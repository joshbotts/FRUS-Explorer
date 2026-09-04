// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - VolumeListSpec

/// The payload of `BrowserLevel.volumeList` — an arbitrary ordered set of volumes with the
/// axis identity that produced it (#1051 R-1).
///
/// ## The contract, and the two rules that keep it honest
/// - **Identity is `axisKey`, never the id array.** `BrowserLevel` hashes and compares this
///   spec on `axisKey` alone, matching how `.volume` keys on `volumeId`: a recomputed set
///   under the same axis (a re-resolved scope, a refreshed ranking) is the SAME level, so
///   breadcrumb truncation and path equality never break on incidental recomputation.
/// - **Order is the caller's payload and is never re-sorted.** A release-date axis hands
///   over year order, an administration axis hands over document-count order — the list
///   renders exactly what it was given. Sorting here would silently overwrite the one thing
///   several axes exist to say.
///
/// Version history:
///   1.0 — #1051 B-1: initial implementation (the shared cross-subseries destination;
///          consumers arrive with the B-2+ axes)
public struct VolumeListSpec: Hashable, Sendable {

    /// Stable identity for this list, e.g. `"administration:truman"` or `"editor:slany"`.
    /// Two specs with the same key are the same browse level.
    public let axisKey: String

    /// The level's display title, e.g. a president's or editor's name.
    public let title: String

    /// The member volume ids, in the axis's own order. Ids the manifest cannot resolve are
    /// skipped at render time (never invented).
    public let volumeIds: [String]

    /// The coverage/honesty caption pinned above the rows, or `nil` for none. Every
    /// counting axis owes one (the Topic Index pattern).
    public let caption: String?

    /// Optional per-volume trailing accessory text (volumeId → text), e.g.
    /// `"312 docs / 4.2%"` on an administration list or a role note on an editor list.
    public let accessories: [String: String]

    /// Optional per-volume attention note (volumeId → text), rendered as an amber
    /// caption beneath the row — the administration axis's "Also under Eisenhower"
    /// dual-membership disclosure (#1051 B-2, design 1g).
    public let notes: [String: String]

    /// Creates a spec.
    ///
    /// - Parameters:
    ///   - axisKey: Stable identity for the list (see above).
    ///   - title: Display title.
    ///   - volumeIds: Member ids in the axis's order.
    ///   - caption: Coverage caption above the rows, or `nil`.
    ///   - accessories: Per-volume trailing accessory text, keyed by volume id.
    ///   - notes: Per-volume amber attention notes, keyed by volume id.
    public init(
        axisKey: String,
        title: String,
        volumeIds: [String],
        caption: String? = nil,
        accessories: [String: String] = [:],
        notes: [String: String] = [:]
    ) {
        self.axisKey = axisKey
        self.title = title
        self.volumeIds = volumeIds
        self.caption = caption
        self.accessories = accessories
        self.notes = notes
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(axisKey)
    }

    public static func == (lhs: VolumeListSpec, rhs: VolumeListSpec) -> Bool {
        lhs.axisKey == rhs.axisKey
    }
}

// MARK: - VolumeListView

#if os(iOS)

/// The iOS mount of the R-1 shared volume list: an arbitrary ordered volume set rendered
/// with the unified row (`VolumeRowLabel`), a pinned coverage caption, and an optional
/// per-row trailing accessory (#1051 R-1).
///
/// Rows append `.volume` with the same Button-mutating-the-path pattern every Browse row
/// uses (no `NavigationLink` anywhere in Browser/ — a link would be inert in the two-pane
/// layout). Pushing `.volume` without a `.subseries` ancestor is an established path
/// (Corpus → People → Volume ships today); the tag-chip wrinkle it used to carry is fixed
/// by the Q-5 fallback in `BrowserViewModel.activateTagFilter`.
///
/// Version history:
///   1.0 — #1051 B-1: initial implementation
///   1.1 — #1051 B-3: the pan-axis scope affordances land in the SHARED list, so every
///          axis inherits them — the 3b context menu on each row, and the 3c
///          "Save as Scope…" whole-slice capture in the toolbar (name pre-filled from
///          the axis identity)
struct VolumeListView: View {

    let vm: BrowserViewModel
    let spec: VolumeListSpec

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    /// The 3c capture prompt's working name.
    @State private var captureName = ""
    @State private var showingCapturePrompt = false

    var body: some View {
        // Resolved in caller order; unknown ids are skipped, never invented (an axis list can
        // legitimately reference a volume a stale artifact knows and the manifest no longer does).
        let entries = spec.volumeIds.compactMap { appState.manifestStore.entry(forVolumeId: $0) }
        List {
            if let caption = spec.caption {
                // Above the rows, not in a footer — a caveat below the fold cannot do its job
                // (the Topic Index precedent).
                Section {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                ForEach(entries) { entry in
                    Button {
                        vm.navigationPath.append(.volume(entry))
                        #if DEBUG
                        print("[BrowserView] Navigate → volume \(entry.volumeId) (axis \(spec.axisKey))")
                        #endif
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                VolumeRowLabel(
                                    volume: entry,
                                    isDownloaded: vm.isDownloaded(entry.volumeId),
                                    isIndexed: vm.isIndexed(entry.volumeId),
                                    isDownloading: appState.downloadQueue.contains(entry.volumeId),
                                    documentCount: appState.administrationProfilesStore
                                        .documentCount(forVolumeId: entry.volumeId)
                                )
                                if let accessory = spec.accessories[entry.volumeId] {
                                    Text(accessory)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if let note = spec.notes[entry.volumeId] {
                                Text(note)
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        // #1051 B-3 (3b): scope items first, then the volume's own actions.
                        VolumeScopeMenuItems(volumeId: entry.volumeId) { [vm] id in
                            vm.navigationPath.append(.scopeEditor(id))
                        }
                        Divider()
                        VolumeRowContextMenu(volume: entry)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(spec.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // #1051 B-3 (3c): whole-slice capture — the list's current volume set becomes
            // a scope, name pre-filled from the axis identity.
            ToolbarItem(placement: .primaryAction) {
                Button {
                    let count = spec.volumeIds
                        .filter { appState.manifestStore.entry(forVolumeId: $0) != nil }.count
                    captureName = String(localized: "browser.scopes.capture.prefill",
                                         defaultValue: "\(spec.title) (\(count) volumes)")
                    showingCapturePrompt = true
                } label: {
                    Label(String(localized: "browser.scopes.capture", defaultValue: "Save as Scope…"),
                          systemImage: "plus.square.on.square")
                }
                .help(String(localized: "browser.scopes.capture.help",
                             defaultValue: "Save this list’s volumes as a custom scope"))
            }
        }
        .alert(String(localized: "browser.scopes.capture.title", defaultValue: "Save as Scope"),
               isPresented: $showingCapturePrompt) {
            TextField(String(localized: "browser.scopes.capture.name", defaultValue: "Scope name"),
                      text: $captureName)
            Button(String(localized: "browser.scopes.capture.save", defaultValue: "Save")) {
                let ids = spec.volumeIds.filter { appState.manifestStore.entry(forVolumeId: $0) != nil }
                _ = ScopeAxis.create(named: captureName, volumeIds: ids, in: modelContext)
                #if DEBUG
                print("[VolumeListView] Captured scope from \(spec.axisKey): \(ids.count) volumes")
                #endif
            }
            Button(String(localized: "browser.scopes.capture.cancel", defaultValue: "Cancel"),
                   role: .cancel) {}
        } message: {
            Text(String(localized: "browser.scopes.capture.detail",
                        defaultValue: "The scope keeps this list’s volumes; the axis’s ordering and counts stay here."))
        }
    }
}

#endif // os(iOS)
