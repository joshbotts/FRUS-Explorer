// Collections/DocumentCollection.swift
// Data model for a user-created collection of FRUS documents and editorial notes.
// Collections are persisted as JSON in Application Support.

import Foundation
import Observation
import SwiftUI

// MARK: - CollectionItem

/// A reference to a single document or editorial note inside a loaded FRUS volume.
/// Stored by identity (volumeID + divisionID) so the collection survives across launches
/// as long as the volume is still downloaded.
public struct CollectionItem: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    /// The FRUS volume identifier, e.g. `"frus1969-76v24"`.
    public let volumeID: String
    /// The `@xml:id` of the `<div>` or `<note>` element, e.g. `"d176"`.
    public let divisionID: String
    /// Cached display title (subject heading + number) — shown even when volume is unloaded.
    public let cachedTitle: String
    /// Cached dateline string — shown as subtitle.
    public let cachedDateline: String?
    /// Whether this item is an editorial note rather than a document division.
    public let isEditorialNote: Bool
    /// User-supplied annotation for this item within the collection.
    public var annotation: String

    public init(
        id: UUID = UUID(),
        volumeID: String,
        divisionID: String,
        cachedTitle: String,
        cachedDateline: String? = nil,
        isEditorialNote: Bool = false,
        annotation: String = ""
    ) {
        self.id = id
        self.volumeID = volumeID
        self.divisionID = divisionID
        self.cachedTitle = cachedTitle
        self.cachedDateline = cachedDateline
        self.isEditorialNote = isEditorialNote
        self.annotation = annotation
    }
}

// MARK: - DocumentCollection

/// A named, ordered list of `CollectionItem`s.
public struct DocumentCollection: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var notes: String          // collection-level user notes
    public var items: [CollectionItem]
    public let createdAt: Date
    public var modifiedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        notes: String = "",
        items: [CollectionItem] = [],
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.items = items
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    mutating func touch() { modifiedAt = Date() }
}

// MARK: - CollectionStore

/// Manages persistence and mutation of all `DocumentCollection` values.
/// Lives on `@MainActor` so SwiftUI can observe it directly.
@MainActor
@Observable
final class CollectionStore {

    private(set) var collections: [DocumentCollection] = []

    // MARK: Persistence

    private static let fileName = "collections.json"
    private static var storageURL: URL {
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0]
        return support.appending(component: "FRUSExplorer/\(fileName)")
    }

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init() { load() }

    // MARK: - CRUD

    func create(name: String) -> DocumentCollection {
        let c = DocumentCollection(name: name)
        collections.append(c)
        save()
        return c
    }

    func rename(_ collection: DocumentCollection, to name: String) {
        guard let idx = index(of: collection) else { return }
        collections[idx].name = name
        collections[idx].touch()
        save()
    }

    func delete(_ collection: DocumentCollection) {
        collections.removeAll { $0.id == collection.id }
        save()
    }

    func updateNotes(_ collection: DocumentCollection, notes: String) {
        guard let idx = index(of: collection) else { return }
        collections[idx].notes = notes
        collections[idx].touch()
        save()
    }

    // MARK: - Items

    func addItem(_ item: CollectionItem, to collection: DocumentCollection) {
        guard let idx = index(of: collection) else { return }
        // Prevent duplicates within the same collection
        guard !collections[idx].items.contains(where: {
            $0.volumeID == item.volumeID && $0.divisionID == item.divisionID
        }) else { return }
        collections[idx].items.append(item)
        collections[idx].touch()
        save()
    }

    func removeItem(_ item: CollectionItem, from collection: DocumentCollection) {
        guard let idx = index(of: collection) else { return }
        collections[idx].items.removeAll { $0.id == item.id }
        collections[idx].touch()
        save()
    }

    func moveItems(in collection: DocumentCollection, from source: IndexSet, to destination: Int) {
        guard let idx = index(of: collection) else { return }
        collections[idx].items.move(fromOffsets: source, toOffset: destination)
        collections[idx].touch()
        save()
    }

    func updateAnnotation(
        _ item: CollectionItem,
        in collection: DocumentCollection,
        annotation: String
    ) {
        guard let cidx = index(of: collection),
              let iidx = collections[cidx].items.firstIndex(where: { $0.id == item.id })
        else { return }
        collections[cidx].items[iidx].annotation = annotation
        collections[cidx].touch()
        save()
    }

    /// Resolve a `CollectionItem` to a live `Division` from the loaded volumes cache.
    /// Returns `nil` when the volume is not currently loaded in memory.
    func resolve(
        _ item: CollectionItem,
        in loadedVolumes: [String: LoadedVolume]
    ) -> Division? {
        guard let vol = loadedVolumes[item.volumeID] else { return nil }
        let t = vol.volume.text
        return t.body.divisions.findDivision(id: item.divisionID)
            ?? (t.front?.divisions ?? []).findDivision(id: item.divisionID)
            ?? (t.back?.divisions ?? []).findDivision(id: item.divisionID)
    }

    // MARK: - Persistence helpers

    private func index(of collection: DocumentCollection) -> Int? {
        collections.firstIndex(where: { $0.id == collection.id })
    }

    func save() {
        do {
            let data = try encoder.encode(collections)
            let url = Self.storageURL
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
        } catch {
            print("[CollectionStore] Save failed: \(error)")
        }
    }

    /// Flat dictionary of all non-empty annotations keyed by nodeID ("volumeID__divisionID").
    /// Used by the search engine to include annotation text in full-text queries.
    var allAnnotations: [String: String] {
        var result: [String: String] = [:]
        for col in collections {
            for item in col.items where !item.annotation.isEmpty {
                result["\(item.volumeID)__\(item.divisionID)"] = item.annotation
            }
        }
        return result
    }

    func load() {
        let url = Self.storageURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            collections = try decoder.decode([DocumentCollection].self, from: data)
        } catch {
            print("[CollectionStore] Load failed: \(error)")
        }
    }
}
