// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - PoliticalParty colour

/// The party palette, the app's half of `PoliticalParty`: the kit's enum carries the party and its
/// label, and a `Color` is SwiftUI's, so the colour stays here.
///
/// Version history:
///   1.0 — 2026-11-12 (FRUS Explorer Light, S24b): out of `AdministrationProfilesData.swift`, unchanged,
///          when that file moved into FRUSCoreKit
extension PoliticalParty {

    /// The stable chart color for this party — the `range` half of the party
    /// color scale.
    var color: Color {
        switch self {
        case .republican: return .red
        case .democratic: return .blue
        case .nationalUnion: return .orange
        case .other: return .gray
        }
    }
}
