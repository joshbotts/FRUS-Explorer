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
/// ## Front Matter Support
/// Structural sections whose `divType` is one of `"preface"`, `"intro"`,
/// `"introduction"`, or `"errata"` and that contain bare prose (no nested
/// `<div type="document">` children) are handled specially: instead of showing
/// "No documents in this section", `CompilationView` shows a "Read [Title]" button.
/// Tapping it creates a synthetic `DocumentBrowserEntry` (using the section's
/// `sectionId` as the `documentId`) and navigates to `DocumentView`.
/// `FRUSDocumentParser.parseDocument(documentId:)` matches the structural div by
/// `xml:id` (Session 34 fallback) and renders its prose content.
///
/// Version history:
///   1.0 — Session 11: initial implementation
///   1.1 — Session 34: front matter direct-read support for prose-only structural sections
///   1.2 — Session 38: `DocumentRowLabel` shows italic header and editorial note badge
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
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
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

    // MARK: - Front Matter Direct Read

    /// `true` when this section contains prose directly (no document sub-divs) and
    /// belongs to a type that should be readable without FTS indexing.
    ///
    /// Covers `<div type="preface">`, `<div type="introduction">`, `<div type="intro">`,
    /// and `<div type="errata">` that are leaf sections (no subsections, no document IDs).
    ///
    /// Sections with auto-generated `sectionId` values (e.g. `"preface-3"`, produced when
    /// the TEI element has no `xml:id` attribute) are excluded because
    /// `FRUSDocumentParser.parseDocument(documentId:)` cannot locate them by ID.
    private var canReadSectionDirectly: Bool {
        let proseTypes: Set<String> = ["preface", "intro", "introduction", "errata"]
        guard proseTypes.contains(section.divType),
              section.allDocumentIds.isEmpty,
              section.subsections.isEmpty
        else { return false }
        // Guard against auto-generated sectionIds like "preface-3" — these have no
        // xml:id in the TEI source and parseDocument would return nil.
        let autoPrefix = "\(section.divType)-"
        if section.sectionId.hasPrefix(autoPrefix) {
            let suffix = section.sectionId.dropFirst(autoPrefix.count)
            if !suffix.isEmpty, suffix.allSatisfy(\.isNumber) { return false }
        }
        return !section.sectionId.isEmpty
    }

    @ViewBuilder
    private var readSectionDirectlySection: some View {
        Section {
            Button {
                let entry = DocumentBrowserEntry(
                    documentId: section.sectionId,
                    volumeId: volumeId,
                    documentNumber: nil,
                    header: section.title,
                    dateline: nil,
                    sourceNote: nil
                )
                vm.navigationPath.append(.document(entry))
                #if DEBUG
                print("[BrowserView] Navigate → front matter section \(section.sectionId)")
                #endif
            } label: {
                Label(
                    String(
                        format: String(localized: "browser.compilation.readSection",
                                       defaultValue: "Read %@"),
                        section.title
                    ),
                    systemImage: "doc.text"
                )
            }
            .buttonStyle(.borderedProminent)
        } footer: {
            Text(String(localized: "browser.compilation.readSection.footer",
                        defaultValue: "This section contains prose content rather than individual numbered documents."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Document List

    @ViewBuilder
    private var documentListSection: some View {
        if canReadSectionDirectly {
            // Prose-only front matter section — bypass indexing and open directly.
            readSectionDirectlySection
        } else if !vm.isIndexed(volumeId) {
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
                    Button {
                        vm.navigationPath.append(.document(doc))
                        #if DEBUG
                        print("[BrowserView] Navigate → document \(doc.documentId)")
                        #endif
                    } label: {
                        DocumentRowLabel(doc: doc)
                    }
                    .buttonStyle(.plain)
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
                    .italic(doc.isEditorialNote)
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
            if doc.isEditorialNote {
                Label(
                    String(localized: "browser.editorialnote.badge", defaultValue: "Editorial Note"),
                    systemImage: "text.badge.checkmark"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}
