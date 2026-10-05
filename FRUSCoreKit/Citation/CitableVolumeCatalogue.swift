// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CitableVolumeCatalogue

/// The volumes a citation lookup answers for, which `CitationMatchingEngine` reads at each lookup
/// (#1523): the published catalogue's own records of each volume's subseries, numbering and title,
/// and never a volume side-loaded from the reader's own file.
///
/// The app's catalogue is `ManifestStore`, whose `citableEntries` are its bundled entries; its
/// conformance is empty, in the app, beside it. The kit never names `ManifestStore` itself
/// (FRUSCoreKitBoundaryTests): it is the app's `@Observable` store, which reads the app's bundle and
/// the live listing. A host without one, such as FRUS Explorer Light's server or a package test,
/// passes a ``FixedVolumeCatalogue``. The engine's initialisers keep the label `manifestStore:`.
///
/// Version history:
///   1.0 — Session 2026-10-05 (FRUSCoreKit, part 2): initial implementation
public protocol CitableVolumeCatalogue: Sendable {
    /// The volumes a citation may resolve to, in the catalogue's order.
    var citableEntries: [VolumeManifestEntry] { get async }
}

// MARK: - FixedVolumeCatalogue

/// A ``CitableVolumeCatalogue`` that answers the same entries for as long as it lives: a catalogue
/// read once from a `manifest.json`, as `ManifestStore` reads the copy bundled with the app.
///
/// Version history:
///   1.0 — Session 2026-10-05 (FRUSCoreKit, part 2): initial implementation
public struct FixedVolumeCatalogue: CitableVolumeCatalogue {

    /// The volumes a citation may resolve to.
    public let citableEntries: [VolumeManifestEntry]

    /// A catalogue of exactly `entries`.
    public init(entries: [VolumeManifestEntry]) {
        self.citableEntries = entries
    }

    /// The catalogue in the `manifest.json` at `url`, decoded as `ManifestStore` decodes the app's.
    public init(contentsOf url: URL) throws {
        self.citableEntries = try JSONDecoder().decode([VolumeManifestEntry].self, from: Data(contentsOf: url))
    }
}
