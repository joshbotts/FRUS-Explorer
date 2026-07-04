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
/// `"introduction"`, `"errata"`, `"prefatoryNote"`, or `"terms"` and that contain bare
/// prose (no nested `<div type="document">` children) are handled specially: instead of
/// showing "No documents in this section", `CompilationView` shows a "Read [Title]" button.
/// Tapping it creates a synthetic `DocumentBrowserEntry` (using the section's
/// `sectionId` as the `documentId`) and navigates to `DocumentView`.
/// `FRUSDocumentParser.parseDocument(documentId:)` matches the structural div by
/// `xml:id` (Session 34 fallback) and renders its prose content.
///
/// ## Persons Section
/// A section with `divType == "persons"` is routed to `FrontMatterPersonsView`, which
/// loads the indexed persons list for the volume from `PersonMentionStore`.
///
/// ## Sources Section
/// A section with `divType == "sources"` is routed to `VolumeSourcesView`, which
/// loads the structured archival sources from `IndexingPipeline.volumeSources(forVolumeId:)`.
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
///   1.5 — Session 2026-06-08: `"prefatoryNote"` and `"terms"` added to `canReadSectionDirectly`;
///          `"persons"` → `FrontMatterPersonsView`; `"sources"` → `VolumeSourcesView`
///   1.6 — Session 2026-06-10: routing predicates replaced with the shared
///          `VolumeSection` kind helpers (`canReadDirectly`, `isPersonsList`,
///          `isSourcesList`), which understand the real corpus encoding
///   1.7 — Session 2026-07-03: complete long titles — the full section title heads the
///          list (nav-bar title switched to inline; it truncates long chapter titles),
///          and `DocumentRowLabel` wraps document headers instead of clipping at two lines
struct CompilationView: View {

    let vm: BrowserViewModel
    let volumeId: String
    let section: VolumeSection

    @Environment(AppState.self) private var appState

    /// When set, presents the Archival Neighbors sheet for a document row.
    @State private var archivalNeighborsTarget: ArchivalNeighborsDocKey? = nil
    /// Hoisted presentation targets for the section-emitting front-matter subviews
    /// (`VolumeSourcesView` / `FrontMatterPersonsView`) — see the List-level sheets in
    /// `body` for why these cannot live inside those views.
    @State private var sourceNeighborsTarget: VolumeSourceNeighborsTarget? = nil
    @State private var crossVolumeTarget: CrossVolumeTarget? = nil
    @State private var selectedPerson: PersonIndexEntry? = nil

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
            // Full section title, wrapping to as many lines as it needs. The navigation
            // bar title truncates long chapter/compilation titles (older volumes carry
            // appended clauses), so the complete value must be readable in content.
            Section {
                Text(section.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }

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
        // Inline (not large) title: the full title now heads the content list, so the
        // large title would only restate a truncated copy of it.
        .navigationBarTitleDisplayMode(.inline)
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
        .sheet(item: $archivalNeighborsTarget) { key in
            ArchivalNeighborsSheet(appState: appState, docKey: key)
                .environment(appState)
        }
        // Presentation for the section-emitting front-matter subviews (sources/persons),
        // anchored HERE on the List — exactly once. Attaching these inside those views
        // (on their Group/Section content) creates one presenter per row and the
        // presenters ping-pong present/dismiss after close (the reported Archival
        // Neighbors open/close loop). Same pattern as `archivalNeighborsTarget` above,
        // which never exhibited the loop.
        .sheet(item: $sourceNeighborsTarget) { target in
            ArchivalNeighborsSheet(appState: appState) {
                guard let pipeline = appState.indexingPipeline else { return ([], 0, nil) }
                return (try? await pipeline.archivalNeighbors(
                    forLotFile:   target.lotFile,
                    recordGroup:  target.recordGroup,
                    series:       target.series,
                    repository:   target.repository,
                    decimalClass: target.decimalClass
                )) ?? ([], 0, nil)
            }
            .environment(appState)
        }
        .sheet(item: $crossVolumeTarget) { target in
            VolumeSourcesCrossVolumeSheet(collectionTitle: target.title, volumeIds: target.volumeIds)
                .environment(appState)
        }
        .sheet(item: $selectedPerson) { entry in
            PersonIndexDetailSheet(indexEntry: entry)
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
        if section.canReadDirectly {
            // Prose-only front matter section — bypass indexing and open directly.
            readSectionDirectlySection
        } else if section.isPersonsList {
            // Persons list — rendered by FrontMatterPersonsView without requiring indexing.
            FrontMatterPersonsView(volumeId: volumeId, selectedPerson: $selectedPerson)
        } else if section.isSourcesList {
            // Archival sources list — rendered by VolumeSourcesView from the indexed table.
            VolumeSourcesView(volumeId: volumeId,
                              sourceNeighborsTarget: $sourceNeighborsTarget,
                              crossVolumeTarget: $crossVolumeTarget)
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
                    .contextMenu {
                        Button {
                            archivalNeighborsTarget = ArchivalNeighborsDocKey(
                                volumeId:     doc.volumeId,
                                documentId:   doc.documentId,
                                documentYear: nil
                            )
                        } label: {
                            Label(String(localized: "browser.compilation.archivalNeighbors",
                                         defaultValue: "Archival Neighbors…"),
                                  systemImage: "archivebox")
                        }
                    }
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
        case .optimizing:
            return String(localized: "browser.compilation.indexing.stage.optimizing",
                          defaultValue: "Finalizing index…")
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
///
/// The label expands to the full row width and declares a rectangular content shape so
/// the entire row is tappable inside its `.buttonStyle(.plain)` Button — plain buttons
/// otherwise hit-test only their opaque text (Session 2026-07-03 tap-target fix).
struct DocumentRowLabel: View {
    let doc: DocumentBrowserEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(doc.header)
                .font(.body)
                .italic(doc.isEditorialNote)
                .fixedSize(horizontal: false, vertical: true)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
