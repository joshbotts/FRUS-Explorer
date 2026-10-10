// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - ReviewedMarksTests

/// The checklist's marks and its one level of Undo (#1576 lane 1). One fixture per branch of
/// ``ReviewedMarks``.
@Suite("Checklist reviewed marks")
struct ReviewedMarksTests {

    @Test("A hand mark is a mark, and is nothing to undo")
    func handMark() {
        var marks = ReviewedMarks()
        marks.mark("v|d1")
        #expect(marks.keys == ["v|d1"])
        #expect(!marks.canUndoBulk)
        #expect(marks.undoLastBulk().isEmpty)
        #expect(marks.keys == ["v|d1"], "an undo with no bulk mark behind it takes nothing back")
    }

    @Test("A bulk mark returns the keys it newly hid, and they are the batch")
    func bulkMarkReturnsTheNewKeys() {
        var marks = ReviewedMarks()
        let fresh = marks.markBulk(["v|d1", "v|d2", "v|d3"])
        #expect(fresh == ["v|d1", "v|d2", "v|d3"])
        #expect(marks.keys == ["v|d1", "v|d2", "v|d3"])
        #expect(marks.lastBulkBatch == fresh)
        #expect(marks.canUndoBulk)
    }

    /// `d2` was marked by hand first. The page mark must not claim it: undo would then take back a
    /// mark the reader made on purpose.
    @Test("A bulk mark leaves a key already marked out of its batch")
    func bulkMarkSkipsWhatIsAlreadyMarked() {
        var marks = ReviewedMarks()
        marks.mark("v|d2")
        let fresh = marks.markBulk(["v|d1", "v|d2", "v|d3"])
        #expect(fresh == ["v|d1", "v|d3"], "only the keys newly hidden are returned")

        let restored = marks.undoLastBulk()
        #expect(restored == ["v|d1", "v|d3"])
        #expect(marks.keys == ["v|d2"], "the hand mark stands")
        #expect(!marks.canUndoBulk)
    }

    @Test("A bulk mark that hides nothing new changes nothing, and the batch before it stays undoable")
    func emptyBulkMarkKeepsTheEarlierBatch() {
        var marks = ReviewedMarks()
        marks.markBulk(["v|d1", "v|d2"])
        let before = marks

        #expect(marks.markBulk(["v|d2", "v|d1"]).isEmpty)
        #expect(marks.markBulk([String]()).isEmpty)
        #expect(marks == before)
        #expect(marks.undoLastBulk() == ["v|d1", "v|d2"])
    }

    /// One level: the second page mark is what Undo takes back. The first stays hidden.
    @Test("Undo takes back the last bulk mark only")
    func undoIsOneLevel() {
        var marks = ReviewedMarks()
        marks.markBulk(["v|d1", "v|d2"])
        marks.markBulk(["v|d3", "v|d4"])

        #expect(marks.undoLastBulk() == ["v|d3", "v|d4"])
        #expect(marks.keys == ["v|d1", "v|d2"])
        #expect(!marks.canUndoBulk, "the earlier batch is not offered once the later one is undone")
        #expect(marks.undoLastBulk().isEmpty)
        #expect(marks.keys == ["v|d1", "v|d2"])
    }

    @Test("A hand mark made after a bulk mark survives its undo")
    func handMarkAfterBulkSurvivesUndo() {
        var marks = ReviewedMarks()
        marks.markBulk(["v|d1", "v|d2"])
        marks.mark("v|d9")
        #expect(marks.undoLastBulk() == ["v|d1", "v|d2"])
        #expect(marks.keys == ["v|d9"])
    }

    @Test("A key of the batch that is then marked by hand leaves the batch")
    func handMarkTakesAKeyOutOfTheBatch() {
        var marks = ReviewedMarks()
        marks.markBulk(["v|d1", "v|d2"])
        marks.mark("v|d1")
        #expect(marks.lastBulkBatch == ["v|d2"])
        #expect(marks.undoLastBulk() == ["v|d2"])
        #expect(marks.keys == ["v|d1"])
    }

    @Test("Reset clears the marks and the batch")
    func resetClearsBoth() {
        var marks = ReviewedMarks()
        marks.mark("v|d9")
        marks.markBulk(["v|d1", "v|d2"])
        marks.reset()
        #expect(marks.keys.isEmpty)
        #expect(!marks.canUndoBulk)
        #expect(marks == ReviewedMarks())
    }

    // MARK: What Undo would bring back

    /// The batch is three keys. What Undo restores to a list is the batch's keys that the list
    /// holds, so each fixture below changes one thing about the list and nothing about the batch.
    @Test("With the whole batch loaded and hidden by nothing else, Undo brings back all of it")
    func undoableCountIsTheBatchWhenAllOfItIsLoaded() {
        var marks = ReviewedMarks()
        marks.markBulk(["v|d1", "v|d2", "v|d3"])
        #expect(marks.undoableCount(among: ["v|d1", "v|d2", "v|d3", "v|d4"], otherwiseHidden: []) == 3)
    }

    /// A re-run of the same search under a narrower filter loaded one of the three.
    @Test("A result of the batch that the search no longer loads is not counted")
    func undoableCountLeavesOutWhatIsNotLoaded() {
        var marks = ReviewedMarks()
        marks.markBulk(["v|d1", "v|d2", "v|d3"])
        #expect(marks.undoableCount(among: ["v|d2", "v|d7", "v|d8"], otherwiseHidden: []) == 1)
        #expect(marks.undoableCount(among: ["v|d7", "v|d8"], otherwiseHidden: []) == 0,
                "none of the batch is in this list, so Undo would bring nothing back to it")
    }

    /// `d2` was opened since the mode came on, which hides it whatever its mark.
    @Test("A result of the batch that is hidden for another reason is not counted")
    func undoableCountLeavesOutWhatStaysHidden() {
        var marks = ReviewedMarks()
        marks.markBulk(["v|d1", "v|d2", "v|d3"])
        #expect(marks.undoableCount(among: ["v|d1", "v|d2", "v|d3"], otherwiseHidden: ["v|d2"]) == 2)
    }

    /// A hand mark is hidden and is in no batch: only the batch is counted, not every mark.
    @Test("A hand mark is not counted, and with no bulk mark there is nothing to count")
    func undoableCountCountsOnlyTheBatch() {
        var marks = ReviewedMarks()
        marks.mark("v|d9")
        #expect(marks.undoableCount(among: ["v|d9", "v|d1"], otherwiseHidden: []) == 0)
        marks.markBulk(["v|d1"])
        #expect(marks.undoableCount(among: ["v|d9", "v|d1"], otherwiseHidden: []) == 1)
        marks.undoLastBulk()
        #expect(marks.undoableCount(among: ["v|d9", "v|d1"], otherwiseHidden: []) == 0)
    }
}

// MARK: - ChecklistAnchorTests

/// What counts as the same search for a checklist's marks (#1576 lane 1, the owner's decision 4).
@Suite("Checklist anchor")
struct ChecklistAnchorTests {

    private static let kissinger = PersonRollupAnchor(volumeId: "frus1969-76v01", ref: "p_KHA1")
    private static let rogers = PersonRollupAnchor(volumeId: "frus1969-76v01", ref: "p_RWP1")

    private func anchor(_ query: String, _ parameters: SearchParameters = SearchParameters()) -> ChecklistAnchor {
        ChecklistAnchor(query: query, parameters: parameters)
    }

    // MARK: With words

    @Test("The same words are the same search, whatever the filters")
    func sameWordsAreTheSameSearch() {
        let plain = anchor("détente")
        let filtered = anchor("détente", SearchParameters(
            dateRange: DateRange(earliest: "1969-01-01", latest: "1972-12-31"),
            volumeIds: ["frus1969-76v01"], personRollupId: 12, subjectBucket: 3))
        #expect(plain.browse == nil)
        #expect(filtered.browse == nil, "a search with words is not a browse, whatever filters it carries")
        #expect(plain.isSameSearch(as: filtered))
        #expect(filtered.isSameSearch(as: plain))
    }

    @Test("Other words are another search")
    func otherWordsAreAnotherSearch() {
        #expect(!anchor("alpha").isSameSearch(as: anchor("beta")))
        #expect(!anchor("alpha").isSameSearch(as: anchor("Alpha")), "case is not folded, as in the trail")
    }

    /// #1298: the writer calls these one query, and the checklist follows the writer.
    @Test("The same query in other quotation marks keeps its marks")
    func quotationMarksAreFolded() {
        #expect(anchor("“cold war”").isSameSearch(as: anchor("\"cold war\"")))
        #expect(anchor("«cold war»").isSameSearch(as: anchor("\"cold war\"")))
    }

    @Test("The typed text is trimmed, and is the authority on what was typed")
    func queryIsTrimmedAndOverridesTheParameters() {
        let stale = SearchParameters(keywords: "something else")
        #expect(anchor("  alpha \n", stale) == anchor("alpha"))
        #expect(anchor("", SearchParameters(keywords: "left over", personRollupId: 12)).browse != nil,
                "an empty submitted query is a browse though the stored parameters still hold old words")
    }

    @Test("A restored phrase, prefix or excluded term is part of the words")
    func structuredTermsAreWords() {
        let phrase = anchor("", SearchParameters(phrase: "cold war"))
        #expect(phrase.browse == nil, "a phrase is words: the search is not a browse")
        #expect(!phrase.isSameSearch(as: anchor("", SearchParameters(phrase: "open door"))))
        #expect(!anchor("alpha").isSameSearch(as: anchor("alpha", SearchParameters(excludedTerms: ["beta"]))))
        #expect(!anchor("alpha").isSameSearch(as: anchor("alpha", SearchParameters(prefixWildcard: "negot"))))
        #expect(phrase.isSameSearch(as: anchor("", SearchParameters(phrase: "cold war", subjectBucket: 2))))
    }

    // MARK: With no words

    @Test("A browse of one person and a browse of another are different searches")
    func anotherPersonIsAnotherSearch() {
        let first = anchor("", SearchParameters(personRollupId: 12, personAnchor: Self.kissinger))
        let second = anchor("", SearchParameters(personRollupId: 40, personAnchor: Self.rogers))
        #expect(first.browse != nil)
        #expect(!first.isSameSearch(as: second))
        #expect(!second.isSameSearch(as: first))
    }

    /// The slot is positional and a rollup rebuild renumbers it. The anchor is what names the person.
    @Test("The same person under a renumbered slot is the same search; another person in the old slot is not")
    func personIsNamedByTheAnchorNotTheSlot() {
        let before = anchor("", SearchParameters(personRollupId: 12, personAnchor: Self.kissinger))
        let renumbered = anchor("", SearchParameters(personRollupId: 97, personAnchor: Self.kissinger))
        let usurper = anchor("", SearchParameters(personRollupId: 12, personAnchor: Self.rogers))
        #expect(before.isSameSearch(as: renumbered))
        #expect(!before.isSameSearch(as: usurper))
    }

    /// A filter set by its slot gains its anchor a moment later, with no search run. The two are
    /// compared on what both carry, which is the slot.
    @Test("A person whose anchor is captured after the fact is still the same person")
    func anchorCapturedLaterIsTheSamePerson() {
        let slotOnly = anchor("", SearchParameters(personRollupId: 12))
        let anchored = anchor("", SearchParameters(personRollupId: 12, personAnchor: Self.kissinger))
        #expect(slotOnly.isSameSearch(as: anchored))
        #expect(anchored.isSameSearch(as: slotOnly))
        #expect(!slotOnly.isSameSearch(as: anchor("", SearchParameters(personRollupId: 13))))
    }

    @Test("A single volume's person reference names a person too")
    func personRefNamesAPerson() {
        let one = anchor("", SearchParameters(personRef: "p_KHA1"))
        #expect(one.isSameSearch(as: anchor("", SearchParameters(personRef: "p_KHA1"))))
        #expect(!one.isSameSearch(as: anchor("", SearchParameters(personRef: "p_RWP1"))))
        #expect(!one.isSameSearch(as: anchor("", SearchParameters(personRollupId: 12))),
                "a reference and a slot share no handle, so they are not known to be one person")
    }

    @Test("A browse of one topic and a browse of another are different searches")
    func anotherTopicIsAnotherSearch() {
        let first = anchor("", SearchParameters(subjectRef: "rec_korean_war", subjectName: "Korean War"))
        #expect(first.isSameSearch(as: anchor("", SearchParameters(subjectRef: "rec_korean_war"))))
        #expect(!first.isSameSearch(as: anchor("", SearchParameters(subjectRef: "collective-security"))))
    }

    @Test("A browse of one subject area and a browse of another are different searches")
    func anotherSubjectAreaIsAnotherSearch() {
        let keyed = anchor("", SearchParameters(subjectBucket: 3, subjectBucketKey: "Regions/Africa"))
        #expect(keyed.isSameSearch(as: anchor("", SearchParameters(subjectBucket: 9, subjectBucketKey: "Regions/Africa"))),
                "the durable key names the area; its position may move")
        #expect(!keyed.isSameSearch(as: anchor("", SearchParameters(subjectBucket: 3, subjectBucketKey: "Regions/Asia"))))
        let positional = anchor("", SearchParameters(subjectBucket: 3))
        #expect(positional.isSameSearch(as: anchor("", SearchParameters(subjectBucket: 3))))
        #expect(!positional.isSameSearch(as: anchor("", SearchParameters(subjectBucket: 4))))
    }

    /// A date range, a volume scope and a document type are filters on a browse as on a search.
    @Test("A browse keeps its marks when a filter that is not its person or subject changes")
    func otherFiltersDoNotMakeAnotherBrowse() {
        let browse = anchor("", SearchParameters(personRollupId: 12, personAnchor: Self.kissinger))
        let narrowed = anchor("", SearchParameters(
            dateRange: DateRange(earliest: "1969-01-01", latest: "1972-12-31"),
            yearKeys: ["1971"], volumeIds: ["frus1969-76v01"],
            documentTypeFilter: .documentsOnly,
            personRollupId: 12, personAnchor: Self.kissinger))
        #expect(browse.isSameSearch(as: narrowed))
    }

    /// The browse was of Kissinger. Narrowing it to a subject area is still a browse of Kissinger;
    /// dropping Kissinger for the subject area alone is not.
    @Test("A subject added to a person's browse narrows it; the person taken away ends it")
    func addingNarrowsAndRemovingEnds() {
        let person = anchor("", SearchParameters(personRollupId: 12, personAnchor: Self.kissinger))
        let personInArea = anchor("", SearchParameters(
            personRollupId: 12, personAnchor: Self.kissinger, subjectBucket: 3, subjectBucketKey: "Regions/Africa"))
        let areaAlone = anchor("", SearchParameters(subjectBucket: 3, subjectBucketKey: "Regions/Africa"))

        #expect(person.isSameSearch(as: personInArea), "an area added to the person's browse is a narrowing")
        #expect(!person.isSameSearch(as: areaAlone), "the person the browse was of is gone")
        #expect(!personInArea.isSameSearch(as: person),
                "anchored with the area, a browse without it is no longer what was anchored")
        #expect(areaAlone.isSameSearch(as: personInArea), "a person added to an area's browse is a narrowing")
    }

    @Test("A browse and a search with words are different searches")
    func browseAndWordsDiffer() {
        let browse = anchor("", SearchParameters(personRollupId: 12))
        let words = anchor("chile", SearchParameters(personRollupId: 12))
        #expect(!browse.isSameSearch(as: words))
        #expect(!words.isSameSearch(as: browse))
    }

    /// A checklist turned on before anything was searched is anchored to nothing. The first browse
    /// must take the anchor over, or the browse after it would inherit the first one's marks.
    @Test("An anchor made before any search is not the same search as the first browse")
    func emptyAnchorIsNotABrowse() {
        let nothing = anchor("")
        #expect(nothing.browse == nil)
        #expect(!nothing.isSameSearch(as: anchor("", SearchParameters(personRollupId: 12))))
        #expect(!nothing.isSameSearch(as: anchor("alpha")))
    }
}

// MARK: - ChecklistStripTests

/// The checklist strip's words, and its wiring in both hosts (#1576 lane 1).
///
/// The Mac's half is read from source: `MacSearchViewModel` and the Search window compile for the
/// Mac only, and this bundle builds for iOS. Each scan matches the call it guards.
@Suite("Checklist strip")
struct ChecklistStripTests {

    private static let enUS = Locale(identifier: "en_US")

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// `text` with every run of whitespace removed, so a scan matches a call however it is wrapped.
    private static func squeezed(_ text: String) -> String {
        text.filter { !$0.isWhitespace }
    }

    /// The body of the declaration that opens with `header`, to the line that closes it at the
    /// header's own indentation.
    private static func declaration(_ header: String, in source: String) throws -> Substring {
        let start = try #require(source.range(of: header))
        let lineStart = source[..<start.lowerBound].lastIndex(of: "\n").map(source.index(after:)) ?? source.startIndex
        let indent = source[lineStart..<start.lowerBound]
        let close = try #require(source.range(of: "\n\(indent)}\n", range: start.upperBound..<source.endIndex))
        return source[start.lowerBound..<close.upperBound]
    }

    // MARK: The words

    @Test("The announcements count the results, in the singular at one and grouped past 999")
    func announcementsCount() {
        #expect(ChecklistCopy.markedAnnouncement(1, locale: Self.enUS) == "1 result marked reviewed")
        #expect(ChecklistCopy.markedAnnouncement(25, locale: Self.enUS) == "25 results marked reviewed")
        #expect(ChecklistCopy.markedAnnouncement(1_500, locale: Self.enUS) == "1,500 results marked reviewed")
        #expect(ChecklistCopy.undoneAnnouncement(1, locale: Self.enUS) == "1 result is back in the list")
        #expect(ChecklistCopy.undoneAnnouncement(25, locale: Self.enUS) == "25 results are back in the list")
    }

    @Test("The hidden line keeps the words it has always had, and has words for none")
    func hiddenLine() {
        #expect(ChecklistCopy.hidden(12) == "12 reviewed hidden")
        #expect(ChecklistCopy.nothingHidden == "Nothing hidden")
    }

    /// A reader working down a list presses Mark Page Reviewed again and again. If the first press
    /// put a count line above the buttons, or an Undo before the button, the second press would
    /// land on something else. So the strip's body chooses nothing by the count or by whether there
    /// is an undo: the line and both buttons are always drawn, and Undo is dimmed.
    @Test("Nothing in the strip is added or removed when a page is marked")
    func stripDoesNotReflowOnAMark() throws {
        let strip = try Self.source("FRUSExplorer/Search/ChecklistStrip.swift")
        let body = Self.squeezed(String(try Self.declaration("var body: some View {", in: strip)))
        #expect(!body.contains("ifcanUndo"), "the body must not add Undo when there is something to undo")
        #expect(!body.contains("ifhiddenCount"), "the body must not add the count's line when something is hidden")
        #expect(!body.contains("if!canUndo"))
        // Both layouts draw the line and both buttons.
        #expect(body.components(separatedBy: "markPageButton").count - 1 == 3,
                "Mark Page Reviewed is drawn in the row, and in both arrangements of the stacked layout")
        #expect(body.components(separatedBy: "undoButton").count - 1 == 3,
                "Undo is drawn wherever Mark Page Reviewed is")
        #expect(body.components(separatedBy: "status").count - 1 == 2, "the line is drawn in both layouts")

        let undo = Self.squeezed(String(try Self.declaration("private var undoButton: some View {", in: strip)))
        #expect(undo.contains(".disabled(!canUndo)"), "Undo is dimmed, not removed, with nothing to undo")
        #expect(!undo.contains("ifcanUndo"))
        let status = Self.squeezed(String(try Self.declaration("private var status: some View {", in: strip)))
        #expect(status.contains(Self.squeezed(
            "Label(hiddenCount > 0 ? ChecklistCopy.hidden(hiddenCount) : ChecklistCopy.nothingHidden,")),
            "the line is one Label in both states")
    }

    // MARK: The wiring

    /// The strip is there whenever the mode is on: no test of the hidden count stands between the
    /// mode and the strip, on either platform. That test is what kept the old line off screen
    /// until a row had gone.
    @Test("Both hosts mount the strip whenever Checklist Mode is on, and hand it the page")
    func bothHostsMountTheStrip() throws {
        let hosts: [(path: String, model: String)] = [
            ("FRUSExplorer/Search/SearchView.swift", "vm"),
            ("FRUSExplorer/App/SearchSheet.swift", "searchVM"),
        ]
        for host in hosts {
            let banner = try Self.declaration(
                "private var checklistHiddenBanner: some View {", in: try Self.source(host.path))
            let body = Self.squeezed(String(banner))
            let model = host.model
            #expect(body.contains(Self.squeezed("if \(model).checklistMode { ChecklistStrip(")),
                    "\(host.path): the strip must be the first thing inside the mode's condition")
            #expect(!body.contains("hidden>0"), "\(host.path): the strip must not wait for a hidden row")
            #expect(body.contains(Self.squeezed(
                "hiddenCount: \(model).results.count - \(model).displayedResults.count,")))
            #expect(body.contains(Self.squeezed(
                "pageRowCount: activeReading.isPaged ? \(model).pagedResults.count : 0,")))
            // Undo is offered where Mark Page Reviewed is: under a reading with a page. A
            // collocation is not rebuilt when a mark changes, so an undo made under it would
            // leave the panel ranking a set it no longer describes.
            #expect(body.contains(Self.squeezed("canUndo: activeReading.isPaged && \(model).canUndoBulkMark,")),
                    "\(host.path): Undo must be dimmed under the timeline and the collocates")
            #expect(body.contains(Self.squeezed(
                "markPage: { \(model).markReviewed(\(model).pagedResults) },")))
            #expect(body.contains(Self.squeezed("undo: { \(model).undoLastBulkMark() })")))
            #expect(body.contains(Self.squeezed(
                "loggingNotice: ChecklistLoggingNotice.text(checklistMode: \(model).checklistMode,")))
        }
    }

    @Test("The Mac view model stores the marks and the anchor as the iPhone's does")
    func macViewModelStoresTheSharedTypes() throws {
        let mac = try Self.source("FRUSExplorer/App/MacSearchViewModel.swift")
        let iOS = try Self.source("FRUSExplorer/Search/SearchViewModel.swift")
        for (name, text) in [("MacSearchViewModel", mac), ("SearchViewModel", iOS)] {
            let squeezed = Self.squeezed(text)
            #expect(squeezed.contains(Self.squeezed("private(set) var reviewedMarks = ReviewedMarks() {")),
                    "\(name) must store ReviewedMarks")
            #expect(squeezed.contains(Self.squeezed("var markedReviewedKeys: Set<String> { reviewedMarks.keys }")),
                    "\(name) must keep markedReviewedKeys as a read of the marks")
            #expect(squeezed.contains(Self.squeezed("private(set) var checklistAnchor: ChecklistAnchor?")),
                    "\(name) must store its anchor as a ChecklistAnchor")
            #expect(squeezed.contains(Self.squeezed("""
                reviewedMarks.markBulk(results.map {
                    Self.reviewedKey(volumeId: $0.volumeId, documentId: $0.documentId)
                }).subtracting(readSinceEnabledKeys).count
                """)), "\(name) must mark a page through ReviewedMarks, with keys built by reviewedKey, and count the rows that left")
            // What Undo offers and what it reports are one count, read before the undo: the rows
            // of the loaded results that would come back, not the size of the mark.
            #expect(squeezed.contains(Self.squeezed("""
                private var undoableRowCount: Int {
                    reviewedMarks.undoableCount(
                        among: results.lazy.map { Self.reviewedKey(volumeId: $0.volumeId, documentId: $0.documentId) },
                        otherwiseHidden: readSinceEnabledKeys)
                }
                """)), "\(name) must count what Undo restores over the loaded results, less what is opened")
            #expect(squeezed.contains(Self.squeezed("var canUndoBulkMark: Bool { undoableRowCount > 0 }")),
                    "\(name) must offer Undo only where it would bring a row back")
            #expect(squeezed.contains(Self.squeezed("""
                func undoLastBulkMark() -> Int {
                    let restored = undoableRowCount
                    reviewedMarks.undoLastBulk()
                """)), "\(name) must read the count before the undo, and undo through ReviewedMarks")
            #expect(!squeezed.contains("reviewedMarks.undoLastBulk().count"),
                    "\(name) reports the size of the mark where it should report the rows that came back")
            #expect(squeezed.contains(Self.squeezed("""
                guard checklistMode, checklistAnchor?.isSameSearch(as: anchor) != true else { return }
                checklistAnchor = anchor
                checklistEnabledAt = .now
                readSinceEnabledKeys.removeAll()
                reviewedMarks.reset()
                """)), "\(name) must settle the checklist through the anchor's rule")
        }
    }

    /// The anchor is of the search that runs, on both of the Mac's paths: built from the query and
    /// the parameters that path sends, never from a stored string.
    @Test("Both Mac search paths build the checklist's anchor from the parameters they run")
    func macSearchPathsAnchorOnWhatTheyRun() throws {
        let mac = try Self.source("FRUSExplorer/App/MacSearchViewModel.swift")
        let keyword = try Self.declaration("func performSearch(service: SearchService?) async {", in: mac)
        #expect(keyword.contains("settleChecklist(for: ChecklistAnchor(query: query, parameters: params))"))
        let settleAt = try #require(keyword.range(of: "settleChecklist(for:"))
        let fetchAt = try #require(keyword.range(of: "service.search(parameters: frozenParams"))
        let paramsAt = try #require(keyword.range(of: "params.keywords = query.isEmpty ? nil : query"))
        #expect(paramsAt.upperBound < settleAt.lowerBound, "the anchor is built after the parameters are")
        #expect(settleAt.upperBound < fetchAt.lowerBound, "and before the search is sent")

        let meaning = try Self.declaration("private func performMeaningSearch() async {", in: mac)
        #expect(meaning.contains("settleChecklist(for: ChecklistAnchor(query: query, parameters: parameters))"))

        let code = mac.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
        #expect(code.filter { $0.contains("settleChecklist(for:") && !$0.contains("func ") }.count == 2,
                "the two search paths, and no third place, settle the checklist")
        #expect(!mac.contains("lastChecklistAnchorQuery"), "the anchored string is gone; the anchor is the type")
    }

    /// Turning the mode on anchors it to the search whose rows are on screen. On the Mac every
    /// filter edit runs the search, so the parameters as they stand are that search's. On iPhone
    /// and iPad the Filters fields can be edited without a run, so the view model records the
    /// anchor of each search that completes and the mode takes that.
    @Test("Turning Checklist Mode on anchors it to the search whose rows are on screen, on both platforms")
    func turningTheModeOnAnchorsToTheSearchOnScreen() throws {
        let mac = try Self.source("FRUSExplorer/App/MacSearchViewModel.swift")
        let macOn = Self.squeezed(String(try Self.declaration("func setChecklistMode(_ on: Bool) {", in: mac)))
        #expect(macOn.contains(Self.squeezed("""
            checklistEnabledAt = .now
            checklistAnchor = ChecklistAnchor(query: submittedQuery, parameters: submittedSearchParameters)
            reviewedMarks.reset()
            """)), "the Mac anchors the mode to the submitted query and the parameters it runs with")

        let iOS = try Self.source("FRUSExplorer/Search/SearchViewModel.swift")
        let iOSOn = Self.squeezed(String(try Self.declaration("func setChecklistMode(_ on: Bool) {", in: iOS)))
        #expect(iOSOn.contains(Self.squeezed("""
            checklistAnchor = lastCompletedSearchAnchor
                ?? ChecklistAnchor(query: submittedQuery, parameters: submittedSearchParameters)
            reviewedMarks.reset()
            """)), "the iPhone anchors the mode to the search that last completed")
        let settle = Self.squeezed(String(try Self.declaration(
            "private func settleChecklist(for anchor: ChecklistAnchor) {", in: iOS)))
        #expect(settle.contains(Self.squeezed("""
            lastCompletedSearchAnchor = anchor
            guard checklistMode,
            """)), "every completed search is recorded, whether or not the mode is on")
    }

    /// A page marked reviewed changes every row under the same page index, so the list must
    /// stand at its top as after a page turn. `SearchChecklistModeTests` runs the counter.
    @Test("The iPhone's result list is re-identified by a bulk mark as it is by a page turn")
    func iOSListReturnsToTheTopOnABulkMark() throws {
        let view = try Self.source("FRUSExplorer/Search/SearchView.swift")
        let list = try Self.declaration("private var resultsList: some View {", in: view)
        #expect(list.contains(".id([vm.currentPage, vm.bulkMarkGeneration])"))
        #expect(!list.contains(".id(vm.currentPage)"))
    }

    @Test("The iPhone's two search paths settle the checklist with the parameters that ran")
    func iOSSearchPathsAnchorOnWhatRan() throws {
        let iOS = try Self.source("FRUSExplorer/Search/SearchViewModel.swift")
        let keyword = try Self.declaration("func search() async {", in: iOS)
        #expect(keyword.contains("settleChecklist(for: ChecklistAnchor(query: submittedQuery, parameters: params))"))
        let meaning = try Self.declaration("private func searchMeaning() async {", in: iOS)
        let anchorAt = try #require(meaning.range(of:
            "let checklistAnchorOfThisRun = ChecklistAnchor(query: submittedQuery, parameters: searchParameters)"))
        let awaitAt = try #require(meaning.range(of: "try await backend.run("))
        let settleAt = try #require(meaning.range(of: "settleChecklist(for: checklistAnchorOfThisRun)"))
        #expect(anchorAt.upperBound < awaitAt.lowerBound, "the anchor is read before the await")
        #expect(awaitAt.upperBound < settleAt.lowerBound, "and settled when the rows are in")
    }

    @Test("The anchor decides the same words by the history writer's rule")
    func anchorAsksTheWriter() throws {
        let anchor = try Self.source("FRUSExplorer/Search/ReviewedMarks.swift")
        #expect(anchor.contains("guard SearchHistoryWriter.isSameQuery(query, next.query),"))
    }
}
