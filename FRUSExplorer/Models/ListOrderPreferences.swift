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
import SwiftData

/// The reader's own order for the tag and project lists (#1275).
///
/// ## What it is, and what it is not
/// A **permutation of a baseline**, never a replacement for one. The baseline is alphabetical — the
/// order every tag and project list in the app already uses — and this moves the few names the
/// reader is working with right now to the top of it. A tag the stored order does not name keeps
/// its alphabetical place after the ones it does.
///
/// That is the whole reason ``apply(_:order:id:)`` appends unknown items rather than dropping them:
/// a reader who reorders three tags and then creates a fourth must see the fourth, and a reader who
/// reorders on their iPad and then merges two tags on the Mac must not lose the survivors.
///
/// ## Where it lives
/// One JSON string on `SyncedPreferences` — `{"tags": [uuid…], "projects": [uuid…]}` — because the
/// owner's decision was that the order should follow the reader between devices. Two lists share
/// one property so the change costs one CloudKit identifier rather than two.
///
/// **It is read and written directly rather than through `SettingsSyncCoordinator`**, and that is
/// deliberate: the coordinator mirrors `UserDefaults` into this record only while the reader has
/// turned "Sync Settings Across Devices" ON, which is off by default. An order that silently did
/// not travel would be worse than one that never claimed to.
///
/// ## Identity, not position
/// IDs are stored rather than indices, so a tag renamed, merged or cascade-deleted elsewhere does
/// not renumber the rest. Unknown ids are dropped on read.
///
/// Version history:
///   1.0 — #1275: initial implementation
enum ListOrderPreferences {

    /// The wire shape of ``SyncedPreferences/listOrderJSON``.
    private struct Payload: Codable {
        var tags: [UUID] = []
        var projects: [UUID] = []
    }

    /// Which list an order applies to.
    enum List {
        case tags
        case projects
    }

    // MARK: - Reading

    /// The reader's stored order for `list`, or an empty array when they have set none.
    ///
    /// - Parameters:
    ///   - list: Which list to read.
    ///   - context: The SwiftData context holding the preferences record.
    /// - Returns: The stored ids, in the reader's order. Empty means "no custom order".
    @MainActor
    static func order(for list: List, in context: ModelContext) -> [UUID] {
        guard let payload = payload(in: context) else { return [] }
        switch list {
        case .tags: return payload.tags
        case .projects: return payload.projects
        }
    }

    /// Reorders `items` by the reader's stored order, keeping the rest in the order given.
    ///
    /// - Parameters:
    ///   - items: The baseline list, already in its own order (alphabetical, everywhere this is used).
    ///   - order: The reader's ids, most-wanted first.
    ///   - id: Reads an item's identity.
    /// - Returns: The named items first, in the reader's order, then everything else unchanged.
    static func apply<T>(_ items: [T], order: [UUID], id: (T) -> UUID) -> [T] {
        guard !order.isEmpty else { return items }
        // `uniquingKeysWith:`, never `uniqueKeysWithValues:` — the latter TRAPS on a duplicate key,
        // and duplicate ids are a condition this app expects rather than one it rules out:
        // `DuplicateRecordCleanup` exists because CloudKit can deliver two records with the same
        // identity. A stored order carrying an id twice would have crashed the note editor on open.
        // First position wins, which is where the reader dragged it.
        let rank = Dictionary(order.enumerated().map { ($0.element, $0.offset) },
                              uniquingKeysWith: { first, _ in first })
        // A stable partition, not a sort with a tie-break: everything the order does not name keeps
        // the baseline's own sequence exactly, which is what makes this a permutation of it.
        let named = items.filter { rank[id($0)] != nil }
                         .sorted { (rank[id($0)] ?? 0) < (rank[id($1)] ?? 0) }
        let rest = items.filter { rank[id($0)] == nil }
        return named + rest
    }

    // MARK: - Writing

    /// Stores `order` for `list`, leaving the other list untouched.
    ///
    /// - Parameters:
    ///   - order: The ids in the reader's order.
    ///   - list: Which list they ordered.
    ///   - context: The SwiftData context holding the preferences record.
    @MainActor
    static func setOrder(_ order: [UUID], for list: List, in context: ModelContext) {
        guard let record = canonicalRecord(in: context, create: true) else { return }
        var payload = decode(record.listOrderJSON) ?? Payload()
        switch list {
        case .tags: payload.tags = order
        case .projects: payload.projects = order
        }
        guard let data = try? JSONEncoder().encode(payload),
              let json = String(data: data, encoding: .utf8) else { return }
        guard record.listOrderJSON != json else { return }
        record.listOrderJSON = json
        record.updatedAt = .now
        try? context.save()
    }

    // MARK: - Storage

    @MainActor
    private static func payload(in context: ModelContext) -> Payload? {
        guard let record = canonicalRecord(in: context, create: false) else { return nil }
        return decode(record.listOrderJSON)
    }

    private static func decode(_ json: String) -> Payload? {
        guard !json.isEmpty, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Payload.self, from: data)
    }

    /// The one preferences record: earliest `createdAt` wins, so two devices that each minted one
    /// before syncing agree on which is real.
    ///
    /// The same RULE as `SettingsSyncCoordinator.resolveCanonical`, but not the same behaviour — that
    /// one also deletes the duplicates it passes over, which is its job as the sync owner and not
    /// this one's. Reading a list order is not the moment to delete a record.
    @MainActor
    private static func canonicalRecord(in context: ModelContext, create: Bool) -> SyncedPreferences? {
        let descriptor = FetchDescriptor<SyncedPreferences>(sortBy: [SortDescriptor(\.createdAt)])
        if let existing = (try? context.fetch(descriptor))?.first { return existing }
        guard create else { return nil }
        // **Seeded from this device's own settings, not left at type defaults.**
        // `SettingsSyncCoordinator` decides between seeding the cloud and adopting from it purely on
        // whether a record EXISTS: enabling "Sync Settings Across Devices" pulls when one does and
        // pushes when it does not. Before this file, the only creator was that coordinator, always
        // under the reader's explicit opt-in. A reorder is not that opt-in — so a record minted here
        // at stock defaults would silently convert the reader's next "turn sync on" from "publish my
        // settings" into "adopt these blanks", overwriting their word-cloud thresholds, stop lists
        // and research-logging switch with type defaults. Seeding makes the adopt a no-op instead.
        let fresh = SyncedPreferences()
        SettingsSyncCoordinator.seedFromDeviceDefaults(fresh)
        context.insert(fresh)
        return fresh
    }
}
