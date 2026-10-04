// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
// For the `NavigationPath` overload of `DocumentJump.apply` below: one reader host
// (CitationLookupView) keeps a NavigationPath rather than an array, and leaving it as the single
// hand-written copy of the rule is what let the rule go untested in the first place.
import SwiftUI

// MARK: - DocumentJump, NavigationPath

/// The SwiftUI half of `DocumentJump` (FRUSCoreKit's `VolumeStructure.swift`), which the kit cannot
/// compile.
///
/// Version history:
///   1.0 — FRUSCoreKit, part 1: moved from `VolumeStructure.swift`
extension DocumentJump {

    /// The `NavigationPath` overload, for a host that keeps an opaque path rather than an array.
    ///
    /// `DocumentBrowserEntry` is `Hashable` and NOT `Codable`, so this resolves to the same
    /// `append` overload the hand-written call did — a path that was never codable stays
    /// non-codable, and no state-restoration behaviour changes.
    public func apply(to path: inout NavigationPath, appending entry: some Hashable) {
        if self == .replace, !path.isEmpty {
            path.removeLast()
        }
        path.append(entry)
    }
}
