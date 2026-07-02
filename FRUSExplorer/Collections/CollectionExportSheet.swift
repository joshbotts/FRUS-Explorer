// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - ExportSheetView

/// Picker + progress view that runs the chosen exporter and presents a share sheet.
///
/// Version history:
///   1.0 — extracted from CollectionEditorView.swift (Session 2026-07-02, Collections Authoring Phase 1)
struct ExportSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    let collection: Collection
    let entries: [CollectionEntry]
    let allNotes: [ResearchNote]
    let appState: AppState

    @State private var selectedFormat: ExportFormat = .pdf
    @State private var isExporting = false
    @State private var exportedURL: URL? = nil
    @State private var exportError: String? = nil
    /// D9a privacy default: research notes are excluded from a shared `.fruscollection`
    /// file unless the user opts in here. Independent of the collection's `includeNotes`
    /// composition setting (which governs rendered exports, not shared source files).
    @State private var includeNotesInSharedFile = false
    /// Non-nil while volumes need to be downloaded/indexed before export can proceed.
    @State private var preparingMessage: String? = nil
    /// Non-nil while summaries are being generated on demand.
    @State private var summaryGeneratingMessage: String? = nil
    /// Non-nil after a successful "Send to Zotero Library" run (drives the result alert).
    @State private var zoteroResult: ZoteroSendResult? = nil

    // MARK: - Ephemeral document reference (smart collection path)

    /// Lightweight document reference used for smart-collection resolution.
    /// Avoids creating SwiftData model instances outside a context.
    private struct SmartEntry {
        let documentId: String
        let volumeId: String
        let sortOrder: Int
    }

    /// The document formats offered in the picker. Zotero RIS is excluded — it now lives in the
    /// unified "Send to Zotero…" menu (D6) — and the native `.fruscollection` file is hidden for
    /// smart (saved-search) collections until they're snapshotted (D8/D9b).
    private var availableFormats: [ExportFormat] {
        ExportFormat.allCases.filter { fmt in
            switch fmt {
            case .zoteroJSON:     return false
            case .fruscollection: return collection.savedSearchId == nil
            default:              return true
            }
        }
    }

    var body: some View {
        #if os(macOS)
        macExportBody
        #else
        iOSExportBody
        #endif
    }

    // MARK: - macOS body

    /// macOS-native export dialog.
    ///
    /// Replaces the `NavigationStack { Form }` pattern used on iOS, which adds
    /// an unwanted navigation bar on macOS. Changes from the iOS layout:
    /// - Title row + Divider + content area + Divider + button bar
    /// - Format uses `.pickerStyle(.radioGroup)` — the HIG-correct control for
    ///   2–5 mutually exclusive options in a dialog body (segmented is correct
    ///   for toolbars/control strips, not dialog content areas)
    /// - Contents List uses a `LabeledContent` row with `.pickerStyle(.menu)`
    /// - Progress spinner sits inline in the button bar next to Export
    /// - Error message appears above the button bar, not in a Form section
    /// - Export is the default action (↩) via `.keyboardShortcut(.defaultAction)`
    #if os(macOS)
    private var macExportBody: some View {
        VStack(spacing: 0) {

            // Title
            Text(String(localized: "export.nav.title", defaultValue: "Export Collection"))
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 12)

            Divider()

            // Options
            VStack(alignment: .leading, spacing: 18) {

                // Format — radio buttons (HIG: mutually exclusive choices in a dialog)
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "export.format.header", defaultValue: "Format"))
                        .font(.callout.weight(.medium))
                    Picker(
                        String(localized: "export.format.picker", defaultValue: "Format"),
                        selection: $selectedFormat
                    ) {
                        ForEach(availableFormats) { fmt in
                            Text(fmt.displayName).tag(fmt)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                }

                if selectedFormat == .fruscollection {
                    nativeShareOptions
                } else {
                    // Content composition (body depth, footnotes, notes, highlights, word cloud)
                    // now lives in the collection manager's Composition section and is persisted
                    // on the collection — this sheet is purely format + destination.
                    Text(String(localized: "export.compositionHint",
                                defaultValue: "Body, footnotes, notes, and other content options are set in the collection's Composition section."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            // Inline error — shown above the button bar when present
            if let error = exportError {
                Divider()
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.callout)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }

            Divider()

            // Button bar
            HStack(spacing: 12) {
                Button(String(localized: "export.close", defaultValue: "Close")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                // Progress feedback — inline in the button bar when busy
                if let msg = preparingMessage ?? summaryGeneratingMessage {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text(msg).font(.callout).foregroundStyle(.secondary)
                    }
                } else if isExporting {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text(String(localized: "export.progress.label",
                                    defaultValue: "Exporting…"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                zoteroMenu

                Button {
                    Task { await runExport() }
                } label: {
                    Label(
                        String(localized: "export.button.label", defaultValue: "Export"),
                        systemImage: "square.and.arrow.up"
                    )
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(isExporting
                          || preparingMessage != nil
                          || (entries.isEmpty && collection.savedSearchId == nil))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 380, idealWidth: 420, minHeight: 260)
        .sheet(item: $exportedURL) { url in
            MacExportCompleteView(url: url)
        }
        .zoteroResultAlert(result: $zoteroResult, message: zoteroResultMessage, openURL: openURL)
    }
    #endif

    // MARK: - iOS body

    /// iOS/iPadOS export sheet.
    ///
    /// Retains `NavigationStack { Form }` which is the correct pattern on iOS:
    /// the navigation bar provides title and Cancel/Close button placement,
    /// and the Form renders correctly as an inset-grouped table.
    #if os(iOS)
    private var iOSExportBody: some View {
        NavigationStack {
            Form {
                Section(String(localized: "export.format.header", defaultValue: "Format")) {
                    Picker("", selection: $selectedFormat) {
                        ForEach(availableFormats) { fmt in Text(fmt.displayName).tag(fmt) }
                    }
                    .pickerStyle(.menu)
                }

                if selectedFormat == .fruscollection {
                    Section {
                        nativeShareOptions
                    }
                } else {
                    Section {
                        Text(String(localized: "export.compositionHint",
                                    defaultValue: "Body, footnotes, notes, and other content options are set in the collection's Composition section."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    if let msg = preparingMessage ?? summaryGeneratingMessage {
                        HStack {
                            ProgressView().padding(.trailing, 8)
                            Text(msg).foregroundStyle(.secondary)
                        }
                    } else if isExporting {
                        HStack {
                            ProgressView().padding(.trailing, 8)
                            Text(String(localized: "export.progress.label",
                                        defaultValue: "Exporting…"))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button {
                            Task { await runExport() }
                        } label: {
                            Label(
                                String(localized: "export.button.label", defaultValue: "Export"),
                                systemImage: "square.and.arrow.up"
                            )
                        }
                        .disabled(entries.isEmpty && collection.savedSearchId == nil)
                        zoteroMenu
                    }
                }

                if let error = exportError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }
            }
            .navigationTitle(String(localized: "export.nav.title", defaultValue: "Export Collection"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "export.close", defaultValue: "Close")) {
                        dismiss()
                    }
                }
            }
            .sheet(item: $exportedURL) { url in
                ShareSheet(url: url)
                    .ignoresSafeArea()
            }
            .zoteroResultAlert(result: $zoteroResult, message: zoteroResultMessage, openURL: openURL)
        }
    }
    #endif // os(iOS)

    private func runExport() async {
        exportError = nil

        // Native shareable-collection file (D9): serialize the collection's source directly.
        if selectedFormat == .fruscollection {
            runNativeExport()
            return
        }

        // Smart collection path: resolve documents via the linked SavedSearch.
        if let searchId = collection.savedSearchId {
            isExporting = true
            defer { isExporting = false; summaryGeneratingMessage = nil }

            guard let searchService = appState.searchService else {
                exportError = String(localized: "export.smart.noSearchService",
                                     defaultValue: "Search service unavailable. Please try again.")
                return
            }
            let descriptor = FetchDescriptor<SavedSearch>(
                predicate: #Predicate { $0.id == searchId }
            )
            guard let savedSearch = try? modelContext.fetch(descriptor).first else {
                exportError = String(localized: "export.smart.missingSearch",
                                     defaultValue: "The linked saved search could not be found. It may have been deleted.")
                return
            }
            do {
                // Resolve the full result set (not just the first page) — the default
                // `search` limit is `defaultPageSize` (20), which silently truncated
                // smart-collection exports. Mirror the live saved search's hard limit.
                let results = try await searchService.search(
                    parameters: savedSearch.searchParameters,
                    limit: SearchViewModel.searchHardLimit
                )
                let smartEntries = results.enumerated().map { i, r in
                    SmartEntry(documentId: r.documentId, volumeId: r.volumeId, sortOrder: i)
                }
                var docs = await resolveSmartDocuments(smartEntries)
                let options = buildExportOptions()

                // Resolve AI summaries on demand when exporting at .summaryOnly depth,
                // mirroring the static-collection path below. Without this, a smart
                // collection exported as "Summary only" would carry no summary text
                // even when the user has generated summaries for the saved search.
                let summaryDocs = docs.filter { $0.bodyDepth == .summaryOnly }
                if !summaryDocs.isEmpty {
                    guard let promptId = options.summaryPromptId else {
                        exportError = String(localized: "export.summaryNoPrompt",
                                             defaultValue: "Choose a summarization prompt in the collection's Composition section to export summaries.")
                        return
                    }
                    let bodyTexts = Dictionary(uniqueKeysWithValues:
                        summaryDocs.map { ("\($0.volumeId)/\($0.documentId)", $0.bodyText) })
                    let summaries = try await resolveSummaries(for: summaryDocs, promptId: promptId,
                                                               bodyTexts: bodyTexts)
                    docs = docs.map { doc in
                        guard doc.bodyDepth == .summaryOnly,
                              let text = summaries["\(doc.volumeId)/\(doc.documentId)"] else { return doc }
                        return doc.withSummary(text)
                    }
                }

                let metadata = CollectionExportMetadata(name: collection.name, note: collection.note)
                guard let exporter = selectedFormat.makeExporter() else { return }
                let url = try await exporter.export(metadata: metadata, documents: docs, options: options)
                exportedURL = url
                appState.logEvent(.export(
                    format: selectedFormat.rawValue,
                    documentCount: docs.count
                ))
            } catch {
                exportError = error.localizedDescription
            }
            return
        }

        // Static collection path.
        // Phase 1: ensure every volume referenced by the collection is downloaded and indexed.
        await prepareVolumes()

        // Phase 2: resolve document content.
        isExporting = true
        do {
            var items = try await resolveItems()
            let opts = buildExportOptions()

            // Phase 2b: generate summaries on demand for entries whose effective body
            // depth is .summaryOnly (per-entry — only the documents that need one).
            let summaryDocs = items.documents.filter { $0.bodyDepth == .summaryOnly }
            if !summaryDocs.isEmpty {
                guard let promptId = opts.summaryPromptId else {
                    exportError = String(localized: "export.summaryNoPrompt",
                                        defaultValue: "Choose a summarization prompt in the collection's Composition section to export summaries.")
                    isExporting = false
                    return
                }
                let bodyTexts = Dictionary(uniqueKeysWithValues:
                    summaryDocs.map { ("\($0.volumeId)/\($0.documentId)", $0.bodyText) })
                let summaries = try await resolveSummaries(for: summaryDocs, promptId: promptId,
                                                           bodyTexts: bodyTexts)
                items = items.map { item in
                    guard case .document(let doc) = item, doc.bodyDepth == .summaryOnly,
                          let text = summaries["\(doc.volumeId)/\(doc.documentId)"] else { return item }
                    return .document(doc.withSummary(text))
                }
            }

            let metadata = CollectionExportMetadata(name: collection.name, note: collection.note)
            guard let exporter = selectedFormat.makeExporter() else { isExporting = false; return }
            let url = try await exporter.export(metadata: metadata, items: items, options: opts)
            exportedURL = url
            appState.logEvent(.export(
                format: selectedFormat.rawValue,
                documentCount: items.documents.count
            ))
        } catch {
            exportError = error.localizedDescription
        }
        isExporting = false
        summaryGeneratingMessage = nil
    }

    /// Assembles `CollectionExportOptions` from the collection's persisted composition
    /// (edited in the manager's Composition section) plus the format-dependent word-cloud gate.
    private func buildExportOptions() -> CollectionExportOptions {
        CollectionExportOptions(
            tocStyle:        CollectionToCStyle(rawValue: collection.tocStyle) ?? .citation,
            footnoteStyle:   CollectionFootnoteStyle(rawValue: collection.footnoteStyle) ?? .all,
            applyHighlights: collection.applyHighlights,
            includeNotes:    collection.includeNotes,
            summaryPromptId: collection.summaryPromptId,
            includeWordCloud: collection.includeWordCloud && (selectedFormat == .pdf || selectedFormat == .html)
        )
    }

    // MARK: - Native collection file (Phase 4 / D9)

    /// Options shown when the native `.fruscollection` format is selected: the D9a
    /// notes-privacy opt-in plus a short explanation of what the shared file carries.
    @ViewBuilder
    private var nativeShareOptions: some View {
        Toggle(String(localized: "export.native.includeNotes",
                      defaultValue: "Include my research notes"),
               isOn: $includeNotesInSharedFile)
        Text(String(localized: "export.native.hint",
                    defaultValue: "Shares an editable copy of this collection — its documents, composition, sections, and prose. Recipients open it in FRUS Explorer and download any volumes they don’t have. Your research notes stay private unless you include them above."))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Serializes the collection to a temporary `.fruscollection` file and routes it into the
    /// shared export-delivery path. Bypasses document resolution entirely — the native format
    /// carries the collection's *source* (references + composition + structure), not rendered
    /// content — so no volume needs to be downloaded to produce it.
    private func runNativeExport() {
        exportError = nil
        // Smart collections have no static entries to serialize yet (D9b); the picker hides the
        // native format for them, but guard defensively.
        guard collection.savedSearchId == nil else {
            exportError = String(localized: "export.native.smartUnsupported",
                                 defaultValue: "Smart collections can’t be shared as a file yet.")
            return
        }
        isExporting = true
        defer { isExporting = false }
        do {
            let resolveNoteTexts: (CollectionEntry) -> [String] = { entry in
                let ids = entry.selectedNoteIds.isEmpty
                    ? (entry.researchNoteId.map { [$0] } ?? [])
                    : entry.selectedNoteIds
                return ids.compactMap { id in allNotes.first { $0.id == id }?.bodyText }
            }
            let file = NativeCollectionSerializer.makeFile(
                from: collection,
                includeNotes: includeNotesInSharedFile,
                resolveNoteTexts: resolveNoteTexts)
            let data = try NativeCollectionSerializer.encode(file)

            let safeName = collection.name.components(separatedBy: CharacterSet(charactersIn: "/:\\?%*|\"<>"))
                .joined(separator: "-")
            let filename = (safeName.isEmpty ? "collection" : safeName)
                + "." + NativeCollectionSerializer.fileExtension
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)
            exportedURL = url
            appState.logEvent(.export(
                format: selectedFormat.rawValue,
                documentCount: entries.filter { $0.entryKind == .document }.count))
        } catch {
            exportError = error.localizedDescription
        }
    }

    // MARK: - Send to Zotero Library (Web API)

    /// `true` when a Zotero account is connected (Settings → Integrations → Zotero).
    private var isZoteroConnected: Bool { ZoteroAccountStore.shared.isConnected }

    /// A single "Send to Zotero…" menu (D6): one entry point that covers both the
    /// connected-account Web-API path (annotation-preserving, works on iOS) and the RIS-file
    /// fallback for Zotero desktop — replacing the former split between a picker format
    /// ("Zotero RIS") and a separate "Send to Zotero Library" button that behaved differently.
    @ViewBuilder
    private var zoteroMenu: some View {
        Menu {
            if isZoteroConnected {
                Button {
                    Task { await sendToZoteroLibrary() }
                } label: {
                    Label(String(localized: "export.zotero.send",
                                 defaultValue: "Send to Zotero Library"),
                          systemImage: "books.vertical")
                }
                Button {
                    Task { await exportZoteroRIS() }
                } label: {
                    Label(String(localized: "export.zotero.risAlt",
                                 defaultValue: "Export RIS File Instead"),
                          systemImage: "doc.text")
                }
            } else {
                Button {
                    Task { await exportZoteroRIS() }
                } label: {
                    Label(String(localized: "export.zotero.risDesktop",
                                 defaultValue: "Export RIS File (Zotero desktop)"),
                          systemImage: "doc.text")
                }
                Text(String(localized: "export.zotero.connectHint",
                            defaultValue: "Connect a Zotero account in Settings to send directly."))
            }
        } label: {
            Label(String(localized: "export.zotero.menu", defaultValue: "Send to Zotero…"),
                  systemImage: "books.vertical")
        }
        .disabled(isExporting || (entries.isEmpty && collection.savedSearchId == nil))
    }

    /// Produces the Zotero RIS file (desktop-import fallback) and routes it into the shared
    /// export delivery. Reuses `resolvedZoteroDocuments()` (static + smart paths) so the RIS
    /// file and the Web-API send always carry the same resolved documents.
    private func exportZoteroRIS() async {
        isExporting = true
        defer { isExporting = false; preparingMessage = nil }
        do {
            let docs = try await resolvedZoteroDocuments()
            guard !docs.isEmpty else {
                exportError = String(localized: "export.zotero.empty",
                                     defaultValue: "This collection has no documents to send.")
                return
            }
            let metadata = CollectionExportMetadata(name: collection.name, note: collection.note)
            let url = try await ZoteroCollectionExporter().export(
                metadata: metadata, documents: docs, options: buildExportOptions())
            exportedURL = url
            appState.logEvent(.export(format: ExportFormat.zoteroJSON.rawValue, documentCount: docs.count))
        } catch is CancellationError {
            return
        } catch {
            exportError = error.localizedDescription
        }
    }

    /// Resolves the collection's documents (static or smart) and POSTs them to the
    /// user's Zotero library, then surfaces a result alert.
    private func sendToZoteroLibrary() async {
        let store = ZoteroAccountStore.shared
        guard let apiKey = store.retrieveKey(), let userID = store.userID else {
            exportError = ZoteroAPIError.missingCredentials.errorDescription
            return
        }
        isExporting = true
        defer { isExporting = false; preparingMessage = nil }
        do {
            let docs = try await resolvedZoteroDocuments()
            let items = docs.sorted { $0.sortOrder < $1.sortOrder }.compactMap(\.zoteroItem)
            guard !items.isEmpty else {
                exportError = String(localized: "export.zotero.empty",
                                     defaultValue: "This collection has no documents to send.")
                return
            }
            let result = try await ZoteroAPIClient().send(
                items: items,
                collectionName: collection.name.isEmpty ? nil : collection.name,
                apiKey: apiKey,
                userID: userID,
                username: store.username
            ) { message in
                Task { @MainActor in preparingMessage = message }
            }
            appState.logEvent(.export(format: "zotero-api", documentCount: result.addedItems))
            zoteroResult = result
        } catch is CancellationError {
            return
        } catch {
            exportError = (error as? ZoteroAPIError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Resolves the collection's export documents for the Zotero send, handling both
    /// the smart (saved-search) and static collection paths.
    private func resolvedZoteroDocuments() async throws -> [CollectionExportDocument] {
        if let searchId = collection.savedSearchId {
            guard let searchService = appState.searchService else {
                throw ZoteroAPIError.network(String(localized: "export.smart.noSearchService",
                                                    defaultValue: "Search service unavailable."))
            }
            let descriptor = FetchDescriptor<SavedSearch>(predicate: #Predicate { $0.id == searchId })
            guard let savedSearch = try? modelContext.fetch(descriptor).first else { return [] }
            // Full result set, not the 20-item default page (see runExport).
            let results = try await searchService.search(
                parameters: savedSearch.searchParameters,
                limit: SearchViewModel.searchHardLimit
            )
            let smart = results.enumerated().map {
                SmartEntry(documentId: $0.element.documentId, volumeId: $0.element.volumeId, sortOrder: $0.offset)
            }
            return await resolveSmartDocuments(smart)
        }
        await prepareVolumes()
        return try await resolveDocuments()
    }

    /// Localised body for the Zotero result alert.
    private func zoteroResultMessage(_ result: ZoteroSendResult) -> String {
        var line = String(format: String(localized: "export.zotero.result %lld %lld",
                                          defaultValue: "Added %lld documents and %lld notes to Zotero."),
                          Int64(result.addedItems), Int64(result.addedNotes))
        if result.failedItems > 0 {
            line += " " + String(format: String(localized: "export.zotero.result.failed %lld",
                                                defaultValue: "%lld failed."),
                                 Int64(result.failedItems))
        }
        return line
    }

    /// Downloads and indexes any volumes referenced by the collection that are not yet
    /// available locally. Updates `preparingMessage` to give the user live feedback.
    private func prepareVolumes() async {
        guard let dm = appState.downloadManager,
              let pipeline = appState.indexingPipeline else { return }

        let manifest = appState.manifestStore.diffResult?.known
            ?? appState.manifestStore.bundledEntries
        let neededVolumeIds = Set(entries.map(\.volumeId))

        // Classify each needed volume.
        var toDownload: [(volumeId: String, downloadUrl: String)] = []
        var toIndex: [String] = []
        for vid in neededVolumeIds {
            if !dm.isVolumeDownloaded(vid) {
                if let entry = manifest.first(where: { $0.volumeId == vid }) {
                    toDownload.append((vid, entry.downloadUrl))
                }
            } else if (try? !pipeline.isVolumeIndexed(vid)) == true {
                toIndex.append(vid)
            }
        }

        guard !toDownload.isEmpty || !toIndex.isEmpty else { return }

        let totalNeeded = toDownload.count + toIndex.count
        preparingMessage = String(
            localized: "export.preparing.volumes",
            defaultValue: "Preparing \(totalNeeded) volume\(totalNeeded == 1 ? "" : "s")…"
        )

        // Kick off indexing for downloaded-but-unindexed volumes.
        for vid in toIndex {
            Task { try? await pipeline.indexVolume(vid) }
        }
        // Enqueue downloads; indexing follows automatically via onVolumeDownloaded.
        for (vid, url) in toDownload {
            await dm.enqueueDownload(volumeId: vid, downloadUrl: url)
        }

        // Poll until every needed volume is indexed (or we time out after ~5 min).
        let waitSet = Set(toDownload.map(\.volumeId) + toIndex)
        var remaining = waitSet
        var elapsedMs = 0
        let pollInterval = 1_000_000_000   // 1 second in nanoseconds
        let timeoutMs   = 300_000          // 5 minutes

        while !remaining.isEmpty && elapsedMs < timeoutMs {
            try? await Task.sleep(nanoseconds: UInt64(pollInterval))
            elapsedMs += 1_000
            remaining = remaining.filter { vid in
                (try? !pipeline.isVolumeIndexed(vid)) != false
            }
            let ready = waitSet.count - remaining.count
            let total = waitSet.count
            preparingMessage = String(
                localized: "export.preparing.progress",
                defaultValue: "Preparing volumes: \(ready) of \(total) ready…"
            )
        }

        preparingMessage = nil
    }

    /// Documents-only view of the resolved items — for callers that need a flat document
    /// list (e.g. the Zotero Web-API send path). Headings and prose are dropped.
    private func resolveDocuments() async throws -> [CollectionExportDocument] {
        try await resolveItems().documents
    }

    /// Resolves the collection's ordered entries into export items: each document entry is
    /// fully resolved into a `.document`; heading/prose entries pass through as `.heading` /
    /// `.prose`, so the exported product preserves the authored structure (Phase 3a).
    private func resolveItems() async throws -> [CollectionExportItem] {
        let opts    = buildExportOptions()
        let manifest = appState.manifestStore.diffResult?.known
            ?? appState.manifestStore.bundledEntries
        let manifestMap = Dictionary(uniqueKeysWithValues: manifest.map { ($0.volumeId, $0) })
        let formatter = HistoryAtStateCitationFormatter()

        // Pre-load body texts: SQLite cache (fast) then XML fallback (slow).
        // Group by volume so each volume XML is opened at most once on the fallback path.
        var bodyTexts: [String: String] = [:]

        let volumeIds = Set(entries.map(\.volumeId))
        for volumeId in volumeIds {
            let docsInVolume = entries.filter { $0.volumeId == volumeId }

            // SQLite cache path
            if let pipeline = appState.indexingPipeline {
                for entry in docsInVolume {
                    let key = "\(entry.volumeId)/\(entry.documentId)"
                    if let text = try? await pipeline.fetchDocumentBodyText(
                        volumeId: entry.volumeId, documentId: entry.documentId) {
                        bodyTexts[key] = text
                    }
                }
            }

            // XML fallback for anything still uncached
            let uncached = docsInVolume.filter {
                bodyTexts["\($0.volumeId)/\($0.documentId)"] == nil
            }
            if !uncached.isEmpty, let dm = appState.downloadManager {
                let volumeURL = dm.volumeURL(for: volumeId)
                if FileManager.default.fileExists(atPath: volumeURL.path) {
                    let parser = FRUSDocumentParser()
                    for entry in uncached {
                        let key = "\(entry.volumeId)/\(entry.documentId)"
                        if let ast = try? await parser.parseDocument(
                            documentId: entry.documentId, volumeURL: volumeURL) {
                            bodyTexts[key] = IndexingPipeline.extractBodyText(from: ast.nodes)
                        }
                    }
                }
            }
        }

        // Render models: parse each volume XML to obtain structured render output.
        // One parse per document — acceptable cost for a user-initiated export.
        // Falls back gracefully (nil) when the volume file is unavailable.
        var renderModels: [String: FRUSDocumentRenderModel] = [:]
        for volumeId in volumeIds {
            guard let dm = appState.downloadManager else { continue }
            let volumeURL = dm.volumeURL(for: volumeId)
            guard FileManager.default.fileExists(atPath: volumeURL.path) else { continue }
            let docsInVolume = entries.filter { $0.volumeId == volumeId }
            for entry in docsInVolume {
                let key = "\(entry.volumeId)/\(entry.documentId)"
                if let ast = try? await FRUSDocumentParser().parseDocument(
                    documentId: entry.documentId, volumeURL: volumeURL) {
                    var converter = ASTToRenderNodeConverter()
                    renderModels[key] = converter.convert(ast)
                }
            }
        }

        // Editorial-note flags from the index, so collection-level Zotero items
        // carry the same "Editorial note" extra line as document-level exports.
        let editorialNoteFlags = await ZoteroJSONExporter.editorialNoteFlags(
            volumeIds: volumeIds, pipeline: appState.indexingPipeline)

        var items: [CollectionExportItem] = []
        // A heading may carry a `bodyDepthOverride` that acts as the section default for the
        // documents following it, until the next heading (Phase 3c). Tracked across the pass.
        var currentSectionDepth: String? = nil
        for entry in entries.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            // Heading / prose entries pass straight through as structural items.
            switch entry.entryKind {
            case .heading:
                currentSectionDepth = entry.bodyDepthOverride
                items.append(.heading(entry.text ?? ""))
                continue
            case .prose:
                items.append(.prose(ProseRichText.exportRTF(from: entry)))
                continue
            case .document:
                break
            }
            let manifestEntry = manifestMap[entry.volumeId]
            let volMeta = manifestEntry.map { FRUSVolumeMetadata($0) }
            let key = "\(entry.volumeId)/\(entry.documentId)"
            let renderModel = renderModels[key]

            // Extract header and dateline from the render model when available.
            let (header, dateline) = renderModelHeadAndDateline(renderModel)

            let docNum: String? = entry.documentId.hasPrefix("d")
                ? Int(entry.documentId.dropFirst()).map { String($0) }
                : nil
            let docMeta = FRUSDocumentMetadata(
                documentId: entry.documentId, documentNumber: docNum,
                header: header, dateline: dateline)
            let citation = volMeta.map { formatter.format(document: docMeta, volume: $0) }
                ?? "\(entry.volumeId)/\(entry.documentId)"
            let urlString = "https://history.state.gov/historicaldocuments/\(entry.volumeId)/\(entry.documentId)"
            let volumeTitle = manifestEntry?.title ?? entry.volumeId
            let bodyText = bodyTexts[key] ?? ""

            // Resolve note texts: selectedNoteIds takes precedence over legacy researchNoteId.
            let resolvedNoteTexts: [String]
            if !entry.selectedNoteIds.isEmpty {
                resolvedNoteTexts = entry.selectedNoteIds.compactMap { nid in
                    allNotes.first { $0.id == nid }?.bodyText
                }.filter { !$0.isEmpty }
            } else if let legacyNote = entry.researchNoteId.flatMap({ nid in allNotes.first { $0.id == nid } }) {
                resolvedNoteTexts = legacyNote.bodyText.isEmpty ? [] : [legacyNote.bodyText]
            } else {
                resolvedNoteTexts = []
            }

            // Effective body depth cascade (Phase 3c): the entry's own override, else the
            // section override (nearest preceding heading), else the collection default.
            // Drives per-document rendering and gates inline highlights.
            let effectiveDepth = CollectionBodyDepth.resolve(
                entryOverride: entry.bodyDepthOverride,
                sectionOverride: currentSectionDepth,
                collectionDefault: collection.defaultBodyDepth)

            // Highlights (when applyHighlights and body is full)
            let resolvedHighlights: [ExportHighlight]
            if opts.applyHighlights && effectiveDepth == .full {
                let allHL = (try? modelContext.fetch(FetchDescriptor<DocumentHighlight>())) ?? []
                resolvedHighlights = allHL
                    .filter { $0.volumeId == entry.volumeId && $0.documentId == entry.documentId }
                    .map { ExportHighlight(startOffset: $0.startOffset,
                                          endOffset:   $0.endOffset,
                                          color:       $0.color) }
            } else {
                resolvedHighlights = []
            }

            // Source note (footnoteStyle == .sourceNoteOnly)
            let resolvedSourceNote: String?
            if opts.footnoteStyle == .sourceNoteOnly {
                resolvedSourceNote = try? await appState.indexingPipeline?
                    .fetchDocumentSourceNote(volumeId: entry.volumeId,
                                             documentId: entry.documentId)
            } else {
                resolvedSourceNote = nil
            }

            // Zotero JSON item (for ExportFormat.zoteroJSON)
            let zoteroItem: ZoteroJSONExporter.Item?
            if let volMeta {
                let year = FRUSVolumeMetadata.firstYear(in: volMeta.publicationDate).map(String.init) ?? "n.d."
                let (tags, _) = ZoteroJSONExporter.fetchTagsAndNotes(
                    documentId: entry.documentId, volumeId: entry.volumeId, context: modelContext)
                zoteroItem = ZoteroJSONExporter.makeItem(
                    document: docMeta,
                    volume: volMeta,
                    year: year,
                    url: urlString,
                    isEditorialNote: editorialNoteFlags[key] ?? false,
                    tags: tags,
                    notes: resolvedNoteTexts
                )
            } else {
                zoteroItem = nil
            }

            items.append(.document(CollectionExportDocument(
                documentId: entry.documentId,
                volumeId: entry.volumeId,
                sortOrder: entry.sortOrder,
                bodyDepth: effectiveDepth,
                title: "\(volumeTitle) — \(entry.documentId)",
                date: manifestEntry?.dateRange.earliest,
                bodyText: bodyText,
                noteTexts: resolvedNoteTexts,
                citation: citation,
                historyStateGovURL: urlString,
                renderModel: renderModel,
                header: header,
                dateline: dateline,
                highlights: resolvedHighlights,
                sourceNoteText: resolvedSourceNote,
                zoteroItem: zoteroItem
            )))
        }
        return items
    }

    /// Generates or fetches summaries for all entries when bodyDepth == .summaryOnly.
    /// Returns a [key: summaryText] map. Throws if any generation fails.
    private func resolveSummaries(
        for docs: [CollectionExportDocument],
        promptId: UUID,
        bodyTexts: [String: String]
    ) async throws -> [String: String] {
        guard AppleIntelligenceProvider.shared.isAvailable else {
            throw ExportError.renderingFailed
        }
        guard let service = appState.summarizationService else {
            throw ExportError.renderingFailed
        }
        guard let prompt = (try? modelContext.fetch(
            FetchDescriptor<SummarizationPrompt>(
                predicate: #Predicate { $0.id == promptId }
            )))?.first else {
            throw ExportError.renderingFailed
        }
        let snapshot = SummarizationPromptSnapshot(from: prompt)

        var result: [String: String] = [:]
        let total = docs.count

        for (i, doc) in docs.enumerated() {
            let key = "\(doc.volumeId)/\(doc.documentId)"
            await MainActor.run {
                summaryGeneratingMessage = String(
                    localized: "export.summaryProgress",
                    defaultValue: "Generating summaries (\(i + 1) of \(total))…")
            }

            // Check for existing summary first (capture scalars — #Predicate can't use struct fields).
            let vid = doc.volumeId
            let did = doc.documentId
            let pid = promptId
            let existingDesc = FetchDescriptor<GeneratedSummary>(
                predicate: #Predicate<GeneratedSummary> { s in
                    s.volumeId == vid && s.documentId == did && s.promptId == pid
                }
            )
            if let existing = try? modelContext.fetch(existingDesc).first,
               !existing.responseText.isEmpty {
                result[key] = existing.responseText
                continue
            }

            // Generate on demand.
            let text = bodyTexts[key] ?? doc.bodyText
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ExportError.renderingFailed
            }
            let generated = try await service.summarize(
                documentId:    doc.documentId,
                volumeId:      doc.volumeId,
                documentText:  text,
                prompt:        snapshot,
                provider:      AppleIntelligenceProvider.shared,
                activeProjectId: appState.activeProjectId
            )
            result[key] = generated.responseText
        }
        await MainActor.run { summaryGeneratingMessage = nil }
        return result
    }

    // MARK: - Render Model Extraction Helpers

    /// Extracts the first heading and first dateline from a render model's body nodes.
    private func renderModelHeadAndDateline(_ model: FRUSDocumentRenderModel?) -> (header: String, dateline: String?) {
        guard let model else { return ("", nil) }
        var header = ""
        var dateline: String? = nil
        for node in model.bodyNodes {
            if case .heading(let c) = node, header.isEmpty {
                header = renderNodePlainText(c).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if case .dateline(let c) = node, dateline == nil {
                let text = renderNodePlainText(c).trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { dateline = text }
            }
            if !header.isEmpty && dateline != nil { break }
        }
        return (header, dateline)
    }

    /// Recursively extracts plain text from an array of `FRUSRenderNode` values.
    private func renderNodePlainText(_ nodes: [FRUSRenderNode]) -> String {
        nodes.map { renderNodePlainText($0) }.joined()
    }

    /// Recursively extracts plain text from a single `FRUSRenderNode`.
    private func renderNodePlainText(_ node: FRUSRenderNode) -> String {
        switch node {
        case .plainText(let s):
            return s
        case .boldText(let c), .italicText(let c), .smallCapsText(let c),
             .underlineText(let c), .termText(let c), .corrText(let c),
             .suppliedText(let c), .sicText(let c):
            return renderNodePlainText(c)
        case .heading(let c), .dateline(let c), .salutation(let c),
             .paragraph(let c), .attachmentHeading(let c):
            return renderNodePlainText(c)
        case .letterOpener(let c), .letterCloser(let c),
             .editorialNoteBlock(let c), .titlePageBlock(let c):
            return renderNodePlainText(c)
        case .attachmentBlock(_, let c), .unknown(_, let c):
            return renderNodePlainText(c)
        case .persNameLink(_, let c, _), .glossLink(_, let c, _),
             .crossRefLink(_, _, let c):
            return renderNodePlainText(c)
        case .formulaText(let s):
            return s
        case .lineBreak:
            return " "
        case .footnoteMarker(_, let label):
            return "[\(label)]"
        case .listBlock(_, let items):
            return items.map { renderNodePlainText($0) }.joined(separator: " ")
        case .tableBlock(let rows):
            return rows.map { row in row.map { renderNodePlainText($0.children) }.joined(separator: " | ") }.joined(separator: "\n")
        case .footnoteBody, .pageBreak, .figureBlock:
            return ""
        }
    }

    // MARK: - Smart Document Resolution

    /// Resolves documents from a smart collection using pre-fetched search result entries.
    /// Unlike `resolveDocuments()`, this path has no `prepareVolumes` phase — search results
    /// are already indexed — and produces no `noteText` since smart entries carry no research note links.
    private func resolveSmartDocuments(_ smartEntries: [SmartEntry]) async -> [CollectionExportDocument] {
        let manifest = appState.manifestStore.diffResult?.known
            ?? appState.manifestStore.bundledEntries
        let manifestMap = Dictionary(uniqueKeysWithValues: manifest.map { ($0.volumeId, $0) })
        let formatter = HistoryAtStateCitationFormatter()

        var bodyTexts: [String: String] = [:]
        let volumeIds = Set(smartEntries.map(\.volumeId))

        for volumeId in volumeIds {
            let docsInVolume = smartEntries.filter { $0.volumeId == volumeId }

            if let pipeline = appState.indexingPipeline {
                for entry in docsInVolume {
                    let key = "\(entry.volumeId)/\(entry.documentId)"
                    if let text = try? await pipeline.fetchDocumentBodyText(
                        volumeId: entry.volumeId, documentId: entry.documentId) {
                        bodyTexts[key] = text
                    }
                }
            }

            let uncached = docsInVolume.filter { bodyTexts["\($0.volumeId)/\($0.documentId)"] == nil }
            if !uncached.isEmpty, let dm = appState.downloadManager {
                let volumeURL = dm.volumeURL(for: volumeId)
                if FileManager.default.fileExists(atPath: volumeURL.path) {
                    let parser = FRUSDocumentParser()
                    for entry in uncached {
                        let key = "\(entry.volumeId)/\(entry.documentId)"
                        if let ast = try? await parser.parseDocument(
                            documentId: entry.documentId, volumeURL: volumeURL) {
                            bodyTexts[key] = IndexingPipeline.extractBodyText(from: ast.nodes)
                        }
                    }
                }
            }
        }

        var renderModels: [String: FRUSDocumentRenderModel] = [:]
        for volumeId in volumeIds {
            guard let dm = appState.downloadManager else { continue }
            let volumeURL = dm.volumeURL(for: volumeId)
            guard FileManager.default.fileExists(atPath: volumeURL.path) else { continue }
            let docsInVolume = smartEntries.filter { $0.volumeId == volumeId }
            for entry in docsInVolume {
                let key = "\(entry.volumeId)/\(entry.documentId)"
                if let ast = try? await FRUSDocumentParser().parseDocument(
                    documentId: entry.documentId, volumeURL: volumeURL) {
                    var converter = ASTToRenderNodeConverter()
                    renderModels[key] = converter.convert(ast)
                }
            }
        }

        // Editorial-note flags from the index, so collection-level Zotero items
        // carry the same "Editorial note" extra line as document-level exports.
        let editorialNoteFlags = await ZoteroJSONExporter.editorialNoteFlags(
            volumeIds: volumeIds, pipeline: appState.indexingPipeline)

        return smartEntries.sorted { $0.sortOrder < $1.sortOrder }.map { entry in
            let manifestEntry = manifestMap[entry.volumeId]
            let volMeta = manifestEntry.map { FRUSVolumeMetadata($0) }
            let key = "\(entry.volumeId)/\(entry.documentId)"
            let renderModel = renderModels[key]

            let (header, dateline) = renderModelHeadAndDateline(renderModel)

            let docNum: String? = entry.documentId.hasPrefix("d")
                ? Int(entry.documentId.dropFirst()).map { String($0) }
                : nil
            let docMeta = FRUSDocumentMetadata(
                documentId: entry.documentId, documentNumber: docNum,
                header: header, dateline: dateline)
            let citation = volMeta.map { formatter.format(document: docMeta, volume: $0) }
                ?? "\(entry.volumeId)/\(entry.documentId)"
            let urlString = "https://history.state.gov/historicaldocuments/\(entry.volumeId)/\(entry.documentId)"
            let volumeTitle = manifestEntry?.title ?? entry.volumeId
            let bodyText = bodyTexts[key] ?? ""

            let zoteroItem: ZoteroJSONExporter.Item?
            if let volMeta {
                let year = FRUSVolumeMetadata.firstYear(in: volMeta.publicationDate).map(String.init) ?? "n.d."
                let (tags, notes) = ZoteroJSONExporter.fetchTagsAndNotes(
                    documentId: entry.documentId, volumeId: entry.volumeId, context: modelContext)
                zoteroItem = ZoteroJSONExporter.makeItem(
                    document: docMeta,
                    volume: volMeta,
                    year: year,
                    url: urlString,
                    isEditorialNote: editorialNoteFlags[key] ?? false,
                    tags: tags,
                    notes: notes
                )
            } else {
                zoteroItem = nil
            }

            return CollectionExportDocument(
                documentId: entry.documentId,
                volumeId: entry.volumeId,
                sortOrder: entry.sortOrder,
                bodyDepth: CollectionBodyDepth(rawValue: collection.defaultBodyDepth) ?? .full,
                title: "\(volumeTitle) — \(entry.documentId)",
                date: manifestEntry?.dateRange.earliest,
                bodyText: bodyText,
                citation: citation,
                historyStateGovURL: urlString,
                renderModel: renderModel,
                header: header,
                dateline: dateline,
                zoteroItem: zoteroItem
            )
        }
    }
}

// MARK: - MacExportCompleteView

#if os(macOS)
/// Shown after a successful export on macOS.
///
/// Offers two actions:
/// - **Reveal in Finder** — opens the file's containing folder with the file selected.
/// - **Save To…** — presents an `NSSavePanel` so the user can copy the exported file
///   to a permanent location of their choice.
///
/// The file lives in `FileManager.temporaryDirectory` and will be cleaned up by
/// the OS; using the Save panel is the recommended path for keeping the output.
struct MacExportCompleteView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Success content
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)

                Text(String(localized: "export.mac.success.title",
                            defaultValue: "Export Complete"))
                    .font(.headline)

                Text(url.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 20)

            Divider()

            // Button bar — Done (left, Escape), Reveal in Finder (secondary),
            // Save To… (primary, Return). Standard macOS success dialog layout.
            HStack(spacing: 8) {
                Button(String(localized: "export.mac.done",
                              defaultValue: "Done")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(String(localized: "export.mac.reveal",
                              defaultValue: "Reveal in Finder")) {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                    dismiss()
                }

                Button(String(localized: "export.mac.saveTo",
                              defaultValue: "Save To\u{2026}")) {
                    let panel = NSSavePanel()
                    panel.nameFieldStringValue = url.lastPathComponent
                    panel.canCreateDirectories = true
                    if panel.runModal() == .OK, let dest = panel.url {
                        try? FileManager.default.removeItem(at: dest)
                        try? FileManager.default.copyItem(at: url, to: dest)
                        NSWorkspace.shared.activateFileViewerSelecting([dest])
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 340)
    }
}
#endif

// MARK: - ShareSheet

#if os(iOS)
/// Thin wrapper around the iOS share sheet.
private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

// MARK: - URL: Identifiable

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

// MARK: - Zotero result alert

/// Presents the outcome of a "Send to Zotero Library" run, with an optional
/// "View in Zotero" link. Shared by the export sheet's macOS and iOS bodies.
private struct ZoteroResultAlertModifier: ViewModifier {
    @Binding var result: ZoteroSendResult?
    let message: (ZoteroSendResult) -> String
    let openURL: OpenURLAction

    func body(content: Content) -> some View {
        content.alert(
            String(localized: "export.zotero.result.title", defaultValue: "Sent to Zotero"),
            isPresented: Binding(get: { result != nil }, set: { if !$0 { result = nil } }),
            presenting: result
        ) { result in
            if let url = result.webURL {
                Button(String(localized: "export.zotero.viewInZotero",
                              defaultValue: "View in Zotero")) { openURL(url) }
            }
            Button(String(localized: "common.ok", defaultValue: "OK"), role: .cancel) {}
        } message: { result in
            Text(message(result))
        }
    }
}

extension View {
    /// Attaches the Zotero "Sent to Zotero" result alert.
    func zoteroResultAlert(
        result: Binding<ZoteroSendResult?>,
        message: @escaping (ZoteroSendResult) -> String,
        openURL: OpenURLAction
    ) -> some View {
        modifier(ZoteroResultAlertModifier(result: result, message: message, openURL: openURL))
    }
}
