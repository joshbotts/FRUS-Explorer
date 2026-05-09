// Views/Onboarding/OnboardingView.swift
//
// Presented as a modal sheet whenever the user has no downloaded volumes.
// Walks new users through three screens:
//
//   1. Welcome  — explains the app and its reliance on local volumes.
//   2. Selector — grouped subseries list; select and start downloads.
//      (or Offline — shown instead when the device has no connectivity.)
//
// The sheet auto-dismisses when localVolumeIDs becomes non-empty
// (i.e., when the first download finishes). Users can also skip via the
// toolbar so that the sheet closes even while offline; it will reappear
// on the next launch if still no volumes are present.

import SwiftUI

// MARK: - Shared subseries helpers

private func onboardingPrefix(from id: String) -> String {
    // Matches the subseries year-group: frus1946, frus1946-47, etc.
    let pattern = #"^frus\d{4}(?:-\d{2,4})?"#
    if let range = id.range(of: pattern, options: .regularExpression) {
        return String(id[range])
    }
    return id
}

private struct OnboardingSeries: Identifiable {
    let prefix: String
    let volumes: [FRUSVolumeInfo]
    var id: String { prefix }
    var totalBytes: Int { volumes.reduce(0) { $0 + $1.size } }
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file)
    }
}

private func makeOnboardingGroups(_ catalogue: [FRUSVolumeInfo]) -> [OnboardingSeries] {
    var order: [String] = []
    var map: [String: [FRUSVolumeInfo]] = [:]
    for vol in catalogue {
        let p = onboardingPrefix(from: vol.id)
        if map[p] == nil { order.append(p) }
        map[p, default: []].append(vol)
    }
    return order.map { OnboardingSeries(prefix: $0, volumes: map[$0]!) }
}

// MARK: - OnboardingView (container)

struct OnboardingView: View {
    var body: some View {
        NavigationStack {
            OnboardingWelcomePage()
        }
    }
}

// MARK: - Step 1: Welcome

struct OnboardingWelcomePage: View {
    @Environment(AppStore.self) private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Hero
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.frusRuby)
                        .padding(.bottom, 4)

                    Text("Welcome to FRUS Explorer")
                        .font(.system(.largeTitle, design: .serif))
                        .fontWeight(.bold)

                    Text("A research reader for the Foreign Relations of the United States documentary series")
                        .font(.system(.title3, design: .serif))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 28)

                // Feature list
                VStack(alignment: .leading, spacing: 18) {
                    OnboardingFeatureRow(
                        icon: "doc.text.magnifyingglass",
                        title: "Full-text search",
                        detail: "Search every paragraph across all loaded volumes by keyword, date range, or subject — results link directly to the source document."
                    )
                    OnboardingFeatureRow(
                        icon: "tag.fill",
                        title: "Subject browsing",
                        detail: "Navigate documents by topic using a structured taxonomy covering countries, people, organisations, and policy themes."
                    )
                    OnboardingFeatureRow(
                        icon: "rectangle.stack.fill",
                        title: "Research collections",
                        detail: "Gather documents into named collections, annotate each one, and export a formatted, paginated PDF."
                    )
                    OnboardingFeatureRow(
                        icon: "wifi.slash",
                        title: "Offline access",
                        detail: "Volumes are stored locally. Once downloaded, you can read and search them without an internet connection."
                    )
                }
                .padding(.bottom, 28)

                // Volume requirement callout
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.tint)
                        .font(.system(size: 15))
                        .padding(.top, 1)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Volumes must be downloaded first")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Every feature depends on FRUS volumes stored on this device. Each volume is an XML file between 2 – 30 MB. Start by selecting the time periods you need — you can always add more later from the Volumes tab.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
                .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                .padding(.bottom, 8)
            }
            .padding(28)
        }
        .navigationTitle("")
        .toolbar {
            // Skip — allows users who are offline or not ready to dismiss.
            // The sheet reappears on next launch if still no volumes.
            ToolbarItem(placement: .cancellationAction) {
                Button("Skip for Now") { dismiss() }
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    OnboardingStep2()
                } label: {
                    Text("Get Started")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

// MARK: - Feature row

private struct OnboardingFeatureRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(Color.frusRuby)
                .frame(width: 28, alignment: .center)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Step 2 dispatcher (online or offline)

private struct OnboardingStep2: View {
    @Environment(AppStore.self) private var store: AppStore

    var body: some View {
        Group {
            if store.isOnline {
                OnboardingVolumeSelector()
            } else {
                OnboardingOfflinePage()
            }
        }
        // If connectivity changes while the user is on this screen,
        // the Group re-evaluates and the view swaps automatically.
    }
}

// MARK: - Offline page

private struct OnboardingOfflinePage: View {
    @Environment(AppStore.self) private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "wifi.slash")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)

            VStack(spacing: 10) {
                Text("No Internet Connection")
                    .font(.system(.title2, design: .serif))
                    .fontWeight(.semibold)
                Text("FRUS Explorer needs an internet connection to fetch the volume catalogue and download XML files. Please connect to Wi-Fi or a cellular network and try again.\n\nWhen connectivity is restored this screen will update automatically.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if store.isOnline {
                // Connection restored while page is visible — invite forward
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 13, weight: .medium))
            }

            Spacer()

            Button("Close") { dismiss() }
                .buttonStyle(.bordered)
                .controlSize(.large)
        }
        .padding(32)
        .navigationTitle("Connection Required")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
}

// MARK: - Volume selector

struct OnboardingVolumeSelector: View {
    @Environment(AppStore.self) private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPrefixes: Set<String> = []
    @State private var showDownloadAllConfirmation = false

    // MARK: Derived

    private var groups: [OnboardingSeries] {
        makeOnboardingGroups(store.catalogue)
    }

    private var allPrefixes: Set<String> {
        Set(groups.map(\.prefix))
    }

    private var selectedVolumes: [FRUSVolumeInfo] {
        groups
            .filter { selectedPrefixes.contains($0.prefix) }
            .flatMap(\.volumes)
    }

    private var selectedBytes: Int {
        selectedVolumes.reduce(0) { $0 + $1.size }
    }

    private var totalBytes: Int {
        store.catalogue.reduce(0) { $0 + $1.size }
    }

    private func formatted(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            selectorBody
            Divider()
            downloadFooter
        }
        .navigationTitle("Select Volumes")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar { selectorToolbar }
        .confirmationDialog(
            "Download the Entire FRUS Series?",
            isPresented: $showDownloadAllConfirmation,
            titleVisibility: .visible
        ) {
            Button("Download All \(store.catalogue.count) Volumes (\(formatted(totalBytes)))") {
                kickOffDownloads(store.catalogue)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All \(store.catalogue.count) volumes (\(formatted(totalBytes))) will be downloaded. This may take a long time on a slow connection. You can pause individual downloads later from the Volumes tab.")
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var selectorToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Skip for Now") { dismiss() }
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        ToolbarItem(placement: .primaryAction) {
            let allSelected = selectedPrefixes == allPrefixes
            Button(allSelected ? "Deselect All" : "Select All") {
                selectedPrefixes = allSelected ? [] : allPrefixes
            }
            .font(.system(size: 13))
        }
    }

    // MARK: Content

    @ViewBuilder
    private var selectorBody: some View {
        switch store.catalogueState {
        case .idle, .loading:
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading volume catalogue…")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let msg):
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 36))
                    .foregroundStyle(.orange)
                Text("Couldn't load catalogue")
                    .font(.system(.headline, design: .serif))
                Text(msg)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try Again") { Task { await store.loadCatalogue() } }
                    .buttonStyle(.bordered)
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded:
            VStack(spacing: 0) {
                descriptionHeader
                Divider()
                seriesList
            }
        }
    }

    private var descriptionHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("The complete FRUS series spans \(store.catalogue.count) volumes across \(groups.count) subseries — approximately \(formatted(totalBytes)) total. Select the time periods relevant to your research. You can download more volumes later from the Volumes tab.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                showDownloadAllConfirmation = true
            } label: {
                Label(
                    "Download Entire Series (\(formatted(totalBytes)))",
                    systemImage: "arrow.down.circle.fill"
                )
                .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quinary)
    }

    private var seriesList: some View {
        List {
            ForEach(groups) { group in
                seriesRow(group)
            }
        }
        .listStyle(.inset)
    }

    private func seriesRow(_ group: OnboardingSeries) -> some View {
        let selected = selectedPrefixes.contains(group.prefix)
        return HStack(spacing: 12) {
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(selected ? Color.accentColor : Color(white: 0.7))
                .animation(.easeInOut(duration: 0.12), value: selected)

            VStack(alignment: .leading, spacing: 3) {
                Text(group.prefix)
                    .font(.system(.callout, design: .monospaced))
                    .fontWeight(.medium)
                HStack(spacing: 4) {
                    Text("\(group.volumes.count) volume\(group.volumes.count == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("·")
                        .font(.system(size: 11))
                        .foregroundStyle(.quaternary)
                    Text(group.formattedSize)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if selected { selectedPrefixes.remove(group.prefix) }
            else        { selectedPrefixes.insert(group.prefix) }
        }
        .padding(.vertical, 3)
    }

    // MARK: Footer

    private var downloadFooter: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                if selectedVolumes.isEmpty {
                    Text("Select one or more subseries above, or download the entire series.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(selectedVolumes.count) volume\(selectedVolumes.count == 1 ? "" : "s") selected")
                        .font(.system(size: 12, weight: .semibold))
                    Text("≈ \(formatted(selectedBytes))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button("Start Downloading") {
                kickOffDownloads(selectedVolumes)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(selectedVolumes.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
        .overlay(alignment: .top) {
            // Reminder that the sheet will close automatically
            if !selectedVolumes.isEmpty {
                Text("This window closes automatically when your first volume finishes downloading. Additional volumes continue in the background.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .frame(maxWidth: .infinity)
                    .offset(y: -22)
            }
        }
    }

    // MARK: Action

    private func kickOffDownloads(_ volumes: [FRUSVolumeInfo]) {
        // Use the onboarding download path, which starts every volume as an
        // independent Task — no user throttle applied. URLSession + HTTP/2
        // multiplexing on GitHub's CDN naturally bounds actual concurrency.
        store.downloadForOnboarding(volumes)
        // The sheet auto-dismisses via RootView's onChange(of: localVolumeIDs.isEmpty).
    }
}
