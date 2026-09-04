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
struct ArchiveVisitListView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ArchiveVisitPlan.lastModified, order: .reverse)
    private var plans: [ArchiveVisitPlan]

    @State private var renaming: ArchiveVisitPlan?
    @State private var draftName = ""
    @State private var deleting: ArchiveVisitPlan?
    @State private var opened: ArchiveVisitPlan?
    /// Per-plan derived summary ("23 targets · 3 repositories"), filled asynchronously —
    /// keyed on id + lastModified so an edit invalidates the cached line.
    @State private var summaries: [String: String] = [:]

    var body: some View {
        List {
            if plans.isEmpty {
                Section {
                    ContentUnavailableView(
                        String(localized: "archiveVisit.empty.title",
                               defaultValue: "No Archive Visits"),
                        systemImage: "building.columns",
                        description: Text(String(
                            localized: "archiveVisit.empty.detail",
                            defaultValue: "An Archive Visit turns documents’ source notes into a research-trip plan. Seed one from Source Explorer, Archival Neighbors, a collection, or a project — or start empty below.")))
                }
            } else {
                Section {
                    ForEach(plans) { plan in row(plan) }
                } footer: {
                    Text(String(localized: "archiveVisit.list.footer",
                                defaultValue: "An Archive Visit is your plan for consulting the records behind these documents — what to see, in what order, at which repository. The whole plan syncs to your other devices."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // S-3b: every list ends with its New row — reachable from the empty state too.
            Section {
                SettingsNewItemRow(label: String(localized: "archiveVisit.new",
                                                 defaultValue: "New Archive Visit")) {
                    let plan = ArchiveVisitPlan(name: "")
                    modelContext.insert(plan)
                    try? modelContext.save()
                    opened = plan
                }
            }
        }
        .navigationTitle(String(localized: "archiveVisit.list.title",
                                defaultValue: "Archive Visits"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationDestination(item: $opened) { plan in
            ArchiveVisitEditorView(plan: plan)
        }
        .alert(String(localized: "archiveVisit.rename.title",
                      defaultValue: "Rename Archive Visit"),
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
                   defaultValue: "Delete this Archive Visit?"),
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
        Button {
            opened = plan
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(plan.displayName).font(.body).foregroundStyle(.primary)
                Text(summaryLine(plan))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if indexed < seeds.count {
                    // The both-numbers grammar, orange when incomplete (1a / WorkingCorpora);
                    // counts grouped — a unit-grain seed can run to 20,000 documents.
                    Text(String(localized: "archiveVisit.coverage.v2",
                                defaultValue: "\(indexed.formatted()) of \(seeds.count.formatted()) documents indexed on this device"))
                        .font(.caption)
                        .foregroundStyle(Color.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .task(id: summaryTaskKey(plan)) { await loadSummary(plan) }
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

    /// The row's summary — the derived "N targets · M repositories" once known, the seed
    /// count until then, and the modification date always.
    private func summaryLine(_ plan: ArchiveVisitPlan) -> String {
        var parts: [String] = []
        if let derived = summaries[summaryTaskKey(plan)] {
            parts.append(derived)
        } else {
            let count = (plan.documents ?? []).count
            parts.append(String(localized: "archiveVisit.list.docCount.v2",
                                defaultValue: "\(count.formatted()) documents"))
        }
        if let modified = plan.lastModified {
            parts.append(String(format: String(localized: "archiveVisit.list.modified %@",
                                               defaultValue: "Modified %@"),
                                modified.formatted(date: .abbreviated, time: .omitted)))
        }
        return parts.joined(separator: " · ")
    }

    private func summaryTaskKey(_ plan: ArchiveVisitPlan) -> String {
        "\(plan.id)|\(plan.lastModified?.timeIntervalSince1970 ?? 0)"
    }

    /// Derives the row's target/repository counts through the ONE derivation path — cached
    /// per (plan, lastModified), so an unchanged plan costs its queries once.
    private func loadSummary(_ plan: ArchiveVisitPlan) async {
        let key = summaryTaskKey(plan)
        guard summaries[key] == nil, !(plan.documents ?? []).isEmpty,
              let pipeline = appState.indexingPipeline else { return }
        let manifest = appState.manifestStore.diffResult?.known
            ?? appState.manifestStore.bundledEntries
        let derived = await ArchiveVisitDerivation.derive(
            plan: plan,
            indexedVolumeIds: Set(appState.indexedVolumeIds),
            dataSource: TripPacketDataSource(
                pipeline: pipeline,
                manifestMap: Dictionary(manifest.map { ($0.volumeId, $0) },
                                        uniquingKeysWith: { first, _ in first })))
        let targets = derived.model.targets.count
        let repositories = Set(derived.model.targets.compactMap(\.facility.chapterHeading)).count
        summaries[key] = String(format: String(
            localized: "archiveVisit.list.summary %lld %lld",
            defaultValue: "%lld targets · %lld repositories"),
            Int64(targets), Int64(repositories))
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
