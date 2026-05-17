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
/// Version history:
///   1.0 — Session 11: initial implementation
struct VolumeView: View {

    let vm: BrowserViewModel
    let volume: VolumeManifestEntry

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
                Section(header: Text(String(localized: "browser.volume.sections.header",
                                            defaultValue: "Contents"))) {
                    ForEach(structure.sections) { section in
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
        default:
            return section.divType
        }
    }
}
