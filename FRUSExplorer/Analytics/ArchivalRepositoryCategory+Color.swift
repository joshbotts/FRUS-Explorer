// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - ArchivalRepositoryCategory colour

/// The custodians' tints, the app's half of `ArchivalRepositoryCategory`: the kit's enum carries the
/// bucket, its rule and its name, and a `Color` is SwiftUI's, so the tints stay here.
///
/// Version history:
///   1.0 — 2026-11-12 (FRUS Explorer Light, S24c): out of `ArchivalAnalyticsAxes.swift`, unchanged, when
///          that file moved into FRUSCoreKit
extension ArchivalRepositoryCategory {

    /// The design's four sector tints.
    var color: Color {
        switch self {
        case .stateDepartment: return .blue
        case .lotFile: return .teal
        case .presidentialLibrary: return .purple
        case .otherInstitution: return .orange
        }
    }
}
