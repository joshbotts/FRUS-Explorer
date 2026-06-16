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

    /// The year the FRUS document was created, used for period-based central-file
    /// routing. Mirrors the same parameter on `SourceExplorerView`.
    var documentYear: Int? = nil

    /// The indexing pipeline used for same-collection document discovery.
    /// When `nil` the related documents box is not shown.
    var indexingPipeline: IndexingPipeline? = nil

    /// Called when the user double-clicks (or activates) a related document row.
    /// Passes `(volumeId, documentId)`.
    var onRelatedDocumentTapped: ((String, String) -> Void)? = nil

    // MARK: - Dependencies

    private let client = NARACatalogClient()

    // MARK: - State

    @State private var parsed: ParsedSourceNote? = nil
    @State private var catalogResult: NARACatalogResult? = nil
    @State private var isLoading = false
    @State private var loadError: String? = nil
    @State private var hasAPIKey: Bool = false
    @State private var manualQuery: String = ""
    /// Same-collection document discovery results.
    @State private var relatedDocs: [IndexingPipeline.RelatedDocument] = []
    /// Total count of matches in the index (may exceed the displayed slice).
    @State private var relatedTotalCount: Int = 0
    /// True while the related-documents query is running.
    @State private var relatedLoading: Bool = false

    @Environment(\.openURL)  private var openURL
    @Environment(AppState.self) private var appState

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
        ToolbarItem {
            // Contextual deep link into the Research Guide's "Understanding
            // What You're Reading" page — the source-note breakdown shown
            // in the left column is exactly what that page explains in depth.
            ResearchGuideLinkButton(
                pageId: "understanding-documents",
                label: String(localized: "source.explorer.learnMore",
                              defaultValue: "Learn About Source Notes")
            )
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
                if indexingPipeline != nil {
                    relatedDocumentsBox
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

                case .cfpfFile(let fileId):
                    provenanceRow(label: String(localized: "source.explorer.cfpf.type",
                                               defaultValue: "Type"),
                                  value: String(localized: "source.explorer.cfpf.typeValue",
                                               defaultValue: "State Dept. Central Foreign Policy File (1973–1979)"))
                    provenanceRow(label: "Record Group", value: "RG 59")
                    if let fid = fileId {
                        provenanceRow(label: String(localized: "source.explorer.cfpf.fileId",
                                                   defaultValue: "File Identifier"),
                                      value: fid)
                    }

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
            // Period-based routing replaces the old resolveRG59CentralFiles catalog-search
            // URL, which returned empty results for decimal file numbers. For 1906–1910
            // documents, the bundled index resolves the exact digitized roll first.
            GroupBox(header) {
                VStack(alignment: .leading, spacing: 10) {
                    if let fileId, let year = documentYear, (1906...1910).contains(year) {
                        numericalFileBox(fileIdentifier: fileId)
                        Divider()
                    }
                    centralFilesPeriodBox
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

        case .cfpfFile:
            GroupBox(header) {
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        openURL(client.cfpfFAQURL)
                    } label: {
                        Label(String(localized: "source.explorer.cfpf.faqLink",
                                     defaultValue: "CFPF Research Guide (PDF)"),
                              systemImage: "doc.fill")
                    }
                    Button {
                        openURL(client.cfpfAADURL)
                    } label: {
                        Label(String(localized: "source.explorer.cfpf.aadLink",
                                     defaultValue: "Search AAD Electronic Telegrams Database"),
                              systemImage: "arrow.up.right.square")
                    }
                    Text(String(localized: "source.explorer.cfpf.note",
                                defaultValue: "CFPF records are available on microfilm (P-Reels, D-Reels, N-Reels) at NARA and as electronic telegrams in the AAD database. No API key is required for either resource."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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

        // Local related-documents query — runs unconditionally; no API key needed.
        // Must be called before the per-case hasAPIKey guards that return early.
        await loadRelatedDocuments(for: note)

        switch note {
        case .lotFile(let rg, let lotNumber, _):
            // Pre-fill manual query with the lot number (without decorative prefix).
            manualQuery = lotNumber
            guard hasAPIKey else { return }
            // Use variantControlNumber_is with three normalised forms; falls back to
            // phrase query if all variants return zero results. Pass the actual RG so
            // F-designator lot files (RG 84 post records) are queried correctly.
            let rgToUse = (rg ?? "RG-59").replacingOccurrences(of: "RG-", with: "")
            await fetchResult {
                let results = try await client.resolveLotFileVariants(lotNumber: lotNumber, recordGroup: rgToUse)
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

    private func loadRelatedDocuments(for note: ParsedSourceNote) async {
        guard let pipeline = indexingPipeline else { return }
        relatedLoading = true
        do {
            let result = try await pipeline.relatedDocuments(for: note, limit: 30)
            relatedDocs       = result.documents
            relatedTotalCount = result.totalCount
        } catch {
            #if DEBUG
            print("[SourceExplorer] Related documents query failed: \(error)")
            #endif
        }
        relatedLoading = false
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

    // MARK: - Numerical File Roll Box (1906–1910)

    /// Resolves a 1906–1910 "File No." to the digitized Numerical File roll(s) holding its
    /// case, from the bundled `central-files-index.json` (no API key, no network). Mirrors
    /// `SourceExplorerView.numericalFileSection`. Falls back to the Card Index (M1889) and
    /// the series link when the case is in a coverage gap or filed on a name/place roll.
    @ViewBuilder
    private func numericalFileBox(fileIdentifier: String) -> some View {
        let rolls = CentralFilesIndexStore.shared?
            .numericalFile.rolls(forFileNumber: fileIdentifier) ?? []

        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "source.explorer.numericalFile.header",
                        defaultValue: "Digitized Numerical File (M862)"))
                .font(.headline)
            if rolls.isEmpty {
                Text(String(localized: "source.explorer.numericalFile.gap",
                            defaultValue: "No digitized roll directly covers this file number. Use the Card Index to confirm the case number, then browse the Numerical File series."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    openURL(CentralFilesIndexStore.cardIndexURL)
                } label: {
                    Label(String(localized: "source.explorer.numericalFile.cardIndex",
                                 defaultValue: "Open Card Index (M1889) in NARA Catalog"),
                          systemImage: "rectangle.stack.badge.person.crop")
                }
                .buttonStyle(.link)
                Button {
                    openURL(CentralFilesIndexStore.numericalFileSeriesURL)
                } label: {
                    Label(String(localized: "source.explorer.numericalFile.series",
                                 defaultValue: "Browse the Numerical File series"),
                          systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.link)
            } else {
                Text(String(localized: "source.explorer.numericalFile.found",
                            defaultValue: "These digitized rolls hold File No. \(fileIdentifier). Open one and review the images page by page — documents are filed in numeric order by case."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(rolls) { roll in
                    Button {
                        if let url = URL(string: roll.catalogURL) { openURL(url) }
                    } label: {
                        Label(roll.title, systemImage: "film")
                    }
                    .buttonStyle(.link)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Central Files Period Box

    /// Period-based NARA finding-aid routing for `.centralFiles` notes.
    ///
    /// Mirrors `SourceExplorerView.centralFilesPeriodSection`:
    /// - When `documentYear` is known: links directly to the period-specific
    ///   `archives.gov/research/…` page plus the filing manual PDF if applicable.
    /// - When unknown: shows a compact table of all filing periods so the
    ///   researcher can navigate to the right one manually.
    ///
    /// `resolveRG59CentralFiles` is intentionally not used here because
    /// `catalog.archives.gov/search?q=…&f.parentDescriptionNaId=302028`
    /// returns no useful results for decimal file identifiers.
    @ViewBuilder
    private var centralFilesPeriodBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let year = documentYear {
                // Resolved period
                let label  = client.decimalFilePeriodLabel(year: year)
                let url    = client.decimalFilePeriodURL(year: year)
                HStack {
                    Text(String(localized: "source.explorer.decimalPeriod.matched",
                                defaultValue: "Filing Period"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .trailing)
                    Text(label).font(.callout).textSelection(.enabled)
                }
                Button {
                    openURL(url)
                } label: {
                    Label(String(localized: "source.explorer.decimalPeriod.link",
                                 defaultValue: "Open NARA Finding Aids for This Period"),
                          systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.link)
                if let manualURL = client.filingManualURL(year: year) {
                    Button {
                        openURL(manualURL)
                    } label: {
                        Label(String(localized: "source.explorer.decimalPeriod.manualLink",
                                     defaultValue: "Filing Manual for This Period (PDF)"),
                              systemImage: "doc.fill")
                    }
                    .buttonStyle(.link)
                }
                Text(String(localized: "source.explorer.decimalPeriod.hint",
                            defaultValue: "Box lists, purport indexes, and the filing manual for this period are available on the linked NARA page."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                // No year — show the full period table with filing manuals
                Text(String(localized: "source.explorer.decimalPeriod.noYear",
                            defaultValue: "Select the filing period that matches the document date:"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(SourceExplorerView.allFilingPeriods, id: \.id) { period in
                    VStack(alignment: .leading, spacing: 2) {
                        Button(period.label) {
                            openURL(period.url)
                        }
                        .buttonStyle(.link)
                        .font(.callout)
                        ForEach(period.filingManuals, id: \.url) { manual in
                            Button {
                                openURL(manual.url)
                            } label: {
                                Label(manual.label, systemImage: "doc.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.link)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    // MARK: - Related Documents Box

    /// GroupBox listing documents from the same archival collection.
    ///
    /// Shown only when `indexingPipeline` is non-nil. An empty result is hidden
    /// so the box does not take up space when no related documents are indexed.
    @ViewBuilder
    private var relatedDocumentsBox: some View {
        if relatedLoading {
            GroupBox(String(localized: "source.explorer.related.header",
                            defaultValue: "Documents from This Collection")) {
                HStack {
                    ProgressView().controlSize(.small).padding(.trailing, 6)
                    Text(String(localized: "source.explorer.related.loading",
                                defaultValue: "Searching indexed volumes…"))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else if !relatedDocs.isEmpty {
            GroupBox {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(relatedDocs, id: \.documentId) { doc in
                        Button {
                            onRelatedDocumentTapped?(doc.volumeId, doc.documentId)
                        } label: {
                            macRelatedDocumentRow(doc)
                        }
                        .buttonStyle(.plain)
                        if doc.documentId != relatedDocs.last?.documentId {
                            Divider().padding(.leading, 8)
                        }
                    }
                    if relatedTotalCount > relatedDocs.count {
                        Text(String(localized: "source.explorer.related.overflow",
                                    defaultValue: "\(relatedTotalCount - relatedDocs.count) more documents not shown"))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 6)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                HStack {
                    Text(String(localized: "source.explorer.related.header",
                                defaultValue: "Documents from This Collection"))
                        .font(.headline.weight(.semibold))
                    Spacer()
                    Text("\(relatedTotalCount)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
            }
        }
    }

    @ViewBuilder
    private func macRelatedDocumentRow(_ doc: IndexingPipeline.RelatedDocument) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if let num = doc.documentNumber {
                Text(num)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .trailing)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(doc.header.isEmpty ? doc.documentId : doc.header)
                    .font(.callout)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    Text(doc.volumeId)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    if let dateline = doc.dateline {
                        Text(dateline)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }
}

#endif
