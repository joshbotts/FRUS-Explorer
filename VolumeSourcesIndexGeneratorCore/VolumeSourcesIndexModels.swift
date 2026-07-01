// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// The bundled `volume-sources-index.json` artifact: every volume's front-matter Sources
/// section (prose + a nested collection outline with resolved NARA Catalog records), plus a
/// cross-volume authority of the major collections and which volumes cite each.
public struct VolumeSourcesIndex: Codable, Sendable, Equatable {
    public var schemaVersion: Int
    public var generated: String
    /// Per volume, keyed by `volumeId`.
    public var volumes: [String: VolumeSources]
    /// Deduplicated cross-volume authority of named collections.
    public var majorCollections: [MajorCollection]
}

/// One volume's Sources section.
public struct VolumeSources: Codable, Sendable, Equatable {
    /// The narrative "Note on Sources" paragraphs, in order.
    public var prose: [String]
    /// The archival-collection outline (top-level nodes; each may nest `children`).
    public var collections: [CollectionNode]
}

/// A node in a volume's archival-collection outline.
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
