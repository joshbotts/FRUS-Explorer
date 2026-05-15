// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - UserTag

/// A user-defined label that can be applied to research notes.
///
/// UserTags are **global** — they are never scoped to a project. A tag like
/// "Primary Source" or "Revisit" means the same thing regardless of which
/// project the user is working in. This keeps the tag list manageable and avoids
/// duplication across projects.
///
/// `ResearchNote.userTagIds` carries the IDs of tags applied to that note.
/// The tag record itself has no back-reference; the relationship is navigated
/// by querying notes that contain a given `UserTag.id` in their `userTagIds`.
///
/// Version history:
///   1.0 — Session 04: initial implementation
@Model final class UserTag {

    // MARK: - Identity

    var id: UUID = UUID()

    // MARK: - Content

    var name: String = "" {
        didSet { lastModified = .now }
    }

    // MARK: - Timestamps

    /// Optional for CloudKit schema compatibility — always non-nil in practice.
    var createdAt: Date?
    /// Optional for CloudKit schema compatibility — always non-nil in practice.
    var lastModified: Date?

    // MARK: - Initializer

    init(name: String) {
        self.id = UUID()
        self.name = name
        let now = Date.now
        createdAt = now
        lastModified = now

        #if DEBUG
        print("[SwiftData] UserTag created: \(id) '\(name)'")
        #endif
    }
}
