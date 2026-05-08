// SubjectTaxonomy.swift
// FRUS Explorer

import Foundation
import Observation

// MARK: - Models

public struct TaxonomySubject: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let kind: String
    public let lcsh: String?
    public let variants: [String]
    public let annotationCount: Int
    public let volumeCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case kind
        case lcsh
        case variants
        case annotationCount = "annotation_count"
        case volumeCount = "volume_count"
    }
}

struct TaxonomySubcategory: Codable, Sendable {
    let label: String
    let annotationCount: Int
    let subjects: [TaxonomySubject]

    enum CodingKeys: String, CodingKey {
        case label
        case annotationCount = "annotation_count"
        case subjects
    }
}

struct TaxonomyCategory: Identifiable, Codable, Sendable {
    let label: String
    let annotationCount: Int
    let subcategories: [TaxonomySubcategory]

    var id: String { label }

    enum CodingKeys: String, CodingKey {
        case label
        case annotationCount = "annotation_count"
        case subcategories
    }
}

// MARK: - Payload

private struct TaxonomyPayload: Decodable {
    let categories: [TaxonomyCategory]
}

// MARK: - Store

@MainActor @Observable
final class TaxonomyStore {

    // MARK: Public State

    private(set) var isLoaded: Bool = false
    private(set) var categories: [TaxonomyCategory] = []
    private(set) var subjectsByID: [String: TaxonomySubject] = [:]

    // MARK: Private State

    /// volumeID → docID → [subjectID]
    private var volumeSubjectMaps: [String: [String: [String]]] = [:]

    // MARK: Loading

    func loadTaxonomy() async {
        guard !isLoaded else { return }

        let result = await Task.detached(priority: .utility) { () -> TaxonomyPayload? in
            guard let url = Bundle.main.url(forResource: "taxonomy", withExtension: "json") else {
                return nil
            }
            do {
                let data = try Data(contentsOf: url)
                return try JSONDecoder().decode(TaxonomyPayload.self, from: data)
            } catch {
                return nil
            }
        }.value

        guard let payload = result else { return }

        var index: [String: TaxonomySubject] = [:]
        for category in payload.categories {
            for subcategory in category.subcategories {
                for subject in subcategory.subjects {
                    index[subject.id] = subject
                }
            }
        }

        self.categories = payload.categories
        self.subjectsByID = index
        self.isLoaded = true
    }

    // MARK: Volume Subject Maps

    func storeVolumeSubjects(_ map: [String: [String]], volumeID: String) {
        volumeSubjectMaps[volumeID] = map
    }

    func removeVolumeSubjects(volumeID: String) {
        volumeSubjectMaps.removeValue(forKey: volumeID)
    }

    // MARK: Querying

    func subjects(for docID: String, in volumeID: String) -> [TaxonomySubject] {
        guard let docMap = volumeSubjectMaps[volumeID],
              let ids = docMap[docID] else { return [] }
        return ids
            .compactMap { subjectsByID[$0] }
            .sorted { $0.name < $1.name }
    }

    func hasSubjects(for docID: String, in volumeID: String) -> Bool {
        guard let docMap = volumeSubjectMaps[volumeID],
              let ids = docMap[docID] else { return false }
        return !ids.isEmpty
    }

    var allSubjectsSorted: [TaxonomySubject] {
        subjectsByID.values.sorted { $0.name < $1.name }
    }

    func subjects(withIDs ids: Set<String>) -> [TaxonomySubject] {
        ids.compactMap { subjectsByID[$0] }.sorted { $0.name < $1.name }
    }
}
