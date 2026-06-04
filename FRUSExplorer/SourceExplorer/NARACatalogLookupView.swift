// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - NARACatalogLookupView

/// Sheet that queries the NARA Catalog using user-selected document text.
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
struct NARACatalogLookupView: View {

    let initialText: String

    // MARK: - Dependencies

    private let client = NARACatalogClient()

    // MARK: - State

    @State private var queryText: String
    @State private var strategy: LookupStrategy = .keywordRG59
    @State private var isSearching = false
    @State private var results: [NARACatalogResult] = []
    @State private var hasAPIKey = false
    @State private var searchError: String? = nil
    @State private var hasSearched = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL)  private var openURL

    // MARK: - Init

    init(initialText: String) {
        self.initialText = initialText
        _queryText = State(initialValue: initialText.trimmingCharacters(in: .whitespacesAndNewlines))
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
            Text(String(localized: "nara.lookup.title", defaultValue: "Look Up in NARA Catalog"))
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()

            // Content area
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    queryFieldSection
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

            // Button bar
            HStack(spacing: 10) {
                Button(String(localized: "nara.lookup.close", defaultValue: "Close")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

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
                           defaultValue: "A NARA Catalog API key is required for this strategy. Add your key in Settings → NARA API. The \"Central files identifier\" strategy does not require a key."),
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
                Button(period.label) {
                    openURL(period.url)
                }
                .font(.callout)
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
