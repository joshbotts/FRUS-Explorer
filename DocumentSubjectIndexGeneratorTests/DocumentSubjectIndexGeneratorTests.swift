// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import DocumentSubjectIndexGeneratorCore

// MARK: - DocumentSubjectIndexGeneratorTests

/// Pins `DocumentSubjectIndexRunner` — the #308 Phase 3 document-grain subject index.
///
/// Version history:
///   1.0 — Session 2026-08-21: #308 Phase 3
@Suite("Document subject index (#308)")
struct DocumentSubjectIndexGeneratorTests {

    /// Two volumes, four documents, four subjects — small enough to reason about by hand and
    /// shaped like the real drop (comma-joined document ids, one subject spanning volumes).
    private func fixture() -> DocumentSubjectIndexRunner.SourceDrop {
        let json = """
        {
          "generated": "2026-08-21",
          "subjectsIndex": {
            "s-war":   {"name": "War",      "category": "Warfare", "subcategory": "Conflict"},
            "s-peace": {"name": "Peace",    "category": "Warfare", "subcategory": "Settlement"},
            "s-rare":  {"name": "Rare",     "category": "Economy", "subcategory": "Trade"},
            "s-solo":  {"name": "Solo",     "category": "Economy", "subcategory": "Trade"}
          },
          "subjects": {
            "s-war":   {"v1": "d1, d2", "v2": "d1"},
            "s-peace": {"v1": "d1, d2"},
            "s-rare":  {"v1": "d1"},
            "s-solo":  {"v2": "d9"}
          }
        }
        """
        return try! JSONDecoder().decode(DocumentSubjectIndexRunner.SourceDrop.self,
                                         from: Data(json.utf8))
    }

    private func build() throws -> DocumentSubjectIndexArtifact {
        try DocumentSubjectIndexRunner.build(source: fixture(), sourceMD5: "abc",
                                             sourcePath: "fixture", generated: "2026-08-21")
    }

    // MARK: - Shape

    @Test("Every document's subjects are inverted out of the subject-keyed source")
    func invertsToDocuments() throws {
        let a = try build()
        #expect(a.documentCount == 4, "v1/d1, v1/d2, v2/d1, v2/d9 — four distinct documents")
        let refs = a.vocab.map(\.ref)
        func subjects(_ v: String, _ d: String) -> [String] {
            (a.documents[v]?[d] ?? []).map { refs[$0] }
        }
        #expect(subjects("v1", "d1").sorted() == ["s-peace", "s-rare", "s-war"])
        #expect(subjects("v2", "d1") == ["s-war"], """
            v2/d1 and v1/d1 are DIFFERENT documents that share a document id. Keying on the id \
            alone would merge them and give v2/d1 three subjects.
            """)
        #expect(subjects("v2", "d9") == ["s-solo"])
    }

    @Test("Document frequency counts documents, not volumes")
    func documentFrequencyIsPerDocument() throws {
        let a = try build()
        let df = Dictionary(uniqueKeysWithValues: a.vocab.map { ($0.ref, $0.documentFrequency) })
        #expect(df["s-war"] == 3, "v1/d1, v1/d2, v2/d1 — three documents across two volumes")
        #expect(df["s-peace"] == 2)
        #expect(df["s-rare"] == 1)
        #expect(df["s-solo"] == 1)
    }

    // MARK: - The stored co-occurrence

    /// **The guard that makes storing derived data safe.** `coOccurrence` is redundant with
    /// `documents` — it is stored to keep 238,302 documents' worth of pairwise combination off the
    /// launch path — so this recomputes every count from the rows that ship and fails on any
    /// mismatch. Without it the artifact carries two descriptions of one fact and nothing checks
    /// they agree.
    @Test("Stored co-occurrence equals a recomputation from the documents that ship")
    func coOccurrenceMatchesTheDocuments() throws {
        let a = try build()
        var recomputed: [String: Int] = [:]
        for (_, byDocument) in a.documents {
            for (_, list) in byDocument where list.count > 1 {
                for i in 0..<(list.count - 1) {
                    for j in (i + 1)..<list.count {
                        recomputed["\(list[i])-\(list[j])", default: 0] += 1
                    }
                }
            }
        }
        var stored: [String: Int] = [:]
        for i in a.coOccurrence.counts.indices {
            stored["\(a.coOccurrence.lower[i])-\(a.coOccurrence.higher[i])"] = a.coOccurrence.counts[i]
        }
        #expect(stored == recomputed, """
            The stored co-occurrence table disagrees with the documents in the same artifact. \
            Stored \(stored.count) pairs, recomputed \(recomputed.count). A wrong count here does \
            not fail anything at runtime — it produces a plausible wrong PMI and reorders related \
            documents for good.
            """)
    }

    @Test("Pair keys are canonical, so a lookup never has to try both orders")
    func pairKeysAreCanonical() throws {
        let a = try build()
        for i in a.coOccurrence.counts.indices {
            #expect(a.coOccurrence.lower[i] < a.coOccurrence.higher[i],
                    "pair \(i) is not in canonical order")
        }
    }

    // MARK: - Refusals

    @Test("A drop with no mappings is refused rather than written")
    func emptyDropIsRefused() throws {
        let empty = try JSONDecoder().decode(
            DocumentSubjectIndexRunner.SourceDrop.self,
            from: Data(#"{"generated":"x","subjectsIndex":{},"subjects":{}}"#.utf8))
        #expect(throws: DocumentSubjectIndexError.self) {
            _ = try DocumentSubjectIndexRunner.build(source: empty, sourceMD5: "x",
                                                     sourcePath: "fixture", generated: "x")
        }
    }

    /// A subject with mappings but no metadata would ship as an unlabelled row that every display
    /// surface renders as a bare id.
    @Test("A subject missing from subjectsIndex is refused, not defaulted")
    func unlabelledSubjectIsRefused() throws {
        let orphan = try JSONDecoder().decode(
            DocumentSubjectIndexRunner.SourceDrop.self,
            from: Data(#"{"generated":"x","subjectsIndex":{},"subjects":{"ghost":{"v1":"d1"}}}"#.utf8))
        #expect(throws: DocumentSubjectIndexError.self) {
            _ = try DocumentSubjectIndexRunner.build(source: orphan, sourceMD5: "x",
                                                     sourcePath: "fixture", generated: "x")
        }
    }

    // MARK: - Determinism

    @Test("Two builds of the same drop are identical")
    func buildsAreDeterministic() throws {
        #expect(try build() == build(), """
            The artifact is not reproducible. Vocabulary order, per-document sort and pair order \
            are all explicit precisely so a rebuild diffs to nothing.
            """)
    }

    /// No breadth filter and no era gate — both were measured and rejected (see the artifact's
    /// note). `s-war` is on every document in the fixture, the shape a `max-volumes` cut removes.
    @Test("Nothing is filtered out of the artifact")
    func nothingIsFiltered() throws {
        let a = try build()
        #expect(a.vocab.count == 4, "all four subjects ship, including the corpus-wide one")
        let pairs = a.documents.values.reduce(0) { $0 + $1.values.reduce(0) { $0 + $1.count } }
        #expect(pairs == 7, "3 war + 2 peace + 1 rare + 1 solo — every mapping carried through")
    }
}
