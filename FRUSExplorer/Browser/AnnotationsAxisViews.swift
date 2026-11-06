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
/// **At regular width the strips stack into a matrix** (§6, lane D): on an iPad's regular width and
/// on the Mac, each group opens with a row naming the eras, and each layer's row is its name, which
/// opens its page, beside eleven cells, each of which opens that era's volumes that carry the layer
/// (`onSelectEra`). On an iPhone a cell would be about 20 pt wide, under a tap's 44, so there the
/// strip stays a picture and the row opens the page.
///
/// Version history:
///   1.0 — 2026-11-06: the editors' annotations design, lane C
///   1.1 — 2026-11-06: lane D — the regular-width matrix (`AnnotationsMatrixHeader`,
///          `AnnotationsMatrixRow`) and `onSelectEra`
struct AnnotationsIndexView: View {
    /// The bundled file, or `nil` when it failed to load.
    let index: VolumeAnnotationsIndex?
    /// Row action: the mount's navigation to the layer's page.
    let onSelect: @MainActor (AnnotationLayer) -> Void
    /// A matrix cell's action: the mount's navigation to the era's volume list. `nil` draws no matrix.
    var onSelectEra: (@MainActor (VolumeListSpec) -> Void)? = nil

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    /// Whether the rows are a matrix: at regular width, where a cell is wide enough to tap.
    private var isMatrix: Bool {
        guard onSelectEra != nil else { return false }
        #if os(iOS)
        return horizontalSizeClass == .regular
        #else
        return true
        #endif
    }

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
                        if isMatrix { AnnotationsMatrixHeader() }
                        ForEach(AnnotationLayer.allCases.filter { $0.family == family }) { layer in
                            if isMatrix, let onSelectEra {
                                AnnotationsMatrixRow(reach: AnnotationsAxis.reach(of: layer, in: index), index: index,
                                                     onSelect: onSelect, onSelectEra: onSelectEra)
                            } else {
                                row(AnnotationsAxis.reach(of: layer, in: index))
                            }
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

// MARK: - The regular-width matrix

/// The width of the matrix's first column, the layers' names, shared by its header and its rows so
/// that the cells line up under the eras' names.
private enum AnnotationsMatrixMetrics {
    /// The names' column at the default text size; each view scales it with the text.
    static let labelWidth: CGFloat = 230
}

/// The row that opens a group of the matrix: the eras' first years over the cells' columns.
///
/// Version history:
///   1.0 — 2026-11-06: the editors' annotations design, lane D
struct AnnotationsMatrixHeader: View {
    @ScaledMetric(relativeTo: .body) private var labelWidth: CGFloat = AnnotationsMatrixMetrics.labelWidth

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            Color.clear.frame(width: labelWidth, height: 1)
            HStack(spacing: 2) {
                ForEach(AnnotationsAxis.stripEras, id: \.self) { era in
                    Text(AnnotationsAxis.shortEraName(era))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity)
                        .padding(.leading, era == .retrospective ? 6 : 0)
                }
            }
        }
        // Each cell reads its era aloud, so the header would only repeat it.
        .accessibilityHidden(true)
    }
}

/// One layer's row of the matrix: its name, which opens its page, beside its eleven cells, each a
/// button that opens the era's volumes carrying it. A cell no volume of its era fills is drawn, read
/// and disabled, never hidden.
///
/// Version history:
///   1.0 — 2026-11-06: the editors' annotations design, lane D
struct AnnotationsMatrixRow: View {
    /// The layer's reach.
    let reach: AnnotationsAxis.Reach
    /// The bundled file, for a cell's drill.
    let index: VolumeAnnotationsIndex
    /// The name's action: the layer's page.
    let onSelect: @MainActor (AnnotationLayer) -> Void
    /// A cell's action: its era's volume list.
    let onSelectEra: @MainActor (VolumeListSpec) -> Void

    @ScaledMetric(relativeTo: .body) private var labelWidth: CGFloat = AnnotationsMatrixMetrics.labelWidth
    @ScaledMetric(relativeTo: .caption) private var cellHeight: CGFloat = 22
    // The symbols' column, as on a volume's page (`VolumeAnnotationsRowView`).
    #if os(macOS)
    @ScaledMetric(relativeTo: .body) private var symbolWidth: CGFloat = 28
    #else
    @ScaledMetric(relativeTo: .body) private var symbolWidth: CGFloat = 36
    #endif

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                onSelect(reach.layer)
                #if DEBUG
                print("[AnnotationsMatrixRow] Navigate → \(reach.layer.rawValue)")
                #endif
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: reach.layer.symbol)
                        .foregroundStyle(.secondary)
                        .frame(width: symbolWidth)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(reach.layer.label)
                        Text(AnnotationsAxis.volumesLine(reach.carrying.count, of: reach.total))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    VolumeAnnotationsRowView.chevron
                }
                .frame(width: labelWidth, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AnnotationsAxis.spokenRow(for: reach))
            .accessibilityIdentifier("annotations.layer.\(reach.layer.rawValue)")
            .help(String(localized: "browser.annotations.row.help",
                         defaultValue: "What the editors did, when it became standard, and the volumes that carry it"))

            HStack(spacing: 2) {
                ForEach(reach.bands) { band in
                    cell(band)
                        .padding(.leading, band.era == .retrospective ? 6 : 0)
                }
            }
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private func cell(_ band: AnnotationsAxis.Band) -> some View {
        let spoken = AnnotationsAxis.spokenCell(reach.layer, band)
        Button {
            onSelectEra(AnnotationsAxis.eraDrill(for: reach.layer, era: band.era, in: index).spec)
            #if DEBUG
            print("[AnnotationsMatrixRow] Navigate → \(reach.layer.rawValue) in \(band.era.rawValue)")
            #endif
        } label: {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(AnnotationEraStrip.fill(band))
                .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.35), lineWidth: 0.5))
                .frame(maxWidth: .infinity)
                .frame(height: cellHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(band.carrying == 0)
        .accessibilityLabel(spoken)
        .accessibilityIdentifier("annotations.cell.\(reach.layer.rawValue).\(band.era.rawValue)")
        .help(spoken)
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

// MARK: - PeopleTaggingCaption

/// The line the People browser and Person analytics carry (the design's §6, lane D): how many volumes
/// tag their people, that only those volumes' people appear, and a way to the volumes. A reader
/// studying an 1890s figure otherwise finds nothing there and is not told why.
///
/// The count is the bundled file's, so it is the same before and after downloads. The link is drawn
/// only where its host can deliver it (`onOpen`).
///
/// Version history:
///   1.0 — 2026-11-06: the editors' annotations design, lane D
struct PeopleTaggingCaption: View {
    /// Opens People tagged's page on the Editors’ Annotations axis, or `nil` where the host cannot.
    var onOpen: (@MainActor () -> Void)? = nil

    var body: some View {
        if let text = Self.text() {
            VStack(alignment: .leading, spacing: 6) {
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("people.tagging.caption")
                if let onOpen {
                    Button(String(localized: "people.tagging.link", defaultValue: "Volumes that tag people")) {
                        onOpen()
                    }
                    .font(.caption)
                    #if os(macOS)
                    .buttonStyle(.link)
                    #else
                    .buttonStyle(.borderless)
                    #endif
                    .accessibilityIdentifier("people.tagging.link")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The caption, from `index`, or `nil` when the file did not load.
    static func text(index: VolumeAnnotationsIndex? = VolumeAnnotationsStore.shared,
                     locale: Locale = .autoupdatingCurrent) -> String? {
        guard let index, !index.volumes.isEmpty else { return nil }
        let reach = AnnotationsAxis.reach(of: .people, in: index)
        return String(format: String(localized: "people.tagging.caption",
                                     defaultValue: "People are tagged in %@, and only those volumes' people appear here. In the others, search for the names."),
                      AnnotationsAxis.volumesLine(reach.carrying.count, of: reach.total, locale: locale))
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
        AnnotationsIndexView(
            index: VolumeAnnotationsStore.shared,
            onSelect: { [vm] layer in
                vm.navigationPath.append(.annotationCategory(id: layer.rawValue, fromVolume: nil))
            },
            onSelectEra: { [vm] spec in vm.navigationPath.append(.volumeList(spec)) })
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
