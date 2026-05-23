// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

#if os(macOS)

import SwiftUI

// MARK: - MacSourceExplorerView

/// macOS Source Explorer panel.
///
/// Presents parsed FRUS source note provenance in a two-column sheet:
/// the left column shows the raw note and structured provenance fields; the right
/// column shows the NARA Catalog result (or the no-key / loading / error state).
///
/// Mirroring `SourceExplorerView` (the iOS baseline), this view parses the source
/// note on appear, checks for a stored NARA API key, and fetches a catalog record
/// for provenance types that require one.
///
/// ## macOS adaptations
/// - Two-column `HSplitView` instead of a single-column `Form`.
/// - `GroupBox` panels replace `Form.Section` for a native macOS appearance.
/// - `SettingsLink` replaces the iOS `NavigationLink` for the no-API-key prompt,
///   opening the app's Settings window directly.
/// - Minimum window size 640 × 380 pt.
///
/// Version history:
///   1.0 — macOS Source Explorer implementation (adapted from iOS SourceExplorerView)
///   1.1 — Session 94: removed NavigationStack wrapper and Done toolbar button; the Window
///          scene provides its own titlebar and × close button — redundant navigation chrome
///          caused a spurious nav-bar-height gap at the top of the split view
struct MacSourceExplorerView: View {

    // MARK: - Input

    /// Raw plain-text source note extracted from the TEI document.
    let rawSourceNote: String

    // MARK: - Dependencies

    private let client = NARACatalogClient()

    // MARK: - State

    @State private var parsed: ParsedSourceNote? = nil
    @State private var catalogResult: NARACatalogResult? = nil
    @State private var isLoading = false
    @State private var loadError: String? = nil
    @State private var hasAPIKey: Bool = false

    @Environment(\.openURL)  private var openURL

    // MARK: - Body

    var body: some View {
        HSplitView {
            leftColumn
                .frame(minWidth: 240, idealWidth: 260, maxWidth: 320)

            rightColumn
                .frame(minWidth: 340)
        }
        .task { await load() }
        .frame(minWidth: 640, minHeight: 380)
    }

    // MARK: - Left Column

    private var leftColumn: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 14) {
                GroupBox(String(localized: "source.explorer.rawNote.header",
                                defaultValue: "Source Note")) {
                    Text(rawSourceNote)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let parsed {
                    provenanceBox(for: parsed)
                }
            }
            .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Right Column

    private var rightColumn: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 14) {
                if let parsed {
                    naraBox(for: parsed)
                } else {
                    // Parsing in progress
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(40)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Provenance Box

    @ViewBuilder
    private func provenanceBox(for parsed: ParsedSourceNote) -> some View {
        GroupBox(String(localized: "source.explorer.provenance.header",
                        defaultValue: "Provenance")) {
            VStack(alignment: .leading, spacing: 10) {
                switch parsed {
                case .centralFiles(let rg, let fileId):
                    provenanceRow(label: String(localized: "source.explorer.centralFiles.type",
                                               defaultValue: "Type"),
                                  value: String(localized: "source.explorer.centralFiles.typeValue",
                                               defaultValue: "State Dept. Central Files (\(rg))"))
                    if let fileId {
                        provenanceRow(label: String(localized: "source.explorer.centralFiles.identifier",
                                                   defaultValue: "File Identifier"),
                                      value: fileId)
                    }

                case .lotFile(let lot, let fileId):
                    provenanceRow(label: String(localized: "source.explorer.lotFile.type",
                                               defaultValue: "Type"),
                                  value: String(localized: "source.explorer.lotFile.typeValue",
                                               defaultValue: "State Dept. Lot File"))
                    provenanceRow(label: String(localized: "source.explorer.lotFile.lot",
                                               defaultValue: "Lot Number"),
                                  value: lot)
                    if let fileId {
                        provenanceRow(label: String(localized: "source.explorer.lotFile.fileId",
                                                   defaultValue: "File Identifier"),
                                      value: fileId)
                    }

                case .presidentialLibrary(let library, let collection, let fileId):
                    provenanceRow(label: String(localized: "source.explorer.presLib.type",
                                               defaultValue: "Type"),
                                  value: String(localized: "source.explorer.presLib.typeValue",
                                               defaultValue: "Presidential Library"))
                    provenanceRow(label: String(localized: "source.explorer.presLib.library",
                                               defaultValue: "Library"),
                                  value: library)
                    if !collection.isEmpty {
                        provenanceRow(label: String(localized: "source.explorer.presLib.collection",
                                                   defaultValue: "Collection"),
                                      value: collection)
                    }
                    if let fileId {
                        provenanceRow(label: String(localized: "source.explorer.presLib.fileId",
                                                   defaultValue: "File Identifier"),
                                      value: fileId)
                    }

                case .foreignGovernmentArchive(let desc):
                    provenanceRow(label: String(localized: "source.explorer.foreignArchive.type",
                                               defaultValue: "Type"),
                                  value: String(localized: "source.explorer.foreignArchive.typeValue",
                                               defaultValue: "Foreign Government Archive"))
                    Text(desc)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)

                case .previouslyPublished(let citation):
                    provenanceRow(label: String(localized: "source.explorer.published.type",
                                               defaultValue: "Type"),
                                  value: String(localized: "source.explorer.published.typeValue",
                                               defaultValue: "Previously Published"))
                    Text(citation)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)

                case .unrecognized:
                    provenanceRow(label: String(localized: "source.explorer.unrecognized.type",
                                               defaultValue: "Type"),
                                  value: String(localized: "source.explorer.unrecognized.typeValue",
                                               defaultValue: "Unrecognized Format"))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func provenanceRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .trailing)
            Text(value)
                .font(.callout)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - NARA Box

    @ViewBuilder
    private func naraBox(for parsed: ParsedSourceNote) -> some View {
        let header = String(localized: "source.explorer.nara.header", defaultValue: "NARA Catalog")

        switch parsed {

        case .centralFiles(_, let fileId):
            GroupBox(header) {
                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        openURL(client.resolveRG59CentralFiles(fileIdentifier: fileId ?? ""))
                    } label: {
                        Label(String(localized: "source.explorer.centralFiles.naraLink",
                                     defaultValue: "Search NARA Catalog for This File"),
                              systemImage: "arrow.up.right.square")
                    }
                    Text(String(localized: "source.explorer.centralFiles.noKeyNote",
                                defaultValue: "Central file searches open directly in your browser — no API key required."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .foreignGovernmentArchive:
            GroupBox(header) {
                Text(String(localized: "source.explorer.foreignArchive.note",
                            defaultValue: "Foreign government archives are not indexed in the NARA Catalog. Consult the archive directly for access."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .previouslyPublished:
            GroupBox(header) {
                Text(String(localized: "source.explorer.published.note",
                            defaultValue: "This document was previously published. Consult the cited publication for the original source."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .unrecognized:
            GroupBox(header) {
                Text(String(localized: "source.explorer.unrecognized.explanation",
                            defaultValue: "The source note format was not recognized. The raw text is shown to the left. Automated NARA Catalog resolution is unavailable for this entry."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

        default:
            // Lot file and Presidential Library require an API key
            GroupBox(header) {
                VStack(alignment: .leading, spacing: 12) {
                    if !hasAPIKey {
                        noAPIKeyView
                    } else if isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text(String(localized: "source.explorer.nara.loading",
                                        defaultValue: "Searching NARA Catalog…"))
                                .foregroundStyle(.secondary)
                        }
                    } else if let error = loadError {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .font(.callout)
                    } else if let result = catalogResult {
                        catalogResultView(result)
                    } else {
                        Text(String(localized: "source.explorer.nara.noResult",
                                    defaultValue: "No matching record found in the NARA Catalog."))
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - No API Key View

    private var noAPIKeyView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(String(localized: "source.explorer.noKey.label",
                         defaultValue: "NARA Catalog API Key Required"),
                  systemImage: "key")
                .font(.callout.weight(.medium))

            Text(String(localized: "source.explorer.noKey.explanation",
                        defaultValue: "A free NARA Catalog API key is needed to search for lot file and Presidential Library records. Add your key in Settings."))
                .font(.caption)
                .foregroundStyle(.secondary)

            SettingsLink {
                Text(String(localized: "source.explorer.noKey.settingsLink",
                            defaultValue: "Open Settings"))
            }
            .buttonStyle(.link)
        }
    }

    // MARK: - Catalog Result

    private func catalogResultView(_ result: NARACatalogResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(result.title)
                .font(.callout.weight(.medium))
                .textSelection(.enabled)

            if let scope = result.scopeNote {
                Text(scope)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(8)
                    .textSelection(.enabled)
            }

            Button {
                openURL(result.catalogURL)
            } label: {
                Label(String(localized: "source.explorer.nara.viewRecord",
                             defaultValue: "View in NARA Catalog"),
                      systemImage: "arrow.up.right.square")
            }
            .buttonStyle(.link)
            .padding(.top, 2)
        }
    }

    // MARK: - Load

    private func load() async {
        let note = SourceNoteParser().parse(rawSourceNote)
        parsed = note
        hasAPIKey = await client.hasAPIKey()

        switch note {
        case .lotFile(let lotNumber, _):
            guard hasAPIKey else { return }
            await fetchResult { try await client.resolveLotFile(lotNumber: lotNumber) }

        case .presidentialLibrary(let library, let collection, _):
            guard hasAPIKey else { return }
            await fetchResult {
                try await client.resolvePresidentialLibrary(library: library, collection: collection)
            }

        default:
            break
        }
    }

    private func fetchResult(_ operation: @Sendable () async throws -> NARACatalogResult?) async {
        isLoading = true
        loadError = nil
        do {
            catalogResult = try await operation()
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }
}

#endif
