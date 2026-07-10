// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ManifestVolume

/// The subset of `manifest.json` the cross-reference validator needs: the shipped-volume identity.
///
/// A deliberately lean decode of the app manifest — `Codable` ignores the entry's other keys
/// (`dateRange`, `editors`, `tags`, …). The manifest defines the **series** set (the volumes the app
/// can navigate to); the local corpus directory is a possible superset (it also holds index and
/// supplement volumes the app does not ship). Keying validation on both sets is what lets the
/// generator tell a genuine dangling volume id (`unknownVolume`, broken) apart from a real target
/// that simply is not shipped (non-shippable / not-in-snapshot, informational).
public struct ManifestVolume: Codable, Sendable, Equatable {
    /// Stable primary key across all data layers (e.g. `frus1969-76v01`).
    public let volumeId: String
    /// The volume's TEI filename (e.g. `frus1969-76v01.xml`).
    public let filename: String
    /// Publication status raw value (`published` / `partiallyPublished` / `planned`).
    public let status: String
}

// MARK: - ManifestLoader

/// Decodes the bundled `manifest.json` (a flat JSON array) into the lean `ManifestVolume` list.
public enum ManifestLoader {

    /// Loads and decodes the manifest array.
    ///
    /// - Parameter url: The `manifest.json` path.
    /// - Returns: The decoded volume entries.
    /// - Throws: A read error, or a decoding error if the shape is not the expected array.
    public static func load(from url: URL) throws -> [ManifestVolume] {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([ManifestVolume].self, from: data)
    }
}
