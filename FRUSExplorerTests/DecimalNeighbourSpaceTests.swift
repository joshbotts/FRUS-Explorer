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
/// ## A head with no number (index version 69)
/// A file under the primary subject alone (`POL US-USSR`) folds to its head, `POL`, and a head is
/// a prefix of every numbered file of the subject too. So that family's query is its patterns
/// less `IndexingPipeline.classFamilyExclusion`, and the stand-in below reads both. The real SQL
/// is driven by `VolumeSourceMatcherTests.aPrimarySubjectFamilyLeavesOutTheNumberedFiles`.
///
/// ## A numbered file with a country (A16, #1691's first line)
/// A numbered key with an area is one file, itself and the same file at a post, so `POL 27 VIET`
/// reaches neither `POL 27 VIET S` nor `POL 27 VIET N`. `aNumberedFileWithACountryIsOneFile`
/// pins the patterns and sweeps the shipped vocabulary: every key such a key's query reaches has
/// its category, number and area, and the reach beyond itself is the four post pairs.
///
/// Version history:
///   1.0 — Session 2026-08-11: #841
///   1.1 — index version 69: the stand-in reads the exclusion, and the sweep counts the heads
///   1.2 — 2026-10-20 (A16): a numbered file with a country reaches no other country's file
@Suite("Class family definition (#841)")
struct ClassFamilyDefinitionTests {

    /// A stand-in for SQL `LIKE`, which is what the patterns are bound into.
    private func matches(_ stored: String, patterns: [String]) -> Bool {
        patterns.contains { pattern in
            if pattern.hasSuffix("%") { return stored.hasPrefix(String(pattern.dropLast())) }
            return stored == pattern
        }
    }

    /// A stand-in for the family's whole `WHERE`: the patterns, less the one `GLOB` the
    /// exclusion writes, which is a literal prefix and then `[0-9(]*`.
    private func inFamily(_ stored: String, of key: String) throws -> Bool {
        let patterns = try #require(IndexingPipeline.classLeafPatterns(forCanonicalKey: key))
        guard matches(stored, patterns: patterns) else { return false }
        guard let glob = IndexingPipeline.classFamilyExclusion(forCanonicalKey: key) else { return true }
        let classAndStar = " [0-9(]*"
        try #require(glob.hasSuffix(classAndStar), "the stand-in reads one shape of GLOB, and this is \(glob)")
        let prefix = String(glob.dropLast(classAndStar.count)) + " "
        guard stored.hasPrefix(prefix), let next = stored.dropFirst(prefix.count).first else { return true }
        return !("0"..."9").contains(next) && next != "("
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
        var heads = 0
        var headLeaves = 0
        var leaks: Set<String> = []
        var families: [String: [String]] = [:]
        for key in usage.classKeys where CollectionKeying.isSubjectNumericClass(key) {
            let group = CollectionKeying.subjectNumericGroup(key) ?? key
            families[group, default: []].append(key)
        }
        for (group, leaves) in families {
            let isHead = IndexingPipeline.classFamilyExclusion(forCanonicalKey: group) != nil
            if isHead { heads += 1 }
            for leaf in leaves {
                #expect(try inFamily(leaf, of: group), """
                    \(leaf) folds to \(group) but the query for \(group) would not find it.
                    """)
                checked += 1
                if isHead { headLeaves += 1 }
            }
            // And nothing from a different family leaks in — except the residue below.
            for (otherGroup, otherLeaves) in families where otherGroup != group {
                for leaf in otherLeaves where try inFamily(leaf, of: group) {
                    leaks.insert("\(group) → \(leaf)")
                }
            }
        }
        #expect(checked > 1_000, "the sweep covered \(checked) keys, which is too few")
        // The heads with no number are in the sweep, so the exclusion is: 30 heads over 300-odd
        // keys on the index regenerated for version 69. Without the exclusion `POL` alone leaks
        // every numbered POL key.
        #expect(heads >= 20, "the sweep met \(heads) heads with no number")
        #expect(headLeaves >= 250, "and \(headLeaves) keys under them")

        // THE RESIDUE IS GONE, and the way it went is the point. It was never a limit of prefix
        // matching: the fold's regex required two-to-six category letters, so the corpus's
        // single-letter `E` keys could not be parsed and `?? key` made each its own group —
        // whereupon `E 1`'s space branch reached `E 1 JAPAN-US` and `E 1 US`, which under any
        // correct fold are its own members. Widening the floor to one letter puts all three in
        // one family and the leak disappears with them. Pinned as an exact set, empty: a NEW
        // leak — from any change to either definition — fails here.
        #expect(leaks.isEmpty, """
            The cross-family leaks are \(leaks.sorted()). Before #841 this was 38 of the 102 \
            class rows the ranking draws, with POL 15 sweeping 73 keys; the last two closed when \
            the fold learned to parse a one-letter category.
            """)
    }

    @Test("A head with no number takes the files under it and leaves the numbered ones (index version 69)")
    func aHeadLeavesOutItsNumberedFiles() throws {
        #expect(try inFamily("POL US-USSR", of: "POL"))
        #expect(try inFamily("POL GER W-US", of: "POL"))
        #expect(try !inFamily("POL 27 VIET S", of: "POL"), "`POL %` reaches it, and the exclusion takes it out")
        #expect(try !inFamily("POL1 US", of: "POL"))
        // An agency or a commodity is a head of its own.
        #expect(try inFamily("AID (US) INDIA", of: "AID (US)"))
        #expect(try inFamily("AID (US)", of: "AID (US)"), "six notes cite the head alone")
        #expect(try !inFamily("AID (US) 15 INDIA", of: "AID (US)"))
        #expect(try !inFamily("AID (US) INDIA", of: "AID"))
        #expect(try !inFamily("INCO-WOOL US", of: "INCO"))
        #expect(IndexingPipeline.classFamilyExclusion(forCanonicalKey: "POL") == "POL [0-9(]*")
        #expect(IndexingPipeline.classFamilyExclusion(forCanonicalKey: "AID (US)") == "AID (US) [0-9(]*")
        // A numbered family, a decimal number and a file with an area have nothing to leave out.
        for key in ["POL 27", "611.61", "POL US-USSR", "POL 27 VIET S"] {
            #expect(IndexingPipeline.classFamilyExclusion(forCanonicalKey: key) == nil, "\(key)")
        }
    }

    @Test("A file with no number and an area is matched as itself (index version 69)")
    func aPrimarySubjectFileIsMatchedExactly() throws {
        // Its space branch could only reach another area's file: `POL GER` is Germany's, and
        // `POL GER W-US` is West Germany's with the United States (57 documents).
        #expect(IndexingPipeline.classLeafPatterns(forCanonicalKey: "POL GER") == ["POL GER"])
        #expect(try !inFamily("POL GER W-US", of: "POL GER"))
        // A numbered key keeps its space branch, which is how `POL 27` finds its countries.
        #expect(IndexingPipeline.classLeafPatterns(forCanonicalKey: "POL 27")
                    == ["POL 27", "POL 27 %", "POL 27.%"])
        // The clause binds its patterns and then the exclusion, in that order.
        let head = try #require(IndexingPipeline.classFamilyClause(forCanonicalKey: "POL"))
        #expect(head.params == ["POL", "POL %", "POL [0-9(]*"])
        #expect(head.clause.contains("NOT GLOB ?"))
        let numbered = try #require(IndexingPipeline.classFamilyClause(forCanonicalKey: "POL 27"))
        #expect(numbered.params == ["POL 27", "POL 27 %", "POL 27.%"])
        #expect(!numbered.clause.contains("GLOB"))
    }

    @Test("A numbered file with a country reaches no other country's file, and its post is the same file (A16)")
    func aNumberedFileWithACountryIsOneFile() throws {
        // The patterns: the file and the file at a post, from either spelling; a family keeps
        // its space branch, which is how `POL 27` finds its countries.
        #expect(IndexingPipeline.classLeafPatterns(forCanonicalKey: "POL 27 VIET")
                    == ["POL 27 VIET", "POL 27 VIET (%"])
        #expect(IndexingPipeline.classLeafPatterns(forCanonicalKey: "NATO 3 LUX (LU)")
                    == ["NATO 3 LUX", "NATO 3 LUX (%"])
        #expect(IndexingPipeline.classLeafPatterns(forCanonicalKey: "AID (US) 15 INDIA")
                    == ["AID (US) 15 INDIA", "AID (US) 15 INDIA (%"], "a head's parenthesis is not a post")
        #expect(IndexingPipeline.classLeafPatterns(forCanonicalKey: "POL 27")
                    == ["POL 27", "POL 27 %", "POL 27.%"])
        #expect(IndexingPipeline.classFamilyExclusion(forCanonicalKey: "POL 27 VIET") == nil)
        #expect(try !inFamily("POL 27 VIET S", of: "POL 27 VIET"), "South Vietnam's file is another country's")
        #expect(try !inFamily("POL 27 VIET N", of: "POL 27 VIET"))
        #expect(try inFamily("POL 27 VIET", of: "POL 27"), "and the family still holds it")
        #expect(try inFamily("POL 27 VIET S", of: "POL 27"))
        #expect(try inFamily("NATO 3 LUX (LU)", of: "NATO 3 LUX"), "the file at a post is the file")
        #expect(try inFamily("NATO 3 LUX", of: "NATO 3 LUX (LU)"), "from the post's side too")
        #expect(try !inFamily("POL 7 US CONNALLY", of: "POL 7 US"), "a folder written with a space is a key of its own (the owner's decision of 2026-10-20)")
        #expect(try !inFamily("POL 2 DOM REP", of: "POL 2 DOM"))

        // The sweep: over every Subject-Numeric key of the shipped vocabulary, a numbered key
        // with an area reaches only keys with its own category, number and area. Before A16, 17
        // keys reached another country's file at a space, `POL 27 VIET` taking in South
        // Vietnam's 477 documents. The patterns are computed once per key, since the sweep is
        // every key against every other.
        let usage = try #require(CollectionUsageIndexStore.shared)
        let keys = usage.classKeys.filter { CollectionKeying.isSubjectNumericClass($0) }
        var patterns: [String: [String]] = [:]
        for key in keys { patterns[key] = IndexingPipeline.classLeafPatterns(forCanonicalKey: key) }
        var checked = 0
        var leaks: Set<String> = []
        var posts: Set<String> = []
        for key in keys {
            guard let parts = CollectionKeying.subjectNumericParts(of: key), parts.number != nil,
                  !parts.area.isEmpty, let own = patterns[key] else { continue }
            checked += 1
            #expect(IndexingPipeline.classFamilyExclusion(forCanonicalKey: key) == nil,
                    "\(key) has nothing to leave out")
            for other in keys where other != key && matches(other, patterns: own) {
                if let reached = CollectionKeying.subjectNumericParts(of: other),
                   reached.group == parts.group, reached.area == parts.area {
                    posts.insert("\(key) → \(other)")
                } else {
                    leaks.insert("\(key) → \(other)")
                }
            }
        }
        // 1,486 on the usage index at version 69.
        #expect(checked > 1_400, "the sweep covered \(checked) numbered keys with an area, which is too few")
        #expect(leaks.isEmpty, "a numbered file with a country reaches another file: \(leaks.sorted())")
        #expect(posts == ["NATO 3 LUX → NATO 3 LUX (LU)", "NATO 3 LUX (LU) → NATO 3 LUX",
                          "PET 6 IRAQ → PET 6 IRAQ (SYR)", "PET 6 IRAQ (SYR) → PET 6 IRAQ"],
                "the reach beyond a key itself is the post pairs of the usage index at version 69; got \(posts.sorted())")
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
