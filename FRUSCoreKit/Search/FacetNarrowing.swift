// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - FacetNarrowing

/// How a facet row narrows the search — and, for one section, that it cannot.
///
/// ## Four of six narrow through fields that already exist
/// The design's requirement is that a facet click applies through the **existing**
/// `SearchSQLFilters` fields, so facets and the filter sheet can never disagree. That holds
/// for years (`dateRange`), volumes (`volumeIds`), people (`personRollupId`) and document
/// type (`documentTypeFilter`) — and two of those already read back in the macOS filter row
/// for free, because that row is driven from the same parameters.

/// ## Subjects adds a field, deliberately, and the reason is a hard limit
/// #308's section is the one exception, and it is not a relaxation of the rule so much as a case
/// the rule did not anticipate. The obvious existing-field route is `documentIds`: resolve the
/// bucket to its documents and pass them in. That works up to a point and then stops working —
/// `documentIds` binds one SQL parameter per id, SQLite's `SQLITE_MAX_VARIABLE_NUMBER` is 32,766,
/// and the largest bucket (*Warfare · General*) holds 65,958 documents. The break would show up
/// only on broad searches over big buckets, which is precisely what a facet is for. So
/// `subjectBucket` is a real predicate: one integer, constant cost at any bucket size. The
/// no-disagreement property the rule protects is preserved the same way the others get it — the
/// field lives on `SearchParameters`, so any surface that reads scope reads this too.
///
/// ## Provenance cannot, and pretending otherwise would be the wrong fix
/// `SearchSQLFilters` has no repository, record-group or citation-era field, and the design
/// is explicit that no new filter plumbing should be added here. So the provenance section
/// is **descriptive only**: it tells the researcher how the match is sourced without
/// offering a click that would have to invent a filter dimension. A disabled-looking row
/// that silently does nothing would be worse; the section says why instead.
///
/// Version history:
///   1.0 — R-1b: initial implementation
///   1.1 — FRUS Explorer Light: moved into the kit and public, for the web edition's facets.
///          `apply(to:resources:)` reads the subject vocabulary from the resources a host gives
///          its pipeline; the app's `apply(to:)` passes its bundled ones
public enum FacetNarrowing: Sendable, Equatable {

    /// Restrict to a single year.
    case year(String)
    /// Restrict to a single volume.
    case volume(String)
    /// Restrict to one person rollup. The label rides along (#1092): `rollup_id` is a slot
    /// number renumbered on every rebuild, so a chip showing the integer names nothing — and
    /// the bucket that was tapped already knows the person's display name.
    case person(Int, label: String?)
    /// Restrict to primary documents or editorial notes.
    case documentType(DocumentTypeFilter)
    /// Restrict to documents carrying one `(category, subcategory)` subject bucket (#308).
    case subject(Int)

    /// The narrowing a bucket in `section` represents, or `nil` when that section is
    /// descriptive only.
    public static func forBucket(_ bucket: FacetBucket, in section: FacetSection) -> FacetNarrowing? {
        switch section {
        case .years:
            return .year(bucket.key)
        case .volumes:
            return .volume(bucket.key)
        case .people:
            return Int(bucket.key).map { .person($0, label: bucket.label) }
        case .documentType:
            // The aggregate keys on `is_editorial_note`, so "1" is the notes bucket.
            return .documentType(bucket.key == "1" ? .editorialNotesOnly : .documentsOnly)
        case .subjects:
            return Int(bucket.key).map { .subject($0) }
        case .provenance:
            return nil
        }
    }

    /// Whether a section offers click-to-narrow at all.
    public static func isNarrowable(_ section: FacetSection) -> Bool { section != .provenance }

    /// Applies this narrowing to `parameters`, in place.
    ///
    /// Every case writes a field the filter sheet also owns, which is what makes the two
    /// surfaces incapable of disagreeing.
    ///
    /// - Parameter resources: the data files the host's pipeline reads, whose subject index names
    ///   a subject bucket's durable key; without one, the key is `nil`.
    public func apply(to parameters: inout SearchParameters, resources: IndexingResources) {
        switch self {
        case .year(let year):
            parameters.dateRange = DateRange(earliest: "\(year)-01-01", latest: "\(year)-12-31")
        case .volume(let volumeId):
            parameters.volumeIds = [volumeId]
        case .person(let rollupId, let label):
            parameters.personRollupId = rollupId
            // #1092: the tapped bucket's display name IS the chip's label; without it every
            // person-filter surface falls back to "person #N", a slot number that means
            // nothing and stops being the same person on the next rollup rebuild.
            parameters.personLabel = label
            // A rollup and a single ref are alternative expressions of the same filter;
            // leaving a stale ref set would AND them and silently return fewer documents
            // than the facet promised.
            parameters.personRef = nil
            // Drop any anchor from a previous person: it names someone else, and leaving it would
            // make the next rebind silently re-point this filter back at them. The iOS twin
            // (`SearchViewModel.applyFacetNarrowing`) has always cleared it, with that reason
            // written down; this shared path — the one macOS takes — did not, so
            // `refreshPersonRollupBinding` could re-resolve a facet-chosen person B back to the
            // popover-chosen person A and overwrite both the id and the label. Found while giving
            // the person filter a token, which promotes its label to primary window chrome.
            parameters.personAnchor = nil
        case .documentType(let filter):
            parameters.documentTypeFilter = filter
        case .subject(let bucket):
            parameters.subjectBucket = bucket
            // The durable half. Without it the narrowing is a bare position and cannot survive a
            // data drop — see `SearchParameters.subjectBucketKey`.
            parameters.subjectBucketKey = resources.documentSubjects()?.bucketVocabulary.key(at: bucket)
        }
    }
}
