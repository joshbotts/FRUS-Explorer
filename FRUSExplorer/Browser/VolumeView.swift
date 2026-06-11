// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - VolumeView

/// Browser level showing volume metadata, tag chips, and the section/compilation list.
///
/// Volume structure is loaded lazily via `BrowserViewModel.loadVolumeStructure(for:)` on
/// appear. If the volume is not downloaded, a "Download Required" placeholder is shown
/// instead. Tag chips call `vm.activateTagFilter(slug:forSubseries:)` which pops navigation
/// back to the Subseries level with the filter applied.
///
/// ## Front Matter Split (Session 2026-06-08)
/// The section list is split into three groups: **Front Matter** (preface, persons,
/// sources, terms, press release, summary, etc.), **Contents** (compilations, chapters,
/// appendices), and **Back Matter** (errata, index). The `<front>` and `<back>` wrapper
/// sections are automatically expanded so their subsections appear directly rather than
/// requiring an extra tap to enter the wrapper.
///
/// Version history:
///   1.0 — Session 11: initial implementation
///   2.0 — Session 2026-06-08: Front Matter / Contents split; front-matter div types surfaced
///   2.1 — Session 2026-06-10: kind sets moved to `VolumeSection.frontMatterKinds`
///          (real corpus encoding); Back Matter group added with `<back>` expansion
///   2.2 — Session 153: added a toolbar button presenting `VolumeConnectionGraphView`
///          in a sheet, closing the iOS gap with the macOS corpus browser's
///          per-volume cross-reference graph affordance
struct VolumeView: View {

    let vm: BrowserViewModel
    let volume: VolumeManifestEntry

    @State private var showConnectionGraph = false

    var body: some View {
        List {
            // Volume metadata header
            Section {
                VolumeMetadataView(volume: volume)
            }

            // Tag chips
            let chips = vm.tagChips(for: volume)
            if !chips.isEmpty {
                Section(header: Text(String(localized: "browser.volume.tags.header",
                                            defaultValue: "Tags"))) {
                    VolumeTagChipsView(vm: vm, volume: volume, chips: chips)
                }
            }

            // Structure / section list
            volumeStructureSection
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
        .navigationTitle(volume.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .task { await vm.loadVolumeStructure(for: volume) }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                let isIndexed = vm.isIndexed(volume.volumeId)
                Button {
                    showConnectionGraph = true
                } label: {
                    Label(
                        String(localized: "browser.volume.connectionGraph",
                               defaultValue: "Cross-Volume Connections"),
                        systemImage: "point.3.connected.trianglepath.dotted"
                    )
                }
                .disabled(!isIndexed)
                .accessibilityLabel(
                    String(localized: "browser.volume.connectionGraph.a11y",
                           defaultValue: "Cross-volume connection graph for \(volume.volumeId)")
                )
                .accessibilityHint(
                    isIndexed
                        ? ""
                        : String(localized: "browser.volume.connectionGraph.notIndexed.a11y",
                                 defaultValue: "Index this volume to view its cross-volume connections.")
                )
            }
        }
        // The graph benefits from extra vertical room — large layouts and the
        // force-directed simulation are easier to read at full height. Letting
        // the user drag between .medium/.large mirrors the presentation used
        // for DocumentView's DocumentSheet.crossReferenceGraph sheet.
        .sheet(isPresented: $showConnectionGraph) {
            NavigationStack {
                VolumeConnectionGraphView(volumeId: volume.volumeId)
                    .navigationTitle(String(localized: "browser.volume.connectionGraph.title",
                                            defaultValue: "Connections"))
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(String(localized: "browser.volume.connectionGraph.done",
                                          defaultValue: "Done")) {
                                showConnectionGraph = false
                            }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Structure Section

    @ViewBuilder
    private var volumeStructureSection: some View {
        let isDownloaded = vm.isDownloaded(volume.volumeId)

        if !isDownloaded {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Label(
                        String(localized: "browser.volume.downloadRequired",
                               defaultValue: "Download Required"),
                        systemImage: "arrow.down.circle"
                    )
                    .font(.headline)
                    Text(String(localized: "browser.volume.downloadRequired.detail",
                                defaultValue: "Download this volume to browse its contents."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
        } else if vm.isLoadingStructure {
            Section {
                HStack {
                    ProgressView()
                    Text(String(localized: "browser.volume.loading",
                                defaultValue: "Loading structure…"))
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
                // minHeight reserves space equal to a typical section list so the
                // view doesn't visually jump when content loads (F-025).
                .frame(minHeight: 120, alignment: .center)
                .padding(.vertical, 4)
            }
        } else if let structure = vm.volumeStructures[volume.volumeId] {
            if structure.isEmpty {
                Section {
                    Text(String(localized: "browser.volume.emptyStructure",
                                defaultValue: "No structural sections found in this volume."))
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            } else {
                // Split into front-matter, body-content, and back-matter groups.
                // The "<front>" and "<back>" wrappers are expanded so their
                // subsections appear directly.
                let frontMatterItems = Self.extractFrontMatter(from: structure.sections)
                let backMatterItems = Self.extractBackMatter(from: structure.sections)
                let contentSections = structure.sections.filter {
                    !$0.isFrontMatterKind && $0.divType != "back"
                }

                if !frontMatterItems.isEmpty {
                    Section(header: Text(String(localized: "browser.volume.frontMatter.header",
                                                defaultValue: "Front Matter"))) {
                        ForEach(frontMatterItems) { section in
                            sectionRow(section: section)
                        }
                    }
                }

                if !contentSections.isEmpty {
                    Section(header: Text(String(localized: "browser.volume.sections.header",
                                                defaultValue: "Contents"))) {
                        ForEach(contentSections) { section in
                            sectionRow(section: section)
                        }
                    }
                }

                if !backMatterItems.isEmpty {
                    Section(header: Text(String(localized: "browser.volume.backMatter.header",
                                                defaultValue: "Back Matter"))) {
                        ForEach(backMatterItems) { section in
                            sectionRow(section: section)
                        }
                    }
                }
            }
        } else if vm.structureError != nil {
            Section {
                Label(
                    String(localized: "browser.volume.structureError",
                           defaultValue: "Failed to load volume structure."),
                    systemImage: "exclamationmark.triangle"
                )
                .foregroundStyle(.secondary)
                .font(.callout)
            }
        }
    }

    @ViewBuilder
    private func sectionRow(section: VolumeSection) -> some View {
        Button {
            vm.navigationPath.append(.compilation(
                volumeId: volume.volumeId, section: section
            ))
            #if DEBUG
            print("[BrowserView] Navigate → compilation \(section.sectionId)")
            #endif
        } label: {
            SectionRowLabel(section: section)
        }
        .buttonStyle(.plain)
    }

    /// Extracts front-matter sections to display directly under the "Front Matter" header.
    ///
    /// If the top-level sections contain a `<front>` wrapper, its subsections are
    /// flattened out (one tap saved). Any other top-level sections typed as front matter
    /// (e.g. `"preface"` placed outside `<front>`) are included as-is. A `<front>`
    /// wrapper that holds documents directly (the 1861-era volumes place the
    /// President's annual message in `<front>`) is kept alongside its subsections so
    /// those documents stay reachable.
    private static func extractFrontMatter(from sections: [VolumeSection]) -> [VolumeSection] {
        var items: [VolumeSection] = []
        for section in sections {
            if section.divType == "front" {
                // Expand: show subsections directly, or the front section itself
                // when it is empty or carries direct documents.
                if section.subsections.isEmpty || !section.documentIds.isEmpty {
                    items.append(section)
                }
                items.append(contentsOf: section.subsections)
            } else if section.isFrontMatterKind {
                items.append(section)
            }
        }
        return items
    }

    /// Extracts back-matter sections (errata, index) by expanding the `<back>` wrapper,
    /// mirroring `extractFrontMatter`.
    private static func extractBackMatter(from sections: [VolumeSection]) -> [VolumeSection] {
        var items: [VolumeSection] = []
        for section in sections where section.divType == "back" {
            if section.subsections.isEmpty || !section.documentIds.isEmpty {
                items.append(section)
            }
            items.append(contentsOf: section.subsections)
        }
        return items
    }
}

// MARK: - VolumeMetadataView

private struct VolumeMetadataView: View {
    let volume: VolumeManifestEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if volume.documentCount > 0 {
                Text("\(volume.documentCount) documents")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let pub = volume.publicationDate {
                Text("Published \(pub)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if !volume.editors.isEmpty {
                Text(volume.editors.joined(separator: ", "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let ge = volume.generalEditor {
                Text(String(localized: "browser.volume.meta.generalEditor", defaultValue: "General Editor:") + " \(ge)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if volume.status == .partiallyPublished {
                Label(
                    String(localized: "browser.volume.partial", defaultValue: "Partially Published"),
                    systemImage: "ellipsis.circle"
                )
                .font(.footnote)
                .foregroundStyle(.orange)
            } else if volume.status == .planned {
                Label(
                    String(localized: "browser.volume.planned.label", defaultValue: "Planned"),
                    systemImage: "clock"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - VolumeTagChipsView

private struct VolumeTagChipsView: View {
    let vm: BrowserViewModel
    let volume: VolumeManifestEntry
    let chips: [VolumeLevelTag]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(chips, id: \.slug) { chip in
                    Button {
                        vm.activateTagFilter(slug: chip.slug, forSubseries: volume.subseries)
                    } label: {
                        Text(chip.displayName)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.accentColor.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        String(localized: "browser.volume.filterChip.a11y",
                               defaultValue: "Filter by \(chip.displayName)")
                    )
                    .help(String(
                        localized: "browser.volume.filterChip.help",
                        defaultValue: "Show other volumes in this subseries with this tag"
                    ))
                }
            }
            .padding(.vertical, 2)
        }
    }
}

// MARK: - SectionRowLabel

struct SectionRowLabel: View {
    let section: VolumeSection

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(section.title)
                .font(.body)
                .lineLimit(2)
            HStack(spacing: 10) {
                Text(sectionTypeLabel)
                    .foregroundStyle(.secondary)
                let docCount = section.allDocumentIds.count
                if docCount > 0 {
                    Text("\(docCount) docs")
                        .foregroundStyle(.secondary)
                }
                if !section.subsections.isEmpty {
                    Text("\(section.subsections.count) sections")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
        }
        .padding(.vertical, 3)
    }

    private var sectionTypeLabel: String {
        switch section.divType {
        case "compilation":
            return String(localized: "browser.section.type.compilation", defaultValue: "Compilation")
        case "chapter":
            return String(localized: "browser.section.type.chapter", defaultValue: "Chapter")
        case "subchapter":
            return String(localized: "browser.section.type.subchapter", defaultValue: "Subchapter")
        case "appendix":
            return String(localized: "browser.section.type.appendix", defaultValue: "Appendix")
        case "preface":
            return String(localized: "browser.section.type.preface", defaultValue: "Preface")
        case "intro", "introduction":
            return String(localized: "browser.section.type.introduction", defaultValue: "Introduction")
        case "front":
            return String(localized: "browser.section.type.front", defaultValue: "Front Matter")
        case "back":
            return String(localized: "browser.section.type.back", defaultValue: "Back Matter")
        case "errata":
            return String(localized: "browser.section.type.errata", defaultValue: "Errata")
        case "index":
            return String(localized: "browser.section.type.index", defaultValue: "Index")
        case "prefatoryNote":
            return String(localized: "browser.section.type.prefatoryNote", defaultValue: "Prefatory Note")
        case "sources":
            return String(localized: "browser.section.type.sources", defaultValue: "Sources")
        case "persons":
            return String(localized: "browser.section.type.persons", defaultValue: "Persons")
        case "terms":
            return String(localized: "browser.section.type.terms", defaultValue: "Terms & Abbreviations")
        case "table-of-contents":
            return String(localized: "browser.section.type.toc", defaultValue: "Table of Contents")
        case "press-release":
            return String(localized: "browser.section.type.pressRelease", defaultValue: "Press Release")
        case "volume-summary":
            return String(localized: "browser.section.type.volumeSummary", defaultValue: "Volume Summary")
        case "about-frus-series":
            return String(localized: "browser.section.type.aboutSeries", defaultValue: "About the Series")
        case "historical-document":
            return String(localized: "browser.section.type.historicalDocument", defaultValue: "Document")
        case "section":
            return String(localized: "browser.section.type.section", defaultValue: "Section")
        default:
            return section.divType
        }
    }
}
