// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - PageSpanResolver

/// Resolves a printed arabic page number to the document whose page span contains it.
///
/// FRUS TEI marks every printed page with a `<pb n="427" xml:id="pg_427"/>` element and
/// references a specific page with `<ref target="#pg_427">`. A page has no `<div>` of its
/// own — the containing *document* must be inferred from where its opening `<pb>` falls
/// relative to the neighbouring documents' opening `<pb>` elements.
///
/// ## Span definition
/// Given the (documentId, firstArabicPage) boundary of every document in a section,
/// sorted ascending by page, document *D*'s span is `[D.firstPage, nextDoc.firstPage − 1]`.
/// The **final** document's span is closed at the section's highest recorded page (every
/// printed page carries a `<pb>` marker, so the maximum row is the section's last real
/// page) rather than `Int.max` — a section whose pagination ends early must not claim
/// every later page of the volume.
///
/// ## Single source of truth
/// Both the display path (`PageRangeStore.span`) and the indexing-time resolver
/// (`IndexingPipeline.resolvePageBasedCrossReferences`) call
/// ``documentContaining(page:in:)`` so the two can never diverge again.
///
/// Version history:
///   1.0 — Session 2026-07-05: extracted from `PageRangeStore.span` (Session 162 fix
///          preserved: the final span closes at the section max page, not `Int.max`) so
///          the indexing-time page-reference resolver and the reader share one algorithm.
public enum PageSpanResolver {

    /// Returns the documentId whose page span contains `page`, or `nil` if none.
    ///
    /// - Parameters:
    ///   - page: The arabic printed page number to resolve.
    ///   - rows: `(documentId, pageInt)` pairs for a **single section**, one per `<pb>`
    ///     element. Order is irrelevant — the function sorts internally by page number
    ///     (ties broken by input order) before deriving document boundaries.
    /// - Returns: The documentId whose span `[firstPage, nextDoc.firstPage − 1]` (last
    ///   document closed at the section max page) contains `page`, or `nil` when no
    ///   document's span contains it (including an empty input, or a page below the first
    ///   document's opening page).
    public static func documentContaining(
        page: Int,
        in rows: [(documentId: String, pageInt: Int)]
    ) -> String? {
        guard let maxPage = rows.map(\.pageInt).max() else { return nil }

        // Sort by page ascending, preserving input order for equal pages so the first
        // occurrence of a document (its opening <pb>) wins during deduplication. The
        // display path supplies rows pre-sorted by `page_number_int, rowid`; sorting here
        // makes the function order-independent for callers that do not (e.g. the indexer).
        let sorted = rows.enumerated()
            .sorted { lhs, rhs in
                lhs.element.pageInt != rhs.element.pageInt
                    ? lhs.element.pageInt < rhs.element.pageInt
                    : lhs.offset < rhs.offset
            }
            .map(\.element)

        // Deduplicate: keep only the first occurrence of each document (its first <pb>).
        var seen = Set<String>()
        var boundaries: [(documentId: String, firstPage: Int)] = []
        for row in sorted where seen.insert(row.documentId).inserted {
            boundaries.append((row.documentId, row.pageInt))
        }
        guard !boundaries.isEmpty else { return nil }

        for i in 0..<boundaries.count {
            let start = boundaries[i].firstPage
            let end = i + 1 < boundaries.count ? boundaries[i + 1].firstPage - 1 : maxPage
            if page >= start && page <= end {
                return boundaries[i].documentId
            }
        }
        return nil
    }
}
