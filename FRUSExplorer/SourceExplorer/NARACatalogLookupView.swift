// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - NARACatalogLookupView

/// Queries the NARA Catalog using user-selected document text — an iOS sheet, and
/// the content of the macOS Source Explorer window's **NARA Lookup** segment.
///
/// Complements the parsing-based `SourceExplorerView` by letting the researcher
/// directly select archival citation text in the document (a lot number, decimal
/// file ID, keywords, etc.) and choose an appropriate query strategy, rather than
/// relying on automatic source-note parsing.  Useful when the parser cannot
/// identify the citation type or when the researcher wants to try alternate queries.
///
/// ## Layout
/// - Editable search text field (pre-populated with selected text)
/// - Strategy picker (Lot file RG 59, Lot file RG 84, Keywords in RG, Central
///   files URL, General keyword)
/// - Search / Open button
/// - Results list (same `NARACatalogResult` display as `SourceExplorerView`)
///
/// ## API key
/// Most strategies require a NARA Catalog API key. The "Central files identifier"
/// strategy opens a static NARA URL in the browser without an API key.
///
/// Version history:
///   1.0 — Session 153: initial implementation
///   1.1 — Session 2026-07-04 (macOS UI audit B3): the macOS body is embedded in the
///          Source Explorer window's NARA Lookup segment instead of a sheet, so its
///          Close button (sheet chrome — `dismiss` would now close the whole window)
///          is gone; the iOS sheet chrome is unchanged
struct NARACatalogLookupView: View {

    let initialText: String

    /// The enclosing footnote body (the JS `blockText`, #269), when the lookup was opened from
    /// a footnote selection — scanned once for candidate archival citations offered as
    /// one-tap quick-fills. `nil`/empty for an in-document selection or other entry points.
    let blockContext: String?

    /// Archival citations detected in `blockContext` (empty when there is none). Computed once
    /// at init via SourceNoteKit's body-text `extractCitations`.
    /// Ranked, routed, offline-resolved readings of the selection (#235).
    private let candidates: [NARALookupCandidate]

    // MARK: - Dependencies

    private let client = NARACatalogClient()

    // MARK: - State

    @State private var queryText: String
    /// Set from the top candidate at open (#235), not hardcoded — see `init`.
    @State private var strategy: LookupStrategy
    @State private var isSearching = false
    @State private var results: [NARACatalogResult] = []
    @State private var hasAPIKey = false
    @State private var searchError: String? = nil
    @State private var hasSearched = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL)  private var openURL
    @Environment(AppState.self) private var appState

    // MARK: - Init

    init(initialText: String, blockContext: String? = nil) {
        self.initialText = initialText
        self.blockContext = blockContext
        _queryText = State(initialValue: initialText.trimmingCharacters(in: .whitespacesAndNewlines))
        // #235: the selection ITSELF is read, not only a block context the in-document path never
        // supplied. Deduplication, routing and offline resolution all live in the analyzer, which
        // is testable; this init used to hold that logic and therefore could not be.
        let found = NARALookupAnalyzer.candidates(selection: initialText, context: blockContext)
        candidates = found
        // Open on the route the text implies. The old `.keywordRG59` default was wrong for every
        // F-designator lot (RG 84), every presidential-library collection (no record group at all)
        // and every decimal file number (`.centralURL`, the one route needing no API key) — and it
        // was applied to every selection, including the ones the app could already answer.
        _strategy = State(initialValue: found.first?.strategy ?? .keywordRG59)
    }

    // MARK: - Body

    var body: some View {
        #if os(macOS)
        macBody
        #else
        iOSBody
        #endif
    }

    /// True when the selected strategy serves period links rather than API results.
    private var showsPeriodLinks: Bool { strategy == .centralURL }

    // MARK: - macOS body

    #if os(macOS)
    private var macBody: some View {
        VStack(spacing: 0) {

            // Title
            HStack {
                Text(String(localized: "nara.lookup.title", defaultValue: "Look Up in NARA Catalog"))
                    .font(.headline)
                Spacer()
                // Contextual deep link into the Research Guide's "App Feature
                // Walkthrough" page, which documents NARA Catalog Lookup directly.
                ResearchGuideLinkButton(
                    pageId: "app-features",
                    label: String(localized: "nara.lookup.learnMore",
                                  defaultValue: "Learn About NARA Lookup")
                )
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help(String(localized: "nara.lookup.learnMore",
                             defaultValue: "Learn About NARA Lookup"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // Content area
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    queryFieldSection
                    candidateCitationsSection
                    strategySection
                    if showsPeriodLinks {
                        // Period links appear immediately — no API call needed
                        periodLinksSection
                    } else if hasSearched {
                        resultSection
                    }
                }
                .padding(20)
            }

            Divider()

            // Button bar. No Close button: this body lives inside the Source
            // Explorer window's NARA Lookup segment (B3), not a sheet — the window's
            // own close control is the exit (UI audit gap 11: no dead sheet chrome
            // in window contexts).
            HStack(spacing: 10) {
                Spacer()

                if isSearching {
                    ProgressView().controlSize(.small).padding(.trailing, 4)
                }

                if !showsPeriodLinks {
                    Button(String(localized: "nara.lookup.search", defaultValue: "Search")) {
                        Task { await runSearch() }
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(isSearching
                              || queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || !hasAPIKey)
                }
                // centralURL: period links are shown inline — no button needed
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 480, idealWidth: 540, minHeight: 380)
        .task { hasAPIKey = await client.hasAPIKey() }
    }
    #endif

    // MARK: - iOS body

    private var iOSBody: some View {
        NavigationStack {
            Form {
                queryFieldSection
                candidateCitationsSection
                strategySection
                if showsPeriodLinks {
                    periodLinksSection
                } else if hasSearched {
                    resultSection
                }
            }
            .navigationTitle(
                String(localized: "nara.lookup.title", defaultValue: "Look Up in NARA Catalog"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "nara.lookup.close", defaultValue: "Close")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                        if !showsPeriodLinks {
                        Button(String(localized: "nara.lookup.search", defaultValue: "Search")) {
                            Task { await runSearch() }
                        }
                        .disabled(isSearching
                                  || queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                  || !hasAPIKey)
                    }
                }
                // Contextual deep link into the Research Guide's "App Feature
                // Walkthrough" page, which documents NARA Catalog Lookup directly.
                ToolbarItem(placement: .secondaryAction) {
                    ResearchGuideLinkButton(
                        pageId: "app-features",
                        label: String(localized: "nara.lookup.learnMore",
                                      defaultValue: "Learn About NARA Lookup")
                    )
                }
            }
            .task { hasAPIKey = await client.hasAPIKey() }
        }
    }

    // MARK: - Shared sections

    /// Editable text field pre-populated with the user's selection.
    @ViewBuilder
    private var queryFieldSection: some View {
        Section(String(localized: "nara.lookup.queryField.header",
                       defaultValue: "Search Text")) {
            TextField(
                String(localized: "nara.lookup.queryField.placeholder",
                       defaultValue: "Lot number, file identifier, or keywords"),
                text: $queryText
            )
            #if os(iOS)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            #endif
            Text(String(localized: "nara.lookup.queryField.hint",
                        defaultValue: "Edit the selected text before searching if needed."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Candidate readings of the reader's selection (#269, widened by #235).
    ///
    /// Each row is a one-tap quick-fill that populates the query and pre-selects its route. Where
    /// the bundled indexes already hold the answer the row **shows that answer** — NAID and series
    /// title — so a reader with no API key gets what they came for without a network call. The
    /// manual field and picker below remain the fallback the issue asks to keep.
    @ViewBuilder
    private var candidateCitationsSection: some View {
        if !candidates.isEmpty {
            Section(String(localized: "nara.lookup.detected.header.v2",
                           defaultValue: "Detected in This Passage")) {
                Text(String(localized: "nara.lookup.detected.hint.v2",
                            defaultValue: "Archival citations found in the selected text and around it — tap one to fill the search."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(candidates) { candidate in
                    Button {
                        apply(candidate)
                    } label: {
                        candidateLabel(candidate)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(String(localized: "nara.lookup.detected.tapHint",
                                              defaultValue: "Fills the search text with this citation"))
                }
            }
        }
    }

    /// The display label for a candidate: the citation as printed, then the bundled resolution
    /// when there is one.
    @ViewBuilder
    private func candidateLabel(_ candidate: NARALookupCandidate) -> some View {
        HStack(spacing: 8) {
            // A resolved candidate gets the archival glyph the rest of the app uses for a real
            // NARA record; an unresolved one keeps the search glyph, because it is still a query.
            Image(systemName: candidate.resolution == nil
                  ? "doc.text.magnifyingglass" : "building.columns")
                .foregroundStyle(candidate.resolution == nil ? .secondary : Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.label)
                    .font(.callout)
                    .multilineTextAlignment(.leading)
                if let resolution = candidate.resolution {
                    Text(resolution.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                    // The claim this caption makes is deliberately narrow: the record came from
                    // the shipped index, which is why it needs no key. It does NOT claim the
                    // series is the only one holding the lot — where NARA divided one,
                    // `lot-claimants-index.json` is what discloses the rest.
                    Text(String(format: String(localized: "nara.lookup.detected.resolved %@",
                                               defaultValue: "NAID %@ — from the bundled index; no API key needed"),
                                resolution.naId))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    /// Fills the query field from a candidate and adopts its route.
    ///
    /// Every candidate carries a strategy, so the `else` branch that used to leave the reader on
    /// the picker — the one a decimal file number always fell into, because `ArchiveCitation`
    /// carries no decimal field — no longer exists.
    private func apply(_ candidate: NARALookupCandidate) {
        queryText = candidate.query
        strategy = candidate.strategy
        // Reset any prior results so the next Search reflects the new query.
        results = []
        searchError = nil
        hasSearched = false
    }

    /// Strategy picker — maps to the collection-type logic in NARACatalogClient.
    @ViewBuilder
    private var strategySection: some View {
        Section(String(localized: "nara.lookup.strategy.header",
                       defaultValue: "Query Strategy")) {
            Picker(
                String(localized: "nara.lookup.strategy.picker", defaultValue: "Strategy"),
                selection: $strategy
            ) {
                ForEach(LookupStrategy.allCases) { s in
                    Text(s.displayName).tag(s)
                }
            }
            #if os(macOS)
            .pickerStyle(.radioGroup)
            #else
            .pickerStyle(.inline)
            #endif
            .onChange(of: strategy) { _, _ in
                // Clear results when the strategy changes so the user sees fresh results.
                results = []
                searchError = nil
                hasSearched = false
            }

            // Hint explaining the selected strategy
            Text(strategy.hint)
                .font(.caption)
                .foregroundStyle(.secondary)

            // API key warning for strategies that need one
            if strategy != .centralURL && !hasAPIKey {
                Label(
                    String(localized: "nara.lookup.noKey.warning",
                           defaultValue: "A NARA Catalog API key is required for this strategy. Add your key in Settings → Connections. The \"Central files identifier\" strategy does not require a key."),
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }
        }
    }

    /// Period links section — shown instead of API results when `centralURL` is selected.
    ///
    /// Uses the same period table as `SourceExplorerView.centralFilesPeriodSection`
    /// to route the researcher to the correct `archives.gov/research/…` page.
    @ViewBuilder
    private var periodLinksSection: some View {
        Section(String(localized: "nara.lookup.periodLinks.header",
                       defaultValue: "NARA Finding Aids by Period")) {
            Text(String(localized: "nara.lookup.periodLinks.intro",
                        defaultValue: "Select the filing period that matches the document date. Each link goes directly to the NARA research page for that period — no API key required."))
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(SourceExplorerView.allFilingPeriods, id: \.id) { period in
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

    /// Results section — loading spinner, results list, or empty state.
    @ViewBuilder
    private var resultSection: some View {
        Section(String(localized: "nara.lookup.results.header",
                       defaultValue: "NARA Catalog Results")) {
            if isSearching {
                HStack {
                    ProgressView().padding(.trailing, 8)
                    Text(String(localized: "nara.lookup.results.loading",
                                defaultValue: "Searching NARA Catalog…"))
                        .foregroundStyle(.secondary)
                }
            } else if let error = searchError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.callout)
            } else if results.isEmpty {
                Text(String(localized: "nara.lookup.results.empty",
                            defaultValue: "No matching records found. Try editing the search text or selecting a different strategy."))
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ForEach(results, id: \.naId) { result in
                    resultRow(result)
                }
            }
        }
    }

    @ViewBuilder
    private func resultRow(_ result: NARACatalogResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(result.title)
                .font(.callout.weight(.medium))
            if let scope = result.scopeNote {
                Text(scope)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
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
                    String(localized: "nara.lookup.results.view",
                           defaultValue: "View in NARA Catalog"),
                    systemImage: "arrow.up.right.square"
                )
                .font(.callout)
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Search

    private func runSearch() async {
        let q = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }

        isSearching  = true
        searchError  = nil
        results      = []
        hasSearched  = true

        do {
            results = try await strategy.execute(query: q, client: client)
        } catch {
            searchError = error.localizedDescription
        }
        isSearching = false
    }
}

// MARK: - LookupStrategy

/// Query strategies available in `NARACatalogLookupView`.
///
/// Each strategy maps to a specific `NARACatalogClient` method, matching the
/// collection-type logic already used in `SourceExplorerView`.
enum LookupStrategy: String, CaseIterable, Identifiable, Sendable {
    /// Lot file in RG 59 (State Dept. central files series).
    case lotFileRG59
    /// Lot file in RG 84 (diplomatic post records — F-designator lots).
    case lotFileRG84
    /// Keywords searched within RG 59.
    case keywordRG59
    /// Keywords searched within RG 84.
    case keywordRG84
    /// Open a pre-scoped NARA Catalog URL for a decimal/central file identifier.
    /// Does not require an API key.
    case centralURL
    /// General free-text keyword search across all record groups.
    case keyword

    var id: String { rawValue }

    // MARK: - Routing a detected citation to a strategy

    /// The lot-file strategy for a detected citation: RG 84 when the note names RG 84 or the lot
    /// carries an F-designator (State Dept. diplomatic-post records), else RG 59 — mirroring
    /// SourceNoteKit's own lot→record-group heuristic (`lotFileRecordGroup`).
    ///
    /// Lives on the strategy rather than on `NARACatalogLookupView` because it is a routing rule,
    /// not a view concern, and because a `View` is implicitly `@MainActor` under Swift 6 — which
    /// made every call from the nonisolated `NARALookupAnalyzer` a concurrency warning. The analyzer
    /// is deliberately isolation-free so it can be driven off the main actor by its tests.
    static func lotStrategy(recordGroup: String?, lotFile: String) -> LookupStrategy {
        if recordGroup == "84" { return .lotFileRG84 }
        if recordGroup == "59" { return .lotFileRG59 }
        // No explicit RG in the note: an F-designator lot ("55 F 44", "57–F103") is RG 84.
        let fPattern = #"(?:\d|^)\s*[–—\-]?\s*[Ff]\s*[–—\-]?\s*\d"#
        if lotFile.range(of: fPattern, options: .regularExpression) != nil { return .lotFileRG84 }
        return .lotFileRG59
    }

    /// The keyword strategy for a series/collection citation: scoped to RG 59/84 when the note
    /// names one, else a general keyword search (e.g. a presidential-library collection, which
    /// has no record group).
    static func keywordStrategy(recordGroup: String?) -> LookupStrategy {
        switch recordGroup {
        case "59": return .keywordRG59
        case "84": return .keywordRG84
        default:   return .keyword
        }
    }

    var displayName: String {
        switch self {
        case .lotFileRG59:  return String(localized: "nara.lookup.strategy.lotFileRG59",
                                          defaultValue: "Lot file — RG 59 (State Dept.)")
        case .lotFileRG84:  return String(localized: "nara.lookup.strategy.lotFileRG84",
                                          defaultValue: "Lot file — RG 84 (Post Records)")
        case .keywordRG59:  return String(localized: "nara.lookup.strategy.keywordRG59",
                                          defaultValue: "Keywords in RG 59")
        case .keywordRG84:  return String(localized: "nara.lookup.strategy.keywordRG84",
                                          defaultValue: "Keywords in RG 84")
        case .centralURL:   return String(localized: "nara.lookup.strategy.centralURL",
                                          defaultValue: "Central files identifier (no API key)")
        case .keyword:      return String(localized: "nara.lookup.strategy.keyword",
                                          defaultValue: "General keyword search")
        }
    }

    var hint: String {
        switch self {
        case .lotFileRG59:
            return String(localized: "nara.lookup.strategy.lotFileRG59.hint",
                          defaultValue: "Use for D-designator lot numbers (e.g. \"63D135\" or \"68 D 277\"). Queries State Dept. lot file series in RG 59.")
        case .lotFileRG84:
            return String(localized: "nara.lookup.strategy.lotFileRG84.hint",
                          defaultValue: "Use for F-designator lot numbers (e.g. \"55F44\" or \"56 F 28\"). Queries diplomatic post record lots in RG 84.")
        case .keywordRG59:
            return String(localized: "nara.lookup.strategy.keywordRG59.hint",
                          defaultValue: "Use for series names, collection descriptions, or partial citation text. Restricts results to RG 59 (State Dept.).")
        case .keywordRG84:
            return String(localized: "nara.lookup.strategy.keywordRG84.hint",
                          defaultValue: "Use for series names or collection descriptions. Restricts results to RG 84 (State Dept. post records).")
        case .centralURL:
            return String(localized: "nara.lookup.strategy.centralURL.hint",
                          defaultValue: "Use for decimal file identifiers (e.g. \"862S.01/10-1646\") or central file keywords. Opens a pre-filtered NARA Catalog search — no API key required.")
        case .keyword:
            return String(localized: "nara.lookup.strategy.keyword.hint",
                          defaultValue: "General free-text search across all record groups in the NARA Catalog. Useful when the collection type is unclear.")
        }
    }

    /// Executes the appropriate `NARACatalogClient` query for this strategy.
    func execute(query: String, client: NARACatalogClient) async throws -> [NARACatalogResult] {
        switch self {
        case .lotFileRG59:
            return try await client.resolveLotFileVariants(lotNumber: query, recordGroup: "59")
        case .lotFileRG84:
            return try await client.resolveLotFileVariants(lotNumber: query, recordGroup: "84")
        case .keywordRG59:
            return try await client.searchByRecordGroup("59", keywords: query, maxResults: 5)
        case .keywordRG84:
            return try await client.searchByRecordGroup("84", keywords: query, maxResults: 5)
        case .centralURL:
            // Central files URL strategy is handled separately in the view
            // (opens browser); this path should not be reached.
            return []
        case .keyword:
            if let result = try await client.searchCatalog(query: query) {
                return [result]
            }
            return []
        }
    }
}
