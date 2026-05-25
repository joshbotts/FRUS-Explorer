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
///   1.3 — Session 56: "Index Now" demoted to `.bordered` (HIG: only one `.borderedProminent`
///          per view; "Read [Title]" is the true primary action)
///   1.4 — Session 68: rich indexing progress section (`indexingProgressSection`) using
///          `vm.indexingProgress`; `.onChange(of: vm.isIndexing)` auto-loads document
///          list when indexing finishes — no navigate-away required;
///          `DocumentRowLabel` drops the redundant leading document-number chip because
///          the number is already part of the `header` text
struct CompilationView: View {

    let vm: BrowserViewModel
    let volumeId: String
    let section: VolumeSection

    @Environment(AppState.self) private var appState

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
        // When a user-triggered indexing operation finishes successfully, load the
        // document list immediately. This replaces the previous behaviour where the
        // user had to navigate away and back to see documents after indexing.
        .onChange(of: vm.isIndexing) { wasIndexing, isIndexing in
            if wasIndexing && !isIndexing && vm.indexingError == nil {
                Task { await vm.loadDocuments(for: section, volumeId: volumeId) }
            }
        }
        // Handle external (Settings-triggered) bulk indexing: when the pipeline
        // finishes and progress drops to nil, re-check whether our volume is now
        // indexed. This prevents the "Index Required" banner from persisting after
        // a batch indexing run completes outside the browser flow.
        .onChange(of: appState.currentIndexingProgress) { _, progress in
            guard progress == nil else { return }
            guard !vm.isIndexing else { return }
            if vm.isIndexed(volumeId) {
                Task { await vm.loadDocuments(for: section, volumeId: volumeId) }
            }
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
        } else if vm.isIndexing {
            // Indexing in progress — show live progress (takes priority over index check).
            indexingProgressSection
        } else if !vm.isIndexed(volumeId) {
            // Not indexed and not currently indexing — show prompt.
            indexRequiredSection
        } else if vm.isLoadingDocuments || vm.compilationDocuments[cacheKey] == nil {
            // Indexed but documents not yet in cache — covers both normal first-load and
            // the brief window immediately after indexing completes before loadDocuments runs.
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
        } else {
            documentRows(docs: vm.compilationDocuments[cacheKey] ?? [])
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
                // .bordered (not .borderedProminent) — HIG requires only one primary-
                // action button per view. "Read [Title]" is the true primary action;
                // "Index Now" is a prerequisite maintenance action.
                .buttonStyle(.bordered)
                if let err = vm.indexingError {
                    Text(err.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: - Indexing Progress Section

    /// Shown while `vm.isIndexing` is true. Displays a labelled progress bar fed
    /// by `vm.indexingProgress` (per-document updates from `IndexingPipeline.progressStream`).
    /// Falls back to an indeterminate spinner before the first update arrives.
    @ViewBuilder
    private var indexingProgressSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Label(
                    String(localized: "browser.compilation.indexing.title",
                           defaultValue: "Indexing Volume"),
                    systemImage: "arrow.triangle.2.circlepath"
                )
                .font(.headline)

                if let prog = vm.indexingProgress, prog.totalDocuments > 0 {
                    // Determinate progress once pipeline starts emitting updates
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(
                            value: Double(prog.completedDocuments),
                            total: Double(prog.totalDocuments)
                        )

                        HStack {
                            Text(indexingStageLabel(prog.stage))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(
                                format: String(localized: "browser.compilation.indexing.progress",
                                               defaultValue: "%@ / %@ documents"),
                                formattedCount(prog.completedDocuments),
                                formattedCount(prog.totalDocuments)
                            ))
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                        }

                        if prog.docsPerSecond > 0 {
                            Text(String(
                                format: String(localized: "browser.compilation.indexing.throughput",
                                               defaultValue: "%@ docs/s"),
                                formattedCount(Int(prog.docsPerSecond))
                            ))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        }
                    }
                } else {
                    // Indeterminate spinner before first update arrives
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(String(localized: "browser.compilation.indexing.preparing",
                                    defaultValue: "Preparing…"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: - Indexing Helpers

    private func indexingStageLabel(_ stage: IndexingStage) -> String {
        switch stage {
        case .reading:
            return String(localized: "browser.compilation.indexing.stage.reading",
                          defaultValue: "Reading…")
        case .storingBatch(let current, let total):
            return String(localized: "browser.compilation.indexing.stage.storingBatch",
                          defaultValue: "Storing batch \(current) of \(total)…")
        case .complete:
            return String(localized: "browser.compilation.indexing.stage.complete",
                          defaultValue: "Complete")
        }
    }

    private func formattedCount(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}


// MARK: - DocumentRowLabel

/// A single row in the document browser list.
///
/// The leading document-number chip was removed in Session 68 because
/// `DocumentBrowserEntry.documentNumber` is extracted from the leading integer in
/// the `<head>` text, which is also what `header` contains in full. Showing both
/// produced repeated numbers (e.g. "1  1. Memorandum…"). The header is the
/// canonical display text; the `documentNumber` field is retained on the model for
/// search and sort purposes only.
struct DocumentRowLabel: View {
    let doc: DocumentBrowserEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(doc.header)
                .font(.body)
                .italic(doc.isEditorialNote)
                .lineLimit(2)
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
