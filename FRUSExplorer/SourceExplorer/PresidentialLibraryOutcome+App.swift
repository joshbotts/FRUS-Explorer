// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// The app's half of `PresidentialLibraryOutcome` (FRUS Explorer Light, S22a): the resolution against the
// app's bundled catalogue and curated table, through their stores. The outcome, and its resolution over the
// two tables it is given, are FRUSCoreKit's (`FRUSCoreKit/SourceExplorer/PresidentialLibraryOutcome.swift`).

extension PresidentialLibraryOutcome {

    /// ``resolve(repository:collection:note:index:curated:)`` against the app's bundled catalogue
    /// (`PresidentialLibraryIndexStore`) and curated bridge table (`CuratedLibraryResolutionsStore`).
    static func resolve(repository: String, collection: String, note: String) -> PresidentialLibraryOutcome {
        resolve(repository: repository, collection: collection, note: note,
                index: PresidentialLibraryIndexStore.shared,
                curated: CuratedLibraryResolutionsStore.shared)
    }
}
