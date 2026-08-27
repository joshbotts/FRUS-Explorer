// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ExternalCitationIndex

/// `external-citation-index.json` (#784) — where FRUS's editorial footnotes point **outside** the
/// printed record, aggregated to archival units.
///
/// ## What one number in here means
/// A *reference* is one archival unit named in one body footnote. It is the editor writing
/// *"Telegram 1345 from Moscow, March 5, is in … Lot 66–D95"* — a document the volume did not
/// print, and where to find it. It is **not** a document drawn from that unit (that is
/// `collection-usage-index.json`) and **not** a reference between two printed documents (that is
/// `provenance-flow-index.json`).
///
/// ## Why the per-volume table exists and no era table does
/// The whole case for this harvest is reach: the `#dN` cross-reference idiom yields 7 / 0 / 0
/// references for the 1910s / 1920s / 1930s, which is why #764's flow matrix is structurally empty
/// before 1945. Footnote citations are the only archival signal that reaches those decades, and a
/// surface that cannot show the decades cannot make the claim. So ``targets`` is per-volume and the
/// era rollup happens in the app against `manifest.json` — the same route
/// `CollectionRelations.coverageEras` already takes for the #762 timeline. A second era axis stored
/// here could silently disagree with the first.
///
/// ## Same-unit pairs are stored
/// A footnote in a document drawn from Lot 63 D 351 that points at more material in Lot 63 D 351
/// is a real reference and a real fact about editorial practice, but it is not a *flow between*
/// archives, so no diagram draws it. It is stored anyway (`ExternalCitationPair.sameUnit`) for the
/// reason #764 stores its own: an artifact that had already dropped them could not disclose what
/// the exclusion removed.
///
/// Version history:
///   1.0 — Session 2026-08-10: #784
public struct ExternalCitationIndex: Codable, Sendable, Equatable {

    /// One archival unit's references, broken down by the volume whose footnotes made them.
    ///
    /// `volumes` holds indices into ``ExternalCitationIndex/volumes``, ascending; `counts` holds
    /// the reference count at the same position.
    public struct UnitRow: Codable, Sendable, Equatable {
        /// Index into ``ExternalCitationIndex/targetIds``.
        public let key: Int
        /// Volume indices, ascending.
        public let volumes: [Int]
        /// Reference counts, parallel to ``volumes``.
        public let counts: [Int]

        /// One-letter wire names, for the reason `CollectionUsageIndex.UsageRow` uses them: the
        /// field names cost more than the data in a machine-read index.
        enum CodingKeys: String, CodingKey {
            case key = "k"
            case volumes = "v"
            case counts = "n"
        }

        /// References across every volume.
        public var total: Int { counts.reduce(0, +) }

        /// Creates a row.
        public init(key: Int, volumes: [Int], counts: [Int]) {
            self.key = key
            self.volumes = volumes
            self.counts = counts
        }

        /// Decodes, refusing a row whose parallel arrays have drifted apart — a truncated read
        /// would attribute one collection's counts to another collection's volumes.
        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            key = try c.decode(Int.self, forKey: .key)
            volumes = try c.decode([Int].self, forKey: .volumes)
            counts = try c.decode([Int].self, forKey: .counts)
            guard volumes.count == counts.count else {
                throw DecodingError.dataCorruptedError(
                    forKey: .counts, in: c,
                    debugDescription: "row \(key) has \(volumes.count) volumes and \(counts.count) counts")
            }
        }
    }

    /// One (citing unit → cited unit) edge: the editors, annotating material drawn from `source`,
    /// pointed the reader at unprinted material in `target`.
    public struct Pair: Codable, Sendable, Equatable {
        /// Index into ``ExternalCitationIndex/sourceIds`` — the *citing document's own* unit.
        public let source: Int
        /// Index into ``ExternalCitationIndex/targetIds`` — the unit the footnote points at.
        public let target: Int
        /// References along this edge.
        public let count: Int

        /// Short wire names, as above.
        enum CodingKeys: String, CodingKey {
            case source = "f"
            case target = "t"
            case count = "n"
        }

        /// Creates a pair.
        public init(source: Int, target: Int, count: Int) {
            self.source = source
            self.target = target
            self.count = count
        }
    }

    /// What the scan saw. Every disclosure a surface owes is computed from this rather than
    /// written into a sentence that a regenerated artifact would leave quietly wrong.
    public struct Coverage: Codable, Sendable, Equatable {
        /// Volumes scanned (the manifest's shippable set, intersected with the local corpus).
        public let volumesScanned: Int
        /// Volumes contributing at least one reference.
        public let volumesWithReferences: Int
        /// Documents whose body footnotes were read.
        public let documentsScanned: Int
        /// Body footnotes read.
        public let footnotesScanned: Int
        /// Notes excluded before the grammar ran (head-nested, `type="source"`, source segment).
        /// Overwhelmingly source notes: 268,752 of the corpus's 777,086 `<note>` elements are one.
        public let footnotesExcluded: Int
        /// Of those, the ones excluded for being **head-nested** — the judgement call, and the
        /// only exclusion whose cost is worth watching.
        public let headNestedExcluded: Int
        /// Head-nested notes that carried an anchor: what that judgement actually cost.
        public let headNestedExcludedWithAnchor: Int
        /// References harvested, before the authority join.
        public let referencesFound: Int
        /// References that came from an `Ibid.` rather than from a phrase of their own.
        public let referencesInherited: Int
        /// Clauses that named a unit inside an absence claim and were refused.
        public let absenceClaimsRefused: Int
        /// References naming a lot file.
        public let lotReferences: Int
        /// References naming a library collection.
        public let libraryReferences: Int
        /// References that resolved to an authority collection — the ones this artifact stores.
        /// The gap to ``referencesFound`` is real and is the honest ceiling on the feature.
        public let referencesJoined: Int
        /// Joined references whose *citing* document also resolved to a unit, so a pair exists.
        public let referencesWithBothEnds: Int
        /// Pairs whose two ends are the same unit — stored, never drawn.
        public let sameUnitReferences: Int
        /// Records in the authority the scan was joined against.
        public let authorityCollectionCount: Int

        // MARK: Decimal channel (#834, schema 2)

        /// References naming a **central-file class** — the decimal channel. Admitted by the
        /// shipped rule: the clause carries a class followed by its document serial
        /// (`793.94/9732`) and the key composes under the 1910-1949 schedule.
        public let decimalReferences: Int
        /// Of those, the ones whose class came from a bare `Ibid.` inheriting an earlier
        /// footnote's class (#1014 W-1b) rather than from a class written in the clause. Any
        /// surface quoting the decimal channel's size beside its rule owes this split, the same
        /// way the collection axis owes ``referencesInherited``.
        public let decimalReferencesInherited: Int
        /// Decimal references whose citing document also has a class, so a class pair exists.
        public let decimalReferencesWithBothEnds: Int
        /// Decimal pairs whose two ends are the **same class** — the document restating its own
        /// file rather than pointing outside itself. Stored and counted, never drawn; measured at
        /// 74-76% pre-war, which is the single most important number about this channel.
        public let decimalSameClassReferences: Int
        /// Candidates refused for being **subject-numeric** (`POL 27 VIET S`) rather than decimal.
        /// Out of scope by decision, counted so the scope is a decision rather than a gap.
        public let decimalSubjectNumericRefused: Int
        /// Candidates carrying a serial whose key does **not** compose under the shipped schedule.
        /// Refused — but the shipped country table is incomplete (~290 codes measured against 198
        /// shipped), so some of these are false negatives and the count says how many are at stake.
        public let decimalNotComposingRefused: Int
        /// Candidates whose key composes but does **not** round-trip through the shared class
        /// vocabulary (`decimalClassKey`) — bare dotless numbers, which `decimalClassLocation`
        /// admits via `bareClassCandidate` and `decimalClassKey` rejects. Refused for
        /// JOINABILITY, not authenticity: the class lens merges this weight with weights keyed by
        /// `collection-usage-index.json`, and a key absent from that vocabulary would rank with
        /// zero documents beside it.
        public let decimalNotInSharedVocabularyRefused: Int

        /// Creates a coverage summary.
        public init(volumesScanned: Int, volumesWithReferences: Int, documentsScanned: Int,
                    footnotesScanned: Int, footnotesExcluded: Int,
                    headNestedExcluded: Int, headNestedExcludedWithAnchor: Int,
                    referencesFound: Int,
                    referencesInherited: Int, absenceClaimsRefused: Int, lotReferences: Int,
                    libraryReferences: Int, referencesJoined: Int, referencesWithBothEnds: Int,
                    sameUnitReferences: Int, authorityCollectionCount: Int,
                    decimalReferences: Int, decimalReferencesInherited: Int,
                    decimalReferencesWithBothEnds: Int,
                    decimalSameClassReferences: Int, decimalSubjectNumericRefused: Int,
                    decimalNotComposingRefused: Int,
                    decimalNotInSharedVocabularyRefused: Int) {
            self.volumesScanned = volumesScanned
            self.volumesWithReferences = volumesWithReferences
            self.documentsScanned = documentsScanned
            self.footnotesScanned = footnotesScanned
            self.footnotesExcluded = footnotesExcluded
            self.headNestedExcluded = headNestedExcluded
            self.headNestedExcludedWithAnchor = headNestedExcludedWithAnchor
            self.referencesFound = referencesFound
            self.referencesInherited = referencesInherited
            self.absenceClaimsRefused = absenceClaimsRefused
            self.lotReferences = lotReferences
            self.libraryReferences = libraryReferences
            self.referencesJoined = referencesJoined
            self.referencesWithBothEnds = referencesWithBothEnds
            self.sameUnitReferences = sameUnitReferences
            self.authorityCollectionCount = authorityCollectionCount
            self.decimalReferences = decimalReferences
            self.decimalReferencesInherited = decimalReferencesInherited
            self.decimalReferencesWithBothEnds = decimalReferencesWithBothEnds
            self.decimalSameClassReferences = decimalSameClassReferences
            self.decimalSubjectNumericRefused = decimalSubjectNumericRefused
            self.decimalNotComposingRefused = decimalNotComposingRefused
            self.decimalNotInSharedVocabularyRefused = decimalNotInSharedVocabularyRefused
        }
    }

    /// Artifact schema version.
    public let schemaVersion: Int
    /// Generation date stamp (`yyyy-MM-dd`).
    public let generated: String
    /// Every volume contributing at least one reference, sorted — the index space for ``targets``.
    public let volumes: [String]
    /// Authority collection ids reached as a citation *target*, sorted.
    public let targetIds: [String]
    /// Authority collection ids reached as a citing document's *own* unit, sorted.
    public let sourceIds: [String]
    /// Per-target references by volume, sorted by `key`.
    public let targets: [UnitRow]
    /// (source → target) edges, sorted by `source` then `target`. Includes same-unit edges.
    public let pairs: [Pair]

    // MARK: The class axis (#834, schema 2)

    /// Central-file class keys reached as a citation **target**, sorted.
    ///
    /// ## Why a second axis rather than a third anchor
    /// `targetIds` are collection-authority ids, and the authority has no class records — classes
    /// exist there only as id-less display children. `AuthorityLookup.record(forParsed:)` keys on
    /// a lot number or a leading segment, so a bare `(681.8229/8-2950, not printed)` resolves to
    /// nothing however good its grammar. Even the *anchored* decimal notes that do resolve land on
    /// one umbrella record (`department of state|central file`) that the analytics UI hides by
    /// default. A class-keyed axis is the only shape that yields a rankable vocabulary — the same
    /// two-axis shape `provenance-flow-index.json` and `collection-usage-index.json` already use.
    ///
    /// The vocabulary is `collection-usage-index.json`'s, **not namespaced**, so a key here is the
    /// key `ArchivalCollectionsData` already ranks and `decimal-class-labels.json` already glosses.
    public let classTargetKeys: [String]
    /// Class keys reached as a citing document's **own** class, sorted.
    ///
    /// **This vocabulary holds BOTH filing systems, and the target one does not.** Subject-numeric
    /// designators (`POL 1 CHICOM USSR`, `DEF 18`) are out of scope as harvest TARGETS by owner
    /// decision — the footnote grammar refuses them — but a citing document filed under one is
    /// simply a fact about that document, and dropping it would discard real pairs whose target is
    /// a decimal file. So a pair may read `POL 1 CHICOM USSR -> 763.72`, meaning a
    /// subject-numeric-filed document cited a decimal one. Branch on
    /// `CollectionKeying.isSubjectNumericClass` before grouping or labelling.
    public let classSourceKeys: [String]
    /// Per-target-class references by volume, sorted by `key`.
    public let classTargets: [UnitRow]
    /// (source class → target class) edges, sorted. **Same-class edges are included**, and are
    /// exactly those whose `source` and `target` name the same key — stored rather than dropped
    /// for the reason the collection axis stores its own: an artifact that had already excluded
    /// them could not disclose what the exclusion removed, and here they are 74-76% of the
    /// pre-war channel.
    public let classPairs: [Pair]

    /// What the scan saw.
    public let coverage: Coverage

    /// Creates an index.
    public init(schemaVersion: Int, generated: String, volumes: [String], targetIds: [String],
                sourceIds: [String], targets: [UnitRow], pairs: [Pair],
                classTargetKeys: [String], classSourceKeys: [String],
                classTargets: [UnitRow], classPairs: [Pair], coverage: Coverage) {
        self.schemaVersion = schemaVersion
        self.generated = generated
        self.volumes = volumes
        self.targetIds = targetIds
        self.sourceIds = sourceIds
        self.targets = targets
        self.pairs = pairs
        self.classTargetKeys = classTargetKeys
        self.classSourceKeys = classSourceKeys
        self.classTargets = classTargets
        self.classPairs = classPairs
        self.coverage = coverage
    }
}
