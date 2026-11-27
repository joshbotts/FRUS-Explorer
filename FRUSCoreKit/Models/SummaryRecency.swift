// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Which of a document's summaries is the newer: the order the document's rail shows them in, newest
/// first, and so the summary a collection prints where its entry chose none.
///
/// By when each was made, then when it was last saved, then by id, so the order is total. `createdAt` is
/// never stamped again; `lastModified` is a save stamp, which two bulk paths rewrite for reasons of their
/// own, so it only breaks a tie (R-5 P3b-6). A summary with no date sorts as the oldest. The app's
/// `GeneratedSummary.ranksAbove(_:_:)`, which the rail, the change review and search read, is this rule
/// over its records.
///
/// Version history:
///   1.0 — L34: the rule of `GeneratedSummary.ranksAbove(_:_:)`, moved here over values, so that a
///          collection's headnote, the entry inspector's card and a document printed at summary depth take
///          the summary the rail shows first, where each took the first the store returned, which is the
///          oldest (R2b's finding: d475's oldest of four)
public struct SummaryRecency: Sendable, Equatable {

    /// When the summary was made; `nil` for a record from before the date was kept.
    public let createdAt: Date?

    /// When the summary was last saved.
    public let lastModified: Date?

    /// The summary's id: the last tie-break, so that no two summaries rank alike.
    public let id: UUID

    /// A summary's dates and id.
    ///
    /// - Parameters:
    ///   - createdAt: When the summary was made.
    ///   - lastModified: When it was last saved.
    ///   - id: Its id.
    public init(createdAt: Date?, lastModified: Date?, id: UUID) {
        self.createdAt = createdAt
        self.lastModified = lastModified
        self.id = id
    }

    /// Whether this summary comes before `other`, newest first.
    ///
    /// - Parameter other: The summary to compare with.
    /// - Returns: `true` when this one is the newer.
    public func ranksAbove(_ other: SummaryRecency) -> Bool {
        let made = createdAt ?? .distantPast, otherMade = other.createdAt ?? .distantPast
        if made != otherMade { return made > otherMade }
        let saved = lastModified ?? .distantPast, otherSaved = other.lastModified ?? .distantPast
        if saved != otherSaved { return saved > otherSaved }
        return id.uuidString < other.id.uuidString
    }

    /// The newest of `summaries`, or `nil` when there is none.
    ///
    /// - Parameters:
    ///   - summaries: The summaries, in any order.
    ///   - recency: Each one's dates and id.
    /// - Returns: The one that ranks above every other.
    public static func newest<Summary>(_ summaries: [Summary],
                                       recency: (Summary) -> SummaryRecency) -> Summary? {
        // `min(by:)` with "comes first" as its order is the first of the newest-first order.
        summaries.min { recency($0).ranksAbove(recency($1)) }
    }

    /// The summary a headnote prints where its entry chose none: the newest stored under the collection's
    /// prompt, else the newest of all. The assembly's headnote and the entry inspector's card both read it,
    /// so the card shows and edits the summary the export prints.
    ///
    /// - Parameters:
    ///   - stored: The document's stored summaries, headnote drafts and empty ones already left out.
    ///   - preferredPromptId: The prompt the entry's settings name, if any.
    ///   - promptId: Each summary's prompt.
    ///   - recency: Each summary's dates and id.
    /// - Returns: The summary to print, or `nil` when none is stored.
    public static func headnoteFallback<Summary>(_ stored: [Summary], preferredPromptId: UUID?,
                                                 promptId: (Summary) -> UUID,
                                                 recency: (Summary) -> SummaryRecency) -> Summary? {
        if let preferredPromptId,
           let preferred = newest(stored.filter { promptId($0) == preferredPromptId }, recency: recency) {
            return preferred
        }
        return newest(stored, recency: recency)
    }
}

extension GeneratedSummaryExport {

    /// This summary's place in the newest-first order.
    public var recency: SummaryRecency {
        SummaryRecency(createdAt: createdAt, lastModified: lastModified, id: id)
    }
}
