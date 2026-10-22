// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - AdministrationAxis

/// The Administrations browse axis's pure logic (#1051 A-3, design 1g): the roster rows
/// and the R-1 drill spec, split from the view for testability (the Topic Index pattern).
///
/// ## The settled semantics this encodes (do not re-litigate in session)
/// - **Membership = `volumeCount`** — any dated document, point or range (owner decision
///   Q-2; the #791 history is why the two counts exist at all).
/// - **Attribution is by document COVERAGE date** — who was in office when — never where
///   or when a volume was published, so every caption says "covering", never
///   "published under".
/// - **Any-overlap double counting is disclosed, not hidden**: a volume spanning two
///   administrations appears under both, so memberships sum well past the corpus's 553.
/// - The drill orders its volumes by the documents each row prints, point and range together,
///   most first (`drillOrder(_:)`, #1756). The artifact sorts `volumes` by `pointDocs` alone, and
///   kept as it came the drill read out of order by its own counts: Truman's third and fourth
///   rows printed 1,164 and then 1,242 docs, and 168 of the index's 854 adjacent pairs ran the
///   wrong way, under a caption that said "largest share first". The R-1 contract still holds:
///   the order is the axis's payload, and the list never re-sorts it.
///
/// Version history:
///   1.0 — #1051 B-2: initial implementation
///   1.1 — #1756: the drill is in the order of the documents its rows print (`drillOrder(_:)`,
///          `documents(of:)`), and its caption says so, with its volume count in the singular at one
enum AdministrationAxis {

    /// The term span for display — `"1945–1953"`, or `"2025–present"` for the sitting
    /// administration (mirrors the SA-2b dashboard's `termText`).
    ///
    /// - Parameters:
    ///   - start: The ISO term start (`yyyy-MM-dd`).
    ///   - end: The ISO term end, or `nil` for the sitting administration.
    /// - Returns: The year-span string.
    static func termText(start: String, end: String?) -> String {
        let startYear = String(start.prefix(4))
        if let end {
            return "\(startYear)\u{2013}\(String(end.prefix(4)))"
        }
        // `startYear` is already a String; the wrap is for the year scan, which reads the
        // spelling and not the type, so no year in a `defaultValue:` goes unwrapped (#1382).
        return String(localized: "browser.administrations.term.present",
                      defaultValue: "\(String(startYear))–present")
    }

    /// The other administrations a volume also appears under, keyed by volume id —
    /// computed once per index so each drill's "also under" notes are one lookup.
    ///
    /// - Parameter index: The bundled profiles index.
    /// - Returns: volumeId → the administrations containing it, in presidency order.
    static func membershipMap(for index: AdministrationProfilesIndex) -> [String: [AdministrationProfile]] {
        var map: [String: [AdministrationProfile]] = [:]
        for profile in index.administrations.sorted(by: { $0.number < $1.number }) {
            for volume in profile.volumes {
                map[volume.volumeId, default: []].append(profile)
            }
        }
        return map
    }

    /// The documents a drill row prints for a volume: any dated document, point or range (Q-2).
    ///
    /// - Parameter volume: One of an administration's volumes.
    /// - Returns: Its point and range documents together.
    static func documents(of volume: AdministrationVolume) -> Int {
        volume.pointDocs + volume.rangeDocs
    }

    /// The drill's order (#1756): the documents each row prints (``documents(of:)``), most first;
    /// then the artifact's own rule, point documents first and the volume id, so a tie has one order.
    ///
    /// - Parameter volumes: An administration's volumes, in any order.
    /// - Returns: The same volumes in the order the drill lists them.
    static func drillOrder(_ volumes: [AdministrationVolume]) -> [AdministrationVolume] {
        volumes.sorted { lhs, rhs in
            let lhsDocs = documents(of: lhs), rhsDocs = documents(of: rhs)
            if lhsDocs != rhsDocs { return lhsDocs > rhsDocs }
            if lhs.pointDocs != rhs.pointDocs { return lhs.pointDocs > rhs.pointDocs }
            return lhs.volumeId < rhs.volumeId
        }
    }

    /// Builds the R-1 drill spec for one administration.
    ///
    /// - Parameters:
    ///   - profile: The administration.
    ///   - index: The whole index (for `volumeTotals` denominators and dual membership).
    ///   - membership: The precomputed `membershipMap(for:)`.
    /// - Returns: The spec: ids in ``drillOrder(_:)``, the coverage caption, a
    ///   "N docs · N.N%" accessory per volume, and an "Also under …" note where a volume
    ///   spans administrations.
    static func spec(
        for profile: AdministrationProfile,
        index: AdministrationProfilesIndex,
        membership: [String: [AdministrationProfile]]
    ) -> VolumeListSpec {
        var accessories: [String: String] = [:]
        var notes: [String: String] = [:]
        for volume in profile.volumes {
            let docs = documents(of: volume)
            if let totals = index.volumeTotals[volume.volumeId] {
                let denominator = totals.pointDocs + totals.rangeDocs + totals.undatedDocs
                if denominator > 0 {
                    let share = Double(docs) / Double(denominator) * 100
                    accessories[volume.volumeId] = String(
                        localized: "browser.administrations.accessory",
                        defaultValue: "\(docs) docs · \(share.formatted(.number.precision(.fractionLength(1))))%")
                } else {
                    accessories[volume.volumeId] = String(
                        localized: "browser.administrations.accessory.noShare",
                        defaultValue: "\(docs) docs")
                }
            } else {
                accessories[volume.volumeId] = String(
                    localized: "browser.administrations.accessory.noShare",
                    defaultValue: "\(docs) docs")
            }
            let others = (membership[volume.volumeId] ?? []).filter { $0.id != profile.id }
            if !others.isEmpty {
                let names = others.map(\.president).joined(separator: ", ")
                notes[volume.volumeId] = String(
                    localized: "browser.administrations.alsoUnder",
                    defaultValue: "Also under \(names)")
            }
        }
        // "Most documents first", where it said "largest share first" beside rows whose share is
        // of each volume, which the order does not follow (#1756). Its count goes through
        // `CountCopy`: George H. W. Bush's drill read "1 volumes".
        let caption = String(
            format: String(
                localized: "browser.administrations.drill.caption.v2 %@ %@ %@",
                defaultValue: "%1$@ with documents covering the %2$@ administration (%3$@), most documents first. Membership: any dated document. A volume spanning two administrations appears under both."),
            CountCopy.volumes(profile.volumes.count), profile.president,
            termText(start: profile.start, end: profile.end))
        return VolumeListSpec(
            axisKey: "administration:\(profile.id)",
            title: profile.president,
            volumeIds: drillOrder(profile.volumes).map(\.volumeId),
            caption: caption,
            accessories: accessories,
            notes: notes
        )
    }
}

// MARK: - AdministrationIndexView

/// The Administrations index (#1051 A-3, design 1g): every administration from Lincoln
/// on, in presidency order, with its reach — drilling to the R-1 volume list.
///
/// Shared across both platforms behind one `onSelect` closure (the catalogue's pattern):
/// the iOS level pushes `.volumeList`, the macOS Corpus Browser pushes its
/// `.axisList` case. Zero-volume administrations (Clinton onward — FRUS is not yet
/// published for them) render **disabled with the reason, never hidden** — the
/// "disabled rather than dead" idiom the semantic map's scope menu established.
///
/// Version history:
///   1.0 — #1051 B-2: initial implementation
///   1.1 — #1761: a row's volume and document counts, and its VoiceOver label, say one in the
///          singular ("1 vol", where it read "1 vols")
struct AdministrationIndexView: View {

    /// The bundled profiles index, or `nil` when it failed to decode.
    let index: AdministrationProfilesIndex?
    /// Row action — the mount's navigation, handed the ready-built drill spec.
    let onSelect: @MainActor (VolumeListSpec) -> Void

    var body: some View {
        List {
            if let index, !index.administrations.isEmpty {
                Section {
                    Text(coverageCaption(for: index))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                rows(for: index)
            } else {
                // The tolerant decode means a malformed artifact yields an empty axis —
                // surface an explicit empty state rather than a silent blank list.
                Section {
                    ContentUnavailableView(
                        String(localized: "browser.administrations.unavailable.title",
                               defaultValue: "Administrations Unavailable"),
                        systemImage: "building.columns",
                        description: Text(String(
                            localized: "browser.administrations.unavailable.detail",
                            defaultValue: "The bundled administration data could not be loaded. Reinstalling the app restores it."))
                    )
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
        .navigationTitle(String(localized: "browser.administrations.title",
                                defaultValue: "Administrations"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    /// The honesty caption above the roster (the Topic Index pattern): what the counts
    /// mean, and the any-overlap disclosure with the LIVE membership sum.
    private func coverageCaption(for index: AdministrationProfilesIndex) -> String {
        let membershipSum = index.administrations.reduce(0) { $0 + $1.volumeCount }
        return String(
            localized: "browser.administrations.coverage",
            defaultValue: "Volumes filed by the administration their documents cover — dated to each term, never by where a volume was published. A volume spanning two administrations appears under both: memberships sum to \(membershipSum) across \(index.volumeTotals.count) volumes.")
    }

    @ViewBuilder
    private func rows(for index: AdministrationProfilesIndex) -> some View {
        let membership = AdministrationAxis.membershipMap(for: index)
        Section {
            ForEach(index.administrations.sorted(by: { $0.number < $1.number }), id: \.id) { profile in
                if profile.volumeCount > 0 {
                    Button {
                        onSelect(AdministrationAxis.spec(for: profile, index: index, membership: membership))
                        #if DEBUG
                        print("[AdministrationIndexView] Navigate → \(profile.id)")
                        #endif
                    } label: {
                        rowLabel(profile, enabled: true)
                            // Both modifiers, in this order — the #312 full-row tap-target idiom.
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(rowA11yLabel(profile))
                    .help(String(localized: "browser.administrations.row.help",
                                 defaultValue: "Browse the volumes with documents covering this administration"))
                } else {
                    // Disabled, never hidden: the reader learns WHY Clinton onward is
                    // not browsable instead of wondering where the recent past went.
                    rowLabel(profile, enabled: false)
                        .accessibilityLabel(rowA11yLabel(profile))
                        .accessibilityHint(Self.noVolumesReason)
                }
            }
        }
    }

    /// The disabled rows' reason, shown inline and read by VoiceOver.
    static var noVolumesReason: String {
        String(localized: "browser.administrations.none",
               defaultValue: "No published volumes cover this administration yet")
    }

    @ViewBuilder
    private func rowLabel(_ profile: AdministrationProfile, enabled: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(profile.number)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.president)
                    .font(.body)
                Text("\(AdministrationAxis.termText(start: profile.start, end: profile.end)) · \(profile.party)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !enabled {
                    Text(Self.noVolumesReason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if enabled {
                // Each count says one in the singular: George H. W. Bush's row read "1 vols" (#1761).
                VStack(alignment: .trailing, spacing: 2) {
                    Text(CountCopy.vols(profile.volumeCount))
                    Text(CountCopy.docs(profile.pointDocCount + profile.rangeDocCount))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
        .opacity(enabled ? 1 : 0.45)
    }

    /// What VoiceOver reads for a row, its volume count in the singular at one, as the row prints it (#1761).
    private func rowA11yLabel(_ profile: AdministrationProfile) -> String {
        String(localized: "browser.administrations.row.a11y.v2",
               defaultValue: "\(profile.president), \(AdministrationAxis.termText(start: profile.start, end: profile.end)), \(CountCopy.volumes(profile.volumeCount))")
    }
}

// MARK: - BrowseAdministrationsLevel (iOS mount)

#if os(iOS)

/// The iOS mount: `BrowserLevel.administrations`, wired to the eager store on `AppState`;
/// a row pushes the ready-built R-1 spec.
///
/// Version history:
///   1.0 — #1051 B-2: initial implementation
struct BrowseAdministrationsLevel: View {
    let vm: BrowserViewModel

    @Environment(AppState.self) private var appState

    var body: some View {
        AdministrationIndexView(
            index: appState.administrationProfilesStore.index,
            onSelect: { [vm] spec in
                vm.navigationPath.append(.volumeList(spec))
            }
        )
    }
}

#endif // os(iOS)
