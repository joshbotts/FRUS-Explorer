// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import CrossRefValidationGeneratorCore

do {
    try CrossRefValidationRunner.run()
} catch {
    FileHandle.standardError.write(Data("CrossRefValidationGenerator failed: \(error)\n".utf8))
    exit(1)
}
