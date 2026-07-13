import Foundation

protocol ApplicationMetadataInspecting {
    func metadata(for applicationURL: URL) throws -> ApplicationMetadata
}
