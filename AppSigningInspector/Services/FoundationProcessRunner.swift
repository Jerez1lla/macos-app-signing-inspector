import Foundation

struct FoundationProcessRunner: ProcessRunning {
    func run(executableURL: URL, arguments: [String]) async throws -> ProcessResult {
        try await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            guard fileManager.isExecutableFile(atPath: executableURL.path) else {
                throw ProcessExecutionError.executableUnavailable(
                    executableURL: executableURL,
                    arguments: arguments
                )
            }

            let outputURL = fileManager.temporaryDirectory
                .appendingPathComponent("AppSigningInspector-\(UUID().uuidString)-stdout")
            let errorURL = fileManager.temporaryDirectory
                .appendingPathComponent("AppSigningInspector-\(UUID().uuidString)-stderr")

            defer {
                try? fileManager.removeItem(at: outputURL)
                try? fileManager.removeItem(at: errorURL)
            }

            let privateFileAttributes: [FileAttributeKey: Any] = [
                .posixPermissions: 0o600
            ]
            guard fileManager.createFile(
                atPath: outputURL.path,
                contents: nil,
                attributes: privateFileAttributes
            ), fileManager.createFile(
                atPath: errorURL.path,
                contents: nil,
                attributes: privateFileAttributes
            ) else {
                throw ProcessExecutionError.outputCaptureFailed(
                    executableURL: executableURL,
                    arguments: arguments,
                    description: "Temporary output files could not be created."
                )
            }

            let outputHandle: FileHandle
            let errorHandle: FileHandle
            do {
                outputHandle = try FileHandle(forWritingTo: outputURL)
                errorHandle = try FileHandle(forWritingTo: errorURL)
            } catch {
                throw ProcessExecutionError.outputCaptureFailed(
                    executableURL: executableURL,
                    arguments: arguments,
                    description: error.localizedDescription
                )
            }

            defer {
                try? outputHandle.close()
                try? errorHandle.close()
            }

            let process = Process()
            process.executableURL = executableURL
            process.arguments = arguments
            process.standardOutput = outputHandle
            process.standardError = errorHandle

            do {
                try process.run()
            } catch {
                throw ProcessExecutionError.launchFailed(
                    executableURL: executableURL,
                    arguments: arguments,
                    description: error.localizedDescription
                )
            }

            process.waitUntilExit()

            do {
                try outputHandle.close()
                try errorHandle.close()
                let outputData = try Data(contentsOf: outputURL)
                let errorData = try Data(contentsOf: errorURL)

                return ProcessResult(
                    executableURL: executableURL,
                    arguments: arguments,
                    terminationStatus: process.terminationStatus,
                    standardOutput: String(decoding: outputData, as: UTF8.self),
                    standardError: String(decoding: errorData, as: UTF8.self)
                )
            } catch {
                throw ProcessExecutionError.outputCaptureFailed(
                    executableURL: executableURL,
                    arguments: arguments,
                    description: error.localizedDescription
                )
            }
        }.value
    }
}
