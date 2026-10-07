import Foundation
import Darwin

/// Helper processes (the mediaremote-adapter.pl stream) that must not outlive
/// the app. Their owners only stop them in deinit, which never runs at exit, so
/// every quit or "Restart Now" used to leave a ~17 MB perl process behind.
enum ChildProcessRegistry {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var processes: [ObjectIdentifier: Process] = [:]

    static func register(_ process: Process) {
        lock.lock()
        defer { lock.unlock() }
        processes = processes.filter { $0.value.isRunning }
        processes[ObjectIdentifier(process)] = process
    }

    /// Called from applicationWillTerminate. SIGTERM, a short grace period,
    /// then SIGKILL for anything still running.
    static func terminateAll() {
        lock.lock()
        let running = processes.values.filter { $0.isRunning }
        processes.removeAll()
        lock.unlock()

        running.forEach { $0.terminate() }
        let deadline = Date().addingTimeInterval(0.5)
        while running.contains(where: { $0.isRunning }), Date() < deadline {
            usleep(20_000)
        }
        for process in running where process.isRunning {
            kill(process.processIdentifier, SIGKILL)
        }
    }

    /// Ends adapters left by an earlier crash or force quit of this app: owned
    /// by launchd (ppid 1) and running this bundle's copy of the script.
    static func reapOrphanedAdapters() {
        guard let script = Bundle.main.url(forResource: "mediaremote-adapter", withExtension: "pl")?.path else { return }
        let ownPID = getpid()
        for pid in LocalProcessLookup.allPIDs() where pid != ownPID {
            guard LocalProcessLookup.parentPID(pid) == 1,
                  let arguments = LocalProcessLookup.arguments(pid),
                  arguments.contains(script) else { continue }
            kill(pid, SIGTERM)
        }
    }
}
