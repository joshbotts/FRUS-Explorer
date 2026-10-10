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

/// A run of the taxonomy generator never replaces a good file with a broken list (#1600).
///
/// Each test drives `TaxonomyGeneratorRunner.generate(fromHTML:outputPath:)`, everything a run
/// does after its fetch, over a file in a temporary folder, and reads the file's bytes afterwards:
/// the defect was a write, so the write is what is checked.
///
/// Version history:
///   1.0 — #1600: initial implementation
@Suite("The taxonomy generator refuses to replace a good file with a broken list (#1600)")
struct TaxonomyGateTests {

    // MARK: - Fixtures

    /// A tags page in the site's markup: one root per category, each holding one subcategory whose
    /// leaves are `tags`. `rootSlugs` renames the roots, for a page the parser cannot place.
    private static func page(people: [String] = [], places: [String] = [], topics: [String] = [],
                             rootSlugs: [String] = ["people", "places", "topics"]) -> String {
        func leaves(_ slugs: [String]) -> String {
            slugs.map { "<li><a href=\"/tags/\($0)\">\($0.capitalized)</a></li>" }.joined(separator: "\n")
        }
        return """
        <html><body>
        <ul class="hsg-tag-list">
        <li><a href="/tags/\(rootSlugs[0])">People</a><ul class="hsg-tag-list">
        <li><a href="/tags/presidents">Presidents</a><ul class="hsg-tag-list">
        \(leaves(people))
        </ul></li>
        </ul></li>
        <li><a href="/tags/\(rootSlugs[1])">Places</a><ul class="hsg-tag-list">
        <li><a href="/tags/near-east">Near East</a><ul class="hsg-tag-list">
        \(leaves(places))
        </ul></li>
        </ul></li>
        <li><a href="/tags/\(rootSlugs[2])">Topics</a><ul class="hsg-tag-list">
        <li><a href="/tags/arms-control">Arms Control</a><ul class="hsg-tag-list">
        \(leaves(topics))
        </ul></li>
        </ul></li>
        </ul>
        </body></html>
        """
    }

    /// The page the "good file" of each test is written from: ten slugs, the three subcategories
    /// and seven leaves.
    private static let tenTagPage = page(people: ["nixon", "reagan", "carter"],
                                         places: ["iran", "israel"],
                                         topics: ["test-ban", "salt"])

    /// Runs `body` with the path of a taxonomy file in a folder of its own, written from
    /// ``tenTagPage``, and that file's bytes.
    private func withGoodFile(_ body: (_ path: String, _ bytes: Data) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-taxonomy-gate-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("volume-tag-taxonomy.json").path
        let written = try TaxonomyGeneratorRunner.generate(fromHTML: Self.tenTagPage, outputPath: path)
        try #require(written.entries.count == 10, "fixture: the good page parses to \(written.entries.count) tags")
        try body(path, try #require(FileManager.default.contents(atPath: path)))
    }

    /// The refusal `generate` throws for `html` over the file at `path`, or `nil` when it wrote.
    private func refusal(for html: String, over path: String) throws -> TaxonomyRefusal? {
        do {
            try TaxonomyGeneratorRunner.generate(fromHTML: html, outputPath: path)
            return nil
        } catch let refusal as TaxonomyRefusal {
            return refusal
        }
    }

    // MARK: - The three refusals

    @Test("A page with none of the markup the parser reads leaves the file as it was")
    func aPageWithNoTagsIsRefused() throws {
        try withGoodFile { path, bytes in
            // The site's successor, as the issue found it: the same links, in lists of another class.
            let redesigned = Self.tenTagPage.replacingOccurrences(of: "hsg-tag-list", with: "tag-tree")
            try #expect(refusal(for: redesigned, over: path) == .noEntries)
            #expect(FileManager.default.contents(atPath: path) == bytes, "the file was rewritten")
            try #expect(refusal(for: "", over: path) == .noEntries)
            #expect(FileManager.default.contents(atPath: path) == bytes, "the file was rewritten")
        }
    }

    @Test("A page whose roots are not the three categories leaves the file as it was")
    func aPageWithOtherRootsIsRefused() throws {
        try withGoodFile { path, bytes in
            // Every slug is still there, so only the category rule can refuse this one.
            let renamed = Self.page(people: ["nixon", "reagan", "carter"], places: ["iran", "israel"],
                                    topics: ["test-ban", "salt"],
                                    rootSlugs: ["persons", "places", "topics"])
            try #expect(refusal(for: renamed, over: path)
                    == .unknownCategory(slug: "carter", category: "", count: 4))
            #expect(FileManager.default.contents(atPath: path) == bytes, "the file was rewritten")
        }
    }

    @Test("A page missing more than one in ten of the file's slugs leaves the file as it was")
    func aPageThatLostItsSlugsIsRefused() throws {
        try withGoodFile { path, bytes in
            // Two of ten gone, and two others in their place: the count is the same, so only the
            // slugs can tell.
            let renamed = Self.page(people: ["nixon", "reagan", "ford"], places: ["iran", "egypt"],
                                    topics: ["test-ban", "salt"])
            try #expect(refusal(for: renamed, over: path)
                    == .slugsLost(lost: ["carter", "israel"], existing: 10))
            #expect(FileManager.default.contents(atPath: path) == bytes, "the file was rewritten")
        }
    }

    // MARK: - What is still written

    @Test("A page missing exactly one in ten of the file's slugs is written, and the run names the slug")
    func oneSlugInTenMayGo() throws {
        try withGoodFile { path, bytes in
            let oneGone = Self.page(people: ["nixon", "reagan"], places: ["iran", "israel"],
                                    topics: ["test-ban", "salt", "start"])
            let outcome = try TaxonomyGeneratorRunner.generate(fromHTML: oneGone, outputPath: path)
            #expect(outcome.lostSlugs == ["carter"])
            #expect(outcome.newSlugs == ["start"])
            let now = try #require(FileManager.default.contents(atPath: path))
            #expect(now != bytes, "the file was not rewritten")
            let slugs = try JSONDecoder().decode([TagTaxonomyFileEntry].self, from: now).map(\.slug)
            #expect(slugs.contains("start") && !slugs.contains("carter"), "\(slugs)")
        }
    }

    @Test("The same page over its own file writes the same bytes")
    func anUnchangedPageWritesTheSameBytes() throws {
        try withGoodFile { path, bytes in
            let outcome = try TaxonomyGeneratorRunner.generate(fromHTML: Self.tenTagPage, outputPath: path)
            #expect(outcome.lostSlugs.isEmpty && outcome.newSlugs.isEmpty)
            #expect(FileManager.default.contents(atPath: path) == bytes)
        }
    }

    @Test("With no file, or one that does not decode, there is nothing to measure a loss against")
    func aFirstRunHasNothingToLose() throws {
        try withGoodFile { path, _ in
            let small = Self.page(people: ["ford"])
            try FileManager.default.removeItem(atPath: path)
            try #expect(refusal(for: small, over: path) == nil, "no file")
            try Data("not a taxonomy".utf8).write(to: URL(fileURLWithPath: path))
            try #expect(refusal(for: small, over: path) == nil, "a file that does not decode")
            // The first two rules need no file: an empty parse is refused over nothing as well.
            try FileManager.default.removeItem(atPath: path)
            try #expect(refusal(for: "", over: path) == .noEntries)
            #expect(!FileManager.default.fileExists(atPath: path), "an empty list was written")
        }
    }

    // MARK: - The gate against the bundled file

    @Test("The bundled taxonomy passes its own gate")
    func theBundledTaxonomyPasses() throws {
        let bundled = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(TaxonomyGeneratorRunner.defaultOutputPath)
        let entries = try JSONDecoder().decode([TagTaxonomyFileEntry].self, from: Data(contentsOf: bundled))
        // 508 on 2026-10-09. A floor, so a truncated file is not read as a small taxonomy.
        try #require(entries.count > 400, "the bundled taxonomy holds \(entries.count) tags")
        #expect(TaxonomyGate.refusal(for: entries, replacing: entries) == nil)
        #expect(Set(entries.map(\.category)) == TaxonomyGate.categories)
    }
}
