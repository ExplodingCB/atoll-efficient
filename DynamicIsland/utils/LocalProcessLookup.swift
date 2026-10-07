import Foundation
import Darwin

/// Looks up this user's processes without launching pgrep/killall or asking
/// a monitoring daemon to collect system-wide resource statistics.
enum LocalProcessLookup {
    static func pids(named name: String, userID: uid_t = getuid()) -> [pid_t] {
        let bytes = proc_listpids(UInt32(PROC_UID_ONLY), userID, nil, 0)
        guard bytes > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(bytes) / MemoryLayout<pid_t>.size + 64)
        let capacity = Int32(pids.count * MemoryLayout<pid_t>.size)
        let actualBytes = pids.withUnsafeMutableBytes {
            proc_listpids(UInt32(PROC_UID_ONLY), userID, $0.baseAddress, capacity)
        }
        guard actualBytes > 0 else { return [] }
        return pids.prefix(Int(actualBytes) / MemoryLayout<pid_t>.size).filter {
            $0 > 0 && processName($0) == name
        }
    }

    static func processName(_ pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 1024)
        let length = proc_name(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(cString: buffer)
    }
}
