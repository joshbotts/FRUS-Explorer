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

import Testing
import Foundation
@testable import FRUSExplorer

/// Two persons-list encodings the corpus uses and the parser mishandled (#740, #741).
///
/// Every fixture here is a trimmed copy of real markup, not an invented shape — both defects were
/// found by cross-checking a TEI-derived volume census against the app's own database during the
/// #234 M1a survey, and both are things a plausible-looking parser gets wrong.
///
/// These drive `FRUSDocumentParser.parsePersons` — the real emitter — through a temporary volume
/// file, so a fix that only satisfied a re-implementation would not pass.
///
/// Version history:
///   1.0 — Session 2026-08-07: #740 / #741
@Suite("Persons list encodings")
struct PersonsListEncodingTests {

    /// Writes a minimal TEI volume whose front matter is `front`.
    private func makeVolume(front: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("persons-\(UUID().uuidString).xml")
        let xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <TEI xmlns="http://www.tei-c.org/ns/1.0">
              <text><front>\(front)</front><body></body></text>
            </TEI>
            """
        try Data(xml.utf8).write(to: url)
        return url
    }

    // MARK: - #740: the 1873 "correspondents" list

    @Test("A list under xml:id=\"correspondents\" is read (#740)")
    func readsCorrespondentsList() async throws {
        // Real shape from frus1873p1v1 / frus1873p1v2: `type="section"` with NO `subtype`, and an
        // xml:id none of the previously-accepted spellings match. 57 entries per volume were
        // dropped, and both volumes showed the "No Persons Listed" empty state.
        let url = try makeVolume(front: """
            <div type="section" xml:id="correspondents">
              <head>List of persons whose correspondence with or from the Department of State is
                    contained in this volume.</head>
              <list>
                <item><persName xml:id="p_HF1">Hamilton Fish</persName>, Secretary of State.</item>
                <item><persName xml:id="p_CH1">Charles Hale</persName>, Assistant Secretary of
                      State.</item>
              </list>
            </div>
            """)
        defer { try? FileManager.default.removeItem(at: url) }

        let persons = try await FRUSDocumentParser().parsePersons(volumeURL: url)
        #expect(persons.count == 2)
        let fish = try #require(persons.first { $0.ref == "p_HF1" })
        #expect(fish.name == "Hamilton Fish")
        #expect(fish.description?.contains("Secretary of State") == true)
        #expect(persons.contains { $0.ref == "p_CH1" && $0.name == "Charles Hale" })
    }

    @Test("The previously-accepted spellings still work (#740)")
    func keepsExistingSpellings() async throws {
        for xmlId in ["persons", "persName", "listOfPersons"] {
            let url = try makeVolume(front: """
                <div type="section" subtype="index" xml:id="\(xmlId)">
                  <list><item><persName xml:id="p_A1">Acheson, Dean</persName>, Secretary.</item></list>
                </div>
                """)
            defer { try? FileManager.default.removeItem(at: url) }
            let persons = try await FRUSDocumentParser().parsePersons(volumeURL: url)
            #expect(persons.count == 1, "xml:id=\(xmlId) stopped being recognised")
        }
    }

    @Test("An unrelated section is still not a persons list (#740)")
    func doesNotWidenTooFar() async throws {
        // The fix adds one id; it must not make every `<div type="section">` a persons list.
        let url = try makeVolume(front: """
            <div type="section" subtype="index" xml:id="terms">
              <list><item><gloss xml:id="t_NATO">NATO</gloss>: North Atlantic Treaty Organization.</item></list>
            </div>
            """)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(try await FRUSDocumentParser().parsePersons(volumeURL: url).isEmpty)
    }

    // MARK: - #741: nested index sub-entries are not people

    /// Real shape from `frus1941-43`'s "Index of Persons": one person, whose page references are
    /// nested `<list>`/`<item>` trees beneath them.
    private let nestedIndexEntry = """
        <div type="section" subtype="index" xml:id="persons">
          <head>Index of Persons</head>
          <list>
            <item>Arnold, Henry H., Lieutenant General, U.S.A., Chief of the Army Air Forces:
              <list>
                <item>Meetings:
                  <list>
                    <item>Casablanca Conference: Combined Chiefs of Staff, 536, 546, 547</item>
                    <item>First Washington Conference, 62, 64</item>
                  </list>
                </item>
                <item>Correspondence with, 88, 91</item>
              </list>
            </item>
            <item>Finletter, Thomas K., Special Assistant to the Secretary of State, 104</item>
          </list>
        </div>
        """

    @Test("Only the outermost item is a person (#741)")
    func nestedSubEntriesAreNotPeople() async throws {
        // Before the fix every nested <item> became its own row, which is how "Casablanca
        // Conference", "Meetings" and "Correspondence with" ended up filed under People.
        let url = try makeVolume(front: nestedIndexEntry)
        defer { try? FileManager.default.removeItem(at: url) }

        let persons = try await FRUSDocumentParser().parsePersons(volumeURL: url)
        let names = persons.map(\.name)
        #expect(!names.contains { $0.hasPrefix("Casablanca") }, "got \(names)")
        #expect(!names.contains { $0.hasPrefix("Meetings") }, "got \(names)")
        #expect(!names.contains { $0.hasPrefix("Correspondence") }, "got \(names)")
        #expect(!names.contains { $0.hasPrefix("First Washington") }, "got \(names)")
        #expect(names.contains { $0.hasPrefix("Arnold") })

        // Finletter is deliberately NOT expected. His entry ends ", 104", and
        // `PersonListHeuristics.isLikelyPersonName` rejects a name carrying a page-number run —
        // pre-existing behaviour that keeps back-of-book index rows out of the People browser,
        // unchanged by this fix. The guarantee here is only that no *sub-entry* becomes a person.
        #expect(persons.count == 1, "only top-level entries, and only clean ones; got \(names)")
    }

    @Test("A person's description stops at their sub-entries (#741)")
    func descriptionStopsAtNestedList() async throws {
        // Without the nested-list guard the outer item's text buffer swallows the whole subtree,
        // so Arnold's role would carry every page reference under him.
        let url = try makeVolume(front: nestedIndexEntry)
        defer { try? FileManager.default.removeItem(at: url) }

        let persons = try await FRUSDocumentParser().parsePersons(volumeURL: url)
        let arnold = try #require(persons.first { $0.name.hasPrefix("Arnold") })
        let text = (arnold.name) + " " + (arnold.description ?? "")
        #expect(!text.contains("Casablanca"), "sub-entry text leaked: \(text)")
        #expect(!text.contains("Correspondence with"), "sub-entry text leaked: \(text)")
        #expect(text.contains("Chief of the Army Air Forces"), "the real role was lost: \(text)")
    }

    @Test("A flat list is unaffected by the depth rule (#741)")
    func flatListStillWorks() async throws {
        // The overwhelming majority of volumes use a flat list; the depth rule must be a no-op
        // there, not a regression.
        let url = try makeVolume(front: """
            <div type="section" subtype="index" xml:id="persons">
              <list>
                <item><persName xml:id="p_K1">Kissinger, Henry A.</persName>, Secretary of State.</item>
                <item><persName xml:id="p_N1">Nixon, Richard M.</persName>, President.</item>
                <item><persName xml:id="p_R1">Rogers, William P.</persName>, Secretary of State.</item>
              </list>
            </div>
            """)
        defer { try? FileManager.default.removeItem(at: url) }
        let persons = try await FRUSDocumentParser().parsePersons(volumeURL: url)
        #expect(persons.count == 3)
        #expect(persons.map(\.ref).sorted() == ["p_K1", "p_N1", "p_R1"])
    }

    @Test("Two persons sections in one volume both parse (#741)")
    func sectionStateResetsBetweenSections() async throws {
        // The depth counters are section-scoped; a volume with a front-matter list and a
        // back-of-book index must not leave `itemDepth` stuck from the first.
        let url = try makeVolume(front: """
            <div type="section" subtype="index" xml:id="persons">
              <list><item><persName xml:id="p_A1">Acheson, Dean</persName>, Secretary.</item></list>
            </div>
            <div type="section" xml:id="correspondents">
              <list><item><persName xml:id="p_B1">Bohlen, Charles</persName>, Ambassador.</item></list>
            </div>
            """)
        defer { try? FileManager.default.removeItem(at: url) }
        let persons = try await FRUSDocumentParser().parsePersons(volumeURL: url)
        #expect(persons.map(\.ref).sorted() == ["p_A1", "p_B1"])
    }
}
