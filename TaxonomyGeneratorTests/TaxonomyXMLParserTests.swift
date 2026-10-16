// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import TaxonomyGeneratorCore

// MARK: - TaxonomyXMLParserTests

/// `TaxonomyXMLParser` over a small file in the shape of `taxonomy/taxonomy.xml` (#1622).
///
/// One fixture, with a case for each thing the parser decides: what is an entry, where an entry
/// sits, what a definition keeps, and how a pointer inside one is written. The four errors have a
/// file each, so that no one of them can stand in for another.
///
/// Version history:
///   1.0 — #1622: initial implementation
@Suite("The taxonomy file's parser (#1622)")
struct TaxonomyXMLParserTests {

    // MARK: - Fixture

    /// People → Presidents → adams-john
    /// Places → Sovereign Territories (structural) → Near East → iran; Places → Other → antarctica
    /// Topics → Human Rights → asylum, detainees, civil-rights → civil-rights-foreign; Topics → warfare
    private static let fixture = """
    <?xml version="1.0" encoding="UTF-8"?>
    <taxonomy>
        <title>A taxonomy</title>
        <description>
            <p>Each entry has an <id>id-in-the-prose</id> and a <label>label in the prose</label>.</p>
        </description>
        <category created-by="someone" created-date="2013-04-08">
            <id>people</id>
            <label>People</label>
            <definition>A root's definition belongs to no entry.</definition>
            <usage-hint>Only for service in office. See <ptr target="warfare"/>.</usage-hint>
            <category>
                <id>presidents</id>
                <label>Presidents</label>
                <definition>Administrations in order. (P) is appended to a
                    President's name where the President also served as Secretary.</definition>
                <tag>
                    <id>adams-john</id>
                    <label>Adams, John</label>
                </tag>
            </category>
        </category>
        <category>
            <id>places</id>
            <label>Places</label>
            <category>
                <id>sovereign-territories</id>
                <label>Sovereign Territories</label>
                <tag>
                    <id>near-east</id>
                    <label>Near East</label>
                    <tag>
                        <id>iran</id>
                        <label>Iran</label>
                    </tag>
                </tag>
            </category>
            <category>
                <id>other</id>
                <label>Other</label>
                <tag>
                    <id>antarctica</id>
                    <label>Antarctica</label>
                </tag>
            </category>
        </category>
        <category>
            <id>topics</id>
            <label>Topics</label>
            <tag>
                <id>human-rights</id>
                <label>Human Rights</label>
                <tag>
                    <id>asylum</id>
                    <label>Asylum</label>
                </tag>
                <tag>
                    <id>detainees</id>
                    <label>Detainees</label>
                    <definition>People held who are not accorded the status of
                        other terms, i.e., <ptr target="asylum" /> or <ptr target="refugees" />
                    </definition>
                    <usage-hint>Not for <ptr target="asylum"/>. A hint may quote an <id>id-in-a-hint</id>,
                        a <label>Label in a hint</label> or a <definition>definition in a hint</definition>.</usage-hint>
                </tag>
                <!--
                <tag>
                    <id>withheld</id>
                    <label>Withheld</label>
                </tag>
                -->
                <tag>
                    <id>civil-rights</id>
                    <label>Civil Rights</label>
                    <tag>
                        <id>civil-rights-foreign</id>
                        <label>Civil Rights: Foreign</label>
                    </tag>
                </tag>
            </tag>
            <tag>
                <id>warfare</id>
                <label>Warfare &amp; Peace</label>
                <definition>   See <a href="http://example.gov/list">the
                    list</a>.   </definition>
            </tag>
        </category>
    </taxonomy>
    """

    private static func parsed() throws -> [RawTaxonomyEntry] {
        try TaxonomyXMLParser.parse(xml: Data(fixture.utf8))
    }

    private static func bySlug() throws -> [String: RawTaxonomyEntry] {
        Dictionary(uniqueKeysWithValues: try parsed().map { ($0.slug, $0) })
    }

    // MARK: - What is an entry

    @Test("Every category and tag below the roots is an entry, in the file's order, and nothing else is")
    func whatIsAnEntry() throws {
        // Not entries: the three roots, the tag inside the comment, and the id and label that
        // sit in the taxonomy's own description. `detainees` keeps its id, its label and its
        // definition though its usage hint quotes one of each after them.
        #expect(try Self.parsed().map(\.slug) == [
            "presidents", "adams-john",
            "sovereign-territories", "near-east", "iran", "other", "antarctica",
            "human-rights", "asylum", "detainees", "civil-rights", "civil-rights-foreign", "warfare",
        ])
    }

    @Test("An entry's category is the root it sits under, at any depth")
    func categoryIsTheRoot() throws {
        let entries = try Self.bySlug()
        #expect(entries["presidents"]?.category == "people")
        #expect(entries["adams-john"]?.category == "people")
        #expect(entries["iran"]?.category == "places")
        #expect(entries["antarctica"]?.category == "places")
        #expect(entries["civil-rights-foreign"]?.category == "topics")
        #expect(entries["warfare"]?.category == "topics")
    }

    // MARK: - Where an entry sits

    @Test("Under a root an entry is its own subcategory and has no parent")
    func underARoot() throws {
        let entries = try Self.bySlug()
        for slug in ["presidents", "sovereign-territories", "other", "human-rights", "warfare"] {
            #expect(entries[slug]?.subcategory == slug, "\(slug)")
            #expect(entries[slug]?.parentSlug == nil, "\(slug)")
        }
    }

    @Test("Under a structural grouping an entry is its own subcategory and keeps the grouping as its parent")
    func underAStructuralGrouping() throws {
        let nearEast = try #require(try Self.bySlug()["near-east"])
        #expect(nearEast.subcategory == "near-east")
        #expect(nearEast.parentSlug == "sovereign-territories")
    }

    @Test("Anywhere else an entry's subcategory and parent are the entry it sits in")
    func underAnEntry() throws {
        let entries = try Self.bySlug()
        // A category that is not structural, a tag, a tag under a structural grouping's tag, and
        // a tag four levels down.
        for (slug, parent) in [("adams-john", "presidents"), ("antarctica", "other"),
                               ("asylum", "human-rights"), ("civil-rights", "human-rights"),
                               ("iran", "near-east"), ("civil-rights-foreign", "civil-rights")] {
            #expect(entries[slug]?.subcategory == parent, "\(slug)")
            #expect(entries[slug]?.parentSlug == parent, "\(slug)")
        }
    }

    // MARK: - What a definition keeps

    @Test("A definition keeps its line breaks and indentation, and loses only its ends")
    func aDefinitionIsKeptAsWritten() throws {
        let entries = try Self.bySlug()
        #expect(entries["presidents"]?.description
                == "Administrations in order. (P) is appended to a\n"
                + "                President's name where the President also served as Secretary.")
        // No definition, and a usage hint alone, are no description.
        #expect(entries["adams-john"]?.description == nil)
        #expect(entries["asylum"]?.description == nil)
        // The roots' definitions went nowhere.
        #expect(try Self.parsed().allSatisfy { $0.description?.contains("root's definition") != true })
    }

    @Test("A pointer in a definition is the page's link to the tag, under the tag's label")
    func aPointerIsALink() throws {
        let entry = try #require(try Self.bySlug()["detainees"])
        #expect(entry.displayName == "Detainees")
        let detainees = try #require(entry.description)
        // `asylum` is in the file, so its label is known. `refugees` is not, and is drawn under
        // its id. The usage hint's pointer is not read.
        #expect(detainees == "People held who are not accorded the status of\n"
                + "                    other terms, i.e., <a href=\"/tags/asylum\">Asylum</a>"
                + " or <a href=\"/tags/refugees\">refugees</a>")
    }

    @Test("A link in a definition keeps its address and its text, and an entity is decoded")
    func aLinkAndAnEntity() throws {
        let warfare = try #require(try Self.bySlug()["warfare"])
        #expect(warfare.displayName == "Warfare & Peace")
        #expect(warfare.description == "See <a href=\"http://example.gov/list\">the\n"
                + "                list</a>.")
    }

    // MARK: - What it will not guess at

    @Test("Text that is not XML is an error that names the line")
    func notXML() {
        #expect(throws: TaxonomyXMLError.self) {
            try TaxonomyXMLParser.parse(xml: Data("<taxonomy><category><id>people</id>".utf8))
        }
        do {
            _ = try TaxonomyXMLParser.parse(xml: Data("<taxonomy>\n<category>\n</taxonomy>".utf8))
            Issue.record("a mismatched tag was parsed")
        } catch let error as TaxonomyXMLError {
            guard case .malformed(let line, _) = error else {
                Issue.record("\(error) is not .malformed")
                return
            }
            #expect(line == 3)
        } catch {
            Issue.record("\(error) is not a TaxonomyXMLError")
        }
    }

    /// A taxonomy of one root and one tag, the tag's `<id>` and `<label>` as given.
    private static func oneTag(id: String?, label: String?, twice: Bool = false) -> Data {
        let tag = "<tag>\(id.map { "<id>\($0)</id>" } ?? "")\(label.map { "<label>\($0)</label>" } ?? "")</tag>"
        return Data("""
            <taxonomy>
            <category><id>topics</id><label>Topics</label>
            \(tag)\(twice ? tag : "")
            </category>
            </taxonomy>
            """.utf8)
    }

    @Test("An entry with no id, or an empty one, is an error that names its line")
    func anEntryWithNoID() {
        #expect(throws: TaxonomyXMLError.missingID(line: 3)) {
            try TaxonomyXMLParser.parse(xml: Self.oneTag(id: nil, label: "Warfare"))
        }
        #expect(throws: TaxonomyXMLError.missingID(line: 3)) {
            try TaxonomyXMLParser.parse(xml: Self.oneTag(id: "  ", label: "Warfare"))
        }
    }

    @Test("An entry with no label, or an empty one, is an error that names it")
    func anEntryWithNoLabel() {
        #expect(throws: TaxonomyXMLError.missingLabel(id: "warfare")) {
            try TaxonomyXMLParser.parse(xml: Self.oneTag(id: "warfare", label: nil))
        }
        #expect(throws: TaxonomyXMLError.missingLabel(id: "warfare")) {
            try TaxonomyXMLParser.parse(xml: Self.oneTag(id: "warfare", label: ""))
        }
    }

    @Test("Two entries with one id are an error, and so is an entry with a root's id")
    func twoEntriesWithOneID() {
        #expect(throws: TaxonomyXMLError.duplicateID("warfare")) {
            try TaxonomyXMLParser.parse(xml: Self.oneTag(id: "warfare", label: "Warfare", twice: true))
        }
        #expect(throws: TaxonomyXMLError.duplicateID("topics")) {
            try TaxonomyXMLParser.parse(xml: Self.oneTag(id: "topics", label: "Topics again"))
        }
        // The control: the same file with one tag parses.
        #expect((try? TaxonomyXMLParser.parse(xml: Self.oneTag(id: "warfare", label: "Warfare")))?.map(\.slug)
                == ["warfare"])
    }

    @Test("Well-formed XML with no category in it is no entries, which the gate refuses")
    func xmlThatIsNotATaxonomy() throws {
        let page = Data("<html><body><p>Not found</p></body></html>".utf8)
        #expect(try TaxonomyXMLParser.parse(xml: page).isEmpty)
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-taxonomy-xml-\(UUID().uuidString).json").path
        #expect(throws: TaxonomyRefusal.noEntries) {
            try TaxonomyGeneratorRunner.generate(fromTaxonomyXML: page, outputPath: path)
        }
        #expect(!FileManager.default.fileExists(atPath: path), "an empty list was written")
    }
}

// MARK: - TaxonomySourceParityTests

/// The same taxonomy, read from the file and from the page drawn from it, is the same entries
/// (#1622).
///
/// The page here is in the site's markup as `TaxonomyParserTests` has it, with each definition
/// printed as the file writes it and each pointer as the link the page draws. The two parsers
/// share one list of structural groupings and nothing else, so this is what holds their placing
/// of an entry together.
///
/// Version history:
///   1.0 — #1622: initial implementation
@Suite("The file and the page give the same taxonomy (#1622)")
struct TaxonomySourceParityTests {

    static let file = """
    <taxonomy>
      <category><id>people</id><label>People</label>
        <category><id>presidents</id><label>Presidents</label>
          <definition>Administrations in
              order.</definition>
          <tag><id>adams-john</id><label>Adams, John</label></tag>
        </category>
      </category>
      <category><id>places</id><label>Places</label>
        <category><id>sovereign-territories</id><label>Sovereign Territories</label>
          <tag><id>near-east</id><label>Near East</label>
            <tag><id>iran</id><label>Iran</label></tag>
          </tag>
        </category>
        <category><id>dependencies-and-areas-of-special-sovereignty</id><label>Dependencies</label>
          <tag><id>guam</id><label>Guam</label></tag>
        </category>
      </category>
      <category><id>topics</id><label>Topics</label>
        <tag><id>human-rights</id><label>Human Rights</label>
          <tag><id>asylum</id><label>Asylum</label></tag>
          <tag><id>detainees</id><label>Detainees</label>
            <definition>Not <ptr target="asylum"/>
            </definition>
          </tag>
          <tag><id>civil-rights</id><label>Civil Rights</label>
            <tag><id>civil-rights-foreign</id><label>Civil Rights: Foreign</label></tag>
          </tag>
        </tag>
      </category>
    </taxonomy>
    """

    static let page = """
    <html><body>
    <ul class="hsg-tag-list">
    <li><a href="/tags/people">People</a><ul class="hsg-tag-list">
    <li><a href="/tags/presidents">Presidents</a><span class="hsg-font-italic">Administrations in
              order.</span><ul class="hsg-tag-list">
    <li><a href="/tags/adams-john">Adams, John</a></li>
    </ul></li>
    </ul></li>
    <li><a href="/tags/places">Places</a><ul class="hsg-tag-list">
    <li><a href="/tags/sovereign-territories">Sovereign Territories</a><ul class="hsg-tag-list">
    <li><a href="/tags/near-east">Near East</a><ul class="hsg-tag-list">
    <li><a href="/tags/iran">Iran</a></li>
    </ul></li>
    </ul></li>
    <li><a href="/tags/dependencies-and-areas-of-special-sovereignty">Dependencies</a><ul class="hsg-tag-list">
    <li><a href="/tags/guam">Guam</a></li>
    </ul></li>
    </ul></li>
    <li><a href="/tags/topics">Topics</a><ul class="hsg-tag-list">
    <li><a href="/tags/human-rights">Human Rights</a><ul class="hsg-tag-list">
    <li><a href="/tags/asylum">Asylum</a></li>
    <li><a href="/tags/detainees">Detainees</a><span class="hsg-font-italic">Not <a href="/tags/asylum">Asylum</a>
            </span></li>
    <li><a href="/tags/civil-rights">Civil Rights</a><ul class="hsg-tag-list">
    <li><a href="/tags/civil-rights-foreign">Civil Rights: Foreign</a></li>
    </ul></li>
    </ul></li>
    </ul></li>
    </ul>
    </body></html>
    """

    @Test("Both parsers give the same entries in the same order")
    func theSameEntries() throws {
        let fromFile = try TaxonomyXMLParser.parse(xml: Data(Self.file.utf8)).map { $0.asFileEntry() }
        let fromPage = TaxonomyParser.parse(html: Self.page).map { $0.asFileEntry() }
        #expect(fromFile.count == 12)
        #expect(fromFile == fromPage)
        // The fixture reaches each placing: under a root, under each structural grouping, under
        // an entry, and four levels down; and a description with a line break and a pointer.
        let bySlug = Dictionary(uniqueKeysWithValues: fromFile.map { ($0.slug, $0) })
        #expect(bySlug["guam"]?.subcategory == "guam")
        #expect(bySlug["guam"]?.parentSlug == "dependencies-and-areas-of-special-sovereignty")
        #expect(bySlug["civil-rights-foreign"]?.parentSlug == "civil-rights")
        #expect(bySlug["detainees"]?.description == "Not <a href=\"/tags/asylum\">Asylum</a>")
        #expect(bySlug["presidents"]?.description == "Administrations in\n          order.")
    }

    @Test("Both sources write the same bytes")
    func theSameBytes() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-taxonomy-parity-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fromFile = directory.appendingPathComponent("file.json").path
        let fromPage = directory.appendingPathComponent("page.json").path
        try TaxonomyGeneratorRunner.generate(fromTaxonomyXML: Data(Self.file.utf8), outputPath: fromFile)
        try TaxonomyGeneratorRunner.generate(fromHTML: Self.page, outputPath: fromPage)
        let bytes = try #require(FileManager.default.contents(atPath: fromFile))
        #expect(bytes.count > 1_000)
        #expect(bytes == FileManager.default.contents(atPath: fromPage))
    }
}

// MARK: - TaxonomyRepositoryFileTests

/// The Office of the Historian's taxonomy file, with the local overlay laid over it, writes the
/// bundled taxonomy byte for byte (#1622).
///
/// `Fixtures/taxonomy.xml` is `taxonomy/taxonomy.xml` of the public HistoryAtState/tags
/// repository at commit `0e701226` (read 2026-10-11; the file's blob is `6fd68631`, 101,303 bytes,
/// last changed upstream on 2025-01-24). The repository's licence places it in the public domain
/// in the United States and under CC0 elsewhere.
///
/// **The copy and the bundled file go together.** A run that changes
/// `FRUSExplorer/Resources/volume-tag-taxonomy.json` fails the first test here until the copy is
/// replaced with the file that run read, in the same commit:
/// `curl -o TaxonomyGeneratorTests/Fixtures/taxonomy.xml` and `TaxonomySource.repository.url`.
/// A change to the parser that fails it has stopped writing the file the app ships.
///
/// **Since decision 39 the bundled file is the Office's taxonomy and the overlay's tags**
/// (`TaxonomyOverlay`, `TaxonomyGenerator/volume-tag-taxonomy-overlay.json`), so it no longer
/// reproduces the Office's file alone byte for byte. What the copy writes alone is the bundled file
/// less exactly the overlay's tags, which the second test holds.
///
/// Version history:
///   1.0 — #1622: initial implementation
///   1.1 — #1622, decision 39: the copy writes the bundled file with the committed overlay laid over
///         it, and alone writes it less exactly the overlay's one tag
@Suite("The repository's taxonomy file writes the bundled taxonomy (#1622)")
struct TaxonomyRepositoryFileTests {

    private static let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("Fixtures/taxonomy.xml")

    private static let bundled = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent(TaxonomyGeneratorRunner.defaultOutputPath)

    @Test("The file and the overlay write the bundled taxonomy byte for byte, over nothing and over itself")
    func theFileWritesTheBundledTaxonomy() throws {
        let xml = try Data(contentsOf: Self.file)
        let shipped = try Data(contentsOf: Self.bundled)
        let overlay = try TaxonomyOverlay.load(from: TaxonomyOverlayTests.committed.path)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-taxonomy-file-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("volume-tag-taxonomy.json").path

        // Over nothing: the whole file comes from the source and the overlay.
        let first = try TaxonomyGeneratorRunner.generate(fromTaxonomyXML: xml, outputPath: path, overlay: overlay)
        // 509 since decision 39: 508 from the copy (2026-10-11) and the overlay's one. A floor, so a
        // cut-off copy is not read as a small taxonomy.
        try #require(first.entries.count > 400, "the copy parses to \(first.entries.count) tags")
        #expect(first.overlaid == ["lgbtq-rights"] && first.overlayInSource.isEmpty)
        #expect(FileManager.default.contents(atPath: path) == shipped, """
            The bundled taxonomy is not what TaxonomyGeneratorTests/Fixtures/taxonomy.xml writes. \
            If volume-tag-taxonomy.json was regenerated, replace the copy with the file that run \
            read, in the same commit. If the parser changed, it no longer writes the file the app ships.
            """)

        // Over the bundled file: nothing is lost or new, and the bytes are the same.
        try shipped.write(to: URL(fileURLWithPath: path))
        let second = try TaxonomyGeneratorRunner.generate(fromTaxonomyXML: xml, outputPath: path, overlay: overlay)
        #expect(second.lostSlugs.isEmpty && second.newSlugs.isEmpty)
        #expect(FileManager.default.contents(atPath: path) == shipped)
    }

    /// Why the bundled file no longer reproduces the Office's alone, and that the overlay is the only
    /// reason: the copy alone writes it less exactly the overlay's tags.
    @Test("The file alone writes the bundled taxonomy less exactly the overlay's tag")
    func theFileAloneIsTheOfficesTaxonomy() throws {
        let xml = try Data(contentsOf: Self.file)
        let shipped = try JSONDecoder().decode([TagTaxonomyFileEntry].self, from: try Data(contentsOf: Self.bundled))
        let overlay = try TaxonomyOverlay.load(from: TaxonomyOverlayTests.committed.path)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-taxonomy-office-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("volume-tag-taxonomy.json").path

        let office = try TaxonomyGeneratorRunner.generate(fromTaxonomyXML: xml, outputPath: path)
        let written = try JSONDecoder().decode([TagTaxonomyFileEntry].self,
                                               from: try #require(FileManager.default.contents(atPath: path)))
        #expect(office.overlaid.isEmpty)
        #expect(!written.contains { $0.slug == "lgbtq-rights" }, "the Office's file now gives lgbtq-rights itself")
        let overlaySlugs = Set(overlay.map(\.slug))
        #expect(written == shipped.filter { !overlaySlugs.contains($0.slug) },
                "the bundled taxonomy differs from the Office's in more than the overlay's tags")
        #expect(shipped.count == written.count + overlay.count)
        #expect(shipped.first { $0.slug == "lgbtq-rights" } == overlay.first?.fileEntry)
    }

    @Test("Every id the file states outside a comment, less its three roots, is an entry")
    func theEntriesAreTheFilesIDs() throws {
        let text = try String(contentsOf: Self.file, encoding: .utf8)
        let entries = try TaxonomyXMLParser.parse(xml: Data(text.utf8))

        // A second reading that shares no code with the parser: the ids in the text, once what
        // sits inside comments is taken out. On 2026-10-11 the file has one comment, with one tag
        // in it, which this reading and the parser both leave out.
        var uncommented = text
        while let open = uncommented.range(of: "<!--"),
              let close = uncommented.range(of: "-->", range: open.upperBound..<uncommented.endIndex) {
            uncommented.removeSubrange(open.lowerBound..<close.upperBound)
        }
        let ids = uncommented.components(separatedBy: "<id>").dropFirst()
            .compactMap { $0.components(separatedBy: "</id>").first }
        #expect(Set(ids).count == ids.count, "the file repeats an id")
        #expect(Set(entries.map(\.slug)) == Set(ids).subtracting(TaxonomyGate.categories))
        #expect(entries.count == ids.count - TaxonomyGate.categories.count)
        #expect(Set(entries.map(\.category)) == TaxonomyGate.categories)
    }
}

// MARK: - TaxonomySourceOrderTests

/// A run reads its sources in order and writes the first the gate accepts (#1622).
///
/// Each test drives `TaxonomyGeneratorRunner.generate(from:outputPath:read:)`, which is the run
/// less its fetch, with the text each source is to give, and reads the file's bytes afterwards.
///
/// Version history:
///   1.0 — #1622: initial implementation
@Suite("A run reads the repository's file, then the page (#1622)")
struct TaxonomySourceOrderTests {

    private struct Unreachable: Error {}

    /// The sources a run asked for, in the order it asked.
    private final class Asked: @unchecked Sendable {
        var sources: [TaxonomySource] = []
    }

    /// Runs `sources` over a fresh output path, each source giving `texts[source]` or failing to
    /// be read when it has none, and returns what the run did, what it asked for and the bytes.
    private func run(_ sources: [TaxonomySource], _ texts: [TaxonomySource: String],
                     over existing: Data? = nil) async throws
        -> (result: Result<TaxonomyGeneratorRunner.SourcedOutcome, any Error>, asked: [TaxonomySource], bytes: Data?) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-taxonomy-order-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("volume-tag-taxonomy.json").path
        if let existing { try existing.write(to: URL(fileURLWithPath: path)) }
        let asked = Asked()
        let result: Result<TaxonomyGeneratorRunner.SourcedOutcome, any Error>
        do {
            result = .success(try await TaxonomyGeneratorRunner.generate(from: sources, outputPath: path) { source in
                asked.sources.append(source)
                guard let text = texts[source] else { throw Unreachable() }
                return text
            })
        } catch {
            result = .failure(error)
        }
        return (result, asked.sources, FileManager.default.contents(atPath: path))
    }

    private static let file = TaxonomySourceParityTests.file
    private static let page = TaxonomySourceParityTests.page
    /// A page of the same shape with one more tag, so its bytes can be told from the file's.
    private static let longerPage = page.replacingOccurrences(
        of: "<li><a href=\"/tags/guam\">Guam</a></li>",
        with: "<li><a href=\"/tags/guam\">Guam</a></li>\n<li><a href=\"/tags/wake-island\">Wake Island</a></li>")

    @Test("The file is read first, and the page is not asked for when the file is written")
    func theFileIsFirst() async throws {
        #expect(TaxonomySource.automaticOrder == [.repository, .page])
        let run = try await run(TaxonomySource.automaticOrder, [.repository: Self.file, .page: Self.longerPage])
        let outcome = try run.result.get()
        #expect(outcome.source == .repository)
        #expect(outcome.passedOver.isEmpty)
        #expect(run.asked == [.repository])
        #expect(outcome.outcome.entries.count == 12)
        let slugs = try JSONDecoder().decode([TagTaxonomyFileEntry].self, from: try #require(run.bytes)).map(\.slug)
        #expect(!slugs.contains("wake-island"), "the page was written")
    }

    @Test("A file that cannot be read is passed over, and the page is written")
    func anUnreachableFile() async throws {
        let run = try await run(TaxonomySource.automaticOrder, [.page: Self.longerPage])
        let outcome = try run.result.get()
        #expect(outcome.source == .page)
        #expect(run.asked == [.repository, .page])
        #expect(outcome.passedOver.map(\.source) == [.repository])
        #expect(outcome.passedOver.first?.reason.hasPrefix("it could not be read (") == true)
        #expect(outcome.outcome.entries.count == 13)
    }

    @Test("A file that is not XML is passed over with the parser's reason")
    func aFileThatIsNotXML() async throws {
        let run = try await run(TaxonomySource.automaticOrder,
                                [.repository: "<taxonomy><category>", .page: Self.page])
        let outcome = try run.result.get()
        #expect(outcome.source == .page)
        #expect(outcome.passedOver.map(\.source) == [.repository])
        #expect(outcome.passedOver.first?.reason.hasPrefix("it is not well-formed XML (line ") == true)
    }

    @Test("A file the gate refuses is passed over with the gate's reason for a file")
    func aFileTheGateRefuses() async throws {
        // A page where the file should be: well-formed, and no category in it.
        let run = try await run(TaxonomySource.automaticOrder,
                                [.repository: "<html><body/></html>", .page: Self.page])
        let outcome = try run.result.get()
        #expect(outcome.source == .page)
        #expect(outcome.passedOver
                == [.init(source: .repository, reason: TaxonomyRefusal.noEntries.explanation(for: .repository))])
        #expect(outcome.passedOver.first?.reason.contains("the repository's file gave no tags") == true)
        // The page's own wording is another sentence.
        #expect(TaxonomyRefusal.noEntries.explanation(for: .page) == TaxonomyRefusal.noEntries.description)
        #expect(TaxonomyRefusal.noEntries.explanation(for: .page).contains("the page gave no tags"))
    }

    @Test("When neither source gives a taxonomy the file is left as it was, with both reasons")
    func neitherSource() async throws {
        let good = Data("a taxonomy that must survive".utf8)
        let run = try await run(TaxonomySource.automaticOrder,
                                [.repository: "<html><body/></html>", .page: "<html></html>"], over: good)
        guard case .failure(let error) = run.result else {
            Issue.record("something was written")
            return
        }
        let nothing = try #require(error as? TaxonomyGeneratorRunner.NothingToWrite)
        #expect(nothing.passedOver == [
            .init(source: .repository, reason: TaxonomyRefusal.noEntries.explanation(for: .repository)),
            .init(source: .page, reason: TaxonomyRefusal.noEntries.explanation(for: .page)),
        ])
        #expect(run.asked == [.repository, .page])
        #expect(run.bytes == good, "the file was rewritten")
    }

    @Test("A run told one source reads that one and stops there")
    func oneSourceNamed() async throws {
        // The page alone, and it gives nothing: the file, which would have been written, is not asked for.
        let pageOnly = try await run([.page], [.repository: Self.file, .page: "<html></html>"])
        guard case .failure(let error) = pageOnly.result else {
            Issue.record("something was written")
            return
        }
        #expect((error as? TaxonomyGeneratorRunner.NothingToWrite)?.passedOver.map(\.source) == [.page])
        #expect(pageOnly.asked == [.page])
        #expect(pageOnly.bytes == nil)

        // The file alone, and it cannot be read: the page is not asked for.
        let fileOnly = try await run([.repository], [.page: Self.page])
        guard case .failure = fileOnly.result else {
            Issue.record("something was written")
            return
        }
        #expect(fileOnly.asked == [.repository])

        // The page alone, and it is good.
        let page = try await run([.page], [.page: Self.page])
        #expect(try page.result.get().source == .page)
    }

    @Test("A refusal for lost slugs names the source the list came from")
    func lostSlugsNameTheirSource() {
        let refusal = TaxonomyRefusal.slugsLost(lost: ["carter"], existing: 4)
        #expect(refusal.explanation(for: .repository).contains("are missing from the repository's file (carter)"))
        #expect(refusal.explanation(for: .page).contains("are missing from the page (carter)"))
        let stray = TaxonomyRefusal.unknownCategory(slug: "x", category: "persons", count: 1)
        #expect(stray.explanation(for: .repository).contains("The file's three roots"))
        #expect(stray.explanation(for: .page).contains("The page's three roots"))
    }

    @Test("TAXONOMY_SOURCE names one source, and nothing else is read as either")
    func theEnvironmentValue() {
        #expect(TaxonomySource.order(named: nil) == [.repository, .page])
        #expect(TaxonomySource.order(named: "") == [.repository, .page])
        #expect(TaxonomySource.order(named: "repository") == [.repository])
        #expect(TaxonomySource.order(named: "page") == [.page])
        #expect(TaxonomySource.order(named: "xml") == nil)
        #expect(TaxonomySource.order(named: "Page") == nil)
        #expect(TaxonomySource.repository.url.hasSuffix("/HistoryAtState/tags/HEAD/taxonomy/taxonomy.xml"))
        #expect(TaxonomySource.page.url == "https://history.state.gov/tags/all")
        #expect(TaxonomyFetcher.taxonomyURL == TaxonomySource.page.url)
    }
}
