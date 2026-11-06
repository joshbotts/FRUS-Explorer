// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - AnnotationEraStrip

/// A layer's reach era by era: one cell per era, earliest first and the late retrospectives last,
/// shaded by the share of the era's volumes that carry the layer (the design's §6). An era none of
/// whose volumes carries it is an outline.
///
/// Compact in an axis row, where the row's own label says what VoiceOver needs and the strip is
/// hidden from it; labelled at full size on a layer's page, where each cell names its era under it
/// and reads its own count to VoiceOver ("1955–1968: 58 of 60 volumes").
///
/// Version history:
///   1.0 — 2026-11-06: the editors' annotations design, lane C
struct AnnotationEraStrip: View {
    /// The layer's eras, in strip order.
    let bands: [AnnotationsAxis.Band]
    /// `true` for the full strip on a layer's page.
    var isLabelled: Bool = false

    @ScaledMetric(relativeTo: .caption) private var compactHeight: CGFloat = 8
    @ScaledMetric(relativeTo: .caption) private var fullHeight: CGFloat = 24

    var body: some View {
        HStack(alignment: .top, spacing: 2) {
            ForEach(bands) { band in
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Self.fill(band))
                        .overlay(RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .strokeBorder(Color.secondary.opacity(0.35), lineWidth: 0.5))
                        .frame(height: isLabelled ? fullHeight : compactHeight)
                    if isLabelled {
                        Text(AnnotationsAxis.shortEraName(band.era))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                }
                .frame(maxWidth: .infinity)
                // The retrospectives are a band of their own, not the next era: set them apart.
                .padding(.leading, band.era == .retrospective ? 6 : 0)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(AnnotationsAxis.spokenBand(band))
            }
        }
        .accessibilityHidden(!isLabelled)
    }

    /// A cell's fill: the accent, as strong as the share, and clear at none.
    static func fill(_ band: AnnotationsAxis.Band) -> Color {
        band.carrying == 0 ? .clear : Color.accentColor.opacity(0.15 + 0.85 * band.share)
    }
}

// MARK: - AnnotationsIndexView

/// The Editors’ Annotations axis (`Planning/Editors-Annotations-Design-2026-11-06.md`, §6): every
/// layer in the three groups a volume's page uses, each with how many volumes carry it and its strip,
/// opening the layer's page.
///
/// Shared by both platforms behind one `onSelect` closure, the Administrations axis's pattern: the
/// iOS level pushes `.annotationCategory`, the Mac's Corpus Browser its own value of that name.
///
/// Version history:
///   1.0 — 2026-11-06: the editors' annotations design, lane C
struct AnnotationsIndexView: View {
    /// The bundled file, or `nil` when it failed to load.
    let index: VolumeAnnotationsIndex?
    /// Row action: the mount's navigation to the layer's page.
    let onSelect: @MainActor (AnnotationLayer) -> Void

    var body: some View {
        List {
            if let index, !index.volumes.isEmpty {
                Section {
                    Text(AnnotationsAxis.indexCaption(total: index.volumes.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(AnnotationCategory.Family.allCases, id: \.self) { family in
                    Section {
                        ForEach(AnnotationLayer.allCases.filter { $0.family == family }) { layer in
                            row(AnnotationsAxis.reach(of: layer, in: index))
                        }
                    } header: {
                        Text(AnnotationsAxis.familyTitle(family))
                            .accessibilityAddTraits(.isHeader)
                    }
                }
            } else {
                // A file that did not load is said, not left as a blank list.
                Section {
                    ContentUnavailableView(
                        String(localized: "browser.annotations.unavailable.title",
                               defaultValue: "Editors’ Annotations Unavailable"),
                        systemImage: "pencil.line",
                        description: Text(String(
                            localized: "browser.annotations.unavailable.detail",
                            defaultValue: "The bundled annotation data could not be loaded. Reinstalling the app restores it."))
                    )
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
        .navigationTitle(VolumeAnnotationsPresentation.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @ViewBuilder
    private func row(_ reach: AnnotationsAxis.Reach) -> some View {
        Button {
            onSelect(reach.layer)
            #if DEBUG
            print("[AnnotationsIndexView] Navigate → \(reach.layer.rawValue)")
            #endif
        } label: {
            AnnotationLayerRowLabel(reach: reach)
                // Both modifiers, in this order — the #312 full-row tap-target idiom.
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AnnotationsAxis.spokenRow(for: reach))
        .accessibilityIdentifier("annotations.layer.\(reach.layer.rawValue)")
        .help(String(localized: "browser.annotations.row.help",
                     defaultValue: "What the editors did, when it became standard, and the volumes that carry it"))
    }
}

/// One layer's row on the axis: its symbol, its name, how many volumes carry it, and its strip.
///
/// Version history:
///   1.0 — 2026-11-06: the editors' annotations design, lane C
struct AnnotationLayerRowLabel: View {
    /// The layer's reach.
    let reach: AnnotationsAxis.Reach

    // The symbols' column, as on a volume's page (`VolumeAnnotationsRowView`).
    #if os(macOS)
    @ScaledMetric(relativeTo: .body) private var symbolWidth: CGFloat = 28
    #else
    @ScaledMetric(relativeTo: .body) private var symbolWidth: CGFloat = 36
    #endif

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: reach.layer.symbol)
                .foregroundStyle(.secondary)
                .frame(width: symbolWidth)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(reach.layer.label)
                Text(AnnotationsAxis.volumesLine(reach.carrying.count, of: reach.total))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                AnnotationEraStrip(bands: reach.bands)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 3)
    }
}

// MARK: - AnnotationCategoryView

/// One layer's page on the axis (the design's §6): what the editors did, when it became standard, the
/// strip at full size, what the app does with it, and its drills into the volumes with it and
/// without it (or, for the printed aids, one drill per aid).
///
/// Opened from the axis, or from a row of a volume's page, whose volume each drill then marks with a
/// note. Shared by both platforms behind its closures.
///
/// Version history:
///   1.0 — 2026-11-06: the editors' annotations design, lane C
struct AnnotationCategoryView: View {
    /// The layer.
    let layer: AnnotationLayer
    /// The bundled file, or `nil` when it failed to load.
    let index: VolumeAnnotationsIndex?
    /// The volume whose page opened this one, or `nil`.
    var fromVolumeId: String? = nil
    /// A drill's action: the mount's navigation to the volume list.
    let onDrill: @MainActor (VolumeListSpec) -> Void
    /// The link to the screen that reads the layer, or `nil` where the mount has no way there.
    var onOpenLink: (@MainActor (AnnotationLayer.AppLink) -> Void)? = nil

    var body: some View {
        List {
            if let index, !index.volumes.isEmpty {
                let reach = AnnotationsAxis.reach(of: layer, in: index)
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(AnnotationsAxis.volumesLine(reach.carrying.count, of: reach.total))
                            .font(.headline)
                        Text(layer.rule)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("annotations.category.reach")
                }
                Section {
                    Text(layer.practice)
                } header: {
                    Text(String(localized: "browser.annotations.category.practice",
                                defaultValue: "What the editors did"))
                }
                Section {
                    let standard = AnnotationsAxis.standardLine(for: reach)
                    if !standard.isEmpty {
                        Text(standard)
                            .accessibilityIdentifier("annotations.category.standard")
                    }
                    AnnotationEraStrip(bands: reach.bands, isLabelled: true)
                        .padding(.vertical, 4)
                } header: {
                    Text(String(localized: "browser.annotations.category.eras",
                                defaultValue: "Era by era"))
                }
                Section {
                    Text(layer.appUse)
                    if let link = layer.appLink, let onOpenLink {
                        Button(link.title) { onOpenLink(link) }
                            .accessibilityIdentifier("annotations.category.link")
                    }
                } header: {
                    Text(String(localized: "browser.annotations.category.app",
                                defaultValue: "In the app"))
                }
                Section {
                    ForEach(AnnotationsAxis.drills(for: layer, in: index, from: fromVolumeId)) { drill in
                        drillRow(drill)
                    }
                } header: {
                    Text(String(localized: "browser.annotations.category.volumes", defaultValue: "Volumes"))
                }
            } else {
                Section {
                    ContentUnavailableView(
                        String(localized: "browser.annotations.unavailable.title",
                               defaultValue: "Editors’ Annotations Unavailable"),
                        systemImage: "pencil.line",
                        description: Text(String(
                            localized: "browser.annotations.unavailable.detail",
                            defaultValue: "The bundled annotation data could not be loaded. Reinstalling the app restores it."))
                    )
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
        .navigationTitle(layer.label)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @ViewBuilder
    private func drillRow(_ drill: AnnotationsAxis.Drill) -> some View {
        Button {
            onDrill(drill.spec)
            #if DEBUG
            print("[AnnotationCategoryView] Navigate → \(drill.spec.axisKey)")
            #endif
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(drill.title)
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                Text(drill.count.formatted())
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            // Both modifiers, in this order — the #312 full-row tap-target idiom.
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(format: String(localized: "browser.annotations.drill.spoken",
                                                  defaultValue: "%1$@: %2$@"),
                                   drill.title, CountCopy.volumes(drill.count)))
        .accessibilityIdentifier("annotations.drill.\(drill.id)")
    }
}

// MARK: - iOS mounts

#if os(iOS)

/// The iOS mount of the axis: `BrowserLevel.annotations`; a row pushes the layer's page.
///
/// Version history:
///   1.0 — 2026-11-06: the editors' annotations design, lane C
struct BrowseAnnotationsLevel: View {
    /// The Browse stack's view model.
    let vm: BrowserViewModel

    var body: some View {
        AnnotationsIndexView(index: VolumeAnnotationsStore.shared, onSelect: { [vm] layer in
            vm.navigationPath.append(.annotationCategory(id: layer.rawValue, fromVolume: nil))
        })
    }
}

/// The iOS mount of a layer's page: `BrowserLevel.annotationCategory`; a drill pushes the R-1 volume
/// list, and the link pushes People or Archives in the same stack.
///
/// Version history:
///   1.0 — 2026-11-06: the editors' annotations design, lane C
struct BrowseAnnotationCategoryLevel: View {
    /// The Browse stack's view model.
    let vm: BrowserViewModel
    /// The layer.
    let layer: AnnotationLayer
    /// The volume whose page opened this one, or `nil`.
    let fromVolumeId: String?

    var body: some View {
        AnnotationCategoryView(
            layer: layer,
            index: VolumeAnnotationsStore.shared,
            fromVolumeId: fromVolumeId,
            onDrill: { [vm] spec in vm.navigationPath.append(.volumeList(spec)) },
            onOpenLink: { [vm] link in
                switch link {
                case .people: vm.navigationPath.append(.people)
                case .archives: vm.navigationPath.append(.archives)
                }
            })
    }
}

#endif // os(iOS)
