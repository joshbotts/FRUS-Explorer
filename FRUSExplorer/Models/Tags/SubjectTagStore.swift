// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Loads the bundled document-level subject taxonomy and appearance records.
///
/// `SubjectTagStore` is the data source for document-level subject filtering. It decodes
/// `taxonomy.json` (subject definitions) and `subject-appearances.json` (per-document
/// assignments) once at init, then provides fast lookups via in-memory indexes.
///
/// ## Bundle Asset Provenance
/// Both JSON files are generated from the `frus-subject-taxonomy` repository by
/// `scripts/export_app_bundle.py`. The taxonomy is sourced from the Office of the
/// Historian's manually reviewed subject index (1,465 raw terms, 683 after deduplication).
///
/// `subject-appearances.json` applies a `--max-volumes=150` filter: subjects that appear
/// in more than 150 of the ~560 FRUS volumes are too broad to be useful for document-level
/// discovery (e.g. "War", "United States — Foreign policy"). All 683 subjects appear in
/// `taxonomy.json` for browsing; only the 405 most specific have document-level entries.
/// Appearances for included subjects are always `.curated` confidence.
///
/// ## Confidence Tiers
/// Each `SubjectAppearance` carries a `confidence` value: `.curated` (manually verified)
/// or `.stringMatch` (algorithmically assigned, higher false-positive rate). Callers
/// that surface subject tags in the UI should let users toggle the confidence floor.
///
/// ## Missing Bundle Files
/// If either JSON file is absent (e.g. in a fresh checkout before assets are generated),
/// the corresponding index is empty. No crash occurs; query methods return empty arrays.
///
/// ## Thread Safety
/// `SubjectTagStore` is an `actor`. Callers must `await` all method calls.
///
/// Version history:
///   1.0 — Session 08: initial implementation
///   1.1 — Session 35: bundle assets populated from frus-subject-taxonomy export pipeline
public actor SubjectTagStore {

    // MARK: - Indexes

    private let bySubjectId: [String: SubjectTagEntry]
    private let byDocumentId: [String: [SubjectAppearance]]
    private let bySubjectIdAppearances: [String: [SubjectAppearance]]

    // MARK: - Initialization

    /// Production init — loads `taxonomy.json` and `subject-appearances.json` from the main bundle.
    public init() {
        let (entries, appearances) = Self.loadBundledData()
        bySubjectId = Dictionary(uniqueKeysWithValues: entries.map { ($0.subjectId, $0) })
        byDocumentId = Dictionary(grouping: appearances, by: \.documentId)
        bySubjectIdAppearances = Dictionary(grouping: appearances, by: \.subjectId)
    }

    /// Testing init — skips bundle I/O and uses provided data directly.
    init(entries: [SubjectTagEntry], appearances: [SubjectAppearance]) {
        bySubjectId = Dictionary(uniqueKeysWithValues: entries.map { ($0.subjectId, $0) })
        byDocumentId = Dictionary(grouping: appearances, by: \.documentId)
        bySubjectIdAppearances = Dictionary(grouping: appearances, by: \.subjectId)
    }

    // MARK: - Document Queries

    /// Returns all subject tags assigned to the given document.
    public func tags(forDocumentId documentId: String) -> [SubjectTag] {
        resolve(byDocumentId[documentId] ?? [])
    }

    /// Returns subject tags assigned to the given document filtered to the given confidence tier.
    public func tags(forDocumentId documentId: String, confidence: SubjectTagConfidence) -> [SubjectTag] {
        let filtered = (byDocumentId[documentId] ?? []).filter { $0.confidence == confidence }
        return resolve(filtered)
    }

    // MARK: - Subject Queries

    /// Returns the document IDs that have the given subject tag, across all confidence tiers.
    public func documents(forSubjectId subjectId: String) -> [String] {
        (bySubjectIdAppearances[subjectId] ?? []).map(\.documentId)
    }

    /// Returns the document IDs that have the given subject tag at the specified confidence tier.
    public func documents(forSubjectId subjectId: String, confidence: SubjectTagConfidence) -> [String] {
        (bySubjectIdAppearances[subjectId] ?? [])
            .filter { $0.confidence == confidence }
            .map(\.documentId)
    }

    // MARK: - Taxonomy Queries

    /// All resolved subject tags, sorted by display name within category.
    public func allTags() -> [SubjectTag] {
        bySubjectId.values
            .sorted { lhs, rhs in
                if lhs.category != rhs.category { return lhs.category < rhs.category }
                return lhs.displayName < rhs.displayName
            }
            .compactMap { resolve(entry: $0) }
    }

    /// All resolved subject tags in the given category, sorted by display name.
    public func allTags(inCategory category: TagCategory) -> [SubjectTag] {
        allTags().filter { $0.category == category }
    }

    // MARK: - Private

    private func resolve(_ appearances: [SubjectAppearance]) -> [SubjectTag] {
        var seen = Set<String>()
        var result: [SubjectTag] = []
        for appearance in appearances {
            guard !seen.contains(appearance.subjectId),
                  let entry = bySubjectId[appearance.subjectId],
                  let tag = resolve(entry: entry, confidence: appearance.confidence) else { continue }
            seen.insert(appearance.subjectId)
            result.append(tag)
        }
        return result.sorted { $0.displayName < $1.displayName }
    }

    private func resolve(entry: SubjectTagEntry, confidence: SubjectTagConfidence = .curated) -> SubjectTag? {
        guard let category = TagCategory(rawValue: entry.category) else { return nil }
        return SubjectTag(
            subjectId: entry.subjectId,
            displayName: entry.displayName,
            category: category,
            confidence: confidence
        )
    }

    private static func loadBundledData() -> ([SubjectTagEntry], [SubjectAppearance]) {
        let entries = loadJSON([SubjectTagEntry].self, resource: "taxonomy")
        let appearances = loadJSON([SubjectAppearance].self, resource: "subject-appearances")
        return (entries, appearances)
    }

    private static func loadJSON<T: Decodable>(_ type: T.Type, resource: String) -> T where T: ExpressibleByArrayLiteral {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json") else {
            #if DEBUG
            print("[FRUSExplorer] SubjectTagStore: \(resource).json not found in bundle.")
            #endif
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            #if DEBUG
            print("[FRUSExplorer] SubjectTagStore: failed to decode \(resource).json — \(error)")
            #endif
            return []
        }
    }
}
