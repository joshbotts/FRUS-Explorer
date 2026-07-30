// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import RecordGroupCatalogGeneratorCore

// Entry point for the record-group catalog harvester. All logic lives in
// RecordGroupCatalogGeneratorCore so it is testable without running the executable.
//
// Harvests NARA's public S3 bulk export — no CATALOG_API_KEY, no quota. Start with
// `PROBE=1`, which fetches one shard per record group and writes the censuses only.
//
// NOTE: the raw NDJSON under CACHE_DIR is not merely scratch, despite living beneath the
// `.cache/` path .gitignore describes as regenerable. It is the resume state for an
// interrupted harvest and the source for `PROJECT_ONLY=1` re-projection; deleting it turns a
// schema correction from a seconds-long offline rebuild back into a full re-download.
//
// See the environment contract on RecordGroupCatalogRunner, and
// Planning/nara-record-group-catalog-runbook.md.

do {
    try await RecordGroupCatalogRunner.run()
} catch {
    FileHandle.standardError.write(Data("[RecordGroupCatalogGenerator] ✗ \(error)\n".utf8))
    exit(1)
}
