import Foundation

enum AppConfig {
    static let label = "com.core-reminder"
    static let home = FileManager.default.homeDirectoryForCurrentUser.path
    static let plistPath = home + "/Library/LaunchAgents/\(label).plist"
    static let logDir = home + "/Library/Logs/CORE/"
    static let logFiles = ["stdout.log", "stderr.log", "debug.log"]
}
