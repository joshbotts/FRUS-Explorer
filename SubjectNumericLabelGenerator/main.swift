// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SubjectNumericLabelGeneratorCore

do {
    try SubjectNumericLabelRunner.run(environment: ProcessInfo.processInfo.environment)
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}
