// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

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
struct DocumentEngagement: OptionSet, Sendable, Hashable {

    /// The bitmask backing the set.
    let rawValue: Int

    /// Creates an engagement set from its bitmask.
    ///
    /// - Parameter rawValue: The bitmask.
    init(rawValue: Int) { self.rawValue = rawValue }

    /// The document was opened while this scope was active (`ReadingHistoryEntry`).
    ///
    /// **Gated on research logging**, so this member is *undercounted* whenever the reader has
    /// "Log Research Sessions" off — see ``EngagementCoverage/isOpenedComplete``.
    static let opened = DocumentEngagement(rawValue: 1 << 0)

    /// The document carries a research note, or a highlight belonging to one.
    static let annotated = DocumentEngagement(rawValue: 1 << 1)

    /// The document is an entry in a collection.
    static let collected = DocumentEngagement(rawValue: 1 << 2)

    /// The single state a list row displays, when several kinds apply at once.
    ///
    /// Ranked by **how deliberate the act was**, strongest first: annotating is work done on the
    /// document, collecting is a judgement that it belongs to an argument, and opening may be no
    /// more than a mis-tap. A row shows the strongest thing that is true of it.
    var state: State {
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
    enum State: String, Sendable, CaseIterable {
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
        var symbolName: String? {
            switch self {
            case .untouched: return nil
            case .opened: return "eye"
            case .collected: return "folder"
            case .annotated: return "note.text"
            }
        }

        /// The badge's accessibility label. Present for every case, including `untouched`, because
        /// a screen reader has no "absence of a badge" to perceive.
        var label: String {
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
struct EngagementCoverage: Sendable, Equatable {

    /// Every corpus key that carries **some** engagement, and which kinds. Untouched keys are
    /// absent rather than mapped to an empty set, so `engagements.count` is the engaged count.
    let engagements: [String: DocumentEngagement]

    /// Documents the corpus names — the denominator of every sentence below.
    let totalCount: Int

    /// Documents opened in this scope.
    let openedCount: Int

    /// Documents carrying a note or a highlight.
    let annotatedCount: Int

    /// Documents in a collection.
    let collectedCount: Int

    /// Whether ``openedCount`` can be trusted as a total.
    ///
    /// `false` when research logging is off. It does **not** mean the count is zero — entries
    /// written before the switch was turned off are still there — it means the app stopped
    /// recording and the number is a floor. Every surface showing `openedCount` must show
    /// ``loggingCaveat`` beside it.
    let isOpenedComplete: Bool

    /// Documents with at least one engagement.
    var engagedCount: Int { engagements.count }

    /// Documents nothing has touched — the number a systematic review is actually hunting.
    var untouchedCount: Int { max(0, totalCount - engagedCount) }

    /// The kinds recorded against one `"volumeId/documentId"` key.
    ///
    /// - Parameter key: The document key.
    /// - Returns: The engagements, empty when the document is untouched.
    func engagement(for key: String) -> DocumentEngagement {
        engagements[key] ?? []
    }

    /// The single state a row for `key` displays.
    ///
    /// - Parameter key: The document key.
    /// - Returns: The strongest engagement that applies, or `.untouched`.
    func state(for key: String) -> DocumentEngagement.State {
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
    var coverageDescription: String {
        String(format: String(localized: "engagement.coverage %@ %@",
                              defaultValue: "%@ of %@ documents worked on"),
               engagedCount.formatted(), totalCount.formatted())
    }

    /// The per-kind breakdown that defines the headline, or `nil` when nothing is engaged.
    ///
    /// All three kinds are always named, zeros included, because in a review a zero is a finding:
    /// "12 opened · 0 annotated · 0 collected" says something a line that omitted the empty kinds
    /// would leave the reader to infer.
    var breakdownDescription: String? {
        guard engagedCount > 0 else { return nil }
        return String(format: String(localized: "engagement.breakdown %@ %@ %@",
                                     defaultValue: "%@ opened · %@ annotated · %@ collected"),
                      openedCount.formatted(), annotatedCount.formatted(),
                      collectedCount.formatted())
    }

    /// The remainder, spelled out — "224 untouched".
    ///
    /// Separate from ``breakdownDescription`` rather than folded into it because the two surfaces
    /// read differently: a list caption is glanced at repeatedly and stays terse, while an exported
    /// methods appendix is read once and carefully, by someone checking a claim, and the number of
    /// documents the researcher did *not* open is the one a reviewer most wants stated rather than
    /// subtracted. The two cannot disagree — this is `totalCount - engagedCount`.
    var untouchedDescription: String {
        String(format: String(localized: "engagement.untouched %@",
                              defaultValue: "%@ untouched"),
               untouchedCount.formatted())
    }

    /// The caveat that must accompany ``openedCount`` when logging is off; `nil` when it is on.
    var loggingCaveat: String? {
        guard !isOpenedComplete else { return nil }
        return String(localized: "engagement.caveat.loggingOff",
                      defaultValue: "Opened is a floor, not a total — research logging is off.")
    }
}

// MARK: - DocumentEngagementService

/// Gathers the three engagement kinds separately and partitions a corpus by them (W-13 session 1).
///
/// ## The gatherer shape, and why it is `ProjectLeadsService`'s
/// Each gatherer is `nonisolated`, takes a `ModelContext`, fetches unscoped and filters in memory
/// (a `[UUID].contains` predicate is unreliable in SwiftData), and returns keys. That is the shape
/// `ProjectLeadsService` settled on after its Phase-2a freeze, and the reason is the same one:
/// these fetches pull every note, visit and collection and fault each collection's
/// `documentEntries` relationship, which must never happen synchronously in a UI path.
///
/// ``coverage(forCorpusKeys:project:container:defaults:)`` is the only entry point a view should
/// use; the individual gatherers are exposed so the suite can drive them one at a time.
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
enum DocumentEngagementService {

    /// The documents opened in this scope (`ReadingHistoryEntry`).
    ///
    /// **Gated on research logging at the writer**, so an empty result may mean "read nothing" or
    /// "recorded nothing"; the caller pairs it with `AppState.isResearchLoggingEnabled`.
    ///
    /// - Parameters:
    ///   - projectId: The project to attribute to, or `nil` for every visit on the device.
    ///   - context: The context to fetch through.
    /// - Returns: `"volumeId/documentId"` keys.
    nonisolated static func openedKeys(forProject projectId: UUID?,
                                       in context: ModelContext) -> Set<String> {
        openedKeys(visits: (try? context.fetch(FetchDescriptor<ReadingHistoryEntry>())) ?? [],
                   forProject: projectId)
    }

    /// The same rule over visits a caller already holds.
    ///
    /// Project Home has every one of these tables live in a `@Query` already, and re-fetching them
    /// through a context to answer a question its own arrays can answer would be both wasteful and
    /// a second place for the rule to live. The context overloads delegate here, so there is one
    /// definition of what counts and the two callers cannot drift.
    ///
    /// - Parameters:
    ///   - visits: the visits to consider.
    ///   - projectId: The project to attribute to, or `nil` for every visit.
    /// - Returns: `"volumeId/documentId"` keys.
    nonisolated static func openedKeys(visits: [ReadingHistoryEntry],
                                       forProject projectId: UUID?) -> Set<String> {
        var keys = Set<String>()
        for visit in visits
        where !visit.volumeId.isEmpty && !visit.documentId.isEmpty
            && (projectId == nil || visit.projectId == projectId) {
            keys.insert(ProjectEngagedDocuments.key(visit.volumeId, visit.documentId))
        }
        return keys
    }

    /// The documents carrying a research note, or a highlight belonging to one.
    ///
    /// - Parameters:
    ///   - projectId: The project to attribute to, or `nil` for every annotation on the device.
    ///   - context: The context to fetch through.
    /// - Returns: `"volumeId/documentId"` keys.
    nonisolated static func annotatedKeys(forProject projectId: UUID?,
                                          in context: ModelContext) -> Set<String> {
        annotatedKeys(notes: (try? context.fetch(FetchDescriptor<ResearchNote>())) ?? [],
                      highlights: (try? context.fetch(FetchDescriptor<DocumentHighlight>())) ?? [],
                      forProject: projectId)
    }

    /// The same rule over notes and highlights a caller already holds. See
    /// ``openedKeys(visits:forProject:)`` for why the pure overload exists.
    ///
    /// - Parameters:
    ///   - notes: the notes to consider.
    ///   - highlights: the highlights to consider.
    ///   - projectId: The project to attribute to, or `nil` for every annotation.
    /// - Returns: `"volumeId/documentId"` keys.
    nonisolated static func annotatedKeys(notes: [ResearchNote],
                                          highlights: [DocumentHighlight],
                                          forProject projectId: UUID?) -> Set<String> {
        let inScope = notes.filter { note in
            guard let projectId else { return true }
            return note.projectIds.contains(projectId)
        }
        var keys = Set<String>()
        for note in inScope where !note.volumeId.isEmpty && !note.documentId.isEmpty {
            keys.insert(ProjectEngagedDocuments.key(note.volumeId, note.documentId))
        }
        // A highlight has no project of its own; it inherits its note's. Unscoped, every highlight
        // counts — including the standalone ones, which are exactly what a scope cannot claim.
        let claimable = Set(inScope.map(\.id))
        for highlight in highlights
        where !highlight.volumeId.isEmpty && !highlight.documentId.isEmpty
            && (projectId == nil || highlight.noteId.map(claimable.contains) == true) {
            keys.insert(ProjectEngagedDocuments.key(highlight.volumeId, highlight.documentId))
        }
        return keys
    }

    /// The documents that are entries in a collection.
    ///
    /// Not shared with `ProjectLeadsService.collectionSeedKeys`, which answers the same question
    /// for a **mandatory** project and unions its answer into a seed. The shared thing between them
    /// is the key format, and that is taken from its one definition,
    /// `ProjectEngagedDocuments.key(_:_:)`.
    ///
    /// - Parameters:
    ///   - projectId: The project to attribute to, or `nil` for every collection on the device.
    ///   - context: The context to fetch through.
    /// - Returns: `"volumeId/documentId"` keys.
    nonisolated static func collectedKeys(forProject projectId: UUID?,
                                          in context: ModelContext) -> Set<String> {
        collectedKeys(collections: (try? context.fetch(FetchDescriptor<Collection>())) ?? [],
                      forProject: projectId)
    }

    /// The same rule over collections a caller already holds. See
    /// ``openedKeys(visits:forProject:)`` for why the pure overload exists.
    ///
    /// - Parameters:
    ///   - collections: the collections to consider.
    ///   - projectId: The project to attribute to, or `nil` for every collection.
    /// - Returns: `"volumeId/documentId"` keys.
    nonisolated static func collectedKeys(collections allCollections: [Collection],
                                          forProject projectId: UUID?) -> Set<String> {
        let collections = allCollections
            .filter { collection in
                guard let projectId else { return true }
                return collection.projectIds.contains(projectId)
            }
        var keys = Set<String>()
        for collection in collections {
            for entry in collection.documentEntries ?? []
            where entry.kind == CollectionEntryKind.document.rawValue
                && !entry.volumeId.isEmpty && !entry.documentId.isEmpty {
                keys.insert(ProjectEngagedDocuments.key(entry.volumeId, entry.documentId))
            }
        }
        return keys
    }

    /// The three kinds gathered once, for a caller that must partition **several** corpora.
    ///
    /// The export path needs this: a method appendix reports coverage of every corpus the project
    /// searched inside, and gathering per corpus would re-fetch every note, visit and collection
    /// once per corpus. Gather once, partition many.
    ///
    /// Version history:
    ///   1.0 — W-13 session 2: initial implementation
    struct GatheredKeys: Sendable, Equatable {
        /// Documents opened in scope.
        let opened: Set<String>
        /// Documents carrying a note or a highlight.
        let annotated: Set<String>
        /// Documents in a collection.
        let collected: Set<String>
    }

    /// Runs all three gatherers against one context.
    ///
    /// The single definition of "every kind of engagement": `coverage(forCorpusKeys:…)` calls it
    /// too, so the one-corpus and many-corpus paths cannot come to disagree about what counts.
    ///
    /// - Parameters:
    ///   - projectId: The project to attribute to, or `nil` for the whole device.
    ///   - context: The context to fetch through.
    /// - Returns: The three key sets.
    nonisolated static func gather(forProject projectId: UUID?,
                                   in context: ModelContext) -> GatheredKeys {
        GatheredKeys(opened: openedKeys(forProject: projectId, in: context),
                     annotated: annotatedKeys(forProject: projectId, in: context),
                     collected: collectedKeys(forProject: projectId, in: context))
    }

    /// All three kinds over model arrays a caller already holds — the Project Home path.
    ///
    /// - Parameters:
    ///   - collections: the collections to consider.
    ///   - notes: the notes to consider.
    ///   - highlights: the highlights to consider.
    ///   - visits: the visits to consider.
    ///   - projectId: The project to attribute to, or `nil` for the whole device.
    /// - Returns: The three key sets.
    nonisolated static func gather(collections: [Collection],
                                   notes: [ResearchNote],
                                   highlights: [DocumentHighlight],
                                   visits: [ReadingHistoryEntry],
                                   forProject projectId: UUID?) -> GatheredKeys {
        GatheredKeys(opened: openedKeys(visits: visits, forProject: projectId),
                     annotated: annotatedKeys(notes: notes, highlights: highlights,
                                              forProject: projectId),
                     collected: collectedKeys(collections: collections, forProject: projectId))
    }

    /// Partitions one corpus against an already-gathered key set.
    ///
    /// - Parameters:
    ///   - corpusKeys: The corpus's document keys.
    ///   - keys: The gathered engagement.
    ///   - isOpenedComplete: Whether research logging is on.
    /// - Returns: The partition.
    nonisolated static func partition(corpusKeys: [String],
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
    ///   - opened: Keys from ``openedKeys(forProject:in:)``.
    ///   - annotated: Keys from ``annotatedKeys(forProject:in:)``.
    ///   - collected: Keys from ``collectedKeys(forProject:in:)``.
    ///   - isOpenedComplete: Whether research logging is on.
    /// - Returns: The partition.
    nonisolated static func partition(corpusKeys: [String],
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

    /// Gathers all three kinds off the main actor and partitions `corpusKeys` by them.
    ///
    /// - Parameters:
    ///   - corpusKeys: The corpus's document keys.
    ///   - projectId: The project to attribute to, or `nil` for the whole device.
    ///   - container: The container a private background context is opened on.
    ///   - isOpenedComplete: Whether research logging is on. **Defaulted to the live gate**, so a
    ///     caller gets the caveat right by saying nothing; the suite passes it explicitly to drive
    ///     both branches without mutating `UserDefaults.standard`. A `UserDefaults` parameter would
    ///     be the more obvious shape and cannot be used: it is not `Sendable`, and this signature
    ///     crosses an actor boundary.
    /// - Returns: The partition.
    nonisolated static func coverage(forCorpusKeys corpusKeys: [String],
                                     project projectId: UUID?,
                                     container: ModelContainer,
                                     isOpenedComplete: Bool = AppState.isResearchLoggingEnabled)
    async -> EngagementCoverage {
        await Task.detached {
            let context = ModelContext(container)
            return partition(corpusKeys: corpusKeys,
                             keys: gather(forProject: projectId, in: context),
                             isOpenedComplete: isOpenedComplete)
        }.value
    }
}
