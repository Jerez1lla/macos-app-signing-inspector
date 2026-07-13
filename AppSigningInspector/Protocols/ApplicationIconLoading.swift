import AppKit
import Foundation

protocol ApplicationIconLoading {
    func icon(for applicationURL: URL) throws -> NSImage
}
