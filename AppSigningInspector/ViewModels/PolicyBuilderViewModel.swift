import AppKit
import Combine
import Foundation

@MainActor
final class PolicyBuilderViewModel: ObservableObject {
    @Published private(set) var entries: [PolicyEntry] = []
    @Published private(set) var notices: [PolicyBuilderNotice] = []
    @Published private(set) var isAddingApplications = false
    @Published private(set) var isExporting = false
    @Published private(set) var jsonPreview: String?
    @Published private(set) var generationErrorMessage: String?
    @Published private(set) var workflowErrorMessage: String?
    @Published private(set) var exportStatusMessage: String?

    private let picker: PolicyApplicationPicking
    private let metadataInspector: ApplicationMetadataInspecting
    private let codeSignatureInspector: CodeSignatureInspecting
    private let iconLoader: ApplicationIconLoading
    private let clipboardWriter: ClipboardWriting
    private let declarationGenerator: DDMDeclarationGenerating
    private let exporter: JSONExporting
    private let declarationIdentifier: UUID
    private let serverToken: UUID
    private let entryIDProvider: () -> UUID

    init(
        picker: PolicyApplicationPicking = ApplicationPickerService(),
        metadataInspector: ApplicationMetadataInspecting = ApplicationMetadataInspector(),
        codeSignatureInspector: CodeSignatureInspecting = ApplicationCodeSignatureInspector(),
        iconLoader: ApplicationIconLoading = WorkspaceApplicationIconLoader(),
        clipboardWriter: ClipboardWriting = PasteboardClipboardWriter(),
        declarationGenerator: DDMDeclarationGenerating = DDMDeclarationGenerator(),
        exporter: JSONExporting = JSONExportService(),
        declarationIdentifier: UUID = UUID(),
        serverToken: UUID = UUID(),
        entryIDProvider: @escaping () -> UUID = UUID.init
    ) {
        self.picker = picker
        self.metadataInspector = metadataInspector
        self.codeSignatureInspector = codeSignatureInspector
        self.iconLoader = iconLoader
        self.clipboardWriter = clipboardWriter
        self.declarationGenerator = declarationGenerator
        self.exporter = exporter
        self.declarationIdentifier = declarationIdentifier
        self.serverToken = serverToken
        self.entryIDProvider = entryIDProvider
        generationErrorMessage = DDMDeclarationGenerationError.emptyPolicy.userMessage
    }

    var canExport: Bool {
        !isAddingApplications
            && !isExporting
            && !entries.isEmpty
            && entries.allSatisfy(\.isValid)
            && jsonPreview != nil
    }

    var allowOnlySafetyWarning: String? {
        let validEntries = entries.filter(\.isValid)
        guard !validEntries.isEmpty,
              validEntries.allSatisfy({ $0.action == .allow }) else {
            return nil
        }

        return "Allow-only policies can block management agents, security tools, background services, and other required software. Confirm every required application before deployment."
    }

    func addApplications() async {
        workflowErrorMessage = nil
        exportStatusMessage = nil

        do {
            let result = try await picker.selectApplications()
            guard case .selected(let applicationURLs) = result else {
                return
            }

            notices = []
            isAddingApplications = true
            defer {
                isAddingApplications = false
                refreshGenerationState()
            }

            for applicationURL in applicationURLs {
                await addApplication(at: applicationURL)
            }
        } catch {
            workflowErrorMessage = "Applications could not be selected. Try again."
        }
    }

    func setAction(_ action: PolicyAction, for entryID: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else {
            return
        }

        entries[index].action = action
        exportStatusMessage = nil
        refreshGenerationState()
    }

    func removeEntry(id: UUID) {
        entries.removeAll { $0.id == id }
        exportStatusMessage = nil
        refreshGenerationState()
    }

    func copyGeneratedJSON() {
        guard canExport, let jsonPreview else {
            return
        }
        clipboardWriter.copy(jsonPreview)
        exportStatusMessage = "Declaration JSON copied."
    }

    func exportGeneratedJSON() async {
        guard canExport, let jsonPreview else {
            workflowErrorMessage = "Resolve policy validation issues before exporting JSON."
            return
        }

        workflowErrorMessage = nil
        exportStatusMessage = nil
        isExporting = true
        defer { isExporting = false }

        do {
            let result = try await exporter.export(
                json: jsonPreview,
                suggestedFilename: "app-settings-declaration.json"
            )
            if case .exported(let destinationURL) = result {
                exportStatusMessage = "Exported \(destinationURL.lastPathComponent)."
            }
        } catch let error as JSONExportError {
            workflowErrorMessage = error.userMessage
        } catch {
            workflowErrorMessage = "The declaration JSON could not be exported. Try again."
        }
    }

    private func addApplication(at applicationURL: URL) async {
        let normalizedPath = applicationURL.standardizedFileURL.path
        if entries.contains(where: { $0.applicationURL.standardizedFileURL.path == normalizedPath }) {
            notices.append(.duplicateApplication(applicationURL.deletingPathExtension().lastPathComponent))
            return
        }

        let metadata: ApplicationMetadata
        let icon: NSImage
        do {
            metadata = try metadataInspector.metadata(for: applicationURL)
            icon = try iconLoader.icon(for: applicationURL)
        } catch {
            notices.append(.applicationInspectionFailed(
                displayName: applicationURL.deletingPathExtension().lastPathComponent,
                details: error.localizedDescription
            ))
            return
        }

        do {
            let signatureInfo = try await codeSignatureInspector.inspect(applicationAt: applicationURL)
            if let signingIdentifier = signatureInfo.signingIdentifier,
               let teamIdentifier = signatureInfo.teamIdentifier,
               entries.contains(where: {
                   $0.signingKey == PolicySigningKey(
                       signingIdentifier: signingIdentifier,
                       teamIdentifier: teamIdentifier
                   )
               }) {
                notices.append(.duplicateSigningEntry(
                    displayName: metadata.displayName,
                    signingIdentifier: signingIdentifier,
                    teamIdentifier: teamIdentifier
                ))
                return
            }

            entries.append(PolicyEntry(
                id: entryIDProvider(),
                applicationURL: applicationURL,
                displayName: metadata.displayName,
                icon: icon,
                signingIdentifier: signatureInfo.signingIdentifier,
                teamIdentifier: signatureInfo.teamIdentifier,
                action: .deny,
                validationState: validationState(for: signatureInfo)
            ))
        } catch let error as CodeSignatureInspectionError {
            appendSignatureFailureEntry(
                applicationURL: applicationURL,
                metadata: metadata,
                icon: icon,
                details: error.diagnosticDetails
            )
        } catch {
            appendSignatureFailureEntry(
                applicationURL: applicationURL,
                metadata: metadata,
                icon: icon,
                details: error.localizedDescription
            )
        }
    }

    private func appendSignatureFailureEntry(
        applicationURL: URL,
        metadata: ApplicationMetadata,
        icon: NSImage,
        details: String
    ) {
        entries.append(PolicyEntry(
            id: entryIDProvider(),
            applicationURL: applicationURL,
            displayName: metadata.displayName,
            icon: icon,
            signingIdentifier: nil,
            teamIdentifier: nil,
            action: .deny,
            validationState: .signatureInspectionFailed(details)
        ))
    }

    private func validationState(for signatureInfo: CodeSignatureInfo) -> PolicyEntryValidationState {
        switch (signatureInfo.signingIdentifier, signatureInfo.teamIdentifier) {
        case (.some, .some):
            return .valid
        case (.none, .some):
            return .missingSigningIdentifier
        case (.some, .none):
            return .missingTeamIdentifier
        case (.none, .none):
            return .missingSigningAndTeamIdentifiers
        }
    }

    private func refreshGenerationState() {
        guard !entries.isEmpty else {
            jsonPreview = nil
            generationErrorMessage = DDMDeclarationGenerationError.emptyPolicy.userMessage
            return
        }
        guard entries.allSatisfy(\.isValid) else {
            jsonPreview = nil
            generationErrorMessage = DDMDeclarationGenerationError.invalidEntries.userMessage
            return
        }

        let candidates = entries.compactMap(\.binaryCandidate)
        do {
            jsonPreview = try declarationGenerator.generate(
                entries: candidates,
                identifier: declarationIdentifier,
                serverToken: serverToken
            ).json
            generationErrorMessage = nil
        } catch let error as DDMDeclarationGenerationError {
            jsonPreview = nil
            generationErrorMessage = error.userMessage
        } catch {
            jsonPreview = nil
            generationErrorMessage = "The declaration JSON could not be generated."
        }
    }
}
