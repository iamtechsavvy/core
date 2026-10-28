import Foundation

protocol ServiceControlling {
    func isInstalled() -> Bool
    func isRunning() -> Bool
    func getInterval() -> Int
    func getDebug() -> Bool
    func getImminentMinutes() -> Int
    func writePlist(script: String, interval: Int, debug: Bool, imminentMinutes: Int) -> Bool
    func findScript() -> String?
    func loadDaemon()
    func stopDaemon()
    func uninstallDaemon()
}

protocol PlatformAdapter {
    var platformName: String { get }
    var serviceController: ServiceControlling { get }
}

enum PlatformAdapterFactory {
    static func current() -> PlatformAdapter {
        #if os(macOS)
        return MacOSPlatformAdapter()
        #else
        return UnsupportedPlatformAdapter()
        #endif
    }
}

private struct UnsupportedPlatformAdapter: PlatformAdapter {
    let platformName = "unsupported"

    var serviceController: ServiceControlling {
        fatalError("No platform adapter available for this OS")
    }
}
