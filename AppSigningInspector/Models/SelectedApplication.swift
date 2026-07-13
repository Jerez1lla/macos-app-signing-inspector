import AppKit
import Foundation

struct SelectedApplication {
    let metadata: ApplicationMetadata
    let icon: NSImage

    var url: URL {
        metadata.applicationURL
    }

    var name: String {
        metadata.displayName
    }

    var path: String {
        metadata.bundlePath
    }
}
