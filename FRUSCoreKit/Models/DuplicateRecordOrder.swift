// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

// MARK: - DuplicateRecordOrder

/// The order a record is kept over its duplicate by: the earlier creation, a missing date sorting
/// last, then the lower id, so independent devices agree.
///
/// The app's `DuplicateRecordCleanup` keeps one of a duplicate group by it, and an Archives Visit
/// target shows one of several stored rows by it (``ArchiveVisitTargetKeys/shownRow(among:answeringFor:)``,
/// decision 62), so the row a target shows is the one that pass would keep.
///
/// Version history:
///   1.0 — 2026-11-24 (FRUS Explorer Light, S30b): out of the app's `DuplicateRecordCleanup.isKept(_:over:)`,
///          which now forwards to it, when the Archives Visit derivation that reads it moved into FRUSCoreKit;
///          unchanged
public enum DuplicateRecordOrder {

    /// Whether a record created at `record.createdAt` with id `record.id` is kept over `other`:
    /// the earlier creation, a missing date sorting last, then the lower id, so independent
    /// devices agree.
    public static func isKept(_ record: (createdAt: Date?, id: UUID),
                              over other: (createdAt: Date?, id: UUID)) -> Bool {
        let l = record.createdAt ?? .distantFuture
        let r = other.createdAt ?? .distantFuture
        if l != r { return l < r }
        return record.id.uuidString < other.id.uuidString
    }
}
