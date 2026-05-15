// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

/// TaxonomyGenerator — FRUS Explorer release tool.
///
/// Fetches and parses `history.state.gov/tags/all` to produce
/// `Sources/FRUSExplorer/Resources/volume-tag-taxonomy.json`, which provides
/// humanised display names, categories, and hierarchy for volume-level subject tag slugs.
///
/// Run manually when the history.state.gov tag taxonomy changes:
/// ```
/// swift run TaxonomyGenerator
/// ```
///
/// Full implementation delivered in Session 02.
#if DEBUG
print("[TaxonomyGenerator] Session 02 stub — not yet implemented.")
#else
print("TaxonomyGenerator — run via `swift run TaxonomyGenerator` in DEBUG mode during development.")
#endif
