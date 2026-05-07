// AppStore.swift
// Central application state — volume catalogue, download management, parsed volumes.

import Foundation
import Observation
import Network
import FRUSKit

// MARK: - Download state per volume

enum VolumeDownloadState: Equatable {
    case notDownloaded
    case downloading(progress: Double)   // 0.0 – 1.0
    case downloaded(localURL: URL)
    case parsing
    case ready
    case failed(String)
}

// MARK: - Parsed volume wrapper

final class LoadedVolume: Identifiable {
    let info: FRUSVolumeInfo
    let volume: FRUSVolume
    var id: String { info.id }

    init(info: FRUSVolumeInfo, volume: FRUSVolume) {
        self.info = info
        self.volume = volume
    }
}

// MARK: - AppStore

@MainActor
@Observable
final class AppStore {

    // Catalogue
    var catalogue: [FRUSVolumeInfo] = []
    var catalogueState: CatalogueState = .idle
    var searchText = ""

    // Network reachability
    var isOnline: Bool = true

    // Per-volume state
    var downloadStates: [String: VolumeDownloadState] = [:]

    // Loaded (parsed) volumes
    var loadedVolumes: [String: LoadedVolume] = [:]

    // Local-only volume metadata (populated from disk at launch, before network)
    var localVolumeIDs: Set<String> = []

    // Currently explored volume / selection
    var selectedVolumeID: String?
    var selectedNodeID: String?

    // Summaries cache: composite key = "{volumeID}__{divisionID}" (matches nodeID / SearchRecord.id)
    var summaries: [String: SummaryState] = [:]

    var summaryStore: SummaryStore?

    let downloader = FRUSDownloader(maxConcurrentDownloads: 2, skipIfAlreadyDownloaded: true)
    let summariser = SummarisationService()
    let searchEngine = SearchEngine()

    // Search state
    var searchResults: [SearchResult] = []
    var isSearching = false

    var profileStore: PromptProfileStore? {
        didSet { observeProfileChanges() }
    }
    private var profileObserver: NSObjectProtocol?
    private var networkMonitor: NWPathMonitor?
    private var networkQueue = DispatchQueue(label: "frus.network.monitor")

    private func observeProfileChanges() {
        if let existing = profileObserver {
            NotificationCenter.default.removeObserver(existing)
        }
        profileObserver = NotificationCenter.default.addObserver(
            forName: .summaryProfileDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.summaries.removeAll()
        }
    }

    private let downloadDirectory: URL = {
        // On macOS, store in Application Support (hidden from Finder by default).
        // On iPadOS, store in the Documents directory so volumes appear in the
        // Files app and survive iCloud Drive backups.
#if os(macOS)
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appending(component: "FRUSExplorer/volumes")
#else
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appending(component: "FRUSVolumes")
#endif
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    // MARK: - Init

    init() {
        // Scan local volumes immediately so offline content is available
        // before any network request completes.
        scanLocalVolumes()
        startNetworkMonitor()
    }

    // MARK: - Network monitoring

    private func startNetworkMonitor() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.isOnline = online
            }
        }
        monitor.start(queue: networkQueue)
        networkMonitor = monitor
    }

    // MARK: - Local volume scanning

    /// Scans the download directory and populates `downloadStates` and `localVolumeIDs`
    /// without waiting for the network. Called at init and after every download.
    func scanLocalVolumes() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: downloadDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return }

        var found: Set<String> = []
        for file in files where file.pathExtension == "xml" {
            let volumeID = file.deletingPathExtension().lastPathComponent
            found.insert(volumeID)
            // Only set to .downloaded if we haven't already parsed it into .ready
            switch downloadStates[volumeID] {
            case .none, .notDownloaded:
                downloadStates[volumeID] = .downloaded(localURL: file)
            default:
                break
            }
        }
        localVolumeIDs = found
    }

    // MARK: - Computed

    var filteredCatalogue: [FRUSVolumeInfo] {
        guard !searchText.isEmpty else { return catalogue }
        return catalogue.filter { $0.id.localizedCaseInsensitiveContains(searchText) }
    }

    /// Volumes available locally but not present in the current catalogue
    /// (e.g. when offline or before the catalogue finishes loading).
    var offlineOnlyVolumeIDs: [String] {
        let catalogueIDs = Set(catalogue.map(\.id))
        return localVolumeIDs.subtracting(catalogueIDs).sorted()
    }

    var selectedVolume: LoadedVolume? {
        guard let id = selectedVolumeID else { return nil }
        return loadedVolumes[id]
    }

    // MARK: - Catalogue loading

    enum CatalogueState: Equatable {
        case idle, loading, loaded, failed(String)
    }

    func loadCatalogue() async {
        guard catalogueState != .loading else { return }
        catalogueState = .loading
        do {
            let list = try await downloader.fetchVolumeList()
            catalogue = list
            catalogueState = .loaded
            // Re-scan local after we have catalogue metadata to merge against
            scanLocalVolumes()
        } catch {
            // Don't erase existing catalogue on refresh failure
            if catalogue.isEmpty {
                catalogueState = .failed(error.localizedDescription)
            } else {
                catalogueState = .loaded
            }
        }
    }

    // MARK: - Downloading

    func download(_ info: FRUSVolumeInfo) {
        let id = info.id
        switch downloadStates[id] {
        case .none, .notDownloaded, .failed:
            break
        default:
            return
        }
        downloadStates[id] = .downloading(progress: 0)

        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await downloader.download(
                    volume: info,
                    to: downloadDirectory,
                    progress: { [weak self] p in
                        self?.downloadStates[id] = .downloading(
                            progress: p.fractionCompleted ?? 0
                        )
                    }
                )
                downloadStates[id] = .downloaded(localURL: result.localURL)
                localVolumeIDs.insert(id)
            } catch {
                downloadStates[id] = .failed(error.localizedDescription)
            }
        }
    }

    func cancelDownload(_ id: String) {
        downloadStates[id] = .notDownloaded
    }

    // MARK: - Bulk download

    /// Downloads every volume in the catalogue that has not yet been downloaded.
    /// Individual `download(_:)` calls drive the per-volume progress already
    /// observed by the UI, so no additional state is needed.
    func downloadAll() {
        guard catalogueState == .loaded else { return }
        let pending = catalogue.filter {
            switch downloadStates[$0.id] {
            case .none, .notDownloaded, .failed: return true
            default: return false
            }
        }
        for info in pending {
            download(info)
        }
    }

    /// Cancels every in-progress download.
    func cancelAllDownloads() {
        for (id, state) in downloadStates {
            if case .downloading = state {
                downloadStates[id] = .notDownloaded
            }
        }
    }

    // MARK: - Bulk progress summary

    struct BulkProgress {
        let downloading: Int   // volumes currently in flight
        let completed: Int     // volumes in .downloaded or .ready state
        let total: Int         // total volumes in catalogue
        let failed: Int

        var fractionCompleted: Double {
            total > 0 ? Double(completed) / Double(total) : 0
        }

        var isActive: Bool { downloading > 0 }
    }

    var bulkProgress: BulkProgress {
        let total = catalogue.count
        guard total > 0 else { return BulkProgress(downloading: 0, completed: 0, total: 0, failed: 0) }
        var downloading = 0, completed = 0, failed = 0
        for info in catalogue {
            switch downloadStates[info.id] {
            case .downloading:            downloading += 1
            case .downloaded, .ready:     completed  += 1
            case .failed:                 failed     += 1
            default: break
            }
        }
        return BulkProgress(downloading: downloading, completed: completed,
                            total: total, failed: failed)
    }

    // MARK: - Parsing / loading

    func loadVolume(_ info: FRUSVolumeInfo) async {
        let id = info.id
        // Accept both .downloaded and .ready states as triggers
        guard case .downloaded(let url) = downloadStates[id] else {
            // Also handle the case where the file is on disk but state is stale
            let fileURL = downloadDirectory.appending(component: "\(id).xml")
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
            if loadedVolumes[id] != nil { selectedVolumeID = id; return }
            await parseVolume(id: id, url: fileURL, info: info)
            return
        }
        guard loadedVolumes[id] == nil else {
            selectedVolumeID = id
            return
        }
        await parseVolume(id: id, url: url, info: info)
    }

    private func parseVolume(id: String, url: URL, info: FRUSVolumeInfo) async {
        downloadStates[id] = .parsing
        do {
            // Parse XML and build search index together off the main thread
            let (volume, records) = try await Task.detached(priority: .userInitiated) {
                let v = try FRUSParser().parse(url: url)
                let r = SearchIndexBuilder.build(from: v, volumeID: id)
                return (v, r)
            }.value
            let loaded = LoadedVolume(info: info, volume: volume)
            loadedVolumes[id] = loaded
            downloadStates[id] = .ready
            selectedVolumeID = id
            await searchEngine.addIndex(volumeID: id, records: records)
        } catch {
            downloadStates[id] = .failed(error.localizedDescription)
        }
    }

    // MARK: - Summarisation

    func summarise(_ division: Division, volumeID: String) {
        guard let divID = division.id else { return }
        let key = "\(volumeID)__\(divID)"
        guard summaries[key] == nil else { return }

        // Return persisted summary for the active profile if one exists.
        if let profileID = profileStore?.activeProfileID,
           let stored = summaryStore?.lookup(volumeID: volumeID, divisionID: divID, profileID: profileID) {
            summaries[key] = .ready(stored)
            return
        }

        summaries[key] = .generating

        let text = division.bodyText
        guard !text.isEmpty else {
            summaries[key] = .ready("No text content available.")
            return
        }

        let activeProfile = profileStore?.activeProfile
        let profileID = profileStore?.activeProfileID
        let profileName = profileStore?.activeProfile.name ?? "Default"

        Task {
            let result = await summariser.summarise(
                text: text,
                title: division.title ?? "",
                profile: activeProfile
            )
            summaries[key] = result
            if case .ready(let t) = result, let pid = profileID {
                summaryStore?.store(
                    volumeID: volumeID,
                    divisionID: divID,
                    profileID: pid,
                    profileName: profileName,
                    text: t
                )
            }
        }
    }

    func regenerateSummary(for division: Division, volumeID: String) {
        guard let divID = division.id else { return }
        let key = "\(volumeID)__\(divID)"
        summaries.removeValue(forKey: key)
        if let profileID = profileStore?.activeProfileID {
            summaryStore?.purge(volumeID: volumeID, divisionID: divID, profileID: profileID)
        }
        summarise(division, volumeID: volumeID)
    }

    func summary(for division: Division, volumeID: String) -> SummaryState? {
        guard let divID = division.id else { return nil }
        return summaries["\(volumeID)__\(divID)"]
    }

    func clearSummaryCache() {
        summaries.removeAll()
    }

    // MARK: - Search

    func runSearch(
        query: String,
        dateFilter: DateFilter? = nil,
        annotations: [String: String] = [:]
    ) async {
        isSearching = true
        defer { isSearching = false }
        // Merge persisted summaries (all profiles, all volumes) with the in-memory
        // session cache so every stored summary is reachable in a single search pass.
        var summaryTexts = summaryStore?.allSummaryTexts ?? [:]
        for (key, state) in summaries {
            if case .ready(let t) = state {
                if let existing = summaryTexts[key] {
                    summaryTexts[key] = existing + " " + t
                } else {
                    summaryTexts[key] = t
                }
            }
        }
        searchResults = await searchEngine.search(
            queryString: query,
            explicitDateFilter: dateFilter,
            summaries: summaryTexts,
            annotations: annotations
        )
    }

    // MARK: - Load by ID (offline row convenience)

    /// Loads a volume from disk when only the volume ID is known.
    /// Prefers the real `FRUSVolumeInfo` from the catalogue when available.
    func loadVolumeByID(_ id: String) async {
        if let info = catalogue.first(where: { $0.id == id }) {
            await loadVolume(info)
            return
        }
        if loadedVolumes[id] != nil { selectedVolumeID = id; return }
        let fileURL = downloadDirectory.appending(component: "\(id).xml")
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let placeholderURL = URL(string: "https://raw.githubusercontent.com/HistoryAtState/frus/master/volumes/\(id).xml")!
        let info = FRUSVolumeInfo(id: id, size: 0, sha: "", downloadURL: placeholderURL)
        await parseVolume(id: id, url: fileURL, info: info)
    }

    // MARK: - Delete local file

    func deleteVolume(_ id: String) {
        let url = downloadDirectory.appending(component: "\(id).xml")
        try? FileManager.default.removeItem(at: url)
        downloadStates[id] = .notDownloaded
        localVolumeIDs.remove(id)
        loadedVolumes.removeValue(forKey: id)
        if selectedVolumeID == id { selectedVolumeID = nil }
        Task { await searchEngine.removeIndex(volumeID: id) }
        summaryStore?.purgeVolume(id)
        summaries = summaries.filter { !$0.key.hasPrefix("\(id)__") }
    }

    func downloadState(for id: String) -> VolumeDownloadState {
        downloadStates[id] ?? .notDownloaded
    }
}

// MARK: - Summary state

enum SummaryState: Equatable {
    case generating
    case ready(String)
    case failed(String)
}
