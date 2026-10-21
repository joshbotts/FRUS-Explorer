// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import Testing
@testable import FRUSExplorer

// MARK: - SearchResultAccessibilityTests (#1684)

/// What VoiceOver says of a search result on iPhone and iPad, read from the functions the row calls
/// (`SearchResultAccessibility`). `SearchResultVoiceOverTests` listens to the same rows in the app.
///
/// Version history:
///   1.0 — #1684: initial implementation
///   1.1 — A10b (decision 74): More Content keeps about 300 characters in all, the snippet's lead of
///         about 30 and the rest after the word; a keyword row that shows its opening prose offers it
@Suite("A search result, as VoiceOver reads it")
struct SearchResultAccessibilityTests {

    /// `frus1961-63v11` d41, as the index stores it: a head that prints its own number, a dateline,
    /// and a source note whose second sentence is the classification.
    private static func minutes(snippet: String = "… The President opened the meeting …",
                                semanticScore: Double? = nil,
                                isEditorialNote: Bool = false,
                                isFrontMatter: Bool = false) -> SearchResult {
        SearchResult(documentId: "d41", volumeId: "frus1961-63v11", documentNumber: "41",
                     header: "41. Minutes of the 507th Meeting of the National Security Council",
                     dateline: "Washington, October 22, 1962, 3 p.m.",
                     sourceNote: "Source: Kennedy Library, National Security Files, Meetings and Memoranda Series, "
                        + "NSC Meetings. Top Secret. The source text bears no drafting information.",
                     snippet: snippet, bm25Score: -12, semanticScore: semanticScore,
                     isEditorialNote: isEditorialNote, isFrontMatter: isFrontMatter)
    }

    /// A row with only what every row has: a heading and a volume.
    private static func bare(header: String, number: String? = nil, snippet: String = "",
                             semanticScore: Double? = nil) -> SearchResult {
        SearchResult(documentId: "d17", volumeId: "frus1865p1", documentNumber: number, header: header,
                     snippet: snippet, bm25Score: -3, semanticScore: semanticScore)
    }

    @Test("The label is the heading, then the row as drawn: dateline, volume, classification, tags (decision 73)")
    func labelInDrawnOrder() {
        let tags = [UserTagChip(id: "A", name: "Cuba"), UserTagChip(id: "B", name: "Berlin")]
        #expect(SearchResultAccessibility.label(for: Self.minutes(), tags: tags)
                == "41. Minutes of the 507th Meeting of the National Security Council, "
                + "Washington, October 22, 1962, 3 p.m., frus1961-63v11, "
                + "Classification markings: Top Secret, Tags: Cuba, Berlin")
        #expect(SearchResultAccessibility.label(for: Self.minutes(), tags: [])
                == "41. Minutes of the 507th Meeting of the National Security Council, "
                + "Washington, October 22, 1962, 3 p.m., frus1961-63v11, Classification markings: Top Secret")
    }

    @Test("A row with no dateline says the day or span the index dates it by, where the dateline would be (A18)")
    func drawnDateInPlaceOfADateline() throws {
        // A meeting's list of those present: a section's row, dated by its documents (index version 70).
        let meeting = SearchResult(documentId: "ch1", volumeId: "frus1945Berlinv02",
                                   header: "Meeting of the Joint Chiefs of Staff, 10 a.m.",
                                   dateISO: "1945-07-16", dateISOMax: "1945-07-16", datePrecision: .day,
                                   snippet: "", bm25Score: -3)
        let drawn = try #require(meeting.drawnDate)
        #expect(drawn == SearchResultDate.text(dateISO: "1945-07-16", dateISOMax: "1945-07-16", precision: .day))
        #expect(SearchResultAccessibility.label(for: meeting, tags: [])
                == "Meeting of the Joint Chiefs of Staff, 10 a.m., \(drawn), frus1945Berlinv02")
        // A dateline the text prints wins, and a row with neither says neither.
        #expect(SearchResultAccessibility.label(for: Self.minutes(), tags: []).contains("Washington, October 22, 1962, 3 p.m."))
        #expect(SearchResultAccessibility.label(for: Self.bare(header: "Spain."), tags: []) == "Spain., frus1865p1")
    }

    @Test("The number is read where the row draws it, before the heading, and never twice")
    func numberWhereDrawn() {
        // The head does not print it, so the row draws it beside the heading.
        #expect(SearchResultAccessibility.label(for: Self.bare(header: "Mr. Adams to Mr. Seward", number: "17"), tags: [])
                == "17. Mr. Adams to Mr. Seward, frus1865p1")
        // The head prints it, so the row draws none of its own (`headerRepeatsNumber`).
        #expect(SearchResultAccessibility.heading(for: Self.minutes())
                == "41. Minutes of the 507th Meeting of the National Security Council")
        // A letter-suffixed number printed in capitals is the head's own.
        #expect(SearchResultAccessibility.heading(for: Self.bare(header: "278A. Memorandum", number: "278a"))
                == "278A. Memorandum")
        // No number, or an empty one, draws none.
        #expect(SearchResultAccessibility.heading(for: Self.bare(header: "Editorial Note")) == "Editorial Note")
        #expect(SearchResultAccessibility.heading(for: Self.bare(header: "Editorial Note", number: "")) == "Editorial Note")
    }

    @Test("Each badge is read after the classification, in the order the row draws them")
    func badges() {
        #expect(SearchResultAccessibility.label(for: Self.minutes(isEditorialNote: true, isFrontMatter: true), tags: [])
                .hasSuffix("Classification markings: Top Secret, Editorial Note, Front Matter"))
        #expect(SearchResultAccessibility.editorialNoteBadge == "Editorial Note")
        #expect(SearchResultAccessibility.frontMatterBadge == "Front Matter")
    }

    @Test("A part the row does not draw is not read, and neither the snippet nor the score is in the label")
    func onlyWhatIsDrawn() {
        let label = SearchResultAccessibility.label(
            for: Self.bare(header: "Mr. Adams to Mr. Seward", snippet: "the <b>treaty</b> of 1865", semanticScore: 0.71),
            tags: [])
        #expect(label == "Mr. Adams to Mr. Seward, frus1865p1")
        // A note with no marking sentence draws no chip.
        let unmarked = SearchResult(documentId: "d1", volumeId: "frus1952-54v05p1",
                                    header: "Memorandum of Conversation",
                                    sourceNote: "Source: Department of State, Central Files, 740.5/1-1052.",
                                    snippet: "", bm25Score: -1)
        #expect(SearchResultAccessibility.label(for: unmarked, tags: []) == "Memorandum of Conversation, frus1952-54v05p1")
    }

    @Test("A heading that runs on into its source note is read as the row draws it, trimmed")
    func trimmedHeading() {
        let leaked = Self.bare(header: "Memorandum From Rostow to Johnson Source: Johnson Library, National Security File")
        #expect(SearchResultAccessibility.heading(for: leaked) == "Memorandum From Rostow to Johnson")
    }

    @Test("The label and the classification chip say the chip's words alike")
    func classificationWords() {
        #expect(ClassificationChip.accessibilityLabel(for: "Secret; Nodis") == "Classification markings: Secret; Nodis")
        #expect(SearchResultAccessibility.label(for: Self.minutes(), tags: [])
                .contains(ClassificationChip.accessibilityLabel(for: "Top Secret")))
    }

    @Test("A tag's action is named as its chip is, and the tags part lists them in order")
    func tagWords() {
        #expect(SearchResultAccessibility.filterAction(tagName: "Cuba") == "Filter by Cuba")
        #expect(SearchResultAccessibility.tagList(["Cuba"]) == "Tags: Cuba")
        #expect(SearchResultAccessibility.tagList(["Cuba", "Berlin"]) == "Tags: Cuba, Berlin")
    }

    /// Read from source: no UI test can make VoiceOver do a custom action (a tap goes to the element
    /// under it; `SearchResultVoiceOverTests` says what was measured). That suite reads the action's
    /// words from VoiceOver and drives the chip's tap; this holds the action to the chip's function.
    @Test("A row's action for a tag calls the function its chip's tap calls, and is not offered in selection")
    func theActionIsTheChipsFunction() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let code = try String(contentsOf: root.appendingPathComponent("FRUSExplorer/Search/SearchView.swift"),
                              encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined()
            .filter { !$0.isWhitespace }
        func squeezed(_ text: String) -> String { text.filter { !$0.isWhitespace } }
        #expect(code.contains(squeezed("""
            .accessibilityActions {
                if !vm.resultSelection.isSelecting {
                    ForEach(chips) { chip in
                        Button(SearchResultAccessibility.filterAction(tagName: chip.name)) {
                            filterResults(byUserTag: chip.id)
                        }
                    }
                }
            }
            """)), "the row's actions for its tags")
        #expect(code.contains(squeezed("""
            guard !vm.resultSelection.isSelecting else {
                vm.toggleSelection(of: result)
                return
            }
            filterResults(byUserTag: tagId)
            """)), "the chip's tap: it picks its row in selection, and filters by its tag outside it")
        // One place narrows the search by a tag, so the action and the chip cannot differ.
        #expect(code.components(separatedBy: "vm.selectedUserTagIds.insert(").count - 1 == 1)
        // The label the row is given is the composed one, with the chips the row draws.
        #expect(code.contains(".accessibilityLabel(SearchResultAccessibility.label(for:result,tags:chips))"))
        #expect(code.contains("letchips=UserTag.chips(for:result.userTagIds,among:vm.availableUserTags)"))
    }

    @Test("More Content offers a keyword row's words around its match, as \"Matched text\"")
    func matchedText() throws {
        let row = Self.minutes(snippet: "The President opened the meeting by asking Secretary <b>Rusk</b> to read the "
                                + "attached message from Prime Minister Macmillan.")
        let content = try #require(SearchResultAccessibility.moreContent(for: row))
        #expect(content.label == "Matched text")
        #expect(content.text == "The President opened the meeting by asking Secretary Rusk to read the attached "
                + "message from Prime Minister Macmillan.")
    }

    @Test("More Content keeps about 300 characters: the snippet's lead before the match, then the rest after it")
    func matchedTextWindow() throws {
        // A keyword snippet since A10b: about 30 characters before its word and 2,000 after.
        let after = (1...400).map { "w\($0)" }.joined(separator: " ")
        let snippet = "… Bonn’s 3463 to Department repeated <b>Berlin</b> " + after + " …"
        let text = try #require(SearchResultAccessibility.matchedText(inSnippet: snippet))
        #expect(text.hasPrefix("… Bonn’s 3463 to Department repeated Berlin w1 w2 w3"), "the lead is kept whole")
        #expect(text.hasSuffix(" …"))
        #expect(abs(text.count - SearchResultAccessibility.moreContentLength) <= 6, "\(text.count) characters")
        #expect(!text.contains("<b>") && !text.contains("</b>"))
        // Before the word no more than half the length is kept, so a long lead is cut too, and marked:
        // twenty characters of it, then the rest of forty after the word, in whole words.
        let before = (1...60).map { "w\($0)" }.joined(separator: " ")   // 230 characters
        let longLead = try #require(SearchResultAccessibility.matchedText(
            inSnippet: "… " + before + " <b>match</b> " + after + " …", length: 40))
        #expect(longLead == "… w56 w57 w58 w59 w60 match w1 w2 w3 w4 w5 …")
    }

    @Test("A window that cuts at a word's end keeps the word; one that reaches the snippet's ends keeps its marks")
    func matchedTextEdges() throws {
        // Twenty characters after the match end on a word's last letter: that word is kept.
        #expect(SearchResultAccessibility.matchedText(inSnippet: "<b>m</b> abcdefghi jklmnopqrs tuv", length: 21)
                == "m abcdefghi jklmnopqrs …")
        // Twenty that end inside a word stop before it.
        #expect(SearchResultAccessibility.matchedText(inSnippet: "<b>m</b> abcde fghij klmno pqrs tuv", length: 21)
                == "m abcde fghij klmno …")
        // A length the lead and the word use up leaves an ellipsis after them.
        #expect(SearchResultAccessibility.matchedText(inSnippet: "<b>match</b> and more", length: 5) == "match …")
        // The snippet's own "… " and " …" stay where the window reaches them.
        #expect(SearchResultAccessibility.matchedText(inSnippet: "… asking Secretary <b>Rusk</b> to read …")
                == "… asking Secretary Rusk to read …")
        // A match against punctuation stays against it, and white space runs read as one space.
        #expect(SearchResultAccessibility.matchedText(inSnippet: "the Secretary (<b>Rusk</b>),\n  who read")
                == "the Secretary (Rusk), who read")
        #expect(SearchResultAccessibility.matchedText(inSnippet: "no match marked here") == nil)
        #expect(SearchResultAccessibility.matchedText(inSnippet: "an <b>unclosed mark") == nil)
    }

    @Test("More Content is a Meaning row's opening prose, and nothing for a row whose snippet is its heading again")
    func moreContentByEngine() throws {
        let prose = "The President opened the meeting by asking Secretary Rusk to read the attached message."
        let meaning = try #require(SearchResultAccessibility.moreContent(for: Self.minutes(snippet: prose,
                                                                                          semanticScore: 0.64)))
        #expect(meaning.label == "Opening text")
        #expect(meaning.text == prose)
        // A long prose snippet is cut, at a space, with its cut marked.
        let long = String(repeating: "opening ", count: 80)
        let cut = try #require(SearchResultAccessibility.moreContent(for: Self.minutes(snippet: long, semanticScore: 0.5)))
        #expect(cut.text.count <= SearchResultAccessibility.moreContentLength + 2)
        #expect(cut.text.hasSuffix("opening …"))
        // A keyword row whose body did not hold the words shows its heading and dateline again, and
        // offers nothing, ranked by a question (a score added) or not.
        let fallback = Self.minutes(snippet: "41. Minutes of the 507th Meeting of the National Security Council · "
                                    + "Washington, October 22, 1962, 3 p.m.")
        #expect(SearchResultAccessibility.isHeadingAndDatelineAgain(fallback))
        #expect(SearchResultAccessibility.moreContent(for: fallback) == nil)
        #expect(SearchResultAccessibility.moreContent(for: fallback.replacingScores(bm25: -12, semantic: 0.5)) == nil)
        // An undated row's is its heading alone.
        #expect(SearchResultAccessibility.isHeadingAndDatelineAgain(
            Self.bare(header: "Mr. Adams to Mr. Seward", snippet: "Mr. Adams to Mr. Seward", semanticScore: 0.5)))
        // A Meaning row with no prose offers nothing.
        #expect(SearchResultAccessibility.moreContent(for: Self.minutes(snippet: "", semanticScore: 0.5)) == nil)
    }

    @Test("A keyword row whose words are only in its heading offers its opening prose, as a Meaning row does")
    func keywordOpeningProse() throws {
        // Since A10b the service shows such a row the document's opening prose, unmarked (decision 74),
        // and it has no score: More Content is that prose.
        let prose = "The President opened the meeting by asking Secretary Rusk to read the attached message."
        let content = try #require(SearchResultAccessibility.moreContent(for: Self.minutes(snippet: prose)))
        #expect(content == SearchResultAccessibility.MoreContent(label: "Opening text", text: prose))
    }

    /// The heading-and-dateline form is the service's, not this file's: a row the service gives no
    /// words to mark is read through `SearchService.results(from:parameters:)` itself.
    @Test("A row whose body does not hold the words gets the heading and dateline again from the service, and no More Content")
    func theServicesHeadingAndDatelineAgain() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-more-content-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let dbURL = dir.appendingPathComponent("frus.db")
        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(fts5Store: store, databaseURL: dbURL, volumesDirectory: dir,
                                            concurrencyLimit: 1)
        let service = SearchService(fts5Store: store, pipeline: pipeline)
        let row = IndexedSearchRow(documentId: "d41", volumeId: "frus1961-63v11", documentNumber: "41",
                                   header: "41. Minutes of the 507th Meeting of the National Security Council",
                                   dateline: "Washington, October 22, 1962, 3 p.m.", sourceNote: nil,
                                   bodyText: "The President opened the meeting.", subjectTagIds: nil, userTagIds: nil,
                                   isEditorialNote: false, isFrontMatter: false, dateISO: "1962-10-22", score: -3)
        let results = try await service.results(from: [row], parameters: SearchParameters(keywords: "blockade"))
        let result = try #require(results.first)
        #expect(SearchResultAccessibility.isHeadingAndDatelineAgain(result), "the service's snippet: \(result.snippet)")
        #expect(SearchResultAccessibility.moreContent(for: result.replacingScores(bm25: -3, semantic: 0.5)) == nil)
        // And the same row with the word in its body is marked, and offers its words.
        let marked = try await service.results(from: [row], parameters: SearchParameters(keywords: "president"))
        #expect(SearchResultAccessibility.moreContent(for: try #require(marked.first))?.label == "Matched text")
        // A body that opens with the heading and dateline, as an indexed one does, and holds the word
        // only there, shows its opening prose, which More Content offers (A10b).
        let opening = IndexedSearchRow(documentId: "d41", volumeId: "frus1961-63v11", documentNumber: "41",
                                       header: row.header, dateline: row.dateline, sourceNote: nil,
                                       bodyText: row.header + " " + (row.dateline ?? "") + " " + row.bodyText,
                                       subjectTagIds: nil, userTagIds: nil, isEditorialNote: false,
                                       isFrontMatter: false, dateISO: "1962-10-22", score: -3)
        let openingResults = try await service.results(from: [opening], parameters: SearchParameters(keywords: "minutes"))
        let unmarked = try #require(openingResults.first)
        #expect(unmarked.snippet == "The President opened the meeting.")
        #expect(SearchResultAccessibility.moreContent(for: unmarked)
                == SearchResultAccessibility.MoreContent(label: "Opening text", text: "The President opened the meeting."))
    }
}

// MARK: - UITestSpokenVolumeSeederTests

#if DEBUG
/// The volume `SearchResultVoiceOverTests` searches (#1684): written and removed with the launch,
/// and indexed into rows whose labels are the ones that suite expects.
///
/// Version history:
///   1.0 — #1684: initial implementation
@Suite("UI-test spoken-row volume")
struct UITestSpokenVolumeSeederTests {

    private func makeVolumesDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-spoken-volume-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("A launch that asks writes the volume, and one that does not removes it and nothing else")
    func writtenWhenAskedAndRemovedWhenNot() throws {
        let dir = try makeVolumesDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let other = dir.appendingPathComponent("frus1961-63v06.xml")
        try Data("<TEI/>".utf8).write(to: other)
        let spoken = dir.appendingPathComponent("\(UITestVolumeSeeder.spokenVolumeId).xml")

        #expect(!UITestVolumeSeeder.prepareSpokenVolume(requested: false, in: dir), "nothing to remove yet")
        #expect(UITestVolumeSeeder.prepareSpokenVolume(requested: true, in: dir))
        #expect(FileManager.default.fileExists(atPath: spoken.path))

        #expect(UITestVolumeSeeder.prepareSpokenVolume(requested: false, in: dir))
        #expect(!FileManager.default.fileExists(atPath: spoken.path))
        #expect(FileManager.default.fileExists(atPath: other.path), "another volume's file is not the seed's to remove")
    }

    @Test("The query word is this volume's alone, and no other fixture's titles are in it")
    func fixtureIsItsOwn() {
        let word = UITestVolumeSeeder.spokenQueryWord
        #expect(UITestVolumeSeeder.spokenVolumeXML().components(separatedBy: word).count - 1 == 3)
        #expect(!UITestVolumeSeeder.fixtureXML(volumeId: "frus1961-63v06").contains(word))
        #expect(!UITestVolumeSeeder.bulkVolumeXML().contains(word))
        #expect(!UITestVolumeSeeder.spokenVolumeXML().contains("UI Test Document"),
                "the browse fixture's suites match its titles by substring")
    }

    /// Driven against a real pipeline: the three rows a search for the word lists, read through the
    /// functions the row calls, say what `SearchResultVoiceOverTests` expects of them.
    @Test("Indexed and searched, each row's label is the one the UI suite reads")
    func indexedRowsSayWhatTheSuiteReads() async throws {
        let dir = try makeVolumesDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let dbURL = dir.appendingPathComponent("frus.db")
        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(fts5Store: store, databaseURL: dbURL, volumesDirectory: dir,
                                            concurrencyLimit: 1)
        let service = SearchService(fts5Store: store, pipeline: pipeline)
        let query = SearchParameters(keywords: UITestVolumeSeeder.spokenQueryWord)

        UITestVolumeSeeder.prepareSpokenVolume(requested: true, in: dir)
        await UITestVolumeSeeder.prepareSpokenVolumeIndex(pipeline: pipeline, requested: true)
        #expect(try pipeline.isVolumeIndexed(UITestVolumeSeeder.spokenVolumeId))
        let rows = try await service.search(parameters: query, limit: 10)
        let labels = Set(rows.map { SearchResultAccessibility.label(for: $0, tags: []) })
        #expect(labels == [
            "7. UI Test Spoken Document, Washington, May 4, 1962, uitest-spoken-01, "
                + "Classification markings: Secret; Nodis",
            "8. UI Test Spoken Editorial Note, uitest-spoken-01, Editorial Note",
            "UI Test Spoken Preface, uitest-spoken-01, Front Matter",
        ])
        let document = try #require(rows.first { $0.documentId == "d7" })
        let content = try #require(SearchResultAccessibility.moreContent(for: document))
        #expect(content.label == "Matched text")
        #expect(content.text.contains(UITestVolumeSeeder.spokenQueryWord))
        // Since A10b the snippet starts at the prose, after the heading, source note and dateline
        // the label reads (decision 74); the row drew them again until then.
        #expect(document.snippet == "Spoken-row fixture, <b>\(UITestVolumeSeeder.spokenQueryWord)</b> document.")
        #expect(content.text == "Spoken-row fixture, \(UITestVolumeSeeder.spokenQueryWord) document.")

        UITestVolumeSeeder.prepareSpokenVolume(requested: false, in: dir)
        await UITestVolumeSeeder.prepareSpokenVolumeIndex(pipeline: pipeline, requested: false)
        #expect(try !pipeline.isVolumeIndexed(UITestVolumeSeeder.spokenVolumeId))
    }

    @Test("Boot writes or removes the volume beside the bulk volume, and brings its index to match")
    func bootPreparesTheSpokenVolume() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let app = try String(contentsOf: root.appendingPathComponent("FRUSExplorer/App/FRUSExplorerApp.swift"),
                             encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined()
            .filter { !$0.isWhitespace }
        #expect(app.contains("UITestVolumeSeeder.prepareBulkVolumeIfRequested(in:volumesDir)"
                             + "UITestVolumeSeeder.prepareSpokenVolumeIfRequested(in:volumesDir)"))
        #expect(app.contains("awaitUITestVolumeSeeder.prepareBulkVolumeIndex(pipeline:pipeline)"
                             + "awaitUITestVolumeSeeder.prepareSpokenVolumeIndex(pipeline:pipeline)"))
    }
}
#endif
