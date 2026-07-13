import Foundation

protocol ProcessRunning: Sendable {
    func run(executableURL: URL, arguments: [String]) async throws -> ProcessResult
}
