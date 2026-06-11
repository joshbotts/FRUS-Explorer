// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Typed identifier for iPadOS Stage Manager document windows.
///
/// Passed to `WindowGroup(for: DocumentWindowID.self)` so SwiftUI can
/// open and restore individual document windows on M-chip iPads running
/// Stage Manager. Each value uniquely identifies one document in the corpus.
///
/// `Codable` conformance lets SwiftUI persist and restore window state
/// across scene lifecycle events (backgrounding, system kills, etc.).
///
/// ## Identity
/// Equality and hashing are deliberately keyed on `(volumeId, documentId)` only —
/// `header` is a display placeholder, not part of the document's identity. SwiftUI
/// reuses an existing window when the presented value compares equal, so without
/// this the *same* document opened with a different placeholder header (e.g. from a
/// search result vs. a cross-reference tap, which build entries with different
/// header strings) would wrongly spawn a duplicate window instead of focusing the
/// one already open.
struct DocumentWindowID: Codable, Hashable {
    var volumeId: String
    var documentId: String
    /// Placeholder heading shown in the window title bar while the document loads.
    /// Not part of the value's identity — see the `Equatable`/`Hashable` note above.
    var header: String

    static func == (lhs: DocumentWindowID, rhs: DocumentWindowID) -> Bool {
        lhs.volumeId == rhs.volumeId && lhs.documentId == rhs.documentId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(volumeId)
        hasher.combine(documentId)
    }
}
