// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - ConnectionsView

/// Settings → System → **Connections** — the two outside services in one place (S-4a).
///
/// ## What this replaces
/// Two unrelated-looking root rows, "NARA API" and "Zotero", each with its own layout, its own
/// vocabulary for the same ideas, and its own answer to "is this working?" — which on NARA you
/// could only get by reading to the middle of the screen.
///
/// Both are the same kind of thing: an account somewhere else that this app talks to on your
/// behalf. So both get one grammar — a card that answers *does it work* before it says anything
/// else, and an editor behind it in a fixed anatomy: **status → About → Account**.
///
/// Version history:
///   1.0 — S-4a: initial implementation
struct ConnectionsView: View {

    @State private var naraHasKey = false
    @State private var naraCalls = 0
    @State private var zoteroConnected = false
    @State private var zoteroUsername: String?

    /// Which editor is open. macOS presents them as sheets (a Settings window has no navigation
    /// chrome); iOS pushes.
    @State private var editor: ConnectionService? = nil

    /// The two services, so the destination can be written once.
    enum ConnectionService: String, Identifiable, CaseIterable {
        case naraCatalog, zotero
        var id: String { rawValue }
    }

    var body: some View {
        Form {
            Section {
                serviceRow(.naraCatalog)
                serviceRow(.zotero)
            } header: {
                Text(String(localized: "settings.connections.header", defaultValue: "Services"))
            } footer: {
                Text(String(localized: "settings.connections.footer",
                            defaultValue: "Both keys are held in your keychain and travel with iCloud Keychain to your other devices. Neither service is required — the app works without them."))
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        .navigationTitle(String(localized: "settings.pane.connections", defaultValue: "Connections"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await refresh() }
        #if os(macOS)
        .sheet(item: $editor) { service in
            editorSheet(service)
        }
        #endif
    }

    // MARK: - Rows

    @ViewBuilder
    private func serviceRow(_ service: ConnectionService) -> some View {
        #if os(macOS)
        Button {
            editor = service
        } label: {
            statusRow(service)
        }
        .buttonStyle(.plain)
        #else
        NavigationLink {
            editorBody(service)
                .onDisappear { Task { await refresh() } }
        } label: {
            statusRow(service)
        }
        #endif
    }

    /// The card: name, then whether it works, then what it is for.
    @ViewBuilder
    private func statusRow(_ service: ConnectionService) -> some View {
        let connected = isConnected(service)
        HStack {
            SettingsStatusRow(
                label: name(service),
                detail: statusDetail(service),
                state: connected ? .ok : .warning
            )
            Spacer(minLength: 8)
            // iOS: the NavigationLink draws its own chevron, so adding one here gave every row
            // two (caught on the simulator, not by the compiler). macOS presents a sheet from a
            // plain Button and has no chevron of its own, so it needs this one.
            #if os(macOS)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
            #endif
        }
        .contentShape(Rectangle())
    }

    private func name(_ service: ConnectionService) -> String {
        switch service {
        case .naraCatalog:
            return String(localized: "settings.connections.nara.name", defaultValue: "NARA Catalog")
        case .zotero:
            return String(localized: "settings.connections.zotero.name", defaultValue: "Zotero")
        }
    }

    private func isConnected(_ service: ConnectionService) -> Bool {
        switch service {
        case .naraCatalog: return naraHasKey
        case .zotero:      return zoteroConnected
        }
    }

    /// Status first, purpose second — one line that answers "does it work?" then "for what?".
    private func statusDetail(_ service: ConnectionService) -> String {
        switch service {
        case .naraCatalog:
            return naraHasKey
                ? String(localized: "settings.connections.nara.on",
                         defaultValue: "Key stored — Source Explorer can search archival records.")
                : String(localized: "settings.connections.nara.off",
                         defaultValue: "No key yet. Source Explorer needs one to search lot files and Presidential Library records.")
        case .zotero:
            if zoteroConnected {
                let who = zoteroUsername ?? String(localized: "settings.connections.zotero.yourLibrary",
                                                   defaultValue: "your library")
                return String(localized: "settings.connections.zotero.on",
                              defaultValue: "Connected as \(who) — documents, tags and notes can be sent across.")
            }
            return String(localized: "settings.connections.zotero.off",
                          defaultValue: "Not connected. Connect to send documents, tags and notes to your Zotero library.")
        }
    }

    // MARK: - Editors

    @ViewBuilder
    private func editorBody(_ service: ConnectionService) -> some View {
        switch service {
        case .naraCatalog: NARACatalogConnectionView()
        case .zotero:      ZoteroConnectionView()
        }
    }

    #if os(macOS)
    /// macOS presents the editor as a sheet with its own Done button — the Settings window carries
    /// no navigation chrome of its own to push into.
    @ViewBuilder
    private func editorSheet(_ service: ConnectionService) -> some View {
        VStack(spacing: 0) {
            editorBody(service)
                .formStyle(.grouped)
            Divider()
            HStack {
                Spacer()
                Button(String(localized: "settings.connections.done", defaultValue: "Done")) {
                    editor = nil
                    Task { await refresh() }
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 480, minHeight: 420)
    }
    #endif

    // MARK: - State

    private func refresh() async {
        naraHasKey = await KeychainStore.shared.hasAPIKey()
        naraCalls = NARAAPIKeyStore.shared.callCountLast30Days
        zoteroConnected = ZoteroAccountStore.shared.isConnected
        zoteroUsername = ZoteroAccountStore.shared.username
    }
}

// MARK: - NARACatalogConnectionView

/// The NARA Catalog editor, in the shared connection anatomy (S-4a).
///
/// ## What changed
/// - **Status first.** Whether a key is stored used to be a sentence in the middle of the second
///   section; it now heads the screen.
/// - **The key field is behind "Replace Key…".** A stored key does not need an empty paste field
///   sitting under it inviting one.
/// - **Feedback is inline.** The old result lived in its own `Section` that appeared and vanished,
///   shifting everything below it. It is now a row beside the action.
/// - **The usage row answers the reader's question.** "Limit not enforced by FRUS Explorer" told
///   them about the app's implementation; what they want to know is whether they are near NARA's
///   own limit, which this app cannot see — so it says that instead.
/// - **One name.** The row said "NARA API", the screen said "NARA Catalog API Key", the mock said
///   "NARA Catalog". It is "NARA Catalog" everywhere now.
///
/// Version history:
///   1.0 — S-4a: initial implementation, replacing `NARAKeyView` and the macOS `SettingsNARAPane`
struct NARACatalogConnectionView: View {

    @State private var hasExistingKey = false
    @State private var callCount = 0
    /// Non-nil while the key field is showing.
    @State private var keyText: String? = nil
    @State private var isSaving = false
    @State private var feedback: Feedback? = nil
    @State private var showRemoveConfirmation = false

    private let keychainStore = KeychainStore.shared

    /// Inline result of the last action.
    private enum Feedback: Equatable {
        case saved, removed, failed(String)
    }

    private let helpURL = URL(string: "https://www.archives.gov/research/catalog/help/api")

    var body: some View {
        Form {
            Section {
                SettingsStatusRow(
                    label: String(localized: "settings.connections.nara.name",
                                  defaultValue: "NARA Catalog"),
                    detail: hasExistingKey
                        ? String(localized: "settings.connections.nara.status.stored",
                                 defaultValue: "Key stored")
                        : String(localized: "settings.connections.nara.status.none",
                                 defaultValue: "No key stored"),
                    state: hasExistingKey ? .ok : .warning
                )
            } footer: {
                Text(String(localized: "settings.connections.nara.status.footer",
                            defaultValue: "Held in your keychain and synced via iCloud Keychain to your other devices."))
            }

            Section {
                Text(String(localized: "settings.connections.nara.about",
                            defaultValue: "A free key from the National Archives Catalog. Source Explorer needs it to search lot files and Presidential Library records; everything else in the app works without it."))
                    .foregroundStyle(.secondary)
                if let helpURL {
                    Link(destination: helpURL) {
                        HStack {
                            Label(String(localized: "settings.connections.nara.getKey",
                                         defaultValue: "Get a free key from NARA"), systemImage: "key")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityAddTraits(.isLink)
                }
            } header: {
                Text(String(localized: "settings.connections.about.header", defaultValue: "About"))
            }

            accountSection
        }
        .navigationTitle(String(localized: "settings.connections.nara.name",
                                defaultValue: "NARA Catalog"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            hasExistingKey = await keychainStore.hasAPIKey()
            callCount = NARAAPIKeyStore.shared.callCountLast30Days
        }
        .confirmationDialog(
            String(localized: "settings.connections.nara.remove.title",
                   defaultValue: "Remove the stored key?"),
            isPresented: $showRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "settings.connections.remove", defaultValue: "Remove"),
                   role: .destructive) { removeKey() }
            Button(String(localized: "settings.connections.cancel", defaultValue: "Cancel"),
                   role: .cancel) {}
        } message: {
            Text(String(localized: "settings.connections.nara.remove.message",
                        defaultValue: "Source Explorer's archival search stops working on this device and every device sharing your iCloud Keychain. Nothing you've already saved is affected."))
        }
    }

    // MARK: Account

    @ViewBuilder
    private var accountSection: some View {
        Section {
            SettingsNavRow(
                label: String(localized: "settings.connections.nara.usage",
                              defaultValue: "Requests (30 days)"),
                value: "\(callCount)"
            )

            if let text = keyText {
                SecureField(
                    String(localized: "settings.connections.nara.field",
                           defaultValue: "Paste your key"),
                    text: Binding(get: { text }, set: { keyText = $0 })
                )
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.asciiCapable)
                #endif
                .accessibilityLabel(String(localized: "settings.connections.nara.field.a11y",
                                           defaultValue: "NARA Catalog key"))

                HStack {
                    Button(String(localized: "settings.connections.save", defaultValue: "Save")) {
                        save()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                    Spacer()
                    Button(String(localized: "settings.connections.cancel", defaultValue: "Cancel")) {
                        keyText = nil
                        feedback = nil
                    }
                    if isSaving { ProgressView().controlSize(.small) }
                    inlineFeedback
                }
            } else {
                Button {
                    keyText = ""
                    feedback = nil
                } label: {
                    HStack {
                        Text(hasExistingKey
                             ? String(localized: "settings.connections.nara.replace",
                                      defaultValue: "Replace Key…")
                             : String(localized: "settings.connections.nara.add",
                                      defaultValue: "Add Key…"))
                        Spacer()
                        inlineFeedback
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)

                if hasExistingKey {
                    Button(role: .destructive) {
                        showRemoveConfirmation = true
                    } label: {
                        Text(String(localized: "settings.connections.nara.removeKey",
                                    defaultValue: "Remove Key"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }
            }
        } header: {
            Text(String(localized: "settings.connections.account.header", defaultValue: "Account"))
        } footer: {
            Text(usageFooter)
        }
    }

    /// What the reader wants to know about the count, not what the developer knows.
    private var usageFooter: String {
        let base = String(localized: "settings.connections.nara.usage.footer",
                          defaultValue: "Requests this app has made with your key in the last 30 days. NARA sets the actual rate limit and this app can't see it, so treat this as your own record rather than a quota.")
        guard hasExistingKey else { return base }
        return base + " " + String(localized: "settings.connections.nara.usage.footer.remove",
                                   defaultValue: "Removing the key hides Source Explorer's archival search.")
    }

    /// Result of the last action, shown beside the control rather than in a section that appears
    /// and vanishes and shifts the rest of the screen.
    @ViewBuilder
    private var inlineFeedback: some View {
        switch feedback {
        case .saved:
            Label(String(localized: "settings.connections.saved", defaultValue: "Saved"),
                  systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .removed:
            Label(String(localized: "settings.connections.removed", defaultValue: "Removed"),
                  systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        case nil:
            EmptyView()
        }
    }

    // MARK: Actions

    private func save() {
        guard let trimmed = keyText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return }
        isSaving = true
        feedback = nil
        Task {
            do {
                try await keychainStore.setNARACatalogAPIKey(trimmed)
                keyText = nil
                hasExistingKey = true
                feedback = .saved
            } catch {
                feedback = .failed(error.localizedDescription)
            }
            isSaving = false
        }
    }

    private func removeKey() {
        Task {
            do {
                try await keychainStore.deleteNARACatalogAPIKey()
                keyText = nil
                hasExistingKey = false
                feedback = .removed
            } catch {
                feedback = .failed(error.localizedDescription)
            }
        }
    }
}

// MARK: - ZoteroConnectionView

/// The Zotero editor, in the shared connection anatomy (S-4a).
///
/// Same shape as NARA — status, then About, then Account — so the two integrations stop being two
/// unrelated screens. The connect flow is unchanged; the key is verified against the Zotero API
/// before it is stored, which is why a failure appears beside the button rather than as a footer.
///
/// Version history:
///   1.0 — Zotero Web API integration (Phase 2), as `ZoteroIntegrationView`
///   1.1 — S-4a: adopts the shared connection anatomy; renamed
struct ZoteroConnectionView: View {

    @State private var keyText = ""
    @State private var isConnecting = false
    @State private var connectedUsername: String?
    @State private var isConnected = false
    @State private var errorMessage: String?
    @State private var showDisconnectConfirmation = false

    private let store = ZoteroAccountStore.shared
    private let client = ZoteroAPIClient()

    /// Deep link that pre-fills a new key with library + notes + write access.
    private let getKeyURL = URL(string:
        "https://www.zotero.org/settings/keys/new?name=FRUS%20Explorer&library_access=1&notes_access=1&write_access=1")

    var body: some View {
        Form {
            Section {
                SettingsStatusRow(
                    label: String(localized: "settings.connections.zotero.name", defaultValue: "Zotero"),
                    detail: isConnected
                        ? String(localized: "settings.connections.zotero.status.on",
                                 defaultValue: "Connected as \(connectedUsername ?? String(localized: "settings.connections.zotero.yourLibrary", defaultValue: "your library"))")
                        : String(localized: "settings.connections.zotero.status.off",
                                 defaultValue: "Not connected"),
                    state: isConnected ? .ok : .warning
                )
            } footer: {
                Text(String(localized: "settings.connections.zotero.status.footer",
                            defaultValue: "Held in your keychain and synced via iCloud Keychain to your other devices."))
            }

            Section {
                Text(String(localized: "settings.zotero.about.body",
                            defaultValue: "Send FRUS documents to your Zotero library with your tags and research notes attached. Zotero syncs them to all your devices, including the Zotero iOS app. This is the only way to get FRUS annotations into Zotero on iPhone and iPad."))
                    .foregroundStyle(.secondary)
                if !isConnected, let getKeyURL {
                    Link(destination: getKeyURL) {
                        HStack {
                            Label(String(localized: "settings.zotero.getKey",
                                         defaultValue: "Create a Zotero API key"), systemImage: "key")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityAddTraits(.isLink)
                }
            } header: {
                Text(String(localized: "settings.connections.about.header", defaultValue: "About"))
            }

            accountSection
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        .navigationTitle(String(localized: "settings.connections.zotero.name", defaultValue: "Zotero"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { refresh() }
        .confirmationDialog(
            String(localized: "settings.connections.zotero.disconnect.title",
                   defaultValue: "Disconnect from Zotero?"),
            isPresented: $showDisconnectConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "settings.zotero.disconnect", defaultValue: "Disconnect"),
                   role: .destructive) {
                store.disconnect()
                refresh()
            }
            Button(String(localized: "settings.connections.cancel", defaultValue: "Cancel"),
                   role: .cancel) {}
        } message: {
            Text(String(localized: "settings.connections.zotero.disconnect.message",
                        defaultValue: "\"Send to Zotero Library…\" disappears from collections and documents. Anything already sent stays in your Zotero library."))
        }
    }

    @ViewBuilder
    private var accountSection: some View {
        Section {
            if isConnected {
                SettingsNavRow(
                    label: String(localized: "settings.zotero.connectedAs", defaultValue: "Connected as"),
                    value: connectedUsername ?? String(localized: "settings.zotero.unknownUser",
                                                       defaultValue: "your library")
                )
                Button(role: .destructive) {
                    showDisconnectConfirmation = true
                } label: {
                    Text(String(localized: "settings.zotero.disconnect", defaultValue: "Disconnect"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            } else {
                SecureField(
                    String(localized: "settings.zotero.field.placeholder",
                           defaultValue: "Paste your Zotero API key…"),
                    text: $keyText
                )
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.asciiCapable)
                #endif
                HStack {
                    Button(String(localized: "settings.zotero.connect", defaultValue: "Connect")) {
                        connect()
                    }
                    .disabled(keyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isConnecting)
                    Spacer()
                    if isConnecting {
                        ProgressView().controlSize(.small)
                    } else if let errorMessage {
                        // Beside the action, not in a footer that shifts the layout under it.
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
        } header: {
            Text(String(localized: "settings.connections.account.header", defaultValue: "Account"))
        } footer: {
            Text(isConnected
                 ? String(localized: "settings.connections.zotero.account.footer.on",
                          defaultValue: "\"Send to Zotero Library…\" appears on collections and documents while you're connected.")
                 : String(localized: "settings.connections.zotero.account.footer.off",
                          defaultValue: "The key is checked with Zotero before it's stored, so a bad paste is caught here rather than the first time you try to send something."))
        }
    }

    private func refresh() {
        isConnected = store.isConnected
        connectedUsername = store.username
    }

    private func connect() {
        let key = keyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        isConnecting = true
        errorMessage = nil
        Task {
            do {
                let info = try await client.resolveAccount(key: key)
                store.storeKey(key)
                store.setAccount(userID: info.userID, username: info.username)
                keyText = ""
                refresh()
            } catch {
                errorMessage = (error as? ZoteroAPIError)?.errorDescription ?? error.localizedDescription
            }
            isConnecting = false
        }
    }
}
