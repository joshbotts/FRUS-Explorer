// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - SimilarityAxis (the app's)

/// The app's half of ``SimilarityAxis``, whose cases, names and weights are FRUSCoreKit's
/// (`FRUSCoreKit/RelatedDocuments/SimilarityModel.swift`): the SF Symbol each axis is drawn with,
/// which stays here beside the views that draw it, since the semantic axis's is `SemanticGlyph`'s.
///
/// Version history:
///   1.0 — 2026-11-08: FRUS Explorer Light's S23a — moved here unchanged from `SimilarityModel.swift`
extension SimilarityAxis {

    /// An SF Symbol representing the axis in the tuning UI and per-row "why related" chips.
    var systemImage: String {
        switch self {
        case .archivalProvenance: return "archivebox"
        case .crossReference:     return "arrow.triangle.branch"
        case .dateProximity:      return "calendar"
        case .subseries:          return "books.vertical"
        case .sharedPersons:      return "person.2"
        case .sharedSubjects:     return "tag"
        case .semanticSimilarity: return SemanticGlyph.document
        case .lexicalSimilarity:  return "text.magnifyingglass"
        }
    }
}
