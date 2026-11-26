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
@testable import SourceNoteKit

// MARK: - SubjectNumericFootnoteTests (decision 191)

/// The Subject-Numeric File of 1963–73 in the footnote grammar (decision 191, index version 76):
/// the shipped chain's subject-numeric half, ``FootnoteIbidGapWalker/subjectNumericVerdict(_:)``,
/// and the `Ibid.` that names a file of its own under its referent's repository.
///
/// The clauses are the catalogue's own, from the measurement the rule was decided on, apart from
/// the two the White House and Central Foreign Policy File refusals are written for. Two the
/// measurement read give the class grammar no candidate at all, and are not here: a file with no
/// number (`Central Files, POL US–USSR`) and one the clause runs on from (`POL 23–8 LEB and
/// telegram 3451 from Beirut`). They are `SourceNoteParser.decimalClassLocation`'s residue, which
/// no admission rule can reach.
///
/// Version history:
///   1.0 — 2026-11-26 (L26): decision 191
@Suite("Subject-numeric files in footnotes (decision 191)")
struct SubjectNumericFootnoteTests {

    /// The shipped chain. Its schedule composes nothing, which the subject-numeric half never asks.
    private static let verdict = FootnoteIbidGapWalker.shippedAdmissionVerdict { _ in false }

    /// The class candidate a note's first clause yields.
    private func candidate(_ note: String) throws -> FootnoteClassCandidate {
        try #require(FootnoteCitationScanner.classCandidates(inNote: note).first,
                     "no class candidate in “\(note)”")
    }

    /// Walks one document's footnotes with the shipped chain and returns every observation.
    private func walk(_ notes: [String], sourceNote: String? = nil) -> [FootnoteIbidGapWalker.Observation] {
        var walker = FootnoteIbidGapWalker(admissionVerdict: Self.verdict)
        if let sourceNote {
            walker.beginDocument(sourceNote: SourceNoteParser().parse(sourceNote), note: sourceNote)
        } else {
            walker.beginDocument()
        }
        return notes.flatMap { walker.scan(note: $0).observations }
    }

    /// The keys of the observations that inherit a repository.
    private func inheritedRepositories(_ observations: [FootnoteIbidGapWalker.Observation]) -> [String] {
        observations.compactMap {
            if case let .inheritsRepository(key, _) = $0.outcome { return key }
            return nil
        }
    }

    // MARK: The direct citation

    @Test("A designator the clause places in the Central Files is admitted", arguments: [
        "Department of State, Central Files, POL 27 VIET S.",
        "Ibid., RG 59, Central Files 1970–73, POL 27 CAMB.",
        "A copy is in National Archives and Records Administration, RG 59, Central Files 1967–69, DEF 12–5 PAK.",
        "Department of State, Central Files, POL 15–1 NIGERIA.",
        // An organization's file, which the source-note grammar reads beside the categories.
        "Department of State, Central Files, NATO 3 FR.",
        "National Archives, RG 59, Central Files 1970–73, UN 6 CHICOM.",
    ])
    func centralFilesDesignatorIsAdmitted(note: String) throws {
        let found = try candidate(note)
        #expect(found.isSubjectNumeric, "“\(found.classKey)” was read as a decimal number")
        #expect(Self.verdict(found) == nil, """
            “\(note)” names the Central Files and a lead the source notes read, and was refused as \
            \(Self.verdict(found) ?? "-")
            """)
    }

    @Test("Each refusal has its reason", arguments: [
        // No repository of its own: an `Ibid.` that is not first after the Central Files is no citation.
        ("Ibid., POL 27 VIET S.", "subjectNumeric"),
        ("National Archives, RG 59, Central Foreign Policy Files, POL 7 US.", "subjectNumericForeignPolicyFile"),
        // `PR` is a handbook category and a White House subject code alike: only the White House
        // rule refuses it.
        ("The memorandum is in the Johnson Library, White House Central Files, PR 8–1.",
         "subjectNumericWhiteHouse"),
        ("Department of State, Central Files, NCO 10 UN.", "subjectNumericOutOfVocabulary"),
    ])
    func refusalsCarryTheirReason(note: String, reason: String) throws {
        let found = try candidate(note)
        #expect(found.isSubjectNumeric, "“\(found.classKey)” was read as a decimal number")
        #expect(Self.verdict(found) == reason)
        #expect(FootnoteIbidGapWalker.subjectNumericVerdict(found) == reason,
                "the shipped chain must give the subject-numeric half's own answer")
    }

    // MARK: The `Ibid.` naming a file of its own

    @Test("An Ibid. naming a file after a Central Files citation inherits the repository")
    func ibidAfterACentralFilesCitationInheritsTheRepository() throws {
        let observations = walk(["Department of State, Central Files, POL 27 VIET S.",
                                 "Ibid., POL 15 VIET S."])
        let observation = try #require(observations.first)
        guard case let .inheritsRepository(key, distance) = observation.outcome else {
            Issue.record("expected the repository inherited, got \(observation.outcome)")
            return
        }
        #expect(CollectionKeying.isSubjectNumericClass(key))
        #expect(key.hasPrefix("POL 15"), "the file is the Ibid.'s own, not its referent's: \(key)")
        #expect(distance == 1)
        #expect(observation.armingClause.contains("POL 27 VIET S"))
    }

    @Test("First in the document, the source note's Central Files are the referent")
    func firstIbidInheritsTheSourceNotesCentralFiles() throws {
        let observations = walk(
            ["Ibid., POL 15 VIET S."],
            sourceNote: "Source: National Archives, RG 59, Central Files 1964–66, POL 27 VIET S. Secret.")
        let observation = try #require(observations.first)
        guard case let .inheritsRepository(key, distance) = observation.outcome else {
            Issue.record("expected the repository inherited, got \(observation.outcome)")
            return
        }
        #expect(key.hasPrefix("POL 15"))
        #expect(distance == nil, "a source note is no footnote, so there is no distance to give")
    }

    @Test("After a lot, or out of reach, an Ibid. naming a file inherits nothing")
    func otherReferentsGiveNothing() {
        #expect(inheritedRepositories(walk(["Department of State, S/S Files: Lot 66 D 95.",
                                            "Ibid., POL 15 VIET S."])).isEmpty,
                "the referent is a lot, which is no Central Files")
        #expect(inheritedRepositories(walk(
            ["Department of State, S/S Files: Lot 66 D 95.", "Ibid., POL 15 VIET S."],
            sourceNote: "Source: National Archives, RG 59, Central Files 1964–66, POL 27 VIET S. Secret."
        )).isEmpty, "the source note seeds only the first citation in the document")
        #expect(inheritedRepositories(walk(["Department of State, Central Files, POL 27 VIET S.",
                                            "Not printed.", "Not printed.", "Not printed.",
                                            "Ibid., POL 15 VIET S."])).isEmpty,
                "four notes back is beyond the reach a bare Ibid. has")
        #expect(inheritedRepositories(walk(
            ["Ibid., POL 15 VIET S."],
            sourceNote: "Source: Department of State, S/S Files: Lot 66 D 95. Secret.")).isEmpty,
                "a source note citing a lot is no Central Files")
        // A publication clears the referent, as it does for a bare Ibid.; what follows it cites the
        // publication, and the source note, which seeds only the first citation, is no referent.
        #expect(inheritedRepositories(walk(
            ["Department of State, Central Files, POL 27 VIET S.",
             "See Foreign Relations, 1914, Supplement, p. 22.",
             "Ibid., POL 15 VIET S."],
            sourceNote: "Source: National Archives, RG 59, Central Files 1964–66, POL 27 VIET S. Secret."
        )).isEmpty, "after a publication, the Ibid. is the publication's")
    }

    @Test("The inherited file is the referent of a bare Ibid. after it")
    func inheritedFileArmsTheWalker() throws {
        let observations = walk(["Department of State, Central Files, POL 27 VIET S.",
                                 "Ibid., POL 15 VIET S.",
                                 "Ibid."])
        let last = try #require(observations.last)
        guard case let .inheritsAdmittedClass(key, distance, _) = last.outcome else {
            Issue.record("expected the bare Ibid. to inherit the class, got \(last.outcome)")
            return
        }
        #expect(key.hasPrefix("POL 15"))
        #expect(distance == 1)
    }

    @Test("A bare Ibid. first in the document still inherits nothing from the source note")
    func bareIbidIsNeverSeeded() throws {
        let observations = walk(
            ["Ibid."],
            sourceNote: "Source: National Archives, RG 59, Central Files 1964–66, POL 27 VIET S. Secret.")
        let observation = try #require(observations.first)
        #expect(observation.outcome == .noPriorCitation)
    }
}

// MARK: - CentralForeignPolicyFileFootnoteTests (decision 191)

/// The Central Foreign Policy File's anchor in `FootnoteCitationScanner` (decision 191, index
/// version 76): the phrase is the anchor, the film number the file identifier, and an `Ibid.` that
/// names a film number of its own is the same file.
///
/// Version history:
///   1.0 — 2026-11-26 (L26): decision 191
@Suite("The Central Foreign Policy File in footnotes (decision 191)")
struct CentralForeignPolicyFileFootnoteTests {

    /// Scans one document's footnotes and returns each note's citations.
    private func scan(_ notes: [String], sourceNote: ParsedSourceNote? = nil) -> [[FootnoteArchivalCitation]] {
        var scanner = FootnoteCitationScanner()
        scanner.beginDocument(sourceNote: sourceNote)
        return notes.map { scanner.scan(note: $0) }
    }

    /// The film number a citation carries, or `nil`; fails the test for any other kind.
    private func film(_ citation: FootnoteArchivalCitation?) -> String?? {
        guard let citation, citation.anchor == .centralForeignPolicyFile,
              case let .cfpfFile(identifier) = citation.parsed else { return .none }
        return .some(identifier)
    }

    @Test("The phrase is the anchor, and the film number the file", arguments: [
        ("National Archives, RG 59, Central Foreign Policy File, D780382–0612.", "D780382–0612"),
        ("Department of State, Central Foreign Policy File, Electronic Telegrams, N840012–0534.", "N840012–0534"),
        ("National Archives, RG 59, Central Foreign Policy File, P850056–2302.", "P850056–2302"),
        ("National Archives, RG 59, Central Foreign Policy File, D770352-1148.", "D770352-1148"),
    ])
    func phraseAnchorsAndFilmIdentifies(note: String, expected: String) throws {
        let citations = scan([note])[0]
        #expect(citations.count == 1)
        let citation = try #require(citations.first)
        #expect(film(citation) == .some(expected))
        #expect(!citation.inherited)
    }

    @Test("A citation that prints no film number is still the file")
    func noFilmNumberIsStillTheFile() throws {
        let citation = try #require(scan(
            ["National Archives, RG 59, Central Foreign Policy File, [no film number]."])[0].first)
        #expect(film(citation) == .some(nil))
    }

    @Test("An Ibid. naming a film number after the file is the file, with its own telegram")
    func ibidWithAFilmNumberInheritsTheFile() throws {
        let notes = scan(["National Archives, RG 59, Central Foreign Policy File, D780382–0612.",
                          "Ibid., D780383–0190."])
        let citation = try #require(notes[1].first)
        #expect(film(citation) == .some("D780383–0190"))
        #expect(citation.inherited)
    }

    @Test("A bare Ibid. after the file is the same telegram")
    func bareIbidKeepsTheFilm() throws {
        let notes = scan(["National Archives, RG 59, Central Foreign Policy File, D780382–0612.",
                          "Ibid."])
        let citation = try #require(notes[1].first)
        #expect(film(citation) == .some("D780382–0612"))
        #expect(citation.inherited)
    }

    @Test("First in the document, a source note citing the file is the referent of a film number")
    func sourceNoteSeedsAnIbidThatNamesAFilmNumber() throws {
        let notes = scan(["Ibid., D780382–0612."], sourceNote: .cfpfFile(fileIdentifier: "D780001–0001"))
        let citation = try #require(notes[0].first)
        #expect(film(citation) == .some("D780382–0612"))
        #expect(citation.inherited)
    }

    @Test("A source note seeds nothing else", arguments: [
        // A bare Ibid. first in the document: refusal 4 stands.
        ["Ibid."],
        // Once a lot is cited, an Ibid. refers to it, and a film number is no part of a lot.
        ["Department of State, S/S Files: Lot 66 D 95.", "Ibid., D780382–0612."],
        // A publication clears the referent, and the source note seeds only the first citation.
        ["National Archives, RG 59, Central Foreign Policy File, D780382–0612.",
         "See Foreign Relations, 1914, Supplement, p. 22.", "Ibid., D780383–0190."],
    ])
    func sourceNoteSeedsNothingElse(notes: [String]) throws {
        let scanned = scan(notes, sourceNote: .cfpfFile(fileIdentifier: "D780001–0001"))
        let last = try #require(scanned.last)
        #expect(last.allSatisfy { $0.anchor != .centralForeignPolicyFile }, "\(last)")
    }

    @Test("Without the file in reach or in the source note, an Ibid. naming a film number is nothing")
    func filmNumberAloneIsNotACitation() {
        #expect(scan(["Ibid., D780382–0612."]).flatMap { $0 }.isEmpty)
        #expect(scan(["Ibid., D780382–0612."],
                     sourceNote: .lotFile(recordGroup: nil, lotNumber: "66 D 95", fileIdentifier: nil))
            .flatMap { $0 }.isEmpty)
    }
}
