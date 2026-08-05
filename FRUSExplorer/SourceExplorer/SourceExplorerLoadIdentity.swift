// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - MacSourceExplorerLoadIdentity

/// The `.task(id:)` key both Source Explorer views use to decide that the document being
/// explained has changed.
///
/// ## The bug it exists to prevent
/// `MacSourceExplorerView` lives inside a persistent `Window`, not a sheet: SwiftUI keeps one
/// view instance alive and swaps its properties as the user opens documents. With a bare
/// `.task`, `load()` ran **once, ever** — so `rawSourceNote`, read directly in `body`,
/// tracked the current document while the parsed lot number, record group, archival
/// collection, NARA query and results all stayed pinned to whichever document was open
/// first. On screen that reads as one document's source note above another document's
/// provenance, which is worse than showing nothing.
///
/// Shared rather than duplicated because the iOS view keys on the same identity, and the two
/// Source Explorer views have drifted before.
///
/// Version history:
///   1.0 — Session 2026-08-04: N-8 stale-state fix
enum MacSourceExplorerLoadIdentity {

    /// A key that changes whenever anything `load()` reads changes.
    ///
    /// Includes the raw note as well as the identifiers because some hosts pass no
    /// `documentId`, and because two documents sharing a note byte-for-byte are, for this
    /// view's purposes, the same citation. Joined on U+001F (unit separator) so a value
    /// containing the delimiter cannot forge a different key.
    static func make(volumeId: String?, documentId: String?,
                     rawSourceNote: String, documentYear: Int?) -> String {
        [volumeId ?? "", documentId ?? "", documentYear.map(String.init) ?? "", rawSourceNote]
            .joined(separator: "\u{1F}")
    }
}
