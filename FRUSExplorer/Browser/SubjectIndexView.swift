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

import SwiftUI

// MARK: - SubjectIndexGrouping

/// The pure grouping and filtering behind ``SubjectIndexView``, split out so a test drives the
/// real rule rather than a copy of it — the #1027 lesson.
///
/// Version history:
///   1.0 — Session 2026-08-22: #1023
///   1.1 — #1365: the arrival rule (``IndexState/land(_:rows:)``), the chip's caption
///          (``groupFilterCaption(_:areaRows:query:)``), ``Arrival``, and ``HostState`` — what
///          a host keeps for the index it mounts: the delivery waiting to land (posted by
///          ``HostState/post(_:)``, emptied by ``HostState/landPending(rows:)``, so a delivery
///          lands once) and the reader's ``IndexState``, so a re-mounted index shows what the
///          reader left; only ``HostState/openWhole()`` resets it
enum SubjectIndexGrouping {

    /// One initial-letter section of the index.
    struct Section: Identifiable, Equatable {
        /// The section's heading — an initial letter, or `#` for anything not starting with one.
        let letter: String
        /// The subjects filed under it, in catalogue (name) order.
        let subjects: [SubjectIndexRow]
        var id: String { letter }
    }

    /// One row: a subject, and the two reach figures that describe it.
    struct SubjectIndexRow: Identifiable, Equatable {
        /// The durable ref — exact half of the saved-search key.
        let ref: String
        /// Display name, and the fallback half of that key.
        let name: String
        /// Top-level taxonomy category.
        let category: String
        /// Second-level sub-category.
        let subcategory: String
        /// Documents carrying this subject **across the whole corpus**, from the bundled artifact.
        let documentCount: Int
        /// Volumes carrying it, corpus-wide.
        let volumeCount: Int
        var id: String { ref }
    }

    /// Filters by `query` and groups by initial letter.
    ///
    /// Matching is on the NAME and on the `category · subcategory` pair, because a reader who types
    /// "Vietnam" wants the Vietnam Conflict sub-category's subjects as readily as the subject
    /// literally called Vietnam — and because the sub-category is on screen in every row, so a row
    /// visibly containing the typed word must not be filtered out.
    ///
    /// Sections are ordered by letter with `#` last: a heading a reader cannot predict the position
    /// of belongs at the end, not sorted among the letters by its code point.
    static func sections(from rows: [SubjectIndexRow], query: String) -> [Section] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let matching = trimmed.isEmpty ? rows : rows.filter { row in
            row.name.localizedCaseInsensitiveContains(trimmed)
                || row.category.localizedCaseInsensitiveContains(trimmed)
                || row.subcategory.localizedCaseInsensitiveContains(trimmed)
        }
        var byLetter: [String: [SubjectIndexRow]] = [:]
        for row in matching {
            let first = row.name.first.map { String($0).uppercased() } ?? "#"
            byLetter[first.first?.isLetter == true ? first : "#", default: []].append(row)
        }
        return byLetter
            .map { Section(letter: $0.key, subjects: $0.value) }
            .sorted { lhs, rhs in
                if (lhs.letter == "#") != (rhs.letter == "#") { return rhs.letter == "#" }
                return lhs.letter < rhs.letter
            }
    }

    // MARK: The .group arrival (#1051 B-6)

    /// An active topic-area narrowing — the `.group(categoryKey:)` arrival's state.
    struct GroupFilter: Equatable {
        /// The bucket's top-level category.
        let category: String
        /// The bucket's sub-category.
        let subcategory: String
        /// The display label — the bare sub-category when it names one bucket, the
        /// `category · subcategory` pair when the sub-category is shared (all thirteen
        /// "General" buckets), mirroring `SubjectBucketVocabulary.label(at:)`.
        let label: String
    }

    /// Resolves a `.group(categoryKey:)` arrival against the loaded rows.
    ///
    /// The key is the `SubjectBucketVocabulary` durable form — `category`, U+001F,
    /// `subcategory` — split the way the vocabulary itself splits it. A malformed key,
    /// or one naming a bucket no loaded subject belongs to (a stale key from an older
    /// data drop), resolves to `nil`: the index then shows everything, the same honest
    /// fallback `.all` is.
    ///
    /// - Parameters:
    ///   - key: The durable bucket key.
    ///   - rows: The loaded catalogue rows.
    /// - Returns: The filter, or `nil` when the key cannot land.
    static func groupFilter(forCategoryKey key: String, rows: [SubjectIndexRow]) -> GroupFilter? {
        let parts = key.split(separator: "\u{1F}", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        let category = String(parts[0])
        let subcategory = String(parts[1])
        guard rows.contains(where: { $0.category == category && $0.subcategory == subcategory })
        else { return nil }
        let shared = rows.contains { $0.subcategory == subcategory && $0.category != category }
        return GroupFilter(category: category, subcategory: subcategory,
                           label: shared ? "\(category) · \(subcategory)" : subcategory)
    }

    /// The rows inside a topic area, or everything when no filter is active.
    ///
    /// - Parameters:
    ///   - rows: The loaded catalogue rows.
    ///   - filter: The active narrowing, or `nil`.
    /// - Returns: The rows the index should section.
    static func filtered(_ rows: [SubjectIndexRow], by filter: GroupFilter?) -> [SubjectIndexRow] {
        guard let filter else { return rows }
        return rows.filter { $0.category == filter.category && $0.subcategory == filter.subcategory }
    }

    // MARK: Arrivals (#1365)

    /// Everything the index holds for the reader — the search, the topic-area chip, and the subject
    /// whose sheet is open — as ONE value, so an arrival replaces it in one assignment.
    ///
    /// Until #1365 these were three `@State`s and each arrival set only the one it carried. A
    /// `.group` arrival set the chip and left the search, so "All Cold War topics" taken from a
    /// search for "Berlin" listed one topic under "Topic area: Cold War — 6 topics"; `.all` set
    /// nothing at all.
    struct IndexState: Equatable {
        /// The search field's text.
        var query = ""
        /// The topic-area narrowing, cleared by the chip's ✕.
        var groupFilter: GroupFilter?
        /// The subject whose detail sheet is open.
        var selected: SubjectIndexRow?

        /// Lands an arrival: the index becomes what a NEW index opened at `request` would be.
        ///
        /// **Nothing the reader had survives, in any case.** An arrival asks to see something, and
        /// a search or chip left over from before narrows it to something else, so the list
        /// contradicts the door the reader took. The view reaches this through
        /// ``HostState/landPending(rows:)``, from `load()` and from its arrival observer; replacing
        /// the whole value is what makes a hand-off into a live index land the same way as one
        /// into a new index, as the view's arrival handling has said it does since #1051 B-6.
        ///
        /// - `.all`: the whole index, with no chip and no sheet.
        /// - `.group`: that area's chip over the whole area. A key naming no loaded area lands as
        ///   `.all` does (the fallback ``SubjectIndexGrouping/groupFilter(forCategoryKey:rows:)``
        ///   documents).
        /// - `.subject`: that subject's sheet over the whole index, so dismissing it does not reveal
        ///   a search or an area from an earlier visit. A ref naming no loaded subject lands as
        ///   `.all` does.
        ///
        /// A pure value transformation: it reads only its arguments and writes only `self`.
        ///
        /// - Parameters:
        ///   - request: What the index was opened at.
        ///   - rows: The loaded catalogue rows.
        mutating func land(_ request: SubjectExplorerRequest, rows: [SubjectIndexRow]) {
            switch request {
            case .all:
                self = IndexState()
            case .group(let categoryKey):
                self = IndexState(groupFilter: SubjectIndexGrouping.groupFilter(
                    forCategoryKey: categoryKey, rows: rows))
            case .subject(let ref, _):
                self = IndexState(selected: rows.first { $0.ref == ref })
            }
        }
    }

    /// What a host keeps for the Topic index it mounts: the hand-off waiting to land, and the
    /// reader's ``IndexState`` (#1365).
    ///
    /// **Why the reader's state lives in the host, not in the index view.** A host can mount a NEW
    /// index for a reader who never left the one they were using. The iPad two-pane draws only the
    /// path's last level, so a covering volume opened from a topic's sheet replaces the index, and
    /// Back (`removeLast()`) mounts another; crossing the two-pane gate — a rotation, a Stage
    /// Manager resize — swaps the whole layout and mounts another too. State the view held died
    /// with the view, and the reader came back to the whole index instead of the area and search
    /// they left, where the iPhone's navigation stack, which keeps the index alive, had always
    /// kept both. Every index a host mounts reads this value, so a re-mount shows what the reader
    /// was looking at on either idiom.
    ///
    /// **Three things change it, and only one of them resets it.**
    /// - A hand-off: ``post(_:)`` puts a delivery in ``pending`` and the index lands it with
    ///   ``landPending(rows:)``, which EMPTIES the slot and replaces ``index`` whole
    ///   (``IndexState/land(_:rows:)``). The slot is emptied so a delivery lands once: a re-mount
    ///   calls `landPending` again from `load()`, and a delivery still waiting would land a second
    ///   time over whatever the reader has done since — a search typed inside the area, a chip
    ///   cleared with its ✕.
    /// - The reader: the index binds its search, chip and sheet to ``index``.
    /// - An entry that is NOT a hand-off: ``openWhole()``, which Browse's Topics row calls. Before
    ///   the state moved here that row needed nothing — a new view started empty — except that the
    ///   host's never-emptied slot re-landed the last hand-off into it (#1274's session recorded
    ///   that gap). Tapped while the index is already the level on screen (the iPad two-pane,
    ///   where the list pane stays beside it), the same view stays and simply redraws whole.
    ///
    /// The macOS Topics window holds one of these too. Nothing there re-mounts its index, so for it
    /// this is only where the hand-off rule lives; it has no Topics row, and a window opened again
    /// starts from a new value.
    struct HostState: Equatable {
        /// The hand-off waiting to land, or `nil` once an index has landed it.
        var pending: Arrival?
        /// The reader's search, topic-area chip and open sheet — what every index this host
        /// mounts shows.
        var index = IndexState()

        /// Posts a consumed hand-off for the index to land: a NEW ``Arrival``, whatever was
        /// waiting.
        ///
        /// Both hosts call this — `BrowserView.consumePendingSubjectExplorer()` on iOS and iPadOS,
        /// and the macOS Topics window's `SubjectExplorerWindowContent.consume()`. The index
        /// observes ``pending`` and lands it; see ``Arrival`` for why each post carries its own
        /// identity.
        ///
        /// - Parameter request: The hand-off's payload.
        mutating func post(_ request: SubjectExplorerRequest) {
            pending = Arrival(request)
        }

        /// Lands the delivery waiting in ``pending``, if there is one, and EMPTIES the slot — so a
        /// delivery lands once, and an index mounted after it shows ``index`` as it stands.
        ///
        /// - Parameter rows: The loaded catalogue rows.
        /// - Returns: Whether a delivery landed.
        @discardableResult
        mutating func landPending(rows: [SubjectIndexRow]) -> Bool {
            guard let arrival = pending else { return false }
            pending = nil
            index.land(arrival.request, rows: rows)
            return true
        }

        /// Opens the whole index from an entry that hands nothing off — Browse's Topics row: no
        /// search, no chip, no sheet, and nothing waiting to land over it.
        mutating func openWhole() {
            self = HostState()
        }
    }

    /// One delivery of a ``SubjectExplorerRequest`` into the index: the request, and an identity
    /// minted for each hand-off (#1365).
    ///
    /// **Why the identity.** The index lands a delivery when ``HostState/pending`` CHANGES, and an
    /// equal request is not a change. Observed by value, a reader who took "All Cold War topics",
    /// searched inside the area and took the same door again sent an equal `.group` into the same
    /// live view: the observer never fired and the door did nothing — #1365 again, one tap later.
    /// The same held for an `.all` hand-off into an index opened at `.all`, and for the same
    /// `.subject` twice.
    ///
    /// **Today the identity is defensive, and no reachable path depends on it.** The index empties
    /// the slot as it lands a delivery (``HostState/landPending(rows:)``), so a post finds the slot
    /// empty and nil-to-a-delivery is a change on its own. A delivery can wait in a MOUNTED index's
    /// slot only while the catalogue has not loaded, and then nothing can land it anyway — `load()`
    /// lands whatever the slot holds once it can, identity or not. The identity is kept so that
    /// "an equal hand-off is still a change" does not rest on every host and every future path
    /// emptying the slot; `SubjectIndexGroupingTests.postingIsANewDeliveryEveryTime` pins it.
    ///
    /// Hosts post one with ``HostState/post(_:)`` and never build one in a `body`, which would
    /// carry a new identity on every render.
    struct Arrival: Equatable {
        /// What the index was opened at.
        let request: SubjectExplorerRequest
        /// This delivery's identity — different for every hand-off, even of an equal request.
        let id: UUID

        /// A delivery of `request`.
        ///
        /// - Parameters:
        ///   - request: What the index was opened at.
        ///   - id: The delivery's identity; a new one unless given.
        init(_ request: SubjectExplorerRequest, id: UUID = UUID()) {
            self.request = request
            self.id = id
        }
    }

    /// The chip's words: the topic area, and how many of its topics the list is showing (#1365).
    ///
    /// **It counts through ``sections(from:query:)``**, the call the list is drawn from, so the chip
    /// cannot count something the list does not show. Before #1365 it counted the area alone, and a
    /// reader who searched after landing read "6 topics" over a list of one. While the search hides
    /// none of the area's topics the chip reads "6 topics"; once it hides some, "1 of 6 topics".
    ///
    /// Counts are grouped with `.formatted()` and the noun is singular at one, in the `%@` +
    /// `.formatted()` form Browse already uses (`ArchivesArrangement.collectionCountLabel`). The
    /// noun follows the AREA's size, since that is the number it is attached to: "0 of 1 topic".
    ///
    /// - Parameters:
    ///   - filter: The active narrowing.
    ///   - areaRows: The rows inside the area — the list's rows before the search.
    ///   - query: The reader's search, as the list receives it.
    /// - Returns: The chip's text.
    static func groupFilterCaption(_ filter: GroupFilter, areaRows: [SubjectIndexRow],
                                   query: String) -> String {
        let total = areaRows.count
        let shown = sections(from: areaRows, query: query).reduce(0) { $0 + $1.subjects.count }
        if shown == total {
            return total == 1
                ? String(format: String(localized: "subjects.index.groupFilter.all.one %@",
                                        defaultValue: "Topic area: %@ — 1 topic"),
                         filter.label)
                : String(format: String(localized: "subjects.index.groupFilter.all.many %@ %@",
                                        defaultValue: "Topic area: %1$@ — %2$@ topics"),
                         filter.label, total.formatted())
        }
        return total == 1
            ? String(format: String(localized: "subjects.index.groupFilter.some.one %@ %@",
                                    defaultValue: "Topic area: %1$@ — %2$@ of 1 topic"),
                     filter.label, shown.formatted())
            : String(format: String(localized: "subjects.index.groupFilter.some.many %@ %@ %@",
                                    defaultValue: "Topic area: %1$@ — %2$@ of %3$@ topics"),
                     filter.label, shown.formatted(), total.formatted())
    }
}

// MARK: - SubjectIndexView

/// The Subject Explorer: a browsable index of the 491 detected subjects (#1023).
///
/// ## What this surface is for, and what D1 forbade
/// D1 dropped the document-view Subjects accordion and ruled that when the surface returned it
/// would be "a separate view, not an accordion, not the handoff's grid tile". This is that view.
///
/// ## The reach figures are CORPUS-WIDE, and the caption says so
/// The bundled subject index covers all 552 volumes; the SQL tables carry only volumes this reader
/// has indexed. So a row can truthfully read "4,000 documents" and a search for that subject
/// return sixty. Every surface in this app that faces the split discloses it, and a browse whose
/// whole content is counts would be the worst place to start hiding it.
///
/// ## Why the list needs no boot guard and the detail does
/// The vocabulary comes from `DocumentSubjectStore.shared`, a bundled artifact available on the
/// first frame — so the index renders immediately, with no "Preparing your index…" over content
/// that is genuinely ready. Reaching DOCUMENTS goes through `SearchService`, which does not exist
/// until boot completes, so that half guards on `appState.isBootComplete`. Guarding the whole
/// window on boot would spin over a list that could already be read.
///
/// Version history:
///   1.0 — Session 2026-08-22: #1023
///   1.1 — #1051 B-6: the `.group(categoryKey:)` arrival lands — a topic-area chip
///          narrows the index (stale keys degrade to the whole index); arrivals into a
///          LIVE view re-apply via the `request` observer (also closing the pre-existing
///          `.subject` re-arrival gap); `SubjectDetailSheet` gains its covering-volumes
///          list (complete membership, previewed) and the "All «area» topics" door — the
///          first `.group` producer, placed here because this sheet knows its bucket
///          exactly where the facet panel's section header structurally cannot
///   1.2 — #1365: an arrival replaces the reader's search, chip and open sheet
///          (`IndexState.land`), so "All «area» topics" lists the whole area; the chip
///          says "1 of 6 topics" when a search hides some of it; the view observes a
///          per-hand-off `Arrival`, so an equal request lands again (the 1.1 observer
///          compared requests by value, so it closed the re-arrival gap only for a
///          DIFFERENT request); the search, chip and sheet are the HOST's
///          (`SubjectIndexGrouping.HostState`, bound), so an index re-mounted by the iPad
///          two-pane's Back or by crossing the two-pane gate shows the area and search
///          the reader left, a delivery lands once, and Browse ▸ Topics resets it to
///          the whole index rather than re-landing the last hand-off
struct SubjectIndexView: View {

    /// The host's Topic-index state — the hand-off waiting to land, and the reader's search,
    /// topic-area chip and open sheet — BOUND, so the host outlives this view (#1365). The iPad
    /// two-pane mounts a new index on Back and when the layout crosses its gate, and every mount
    /// reads the same value, so the reader returns to what they left. The host posts each
    /// hand-off with ``SubjectIndexGrouping/HostState/post(_:)``, this view lands it with
    /// ``SubjectIndexGrouping/HostState/landPending(rows:)``, and Browse's Topics row — which hands
    /// nothing off — resets it with ``SubjectIndexGrouping/HostState/openWhole()``.
    @Binding var host: SubjectIndexGrouping.HostState

    @Environment(AppState.self) private var appState
    /// The scene this renders in, so a hand-off out of here addresses the presenting window (#338).
    @Environment(\.sceneID) private var sceneID

    /// The catalogue, resolved once. `subjectCatalogue` is cheap now that `subjectsByVolume` is
    /// stored, but it still allocates 491 rows and sorts them, which is not work for `body`.
    @State private var rows: [SubjectIndexGrouping.SubjectIndexRow] = []

    var body: some View {
        // The reader's search, topic-area chip and open sheet, as one value an arrival replaces
        // whole (#1365). The chip's ✕ clears `groupFilter` alone; a stale or malformed area key
        // lands as no chip at all (= the whole index, the same honest fallback `.all` is).
        let state = host.index
        let visibleRows = SubjectIndexGrouping.filtered(rows, by: state.groupFilter)
        List {
            if rows.isEmpty {
                unavailableSection
            } else {
                // The disclosure sits ABOVE the index, not in a footer: every row on this screen is
                // a pair of counts, and a caveat a reader reaches only by scrolling 491 rows has
                // been placed where it cannot do its job.
                Section {
                    Text(coverageCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let groupFilter = state.groupFilter {
                    groupFilterChip(SubjectIndexGrouping.groupFilterCaption(
                        groupFilter, areaRows: visibleRows, query: state.query))
                }

                ForEach(SubjectIndexGrouping.sections(from: visibleRows, query: state.query)) { section in
                    Section(section.letter) {
                        ForEach(section.subjects) { row in
                            Button { host.index.selected = row } label: { rowLabel(row) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .searchable(text: $host.index.query,
                    prompt: Text(String(localized: "subjects.index.search.prompt",
                                        defaultValue: "Search topics")))
        .overlay { emptyResultsOverlay }
        .navigationTitle(String(localized: "subjects.index.title", defaultValue: "Topics"))
        .task { load() }
        // An arrival can come while this view is LIVE (a second hand-off into the open macOS
        // Topics window, or a new arrival at the already-selected Browse level): `load()`'s rows
        // guard makes it once-only, so arrivals land here too (#1051 B-6). The observer keys on
        // the host's waiting ARRIVAL, not on its request, and landing empties the slot, so the same
        // door taken twice lands twice; it fires again when that emptying happens, which finds
        // nothing to take (#1365).
        .onChange(of: host.pending) { _, _ in
            landPendingArrival()
        }
        .sheet(item: $host.index.selected) { row in
            SubjectDetailSheet(subject: row)
                .environment(appState)
                .environment(\.sceneID, sceneID)
        }
    }

    /// The active topic-area chip: what the index is narrowed to, and the one-tap ✕ out.
    /// `caption` is `SubjectIndexGrouping.groupFilterCaption`'s, computed from the same rows and
    /// search the list below it is drawn from.
    @ViewBuilder
    private func groupFilterChip(_ caption: String) -> some View {
        Section {
            HStack(spacing: 8) {
                Image(systemName: "square.grid.2x2")
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                Text(caption)
                    .font(.caption)
                    .accessibilityIdentifier("subjects.index.groupFilter")
                Spacer(minLength: 4)
                Button {
                    host.index.groupFilter = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(
                    String(localized: "subjects.index.groupFilter.clear.a11y",
                           defaultValue: "Show all topics")
                )
                .help(String(localized: "subjects.index.groupFilter.clear.help",
                             defaultValue: "Clear the topic-area narrowing"))
            }
        }
    }

    /// The caption that keeps every number on this screen honest.
    private var coverageCaption: String {
        // R-3: the volume count is the bundled manifest's, never a literal — `552` shipped here
        // and would have been false on the day a 553rd volume was catalogued.
        String(format: String(
            localized: "subjects.index.coverage.v2 %lld %lld",
            defaultValue: "%1$lld detected topics across the whole series. Counts describe all %2$lld cataloged volumes, not the volumes you have indexed — a search reaches only what is on this device. Topics are detected automatically from the text, not editorial subject headings, so some are wrong."),
            Int64(rows.count), Int64(appState.manifestStore.bundledEntries.count))
    }

    @ViewBuilder
    private func rowLabel(_ row: SubjectIndexGrouping.SubjectIndexRow) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(row.name).font(.callout)
            Text("\(row.category) · \(row.subcategory)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(String(format: String(
                localized: "subjects.index.row.reach %lld %lld",
                defaultValue: "%lld documents · %lld volumes"),
                Int64(row.documentCount), Int64(row.volumeCount)))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// The artifact is missing — the same degradation every subject surface takes, stated rather
    /// than shown as an empty index.
    @ViewBuilder
    private var unavailableSection: some View {
        ContentUnavailableView(
            String(localized: "subjects.index.unavailable.title", defaultValue: "Topics Unavailable"),
            systemImage: "tag.slash",
            description: Text(String(
                localized: "subjects.index.unavailable.message",
                defaultValue: "The detected-topic index did not load, so topics cannot be browsed. Everything else in the app is unaffected.")))
    }

    @ViewBuilder
    private var emptyResultsOverlay: some View {
        if !rows.isEmpty,
           SubjectIndexGrouping.sections(
               from: SubjectIndexGrouping.filtered(rows, by: host.index.groupFilter),
               query: host.index.query).isEmpty {
            ContentUnavailableView.search(text: host.index.query)
        }
    }

    private func load() {
        guard rows.isEmpty, let index = DocumentSubjectStore.shared else { return }
        rows = index.subjectCatalogue.map {
            SubjectIndexGrouping.SubjectIndexRow(
                ref: $0.ref, name: $0.name, category: $0.category, subcategory: $0.subcategory,
                documentCount: $0.documentCount, volumeCount: $0.volumeCount)
        }
        landPendingArrival()
    }

    /// Lands the hand-off waiting in the host's slot, if any — the whole index, one topic area,
    /// or one subject (#1051 B-6) — and empties the slot (#1365).
    ///
    /// Called from `load()` and from the `host.pending` observer, so a hand-off into a live view
    /// lands the same way one into a fresh view does, because the rule replaces the reader's whole
    /// state rather than the one field an arrival carries; and each delivery lands once, because
    /// taking it empties the slot. With nothing waiting it changes nothing, which is what lets a
    /// RE-MOUNTED index — the iPad two-pane's Back, or the layout crossing its gate — show the
    /// host's state as the reader left it. Before the catalogue has loaded there is nothing to
    /// resolve a key or a ref against, so a delivery waits in the slot for `load()`.
    private func landPendingArrival() {
        guard !rows.isEmpty else { return }
        host.landPending(rows: rows)
    }
}

// MARK: - SubjectDetailSheet

/// One subject: what it is, how far it reaches, and the two ways into the record (#1023).
///
/// ## Three numbers, three different questions
/// The corpus figures come from the bundled artifact and describe all 552 volumes. The device
/// figure comes from running the browse — `searchCount` over a filter-only `SearchParameters`,
/// which is the same correlated `EXISTS` the search itself runs and is served by the primary key.
/// It is deliberately NOT a new `COUNT(*) … WHERE subject = ?`: `document_subject_refs` has no
/// index on `subject`, so that scans all 877,817 rows, and adding the index costs half the table
/// again in disk plus nearly double the backfill (see the schema comment).
///
/// Version history:
///   1.0 — Session 2026-08-22: #1023
struct SubjectDetailSheet: View {

    /// The subject being shown.
    let subject: SubjectIndexGrouping.SubjectIndexRow

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.sceneID) private var sceneID
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    /// Documents this device can actually return — `nil` until counted, and `nil` forever if the
    /// count fails, which the caption renders as "not counted" rather than as zero.
    @State private var deviceCount: Int?
    @State private var counting = true
    /// The covering volumes (#1051 B-6) — COMPLETE membership from the document index
    /// (`volumeIds(forSubjectRef:)`, the #1027 resolver), never the profiles' top-15 cut.
    @State private var coveringVolumeIds: [String] = []
    /// Whether the covering-volumes section shows past its preview cap.
    @State private var showsAllVolumes = false

    /// How many covering volumes show before "Show all" (#1051 B-6). A subject can cover
    /// most of the series (War reaches hundreds of volumes); the sheet previews, the
    /// toggle discloses.
    private static let volumePreviewCap = 6

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent(String(localized: "subjects.detail.category",
                                          defaultValue: "Category"),
                                   value: "\(subject.category) · \(subject.subcategory)")
                    LabeledContent(String(localized: "subjects.detail.corpusDocuments",
                                          defaultValue: "Documents in the series"),
                                   value: subject.documentCount.formatted())
                    LabeledContent(String(localized: "subjects.detail.corpusVolumes",
                                          defaultValue: "Volumes in the series"),
                                   value: subject.volumeCount.formatted())
                    LabeledContent(String(localized: "subjects.detail.onThisDevice",
                                          defaultValue: "Indexed on this device"),
                                   value: deviceCountText)
                } footer: {
                    Text(String(localized: "subjects.detail.footer",
                                defaultValue: "The first three figures describe the whole series, including volumes you have not downloaded. Only the last one is what a search here can return. Topics are detected automatically from the text, not editorial subject headings."))
                }

                coveringVolumesSection

                Section {
                    Button {
                        findDocuments()
                    } label: {
                        Label(String(localized: "subjects.detail.findDocuments",
                                     defaultValue: "Find documents on this topic"),
                              systemImage: "magnifyingglass")
                    }
                    .disabled(!appState.isBootComplete)

                    // #1051 B-6: the .group door — this sheet knows its subject's
                    // (category, subcategory) bucket exactly, so it may send what the
                    // results facet's section header structurally cannot (that header
                    // knows nothing narrower than .all, and per-row facet doors are the
                    // deferred P2-i). Lands on the index narrowed to the topic area.
                    if let key = bucketKey {
                        Button {
                            browseTopicArea(key)
                        } label: {
                            Label(String(localized: "subjects.detail.browseArea",
                                         defaultValue: "All \(subject.subcategory) topics"),
                                  systemImage: "square.grid.2x2")
                        }
                        .accessibilityIdentifier("subjects.detail.browseArea")
                    }
                } footer: {
                    if !appState.isBootComplete {
                        Text(String(localized: "subjects.detail.preparing",
                                    defaultValue: "Available once the index has finished preparing."))
                    }
                }
            }
            .navigationTitle(subject.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done", defaultValue: "Done")) { dismiss() }
                }
            }
            .task {
                coveringVolumeIds = DocumentSubjectStore.shared?
                    .volumeIds(forSubjectRef: subject.ref).sorted() ?? []
                await countOnThisDevice()
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 460)
        #endif
    }

    /// The covering-volumes list (#1051 B-6): complete membership joined to the manifest,
    /// previewed to the cap with a Show-all disclosure. Rows open the volume in the
    /// browser through the same hand-off the volume pivot sheet uses — safe to fire
    /// beside `dismiss()` because the destination is the Browse tab / corpus-browser
    /// window, not another sheet (the `VolumeSubjectVolumesSheet.open` precedent; the
    /// sheet's Search and topic-area doors keep the #833 dismiss-first ordering instead).
    @ViewBuilder
    private var coveringVolumesSection: some View {
        if !coveringVolumeIds.isEmpty {
            let visible = showsAllVolumes
                ? coveringVolumeIds
                : Array(coveringVolumeIds.prefix(Self.volumePreviewCap))
            Section {
                ForEach(visible, id: \.self) { volumeId in
                    Button {
                        openVolume(volumeId)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appState.manifestStore.entry(forVolumeId: volumeId)?.title ?? volumeId)
                                .font(.callout)
                                .multilineTextAlignment(.leading)
                            Text(volumeId)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                        // Both modifiers, in this order — the #312 full-row tap-target idiom.
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(String(localized: "subjects.detail.volumeRow.hint",
                                              defaultValue: "Opens this volume in the browser"))
                    .accessibilityIdentifier("subjects.detail.volume")
                }
                if coveringVolumeIds.count > Self.volumePreviewCap {
                    Button {
                        showsAllVolumes.toggle()
                    } label: {
                        Text(showsAllVolumes
                             ? String(localized: "subjects.detail.volumes.fewer",
                                      defaultValue: "Show fewer")
                             : String(localized: "subjects.detail.volumes.all",
                                      defaultValue: "Show all \(coveringVolumeIds.count) volumes"))
                            .font(.callout)
                    }
                    .buttonStyle(.borderless)
                }
            } header: {
                Text(String(localized: "subjects.detail.volumes.header",
                            defaultValue: "Covering volumes"))
            } footer: {
                Text(String(localized: "subjects.detail.volumes.footer",
                            defaultValue: "Complete membership across the series — including volumes you have not downloaded."))
            }
        }
    }

    /// The durable bucket key for this subject's topic area, from the vocabulary itself
    /// (never hand-assembled — the key format is the vocabulary's own). `nil` on a digest
    /// mismatch, which withholds the door rather than sending a key that cannot land.
    private var bucketKey: String? {
        guard let vocabulary = DocumentSubjectStore.shared?.bucketVocabulary,
              let id = vocabulary.id(category: subject.category, subcategory: subject.subcategory)
        else { return nil }
        return vocabulary.key(at: id)
    }

    /// Opens a covering volume in the browser (the pivot sheet's `open` shape).
    private func openVolume(_ volumeId: String) {
        appState.openBrowseVolume(volumeId, from: sceneID)
        #if os(macOS)
        openWindow.fronting(id: "frus.corpusBrowser")
        #else
        appState.openTab(.browse, from: sceneID)
        #endif
        dismiss()
    }

    /// Sends the `.group` arrival back to the index (#1051 B-6), with the #833 ordering.
    private func browseTopicArea(_ key: String) {
        #if os(macOS)
        appState.openSubjectExplorer(.group(categoryKey: key), from: sceneID)
        openWindow.fronting(id: "frus.subjects")
        dismiss()
        #else
        // Dismiss first, hand off on the next turn — the presenting index consumes the
        // request through its host's drain and re-applies it (#833).
        dismiss()
        Task { @MainActor in
            appState.openSubjectExplorer(.group(categoryKey: key), from: sceneID)
        }
        #endif
    }

    /// Three states, not two — the third is the one people forget. A count that could not be taken
    /// is unknown, and reporting it as zero would tell the reader this device has nothing on a
    /// subject it may be full of.
    private var deviceCountText: String {
        if counting {
            return String(localized: "subjects.detail.counting", defaultValue: "Counting…")
        }
        guard let deviceCount else {
            return String(localized: "subjects.detail.countUnavailable", defaultValue: "Not counted")
        }
        return deviceCount.formatted()
    }

    private func countOnThisDevice() async {
        defer { counting = false }
        guard let service = appState.searchService else { return }
        var params = SearchParameters()
        params.subjectRef = subject.ref
        params.subjectName = subject.name
        deviceCount = try? await service.searchCount(parameters: params)
    }

    /// Hands the subject to Search as a filter-only query, carrying BOTH halves of the durable key.
    private func findDocuments() {
        var params = SearchParameters()
        params.subjectRef = subject.ref
        params.subjectName = subject.name
        #if os(macOS)
        appState.openSearch(params, from: sceneID)
        openWindow.fronting(id: "frus.search")
        dismiss()
        #else
        // iOS presents Search from the tab shell, and dismissing one sheet while presenting another
        // in the same state change drops the second — the #833 lesson. Dismiss, then hand off.
        dismiss()
        Task { @MainActor in
            appState.openSearch(params, from: sceneID)
        }
        #endif
    }
}
