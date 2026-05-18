import Cocoa

func makeStatusTitle(running: Bool, installed: Bool, interval: Int) -> NSAttributedString {
    let text = running
        ? "Running - every \(interval)s"
        : (installed ? "Stopped - will restart at login" : "Stopped - not installed")
    let dotColor: NSColor = running ? .systemGreen : .systemRed

    let output = NSMutableAttributedString(
        string: "● ",
        attributes: [.foregroundColor: dotColor]
    )
    output.append(
        NSAttributedString(
            string: text,
            attributes: [.foregroundColor: NSColor.labelColor]
        )
    )
    return output
}
