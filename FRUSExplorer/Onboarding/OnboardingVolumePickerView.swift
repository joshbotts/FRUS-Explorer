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

/// Second step of onboarding: volume picker.
///
/// Supports two browse modes:
///   - **Sort by subseries** (default): grouped chronologically
///   - **Browse by tag**: searchable taxonomy picker with AND multi-select
///
/// Volume rows show title, subseries, date range, document count, and up to 5 tag chips.
/// Tapping a chip activates it as a tag filter. "Newly available" volumes appear at the
/// top with a badge. Multi-select drives the storage estimate in the footer.
///
/// Version history:
///   1.0 — Session 10: initial implementation
@MainActor
struct OnboardingVolumePickerView: View {

    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "onboarding.picker.title",
                            defaultValue: "Choose Volumes"))
                    .font(.title.bold())
                Text(String(localized: "onboarding.picker.subtitle",
                            defaultValue: "Select which volumes to download. You can add more later."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()

            Divider()

            // Mode picker + Select All
            HStack {
                Picker(String(localized: "onboarding.picker.mode.label", defaultValue: "Browse by"),
                       selection: $viewModel.sortMode) {
                    Text(String(localized: "onboarding.picker.mode.subseries",
                                defaultValue: "Subseries"))
                        .tag(OnboardingViewModel.SortMode.bySubseries)
                    Text(String(localized: "onboarding.picker.mode.tag",
                                defaultValue: "Tag"))
                        .tag(OnboardingViewModel.SortMode.byTag)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)

                Spacer()

                selectAllToggle
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Tag search (only shown in byTag mode)
            if viewModel.sortMode == .byTag {
                tagSearchBar
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            Divider()

            // Volume list
            List {
                // Newly available section
                if !viewModel.newlyAvailableVolumes.isEmpty {
                    Section {
                        ForEach(viewModel.newlyAvailableVolumes) { volume in
                            NewlyAvailableVolumeRow(
                                volume: volume,
                                isSelected: viewModel.selectedVolumeIds.contains(volume.filename)
                            ) {
                                toggleSelection(id: volume.filename)
                            }
                        }
                    } header: {
                        Text(String(localized: "onboarding.picker.newlyAvailable",
                                    defaultValue: "Newly Available"))
                            .font(.headline)
                    }
                }

                if viewModel.sortMode == .byTag {
                    tagFilteredVolumeList
                } else {
                    subseriesVolumeList
                }
            }
            .listStyle(.plain)

            Divider()

            // Footer
            footer
        }
    }

    // MARK: - Subviews

    private var selectAllToggle: some View {
        let allIds = Set(viewModel.displayVolumes.map(\.volumeId)
            + viewModel.newlyAvailableVolumes.map(\.filename))
        let allSelected = !allIds.isEmpty && allIds.isSubset(of: viewModel.selectedVolumeIds)
        return Button {
            if allSelected {
                viewModel.selectedVolumeIds.subtract(allIds)
            } else {
                viewModel.selectedVolumeIds.formUnion(allIds)
            }
        } label: {
            Text(allSelected
                 ? String(localized: "onboarding.picker.deselectAll", defaultValue: "Deselect All")
                 : String(localized: "onboarding.picker.selectAll", defaultValue: "Select All"))
        }
        .buttonStyle(.bordered)
    }

    private var tagSearchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(
                String(localized: "onboarding.picker.tagSearch.placeholder",
                       defaultValue: "Search tags"),
                text: $viewModel.tagSearchText
            )
            .textFieldStyle(.plain)

            if !viewModel.tagSearchText.isEmpty {
                Button {
                    viewModel.tagSearchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var subseriesVolumeList: some View {
        ForEach(viewModel.volumesBySubseries, id: \.subseries) { group in
            Section {
                ForEach(group.volumes) { volume in
                    VolumeRow(
                        volume: volume,
                        isSelected: viewModel.selectedVolumeIds.contains(volume.volumeId),
                        onToggle: { toggleSelection(id: volume.volumeId) },
                        onTagTap: { slug in viewModel.activateTagFilter(slug: slug) }
                    )
                }
            } header: {
                Text(group.subseries)
                    .font(.headline)
            }
        }
    }

    @ViewBuilder
    private var tagFilteredVolumeList: some View {
        // Tag picker section
        Section {
            tagPickerContent
        } header: {
            Text(String(localized: "onboarding.picker.tags.header", defaultValue: "Filter by Tag"))
                .font(.headline)
        }

        // Results section
        if !viewModel.selectedTagSlugs.isEmpty {
            Section {
                ForEach(viewModel.displayVolumes) { volume in
                    VolumeRow(
                        volume: volume,
                        isSelected: viewModel.selectedVolumeIds.contains(volume.volumeId),
                        onToggle: { toggleSelection(id: volume.volumeId) },
                        onTagTap: { slug in viewModel.activateTagFilter(slug: slug) }
                    )
                }
            } header: {
                Text(String(localized: "onboarding.picker.results.header",
                            defaultValue: "Matching Volumes (\(viewModel.displayVolumes.count))"))
            }
        }
    }

    @ViewBuilder
    private var tagPickerContent: some View {
        let categories = groupedFilteredTags()
        ForEach(categories, id: \.category) { group in
            DisclosureGroup(group.category.capitalized) {
                ForEach(group.tags, id: \.slug) { tag in
                    HStack {
                        Text(tag.displayName)
                        Spacer()
                        if viewModel.selectedTagSlugs.contains(tag.slug) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if viewModel.selectedTagSlugs.contains(tag.slug) {
                            viewModel.selectedTagSlugs.remove(tag.slug)
                        } else {
                            viewModel.selectedTagSlugs.insert(tag.slug)
                        }
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "onboarding.picker.footer.selected",
                            defaultValue: "\(viewModel.selectedVolumeIds.count) volumes selected"))
                    .font(.subheadline.bold())
                Text(String(localized: "onboarding.picker.footer.size",
                            defaultValue: "Estimated download: \(formattedBytes(viewModel.selectedBytes))"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                viewModel.step = .downloadConfirm
                #if DEBUG
                print("[Onboarding] Step: volumePicker → downloadConfirm")
                #endif
            } label: {
                Text(String(localized: "onboarding.picker.next", defaultValue: "Next"))
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canProceedFromVolumePicker)
        }
        .padding()
    }

    // MARK: - Helpers

    private func toggleSelection(id: String) {
        if viewModel.selectedVolumeIds.contains(id) {
            viewModel.selectedVolumeIds.remove(id)
        } else {
            viewModel.selectedVolumeIds.insert(id)
        }
    }

    private func formattedBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private struct TagGroup {
        let category: String
        let tags: [TagTaxonomyEntry]
    }

    private func groupedFilteredTags() -> [TagGroup] {
        let search = viewModel.tagSearchText.lowercased()
        let filtered = viewModel.tagStore.allEntries.filter { entry in
            search.isEmpty || entry.displayName.lowercased().contains(search)
                || entry.slug.lowercased().contains(search)
        }
        var byCategory: [String: [TagTaxonomyEntry]] = [:]
        for entry in filtered {
            byCategory[entry.category, default: []].append(entry)
        }
        return byCategory
            .map { TagGroup(category: $0.key, tags: $0.value.sorted { $0.displayName < $1.displayName }) }
            .sorted { $0.category < $1.category }
    }
}

// MARK: - Volume Row

@MainActor
private struct VolumeRow: View {

    let volume: VolumeManifestEntry
    let isSelected: Bool
    let onToggle: () -> Void
    let onTagTap: (String) -> Void

    private static let maxTagChips = 5

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Selection indicator
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .font(.title3)
                .onTapGesture { onToggle() }

            VStack(alignment: .leading, spacing: 4) {
                Text(volume.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Text(volume.subseries)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let earliest = volume.dateRange.earliest {
                        Text(dateRangeText(earliest: earliest, latest: volume.dateRange.latest))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if volume.documentCount > 0 {
                        Text(String(localized: "onboarding.picker.row.docs",
                                    defaultValue: "\(volume.documentCount) docs"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Tag chips (max 5, with overflow count)
                if !volume.tags.isEmpty {
                    tagChips
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var tagChips: some View {
        let displayed = Array(volume.tags.prefix(VolumeRow.maxTagChips))
        let overflow = volume.tags.count - displayed.count
        FlowLayout(spacing: 4) {
            ForEach(displayed, id: \.self) { slug in
                TagChip(slug: slug) { onTagTap(slug) }
            }
            if overflow > 0 {
                Text(String(localized: "onboarding.picker.chip.overflow",
                            defaultValue: "+\(overflow) more"))
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15), in: Capsule())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func dateRangeText(earliest: String, latest: String?) -> String {
        if let latest, latest != earliest {
            return "\(earliest)–\(latest)"
        }
        return earliest
    }
}

// MARK: - Newly Available Volume Row

@MainActor
private struct NewlyAvailableVolumeRow: View {

    let volume: NewlyAvailableVolume
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(volume.filename)
                        .font(.headline)
                    Text(String(localized: "onboarding.picker.newBadge",
                                defaultValue: "NEW"))
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue, in: Capsule())
                        .foregroundStyle(.white)
                }
                if let subseries = volume.subseries {
                    Text(subseries)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
        .padding(.vertical, 4)
    }
}

// MARK: - Tag Chip

@MainActor
private struct TagChip: View {

    let slug: String
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            Text(slug)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.15), in: Capsule())
                .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout

/// A simple flow layout that wraps children onto new lines.
private struct FlowLayout: Layout {

    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                totalHeight += lineHeight + spacing
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        totalHeight += lineHeight
        return CGSize(width: maxWidth, height: max(0, totalHeight))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            view.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            _ = maxWidth // suppress unused warning
        }
    }
}
