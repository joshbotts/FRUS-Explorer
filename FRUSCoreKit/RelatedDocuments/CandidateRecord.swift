// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CandidateRecord

/// The display fields for one related-document row, carried alongside the key so the list
/// renders (and the row-tap hand-off builds a `DocumentBrowserEntry`) without a re-fetch.
struct CandidateRecord: Sendable, Hashable {
    /// The document header (title). May be empty; the row falls back to the document id.
    let header: String
    /// The human-readable dateline (a display string, e.g. `"Washington, June 3, 1964"`), if any.
    let dateline: String?
    /// The document number within its volume, if any.
    let documentNumber: String?
    /// Whether the document is an editorial note rather than a primary document.
    let isEditorialNote: Bool

    /// Creates a display record.
    init(header: String, dateline: String?, documentNumber: String?, isEditorialNote: Bool) {
        self.header = header
        self.dateline = dateline
        self.documentNumber = documentNumber
        self.isEditorialNote = isEditorialNote
    }
}
