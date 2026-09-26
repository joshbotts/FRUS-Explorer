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
import SwiftData

// MARK: - ArchiveVisitListView

/// The Archive Visits list — full CRUD over the persistent plans (design §4a, artboard 1a).
///
/// Mirrors `WorkingCorporaView`, not `CollectionListView`: the same row anatomy (`.body` name,
/// `.caption` summary, orange-when-incomplete coverage line), rename through an `.alert` +
/// `TextField`, and — from the sibling `CustomScopesView` — the end-of-list New row (S-3b's
/// rule: never a nav-bar `+`) and the swipe-arms-a-confirmation delete, because deletion here
/// cascades over children and a full swipe with no confirmation would destroy a hand-built
/// plan in one gesture.
///
/// Hosted inside a `NavigationStack` by the iOS Research-tab sheet; row taps and creation
/// both route through `.navigationDestination(item:)` so a freshly created plan opens
/// immediately. The macOS `frus.archiveVisits` window no longer hosts this list — it is
/// `MacArchiveVisitManagerView`, the Collections window's flat-pane shape (UI pass).
///
/// Version history:
///   1.0 — Archive Visits Phase 3: initial implementation
///   1.1 — UI pass: iOS-only (the Mac window moved to `MacArchiveVisitManagerView`);
///         counts through `.formatted()`.
///   1.2 — #1366: New Archives Visit creates through `ArchiveVisitPlan.make`, so the plan
///         belongs to the active project and carries its research question as the topic.
///   1.3 — #1458: the row's "N targets · M repositories" is `ArchiveVisitCounts.listSummary`, the
///         count the editor's summary reads, presidential libraries included.
///   1.4 — #1456 review, round 1: a row's summary is derived and cached under the plan's
///         `ArchiveVisitDerivation.InputSignature` (``SummaryKey``), not its `lastModified`, which a
///         seed's flag and a seed's volume finishing indexing never move.
struct ArchiveVisitListView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ArchiveVisitPlan.lastModified, order: .reverse)
    private var plans: [ArchiveVisitPlan]

    @State private var renaming: ArchiveVisitPlan?
    @State private var draftName = ""
    @State private var deleting: ArchiveVisitPlan?
    @State private var opened: ArchiveVisitPlan?
    /// Per-plan derived summary ("23 targets · 3 repositories"), filled asynchronously and cached
    /// under ``SummaryKey``, so a change to anything the derivation reads invalidates the line.
    @State private var summaries: [SummaryKey: String] = [:]

    /// What a row's summary is derived and cached under (#1456 review, round 1): the plan, and
    /// everything the derivation reads from it and which of its seed volumes are indexed
    /// (``ArchiveVisitDerivation/InputSignature``) — the editor's own key, less its counter.
    ///
    /// It was the plan's id and `lastModified`, and `ModelModificationStamper` stamps only the rows
    /// a save changed. A seed's flag turned off in the editor changes the seed row alone, and a seed's
    /// volume finishing indexing changes no row at all, so the row kept "0 targets" beside a coverage
    /// line that had already gone, until the list was reopened. A rename moved that key and
    /// re-derived for nothing; the derivation never reads the name.
    private struct SummaryKey: Hashable {
        /// The plan.
        let planId: UUID
        /// Everything the derivation reads from it.
        let inputs: ArchiveVisitDerivation.InputSignature
    }

    var body: some View {
        List {
            if plans.isEmpty {
                Section {
                    ContentUnavailableView(
                        String(localized: "archiveVisit.empty.title",
                               defaultValue: "No Archives Visits"),
                        systemImage: "building.columns",
                        description: Text(String(
                            localized: "archiveVisit.empty.detail",
                            defaultValue: "An Archives Visit turns documents’ source notes into a research-trip plan. Seed one from Source Explorer, Archival Neighbors, a collection, or a project — or start empty below.")))
                }
            } else {
                Section {
                    ForEach(plans) { plan in row(plan) }
                } footer: {
                    Text(String(localized: "archiveVisit.list.footer",
                                defaultValue: "An Archives Visit is your plan for consulting the records behind these documents — what to see, in what order, at which repository. The whole plan syncs to your other devices."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // S-3b: every list ends with its New row — reachable from the empty state too.
            Section {
                SettingsNewItemRow(label: String(localized: "archiveVisit.new",
                                                 defaultValue: "New Archives Visit")) {
                    // #1366: under the active project, with its research question as the topic.
                    let plan = ArchiveVisitPlan.make(name: "",
                                                     activeProjectId: appState.activeProjectId,
                                                     in: modelContext)
                    modelContext.insert(plan)
                    try? modelContext.save()
                    opened = plan
                }
            }
        }
        .navigationTitle(String(localized: "archiveVisit.list.title",
                                defaultValue: "Archives Visits"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationDestination(item: $opened) { plan in
            ArchiveVisitEditorView(plan: plan)
        }
        .alert(String(localized: "archiveVisit.rename.title",
                      defaultValue: "Rename Archives Visit"),
               isPresented: Binding(get: { renaming != nil },
                                    set: { if !$0 { renaming = nil } })) {
            TextField(String(localized: "archiveVisit.rename.placeholder", defaultValue: "Name"),
                      text: $draftName)
            Button(String(localized: "common.cancel", defaultValue: "Cancel"), role: .cancel) {
                renaming = nil
            }
            Button(String(localized: "common.save", defaultValue: "Save")) { commitRename() }
        }
        .confirmationDialog(
            String(localized: "archiveVisit.delete.title",
                   defaultValue: "Delete this Archives Visit?"),
            isPresented: Binding(get: { deleting != nil },
                                 set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible
        ) {
            Button(String(localized: "common.delete", defaultValue: "Delete"),
                   role: .destructive) { commitDelete() }
            Button(String(localized: "common.cancel", defaultValue: "Cancel"), role: .cancel) {
                deleting = nil
            }
        } message: {
            // The confirmation names what goes (§4a) — the plan AND its stored state, from
            // every device. Documents and volumes are untouched.
            Text(String(localized: "archiveVisit.delete.message",
                        defaultValue: "This deletes the plan, its priority tiers, and its per-target notes — from your other devices too, after sync. Documents and volumes are untouched."))
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func row(_ plan: ArchiveVisitPlan) -> some View {
        let seeds = (plan.documents ?? [])
        let indexed = seeds.filter { seed in
            guard let volumeId = seed.documentKey.split(separator: "/").first else { return false }
            return appState.indexedVolumeIds.contains(String(volumeId))
        }.count
        // Computed in the body, as the editor computes its key, so the body observes every seed,
        // state row and the indexed set, and re-runs the task below when one of them changes.
        let key = summaryKey(for: plan)
        Button {
            opened = plan
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(plan.displayName).font(.body).foregroundStyle(.primary)
                Text(summaryLine(plan, cachedUnder: key))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if indexed < seeds.count {
                    // The both-numbers grammar, orange when incomplete (1a / WorkingCorpora);
                    // counts grouped — a unit-grain seed can run to 20,000 documents — and the
                    // total singular at one, where a one-document plan read "0 of 1 documents"
                    // (#1374 review, round 1).
                    Text(String(localized: "archiveVisit.coverage.v3",
                                defaultValue: "\(indexed.formatted()) of \(CountCopy.documents(seeds.count)) indexed on this device"))
                        .font(.caption)
                        .foregroundStyle(Color.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .task(id: key) { await loadSummary(plan, cachingUnder: key) }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                deleting = plan
            } label: {
                Label(String(localized: "common.delete", defaultValue: "Delete"),
                      systemImage: "trash")
            }
        }
        .contextMenu {
            Button {
                draftName = plan.name
                renaming = plan
            } label: {
                Label(String(localized: "common.rename", defaultValue: "Rename"),
                      systemImage: "pencil")
            }
            Button {
                let copy = plan.duplicate(in: modelContext)
                try? modelContext.save()
                opened = copy
            } label: {
                Label(String(localized: "common.duplicate", defaultValue: "Duplicate"),
                      systemImage: "plus.square.on.square")
            }
            Button(role: .destructive) {
                deleting = plan
            } label: {
                Label(String(localized: "common.delete", defaultValue: "Delete"),
                      systemImage: "trash")
            }
        }
    }

    /// The row's summary — the derived "N targets · M repositories" once known under `key`, the
    /// seed count until then, and the modification date always.
    private func summaryLine(_ plan: ArchiveVisitPlan, cachedUnder key: SummaryKey) -> String {
        var parts: [String] = []
        if let derived = summaries[key] {
            parts.append(derived)
        } else {
            // #1374 review, round 1: a one-document plan read "1 documents" until its summary
            // was derived, then "1 target · 1 repository".
            parts.append(CountCopy.documents((plan.documents ?? []).count))
        }
        if let modified = plan.lastModified {
            parts.append(String(format: String(localized: "archiveVisit.list.modified %@",
                                               defaultValue: "Modified %@"),
                                modified.formatted(date: .abbreviated, time: .omitted)))
        }
        return parts.joined(separator: " · ")
    }

    /// `plan`'s ``SummaryKey`` over the device's indexed volumes — the set ``loadSummary(_:cachingUnder:)``
    /// hands the derivation.
    private func summaryKey(for plan: ArchiveVisitPlan) -> SummaryKey {
        SummaryKey(planId: plan.id,
                   inputs: ArchiveVisitDerivation.inputSignature(plan: plan,
                                                                 indexedVolumeIds: appState.indexedVolumeIds))
    }

    /// Derives the row's target/repository counts through the ONE derivation path — cached under
    /// `key`, so a plan whose inputs have not changed costs its queries once.
    private func loadSummary(_ plan: ArchiveVisitPlan, cachingUnder key: SummaryKey) async {
        guard summaries[key] == nil, !(plan.documents ?? []).isEmpty,
              let pipeline = appState.indexingPipeline else { return }
        let manifest = appState.manifestStore.diffResult?.known
            ?? appState.manifestStore.bundledEntries
        let derived = await ArchiveVisitDerivation.derive(
            plan: plan,
            indexedVolumeIds: appState.indexedVolumeIds,
            dataSource: TripPacketDataSource(
                pipeline: pipeline,
                manifestMap: Dictionary(manifest.map { ($0.volumeId, $0) },
                                        uniquingKeysWith: { first, _ in first })))
        // #1374: through `CountCopy`, like the editor's summary — this row read
        // "8 targets · 1 repositories" beside a packet that says "1 repository". #1458: the same
        // function counts the repositories the editor's sections draw.
        summaries[key] = ArchiveVisitCounts.listSummary(of: derived.model)
    }

    // MARK: - Actions

    private func commitRename() {
        guard let plan = renaming else { return }
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        // An empty commit is ignored rather than clearing to Untitled — matching the
        // WorkingCorpora rule; `lastModified` moves via the save-time stamper.
        if !trimmed.isEmpty { plan.rename(to: trimmed) }
        try? modelContext.save()
        renaming = nil
    }

    private func commitDelete() {
        guard let plan = deleting else { return }
        // Through the explicit cascade — the `.nullify` relationships would orphan every
        // child row under a bare delete (§4a).
        plan.deleteWithChildren(in: modelContext)
        try? modelContext.save()
        deleting = nil
    }
}
