// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// The app's half of `NARALookupAnalyzer` (FRUS Explorer Light, S22c): the candidates over the app's
// bundled indexes, through their stores, which the kit's `candidates` had as its defaults before it
// moved into FRUSCoreKit (`FRUSCoreKit/SourceExplorer/NARALookupAnalyzer.swift`).

extension NARALookupAnalyzer {

    /// ``candidates(selection:context:centralFiles:volumeSources:claimants:)`` over the app's bundled
    /// central-files, volume-sources and divided-lot claimants indexes (`CentralFilesIndexStore`,
    /// `VolumeSourcesIndexStore`, `LotClaimantsIndexStore`).
    static func candidates(selection: String, context: String?) -> [NARALookupCandidate] {
        candidates(selection: selection, context: context,
                   centralFiles: CentralFilesIndexStore.shared,
                   volumeSources: VolumeSourcesIndexStore.shared,
                   claimants: LotClaimantsIndexStore.shared)
    }
}
