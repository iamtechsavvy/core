import Cocoa
import Foundation

final class RangeIntegerFormatter: Formatter {
    private let minValue: Int
    private let maxValue: Int
    private let maxDigits: Int

    init(min: Int, max: Int) {
        self.minValue = min
        self.maxValue = max
        self.maxDigits = String(max).count
        super.init()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func string(for obj: Any?) -> String? {
        if let number = obj as? NSNumber {
            return "\(number.intValue)"
        }
        if let value = obj as? Int {
            return "\(value)"
        }
        return nil
    }

    override func getObjectValue(
        _ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?,
        for string: String,
        errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?
    ) -> Bool {
        guard let value = Int(string), (minValue...maxValue).contains(value) else {
            return false
        }
        obj?.pointee = NSNumber(value: value)
        return true
    }

    override func isPartialStringValid(
        _ partialString: String,
        newEditingString newString: AutoreleasingUnsafeMutablePointer<NSString?>?,
        errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?
    ) -> Bool {
        if partialString.isEmpty {
            return true
        }

        if partialString.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) != nil {
            return false
        }

        if partialString.count > maxDigits {
            return false
        }

        if partialString.count > 1, partialString.first == "0" {
            return false
        }

        guard let value = Int(partialString), value <= maxValue else {
            return false
        }

        if minValue > 0 && partialString == "0" {
            return false
        }

        return true
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let service: ServiceControlling
    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!
    private var refreshTimer: Timer?
    private var dailyTimer: Timer?
    private var scriptPath: String?

    init(service: ServiceControlling) {
        self.service = service
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        scriptPath = service.findScript()
        configureStatusItem()
        configureMenu()
        refreshStatus()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.refreshStatus()
        }

        maybeRotateLogs()
        scheduleDailyRotation()
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem.button else { return }

        if let symbol = NSImage(systemSymbolName: "clock.fill", accessibilityDescription: "CORE")
            ?? NSImage(systemSymbolName: "alarm.fill", accessibilityDescription: "CORE") {
            let base = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
            let config = base.applying(NSImage.SymbolConfiguration(scale: .medium))
            let icon = symbol.withSymbolConfiguration(config) ?? symbol
            icon.isTemplate = true
            button.image = icon
            button.imageScaling = .scaleProportionallyDown
            button.imagePosition = .imageOnly
        } else {
            button.title = "CORE"
        }

        button.toolTip = "CORE"
        button.setAccessibilityLabel("CORE reminder status")
    }

    private func configureMenu() {
        let menu = NSMenu()

        statusMenuItem = NSMenuItem(title: "Checking...", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())
        menu.addItem(menuItem("Change Check Interval", #selector(changeInterval)))
        menu.addItem(menuItem("Change Reminder Lead Time", #selector(changeImminentMinutes)))
        menu.addItem(menuItem("Install / Restart Service", #selector(install)))
        menu.addItem(menuItem("Stop Service", #selector(stop)))
        menu.addItem(.separator())
        menu.addItem(menuItem("Open Logs Folder", #selector(openLogs)))
        menu.addItem(menuItem("Clear Logs", #selector(clearLogs)))
        menu.addItem(menuItem("Uninstall Service", #selector(uninstall)))
        menu.addItem(.separator())
        let createdByItem = NSMenuItem(title: "Created By: Naresh Vasikarla", action: nil, keyEquivalent: "")
        createdByItem.isEnabled = false
        menu.addItem(createdByItem)
        menu.addItem(menuItem("What is this?", #selector(about)))
        menu.addItem(menuItem("Quit", #selector(quit)))

        statusItem.menu = menu
    }

    private func refreshStatus() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let running = self.service.isRunning()
            let installed = self.service.isInstalled()
            let interval = running ? self.service.getInterval() : 0
            let status = makeStatusTitle(running: running, installed: installed, interval: interval)

            DispatchQueue.main.async {
                self.statusItem.button?.title = ""
                self.statusMenuItem.attributedTitle = status
            }
        }
    }

    private func menuItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func alert(_ title: String, _ message: String, style: NSAlert.Style = .informational) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func confirm(_ title: String, _ message: String, ok okLabel: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: okLabel)
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func makeIntegerFormatter(min: Int, max: Int) -> RangeIntegerFormatter {
        let formatter = RangeIntegerFormatter(min: min, max: max)
        return formatter
    }

    private func makeNumericAccessory(current: Int, min: Int, max: Int) -> (NSTextField, NSView) {
        let accessory = NSView(frame: NSRect(x: 0, y: 0, width: 262, height: 28))

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 232, height: 28))
        input.formatter = makeIntegerFormatter(min: min, max: max)
        input.alignment = .center
        input.integerValue = current
        input.controlSize = .regular
        input.isBezeled = true
        input.isBordered = true
        input.drawsBackground = true

        let stepper = NSStepper(frame: NSRect(x: 232, y: 0, width: 30, height: 28))
        stepper.minValue = Double(min)
        stepper.maxValue = Double(max)
        stepper.increment = 1
        stepper.integerValue = current
        stepper.controlSize = .regular
        stepper.valueWraps = false
        stepper.autorepeat = true
        stepper.bind(.value, to: input, withKeyPath: "objectValue", options: nil)

        accessory.addSubview(input)
        accessory.addSubview(stepper)
        return (input, accessory)
    }

    private func pickInterval(current: Int) -> Int {
        let prompt = NSAlert()
        prompt.messageText = "Check Interval"
        prompt.informativeText = "Enter a whole number from 1 to 300 seconds.\nCurrent: \(current)s"
        prompt.addButton(withTitle: "Apply")
        prompt.addButton(withTitle: "Cancel")

        let (input, accessory) = makeNumericAccessory(current: current, min: 1, max: 300)
        prompt.accessoryView = accessory

        NSApp.activate(ignoringOtherApps: true)
        guard prompt.runModal() == .alertFirstButtonReturn else { return -1 }

        let value = input.integerValue
        guard (1...300).contains(value) else {
            alert("Invalid Value", "Please enter a whole number between 1 and 300.", style: .warning)
            return -1
        }
        return value
    }

    private func pickImminentMinutes(current: Int) -> Int {
        let prompt = NSAlert()
        prompt.messageText = "Reminder Lead Time"
        prompt.informativeText = "Enter a whole number from 0 to 30 minutes.\n0 means Now only.\nCurrent: \(current)"
        prompt.addButton(withTitle: "Apply")
        prompt.addButton(withTitle: "Cancel")

        let (input, accessory) = makeNumericAccessory(current: current, min: 0, max: 30)
        prompt.accessoryView = accessory

        NSApp.activate(ignoringOtherApps: true)
        guard prompt.runModal() == .alertFirstButtonReturn else { return -1 }

        let value = input.integerValue
        guard (0...30).contains(value) else {
            alert("Invalid Value", "Please enter a whole number between 0 and 30.", style: .warning)
            return -1
        }
        return value
    }

    private func runStopDaemon(then completion: @escaping () -> Void = {}) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.service.stopDaemon()
            DispatchQueue.main.async {
                completion()
            }
        }
    }

    @objc private func changeInterval() {
        guard service.isInstalled() else {
            alert("Not Installed", "Install the service first, then change the interval.")
            return
        }

        let value = pickInterval(current: service.getInterval())
        guard value != -1 else { return }

        guard let script = scriptPath ?? service.findScript() else {
            alert("Script Not Found", "Place outlook-reminder-center.sh in the same folder as the .app.")
            return
        }

        guard confirm("Apply \(value)s Interval", "Restart the service with the new interval?", ok: "Apply & Restart") else {
            return
        }

        let debugEnabled = service.getDebug()
        let imminentMinutes = service.getImminentMinutes()
        runStopDaemon { [weak self] in
            guard let self else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                self.service.writePlist(
                    script: script,
                    interval: value,
                    debug: debugEnabled,
                    imminentMinutes: imminentMinutes
                )
                self.service.loadDaemon()
                DispatchQueue.main.async {
                    self.refreshStatus()
                }
            }
        }
    }

    @objc private func changeImminentMinutes() {
        guard service.isInstalled() else {
            alert("Not Installed", "Install the service first, then change the reminder lead time.")
            return
        }

        let value = pickImminentMinutes(current: service.getImminentMinutes())
        guard value != -1 else { return }

        guard let script = scriptPath ?? service.findScript() else {
            alert("Script Not Found", "Place outlook-reminder-center.sh in the same folder as the .app.")
            return
        }

        let summary = value == 0 ? "Now only" : "Now + \(value) min"
        guard confirm("Apply Lead Time", "Restart the service with lead time: \(summary)?", ok: "Apply & Restart") else {
            return
        }

        let debugEnabled = service.getDebug()
        let interval = service.getInterval()
        runStopDaemon { [weak self] in
            guard let self else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                self.service.writePlist(
                    script: script,
                    interval: interval,
                    debug: debugEnabled,
                    imminentMinutes: value
                )
                self.service.loadDaemon()
                DispatchQueue.main.async {
                    self.refreshStatus()
                }
            }
        }
    }

    @objc private func install() {
        guard let script = scriptPath ?? service.findScript() else {
            alert("Script Not Found", "Place outlook-reminder-center.sh in the same folder as the .app.")
            return
        }

        let value = pickInterval(current: service.isInstalled() ? service.getInterval() : 10)
        guard value != -1 else { return }

        let installWork = { [weak self] in
            guard let self else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                sh("chmod +x '\(script)'")
                let imminentMinutes = self.service.isInstalled() ? self.service.getImminentMinutes() : 2
                self.service.writePlist(
                    script: script,
                    interval: value,
                    debug: false,
                    imminentMinutes: imminentMinutes
                )
                self.service.loadDaemon()
                sh("osascript -e 'display notification \"Running - checking every \(value)s\" with title \"CORE\" subtitle \"Service started\"'")
                DispatchQueue.main.async {
                    self.refreshStatus()
                    self.alert(
                        "CORE Installed",
                        "Service running. Check interval: \(value)s\nStarts automatically at login."
                    )
                }
            }
        }

        if service.isInstalled() {
            runStopDaemon(then: installWork)
        } else {
            installWork()
        }
    }

    @objc private func stop() {
        guard confirm("Stop Service", "Stop the daemon? It will not restart until next login or manual start.", ok: "Stop") else {
            return
        }

        runStopDaemon { [weak self] in
            self?.refreshStatus()
        }
    }

    @objc private func uninstall() {
        guard confirm("Uninstall", "Remove the service from login items and stop it now?", ok: "Uninstall") else {
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            self.service.uninstallDaemon()
            DispatchQueue.main.async {
                self.refreshStatus()
            }
        }
    }

    @objc private func openLogs() {
        sh("mkdir -p '\(AppConfig.logDir)'")
        NSWorkspace.shared.open(URL(fileURLWithPath: AppConfig.logDir))
    }

    private func maybeRotateLogs() {
        let stampFile = AppConfig.logDir + "stdout.log"
        if let attrs = try? FileManager.default.attributesOfItem(atPath: stampFile),
           let modified = attrs[.modificationDate] as? Date,
           Date().timeIntervalSince(modified) < 86400 {
            return
        }
        rotateLogs()
    }

    private func rotateLogs() {
        sh("mkdir -p '\(AppConfig.logDir)'")
        for file in AppConfig.logFiles {
            let path = AppConfig.logDir + file
            if FileManager.default.fileExists(atPath: path) {
                try? "".write(toFile: path, atomically: false, encoding: .utf8)
            }
        }
    }

    private func scheduleDailyRotation() {
        dailyTimer?.invalidate()
        let calendar = Calendar.current
        guard let nextMidnight = calendar.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) else {
            return
        }

        let delay = nextMidnight.timeIntervalSinceNow
        dailyTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.rotateLogs()
            self?.scheduleDailyRotation()
        }
    }

    @objc private func clearLogs() {
        guard confirm("Clear Logs", "Truncate stdout.log, stderr.log and debug.log now?", ok: "Clear") else {
            return
        }

        rotateLogs()
        let previousTitle = statusItem.button?.title ?? ""
        DispatchQueue.main.async {
            self.statusItem.button?.title = "cleared"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.statusItem.button?.title = previousTitle
        }
    }

    @objc private func about() {
        let text: String
        if let path = Bundle.main.path(forResource: "ABOUT", ofType: "md"),
           let contents = try? String(contentsOfFile: path, encoding: .utf8) {
            text = contents
                .components(separatedBy: .newlines)
                .filter { !$0.hasPrefix("#") }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            text = "CORE keeps your Outlook meeting reminders visible and centered on screen."
        }

        alert("What is CORE?", text)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
