// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - CompilationView

/// Browser level showing the document list for a single compilation or chapter.
///
/// Documents are loaded lazily via `BrowserViewModel.loadDocuments(for:volumeId:)` on
/// appear. If the volume has not been indexed, an "Index Required" prompt is shown with
/// an "Index Now" action that triggers `BrowserViewModel.indexVolume(_:)`.
///
/// Version history:
///   1.0 — Session 11: initial implementation
struct CompilationView: View {

    let vm: BrowserViewModel
    let volumeId: String
    let section: VolumeSection

    private var cacheKey: String {
        vm.compilationKey(volumeId: volumeId, sectionId: section.sectionId)
    }

    private var volume: VolumeManifestEntry? {
        vm.allSubseriesGroups
            .flatMap(\.volumes)
            .first { $0.volumeId == volumeId }
    }

    var body: some View {
        List {
            // Subsection navigation if this section has subsections
            if !section.subsections.isEmpty {
                subsectionsList
            }

            // Document list
            documentListSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(section.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .task {
            guard volume != nil else { return }
            if !vm.isIndexed(volumeId) { return }
            await vm.loadDocuments(for: section, volumeId: volumeId)
        }
    }

    // MARK: - Subsections

    @ViewBuilder
    private var subsectionsList: some View {
        Section(header: Text(String(localized: "browser.compilation.subsections.header",
                                    defaultValue: "Sections"))) {
            ForEach(section.subsections) { sub in
                Button {
                    vm.navigationPath.append(.compilation(volumeId: volumeId, section: sub))
                    #if DEBUG
                    print("[BrowserView] Navigate → subsection \(sub.sectionId)")
                    #endif
                } label: {
                    SectionRowLabel(section: sub)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Document List

    @ViewBuilder
    private var documentListSection: some View {
        if !vm.isIndexed(volumeId) {
            indexRequiredSection
        } else if vm.isLoadingDocuments {
            Section {
                HStack {
                    ProgressView()
                    Text(String(localized: "browser.compilation.loading",
                                defaultValue: "Loading documents…"))
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
                .padding(.vertical, 4)
            }
        } else if let docs = vm.compilationDocuments[cacheKey] {
            documentRows(docs: docs)
        }
    }

    @ViewBuilder
    private func documentRows(docs: [DocumentBrowserEntry]) -> some View {
        if docs.isEmpty {
            Section {
                Text(String(localized: "browser.compilation.noDocs",
                            defaultValue: "No documents in this section."))
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        } else {
            Section(header: Text(docsHeader(count: docs.count))) {
                ForEach(docs) { doc in
                    DocumentRowLabel(doc: doc)
                }
            }
        }
    }

    private func docsHeader(count: Int) -> String {
        let base = String(localized: "browser.compilation.docs.header",
                          defaultValue: "Documents")
        return "\(base) (\(count))"
    }

    // MARK: - Index Required Placeholder

    @ViewBuilder
    private var indexRequiredSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Label(
                    String(localized: "browser.compilation.indexRequired",
                           defaultValue: "Index Required"),
                    systemImage: "magnifyingglass.circle"
                )
                .font(.headline)
                Text(String(localized: "browser.compilation.indexRequired.detail",
                            defaultValue: "This volume must be indexed before its documents can be browsed."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if vm.isIndexing {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(String(localized: "browser.compilation.indexing",
                                    defaultValue: "Indexing…"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button {
                        guard let vol = volume else { return }
                        Task { await vm.indexVolume(vol) }
                    } label: {
                        Label(
                            String(localized: "browser.compilation.indexNow",
                                   defaultValue: "Index Now"),
                            systemImage: "arrow.triangle.2.circlepath"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    if let err = vm.indexingError {
                        Text(err.localizedDescription)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }
}

// MARK: - DocumentRowLabel

struct DocumentRowLabel: View {
    let doc: DocumentBrowserEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let num = doc.documentNumber {
                    Text(num)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 28, alignment: .trailing)
                }
                Text(doc.header)
                    .font(.body)
                    .lineLimit(2)
            }
            if let dateline = doc.dateline {
                Text(dateline)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let source = doc.sourceNote {
                Text(source)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 3)
    }
}
