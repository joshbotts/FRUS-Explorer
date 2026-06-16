// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import CentralFilesIndexGeneratorCore

/// CentralFilesIndexGenerator entry point.
///
/// Phase 1 harvests the digitized 1906–1910 Numerical File (microfilm M862) from the
/// NARA Catalog and writes a bundled `central-files-index.json` mapping case numbers to
/// rolls. Run from the project root:
/// ```
/// CATALOG_API_KEY=<key> swift run CentralFilesIndexGenerator
/// ```
/// Optional environment variables: OUTPUT_PATH, CACHE_DIR, PAGE_SIZE, REFRESH.
///
/// Phase 2 survey mode — report a diplomatic series' structure (record levels, sample
/// titles, parent linkage, date parseability) to finalize its parsers before building:
/// ```
/// CATALOG_API_KEY=<key> SURVEY_SERIES=603720 swift run CentralFilesIndexGenerator
/// ```
/// Diplomatic series NAIDs: 603720 Despatches · 593313 Instructions ·
/// 594363 Notes from Foreign Missions · 597272 Notes to Foreign Missions.
await CentralFilesIndexGeneratorRunner.run()
