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
///   OUTPUT_PATH    — Override the default output path
await ManifestGeneratorRunner.run(
    outputPath: ProcessInfo.processInfo.environment["OUTPUT_PATH"]
        ?? ManifestGeneratorRunner.defaultOutputPath
)
