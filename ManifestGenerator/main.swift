// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import ManifestGeneratorCore

/// ManifestGenerator entry point.
///
/// Run from the project root to regenerate `FRUSExplorer/Resources/manifest.json`:
/// ```
/// swift run ManifestGenerator
/// ```
///
/// Optional environment variables:
///   GITHUB_TOKEN   — GitHub personal access token (recommended; raises rate limit to 5,000/hr)
///   OUTPUT_PATH    — Override the default output path (also the base manifest in overlay mode)
///   VOLUMES_DIR    — Local corpus directory. When set, runs OFFLINE local overlay mode: the
///                    existing manifest at OUTPUT_PATH is the base, and only `publicationDate`
///                    and `dateRange` are re-derived from each `VOLUMES_DIR/<filename>` header.
///                    GitHub is not contacted. Example:
///                    ```
///                    VOLUMES_DIR=/path/to/frus/volumes swift run ManifestGenerator
///                    ```
private let environment = ProcessInfo.processInfo.environment
await ManifestGeneratorRunner.run(
    outputPath: environment["OUTPUT_PATH"] ?? ManifestGeneratorRunner.defaultOutputPath,
    localVolumesDirectory: environment["VOLUMES_DIR"]
)
