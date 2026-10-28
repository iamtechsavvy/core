import Foundation

final class ServiceController: ServiceControlling {
    func isInstalled() -> Bool {
        FileManager.default.fileExists(atPath: AppConfig.plistPath)
    }

    func isRunning() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = ["list", AppConfig.label]
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        try? task.run()
        task.waitUntilExit()

        if task.terminationStatus == 0 {
            return true
        }

        let count = Int(sh("pgrep -f 'outlook-reminder-center.sh' 2>/dev/null | wc -l | tr -d ' '")) ?? 0
        return count > 0
    }

    func getInterval() -> Int {
        Int(sh("""
                     /usr/libexec/PlistBuddy \
                         -c 'Print :EnvironmentVariables:OUTLOOK_CHECK_INTERVAL' \
                         '\(AppConfig.plistPath)' 2>/dev/null || echo 10
                     """)) ?? 10
    }

    func getDebug() -> Bool {
        sh("""
           /usr/libexec/PlistBuddy \
             -c 'Print :EnvironmentVariables:OUTLOOK_DEBUG' \
             '\(AppConfig.plistPath)' 2>/dev/null || echo 0
           """) == "1"
    }

        func getImminentMinutes() -> Int {
                Int(sh("""
                     /usr/libexec/PlistBuddy \
                         -c 'Print :EnvironmentVariables:OUTLOOK_IMMINENT_MINUTES' \
                         '\(AppConfig.plistPath)' 2>/dev/null || echo 2
                     """)) ?? 2
        }

    func writePlist(script: String, interval: Int, debug: Bool, imminentMinutes: Int) -> Bool {
        let plist: [String: Any] = [
            "Label": AppConfig.label,
            "ProgramArguments": ["/bin/bash", script],
            "EnvironmentVariables": [
                "OUTLOOK_CHECK_INTERVAL": "\(interval)",
                "OUTLOOK_IMMINENT_MINUTES": "\(imminentMinutes)",
                "OUTLOOK_DEBUG": debug ? "1" : "0",
            ],
            "RunAtLoad": true,
            "KeepAlive": true,
            "ThrottleInterval": 10,
            "StandardOutPath": AppConfig.logDir + "stdout.log",
            "StandardErrorPath": AppConfig.logDir + "stderr.log",
            "ProcessType": "Background",
        ]
        let fm = FileManager.default
        do {
            try fm.createDirectory(atPath: (AppConfig.plistPath as NSString).deletingLastPathComponent,
                                   withIntermediateDirectories: true)
            try fm.createDirectory(atPath: AppConfig.logDir, withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: URL(fileURLWithPath: AppConfig.plistPath), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    func findScript() -> String? {
        if let bundled = Bundle.main.path(forResource: "outlook-reminder-center", ofType: "sh") {
            return bundled
        }

        // Only run the script bundled inside the app; never fall back to
        // arbitrary locations that could be swapped out and run at login.
        return nil
    }

    func loadDaemon() {
        run("/bin/launchctl", ["load", AppConfig.plistPath])
    }

    func stopDaemon() {
        let uid = sh("id -u")
        sh("launchctl bootout gui/\(uid)/\(AppConfig.label) 2>/dev/null; true")
        sh("launchctl unload '\(AppConfig.plistPath)' 2>/dev/null; true")
        sh("pkill -f 'outlook-reminder-center.sh' 2>/dev/null; true")
        Thread.sleep(forTimeInterval: 1.5)
    }

    func uninstallDaemon() {
        try? FileManager.default.removeItem(atPath: AppConfig.plistPath)
        let uid = sh("id -u")
        sh("launchctl bootout gui/\(uid)/\(AppConfig.label) 2>/dev/null; true")
        sh("launchctl unload '\(AppConfig.plistPath)' 2>/dev/null; true")
        sh("pkill -f 'outlook-reminder-center.sh' 2>/dev/null; true")
        Thread.sleep(forTimeInterval: 1.5)
    }
}
