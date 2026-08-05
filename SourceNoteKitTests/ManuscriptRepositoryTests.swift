// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
@testable import SourceNoteKit

// MARK: - ManuscriptRepositoryTests

/// Pins `CollectionKeying.manuscriptRepositoriesConflict(_:_:)` — the repository test
/// the collection-authority lookup's alias step applies before returning a record
/// (N-4 step 1).
///
/// The predicate has to be narrow in two directions at once, and both boundaries were
/// set by measurement over the 266,513-row corpus rather than by taste. Widening it to
/// every repository refuses 179 correct resolutions; tightening agreement to string
/// equality refuses the same institution under two spellings. These tests hold both
/// walls.
///
/// Version history:
///   1.0 — Session 2026-08-05: N-4 step 1
@Suite("CollectionKeying — manuscript repository conflict")
struct ManuscriptRepositoryTests {

    // MARK: - Conflicts

    @Test("Two presidential libraries conflict")
    func differentLibrariesConflict() {
        #expect(CollectionKeying.manuscriptRepositoriesConflict("Eisenhower Library",
                                                                "Carter Library"))
        #expect(CollectionKeying.manuscriptRepositoriesConflict("Reagan Library",
                                                                "Library of Congress"))
        #expect(CollectionKeying.manuscriptRepositoriesConflict("Library of Congress",
                                                               "Johnson Library"))
    }

    /// The Nixon bucket is the corpus's largest library holding (7,056 documents) and
    /// its canonical form is the bare keyword `"Nixon"` — no `"Librar"`, no marker of
    /// any kind. A guard written on `isLibraryRepositoryName` alone leaves exactly the
    /// highest-stakes repository unprotected.
    @Test("Nixon's bare canonical form still counts as a manuscript repository")
    func nixonCanonicalFormIsGuarded() {
        #expect(!CollectionKeying.isLibraryRepositoryName("Nixon"),
                "the raw marker test does not recognize the bare keyword — isManuscriptRepository exists for this")
        #expect(CollectionKeying.isManuscriptRepository("Nixon"))
        #expect(CollectionKeying.manuscriptRepositoriesConflict("Nixon", "Johnson Library"))
        #expect(CollectionKeying.manuscriptRepositoriesConflict("Kennedy Library", "Nixon"))
    }

    @Test("A university and a presidential library conflict")
    func universityVersusLibraryConflicts() {
        #expect(CollectionKeying.manuscriptRepositoriesConflict("National Defense University",
                                                               "Kennedy Library"))
        #expect(CollectionKeying.manuscriptRepositoriesConflict(
            "U.S. Army Military History Institute", "Johnson Library"))
    }

    // MARK: - Agreement

    /// `canonicalRepository` falls through to the raw string outside its keyword list,
    /// so one institution reaches the lookup under several spellings. Requiring equality
    /// would refuse a correct Princeton resolution the corpus actually makes.
    @Test("One repository under two spellings agrees (containment)")
    func containmentIsAgreement() {
        #expect(!CollectionKeying.manuscriptRepositoriesConflict("Princeton University Library",
                                                                "Princeton University"))
        #expect(!CollectionKeying.manuscriptRepositoriesConflict("Princeton University",
                                                                "Princeton University Library"))
        #expect(!CollectionKeying.manuscriptRepositoriesConflict("Lyndon B. Johnson Library",
                                                                "Johnson Library"))
    }

    /// Custody, creator and accession names for the *same* federal records. The corpus
    /// mixes them freely — a Washington National Records Center citation canonicalizes
    /// through a different keyword than the record it correctly resolves to — so these
    /// must never conflict. Measured cost of getting this wrong: 179 documents.
    @Test("Federal custody and creator names never conflict")
    func federalRepositoriesDoNotConflict() {
        for pair in [("National Archives", "Department of State"),
                     ("National Archives", "Washington National Records Center"),
                     ("National Archives", "Department of Defense"),
                     ("Central Intelligence Agency", "Department of State"),
                     ("Reagan Library", "Department of State"),
                     ("Truman Library", "Department of Defense")] {
            #expect(!CollectionKeying.manuscriptRepositoriesConflict(pair.0, pair.1),
                    "\(pair.0) vs \(pair.1) must not conflict")
        }
    }

    @Test("A missing or unattributed repository never conflicts")
    func absentRepositoryNeverConflicts() {
        #expect(!CollectionKeying.manuscriptRepositoriesConflict(nil, "Johnson Library"))
        #expect(!CollectionKeying.manuscriptRepositoriesConflict("Johnson Library", nil))
        #expect(!CollectionKeying.manuscriptRepositoriesConflict("", "Johnson Library"))
        #expect(!CollectionKeying.manuscriptRepositoriesConflict("Johnson Library", "   "))
    }

    @Test("A repository never conflicts with itself")
    func selfNeverConflicts() {
        for repo in ["Johnson Library", "Nixon", "Library of Congress",
                     "Hoover Institution", "Princeton University"] {
            #expect(!CollectionKeying.manuscriptRepositoriesConflict(repo, repo))
        }
    }
}
