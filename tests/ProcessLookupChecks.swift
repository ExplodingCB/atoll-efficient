import Foundation
import Darwin

@main struct ProcessLookupChecks {
    static func main() {
        let pid = getpid()
        guard let name = LocalProcessLookup.processName(pid) else { fatalError("self lookup failed") }
        precondition(LocalProcessLookup.pids(named: name).contains(pid))
        precondition(LocalProcessLookup.pids(named: "atoll-no-such-process-9876").isEmpty)
        precondition(LocalProcessLookup.processName(-1) == nil)
        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: "/bin/sleep")
        helper.arguments = ["10"]
        try! helper.run()
        let childPID = helper.processIdentifier
        precondition(LocalProcessLookup.pids(named: "sleep").contains(childPID))
        helper.terminate()
        helper.waitUntilExit()
        precondition(!LocalProcessLookup.pids(named: "sleep").contains(childPID))
        print("PASS: self, unknown name, invalid PID, live child, exited child")
    }
}
