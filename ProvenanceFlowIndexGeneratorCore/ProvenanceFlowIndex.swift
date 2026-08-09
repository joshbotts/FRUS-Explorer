// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ProvenanceFlowIndex

/// Where FRUS's editors sent the reader when they cross-referenced one document from another,
/// aggregated to the archival unit each document was drawn from (#764).
///
/// ## What this measures, exactly
/// **Editorial cross-referencing, not archival relationship.** Measured on the corpus:
/// **95.3% of document-to-document references are footnotes** — the editor's annotation on
/// document A pointing at document B — and only 3,646 of 77,792 sit in document body text. So a
/// cell does not say "these two archives reference each other"; it says *the editors, annotating
/// material from this collection, sent the reader to material from that one*. That is a real and
/// previously unmapped thing, and it is not the thing the phrase "reference flow" suggests. Every
/// surface rendering this owes that sentence.
///
/// ## Why the collection axis and the class axis are not equals
/// Both are emitted, with their own coverage blocks, because the numbers differ by a factor of
/// four and a consumer must be able to see that without re-measuring:
///
/// - **Collections**: 58.3% of edges have an authority id at both ends; ~19,800 references survive
///   the same-unit exclusion. The top flows are legible (`Nixon NSC Files → Central Files
///   1970-73`, 449 references).
/// - **Classes**: 14.9% of edges have a class key at both ends, and **75.1% of those are
///   within one class** — leaving ~2,900 references corpus-wide, with a largest single cell of 22.
///   The reason is structural, not fixable by a better parser: the `dN` cross-reference idiom does
///   not exist before 1945 (298 of 552 volumes contribute no edges at all, and pre-1940 coverage
///   contributes 33 references in total), while the decades that *do* cross-reference heavily —
///   the 1960s–80s — cite lot files and libraries rather than decimal classes.
///
/// The class axis is therefore shipped as a **measurement, not a feature**: it is here so a
/// consumer can confirm the thinness rather than discover it, and #765 should not build a
/// class-flow surface on it.
///
/// ## Encoding
/// Int-indexed vocabularies and one row per ordered (source, target) pair, including same-unit
/// pairs — the design excludes those from display, and an artifact that had already dropped them
/// could not disclose what the exclusion removed.
///
/// Version history:
///   1.0 — Session 2026-08-08: #764
public struct ProvenanceFlowIndex: Codable, Sendable, Equatable {

    /// One ordered (source unit → target unit) pair and how many references run along it.
    public struct Flow: Codable, Sendable, Equatable {
        /// Index of the source unit in its vocabulary.
        public let source: Int
        /// Index of the target unit.
        public let target: Int
        /// References from a document in `source` to a document in `target`.
        public let count: Int

        /// Whether both ends are the same unit — excluded from display, retained for disclosure.
        public var isSameUnit: Bool { source == target }

        enum CodingKeys: String, CodingKey {
            case source = "s"
            case target = "t"
            case count = "n"
        }

        /// Creates a flow row.
        public init(source: Int, target: Int, count: Int) {
            self.source = source
            self.target = target
            self.count = count
        }
    }

    /// What one axis reached, and what it cost to get there.
    public struct AxisCoverage: Codable, Sendable, Equatable {
        /// Document-to-document references where **both** ends carry a unit on this axis.
        public let joinedReferences: Int
        /// Of those, references whose two ends are the same unit.
        public let sameUnitReferences: Int
        /// Distinct ordered pairs stored (same-unit pairs included).
        public let pairCount: Int
        /// Distinct units appearing at either end.
        public let unitCount: Int

        /// References between *different* units — what a flow diagram can actually draw.
        public var betweenUnitReferences: Int { joinedReferences - sameUnitReferences }

        /// Creates an axis coverage block.
        public init(joinedReferences: Int, sameUnitReferences: Int, pairCount: Int, unitCount: Int) {
            self.joinedReferences = joinedReferences
            self.sameUnitReferences = sameUnitReferences
            self.pairCount = pairCount
            self.unitCount = unitCount
        }
    }

    /// The funnel from every `<ref target>` in the corpus down to the joinable edges — the
    /// numbers behind every disclosure this feature owes.
    public struct Coverage: Codable, Sendable, Equatable {
        /// Volumes scanned.
        public let volumesScanned: Int
        /// Volumes contributing at least one document-to-document edge. The gap is the finding:
        /// most of the series does not cross-reference this way at all.
        public let volumesWithEdges: Int
        /// Every `<ref target>` harvested.
        public let referencesScanned: Int
        /// References that sit inside a `<div type="document">` — the only ones with a source unit.
        public let referencesInsideDocuments: Int
        /// References resolving to a real document div in a manifest volume.
        public let documentEdges: Int
        /// Of those, references whose source and target are in the same volume.
        public let sameVolumeEdges: Int
        /// Of those, references carried by a footnote rather than document body text.
        public let footnoteEdges: Int
        /// The collection axis.
        public let collections: AxisCoverage
        /// The class axis.
        public let classes: AxisCoverage

        /// Creates a coverage block.
        public init(volumesScanned: Int, volumesWithEdges: Int, referencesScanned: Int,
                    referencesInsideDocuments: Int, documentEdges: Int, sameVolumeEdges: Int,
                    footnoteEdges: Int, collections: AxisCoverage, classes: AxisCoverage) {
            self.volumesScanned = volumesScanned
            self.volumesWithEdges = volumesWithEdges
            self.referencesScanned = referencesScanned
            self.referencesInsideDocuments = referencesInsideDocuments
            self.documentEdges = documentEdges
            self.sameVolumeEdges = sameVolumeEdges
            self.footnoteEdges = footnoteEdges
            self.collections = collections
            self.classes = classes
        }
    }

    /// Artifact schema version.
    public let schemaVersion: Int
    /// Generation date stamp (`yyyy-MM-dd`).
    public let generated: String
    /// Authority collection ids appearing at either end of a collection flow, sorted.
    public let collectionIds: [String]
    /// Central-file class keys appearing at either end of a class flow, sorted.
    public let classKeys: [String]
    /// Collection-to-collection flows, sorted by (source, target).
    public let collectionFlows: [Flow]
    /// Class-to-class flows, sorted by (source, target). Thin by measurement — see the type's note.
    public let classFlows: [Flow]
    /// The funnel.
    public let coverage: Coverage

    /// Creates a flow index.
    public init(schemaVersion: Int, generated: String, collectionIds: [String],
                classKeys: [String], collectionFlows: [Flow], classFlows: [Flow],
                coverage: Coverage) {
        self.schemaVersion = schemaVersion
        self.generated = generated
        self.collectionIds = collectionIds
        self.classKeys = classKeys
        self.collectionFlows = collectionFlows
        self.classFlows = classFlows
        self.coverage = coverage
    }
}
