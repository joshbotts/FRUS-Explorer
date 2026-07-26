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

// MARK: - NotesPaneSnapshotTests

/// Tests the macOS Notes pane's row model and filtering (S-5b).
///
/// The filtering used to live in a computed property inside the view, over three live `@Query`
/// results, which is why nothing tested it — and why its "Untagged" option shipped broken for
/// however long it existed. Pulling it into a value type is what makes these assertions possible.
struct NotesPaneSnapshotTests {

    // MARK: - Fixtures

    private func row(id: UUID = UUID(),
                     volume: String = "frus1969-76v01",
                     document: String = "d1",
                     body: String = "A note",
                     projects: [UUID] = [],
                     tags: [UUID] = [],
                     modified: Date? = nil) -> NotesPaneSnapshot.Row {
        NotesPaneSnapshot.Row(id: id,
                              volumeId: volume,
                              documentId: document,
                              bodyText: body,
                              projectNames: [],
                              tagNames: [],
                              lastModified: modified,
                              projectIds: projects,
                              userTagIds: tags)
    }

    // MARK: - Filtering

    /// The defect this type exists to fix. "Untagged" was tagged with the all-zeros UUID and
    /// matched with `projectIds.contains(_:)`; no note's project list contains that, so the
    /// option always produced zero results and the "no notes match" empty state.
    @Test("Unfiled matches notes with no project, not a sentinel id")
    func unfiledMatchesEmptyProjectList() {
        let filed = UUID()
        let snapshot = NotesPaneSnapshot(
            rows: [row(body: "filed", projects: [filed]), row(body: "loose", projects: [])],
            projects: [(id: filed, name: "Berlin")],
            tags: [])

        let unfiled = snapshot.filtered(project: .unfiled)
        #expect(unfiled.count == 1)
        #expect(unfiled.first?.bodyText == "loose")

        // And the sentinel that used to stand in for it matches nothing, as it always did.
        let sentinel = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        #expect(snapshot.filtered(project: .id(sentinel)).isEmpty)
    }

    /// No filter shows everything — a cleared picker must not blank the list.
    @Test("The any/nil filters pass every row through")
    func anyMatchesAll() {
        let snapshot = NotesPaneSnapshot(
            rows: [row(body: "a"), row(body: "b"), row(body: "c")], projects: [], tags: [])
        #expect(snapshot.filtered().count == 3)
        #expect(snapshot.filtered(project: .any, tagId: nil).count == 3)
    }

    /// Project and tag filters are an AND, as the pane has always presented them.
    @Test("Project and tag filters intersect")
    func filtersIntersect() {
        let project = UUID(), tag = UUID()
        let snapshot = NotesPaneSnapshot(
            rows: [
                row(body: "both", projects: [project], tags: [tag]),
                row(body: "project only", projects: [project]),
                row(body: "tag only", tags: [tag]),
            ],
            projects: [(id: project, name: "P")],
            tags: [(id: tag, name: "T")])

        #expect(snapshot.filtered(project: .id(project)).count == 2)
        #expect(snapshot.filtered(tagId: tag).count == 2)
        let both = snapshot.filtered(project: .id(project), tagId: tag)
        #expect(both.count == 1)
        #expect(both.first?.bodyText == "both")
    }

    /// A filter naming something no note carries returns nothing rather than everything.
    @Test("An unmatched filter returns no rows")
    func unmatchedFilterIsEmpty() {
        let snapshot = NotesPaneSnapshot(rows: [row(projects: [UUID()])], projects: [], tags: [])
        #expect(snapshot.filtered(project: .id(UUID())).isEmpty)
        #expect(snapshot.filtered(tagId: UUID()).isEmpty)
    }

    // MARK: - Row copy

    /// The row's primary line is the note's first line — a multi-line note must not smear its
    /// whole body across the label.
    @Test("Title is the first non-empty line")
    func titleIsFirstLine() {
        #expect(row(body: "Opening line\nsecond line\nthird").title == "Opening line")
        #expect(row(body: "  padded  \nrest").title == "padded")
    }

    /// A note that was never written into says so, rather than rendering as a blank row.
    @Test("An empty body reads as a placeholder")
    func emptyBodyPlaceholder() {
        #expect(row(body: "").title == "Empty note")
        #expect(row(body: "\n\n").title == "Empty note")
        #expect(row(body: "   ").title == "Empty note")
    }

    /// The detail line leads with where the note lives, then what it is filed under.
    @Test("Detail lists location then filing")
    func detailComposition() {
        let r = NotesPaneSnapshot.Row(id: UUID(),
                                      volumeId: "frus1977-80v06",
                                      documentId: "d42",
                                      bodyText: "x",
                                      projectNames: ["Panama"],
                                      tagNames: ["Cables", "Treaty"],
                                      lastModified: nil,
                                      projectIds: [],
                                      userTagIds: [])
        #expect(r.detail == "frus1977-80v06 / d42 · Panama · Cables · Treaty")
    }

    /// A note filed under nothing shows only its location — no stray separators.
    @Test("Detail has no trailing separator when nothing is filed")
    func detailWithoutFiling() {
        #expect(row(volume: "v", document: "d").detail == "v / d")
    }

    // MARK: - Counts

    /// Two forms, because the app ships no String Catalog and `inflect:` is inert.
    @Test("Note counts agree in number")
    func noteCountAgreement() {
        #expect(NotesPaneSnapshot.noteCount(1) == "1 note")
        #expect(NotesPaneSnapshot.noteCount(0) == "0 notes")
        #expect(NotesPaneSnapshot.noteCount(2) == "2 notes")
        #expect(NotesPaneSnapshot.noteCount(312) == "312 notes")
    }

    /// "Showing 5 of 312 notes" only when something is actually hidden; otherwise the plain count.
    @Test("Showing-count only qualifies when the list is truncated")
    func showingCount() {
        #expect(NotesPaneSnapshot.showingCount(shown: 5, of: 312) == "Showing 5 of 312 notes")
        #expect(NotesPaneSnapshot.showingCount(shown: 3, of: 3) == "3 notes")
        #expect(NotesPaneSnapshot.showingCount(shown: 1, of: 1) == "1 note")
        // A shown count above the total is nonsense; it must not produce "Showing 9 of 3".
        #expect(NotesPaneSnapshot.showingCount(shown: 9, of: 3) == "3 notes")
    }

    /// `total` counts every row, not the filtered subset — the denominator in the pane's footer.
    @Test("Total is the unfiltered row count")
    func totalIsUnfiltered() {
        let snapshot = NotesPaneSnapshot(
            rows: [row(projects: [UUID()]), row(), row()], projects: [], tags: [])
        #expect(snapshot.total == 3)
        #expect(snapshot.filtered(project: .unfiled).count == 2)
        #expect(snapshot.total == 3)
    }
}
