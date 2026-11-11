// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - LookupStrategy

/// Query strategies available in `NARACatalogLookupView`.
///
/// Each strategy maps to a specific `NARACatalogClient` method, matching the
/// collection-type logic already used in `SourceExplorerView`.
///
/// Version history:
///   1.0 — FRUS Explorer Light's S22c: out of `NARACatalogLookupView.swift`, a SwiftUI file, into
///          FRUSCoreKit unchanged but for access; the view stays the app's
public enum LookupStrategy: String, CaseIterable, Identifiable, Sendable {
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

    public var id: String { rawValue }

    // MARK: - Routing a detected citation to a strategy

    /// The lot-file strategy for a detected citation: RG 84 when the note names RG 84 or the lot
    /// carries an F-designator (State Dept. diplomatic-post records), else RG 59 — mirroring
    /// SourceNoteKit's own lot→record-group heuristic (`lotFileRecordGroup`).
    ///
    /// Lives on the strategy rather than on `NARACatalogLookupView` because it is a routing rule,
    /// not a view concern, and because a `View` is implicitly `@MainActor` under Swift 6 — which
    /// made every call from the nonisolated `NARALookupAnalyzer` a concurrency warning. The analyzer
    /// is deliberately isolation-free so it can be driven off the main actor by its tests.
    public static func lotStrategy(recordGroup: String?, lotFile: String) -> LookupStrategy {
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
    public static func keywordStrategy(recordGroup: String?) -> LookupStrategy {
        switch recordGroup {
        case "59": return .keywordRG59
        case "84": return .keywordRG84
        default:   return .keyword
        }
    }

    public var displayName: String {
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

    public var hint: String {
        switch self {
        case .lotFileRG59:
            return String(localized: "nara.lookup.strategy.lotFileRG59.hint",
                          defaultValue: "Use for D-designator lot numbers (e.g. “63D135” or “68 D 277”). Queries State Dept. lot file series in RG 59.")
        case .lotFileRG84:
            return String(localized: "nara.lookup.strategy.lotFileRG84.hint",
                          defaultValue: "Use for F-designator lot numbers (e.g. “55F44” or “56 F 28”). Queries diplomatic post record lots in RG 84.")
        case .keywordRG59:
            return String(localized: "nara.lookup.strategy.keywordRG59.hint",
                          defaultValue: "Use for series names, collection descriptions, or partial citation text. Restricts results to RG 59 (State Dept.).")
        case .keywordRG84:
            return String(localized: "nara.lookup.strategy.keywordRG84.hint",
                          defaultValue: "Use for series names or collection descriptions. Restricts results to RG 84 (State Dept. post records).")
        case .centralURL:
            return String(localized: "nara.lookup.strategy.centralURL.hint",
                          defaultValue: "Use for decimal file identifiers (e.g. “862S.01/10-1646”) or central file keywords. Opens a pre-filtered NARA Catalog search — no API key required.")
        case .keyword:
            return String(localized: "nara.lookup.strategy.keyword.hint",
                          defaultValue: "General free-text search across all record groups in the NARA Catalog. Useful when the collection type is unclear.")
        }
    }

    /// Executes the appropriate `NARACatalogClient` query for this strategy.
    public func execute(query: String, client: NARACatalogClient) async throws -> [NARACatalogResult] {
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
