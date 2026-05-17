// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - SettingsView

/// Root Settings screen.
///
/// ## Layout
/// `Form` inside a `NavigationStack`. Each panel is a `NavigationLink` to a dedicated
/// sub-view. Panels are grouped into functional sections matching the specification.
///
/// ## Panels
/// | Panel | Sub-view |
/// |---|---|
/// | Volume management | `VolumeManagementView` |
/// | Storage management | `StorageManagementView` |
/// | Sideload | `SideloadView` |
/// | Reindex | `ReindexView` |
/// | User tags | `UserTagsView` |
/// | Summarization prompts | `SummarizationPromptsSettingsView` |
/// | NARA API key | `NARAKeyView` |
/// | Reset | `ResetView` |
///
/// ## Log prefix
/// `[Settings]`
///
/// Version history:
///   1.0 — Session 24: initial implementation
///   1.1 — Session 26: add About row
///   1.2 — Session 35: fix macOS blank NavigationLink destinations via frame expansion
///   1.3 — Session 44: Done button and dismiss guarded to non-iOS (Settings is a tab on iOS)
///   1.4 — Session 49: Download Manager row added to Volumes section
///   1.5 — Session 50: About row removed from iOS SettingsView (now in macOS App menu)
struct SettingsView: View {

    #if !os(iOS)
    @Environment(\.dismiss) private var dismiss
    #endif

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "settings.section.volumes",
                               defaultValue: "Volumes")) {
                    NavigationLink(String(localized: "settings.row.downloadManager",
                                         defaultValue: "Download Manager")) {
                        DownloadManagerSettingsView()
                    }
                    NavigationLink(String(localized: "settings.row.volumeManagement",
                                         defaultValue: "Volume Management")) {
                        VolumeManagementView()
                    }
                    NavigationLink(String(localized: "settings.row.storage",
                                         defaultValue: "Storage")) {
                        StorageManagementView()
                    }
                    NavigationLink(String(localized: "settings.row.sideload",
                                         defaultValue: "Sideload Volume")) {
                        SideloadView()
                    }
                    NavigationLink(String(localized: "settings.row.reindex",
                                         defaultValue: "Reindex")) {
                        ReindexView()
                    }
                }

                Section(String(localized: "settings.section.research",
                               defaultValue: "Research")) {
                    NavigationLink(String(localized: "settings.row.tags",
                                         defaultValue: "User Tags")) {
                        UserTagsView()
                    }
                    NavigationLink(String(localized: "settings.row.summarization",
                                         defaultValue: "Summarization Prompts")) {
                        SummarizationPromptsSettingsView()
                    }
                }

                Section(String(localized: "settings.section.integrations",
                               defaultValue: "Integrations")) {
                    NavigationLink(String(localized: "settings.row.naraKey",
                                         defaultValue: "NARA Catalog API Key")) {
                        NARAKeyView()
                    }
                }

                Section {
                    NavigationLink(String(localized: "settings.row.reset",
                                         defaultValue: "Reset App")) {
                        ResetView()
                    }
                    .foregroundStyle(.red)
                }

                #if os(iOS)
                Section {
                    NavigationLink(String(localized: "settings.row.about",
                                         defaultValue: "About FRUS Explorer")) {
                        AboutView()
                    }
                }
                #endif
            }
            .navigationTitle(String(localized: "settings.title", defaultValue: "Settings"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if !os(iOS)
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "settings.done", defaultValue: "Done")) {
                        dismiss()
                    }
                }
                #endif
            }
        }
        #if os(macOS)
        // Provides stable minimum dimensions for the settings sheet on macOS so that
        // NavigationLink destinations inherit a proper sized container and render correctly.
        .frame(minWidth: 500, minHeight: 440)
        #endif
    }
}

// MARK: - VolumeManagementView

private struct VolumeManagementView: View {

    @Environment(AppState.self) private var appState

    @State private var concurrentDownloadLimit: Int = {
        let stored = UserDefaults.standard.integer(forKey: SettingsKeys.concurrentDownloadLimit)
        return stored > 0 ? stored : 4
    }()

    var body: some View {
        Form {
            Section(String(localized: "settings.volumes.downloads.header",
                           defaultValue: "Download Settings")) {
                Picker(
                    String(localized: "settings.volumes.concurrentLimit.label",
                           defaultValue: "Concurrent Downloads"),
                    selection: $concurrentDownloadLimit
                ) {
                    ForEach([1, 2, 3, 4, 6], id: \.self) { n in
                        Text("\(n)").tag(n)
                    }
                }
                .onChange(of: concurrentDownloadLimit) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: SettingsKeys.concurrentDownloadLimit)
                    #if DEBUG
                    print("[Settings] Concurrent download limit set to \(newValue) (takes effect on next launch)")
                    #endif
                }
                .accessibilityLabel(
                    String(localized: "settings.volumes.concurrentLimit.a11y",
                           defaultValue: "Concurrent download limit")
                )

                Text(String(localized: "settings.volumes.concurrentLimit.note",
                            defaultValue: "Takes effect on next launch."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(String(localized: "settings.volumes.active.header",
                           defaultValue: "Active Downloads")) {
                activeDownloadsSection
            }

            Section(String(localized: "settings.volumes.downloaded.header",
                           defaultValue: "Downloaded Volumes")) {
                downloadedVolumesSection
            }

            Section(String(localized: "settings.volumes.available.header",
                           defaultValue: "Available Volumes")) {
                availableVolumesSection
            }

            Section {
                Button {
                    Task { await appState.manifestStore.fetchLiveManifest() }
                } label: {
                    Label(
                        String(localized: "settings.volumes.checkNew.button",
                               defaultValue: "Check for New Volumes"),
                        systemImage: "arrow.clockwise"
                    )
                }
                .accessibilityLabel(
                    String(localized: "settings.volumes.checkNew.a11y",
                           defaultValue: "Check for new FRUS volumes")
                )
            }
        }
        .navigationTitle(String(localized: "settings.volumes.title",
                                defaultValue: "Volume Management"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
    }

    @ViewBuilder
    private var activeDownloadsSection: some View {
        let queue = appState.downloadQueue
        if queue.isEmpty {
            Text(String(localized: "settings.volumes.active.empty",
                        defaultValue: "No active downloads."))
                .foregroundStyle(.secondary)
                .font(.callout)
        } else {
            ForEach(queue, id: \.self) { volumeId in
                HStack {
                    Text(volumeId)
                        .font(.callout)
                    Spacer()
                    Button(String(localized: "settings.volumes.active.cancel",
                                  defaultValue: "Cancel")) {
                        Task {
                            await appState.downloadManager?.cancelDownload(volumeId: volumeId)
                        }
                    }
                    .font(.callout)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                    .accessibilityLabel(
                        String(localized: "settings.volumes.active.cancel.a11y",
                               defaultValue: "Cancel download for \(volumeId)")
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var downloadedVolumesSection: some View {
        let downloaded = downloadedVolumes
        if downloaded.isEmpty {
            Text(String(localized: "settings.volumes.downloaded.empty",
                        defaultValue: "No downloaded volumes."))
                .foregroundStyle(.secondary)
                .font(.callout)
        } else {
            ForEach(downloaded) { entry in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.title)
                            .font(.callout)
                            .lineLimit(1)
                        Text(entry.volumeId)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(String(localized: "settings.volumes.downloaded.delete",
                                  defaultValue: "Delete")) {
                        Task { try? await appState.downloadManager?.deleteVolume(volumeId: entry.volumeId) }
                    }
                    .font(.callout)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                    .accessibilityLabel(
                        String(localized: "settings.volumes.downloaded.delete.a11y",
                               defaultValue: "Delete \(entry.title)")
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var availableVolumesSection: some View {
        let notDownloaded = notDownloadedVolumes
        if notDownloaded.isEmpty {
            Text(String(localized: "settings.volumes.available.empty",
                        defaultValue: "All known volumes are downloaded."))
                .foregroundStyle(.secondary)
                .font(.callout)
        } else {
            ForEach(notDownloaded) { entry in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.title)
                            .font(.callout)
                            .lineLimit(1)
                        Text(formattedBytes(entry.sizeBytes))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(String(localized: "settings.volumes.available.download",
                                  defaultValue: "Download")) {
                        let url = "https://raw.githubusercontent.com/HistoryAtState/frus/master/volumes/\(entry.filename)"
                        Task {
                            await appState.downloadManager?.enqueueDownload(
                                volumeId: entry.volumeId,
                                downloadUrl: url)
                        }
                    }
                    .font(.callout)
                    .buttonStyle(.borderless)
                    .accessibilityLabel(
                        String(localized: "settings.volumes.available.download.a11y",
                               defaultValue: "Download \(entry.title)")
                    )
                }
            }
        }
    }

    private var downloadedVolumes: [VolumeManifestEntry] {
        guard let dm = appState.downloadManager else { return [] }
        let all = appState.manifestStore.diffResult?.known ?? appState.manifestStore.bundledEntries
        return all.filter { dm.isVolumeDownloaded($0.volumeId) }
    }

    private var notDownloadedVolumes: [VolumeManifestEntry] {
        guard let dm = appState.downloadManager else { return [] }
        let all = appState.manifestStore.diffResult?.known ?? appState.manifestStore.bundledEntries
        return all.filter { !dm.isVolumeDownloaded($0.volumeId) }
    }
}

// MARK: - StorageManagementView

private struct StorageManagementView: View {

    @Environment(AppState.self) private var appState
    @State private var report: StorageReport? = nil
    @State private var loadError: String? = nil

    var body: some View {
        Form {
            Section(String(localized: "settings.storage.aggregate.header",
                           defaultValue: "Total Storage Used")) {
                if let report {
                    LabeledContent(
                        String(localized: "settings.storage.volumes.label",
                               defaultValue: "Volume XML Files"),
                        value: formattedBytes(report.totalVolumesBytes)
                    )
                    LabeledContent(
                        String(localized: "settings.storage.index.label",
                               defaultValue: "Search Index"),
                        value: formattedBytes(report.totalIndexBytes)
                    )
                    LabeledContent(
                        String(localized: "settings.storage.summaries.label",
                               defaultValue: "AI Summaries"),
                        value: formattedBytes(report.totalSummariesBytes)
                    )
                    LabeledContent(
                        String(localized: "settings.storage.total.label",
                               defaultValue: "Grand Total"),
                        value: formattedBytes(report.grandTotalBytes)
                    )
                    .bold()
                } else if let error = loadError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.callout)
                } else {
                    ProgressView()
                }
            }

            if let report, !report.perVolume.isEmpty {
                Section(String(localized: "settings.storage.perVolume.header",
                               defaultValue: "Per-Volume Storage")) {
                    ForEach(report.perVolume, id: \.volumeId) { entry in
                        let manifestEntry = appState.manifestStore.diffResult?.known
                            .first { $0.volumeId == entry.volumeId }
                            ?? appState.manifestStore.bundledEntries
                            .first { $0.volumeId == entry.volumeId }
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(manifestEntry?.title ?? entry.volumeId)
                                    .font(.callout)
                                    .lineLimit(1)
                                Text(entry.volumeId)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(formattedBytes(entry.volumeFileBytes))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                Text(String(localized: "settings.storage.backup.note",
                            defaultValue: "Downloaded volume XML files are excluded from iCloud Backup to avoid redundant uploads. Files are re-downloadable at any time."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(String(localized: "settings.storage.title",
                                defaultValue: "Storage"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
        .task {
            do {
                report = try await appState.downloadManager?.storageReport()
            } catch {
                loadError = error.localizedDescription
            }
        }
    }
}

// MARK: - SideloadError

/// Errors from `SideloadValidator`.
///
/// Version history:
///   1.0 — Session 24: initial implementation
enum SideloadError: LocalizedError {
    case notXML
    case notFRUSVolume(reason: String)
    case duplicateVolume(volumeId: String)
    case copyFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .notXML:
            return String(localized: "sideload.error.notXML",
                          defaultValue: "The selected file is not valid XML.")
        case .notFRUSVolume(let reason):
            return String(localized: "sideload.error.notFRUS",
                          defaultValue: "This XML file does not appear to be a FRUS volume: \(reason)")
        case .duplicateVolume(let id):
            return String(localized: "sideload.error.duplicate",
                          defaultValue: "Volume '\(id)' is already present. Delete it first to replace it.")
        case .copyFailed(let error):
            return String(localized: "sideload.error.copy",
                          defaultValue: "Could not import the file: \(error.localizedDescription)")
        }
    }
}

// MARK: - SideloadValidator

/// Validates and imports a sideloaded FRUS volume XML file.
///
/// Validation checks:
/// 1. File is parseable as XML.
/// 2. Root element looks like a FRUS TEI volume (root named `volume` or `TEI`/`tei`,
///    or has a `volumeId` / `xml:id` attribute).
/// 3. VolumeId (derived from filename) does not already exist on disk.
///
/// Version history:
///   1.0 — Session 24: initial implementation
struct SideloadValidator {

    /// Validates the file at `url` and imports it to `volumesDirectory` if valid.
    ///
    /// - Returns: The `volumeId` of the imported volume.
    /// - Throws: `SideloadError` describing the failure.
    func validate(url: URL, volumesDirectory: URL) throws -> String {
        let volumeId = url.deletingPathExtension().lastPathComponent

        // 1. Check root element via a quick XML parse
        guard let xmlParser = XMLParser(contentsOf: url) else {
            throw SideloadError.notXML
        }
        let rootDelegate = RootElementSnifferDelegate()
        xmlParser.delegate = rootDelegate
        xmlParser.parse()

        // An XML parse error (before finding root) means invalid XML
        if !rootDelegate.rootElementFound, xmlParser.parserError != nil {
            throw SideloadError.notXML
        }

        guard rootDelegate.rootElementFound else {
            throw SideloadError.notFRUSVolume(reason: String(
                localized: "sideload.error.noRoot", defaultValue: "No root element found."))
        }

        guard rootDelegate.looksLikeFRUS else {
            let reason = String(
                localized: "sideload.error.unexpectedRoot",
                defaultValue: "Unexpected root element '\(rootDelegate.rootElementName ?? "unknown")'.")
            throw SideloadError.notFRUSVolume(reason: reason)
        }

        // 2. Check for duplicate
        let dest = volumesDirectory.appendingPathComponent("\(volumeId).xml")
        if FileManager.default.fileExists(atPath: dest.path) {
            throw SideloadError.duplicateVolume(volumeId: volumeId)
        }

        // 3. Copy file to volumes directory
        do {
            try FileManager.default.createDirectory(
                at: volumesDirectory, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: url, to: dest)
        } catch {
            throw SideloadError.copyFailed(underlying: error)
        }

        #if DEBUG
        print("[Settings] Sideloaded volume: \(volumeId)")
        #endif

        return volumeId
    }
}

// MARK: - RootElementSnifferDelegate (internal for testing)

final class RootElementSnifferDelegate: NSObject, XMLParserDelegate {
    var rootElementFound = false
    var looksLikeFRUS = false
    var rootElementName: String? = nil
    private var hasFoundRoot = false

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes: [String: String] = [:]
    ) {
        guard !hasFoundRoot else { return }
        hasFoundRoot = true
        rootElementFound = true
        rootElementName = elementName

        let lower = elementName.lowercased()
        let knownRoots: Set<String> = ["volume", "tei", "tei:tei"]
        let hasFRUSAttribute = attributes.keys.contains("volumeId")
            || attributes.keys.contains("xml:id")
            || (attributes["xmlns"] ?? "").contains("frus")

        looksLikeFRUS = knownRoots.contains(lower) || hasFRUSAttribute

        // Stop parsing — we have what we need
        parser.abortParsing()
    }
}

// MARK: - SideloadView

private struct SideloadView: View {

    @Environment(AppState.self) private var appState

    @State private var isImporting = false
    @State private var importResult: ImportResult? = nil

    enum ImportResult {
        case success(volumeId: String)
        case failure(String)
    }

    var body: some View {
        Form {
            Section(String(localized: "settings.sideload.about.header",
                           defaultValue: "About Sideloading")) {
                Text(String(localized: "settings.sideload.about.body",
                            defaultValue: "Import a FRUS volume XML file from your device. The file will be validated and added to your library. Standard FRUS volumes are available for download from the Volume Management screen."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    isImporting = true
                } label: {
                    Label(
                        String(localized: "settings.sideload.import.button",
                               defaultValue: "Choose XML File…"),
                        systemImage: "doc.badge.plus"
                    )
                }
                .accessibilityLabel(
                    String(localized: "settings.sideload.import.a11y",
                           defaultValue: "Choose a FRUS volume XML file to import")
                )
            }

            if let result = importResult {
                Section {
                    switch result {
                    case .success(let volumeId):
                        Label(
                            String(localized: "settings.sideload.success",
                                   defaultValue: "Imported '\(volumeId)' successfully."),
                            systemImage: "checkmark.circle"
                        )
                        .foregroundStyle(.green)
                        .font(.callout)
                    case .failure(let message):
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }
            }
        }
        .navigationTitle(String(localized: "settings.sideload.title",
                                defaultValue: "Sideload Volume"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.xml],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
    }

    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importResult = .failure(error.localizedDescription)
        case .success(let urls):
            guard let url = urls.first else { return }
            guard let dm = appState.downloadManager else {
                importResult = .failure(
                    String(localized: "settings.sideload.error.noManager",
                           defaultValue: "Download manager not available."))
                return
            }
            let validator = SideloadValidator()
            do {
                let volumeId = try validator.validate(
                    url: url, volumesDirectory: dm.volumesDirectory)
                importResult = .success(volumeId: volumeId)
                // Trigger reindex of the newly sideloaded volume
                if let pipeline = appState.indexingPipeline {
                    Task {
                        let volumeURL = dm.volumeURL(for: volumeId)
                        try? await pipeline.indexVolume(volumeId)
                        _ = volumeURL
                    }
                }
            } catch {
                importResult = .failure(error.localizedDescription)
            }
        }
    }
}

// MARK: - ReindexView

private struct ReindexView: View {

    @Environment(AppState.self) private var appState

    @State private var isReindexing = false
    @State private var progressState: IndexingProgress.State = .idle
    @State private var reindexError: String? = nil

    var body: some View {
        Form {
            Section(String(localized: "settings.reindex.about.header",
                           defaultValue: "About Reindexing")) {
                Text(String(localized: "settings.reindex.about.body",
                            defaultValue: "Rebuilds the full-text search index from all downloaded volumes. Use this if search results are missing or incorrect."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    startReindex()
                } label: {
                    if isReindexing {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 4)
                            Text(progressLabel)
                                .font(.callout)
                        }
                    } else {
                        Label(
                            String(localized: "settings.reindex.start.button",
                                   defaultValue: "Reindex All Volumes"),
                            systemImage: "magnifyingglass.circle"
                        )
                    }
                }
                .disabled(isReindexing || appState.indexingPipeline == nil)
                .accessibilityLabel(
                    String(localized: "settings.reindex.start.a11y",
                           defaultValue: "Reindex all downloaded FRUS volumes")
                )

                if case .completed(let volumes, let docs) = progressState {
                    Label(
                        String(localized: "settings.reindex.done",
                               defaultValue: "Completed: \(volumes) volume\(volumes == 1 ? "" : "s"), \(docs) documents"),
                        systemImage: "checkmark.circle"
                    )
                    .foregroundStyle(.green)
                    .font(.callout)
                }

                if let error = reindexError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
        }
        .navigationTitle(String(localized: "settings.reindex.title", defaultValue: "Reindex"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
    }

    private var progressLabel: String {
        switch progressState {
        case .idle:
            return String(localized: "settings.reindex.progress.starting",
                          defaultValue: "Starting…")
        case .indexing(let volumeId, let current, let total):
            return String(localized: "settings.reindex.progress.indexing",
                          defaultValue: "\(current)/\(total) — \(volumeId)")
        case .completed, .failed:
            return ""
        }
    }

    private func startReindex() {
        guard let pipeline = appState.indexingPipeline else { return }
        isReindexing = true
        progressState = .idle
        reindexError = nil

        Task {
            // Consume the progress stream while running reindex
            async let progressTask: Void = {
                for await event in pipeline.progress {
                    await MainActor.run { progressState = event.state }
                }
            }()
            do {
                try await pipeline.indexAllVolumes()
            } catch {
                await MainActor.run {
                    reindexError = error.localizedDescription
                    #if DEBUG
                    print("[Settings] Reindex failed: \(error)")
                    #endif
                }
            }
            _ = await progressTask
            await MainActor.run { isReindexing = false }
        }
    }
}

// MARK: - UserTagsView

private struct UserTagsView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserTag.name) private var tags: [UserTag]

    @State private var renamingTag: UserTag? = nil
    @State private var renameText = ""
    @State private var mergingTag: UserTag? = nil
    @State private var mergeTargetId: UUID? = nil

    var body: some View {
        Form {
            Section {
                if tags.isEmpty {
                    Text(String(localized: "settings.tags.empty",
                                defaultValue: "No user tags created yet."))
                        .foregroundStyle(.secondary)
                        .font(.callout)
                } else {
                    ForEach(tags) { tag in
                        let isRenaming = renamingTag?.id == tag.id
                        HStack {
                            if isRenaming {
                                TextField(
                                    String(localized: "settings.tags.rename.placeholder",
                                           defaultValue: "Tag name"),
                                    text: $renameText
                                )
                                .onSubmit { commitRename() }
                                .accessibilityLabel(
                                    String(localized: "settings.tags.rename.a11y",
                                           defaultValue: "Rename tag \(tag.name)")
                                )
                            } else {
                                Text(tag.name)
                            }
                            Spacer()
                            if !isRenaming {
                                Button(String(localized: "settings.tags.merge.button",
                                              defaultValue: "Merge…")) {
                                    mergingTag = tag
                                    mergeTargetId = nil
                                }
                                .font(.caption)
                                .buttonStyle(.borderless)
                                .foregroundStyle(.secondary)
                                .accessibilityLabel(
                                    String(localized: "settings.tags.merge.a11y",
                                           defaultValue: "Merge tag \(tag.name) into another")
                                )
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard renamingTag == nil else { return }
                            renamingTag = tag
                            renameText = tag.name
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            modelContext.delete(tags[index])
                        }
                    }
                }
            } header: {
                Text(String(localized: "settings.tags.list.header", defaultValue: "Tags"))
            } footer: {
                Text(String(localized: "settings.tags.list.footer",
                            defaultValue: "Tap a tag to rename it. Swipe to delete."))
                    .font(.caption)
            }
        }
        .navigationTitle(String(localized: "settings.tags.title", defaultValue: "User Tags"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
        .toolbar {
            if renamingTag != nil {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "settings.tags.rename.done", defaultValue: "Done")) {
                        commitRename()
                    }
                }
            }
        }
        .sheet(item: $mergingTag) { sourceTag in
            MergeTagSheet(
                sourceTag: sourceTag,
                allTags: tags.filter { $0.id != sourceTag.id },
                onMerge: { targetTag in
                    mergeTag(source: sourceTag, into: targetTag)
                    mergingTag = nil
                }
            )
        }
    }

    private func commitRename() {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, let tag = renamingTag {
            tag.name = trimmed
        }
        renamingTag = nil
        renameText = ""
    }

    private func mergeTag(source: UserTag, into target: UserTag) {
        // Update all notes that reference the source tag to reference the target tag instead
        let sourceId = source.id
        let targetId = target.id
        var descriptor = FetchDescriptor<ResearchNote>(
            predicate: #Predicate { note in note.userTagIds.contains(sourceId) }
        )
        descriptor.fetchLimit = 500
        let affected = (try? modelContext.fetch(descriptor)) ?? []
        for note in affected {
            var ids = note.userTagIds.filter { $0 != sourceId }
            if !ids.contains(targetId) { ids.append(targetId) }
            note.userTagIds = ids
        }
        modelContext.delete(source)

        #if DEBUG
        print("[Settings] Merged tag \(source.name) into \(target.name); updated \(affected.count) notes")
        #endif
    }
}

// MARK: - MergeTagSheet

private struct MergeTagSheet: View {
    let sourceTag: UserTag
    let allTags: [UserTag]
    let onMerge: (UserTag) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTagId: UUID? = nil

    @ViewBuilder
    private func mergeTagRow(tag: UserTag) -> some View {
        let isSelected: Bool = selectedTagId == tag.id
        HStack {
            Text(tag.name)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.accentColor)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { selectedTagId = tag.id }
        .accessibilityLabel(tag.name)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "settings.tags.merge.source.header",
                               defaultValue: "Merge '\(sourceTag.name)' into:")) {
                    ForEach(allTags) { tag in
                        mergeTagRow(tag: tag)
                    }
                }

                Text(String(localized: "settings.tags.merge.explanation",
                            defaultValue: "All notes tagged '\(sourceTag.name)' will be re-tagged with the selected tag. '\(sourceTag.name)' will be deleted."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle(String(localized: "settings.tags.merge.title",
                                    defaultValue: "Merge Tag"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "settings.tags.merge.cancel",
                                  defaultValue: "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "settings.tags.merge.confirm",
                                  defaultValue: "Merge")) {
                        if let id = selectedTagId,
                           let target = allTags.first(where: { $0.id == id }) {
                            onMerge(target)
                        }
                    }
                    .disabled(selectedTagId == nil)
                }
            }
        }
    }
}

// MARK: - SummarizationPromptsSettingsView

private struct SummarizationPromptsSettingsView: View {

    @Environment(AppState.self) private var appState
    @Query(sort: \SummarizationPrompt.createdAt) private var allPrompts: [SummarizationPrompt]
    @Query(sort: \GeneratedSummary.lastModified, order: .reverse) private var allSummaries: [GeneratedSummary]

    @State private var editingPrompt: SummarizationPrompt? = nil

    var body: some View {
        Form {
            promptsSection
            summaryCountsSection
            backgroundSection
        }
        .navigationTitle(String(localized: "settings.summarization.title",
                                defaultValue: "Summarization Prompts"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
    }

    @ViewBuilder
    private var promptsSection: some View {
        let standard = allPrompts.filter { $0.isStandard }
        let user = allPrompts.filter { !$0.isStandard }

        if !standard.isEmpty {
            Section(String(localized: "settings.summarization.standard.header",
                           defaultValue: "Standard Prompts")) {
                ForEach(standard) { prompt in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(prompt.name).font(.callout)
                        Text(summaryCountLabel(for: prompt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }

        Section(String(localized: "settings.summarization.user.header",
                       defaultValue: "Your Prompts")) {
            if user.isEmpty {
                Text(String(localized: "settings.summarization.user.empty",
                            defaultValue: "No custom prompts yet."))
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ForEach(user) { prompt in
                    Button {
                        editingPrompt = prompt
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(prompt.name)
                                    .font(.callout)
                                    .foregroundStyle(.primary)
                                Text(summaryCountLabel(for: prompt))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityLabel(
                        String(localized: "settings.summarization.prompt.a11y",
                               defaultValue: "Edit prompt \(prompt.name)")
                    )
                }
                .onDelete { offsets in
                    for i in offsets { modelContext.delete(user[i]) }
                }
            }
        }
    }

    @ViewBuilder
    private var summaryCountsSection: some View {
        Section(String(localized: "settings.summarization.counts.header",
                       defaultValue: "Summaries")) {
            LabeledContent(
                String(localized: "settings.summarization.counts.total", defaultValue: "Total Summaries"),
                value: "\(allSummaries.count)"
            )
        }
    }

    @ViewBuilder
    private var backgroundSection: some View {
        Section(String(localized: "settings.summarization.background.header",
                       defaultValue: "Background Summarization")) {
            BackgroundSummarizationSettingsView()
        }
    }

    @Environment(\.modelContext) private var modelContext

    private func summaryCountLabel(for prompt: SummarizationPrompt) -> String {
        let count = allSummaries.filter { $0.promptId == prompt.id }.count
        return String(localized: "settings.summarization.prompt.count",
                      defaultValue: "\(count) summary\(count == 1 ? "" : "ies") generated")
    }
}

// MARK: - NARAKeyView

private struct NARAKeyView: View {

    @State private var keyText: String = ""
    @State private var hasExistingKey: Bool = false
    @State private var isSaving: Bool = false
    @State private var saveResult: SaveResult? = nil

    private let keychainStore = KeychainStore.shared

    enum SaveResult {
        case saved, cleared, error(String)
    }

    var body: some View {
        Form {
            Section(String(localized: "settings.naraKey.about.header",
                           defaultValue: "About the NARA Catalog API Key")) {
                Text(String(localized: "settings.naraKey.about.body",
                            defaultValue: "A free API key from the National Archives Catalog is required to search for lot file and Presidential Library records in the Source Explorer. The key is stored securely in iCloud Keychain and synced across your devices."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section(String(localized: "settings.naraKey.entry.header",
                           defaultValue: "API Key")) {
                if hasExistingKey && keyText.isEmpty {
                    Text(String(localized: "settings.naraKey.stored",
                                defaultValue: "A key is currently stored."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                SecureField(
                    String(localized: "settings.naraKey.field.placeholder",
                           defaultValue: hasExistingKey ? "Enter new key to replace…" : "Paste your API key here…"),
                    text: $keyText
                )
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.asciiCapable)
                #endif
                .accessibilityLabel(
                    String(localized: "settings.naraKey.field.a11y",
                           defaultValue: "NARA Catalog API key field")
                )

                HStack {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text(String(localized: "settings.naraKey.save.button",
                                        defaultValue: "Save Key"))
                        }
                    }
                    .disabled(keyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                    .accessibilityLabel(
                        String(localized: "settings.naraKey.save.a11y", defaultValue: "Save API key")
                    )

                    if hasExistingKey {
                        Spacer()
                        Button(String(localized: "settings.naraKey.clear.button",
                                      defaultValue: "Clear Key"), role: .destructive) {
                            clearKey()
                        }
                        .accessibilityLabel(
                            String(localized: "settings.naraKey.clear.a11y",
                                   defaultValue: "Remove stored API key")
                        )
                    }
                }
            }

            if let result = saveResult {
                Section {
                    switch result {
                    case .saved:
                        Label(
                            String(localized: "settings.naraKey.saved",
                                   defaultValue: "API key saved."),
                            systemImage: "checkmark.circle"
                        )
                        .foregroundStyle(.green)
                        .font(.callout)
                    case .cleared:
                        Label(
                            String(localized: "settings.naraKey.cleared",
                                   defaultValue: "API key removed."),
                            systemImage: "trash"
                        )
                        .font(.callout)
                    case .error(let msg):
                        Label(msg, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }
            }
        }
        .navigationTitle(String(localized: "settings.naraKey.title",
                                defaultValue: "NARA Catalog API Key"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
        .task {
            hasExistingKey = await keychainStore.hasAPIKey()
        }
    }

    private func save() {
        let trimmed = keyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSaving = true
        saveResult = nil
        Task {
            do {
                try await keychainStore.setNARACatalogAPIKey(trimmed)
                keyText = ""
                hasExistingKey = true
                saveResult = .saved
                #if DEBUG
                print("[Settings] NARA API key saved")
                #endif
            } catch {
                saveResult = .error(error.localizedDescription)
            }
            isSaving = false
        }
    }

    private func clearKey() {
        Task {
            do {
                try await keychainStore.deleteNARACatalogAPIKey()
                keyText = ""
                hasExistingKey = false
                saveResult = .cleared
                #if DEBUG
                print("[Settings] NARA API key cleared")
                #endif
            } catch {
                saveResult = .error(error.localizedDescription)
            }
        }
    }
}

// MARK: - ResetView

/// Two-step confirmation UI for the destructive "Reset App to Initial State" action.
///
/// ## What is deleted
/// - All downloaded volume XML files (via `DownloadManager`)
/// - All SwiftData user-generated records: `ResearchNote`, `UserTag`, `GeneratedSummary`,
///   `ReadingHistoryEntry`, `Collection`, `CollectionEntry`, `SummarizationPrompt`, `Project`
/// - Active project selection (`AppState.activeProjectId`)
///
/// ## Post-reset navigation
/// Both platforms now set `hasCompletedOnboarding = false` directly after clearing data.
/// - **iOS**: Settings is a persistent tab — no sheet is on screen.
/// - **macOS**: Settings is now a `Settings` scene (independent window, not a modal sheet).
///   There is no animation race with `ContentView`, so direct assignment is safe.
///
/// ## Confirmation gates
/// The user must confirm twice (two `confirmationDialog` calls) before `performReset()`
/// is invoked, guarding against accidental taps.
///
/// Version history:
///   1.0 — Session 24: initial implementation
///   1.1 — Session 32: added `Project` deletion; switched to two-phase sheet-dismissal
///          for safe post-reset onboarding navigation (macOS)
///   1.2 — Session 44: iOS path simplified to direct assignment
///   1.3 — Session 46: macOS path also simplified; pendingOnboardingAfterReset removed
private struct ResetView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var showFirstConfirmation = false
    @State private var showSecondConfirmation = false
    @State private var isResetting = false
    @State private var resetError: String? = nil

    var body: some View {
        Form {
            Section {
                Text(String(localized: "settings.reset.warning",
                            defaultValue: "This will delete all downloaded volumes, your search index, all research notes, projects, user tags, collections, and AI-generated summaries. This action cannot be undone."))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Button(String(localized: "settings.reset.button",
                              defaultValue: "Reset App to Initial State"), role: .destructive) {
                    showFirstConfirmation = true
                }
                .disabled(isResetting)
                .accessibilityLabel(
                    String(localized: "settings.reset.button.a11y",
                           defaultValue: "Reset app to initial state. Destructive action.")
                )
            }

            if let error = resetError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
        }
        .navigationTitle(String(localized: "settings.reset.title", defaultValue: "Reset App"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
        .confirmationDialog(
            String(localized: "settings.reset.confirm1.title",
                   defaultValue: "Reset FRUS Explorer?"),
            isPresented: $showFirstConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "settings.reset.confirm1.proceed",
                          defaultValue: "Continue"), role: .destructive) {
                showSecondConfirmation = true
            }
            Button(String(localized: "settings.reset.cancel",
                          defaultValue: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "settings.reset.confirm1.message",
                        defaultValue: "All user data will be permanently deleted. Are you sure?"))
        }
        .confirmationDialog(
            String(localized: "settings.reset.confirm2.title",
                   defaultValue: "This Cannot Be Undone"),
            isPresented: $showSecondConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "settings.reset.confirm2.proceed",
                          defaultValue: "Delete Everything"), role: .destructive) {
                performReset()
            }
            Button(String(localized: "settings.reset.cancel",
                          defaultValue: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "settings.reset.confirm2.message",
                        defaultValue: "All downloaded volumes, research notes, projects, and summaries will be deleted immediately."))
        }
    }

    private func performReset() {
        isResetting = true
        resetError = nil
        Task {
            do {
                // Delete all downloaded volumes
                if let dm = appState.downloadManager {
                    let all = appState.manifestStore.diffResult?.known
                        ?? appState.manifestStore.bundledEntries
                    for entry in all where dm.isVolumeDownloaded(entry.volumeId) {
                        try? await dm.deleteVolume(volumeId: entry.volumeId)
                    }
                }
                // Delete all SwiftData user-generated records
                try modelContext.delete(model: ResearchNote.self)
                try modelContext.delete(model: UserTag.self)
                try modelContext.delete(model: GeneratedSummary.self)
                try modelContext.delete(model: ReadingHistoryEntry.self)
                try modelContext.delete(model: Collection.self)
                try modelContext.delete(model: CollectionEntry.self)
                try modelContext.delete(model: SummarizationPrompt.self)
                try modelContext.delete(model: Project.self)
                await MainActor.run {
                    appState.activeProjectId = nil
                    // Both iOS and macOS now use direct assignment. On iOS, Settings is
                    // a persistent tab; on macOS, Settings is a Settings scene (independent
                    // window). Neither path has a modal sheet on screen that could race
                    // with ContentView's transition to OnboardingView.
                    appState.hasCompletedOnboarding = false
                }

                #if DEBUG
                print("[Settings] App reset complete")
                #endif
            } catch {
                await MainActor.run {
                    resetError = error.localizedDescription
                    isResetting = false
                }
                return
            }
            await MainActor.run { isResetting = false }
        }
    }
}

// MARK: - Shared Helpers

/// Formats a byte count using `ByteCountFormatter` with adaptive style.
func formattedBytes(_ bytes: Int) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB, .useGB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: Int64(bytes))
}

// MARK: - SettingsKeys

enum SettingsKeys {
    static let concurrentDownloadLimit = "frus.concurrentDownloadLimit"
}

// MARK: - MacSettingsView

#if os(macOS)

/// macOS Settings window content.
///
/// Replaces the sheet-based `SettingsView` used before Session 46.
/// Presented by the system `Settings` scene declared in `FRUSExplorerApp`.
/// The system opens this window via ⌘, and the App menu > Settings item.
///
/// Eight settings panels are consolidated into four logical tabs:
///
/// | Tab | Panels |
/// |---|---|
/// | Volumes | Volume Management, Storage, Sideload, Reindex |
/// | Research | User Tags, Summarization Prompts |
/// | Integrations | NARA Catalog API Key |
/// | Advanced | Reset App, About |
///
/// Each tab hosts a `NavigationStack` + `Form` with `NavigationLink` rows so
/// sub-panels retain the same drill-down structure as the iOS `SettingsView`.
///
/// Version history:
///   1.0 — Session 46: initial implementation
struct MacSettingsView: View {

    var body: some View {
        TabView {
            Tab(String(localized: "settings.mac.tab.volumes",
                       defaultValue: "Volumes"),
                systemImage: "arrow.down.circle") {
                VolumesSettingsPane()
            }
            Tab(String(localized: "settings.mac.tab.research",
                       defaultValue: "Research"),
                systemImage: "note.text") {
                ResearchSettingsPane()
            }
            Tab(String(localized: "settings.mac.tab.integrations",
                       defaultValue: "Integrations"),
                systemImage: "network") {
                NavigationStack {
                    NARAKeyView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            Tab(String(localized: "settings.mac.tab.advanced",
                       defaultValue: "Advanced"),
                systemImage: "gearshape.2") {
                AdvancedSettingsPane()
            }
        }
        .frame(width: 560, height: 480)
    }
}

/// Volumes pane: Download Manager, Volume Management, Storage, Sideload, Reindex.
private struct VolumesSettingsPane: View {
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink(String(localized: "settings.row.downloadManager",
                                         defaultValue: "Download Manager")) {
                        DownloadManagerSettingsView()
                    }
                    NavigationLink(String(localized: "settings.row.volumeManagement",
                                         defaultValue: "Volume Management")) {
                        VolumeManagementView()
                    }
                    NavigationLink(String(localized: "settings.row.storage",
                                         defaultValue: "Storage")) {
                        StorageManagementView()
                    }
                    NavigationLink(String(localized: "settings.row.sideload",
                                         defaultValue: "Sideload Volume")) {
                        SideloadView()
                    }
                    NavigationLink(String(localized: "settings.row.reindex",
                                         defaultValue: "Reindex")) {
                        ReindexView()
                    }
                }
            }
            .navigationTitle(String(localized: "settings.mac.tab.volumes",
                                    defaultValue: "Volumes"))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Research pane: User Tags, Summarization Prompts.
private struct ResearchSettingsPane: View {
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink(String(localized: "settings.row.tags",
                                         defaultValue: "User Tags")) {
                        UserTagsView()
                    }
                    NavigationLink(String(localized: "settings.row.summarization",
                                         defaultValue: "Summarization Prompts")) {
                        SummarizationPromptsSettingsView()
                    }
                }
            }
            .navigationTitle(String(localized: "settings.mac.tab.research",
                                    defaultValue: "Research"))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Advanced pane: Reset App.
///
/// The "About FRUS Explorer" item was removed in Session 50; About is now
/// accessible via the App menu (`CommandGroup(replacing: .appInfo)`).
private struct AdvancedSettingsPane: View {
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink(String(localized: "settings.row.reset",
                                         defaultValue: "Reset App")) {
                        ResetView()
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle(String(localized: "settings.mac.tab.advanced",
                                    defaultValue: "Advanced"))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#endif
