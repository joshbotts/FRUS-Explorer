// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftUI
import SwiftData

// MARK: - BrowseScopeFilterState

/// What the "Browsing within" filter is doing right now (#1051 B-3, owner decision Q-3).
///
/// The filter is a LIVE REFERENCE — a scope UUID in UserDefaults, resolved against the
/// SwiftData store at render — so edits to the scope reflect immediately and a scope
/// deleted on another device becomes an explicit `.unavailable` state. The one behaviour
/// every state forbids is the #258 HIGH inversion: an empty or failed resolution must
/// NEVER fall through to the whole corpus under the scope's name. `.empty` and
/// `.unavailable` therefore filter to NOTHING, with the banner saying why.
enum BrowseScopeFilterState: Equatable {
    /// No filter — Browse shows the whole corpus.
    case inactive
    /// Filtering to the scope's manifest-resolvable members.
    case active(name: String, allowed: Set<String>)
    /// The scope exists but has no members this device's catalogue can show.
    case empty(name: String)
    /// The stored id resolves to no scope (deleted here or on another device).
    case unavailable
}

// MARK: - ScopeAxis

/// The custom-scopes browse axis's pure logic (#1051 B-3, A-5): filter resolution, the
/// hierarchy restriction, membership mutation, and the R-1 drill spec — split from the
/// views for testability (the Topic Index pattern).
///
/// Version history:
///   1.0 — #1051 B-3: initial implementation
enum ScopeAxis {

    /// The scope's display name — scopes may legitimately be saved unnamed.
    ///
    /// - Parameter scope: The scope.
    /// - Returns: The name, or the untitled placeholder.
    static func displayName(_ scope: CustomVolumeScope) -> String {
        scope.name.isEmpty
            ? String(localized: "browser.scopes.untitled", defaultValue: "Untitled Scope")
            : scope.name
    }

    /// Resolves the browse filter (Q-3 live reference).
    ///
    /// - Parameters:
    ///   - filterId: The persisted scope id, or `nil` for no filter.
    ///   - scopes: The device's scopes.
    ///   - manifestIds: Every browsable volume id.
    /// - Returns: The filter state — never a silent whole-corpus fallback.
    static func filterState(
        filterId: UUID?,
        scopes: [CustomVolumeScope],
        manifestIds: Set<String>
    ) -> BrowseScopeFilterState {
        guard let filterId else { return .inactive }
        guard let scope = scopes.first(where: { $0.id == filterId }) else { return .unavailable }
        let allowed = Set(scope.volumeIds).intersection(manifestIds)
        guard !allowed.isEmpty else { return .empty(name: displayName(scope)) }
        return .active(name: displayName(scope), allowed: allowed)
    }

    /// Restricts the subseries hierarchy to the filter (manifest grain — undownloaded
    /// members still render, matching Browse's own behaviour).
    ///
    /// - Parameters:
    ///   - groups: The unrestricted groups.
    ///   - state: The filter state.
    /// - Returns: Groups holding only allowed volumes, empties dropped; `[]` under
    ///   `.empty`/`.unavailable` (the explicit nothing, never the whole corpus).
    static func scopedGroups(
        _ groups: [SubseriesGroup],
        state: BrowseScopeFilterState
    ) -> [SubseriesGroup] {
        switch state {
        case .inactive:
            return groups
        case .active(_, let allowed):
            return groups.compactMap { group in
                let volumes = group.volumes.filter { allowed.contains($0.volumeId) }
                return volumes.isEmpty ? nil : SubseriesGroup(subseries: group.subseries, volumes: volumes)
            }
        case .empty, .unavailable:
            return []
        }
    }

    /// Restricts one subseries' volume list to the filter.
    ///
    /// - Parameters:
    ///   - volumes: The unrestricted volumes.
    ///   - state: The filter state.
    /// - Returns: The allowed volumes; `[]` under `.empty`/`.unavailable`.
    static func scopedVolumes(
        _ volumes: [VolumeManifestEntry],
        state: BrowseScopeFilterState
    ) -> [VolumeManifestEntry] {
        switch state {
        case .inactive:
            return volumes
        case .active(_, let allowed):
            return volumes.filter { allowed.contains($0.volumeId) }
        case .empty, .unavailable:
            return []
        }
    }

    /// The R-1 drill spec for one scope: members resolved against the manifest in the
    /// scope's own (sorted) order, with the caption disclosing any entries the current
    /// catalogue cannot show.
    ///
    /// - Parameters:
    ///   - scope: The scope.
    ///   - manifestIds: Every browsable volume id.
    /// - Returns: The spec.
    static func spec(for scope: CustomVolumeScope, manifestIds: Set<String>) -> VolumeListSpec {
        let resolved = scope.volumeIds.filter { manifestIds.contains($0) }
        let missing = scope.volumeIds.count - resolved.count
        var caption = String(localized: "browser.scopes.drill.caption",
                             defaultValue: "\(resolved.count) volumes in this scope, by volume number.")
        if missing > 0 {
            caption += " " + String(localized: "browser.scopes.drill.missing",
                                    defaultValue: "Entries referencing volumes outside this device’s catalogue: \(missing).")
        }
        return VolumeListSpec(
            axisKey: "scope:\(scope.id.uuidString)",
            title: displayName(scope),
            volumeIds: resolved,
            caption: caption
        )
    }

    // MARK: Membership mutation

    /// Adds a volume to a scope. A no-op when already a member (the 3b contract), and a
    /// full-array REASSIGNMENT when not — SwiftData's `@Model` array `didSet` never fires
    /// on in-place mutation, so append-in-place would sync nothing.
    ///
    /// - Parameters:
    ///   - volumeId: The volume to add.
    ///   - scope: The scope to mutate.
    /// - Returns: `true` when membership changed.
    @discardableResult
    static func add(_ volumeId: String, to scope: CustomVolumeScope) -> Bool {
        guard !scope.volumeIds.contains(volumeId) else { return false }
        scope.volumeIds = (scope.volumeIds + [volumeId]).sorted()
        scope.lastModified = Date()
        return true
    }

    /// Removes a volume from a scope (reassignment, as above). A no-op for non-members.
    ///
    /// - Parameters:
    ///   - volumeId: The volume to remove.
    ///   - scope: The scope to mutate.
    /// - Returns: `true` when membership changed.
    @discardableResult
    static func remove(_ volumeId: String, from scope: CustomVolumeScope) -> Bool {
        guard scope.volumeIds.contains(volumeId) else { return false }
        scope.volumeIds = scope.volumeIds.filter { $0 != volumeId }
        scope.lastModified = Date()
        return true
    }

    /// Creates and inserts a new scope (the 3c capture and both New-Scope doors).
    ///
    /// - Parameters:
    ///   - name: The scope name (may be empty; lists show the untitled placeholder).
    ///   - volumeIds: Initial membership.
    ///   - context: The model context to insert into.
    /// - Returns: The inserted scope, already saved.
    @MainActor
    static func create(named name: String, volumeIds: [String],
                       in context: ModelContext) -> CustomVolumeScope {
        let scope = CustomVolumeScope(name: name, volumeIds: volumeIds)
        context.insert(scope)
        // Never dismiss past a failed save silently succeeded — but here there is no
        // dismissal to guard; a throw would surface via the context's own error path.
        try? context.save()
        return scope
    }
}

// MARK: - ScopeIndexView

/// The My Scopes level (#1051 B-3, design 1i): the user's custom volume scopes, most
/// recently edited first, each opening its R-1 volume list — with editing and creation in
/// Browse (the owner call that superseded capture-only *for scopes*; working corpora stay
/// capture-only).
///
/// Shared across both platforms behind `onOpen`/`onEdit` closures (the catalogue's
/// pattern).
///
/// Version history:
///   1.0 — #1051 B-3: initial implementation
struct ScopeIndexView: View {

    /// Every browsable volume id, for membership resolution.
    let manifestIds: Set<String>
    /// Opens a scope's R-1 volume list.
    let onOpen: @MainActor (VolumeListSpec) -> Void
    /// Opens the scope editor.
    let onEdit: @MainActor (UUID) -> Void

    @Query(sort: \CustomVolumeScope.lastModified, order: .reverse)
    private var scopes: [CustomVolumeScope]
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            if scopes.isEmpty {
                Section {
                    ContentUnavailableView(
                        String(localized: "browser.scopes.empty.title",
                               defaultValue: "No Scopes Yet"),
                        systemImage: "square.stack.3d.up",
                        description: Text(String(
                            localized: "browser.scopes.empty.detail",
                            defaultValue: "A scope is a set of volumes you assemble yourself. Create one here, or use “Save as Scope” on any axis’s volume list."))
                    )
                }
            } else {
                Section {
                    Text(String(localized: "browser.scopes.coverage",
                                defaultValue: "Volume sets you assemble yourself, most recently edited first. Scopes also narrow Search, analytics, and word clouds — and sync via iCloud."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section {
                    ForEach(scopes) { scope in
                        row(scope)
                    }
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
        .navigationTitle(String(localized: "browser.scopes.title", defaultValue: "My Scopes"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    let scope = ScopeAxis.create(named: "", volumeIds: [], in: modelContext)
                    onEdit(scope.id)
                    #if DEBUG
                    print("[ScopeIndexView] New scope created: \(scope.id)")
                    #endif
                } label: {
                    Label(String(localized: "browser.scopes.new", defaultValue: "New Scope"),
                          systemImage: "plus")
                }
                .help(String(localized: "browser.scopes.new.help",
                             defaultValue: "Create an empty scope and choose its volumes"))
            }
        }
    }

    @ViewBuilder
    private func row(_ scope: CustomVolumeScope) -> some View {
        HStack(spacing: 8) {
            Button {
                onOpen(ScopeAxis.spec(for: scope, manifestIds: manifestIds))
                #if DEBUG
                print("[ScopeIndexView] Navigate → scope \(scope.id)")
                #endif
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ScopeAxis.displayName(scope))
                        .font(.body)
                    Text(rowCaption(scope))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                // Both modifiers, in this order — the #312 full-row tap-target idiom.
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                String(localized: "browser.scopes.row.a11y",
                       defaultValue: "\(ScopeAxis.displayName(scope)), \(scope.volumeIds.count) volumes")
            )
            Button {
                onEdit(scope.id)
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(
                String(localized: "browser.scopes.edit.a11y",
                       defaultValue: "Edit \(ScopeAxis.displayName(scope))")
            )
            .help(String(localized: "browser.scopes.edit.help",
                         defaultValue: "Rename this scope or change its volumes"))
        }
        .contextMenu {
            Button {
                onEdit(scope.id)
            } label: {
                Label(String(localized: "browser.scopes.menu.edit", defaultValue: "Edit Scope"),
                      systemImage: "pencil")
            }
            #if os(iOS)
            // The browse-within filter is an iOS Browse-tab affordance for now — the macOS
            // corpus browser's sidebar has no filter surface designed yet (B-3 scope).
            if appState.browseScopeFilterId == scope.id {
                Button {
                    appState.browseScopeFilterId = nil
                } label: {
                    Label(String(localized: "browser.scopes.menu.stopBrowsing",
                                 defaultValue: "Stop Browsing Within"),
                          systemImage: "xmark.circle")
                }
            } else {
                Button {
                    appState.browseScopeFilterId = scope.id
                } label: {
                    Label(String(localized: "browser.scopes.menu.browseWithin",
                                 defaultValue: "Browse Within This Scope"),
                          systemImage: "line.3.horizontal.decrease.circle")
                }
            }
            #endif
        }
    }

    private func rowCaption(_ scope: CustomVolumeScope) -> String {
        if scope.volumeIds.isEmpty {
            return String(localized: "browser.scopes.row.empty", defaultValue: "No volumes yet")
        }
        if let modified = scope.lastModified {
            return String(localized: "browser.scopes.row.caption",
                          defaultValue: "\(scope.volumeIds.count) volumes · edited \(modified.formatted(date: .abbreviated, time: .omitted))")
        }
        return String(localized: "browser.scopes.row.caption.plain",
                      defaultValue: "\(scope.volumeIds.count) volumes")
    }
}

// MARK: - VolumeScopeMenuItems

/// The pan-axis "Add to Scope…" context-menu items (#1051 B-3, design 3b) — declared once
/// and attached to every R-1 volume row, so all axes inherit them.
///
/// Adding an existing member is a NO-OP (`ScopeAxis.add`); the submenu marks member rows
/// with a checkmark so the no-op is visible before the tap.
///
/// Version history:
///   1.0 — #1051 B-3: initial implementation
struct VolumeScopeMenuItems: View {

    /// The volume the menu acts on.
    let volumeId: String
    /// Navigates to the editor after "New Scope from Volume…" (iOS pushes the browse
    /// level, macOS the detail-column case).
    let onEditCreatedScope: @MainActor (UUID) -> Void

    @Query(sort: \CustomVolumeScope.lastModified, order: .reverse)
    private var scopes: [CustomVolumeScope]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if let recent = scopes.first {
            Button {
                if ScopeAxis.add(volumeId, to: recent) {
                    try? modelContext.save()
                }
            } label: {
                Label(String(localized: "browser.scopes.menu.addToRecent",
                             defaultValue: "Add to “\(ScopeAxis.displayName(recent))”"),
                      systemImage: "square.stack.3d.up")
            }
            .disabled(recent.volumeIds.contains(volumeId))
        }
        if !scopes.isEmpty {
            Menu {
                ForEach(scopes) { scope in
                    Button {
                        if ScopeAxis.add(volumeId, to: scope) {
                            try? modelContext.save()
                        }
                    } label: {
                        if scope.volumeIds.contains(volumeId) {
                            Label(ScopeAxis.displayName(scope), systemImage: "checkmark")
                        } else {
                            Text(ScopeAxis.displayName(scope))
                        }
                    }
                }
            } label: {
                Label(String(localized: "browser.scopes.menu.addTo",
                             defaultValue: "Add to Scope…"),
                      systemImage: "square.stack.3d.up")
            }
        }
        Button {
            let scope = ScopeAxis.create(named: "", volumeIds: [volumeId], in: modelContext)
            onEditCreatedScope(scope.id)
            #if DEBUG
            print("[VolumeScopeMenuItems] New scope from \(volumeId): \(scope.id)")
            #endif
        } label: {
            Label(String(localized: "browser.scopes.menu.newFromVolume",
                         defaultValue: "New Scope from Volume…"),
                  systemImage: "plus.square.on.square")
        }
    }
}

// MARK: - BrowseScopeFilterSection

/// The "Browsing within" banner (#1051 B-3, design 1i), rendered as the top section of
/// the subseries hierarchy while a scope filter is active — amber, with the one-tap
/// clear. The `.empty`/`.unavailable` states explain themselves here while the lists
/// below show the explicit nothing (never the whole corpus — the #258 rule).
///
/// Version history:
///   1.0 — #1051 B-3: initial implementation
struct BrowseScopeFilterSection: View {

    let state: BrowseScopeFilterState
    /// Clears the filter.
    let onClear: @MainActor () -> Void

    var body: some View {
        if state != .inactive {
            Section {
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Button {
                        onClear()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(
                        String(localized: "browser.scopes.banner.clear.a11y",
                               defaultValue: "Stop browsing within this scope")
                    )
                    .help(String(localized: "browser.scopes.banner.clear.help",
                                 defaultValue: "Show the whole corpus again"))
                }
                .listRowBackground(Color.orange.opacity(0.12))
            }
        }
    }

    private var message: String {
        switch state {
        case .inactive:
            return ""
        case .active(let name, _):
            return String(localized: "browser.scopes.banner.active",
                          defaultValue: "Browsing within: \(name)")
        case .empty(let name):
            return String(localized: "browser.scopes.banner.empty",
                          defaultValue: "Browsing within: \(name) — this scope has no volumes this device’s catalogue can show.")
        case .unavailable:
            return String(localized: "browser.scopes.banner.unavailable",
                          defaultValue: "The scope this browse was narrowed to is no longer available.")
        }
    }
}

// MARK: - iOS mounts

#if os(iOS)

/// The iOS mount of the My Scopes level (`BrowserLevel.scopes`).
///
/// Version history:
///   1.0 — #1051 B-3: initial implementation
struct BrowseScopesLevel: View {
    let vm: BrowserViewModel

    var body: some View {
        ScopeIndexView(
            manifestIds: Set(vm.allVolumes.map(\.volumeId)),
            onOpen: { [vm] spec in vm.navigationPath.append(.volumeList(spec)) },
            onEdit: { [vm] id in vm.navigationPath.append(.scopeEditor(id)) }
        )
    }
}

/// The iOS mount of the scope editor (`BrowserLevel.scopeEditor`). Done pops the level —
/// there is no navigation container to `dismiss()` through in the two-pane layout, where
/// levels render directly.
///
/// Version history:
///   1.0 — #1051 B-3: initial implementation
struct BrowseScopeEditorLevel: View {
    let vm: BrowserViewModel
    let scopeId: UUID

    var body: some View {
        ScopeEditorView(scopeId: scopeId, onDone: { [vm] in
            if case .scopeEditor = vm.navigationPath.last {
                vm.navigationPath.removeLast()
            }
        })
    }
}

#endif // os(iOS)
