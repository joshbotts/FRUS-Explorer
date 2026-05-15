// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

/// ManifestGenerator — FRUS Explorer release tool.
///
/// Fetches the HistoryAtState/frus GitHub repository volume listing, downloads
/// only the `<teiHeader>` portion of each volume XML, and writes
/// `Sources/FRUSExplorer/Resources/manifest.json` with rich metadata for all
/// known FRUS volumes.
///
/// Run before each app release:
/// ```
/// swift run ManifestGenerator
/// ```
///
/// Full implementation delivered in Session 02.
#if DEBUG
print("[ManifestGenerator] Session 02 stub — not yet implemented.")
#else
print("ManifestGenerator — run via `swift run ManifestGenerator` in DEBUG mode during development.")
#endif
