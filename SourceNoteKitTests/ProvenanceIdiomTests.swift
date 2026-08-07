// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import SourceNoteKit

// MARK: - ProvenanceIdiomTests

/// The WWII-era `obtained from the … Library` idiom (#353).
///
/// ## The gate it defeats, and why the gate is right anyway
/// `tryLibraryLeadNote` admits a library keyword only when the text before it is at most 40
/// characters and comma-free — a length rule, and a good one: it stops a library mentioned deep
/// in prose from claiming a note. The 1940s volumes write
///
/// ```
/// Copy of telegram obtained from the Franklin D. Roosevelt Library, Hyde Park, N.Y.
/// ```
///
/// where the prefix is **47** characters and every one of them says *this is where the document
/// came from*. Measured: **281 documents** recovered, **0 lost**.
///
/// ## Why the idiom is the discriminator
/// `obtained from` is exactly what #713 already had to tell apart from `a copy is in the …
/// Library`, which names a duplicate and is stripped. That exception had **zero traffic** until
/// this change, because these notes are bare and never reached the function it guards — so the
/// two halves of one distinction were written a PR apart and only now meet.
///
/// Version history:
///   1.0 — Session 2026-08-06: #353, the obtained-from provenance idiom
@Suite("Obtained-from provenance idiom")
struct ProvenanceIdiomTests {

    private let parser = SourceNoteParser()

    private func library(_ note: String) -> String? {
        if case .presidentialLibrary(let library, _, _) = parser.parse(note) { return library }
        return nil
    }

    // MARK: - What is admitted

    /// The four spellings the corpus uses, all past the 40-character gate.
    @Test("The provenance idiom reaches the library through a long prefix")
    func idiomIsAdmitted() {
        for note in [
            "Copy of telegram obtained from the Franklin D. Roosevelt Library, Hyde Park, N.Y.",
            "Copy of memorandum obtained from the Franklin D. Roosevelt Library, Hyde Park, N.Y.",
            "Photostatic copy obtained from the Franklin D. Roosevelt Library, Hyde Park, N.Y.",
            "Copy of telegram obtained from Franklin D. Roosevelt Library, Hyde Park, N.Y.",
        ] {
            #expect(library(note) == "Roosevelt Library",
                    Comment(rawValue: "got \(library(note) ?? "nil") for: \(note.prefix(60))"))
        }
    }

    /// The repository name is the name, not the sentence that leads to it — the #713 extractor
    /// doing its job on a prefix that is now allowed to be long.
    @Test("The long prefix is not absorbed into the repository name")
    func prefixIsNotAbsorbed() {
        let name = library("Copy of telegram obtained from the Franklin D. Roosevelt Library, Hyde Park, N.Y.")
        #expect(name == "Roosevelt Library")
        #expect(name?.contains("Copy of telegram") != true)
    }

    // MARK: - What stays refused

    /// The gate still does its job. A library reached by ordinary prose, with no provenance
    /// assertion, is still refused — this is the case the 40-character rule exists for.
    @Test("A library reached by prose is still refused")
    func proseLeadIsStillRefused() {
        let note = "The delegation discussed at length the several proposals and reached agreement at the Truman Library."
        #expect(library(note) == nil, "a library named in running prose claimed the note")
    }

    /// The bound after the idiom is what keeps the exception from becoming a general licence:
    /// only a repository's own name may stand between `obtained from` and the keyword.
    @Test("The idiom does not license an unbounded prefix")
    func idiomWindowIsBounded() {
        let far = "Copy obtained from a source that has asked not to be identified in any published form whatsoever, Truman Library."
        #expect(library(far) == nil,
                "an arbitrarily long prefix rode in behind the idiom")
    }

    /// The unit, so the caller cannot satisfy the suite by accident.
    @Test("assertsProvenance requires the idiom near the keyword")
    func assertsProvenanceUnit() {
        #expect(SourceNoteParser.assertsProvenance("Copy of telegram obtained from the Franklin D. "[...]))
        #expect(!SourceNoteParser.assertsProvenance("The delegation reached agreement at the "[...]))
        // Present, but far from the repository name.
        let far = "Copy obtained from a source that has asked not to be identified in any form, "
        #expect(!SourceNoteParser.assertsProvenance(far[...]))
    }

    /// #713's counterpart. `a copy is in the … Library` names a duplicate and must not become
    /// provenance — the two idioms differ by one verb, and this pins that they still do.
    @Test("A duplicate's location is not a provenance assertion")
    func duplicateIsNotProvenance() {
        #expect(!SourceNoteParser.assertsProvenance("A copy of this telegram is in the "[...]))
        #expect(!SourceNoteParser.assertsProvenance("Another copy is in the "[...]))
    }
}
