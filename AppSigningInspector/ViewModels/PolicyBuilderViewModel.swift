import AppKit
import Combine
import Foundation

@MainActor
final class PolicyBuilderViewModel: ObservableObject {
    @Published private(set) var entries: [PolicyEntry] = []
    @Published private(set) var notices: [PolicyBuilderNotice] = []
    @Published private(set) var alwaysAllowManagedApps = false
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
    private let ruleValidator: PolicyRuleValidator
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
        ruleValidator: PolicyRuleValidator = PolicyRuleValidator(),
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
        self.ruleValidator = ruleValidator
        self.declarationIdentifier = declarationIdentifier
        self.serverToken = serverToken
        self.entryIDProvider = entryIDProvider
        generationErrorMessage = DDMDeclarationGenerationError.emptyPolicy.userMessage
    }

    var canExport: Bool {
        !isAddingApplications
            && !isExporting
            && (!entries.isEmpty || alwaysAllowManagedApps)
            && entries.allSatisfy(\.isValid)
            && jsonPreview != nil
    }

    var allowsAllAppleBinaries: Bool {
        entries.contains { $0.rule.type == .appleBinaries }
    }

    var allowOnlySafetyWarning: String? {
        let validEntries = entries.filter(\.isValid)
        let hasAllowBehavior = alwaysAllowManagedApps || validEntries.contains { $0.action == .allow }
        guard hasAllowBehavior, !validEntries.contains(where: { $0.action == .deny }) else {
            return nil
        }

        return "Allow-only policies can block management agents, security tools, background services, and other required software. Confirm every required application before deployment."
    }

    var safetyWarnings: [String] {
        var warnings: [String] = []
        if let allowOnlySafetyWarning {
            warnings.append(allowOnlySafetyWarning)
        }
        if alwaysAllowManagedApps {
            warnings.append("Always Allow Managed Apps depends on macOS identifying an application as managed.")
        }
        if allowsAllAppleBinaries {
            warnings.append("The *APPLE* rule broadly allows Apple binaries according to Apple's documented matching behavior.")
        }

        let broadTeamIdentifiers = Set(entries.compactMap { entry -> String? in
            guard entry.action == .allow,
                  case .developerTeam(let teamIdentifier) = entry.rule else {
                return nil
            }
            return teamIdentifier
        })
        for teamIdentifier in broadTeamIdentifiers.sorted() {
            warnings.append("A developer-wide rule may allow every binary signed with Team ID \(teamIdentifier), not only the selected application.")
        }

        let redundantTeamIdentifiers = Set(entries.compactMap { entry -> String? in
            guard entry.action == .allow,
                  case .specificApplication(_, let possibleTeamIdentifier, _) = entry.rule,
                  let teamIdentifier = possibleTeamIdentifier,
                  broadTeamIdentifiers.contains(teamIdentifier) else {
                return nil
            }
            return teamIdentifier
        })
        for teamIdentifier in redundantTeamIdentifiers.sorted() {
            warnings.append("A developer-wide allow rule for \(teamIdentifier) may already include a specific application rule with the same Team ID.")
        }
        return warnings
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

    func setAlwaysAllowManagedApps(_ enabled: Bool) {
        alwaysAllowManagedApps = enabled
        exportStatusMessage = nil
        refreshGenerationState()
    }

    func setAllowAllAppleBinaries(_ enabled: Bool) {
        if enabled {
            guard !allowsAllAppleBinaries else {
                notices.append(.duplicateRule("Apple binaries"))
                return
            }
            entries.append(PolicyEntry(
                id: entryIDProvider(),
                applicationURL: nil,
                displayName: "Apple Binaries",
                icon: nil,
                signingAuthority: "Apple",
                applicationSigningIdentifier: nil,
                applicationTeamIdentifier: nil,
                rule: .appleBinaries,
                action: .allow,
                validationState: .valid
            ))
        } else {
            entries.removeAll { $0.rule.type == .appleBinaries }
        }
        exportStatusMessage = nil
        refreshGenerationState()
    }

    @discardableResult
    func addDeveloperTeamRule(teamIdentifier rawTeamIdentifier: String) -> Bool {
        workflowErrorMessage = nil
        let teamIdentifier = ruleValidator.normalizedManualTeamIdentifier(rawTeamIdentifier)
        guard !teamIdentifier.isEmpty else {
            workflowErrorMessage = "Enter an Apple signing Team ID."
            return false
        }
        if teamIdentifier == PolicyRule.appleTeamIdentifier {
            if allowsAllAppleBinaries {
                notices.append(.duplicateRule("Apple binaries"))
                return false
            }
            setAllowAllAppleBinaries(true)
            return true
        }
        guard !teamIdentifier.contains("*") else {
            workflowErrorMessage = "Only the documented *APPLE* special Team ID token is supported."
            return false
        }

        let rule = PolicyRule.developerTeam(teamIdentifier: teamIdentifier)
        guard !containsDuplicate(rule: rule) else {
            notices.append(.duplicateRule("developer Team ID \(teamIdentifier)"))
            return false
        }

        entries.append(PolicyEntry(
            id: entryIDProvider(),
            applicationURL: nil,
            displayName: "Developer Team \(teamIdentifier)",
            icon: nil,
            signingAuthority: nil,
            applicationSigningIdentifier: nil,
            applicationTeamIdentifier: nil,
            rule: rule,
            action: .allow,
            validationState: ruleValidator.validate(rule, action: .allow)
        ))
        exportStatusMessage = nil
        refreshGenerationState()
        return true
    }

    func setAction(_ action: PolicyAction, for entryID: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else {
            return
        }
        guard entries[index].rule.supportsDeniedAction || action == .allow else {
            workflowErrorMessage = "Developer Team and Apple rules are currently supported only in AllowedBinaries."
            return
        }

        entries[index].action = action
        entries[index].validationState = ruleValidator.validate(entries[index].rule, action: action)
        exportStatusMessage = nil
        refreshGenerationState()
    }

    @discardableResult
    func updateRule(_ rule: PolicyRule, action: PolicyAction, for entryID: UUID) -> Bool {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else {
            return false
        }
        let resolvedAction = rule.supportsDeniedAction ? action : .allow
        if containsDuplicate(rule: rule, excluding: entryID) {
            notices.append(.duplicateRule(rule.type.displayValue.lowercased()))
            return false
        }

        entries[index].rule = rule
        entries[index].action = resolvedAction
        entries[index].validationState = ruleValidator.validate(rule, action: resolvedAction)
        exportStatusMessage = nil
        refreshGenerationState()
        return true
    }

    func setPathPrefix(_ pathPrefix: String?, for entryID: UUID) {
        guard let entry = entries.first(where: { $0.id == entryID }),
              case .specificApplication(let signingIdentifier, let teamIdentifier, _) = entry.rule else {
            return
        }
        _ = updateRule(
            .specificApplication(
                signingIdentifier: signingIdentifier,
                teamIdentifier: teamIdentifier,
                pathPrefix: pathPrefix
            ),
            action: entry.action,
            for: entryID
        )
    }

    func convertToDeveloperTeamRule(entryID: UUID) {
        guard let entry = entries.first(where: { $0.id == entryID }),
              let teamIdentifier = entry.teamIdentifier else {
            return
        }
        _ = updateRule(.developerTeam(teamIdentifier: teamIdentifier), action: .allow, for: entryID)
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
        if entries.contains(where: { $0.applicationURL?.standardizedFileURL.path == normalizedPath }) {
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
            let rule = PolicyRule.specificApplication(
                signingIdentifier: signatureInfo.signingIdentifier,
                teamIdentifier: signatureInfo.teamIdentifier,
                pathPrefix: nil
            )
            if containsDuplicate(rule: rule) {
                notices.append(.duplicateRule("specific application"))
                return
            }

            entries.append(PolicyEntry(
                id: entryIDProvider(),
                applicationURL: applicationURL,
                displayName: metadata.displayName,
                icon: icon,
                signingAuthority: signatureInfo.authorities.first,
                applicationSigningIdentifier: signatureInfo.signingIdentifier,
                applicationTeamIdentifier: signatureInfo.teamIdentifier,
                rule: rule,
                action: .deny,
                validationState: ruleValidator.validate(rule, action: .deny)
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
            signingAuthority: nil,
            applicationSigningIdentifier: nil,
            applicationTeamIdentifier: nil,
            rule: .specificApplication(
                signingIdentifier: nil,
                teamIdentifier: nil,
                pathPrefix: nil
            ),
            action: .deny,
            validationState: .signatureInspectionFailed(details)
        ))
    }

    private func containsDuplicate(rule: PolicyRule, excluding entryID: UUID? = nil) -> Bool {
        guard let identity = rule.semanticIdentity else {
            return false
        }
        return entries.contains { entry in
            entry.id != entryID && entry.rule.semanticIdentity == identity
        }
    }

    private func refreshGenerationState() {
        guard !entries.isEmpty || alwaysAllowManagedApps else {
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
                alwaysAllowManagedApps: alwaysAllowManagedApps,
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
