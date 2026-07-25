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

// MARK: - ResearchItemCountsTests

/// Tests the row tallies behind the settings list grammar (S-3a).
///
/// These numbers are what tells a researcher what they are about to destroy — "12 notes · 3
/// collections" is the sentence that makes a Delete button safe to press — so the arithmetic is
/// worth pinning, including the cases real data produces: an item with nothing attached, an item
/// attached only one way, and a record listing the same id twice.
struct ResearchItemCountsTests {

    private let projectA = UUID()
    private let projectB = UUID()
    private let tagA = UUID()
    private let tagB = UUID()

    // MARK: - Projects

    @Test("Notes and collections are counted separately per project")
    func projectTally() {
        let counts = ResearchItemCounts.tally(
            noteProjectIds: [[projectA], [projectA], [projectA, projectB]],
            noteTagIds: [[], [], []],
            collectionProjectIds: [[projectB]],
            assignmentTagIds: []
        )
        #expect(counts.project(projectA).notes == 3)
        #expect(counts.project(projectA).collections == 0)
        #expect(counts.project(projectB).notes == 1)
        #expect(counts.project(projectB).collections == 1)
    }

    /// A note or collection listing the same project twice is malformed data — a CloudKit merge can
    /// produce it — and must not read as two notes.
    @Test("A duplicated id within one record counts once")
    func duplicateIdCountsOnce() {
        let counts = ResearchItemCounts.tally(
            noteProjectIds: [[projectA, projectA]],
            noteTagIds: [[tagA, tagA]],
            collectionProjectIds: [],
            assignmentTagIds: []
        )
        #expect(counts.project(projectA).notes == 1)
        #expect(counts.tag(tagA).notes == 1)
    }

    /// A project nothing has been filed under is the commonest state right after creation.
    @Test("An untouched project tallies zero and says so in words")
    func emptyProject() {
        let counts = ResearchItemCounts.tally(noteProjectIds: [], noteTagIds: [],
                                              collectionProjectIds: [], assignmentTagIds: [])
        let tally = counts.project(projectA)
        #expect(tally.notes == 0)
        #expect(tally.collections == 0)
        #expect(tally.summary == "Nothing filed yet")
    }

    @Test("The project summary names only the kinds that are present")
    func projectSummaryOmitsZeroes() {
        let notesOnly = ResearchItemCounts.tally(noteProjectIds: [[projectA], [projectA]],
                                                 noteTagIds: [[], []],
                                                 collectionProjectIds: [], assignmentTagIds: [])
        #expect(notesOnly.project(projectA).summary == "2 notes")

        let collectionsOnly = ResearchItemCounts.tally(noteProjectIds: [], noteTagIds: [],
                                                       collectionProjectIds: [[projectA]],
                                                       assignmentTagIds: [])
        #expect(collectionsOnly.project(projectA).summary == "1 collection")

        let both = ResearchItemCounts.tally(noteProjectIds: [[projectA]], noteTagIds: [[]],
                                            collectionProjectIds: [[projectA], [projectA]],
                                            assignmentTagIds: [])
        #expect(both.project(projectA).summary == "1 note · 2 collections")
    }

    // MARK: - Tags

    /// A tag reaches documents two different ways — through a note, and directly. Both count, and
    /// they are different things, so the row names both.
    @Test("Note tags and direct document assignments are counted separately")
    func tagTally() {
        let counts = ResearchItemCounts.tally(
            noteProjectIds: [[], []],
            noteTagIds: [[tagA], [tagA, tagB]],
            collectionProjectIds: [],
            assignmentTagIds: [tagA, tagA, tagB]
        )
        #expect(counts.tag(tagA).notes == 2)
        #expect(counts.tag(tagA).documents == 2)
        #expect(counts.tag(tagB).notes == 1)
        #expect(counts.tag(tagB).documents == 1)
    }

    /// The state a reader is most likely deciding about when they open the Tags list.
    @Test("An unused tag says it is applied to nothing")
    func unusedTag() {
        let counts = ResearchItemCounts.tally(noteProjectIds: [], noteTagIds: [],
                                              collectionProjectIds: [], assignmentTagIds: [])
        #expect(counts.tag(tagA).summary == "Not applied to anything")
    }

    @Test("Tag summaries agree in number")
    func tagSummaryAgreement() {
        let one = ResearchItemCounts.tally(noteProjectIds: [[]], noteTagIds: [[tagA]],
                                           collectionProjectIds: [], assignmentTagIds: [tagA])
        #expect(one.tag(tagA).summary == "1 note · 1 document")

        let many = ResearchItemCounts.tally(noteProjectIds: [[], []], noteTagIds: [[tagA], [tagA]],
                                            collectionProjectIds: [],
                                            assignmentTagIds: [tagA, tagA, tagA])
        #expect(many.tag(tagA).summary == "2 notes · 3 documents")
    }

    // MARK: - Shape

    /// Items with nothing attached are absent from the dictionaries rather than stored as zeroes,
    /// so a corpus-scale library does not carry a tally per project it never used.
    @Test("Only items with something attached are stored")
    func sparseStorage() {
        let counts = ResearchItemCounts.tally(noteProjectIds: [[projectA]], noteTagIds: [[]],
                                              collectionProjectIds: [], assignmentTagIds: [])
        #expect(counts.projects.count == 1)
        #expect(counts.projects[projectB] == nil)
        #expect(counts.tags.isEmpty)
    }

    @Test("The empty value tallies nothing")
    func emptyValue() {
        #expect(ResearchItemCounts.empty.projects.isEmpty)
        #expect(ResearchItemCounts.empty.tags.isEmpty)
        #expect(ResearchItemCounts.empty.project(projectA).notes == 0)
        #expect(ResearchItemCounts.empty.tag(tagA).documents == 0)
    }
}
