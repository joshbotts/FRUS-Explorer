// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - DocumentEngagement

/// What has been done with one document — **kept apart by kind** (W-13 session 1).
///
/// ## Why this is not `ProjectEngagedDocuments`
/// `ProjectEngagedDocuments.keys` unions visits, notes and collection entries into one flat
/// `Set<String>`, which is exactly right for its job (the search History scope asks only *has this
/// project touched the document*). A coverage statement asks a different question — "opened 43 of
/// 267, annotated 12" — and that union has already discarded the split it needs. So this is a
/// second reading of the same three sources, not a wrapper around the first.
///
/// An `OptionSet` rather than an enum because the kinds **co-occur**: the common case for a
/// document a researcher has worked on is opened *and* annotated *and* collected, and a type that
/// could hold only one of those would force the gatherer to choose before the caller could count.
///
/// Version history:
///   1.0 — W-13 session 1: initial implementation
///   1.1 — Session 2026-10-25 (FRUS Explorer Light, S17b): moved into FRUSCoreKit, public, unchanged, from
///          the app's `ProjectContext/DocumentEngagementService.swift`, with the method appendix's coverage
public struct DocumentEngagement: OptionSet, Sendable, Hashable {

    /// The bitmask backing the set.
    public let rawValue: Int

    /// Creates an engagement set from its bitmask.
    ///
    /// - Parameter rawValue: The bitmask.
    public init(rawValue: Int) { self.rawValue = rawValue }

    /// The document was opened while this scope was active (`ReadingHistoryEntry`).
    ///
    /// **Gated on research logging**, so this member is *undercounted* whenever the reader has
    /// "Log Research Sessions" off — see ``EngagementCoverage/isOpenedComplete``.
    public static let opened = DocumentEngagement(rawValue: 1 << 0)

    /// The document carries a research note, or a highlight belonging to one.
    public static let annotated = DocumentEngagement(rawValue: 1 << 1)

    /// The document is an entry in a collection.
    public static let collected = DocumentEngagement(rawValue: 1 << 2)

    /// The single state a list row displays, when several kinds apply at once.
    ///
    /// Ranked by **how deliberate the act was**, strongest first: annotating is work done on the
    /// document, collecting is a judgement that it belongs to an argument, and opening may be no
    /// more than a mis-tap. A row shows the strongest thing that is true of it.
    public var state: State {
        if contains(.annotated) { return .annotated }
        if contains(.collected) { return .collected }
        if contains(.opened) { return .opened }
        return .untouched
    }

    // MARK: - State

    /// The one engagement a row shows.
    ///
    /// Version history:
    ///   1.0 — W-13 session 1: initial implementation
    public enum State: String, Sendable, CaseIterable {
        /// Nothing in this scope has touched the document.
        case untouched
        /// Opened, and nothing more.
        case opened
        /// In a collection, and not annotated.
        case collected
        /// Carries a note or a highlight.
        case annotated

        /// The SF Symbol a row badge draws. `nil` for `untouched`: the absence of a badge *is* the
        /// untouched state, and in a systematic review most rows are untouched — badging them would
        /// put a mark on every line and make the engaged ones harder to find, not easier.
        public var symbolName: String? {
            switch self {
            case .untouched: return nil
            case .opened: return "eye"
            case .collected: return "folder"
            case .annotated: return "note.text"
            }
        }

        /// The badge's accessibility label. Present for every case, including `untouched`, because
        /// a screen reader has no "absence of a badge" to perceive.
        public var label: String {
            switch self {
            case .untouched:
                return String(localized: "engagement.state.untouched", defaultValue: "Untouched")
            case .opened:
                return String(localized: "engagement.state.opened", defaultValue: "Opened")
            case .collected:
                return String(localized: "engagement.state.collected", defaultValue: "In a collection")
            case .annotated:
                return String(localized: "engagement.state.annotated", defaultValue: "Annotated")
            }
        }
    }
}

// MARK: - EngagementCoverage

/// A corpus partitioned by what has been done with each of its documents (W-13 session 1).
///
/// The sibling of ``WorkingCorpusResolution``, and deliberately shaped like it: that type answers
/// *how much of this corpus can this device reach*, this one answers *how much of it have I worked
/// on*. Both always state their denominator, for the same reason — "43 opened" invites the reader
/// to supply a total they do not have.
///
/// The counts are stored rather than derived on demand because a SwiftUI body reads all four of
/// them on every pass, and each would otherwise be a fresh scan of `engagements`.
///
/// Version history:
///   1.0 — W-13 session 1: initial implementation
///   1.1 — Session 2026-10-25 (FRUS Explorer Light, S17b): moved into FRUSCoreKit, public, for the method
///          appendix's coverage block; each sentence also takes the locale that groups its numbers
///          (``coverageDescription(locale:)``, ``breakdownDescription(locale:)``, ``untouchedDescription(locale:)``)
public struct EngagementCoverage: Sendable, Equatable {

    /// Every corpus key that carries **some** engagement, and which kinds. Untouched keys are
    /// absent rather than mapped to an empty set, so `engagements.count` is the engaged count.
    public let engagements: [String: DocumentEngagement]

    /// Documents the corpus names — the denominator of every sentence below.
    public let totalCount: Int

    /// Documents opened in this scope.
    public let openedCount: Int

    /// Documents carrying a note or a highlight.
    public let annotatedCount: Int

    /// Documents in a collection.
    public let collectedCount: Int

    /// Whether ``openedCount`` can be trusted as a total.
    ///
    /// `false` when research logging is off. It does **not** mean the count is zero — entries
    /// written before the switch was turned off are still there — it means the app stopped
    /// recording and the number is a floor. Every surface showing `openedCount` must show
    /// ``loggingCaveat`` beside it.
    public let isOpenedComplete: Bool

    /// Creates a partition from its counts, as `DocumentEngagementService.partition` makes one.
    public init(engagements: [String: DocumentEngagement], totalCount: Int, openedCount: Int,
                annotatedCount: Int, collectedCount: Int, isOpenedComplete: Bool) {
        self.engagements = engagements
        self.totalCount = totalCount
        self.openedCount = openedCount
        self.annotatedCount = annotatedCount
        self.collectedCount = collectedCount
        self.isOpenedComplete = isOpenedComplete
    }

    /// Documents with at least one engagement.
    public var engagedCount: Int { engagements.count }

    /// Documents nothing has touched — the number a systematic review is actually hunting.
    public var untouchedCount: Int { max(0, totalCount - engagedCount) }

    /// The kinds recorded against one `"volumeId/documentId"` key.
    ///
    /// - Parameter key: The document key.
    /// - Returns: The engagements, empty when the document is untouched.
    public func engagement(for key: String) -> DocumentEngagement {
        engagements[key] ?? []
    }

    /// The single state a row for `key` displays.
    ///
    /// - Parameter key: The document key.
    /// - Returns: The strongest engagement that applies, or `.untouched`.
    public func state(for key: String) -> DocumentEngagement.State {
        engagement(for: key).state
    }

    /// The headline sentence, stating both numbers the way ``WorkingCorpusResolution`` does.
    ///
    /// Numbers go through `formatted()` rather than `%lld` so they carry the reader's grouping
    /// separators. That is not cosmetic here: `QueryMethodAppendix` prints every other number this
    /// way, and a methods appendix whose table said "1,234" beside a coverage line saying "1234"
    /// invites the reader to wonder whether the two came from the same count.
    ///
    /// Says "worked on" rather than "engaged": the codebase's own word for this set is *engaged*,
    /// but that is a term of art from `ProjectEngagedDocuments` and no reader has met it.
    public var coverageDescription: String { coverageDescription(locale: .autoupdatingCurrent) }

    /// The headline sentence, its numbers grouped for `locale`.
    ///
    /// - Parameter locale: The locale that groups the numbers.
    /// - Returns: The sentence.
    public func coverageDescription(locale: Locale) -> String {
        String(format: String(localized: "engagement.coverage %@ %@",
                              defaultValue: "%@ of %@ documents worked on"),
               engagedCount.formatted(.number.locale(locale)), totalCount.formatted(.number.locale(locale)))
    }

    /// The per-kind breakdown that defines the headline, or `nil` when nothing is engaged.
    ///
    /// All three kinds are always named, zeros included, because in a review a zero is a finding:
    /// "12 opened · 0 annotated · 0 collected" says something a line that omitted the empty kinds
    /// would leave the reader to infer.
    public var breakdownDescription: String? { breakdownDescription(locale: .autoupdatingCurrent) }

    /// The per-kind breakdown, its numbers grouped for `locale`, or `nil` when nothing is engaged.
    ///
    /// - Parameter locale: The locale that groups the numbers.
    /// - Returns: The breakdown, or `nil`.
    public func breakdownDescription(locale: Locale) -> String? {
        guard engagedCount > 0 else { return nil }
        return String(format: String(localized: "engagement.breakdown %@ %@ %@",
                                     defaultValue: "%@ opened · %@ annotated · %@ collected"),
                      openedCount.formatted(.number.locale(locale)), annotatedCount.formatted(.number.locale(locale)),
                      collectedCount.formatted(.number.locale(locale)))
    }

    /// The remainder, spelled out — "224 untouched".
    ///
    /// Separate from ``breakdownDescription`` rather than folded into it because the two surfaces
    /// read differently: a list caption is glanced at repeatedly and stays terse, while an exported
    /// methods appendix is read once and carefully, by someone checking a claim, and the number of
    /// documents the researcher did *not* open is the one a reviewer most wants stated rather than
    /// subtracted. The two cannot disagree — this is `totalCount - engagedCount`.
    public var untouchedDescription: String { untouchedDescription(locale: .autoupdatingCurrent) }

    /// The remainder, its number grouped for `locale`.
    ///
    /// - Parameter locale: The locale that groups the number.
    /// - Returns: The sentence.
    public func untouchedDescription(locale: Locale) -> String {
        String(format: String(localized: "engagement.untouched %@",
                              defaultValue: "%@ untouched"),
               untouchedCount.formatted(.number.locale(locale)))
    }

    /// The caveat that must accompany ``openedCount`` when logging is off; `nil` when it is on.
    public var loggingCaveat: String? {
        guard !isOpenedComplete else { return nil }
        return String(localized: "engagement.caveat.loggingOff",
                      defaultValue: "Opened is a floor, not a total — research logging is off.")
    }
}

// MARK: - DocumentEngagementService

/// Gathers the three engagement kinds separately and partitions a corpus by them (W-13 session 1).
///
/// ## The gatherer shape, and why it is `ProjectLeadsService`'s
/// Each of the app's gatherers is `nonisolated`, takes a `ModelContext`, fetches unscoped and filters
/// in memory (a `[UUID].contains` predicate is unreliable in SwiftData) by the rules here, over the
/// rows' values, and returns keys. That is the shape
/// `ProjectLeadsService` settled on after its Phase-2a freeze, and the reason is the same one:
/// these fetches pull every note, visit and collection and fault each collection's
/// `documentEntries` relationship, which must never happen synchronously in a UI path.
///
/// The app's `coverage(forCorpusKeys:project:container:isOpenedComplete:)` is the only entry point a
/// view should use; the individual gatherers are exposed so the suite can drive them one at a time.
///
/// ## Scope is optional, on purpose
/// Every gatherer takes `UUID?`. With a project, it counts what that project did; without one it
/// counts what has been done on this device at all. A version that required a project would make
/// the feature invisible to every reader who has not created one, and "have I read this document"
/// is a question that does not need a project to be worth answering.
///
/// ## What cannot be attributed, and is therefore not counted
/// A `DocumentHighlight` carries **no** `projectId` — only an optional `noteId` — so under a
/// project scope a highlight counts only when its note belongs to that project. A standalone
/// highlight (`noteId == nil`) is a real annotation that no project can claim; it counts unscoped
/// and is invisible scoped. Recorded here rather than silently rounded away.
///
/// Version history:
///   1.0 — W-13 session 1: initial implementation
///   1.1 — Session 2026-10-25 (FRUS Explorer Light, S17b): moved into FRUSCoreKit, public, with the rules
///          over values: what counts as opened, annotated and collected (``openedKeys(among:forProject:)``,
///          ``annotatedKeys(among:highlights:forProject:)``, ``collectedKeys(among:forProject:)``,
///          ``gather(among:forProject:)``) and the partition, unchanged; the gatherers over the app's
///          models and its `coverage(forCorpusKeys:project:container:isOpenedComplete:)` stay in the app's
///          extension, and pass their rows here as values
public enum DocumentEngagementService {

    // MARK: - The rules, over values

    /// A visit's values, as the opened rule reads them (`ReadingHistoryEntry`'s).
    public struct Visit: Sendable, Equatable {
        /// The visited document's volume.
        public var volumeId: String
        /// The visited document.
        public var documentId: String
        /// The project active at the visit, or `nil`.
        public var projectId: UUID?

        /// Creates a visit's values.
        public init(volumeId: String, documentId: String, projectId: UUID?) {
            self.volumeId = volumeId
            self.documentId = documentId
            self.projectId = projectId
        }
    }

    /// A note's values, as the annotated rule reads them (`ResearchNote`'s).
    public struct Note: Sendable, Equatable {
        /// The note's id, which a highlight's `noteId` names.
        public var id: UUID
        /// The annotated document's volume, empty for a project-level note.
        public var volumeId: String
        /// The annotated document, empty for a project-level note.
        public var documentId: String
        /// The projects the note is filed under.
        public var projectIds: [UUID]

        /// Creates a note's values.
        public init(id: UUID, volumeId: String, documentId: String, projectIds: [UUID]) {
            self.id = id
            self.volumeId = volumeId
            self.documentId = documentId
            self.projectIds = projectIds
        }
    }

    /// A highlight's values, as the annotated rule reads them (`DocumentHighlight`'s).
    public struct Highlight: Sendable, Equatable {
        /// The highlighted document's volume.
        public var volumeId: String
        /// The highlighted document.
        public var documentId: String
        /// The note the highlight belongs to, or `nil` for a standalone highlight.
        public var noteId: UUID?

        /// Creates a highlight's values.
        public init(volumeId: String, documentId: String, noteId: UUID?) {
            self.volumeId = volumeId
            self.documentId = documentId
            self.noteId = noteId
        }
    }

    /// A collection's values, as the collected rule reads them (`Collection`'s, with its entries').
    public struct CollectionDocuments: Sendable, Equatable {
        /// The projects the collection is filed under.
        public var projectIds: [UUID]
        /// Its entries, each as its kind (`CollectionEntryKind`'s raw value) and the document it names.
        public var entries: [Entry]

        /// One entry's values.
        public struct Entry: Sendable, Equatable {
            /// The entry's kind, as `CollectionEntry.kind` stores it.
            public var kind: String
            /// The named document's volume, empty for an entry that names none.
            public var volumeId: String
            /// The named document, empty for an entry that names none.
            public var documentId: String

            /// Creates an entry's values.
            public init(kind: String, volumeId: String, documentId: String) {
                self.kind = kind
                self.volumeId = volumeId
                self.documentId = documentId
            }
        }

        /// Creates a collection's values.
        public init(projectIds: [UUID], entries: [Entry]) {
            self.projectIds = projectIds
            self.entries = entries
        }
    }

    /// The four sources the engagement kinds are gathered from, as values.
    public struct Sources: Sendable, Equatable {
        /// Every visit to consider.
        public var visits: [Visit]
        /// Every note to consider.
        public var notes: [Note]
        /// Every highlight to consider.
        public var highlights: [Highlight]
        /// Every collection to consider.
        public var collections: [CollectionDocuments]

        /// Creates the sources.
        public init(visits: [Visit], notes: [Note], highlights: [Highlight],
                    collections: [CollectionDocuments]) {
            self.visits = visits
            self.notes = notes
            self.highlights = highlights
            self.collections = collections
        }
    }

    /// The documents opened in this scope.
    ///
    /// **Gated on research logging at the writer**, so an empty result may mean "read nothing" or
    /// "recorded nothing"; the caller pairs it with whether research logging is on.
    ///
    /// - Parameters:
    ///   - visits: the visits to consider.
    ///   - projectId: The project to attribute to, or `nil` for every visit.
    /// - Returns: `"volumeId/documentId"` keys.
    public nonisolated static func openedKeys(among visits: [Visit],
                                              forProject projectId: UUID?) -> Set<String> {
        var keys = Set<String>()
        for visit in visits
        where !visit.volumeId.isEmpty && !visit.documentId.isEmpty
            && (projectId == nil || visit.projectId == projectId) {
            keys.insert(key(visit.volumeId, visit.documentId))
        }
        return keys
    }

    /// The documents carrying a research note, or a highlight belonging to one.
    ///
    /// - Parameters:
    ///   - notes: the notes to consider.
    ///   - highlights: the highlights to consider.
    ///   - projectId: The project to attribute to, or `nil` for every annotation.
    /// - Returns: `"volumeId/documentId"` keys.
    public nonisolated static func annotatedKeys(among notes: [Note],
                                                 highlights: [Highlight],
                                                 forProject projectId: UUID?) -> Set<String> {
        let inScope = notes.filter { isInScope($0.projectIds, forProject: projectId) }
        var keys = Set<String>()
        for note in inScope where !note.volumeId.isEmpty && !note.documentId.isEmpty {
            keys.insert(key(note.volumeId, note.documentId))
        }
        // A highlight has no project of its own; it inherits its note's. Unscoped, every highlight
        // counts — including the standalone ones, which are exactly what a scope cannot claim.
        let claimable = Set(inScope.map(\.id))
        for highlight in highlights
        where !highlight.volumeId.isEmpty && !highlight.documentId.isEmpty
            && (projectId == nil || highlight.noteId.map(claimable.contains) == true) {
            keys.insert(key(highlight.volumeId, highlight.documentId))
        }
        return keys
    }

    /// The documents that are entries in a collection.
    ///
    /// Not shared with `ProjectLeadsService.collectionSeedKeys`, which answers the same question
    /// for a **mandatory** project and unions its answer into a seed. The shared thing between them
    /// is the key format, `ProjectEngagedDocuments.key(_:_:)`'s, which ``key(_:_:)`` writes the same.
    ///
    /// - Parameters:
    ///   - collections: the collections to consider.
    ///   - projectId: The project to attribute to, or `nil` for every collection.
    /// - Returns: `"volumeId/documentId"` keys.
    public nonisolated static func collectedKeys(among allCollections: [CollectionDocuments],
                                                 forProject projectId: UUID?) -> Set<String> {
        let collections = allCollections.filter { isInScope($0.projectIds, forProject: projectId) }
        var keys = Set<String>()
        for collection in collections {
            for entry in collection.entries
            where entry.kind == CollectionEntryKind.document.rawValue
                && !entry.volumeId.isEmpty && !entry.documentId.isEmpty {
                keys.insert(key(entry.volumeId, entry.documentId))
            }
        }
        return keys
    }

    /// All three kinds over sources a caller already holds.
    ///
    /// The single definition of "every kind of engagement": the app's gatherers over its models
    /// come here, so the one-corpus and many-corpus paths cannot come to disagree about what counts.
    ///
    /// - Parameters:
    ///   - sources: the visits, notes, highlights and collections to consider.
    ///   - projectId: The project to attribute to, or `nil` for the whole device.
    /// - Returns: The three key sets.
    public nonisolated static func gather(among sources: Sources,
                                          forProject projectId: UUID?) -> GatheredKeys {
        GatheredKeys(opened: openedKeys(among: sources.visits, forProject: projectId),
                     annotated: annotatedKeys(among: sources.notes, highlights: sources.highlights,
                                              forProject: projectId),
                     collected: collectedKeys(among: sources.collections, forProject: projectId))
    }

    /// Whether a note or a collection filed under `projectIds` counts for `projectId`: every one when
    /// there is no project, otherwise one filed under it.
    ///
    /// - Parameters:
    ///   - projectIds: The record's projects.
    ///   - projectId: The project to attribute to, or `nil` for the whole device.
    /// - Returns: `true` when the record is in scope.
    public nonisolated static func isInScope(_ projectIds: [UUID], forProject projectId: UUID?) -> Bool {
        guard let projectId else { return true }
        return projectIds.contains(projectId)
    }

    /// A stable `"volumeId/documentId"` key, the string `ProjectEngagedDocuments.key(_:_:)` makes and the
    /// FTS5 `documentIds` filter matches on.
    ///
    /// - Parameters:
    ///   - volumeId: The volume.
    ///   - documentId: The document.
    /// - Returns: The key.
    public nonisolated static func key(_ volumeId: String, _ documentId: String) -> String {
        "\(volumeId)/\(documentId)"
    }

    /// The three kinds gathered once, for a caller that must partition **several** corpora.
    ///
    /// The export path needs this: a method appendix reports coverage of every corpus the project
    /// searched inside, and gathering per corpus would re-fetch every note, visit and collection
    /// once per corpus. Gather once, partition many.
    ///
    /// Version history:
    ///   1.0 — W-13 session 2: initial implementation
    public struct GatheredKeys: Sendable, Equatable {
        /// Documents opened in scope.
        public let opened: Set<String>
        /// Documents carrying a note or a highlight.
        public let annotated: Set<String>
        /// Documents in a collection.
        public let collected: Set<String>

        /// Creates the three key sets, as ``DocumentEngagementService/gather(among:forProject:)`` makes them.
        public init(opened: Set<String>, annotated: Set<String>, collected: Set<String>) {
            self.opened = opened
            self.annotated = annotated
            self.collected = collected
        }
    }

    /// Partitions one corpus against an already-gathered key set.
    ///
    /// - Parameters:
    ///   - corpusKeys: The corpus's document keys.
    ///   - keys: The gathered engagement.
    ///   - isOpenedComplete: Whether research logging is on.
    /// - Returns: The partition.
    public nonisolated static func partition(corpusKeys: [String],
                                             keys: GatheredKeys,
                                             isOpenedComplete: Bool) -> EngagementCoverage {
        partition(corpusKeys: corpusKeys,
                  opened: keys.opened, annotated: keys.annotated, collected: keys.collected,
                  isOpenedComplete: isOpenedComplete)
    }

    /// Partitions a corpus by the three gathered sets. Pure, so the suite pins the arithmetic
    /// without a store.
    ///
    /// Each set is **intersected with the corpus**: the gatherers answer for the whole library,
    /// and a coverage sentence that counted a note on a document outside the corpus would report
    /// more documents worked on than the corpus contains.
    ///
    /// - Parameters:
    ///   - corpusKeys: The corpus's document keys. Its `count` is the denominator, matching
    ///     `WorkingCorpusResolution.totalCount`.
    ///   - opened: Keys from ``openedKeys(among:forProject:)``.
    ///   - annotated: Keys from ``annotatedKeys(among:highlights:forProject:)``.
    ///   - collected: Keys from ``collectedKeys(among:forProject:)``.
    ///   - isOpenedComplete: Whether research logging is on.
    /// - Returns: The partition.
    public nonisolated static func partition(corpusKeys: [String],
                                             opened: Set<String>,
                                             annotated: Set<String>,
                                             collected: Set<String>,
                                             isOpenedComplete: Bool) -> EngagementCoverage {
        let corpus = Set(corpusKeys)
        var engagements: [String: DocumentEngagement] = [:]
        for key in corpus.intersection(opened) { engagements[key, default: []].insert(.opened) }
        for key in corpus.intersection(annotated) { engagements[key, default: []].insert(.annotated) }
        for key in corpus.intersection(collected) { engagements[key, default: []].insert(.collected) }
        return EngagementCoverage(
            engagements: engagements,
            totalCount: corpusKeys.count,
            openedCount: engagements.values.count { $0.contains(.opened) },
            annotatedCount: engagements.values.count { $0.contains(.annotated) },
            collectedCount: engagements.values.count { $0.contains(.collected) },
            isOpenedComplete: isOpenedComplete
        )
    }
}
