// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif

// MARK: - FacetNarrowingTests

/// The facet panel's narrowing map (R-1b): a facet row writes the field the filter sheet writes,
/// or the two surfaces disagree.
///
/// Version history:
///   1.0 — R-1b: initial implementation, in `FacetPanelControllerTests`
///   1.1 — FRUS Explorer Light: a kit suite, beside the narrowing, with the subject bucket's key
///          read from the host's resources
@Suite("Facet narrowing")
struct FacetNarrowingTests {

    /// The data files a test pipeline reads: the app's bundled ones in Xcode, the repository's in
    /// the package.
    private var resources: IndexingResources {
        #if SWIFT_PACKAGE
        testIndexingResources
        #else
        .bundled
        #endif
    }

    @Test("Every narrowable section maps to a field the filter sheet also owns")
    func narrowingWritesSharedFields() {
        var params = SearchParameters(keywords: "containment")

        FacetNarrowing.year("1948").apply(to: &params, resources: .none)
        #expect(params.dateRange?.earliest == "1948-01-01")
        #expect(params.dateRange?.latest == "1948-12-31")

        FacetNarrowing.volume("frus1948v03").apply(to: &params, resources: .none)
        #expect(params.volumeIds == ["frus1948v03"])

        FacetNarrowing.person(77, label: "Acheson, Dean").apply(to: &params, resources: .none)
        #expect(params.personRollupId == 77)
        #expect(params.personLabel == "Acheson, Dean", """
            #1092: the tapped bucket's name must ride into the parameters, or every chip
            reading the person filter falls back to "person #77" — a slot number that is
            renumbered on every rollup rebuild.
            """)

        FacetNarrowing.documentType(.editorialNotesOnly).apply(to: &params, resources: .none)
        #expect(params.documentTypeFilter == .editorialNotesOnly)
    }

    /// A rollup and a single ref are alternative expressions of one filter. Leaving a stale
    /// ref set would AND them and return fewer documents than the facet's own count promised.
    @Test("Narrowing to a person clears any single-ref person filter")
    func personNarrowingClearsTheRef() {
        var params = SearchParameters(keywords: "containment")
        params.personRef = "#p-acheson"
        FacetNarrowing.person(77, label: nil).apply(to: &params, resources: .none)
        #expect(params.personRollupId == 77)
        #expect(params.personRef == nil, "a stale ref would silently AND with the rollup")
    }

    @Test("The document-type bucket key maps to the right half")
    func documentTypeKeyMapping() {
        let notes = FacetBucket(key: "1", label: "Editorial notes", count: 3)
        let documents = FacetBucket(key: "0", label: "Documents", count: 7)
        #expect(FacetNarrowing.forBucket(notes, in: .documentType)
                == .documentType(.editorialNotesOnly))
        #expect(FacetNarrowing.forBucket(documents, in: .documentType)
                == .documentType(.documentsOnly))
    }

    /// `SearchSQLFilters` has no repository, record-group or citation-era field, and the
    /// design forbids adding filter plumbing here. So the section is descriptive, and this
    /// pins that rather than leaving a future reader to discover a dead control.
    @Test("Provenance offers no narrowing, deliberately")
    func provenanceIsDescriptiveOnly() {
        let bucket = FacetBucket(key: "centralDecimalFile", label: "Central Decimal File", count: 12)
        #expect(FacetNarrowing.forBucket(bucket, in: .provenance) == nil)
        #expect(!FacetNarrowing.isNarrowable(.provenance))
        for section in FacetSection.allCases where section != .provenance {
            #expect(FacetNarrowing.isNarrowable(section), "\(section.rawValue) should narrow")
        }
    }

    @Test("A non-numeric person key yields no narrowing rather than a wrong one")
    func malformedPersonKeyIsRefused() {
        let bucket = FacetBucket(key: "not-a-rollup-id", label: "?", count: 1)
        #expect(FacetNarrowing.forBucket(bucket, in: .people) == nil)
    }


    /// A subject bucket's id is a position in the vocabulary, so the narrowing also stores the
    /// durable pair key a saved search restores from, which the host's subject index names.
    @Test("A subject narrowing records the durable key from the host's resources, and none without them")
    func subjectNarrowingReadsTheResources() throws {
        let vocabulary = try #require(resources.documentSubjects()?.bucketVocabulary,
                                      "the test host's resources hold no subject index")
        var params = SearchParameters(keywords: "containment")
        FacetNarrowing.subject(5).apply(to: &params, resources: resources)
        #expect(params.subjectBucket == 5)
        #expect(params.subjectBucketKey != nil)
        #expect(params.subjectBucketKey == vocabulary.key(at: 5))

        var bare = SearchParameters(keywords: "containment")
        FacetNarrowing.subject(5).apply(to: &bare, resources: .none)
        #expect(bare.subjectBucket == 5)
        #expect(bare.subjectBucketKey == nil, "a host without a subject index has no key to record")
    }
}
