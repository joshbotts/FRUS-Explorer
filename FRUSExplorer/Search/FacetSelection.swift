// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - FacetRowState

/// What a facet row is currently set to (#775).
///
/// Three states, not two: a row the user has said nothing about is not the same as one they have
/// ruled out, and collapsing them would make "exclude 1950" indistinguishable from "select every
/// year except 1950" — which are different requests the moment the panel is re-paged or filtered.
enum FacetRowState: Sendable, Equatable {
    /// The user has expressed no opinion. The row does not constrain the search.
    case neutral
    /// The user wants this value.
    case included
    /// The user wants this value gone.
    case excluded

    /// The next state when the row is activated, cycling neutral → included → excluded → neutral.
    var next: FacetRowState {
        switch self {
        case .neutral:  return .included
        case .included: return .excluded
        case .excluded: return .neutral
        }
    }
}

// MARK: - FacetSelection

/// A pending include/exclude selection within one facet section (#775).
///
/// ## Why the selection is staged rather than applied per tap
/// A facet section is computed **against the active filters**, and applying a narrowing re-runs the
/// search, which invalidates every section. So on the shipped behaviour, tapping 1951 leaves a
/// Years section containing only 1951 — there is no second row left to tap, and multi-select is
/// structurally unreachable one tap at a time. Staging is what makes it possible: the panel keeps
/// the full bucket list, taps mutate this value and run nothing, and one Apply commits the whole
/// selection as a single search.
///
/// ## Why include and exclude resolve here and never reach SQL
/// ``resolved(from:)`` turns the two sets into the one set the query actually runs, over the
/// section's own bucket keys. Two consequences, both deliberate:
///
/// 1. **#775's equivalence holds by construction.** The issue requires that *include 1951 and
///    1953* and *include 1950–1953 then exclude 1950 and 1952* reach the same results. After
///    resolution they are literally the same `["1951", "1953"]`, so they cannot diverge — no
///    second code path has to agree with the first.
/// 2. **No negation reaches the database.** A `NOT IN` spelling would have been the obvious one and
///    is a trap: `substr(NULL, 1, 4) NOT IN ('1950')` evaluates to NULL, SQLite drops the row, and
///    excluding a single year would silently delete every undated document while the panel went on
///    reporting them present.
///
/// ## The universe matters
/// Resolution is over the buckets the section currently shows. An exclude-only selection therefore
/// means "everything in this result set except these", which is what the user sees and can
/// predict. It is *not* "everything in the corpus except these" — a distinction that would matter
/// the moment the keywords changed under a filter the user had not revisited.
///
/// Version history:
///   1.0 — Session 2026-08-10: #775
struct FacetSelection: Sendable, Equatable {

    /// Bucket keys the user included.
    private(set) var included: Set<String> = []

    /// Bucket keys the user excluded.
    private(set) var excluded: Set<String> = []

    /// An empty selection — the state a panel opens in and returns to when cleared.
    init() {}

    /// Creates a selection directly, for tests and for restoring a live filter into the panel.
    init(included: Set<String>, excluded: Set<String> = []) {
        self.included = included
        self.excluded = excluded
    }

    /// Whether the user has expressed any opinion at all.
    var isEmpty: Bool { included.isEmpty && excluded.isEmpty }

    /// How many rows carry an opinion — what a summary strip counts.
    var count: Int { included.count + excluded.count }

    /// This row's state.
    func state(of key: String) -> FacetRowState {
        if included.contains(key) { return .included }
        if excluded.contains(key) { return .excluded }
        return .neutral
    }

    /// Advances one row through neutral → included → excluded → neutral.
    ///
    /// A key is only ever in one of the two sets: the cycle removes it from the previous one
    /// before adding it to the next, so a row can never be both included and excluded — a state
    /// no resolution rule could interpret and no UI could draw.
    mutating func cycle(_ key: String) {
        set(key, to: state(of: key).next)
    }

    /// Puts one row into an explicit state.
    mutating func set(_ key: String, to state: FacetRowState) {
        included.remove(key)
        excluded.remove(key)
        switch state {
        case .neutral:  break
        case .included: included.insert(key)
        case .excluded: excluded.insert(key)
        }
    }

    /// Clears every opinion.
    mutating func removeAll() {
        included.removeAll()
        excluded.removeAll()
    }

    /// Every included key, for a summary that has to name them.
    var includedKeys: Set<String> { included }

    /// Every excluded key.
    var excludedKeys: Set<String> { excluded }

    /// The single set of keys this selection asks for, over `universe`.
    ///
    /// - Returns: `nil` when the selection expresses nothing, meaning "do not filter on this
    ///   dimension at all". An **empty array is a real answer** — the user excluded everything they
    ///   included — and callers must pass it through rather than treating it as absent, or the
    ///   search silently widens to the whole corpus under a chip promising the opposite.
    func resolved(from universe: [String]) -> [String]? {
        guard !isEmpty else { return nil }
        // Include-only and exclude-only are different questions. With nothing included, the
        // starting point is everything the section currently shows; with something included, it is
        // exactly that, and any exclusion of a row the user also included cancels it.
        let base: [String] = included.isEmpty ? universe : universe.filter { included.contains($0) }
        return base.filter { !excluded.contains($0) }
    }
}

// MARK: - FacetSelectionApplier

/// Writes a resolved facet selection onto `SearchParameters` (#775).
///
/// One implementation, both platforms. The single-tap narrowing has two — `FacetNarrowing.apply`
/// for macOS and `SearchViewModel.applyFacetNarrowing` for iOS, over different storage — and they
/// have already drifted once (the macOS one still does not clear `personAnchor`). A second pair
/// would drift the same way, so the multi-select path has exactly one applier and iOS routes
/// through it.
///
/// Version history:
///   1.0 — Session 2026-08-10: #775
enum FacetSelectionApplier {

    /// Applies a resolved key set for `section` to `parameters`.
    ///
    /// - Parameter keys: the resolved set from ``FacetSelection/resolved(from:)``. `nil` clears the
    ///   dimension; an **empty array is kept as an empty array**, because it means "the user
    ///   excluded everything they included" and the SQL contract for `yearKeys` reads that as
    ///   matching nothing. Coercing it to `nil` here would widen the search to the whole corpus
    ///   under a chip promising the opposite.
    static func apply(_ section: FacetSection, keys: [String]?,
                      to parameters: inout SearchParameters) {
        switch section {
        case .years:
            parameters.yearKeys = keys?.sorted()
        case .volumes:
            // `volumeIds`' own contract is the other way round — empty means no filter — and it is
            // reached from scopes that legitimately resolve to nothing, so an empty selection
            // clears rather than blanks the search. The Volumes facet cannot produce an empty
            // resolution from a non-empty selection anyway: excluding every listed volume is
            // "show me none of the volumes in this match", which the panel expresses as clearing.
            parameters.volumeIds = (keys?.isEmpty ?? true) ? nil : keys?.sorted()
        case .people, .documentType, .provenance:
            // Not staged — see `FacetPanelController.stagedSections`. Reaching here would mean a
            // section was added to that set without an applier, which is a programming error and
            // silently doing nothing is the safe failure.
            break
        }
    }
}
