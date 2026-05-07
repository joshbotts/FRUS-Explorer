// Views/PromptProfilesView.swift
// Full prompt profile management UI: list, editor, live preview.

import SwiftUI

// MARK: - PromptProfilesView

struct PromptProfilesView: View {
    @Environment(AppStore.self) private var store: AppStore
    @Environment(PromptProfileStore.self) private var profileStore: PromptProfileStore
    @Environment(SummaryStore.self) private var summaryStore: SummaryStore

    @State private var selectedProfileID: UUID?
    @State private var confirmingDelete: SummaryPromptProfile?
    @State private var confirmingPurge: SummaryStore.ProfileStat?

    private var selectedProfile: SummaryPromptProfile? {
        guard let id = selectedProfileID else { return nil }
        return profileStore.profiles.first(where: { $0.id == id })
    }

    private var deleteDialogTitle: String {
        let name = confirmingDelete?.name ?? ""
        return "Delete \u{201C}\(name)\u{201D}?"
    }

    var body: some View {
        NavigationSplitView {
            profileSidebar
#if os(macOS)
                .navigationSplitViewColumnWidth(min: 210, ideal: 230, max: 270)
#endif
        } detail: {
            if let profile = selectedProfile {
                ProfileDetailView(profile: profile)
            } else {
                emptyDetail
            }
        }
        .navigationTitle("Summarisation Profiles")
        .confirmationDialog(
            deleteDialogTitle,
            isPresented: Binding(
                get: { confirmingDelete != nil },
                set: { if !$0 { confirmingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let p = confirmingDelete { profileStore.delete(p) }
                confirmingDelete = nil
            }
            Button("Cancel", role: .cancel) { confirmingDelete = nil }
        } message: {
            Text("This action cannot be undone.")
        }
        .confirmationDialog(
            "Purge summaries for \u{201C}\(confirmingPurge?.profileName ?? "")\u{201D}?",
            isPresented: Binding(
                get: { confirmingPurge != nil },
                set: { if !$0 { confirmingPurge = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Purge \(confirmingPurge?.count ?? 0) Summaries", role: .destructive) {
                if let stat = confirmingPurge {
                    summaryStore.purge(profileID: stat.profileID)
                    if stat.profileID == profileStore.activeProfileID {
                        store.clearSummaryCache()
                    }
                }
                confirmingPurge = nil
            }
            Button("Cancel", role: .cancel) { confirmingPurge = nil }
        } message: {
            Text("Stored summaries for this profile will be removed. They can be regenerated on demand.")
        }
    }

    // MARK: - Sidebar

    private var profileSidebar: some View {
        List(selection: $selectedProfileID) {
            // Built-in profiles
            Section("Built-in") {
                ForEach(profileStore.profiles.filter(\.isBuiltIn)) { profile in
                    ProfileSidebarRow(profile: profile)
                        .tag(profile.id)
                        .contextMenu {
                            Button("Duplicate") {
                                let copy = profileStore.duplicate(profile)
                                selectedProfileID = copy.id
                            }
                            Button("Set as Active") { profileStore.activate(profile) }
                        }
                }
            }

            // User profiles
            let userProfiles = profileStore.profiles.filter { !$0.isBuiltIn }
            if !userProfiles.isEmpty {
                Section("My Profiles") {
                    ForEach(userProfiles) { profile in
                        ProfileSidebarRow(profile: profile)
                            .tag(profile.id)
                            .contextMenu {
                                Button("Set as Active") { profileStore.activate(profile) }
                                Button("Duplicate") {
                                    let copy = profileStore.duplicate(profile)
                                    selectedProfileID = copy.id
                                }
                                Divider()
                                Button("Delete", role: .destructive) {
                                    confirmingDelete = profile
                                }
                            }
                    }
                }
            }

            // Stored summaries — per-profile counts with purge action
            let stats = summaryStore.profileStats
            if !stats.isEmpty {
                Section("Stored Summaries") {
                    ForEach(stats) { stat in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(stat.profileName)
                                    .font(.system(.callout))
                                    .lineLimit(1)
                                let plural = stat.count == 1 ? "" : "s"
                                Text("\(stat.count) summary\(plural)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Purge") { confirmingPurge = stat }
                                .buttonStyle(.borderless)
                                .font(.system(size: 11))
                                .foregroundStyle(.red)
                                .controlSize(.small)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    let p = profileStore.create()
                    selectedProfileID = p.id
                } label: {
                    Image(systemName: "plus")
                }
                .help("New profile")
            }
        }
    }

    // MARK: - Empty detail

    private var emptyDetail: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.badge.checkmark")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text("Select a profile to view or edit it, or tap + to create a new one.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
            activeProfileBadge
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var activeProfileBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
            Text("Active: \(profileStore.activeProfile.name)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.quinary, in: Capsule())
    }
}

// MARK: - ProfileSidebarRow

private struct ProfileSidebarRow: View {
    @Environment(PromptProfileStore.self) private var profileStore: PromptProfileStore
    let profile: SummaryPromptProfile

    private var isActive: Bool { profileStore.activeProfileID == profile.id }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(profile.name)
                        .font(.system(.callout))
                        .fontWeight(isActive ? .semibold : .regular)
                        .lineLimit(1)
                    if profile.isBuiltIn {
                        Text("built-in")
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.quinary, in: Capsule())
                    }
                }
                Text(profile.outputFormat.displayName)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - ProfileDetailView

struct ProfileDetailView: View {
    @Environment(AppStore.self) private var store: AppStore
    @Environment(PromptProfileStore.self) private var profileStore: PromptProfileStore

    let profile: SummaryPromptProfile

    // Local editable copy
    @State private var draft: SummaryPromptProfile = SummaryPromptProfile.defaultProfile
    @State private var isDirty = false
    @State private var showingPreview = false

    private var isActive: Bool { profileStore.activeProfileID == profile.id }
    private var canEdit: Bool { !profile.isBuiltIn }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // ── Header strip ──────────────────────────────────────────
                profileHeader

                Divider()

                // ── Fields ───────────────────────────────────────────────
                profileFields

                Divider()

                // ── Live preview ─────────────────────────────────────────
                livePreviewSection

                Spacer(minLength: 32)
            }
            .padding(24)
        }
        .toolbar { toolbarItems }
        .onAppear { draft = profile; isDirty = false }
        .onChange(of: profile.id) { _, _ in draft = profile; isDirty = false }
    }

    // MARK: - Header strip

    private var profileHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if canEdit {
                    TextField("Profile name", text: $draft.name)
                        .font(.system(.title2, weight: .bold))
                        .textFieldStyle(.plain)
                        .onChange(of: draft.name) { _, _ in isDirty = true }
                } else {
                    Text(profile.name)
                        .font(.system(.title2, weight: .bold))
                }

                HStack(spacing: 8) {
                    Label(draft.outputFormat.displayName, systemImage: "text.alignleft")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if isActive {
                        Label("Active", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
            Spacer()

            if !isActive {
                Button("Set as Active") {
                    save()
                    profileStore.activate(profile.isBuiltIn ? profile : draft)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
    }

    // MARK: - Fields

    private var profileFields: some View {
        VStack(alignment: .leading, spacing: 20) {

            // Research description
            fieldBlock(
                label: "Research Goal",
                help: "Describe your research goal in plain English. This is shown in the UI to help you pick the right profile — it is not sent to the model."
            ) {
                if canEdit {
                    TextEditor(text: $draft.researchDescription)
                        .font(.system(.callout, design: .serif))
                        .frame(minHeight: 64, maxHeight: 100)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                        .onChange(of: draft.researchDescription) { _, _ in isDirty = true }
                } else {
                    Text(profile.researchDescription)
                        .font(.system(.callout, design: .serif))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Emphasis instruction — the core prompt text
            fieldBlock(
                label: "Emphasis Instruction",
                help: "This text is injected directly into the model prompt. Write in second-person imperative addressed to the model. Be specific about what to emphasise, what to note, and what to omit. Avoid vague instructions like "focus on important things"."
            ) {
                if canEdit {
                    TextEditor(text: $draft.emphasisInstruction)
                        .font(.system(.callout, design: .serif))
                        .frame(minHeight: 100, maxHeight: 180)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                        .onChange(of: draft.emphasisInstruction) { _, _ in isDirty = true }
                } else {
                    Text(profile.emphasisInstruction)
                        .font(.system(.callout, design: .serif))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(10)
                        .background(.quinary, in: RoundedRectangle(cornerRadius: 6))
                }
            }

            // Output format picker
            fieldBlock(
                label: "Output Format",
                help: "Controls how the model structures its response."
            ) {
                if canEdit {
                    Picker("", selection: $draft.outputFormat) {
                        ForEach(SummaryOutputFormat.allCases, id: \.self) { fmt in
                            Text(fmt.displayName).tag(fmt)
                        }
                    }
#if os(macOS)
                    .pickerStyle(.radioGroup)
#else
                    .pickerStyle(.segmented)
#endif
                    .onChange(of: draft.outputFormat) { _, _ in isDirty = true }
                    Text(draft.outputFormat.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(profile.outputFormat.displayName)
                        .foregroundStyle(.secondary)
                    Text(profile.outputFormat.description)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            // Focus label (only relevant for .structuredFields)
            if draft.outputFormat == .structuredFields {
                fieldBlock(
                    label: "Custom Field Label",
                    help: "The label for the research-focus field in the structured output, e.g. "Bureaucratic actors" or "Intelligence dimension"."
                ) {
                    if canEdit {
                        TextField("e.g. Bureaucratic actors", text: $draft.focusLabel)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 260)
                            .onChange(of: draft.focusLabel) { _, _ in isDirty = true }
                    } else {
                        Text(profile.focusLabel.isEmpty ? "(none)" : profile.focusLabel)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Live preview section

    private var livePreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Live Preview", systemImage: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.purple)
                Spacer()
                Text("Uses the currently selected document")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Text("Preview a summary of the document currently open in the Explorer using this profile's settings.")
                .font(.caption)
                .foregroundStyle(.secondary)

            PreviewPane(profileDraft: draft)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(.purple.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.purple.opacity(0.18)))
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        if canEdit {
            ToolbarItemGroup(placement: .primaryAction) {
                if isDirty {
                    Button("Save") { save() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut("s", modifiers: .command)
                }
                if !profile.isBuiltIn {
                    Button {
                        // Duplicate so we preserve the original
                        _ = profileStore.duplicate(profile)
                    } label: {
                        Image(systemName: "plus.square.on.square")
                    }
                    .help("Duplicate this profile")
                }
            }
        } else {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    let copy = profileStore.duplicate(profile)
                    // Post notification to switch selection to the copy —
                    // handled by PromptProfilesView via the selection binding
                    NotificationCenter.default.post(
                        name: .didDuplicateProfile,
                        object: copy.id
                    )
                } label: {
                    Label("Duplicate & Edit", systemImage: "square.and.pencil")
                }
                .help("Create an editable copy of this built-in profile")
            }
        }
    }

    // MARK: - Helpers

    private func save() {
        guard canEdit else { return }
        profileStore.update(draft)
        isDirty = false
    }

    @ViewBuilder
    private func fieldBlock<Content: View>(
        label: String,
        help: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Button {
                    // Use a popover tooltip (tooltip is not available on macOS)
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help(help)
            }
            content()
        }
    }
}

// MARK: - PreviewPane

/// Runs a live test summary against the document currently selected in AppStore,
/// using the draft profile settings — without requiring the user to save first.
private struct PreviewPane: View {
    @Environment(AppStore.self) private var store: AppStore
    let profileDraft: SummaryPromptProfile

    @State private var previewState: PreviewRunState = .idle

    enum PreviewRunState {
        case idle
        case running
        case result(String)
        case failed(String)
        case noDocument
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch previewState {
            case .idle:
                Button("Run Preview Summary") { Task { await runPreview() } }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

            case .running:
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7)
                    Text("Generating…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

            case .result(let text):
                Text(text)
                    .font(.system(.callout, design: .serif))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Regenerate") { Task { await runPreview() } }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }

            case .failed(let msg):
                Label(msg, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Button("Retry") { Task { await runPreview() } }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

            case .noDocument:
                Text("No document is currently selected in the Explorer. Open a volume and select a document, then run the preview.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func runPreview() async {
        // Find the currently-selected division
        guard let volID = store.selectedVolumeID,
              let vol = store.loadedVolumes[volID],
              let nodeID = store.selectedNodeID else {
            previewState = .noDocument
            return
        }
        let prefix = volID + "__"
        let divID = nodeID.hasPrefix(prefix) ? String(nodeID.dropFirst(prefix.count)) : nodeID
        let t = vol.volume.text
        guard let div = t.body.divisions.findDivision(id: divID)
            ?? (t.front?.divisions ?? []).findDivision(id: divID)
            ?? (t.back?.divisions ?? []).findDivision(id: divID)
        else {
            previewState = .noDocument
            return
        }

        previewState = .running
        let result = await store.summariser.summarise(
            text: div.bodyText,
            title: div.title ?? "",
            profile: profileDraft
        )
        switch result {
        case .ready(let text): previewState = .result(text)
        case .failed(let msg): previewState = .failed(msg)
        case .generating:      previewState = .failed("Unexpected state.")
        }
    }

}

// MARK: - Notification

extension Notification.Name {
    static let didDuplicateProfile = Notification.Name("FRUSExplorer.didDuplicateProfile")
}
