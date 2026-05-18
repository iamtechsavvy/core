import Cocoa

let app = NSApplication.shared
let adapter = PlatformAdapterFactory.current()
let appDelegate = AppDelegate(service: adapter.serviceController)

app.setActivationPolicy(.accessory)
app.delegate = appDelegate
app.run()
