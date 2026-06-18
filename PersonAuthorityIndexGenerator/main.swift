// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import PersonAuthorityIndexGeneratorCore

/// PersonAuthorityIndexGenerator entry point.
///
/// Builds the bundled `person-authority-index.json` from a checkout of the Office of the
/// Historian's public-domain (CC0) `HistoryAtState/people` registry, which reconciles per-volume
/// FRUS person entries to canonical identities (with preferred names, birth/death years, and VIAF
/// ids). The app keys its person rollup on these authoritative ids where available, falling back to
/// heuristic clustering elsewhere. Run from the project root:
/// ```
/// PEOPLE_DATA_DIR=/path/to/people/data \
/// MANIFEST_PATH=FRUSExplorer/Resources/manifest.json \
/// swift run PersonAuthorityIndexGenerator
/// ```
/// Optional: `OUTPUT_PATH` (default `FRUSExplorer/Resources/person-authority-index.json`).
PersonAuthorityIndexRunner.run()
