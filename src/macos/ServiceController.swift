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

        func writePlist(script: String, interval: Int, debug: Bool, imminentMinutes: Int) {
        let py = """
import plistlib, os, pathlib
p = os.environ['ORC_PLIST']
pathlib.Path(p).parent.mkdir(parents=True, exist_ok=True)
pathlib.Path(os.environ['ORC_LOG']).mkdir(parents=True, exist_ok=True)
d = {
  'Label': os.environ['ORC_LABEL'],
  'ProgramArguments': ['/bin/bash', os.environ['ORC_SCRIPT']],
  'EnvironmentVariables': {
    'OUTLOOK_CHECK_INTERVAL': os.environ['ORC_INTERVAL'],
        'OUTLOOK_IMMINENT_MINUTES': os.environ['ORC_IMMINENT_MINUTES'],
    'OUTLOOK_DEBUG':          os.environ['ORC_DEBUG'],
  },
  'RunAtLoad': True, 'KeepAlive': True, 'ThrottleInterval': 10,
  'StandardOutPath':  os.environ['ORC_LOG'] + 'stdout.log',
  'StandardErrorPath':os.environ['ORC_LOG'] + 'stderr.log',
  'ProcessType': 'Background',
}
open(p, 'wb').write(plistlib.dumps(d, fmt=plistlib.FMT_XML))
"""
        let tmpPy = FileManager.default.temporaryDirectory
            .appendingPathComponent("orc_pw_\(ProcessInfo.processInfo.processIdentifier).py").path
        try? py.write(toFile: tmpPy, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: tmpPy) }

        var env = ProcessInfo.processInfo.environment
        env["ORC_LABEL"] = AppConfig.label
        env["ORC_SCRIPT"] = script
        env["ORC_INTERVAL"] = "\(interval)"
        env["ORC_IMMINENT_MINUTES"] = "\(imminentMinutes)"
        env["ORC_DEBUG"] = debug ? "1" : "0"
        env["ORC_PLIST"] = AppConfig.plistPath
        env["ORC_LOG"] = AppConfig.logDir

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        task.arguments = [tmpPy]
        task.environment = env
        try? task.run()
        task.waitUntilExit()
    }

    func findScript() -> String? {
        if let bundled = Bundle.main.path(forResource: "outlook-reminder-center", ofType: "sh") {
            return bundled
        }

        let appDir = URL(fileURLWithPath: Bundle.main.bundlePath)
            .deletingLastPathComponent().path

        let candidates = [
            appDir + "/outlook-reminder-center.sh",
            AppConfig.home + "/workspace/outlook-reminder-center/src/macos/outlook-reminder-center.sh",
            AppConfig.home + "/src/macos/outlook-reminder-center.sh"
        ]

        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }

    func loadDaemon() {
        sh("launchctl load '\(AppConfig.plistPath)'")
    }

    func stopDaemon() {
        let uid = sh("id -u")
        sh("launchctl bootout gui/\(uid)/\(AppConfig.label) 2>/dev/null; true")
        sh("launchctl unload '\(AppConfig.plistPath)' 2>/dev/null; true")
        sh("pkill -f 'outlook-reminder-center.sh' 2>/dev/null; true")
        Thread.sleep(forTimeInterval: 1.5)
    }

    func uninstallDaemon() {
        sh("rm -f '\(AppConfig.plistPath)'")
        let uid = sh("id -u")
        sh("launchctl bootout gui/\(uid)/\(AppConfig.label) 2>/dev/null; true")
        sh("launchctl unload '\(AppConfig.plistPath)' 2>/dev/null; true")
        sh("pkill -f 'outlook-reminder-center.sh' 2>/dev/null; true")
        Thread.sleep(forTimeInterval: 1.5)
    }
}
