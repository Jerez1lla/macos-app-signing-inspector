import AppKit
import Foundation

struct SelectedApplication {
    let url: URL
    let name: String
    let icon: NSImage

    var path: String {
        url.path
    }
}
