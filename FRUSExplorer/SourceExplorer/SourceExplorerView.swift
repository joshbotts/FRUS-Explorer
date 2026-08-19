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
///   1.5 — Session 2026-07-03 (Source Explorer Phase 4 step 2): Archival Collection
///          section — when the parsed note's keys land in the bundled cross-volume
///          authority (`CollectionAuthorityStore.record(forParsed:note:)`), links to
///          the shared Collection detail (aliases, NAID, S5 local counts, citing
///          volumes); "Browse Archival Collections" pushes the searchable
///          browse-by-collection list
///   1.6 — #315: `bundledLotSection` shows the HMS/MLR entry number(s) and, for
///          file-unit records, the enclosing File Series (`displaySeriesTitle`) with the
///          series' entry numbers labeled as the series'; citation-guidance captions on
///          the lot, central-files, and CFPF panels name what to hand a NARA archivist.
///          Flagged mis-resolutions (#321, `ancestryLacksRecordGroup` — measured 0/16
///          precision) are treated as unresolved by `lotFile(forRawLot:)` and fall back
///          to the live lookup. Mirrors MacSourceExplorerView 1.6.
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

    /// Document heading — a classifier cue for pre-1906 documents (which carry no source note).
    var documentHeader: String? = nil

    /// Document dateline — the primary classifier cue (originating office + date).
    var documentDateline: String? = nil

    /// The document's volume and `xml:id`, used to resolve its FRUS chapter (country) from
    /// the cached volume structure for pre-1906 series classification.
    var documentVolumeId: String? = nil
    var documentId: String? = nil

    // MARK: - Dependencies

    private let parser = SourceNoteParser()
    private let client = NARACatalogClient()

    // MARK: - State

    @State private var parsed: ParsedSourceNote? = nil
    /// Up to 5 NARA Catalog results; replaces the old single-result `catalogResult`.
    @State private var catalogResults: [NARACatalogResult] = []
    @State private var isLoading = false
    @State private var loadError: String? = nil
    /// What the live catalogue results are evidence of (#681). Set alongside the
    /// query so the heading and the caveat cannot describe a query never issued.
    @State private var catalogEvidence: CatalogQueryEvidence? = nil
    /// What the bundled presidential-library catalogue says about this citation (#681).
    /// Resolved in `load()` rather than in `body` — it reads a 3.1 MB bundle and the panel
    /// re-renders on every state change.
    @State private var libraryOutcome: PresidentialLibraryOutcome = .none
    @State private var hasAPIKey: Bool = false
    /// Same-collection document discovery results.
    @State private var relatedDocs: [IndexingPipeline.RelatedDocument] = []
    /// Total count of collection matches (may exceed the displayed slice).
    @State private var relatedTotalCount: Int = 0
    /// True while the related-documents query is running.
    @State private var relatedLoading: Bool = false

    /// Pre-1906 country-series classifications + the rolls each resolves to (Phase 2).
    @State private var countryResolutions: [CountrySeriesResolution] = []

    /// The bundled cross-volume authority record the parsed note resolves to (Phase 4),
    /// or `nil` when the note's keys land in no tracked collection.
    @State private var authorityRecord: AuthorityCollectionRecord? = nil
    /// This document's footnote pointers at material FRUS did not print, in reading order,
    /// each paired with the authority record it resolves to when it resolves to one.
    @State private var unprintedPointers: [UnprintedPointer] = []

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(AppState.self) private var appState

    /// Whether the document actually carries an archival source note. When `false` (chiefly
    /// pre-1906 documents, which carry none), the explorer leads with the country-series
    /// classification heuristic rather than presenting an "unrecognized note" parse failure.
    private var hasSourceNote: Bool {
        !rawSourceNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                if hasSourceNote {
                    rawNoteSection
                }

                // Only parse provenance when a note exists; an absent note is not an
                // "unrecognized" one.
                if hasSourceNote, let parsed {
                    provenanceSection(parsed: parsed)
                }

                if !countryResolutions.isEmpty {
                    countrySeriesSection
                } else if !hasSourceNote {
                    noSourceNoteSection
                }

                if indexingPipeline != nil {
                    relatedDocumentsSection
                }

                archivalCollectionSection

                if !unprintedPointers.isEmpty {
                    unprintedPointersSection
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
                ToolbarItem(placement: .primaryAction) {
                    FeatureInfoButton.sourceExplorer
                }
            }
            // Keyed, not bare: this view is a sheet on iPhone/iPad and so is rebuilt per
            // presentation today — but its macOS twin is hosted in a persistent Window,
            // where a bare `.task` pinned every derived value to the first document ever
            // opened. Keying here costs nothing and removes the latent version of that bug
            // for any future host that keeps this view alive across documents.
            .task(id: loadIdentity) {
                await load()
            }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 400)
        #endif
    }

    // MARK: - Archival Collection Section (Phase 4)

    /// The cross-volume collection surface: when the parsed note resolves to a bundled
    /// authority record, a link to the shared Collection detail (pushed within this
    /// sheet's `NavigationStack`); always, the browse-by-collection entry point.
    @ViewBuilder
    private var archivalCollectionSection: some View {
        Section {
            if let record = authorityRecord {
                NavigationLink {
                    CollectionDetailView(record: record)
                        .environment(appState)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.name)
                            .font(.callout)
                        Text(String(format: String(
                            localized: "source.explorer.collection.cited %lld",
                            defaultValue: "Cited in %lld volumes across the series"),
                            Int64(record.volumeIds.count)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            NavigationLink {
                CollectionBrowserView()
                    .environment(appState)
            } label: {
                Label(String(localized: "source.explorer.collection.browse",
                             defaultValue: "Browse Archival Collections"),
                      systemImage: "archivebox")
            }
        } header: {
            Text(String(localized: "source.explorer.collection.header",
                        defaultValue: "Archival Collection"))
        } footer: {
            if authorityRecord != nil {
                Text(String(localized: "source.explorer.collection.footer",
                            defaultValue: "Matched against the bundled cross-volume collection authority."))
            }
        }
    }

    // MARK: - Unprinted Material (#829a)

    /// One footnote pointer, with whatever the render-time join could make of it.
    struct UnprintedPointer: Identifiable, Equatable {
        /// The stored citation.
        let citation: ExternalCitation
        /// The authority record it resolved to, when it did.
        let record: AuthorityCollectionRecord?
        var id: String { "\(citation.noteOrdinal)|\(citation.id)" }
    }

    /// Where this document's own footnotes sent the reader, outside the printed record.
    ///
    /// **The most targeted "beyond FRUS" pointer the app can make**, and the third distinct body of
    /// archival evidence: the source note above says where this document was *drawn from*; this says
    /// what its footnotes *pointed at* and FRUS did not print. The two are never combined — that
    /// addition is the defect #783 removed.
    ///
    /// Rows are in **reading order** (`note_ordinal`, then citation index), so the list runs down the
    /// document the way the footnotes do rather than being re-sorted into a ranking.
    @ViewBuilder
    private var unprintedPointersSection: some View {
        Section {
            ForEach(unprintedPointers) { pointer in
                if let record = pointer.record {
                    NavigationLink {
                        CollectionDetailView(record: record)
                            .environment(appState)
                    } label: {
                        unprintedRow(pointer)
                    }
                } else {
                    // **Inert, with no chevron.** The corpus generator joined 96.0% of references at
                    // aggregate grain, so misses are guaranteed here at per-document grain. A row
                    // that offered navigation and then failed, or silently guessed a neighbouring
                    // collection, would be worse than one that simply states what the footnote said.
                    unprintedRow(pointer)
                }
            }
        } header: {
            Text(String(localized: "source.explorer.unprinted.header",
                        defaultValue: "Unprinted Material"))
        } footer: {
            Text(String(localized: "source.explorer.unprinted.footer",
                        defaultValue: "Archival units this document's footnotes name but FRUS did not print. Separate from the source note above, which records where this document itself was drawn from."))
        }
    }

    /// One pointer's row.
    /// - Parameter pointer: The citation and its resolution.
    /// - Returns: The row.
    @ViewBuilder
    private func unprintedRow(_ pointer: UnprintedPointer) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: pointer.citation.displayLabel)
                .font(.callout)
            HStack(spacing: 6) {
                if let fileId = pointer.citation.fileId, !fileId.isEmpty {
                    Text(verbatim: fileId)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if pointer.citation.inherited {
                    // The unit came from an `Ibid.`, not from a phrase of its own. Marked because a
                    // reader checking the printed page will not find these words in this footnote.
                    Label(String(localized: "source.explorer.unprinted.inherited",
                                 defaultValue: "Carried from the previous note"),
                          systemImage: "arrow.turn.up.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .labelStyle(.titleAndIcon)
                }
            }
        }
        .padding(.vertical, 2)
    }

    /// Resolves one stored citation to an authority record.
    ///
    /// **The rows carry no authority id**, so this is the render-time join #829 specifies: the lot
    /// key first, else the repository plus the collection's leading segment — composed exactly as
    /// `ArchivalLibraryProfile.resolve` does, **including the #351 library→lot domain guard**, which
    /// stops a presidential-library citation from matching a lot-file record that happens to share a
    /// leading word.
    ///
    /// - Parameters:
    ///   - citation: The stored row.
    ///   - authority: The bundled authority.
    /// - Returns: The record, or `nil` when nothing matches under the guard.
    /// `nonisolated` because the caller runs it inside a detached task: `SourceExplorerView` is a
    /// `View` and therefore implicitly `@MainActor`, so a plain `static func` here is main-actor
    /// isolated and calling it off the main actor is a strict-concurrency warning. The body touches
    /// only value types and the `Sendable` authority index, which is what makes the annotation
    /// honest rather than a silencer.
    nonisolated static func resolve(_ citation: ExternalCitation,
                                    authority: CollectionAuthorityIndex) -> AuthorityCollectionRecord? {
        ExternalCitationAuthorityJoin.record(lotFileNorm: citation.lotFileNorm,
                                             collectionName: citation.collection,
                                             repository: citation.repository,
                                             authority: authority)
    }

    // MARK: - Raw Note Section

    private var rawNoteSection: some View {
        Section(String(localized: "source.explorer.rawNote.header",
                       defaultValue: "Source Note")) {
            VStack(alignment: .leading, spacing: 6) {
                Text(rawSourceNote)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                // Phase 5: the S1 classification markings (sentence 2 of the note when
                // it matches the marking vocabulary), as a quiet semantic chip.
                if let marking = SourceNoteParser.classificationMarking(fromSourceNote: rawSourceNote) {
                    ClassificationChip(marking: marking)
                }
            }
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

        case .namedFileSeries(let series, let fileId):
            namedFileSeriesPanel(seriesName: series, fileIdentifier: fileId)

        case .foreignGovernmentArchive(let desc):
            foreignArchivePanel(description: desc)

        case .previouslyPublished(let citation):
            previouslyPublishedPanel(citation: citation)

        case .unrecognized(let raw):
            unrecognizedPanel(rawText: raw)
        }
    }

    // MARK: - Named File Series Panel

    /// Provenance panel for a named office-file series or manuscript collection cited
    /// without a lot number or repository (`.namedFileSeries`). The series name is the
    /// key the Phase 3/4 collection-authority work will resolve; no NARA query exists
    /// yet for this case.
    @ViewBuilder
    private func namedFileSeriesPanel(seriesName: String, fileIdentifier: String?) -> some View {
        // A collection cited by name alone still has whatever archival answer curation
        // established for it under its lot number — "CFM Files" is cited both ways, and
        // before this lookup the 376 name-only citations saw nothing (#375).
        let curated = CuratedLotResolutionsStore.shared?.record(forSeriesName: seriesName)

        Section(String(localized: "source.explorer.provenance.header", defaultValue: "Provenance")) {
            LabeledContent(
                String(localized: "source.explorer.namedSeries.series", defaultValue: "File Series"),
                value: seriesName
            )
            if let rg = CuratedLotResolutionsStore.shared?.recordGroup(forSeriesName: seriesName) {
                LabeledContent(
                    String(localized: "source.explorer.lotFile.rg", defaultValue: "Record Group"),
                    value: rg.replacingOccurrences(of: "RG-", with: "RG ")
                )
            }
            if let fileIdentifier {
                LabeledContent(
                    String(localized: "source.explorer.namedSeries.file", defaultValue: "File"),
                    value: fileIdentifier
                )
            }
            if curated == nil {
                Text(String(localized: "source.explorer.namedSeries.explainer",
                            defaultValue: "A named file series cited without a lot number. The repository is not stated in the citation."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        if let outcome = CuratedLotResolutionsStore.shared?.outcome(forSeriesName: seriesName) {
            curatedLotSection(outcome)
        }

        // #354 item 1: the citation states no repository, so until now 5,369 of these 5,745
        // documents were told only that. Where the volume's own Sources section says where the
        // series is — or the name states a Foreign Service post — say it.
        if let routing = NamedFileSeriesRouting.routing(forSeriesName: seriesName) {
            namedSeriesRoutingSection(routing)
        }
    }

    // MARK: - Named File Series Routing

    /// Where a series cited by name alone is held (#354 item 1).
    ///
    /// The evidence line is the point, not decoration: it is the FRUS editors' own sentence
    /// about this series, so the researcher can judge the destination rather than trust it.
    @ViewBuilder
    private func namedSeriesRoutingSection(_ routing: NamedFileSeriesRouting.Entry) -> some View {
        Section(NamedFileSeriesRouting.sectionTitle) {
            VStack(alignment: .leading, spacing: 4) {
                Text(NamedFileSeriesRouting.label(routing))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(NamedFileSeriesRouting.title(routing))
                    .font(.callout.weight(.medium))
                if let url = NamedFileSeriesRouting.url(routing) {
                    Button {
                        openURL(url)
                    } label: {
                        Label(NamedFileSeriesRouting.linkLabel(routing),
                              systemImage: "arrow.up.right.square")
                        .font(.callout)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.vertical, 4)

            Text(routing.evidence)
                .font(.caption)
                .foregroundStyle(.secondary)
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
            // #315: the CFPF variant of the central-files citation guidance — telegram
            // channel/serial numbers are the primary locator in this era's files.
            Text(String(localized: "source.explorer.cfpf.cite.note",
                        defaultValue: "To request the original record from NARA, give them the file identifier above. Add any telegram channel and serial numbers, the from/to information, and the document's date from the source note."))
                .font(.caption)
                .foregroundStyle(.secondary)
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
                // `recordGroup` already carries the "RG-" prefix (e.g. "RG-59"), so interpolating
                // it after a literal "RG " rendered "State Dept. Central Files (RG RG-59)".
                // Normalised to "RG 59", matching the Record Group row in `lotFilePanel` and the
                // macOS panel, which now share this one text under this one key.
                value: String(localized: "source.explorer.centralFiles.typeValue",
                              defaultValue: "State Dept. Central Files (\(recordGroup.replacingOccurrences(of: "RG-", with: "RG ")))")
            )
            if let fileIdentifier {
                LabeledContent(
                    String(localized: "source.explorer.centralFiles.identifier",
                           defaultValue: "File Identifier"),
                    value: fileIdentifier
                )
            }
            // #315: what to hand a NARA archivist. Central-files records are located
            // within the decimal file by their full citation details, so the guidance
            // names each element a request should carry. Guidance text only — the
            // discrete serial/from-to fields are deliberately NOT parsed (that would
            // touch the shared SourceNoteKit grammar and force a corpus re-index).
            Text(String(localized: "source.explorer.centralFiles.cite.note",
                        defaultValue: "To request the original record from NARA, give them the decimal file number above. Add any telegram serial number, the from/to information, and the document's date from the source note. Archivists use these details to find the record within the file."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        // 1906–1910 Numerical File: resolve the exact digitized roll(s) for this
        // File No. from the bundled index — a direct, page-by-page-ready catalog link
        // with no API key required.
        if let fileIdentifier, let year = documentYear, (1906...1910).contains(year) {
            numericalFileSection(fileIdentifier: fileIdentifier)
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

        // #354: RG 256 is not a State Department central file, so neither section above
        // applies to it, and until now these 1,547 documents ended at the Provenance rows.
        // The Commission's records resolve to two hand-verified catalog records plus NARA's
        // own finding aids for them — the same answer for every citation, so a constant.
        if ParisPeaceRecords.applies(recordGroup: recordGroup) {
            parisPeaceSection()
        }

        // #663: NARA has scanned parts of the decimal file. Where this citation's serial lands
        // in a digitised range, link it — as a *range*, never as this document.
        if let fileIdentifier {
            digitizedScansSection(fileIdentifier: fileIdentifier)
        }
    }

    // MARK: - Digitised Scans

    /// NARA's own scans for the file range a decimal citation names (#663).
    ///
    /// Three states, and the middle one is why this is not a single link. **4.6% of adjacent
    /// ranges within a class overlap** in NARA's titles, and a wrong roll sends the researcher
    /// into the wrong several-hundred-page scan — so an ambiguous answer is shown as ambiguous
    /// rather than resolved to whichever range sorted first.
    @ViewBuilder
    private func digitizedScansSection(fileIdentifier: String) -> some View {
        if let index = DigitizedRangeIndexStore.shared,
           let (cls, serial) = DigitizedRangeIndex.classAndSerial(fromFileIdentifier: fileIdentifier) {
            switch index.match(decimalClass: cls, serial: serial) {
            case .resolved(let range):
                Section(String(localized: "source.explorer.scans.header.v2",
                               defaultValue: "Digitized Scans")) {
                    digitizedRangeRow(range, isCandidate: false)
                    Text(Self.scanCaveat)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .multipleRanges(let ranges):
                Section(String(localized: "source.explorer.scans.header.v2",
                               defaultValue: "Digitized Scans")) {
                    Text(String(localized: "source.explorer.scans.multiple",
                                defaultValue: """
                                \(ranges.count) scanned file ranges contain \(fileIdentifier). \
                                They are listed narrowest first. NARA digitised this file in \
                                overlapping sets, so the widest range is not wrong. The \
                                narrowest is simply the most specific.
                                """))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(ranges) { digitizedRangeRow($0, isCandidate: true) }
                }
            case .classDigitizedButSerialNotCovered(let count):
                Section(String(localized: "source.explorer.scans.header.v2",
                               defaultValue: "Digitized Scans")) {
                    Text(String(localized: "source.explorer.scans.classOnly",
                                defaultValue: """
                                NARA has scanned \(count) file ranges in decimal class \(cls), \
                                but none of them covers \(fileIdentifier). The scans for this \
                                file are partial.
                                """))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .none:
                EmptyView()
            }
        }
    }

    /// The honesty line that rides with every resolved scan. The index places the citation in a
    /// *file range*; it cannot place it on a page.
    static let scanCaveat = String(
        localized: "source.explorer.scans.caveat",
        defaultValue: """
        This is the scan of the file range the citation falls in, not of this document. \
        The document is somewhere inside it.
        """)

    private func digitizedRangeRow(_ range: DigitizedRange, isCandidate: Bool) -> some View {
        digitizedScanRow(DigitizedScanPresentation(range), isCandidate: isCandidate)
    }

    /// One digitised scan — a decimal file range or a Numerical File roll.
    ///
    /// Both routes render through `DigitizedScanPresentation` so they cannot drift on what a
    /// scan row says, while each section keeps its own heading, prose and empty state (the two
    /// mean different things — see that type). The macOS twin mirrors this.
    @ViewBuilder
    private func digitizedScanRow(_ scan: DigitizedScanPresentation,
                                  isCandidate: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(scan.title)
                    .font(.callout.weight(.medium))
                if isCandidate { ConfidenceChip(confidence: .medium) }
            }
            if scan.objectCount > 0 {
                Text(scan.imageCountLabel)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if let pdf = scan.pdfURL, let label = scan.pdfLabel {
                Button {
                    openURL(pdf)
                } label: {
                    Label(label, systemImage: "doc.richtext").font(.callout)
                }
            }
            if let url = scan.catalogURL {
                Button {
                    openURL(url)
                } label: {
                    Label(String(localized: "source.explorer.nara.viewRecord",
                                 defaultValue: "View in NARA Catalog"),
                          systemImage: "arrow.up.right.square")
                    .font(.callout)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Paris Peace Conference Section

    /// The offline resolution for a `Paris Peace Conf.` citation (#354).
    ///
    /// Needs no API key and issues no query: every one of these citations resolves to the
    /// same record group and series. The roll is deliberately not claimed — see
    /// `ParisPeaceRecords` for why guessing it is worse than handing over the index.
    @ViewBuilder
    private func parisPeaceSection() -> some View {
        Section(ParisPeaceRecords.sectionTitle) {
            parisPeaceRow(ParisPeaceRecords.recordGroup, label: ParisPeaceRecords.recordGroupLabel)
            parisPeaceRow(ParisPeaceRecords.series, label: ParisPeaceRecords.seriesLabel)

            Text(ParisPeaceRecords.provenanceNote)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(ParisPeaceRecords.rollNote)
                .font(.caption)
                .foregroundStyle(.secondary)

            DisclosureGroup(ParisPeaceRecords.findingAidsTitle) {
                ForEach(ParisPeaceRecords.findingAids) { aid in
                    parisPeaceRow(aid, label: nil)
                }
            }
        }
    }

    /// One catalog record in the Paris Peace section: NARA's own title, its dates, and a
    /// link to the record itself.
    @ViewBuilder
    private func parisPeaceRow(_ record: ParisPeaceRecords.CatalogRecord, label: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let label {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(record.title)
                .font(.callout.weight(.medium))
            if let dates = record.inclusiveDates {
                Text(dates)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if let url = record.catalogURL {
                Button {
                    openURL(url)
                } label: {
                    Label(String(localized: "source.explorer.nara.viewRecord",
                                 defaultValue: "View in NARA Catalog"),
                          systemImage: "arrow.up.right.square")
                    .font(.callout)
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Country-Series Resolution (pre-1906, Phase 2)

    /// One classification candidate paired with the rolls it resolves to in the index.
    struct CountrySeriesResolution: Identifiable {
        let classification: CentralFilesClassification
        let rolls: [CountryRoll]
        var id: String { classification.category.rawValue }
    }

    /// Classifies a pre-1906 document (which carries no source note) from its dateline,
    /// heading, and FRUS chapter, and resolves each candidate series to its roll(s) in the
    /// bundled index. Populates `countryResolutions`; a no-op when inputs are missing or
    /// the document is 1906 or later (handled by the Numerical File / decimal paths).
    private func resolveCountrySeries() async {
        guard let dateline = documentDateline,
              let year = documentYear, year < 1906,
              let index = CentralFilesIndexStore.shared else { return }

        // Resolve the section chain to the document from the cached volume structure. The
        // country (e.g. "Great Britain.") is usually a parent chapter, not the leaf subject
        // section, so we try each title in the chain below.
        var path: [String] = []
        if let pipeline = indexingPipeline, let volumeId = documentVolumeId, let docId = documentId,
           let structure = try? await pipeline.cachedVolumeStructure(forVolumeId: volumeId) {
            path = CentralFilesClassifier.documentSectionPath(in: structure, documentId: docId)
        }
        guard !path.isEmpty else { return }

        let dateISO = CentralFilesClassifier.datelineDateISO(from: dateline)
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
    private var countrySeriesSection: some View {
        Section {
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
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text(String(localized: "source.explorer.countrySeries.header",
                        defaultValue: "Digitized Diplomatic Records (pre-1906)"))
        }
    }

    /// Shown for a document with no source note that the country-series classifier could not
    /// resolve to a specific roll (e.g. 1906–1910 Numerical File documents, whose case-number
    /// filing can't be predicted from metadata). Names the likely series for the era instead
    /// of presenting an "unrecognized note" parse failure.
    @ViewBuilder
    private var noSourceNoteSection: some View {
        Section {
            Text(String(localized: "source.explorer.noNote.detail",
                        defaultValue: "This document carries no archival source note, and its exact filing couldn't be predicted from its dateline and FRUS chapter."))
                .font(.caption)
                .foregroundStyle(.secondary)
            if let series = predictedSeriesNote {
                Text(series)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(String(localized: "source.explorer.noNote.header",
                        defaultValue: "Archival Source"))
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

    /// Resolves a 1906–1910 "File No." to the digitized Numerical File roll(s) that hold
    /// its case, from the bundled `central-files-index.json` (no API key, no network).
    ///
    /// A case can be split across two or three rolls, so all matching rolls are shown.
    /// When the case falls in a coverage gap (or is filed on a name/place roll), the
    /// section falls back to the Card Index (M1889) and the Numerical File series links.
    @ViewBuilder
    private func numericalFileSection(fileIdentifier: String) -> some View {
        let rolls = CentralFilesIndexStore.shared?
            .numericalFile.rolls(forFileNumber: fileIdentifier) ?? []

        Section(String(localized: "source.explorer.numericalFile.header",
                       defaultValue: "Digitized Numerical File (M862)")) {
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
                Button {
                    openURL(CentralFilesIndexStore.numericalFileSeriesURL)
                } label: {
                    Label(String(localized: "source.explorer.numericalFile.series",
                                 defaultValue: "Browse the Numerical File series"),
                          systemImage: "arrow.up.right.square")
                }
            } else {
                Text(String(localized: "source.explorer.numericalFile.found",
                            defaultValue: "These digitized rolls hold File No. \(fileIdentifier). Open one and review the images page by page — documents are filed in numeric order by case."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                // #663 follow-up: the roll's own PDF and image count, joined by NAID from
                // `roll-scans-index.json`. 1,218 of the 1,261 bundled rolls have one; the other
                // 43 keep the catalog link and no PDF button, which is the honest state.
                ForEach(rolls) { roll in
                    digitizedScanRow(DigitizedScanPresentation(
                        roll: roll, scan: RollScansIndexStore.shared?.scan(forNaId: roll.naId)))
                }
            }
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
                // Resolved period. The file-number form resolves the Jan/Feb 1963 and 1973
                // mid-year era boundaries where the year alone is ambiguous.
                let periodLabel = client.decimalFilePeriodLabel(year: year, fileIdentifier: fileIdentifier)
                let periodURL   = client.decimalFilePeriodURL(year: year, fileIdentifier: fileIdentifier)
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
                if let manualURL = client.filingManualURL(year: year, fileIdentifier: fileIdentifier) {
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
        // Curation is authoritative over the parser's record group, which defaults every
        // non-`F` lot to RG 59 — so a curated RG-43 collection would otherwise be labelled
        // RG 59 here *and* searched under RG 59 in the fallback URL below (#375).
        let effectiveRG = CuratedLotResolutionsStore.shared?.recordGroup(forRawLot: lotNumber)
            ?? recordGroup

        Section(String(localized: "source.explorer.provenance.header",
                       defaultValue: "Provenance")) {
            LabeledContent(
                String(localized: "source.explorer.lotFile.type", defaultValue: "Type"),
                value: {
                    let rg = effectiveRG ?? "RG-59"
                    if rg == "RG-84" {
                        return String(localized: "source.explorer.lotFile.typeValueRG84",
                                      defaultValue: "State Dept. Post Records Lot File (RG 84)")
                    }
                    return String(localized: "source.explorer.lotFile.typeValue",
                                  defaultValue: "State Dept. Lot File")
                }()
            )
            if let rg = effectiveRG {
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

        // Bundle-first: a pre-resolved lot file links straight to its NARA Catalog series
        // record with no API key. Shown above the live lookup; the live path remains as a
        // fallback for lots not in the bundle.
        // #675 / N-8b: where NARA divided the lot across several series, show them all rather
        // than naming one. Takes precedence over the single bundled card, which would assert a
        // choice the data does not support.
        if let divided = LotClaimantsIndex.candidatesOutcome(
            forRawLot: lotNumber, in: LotClaimantsIndexStore.shared) {
            curatedLotSection(divided)
        } else if let entry = CentralFilesIndexStore.shared?.lotFile(forRawLot: lotNumber) {
            bundledLotSection(entry)
        }

        // Hand-curated outcome for a lot NARA's catalogue does not resolve by control
        // number (#375). Never a confident card: each kind states its own uncertainty.
        if let outcome = CuratedLotResolutionsStore.shared?.outcome(forRawLot: lotNumber) {
            curatedLotSection(outcome)
        }

        // Fallback: pre-scoped NARA Catalog search for the lot number.
        // Use RG 84 fallback URL for F-designator (post record) lot files.
        let fb: URL = {
            let rg = effectiveRG ?? "RG-59"
            if rg == "RG-84" {
                return client.resolveRG84LotFile(lotNumber: lotNumber)
            }
            return client.resolveRG59CentralFiles(fileIdentifier: "Lot \(lotNumber)")
        }()
        naraResultSection(requiresKey: true, fallbackURL: fb)
    }

    /// The hand-curated outcome for a lot NARA's catalogue does not resolve by control
    /// number (#375 / N-3), in the confidence grammar the pre-1906 country-series section
    /// established: a `ConfidenceChip` beside each candidate and a rationale beneath it.
    ///
    /// Every branch is deliberately hedged. A curated match was reached by collection name
    /// or by creator, not by a control number, so none of them may borrow
    /// `bundledLotSection`'s "Resolved from the bundled index" caption.
    ///
    /// Mirrored by `MacSourceExplorerView.curatedLotBox` — keep in sync.
    @ViewBuilder
    private func curatedLotSection(_ outcome: CuratedLotOutcome) -> some View {
        switch outcome {
        case .possible(let series, let rationale):
            Section(String(localized: "source.explorer.curatedLot.possible.header",
                           defaultValue: "Possible NARA Catalog Record")) {
                HStack(spacing: 6) {
                    Text(series.title).font(.callout)
                    ConfidenceChip(confidence: .medium)
                }
                curatedSeriesDetail(series)
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
                Text(String(localized: "source.explorer.curatedLot.possible.note",
                            defaultValue: "This match was made by collection name, not by a catalog control number. Confirm the lot number against the series before citing it."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .candidates(let series, let rationale, let creatorName, let seeAllURL):
            Section(String(localized: "source.explorer.curatedLot.candidates.header",
                           defaultValue: "Candidate NARA Series")) {
                Text(rationale)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let creatorName {
                    LabeledContent(
                        String(localized: "source.explorer.curatedLot.creator",
                               defaultValue: "NARA Creator"),
                        value: creatorName
                    )
                }
                ForEach(series) { candidate in
                    Button {
                        if let url = candidate.url { openURL(url) }
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(candidate.title).font(.callout)
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
                    .contentShape(Rectangle())
                }
                if let seeAllURL {
                    Button {
                        openURL(seeAllURL)
                    } label: {
                        Label(String(localized: "source.explorer.curatedLot.seeAll",
                                     defaultValue: "See all series by this creator"),
                              systemImage: "arrow.up.right.square")
                    }
                }
                Text(String(localized: "source.explorer.curatedLot.candidates.note",
                            defaultValue: "NARA did not accession this lot as a single series, so no one record is the answer. Review the candidates against the document's date and type."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .referral(let referral):
            Section(String(localized: "source.explorer.curatedLot.referral.header",
                           defaultValue: "Ask a NARA Archivist")) {
                Text(referral.rationale)
                    .font(.callout)
                if let count = referral.seriesCount {
                    LabeledContent(
                        String(localized: "source.explorer.curatedLot.referral.seriesCount",
                               defaultValue: "Series in the collection"),
                        value: "\(count)"
                    )
                }
                if let range = referral.entryNumberRange {
                    LabeledContent(
                        String(localized: "source.explorer.curatedLot.referral.entryRange",
                               defaultValue: "HMS/MLR Entry Range"),
                        value: range
                    )
                }
                Text(referral.guidance)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let url = referral.url {
                    Button {
                        openURL(url)
                    } label: {
                        Label(String(localized: "source.explorer.curatedLot.referral.browse",
                                     defaultValue: "Browse the collection's series"),
                              systemImage: "arrow.up.right.square")
                    }
                }
            }
        }
    }

    /// The identifier rows shared by the curated `possible` card — the entry number a
    /// researcher quotes to NARA staff, and the series' own coverage span.
    @ViewBuilder
    private func curatedSeriesDetail(_ series: CuratedSeries) -> some View {
        if let entry = series.entryNumber {
            LabeledContent(
                String(localized: "source.explorer.lotFile.hmsMlr", defaultValue: "HMS/MLR Entry"),
                value: entry
            )
        }
        if let dateRange = series.dateRange {
            LabeledContent(
                String(localized: "source.explorer.curatedLot.dateRange", defaultValue: "Series Dates"),
                value: dateRange
            )
        }
    }

    /// One-line "entry number · dates" subtitle for a candidate row, or `nil` when neither
    /// is known.
    private func curatedSeriesSubtitle(_ series: CuratedSeries) -> String? {
        let parts = [series.entryNumber, series.dateRange].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// A bundled, key-less link to a lot file's resolved NARA Catalog series record —
    /// enriched (#315) with the identifiers NARA staff ask researchers to cite.
    ///
    /// Row logic (mirrored by `MacSourceExplorerView.bundledLotBox` — keep in sync):
    /// - A **series-level** record's own `title` is the file series name, and its own
    ///   `hmsMlrEntryNumbers` identify exactly the records being cited.
    /// - A **file-unit** record's title names only the file unit; its series name comes from
    ///   `displaySeriesTitle` (the enclosing series, resolved by the enrichment pass), and any
    ///   entry numbers shown are the *series'* — labeled as such, because the parent's
    ///   identifiers locate the series, not the specific unit (a parent can carry up to 23).
    @ViewBuilder
    private func bundledLotSection(_ entry: LotFileEntry) -> some View {
        Section(String(localized: "source.explorer.lotFile.bundled.header",
                       defaultValue: "NARA Catalog Record")) {
            Text(entry.title)
                .font(.callout)
            // File-unit records: name the enclosing series explicitly (#315's
            // "file series name/title"); for series records the title above IS the series.
            if !entry.isSeriesLevel, let seriesTitle = entry.displaySeriesTitle {
                LabeledContent(
                    String(localized: "source.explorer.lotFile.series",
                           defaultValue: "File Series"),
                    value: seriesTitle
                )
            }
            // #405: NARA names the office that made the series; FRUS's own note never does.
            // Absent for most rows and that is honest — `creators` exists only on NARA's series
            // layer, so "not stated" is the true answer for a file unit, not a gap to fill.
            if let creator = SeriesFactsIndex.creatorName(for: entry) {
                LabeledContent(
                    String(localized: "source.explorer.curatedLot.creator",
                           defaultValue: "NARA Creator"),
                    value: creator
                )
            }
            // #663 / F-7: NARA's own trip-planning facts. Access status first because it is the
            // one that decides whether the trip is worth taking — 414 of the 622 series the app
            // can name are restricted in some degree.
            if let facts = SeriesFactsIndex.facts(for: entry) {
                if let access = facts.accessStatus {
                    LabeledContent(
                        String(localized: "source.explorer.lotFile.access",
                               defaultValue: "Access"),
                        value: facts.accessRestrictions.isEmpty
                            ? access
                            : "\(access) — \(facts.accessRestrictions.joined(separator: ", "))"
                    )
                }
                // Separate from access on purpose: whether you may PUBLISH what you find is a
                // different question from whether you may read it, and it is the one a
                // researcher usually discovers too late.
                if facts.isUseRestricted, let use = facts.useStatus {
                    LabeledContent(
                        String(localized: "source.explorer.lotFile.use",
                               defaultValue: "Use"),
                        value: facts.useRestrictions.isEmpty
                            ? use
                            : "\(use) — \(facts.useRestrictions.joined(separator: ", "))"
                    )
                }
                if let years = facts.years {
                    LabeledContent(
                        String(localized: "source.explorer.lotFile.seriesYears",
                               defaultValue: "Series Dates"),
                        value: years
                    )
                }
                if let extent = facts.extent {
                    LabeledContent(
                        String(localized: "source.explorer.lotFile.extent",
                               defaultValue: "Extent"),
                        value: extent
                    )
                }
                if let unit = facts.referenceUnit {
                    LabeledContent(
                        String(localized: "source.explorer.lotFile.heldAt",
                               defaultValue: "Held At"),
                        value: unit
                    )
                }
                if !facts.findingAids.isEmpty {
                    LabeledContent(
                        String(localized: "source.explorer.lotFile.findingAids",
                               defaultValue: "Finding Aids"),
                        value: facts.findingAids.joined(separator: ", ")
                    )
                }
            }
            if let entries = entry.hmsMlrEntryNumbers, !entries.isEmpty {
                LabeledContent(
                    String(localized: "source.explorer.lotFile.hmsMlr",
                           defaultValue: "HMS/MLR Entry"),
                    value: entries.joined(separator: ", ")
                )
            } else if let seriesEntries = entry.seriesHmsMlrEntryNumbers, !seriesEntries.isEmpty {
                LabeledContent(
                    String(localized: "source.explorer.lotFile.hmsMlr.series",
                           defaultValue: "HMS/MLR Entry (series)"),
                    value: seriesEntries.joined(separator: ", ")
                )
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

        // #355/N-4: a hand-curated finding aid for this collection — or, where the collection
        // is really a container, for the sub-collection this citation names. The libraries
        // publish no NARA catalogue record for these (all 438 library clusters carry a null
        // naId, structurally: they sit outside every record group), so a finding aid IS the
        // resolution rather than a consolation for missing one.
        if let curated = CuratedLibraryResolutionsStore.shared?.resolution(
            repository: library, collection: collection,
            subCollection: CuratedLibraryResolutions.subCollection(
                inNote: rawSourceNote, afterCollection: collection)) {
            curatedLibrarySection(curated)
        }

        // #681: the bundled catalogue answers first, with no key and no network. Where it
        // answers, the live query is not issued at all (owner decision) — see
        // `PresidentialLibraryOutcome`. Keep in sync with the macOS twin.
        if libraryOutcome.isHit {
            offlineLibrarySection(libraryOutcome)
        } else if NARACustody.mayQueryCatalog(forRepository: library) {
            // Fallback: institution-specific finding-aid URL when API returns zero results
            let fallback = client.libraryFallbackURL(libraryName: library)
            naraResultSection(requiresKey: true, fallbackURL: fallback)
        } else {
            outsideNARASection(repository: library)
        }
    }

    /// The bundled catalogue's answer for a library citation (#681).
    ///
    /// The collection row is a resolution in both branches — the identifier behind it was
    /// verified by hand against the harvest. What varies is the series: named exactly, or left
    /// as candidates under a caveat that is rendered *above* them so it is read first.
    @ViewBuilder
    private func offlineLibrarySection(_ outcome: PresidentialLibraryOutcome) -> some View {
        Section(outcome.sectionTitle) {
            if let collection = outcome.verifiedCollection {
                VStack(alignment: .leading, spacing: 4) {
                    Text(outcome.collectionRowLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(collection.title)
                        .font(.callout.weight(.medium))
                    if let url = collection.catalogURL {
                        Button {
                            openURL(url)
                        } label: {
                            Label(String(localized: "source.explorer.nara.viewRecord",
                                         defaultValue: "View in NARA Catalog"),
                                  systemImage: "arrow.up.right.square")
                            .font(.callout)
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(.vertical, 4)
            }

            if let series = outcome.resolvedSeries {
                Divider()
                offlineSeriesRow(series, label: outcome.seriesRowLabel, isCandidate: false)
            }

            if let caveat = outcome.caveat {
                Text(caveat)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(outcome.candidateSeries ?? []) { series in
                offlineSeriesRow(series, label: nil, isCandidate: true)
            }

            Text(outcome.provenanceNote)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// One series row in the offline catalogue section. Candidates carry the same
    /// `ConfidenceChip` #669 gives a curated possible match; the resolved series does not.
    @ViewBuilder
    private func offlineSeriesRow(_ series: PresidentialLibraryIndex.Series,
                                  label: String?,
                                  isCandidate: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let label {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                Text(series.title)
                    .font(.callout.weight(.medium))
                if isCandidate { ConfidenceChip(confidence: .medium) }
            }
            if let dates = series.inclusiveDates {
                Text(dates)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if let url = series.catalogURL {
                Button {
                    openURL(url)
                } label: {
                    Label(String(localized: "source.explorer.nara.viewRecord",
                                 defaultValue: "View in NARA Catalog"),
                          systemImage: "arrow.up.right.square")
                    .font(.callout)
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }

    /// Explains why no NARA catalogue results are shown for a repository the National Archives
    /// does not administer (#681).
    ///
    /// The alternative is what shipped before: a free-text query on the library and collection
    /// names, rendered as up to three results behind the same "View in NARA Catalog" button
    /// used for verified lot resolutions. For the 1,061 Library of Congress documents — and the
    /// 900 more naming universities, historical societies and bodies that are not repositories
    /// at all — the catalogue has nothing to find, so every row shown was noise presented as a
    /// finding.
    private func outsideNARASection(repository: String) -> some View {
        Section(String(localized: "source.explorer.nara.header", defaultValue: "NARA Catalog")) {
            Label {
                Text(String(localized: "source.explorer.nara.outsideCustody",
                            defaultValue: """
                            \(repository) is not a National Archives repository, so the NARA \
                            Catalog has no record of this collection. A search on the \
                            collection name alone returns results that look authoritative but \
                            are not. None are shown here.
                            """))
                .font(.callout)
                .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "building.columns")
                    .foregroundStyle(.secondary)
            }

            // #354 item 4: saying the National Archives cannot help is only half an answer.
            // 565 of these documents reached no curated finding aid either, so they were told
            // where the records are *not* and nothing about where they are.
            if let guidance = ManuscriptRepositoryGuidance.guidance(forRepository: repository) {
                repositoryGuidanceRows(guidance)
            }
        }
    }

    /// The rows naming the repository that actually holds these records (#354 item 4).
    ///
    /// Shared wording with the macOS twin through `ManuscriptRepositoryGuidance`, so the two
    /// platforms cannot state different things about the same institution.
    @ViewBuilder
    private func repositoryGuidanceRows(_ guidance: ManuscriptRepositoryGuidance.Entry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(guidance.name)
                .font(.callout.weight(.medium))
            // A renamed repository is the single most useful thing here: the citation's own
            // spelling finds nothing at the institution that now holds the records.
            if let formerName = guidance.formerName {
                Text("\(ManuscriptRepositoryGuidance.citedAsLabel): \(formerName)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(guidance.holdings)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let url = guidance.url {
                Button {
                    openURL(url)
                } label: {
                    Label(ManuscriptRepositoryGuidance.linkLabel(guidance),
                          systemImage: "arrow.up.right.square")
                    .font(.callout)
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }

    /// The curated finding aid for a library collection.
    ///
    /// Shows the repository's **own** title for the collection, not the FRUS shorthand, so a
    /// researcher can confirm the destination rather than trust it — `Matlock Files` is the
    /// citation; `Matlock, Jack F., JR.: Files, 1983-1986` is the aid. The curator's rationale
    /// rides along for the same reason.
    @ViewBuilder
    private func curatedLibrarySection(_ curated: CuratedLibraryResolution) -> some View {
        Section(String(localized: "source.explorer.curatedLibrary.header",
                       defaultValue: "Finding Aid")) {
            if let url = curated.findingAid {
                Link(destination: url) {
                    Label(curated.title, systemImage: "doc.text.magnifyingglass")
                }
            } else {
                Text(curated.title)
            }
            if let catalog = curated.catalogURL {
                Link(destination: catalog) {
                    Label(String(localized: "source.explorer.curatedLibrary.catalog",
                                 defaultValue: "NARA Catalog Record"),
                          systemImage: "building.columns")
                }
            }
            if let rationale = curated.rationale, !rationale.isEmpty {
                Text(rationale)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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
        Section(catalogEvidence?.sectionTitle
                ?? String(localized: "source.explorer.nara.header", defaultValue: "NARA Catalog")) {
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
                // #681: an unverified result set is headed and captioned as candidates. The
                // caveat leads rather than trails — a note under five rows is read last.
                if let caveat = catalogEvidence?.caveat {
                    Text(caveat)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                // Up to 5 ranked candidates
                ForEach(catalogResults.prefix(5), id: \.naId) { result in
                    catalogResultRow(result: result,
                                     isVerified: catalogEvidence?.isVerified ?? true)
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
                        defaultValue: "A free NARA Catalog API key is required to search for lot file and Presidential Library records. Add your key in Settings → Connections."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func catalogResultRow(result: NARACatalogResult,
                                  isVerified: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(result.title)
                    .font(.callout.weight(.medium))
                // #681: the same chip #669 gives a curated possible match. An unchecked live
                // hit has no more standing than a curated one, and had been showing with more.
                if !isVerified { ConfidenceChip(confidence: .medium) }
            }
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

    /// Identity of the document currently being explained, for `.task(id:)`.
    /// Mirrors `MacSourceExplorerView.loadIdentity` — keep in sync.
    var loadIdentity: String {
        MacSourceExplorerLoadIdentity.make(volumeId: documentVolumeId, documentId: documentId,
                                           rawSourceNote: rawSourceNote, documentYear: documentYear)
    }

    /// Reads this document's footnote pointers and joins each to the authority.
    ///
    /// Runs regardless of whether the document has a source note: a document FRUS printed without
    /// stating a provenance can still have footnotes pointing at unprinted files.
    private func loadUnprintedPointers() async {
        guard let pipeline = indexingPipeline,
              let volumeId = documentVolumeId, let docId = documentId else {
            unprintedPointers = []
            return
        }
        let rows = (try? await pipeline.externalCitations(volumeId: volumeId,
                                                          documentId: docId)) ?? []
        guard !rows.isEmpty else { unprintedPointers = []; return }
        // The authority is a ~2 MB decode; join off the main thread, as the source note's own
        // resolution above does.
        unprintedPointers = await Task.detached(priority: .userInitiated) {
            guard let authority = CollectionAuthorityStore.shared else {
                return rows.map { UnprintedPointer(citation: $0, record: nil) }
            }
            return rows.map {
                UnprintedPointer(citation: $0, record: Self.resolve($0, authority: authority))
            }
        }.value
    }

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

        await loadUnprintedPointers()

        // Pre-1906 country-series resolution (no source note; no API key). Runs first so
        // the resolved roll links appear even without a NARA Catalog key.
        await resolveCountrySeries()

        // Local related-documents query — runs unconditionally; no API key needed.
        // Must be called before the hasAPIKey guard so it runs even for users
        // who have not configured a NARA Catalog API key.
        await loadRelatedDocuments(for: note)

        // #681: the bundled library catalogue is resolved BEFORE the API-key guard — it needs
        // neither a key nor the network, and gating it on one would withhold the offline answer
        // from exactly the users who have no other. Detached for the same reason the authority
        // record is: it is a 3.1 MB decode the first time it is touched.
        if case .presidentialLibrary(let library, let collection, _) = note {
            let raw = rawSourceNote
            libraryOutcome = await Task.detached(priority: .userInitiated) {
                PresidentialLibraryOutcome.resolve(
                    repository: library, collection: collection, note: raw)
            }.value
        }

        hasAPIKey = await client.hasAPIKey()
        guard hasAPIKey else { return }
        catalogEvidence = CatalogQueryEvidence.forNote(note)

        switch note {

        case .lotFile(let rg, let lotNumber, _):
            // Use variantControlNumber_is with three normalised lot number forms,
            // falling back to a phrase query if all variants return zero results.
            // Strip the "RG-" prefix to get the bare record group number for the API.
            let rgToUse = (rg ?? "RG-59").replacingOccurrences(of: "RG-", with: "")
            await fetchResults { try await client.resolveLotFileVariants(lotNumber: lotNumber, recordGroup: rgToUse) }

        case .naraCollection(let rg, let series, let lot, _):
            // #681: a record-group citation that names a lot belongs on the *guarded* route.
            // Measured, 853 documents take this branch, and until now they ran the unfiltered
            // record-group query for a citation the acceptance test was built for.
            if let lot {
                let rgToUse = rg.replacingOccurrences(of: "RG-", with: "")
                await fetchResults {
                    try await client.resolveLotFileVariants(lotNumber: lot, recordGroup: rgToUse)
                }
            } else {
                let keywords = [series].compactMap { $0 }.joined(separator: " ")
                await fetchResults { try await client.searchByRecordGroup(rg, keywords: keywords, maxResults: 5) }
            }

        case .presidentialLibrary(let library, let collection, _):
            // #681: the catalogue can only answer for repositories NARA actually administers.
            // For the other 1,961 documents the free-text query returns rows that are wrong by
            // construction, so no query is issued and the view says why.
            guard NARACustody.mayQueryCatalog(forRepository: library) else { return }
            // #681: and where the bundled catalogue already resolved the citation, the live
            // query is suppressed — unconstrained free-text rows shown beside a verified NARA
            // collection cannot be told apart from it (owner decision 2026-08-06).
            guard !libraryOutcome.suppressesLiveQuery else { return }
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
    ///
    /// Routes through the same widened, anchor-excluding `archivalNeighbors(forVolumeId:
    /// documentId:)` entry point the dedicated Archival Neighbors surfaces use, so this
    /// inline list shows the **identical** set of OTHER documents for the same document
    /// — the #217 "same set regardless of trigger" guarantee. This inline section stays
    /// at the all-indexed default scope; the scope picker lives on the dedicated
    /// neighbors window/sheet.
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

    /// A short description of *why* the related documents are neighbors, shown atop the
    /// section so the researcher understands the archival relationship.
    private var archivalNeighborBasis: String? {
        switch parsed {
        case .lotFile(_, let lot, _):
            return String(localized: "source.explorer.related.basis.lot",
                          defaultValue: "Same lot file — \(lot)")
        case .naraCollection(let rg, let series?, let lot, _):
            if let lot {
                return String(localized: "source.explorer.related.basis.lot",
                              defaultValue: "Same lot file — \(lot)")
            }
            return String(localized: "source.explorer.related.basis.collection",
                          defaultValue: "Same collection — RG \(rg), \(series)")
        case .centralFiles(_, let fileId?) where fileId.contains("."):
            let location = DecimalFileSegment.location(from: fileId)
            if let segment = DecimalFileSegment.segment(for: fileId, fallbackYear: documentYear) {
                return String(localized: "source.explorer.related.basis.decimalSegment",
                              defaultValue: "Same decimal file — \(location), \(segment)")
            }
            return String(localized: "source.explorer.related.basis.decimal",
                          defaultValue: "Same decimal file — \(location)")
        case .presidentialLibrary(let library, _, _):
            return String(localized: "source.explorer.related.basis.library",
                          defaultValue: "Same collection — \(library)")
        default:
            return nil
        }
    }

    // MARK: - Related Documents Section

    /// Section displaying documents from the same archival collection or file series.
    ///
    /// Shown once the source note has been parsed (so the header is always visible while the
    /// Source Explorer is open) with three states: a loading spinner, the list of matches, or
    /// an explicit empty-state that explains *why* there are none — either the note isn't a
    /// recognized archival citation, or no other indexed document shares its collection.
    @ViewBuilder
    private var relatedDocumentsSection: some View {
        if relatedLoading || parsed != nil {
            Section {
                if relatedLoading {
                    HStack {
                        ProgressView().padding(.trailing, 8)
                        Text(String(localized: "source.explorer.related.loading",
                                    defaultValue: "Searching indexed volumes…"))
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                } else if !relatedDocs.isEmpty {
                    if let basis = archivalNeighborBasis {
                        Text(basis)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    // Composite key: related documents span volumes, and document ids
                    // are only unique within a single volume.
                    ForEach(relatedDocs, id: \.compositeKey) { doc in
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
                } else {
                    Text(relatedEmptyMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } header: {
                HStack {
                    Text(String(localized: "source.explorer.related.header",
                                defaultValue: "Archival Neighbors"))
                    Spacer()
                    if !relatedDocs.isEmpty {
                        Text("\(relatedTotalCount)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                if !relatedLoading, let key = parsed?.archivalNeighborKey {
                    Text(String(format: String(localized: "source.explorer.related.matchKey %@",
                                               defaultValue: "Matching archival source: %@"), key))
                        .font(.caption2)
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
        // #312 follow-up: the contentShape below only covers this VStack's own width, which for a
        // short header is less than the row; the frame widens it first.
        .frame(maxWidth: .infinity, alignment: .leading)
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
