// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import TaxonomyGeneratorCore

/// TaxonomyGenerator entry point.
///
/// Run from the project root whenever the history.state.gov tag taxonomy changes:
/// ```
/// swift run TaxonomyGenerator
/// ```
/// Review the JSON diff before committing — unexpected changes may indicate a page
/// redesign requiring updates to `TaxonomyParser`.
///
/// Optional environment variables:
///   OUTPUT_PATH    — Override the default output path
await TaxonomyGeneratorRunner.run(
    outputPath: ProcessInfo.processInfo.environment["OUTPUT_PATH"]
        ?? TaxonomyGeneratorRunner.defaultOutputPath
)
