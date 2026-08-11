// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import FRUSExplorer

// MARK: - DecimalNeighbourSpaceTests

/// The whitespace mismatch that gave a decimal citation no archival neighbours at all.
///
/// ## The bug
/// `relatedByDecimal(ref:)` — the path the Source Explorer neighbours list takes for a
/// central-files note — matches `document_sources.series_name` against `location + "/%"`.
/// `DecimalFileSegment.location(from:)` **trims** the whitespace a citation may leave before
/// the item slash, while `series_name` stores the file number verbatim. So a note reading
/// `751G.5 MSP /10–553` is stored with that space, the trimmed prefix `751G.5 MSP/%` matches
/// none of its 41 siblings, and the document shows nothing.
///
/// Reported on `frus1952-54v13p1/d416`. 2,224 decimal rows (1.2%) carry the space.
///
/// These test the location derivation and the prefix arithmetic, which is what actually went
/// wrong; the SQL itself is exercised by the owner's index and the visual review.
///
/// Version history:
///   1.0 — Session 2026-08-05: #353 / N-1a follow-up
@Suite("Decimal neighbour spacing")
struct DecimalNeighbourSpaceTests {

    @Test("location() trims the space that series_name keeps")
    func locationTrimsWhatStorageKeeps() {
        // This asymmetry is the bug in one line: the two sides of the comparison disagree
        // about whether the space exists.
        #expect(DecimalFileSegment.location(from: "751G.5 MSP /10–553") == "751G.5 MSP")
        #expect(DecimalFileSegment.location(from: "751G.5 MSP/10–553") == "751G.5 MSP")
        #expect(DecimalFileSegment.location(from: "740.00119 EW /8–2644") == "740.00119 EW")
    }

    @Test("The spaced prefix matches a stored file number that keeps the space")
    func spacedPrefixMatchesStoredForm() {
        // A stand-in for the SQL `LIKE`: the pattern the query now also binds must match the
        // stored form. Only `location + " /%"` does.
        let stored = "751G.5 MSP /10–553"
        let location = DecimalFileSegment.location(from: stored)
        #expect(!stored.hasPrefix(location + "/"), "the shipped prefix cannot match — this is the bug")
        #expect(stored.hasPrefix(location + " /"), "the added prefix must match")
    }

    @Test("The unspaced form still matches, so the fix only adds")
    func unspacedFormUnaffected() {
        let stored = "611.61/1–2355"
        let location = DecimalFileSegment.location(from: stored)
        #expect(stored.hasPrefix(location + "/"))
    }

    @Test("Every affected shape in the corpus keys through the spaced prefix")
    func realCorpusShapes() {
        // The most affected locations, measured on the owner's index: 501. BC (183 rows),
        // 740.00119 EW (87), 357. AC (59), 396.1– ISG (56), 751.5 MSP (47), 751G.5 MSP (42).
        for stored in ["501. BC /1–2045", "740.00119 EW /8–2644", "357. AC /3–1148",
                       "396.1– ISG /5–1155", "751.5 MSP /2–355", "774.5 MSP /11–1253"] {
            let location = DecimalFileSegment.location(from: stored)
            #expect(stored.hasPrefix(location + " /"),
                    "\(stored) does not key through the spaced prefix")
            #expect(!location.hasSuffix(" "), "\(location) should already be trimmed")
        }
    }
}

// MARK: - ClassFamilyDefinitionTests

/// One definition of a subject-numeric family (#841).
///
/// ## The divergence
/// Two definitions were live at once. `CollectionKeying.subjectNumericGroup` — what the
/// Collections ranking and the co-citation network fold by — is **greedy over the hyphenated
/// number**, so `POL 27-14 VIET` belongs to `POL 27-14`. `IndexingPipeline.classLeafPatterns`
/// carried a `key + "-%"` branch, so the SQL family for `POL 27` **swallowed** it.
///
/// A reader tapping the `POL 27` row — 1,090 documents by the fold — opened a document set drawn
/// from a strictly wider population. Measured before the fix: 38 of the 102 class rows the
/// ranking draws, `POL 15` sweeping 73 keys the fold assigns elsewhere, and `POL 27-14` alone
/// worth 220 documents in one band.
///
/// The owner's decision (option (a)) is that the fold is the definition and the query follows it.
///
/// Version history:
///   1.0 — Session 2026-08-11: #841
@Suite("Class family definition (#841)")
struct ClassFamilyDefinitionTests {

    /// A stand-in for SQL `LIKE`, which is what the patterns are bound into.
    private func matches(_ stored: String, patterns: [String]) -> Bool {
        patterns.contains { pattern in
            if pattern.hasSuffix("%") { return stored.hasPrefix(String(pattern.dropLast())) }
            return stored == pattern
        }
    }

    @Test("A subject-numeric family does not swallow its hyphenated sub-numbers")
    func subjectNumericStopsAtTheHyphen() throws {
        let patterns = try #require(
            IndexingPipeline.classLeafPatterns(forCanonicalKey: "POL 27"))
        #expect(matches("POL 27", patterns: patterns), "the key itself")
        #expect(matches("POL 27 VIET S", patterns: patterns), "a space-separated leaf is in")
        #expect(!matches("POL 27-14 VIET", patterns: patterns), """
            `POL 27-14 VIET` folds to `POL 27-14` under CollectionKeying.subjectNumericGroup, so \
            it is its own family. Matching it here is the divergence #841 records: a bar \
            labelled with one population opening documents from another.
            """)
        #expect(!patterns.contains { $0.hasSuffix("-%") })
    }

    @Test("The two definitions agree over every subject-numeric key the corpus carries")
    func foldAndQueryAgreeOnTheShippedVocabulary() throws {
        // The claim is not about one example: for every subject-numeric key, the SQL family of
        // its fold must contain it, and must not contain a key that folds somewhere else.
        let usage = try #require(CollectionUsageIndexStore.shared)
        var checked = 0
        var leaks: Set<String> = []
        var families: [String: [String]] = [:]
        for key in usage.classKeys where CollectionKeying.isSubjectNumericClass(key) {
            let group = CollectionKeying.subjectNumericGroup(key) ?? key
            families[group, default: []].append(key)
        }
        for (group, leaves) in families {
            let patterns = try #require(
                IndexingPipeline.classLeafPatterns(forCanonicalKey: group))
            for leaf in leaves {
                #expect(matches(leaf, patterns: patterns), """
                    \(leaf) folds to \(group) but the query for \(group) would not find it.
                    """)
                checked += 1
            }
            // And nothing from a different family leaks in — except the residue below.
            for (otherGroup, otherLeaves) in families where otherGroup != group {
                for leaf in otherLeaves where matches(leaf, patterns: patterns) {
                    leaks.insert("\(group) → \(leaf)")
                }
            }
        }
        #expect(checked > 1_000, "the sweep covered \(checked) keys, which is too few")

        // THE RESIDUE, bounded rather than excused. The fold's regex needs two-to-six category
        // letters, so the ten single-letter `E …` keys cannot be parsed and each becomes its own
        // group. Two of them are prefixes of others, and a prefix query cannot tell them apart
        // without a rule that would also break `POL 27` → `POL 27 VIET S`. Pinned as an exact
        // set: a NEW leak — from any change to either definition — fails here.
        #expect(leaks == ["E 1 → E 1 JAPAN-US", "E 1 → E 1 US"], """
            The cross-family leaks are \(leaks.sorted()). Before #841 this was 38 of the 102 \
            class rows the ranking draws, with POL 15 sweeping 73 keys.
            """)
    }

    @Test("A decimal file number keeps its hyphen branch")
    func decimalKeepsSubdivisions() throws {
        // Decimal keys are not folded, so no second definition exists to disagree with — and the
        // corpus writes `611.51-A` style subdivisions that a reader asking for `611.51` means.
        let patterns = try #require(
            IndexingPipeline.classLeafPatterns(forCanonicalKey: "611.51"))
        #expect(patterns.contains { $0.hasSuffix("-%") })
        #expect(matches("611.51-A/3-1054", patterns: patterns))
        // Note what is NOT here: there is no `key + "/%"` branch, so the slashed item form is
        // not this query's business — `relatedByDecimal` matches those through
        // `DecimalFileSegment.location`, which the suite above covers.
        #expect(!matches("611.51/3-1054", patterns: patterns))
    }
}
