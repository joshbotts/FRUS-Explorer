// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CollectionAuthorityGeneratorCore
import Foundation

/// Entry point: runs the collection-authority generation pass and exits non-zero on error.
do {
    try await CollectionAuthorityRunner.run()
} catch {
    FileHandle.standardError.write(Data("ERROR: \(error)\n".utf8))
    exit(1)
}
