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
/// Run from the project root whenever the Office of the Historian's tag taxonomy changes:
/// ```
/// swift run TaxonomyGenerator
/// ```
/// It reads `taxonomy/taxonomy.xml` from the public HistoryAtState/tags repository, and the page
/// `history.state.gov/tags/all` when the file gives nothing to write (#1622), then adds the tags of
/// `TaxonomyGenerator/volume-tag-taxonomy-overlay.json` the source does not give (`TaxonomyOverlay`,
/// decision 39). Review the JSON diff before committing. A run in which every source read gave no tags, tags outside the three
/// categories, or a list missing more than one in ten of the file's slugs leaves the file as it
/// was and exits 1 (`TaxonomyGate`, #1600).
///
/// Optional environment variables:
///   OUTPUT_PATH      — Override the default output path
///   TAXONOMY_SOURCE  — `repository` or `page`: read that source and no other
let environment = ProcessInfo.processInfo.environment
guard let sources = TaxonomySource.order(named: environment["TAXONOMY_SOURCE"]) else {
    print("[TaxonomyGenerator] ✗ TAXONOMY_SOURCE is \"\(environment["TAXONOMY_SOURCE"] ?? "")\". "
          + "It names one source, \(TaxonomySource.allCases.map(\.rawValue).joined(separator: " or ")), "
          + "or is left unset to read them in that order.")
    exit(1)
}
await TaxonomyGeneratorRunner.run(
    outputPath: environment["OUTPUT_PATH"] ?? TaxonomyGeneratorRunner.defaultOutputPath,
    sources: sources
)
