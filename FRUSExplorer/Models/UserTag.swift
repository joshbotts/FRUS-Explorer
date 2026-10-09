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
///   1.1 — Session 2026-10-09: #1591 — `chips(for:among:)`, the tags a search result row names
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

// MARK: - Search result chips (#1591)

/// One tag chip on a search result row: the tag's id as the index stores it, and its name.
struct UserTagChip: Identifiable, Equatable {
    /// The tag's id, as `document_cache.user_tag_ids` holds it. Tapping the chip filters by it.
    let id: String
    /// The tag's name.
    let name: String
}

extension UserTag {

    /// The chips a search result row shows for `tagIds`, the ids the index stores for the
    /// document: one for each id that `tags` names, in `tagIds`' order, each once.
    ///
    /// **An id no tag names gets no chip (#1591).** Both result rows used to print such an id as
    /// its own label, a 36-character UUID, and on iPhone and iPad the chip filtered by it. The
    /// index can hold one for a while: a tag deleted on another device is gone from the tag list
    /// before this device's index is reconciled.
    ///
    /// - Parameters:
    ///   - tagIds: The ids stored for the document, as `SearchResult.userTagIds` gives them.
    ///   - tags: The reader's tags.
    static func chips(for tagIds: [String], among tags: [UserTag]) -> [UserTagChip] {
        var names: [String: String] = [:]
        for tag in tags { names[tag.id.uuidString] = tag.name }
        var seen: Set<String> = []
        return tagIds.compactMap { tagId in
            guard let name = names[tagId], seen.insert(tagId).inserted else { return nil }
            return UserTagChip(id: tagId, name: name)
        }
    }
}
