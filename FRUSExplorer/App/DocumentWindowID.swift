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
struct DocumentWindowID: Codable, Hashable {
    var volumeId: String
    var documentId: String
    /// Placeholder heading shown in the window title bar while the document loads.
    var header: String
}
