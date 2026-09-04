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

// MARK: - ArchiveVisitEditorView

/// The plan editor — a TARGET list, not a document list (design §4, artboard 1b), with the
/// seed list as its secondary tab (1d).
///
/// ## The honesty rules this screen carries
/// - **Claim counts never sum** (§3d): a target reads "drawn from 3 · pointed at by 2", and the
///   two lists render under their own labeled headings with verbatim context.
/// - **Restriction is a line, not a badge**: worst covered status + the series it belongs to +
///   the unmeasured claimant count.
/// - **A claim with nothing behind it never renders a dead control** (1d): an absent half is a
///   caption, and a document with both halves off carries the contributes-nothing warning.
/// - **Orphans are kept and labeled, never deleted**: a stored row whose key no longer derives
///   from the seeds renders under its own heading with its tier and notes intact.
/// - **Coverage in both numbers, orange when incomplete** — the `WorkingCorpusResolver` grammar.
///
/// State mutations write the plan (minting overlay rows through `targetState(forKey:)` — §2a:
/// a row exists only once the user gives a target state) and re-derive through the ONE
/// derivation path the list row and the export sheet also use.
///
/// Version history:
///   1.0 — Archive Visits Phase 3: initial implementation
///   1.1 — Archive Visits UI pass (adversarial review vs the Collections-editor conventions):
///         macOS drops the in-body header for toolbar chrome (tab picker at `.principal`,
///         filters in a toolbar menu, checkbox toggles, Rename… in the More menu) and is
///         hosted by `MacArchiveVisitManagerView` as a detail pane; iOS buffers the inline
///         rename and consolidates the compact toolbar into one labeled menu. Citations
///         render their Markdown italics instead of literal underscores, counts go through
///         `.formatted()`, seed/tier rows gain context menus and `.onDelete`, stale filters
///         reset after derivation, and destructive orphan-state removal confirms first.
struct ArchiveVisitEditorView: View {

    let plan: ArchiveVisitPlan

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    /// Routes a seed row's Open Document (#755's rule: every document list reaches the reader).
    @Environment(\.openWindow) private var openWindow
    @Environment(\.sceneID) private var sceneID
    #if os(iOS)
    /// Compact width consolidates the toolbar into one labeled menu (the Collections
    /// editor's `collectionAuthoringToolbar` rule).
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    /// The two tabs (1b/1d).
    private enum Tab: Hashable { case targets, documents }
    /// The tier filter's three shapes.
    private enum TierFilter: Hashable { case all, tier(UUID), unprioritized }
    /// The claim filter (1b's chips).
    private enum ClaimFilter: Hashable { case all, drawnFrom, pointedAt }

    /// Per-seed facts for the Documents tab — which halves exist, and the row's label
    /// (the document's header + volume title; the full publication citation is
    /// export-grade verbosity in a row list, and its Markdown markers rendered literally).
    private struct SeedFacts {
        var header: String?
        var volumeTitle: String?
        var hasSourceNote: Bool
        var referenceCount: Int
    }

    @State private var tab: Tab = .targets
    @State private var derived: ArchiveVisitDerivation.Derived?
    @State private var seedFacts: [String: SeedFacts] = [:]
    /// The live index's pointed-at sparsity (Phase 4): documents with lot/library footnote
    /// references over all indexed documents — the measured local fact the sparsity
    /// captions state beside the corpus-wide claim. `nil` until measured.
    @State private var sparsity: (withReferences: Int, indexed: Int)?
    @State private var isDeriving = true
    /// Bumped on every plan mutation; the derivation task re-runs on it.
    @State private var revision = 0

    @State private var repositoryFilter: String?
    @State private var tierFilter: TierFilter = .all
    @State private var claimFilter: ClaimFilter = .all
    @State private var includedOnly = false

    @State private var showInfo = false
    @State private var showTiers = false
    @State private var showShare = false
    @State private var showDeleteConfirm = false
    /// iOS inline rename buffer — committed on submit, never written per keystroke.
    @State private var nameDraft = ""
    #if os(macOS)
    /// macOS renames through an explicit alert (the More menu's Rename…), matching the
    /// plan list; the Mac editor has no in-body name field.
    @State private var showRenameAlert = false
    #endif
    /// Transient confirmation after Duplicate (the Collections editor's toast pattern) —
    /// without it the copy is created invisibly.
    @State private var duplicateToast: String?
    /// The orphan key whose stored state is pending removal — destructive (it deletes the
    /// user's tier and hand-typed note), so it confirms first.
    @State private var removingStoredKey: String?
    #if os(iOS)
    /// Compact width presents the About content as a sheet (a menu item cannot anchor a
    /// popover); regular width keeps the toolbar button's popover.
    @State private var showInfoSheet = false
    #endif
    /// The target key whose note is being edited, with the draft.
    @State private var noteEditingKey: String?
    @State private var noteDraft = ""

    var body: some View {
        VStack(spacing: 0) {
            // macOS carries no in-body header: the tab picker lives in the toolbar
            // (`.principal`) and the plan's name in the manager's picker — the Collections
            // window's shape. The iOS header keeps the inline rename + segmented tabs.
            #if os(iOS)
            header
            Divider()
            #endif
            content
        }
        #if os(iOS)
        // The screen's ROLE, not the plan's name — the name is the editable field right
        // below, and printing it twice made the field read as a redundant static title.
        .navigationTitle(String(localized: "archiveVisit.editor.title",
                                defaultValue: "Archive Visit"))
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { editorToolbar }
        .transientToast($duplicateToast)
        .task(id: revision) { await derive() }
        // Recovery for an editor opened before the search index boots: the boot placeholder
        // stays up (derive() returns with `isDeriving` still true) and this re-derives the
        // moment the pipeline appears — without it the editor rendered permanently blank.
        .onChange(of: appState.indexingPipeline == nil) { _, isNil in
            if !isNil { bump() }
        }
        #if os(iOS)
        .task(id: plan.id) { nameDraft = plan.name }
        .sheet(isPresented: $showInfoSheet) { infoPopover }
        #endif
        #if os(macOS)
        .alert(String(localized: "archiveVisit.rename.title",
                      defaultValue: "Rename Archive Visit"),
               isPresented: $showRenameAlert) {
            TextField(String(localized: "archiveVisit.rename.placeholder", defaultValue: "Name"),
                      text: $nameDraft)
            Button(String(localized: "common.cancel", defaultValue: "Cancel"), role: .cancel) {}
            Button(String(localized: "common.save", defaultValue: "Save")) { commitRename() }
        }
        #endif
        .confirmationDialog(
            String(localized: "archiveVisit.orphan.remove.title",
                   defaultValue: "Remove this stored target?"),
            isPresented: Binding(get: { removingStoredKey != nil },
                                 set: { if !$0 { removingStoredKey = nil } }),
            titleVisibility: .visible
        ) {
            Button(String(localized: "archiveVisit.target.removeStored",
                          defaultValue: "Remove Stored State"), role: .destructive) {
                if let key = removingStoredKey { removeStoredState(forKey: key) }
                removingStoredKey = nil
            }
            Button(String(localized: "common.cancel", defaultValue: "Cancel"), role: .cancel) {
                removingStoredKey = nil
            }
        } message: {
            Text(String(localized: "archiveVisit.orphan.remove.message",
                        defaultValue: "Its tier and note are deleted — from your other devices too, after sync. Nothing else in the plan changes."))
        }
        .sheet(isPresented: $showTiers, onDismiss: { bump() }) {
            ArchiveVisitTierSheet(plan: plan)
        }
        .sheet(isPresented: $showShare) {
            TripPacketSheet(seed: .plan(plan), title: plan.displayName, researchQuestion: nil)
                .environment(appState)
        }
        .alert(String(localized: "archiveVisit.note.title", defaultValue: "Target Note"),
               isPresented: Binding(get: { noteEditingKey != nil },
                                    set: { if !$0 { noteEditingKey = nil } })) {
            TextField(String(localized: "archiveVisit.note.placeholder", defaultValue: "Note"),
                      text: $noteDraft)
            Button(String(localized: "common.cancel", defaultValue: "Cancel"), role: .cancel) {
                noteEditingKey = nil
            }
            Button(String(localized: "common.save", defaultValue: "Save")) { commitNote() }
        }
        .confirmationDialog(
            String(localized: "archiveVisit.delete.title",
                   defaultValue: "Delete this Archive Visit?"),
            isPresented: $showDeleteConfirm, titleVisibility: .visible
        ) {
            Button(String(localized: "common.delete", defaultValue: "Delete"),
                   role: .destructive) {
                plan.deleteWithChildren(in: modelContext)
                try? modelContext.save()
                dismiss()
            }
            Button(String(localized: "common.cancel", defaultValue: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "archiveVisit.delete.message",
                        defaultValue: "This deletes the plan, its priority tiers, and its per-target notes — from your other devices too, after sync. Documents and volumes are untouched."))
        }
    }

    // MARK: - Header: inline rename + tabs (iOS)

    #if os(iOS)
    /// The iOS editor header: the inline name field and the Targets/Documents picker,
    /// leading-aligned with the content column. The name edits a local DRAFT and commits
    /// through `rename(to:)` on submit — never per keystroke, and an empty commit reverts
    /// rather than clearing to Untitled (the plan list's own rule).
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(ArchiveVisitPlan.untitledName, text: $nameDraft)
                .textFieldStyle(.plain)
                .font(.headline)
                .onSubmit { commitRename() }
                .accessibilityLabel(String(localized: "archiveVisit.editor.name.a11y",
                                           defaultValue: "Archive visit name"))
            tabPicker
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
    #endif

    /// The Targets/Documents switcher — in the iOS header, and in the macOS toolbar at
    /// `.principal` (the segmented control renders natively in the Mac title bar).
    private var tabPicker: some View {
        Picker(String(localized: "archiveVisit.editor.tab", defaultValue: "View"),
               selection: $tab) {
            Text(String(localized: "archiveVisit.editor.tab.targets",
                        defaultValue: "Targets")).tag(Tab.targets)
            Text(String(localized: "archiveVisit.editor.tab.documents",
                        defaultValue: "Documents")).tag(Tab.documents)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    /// Commits the buffered rename: trimmed non-empty renames through `rename(to:)` (the
    /// stamper moves `lastModified` at save); an empty draft reverts to the current name.
    private func commitRename() {
        let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            nameDraft = plan.name
        } else if trimmed != plan.name {
            plan.rename(to: trimmed)
            try? modelContext.save()
        }
    }

    @ViewBuilder
    private var content: some View {
        if isDeriving && derived == nil {
            BootPlaceholderView(detail: String(
                localized: "archiveVisit.editor.deriving",
                defaultValue: "Deriving research targets from the plan’s documents…"))
                .frame(maxHeight: .infinity)
        } else {
            switch tab {
            case .targets: targetsTab
            case .documents: documentsTab
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var editorToolbar: some ToolbarContent {
        #if os(macOS)
        // macOS: the tab switcher and filters belong to the window chrome (the Collections
        // window's rule) — the segmented control at `.principal`, the Targets-tab filters
        // as one toolbar menu, and the actions as labeled items.
        ToolbarItem(placement: .principal) { tabPicker }
        ToolbarItem(placement: .primaryAction) { filterToolbarMenu }
        exportToolbarItem
        infoToolbarItem
        moreToolbarItem
        #else
        if sizeClass == .compact {
            // iPhone: ONE labeled menu (the `collectionAuthoringToolbar` rule — never a
            // row of bare glyphs in a compact nav bar). About presents as a sheet, since
            // a menu item cannot anchor a popover.
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showShare = true
                    } label: {
                        Label(String(localized: "archiveVisit.editor.export",
                                     defaultValue: "Export packet"),
                              systemImage: "square.and.arrow.up")
                    }
                    .disabled((plan.documents ?? []).isEmpty)
                    Button {
                        showInfoSheet = true
                    } label: {
                        Label(String(localized: "archiveVisit.editor.about",
                                     defaultValue: "About research targets"),
                              systemImage: "info.circle")
                    }
                    Divider()
                    moreMenuItems
                } label: {
                    Label(String(localized: "archiveVisit.editor.menu",
                                 defaultValue: "Menu"),
                          systemImage: "ellipsis.circle")
                }
            }
        } else {
            exportToolbarItem
            infoToolbarItem
            moreToolbarItem
        }
        #endif
    }

    /// Export — disabled while the plan has nothing to export (the sheet's own guard stays
    /// as belt-and-braces).
    private var exportToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showShare = true
            } label: {
                Label(String(localized: "archiveVisit.editor.export",
                             defaultValue: "Export packet"),
                      systemImage: "square.and.arrow.up")
            }
            .disabled((plan.documents ?? []).isEmpty)
        }
    }

    private var infoToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showInfo = true
            } label: {
                Label(String(localized: "archiveVisit.editor.about",
                             defaultValue: "About research targets"),
                      systemImage: "info.circle")
            }
            .popover(isPresented: $showInfo) { infoPopover }
        }
    }

    private var moreToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .secondaryAction) {
            Menu {
                moreMenuItems
            } label: {
                Label(String(localized: "archiveVisit.editor.more", defaultValue: "More"),
                      systemImage: "ellipsis.circle")
            }
        }
    }

    /// The overflow actions, shared by the regular-width menu and the compact consolidated
    /// menu so the two cannot drift.
    @ViewBuilder
    private var moreMenuItems: some View {
        #if os(macOS)
        // macOS has no in-body name field — rename is an explicit command here, matching
        // the plan list's alert.
        Button {
            nameDraft = plan.name
            showRenameAlert = true
        } label: {
            Label(String(localized: "common.rename", defaultValue: "Rename"),
                  systemImage: "pencil")
        }
        #endif
        Button {
            showTiers = true
        } label: {
            Label(String(localized: "archiveVisit.editor.tiers",
                         defaultValue: "Priority Tiers…"),
                  systemImage: "list.number")
        }
        Button {
            duplicatePlan()
        } label: {
            Label(String(localized: "common.duplicate", defaultValue: "Duplicate"),
                  systemImage: "plus.square.on.square")
        }
        if let projectId = plan.projectIds.first {
            // 1e: an explicit re-seed, never a live mirror — the plan is the
            // researcher's edit surface, and only this button moves seeds again.
            Button {
                Task { await reseed(fromProject: projectId) }
            } label: {
                Label(String(localized: "archiveVisit.editor.reseed",
                             defaultValue: "Re-seed from Project"),
                      systemImage: "arrow.triangle.2.circlepath")
            }
        }
        Divider()
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            Label(String(localized: "common.delete", defaultValue: "Delete"),
                  systemImage: "trash")
        }
    }

    /// Duplicates the plan with visible feedback — the copy used to be created invisibly.
    private func duplicatePlan() {
        let copy = plan.duplicate(in: modelContext)
        try? modelContext.save()
        duplicateToast = String(localized: "archiveVisit.duplicate.toast",
                                defaultValue: "Duplicated as “\(copy.displayName)”")
    }

    #if os(macOS)
    /// The Targets-tab filters as ONE toolbar menu (the iOS chip strip stays iOS-only) —
    /// meaningless on the Documents tab, so disabled there rather than vanishing.
    private var filterToolbarMenu: some View {
        Menu {
            if let derived {
                Picker(String(localized: "archiveVisit.filter.repository",
                              defaultValue: "Repository"), selection: $repositoryFilter) {
                    Text(String(localized: "archiveVisit.filter.all", defaultValue: "All"))
                        .tag(String?.none)
                    ForEach(facilityHeadings(derived), id: \.self) { facility in
                        Text(facility).tag(String?.some(facility))
                    }
                }
                Picker(String(localized: "archiveVisit.filter.tier",
                              defaultValue: "Tier"), selection: $tierFilter) {
                    Text(String(localized: "archiveVisit.filter.all", defaultValue: "All"))
                        .tag(TierFilter.all)
                    ForEach(derived.overlay.tiers) { tier in
                        Text(derived.overlay.displayName(for: tier))
                            .tag(TierFilter.tier(tier.id))
                    }
                    Text(String(localized: "archiveVisit.tier.unprioritized",
                                defaultValue: "Unprioritized"))
                        .tag(TierFilter.unprioritized)
                }
                Picker(String(localized: "archiveVisit.filter.claim",
                              defaultValue: "Claim"), selection: $claimFilter) {
                    Text(String(localized: "archiveVisit.filter.all", defaultValue: "All"))
                        .tag(ClaimFilter.all)
                    Text(String(localized: "archiveVisit.claim.drawnFrom",
                                defaultValue: "Drawn from")).tag(ClaimFilter.drawnFrom)
                    Text(String(localized: "archiveVisit.claim.pointedAt",
                                defaultValue: "Pointed at")).tag(ClaimFilter.pointedAt)
                }
                Divider()
                Toggle(String(localized: "archiveVisit.filter.includedOnly",
                              defaultValue: "Included only"), isOn: $includedOnly)
            }
        } label: {
            Label(String(localized: "archiveVisit.filter.menu", defaultValue: "Filter"),
                  systemImage: hasActiveFilters
                      ? "line.3.horizontal.decrease.circle.fill"
                      : "line.3.horizontal.decrease.circle")
        }
        .disabled(tab == .documents || derived == nil)
    }
    #endif

    /// Whether any Targets-tab filter narrows the list — drives the toolbar glyph's fill.
    private var hasActiveFilters: Bool {
        repositoryFilter != nil || tierFilter != .all || claimFilter != .all || includedOnly
    }

    /// The 1b info popover: the claim definitions and the never-summed rule, stated once.
    private var infoPopover: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "archiveVisit.info.title",
                            defaultValue: "About research targets"))
                    .font(.headline)
                Text(String(localized: "archiveVisit.info.body",
                            defaultValue: "A target is one archival unit under one claim. Drawn from: the document was published from this file — its own source note. Pointed at: the document’s footnotes cite this, unprinted. One document can seed several targets, each prioritized on its own; the two counts are never added because they answer different questions. A row is stored only once you give it a tier, a note, or an exclusion — the rest derives from the seeds each time, so it stays right as volumes index."))
                    .font(.callout)
                Text(String(localized: "archiveVisit.info.sparsity",
                            defaultValue: "Footnote references to unprinted material exist on only about 4% of documents corpus-wide (measured over the full index: 13,750 of 316,839), so a thin pointed-at list is expected — sparse data, not a failed scan."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if let sparsity, sparsity.indexed > 0 {
                    // Phase 4: the measured local fact, in the both-numbers grammar —
                    // beside the corpus claim, never replacing it (the two describe
                    // different populations). Grouped digits, matching the static
                    // sentence directly above ("13,750 of 316,839").
                    Text(measuredSparsityLine(sparsity))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .frame(minWidth: 280, idealWidth: 340, minHeight: 200)
        .presentationDetents([.medium])
    }

    // MARK: - Targets tab (1b)

    private var targetsTab: some View {
        List {
            summarySection
            if let derived {
                if (plan.documents ?? []).isEmpty {
                    Section { noSeedsView }
                } else if derived.model.targets.isEmpty {
                    Section {
                        Text(noTargetsExplanation(derived))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                } else if visibleTargets(derived).isEmpty {
                    // Targets exist but every one is filtered out — say so, or a stale
                    // filter (a deleted tier, a vanished repository) reads as an empty plan.
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(String(localized: "archiveVisit.editor.noMatches",
                                        defaultValue: "No targets match the current filters."))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Button(String(localized: "archiveVisit.filter.clear",
                                          defaultValue: "Clear Filters")) {
                                clearFilters()
                            }
                            .font(.callout)
                        }
                    }
                } else {
                    facilitySections(derived)
                    orphanSection(derived)
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
    }

    /// The shared no-seeds empty state — ONE view for both tabs, so the two cannot drift.
    private var noSeedsView: some View {
        ContentUnavailableView(
            String(localized: "archiveVisit.editor.noSeeds.title",
                   defaultValue: "No documents seeded"),
            systemImage: "building.columns",
            description: Text(String(
                localized: "archiveVisit.editor.noSeeds.detail",
                defaultValue: "Seed this plan from Source Explorer, Archival Neighbors, a collection, or a project — each surface offers Add to Archive Visit.")))
    }

    /// Resets every Targets-tab filter to its unfiltered state.
    private func clearFilters() {
        repositoryFilter = nil
        tierFilter = .all
        claimFilter = .all
        includedOnly = false
    }

    /// The summary block: counts, the coverage line (orange when partial), and the filters.
    @ViewBuilder
    private var summarySection: some View {
        if let derived, !(plan.documents ?? []).isEmpty {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    let targets = derived.model.targets.count
                    let repositories = Set(derived.model.targets
                        .compactMap(\.facility.chapterHeading)).count
                    // Counts through .formatted() — a unit-grain seed can run to 20,000
                    // documents, and ungrouped five-digit numbers shipped once already.
                    Text(String(localized: "archiveVisit.editor.summary.v2",
                                defaultValue: "\(targets.formatted()) targets across \(repositories.formatted()) repositories."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if derived.indexedDocumentCount < derived.seededDocumentCount {
                        Text(String(localized: "archiveVisit.editor.coverage.v2",
                                    defaultValue: "\(derived.indexedDocumentCount.formatted()) of \(derived.seededDocumentCount.formatted()) seeding documents indexed on this device — targets from unindexed documents may be missing below."))
                            .font(.caption)
                            .foregroundStyle(Color.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    #if os(iOS)
                    // The chip strip is an iOS idiom; macOS filters from the toolbar menu.
                    filterRow(derived)
                    #endif
                }
            }
        }
    }

    /// The 1b filter chips: repository, tier, claim, included-only.
    private func filterRow(_ derived: ArchiveVisitDerivation.Derived) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    Picker(String(localized: "archiveVisit.filter.repository",
                                  defaultValue: "Repository"), selection: $repositoryFilter) {
                        Text(String(localized: "archiveVisit.filter.all", defaultValue: "All"))
                            .tag(String?.none)
                        ForEach(facilityHeadings(derived), id: \.self) { facility in
                            Text(facility).tag(String?.some(facility))
                        }
                    }
                } label: {
                    filterChip(String(localized: "archiveVisit.filter.repository",
                                      defaultValue: "Repository"),
                               value: repositoryFilter)
                }
                Menu {
                    Picker(String(localized: "archiveVisit.filter.tier",
                                  defaultValue: "Tier"), selection: $tierFilter) {
                        Text(String(localized: "archiveVisit.filter.all", defaultValue: "All"))
                            .tag(TierFilter.all)
                        ForEach(derived.overlay.tiers) { tier in
                            Text(derived.overlay.displayName(for: tier))
                                .tag(TierFilter.tier(tier.id))
                        }
                        Text(String(localized: "archiveVisit.tier.unprioritized",
                                    defaultValue: "Unprioritized"))
                            .tag(TierFilter.unprioritized)
                    }
                } label: {
                    filterChip(String(localized: "archiveVisit.filter.tier",
                                      defaultValue: "Tier"),
                               value: tierFilterLabel(derived))
                }
                Menu {
                    Picker(String(localized: "archiveVisit.filter.claim",
                                  defaultValue: "Claim"), selection: $claimFilter) {
                        Text(String(localized: "archiveVisit.filter.all", defaultValue: "All"))
                            .tag(ClaimFilter.all)
                        Text(String(localized: "archiveVisit.claim.drawnFrom",
                                    defaultValue: "Drawn from")).tag(ClaimFilter.drawnFrom)
                        Text(String(localized: "archiveVisit.claim.pointedAt",
                                    defaultValue: "Pointed at")).tag(ClaimFilter.pointedAt)
                    }
                } label: {
                    filterChip(String(localized: "archiveVisit.filter.claim",
                                      defaultValue: "Claim"),
                               value: claimFilterLabel)
                }
                Toggle(String(localized: "archiveVisit.filter.includedOnly",
                              defaultValue: "Included only"), isOn: $includedOnly)
                    .toggleStyle(.button)
                    .font(.caption)
            }
        }
    }

    private func filterChip(_ name: String, value: String?) -> some View {
        HStack(spacing: 3) {
            Text(value ?? name)
            Image(systemName: "chevron.down")
                .imageScale(.small)
        }
        .font(.caption)
    }

    private func tierFilterLabel(_ derived: ArchiveVisitDerivation.Derived) -> String? {
        switch tierFilter {
        case .all: return nil
        case .unprioritized:
            return String(localized: "archiveVisit.tier.unprioritized",
                          defaultValue: "Unprioritized")
        case .tier(let id):
            return derived.overlay.tiers.first { $0.id == id }
                .map { derived.overlay.displayName(for: $0) }
        }
    }

    private var claimFilterLabel: String? {
        switch claimFilter {
        case .all: return nil
        case .drawnFrom:
            return String(localized: "archiveVisit.claim.drawnFrom", defaultValue: "Drawn from")
        case .pointedAt:
            return String(localized: "archiveVisit.claim.pointedAt", defaultValue: "Pointed at")
        }
    }

    // MARK: - Facility sections

    /// A section's grouping key: the facility heading, or — for an unplaceable target — the
    /// cited repository's curated name, so a library heads its own section with its links
    /// (1b's LBJ section), falling back to the confirm-before-travel group.
    private func sectionKey(for target: TripPacketModel.Target) -> String {
        target.facility.chapterHeading
            ?? target.facts?.displayName
            ?? String(localized: "archiveVisit.section.unplaced",
                      defaultValue: "Confirm before you travel")
    }

    private func facilityHeadings(_ derived: ArchiveVisitDerivation.Derived) -> [String] {
        var seen = Set<String>()
        return derived.model.targets.map(sectionKey(for:))
            .filter { seen.insert($0).inserted }
    }

    private func visibleTargets(_ derived: ArchiveVisitDerivation.Derived)
        -> [TripPacketModel.Target] {
        derived.model.targets.filter { target in
            if let repositoryFilter, sectionKey(for: target) != repositoryFilter { return false }
            switch tierFilter {
            case .all: break
            case .unprioritized:
                if derived.overlay.tier(for: target.key) != nil { return false }
            case .tier(let id):
                if derived.overlay.tierAssignments[target.key] != id { return false }
            }
            switch claimFilter {
            case .all: break
            case .drawnFrom: if target.drawnFrom.isEmpty { return false }
            case .pointedAt: if target.pointedAt.isEmpty { return false }
            }
            if includedOnly, derived.overlay.excludedKeys.contains(target.key) { return false }
            return true
        }
    }

    @ViewBuilder
    private func facilitySections(_ derived: ArchiveVisitDerivation.Derived) -> some View {
        let visible = visibleTargets(derived)
        let sections = facilityHeadings(derived).filter { heading in
            visible.contains { sectionKey(for: $0) == heading }
        }
        ForEach(sections, id: \.self) { heading in
            Section {
                // Within a repository: tier groups in order, Unprioritized last (§5),
                // label-sorted within a group — the exporter's own ordering.
                let members = visible.filter { sectionKey(for: $0) == heading }
                    .sorted {
                        let l = derived.overlay.tierOrderIndex(for: $0.key)
                        let r = derived.overlay.tierOrderIndex(for: $1.key)
                        if l != r { return l < r }
                        return $0.label < $1.label
                    }
                ForEach(members, id: \.key) { target in
                    targetRow(target, derived: derived)
                }
            } header: {
                sectionHeader(heading, derived: derived)
            }
        }
    }

    /// A repository section header: the name plus its (a) links — a link renders only with a
    /// `verifiedDate` (D12; `linkLines` is the exporter's own gate, reused so no second rule).
    private func sectionHeader(_ heading: String,
                               derived: ArchiveVisitDerivation.Derived) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(heading)
            let row = RepositoryFactTable.current.row(for: heading)
            if let row {
                ForEach(row.links.filter(\.isPrintable), id: \.url) { link in
                    if let url = URL(string: link.url) {
                        Link(link.label, destination: url)
                            .font(.caption)
                            .textCase(nil)
                    }
                }
            }
        }
    }

    // MARK: - Target rows

    @ViewBuilder
    private func targetRow(_ target: TripPacketModel.Target,
                           derived: ArchiveVisitDerivation.Derived) -> some View {
        let excluded = derived.overlay.excludedKeys.contains(target.key)
        DisclosureGroup {
            seedingRows(target)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(target.label)
                        .font(.callout.weight(.medium))
                        .strikethrough(excluded)
                        .foregroundStyle(excluded ? Color.secondary : Color.primary)
                    Spacer()
                    tierMenu(for: target.key, derived: derived)
                }
                if let line = target.recordsLine {
                    Text(line).font(.caption).foregroundStyle(.secondary)
                }
                Text(claimCountsLine(target))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if hasSubstitute(target, derived: derived) {
                    Text(String(localized: "archiveVisit.target.substitute",
                                defaultValue: "⇄ Part of this record is digitized or filmed — read it that way instead of pulling."))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                // DELIBERATE: the access line renders the PACKET's own English sentence
                // (`restrictionLines`), unlocalized — it quotes NARA status vocabulary and
                // must read identically here and in the exported packet (§3a's one-line
                // rule); a localized mirror would be a second sentence to drift. The claim
                // counts above localize because they are arithmetic labels, not quotations.
                ForEach(TripPacketExporter.restrictionLines(target.restriction), id: \.self) {
                    Text($0).font(.caption2).foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let note = derived.overlay.notes[target.key] {
                    Text(note).font(.caption).italic().foregroundStyle(.secondary)
                }
                if excluded {
                    Text(String(localized: "archiveVisit.target.excluded",
                                defaultValue: "Excluded from the exported packet"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .contextMenu { targetContextMenu(for: target.key, derived: derived, isOrphan: false) }
    }

    /// The expanded row: the seedings, itemized under their claims with verbatim context —
    /// the two groups visibly distinct, capped at the shipped 8-per-list grammar.
    @ViewBuilder
    private func seedingRows(_ target: TripPacketModel.Target) -> some View {
        if !target.drawnFrom.isEmpty {
            Text(String(format: String(localized: "archiveVisit.claim.drawnFrom.header %lld",
                                       defaultValue: "Drawn from — %lld documents"),
                        Int64(target.drawnFrom.count)))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(target.drawnFrom.prefix(TripPacketExporter.seedingRowLimit), id: \.id) { doc in
                VStack(alignment: .leading, spacing: 2) {
                    // The citation is Markdown BY DESIGN (CitationFormatter wraps the
                    // series title in underscores for copy/export) — parse it, so the
                    // title italicizes instead of printing literal markers.
                    Text(AttributedString(markdownBody: doc.citation)).font(.caption)
                    Text(quotedExcerpt(doc.sourceNote))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if target.drawnFrom.count > TripPacketExporter.seedingRowLimit {
                Text(String(format: String(
                    localized: "archiveVisit.seedings.more %lld",
                    defaultValue: "…and %lld more — the export carries the same capped list."),
                    Int64(target.drawnFrom.count - TripPacketExporter.seedingRowLimit)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        if !target.pointedAt.isEmpty {
            Text(String(format: String(localized: "archiveVisit.claim.pointedAt.header %lld",
                                       defaultValue: "Pointed at — %lld footnotes"),
                        Int64(target.pointedAt.count)))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(Array(target.pointedAt.prefix(TripPacketExporter.seedingRowLimit)
                        .enumerated()), id: \.offset) { _, seeding in
                VStack(alignment: .leading, spacing: 2) {
                    // Format first, then parse: the wrapper adds no Markdown of its own,
                    // and parsing the whole line renders the citation's italics.
                    Text(AttributedString(markdownBody: String(format: String(
                        localized: "archiveVisit.seeding.footnote %@ %lld",
                        defaultValue: "%@, footnote %lld"),
                        seeding.citation, Int64(seeding.footnoteNumber))))
                        .font(.caption)
                    Text(quotedExcerpt(seeding.rawText))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if seeding.inherited {
                        Text(String(localized: "archiveVisit.seeding.inherited",
                                    defaultValue: "Cited as “Ibid.” — inherited from the preceding footnote’s citation."))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            if target.pointedAt.count > TripPacketExporter.seedingRowLimit {
                Text(String(format: String(
                    localized: "archiveVisit.seedings.more %lld",
                    defaultValue: "…and %lld more — the export carries the same capped list."),
                    Int64(target.pointedAt.count - TripPacketExporter.seedingRowLimit)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func hasSubstitute(_ target: TripPacketModel.Target,
                               derived: ArchiveVisitDerivation.Derived) -> Bool {
        target.drawnFrom.contains {
            derived.model.substitutes.matchesByDocument[$0.id] != nil
        }
    }

    /// The row's claim-count line, LOCALIZED in the UI's own vocabulary ("pointed at", the
    /// filter chips' term) with grouped counts — `TripPacketExporter.claimCounts` stays the
    /// PACKET's English line. The never-summed rule holds: two clauses, never one total.
    private func claimCountsLine(_ target: TripPacketModel.Target) -> String {
        var parts: [String] = []
        if !target.drawnFrom.isEmpty {
            let n = target.drawnFrom.count
            parts.append(n == 1
                ? String(localized: "archiveVisit.row.drawnFrom.one",
                         defaultValue: "drawn from 1 document")
                : String(localized: "archiveVisit.row.drawnFrom.other",
                         defaultValue: "drawn from \(n.formatted()) documents"))
        }
        if !target.pointedAt.isEmpty {
            let n = target.pointedAt.count
            parts.append(n == 1
                ? String(localized: "archiveVisit.row.pointedAt.one",
                         defaultValue: "pointed at by 1 footnote")
                : String(localized: "archiveVisit.row.pointedAt.other",
                         defaultValue: "pointed at by \(n.formatted()) footnotes"))
        }
        return parts.joined(separator: " · ")
    }

    /// Wraps a verbatim excerpt in localized quotation marks — hardcoded curly quotes
    /// would be wrong in locales with their own quotation conventions.
    private func quotedExcerpt(_ text: String) -> String {
        String(format: String(localized: "archiveVisit.seeding.quoted %@",
                              defaultValue: "“%@”"), text)
    }

    /// The row's tier control — "Set tier ⌄" or the current tier's name.
    private func tierMenu(for key: String,
                          derived: ArchiveVisitDerivation.Derived) -> some View {
        Menu {
            tierAssignmentButtons(for: key, derived: derived)
        } label: {
            HStack(spacing: 3) {
                Text(derived.overlay.tier(for: key)
                        .map { derived.overlay.displayName(for: $0) }
                     ?? String(localized: "archiveVisit.target.setTier",
                               defaultValue: "Set tier"))
                Image(systemName: "chevron.down").imageScale(.small)
            }
            .font(.caption)
        }
    }

    @ViewBuilder
    private func tierAssignmentButtons(for key: String,
                                       derived: ArchiveVisitDerivation.Derived) -> some View {
        Button(String(localized: "archiveVisit.tier.unprioritized",
                      defaultValue: "Unprioritized")) {
            setTier(nil, forKey: key)
        }
        ForEach(derived.overlay.tiers) { tier in
            Button(derived.overlay.displayName(for: tier)) {
                setTier(tier.id, forKey: key)
            }
        }
        Divider()
        Button(String(localized: "archiveVisit.editor.tiers",
                      defaultValue: "Priority Tiers…")) {
            showTiers = true
        }
    }

    @ViewBuilder
    private func targetContextMenu(for key: String,
                                   derived: ArchiveVisitDerivation.Derived,
                                   isOrphan: Bool) -> some View {
        Menu(String(localized: "archiveVisit.target.setTier", defaultValue: "Set tier")) {
            tierAssignmentButtons(for: key, derived: derived)
        }
        Button {
            noteDraft = derived.overlay.notes[key] ?? ""
            noteEditingKey = key
        } label: {
            Label(String(localized: "archiveVisit.target.editNote",
                         defaultValue: "Edit Note…"), systemImage: "note.text")
        }
        if !isOrphan {
            let excluded = derived.overlay.excludedKeys.contains(key)
            Button {
                setIncluded(excluded, forKey: key)
            } label: {
                excluded
                    ? Label(String(localized: "archiveVisit.target.include",
                                   defaultValue: "Include in Packet"),
                            systemImage: "checkmark.circle")
                    : Label(String(localized: "archiveVisit.target.exclude",
                                   defaultValue: "Exclude from Packet"),
                            systemImage: "minus.circle")
            }
        } else {
            // The orphan's ONE destructive affordance: the app never deletes the row
            // itself, but the researcher may — behind a confirmation, since it deletes
            // their tier choice and hand-typed note.
            Button(role: .destructive) {
                removingStoredKey = key
            } label: {
                Label(String(localized: "archiveVisit.target.removeStored",
                             defaultValue: "Remove Stored State"), systemImage: "trash")
            }
        }
    }

    // MARK: - Orphans (1b)

    @ViewBuilder
    private func orphanSection(_ derived: ArchiveVisitDerivation.Derived) -> some View {
        if !derived.overlay.orphanKeys.isEmpty {
            Section(String(localized: "archiveVisit.orphans.header",
                           defaultValue: "Stored targets")) {
                ForEach(derived.overlay.orphanKeys, id: \.self) { key in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(orphanLabel(forKey: key))
                                .font(.callout.weight(.medium))
                            Spacer()
                            tierMenu(for: key, derived: derived)
                        }
                        Text(String(localized: "archiveVisit.orphan.caption",
                                    defaultValue: "Stored target — no longer derives from this plan’s current seeds. Kept with your tier and notes; it never deletes itself."))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let note = derived.overlay.notes[key] {
                            Text(note).font(.caption).italic().foregroundStyle(.secondary)
                        }
                    }
                    .contextMenu {
                        targetContextMenu(for: key, derived: derived, isOrphan: true)
                    }
                }
            }
        }
    }

    /// A readable label for an orphan's key — the identity segment of the form-aware key.
    private func orphanLabel(forKey key: String) -> String {
        guard let bar = key.firstIndex(of: "|") else { return key }
        return String(key[key.index(after: bar)...])
    }

    /// Which half is missing, when seeds derive no targets (1b's undrawn state).
    private func noTargetsExplanation(_ derived: ArchiveVisitDerivation.Derived) -> String {
        let seeds = plan.documents ?? []
        let anyOn = seeds.contains { $0.includeSource || $0.includeExternalRefs }
        if !anyOn {
            return String(localized: "archiveVisit.editor.allOff",
                          defaultValue: "Every document’s contributions are switched off — turn a document’s archival source or unprinted references back on under Documents.")
        }
        return String(localized: "archiveVisit.editor.noTargets",
                      defaultValue: "No targets derive from these documents on this device — their volumes may not be indexed yet, or their source notes name nothing the app can place.")
    }

    // MARK: - Documents tab (1d)

    private var documentsTab: some View {
        List {
            if (plan.documents ?? []).isEmpty {
                Section { noSeedsView }
            } else {
                Section {
                    ForEach(sortedSeeds, id: \.documentKey) { seed in
                        documentRow(seed)
                    }
                    .onDelete { offsets in
                        removeSeeds(at: offsets)
                    }
                } footer: {
                    // .fixedSize PER TEXT (plus the full-width frame), the plan list's own
                    // footer pattern — on the container VStack it let a Text clip mid-word.
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "archiveVisit.documents.footer",
                                    defaultValue: "Each document contributes through two switches: its own source note (drawn from) and its footnotes’ citations to unprinted material (pointed at). References beyond FRUS exist on only about 4% of documents — where a half is absent, the control is a caption, never a dead switch."))
                            .fixedSize(horizontal: false, vertical: true)
                        if let sparsity, sparsity.indexed > 0 {
                            Text(measuredSparsityLine(sparsity))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
    }

    /// The measured-sparsity sentence, grouped digits — used by the info popover and the
    /// Documents-tab footer, one string so the two cannot disagree.
    private func measuredSparsityLine(_ sparsity: (withReferences: Int, indexed: Int)) -> String {
        String(localized: "archiveVisit.info.sparsity.measured.v2",
               defaultValue: "On this device: \(sparsity.withReferences.formatted()) of \(sparsity.indexed.formatted()) indexed documents carry such references.")
    }

    /// Removes seeds at the given offsets of `sortedSeeds` — the `.onDelete` twin of the
    /// row's swipe/context Remove, through the same delete-and-rederive tail.
    private func removeSeeds(at offsets: IndexSet) {
        let seeds = sortedSeeds
        for index in offsets { modelContext.delete(seeds[index]) }
        try? modelContext.save()
        bump()
    }

    private var sortedSeeds: [ArchiveVisitDocument] {
        (plan.documents ?? []).sorted { $0.documentKey < $1.documentKey }
    }

    @ViewBuilder
    private func documentRow(_ seed: ArchiveVisitDocument) -> some View {
        let facts = seedFacts[seed.documentKey]
        VStack(alignment: .leading, spacing: 5) {
            // The Collections row anatomy: header as the primary line, volume title as the
            // caption — never the full publication citation.
            Text(facts?.header ?? seed.documentKey)
                .font(.callout)
                .lineLimit(2)
            if let volumeTitle = facts?.volumeTitle {
                Text(volumeTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if seed.includeSource == false && seed.includeExternalRefs == false {
                Text(String(localized: "archiveVisit.document.nothing",
                            defaultValue: "Contributes nothing to this plan"))
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            // The source half — a switch when the note exists, a caption when it does not.
            if facts?.hasSourceNote != false {
                Toggle(String(localized: "archiveVisit.document.source",
                              defaultValue: "Archival source"),
                       isOn: seedBinding(seed, \.includeSource))
                    .font(.caption)
                    #if os(macOS)
                    .toggleStyle(.checkbox)
                    #endif
            } else {
                Text(String(localized: "archiveVisit.document.noSource",
                            defaultValue: "This document carries no source note"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            // The references half.
            if let count = facts?.referenceCount, count == 0 {
                Text(String(localized: "archiveVisit.document.noRefs",
                            defaultValue: "No unprinted references in this document’s footnotes"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Toggle(isOn: seedBinding(seed, \.includeExternalRefs)) {
                    if let count = facts?.referenceCount {
                        Text(String(format: String(
                            localized: "archiveVisit.document.refs.counted %lld",
                            defaultValue: "Unprinted references · %lld"), Int64(count)))
                    } else {
                        Text(String(localized: "archiveVisit.document.refs",
                                    defaultValue: "Unprinted references"))
                    }
                }
                .font(.caption)
                #if os(macOS)
                .toggleStyle(.checkbox)
                #endif
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                removeSeed(seed)
            } label: {
                Label(String(localized: "archiveVisit.document.remove",
                             defaultValue: "Remove"), systemImage: "trash")
            }
        }
        // Mouse-reachable twins of the swipe action, plus the reader route every document
        // list owes (#755): swipe-only Remove was unreachable on macOS.
        .contextMenu {
            Button {
                openSeedInReader(seed)
            } label: {
                Label(String(localized: "archiveVisit.document.open",
                             defaultValue: "Open Document"), systemImage: "doc.text")
            }
            Button(role: .destructive) {
                removeSeed(seed)
            } label: {
                Label(String(localized: "archiveVisit.document.remove",
                             defaultValue: "Remove"), systemImage: "trash")
            }
        }
    }

    /// Removes one seed — the single delete tail behind the swipe action, the context
    /// menu, and (via `removeSeeds(at:)`) edit-mode delete.
    private func removeSeed(_ seed: ArchiveVisitDocument) {
        modelContext.delete(seed)
        try? modelContext.save()
        bump()
    }

    /// Opens a seeded document in the app's reader — the `openInReader` route every other
    /// document list uses (provenance chain on macOS, scene-addressed hand-off on iOS).
    private func openSeedInReader(_ seed: ArchiveVisitDocument) {
        guard let tuple = ArchiveVisitDerivation.documentTuple(fromKey: seed.documentKey)
        else { return }
        let entry = DocumentBrowserEntry(
            documentId: tuple.documentId,
            volumeId: tuple.volumeId,
            header: seedFacts[seed.documentKey]?.header ?? seed.documentKey)
        #if os(macOS)
        appState.openDocument(entry, from: .global, using: openWindow)
        #else
        appState.openTab(.browse, from: sceneID)
        appState.openBrowseDocument(entry, from: sceneID)
        #endif
    }

    private func seedBinding(_ seed: ArchiveVisitDocument,
                             _ keyPath: ReferenceWritableKeyPath<ArchiveVisitDocument, Bool>)
        -> Binding<Bool> {
        Binding(
            get: { seed[keyPath: keyPath] },
            set: { newValue in
                seed[keyPath: keyPath] = newValue
                try? modelContext.save()
                bump()
            })
    }

    // MARK: - Mutations

    private func bump() { revision += 1 }

    private func setTier(_ tierId: UUID?, forKey key: String) {
        // Assigning a tier is STATE, so it mints the overlay row (§2a); clearing back to
        // Unprioritized keeps the row — an explicit choice is state too.
        guard let row = plan.targetState(forKey: key, mintIfMissing: true,
                                         in: modelContext) else { return }
        row.tierId = tierId
        try? modelContext.save()
        bump()
    }

    private func setIncluded(_ included: Bool, forKey key: String) {
        guard let row = plan.targetState(forKey: key, mintIfMissing: true,
                                         in: modelContext) else { return }
        row.included = included
        try? modelContext.save()
        bump()
    }

    private func commitNote() {
        guard let key = noteEditingKey else { return }
        let trimmed = noteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let row = plan.targetState(forKey: key, mintIfMissing: true,
                                         in: modelContext) else { return }
        row.userNote = trimmed.isEmpty ? nil : trimmed
        try? modelContext.save()
        noteEditingKey = nil
        bump()
    }

    private func removeStoredState(forKey key: String) {
        guard let row = plan.targetState(forKey: key, mintIfMissing: false,
                                         in: modelContext) else { return }
        modelContext.delete(row)
        try? modelContext.save()
        bump()
    }

    /// 1e's explicit re-seed: adds the project's CURRENT leads union as new seeds (both
    /// contributions on), never removing anything — a mirror would silently erase choices.
    private func reseed(fromProject projectId: UUID) async {
        let keys = await ProjectLeadsService.gatherSeed(
            forProject: projectId, container: modelContext.container).seedKeys
        let documents = keys.compactMap { DocumentKey(compositeString: $0)?.tuple }
        plan.addSeeds(documents, includeSource: true, includeExternalRefs: true,
                      in: modelContext)
        try? modelContext.save()
        bump()
    }

    // MARK: - Derivation

    private func derive() async {
        guard let pipeline = appState.indexingPipeline else {
            // Keep the boot placeholder up (isDeriving stays true) — the body's onChange
            // re-derives when the pipeline appears. Setting it false here rendered the
            // editor permanently blank when opened before the index booted.
            return
        }
        isDeriving = true
        defer { isDeriving = false }
        let manifest = appState.manifestStore.diffResult?.known
            ?? appState.manifestStore.bundledEntries
        let dataSource = TripPacketDataSource(
            pipeline: pipeline,
            manifestMap: Dictionary(manifest.map { ($0.volumeId, $0) },
                                    uniquingKeysWith: { first, _ in first }))
        derived = await ArchiveVisitDerivation.derive(
            plan: plan,
            indexedVolumeIds: Set(appState.indexedVolumeIds),
            dataSource: dataSource)

        // Phase 4: the live sparsity measure — one query, refreshed with every derivation
        // so the caption tracks the index it describes.
        if let measured = try? await pipeline.externalCitationSparsity() {
            sparsity = (withReferences: measured.documentsWithReferences,
                        indexed: measured.indexedDocuments)
        } else {
            sparsity = nil
        }

        // The Documents tab's per-seed facts: which halves exist, through the same two
        // batched queries the builder runs — so the captions and the packet cannot disagree.
        let seeds = (plan.documents ?? []).compactMap {
            ArchiveVisitDerivation.documentTuple(fromKey: $0.documentKey)
        }
        let records = await dataSource.documentSources(for: seeds)
        let noteKeys = Set(records.map { "\($0.volumeId)/\($0.documentId)" })
        let citations = await dataSource.externalCitations(for: seeds)
        var facts: [String: SeedFacts] = [:]
        for seed in seeds {
            let key = "\(seed.volumeId)/\(seed.documentId)"
            let relevant = (citations[key] ?? []).filter { $0.anchor != "centralFileClass" }
            facts[key] = SeedFacts(
                header: await dataSource.documentHeader(volumeId: seed.volumeId,
                                                        documentId: seed.documentId),
                volumeTitle: dataSource.volumeTitle(volumeId: seed.volumeId),
                hasSourceNote: noteKeys.contains(key),
                referenceCount: relevant.count)
        }
        seedFacts = facts

        // Filters can go stale between derivations — a deleted tier or a repository that
        // no longer derives would silently empty the list while the controls read as
        // unfiltered. Reset exactly the stale ones.
        if let derived {
            if case .tier(let id) = tierFilter,
               !derived.overlay.tiers.contains(where: { $0.id == id }) {
                tierFilter = .all
            }
            if let repositoryFilter, !facilityHeadings(derived).contains(repositoryFilter) {
                self.repositoryFilter = nil
            }
        }
    }
}

// MARK: - ArchiveVisitTierSheet

/// Priority-tier management (artboard 1c): create, rename, reorder, delete — any number,
/// user-named. A new plan starts with NO tiers and only the add control; deleting a tier
/// drops its members to Unprioritized, and the confirmation says so.
///
/// Platform-split chrome (the `PersonMergePickerSheet` rule): iOS keeps the
/// `NavigationStack` + toolbar; macOS is a plain `VStack` with a headline row and a
/// bottom-right Done — a `NavigationStack` inside a macOS sheet renders sidebar-style
/// artifacts.
///
/// Version history:
///   1.0 — Archive Visits Phase 3: initial implementation
///   1.1 — UI pass: macOS plain-VStack chrome; tier rows gain a context menu and
///         `.onDelete` (delete was swipe-only — mouse-unreachable on macOS, and absent
///         from iOS edit mode); both routes arm the SAME confirmation.
struct ArchiveVisitTierSheet: View {

    let plan: ArchiveVisitPlan

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var renaming: ArchiveVisitTier?
    @State private var draftLabel = ""
    @State private var deleting: ArchiveVisitTier?

    var body: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            HStack {
                Text(String(localized: "archiveVisit.tiers.title",
                            defaultValue: "Priority Tiers"))
                    .font(.headline)
                Spacer()
                Button(String(localized: "common.done", defaultValue: "Done")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)
            Divider()
            tierList
        }
        .frame(minWidth: 380, minHeight: 320)
        .alert(String(localized: "archiveVisit.tiers.rename.title",
                      defaultValue: "Rename Tier"),
               isPresented: Binding(get: { renaming != nil },
                                    set: { if !$0 { renaming = nil } })) {
            renameAlertContent
        }
        .confirmationDialog(
            deleteTitle,
            isPresented: Binding(get: { deleting != nil },
                                 set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible
        ) {
            deleteDialogButtons
        } message: {
            Text(deleteMessage)
        }
        #else
        NavigationStack {
            tierList
            .navigationTitle(String(localized: "archiveVisit.tiers.title",
                                    defaultValue: "Priority Tiers"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) { EditButton() }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done", defaultValue: "Done")) { dismiss() }
                }
            }
            .alert(String(localized: "archiveVisit.tiers.rename.title",
                          defaultValue: "Rename Tier"),
                   isPresented: Binding(get: { renaming != nil },
                                        set: { if !$0 { renaming = nil } })) {
                renameAlertContent
            }
            .confirmationDialog(
                deleteTitle,
                isPresented: Binding(get: { deleting != nil },
                                     set: { if !$0 { deleting = nil } }),
                titleVisibility: .visible
            ) {
                deleteDialogButtons
            } message: {
                Text(deleteMessage)
            }
        }
        #endif
    }

    /// The tier list itself, shared by both platforms' chrome.
    private var tierList: some View {
        List {
            Section {
                ForEach(plan.tiers) { tier in
                    tierRow(tier)
                }
                .onMove(perform: move)
                // Edit-mode delete arms the SAME confirmation the swipe path uses —
                // the swipe-arms-a-confirmation rule survives because `.onDelete` only
                // sets `deleting`; `commitDelete()` still runs behind the dialog.
                .onDelete { offsets in
                    if let index = offsets.first, plan.tiers.indices.contains(index) {
                        deleting = plan.tiers[index]
                    }
                }
                Button {
                    var tiers = plan.tiers
                    tiers.append(ArchiveVisitTier(label: nil, order: tiers.count))
                    plan.tiers = tiers
                    try? modelContext.save()
                } label: {
                    Label(String(localized: "archiveVisit.tiers.add",
                                 defaultValue: "Add a priority tier"),
                          systemImage: "plus.circle")
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            } footer: {
                Text(String(localized: "archiveVisit.tiers.footer",
                            defaultValue: "Targets without a tier stay in Unprioritized, always listed last. An unlabeled tier reads “Priority 1”."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// The rename alert's fields, shared by both platforms' chrome.
    @ViewBuilder
    private var renameAlertContent: some View {
        TextField(String(localized: "archiveVisit.tiers.rename.placeholder",
                         defaultValue: "Label"), text: $draftLabel)
        Button(String(localized: "common.cancel", defaultValue: "Cancel"),
               role: .cancel) { renaming = nil }
        Button(String(localized: "common.save", defaultValue: "Save")) { commitRename() }
    }

    /// The delete confirmation's buttons, shared by both platforms' chrome.
    @ViewBuilder
    private var deleteDialogButtons: some View {
        Button(String(localized: "archiveVisit.tiers.delete.confirm",
                      defaultValue: "Delete Tier"), role: .destructive) {
            commitDelete()
        }
        Button(String(localized: "common.cancel", defaultValue: "Cancel"),
               role: .cancel) { deleting = nil }
    }

    private func tierRow(_ tier: ArchiveVisitTier) -> some View {
        let members = (plan.targets ?? []).filter { $0.tierId == tier.id }.count
        return Button {
            draftLabel = tier.label ?? ""
            renaming = tier
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName(tier)).font(.body).foregroundStyle(.primary)
                Text(String(format: String(localized: "archiveVisit.tiers.members %lld",
                                           defaultValue: "%lld targets"), Int64(members)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                deleting = tier
            } label: {
                Label(String(localized: "common.delete", defaultValue: "Delete"),
                      systemImage: "trash")
            }
        }
        // Mouse-reachable twins — swipe-only delete was near-undiscoverable on macOS.
        .contextMenu {
            Button {
                draftLabel = tier.label ?? ""
                renaming = tier
            } label: {
                Label(String(localized: "common.rename", defaultValue: "Rename"),
                      systemImage: "pencil")
            }
            Button(role: .destructive) {
                deleting = tier
            } label: {
                Label(String(localized: "common.delete", defaultValue: "Delete"),
                      systemImage: "trash")
            }
        }
    }

    private func displayName(_ tier: ArchiveVisitTier) -> String {
        if let label = tier.label, !label.isEmpty { return label }
        let position = (plan.tiers.firstIndex(of: tier) ?? 0) + 1
        return String(format: String(localized: "archiveVisit.tier.unnamed %lld",
                                     defaultValue: "Priority %lld"), Int64(position))
    }

    private var deleteTitle: String {
        String(format: String(localized: "archiveVisit.tiers.delete.title %@",
                              defaultValue: "Delete “%@”?"),
               deleting.map(displayName) ?? "")
    }

    private var deleteMessage: String {
        let members = deleting.map { tier in
            (plan.targets ?? []).filter { $0.tierId == tier.id }.count
        } ?? 0
        return String(format: String(
            localized: "archiveVisit.tiers.delete.message %lld",
            defaultValue: "Its %lld targets move to Unprioritized. Nothing is removed from the plan."),
            Int64(members))
    }

    private func move(from source: IndexSet, to destination: Int) {
        var tiers = plan.tiers
        tiers.move(fromOffsets: source, toOffset: destination)
        for index in tiers.indices { tiers[index].order = index }
        plan.tiers = tiers
        try? modelContext.save()
    }

    private func commitRename() {
        guard let tier = renaming else { return }
        var tiers = plan.tiers
        if let index = tiers.firstIndex(where: { $0.id == tier.id }) {
            let trimmed = draftLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            tiers[index].label = trimmed.isEmpty ? nil : trimmed
            plan.tiers = tiers
            try? modelContext.save()
        }
        renaming = nil
    }

    private func commitDelete() {
        guard let tier = deleting else { return }
        var tiers = plan.tiers.filter { $0.id != tier.id }
        for index in tiers.indices { tiers[index].order = index }
        plan.tiers = tiers
        // Same-device cleanliness: members drop to Unprioritized NOW rather than dangling.
        // A row referencing this tier from another device still degrades to Unprioritized
        // by the overlay's dangling-id rule.
        for row in (plan.targets ?? []) where row.tierId == tier.id {
            row.tierId = nil
        }
        try? modelContext.save()
        deleting = nil
    }
}
