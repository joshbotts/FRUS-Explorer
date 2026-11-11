// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// The app's half of `SourceExplorerProvenance` (FRUS Explorer Light, S22b): the lot cards over the app's
// bundled series facts. The rules and the lot cards are FRUSCoreKit's
// (`FRUSCoreKit/SourceExplorer/SourceExplorerProvenance.swift`), given the indexes they read.

extension SourceExplorerProvenance {

    /// ``lotCards(for:note:claimants:centralFiles:curated:seriesFacts:)`` with the app's bundled series facts
    /// (`SeriesFactsIndexStore`), read only for a lot NARA divided, as the divided-lot card read them.
    static func lotCards(for parsed: ParsedSourceNote?, note: String,
                         claimants: LotClaimantsIndex?,
                         centralFiles: CentralFilesIndex?,
                         curated: CuratedLotResolutions?) -> LotCards? {
        lotCards(for: parsed, note: note, claimants: claimants, centralFiles: centralFiles,
                 curated: curated, seriesFacts: SeriesFactsIndexStore.shared)
    }
}
