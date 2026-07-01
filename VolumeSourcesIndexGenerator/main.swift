// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import VolumeSourcesIndexGeneratorCore

/// VolumeSourcesIndexGenerator entry point.
///
/// Harvests every locally-downloaded FRUS volume's front-matter Sources section into a
/// bundled `volume-sources-index.json`: per-volume prose + a resolved archival-collection
/// outline, plus a deduplicated cross-volume authority of the major collections. Lot-file
/// citations resolve offline against `central-files-index.json`; record-group / repository
/// headers the bundle can't resolve are reported for a later NARA Catalog API pass.
///
/// Run from the project root:
/// ```
/// swift run VolumeSourcesIndexGenerator
/// ```
/// Optional environment variables: `VOLUMES_DIR`, `CENTRAL_FILES_INDEX`, `OUTPUT`,
/// `GENERATED_DATE`.
do {
    try await VolumeSourcesIndexRunner.run()
} catch {
    FileHandle.standardError.write(Data("VolumeSourcesIndexGenerator error: \(error)\n".utf8))
    exit(1)
}
