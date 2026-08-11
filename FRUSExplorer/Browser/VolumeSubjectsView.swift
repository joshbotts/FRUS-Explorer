// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - VolumeSubjectsChips

/// The "Top subjects" content for a volume: the volume's most characteristic subjects
/// (from `VolumeSubjectProfilesStore`) as category-grouped chips. Tapping a chip lists
/// the other volumes that share the subject.
///
/// Presentation-agnostic (a plain `VStack`) so both the iOS `VolumeView` List (wrapped in
/// a `Section`) and the macOS `CorpusVolumeDetailView` (in its detail column) can host it.
/// It renders from the bundled aggregate, so it works for volumes the user has not
/// downloaded or indexed.
///
/// Call sites gate on `VolumeSubjectsChips.hasContent(forVolumeId:)` so an empty profile
/// shows no section at all.
///
/// Version history:
///   1.0 — Session 9: initial implementation
///   1.1 — Session 9 review: chip-row scroll indicators stay visible on macOS
///         (an indicator-less overflowing row gave no cue that more chips exist)
struct VolumeSubjectsChips: View {

    /// The volume whose profile is shown.
    let volume: VolumeManifestEntry

    /// #338 step 4: this window's scene, injected into the cross-volume sheet so its volume-open
    /// hand-off targets THIS window.
    @Environment(\.sceneID) private var sceneID

    /// The subject whose cross-volume sheet is open, or `nil`.
    @State private var selectedSubject: VolumeSubjectProfiles.ResolvedSubject?

    /// `true` when the bundled aggregate carries at least one subject for the volume.
    ///
    /// - Parameter volumeId: The manifest volume id.
    /// - Returns: Whether a non-empty profile exists (the gate for showing the section).
    static func hasContent(forVolumeId volumeId: String) -> Bool {
        !(VolumeSubjectProfilesStore.shared?.topSubjects(forVolumeId: volumeId)?.isEmpty ?? true)
    }

    private var groups: [(category: String, subjects: [VolumeSubjectProfiles.ResolvedSubject])] {
        VolumeSubjectProfilesStore.shared?.groupedTopSubjects(forVolumeId: volume.volumeId) ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(groups, id: \.category) { group in
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.category)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .accessibilityAddTraits(.isHeader)
                    // Indicators stay visible on macOS: without them an overflowing
                    // chip row gives no cue that more chips exist (no touch affordance
                    // there); on iOS the platform swipe convention carries it.
                    #if os(macOS)
                    let showsIndicators = true
                    #else
                    let showsIndicators = false
                    #endif
                    ScrollView(.horizontal, showsIndicators: showsIndicators) {
                        HStack(spacing: 6) {
                            ForEach(group.subjects) { subject in
                                chip(subject)
                            }
                        }
                        .padding(.vertical, 1)
                    }
                }
            }
        }
        .sheet(item: $selectedSubject) { subject in
            VolumeSubjectVolumesSheet(subject: subject, currentVolumeId: volume.volumeId)
                .environment(\.sceneID, sceneID)
        }
    }

    @ViewBuilder
    private func chip(_ subject: VolumeSubjectProfiles.ResolvedSubject) -> some View {
        Button {
            selectedSubject = subject
        } label: {
            Text(subject.name)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(subject.name)
        .accessibilityValue(subject.category)
        .accessibilityHint(String(localized: "browser.volume.subjectChip.hint",
                                  defaultValue: "Shows other volumes covering this subject"))
        .help(String(localized: "browser.volume.subjectChip.help",
                     defaultValue: "Show other FRUS volumes that cover this subject"))
    }
}

// MARK: - VolumeSubjectVolumesSheet

/// Lists the other FRUS volumes whose profile carries a subject — the cross-volume
/// pivot from a "Top subjects" chip. Each row opens its volume in the browser via the
/// same `AppState.pendingBrowseVolume` hand-off the cross-volume provenance list uses.
///
/// Works across the whole 552-volume corpus, including volumes the user has not
/// downloaded (the profiles are a bundled aggregate).
///
/// Version history:
///   1.0 — Session 9: initial implementation
///   1.1 — Session 9 review: singular/plural header forms; the zero-volume case is
///         owned entirely by the ContentUnavailableView (no "0 other volumes" header
///         behind the overlay)
///   1.2 — Session 2026-08-11: #833, the topic door — the covering volumes open as an
///         archival profile
struct VolumeSubjectVolumesSheet: View {

    /// The subject being pivoted on.
    let subject: VolumeSubjectProfiles.ResolvedSubject
    /// The volume currently being viewed (excluded from the list), or `""` when the pivot
    /// comes from a non-volume context (the #264 person affinity chips) and nothing is
    /// excluded — the header wording adapts.
    let currentVolumeId: String
    /// Invoked after a row-tap navigation, so a presenting sheet ABOVE this one (the person
    /// detail sheet, #264) can dismiss itself too — otherwise it would keep covering the browse
    /// surface that just navigated. `nil` (the volume-detail context) dismisses only this sheet.
    var onNavigate: (() -> Void)? = nil

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    /// #338 step 4: the scene this sheet renders in, so a volume-row tap's hand-off addresses the
    /// presenting window. Injected by each presenter (incl. the nested PersonIndex path); nil on macOS.
    @Environment(\.sceneID) private var sceneID
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    private var otherVolumeIds: [String] {
        VolumeSubjectProfilesStore.shared?
            .otherVolumes(forSubjectRef: subject.ref, excluding: currentVolumeId) ?? []
    }

    /// Every volume whose profile carries the subject, the volume being viewed INCLUDED.
    ///
    /// Deliberately not `otherVolumeIds`: the list above answers "where else can I read about
    /// this", so excluding the volume in hand is right, while the archival profile answers "which
    /// archives do volumes on this subject draw on", and dropping one of them would quietly
    /// under-count. The button's own count says which set it means.
    private var coveringVolumeIds: [String] {
        VolumeSubjectProfilesStore.shared?.volumesBySubjectRef[subject.ref] ?? []
    }

    /// The pluralized section header. Two keys per context rather than a format inflection so
    /// translators see every form. "Other" is only truthful when a current volume is excluded;
    /// the person-affinity pivot (`currentVolumeId == ""`) lists ALL covering volumes.
    private var countHeader: String {
        if currentVolumeId.isEmpty {
            return otherVolumeIds.count == 1
                ? String(localized: "browser.volume.subjectVolumes.header.all.one",
                         defaultValue: "1 volume covers this subject")
                : String(format: String(localized: "browser.volume.subjectVolumes.header.all.many %lld",
                                        defaultValue: "%lld volumes cover this subject"),
                         Int64(otherVolumeIds.count))
        }
        return otherVolumeIds.count == 1
            ? String(localized: "browser.volume.subjectVolumes.header.one",
                     defaultValue: "1 other volume covers this subject")
            : String(format: String(localized: "browser.volume.subjectVolumes.header.many %lld",
                                    defaultValue: "%lld other volumes cover this subject"),
                     Int64(otherVolumeIds.count))
    }

    var body: some View {
        NavigationStack {
            List {
                // The Section renders only when there are rows: the zero-volume case is
                // fully owned by the ContentUnavailableView overlay (a "0 other volumes"
                // header peeking out from behind it read as a glitch).
                if !otherVolumeIds.isEmpty {
                    Section {
                        ForEach(otherVolumeIds, id: \.self) { volumeId in
                            Button {
                                open(volumeId)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(appState.manifestStore.entry(forVolumeId: volumeId)?.title ?? volumeId)
                                        .font(.callout)
                                    Text(volumeId)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint(String(localized: "browser.volume.subjectVolumes.row.hint",
                                                      defaultValue: "Opens this volume in the browser"))
                        }
                    } header: {
                        Text(countHeader)
                    } footer: {
                        Text(subject.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                archivalProfileSection
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
            .overlay {
                if otherVolumeIds.isEmpty {
                    ContentUnavailableView(
                        String(localized: "browser.volume.subjectVolumes.empty.title",
                               defaultValue: "Only this volume"),
                        systemImage: "books.vertical",
                        description: Text(String(localized: "browser.volume.subjectVolumes.empty.message",
                                                 defaultValue: "No other volume's top subjects include this one."))
                    )
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 420)
        #endif
    }

    /// The topic door (#833): the archival profile of every volume covering this subject.
    ///
    /// Withheld below two volumes. A one-volume "profile of volumes on this subject" is that
    /// volume's own profile wearing a topic's name, which is exactly the misreading the caption
    /// below guards against.
    @ViewBuilder
    private var archivalProfileSection: some View {
        if coveringVolumeIds.count > 1 {
            Section {
                Button {
                    openArchivalProfile()
                } label: {
                    Label(String(localized: "browser.volume.subjectVolumes.archival.button",
                                 defaultValue: "Archival profile of these volumes"),
                          systemImage: "archivebox")
                }
            } footer: {
                // The load-bearing sentence. The scope is WHOLE VOLUMES that rank this subject
                // among their most characteristic, so the profile describes the archives those
                // volumes draw on — not the archives behind the documents about this subject,
                // which is what a reader will assume unless told otherwise.
                Text(String(format: String(
                    localized: "browser.volume.subjectVolumes.archival.footer %lld",
                    defaultValue: "Ranks the collections and file series the %lld volumes covering this subject draw on. The scope is whole volumes, not the documents about this subject inside them — and the subjects themselves are detected automatically, not editorial headings."),
                    Int64(coveringVolumeIds.count)))
            }
        }
    }

    /// Hands the covering volumes to Archival Analytics and closes up behind itself.
    ///
    /// **iOS dismisses first and hands off on the next turn.** The destination is a sheet
    /// presented by the tab shell, and dismissing one sheet while presenting another in the same
    /// state change drops the second — the surface would simply never appear. macOS has no such
    /// conflict: the destination is a window, so the hand-off and the dismissal can be one step.
    private func openArchivalProfile() {
        let request = ArchivalScopeRequest(
            volumeIds: coveringVolumeIds,
            label: String(format: String(
                localized: "browser.volume.subjectVolumes.archival.scopeLabel %@",
                defaultValue: "Volumes on %@"), subject.name))
        #if os(macOS)
        appState.openArchivalScope(request, from: sceneID)
        openWindow.fronting(id: "frus.archivalAnalytics")
        dismiss()
        onNavigate?()
        #else
        dismiss()
        onNavigate?()
        let appState = appState
        let sceneID = sceneID
        Task { @MainActor in appState.openArchivalScope(request, from: sceneID) }
        #endif
    }

    /// Navigates to the tapped volume (Browse tab on iOS; the Corpus Browser window on
    /// macOS), mirroring `CrossVolumeProvenanceContent.open`, then lets any presenting
    /// context dismiss itself via `onNavigate`.
    private func open(_ volumeId: String) {
        appState.openBrowseVolume(volumeId, from: sceneID)
        #if os(macOS)
        openWindow.fronting(id: "frus.corpusBrowser")
        #else
        appState.openTab(.browse, from: sceneID)
        #endif
        dismiss()
        onNavigate?()
    }
}
