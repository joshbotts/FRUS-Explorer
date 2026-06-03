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
struct SourceExplorerView: View {

    // MARK: - Input

    /// Raw plain-text source note extracted from the TEI document.
    let rawSourceNote: String

    /// The year the FRUS document was created, used to route decimal-file and central-file
    /// citations to the correct NARA period-specific finding-aid page. When `nil`, the period
    /// table is shown without highlighting a specific period.
    var documentYear: Int? = nil

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

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                rawNoteSection

                if let parsed {
                    provenanceSection(parsed: parsed)
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

        // Date-routed period section — only for RG-59 (decimal files and central files)
        if recordGroup == "59" {
            centralFilesPeriodSection(fileIdentifier: fileIdentifier)
        }

        Section(String(localized: "source.explorer.nara.header", defaultValue: "NARA Catalog")) {
            Button {
                let url = client.resolveRG59CentralFiles(fileIdentifier: fileIdentifier ?? "")
                openURL(url)
            } label: {
                if fileIdentifier != nil {
                    Label(
                        String(localized: "source.explorer.centralFiles.naraLink",
                               defaultValue: "Search NARA Catalog for This File"),
                        systemImage: "arrow.up.right.square"
                    )
                } else {
                    Label(
                        String(localized: "source.explorer.centralFiles.naraLinkGeneral",
                               defaultValue: "Browse RG-59 in NARA Catalog"),
                        systemImage: "arrow.up.right.square"
                    )
                }
            }
            Text(String(localized: "source.explorer.centralFiles.noKeyNote",
                        defaultValue: "Central file searches open directly in your browser — no API key required."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Period-specific finding-aid section for RG-59 decimal and central files.
    ///
    /// When `documentYear` is available, highlights the matching period and links
    /// to the NARA finding-aid page for that period. When unavailable, shows the
    /// full period table so the researcher can locate the right page manually.
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
                Text(String(localized: "source.explorer.decimalPeriod.hint",
                            defaultValue: "Box lists, purport indexes, and the filing manual for this period are available on the linked NARA page."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                // No year available — show the full period table
                Text(String(localized: "source.explorer.decimalPeriod.noYear",
                            defaultValue: "Select the filing period that matches the document date:"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach([
                    ("1910–1929", "1910-1929"),
                    ("1930–1939", "1930-1939"),
                    ("1940–1944", "1940-1944"),
                    ("1945–1949", "1945-1949"),
                    ("1950–1954", "1950-1954"),
                    ("1955–1959", "1955-1959"),
                    ("1960–Jan 1963", "1960-1963"),
                ], id: \.1) { label, slug in
                    Button(label) {
                        let url = URL(string: "https://www.archives.gov/research/foreign-policy/"
                                     + "state-dept/rg-59-central-files/1910-1963/\(slug)")!
                        openURL(url)
                    }
                    .font(.callout)
                }
            }
        }
    }

    // MARK: - Lot File Panel

    @ViewBuilder
    private func lotFilePanel(recordGroup: String?, lotNumber: String, fileIdentifier: String?) -> some View {
        Section(String(localized: "source.explorer.provenance.header",
                       defaultValue: "Provenance")) {
            LabeledContent(
                String(localized: "source.explorer.lotFile.type", defaultValue: "Type"),
                value: String(localized: "source.explorer.lotFile.typeValue",
                              defaultValue: "State Dept. Lot File")
            )
            if let rg = recordGroup {
                LabeledContent(
                    String(localized: "source.explorer.lotFile.rg", defaultValue: "Record Group"),
                    value: "RG \(rg)"
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

        // Fallback: pre-scoped NARA Catalog search for the lot number
        let rg = "59"
        let fb = client.resolveRG59CentralFiles(fileIdentifier: "Lot \(lotNumber)")
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

        hasAPIKey = await client.hasAPIKey()
        guard hasAPIKey else { return }

        switch note {

        case .lotFile(let rg, let lotNumber, _):
            // Use variantControlNumber_is with three normalised lot number forms,
            // falling back to a phrase query if all variants return zero results.
            let rgToUse = rg ?? "59"
            _ = rgToUse   // rg is used only for non-59 fallback path
            await fetchResults { try await client.resolveLotFileVariants(lotNumber: lotNumber) }

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
}
