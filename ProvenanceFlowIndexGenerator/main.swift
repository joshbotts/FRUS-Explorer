// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import ProvenanceFlowIndexGeneratorCore

do {
    // #831 gates its own scope on two measurements. MEASURE=1 runs them and writes NO artifact,
    // so the numbers are in hand before any surface exists.
    if ProcessInfo.processInfo.environment["MEASURE"] == "1" {
        try ProvenanceFlowMeasurement.run()
        exit(0)
    }
    try ProvenanceFlowIndexRunner.run()
} catch {
    FileHandle.standardError.write(Data("ProvenanceFlowIndexGenerator failed: \(error)\n".utf8))
    exit(1)
}
