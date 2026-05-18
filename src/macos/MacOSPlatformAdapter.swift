import Foundation

struct MacOSPlatformAdapter: PlatformAdapter {
    let platformName = "macOS"
    let serviceController: ServiceControlling = ServiceController()
}
