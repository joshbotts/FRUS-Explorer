// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import TaxonomyGeneratorCore

// MARK: - TaxonomyOverlayTests

/// The local overlay the run reads after the Office of the Historian's taxonomy (#1622, decision 39 of
/// the 2026-10-14 plan of record): it adds the tags the Office's sources do not give, and nothing
/// else.
///
/// The committed overlay is read from the repository by path, as `TaxonomyRepositoryFileTests` reads
/// the Office's file; every other overlay here is written in the test.
///
/// Version history:
///   1.0 — #1622, decision 39: initial implementation
@Suite("The local overlay adds the tags the Office's taxonomy does not give (#1622)")
struct TaxonomyOverlayTests {

    /// The committed overlay, `TaxonomyGenerator/volume-tag-taxonomy-overlay.json`.
    static let committed = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent(TaxonomyOverlay.defaultPath)

    private static func tag(_ slug: String, parent: String? = "human-rights", category: String = "topics",
                            reason: String = "A test.") -> TaxonomyOverlay.Tag {
        TaxonomyOverlay.Tag(slug: slug, displayName: slug.capitalized, category: category,
                            subcategory: "human-rights", parentSlug: parent, reason: reason)
    }

    private static func overlayJSON(_ tags: String) -> Data {
        Data("{ \"about\": \"for readers\", \"tags\": [\(tags)] }".utf8)
    }

    /// A fresh output path in a directory of its own, removed by the caller's `defer`.
    private static func scratch() throws -> (directory: URL, path: String) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-taxonomy-overlay-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (directory, directory.appendingPathComponent("volume-tag-taxonomy.json").path)
    }

    // MARK: The committed overlay

    @Test("The committed overlay holds one tag: LGBTQ Rights under Topics, beside HIV/AIDS under Human Rights")
    func theCommittedOverlay() throws {
        let tags = try TaxonomyOverlay.load(from: Self.committed.path)
        #expect(tags.map(\.slug) == ["lgbtq-rights"])
        let tag = try #require(tags.first)
        #expect(tag.displayName == "LGBTQ Rights")
        #expect(tag.category == "topics")
        // Where the Office's file holds it inside a comment: among Human Rights' tags, after HIV/AIDS.
        #expect(tag.subcategory == "human-rights" && tag.parentSlug == "human-rights")
        #expect(tag.reason.contains("decision 39"), "the overlay's tag does not say whose decision it is")
        #expect(tag.fileEntry.description == nil)
    }

    // MARK: Laying it over a source

    @Test("A tag the source lacks is added after the source's entries, which are left as they are")
    func aMissingTagIsAdded() {
        let source = [
            TagTaxonomyFileEntry(slug: "human-rights", displayName: "Human Rights", category: "topics",
                                 subcategory: "human-rights", parentSlug: nil, description: nil),
            TagTaxonomyFileEntry(slug: "hiv-aids", displayName: "HIV/AIDS", category: "topics",
                                 subcategory: "human-rights", parentSlug: "human-rights", description: "As given."),
        ]
        let applied = TaxonomyOverlay.apply([Self.tag("lgbtq-rights")], to: source)
        #expect(applied.added == ["lgbtq-rights"])
        #expect(applied.alreadyInSource.isEmpty)
        #expect(Array(applied.entries.prefix(2)) == source)
        #expect(applied.entries.last == Self.tag("lgbtq-rights").fileEntry)
    }

    @Test("A tag the source gives is left as the source gives it, and said to be no longer needed")
    func aTagTheSourceGivesIsTheSources() {
        let fromTheOffice = TagTaxonomyFileEntry(slug: "lgbtq-rights", displayName: "LGBTQ+ Rights", category: "topics",
                                                 subcategory: "human-rights", parentSlug: "human-rights",
                                                 description: "The Office's own.")
        let applied = TaxonomyOverlay.apply([Self.tag("lgbtq-rights")], to: [fromTheOffice])
        #expect(applied.entries == [fromTheOffice])
        #expect(applied.added.isEmpty)
        #expect(applied.alreadyInSource == ["lgbtq-rights"])
    }

    @Test("A tag whose parent the taxonomy would not hold does not fit, and one whose parent the overlay adds does")
    func aMissingParentDoesNotFit() {
        let source = [TagTaxonomyFileEntry(slug: "asylum", displayName: "Asylum", category: "topics",
                                           subcategory: "asylum", parentSlug: nil, description: nil)]
        let overlay = [Self.tag("lgbtq-rights")]
        let applied = TaxonomyOverlay.apply(overlay, to: source)
        #expect(TaxonomyOverlay.misfit(of: applied, from: overlay)
                == .missingParent(slug: "lgbtq-rights", parentSlug: "human-rights"))
        // A parent the overlay itself adds is held.
        let both = [Self.tag("human-rights", parent: nil), Self.tag("lgbtq-rights")]
        let withParent = TaxonomyOverlay.apply(both, to: source)
        #expect(withParent.added == ["human-rights", "lgbtq-rights"])
        #expect(TaxonomyOverlay.misfit(of: withParent, from: both) == nil)
        // A tag the source gives is not the overlay's to place.
        let given = TaxonomyOverlay.apply([Self.tag("asylum", parent: "nowhere")], to: source)
        #expect(TaxonomyOverlay.misfit(of: given, from: [Self.tag("asylum", parent: "nowhere")]) == nil)
    }

    // MARK: Reading it

    @Test("An overlay that is not one, or holds an incomplete, stray or repeated tag, is refused")
    func aBadOverlayIsRefused() throws {
        let path = "overlay.json"
        let good = """
            { "slug": "lgbtq-rights", "displayName": "LGBTQ Rights", "category": "topics",
              "subcategory": "human-rights", "parentSlug": "human-rights", "reason": "Decision 39." }
            """
        #expect(try TaxonomyOverlay.decode(Self.overlayJSON(good), path: path).map(\.slug) == ["lgbtq-rights"])
        #expect(try TaxonomyOverlay.decode(Self.overlayJSON(""), path: path).isEmpty)

        func problem(_ data: Data) -> TaxonomyOverlay.Problem? {
            do {
                _ = try TaxonomyOverlay.decode(data, path: path)
                return nil
            } catch {
                return error as? TaxonomyOverlay.Problem
            }
        }
        guard case .malformed = problem(Data("[]".utf8)) else {
            Issue.record("a bare list was read as an overlay")
            return
        }
        guard case .malformed = problem(Data("not JSON".utf8)) else {
            Issue.record("text that is not JSON was read as an overlay")
            return
        }
        let noReason = good.replacingOccurrences(of: "\"Decision 39.\"", with: "\" \"")
        #expect(problem(Self.overlayJSON(noReason)) == .incomplete(slug: "lgbtq-rights"))
        let noName = good.replacingOccurrences(of: "\"LGBTQ Rights\"", with: "\"\"")
        #expect(problem(Self.overlayJSON(noName)) == .incomplete(slug: "lgbtq-rights"))
        let stray = good.replacingOccurrences(of: "\"topics\"", with: "\"subjects\"")
        #expect(problem(Self.overlayJSON(stray)) == .unknownCategory(slug: "lgbtq-rights", category: "subjects"))
        #expect(problem(Self.overlayJSON(good + ", " + good)) == .duplicateSlug("lgbtq-rights"))
        #expect(throws: TaxonomyOverlay.Problem.unreadable(path: "/no/such/overlay.json", reason: "no file there")) {
            try TaxonomyOverlay.load(from: "/no/such/overlay.json")
        }
    }

    // MARK: The run

    @Test("The run writes the source and the overlay's tag, and says which tags the overlay added")
    func theRunAddsTheTag() async throws {
        let (directory, path) = try Self.scratch()
        defer { try? FileManager.default.removeItem(at: directory) }
        let overlay = [Self.tag("lgbtq-rights")]
        let result = try await TaxonomyGeneratorRunner.generate(
            from: [.repository], outputPath: path, overlay: overlay) { _ in TaxonomySourceParityTests.file }
        #expect(result.outcome.overlaid == ["lgbtq-rights"])
        #expect(result.outcome.overlayInSource.isEmpty)
        #expect(result.outcome.entries.count == 13)
        let written = try JSONDecoder().decode([TagTaxonomyFileEntry].self,
                                               from: try #require(FileManager.default.contents(atPath: path)))
        #expect(written.first { $0.slug == "lgbtq-rights" } == overlay[0].fileEntry)

        // Run again over what it wrote: nothing is lost or new, and the overlay adds the tag again.
        let again = try TaxonomyGeneratorRunner.generate(fromTaxonomyXML: Data(TaxonomySourceParityTests.file.utf8),
                                                         outputPath: path, overlay: overlay)
        #expect(again.lostSlugs.isEmpty && again.newSlugs.isEmpty && again.overlaid == ["lgbtq-rights"])
    }

    @Test("A source that gives the tag itself is written as it gives it, and the run says the overlay's entry can go")
    func aSourceThatGivesTheTag() async throws {
        let (directory, path) = try Self.scratch()
        defer { try? FileManager.default.removeItem(at: directory) }
        // The parity file with the tag the Office's file keeps inside a comment, out of it.
        let file = TaxonomySourceParityTests.file.replacingOccurrences(
            of: "<tag><id>asylum</id><label>Asylum</label></tag>",
            with: "<tag><id>asylum</id><label>Asylum</label></tag>\n"
                + "<tag><id>lgbtq-rights</id><label>LGBTQ+ Rights</label></tag>")
        let result = try await TaxonomyGeneratorRunner.generate(
            from: [.repository], outputPath: path, overlay: [Self.tag("lgbtq-rights")]) { _ in file }
        #expect(result.outcome.overlaid.isEmpty)
        #expect(result.outcome.overlayInSource == ["lgbtq-rights"])
        let written = try JSONDecoder().decode([TagTaxonomyFileEntry].self,
                                               from: try #require(FileManager.default.contents(atPath: path)))
        #expect(written.first { $0.slug == "lgbtq-rights" }?.displayName == "LGBTQ+ Rights")
    }

    @Test("An overlay never stands for a taxonomy: a source with no tags is refused, and the file left as it was")
    func anOverlayIsNotATaxonomy() async throws {
        let (directory, path) = try Self.scratch()
        defer { try? FileManager.default.removeItem(at: directory) }
        let kept = Data("a taxonomy that must survive".utf8)
        try kept.write(to: URL(fileURLWithPath: path))
        // Well-formed and no category, from both sources: with no file to measure against, the gate's
        // lost-slug rule has nothing to say, so only the source's own emptiness can refuse it.
        try FileManager.default.removeItem(atPath: path)
        do {
            _ = try await TaxonomyGeneratorRunner.generate(
                from: TaxonomySource.automaticOrder, outputPath: path, overlay: [Self.tag("lgbtq-rights", parent: nil)]
            ) { source in source == .repository ? "<taxonomy/>" : "<html></html>" }
            Issue.record("a taxonomy of the overlay's one tag was written")
        } catch let nothing as TaxonomyGeneratorRunner.NothingToWrite {
            #expect(nothing.passedOver.map(\.reason) == [
                TaxonomyRefusal.noEntries.explanation(for: .repository),
                TaxonomyRefusal.noEntries.explanation(for: .page),
            ])
        }
        #expect(FileManager.default.contents(atPath: path) == nil, "something was written")

        // Over a file, too: it stays as it was.
        try kept.write(to: URL(fileURLWithPath: path))
        #expect(throws: TaxonomyRefusal.noEntries) {
            try TaxonomyGeneratorRunner.generate(fromHTML: "<html></html>", outputPath: path,
                                                 overlay: [Self.tag("lgbtq-rights", parent: nil)])
        }
        #expect(FileManager.default.contents(atPath: path) == kept)
    }

    @Test("A source the overlay does not fit is passed over, and with no other the file is left as it was")
    func anOverlayThatDoesNotFit() async throws {
        let (directory, path) = try Self.scratch()
        defer { try? FileManager.default.removeItem(at: directory) }
        let kept = Data("a taxonomy that must survive".utf8)
        try kept.write(to: URL(fileURLWithPath: path))
        let misfit = TaxonomyOverlay.Problem.missingParent(slug: "lgbtq-rights", parentSlug: "nowhere")
        do {
            _ = try await TaxonomyGeneratorRunner.generate(
                from: TaxonomySource.automaticOrder, outputPath: path,
                overlay: [Self.tag("lgbtq-rights", parent: "nowhere")]
            ) { source in source == .repository ? TaxonomySourceParityTests.file : TaxonomySourceParityTests.page }
            Issue.record("a taxonomy the overlay does not fit was written")
        } catch let nothing as TaxonomyGeneratorRunner.NothingToWrite {
            #expect(nothing.passedOver == [.init(source: .repository, reason: misfit.description),
                                           .init(source: .page, reason: misfit.description)])
        }
        #expect(FileManager.default.contents(atPath: path) == kept)
    }

    /// From the review (2026-10-16): the parent check ran before the gate, so a source the gate would refuse threw the
    /// overlay's problem out of the run, blaming the overlay, and the next source was never read.
    @Test("A source the gate refuses is passed over for the gate's reason, though it also lacks the overlay's parent")
    func theGateJudgesTheSourceFirst() async throws {
        let (directory, path) = try Self.scratch()
        defer { try? FileManager.default.removeItem(at: directory) }
        let overlay = [Self.tag("lgbtq-rights")]
        // The file being replaced: the parity taxonomy and the overlay's tag, 13 slugs.
        try TaxonomyGeneratorRunner.generate(fromTaxonomyXML: Data(TaxonomySourceParityTests.file.utf8),
                                             outputPath: path, overlay: overlay)
        // A repository file that has lost its Topics, Human Rights among them: five of the thirteen slugs.
        let withoutTopics = try #require(TaxonomySourceParityTests.file
            .components(separatedBy: "<category><id>topics</id>").first) + "</taxonomy>\n"
        let result = try await TaxonomyGeneratorRunner.generate(
            from: TaxonomySource.automaticOrder, outputPath: path, overlay: overlay
        ) { source in source == .repository ? withoutTopics : TaxonomySourceParityTests.page }
        #expect(result.source == .page)
        let lost = ["asylum", "civil-rights", "civil-rights-foreign", "detainees", "human-rights"]
        #expect(result.passedOver == [.init(source: .repository,
                                            reason: TaxonomyRefusal.slugsLost(lost: lost, existing: 13)
                                                .explanation(for: .repository))])
        #expect(result.outcome.overlaid == ["lgbtq-rights"] && result.outcome.entries.count == 13)
    }
}
