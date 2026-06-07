// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - SourceExplorerView

/// Sheet that displays parsed provenance information for a FRUS source note.
///
/// ## Layout
/// Presented as a sheet from `DocumentView` when the user taps the Source Explorer
/// toolbar button. Parses the raw source note on appear and displays provenance-specific UI.
///
/// ## Provenance-specific panels
/// | Provenance | Panel |
/// |---|---|
/// | Central files (RG-59) | Static NARA URL link — no API key required |
/// | Lot file | NARA Catalog result (requires API key) |
/// | Presidential library | NARA Catalog result (requires API key) |
/// | Foreign archive | Formatted text display |
/// | Previously published | Formatted citation display |
/// | Unrecognized | Raw text with explanation |
///
/// ## No API Key State
/// Panels that require an API key show a prompt with a Settings navigation link
/// rather than a loading spinner.
///
/// ## Log prefix
/// `[SourceExplorer]`
///
/// Version history:
///   1.0 — Session 23: initial implementation
///   1.1 — Session 94: replaced broken NavigationLink { EmptyView() } in noAPIKeyPrompt with
///          a localized instruction text pointing users to Settings → NARA Catalog API Key
///   1.2 — Session 118: `centralFilesPanel` button label changes to "Browse RG-59 in NARA
///          Catalog" when `fileIdentifier` is nil, avoiding the misleading "for This File"
///          label that appeared for narrative central-file notes with no extractable identifier
///   1.3 — Session 150: `variantControlNumber_is` lot file resolution; date-routed decimal
///          file period URLs; presidential library fallback URLs; CIA CREST link; multi-result
///          display (up to 5 candidates); specific error messages for 403/429/missing key;
///          manual-search fallback link when zero results
///   1.4 — Session 151: added `.cfpfFile` panel (CFPF FAQ PDF + AAD Electronic Telegrams);
///          expanded period table in `centralFilesPeriodSection` to include 1789–1906,
///          1906–1910, and 1963–1973; added per-period filing manual PDF links; fixed
///          `lotFilePanel` fallback URL for RG 84 F-designator lot files; fixed `load()`
///          to pass actual record group to `resolveLotFileVariants`
struct SourceExplorerView: View {

    // MARK: - Input

    /// Raw plain-text source note extracted from the TEI document.
    let rawSourceNote: String

    /// The year the FRUS document was created, used to route decimal-file and central-file
    /// citations to the correct NARA period-specific finding-aid page. When `nil`, the period
    /// table is shown without highlighting a specific period.
    var documentYear: Int? = nil

    /// The indexing pipeline used for same-collection document discovery.
    /// When `nil` the related documents section is not shown.
    var indexingPipeline: IndexingPipeline? = nil

    /// Called when the user taps a related document entry. Passes `(volumeId, documentId)`.
    /// The sheet dismisses itself before calling this closure.
    var onRelatedDocumentTapped: ((String, String) -> Void)? = nil

    // MARK: - Dependencies

    private let parser = SourceNoteParser()
    private let client = NARACatalogClient()

    // MARK: - State

    @State private var parsed: ParsedSourceNote? = nil
    /// Up to 5 NARA Catalog results; replaces the old single-result `catalogResult`.
    @State private var catalogResults: [NARACatalogResult] = []
    @State private var isLoading = false
    @State private var loadError: String? = nil
    @State private var hasAPIKey: Bool = false
    /// Same-collection document discovery results.
    @State private var relatedDocs: [IndexingPipeline.RelatedDocument] = []
    /// Total count of collection matches (may exceed the displayed slice).
    @State private var relatedTotalCount: Int = 0
    /// True while the related-documents query is running.
    @State private var relatedLoading: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(AppState.self) private var appState

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                rawNoteSection

                if let parsed {
                    provenanceSection(parsed: parsed)
                }

                if indexingPipeline != nil {
                    relatedDocumentsSection
                }
            }
            .navigationTitle(String(localized: "source.explorer.title",
                                    defaultValue: "Source Explorer"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "source.explorer.done",
                                  defaultValue: "Done")) {
                        dismiss()
                    }
                }
                // Contextual deep link into the Research Guide's "Understanding
                // What You're Reading" page — the source-note breakdown shown
                // here is exactly what that page explains in depth.
                ToolbarItem(placement: .secondaryAction) {
                    ResearchGuideLinkButton(
                        pageId: "understanding-documents",
                        label: String(localized: "source.explorer.learnMore",
                                      defaultValue: "Learn About Source Notes")
                    )
                }
            }
            .task {
                await load()
            }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 400)
        #endif
    }

    // MARK: - Raw Note Section

    private var rawNoteSection: some View {
        Section(String(localized: "source.explorer.rawNote.header",
                       defaultValue: "Source Note")) {
            Text(rawSourceNote)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    // MARK: - Provenance Section

    @ViewBuilder
    private func provenanceSection(parsed: ParsedSourceNote) -> some View {
        switch parsed {

        case .centralFiles(let rg, let fileId):
            centralFilesPanel(recordGroup: rg, fileIdentifier: fileId)

        case .cfpfFile(let fileId):
            cfpfPanel(fileIdentifier: fileId)

        case .lotFile(let rg, let lotNumber, let fileId):
            lotFilePanel(recordGroup: rg, lotNumber: lotNumber, fileIdentifier: fileId)

        case .naraCollection(let rg, let series, let lot, let box):
            naraCollectionPanel(recordGroup: rg, series: series, lotFile: lot, box: box)

        case .ciaCollection(let job, let box, let desc):
            ciaPanel(jobNumber: job, box: box, description: desc)

        case .presidentialLibrary(let library, let collection, let fileId):
            presidentialLibraryPanel(library: library, collection: collection, fileIdentifier: fileId)

        case .foreignGovernmentArchive(let desc):
            foreignArchivePanel(description: desc)

        case .previouslyPublished(let citation):
            previouslyPublishedPanel(citation: citation)

        case .unrecognized(let raw):
            unrecognizedPanel(rawText: raw)
        }
    }

    // MARK: - NARA Collection Panel (new case)

    @ViewBuilder
    private func naraCollectionPanel(recordGroup: String, series: String?, lotFile: String?, box: String?) -> some View {
        Section(String(localized: "source.explorer.provenance.header", defaultValue: "Provenance")) {
            LabeledContent(
                String(localized: "source.explorer.nara.repository", defaultValue: "Repository"),
                value: "National Archives and Records Administration"
            )
            LabeledContent(
                String(localized: "source.explorer.nara.rg", defaultValue: "Record Group"),
                value: "RG \(recordGroup)"
            )
            if let series  { LabeledContent(String(localized: "source.explorer.nara.series", defaultValue: "Series"), value: series) }
            if let lotFile  { LabeledContent(String(localized: "source.explorer.nara.lot", defaultValue: "Lot File"), value: lotFile) }
            if let box     { LabeledContent(String(localized: "source.explorer.nara.box", defaultValue: "Box"), value: box) }
        }
        let fb = client.resolveRG59CentralFiles(fileIdentifier: [series, lotFile].compactMap { $0 }.joined(separator: " "))
        naraResultSection(requiresKey: true, fallbackURL: fb)
    }

    // MARK: - CIA Panel (new case)

    @ViewBuilder
    private func ciaPanel(jobNumber: String?, box: String?, description: String) -> some View {
        Section(String(localized: "source.explorer.provenance.header", defaultValue: "Provenance")) {
            LabeledContent(
                String(localized: "source.explorer.cia.repository", defaultValue: "Repository"),
                value: "Central Intelligence Agency"
            )
            if let jobNumber { LabeledContent(String(localized: "source.explorer.cia.job", defaultValue: "Job/Accession No."), value: jobNumber) }
            if let box       { LabeledContent(String(localized: "source.explorer.cia.box", defaultValue: "Box"), value: box) }
        }
        Section(String(localized: "source.explorer.cia.header", defaultValue: "CIA Research")) {
            Button {
                openURL(client.ciaResearchURL(jobNumber: jobNumber))
            } label: {
                Label(
                    jobNumber != nil
                        ? String(localized: "source.explorer.cia.crestLink",
                                 defaultValue: "Search CIA CREST for This Job Number")
                        : String(localized: "source.explorer.cia.crestLinkGeneral",
                                 defaultValue: "Browse CIA CREST Database"),
                    systemImage: "arrow.up.right.square"
                )
            }
            Text(String(localized: "source.explorer.cia.note",
                        defaultValue: "CIA records are not in the NARA Catalog. The CREST database (cia.gov/readingroom) holds declassified CIA documents including operational files and historical collections."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - CFPF Panel (Central Foreign Policy Files 1973–1979)

    /// Panel for documents sourced from the State Dept. Central Foreign Policy Files (CFPF).
    ///
    /// CFPF records are on P-Reels, D-Reels, and N-Reels at NARA, and the electronic
    /// telegrams subset is searchable via the AAD database. No API key is required.
    @ViewBuilder
    private func cfpfPanel(fileIdentifier: String?) -> some View {
        Section(String(localized: "source.explorer.provenance.header",
                       defaultValue: "Provenance")) {
            LabeledContent(
                String(localized: "source.explorer.cfpf.type", defaultValue: "Type"),
                value: String(localized: "source.explorer.cfpf.typeValue",
                              defaultValue: "State Dept. Central Foreign Policy File (1973–1979)")
            )
            LabeledContent(
                String(localized: "source.explorer.cfpf.rg", defaultValue: "Record Group"),
                value: "RG 59"
            )
            if let fileIdentifier {
                LabeledContent(
                    String(localized: "source.explorer.cfpf.fileId",
                           defaultValue: "File Identifier"),
                    value: fileIdentifier
                )
            }
        }
        Section(String(localized: "source.explorer.cfpf.resources.header",
                       defaultValue: "Research Resources")) {
            Button {
                openURL(client.cfpfFAQURL)
            } label: {
                Label(
                    String(localized: "source.explorer.cfpf.faqLink",
                           defaultValue: "CFPF Research Guide (PDF)"),
                    systemImage: "doc.fill"
                )
            }
            Button {
                openURL(client.cfpfAADURL)
            } label: {
                Label(
                    String(localized: "source.explorer.cfpf.aadLink",
                           defaultValue: "Search AAD Electronic Telegrams Database"),
                    systemImage: "arrow.up.right.square"
                )
            }
            Text(String(localized: "source.explorer.cfpf.note",
                        defaultValue: "CFPF records are available on microfilm (P-Reels, D-Reels, N-Reels) at NARA and as electronic telegrams in the AAD database. No API key is required for either resource."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Central Files Panel

    @ViewBuilder
    private func centralFilesPanel(recordGroup: String, fileIdentifier: String?) -> some View {
        Section(String(localized: "source.explorer.provenance.header",
                       defaultValue: "Provenance")) {
            LabeledContent(
                String(localized: "source.explorer.centralFiles.type", defaultValue: "Type"),
                value: String(localized: "source.explorer.centralFiles.typeValue",
                              defaultValue: "State Dept. Central Files (RG \(recordGroup))")
            )
            if let fileIdentifier {
                LabeledContent(
                    String(localized: "source.explorer.centralFiles.identifier",
                           defaultValue: "File Identifier"),
                    value: fileIdentifier
                )
            }
        }

        // Period-specific NARA finding-aid routing — the primary resource for
        // State Dept. central files. Routes to archives.gov research pages for the
        // correct filing era (1789–1906, 1906–1910, decimal 1910–1963, or 1963–1973)
        // and links to the applicable filing manual PDF when one exists.
        // The old resolveRG59CentralFiles catalog-search URL is not used here because
        // catalog.archives.gov/search returns no useful results for decimal file numbers.
        if recordGroup == "RG-59" || recordGroup == "59" {
            centralFilesPeriodSection(fileIdentifier: fileIdentifier)
        }
    }

    /// Period-specific finding-aid section for RG-59 central files (1789–1973).
    ///
    /// When `documentYear` is available, shows the matching filing period, a link
    /// to the NARA finding-aid page, and (when applicable) a link to the filing
    /// manual PDF for that period. When unavailable, shows the full period table.
    @ViewBuilder
    private func centralFilesPeriodSection(fileIdentifier: String?) -> some View {
        Section(String(localized: "source.explorer.decimalPeriod.header",
                       defaultValue: "NARA Finding Aids by Period")) {
            if let year = documentYear {
                // Resolved period
                let periodLabel = client.decimalFilePeriodLabel(year: year)
                let periodURL   = client.decimalFilePeriodURL(year: year)
                LabeledContent(
                    String(localized: "source.explorer.decimalPeriod.matched",
                           defaultValue: "Filing Period"),
                    value: periodLabel
                )
                Button {
                    openURL(periodURL)
                } label: {
                    Label(
                        String(localized: "source.explorer.decimalPeriod.link",
                               defaultValue: "Open NARA Finding Aids for This Period"),
                        systemImage: "arrow.up.right.square"
                    )
                }
                if let manualURL = client.filingManualURL(year: year) {
                    Button {
                        openURL(manualURL)
                    } label: {
                        Label(
                            String(localized: "source.explorer.decimalPeriod.manualLink",
                                   defaultValue: "Filing Manual for This Period (PDF)"),
                            systemImage: "doc.fill"
                        )
                    }
                }
                Text(String(localized: "source.explorer.decimalPeriod.hint",
                            defaultValue: "Box lists, purport indexes, and the filing manual for this period are available on the linked NARA page."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                // No year available — show the full period table with filing manuals
                Text(String(localized: "source.explorer.decimalPeriod.noYear",
                            defaultValue: "Select the filing period that matches the document date:"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(Self.allFilingPeriods, id: \.id) { period in
                    VStack(alignment: .leading, spacing: 2) {
                        Button(period.label) {
                            openURL(period.url)
                        }
                        .font(.callout)
                        ForEach(period.filingManuals, id: \.url) { manual in
                            Button {
                                openURL(manual.url)
                            } label: {
                                Label(manual.label, systemImage: "doc.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
    }

    /// All State Dept. central-file filing periods, shown when document year is unknown.
    /// Internal (not private) so `MacSourceExplorerView` and `NARACatalogLookupView` can reference the same list.
    ///
    /// ## URL notes (verified 2026-06-04)
    /// - The seven 1910-1963 sub-period pages (`/1910-1963/1910-1929` etc.) all return 404.
    ///   NARA consolidated them onto one parent page; all seven now link to `/1910-1963`.
    /// - The 1789-1906 and 1906-1910 pages load correctly.
    /// - The 1963-1973 page loads correctly.
    /// - All filing manual PDFs are verified present.
    static let allFilingPeriods: [FilingPeriod] = {
        let base     = "https://www.archives.gov/research/foreign-policy/state-dept/rg-59-central-files"
        let manBase  = "https://www.archives.gov/files/research/foreign-policy/state-dept/finding-aids"
        let parent   = "\(base)/1910-1963"  // sub-period pages 404; parent is canonical

        func man(_ file: String, _ label: String) -> FilingManualLink {
            FilingManualLink(url: URL(string: "\(manBase)/\(file)")!, label: label)
        }
        let m1910 = man("manual-1910-49.pdf",                         "Filing Manual 1910–49 (PDF)")
        let m1950 = man("manual-1950-59.pdf",                         "Filing Manual 1950–59 (PDF)")
        let m1955 = man("manual-1955.pdf",                            "Filing Manual 1955 (PDF)")
        let m1960 = man("manual-1960-63.pdf",                         "Filing Manual 1960–63 (PDF)")
        let m1963 = man("records-classification-handbook-1963.pdf",   "Classification Handbook 1963 (PDF)")
        let m1965 = man("dos-records-classification-handbook-1965-1973.pdf",
                                                                      "Classification Handbook 1965–73 (PDF)")

        return [
            FilingPeriod(id: "1789-1906", label: "1789–1906",
                         url: URL(string: "\(base)/1789-1906")!),

            FilingPeriod(id: "1906-1910", label: "1906–1910",
                         url: URL(string: "\(base)/1906-1910")!),

            FilingPeriod(id: "1910-1929", label: "1910–1929 (decimal files)",
                         url: URL(string: parent)!,
                         filingManuals: [m1910]),

            FilingPeriod(id: "1930-1939", label: "1930–1939 (decimal files)",
                         url: URL(string: parent)!,
                         filingManuals: [m1910]),

            FilingPeriod(id: "1940-1944", label: "1940–1944 (decimal files)",
                         url: URL(string: parent)!,
                         filingManuals: [m1910]),

            FilingPeriod(id: "1945-1949", label: "1945–1949 (decimal files)",
                         url: URL(string: parent)!,
                         filingManuals: [m1910]),

            FilingPeriod(id: "1950-1954", label: "1950–1954 (decimal files)",
                         url: URL(string: parent)!,
                         filingManuals: [m1950]),

            FilingPeriod(id: "1955-1959", label: "1955–1959 (decimal files)",
                         url: URL(string: parent)!,
                         filingManuals: [m1955]),

            FilingPeriod(id: "1960-1963", label: "1960–January 1963 (decimal files)",
                         url: URL(string: parent)!,
                         filingManuals: [m1960]),

            // 1963-1973: two filing manuals because the period spans two classification systems.
            FilingPeriod(id: "1963-1973", label: "1963–1973 (subject-numeric files)",
                         url: URL(string: "\(base)/1963-1973")!,
                         filingManuals: [m1963, m1965]),
        ]
    }()

    // MARK: - Lot File Panel

    @ViewBuilder
    private func lotFilePanel(recordGroup: String?, lotNumber: String, fileIdentifier: String?) -> some View {
        Section(String(localized: "source.explorer.provenance.header",
                       defaultValue: "Provenance")) {
            LabeledContent(
                String(localized: "source.explorer.lotFile.type", defaultValue: "Type"),
                value: {
                    let rg = recordGroup ?? "RG-59"
                    if rg == "RG-84" {
                        return String(localized: "source.explorer.lotFile.typeValueRG84",
                                      defaultValue: "State Dept. Post Records Lot File (RG 84)")
                    }
                    return String(localized: "source.explorer.lotFile.typeValue",
                                  defaultValue: "State Dept. Lot File")
                }()
            )
            if let rg = recordGroup {
                LabeledContent(
                    String(localized: "source.explorer.lotFile.rg", defaultValue: "Record Group"),
                    value: rg.replacingOccurrences(of: "RG-", with: "RG ")
                )
            }
            LabeledContent(
                String(localized: "source.explorer.lotFile.lot", defaultValue: "Lot Number"),
                value: lotNumber
            )
            if let fileIdentifier {
                LabeledContent(
                    String(localized: "source.explorer.lotFile.fileId",
                           defaultValue: "File Identifier"),
                    value: fileIdentifier
                )
            }
        }

        // Fallback: pre-scoped NARA Catalog search for the lot number.
        // Use RG 84 fallback URL for F-designator (post record) lot files.
        let fb: URL = {
            let rg = recordGroup ?? "RG-59"
            if rg == "RG-84" {
                return client.resolveRG84LotFile(lotNumber: lotNumber)
            }
            return client.resolveRG59CentralFiles(fileIdentifier: "Lot \(lotNumber)")
        }()
        naraResultSection(requiresKey: true, fallbackURL: fb)
    }

    // MARK: - Presidential Library Panel

    @ViewBuilder
    private func presidentialLibraryPanel(
        library: String,
        collection: String,
        fileIdentifier: String?
    ) -> some View {
        Section(String(localized: "source.explorer.provenance.header",
                       defaultValue: "Provenance")) {
            LabeledContent(
                String(localized: "source.explorer.presLib.type", defaultValue: "Type"),
                value: String(localized: "source.explorer.presLib.typeValue",
                              defaultValue: "Presidential Library")
            )
            LabeledContent(
                String(localized: "source.explorer.presLib.library", defaultValue: "Library"),
                value: library
            )
            if !collection.isEmpty {
                LabeledContent(
                    String(localized: "source.explorer.presLib.collection",
                           defaultValue: "Collection"),
                    value: collection
                )
            }
            if let fileIdentifier {
                LabeledContent(
                    String(localized: "source.explorer.presLib.fileId",
                           defaultValue: "File Identifier"),
                    value: fileIdentifier
                )
            }
        }

        // Fallback: institution-specific finding-aid URL when API returns zero results
        let fallback = client.libraryFallbackURL(libraryName: library)
        naraResultSection(requiresKey: true, fallbackURL: fallback)
    }

    // MARK: - Foreign Archive Panel

    @ViewBuilder
    private func foreignArchivePanel(description: String) -> some View {
        Section(String(localized: "source.explorer.provenance.header",
                       defaultValue: "Provenance")) {
            LabeledContent(
                String(localized: "source.explorer.foreignArchive.type", defaultValue: "Type"),
                value: String(localized: "source.explorer.foreignArchive.typeValue",
                              defaultValue: "Foreign Government Archive")
            )
            Text(description)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }

        Section {
            Text(String(localized: "source.explorer.foreignArchive.note",
                        defaultValue: "Foreign government archives are not indexed in the NARA Catalog. Consult the archive directly for access."))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Previously Published Panel

    @ViewBuilder
    private func previouslyPublishedPanel(citation: String) -> some View {
        Section(String(localized: "source.explorer.provenance.header",
                       defaultValue: "Provenance")) {
            LabeledContent(
                String(localized: "source.explorer.published.type", defaultValue: "Type"),
                value: String(localized: "source.explorer.published.typeValue",
                              defaultValue: "Previously Published")
            )
            Text(citation)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }

        Section {
            Text(String(localized: "source.explorer.published.note",
                        defaultValue: "This document was previously published. Consult the cited publication for the original source."))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Unrecognized Panel

    @ViewBuilder
    private func unrecognizedPanel(rawText: String) -> some View {
        Section(String(localized: "source.explorer.provenance.header",
                       defaultValue: "Provenance")) {
            LabeledContent(
                String(localized: "source.explorer.unrecognized.type", defaultValue: "Type"),
                value: String(localized: "source.explorer.unrecognized.typeValue",
                              defaultValue: "Unrecognized Format")
            )
        }

        Section {
            Text(String(localized: "source.explorer.unrecognized.explanation",
                        defaultValue: "The source note format was not recognized. The raw text is shown above. Automated NARA Catalog resolution is unavailable for this entry."))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - NARA Result Section (API-dependent)

    /// Renders the NARA Catalog API result area.
    ///
    /// - Parameters:
    ///   - requiresKey: Whether an API key is needed for this citation type.
    ///   - fallbackURL: Shown as a manual-search link when results are empty.
    ///                  Typically a pre-scoped NARA Catalog search URL or an
    ///                  institution-specific finding-aid URL.
    @ViewBuilder
    private func naraResultSection(
        requiresKey: Bool,
        fallbackURL: URL? = nil
    ) -> some View {
        Section(String(localized: "source.explorer.nara.header", defaultValue: "NARA Catalog")) {
            if requiresKey && !hasAPIKey {
                noAPIKeyPrompt
            } else if isLoading {
                HStack {
                    ProgressView().padding(.trailing, 8)
                    Text(String(localized: "source.explorer.nara.loading",
                                defaultValue: "Searching NARA Catalog…"))
                        .foregroundStyle(.secondary)
                }
            } else if let error = loadError {
                VStack(alignment: .leading, spacing: 6) {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.callout)
                    if let fb = fallbackURL {
                        Button {
                            openURL(fb)
                        } label: {
                            Label(
                                String(localized: "source.explorer.nara.searchManually",
                                       defaultValue: "Search NARA Catalog Manually"),
                                systemImage: "arrow.up.right.square"
                            )
                            .font(.callout)
                        }
                    }
                }
            } else if !catalogResults.isEmpty {
                // Up to 5 ranked candidates
                ForEach(catalogResults.prefix(5), id: \.naId) { result in
                    catalogResultRow(result: result)
                    if result.naId != catalogResults.prefix(5).last?.naId {
                        Divider()
                    }
                }
            } else {
                // Zero results — show an honest message and a manual-search fallback
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "source.explorer.nara.noResult",
                                defaultValue: "No matching record found in the NARA Catalog."))
                        .foregroundStyle(.secondary)
                        .font(.callout)
                    if let fb = fallbackURL {
                        Button {
                            openURL(fb)
                        } label: {
                            Label(
                                String(localized: "source.explorer.nara.searchManually",
                                       defaultValue: "Search NARA Catalog Manually"),
                                systemImage: "arrow.up.right.square"
                            )
                            .font(.callout)
                        }
                    }
                }
            }
        }
    }

    private var noAPIKeyPrompt: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(
                String(localized: "source.explorer.noKey.label",
                       defaultValue: "NARA Catalog API Key Required"),
                systemImage: "key"
            )
            .font(.callout.weight(.medium))
            Text(String(localized: "source.explorer.noKey.explanation",
                        defaultValue: "A free NARA Catalog API key is required to search for lot file and Presidential Library records. Add your key in Settings → NARA API."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func catalogResultRow(result: NARACatalogResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(result.title)
                .font(.callout.weight(.medium))
            if let scope = result.scopeNote {
                Text(scope)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
            if let dateRange = result.dateRange {
                Text(dateRange)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Button {
                openURL(result.catalogURL)
            } label: {
                Label(
                    String(localized: "source.explorer.nara.viewRecord",
                           defaultValue: "View in NARA Catalog"),
                    systemImage: "arrow.up.right.square"
                )
                .font(.callout)
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Load

    private func load() async {
        let note = SourceNoteParser().parse(rawSourceNote)
        parsed = note

        // Local related-documents query — runs unconditionally; no API key needed.
        // Must be called before the hasAPIKey guard so it runs even for users
        // who have not configured a NARA Catalog API key.
        await loadRelatedDocuments(for: note)

        hasAPIKey = await client.hasAPIKey()
        guard hasAPIKey else { return }

        switch note {

        case .lotFile(let rg, let lotNumber, _):
            // Use variantControlNumber_is with three normalised lot number forms,
            // falling back to a phrase query if all variants return zero results.
            // Strip the "RG-" prefix to get the bare record group number for the API.
            let rgToUse = (rg ?? "RG-59").replacingOccurrences(of: "RG-", with: "")
            await fetchResults { try await client.resolveLotFileVariants(lotNumber: lotNumber, recordGroup: rgToUse) }

        case .naraCollection(let rg, let series, let lot, _):
            let keywords = [series, lot].compactMap { $0 }.joined(separator: " ")
            await fetchResults { try await client.searchByRecordGroup(rg, keywords: keywords, maxResults: 5) }

        case .presidentialLibrary(let library, let collection, _):
            await fetchResults {
                try await client.searchByPresidentialMaterials(
                    library: library, collection: collection, maxResults: 3
                )
            }

        default:
            break
        }
    }

    /// Queries the local index for documents from the same archival collection.
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

    /// Executes an API operation and stores the results (or an error message).
    private func fetchResults(_ operation: @Sendable () async throws -> [NARACatalogResult]) async {
        isLoading = true
        loadError = nil
        do {
            let results = try await operation()
            catalogResults = results
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Related Documents Section

    /// Section displaying documents from the same archival collection or file series.
    ///
    /// Shown only when `indexingPipeline` is non-nil. Loading happens asynchronously;
    /// a spinner is shown while the query runs. An empty result is hidden silently.
    @ViewBuilder
    private var relatedDocumentsSection: some View {
        if relatedLoading {
            Section(String(localized: "source.explorer.related.header",
                           defaultValue: "Documents from This Collection")) {
                HStack {
                    ProgressView().padding(.trailing, 8)
                    Text(String(localized: "source.explorer.related.loading",
                                defaultValue: "Searching indexed volumes…"))
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            }
        } else if !relatedDocs.isEmpty {
            Section {
                ForEach(relatedDocs, id: \.documentId) { doc in
                    Button {
                        dismiss()
                        onRelatedDocumentTapped?(doc.volumeId, doc.documentId)
                    } label: {
                        relatedDocumentRow(doc)
                    }
                    .buttonStyle(.plain)
                }
                if relatedTotalCount > relatedDocs.count {
                    Text(String(localized: "source.explorer.related.overflow",
                                defaultValue: "\(relatedTotalCount - relatedDocs.count) more documents not shown"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
            } header: {
                HStack {
                    Text(String(localized: "source.explorer.related.header",
                                defaultValue: "Documents from This Collection"))
                    Spacer()
                    Text("\(relatedTotalCount)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        // When relatedDocs is empty and not loading: show nothing (clean UX for
        // documents from volumes not yet indexed or without collection matches)
    }

    @ViewBuilder
    private func relatedDocumentRow(_ doc: IndexingPipeline.RelatedDocument) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top) {
                if let num = doc.documentNumber {
                    Text(num)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 28, alignment: .trailing)
                        .padding(.trailing, 2)
                }
                Text(doc.header.isEmpty ? doc.documentId : doc.header)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            HStack(spacing: 8) {
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
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

// MARK: - FilingManualLink

/// A NARA filing manual PDF paired with a display label.
struct FilingManualLink: Sendable {
    let url: URL
    let label: String
}

// MARK: - FilingPeriod

/// A named NARA filing period for State Dept. central files, used in the
/// period-selection table shown when document year is unknown.
struct FilingPeriod: Sendable {
    let id: String
    let label: String
    let url: URL
    /// Filing manual PDFs that apply to this period. Empty for pre-1910 periods
    /// and other periods where NARA has not published a relevant manual.
    let filingManuals: [FilingManualLink]

    init(id: String, label: String, url: URL, filingManuals: [FilingManualLink] = []) {
        self.id = id
        self.label = label
        self.url = url
        self.filingManuals = filingManuals
    }
}
