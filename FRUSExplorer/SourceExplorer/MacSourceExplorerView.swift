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
///   1.5 — Session 2026-07-03 (Source Explorer Phase 4 step 2): Archival Collection
///          box — when the parsed note's keys land in the bundled cross-volume
///          authority, opens the shared Collection detail sheet (aliases, NAID, S5
///          local counts, citing volumes, sub-series)
///   1.6 — #315: `bundledLotBox` shows the HMS/MLR entry number(s) and, for file-unit
///          records, the enclosing File Series with the series' entry numbers labeled as
///          the series'; citation-guidance captions on the central-files and CFPF
///          provenance cases. Flagged mis-resolutions (#321) fall back to the live
///          lookup via the shared `lotFile(forRawLot:)` guard. Mirrors
///          SourceExplorerView 1.6 — keep the two row logics in sync.
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

    /// Document classifier cues for pre-1906 country-series resolution (no source note).
    var documentHeader: String? = nil
    var documentDateline: String? = nil
    var documentVolumeId: String? = nil
    var documentId: String? = nil

    // MARK: - Dependencies

    private let client = NARACatalogClient()

    // MARK: - State

    @State private var parsed: ParsedSourceNote? = nil
    /// Up to five ranked NARA Catalog candidates for the current source note.
    /// Replaces the former single-result `catalogResult`, bringing macOS to parity
    /// with the iOS Source Explorer (which already shows a candidate list).
    @State private var catalogResults: [NARACatalogResult] = []
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
    /// Pre-1906 country-series classifications + resolved rolls (Phase 2).
    @State private var countryResolutions: [CountrySeriesResolution] = []

    /// The bundled cross-volume authority record the parsed note resolves to (Phase 4),
    /// or `nil` when the note's keys land in no tracked collection.
    @State private var authorityRecord: AuthorityCollectionRecord? = nil
    /// When set, presents the shared Collection detail sheet.
    @State private var collectionDetailRecord: AuthorityCollectionRecord? = nil

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
        .sheet(item: $collectionDetailRecord) { record in
            CollectionDetailSheet(record: record)
                .environment(appState)
        }
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
            .disabled(catalogResults.isEmpty)
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
            .disabled(catalogResults.isEmpty)
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
        ToolbarItem {
            FeatureInfoButton.sourceExplorer
        }
    }

    // MARK: - Left Column

    private var leftColumn: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 14) {
                GroupBox(String(localized: "source.explorer.rawNote.header",
                                defaultValue: "Source Note")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(hasSourceNote
                             ? rawSourceNote
                             : String(localized: "source.explorer.noNote.body",
                                      defaultValue: "This document has no archival source note. Its likely filing is predicted from its dateline and FRUS chapter — see the resolution on the right."))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        // Phase 5: the S1 classification markings (sentence 2 of the
                        // note when it matches the marking vocabulary), as a quiet chip.
                        if hasSourceNote,
                           let marking = SourceNoteParser.classificationMarking(fromSourceNote: rawSourceNote) {
                            ClassificationChip(marking: marking)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Only show parsed provenance when there is a note to parse; an absent note
                // is not an "unrecognized" one.
                if hasSourceNote, let parsed {
                    provenanceBox(for: parsed)
                }

                // Phase 4: the cross-volume collection this citation belongs to.
                if authorityRecord != nil {
                    collectionBox
                }
            }
            .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Collection Box (Phase 4)

    /// The bundled authority match: canonical collection name, its series-wide citing
    /// count, and a button opening the shared Collection detail sheet (aliases, NAID
    /// link, S5 local counts, sub-series).
    @ViewBuilder
    private var collectionBox: some View {
        if let record = authorityRecord {
            GroupBox(String(localized: "source.explorer.collection.header",
                            defaultValue: "Archival Collection")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(record.name)
                        .font(.callout.weight(.medium))
                        .textSelection(.enabled)
                    Text(String(format: String(
                        localized: "source.explorer.collection.cited %lld",
                        defaultValue: "Cited in %lld volumes across the series"),
                        Int64(record.volumeIds.count)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        collectionDetailRecord = record
                    } label: {
                        Label(String(localized: "source.explorer.collection.open",
                                     defaultValue: "View Collection"),
                              systemImage: "books.vertical")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Right Column

    private var rightColumn: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 14) {
                if hasSourceNote {
                    // A real note exists — parse it and resolve via the NARA Catalog.
                    if showsManualSearch {
                        manualSearchField
                    }
                    if case .lotFile(_, let lot, _) = parsed,
                       let entry = CentralFilesIndexStore.shared?.lotFile(forRawLot: lot) {
                        bundledLotBox(entry)
                    }
                    // Hand-curated outcome for a collection NARA's catalogue does not resolve
                    // by control number (#375). Mirrors iOS `curatedLotSection`. Reached both
                    // by lot number and — for a citation that names the collection without one
                    // — by series name.
                    if let outcome = curatedOutcome(for: parsed) {
                        curatedLotBox(outcome)
                    }
                    if let parsed {
                        naraBox(for: parsed)
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(40)
                    }
                }
                // Country-series classification (pre-1906 documents with no source note).
                if !countryResolutions.isEmpty {
                    countrySeriesBox
                } else if !hasSourceNote {
                    noSourceNoteBox
                }
                if indexingPipeline != nil {
                    relatedDocumentsBox
                }
            }
            .padding(16)
        }
    }

    // MARK: - Manual Search

    /// Whether the document actually carries an archival source note. When `false` (chiefly
    /// pre-1906 documents, which carry none), the explorer leads with the country-series
    /// classification heuristics rather than parsing — and presenting failure for — a note
    /// that does not exist.
    private var hasSourceNote: Bool {
        !rawSourceNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

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
                    // Same one text as the iOS panel: `rg` carries the "RG-" prefix, normalised
                    // to "RG 59" so this row reads like the lot-file Record Group row below.
                    provenanceRow(label: String(localized: "source.explorer.centralFiles.type",
                                               defaultValue: "Type"),
                                  value: String(localized: "source.explorer.centralFiles.typeValue",
                                               defaultValue: "State Dept. Central Files (\(rg.replacingOccurrences(of: "RG-", with: "RG ")))"))
                    if let fileId {
                        provenanceRow(label: String(localized: "source.explorer.centralFiles.identifier",
                                                   defaultValue: "File Identifier"),
                                      value: fileId)
                    }
                    // #315: citation guidance — mirrors the iOS centralFilesPanel note.
                    Text(String(localized: "source.explorer.centralFiles.cite.note",
                                defaultValue: "When requesting the original record from NARA, provide the decimal file number above together with any telegram serial number, the from/to information, and the document's date from the source note — archivists use these to locate the record within the file."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

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
                    // Curation is authoritative over the parser's record group, which defaults
                    // every non-`F` lot to RG 59 and so mislabels at least one curated
                    // collection that NARA holds in RG 43 (#375). Mirrors the iOS
                    // `lotFilePanel` override — keep in sync.
                    if let r = CuratedLotResolutionsStore.shared?.recordGroup(forRawLot: lot) ?? rg {
                        // `rg` already carries the "RG-" prefix (e.g. "RG-59"); normalise to
                        // "RG 59" so the row doesn't read "RG RG-59".
                        provenanceRow(label: "Record Group",
                                      value: r.replacingOccurrences(of: "RG-", with: "RG "))
                    }
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
                    // #315: CFPF citation guidance — mirrors the iOS cfpfPanel note.
                    Text(String(localized: "source.explorer.cfpf.cite.note",
                                defaultValue: "When requesting the original record from NARA, provide the file identifier above together with any telegram channel and serial numbers, the from/to information, and the document's date from the source note."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                case .namedFileSeries(let series, let fileId):
                    provenanceRow(label: String(localized: "source.explorer.namedSeries.type",
                                               defaultValue: "Type"),
                                  value: String(localized: "source.explorer.namedSeries.typeValue",
                                               defaultValue: "Named File Series"))
                    provenanceRow(label: String(localized: "source.explorer.namedSeries.series",
                                               defaultValue: "File Series"),
                                  value: series)
                    // A collection cited by name alone carries no record group; curation
                    // supplies it when the same collection is curated under its lot number.
                    // Mirrors the iOS `namedFileSeriesPanel` — keep in sync.
                    if let rg = CuratedLotResolutionsStore.shared?.recordGroup(forSeriesName: series) {
                        provenanceRow(label: "Record Group",
                                      value: rg.replacingOccurrences(of: "RG-", with: "RG "))
                    }
                    if let fileId {
                        provenanceRow(label: String(localized: "source.explorer.namedSeries.file",
                                                   defaultValue: "File"),
                                      value: fileId)
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
                    centralFilesPeriodBox(fileIdentifier: fileId)
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

        case .namedFileSeries:
            GroupBox(header) {
                Text(String(localized: "source.explorer.namedSeries.note",
                            defaultValue: "A named file series cited without a lot number. The citation does not state the holding repository, so no automated NARA Catalog query is available."))
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
                    } else if !catalogResults.isEmpty {
                        // Up to 5 ranked candidates (parity with iOS).
                        ForEach(catalogResults.prefix(5), id: \.naId) { result in
                            catalogResultView(result)
                            if result.naId != catalogResults.prefix(5).last?.naId {
                                Divider()
                            }
                        }
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

    // MARK: - Bundled Lot File Box

    /// A bundled, key-less link to a lot file's resolved NARA Catalog series record —
    /// enriched (#315) with the identifiers NARA staff ask researchers to cite.
    ///
    /// Row logic mirrors the iOS `SourceExplorerView.bundledLotSection` — keep in sync:
    /// a series-level record's own title/entry numbers are shown directly; a file-unit
    /// record additionally names its enclosing series (`displaySeriesTitle`), and any
    /// entry numbers shown for it are the *series'*, labeled as such (the parent's
    /// identifiers locate the series, not the specific unit).
    @ViewBuilder
    private func bundledLotBox(_ entry: LotFileEntry) -> some View {
        GroupBox(String(localized: "source.explorer.lotFile.bundled.header",
                        defaultValue: "NARA Catalog Record")) {
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.title).font(.callout)
                if !entry.isSeriesLevel, let seriesTitle = entry.displaySeriesTitle {
                    LabeledContent(
                        String(localized: "source.explorer.lotFile.series",
                               defaultValue: "File Series"),
                        value: seriesTitle
                    )
                    .font(.callout)
                }
                if let entries = entry.hmsMlrEntryNumbers, !entries.isEmpty {
                    LabeledContent(
                        String(localized: "source.explorer.lotFile.hmsMlr",
                               defaultValue: "HMS/MLR Entry"),
                        value: entries.joined(separator: ", ")
                    )
                    .font(.callout)
                } else if let seriesEntries = entry.seriesHmsMlrEntryNumbers, !seriesEntries.isEmpty {
                    LabeledContent(
                        String(localized: "source.explorer.lotFile.hmsMlr.series",
                               defaultValue: "HMS/MLR Entry (series)"),
                        value: seriesEntries.joined(separator: ", ")
                    )
                    .font(.callout)
                    Text(String(localized: "source.explorer.lotFile.hmsMlr.series.note",
                                defaultValue: "These entry numbers identify the enclosing file series, not this specific file unit."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button {
                    if let url = URL(string: entry.catalogURL) { openURL(url) }
                } label: {
                    Label(String(localized: "source.explorer.lotFile.bundled.open",
                                 defaultValue: "Open Series in NARA Catalog"),
                          systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.link)
                if entry.hmsMlrEntryNumbers?.isEmpty == false || entry.seriesHmsMlrEntryNumbers?.isEmpty == false {
                    Text(String(localized: "source.explorer.lotFile.cite.note",
                                defaultValue: "When requesting the original records from NARA, cite the HMS/MLR entry number together with the lot number — it is the identifier archives staff use to locate the series."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(String(localized: "source.explorer.lotFile.bundled.note",
                            defaultValue: "Resolved from the bundled index — no API key required. Records may be described at the series level rather than digitized page-by-page."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The curated outcome for a parsed note, by lot number or — when the citation names the
    /// collection without one — by series name. `nil` for every other parse.
    private func curatedOutcome(for parsed: ParsedSourceNote?) -> CuratedLotOutcome? {
        switch parsed {
        case .lotFile(_, let lot, _):
            return CuratedLotResolutionsStore.shared?.outcome(forRawLot: lot)
        case .namedFileSeries(let series, _):
            return CuratedLotResolutionsStore.shared?.outcome(forSeriesName: series)
        default:
            return nil
        }
    }

    // MARK: - Curated Lot Box

    /// The hand-curated outcome for a lot NARA's catalogue does not resolve by control
    /// number (#375 / N-3), in the confidence grammar the pre-1906 country-series box
    /// established: a `ConfidenceChip` beside each candidate and a rationale beneath it.
    ///
    /// Mirrors `SourceExplorerView.curatedLotSection` — keep in sync. Every branch is
    /// deliberately hedged: a curated match was reached by collection name or by creator,
    /// never by a control number, so none of them may borrow `bundledLotBox`'s
    /// "Resolved from the bundled index" caption.
    @ViewBuilder
    private func curatedLotBox(_ outcome: CuratedLotOutcome) -> some View {
        switch outcome {
        case .possible(let series, let rationale):
            GroupBox(String(localized: "source.explorer.curatedLot.possible.header",
                            defaultValue: "Possible NARA Catalog Record")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text(series.title).font(.callout)
                        ConfidenceChip(confidence: .medium)
                    }
                    if let entry = series.entryNumber {
                        LabeledContent(
                            String(localized: "source.explorer.lotFile.hmsMlr",
                                   defaultValue: "HMS/MLR Entry"),
                            value: entry
                        )
                        .font(.callout)
                    }
                    if let dateRange = series.dateRange {
                        LabeledContent(
                            String(localized: "source.explorer.curatedLot.dateRange",
                                   defaultValue: "Series Dates"),
                            value: dateRange
                        )
                        .font(.callout)
                    }
                    Text(rationale)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        if let url = series.url { openURL(url) }
                    } label: {
                        Label(String(localized: "source.explorer.curatedLot.open",
                                     defaultValue: "Open Series in NARA Catalog"),
                              systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(.link)
                    Text(String(localized: "source.explorer.curatedLot.possible.note",
                                defaultValue: "This match was made by collection name, not by a catalog control number. Confirm the lot number against the series before citing it."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .candidates(let series, let rationale, let creatorName, let seeAllURL):
            GroupBox(String(localized: "source.explorer.curatedLot.candidates.header",
                            defaultValue: "Candidate NARA Series")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(rationale)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let creatorName {
                        LabeledContent(
                            String(localized: "source.explorer.curatedLot.creator",
                                   defaultValue: "NARA Creator"),
                            value: creatorName
                        )
                        .font(.callout)
                    }
                    ForEach(series) { candidate in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Button {
                                    if let url = candidate.url { openURL(url) }
                                } label: {
                                    Text(candidate.title).font(.callout)
                                }
                                .buttonStyle(.link)
                                ConfidenceChip(confidence: .medium)
                            }
                            if let detail = curatedSeriesSubtitle(candidate) {
                                Text(detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let seeAllURL {
                        Button {
                            openURL(seeAllURL)
                        } label: {
                            Label(String(localized: "source.explorer.curatedLot.seeAll",
                                         defaultValue: "See all series by this creator"),
                                  systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(.link)
                    }
                    Text(String(localized: "source.explorer.curatedLot.candidates.note",
                                defaultValue: "NARA did not accession this lot as a single series, so no one record is the answer. Review the candidates against the document's date and type."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .referral(let referral):
            GroupBox(String(localized: "source.explorer.curatedLot.referral.header",
                            defaultValue: "Ask a NARA Archivist")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(referral.rationale)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                    if let count = referral.seriesCount {
                        LabeledContent(
                            String(localized: "source.explorer.curatedLot.referral.seriesCount",
                                   defaultValue: "Series in the collection"),
                            value: "\(count)"
                        )
                        .font(.callout)
                    }
                    if let range = referral.entryNumberRange {
                        LabeledContent(
                            String(localized: "source.explorer.curatedLot.referral.entryRange",
                                   defaultValue: "HMS/MLR Entry Range"),
                            value: range
                        )
                        .font(.callout)
                    }
                    Text(referral.guidance)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let url = referral.url {
                        Button {
                            openURL(url)
                        } label: {
                            Label(String(localized: "source.explorer.curatedLot.referral.browse",
                                         defaultValue: "Browse the collection's series"),
                                  systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(.link)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// One-line "entry number · dates" subtitle for a candidate row, or `nil` when neither
    /// is known. Mirrors `SourceExplorerView.curatedSeriesSubtitle`.
    private func curatedSeriesSubtitle(_ series: CuratedSeries) -> String? {
        let parts = [series.entryNumber, series.dateRange].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
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

    // MARK: - Country-Series Resolution (pre-1906, Phase 2)

    /// One classification candidate paired with the rolls it resolves to.
    struct CountrySeriesResolution: Identifiable {
        let classification: CentralFilesClassification
        let rolls: [CountryRoll]
        var id: String { classification.category.rawValue }
    }

    /// Classifies a pre-1906 document (no source note) from its dateline, heading, and
    /// FRUS chapter, and resolves each candidate series to its roll(s) in the bundled index.
    private func resolveCountrySeries() async {
        guard let dateline = documentDateline,
              let year = documentYear, year < 1906,
              let index = CentralFilesIndexStore.shared else { return }

        var path: [String] = []
        if let pipeline = indexingPipeline, let volumeId = documentVolumeId, let docId = documentId,
           let structure = try? await pipeline.cachedVolumeStructure(forVolumeId: volumeId) {
            path = CentralFilesClassifier.documentSectionPath(in: structure, documentId: docId)
        }
        guard !path.isEmpty else { return }

        let dateISO = CentralFilesClassifier.datelineDateISO(from: dateline)
        // The country usually sits in the middle of the section chain (a parent chapter),
        // not the leaf subject section, so try each title and keep the first that resolves
        // to real rolls.
        var resolutions: [CountrySeriesResolution] = []
        for title in path where resolutions.isEmpty {
            let classifications = CentralFilesClassifier.classify(
                header: documentHeader ?? "", dateline: dateline, chapterCountry: title)
            for classification in classifications {
                guard let geoKey = classification.geoKeys.first,
                      let series = index.series(category: classification.category) else { continue }
                let rolls = series.rolls(geoKey: geoKey, dateISO: dateISO)
                if !rolls.isEmpty {
                    resolutions.append(CountrySeriesResolution(classification: classification, rolls: rolls))
                }
            }
        }
        countryResolutions = resolutions
    }

    @ViewBuilder
    private var countrySeriesBox: some View {
        GroupBox(String(localized: "source.explorer.countrySeries.header",
                        defaultValue: "Digitized Diplomatic Records (pre-1906)")) {
            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "source.explorer.countrySeries.intro",
                            defaultValue: "This document predates the 1906 Numerical File. Based on its dateline and FRUS chapter, it was likely filed in the digitized series below — open a roll and review the images for the document's date."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(countryResolutions) { resolution in
                    let c = resolution.classification
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(c.category.displayName).font(.callout.weight(.semibold))
                            ConfidenceChip(confidence: c.confidence)
                        }
                        Text(c.rationale).font(.caption).foregroundStyle(.secondary)
                        ForEach(resolution.rolls) { roll in
                            Button {
                                if let url = URL(string: roll.catalogURL) { openURL(url) }
                            } label: {
                                Label(roll.title, systemImage: "film")
                            }
                            .buttonStyle(.link)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Shown for a document with no source note that the country-series classifier could not
    /// resolve to a specific roll (e.g. 1906–1910 Numerical File documents, whose case-number
    /// filing can't be predicted from metadata). Names the likely series for the era instead
    /// of presenting an "unrecognized note" parse failure.
    @ViewBuilder
    private var noSourceNoteBox: some View {
        GroupBox(String(localized: "source.explorer.noNote.header",
                        defaultValue: "Archival Source")) {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "source.explorer.noNote.detail",
                            defaultValue: "This document carries no archival source note, and its exact filing couldn't be predicted from its dateline and FRUS chapter."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let series = predictedSeriesNote {
                    Text(series)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// A plain-language note on the likely State Department file series for a note-less
    /// document, inferred from its year. Used when no specific roll can be predicted.
    private var predictedSeriesNote: String? {
        guard let year = documentYear else { return nil }
        switch year {
        case ..<1906:
            return String(localized: "source.explorer.noNote.series.diplomatic",
                          defaultValue: "Documents of this era are held in the country-arranged diplomatic series (Despatches and Instructions) at the National Archives, Record Group 59.")
        case 1906...1910:
            return String(localized: "source.explorer.noNote.series.numerical",
                          defaultValue: "Documents of this era are filed in the 1906–1910 Numerical File at the National Archives, Record Group 59, arranged by case number rather than by country or date.")
        default:
            return nil
        }
    }

    // MARK: - Load

    private func load() async {
        let note = SourceNoteParser().parse(rawSourceNote)
        parsed = note

        // Phase 4: resolve the note against the bundled cross-volume authority.
        // Warmed off the main thread (one ~2 MB decode, once per launch).
        if hasSourceNote {
            let raw = rawSourceNote
            authorityRecord = await Task.detached(priority: .userInitiated) {
                CollectionAuthorityStore.shared?.record(forParsed: note, note: raw)
            }.value
        }

        hasAPIKey = await client.hasAPIKey()

        // Pre-1906 country-series resolution (no source note; no API key).
        await resolveCountrySeries()

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
            await fetchResults {
                try await client.resolveLotFileVariants(lotNumber: lotNumber, recordGroup: rgToUse)
            }

        case .naraCollection(let rg, let series, let lot, _):
            let keywords = [series, lot].compactMap { $0 }.joined(separator: " ")
            manualQuery = "RG \(rg) \(keywords)"
            guard hasAPIKey else { return }
            await fetchResults {
                try await client.searchByRecordGroup(rg, keywords: keywords, maxResults: 5)
            }

        case .presidentialLibrary(let library, let collection, _):
            manualQuery = "\(library) \(collection)"
            guard hasAPIKey else { return }
            await fetchResults {
                try await client.searchByPresidentialMaterials(
                    library: library, collection: collection, maxResults: 3
                )
            }

        default:
            break
        }
    }

    /// Routes through the widened, anchor-excluding `archivalNeighbors(forVolumeId:
    /// documentId:)` entry point (the #217 "same set regardless of trigger" guarantee —
    /// see the iOS `SourceExplorerView` twin). Inline stays at the all-indexed default;
    /// the scope picker lives on the dedicated neighbors window.
    private func loadRelatedDocuments(for note: ParsedSourceNote) async {
        guard let pipeline = indexingPipeline else { return }
        relatedLoading = true
        do {
            let result: (documents: [IndexingPipeline.RelatedDocument], totalCount: Int)
            if let volId = documentVolumeId, let docId = documentId {
                // Anchored to an indexed document → the widened, anchor-excluding entry
                // point, identical to the dedicated neighbors surfaces (#217 parity).
                let r = try await pipeline.archivalNeighbors(
                    forVolumeId: volId, documentId: docId, documentYear: documentYear)
                result = (r.documents, r.totalCount)
            } else {
                // A source note explored without an indexed-document anchor: the
                // note-keyed query, nothing to exclude.
                result = try await pipeline.relatedDocuments(
                    for: note, limit: 30, documentYear: documentYear)
            }
            relatedDocs       = result.documents
            relatedTotalCount = result.totalCount
        } catch {
            #if DEBUG
            print("[SourceExplorer] Related documents query failed: \(error)")
            #endif
        }
        relatedLoading = false
    }

    /// Executes a NARA Catalog API operation and stores up to five ranked candidates
    /// (or an error message). Mirrors the iOS Source Explorer's multi-candidate list.
    private func fetchResults(_ operation: @Sendable () async throws -> [NARACatalogResult]) async {
        isLoading = true
        loadError = nil
        do {
            catalogResults = try await operation()
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Manual Search Action

    private func runManualSearch() async {
        let query = manualQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        await fetchResults { (try await client.searchCatalog(query: query)).map { [$0] } ?? [] }
    }

    // MARK: - Copy

    private func copyResultToClipboard() {
        guard let result = catalogResults.first else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(naraExportText(result), forType: .string)
    }

    // MARK: - Export

    private func exportCatalogResult() {
        guard let result = catalogResults.first else { return }
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
    /// `resolveRG59CentralFiles` is intentionally not used here: a catalog keyword search
    /// returns no useful results for decimal file identifiers, so period-based finding-aid
    /// routing replaces it.
    @ViewBuilder
    private func centralFilesPeriodBox(fileIdentifier: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let year = documentYear {
                // Resolved period. The file-number form resolves the Jan/Feb 1963 and 1973
                // mid-year era boundaries where the year alone is ambiguous.
                let label  = client.decimalFilePeriodLabel(year: year, fileIdentifier: fileIdentifier)
                let url    = client.decimalFilePeriodURL(year: year, fileIdentifier: fileIdentifier)
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
                if let manualURL = client.filingManualURL(year: year, fileIdentifier: fileIdentifier) {
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
    /// Shown once the source note has been parsed, with three states: a loading spinner, the
    /// list of matches, or an explicit empty-state explaining why there are none (the note
    /// isn't a recognized archival citation, or no other indexed document shares its
    /// collection) — rather than silently hiding the box.
    @ViewBuilder
    private var relatedDocumentsBox: some View {
        if relatedLoading || parsed != nil {
            GroupBox {
                VStack(alignment: .leading, spacing: 0) {
                    if relatedLoading {
                        HStack {
                            ProgressView().controlSize(.small).padding(.trailing, 6)
                            Text(String(localized: "source.explorer.related.loading",
                                        defaultValue: "Searching indexed volumes…"))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else if !relatedDocs.isEmpty {
                        // Composite key: related documents span volumes, and document
                        // ids are only unique within a single volume.
                        ForEach(relatedDocs, id: \.compositeKey) { doc in
                            Button {
                                onRelatedDocumentTapped?(doc.volumeId, doc.documentId)
                            } label: {
                                macRelatedDocumentRow(doc)
                            }
                            .buttonStyle(.plain)
                            if doc.compositeKey != relatedDocs.last?.compositeKey {
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
                    } else {
                        Text(relatedEmptyMessage)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if !relatedLoading, let key = parsed?.archivalNeighborKey {
                        Text(String(format: String(localized: "source.explorer.related.matchKey %@",
                                                   defaultValue: "Matching archival source: %@"), key))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 6)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                HStack {
                    Text(String(localized: "source.explorer.related.header",
                                defaultValue: "Archival Neighbors"))
                        .font(.headline.weight(.semibold))
                    Spacer()
                    if !relatedDocs.isEmpty {
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
    }

    /// Explains an empty related-documents result: an unmatched note type vs. a matched key
    /// with no neighbors in the indexed volumes.
    private var relatedEmptyMessage: String {
        if parsed?.supportsArchivalNeighbors == true {
            return String(localized: "source.explorer.related.empty.noNeighbors",
                          defaultValue: "No other indexed documents cite this archival source. Index more volumes to surface related documents.")
        } else {
            return String(localized: "source.explorer.related.empty.unmatched",
                          defaultValue: "This source note doesn't cite a recognized lot file, central file, or presidential library, so related documents can't be matched.")
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
