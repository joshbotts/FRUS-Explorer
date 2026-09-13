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
/// A **permutation of a baseline**, never a replacement for one. The baseline is alphabetical —
/// every list that follows this order sorts its items by name first — and this moves the names the
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
/// ## Which lists follow it
/// It is set from, and shown in, the note editor's tag and project pickers and the Settings Tags and
/// Projects lists on both platforms. It is shown in the Settings Active Project picker, the iOS Browse
/// project switcher, the macOS Research ▸ Switch Project menu, the document tag picker, and Search's
/// My Tags filter on both platforms. Every view that shows it reads the stored record through
/// `@Query(sort: \SyncedPreferences.createdAt)`, with `order(for:in:)` over `[SyncedPreferences]`, so a
/// reorder in another window or on another device re-renders it. The one exception is the Mac Search
/// window's Advanced popover, which copies the tags when it opens: it closes when the reader clicks
/// into another window, so only an order arriving from another device while it is open waits for the
/// next opening.
///
/// A list that shows only some of the ids — the note editor's, loaded when the editor opens — stores
/// a drag through `merging(_:into:)`, so the ids it does not show keep their places.
///
/// Some lists keep an order of their own on purpose: the Research sidebar's By Tag section (by
/// usage), the iPad sidebar's recent projects (newest first), and every export and the Thematic
/// Index (alphabetical, pinned by their tests).
///
/// Version history:
///   1.0 — #1275: initial implementation
///   1.1 — The Settings Tags and Projects lists set the order too, and four more lists show it. Views
///          read it through `@Query`. Move helpers serve both drag and the Move to Top, Move Up and
///          Move Down commands.
///          A partial list keeps the ids it does not show in place (`merging(_:into:)`).
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

    /// The reader's stored order for `list`, read from preferences records a view observes.
    ///
    /// For a view holding `@Query(sort: \SyncedPreferences.createdAt)`. The first record is the
    /// canonical one, by the same earliest-`createdAt` rule the context-based reader uses. Reading it
    /// through the query is what re-renders the view when the order changes: from its own drag, from
    /// another window, or from another device.
    ///
    /// - Parameters:
    ///   - list: Which list to read.
    ///   - records: The observed preferences records, sorted by `createdAt`, earliest first.
    /// - Returns: The stored ids, in the reader's order. Empty means "no custom order".
    @MainActor
    static func order(for list: List, in records: [SyncedPreferences]) -> [UUID] {
        order(for: list, inJSON: records.first?.listOrderJSON ?? "")
    }

    /// One list's order, decoded from a stored `SyncedPreferences.listOrderJSON` string.
    ///
    /// - Parameters:
    ///   - list: Which list to read.
    ///   - json: The stored JSON. Empty or unreadable means "no custom order".
    /// - Returns: The stored ids, in the reader's order.
    static func order(for list: List, inJSON json: String) -> [UUID] {
        guard let payload = decode(json) else { return [] }
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

    // MARK: - Moving

    /// One step for the Move to Top, Move Up and Move Down commands.
    enum Step {
        /// To the head of the list.
        case toTop
        /// One place towards the head.
        case up
        /// One place towards the tail.
        case down
    }

    /// The ids of `displayed` after a drag moves the rows at `source` to `destination`.
    ///
    /// The same result as SwiftUI's `move(fromOffsets:toOffset:)`, the call `onMove` hands its
    /// offsets to. It is written out here so the model does not import SwiftUI, and a test pins the
    /// two together.
    ///
    /// - Parameters:
    ///   - displayed: The ids in the order the rows are shown.
    ///   - source: The offsets being moved.
    ///   - destination: The offset they are dropped before, counted in the original list.
    /// - Returns: The ids in their new order.
    static func moving(_ displayed: [UUID], from source: IndexSet, to destination: Int) -> [UUID] {
        let valid = source.filter { displayed.indices.contains($0) }
        let moved = valid.map { displayed[$0] }
        var remaining = displayed.indices.filter { !valid.contains($0) }.map { displayed[$0] }
        let movedAhead = valid.filter { $0 < destination }.count
        let insertion = min(max(destination - movedAhead, 0), remaining.count)
        remaining.insert(contentsOf: moved, at: insertion)
        return remaining
    }

    /// The ids of `displayed` after `id` moves one `step`, or `nil` when the move would change
    /// nothing: the row is already first, already last, or not in the list.
    ///
    /// - Parameters:
    ///   - id: The row being moved.
    ///   - step: Where it goes.
    ///   - displayed: The ids in the order the rows are shown.
    /// - Returns: The ids in their new order, or `nil`.
    static func moving(_ id: UUID, _ step: Step, in displayed: [UUID]) -> [UUID]? {
        guard let index = displayed.firstIndex(of: id) else { return nil }
        var ids = displayed
        switch step {
        case .toTop:
            guard index > 0 else { return nil }
            ids.remove(at: index)
            ids.insert(id, at: 0)
        case .up:
            guard index > 0 else { return nil }
            ids.swapAt(index, index - 1)
        case .down:
            guard index < ids.count - 1 else { return nil }
            ids.swapAt(index, index + 1)
        }
        return ids
    }

    /// A drag made in a list that shows only some of the stored ids, folded into the stored order.
    ///
    /// Each slot the shown ids held in `stored` takes the next id of `displayed`, in order; every other
    /// stored id stays in its slot; shown ids the store never named follow everything stored. So the
    /// shown ids end up in exactly the order the reader dragged them into, and an id the list does not
    /// show — a tag created and placed in Settings while a note editor was open — keeps its place
    /// instead of dropping to the alphabetical tail.
    static func merging(_ displayed: [UUID], into stored: [UUID]) -> [UUID] {
        let shown = Set(displayed)
        var queue = displayed[...]
        var merged: [UUID] = []
        merged.reserveCapacity(stored.count + displayed.count)
        for id in stored {
            if shown.contains(id) {
                if let next = queue.popFirst() { merged.append(next) }
            } else {
                merged.append(id)
            }
        }
        merged.append(contentsOf: queue)
        return merged
    }

    /// Stores the order a drag produced over the rows as they were shown.
    ///
    /// - Parameters:
    ///   - displayed: The ids in the order the rows were shown when the drag began.
    ///   - source: The offsets `onMove` reported.
    ///   - destination: The destination offset `onMove` reported.
    ///   - list: Which list was reordered.
    ///   - context: The SwiftData context holding the preferences record.
    @MainActor
    static func storeMove(of displayed: [UUID], from source: IndexSet, to destination: Int,
                          for list: List, in context: ModelContext) {
        setOrder(moving(displayed, from: source, to: destination), for: list, in: context)
    }

    /// The Move to Top, Move Up or Move Down command for one row, or `nil` when it would do nothing,
    /// so the control that offers it can hide.
    ///
    /// - Parameters:
    ///   - id: The row the command belongs to.
    ///   - step: Where the command moves the row.
    ///   - displayed: The ids in the order the rows are shown.
    ///   - list: Which list the rows belong to.
    ///   - context: The SwiftData context holding the preferences record.
    /// - Returns: A closure that stores the moved order, or `nil`.
    @MainActor
    static func moveCommand(for id: UUID, _ step: Step, displayed: [UUID], list: List,
                            in context: ModelContext) -> (@MainActor () -> Void)? {
        guard let moved = moving(id, step, in: displayed) else { return nil }
        return { setOrder(moved, for: list, in: context) }
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
