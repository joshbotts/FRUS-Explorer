// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

#if os(macOS)

import SwiftUI
import UniformTypeIdentifiers
import AppKit

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
///   1.2 — Session 95: toolbar (Refresh / Copy / Export), manual NARA search field for
///          lot file and Presidential Library provenance, NSSavePanel plain-text export,
///          NSPasteboard copy; load() pre-fills manualQuery from parsed provenance
///   1.3 — Session 118: `naraBox` RG-59 button label changes to "Browse RG-59 in NARA
///          Catalog" when `fileId` is nil, matching the iOS fix for the misleading label
///   1.4 — Session 150: `load()` uses `resolveLotFileVariants` (variantControlNumber_is);
///          `resolvePresidentialLibrary` returns up to 3 results; specific error messages
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
    @State private var manualQuery: String = ""

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
        .toolbar { explorerToolbar }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var explorerToolbar: some ToolbarContent {
        ToolbarItem {
            Button {
                Task { await runManualSearch() }
            } label: {
                Label(String(localized: "source.explorer.toolbar.refresh",
                             defaultValue: "Refresh"),
                      systemImage: "arrow.clockwise")
            }
            .disabled(isLoading || !showsManualSearch)
            .help(String(localized: "source.explorer.toolbar.refresh.tooltip",
                         defaultValue: "Re-run the current NARA Catalog search"))
        }
        ToolbarItem {
            Button {
                copyResultToClipboard()
            } label: {
                Label(String(localized: "source.explorer.toolbar.copy",
                             defaultValue: "Copy"),
                      systemImage: "doc.on.clipboard")
            }
            .disabled(catalogResult == nil)
            .help(String(localized: "source.explorer.toolbar.copy.tooltip",
                         defaultValue: "Copy catalog result to clipboard"))
        }
        ToolbarItem {
            Button {
                exportCatalogResult()
            } label: {
                Label(String(localized: "source.explorer.toolbar.export",
                             defaultValue: "Export"),
                      systemImage: "square.and.arrow.up")
            }
            .disabled(catalogResult == nil)
            .help(String(localized: "source.explorer.toolbar.export.tooltip",
                         defaultValue: "Save catalog result as a text file"))
        }
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
                if showsManualSearch {
                    manualSearchField
                }
                if let parsed {
                    naraBox(for: parsed)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(40)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Manual Search

    private var showsManualSearch: Bool {
        switch parsed {
        case .lotFile, .presidentialLibrary, .naraCollection: return true
        default: return false
        }
    }

    private var manualSearchField: some View {
        GroupBox(String(localized: "source.explorer.manualSearch.header",
                        defaultValue: "NARA Search Query")) {
            VStack(alignment: .leading, spacing: 8) {
                TextField(
                    String(localized: "source.explorer.manualSearch.placeholder",
                           defaultValue: "Search query"),
                    text: $manualQuery
                )
                .textFieldStyle(.roundedBorder)
                .onSubmit { Task { await runManualSearch() } }

                Button(String(localized: "source.explorer.manualSearch.button",
                              defaultValue: "Search")) {
                    Task { await runManualSearch() }
                }
                .disabled(manualQuery.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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

                case .naraCollection(let rg, let series, let lotFile, let box):
                    provenanceRow(label: "Repository", value: "National Archives (RG \(rg))")
                    if let s = series  { provenanceRow(label: "Series", value: s) }
                    if let l = lotFile { provenanceRow(label: "Lot File", value: l) }
                    if let b = box     { provenanceRow(label: "Box", value: b) }

                case .ciaCollection(let job, let box, _):
                    provenanceRow(label: "Repository", value: "Central Intelligence Agency")
                    if let j = job { provenanceRow(label: "Job No.", value: j) }
                    if let b = box { provenanceRow(label: "Box", value: b) }

                case .lotFile(let rg, let lot, let fileId):
                    provenanceRow(label: String(localized: "source.explorer.lotFile.type",
                                               defaultValue: "Type"),
                                  value: String(localized: "source.explorer.lotFile.typeValue",
                                               defaultValue: "State Dept. Lot File"))
                    if let r = rg { provenanceRow(label: "Record Group", value: "RG \(r)") }
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
                        // When a specific file identifier was parsed, label the action as a
                        // targeted search. When nil (narrative note with no extractable ID),
                        // use a general browse label so the user is not misled.
                        if fileId != nil {
                            Label(String(localized: "source.explorer.centralFiles.naraLink",
                                         defaultValue: "Search NARA Catalog for This File"),
                                  systemImage: "arrow.up.right.square")
                        } else {
                            Label(String(localized: "source.explorer.centralFiles.naraLinkGeneral",
                                         defaultValue: "Browse RG-59 in NARA Catalog"),
                                  systemImage: "arrow.up.right.square")
                        }
                    }
                    .help(fileId != nil
                          ? String(localized: "source.explorer.centralFiles.naraLink.help",
                                   defaultValue: "Open archives.gov with this exact decimal-file identifier")
                          : String(localized: "source.explorer.centralFiles.naraLinkGeneral.help",
                                   defaultValue: "Open the RG-59 Central Files browse page on archives.gov"))
                    Text(String(localized: "source.explorer.centralFiles.noKeyNote",
                                defaultValue: "Central file searches open directly in your browser — no API key required."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .ciaCollection:
            GroupBox(header) {
                Text(String(localized: "source.explorer.cia.naraNote",
                            defaultValue: "CIA accession records are not publicly available in the NARA Catalog."))
                    .font(.callout).foregroundStyle(.secondary)
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
            .help(String(
                localized: "source.explorer.nara.viewRecord.help",
                defaultValue: "Open this NARA catalog record in your browser"
            ))
        }
    }

    // MARK: - Load

    private func load() async {
        let note = SourceNoteParser().parse(rawSourceNote)
        parsed = note
        hasAPIKey = await client.hasAPIKey()

        switch note {
        case .lotFile(let rg, let lotNumber, _):
            // Pre-fill manual query with the lot number (without decorative prefix).
            manualQuery = lotNumber
            guard hasAPIKey else { return }
            // Use variantControlNumber_is with three normalised forms; falls back to
            // phrase query if all variants return zero results.
            await fetchResult {
                let results = try await client.resolveLotFileVariants(lotNumber: lotNumber)
                return results.first
            }

        case .naraCollection(let rg, let series, let lot, _):
            let keywords = [series, lot].compactMap { $0 }.joined(separator: " ")
            manualQuery = "RG \(rg) \(keywords)"
            guard hasAPIKey else { return }
            let results = try? await client.searchByRecordGroup(rg, keywords: keywords, maxResults: 3)
            if let first = results?.first { await MainActor.run { catalogResult = first } }

        case .presidentialLibrary(let library, let collection, _):
            manualQuery = "\(library) \(collection)"
            guard hasAPIKey else { return }
            // Return up to 3 candidates; display the first in the single-result macOS layout.
            await fetchResult {
                try await client.searchByPresidentialMaterials(
                    library: library, collection: collection, maxResults: 3
                ).first
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

    // MARK: - Manual Search Action

    private func runManualSearch() async {
        let query = manualQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        await fetchResult { try await client.searchCatalog(query: query) }
    }

    // MARK: - Copy

    private func copyResultToClipboard() {
        guard let result = catalogResult else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(naraExportText(result), forType: .string)
    }

    // MARK: - Export

    private func exportCatalogResult() {
        guard let result = catalogResult else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "\(result.naId).txt"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? naraExportText(result).write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func naraExportText(_ result: NARACatalogResult) -> String {
        var lines: [String] = [
            "NARA Catalog Record",
            "===================",
            "NA ID: \(result.naId)",
            "Title: \(result.title)",
        ]
        if let scope = result.scopeNote {
            lines.append("")
            lines.append("Scope / Content:")
            lines.append(scope)
        }
        lines.append("")
        lines.append("URL: \(result.catalogURL.absoluteString)")
        return lines.joined(separator: "\n")
    }
}

#endif
