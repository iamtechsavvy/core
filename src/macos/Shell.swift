import Foundation

@discardableResult
func sh(_ cmd: String) -> String {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/sh")
    task.arguments = ["-c", cmd]
    let stdout = Pipe()
    let stderr = Pipe()
    task.standardOutput = stdout
    task.standardError = stderr

    try? task.run()
    task.waitUntilExit()

    let data = stdout.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}

/// Runs an executable directly (no shell), so arguments are never re-parsed.
@discardableResult
func run(_ executable: String, _ args: [String]) -> Int32 {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: executable)
    task.arguments = args
    task.standardOutput = Pipe()
    task.standardError = Pipe()
    do { try task.run() } catch { return -1 }
    task.waitUntilExit()
    return task.terminationStatus
}
