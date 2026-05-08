// CatalogueView.swift
// Left column: searchable catalogue of FRUS volumes with download controls.
// Shows locally-available volumes immediately at launch before the network loads.

import SwiftUI

struct CatalogueView: View {
    @Environment(AppStore.self) private var store: AppStore
    @State private var sortOrder = SortOrder.id
    @State private var showDownloadAllConfirmation = false

    enum SortOrder: String, CaseIterable, Identifiable {
        case id = "Volume ID"
        case size = "File Size"
        var id: String { rawValue }
    }

    private var sorted: [FRUSVolumeInfo] {
        let items = store.filteredCatalogue
        switch sortOrder {
        case .id:   return items
        case .size: return items.sorted { $0.size > $1.size }
        }
    }

    private var bulk: AppStore.BulkProgress { store.bulkProgress }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            searchBar(store: store)
            Divider()
            // Bulk-download progress bar — shown whenever downloads are active
            if bulk.isActive {
                bulkProgressBar
            }
            catalogueBody
        }
        .toolbar { toolbarItems }
        .task { await store.loadCatalogue() }
        .confirmationDialog(
            "Download All Volumes?",
            isPresented: $showDownloadAllConfirmation,
            titleVisibility: .visible
        ) {
            Button("Download All (\(bulk.total - bulk.completed) remaining)") {
                store.downloadAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            let remaining = bulk.total - bulk.completed
            let plural = remaining == 1 ? "" : "s"
            let size = store.catalogue
                .filter { switch store.downloadState(for: $0.id) {
                    case .notDownloaded, .failed: return true
                    default: return false } }
                .reduce(0) { $0 + $1.size }
            let formatted = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
            Text("\(remaining) volume\(plural) will be downloaded (~\(formatted)). This may take a long time.")
        }
    }

    // MARK: - Header bar

    private var headerBar: some View {
        HStack(spacing: 10) {
            Text("Volumes")
                .font(.system(.headline, design: .serif))

            Spacer()

            // Online / offline indicator
            HStack(spacing: 5) {
                Circle()
                    .fill(store.isOnline ? Color.frusRuby : Color.orange)
                    .frame(width: 8, height: 8)
                Text(store.isOnline ? "Online" : "Offline")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Picker("Sort", selection: .init(
                get: { sortOrder },
                set: { sortOrder = $0 }
            )) {
                ForEach(SortOrder.allCases) { s in Text(s.rawValue).tag(s) }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .controlSize(.regular)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Search bar

    private func searchBar(store: AppStore) -> some View {
        @Bindable var store = store
        return HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 13))
            TextField("Search volumes…", text: $store.searchText)
                .textFieldStyle(.plain)
                .font(.system(.callout, design: .monospaced))
            if !store.searchText.isEmpty {
                Button {
                    store.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.quinary)
    }

    // MARK: - Bulk progress bar

    private var bulkProgressBar: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                HStack {
                    Text("\(bulk.downloading) downloading · \(bulk.completed) of \(bulk.total) complete")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Cancel All") { store.cancelAllDownloads() }
                        .font(.system(size: 11))
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                ProgressView(value: bulk.fractionCompleted)
                    .progressViewStyle(.linear)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.quinary)
            Divider()
        }
    }

    // MARK: - Main body

    @ViewBuilder
    private var catalogueBody: some View {
        switch store.catalogueState {
        case .idle:
            offlineSection

        case .loading:
            VStack(spacing: 0) {
                offlineSection
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.75)
                    Text("Loading catalogue…")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(.quinary)
            }

        case .failed(let msg):
            VStack(spacing: 0) {
                offlineSection
                Divider()
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.system(size: 13))
                    Text(msg)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Spacer()
                    Button("Retry") { Task { await store.loadCatalogue() } }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.quinary)
            }

        case .loaded:
            if sorted.isEmpty && store.searchText.isEmpty {
                offlineSection
            } else {
                @Bindable var store = store
                List(selection: $store.selectedVolumeID) {
                    let localIDs      = store.localVolumeIDs
                    let localVolumes  = sorted.filter {  localIDs.contains($0.id) }
                    let remoteVolumes = sorted.filter { !localIDs.contains($0.id) }

                    if !localVolumes.isEmpty && store.searchText.isEmpty {
                        Section {
                            ForEach(localVolumes) { info in
                                VolumeRow(info: info)
                                    .tag(info.id)
                                    .contextMenu { volumeContextMenu(info) }
                            }
                        } header: {
                            Label("Downloaded", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.frusRuby)
                        }
                    }

                    let displayVolumes = store.searchText.isEmpty ? remoteVolumes : sorted
                    if !displayVolumes.isEmpty {
                        Section {
                            ForEach(displayVolumes) { info in
                                VolumeRow(info: info)
                                    .tag(info.id)
                                    .contextMenu { volumeContextMenu(info) }
                            }
                        } header: {
                            if !localVolumes.isEmpty && store.searchText.isEmpty {
                                Text("All Volumes")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if sorted.isEmpty {
                        ContentUnavailableView.search(text: store.searchText)
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }

    // MARK: - Offline section

    @ViewBuilder
    private var offlineSection: some View {
        if store.localVolumeIDs.isEmpty {
            VStack(spacing: 18) {
                Image(systemName: store.isOnline ? "arrow.down.circle" : "wifi.slash")
                    .font(.system(size: 40))
                    .foregroundStyle(.tertiary)
                Text(store.isOnline
                     ? "Fetching volume catalogue…"
                     : "Offline — no downloaded volumes available.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 220)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            @Bindable var store = store
            List(selection: $store.selectedVolumeID) {
                Section {
                    ForEach(store.localVolumeIDs.sorted(), id: \.self) { volumeID in
                        OfflineVolumeRow(volumeID: volumeID)
                            .tag(volumeID)
                    }
                } header: {
                    Label("Downloaded", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.frusRuby)
                }
            }
            .listStyle(.sidebar)
        }
    }

    // MARK: - Context menu

    @ViewBuilder
    private func volumeContextMenu(_ info: FRUSVolumeInfo) -> some View {
        let state = store.downloadState(for: info.id)
        switch state {
        case .notDownloaded, .failed:
            Button("Download") { store.download(info) }
        case .downloaded, .ready:
            Button("Open") { Task { await store.loadVolume(info) } }
            Button("Re-index") { Task { await store.reindexVolume(info) } }
            Divider()
            Button("Delete Local File", role: .destructive) { store.deleteVolume(info.id) }
        case .downloading:
            Button("Cancel Download", role: .destructive) { store.cancelDownload(info.id) }
        case .parsing:
            Text("Parsing…").disabled(true)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        // Download All button
        ToolbarItem(placement: .secondaryAction) {
            if bulk.isActive {
                // While downloading: show aggregate progress + cancel
                Button {
                    store.cancelAllDownloads()
                } label: {
                    Label("Cancel Downloads", systemImage: "xmark.circle")
                }
                .help("Cancel all in-progress downloads")
            } else {
                Button {
                    showDownloadAllConfirmation = true
                } label: {
                    Label("Download All", systemImage: "arrow.down.circle.fill")
                }
                .help("Download all volumes that are not yet saved locally")
                .disabled(
                    store.catalogueState != .loaded ||
                    !store.isOnline ||
                    (bulk.completed >= bulk.total && bulk.total > 0)
                )
            }
        }

        // Refresh catalogue
        ToolbarItem(placement: .primaryAction) {
            Button {
                Task { await store.loadCatalogue() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh catalogue")
            .disabled(store.catalogueState == .loading || !store.isOnline)
        }
    }
}

// MARK: - VolumeRow

struct VolumeRow: View {
    @Environment(AppStore.self) private var store: AppStore
    let info: FRUSVolumeInfo

    private var state: VolumeDownloadState { store.downloadState(for: info.id) }
    private var cachedTitle: String? { store.volumeTitleCache[info.id]?.volumeTitle }

    var body: some View {
        HStack(spacing: 12) {
            // State icon — larger for easier scanning
            stateIcon
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 3) {
                if let title = cachedTitle {
                    Text(title)
                        .font(.system(.callout, design: .serif))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(info.id)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(info.id)
                        .font(.system(.callout, design: .monospaced))
                        .lineLimit(1)
                }
                HStack(spacing: 8) {
                    Text(info.formattedSize)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    if case .downloading(let p) = state {
                        ProgressView(value: p)
                            .progressViewStyle(.linear)
                            .frame(maxWidth: 70)
                    }
                }
            }

            Spacer()

            // Action button — larger touch target
            actionButton
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .padding(.vertical, 5)
    }

    @ViewBuilder private var stateIcon: some View {
        switch state {
        case .notDownloaded:
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 18))
                .foregroundStyle(.tertiary)
        case .downloading:
            ProgressView().scaleEffect(0.75)
        case .downloaded:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.frusRuby)
        case .parsing:
            ProgressView().scaleEffect(0.75)
        case .ready:
            Image(systemName: "book.fill")
                .font(.system(size: 18))
                .foregroundStyle(.accent)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.frusAmber)
        }
    }

    @ViewBuilder private var actionButton: some View {
        switch state {
        case .notDownloaded:
            Button {
                store.download(info)
            } label: {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.accent)
            }
            .buttonStyle(.plain)
            .help("Download \(info.id)")

        case .failed:
            Button {
                store.download(info)
            } label: {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.frusAmber)
            }
            .buttonStyle(.plain)
            .help("Retry download")

        case .downloaded:
            Button {
                Task { await store.loadVolume(info) }
            } label: {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 20))
                    .foregroundStyle(.accent)
            }
            .buttonStyle(.plain)
            .help("Explore \(info.id)")

        case .ready:
            Button {
                store.selectedVolumeID = info.id
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.accent)
            }
            .buttonStyle(.plain)
            .help("View \(info.id)")

        case .downloading, .parsing:
            EmptyView()
        }
    }
}

// MARK: - OfflineVolumeRow

struct OfflineVolumeRow: View {
    @Environment(AppStore.self) private var store: AppStore
    let volumeID: String

    private var state: VolumeDownloadState { store.downloadState(for: volumeID) }
    private var cachedTitle: String? { store.volumeTitleCache[volumeID]?.volumeTitle }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.frusRuby)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 3) {
                if let title = cachedTitle {
                    Text(title)
                        .font(.system(.callout, design: .serif))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(volumeID)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(volumeID)
                        .font(.system(.callout, design: .monospaced))
                        .lineLimit(1)
                }
                Text("Available offline")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if state == .parsing {
                ProgressView().scaleEffect(0.75)
                    .frame(width: 32, height: 32)
            } else {
                Button {
                    Task { await store.loadVolumeByID(volumeID) }
                } label: {
                    Image(systemName: state == .ready ? "chevron.right.circle.fill" : "doc.text.magnifyingglass")
                        .font(.system(size: 20))
                        .foregroundStyle(state == .ready ? Color.accentColor : Color.primary)
                }
                .buttonStyle(.plain)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
                .help(state == .ready ? "View \(volumeID)" : "Load \(volumeID)")
            }
        }
        .padding(.vertical, 5)
        .contextMenu {
            Button("Re-index") { Task { await store.reindexVolumeByID(volumeID) } }
            Divider()
            Button("Delete Local File", role: .destructive) {
                store.deleteVolume(volumeID)
            }
        }
    }
}
