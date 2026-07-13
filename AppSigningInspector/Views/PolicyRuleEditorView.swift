import SwiftUI

struct PolicyRuleEditorView: View {
    let entry: PolicyEntry
    let save: (PolicyRule, PolicyAction) -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var ruleType: PolicyRuleType
    @State private var action: PolicyAction
    @State private var usesPathPrefix: Bool
    @State private var pathPrefix: String
    @State private var errorMessage: String?

    init(entry: PolicyEntry, save: @escaping (PolicyRule, PolicyAction) -> Bool) {
        self.entry = entry
        self.save = save
        _ruleType = State(initialValue: entry.rule.type)
        _action = State(initialValue: entry.action)
        _usesPathPrefix = State(initialValue: entry.pathPrefix != nil)
        _pathPrefix = State(initialValue: entry.pathPrefix ?? entry.applicationURL?.path ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Edit Policy Rule")
                .font(.title2)
                .fontWeight(.semibold)

            if canChangeRuleScope {
                Picker("Rule Scope", selection: $ruleType) {
                    Text("Specific Application").tag(PolicyRuleType.specificApplication)
                    Text("Developer Team").tag(PolicyRuleType.developerTeam)
                }
                .onChange(of: ruleType) { _, newValue in
                    if newValue == .developerTeam {
                        action = .allow
                    }
                }
            } else {
                LabeledContent("Rule Scope", value: ruleType.displayValue)
            }

            if ruleType == .specificApplication {
                Picker("Action", selection: $action) {
                    ForEach(PolicyAction.allCases, id: \.self) { policyAction in
                        Text(policyAction.displayValue).tag(policyAction)
                    }
                }
                .pickerStyle(.segmented)

                LabeledContent("Signing ID", value: entry.applicationSigningIdentifier ?? "Unavailable")
                LabeledContent("Team ID", value: entry.applicationTeamIdentifier ?? "Unavailable")

                Toggle("Restrict by Path Prefix", isOn: $usesPathPrefix)
                if usesPathPrefix {
                    TextField("Absolute path", text: $pathPrefix)
                    Text("Restricts matching to binaries under this absolute path. The path does not need to remain present for export.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if ruleType == .developerTeam {
                LabeledContent("Destination", value: "AllowedBinaries")
                LabeledContent("Team ID", value: entry.applicationTeamIdentifier ?? entry.teamIdentifier ?? "Unavailable")
                if let signingAuthority = entry.signingAuthority {
                    LabeledContent("Signing Authority", value: signingAuthority)
                }
                Text("Allow all binaries signed by \(developerTeamDisplayValue)")
                    .font(.callout)
                Text("This rule may allow every binary signed with this Team ID, not only the selected application.")
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                LabeledContent("Destination", value: "AllowedBinaries")
                LabeledContent("Team ID", value: PolicyRule.appleTeamIdentifier)
                Text("This rule broadly allows Apple binaries according to Apple's documented matching behavior.")
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.callout)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Save") { saveRule() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480)
    }

    private var canChangeRuleScope: Bool {
        entry.applicationURL != nil
            && entry.applicationSigningIdentifier != nil
            && entry.applicationTeamIdentifier != nil
            && entry.rule.type != .appleBinaries
    }

    private var developerTeamDisplayValue: String {
        entry.applicationTeamIdentifier ?? entry.teamIdentifier ?? "this Team ID"
    }

    private func saveRule() {
        let rule: PolicyRule
        switch ruleType {
        case .specificApplication:
            rule = .specificApplication(
                signingIdentifier: entry.applicationSigningIdentifier,
                teamIdentifier: entry.applicationTeamIdentifier,
                pathPrefix: usesPathPrefix ? pathPrefix : nil
            )
        case .developerTeam:
            rule = .developerTeam(teamIdentifier: entry.applicationTeamIdentifier ?? entry.teamIdentifier ?? "")
        case .appleBinaries:
            rule = .appleBinaries
        }

        if save(rule, action) {
            dismiss()
        } else {
            errorMessage = "This rule duplicates an existing policy entry."
        }
    }
}

struct DeveloperTeamRuleSheet: View {
    let addRule: (String) -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var teamIdentifier = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Developer Team Rule")
                .font(.title2)
                .fontWeight(.semibold)

            TextField("Team ID", text: $teamIdentifier)

            Text("Enter an Apple signing Team ID or the documented *APPLE* special token. Company names and undocumented wildcard tokens are not converted.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Label(
                "This rule may allow every binary signed with the Team ID.",
                systemImage: "exclamationmark.triangle"
            )
            .font(.callout)

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Add Rule") { submit() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    private func submit() {
        let trimmed = teamIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Enter an Apple signing Team ID."
            return
        }
        guard !trimmed.contains("*") || trimmed == PolicyRule.appleTeamIdentifier else {
            errorMessage = "Only the documented *APPLE* special Team ID token is supported."
            return
        }
        if addRule(trimmed) {
            dismiss()
        } else {
            errorMessage = "This Team ID rule is already present or invalid."
        }
    }
}
