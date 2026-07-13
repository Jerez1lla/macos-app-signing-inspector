import Combine
import Foundation

@MainActor
final class ApplicationBrowserViewModel: ObservableObject {
    @Published private(set) var selectedApplication: SelectedApplication?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var codeSignatureInfo: CodeSignatureInfo?
    @Published private(set) var signatureErrorMessage: String?
    @Published private(set) var signatureErrorDetails: String?
    @Published private(set) var isInspectingCodeSignature = false
    @Published private(set) var securityAssessment: ApplicationSecurityAssessment?
    @Published private(set) var securityErrorMessage: String?
    @Published private(set) var isValidatingSecurity = false

    private let picker: ApplicationPicking
    private let metadataInspector: ApplicationMetadataInspecting
    private let codeSignatureInspector: CodeSignatureInspecting
    private let securityAssessor: SecurityAssessing
    private let iconLoader: ApplicationIconLoading
    private let clipboardWriter: ClipboardWriting
    private let fileManager: FileManager

    init(
        picker: ApplicationPicking = ApplicationPickerService(),
        metadataInspector: ApplicationMetadataInspecting = ApplicationMetadataInspector(),
        codeSignatureInspector: CodeSignatureInspecting = ApplicationCodeSignatureInspector(),
        securityAssessor: SecurityAssessing = ApplicationSecurityAssessor(),
        iconLoader: ApplicationIconLoading = WorkspaceApplicationIconLoader(),
        clipboardWriter: ClipboardWriting = PasteboardClipboardWriter(),
        fileManager: FileManager = .default
    ) {
        self.picker = picker
        self.metadataInspector = metadataInspector
        self.codeSignatureInspector = codeSignatureInspector
        self.securityAssessor = securityAssessor
        self.iconLoader = iconLoader
        self.clipboardWriter = clipboardWriter
        self.fileManager = fileManager
    }

    var hasSelectedApplication: Bool {
        selectedApplication != nil
    }

    func selectApplication() async {
        do {
            let result = try await picker.selectApplication()
            switch result {
            case .cancelled:
                return
            case .selected(let url):
                clearCodeSignatureState()
                clearSecurityState()
                isLoading = true
                selectedApplication = try application(from: url)
                errorMessage = nil
                isLoading = false
                await inspectCodeSignature(for: url)
                if let metadata = selectedApplication?.metadata {
                    await validateSecurity(for: metadata)
                }
            }
        } catch let error as ApplicationBrowserError {
            errorMessage = error.userMessage
            isLoading = false
        } catch let error as ApplicationMetadataError {
            errorMessage = error.userMessage
            isLoading = false
        } catch {
            errorMessage = "Unable to select the application. Try choosing a different .app bundle."
            isLoading = false
        }
    }

    func copyBundleIdentifier() {
        copy(selectedApplication?.metadata.bundleIdentifier)
    }

    func copyBundlePath() {
        copy(selectedApplication?.metadata.bundlePath)
    }

    func copyExecutablePath() {
        copy(selectedApplication?.metadata.executablePath)
    }

    func copySigningIdentifier() {
        copy(codeSignatureInfo?.signingIdentifier)
    }

    func copyTeamIdentifier() {
        copy(codeSignatureInfo?.teamIdentifier)
    }

    func copyDesignatedRequirement() {
        copy(codeSignatureInfo?.designatedRequirement)
    }

    func copySigningAuthority(_ authority: String) {
        guard codeSignatureInfo?.authorities.contains(authority) == true else {
            return
        }

        copy(authority)
    }

    func copyRawSigningDiagnostics() {
        copy(codeSignatureInfo?.rawDiagnostics)
    }

    func copySignatureErrorDetails() {
        copy(signatureErrorDetails)
    }

    func copyGatekeeperSource() {
        copy(securityAssessment?.gatekeeper.source)
    }

    func copyGatekeeperRejectionReason() {
        copy(securityAssessment?.gatekeeper.rejectionReason)
    }

    func copyArchitectureList() {
        copy(securityAssessment?.architecture.architectureList)
    }

    func copyRawGatekeeperDiagnostics() {
        copy(securityAssessment?.gatekeeper.rawDiagnostics)
    }

    func copyRawArchitectureDiagnostics() {
        copy(securityAssessment?.architecture.rawDiagnostics)
    }

    func application(from url: URL) throws -> SelectedApplication {
        guard fileManager.fileExists(atPath: url.path) else {
            throw ApplicationBrowserError.applicationDoesNotExist(url)
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ApplicationBrowserError.notApplicationBundle(url)
        }

        guard url.pathExtension.lowercased() == "app" else {
            throw ApplicationBrowserError.notApplicationBundle(url)
        }

        guard fileManager.isReadableFile(atPath: url.path) else {
            throw ApplicationBrowserError.applicationNotReadable(url)
        }

        let metadata = try metadataInspector.metadata(for: url)
        let icon = try iconLoader.icon(for: url)

        return SelectedApplication(metadata: metadata, icon: icon)
    }

    private func inspectCodeSignature(for applicationURL: URL) async {
        isInspectingCodeSignature = true
        defer {
            isInspectingCodeSignature = false
        }

        do {
            codeSignatureInfo = try await codeSignatureInspector.inspect(applicationAt: applicationURL)
            signatureErrorMessage = nil
            signatureErrorDetails = nil
        } catch let error as CodeSignatureInspectionError {
            codeSignatureInfo = nil
            signatureErrorMessage = error.userMessage
            signatureErrorDetails = error.diagnosticDetails
        } catch {
            codeSignatureInfo = nil
            signatureErrorMessage = "Code-signature inspection failed. Try again or choose another application."
            signatureErrorDetails = error.localizedDescription
        }
    }

    private func clearCodeSignatureState() {
        codeSignatureInfo = nil
        signatureErrorMessage = nil
        signatureErrorDetails = nil
        isInspectingCodeSignature = false
    }

    private func validateSecurity(for metadata: ApplicationMetadata) async {
        isValidatingSecurity = true
        defer {
            isValidatingSecurity = false
        }

        let assessment = await securityAssessor.assess(
            applicationAt: metadata.applicationURL,
            executablePath: metadata.executablePath
        )
        securityAssessment = assessment
        securityErrorMessage = assessment.validationStatus == .unavailable
            ? "Security validation could not be completed. Review the diagnostic details."
            : nil
    }

    private func clearSecurityState() {
        securityAssessment = nil
        securityErrorMessage = nil
        isValidatingSecurity = false
    }

    private func copy(_ value: String?) {
        guard let value, !value.isEmpty else {
            return
        }

        clipboardWriter.copy(value)
    }
}

enum ApplicationBrowserError: Error, Equatable {
    case applicationDoesNotExist(URL)
    case notApplicationBundle(URL)
    case applicationNotReadable(URL)
    case iconUnavailable(URL)

    var userMessage: String {
        switch self {
        case .applicationDoesNotExist:
            return "The selected application could not be found. Choose an existing .app bundle."
        case .notApplicationBundle:
            return "The selected item is not a macOS application bundle. Choose a .app bundle."
        case .applicationNotReadable:
            return "The selected application cannot be read. Check permissions or choose a different app."
        case .iconUnavailable:
            return "The application icon could not be loaded. Choose a different .app bundle."
        }
    }
}
