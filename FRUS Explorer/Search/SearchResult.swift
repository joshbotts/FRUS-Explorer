// Search/SearchResult.swift
// Value types that represent one search hit.
//
// IMPORTANT: This file imports Foundation only. Keeping it free of SwiftUI and
// any @MainActor context ensures the compiler cannot infer @MainActor isolation on
// SearchResult.MatchField or its synthesised Hashable conformance, which would
// break usage inside the SearchEngine actor under -strict-concurrency=complete.

import Foundation

// MARK: - SearchRecord

/// One indexed, searchable unit — a document-level or section division.
struct SearchRecord: Identifiable, Sendable {
    /// Matches OutlineNode.id format: "\(volumeID)__\(divisionID)"
    let id: String
    let volumeID: String
    let divisionID: String

    let title: String
    let dateline: String?
    let isEditorialNote: Bool

    /// ISO-format date from the first <date> in the dateline.
    /// Sourced from @when (exact) or @from/@notBefore (range start).
    /// May be partial: "1969", "1969-03", or "1969-03-15".
    let isoDate: String?

    /// ISO-format end date for documents that span a range (@to / @notAfter).
    /// Nil for point-in-time documents.
    let isoDateEnd: String?

    /// Lowercased, whitespace-normalised concatenation of all body paragraphs.
    let normalizedBody: String

    // Structured entities extracted from TEI markup
    let personNames: [String]   // lowercased, de-duped
    let placeNames:  [String]
    let orgNames:    [String]
    let terms:       [String]   // diplomatic terms and abbreviations

    /// Subject taxonomy IDs assigned to this document by the FRUS subject index.
    let subjectIDs: [String]
}

// MARK: - SearchResult

struct SearchResult: Identifiable, Sendable {
    let id: String              // same as SearchRecord.id
    let record: SearchRecord
    // Array (not Set) so SearchEngine actor methods can build results without
    // ever needing Hashable — which the compiler would infer as @MainActor because
    // AppStore (@MainActor @Observable) stores [SearchResult] as a property.
    let matchedFields: [MatchField]

    // Hashable is declared here so SwiftUI ForEach(id: \.self) works in
    // @MainActor view code. SearchEngine itself only uses [MatchField] arrays.
    enum MatchField: Hashable, Sendable {
        case title, body, person, place, org, term, summary, annotation, date, subject
    }
}
