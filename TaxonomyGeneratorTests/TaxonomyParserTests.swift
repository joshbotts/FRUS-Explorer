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

/// Tests for `TaxonomyParser`.
///
/// The fixture HTML mirrors the actual `history.state.gov/tags/all` structure:
/// nested `<ul class="hsg-tag-list">` elements at four levels for Places,
/// three levels for People and Topics.
struct TaxonomyParserTests {

    // MARK: - Fixture HTML

    /// Minimal fixture using the actual `hsg-tag-list` nested structure.
    ///
    /// Hierarchy:
    ///   People → Presidents → reagan-ronald, nixon-richard-m
    ///   People → Secretaries of State → kissinger-henry-a
    ///   Places → Sovereign Territories (structural) → Near East → iran, israel
    ///   Topics → Arms Control and Disarmament → arms-control-and-disarmament (leaf)
    ///
    /// Note: `arms-control-and-disarmament` is both the subcategory node (depth 2) and
    /// the only leaf entry in this fixture to exercise the "subcategory = own slug" rule.
    private static let fixtureHTML = """
    <html><body>
    <ul class="hsg-tag-list">
    <li><a href="/tags/people">People</a><ul class="hsg-tag-list">
    <li><a href="/tags/presidents">Presidents</a><ul class="hsg-tag-list">
    <li><a href="/tags/reagan-ronald">Reagan, Ronald</a><span class="hsg-font-italic">40th President of the United States, 1981–1989.</span></li>
    <li><a href="/tags/nixon-richard-m">Nixon, Richard M.</a></li>
    </ul></li>
    <li><a href="/tags/secretaries-of-state">Secretaries of State</a><ul class="hsg-tag-list">
    <li><a href="/tags/kissinger-henry-a">Kissinger, Henry A.</a><span class="hsg-font-italic">Secretary of State, 1973–1977.</span></li>
    </ul></li>
    </ul></li>
    <li><a href="/tags/places">Places</a><ul class="hsg-tag-list">
    <li><a href="/tags/sovereign-territories">Sovereign Territories</a><ul class="hsg-tag-list">
    <li><a href="/tags/near-east">Near East</a><ul class="hsg-tag-list">
    <li><a href="/tags/iran">Iran</a></li>
    <li><a href="/tags/israel">Israel</a><span class="hsg-font-italic">Also referred to as the State of Israel.</span></li>
    </ul></li>
    </ul></li>
    </ul></li>
    <li><a href="/tags/topics">Topics</a><ul class="hsg-tag-list">
    <li><a href="/tags/arms-control-and-disarmament">Arms Control and Disarmament</a><ul class="hsg-tag-list">
    <li><a href="/tags/nuclear-weapons">Nuclear Weapons</a></li>
    </ul></li>
    </ul></li>
    </ul>
    </body></html>
    """

    // MARK: - Tests

    @Test("Parser extracts all three top-level categories")
    func extractsAllCategories() {
        let entries = TaxonomyParser.parse(html: Self.fixtureHTML)
        let categories = Set(entries.map(\.category))
        #expect(categories.contains("people"))
        #expect(categories.contains("places"))
        #expect(categories.contains("topics"))
    }

    @Test("Slug correctly derived from href path segment")
    func slugFromHref() {
        let entries = TaxonomyParser.parse(html: Self.fixtureHTML)
        let slugs = Set(entries.map(\.slug))
        #expect(slugs.contains("reagan-ronald"))
        #expect(slugs.contains("kissinger-henry-a"))
        #expect(slugs.contains("iran"))
        #expect(slugs.contains("arms-control-and-disarmament"))
        #expect(slugs.contains("nuclear-weapons"))
        // Category nodes (people/places/topics) must NOT appear as entries.
        #expect(!slugs.contains("people"))
        #expect(!slugs.contains("places"))
        #expect(!slugs.contains("topics"))
    }

    @Test("Display name extracted from link text")
    func displayNameFromLinkText() {
        let entries = TaxonomyParser.parse(html: Self.fixtureHTML)
        let bySlug = Dictionary(uniqueKeysWithValues: entries.map { ($0.slug, $0) })
        #expect(bySlug["reagan-ronald"]?.displayName == "Reagan, Ronald")
        #expect(bySlug["kissinger-henry-a"]?.displayName == "Kissinger, Henry A.")
        #expect(bySlug["iran"]?.displayName == "Iran")
    }

    @Test("Description extracted where present; nil when absent")
    func descriptionExtraction() {
        let entries = TaxonomyParser.parse(html: Self.fixtureHTML)
        let bySlug = Dictionary(uniqueKeysWithValues: entries.map { ($0.slug, $0) })
        #expect(bySlug["reagan-ronald"]?.description != nil)
        #expect(bySlug["nixon-richard-m"]?.description == nil)
        #expect(bySlug["kissinger-henry-a"]?.description != nil)
        #expect(bySlug["iran"]?.description == nil)
        #expect(bySlug["israel"]?.description != nil)
    }

    @Test("Subcategory assigned correctly at all nesting levels")
    func subcategoryAssignment() {
        let entries = TaxonomyParser.parse(html: Self.fixtureHTML)
        let bySlug = Dictionary(uniqueKeysWithValues: entries.map { ($0.slug, $0) })

        // People depth-2 nodes are their own subcategory.
        #expect(bySlug["presidents"]?.subcategory == "presidents")
        #expect(bySlug["secretaries-of-state"]?.subcategory == "secretaries-of-state")

        // People depth-3 leaves: subcategory = parent (presidents/secretaries-of-state).
        #expect(bySlug["reagan-ronald"]?.subcategory == "presidents")
        #expect(bySlug["kissinger-henry-a"]?.subcategory == "secretaries-of-state")

        // Places: sovereign-territories (structural) is its own subcategory.
        #expect(bySlug["sovereign-territories"]?.subcategory == "sovereign-territories")

        // Places depth-3 entries under a structural node are their own subcategory.
        #expect(bySlug["near-east"]?.subcategory == "near-east")

        // Places depth-4 leaves: subcategory = the regional grouping parent.
        #expect(bySlug["iran"]?.subcategory == "near-east")
        #expect(bySlug["israel"]?.subcategory == "near-east")

        // Topics depth-2 subcategory node is its own subcategory.
        #expect(bySlug["arms-control-and-disarmament"]?.subcategory == "arms-control-and-disarmament")

        // Topics depth-3 leaf: subcategory = parent subcategory.
        #expect(bySlug["nuclear-weapons"]?.subcategory == "arms-control-and-disarmament")
    }

    @Test("Category assigned correctly to all entries")
    func categoryAssignment() {
        let entries = TaxonomyParser.parse(html: Self.fixtureHTML)
        let bySlug = Dictionary(uniqueKeysWithValues: entries.map { ($0.slug, $0) })
        #expect(bySlug["reagan-ronald"]?.category == "people")
        #expect(bySlug["kissinger-henry-a"]?.category == "people")
        #expect(bySlug["iran"]?.category == "places")
        #expect(bySlug["nuclear-weapons"]?.category == "topics")
    }

    @Test("parentSlug nil for depth-2 entries (direct children of category)")
    func parentSlugNilForSubcategoryRoots() {
        let entries = TaxonomyParser.parse(html: Self.fixtureHTML)
        let bySlug = Dictionary(uniqueKeysWithValues: entries.map { ($0.slug, $0) })
        #expect(bySlug["presidents"]?.parentSlug == nil)
        #expect(bySlug["secretaries-of-state"]?.parentSlug == nil)
        #expect(bySlug["sovereign-territories"]?.parentSlug == nil)
        #expect(bySlug["arms-control-and-disarmament"]?.parentSlug == nil)
    }

    @Test("parentSlug set correctly for leaf entries")
    func parentSlugForLeaves() {
        let entries = TaxonomyParser.parse(html: Self.fixtureHTML)
        let bySlug = Dictionary(uniqueKeysWithValues: entries.map { ($0.slug, $0) })
        #expect(bySlug["reagan-ronald"]?.parentSlug == "presidents")
        #expect(bySlug["kissinger-henry-a"]?.parentSlug == "secretaries-of-state")
        #expect(bySlug["iran"]?.parentSlug == "near-east")
        #expect(bySlug["nuclear-weapons"]?.parentSlug == "arms-control-and-disarmament")
    }

    @Test("Correct count of entries parsed from fixture")
    func entryCount() {
        let entries = TaxonomyParser.parse(html: Self.fixtureHTML)
        // Entries: presidents, nixon-richard-m, reagan-ronald,
        //          secretaries-of-state, kissinger-henry-a,
        //          sovereign-territories, near-east, iran, israel,
        //          arms-control-and-disarmament, nuclear-weapons = 11
        #expect(entries.count == 11)
    }

    @Test("TagTaxonomyFileEntry output format round-trips through JSON")
    func outputFormatRoundTrip() throws {
        let entry = RawTaxonomyEntry(
            slug: "kissinger-henry-a",
            displayName: "Kissinger, Henry A.",
            category: "people",
            subcategory: "secretaries-of-state",
            parentSlug: "secretaries-of-state",
            description: "Secretary of State, 1973–1977."
        ).asFileEntry()

        let data = try JSONEncoder().encode([entry])
        let decoded = try JSONDecoder().decode([TagTaxonomyFileEntry].self, from: data)
        #expect(decoded[0].slug == "kissinger-henry-a")
        #expect(decoded[0].displayName == "Kissinger, Henry A.")
        #expect(decoded[0].description == "Secretary of State, 1973–1977.")
        #expect(decoded[0].parentSlug == "secretaries-of-state")
    }
}
