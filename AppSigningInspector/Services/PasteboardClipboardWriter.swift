import AppKit
import Foundation

struct PasteboardClipboardWriter: ClipboardWriting {
    func copy(_ value: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
    }
}
