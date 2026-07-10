// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - VolumeCorpusEnumerator

/// Deterministic enumeration of a local FRUS TEI corpus directory.
///
/// Shared by the corpus-scanning generators (the same
/// `contentsOfDirectory → filter .xml → sort by filename` idiom used across
/// `VolumeSourcesIndexGenerator`, `SourceProvenanceIndexGenerator`, and friends), factored here
/// so the sort order — and therefore every generator's output — stays byte-stable.
public enum VolumeCorpusEnumerator {

    /// Every `*.xml` volume file in `directory`, sorted ascending by filename for deterministic
    /// downstream output.
    ///
    /// - Parameter directory: The corpus directory (e.g. `/Users/.../frus/volumes`).
    /// - Returns: The volume file URLs, filename-sorted.
    /// - Throws: Any error thrown by `FileManager.contentsOfDirectory`.
    public static func volumeFiles(in directory: URL) throws -> [URL] {
        try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "xml" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// The volume id for a volume file: its filename without the `.xml` extension
    /// (e.g. `frus1969-76v01.xml` → `frus1969-76v01`). This id is the stable primary key
    /// across every FRUS data layer.
    ///
    /// - Parameter file: A volume file URL.
    /// - Returns: The volume id.
    public static func volumeId(for file: URL) -> String {
        file.deletingPathExtension().lastPathComponent
    }
}
