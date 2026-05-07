// Views/SearchView.swift
// Cross-volume search panel shown in the outline column.
// Supports the full query language defined in SearchEngine.swift plus a date-range picker.

import SwiftUI
import FRUSKit

// MARK: - SearchView

struct SearchView: View {
    @Environment(AppStore.self) private var store: AppStore
    @Environment(CollectionStore.self) private var collectionStore: CollectionStore

    @State private var query: String = ""
    @State private var showDateFilter = false
    @State private var dateFromEnabled = false
    @State private var dateFrom = Calendar.current.date(from: DateComponents(year: 1960))!
    @State private var dateToEnabled = false
    @State private var dateTo = Date()
    @State private var debounceTask: Task<Void, Never>? = nil

    private var hasDateFilter: Bool { dateFromEnabled || dateToEnabled }

    var body: some View {
        VStack(spacing: 0) {
            queryBar
            if showDateFilter {
                dateFilterPanel
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Divider()
            resultsArea
        }
        .animation(.easeInOut(duration: 0.18), value: showDateFilter)
        .onDisappear { store.searchResults = [] }
    }

    // MARK: - Query bar

    private var queryBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 12))

            TextField("Keywords, \"phrase\", person:Name, term:MIRV…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(.callout, design: .monospaced))
                .onSubmit { triggerSearch() }
                .onChange(of: query) { _, _ in scheduleSearch() }

            if !query.isEmpty {
                Button {
                    query = ""
                    store.searchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Button {
                withAnimation { showDateFilter.toggle() }
            } label: {
                Image(systemName: hasDateFilter ? "calendar.badge.checkmark" : "calendar")
                    .font(.system(size: 13))
                    .foregroundStyle(hasDateFilter ? .accent : .secondary)
            }
            .buttonStyle(.plain)
            .help("Filter by date range")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.quinary)
    }

    // MARK: - Date filter panel

    private var dateFilterPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Date Range")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
                Spacer()
                if hasDateFilter {
                    Button("Clear") {
                        dateFromEnabled = false
                        dateToEnabled = false
                        triggerSearch()
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.accent)
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 16) {
                dateToggleRow(
                    label: "From",
                    enabled: $dateFromEnabled,
                    date: $dateFrom
                )
                dateToggleRow(
                    label: "To",
                    enabled: $dateToEnabled,
                    date: $dateTo
                )
            }

            Text("Also supported inline: date:1969, after:1969-06, before:1970, date:1969..1972")
                .font(.system(size: 9))
                .foregroundStyle(.quaternary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.quinary.opacity(0.6))
        .onChange(of: dateFromEnabled) { _, _ in triggerSearch() }
        .onChange(of: dateToEnabled)   { _, _ in triggerSearch() }
        .onChange(of: dateFrom)        { _, _ in if dateFromEnabled { triggerSearch() } }
        .onChange(of: dateTo)          { _, _ in if dateToEnabled   { triggerSearch() } }
    }

    @ViewBuilder
    private func dateToggleRow(
        label: String, enabled: Binding<Bool>, date: Binding<Date>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(label, isOn: enabled)
                .font(.system(size: 11))
                .toggleStyle(.checkbox)
            DatePicker("", selection: date, displayedComponents: .date)
                .labelsHidden()
                .controlSize(.small)
                .disabled(!enabled.wrappedValue)
                .opacity(enabled.wrappedValue ? 1 : 0.4)
        }
    }

    // MARK: - Results area

    @ViewBuilder
    private var resultsArea: some View {
        if store.isSearching {
            loadingView
        } else if query.trimmingCharacters(in: .whitespaces).isEmpty && !hasDateFilter {
            placeholderView
        } else if store.searchResults.isEmpty {
            ContentUnavailableView(
                "No Results",
                systemImage: "magnifyingglass",
                description: Text("Try different keywords, broaden your date range, or check query syntax.")
            )
        } else {
            resultsList
        }
    }

    private var loadingView: some View {
        HStack(spacing: 8) {
            ProgressView().scaleEffect(0.7)
            Text("Searching…")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var placeholderView: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            VStack(spacing: 5) {
                Text("Search all downloaded volumes")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Group {
                    Text("AND · OR · NOT  /  \"exact phrase\"  /  wild* ")
                    + Text("  person:Name  ·  term:MIRV  ·  place:Saigon")
                    + Text("  date:1969  ·  date:1968..1972  ·  after:1969-06")
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.quaternary)
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 230)

            if !store.loadedVolumes.isEmpty {
                indexedVolumesBadge
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var indexedVolumesBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "books.vertical.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(store.loadedVolumes.count) volume\(store.loadedVolumes.count == 1 ? "" : "s") indexed")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.quinary, in: Capsule())
    }

    private var resultsList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(store.searchResults.count) result\(store.searchResults.count == 1 ? "" : "s")")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Most recent first")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.bar)

            Divider()

            List(store.searchResults) { result in
                SearchResultRow(result: result)
                    .onTapGesture { selectResult(result) }
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Actions

    private func scheduleSearch() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            triggerSearch()
        }
    }

    private func triggerSearch() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty || hasDateFilter else {
            store.searchResults = []
            return
        }
        let df = buildDateFilter()
        let annotations = collectionStore.allAnnotations
        Task { await store.runSearch(query: q, dateFilter: df, annotations: annotations) }
    }

    private func buildDateFilter() -> DateFilter? {
        guard hasDateFilter else { return nil }
        var df = DateFilter()
        let cal = Calendar.current
        if dateFromEnabled {
            df.from = .full(
                cal.component(.year,  from: dateFrom),
                cal.component(.month, from: dateFrom),
                cal.component(.day,   from: dateFrom)
            )
        }
        if dateToEnabled {
            df.to = .full(
                cal.component(.year,  from: dateTo),
                cal.component(.month, from: dateTo),
                cal.component(.day,   from: dateTo)
            )
        }
        return df
    }

    private func selectResult(_ result: SearchResult) {
        let volID  = result.record.volumeID
        let nodeID = result.record.id
        if store.loadedVolumes[volID] != nil {
            store.selectedVolumeID = volID
            store.selectedNodeID   = nodeID
        } else {
            Task {
                await store.loadVolumeByID(volID)
                store.selectedNodeID = nodeID
            }
        }
    }
}

// MARK: - SearchResultRow

struct SearchResultRow: View {
    let result: SearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(result.record.title)
                .font(.system(.caption, design: .serif))
                .fontWeight(.medium)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let dl = result.record.dateline, !dl.isEmpty {
                Text(dl)
                    .font(.system(size: 10, design: .serif))
                    .foregroundStyle(.secondary)
                    .italic()
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                Text(result.record.volumeID)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.quaternary)
                    .lineLimit(1)

                Spacer()

                let sortedFields = result.matchedFields
                    .sorted { $0.sortOrder < $1.sortOrder }
                ForEach(sortedFields, id: \.self) { matchChip($0) }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func matchChip(_ field: SearchResult.MatchField) -> some View {
        HStack(spacing: 2) {
            Image(systemName: field.icon).font(.system(size: 7))
            Text(field.label).font(.system(size: 8, weight: .medium))
        }
        .foregroundStyle(field.tint)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(field.tint.opacity(0.12), in: Capsule())
    }
}

// MARK: - MatchField display

extension SearchResult.MatchField {
    var icon: String {
        switch self {
        case .title:      return "textformat"
        case .body:       return "text.alignleft"
        case .person:     return "person"
        case .place:      return "mappin"
        case .org:        return "building.2"
        case .term:       return "ellipsis.curlybraces"
        case .summary:    return "sparkles"
        case .annotation: return "pencil.line"
        case .date:       return "calendar"
        }
    }

    var label: String {
        switch self {
        case .title:      return "Title"
        case .body:       return "Text"
        case .person:     return "Person"
        case .place:      return "Place"
        case .org:        return "Org"
        case .term:       return "Term"
        case .summary:    return "Summary"
        case .annotation: return "Note"
        case .date:       return "Date"
        }
    }

    var tint: Color {
        switch self {
        case .title:      return .primary
        case .body:       return .blue
        case .person:     return .purple
        case .place:      return .green
        case .org:        return .orange
        case .term:       return .teal
        case .summary:    return .indigo
        case .annotation: return .brown
        case .date:       return .red
        }
    }

    var sortOrder: Int {
        switch self {
        case .title: return 0; case .body: return 1; case .person: return 2
        case .place: return 3; case .org:  return 4; case .term:   return 5
        case .summary: return 6; case .annotation: return 7; case .date: return 8
        }
    }
}
