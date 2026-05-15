// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
@testable import FRUSExplorer

// MARK: - Fixtures

private let sampleTaxonomyEntries: [TagTaxonomyEntry] = [
    TagTaxonomyEntry(slug: "kissinger-henry-a",  displayName: "Kissinger, Henry A.",  category: "people",  subcategory: "national-security-advisors", parentSlug: nil,            description: nil),
    TagTaxonomyEntry(slug: "nixon-richard-m",    displayName: "Nixon, Richard M.",    category: "people",  subcategory: "presidents",                parentSlug: nil,            description: nil),
    TagTaxonomyEntry(slug: "iran",               displayName: "Iran",                 category: "places",  subcategory: "near-east",                 parentSlug: nil,            description: nil),
    TagTaxonomyEntry(slug: "vietnam-war",        displayName: "Vietnam War",          category: "topics",  subcategory: "armed-conflicts",           parentSlug: nil,            description: nil),
    TagTaxonomyEntry(slug: "detente",            displayName: "Détente",              category: "topics",  subcategory: "foreign-policy",            parentSlug: nil,            description: nil),
]

private let sampleManifestEntries: [VolumeManifestEntry] = [
    VolumeManifestEntry(
        volumeId: "frus1969-76v01",
        filename: "frus1969-76v01.xml",
        subseries: "1969-76",
        title: "Foundations of Foreign Policy, 1969–1972",
        dateRange: DateRange(earliest: "1969-01-20", latest: "1972-12-31"),
        publicationDate: "2003",
        status: .published,
        editors: ["David C. Geyer"],
        generalEditor: "Edward C. Keefer",
        documentCount: 340,
        sizeBytes: 5_000_000,
        tags: ["kissinger-henry-a", "nixon-richard-m", "detente"]
    ),
    VolumeManifestEntry(
        volumeId: "frus1969-76v14",
        filename: "frus1969-76v14.xml",
        subseries: "1969-76",
        title: "Soviet Union, October 1971–May 1972",
        dateRange: DateRange(earliest: "1971-10-01", latest: "1972-05-30"),
        publicationDate: "2006",
        status: .published,
        editors: ["David C. Geyer"],
        generalEditor: "Edward C. Keefer",
        documentCount: 280,
        sizeBytes: 4_500_000,
        tags: ["kissinger-henry-a", "detente"]
    ),
    VolumeManifestEntry(
        volumeId: "frus1969-76ve06",
        filename: "frus1969-76ve06.xml",
        subseries: "1969-76",
        title: "Vietnam, January 1969–July 1970",
        dateRange: DateRange(earliest: "1969-01-01", latest: "1970-07-31"),
        publicationDate: "2010",
        status: .published,
        editors: ["Edward C. Keefer"],
        generalEditor: "Edward C. Keefer",
        documentCount: 380,
        sizeBytes: 6_200_000,
        tags: ["vietnam-war", "nixon-richard-m"]
    ),
]

private let sampleSubjectEntries: [SubjectTagEntry] = [
    SubjectTagEntry(subjectId: "kissinger-henry-a", displayName: "Kissinger, Henry A.", category: "people"),
    SubjectTagEntry(subjectId: "vietnam-war",        displayName: "Vietnam War",          category: "topics"),
    SubjectTagEntry(subjectId: "salt-i",             displayName: "SALT I",               category: "topics"),
    SubjectTagEntry(subjectId: "iran",               displayName: "Iran",                 category: "places"),
]

private let sampleAppearances: [SubjectAppearance] = [
    SubjectAppearance(subjectId: "kissinger-henry-a", documentId: "d1", volumeId: "frus1969-76v01", confidence: .curated),
    SubjectAppearance(subjectId: "kissinger-henry-a", documentId: "d2", volumeId: "frus1969-76v01", confidence: .stringMatch),
    SubjectAppearance(subjectId: "vietnam-war",        documentId: "d1", volumeId: "frus1969-76v01", confidence: .stringMatch),
    SubjectAppearance(subjectId: "salt-i",             documentId: "d3", volumeId: "frus1969-76v14", confidence: .curated),
    SubjectAppearance(subjectId: "iran",               documentId: "d4", volumeId: "frus1969-76ve06", confidence: .curated),
]

// MARK: - VolumeLevelTagStore Tests

@Suite("VolumeLevelTagStore — taxonomy loading")
struct TaxonomyLoadTests {

    @MainActor
    @Test("Store initialises with the provided taxonomy entries")
    func storeInitialisesWithEntries() {
        let store = VolumeLevelTagStore(taxonomyEntries: sampleTaxonomyEntries, manifestEntries: [])
        #expect(store.entries.count == 5)
    }

    @MainActor
    @Test("allEntries returns entries sorted: people before places before topics")
    func allEntriesSortedByCategory() {
        let store = VolumeLevelTagStore(taxonomyEntries: sampleTaxonomyEntries, manifestEntries: [])
        let categories = store.allEntries.map(\.category)
        // Categories must be non-decreasing (people ≤ places ≤ topics alphabetically)
        for i in 0..<(categories.count - 1) {
            #expect(categories[i] <= categories[i + 1])
        }
        #expect(categories.first == "people")
        #expect(categories.last == "topics")
    }
}

@Suite("VolumeLevelTagStore — slug resolution")
struct SlugResolutionTests {

    @MainActor
    @Test("Known slug resolves to a VolumeLevelTag with correct fields")
    func knownSlugResolves() {
        let store = VolumeLevelTagStore(taxonomyEntries: sampleTaxonomyEntries, manifestEntries: [])
        let tag = store.resolve(slug: "kissinger-henry-a")
        #expect(tag?.displayName == "Kissinger, Henry A.")
        #expect(tag?.category == .people)
        #expect(tag?.subcategory == "national-security-advisors")
    }

    @MainActor
    @Test("Unknown slug returns nil")
    func unknownSlugReturnsNil() {
        let store = VolumeLevelTagStore(taxonomyEntries: sampleTaxonomyEntries, manifestEntries: [])
        #expect(store.resolve(slug: "unknown-slug") == nil)
    }

    @MainActor
    @Test("resolve(slugs:) skips unknown slugs silently")
    func resolveArraySkipsUnknown() {
        let store = VolumeLevelTagStore(taxonomyEntries: sampleTaxonomyEntries, manifestEntries: [])
        let tags = store.resolve(slugs: ["kissinger-henry-a", "nonexistent", "iran"])
        #expect(tags.count == 2)
        #expect(tags.map(\.slug).contains("kissinger-henry-a"))
        #expect(tags.map(\.slug).contains("iran"))
    }
}

@Suite("VolumeLevelTagStore — volumes by tag")
struct VolumesByTagTests {

    @MainActor
    @Test("Single-tag lookup returns correct volume IDs")
    func singleTagLookup() {
        let store = VolumeLevelTagStore(taxonomyEntries: sampleTaxonomyEntries, manifestEntries: sampleManifestEntries)
        let vols = store.volumes(forTagSlug: "kissinger-henry-a")
        #expect(vols.contains("frus1969-76v01"))
        #expect(vols.contains("frus1969-76v14"))
        #expect(!vols.contains("frus1969-76ve06"))
    }

    @MainActor
    @Test("Unknown tag slug returns empty array")
    func unknownTagReturnsEmpty() {
        let store = VolumeLevelTagStore(taxonomyEntries: sampleTaxonomyEntries, manifestEntries: sampleManifestEntries)
        #expect(store.volumes(forTagSlug: "nonexistent").isEmpty)
    }

    @MainActor
    @Test("Multi-tag AND query returns intersection of results")
    func multiTagIntersection() {
        let store = VolumeLevelTagStore(taxonomyEntries: sampleTaxonomyEntries, manifestEntries: sampleManifestEntries)
        // Both kissinger and detente appear on v01 and v14 — nixon only on v01 and ve06
        let both = store.volumes(forTagSlugs: ["kissinger-henry-a", "nixon-richard-m"])
        #expect(both == ["frus1969-76v01"])
    }

    @MainActor
    @Test("Multi-tag query with empty input returns empty array")
    func emptyTagsReturnsEmpty() {
        let store = VolumeLevelTagStore(taxonomyEntries: sampleTaxonomyEntries, manifestEntries: sampleManifestEntries)
        #expect(store.volumes(forTagSlugs: []).isEmpty)
    }

    @MainActor
    @Test("Multi-tag AND query with no common volumes returns empty array")
    func noCommonVolumesReturnsEmpty() {
        let store = VolumeLevelTagStore(taxonomyEntries: sampleTaxonomyEntries, manifestEntries: sampleManifestEntries)
        // vietnam-war only on ve06; detente only on v01+v14
        let result = store.volumes(forTagSlugs: ["vietnam-war", "detente"])
        #expect(result.isEmpty)
    }
}

@Suite("VolumeLevelTagStore — category and subcategory filters")
struct CategoryFilterTests {

    @MainActor
    @Test("allTags(inCategory:) returns only tags in the requested category")
    func categoryFilter() {
        let store = VolumeLevelTagStore(taxonomyEntries: sampleTaxonomyEntries, manifestEntries: [])
        let people = store.allTags(inCategory: .people)
        #expect(people.allSatisfy { $0.category == .people })
        #expect(people.count == 2)
    }

    @MainActor
    @Test("allTags(inSubcategory:) returns only tags in the requested subcategory")
    func subcategoryFilter() {
        let store = VolumeLevelTagStore(taxonomyEntries: sampleTaxonomyEntries, manifestEntries: [])
        let tags = store.allTags(inSubcategory: "near-east")
        #expect(tags.count == 1)
        #expect(tags.first?.slug == "iran")
    }

    @MainActor
    @Test("allTags() returns the same count as taxonomy entries")
    func allTagsCount() {
        let store = VolumeLevelTagStore(taxonomyEntries: sampleTaxonomyEntries, manifestEntries: [])
        #expect(store.allTags().count == sampleTaxonomyEntries.count)
    }
}

// MARK: - SubjectTagStore Tests

@Suite("SubjectTagStore — bundle load")
struct BundleLoadTests {

    @Test("Testing init builds indexes from provided data")
    func testingInitBuildsIndexes() async {
        let store = SubjectTagStore(entries: sampleSubjectEntries, appearances: sampleAppearances)
        let all = await store.allTags()
        #expect(all.count == sampleSubjectEntries.count)
    }
}

@Suite("SubjectTagStore — document tag lookup")
struct DocumentTagLookupTests {

    @Test("tags(forDocumentId:) returns subjects appearing in that document")
    func documentTagLookup() async {
        let store = SubjectTagStore(entries: sampleSubjectEntries, appearances: sampleAppearances)
        let tags = await store.tags(forDocumentId: "d1")
        #expect(tags.count == 2)
        let ids = Set(tags.map(\.subjectId))
        #expect(ids.contains("kissinger-henry-a"))
        #expect(ids.contains("vietnam-war"))
    }

    @Test("tags(forDocumentId:) for unknown document returns empty array")
    func unknownDocumentReturnsEmpty() async {
        let store = SubjectTagStore(entries: sampleSubjectEntries, appearances: sampleAppearances)
        let tags = await store.tags(forDocumentId: "nonexistent")
        #expect(tags.isEmpty)
    }

    @Test("documents(forSubjectId:) returns all document IDs that carry the subject")
    func documentsBySubject() async {
        let store = SubjectTagStore(entries: sampleSubjectEntries, appearances: sampleAppearances)
        let docs = await store.documents(forSubjectId: "kissinger-henry-a")
        #expect(docs.count == 2)
        #expect(docs.contains("d1"))
        #expect(docs.contains("d2"))
    }
}

@Suite("SubjectTagStore — confidence tier filtering")
struct ConfidenceTierTests {

    @Test("tags(forDocumentId:confidence:curated) returns only curated tags")
    func curatedOnlyFilter() async {
        let store = SubjectTagStore(entries: sampleSubjectEntries, appearances: sampleAppearances)
        // d1 has kissinger(.curated) and vietnam-war(.stringMatch)
        let curated = await store.tags(forDocumentId: "d1", confidence: .curated)
        #expect(curated.count == 1)
        #expect(curated.first?.subjectId == "kissinger-henry-a")
    }

    @Test("tags(forDocumentId:confidence:stringMatch) returns only stringMatch tags")
    func stringMatchOnlyFilter() async {
        let store = SubjectTagStore(entries: sampleSubjectEntries, appearances: sampleAppearances)
        let matched = await store.tags(forDocumentId: "d1", confidence: .stringMatch)
        #expect(matched.count == 1)
        #expect(matched.first?.subjectId == "vietnam-war")
    }

    @Test("documents(forSubjectId:confidence:) filters by confidence tier")
    func documentsConfidenceFilter() async {
        let store = SubjectTagStore(entries: sampleSubjectEntries, appearances: sampleAppearances)
        let curated = await store.documents(forSubjectId: "kissinger-henry-a", confidence: .curated)
        #expect(curated == ["d1"])
        let matched = await store.documents(forSubjectId: "kissinger-henry-a", confidence: .stringMatch)
        #expect(matched == ["d2"])
    }
}

@Suite("SubjectTagStore — category filter")
struct SubjectCategoryFilterTests {

    @Test("allTags(inCategory:) returns only tags in the requested category")
    func subjectCategoryFilter() async {
        let store = SubjectTagStore(entries: sampleSubjectEntries, appearances: sampleAppearances)
        let topics = await store.allTags(inCategory: .topics)
        #expect(topics.allSatisfy { $0.category == .topics })
        // vietnam-war and salt-i are topics
        #expect(topics.count == 2)
    }

    @Test("allTags(inCategory:) for empty category returns empty array")
    func emptyCategoryReturnsEmpty() async {
        // No .people entries in sampleSubjectEntries... wait, kissinger is there.
        let entries = [SubjectTagEntry(subjectId: "vietnam-war", displayName: "Vietnam War", category: "topics")]
        let store = SubjectTagStore(entries: entries, appearances: [])
        let people = await store.allTags(inCategory: .people)
        #expect(people.isEmpty)
    }
}
