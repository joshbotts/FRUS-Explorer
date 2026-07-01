// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// The bundled `volume-sources-index.json` artifact (schema v2): the *resolutions* the app
/// cannot derive on its own — record-group headers and lot-file citations mapped to their
/// NARA Catalog records — plus a cross-volume authority of the major collections and which
/// volumes cite each.
///
/// The per-volume collection trees are deliberately **not** stored: the app already re-parses
/// each volume's Sources section into the `volume_sources` table at index time, so bundling
/// the trees again would duplicate ~10× the data. The app resolves its own parsed nodes by
/// looking them up in `recordGroups` / `lots`.
public struct VolumeSourcesIndex: Codable, Sendable, Equatable {
    public var schemaVersion: Int
    public var generated: String
    /// Record-group headers → their resolved record, keyed by record-group **number** (`"59"`).
    public var recordGroups: [String: ResolvedNAID]
    /// Lot-file citations → their resolved record, keyed by **normalized** lot number
    /// (`BundledLotResolver.normalizeLot`, e.g. `"80D212"`).
    public var lots: [String: ResolvedNAID]
    /// Deduplicated cross-volume authority of named collections.
    public var majorCollections: [MajorCollection]
}

/// A node in a volume's archival-collection outline. Built transiently during generation to
/// gather resolution keys and fold the cross-volume authority; it is **not** serialized.
public struct CollectionNode: Codable, Sendable, Equatable {
    public var text: String
    public var isHeading: Bool
    public var depth: Int
    public var recordGroup: String?
    public var lotFile: String?
    public var repository: String?
    /// The resolved NARA Catalog record, when one was found.
    public var resolved: ResolvedNAID?
    public var children: [CollectionNode]
}

/// A collection that recurs across volumes, deduplicated for the cross-volume authority.
public struct MajorCollection: Codable, Sendable, Equatable {
    /// Stable dedup key (lot-file or normalized text).
    public var key: String
    public var text: String
    public var isHeading: Bool
    public var recordGroup: String?
    public var lotFile: String?
    public var repository: String?
    public var resolved: ResolvedNAID?
    /// Volumes whose Sources section cites this collection, sorted.
    public var volumeIds: [String]
    /// Total number of citing nodes across all volumes (an item may appear once per volume).
    public var occurrences: Int
}
