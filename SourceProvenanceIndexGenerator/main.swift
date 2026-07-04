// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SourceProvenanceIndexGeneratorCore

/// SourceProvenanceIndexGenerator entry point (SA-3a).
///
/// Parses every locally downloaded FRUS volume's per-document source notes with the app's
/// real `SourceNoteParser`, maps each to a stable `ProvenanceCategory`, and aggregates the
/// counts by coverage decade into the bundled `source-provenance-index.json` — the offline
/// data prerequisite for the SA-3 "Archival Sourcing Over Time" dashboard.
///
/// Run from the project root:
/// ```
/// swift run SourceProvenanceIndexGenerator
/// ```
/// Optional environment variables: `VOLUMES_DIR`, `MANIFEST`, `OUTPUT`, `GENERATED_DATE`.
do {
    try SourceProvenanceIndexRunner.run()
} catch {
    FileHandle.standardError.write(Data("SourceProvenanceIndexGenerator error: \(error)\n".utf8))
    exit(1)
}
