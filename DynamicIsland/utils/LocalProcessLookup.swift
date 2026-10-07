import Foundation
import Darwin

/// Looks up this user's processes without launching pgrep/killall or asking
/// a monitoring daemon to collect system-wide resource statistics.
enum LocalProcessLookup {
    static func pids(named name: String, userID: uid_t = getuid()) -> [pid_t] {
        allPIDs(userID: userID).filter { processName($0) == name }
    }

    static func allPIDs(userID: uid_t = getuid()) -> [pid_t] {
        let bytes = proc_listpids(UInt32(PROC_UID_ONLY), userID, nil, 0)
        guard bytes > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(bytes) / MemoryLayout<pid_t>.size + 64)
        let capacity = Int32(pids.count * MemoryLayout<pid_t>.size)
        let actualBytes = pids.withUnsafeMutableBytes {
            proc_listpids(UInt32(PROC_UID_ONLY), userID, $0.baseAddress, capacity)
        }
        guard actualBytes > 0 else { return [] }
        return pids.prefix(Int(actualBytes) / MemoryLayout<pid_t>.size).filter { $0 > 0 }
    }

    static func processName(_ pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 1024)
        let length = proc_name(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(cString: buffer)
    }

    static func parentPID(_ pid: pid_t) -> pid_t? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        return pid_t(info.pbi_ppid)
    }

    /// argv of a process, read with KERN_PROCARGS2 (argc, exec path, argv...).
    static func arguments(_ pid: pid_t) -> [String]? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return nil }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return nil }
        let argc = buffer.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) }
        var index = MemoryLayout<Int32>.size
        while index < size, buffer[index] != 0 { index += 1 } // exec path
        while index < size, buffer[index] == 0 { index += 1 } // padding
        var arguments: [String] = []
        while arguments.count < argc, index < size {
            let start = index
            while index < size, buffer[index] != 0 { index += 1 }
            arguments.append(String(decoding: buffer[start..<index], as: UTF8.self))
            index += 1
        }
        return arguments
    }
}
