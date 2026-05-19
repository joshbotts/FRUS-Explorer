// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

#if os(macOS)

import SwiftUI
import SwiftData

// MARK: - ResearchStripView

/// Persistent research action toolbar displayed between the titlebar and the document body.
///
/// Contains: Add to collection · Add note · Tag · Cite (popover) · collapse chevron.
/// Collapses to a "+" re-expand button when `isCollapsed` is true.
///
/// Version history:
///   1.0 — New UI scaffolding
struct ResearchStripView: View {

    let entry: DocumentBrowserEntry?
    @Binding var isCollapsed: Bool
    @Binding var showCitationPopover: Bool

    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    @State private var showAddToCollection: Bool = false
    @State private var showAddNote: Bool = false
    @State private var showTagPicker: Bool = false

    private var isDisabled: Bool { entry == nil }

    var body: some View {
        HStack(spacing: 6) {
            if isCollapsed {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { isCollapsed = false }
                } label: {
                    Image(systemName: "plus.circle").font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .padding(.leading, 16)
                .padding(.vertical, 5)
                Spacer()
            } else {
                Text("Research")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .kerning(0.8)
                    .padding(.leading, 16)

                ResearchStripButton(
                    title: "Add to collection",
                    systemImage: "folder.badge.plus",
                    isDisabled: isDisabled
                ) { showAddToCollection = true }

                ResearchStripButton(
                    title: "Add note",
                    systemImage: "note.text.badge.plus",
                    isDisabled: isDisabled
                ) { showAddNote = true }

                ResearchStripButton(
                    title: "Tag",
                    systemImage: "tag",
                    isDisabled: isDisabled
                ) { showTagPicker = true }

                ResearchStripButton(
                    title: "Graph",
                    systemImage: "point.3.connected.trianglepath.dotted",
                    isDisabled: isDisabled
                ) {
                    if let entry {
                        appState.currentGraphEntry = entry
                        openWindow(id: "frus.crossReferenceGraph")
                    }
                }

                // Cite — opens citation popover
                Button {
                    showCitationPopover = true
                } label: {
                    Label("Cite", systemImage: "quote.closing")
                        .font(.system(size: 11))
                        .foregroundStyle(isDisabled ? Color.secondary : Color.accentColor)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(isDisabled ? Color.clear : Color.accentColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(
                            isDisabled ? Color.clear : Color.accentColor.opacity(0.3),
                            lineWidth: 0.5
                        )
                )
                .disabled(isDisabled)
                .popover(isPresented: $showCitationPopover, arrowEdge: .bottom) {
                    if let entry { CitationPopoverView(entry: entry) }
                }

                Spacer()

                // Collapse chevron
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { isCollapsed = true }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 14)
            }
        }
        .frame(height: 32)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
        .sheet(isPresented: $showAddToCollection) {
            // CollectionEditorView(collection: nil) creates a new collection.
            CollectionEditorView(collection: nil)
        }
        .sheet(isPresented: $showAddNote) {
            if let entry {
                ResearchNoteEditorView(
                    documentId: entry.documentId,
                    volumeId: entry.volumeId,
                    activeProjectId: appState.activeProjectId
                )
            }
        }
        .sheet(isPresented: $showTagPicker) {
            if let entry { MacTagPickerSheet(entry: entry) }
        }
    }
}

// MARK: - ResearchStripButton

private struct ResearchStripButton: View {
    let title: String
    let systemImage: String
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 11))
                .foregroundStyle(isDisabled ? .tertiary : .primary)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.secondary.opacity(isDisabled ? 0 : 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(Color.secondary.opacity(isDisabled ? 0 : 0.2), lineWidth: 0.5)
        )
        .disabled(isDisabled)
    }
}

// MARK: - SummaryBlockView

/// Inline AI summary block rendered within the document body.
///
/// Shows the most recent summary with prompt label and history cycling controls.
/// Collapses to a "Summarize" prompt when no summary exists.
/// Hidden entirely when `SummarizationService` is unavailable.
///
/// Version history:
///   1.0 — New UI scaffolding
struct SummaryBlockView: View {
    @Bindable var vm: DocumentViewModel
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var showPromptPicker: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Header row
            HStack(alignment: .center) {
                Label("AI summary", systemImage: "sparkles")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .kerning(0.7)

                if vm.activeSummary != nil {
                    Text("· custom prompt")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Button("Change prompt") { showPromptPicker = true }
                        .font(.system(size: 10))
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .popover(isPresented: $showPromptPicker) {
                            SummaryPromptPickerView(vm: vm)
                        }

                    if vm.summaries.count > 1 {
                        Text("·").foregroundStyle(.tertiary).font(.system(size: 10))
                        HStack(spacing: 2) {
                            Button {
                                if vm.activeSummaryIndex < vm.summaries.count - 1 {
                                    vm.activeSummaryIndex += 1
                                }
                            } label: {
                                Image(systemName: "chevron.left").font(.system(size: 10))
                            }
                            .buttonStyle(.plain)
                            .disabled(vm.activeSummaryIndex >= vm.summaries.count - 1)

                            Text("\(vm.activeSummaryIndex + 1)/\(vm.summaries.count)")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)

                            Button {
                                if vm.activeSummaryIndex > 0 { vm.activeSummaryIndex -= 1 }
                            } label: {
                                Image(systemName: "chevron.right").font(.system(size: 10))
                            }
                            .buttonStyle(.plain)
                            .disabled(vm.activeSummaryIndex <= 0)
                        }
                    }

                    Button("Regenerate") { Task { await regenerateSummary() } }
                        .font(.system(size: 10))
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .disabled(vm.isSummarizing)
                }
            }

            // Body
            if vm.isSummarizing {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Summarizing…").font(.system(size: 13)).foregroundStyle(.secondary)
                }
            } else if let summary = vm.activeSummary {
                Text(summary.responseText)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
            } else {
                Button("Summarize this document") { Task { await regenerateSummary() } }
                    .font(.system(size: 13))
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(Color.green.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.green.opacity(0.15), lineWidth: 0.5)
        )
    }

    private func regenerateSummary() async {
        guard let service = appState.summarizationService else { return }
        let provider = AppleIntelligenceProvider.shared
        // Default prompt nil — picked in prompt picker popover.
        // If no prompt is selected, SummarizationService uses the standard prompt.
        if let prompts = try? modelContext.fetch(
            FetchDescriptor<SummarizationPrompt>(sortBy: [SortDescriptor(\.createdAt)])
        ), let prompt = prompts.first {
            await vm.generateSummary(
                prompt: prompt,
                provider: provider,
                service: service,
                activeProjectId: appState.activeProjectId,
                context: modelContext
            )
        }
    }
}

// MARK: - FootnoteSectionView

/// Renders the footnote block at the bottom of a document.
///
/// Each footnote is rendered with its display label and body content.
/// Cross-reference links within footnotes are tappable.
/// The `activeFootnoteLabel` binding highlights a footnote in response
/// to a superscript tap in the document body.
///
/// Version history:
///   1.0 — New UI scaffolding
struct FootnoteSectionView: View {
    let footnotes: [FRUSRenderNode]
    @Binding var activeFootnoteLabel: String?
    let onCrossRefTap: (String, String?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()

            Text("Footnotes")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .kerning(0.7)
                .padding(.bottom, 2)

            ForEach(Array(footnotes.enumerated()), id: \.offset) { _, node in
                if case .footnoteBody(_, _, _, _, let label, let children) = node {
                    // Strip leading/trailing lineBreak and pageBreak nodes that would
                    // otherwise add blank lines at the top and bottom of each footnote.
                    let filteredChildren = children.filter {
                        if case .lineBreak = $0 { return false }
                        if case .pageBreak = $0 { return false }
                        return true
                    }
                    HStack(alignment: .top, spacing: 10) {
                        Text(label)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.accentColor)
                            .frame(minWidth: 18, alignment: .trailing)
                            .padding(.top, 1)

                        FRUSDocumentRenderer(
                            nodes: filteredChildren,
                            onFootnoteTap: { _ in },
                            onPersonTap: { _ in },
                            onGlossTap: { _ in },
                            onCrossRefTap: onCrossRefTap,
                            // Tighter spacing: footnote paragraphs should
                            // not appear double-spaced like body paragraphs.
                            blockSpacing: 2
                        )
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        activeFootnoteLabel == label
                            ? Color.accentColor.opacity(0.06)
                            : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - StatusBarView

/// Persistent status bar at the bottom of the main macOS window.
///
/// Three zones:
/// - Left: indexed volume count (stable, low-noise)
/// - Centre: active background task with progress bar and ETA
/// - Right: CloudKit sync state
///
/// Progress is driven by `AppState.currentIndexingProgress` (now cross-platform)
/// and `AppState.downloadQueue`.
///
/// Version history:
///   1.0 — New UI scaffolding
struct StatusBarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 16) {

            // Left: index count
            HStack(spacing: 5) {
                Circle()
                    .fill(indexedCount > 0 ? Color.green : Color.secondary)
                    .frame(width: 6, height: 6)
                Text("\(indexedCount) volume\(indexedCount == 1 ? "" : "s") indexed")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            // Centre: active task
            if let task = activeTask {
                HStack(spacing: 6) {
                    Image(systemName: task.systemImage)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(task.label)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    if let progress = task.progress {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .frame(width: 60)
                            .tint(.green)
                        if let eta = task.eta {
                            Text(eta)
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            Spacer()

            // Right: sync state
            Label("Synced", systemImage: "checkmark.icloud")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .frame(height: 24)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    // MARK: - Computed

    private var indexedCount: Int {
        guard let dm = appState.downloadManager,
              let pipeline = appState.indexingPipeline else { return 0 }
        let entries = appState.manifestStore.diffResult?.known ?? appState.manifestStore.bundledEntries
        return entries.filter {
            dm.isVolumeDownloaded($0.volumeId) &&
            (try? pipeline.isVolumeIndexed($0.volumeId)) == true
        }.count
    }

    private struct ActiveTask {
        let label: String
        let systemImage: String
        let progress: Double?
        let eta: String?
    }

    private var activeTask: ActiveTask? {
        if let update = appState.currentIndexingProgress {
            let progress: Double? = update.totalDocuments > 0
                ? Double(update.completedDocuments) / Double(update.totalDocuments)
                : nil
            let eta: String? = {
                guard update.docsPerSecond > 0,
                      update.totalDocuments > update.completedDocuments else { return nil }
                let remaining = update.totalDocuments - update.completedDocuments
                let seconds = Double(remaining) / update.docsPerSecond
                return "~\(Int(seconds.rounded()))s"
            }()
            return ActiveTask(
                label: "Indexing \(update.volumeId)…",
                systemImage: "square.and.arrow.down",
                progress: progress,
                eta: eta
            )
        }

        if case .running(let processed, let total, let docId) =
            appState.backgroundSummarizationProgress.state {
            let progress: Double? = total > 0
                ? Double(processed) / Double(total)
                : nil
            let label: String = {
                if total == 0 {
                    return "Summarizing…"
                }
                let base = "Summarizing \(processed)/\(total)"
                if let id = docId { return "\(base) — \(id)" }
                return base
            }()
            return ActiveTask(
                label: label,
                systemImage: "sparkles",
                progress: progress,
                eta: nil
            )
        }

        if !appState.downloadQueue.isEmpty {
            return ActiveTask(
                label: "\(appState.downloadQueue.count) download\(appState.downloadQueue.count == 1 ? "" : "s") queued",
                systemImage: "arrow.down.circle",
                progress: nil,
                eta: nil
            )
        }

        return nil
    }
}

// MARK: - CitationPopoverView

/// Popover displaying a formatted FRUS citation for the current document.
///
/// Three styles: history.state.gov (default), Chicago, Turabian.
/// Volume editors are sourced from `VolumeManifestEntry.editors`.
/// The general editor is intentionally excluded per history.state.gov guidance.
///
/// Version history:
///   1.0 — New UI scaffolding
struct CitationPopoverView: View {
    let entry: DocumentBrowserEntry

    @Environment(AppState.self) private var appState
    @State private var selectedStyle: CitationPopoverStyle = .historyStateDotGov
    /// Publication year extracted live from the volume's TEI `<publicationStmt><date>`.
    /// Preferred over the manifest value, which may contain a coverage range rather
    /// than the actual print year.
    @State private var parsedPublicationYear: String? = nil

    private var volumeEntry: VolumeManifestEntry? {
        appState.manifestStore.entry(forVolumeId: entry.volumeId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header
            HStack {
                Label("Citation", systemImage: "quote.closing")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
            }

            // Document identity
            VStack(alignment: .leading, spacing: 2) {
                Text("Doc \(entry.documentNumber ?? entry.documentId) · \(entry.volumeId)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text(entry.header)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
            }

            // Style picker
            Picker("Style", selection: $selectedStyle) {
                ForEach(CitationPopoverStyle.allCases) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            // Citation text — rendered as Markdown so _series title_ displays as italic.
            Group {
                if let attrStr = try? AttributedString(
                    markdown: formattedCitation,
                    options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                ) {
                    Text(attrStr)
                } else {
                    Text(formattedCitation)
                }
            }
            .font(.custom("Georgia", size: 12))
            .lineSpacing(4)
            .textSelection(.enabled)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 0.5)
            )

            // Metadata
            if let vol = volumeEntry {
                VStack(alignment: .leading, spacing: 3) {
                    if !vol.editors.isEmpty {
                        metaRow("Volume editors", vol.editors.joined(separator: ", "))
                    }
                    let yr = effectiveYear(for: vol)
                    metaRow("Published", "\(effectivePublisher(year: yr)), \(yr)")
                    if let docNum = entry.documentNumber {
                        metaRow("Document no.", docNum)
                    }
                }
                .font(.system(size: 11))
            }

            // Canonical URL
            if let url = canonicalURL {
                HStack(spacing: 4) {
                    Image(systemName: "link").font(.system(size: 10)).foregroundStyle(.secondary)
                    Text(url)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }

            // Actions
            HStack(spacing: 6) {
                Button {
                    copyToClipboard(formattedCitation)
                } label: {
                    Label("Copy citation", systemImage: "doc.on.doc").font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if let url = canonicalURL {
                    Button {
                        copyToClipboard(url)
                    } label: {
                        Label("Copy URL", systemImage: "link").font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Spacer()

                Button {
                    // Zotero export — deferred to future session
                } label: {
                    Label("Zotero", systemImage: "square.and.arrow.up").font(.system(size: 11))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

        }
        .padding(14)
        .frame(width: 440)
        // Load the publication year from the volume's own TEI header when available.
        // The bundled manifest may have a coverage range in publicationDate rather than
        // the actual print year; the live XML is authoritative.
        .task(id: entry.id) { await loadPublicationYear() }
    }

    // MARK: - Formatted Citation

    /// Builds the formatted citation string.
    ///
    /// Fields used (in order): series title (italicised), subseries, volume number,
    /// volume title, editors, city, publisher, year, document location.
    /// The document heading is intentionally excluded — FRUS citations reference the
    /// volume rather than quoting the document title.
    private var formattedCitation: String {
        guard let vol = volumeEntry else {
            return "Citation unavailable — volume metadata not loaded."
        }

        // vol.title contains the full series/subseries/volume path, e.g.:
        //   "Foreign Relations of the United States, 1969–1976, Volume XIX, Part 1, Korea, 1969–1972"
        let volTitle = vol.title
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let year      = effectiveYear(for: vol)
        let city      = "Washington, D.C."
        let publisher = effectivePublisher(year: year)
        let docNum    = entry.documentNumber.map { "Document \($0)" } ?? entry.documentId

        // Editor list: "Name" / "Name and Name" / "Name, Name, and Name"
        let editorString: String? = {
            let eds = vol.editors
            guard !eds.isEmpty else { return nil }
            switch eds.count {
            case 1: return eds[0]
            case 2: return "\(eds[0]) and \(eds[1])"
            default:
                return eds.dropLast().joined(separator: ", ") + ", and \(eds.last!)"
            }
        }()

        switch selectedStyle {
        case .historyStateDotGov:
            // _Series title_, rest of volume title, ed./eds. Name (City: Publisher, Year), Document N.
            var result = italicizedSeriesTitle(volTitle)
            if let eds = editorString {
                let prefix = vol.editors.count == 1 ? "ed." : "eds."
                result += ", \(prefix) \(eds)"
            }
            result += " (\(city): \(publisher), \(year)), \(docNum)."
            return result

        case .chicago:
            // *Full volume title*, edited by Name. (City: Publisher, Year), Document N.
            var result = "*\(volTitle)*"
            if let eds = editorString { result += ", edited by \(eds)" }
            result += " (\(city): \(publisher), \(year)), \(docNum)."
            return result

        case .turabian:
            // *Full volume title*. Edited by Name. City: Publisher, Year. Document N.
            var result = "*\(volTitle)*"
            if let eds = editorString { result += ". Edited by \(eds)" }
            result += ". \(city): \(publisher), \(year). \(docNum)."
            return result
        }
    }

    // MARK: - Publication Year

    /// Returns the best available publication year for `vol`.
    ///
    /// Priority: (1) `parsedPublicationYear` extracted live from the volume XML's
    /// `<publicationStmt><date>` element; (2) the first plausible 4-digit year
    /// found in the manifest's `publicationDate` string; (3) "n.d."
    private func effectiveYear(for vol: VolumeManifestEntry) -> String {
        if let live = parsedPublicationYear, !live.isEmpty { return live }
        guard let pd = vol.publicationDate else { return "n.d." }
        // Extract the first 4-digit number that looks like a year (post-1750).
        let segments = pd.components(separatedBy: .init(charactersIn: "0123456789").inverted)
        if let yr = segments.first(where: { $0.count == 4 }),
           let y = Int(yr), y > 1750 { return yr }
        return "n.d."
    }

    private func effectivePublisher(year: String) -> String {
        let y = Int(year) ?? 0
        return y >= 2014
            ? "United States Government Publishing Office"
            : "Government Printing Office"
    }

    /// Wraps the series name portion of a FRUS volume title in underscores (Markdown italics).
    private func italicizedSeriesTitle(_ fullTitle: String) -> String {
        let knownSeries = [
            "Foreign Relations of the United States",
            "Papers Relating to the Foreign Relations of the United States",
        ]
        for prefix in knownSeries where fullTitle.hasPrefix(prefix) {
            return "_\(prefix)_" + String(fullTitle.dropFirst(prefix.count))
        }
        return fullTitle
    }

    // MARK: - Live Publication Year Extraction

    /// Reads the first portion of the downloaded volume XML and extracts the
    /// publication year from `<publicationStmt><date @when>` or its text content.
    private func loadPublicationYear() async {
        guard let dm = appState.downloadManager,
              dm.isVolumeDownloaded(entry.volumeId) else { return }
        let url = dm.volumeURL(for: entry.volumeId)
        parsedPublicationYear = await Self.extractPublicationYear(from: url)
    }

    private static func extractPublicationYear(from url: URL) async -> String? {
        await Task.detached(priority: .utility) {
            guard let stream = InputStream(url: url) else { return nil }
            stream.open()
            defer { stream.close() }
            // 8 KB covers the teiHeader which always appears at the top of the file.
            var buffer = [UInt8](repeating: 0, count: 8_192)
            let n = stream.read(&buffer, maxLength: buffer.count)
            guard n > 0,
                  let text = String(bytes: Array(buffer[0..<n]), encoding: .utf8) else { return nil }

            // Isolate the <publicationStmt> block.
            guard let blockStart = text.range(of: "<publicationStmt"),
                  let blockEnd   = text.range(of: "</publicationStmt>"),
                  blockStart.lowerBound < blockEnd.lowerBound else { return nil }
            let block = String(text[blockStart.lowerBound..<blockEnd.upperBound])

            // Prefer @when="YYYY" — most authoritative, always the actual publication year.
            if let yr = regexFirstCapture(#"when="(\d{4})""#, in: block),
               let y = Int(yr), y > 1750, y < 2100 { return yr }
            // Fall back to bare year as text content, e.g. <date>2010</date>.
            if let yr = regexFirstCapture(#">(\d{4})\s*<"#, in: block),
               let y = Int(yr), y > 1750, y < 2100 { return yr }
            return nil
        }.value
    }

    private nonisolated static func regexFirstCapture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text,
                                           range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 2,
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    // MARK: - Helpers

    private var canonicalURL: String? {
        "https://history.state.gov/historicaldocuments/\(entry.volumeId)/\(entry.documentId)"
    }

    private var accessedDate: String {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
    }

    private func metaRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(label).foregroundStyle(.secondary).frame(width: 96, alignment: .leading)
            Text(value).foregroundStyle(.primary)
        }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - CitationPopoverStyle
// Renamed from CitationStyle to avoid conflict with Citation/CitationFormatter.CitationStyle.

private enum CitationPopoverStyle: String, CaseIterable, Identifiable {
    case historyStateDotGov
    case chicago
    case turabian

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .historyStateDotGov: return "history.state.gov"
        case .chicago:            return "Chicago"
        case .turabian:           return "Turabian"
        }
    }
}

// MARK: - MacTagPickerSheet

/// macOS document-level user-tag picker.
///
/// Lists all `UserTag` records from SwiftData and lets the user toggle which tags
/// apply to this document. Tags are stored as `userTagIds` on a dedicated
/// `DocumentUserTag` record (note: the full document-level tag persistence model
/// is scaffolded here; complete write-back requires a `DocumentUserTag` SwiftData
/// model to be added in a future session).
struct MacTagPickerSheet: View {
    let entry: DocumentBrowserEntry
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \UserTag.name) private var allTags: [UserTag]
    @State private var selectedTagIds: Set<UUID> = []
    @State private var newTagName: String = ""

    var body: some View {
        NavigationStack {
            List {
                if allTags.isEmpty {
                    Section {
                        Text("No user tags yet. Type a name below to create one.")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                } else {
                    Section("Your Tags") {
                        ForEach(allTags) { tag in
                            Toggle(isOn: Binding(
                                get: { selectedTagIds.contains(tag.id) },
                                set: { on in
                                    if on { selectedTagIds.insert(tag.id) }
                                    else  { selectedTagIds.remove(tag.id) }
                                }
                            )) {
                                Text(tag.name)
                            }
                        }
                    }
                }

                Section("New Tag") {
                    HStack {
                        TextField("Tag name…", text: $newTagName)
                            .onSubmit { createTag() }
                        Button("Add", action: createTag)
                            .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .listStyle(.inset)
            .navigationTitle("Tags — \(entry.documentNumber.map { "Doc \($0)" } ?? entry.documentId)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 340, minHeight: 300)
    }

    private func createTag() {
        let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let tag = UserTag(name: name)
        modelContext.insert(tag)
        selectedTagIds.insert(tag.id)
        newTagName = ""
    }
}

struct SummaryPromptPickerView: View {
    @Bindable var vm: DocumentViewModel
    var body: some View { Text("Prompt picker").padding() }
}

// MARK: - PersonDetailSheet (macOS)
// The iOS PersonDetailSheet is private to DocumentView/DocumentView.swift.
// This macOS version is used by MacDocumentView.

struct PersonDetailSheet: View {
    let person: PersonEntry
    let mentionCount: Int
    let onFindAllMentions: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(person.name).font(.headline)
                    if let desc = person.description {
                        Text(desc).font(.body).foregroundStyle(.secondary)
                    }
                }
                Section {
                    if mentionCount > 0 {
                        Label(
                            "Mentioned in \(mentionCount) indexed \(mentionCount == 1 ? "document" : "documents")",
                            systemImage: "doc.text.magnifyingglass"
                        )
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        Button {
                            dismiss()
                            onFindAllMentions()
                        } label: {
                            Label("Find all mentions", systemImage: "magnifyingglass")
                        }
                    } else {
                        Text("Not found in indexed documents")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                } header: {
                    Text("In Indexed Documents")
                }
            }
            .listStyle(.inset)
            .navigationTitle("List of Persons")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}

// MARK: - GlossDetailSheet (macOS)

struct GlossDetailSheet: View {
    let gloss: GlossEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(gloss.term).font(.headline)
                    if let def = gloss.definition {
                        Text(def).font(.body).foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.inset)
            .navigationTitle("Glossary")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 360, minHeight: 240)
    }
}

// MARK: - CorpusBrowserWindowView

/// Standalone macOS window listing all FRUS subseries and their volumes.
///
/// Uses a `NavigationSplitView`: subseries in the sidebar, volumes in the detail
/// column. Selecting a volume opens `CorpusVolumeDetailSheet` which shows the volume
/// structure (chapters, compilations) and handles download/indexing when needed.
///
/// ## Sidebar controls
/// - **Sort**: toggle between newest-first (descending) and oldest-first (ascending)
/// - **Filter**: hide subseries that have no volumes downloaded to this device
///
/// Version history:
///   1.0 — initial implementation
///   1.1 — sort and filter sidebar controls; volume-structure sheet with in-app
///          download/indexing; `CorpusVolumeDocumentListView` replaced by
///          `CorpusVolumeDetailSheet` + `CorpusSectionDocumentListView`
struct CorpusBrowserWindowView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    enum ViewMode { case browse, connections }
    @State private var viewMode: ViewMode = .browse

    @State private var selectedSubseries: String? = nil
    @State private var selectedVolume: VolumeManifestEntry? = nil
    @State private var searchText: String = ""
    @State private var sortDescending: Bool = true
    @State private var filterDownloaded: Bool = false

    private var allEntries: [VolumeManifestEntry] {
        appState.manifestStore.diffResult?.known ?? appState.manifestStore.bundledEntries
    }

    private var subseries: [String] {
        var seen = Set<String>()
        var all = allEntries.compactMap { e in
            seen.insert(e.subseries).inserted ? e.subseries : nil
        }
        if filterDownloaded {
            let dm = appState.downloadManager
            all = all.filter { sub in
                allEntries.filter { $0.subseries == sub }
                    .contains { dm?.isVolumeDownloaded($0.volumeId) ?? false }
            }
        }
        return all.sorted {
            let a = Int(String($0.prefix(4))) ?? 0
            let b = Int(String($1.prefix(4))) ?? 0
            return sortDescending ? a > b : a < b
        }
    }

    private func volumes(for sub: String) -> [VolumeManifestEntry] {
        allEntries.filter { $0.subseries == sub }
    }

    var body: some View {
        Group {
            if viewMode == .connections {
                VolumeConnectionGraphView()
                    .navigationTitle("Corpus Browser")
                    .toolbar { modeToolbar }
                    .frame(minWidth: 540, minHeight: 440)
            } else {
                browseView
            }
        }
    }

    private var browseView: some View {
        NavigationSplitView {
            List(selection: $selectedSubseries) {
                ForEach(subseries, id: \.self) { sub in
                    subseriesRow(sub).tag(sub)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Corpus Browser")
            .navigationSplitViewColumnWidth(min: 150, ideal: 170)
            .toolbar {
                modeToolbar
                ToolbarItem(placement: .primaryAction) {
                    Button { sortDescending.toggle() } label: {
                        Image(systemName: sortDescending ? "arrow.down" : "arrow.up")
                    }
                    .help(sortDescending ? "Sort oldest first" : "Sort newest first")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { filterDownloaded.toggle() } label: {
                        Image(systemName: filterDownloaded
                              ? "arrow.down.circle.fill" : "arrow.down.circle")
                    }
                    .help(filterDownloaded ? "Show all subseries" : "Show downloaded only")
                }
            }
        } detail: {
            if let sub = selectedSubseries {
                volumeList(for: sub)
            } else {
                ContentUnavailableView(
                    "Select a Subseries",
                    systemImage: "books.vertical",
                    description: Text("Choose a subseries from the list to browse its volumes.")
                )
            }
        }
        .frame(minWidth: 540, minHeight: 440)
    }

    @ToolbarContentBuilder
    private var modeToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Picker("", selection: $viewMode) {
                Label("Browse", systemImage: "books.vertical").tag(ViewMode.browse)
                Label("Connections", systemImage: "point.3.connected.trianglepath.dotted").tag(ViewMode.connections)
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
        }
    }

    private func subseriesRow(_ sub: String) -> some View {
        let vols = volumes(for: sub)
        let dlCount = vols.filter {
            appState.downloadManager?.isVolumeDownloaded($0.volumeId) ?? false
        }.count
        return HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(sub).font(.system(size: 13))
                Text(dlCount > 0
                     ? "\(dlCount)/\(vols.count) downloaded"
                     : "\(vols.count) volumes")
                    .font(.system(size: 10))
                    .foregroundStyle(dlCount > 0 ? Color.secondary : Color.secondary.opacity(0.5))
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func volumeList(for subseries: String) -> some View {
        let vols = volumes(for: subseries)
        let filtered: [VolumeManifestEntry] = searchText.isEmpty ? vols : vols.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.volumeId.localizedCaseInsensitiveContains(searchText)
        }

        List(filtered) { vol in
            VStack(alignment: .leading, spacing: 2) {
                Text(vol.title)
                    .font(.system(size: 12))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Text(vol.volumeId)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    if let dm = appState.downloadManager, dm.isVolumeDownloaded(vol.volumeId) {
                        Label("Downloaded", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.green)
                            .labelStyle(.iconOnly)
                    } else if appState.downloadQueue.contains(vol.volumeId) {
                        Label("Downloading", systemImage: "arrow.down.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(.blue)
                            .labelStyle(.iconOnly)
                    }
                }
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
            .onTapGesture { selectedVolume = vol }
        }
        .listStyle(.inset)
        .searchable(text: $searchText, prompt: "Search volumes…")
        .navigationTitle(subseries)
        .sheet(item: $selectedVolume) { vol in
            CorpusVolumeDetailSheet(volume: vol)
        }
    }
}

// MARK: - CorpusVolumeDetailSheet

/// Sheet showing a volume's structural overview (chapters, compilations) in the corpus browser.
///
/// ## Phase machine
/// ```
/// notDownloaded ──(Download)──► downloading
/// downloading ──(complete)──► indexing   [app auto-indexes after download]
/// notIndexed ──(Index Now)──► indexing
/// indexing ──(pipeline done)──► loadingStructure ──► ready
/// ready ──(tap section)──► CorpusSectionDocumentListView sheet
/// ```
///
/// Download progress is inferred from `AppState.downloadQueue` transitions.
/// Indexing progress is read from `AppState.currentIndexingProgress`.
/// Both are `@Observable` properties so the view re-renders automatically.
private struct CorpusVolumeDetailSheet: View {
    let volume: VolumeManifestEntry
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    enum Phase {
        case notDownloaded, downloading, indexing, loadingStructure, notIndexed
        case ready(VolumeStructure)
        case error(String)
    }

    @State private var phase: Phase = .notDownloaded
    @State private var liveProgress: IndexingProgressUpdate? = nil
    @State private var selectedSection: VolumeSection? = nil
    private let parser = FRUSDocumentParser()

    var body: some View {
        NavigationStack {
            phaseContent
                .navigationTitle(volume.title)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
        }
        .frame(minWidth: 500, minHeight: 440)
        .task { await determinePhase() }
        // Download completion: queue no longer contains volumeId AND file now exists → auto-index begins
        .onChange(of: appState.downloadQueue) { _, queue in
            if case .downloading = phase,
               !queue.contains(volume.volumeId),
               appState.downloadManager?.isVolumeDownloaded(volume.volumeId) == true {
                phase = .indexing
                liveProgress = nil
            }
        }
        // Indexing progress: update display; when complete → load structure
        .onChange(of: appState.currentIndexingProgress) { _, progress in
            guard case .indexing = phase else { return }
            if let progress, progress.volumeId == volume.volumeId {
                liveProgress = progress
                if progress.stage == .complete { Task { await loadStructure() } }
            } else if progress == nil {
                // Stream ended (another volume completed) — check if ours is now indexed
                Task { await loadStructure() }
            }
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch phase {
        case .notDownloaded:    notDownloadedView
        case .downloading:      downloadingView
        case .indexing:         indexingView
        case .loadingStructure:
            ProgressView("Loading contents…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .notIndexed:       notIndexedView
        case .ready(let s):     structureView(s)
        case .error(let msg):
            ContentUnavailableView(
                "Error",
                systemImage: "exclamationmark.triangle",
                description: Text(msg)
            )
        }
    }

    // MARK: Phase logic

    private func determinePhase() async {
        if appState.downloadQueue.contains(volume.volumeId) { phase = .downloading; return }
        if let p = appState.currentIndexingProgress, p.volumeId == volume.volumeId {
            phase = .indexing; liveProgress = p; return
        }
        guard let dm = appState.downloadManager, dm.isVolumeDownloaded(volume.volumeId) else {
            phase = .notDownloaded; return
        }
        guard let pipeline = appState.indexingPipeline else { phase = .notIndexed; return }
        if (try? pipeline.isVolumeIndexed(volume.volumeId)) == true {
            await loadStructure()
        } else {
            phase = .notIndexed
        }
    }

    private func loadStructure() async {
        guard let dm = appState.downloadManager else { return }
        phase = .loadingStructure
        let url = dm.volumeURL(for: volume.volumeId)
        do {
            let structure = try await parser.parseVolumeStructure(volumeURL: url)
            phase = .ready(structure)
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    // MARK: Phase views

    private var notDownloadedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Volume Not Downloaded")
                .font(.headline)
            if volume.sizeBytes > 0 {
                Text("Approx. \(formattedMB(volume.sizeBytes))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Text("Download this volume to browse its chapters, compilations, and documents.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            Button {
                guard let dm = appState.downloadManager else { return }
                phase = .downloading
                Task { await dm.enqueueDownload(volumeId: volume.volumeId,
                                                downloadUrl: volume.downloadUrl) }
            } label: {
                Label("Download Volume", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.borderedProminent)
            .disabled(appState.downloadManager == nil)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var downloadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Downloading…")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Indexing will begin automatically when the download completes.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var indexingView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Indexing Volume", systemImage: "arrow.triangle.2.circlepath")
                .font(.headline)
            if let prog = liveProgress, prog.totalDocuments > 0 {
                ProgressView(value: Double(prog.completedDocuments),
                             total: Double(prog.totalDocuments))
                HStack {
                    Text(indexingStageLabel(prog.stage))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(prog.completedDocuments) / \(prog.totalDocuments)")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Preparing…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var notIndexedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Index Required")
                .font(.headline)
            Text("This volume has been downloaded but must be indexed before you can browse its documents.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            Button {
                guard let pipeline = appState.indexingPipeline else { return }
                phase = .indexing
                liveProgress = nil
                Task {
                    do {
                        try await pipeline.indexVolume(volume.volumeId)
                        await loadStructure()
                    } catch {
                        phase = .error(error.localizedDescription)
                    }
                }
            } label: {
                Label("Index Now", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    @ViewBuilder
    private func structureView(_ structure: VolumeStructure) -> some View {
        if structure.isEmpty {
            ContentUnavailableView(
                "No Contents",
                systemImage: "doc.text",
                description: Text("No structural sections were found in this volume.")
            )
        } else {
            List {
                Section("Contents") {
                    ForEach(structure.sections) { section in
                        Button {
                            selectedSection = section
                        } label: {
                            SectionRowLabel(section: section)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.inset)
            .sheet(item: $selectedSection) { section in
                CorpusSectionDocumentListView(volume: volume, section: section) { doc in
                    appState.pendingBrowseDocument = doc
                    dismiss()
                }
            }
        }
    }

    // MARK: Helpers

    private func formattedMB(_ bytes: Int) -> String {
        String(format: "%.0f MB", Double(bytes) / 1_000_000)
    }

    private func indexingStageLabel(_ stage: IndexingStage) -> String {
        switch stage {
        case .parsing:         return "Parsing documents…"
        case .extractingDates: return "Extracting dates…"
        case .indexingPersons: return "Indexing persons…"
        case .buildingFTS5:    return "Building search index…"
        case .complete:        return "Complete"
        }
    }
}

// MARK: - CorpusSectionDocumentListView

/// Sheet presenting the document list for a single section (chapter / compilation)
/// selected from `CorpusVolumeDetailSheet`.
///
/// Tapping a document calls `onDocumentSelected`, which posts the entry to
/// `AppState.pendingBrowseDocument` and dismisses all corpus browser sheets so the
/// main window can navigate to the document.
private struct CorpusSectionDocumentListView: View {
    let volume: VolumeManifestEntry
    let section: VolumeSection
    let onDocumentSelected: (DocumentBrowserEntry) -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow

    @State private var documents: [DocumentBrowserEntry] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if documents.isEmpty {
                    ContentUnavailableView(
                        "No Documents",
                        systemImage: "doc.text",
                        description: Text("No indexed documents found in this section.")
                    )
                } else {
                    List(documents, id: \.documentId) { doc in
                        Button {
                            dismiss()
                            onDocumentSelected(doc)
                        } label: {
                            DocumentRowLabel(doc: doc)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                appState.currentGraphEntry = doc
                                openWindow(id: "frus.crossReferenceGraph")
                            } label: {
                                Label("Graph", systemImage: "point.3.connected.trianglepath.dotted")
                            }
                            .tint(.indigo)
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .navigationTitle(section.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 460, minHeight: 400)
        .task { await loadDocuments() }
    }

    private func loadDocuments() async {
        guard let pipeline = appState.indexingPipeline else { isLoading = false; return }
        let all = (try? await pipeline.documents(forVolume: volume.volumeId)) ?? []
        let sectionIds = Set(section.allDocumentIds)
        documents = all.filter { sectionIds.contains($0.documentId) }
        isLoading = false
    }
}

struct SourceExplorerWindowView: View {
    var body: some View {
        Text("Source Explorer")
            .font(.title2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#endif // os(macOS)
