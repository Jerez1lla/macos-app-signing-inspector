import Foundation

enum NativeExecutableArchitecture: Hashable, Sendable {
    case arm64
    case arm64e
    case x86_64
    case unknown(Int)

    init(rawValue: Int) {
        switch rawValue {
        case NSBundleExecutableArchitectureARM64:
            self = .arm64
        case NSBundleExecutableArchitectureX86_64:
            self = .x86_64
        default:
            self = .unknown(rawValue)
        }
    }

    var displayName: String {
        switch self {
        case .arm64:
            return "arm64"
        case .arm64e:
            return "arm64e"
        case .x86_64:
            return "x86_64"
        case .unknown(let rawValue):
            return "unknown(\(rawValue))"
        }
    }
}

struct NativeBundleArchitectureSnapshot: Equatable, Sendable {
    let executablePath: String?
    let rawArchitectureValues: [Int]?
    let architectures: [NativeExecutableArchitecture]?
}

enum NativeBundleArchitectureError: Error, Equatable, Sendable {
    case applicationUnavailable
    case bundleUnavailable

    var details: String {
        switch self {
        case .applicationUnavailable:
            return "The application was removed or is no longer available."
        case .bundleUnavailable:
            return "Foundation could not open the selected application bundle."
        }
    }
}

struct FoundationBundleArchitectureProvider: NativeBundleArchitectureProviding {
    func architectureSnapshot(for applicationURL: URL) throws -> NativeBundleArchitectureSnapshot {
        guard FileManager.default.fileExists(atPath: applicationURL.path) else {
            throw NativeBundleArchitectureError.applicationUnavailable
        }
        guard let bundle = Bundle(url: applicationURL) else {
            throw NativeBundleArchitectureError.bundleUnavailable
        }

        let rawValues = bundle.executableArchitectures?.map(\.intValue)
        return NativeBundleArchitectureSnapshot(
            executablePath: bundle.executableURL?.path,
            rawArchitectureValues: rawValues,
            architectures: rawValues?.map(NativeExecutableArchitecture.init(rawValue:))
        )
    }
}

struct ApplicationArchitectureInspector: ArchitectureInspecting {
    private let provider: NativeBundleArchitectureProviding

    init(provider: NativeBundleArchitectureProviding = FoundationBundleArchitectureProvider()) {
        self.provider = provider
    }

    func inspect(applicationAt applicationURL: URL) async -> ArchitectureAssessment {
        do {
            let snapshot = try provider.architectureSnapshot(for: applicationURL)
            return assessment(for: snapshot, applicationURL: applicationURL)
        } catch let error as NativeBundleArchitectureError {
            return unavailableAssessment(
                status: error == .applicationUnavailable ? .applicationUnavailable : .bundleUnavailable,
                applicationURL: applicationURL,
                details: error.details
            )
        } catch {
            return unavailableAssessment(
                status: .bundleUnavailable,
                applicationURL: applicationURL,
                details: error.localizedDescription
            )
        }
    }

    private func assessment(
        for snapshot: NativeBundleArchitectureSnapshot,
        applicationURL: URL
    ) -> ArchitectureAssessment {
        guard let nativeArchitectures = snapshot.architectures, !nativeArchitectures.isEmpty else {
            return ArchitectureAssessment(
                status: .informationUnavailable,
                architectures: [],
                classification: .unknown,
                rawDiagnostics: diagnosticDetails(
                    applicationURL: applicationURL,
                    snapshot: snapshot,
                    classification: .unknown,
                    error: "Foundation returned no executable architecture information."
                )
            )
        }

        var seen = Set<NativeExecutableArchitecture>()
        let uniqueArchitectures = nativeArchitectures.filter { seen.insert($0).inserted }
        let classification = classification(for: uniqueArchitectures)
        let status: ArchitectureInspectionStatus = classification == .unknown
            ? .unsupportedArchitecture
            : .available

        return ArchitectureAssessment(
            status: status,
            architectures: uniqueArchitectures.map(\.displayName),
            classification: classification,
            rawDiagnostics: diagnosticDetails(
                applicationURL: applicationURL,
                snapshot: snapshot,
                classification: classification,
                error: nil
            )
        )
    }

    private func classification(
        for architectures: [NativeExecutableArchitecture]
    ) -> ArchitectureClassification {
        guard !architectures.contains(where: {
            if case .unknown = $0 { return true }
            return false
        }) else {
            return .unknown
        }

        let supportsAppleSilicon = architectures.contains(.arm64) || architectures.contains(.arm64e)
        let supportsIntel = architectures.contains(.x86_64)
        switch (supportsAppleSilicon, supportsIntel) {
        case (true, true):
            return .universal
        case (true, false):
            return .appleSiliconOnly
        case (false, true):
            return .intelOnly
        case (false, false):
            return .unknown
        }
    }

    private func unavailableAssessment(
        status: ArchitectureInspectionStatus,
        applicationURL: URL,
        details: String
    ) -> ArchitectureAssessment {
        ArchitectureAssessment(
            status: status,
            architectures: [],
            classification: .unknown,
            rawDiagnostics: [
                "Application bundle path: \(applicationURL.path)",
                "Native inspection error: \(details)"
            ].joined(separator: "\n")
        )
    }

    private func diagnosticDetails(
        applicationURL: URL,
        snapshot: NativeBundleArchitectureSnapshot,
        classification: ArchitectureClassification,
        error: String?
    ) -> String {
        var lines = [
            "Application bundle path: \(applicationURL.path)",
            "Resolved executable path: \(snapshot.executablePath ?? "Unavailable")",
            "Native architecture values: \(snapshot.rawArchitectureValues?.map { String($0) }.joined(separator: ", ") ?? "Unavailable")",
            "Mapped architecture names: \(snapshot.architectures?.map(\.displayName).joined(separator: ", ") ?? "Unavailable")",
            "Classification: \(classification.displayValue)"
        ]
        if let error {
            lines.append("Native inspection error: \(error)")
        }
        return lines.joined(separator: "\n")
    }
}
