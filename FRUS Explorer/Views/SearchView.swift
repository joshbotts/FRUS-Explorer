// Views/SearchView.swift
// Cross-volume search panel shown in the outline column.
// Each search dimension has its own field; a Search button builds and runs
// the combined query. A help sheet explains every field type.

import SwiftUI

// MARK: - SearchView

struct SearchView: View {
    @Environment(AppStore.self) private var store: AppStore
    @Environment(CollectionStore.self) private var collectionStore: CollectionStore
    @Environment(TaxonomyStore.self) private var taxonomyStore: TaxonomyStore

    // ── Query parameters ──────────────────────────────────────────────────
    @State private var keywords:     String = ""
    @State private var personQuery:  String = ""
    @State private var placeQuery:   String = ""
    @State private var orgQuery:     String = ""
    @State private var termQuery:    String = ""

    // ── Date filter ───────────────────────────────────────────────────────
    @State private var dateFromEnabled = false
    @State private var dateFrom = Calendar.current.date(from: DateComponents(year: 1960))!
    @State private var dateToEnabled   = false
    @State private var dateTo          = Date()

    // ── Subject filter ────────────────────────────────────────────────────
    @State private var subjectFilter:    Set<String> = []
    @State private var showSubjectPicker = false

    // ── Citation navigator ────────────────────────────────────────────────
    @State private var citSubseriesID  = ""   // selected subseries prefix
    @State private var citVolumeID     = ""   // selected volume ID
    @State private var citDocNumber    = ""   // document @n value (e.g. "337")
    @State private var citIsNavigating = false
    @State private var citNotFound     = false

    // ── UI state ──────────────────────────────────────────────────────────
    @State private var showHelp      = false
    @State private var hasRunSearch  = false

    // ── Citation navigator — derived ──────────────────────────────────────

    /// All unique subseries prefixes in alphabetical order.
    private var citSubseriesList: [String] {
        Array(Set(store.catalogue.map { subseriesPrefix(from: $0.id) })).sorted()
    }

    /// Volumes belonging to the currently selected subseries.
    private var citVolumeList: [FRUSVolumeInfo] {
        guard !citSubseriesID.isEmpty else { return [] }
        return store.catalogue.filter { subseriesPrefix(from: $0.id) == citSubseriesID }
    }

    /// True when all three citation fields have a value.
    private var citCanGo: Bool {
        !citSubseriesID.isEmpty
        && !citVolumeID.isEmpty
        && !citDocNumber.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // ── Derived ───────────────────────────────────────────────────────────

    private var hasAnyInput: Bool {
        [keywords, personQuery, placeQuery, orgQuery, termQuery]
            .contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        || dateFromEnabled || dateToEnabled || !subjectFilter.isEmpty
    }

    private var canClear: Bool { hasAnyInput || !store.searchResults.isEmpty }

    // ── Body ──────────────────────────────────────────────────────────────

    var body: some View {
        VStack(spacing: 0) {
            formArea
            Divider()
            resultsArea
        }
        .sheet(isPresented: $showSubjectPicker) {
            SubjectPickerSheet(selectedIDs: $subjectFilter)
                .environment(taxonomyStore)
        }
        .sheet(isPresented: $showHelp) {
            SearchHelpSheet()
        }
        .onDisappear { store.searchResults = [] }
    }

    // MARK: - Form area

    private var formArea: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    keywordsSection
                    entitySection
                    dateSection
                    subjectSection
                    Divider()
                    citationSection
                }
                .padding(12)
            }

            Divider()

            // Sticky action bar — always visible without scrolling
            HStack(spacing: 10) {
                if canClear {
                    Button("Clear") { clearAll() }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .font(.system(size: 11))
                }
                Spacer()
                Button {
                    showHelp = true
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Search guide")

                Button(action: runSearch) {
                    Label("Search", systemImage: "magnifyingglass")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!hasAnyInput)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }

    // MARK: - Keywords

    private var keywordsSection: some View {
        searchSection(label: "Keywords") {
            TextField("Terms, \"exact phrase\", wild*, AND / OR / NOT…", text: $keywords)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
                .onSubmit { runSearch() }
        }
    }

    // MARK: - Named entity fields

    private var entitySection: some View {
        searchSection(label: "Named Entities") {
            VStack(spacing: 6) {
                entityRow(label: "Person", text: $personQuery, placeholder: "e.g. Kissinger")
                entityRow(label: "Place",  text: $placeQuery,  placeholder: "e.g. Saigon")
                entityRow(label: "Org",    text: $orgQuery,    placeholder: "e.g. NATO")
                entityRow(label: "Term",   text: $termQuery,   placeholder: "e.g. MIRV")
            }
        }
    }

    private func entityRow(
        label: String,
        text: Binding<String>,
        placeholder: String
    ) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .trailing)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                .onSubmit { runSearch() }
        }
    }

    // MARK: - Date range

    private var dateSection: some View {
        searchSection(label: "Date Range") {
            HStack(alignment: .top, spacing: 16) {
                datePickerRow(label: "From", enabled: $dateFromEnabled, date: $dateFrom)
                datePickerRow(label: "To",   enabled: $dateToEnabled,   date: $dateTo)
            }
        }
    }

    private func datePickerRow(
        label: String,
        enabled: Binding<Bool>,
        date: Binding<Date>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(label, isOn: enabled)
                .font(.system(size: 11))
#if os(macOS)
                .toggleStyle(.checkbox)
#endif
            DatePicker("", selection: date, displayedComponents: .date)
                .labelsHidden()
                .controlSize(.small)
                .disabled(!enabled.wrappedValue)
                .opacity(enabled.wrappedValue ? 1 : 0.4)
        }
    }

    // MARK: - Subject filter

    private var subjectSection: some View {
        searchSection(label: "Subjects") {
            VStack(alignment: .leading, spacing: 8) {
                if !subjectFilter.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(subjectFilter), id: \.self) { id in
                                if let subject = taxonomyStore.subjectsByID[id] {
                                    HStack(spacing: 3) {
                                        Text(subject.name)
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundStyle(Color.frusRuby)
                                        Button {
                                            subjectFilter.remove(id)
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 7, weight: .bold))
                                                .foregroundStyle(Color.frusRuby.opacity(0.7))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.frusRuby.opacity(0.10), in: Capsule())
                                    .overlay(Capsule().strokeBorder(Color.frusRuby.opacity(0.25),
                                                                    lineWidth: 0.5))
                                }
                            }
                        }
                    }
                }
                Button {
                    showSubjectPicker = true
                } label: {
                    Label(subjectFilter.isEmpty ? "Choose Subjects…" : "Edit Subjects…",
                          systemImage: "tag")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(subjectFilter.isEmpty ? .secondary : Color.frusRuby)
                .disabled(!taxonomyStore.isLoaded)
            }
        }
    }

    // MARK: - Citation Navigator

    private var citationSection: some View {
        searchSection(label: "Citation Navigator") {
            VStack(alignment: .leading, spacing: 8) {
                // ── Subseries picker ──────────────────────────────────────
                Picker(selection: $citSubseriesID) {
                    Text("Select Subseries…")
                        .foregroundStyle(.secondary)
                        .tag("")
                    ForEach(citSubseriesList, id: \.self) { prefix in
                        Text(subseriesLabel(from: prefix))
                            .tag(prefix)
                    }
                } label: {
                    Text("Subseries")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 56, alignment: .trailing)
                }
                .pickerStyle(.menu)
                .onChange(of: citSubseriesID) {
                    citVolumeID  = ""
                    citNotFound  = false
                }

                // ── Volume picker ─────────────────────────────────────────
                Picker(selection: $citVolumeID) {
                    Text("Select Volume…")
                        .foregroundStyle(.secondary)
                        .tag("")
                    ForEach(citVolumeList, id: \.id) { vol in
                        Text(volumeShortLabel(for: vol.id,
                                              titleCache: store.volumeTitleCache))
                            .tag(vol.id)
                    }
                } label: {
                    Text("Volume")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 56, alignment: .trailing)
                }
                .pickerStyle(.menu)
                .disabled(citSubseriesID.isEmpty)
                .onChange(of: citVolumeID) { citNotFound = false }

                // ── Document number + Go ──────────────────────────────────
                HStack(spacing: 6) {
                    Text("Doc #")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 56, alignment: .trailing)

                    TextField("e.g. 337", text: $citDocNumber)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(maxWidth: 80)
                        .onChange(of: citDocNumber) { citNotFound = false }
                        .onSubmit { if citCanGo { Task { await goToDocument() } } }

                    if citIsNavigating {
                        ProgressView().scaleEffect(0.6)
                    } else {
                        Button {
                            Task { await goToDocument() }
                        } label: {
                            Label("Go", systemImage: "arrow.right.circle.fill")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(!citCanGo)
                    }
                }

                // ── Error feedback ────────────────────────────────────────
                if citNotFound {
                    Label("Document \(citDocNumber) not found in this volume.",
                          systemImage: "exclamationmark.triangle")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    // MARK: - Section wrapper

    private func searchSection<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.5)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            content()
        }
    }

    // MARK: - Results area

    @ViewBuilder
    private var resultsArea: some View {
        if store.isSearching {
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.7)
                Text("Searching…")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !hasRunSearch {
            placeholderView
        } else if store.searchResults.isEmpty {
            ContentUnavailableView(
                "No Results",
                systemImage: "magnifyingglass",
                description: Text("Try different keywords, broaden the date range, or adjust your filters.")
            )
        } else {
            resultsList
        }
    }

    private var placeholderView: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("Fill in one or more fields above, then tap Search.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 200)

            if !store.loadedVolumes.isEmpty {
                indexedVolumesBadge
            }

            if store.isReindexingAll {
                loadAllProgressView
            } else if unloadedLocalCount > 0 {
                loadAllBanner
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var unloadedLocalCount: Int {
        store.localVolumeIDs.subtracting(Set(store.loadedVolumes.keys)).count
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

    private var loadAllBanner: some View {
        VStack(spacing: 6) {
            Text("\(unloadedLocalCount) downloaded volume\(unloadedLocalCount == 1 ? "" : "s") not yet indexed")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await store.reindexAllDownloadedVolumes() }
            } label: {
                Label("Load All Downloaded Volumes", systemImage: "arrow.down.circle")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.top, 4)
    }

    private var loadAllProgressView: some View {
        let (current, total) = store.reindexAllProgress
        return VStack(spacing: 6) {
            ProgressView(value: total > 0 ? Double(current) / Double(total) : 0)
                .progressViewStyle(.linear)
                .frame(maxWidth: 180)
            Text("Loading volumes… \(current) / \(total)")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
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

    private func runSearch() {
        let q = buildQueryString()
        guard !q.isEmpty || dateFromEnabled || dateToEnabled || !subjectFilter.isEmpty else {
            return
        }
        hasRunSearch = true
        let df          = buildDateFilter()
        let sf          = subjectFilter
        let annotations = collectionStore.allAnnotations
        Task { await store.runSearch(query: q, dateFilter: df, subjectFilter: sf, annotations: annotations) }
    }

    private func clearAll() {
        keywords    = ""
        personQuery = ""
        placeQuery  = ""
        orgQuery    = ""
        termQuery   = ""
        dateFromEnabled = false
        dateToEnabled   = false
        subjectFilter.removeAll()
        store.searchResults = []
        hasRunSearch = false
    }

    /// Assembles the engine query string from the keyword and entity fields.
    /// Entity values that contain spaces are quoted so the parser treats them
    /// as a single field argument rather than separate keywords.
    private func buildQueryString() -> String {
        var parts: [String] = []
        let kw = keywords.trimmingCharacters(in: .whitespaces)
        if !kw.isEmpty { parts.append(kw) }
        for (field, raw) in [("person", personQuery), ("place", placeQuery),
                              ("org",    orgQuery),    ("term",  termQuery)] {
            let v = raw.trimmingCharacters(in: .whitespaces)
            guard !v.isEmpty else { continue }
            parts.append(v.contains(" ") ? "\(field):\"\(v)\"" : "\(field):\(v)")
        }
        return parts.joined(separator: " ")
    }

    private func buildDateFilter() -> DateFilter? {
        guard dateFromEnabled || dateToEnabled else { return nil }
        var df  = DateFilter()
        let cal = Calendar.current
        if dateFromEnabled {
            df.from = .full(cal.component(.year,  from: dateFrom),
                            cal.component(.month, from: dateFrom),
                            cal.component(.day,   from: dateFrom))
        }
        if dateToEnabled {
            df.to = .full(cal.component(.year,  from: dateTo),
                          cal.component(.month, from: dateTo),
                          cal.component(.day,   from: dateTo))
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

    // MARK: - Citation navigation

    @MainActor
    private func goToDocument() async {
        let volID  = citVolumeID
        let docNum = citDocNumber.trimmingCharacters(in: .whitespaces)
        guard !volID.isEmpty, !docNum.isEmpty else { return }

        citIsNavigating = true
        citNotFound     = false

        // Load the volume if it isn't already in memory.
        if store.loadedVolumes[volID] == nil {
            await store.loadVolumeByID(volID)
        }

        guard let loaded = store.loadedVolumes[volID],
              let divID  = findDocumentByNumber(docNum, in: loaded.volume) else {
            citNotFound     = true
            citIsNavigating = false
            return
        }

        store.navigate(to: divID, in: volID)
        citIsNavigating = false
    }

    /// Searches all divisions (front, body, back) for a document whose `@n` matches `number`.
    private func findDocumentByNumber(_ number: String, in volume: FRUSVolume) -> String? {
        let allDivisions = (volume.text.front?.divisions ?? [])
                         + volume.text.body.divisions
                         + (volume.text.back?.divisions ?? [])
        return searchDivisions(allDivisions, for: number)
    }

    private func searchDivisions(_ divisions: [Division], for number: String) -> String? {
        for div in divisions {
            if div.type == .document, div.number == number, let xmlID = div.id {
                return xmlID
            }
            if let found = searchDivisions(div.children, for: number) {
                return found
            }
        }
        return nil
    }
}

// MARK: - SearchHelpSheet

struct SearchHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                helpSection(
                    icon: "text.magnifyingglass", iconColor: .blue,
                    title: "Keywords",
                    items: [
                        HelpItem("Basic",    "Enter one or more words to match anywhere in a document's title, body text, or entity lists."),
                        HelpItem("Phrase",   "Wrap in double quotes for an exact match: \"national security council\""),
                        HelpItem("Wildcard", "Append * for prefix matching: diplo* matches diplomat, diplomacy, diplomatic…"),
                        HelpItem("Require",  "AND is the default between words — both must appear: Vietnam policy"),
                        HelpItem("Either",   "OR returns documents matching either term: Nixon OR Kissinger"),
                        HelpItem("Exclude",  "NOT removes documents containing a word: Cuba NOT crisis"),
                    ]
                )

                helpSection(
                    icon: "person.text.rectangle", iconColor: .purple,
                    title: "Named Entities",
                    items: [
                        HelpItem("Person", "Matches names tagged as persons in document text — e.g. Kissinger"),
                        HelpItem("Place",  "Matches location names tagged in document text — e.g. Saigon"),
                        HelpItem("Org",    "Matches organization names — e.g. NATO, NSC, Politburo"),
                        HelpItem("Term",   "Matches defined terms, weapons systems, treaties, and technical vocabulary — e.g. MIRV, SALT"),
                    ],
                    note: "Entity fields search the tagged entity lists extracted by the TEI markup, not free-running prose. A document that mentions 'Kissinger' in untagged text will not match a Person search."
                )

                helpSection(
                    icon: "calendar", iconColor: .red,
                    title: "Date Range",
                    items: [
                        HelpItem("From", "Exclude documents dated before this date"),
                        HelpItem("To",   "Exclude documents dated after this date"),
                    ],
                    note: "Dates correspond to when the document was written or sent, not when it was published in FRUS. Enabling only From returns everything from that date forward; only To returns everything up to that date."
                )

                helpSection(
                    icon: "tag", iconColor: Color.frusRuby,
                    title: "Subjects",
                    items: [
                        HelpItem("Choosing",   "Tap 'Choose Subjects' to browse the subject taxonomy and select one or more tags."),
                        HelpItem("Multiple",   "Selecting several subjects returns documents matching any one of them."),
                        HelpItem("Scope",      "Only documents from currently loaded volumes carry subject tags."),
                    ],
                    note: "Subject tags are assigned by the Office of the Historian and reflect the main topics of each document. They cannot be entered as free text — use the picker."
                )

                helpSection(
                    icon: "arrow.triangle.merge", iconColor: .green,
                    title: "Combining Fields",
                    items: [
                        HelpItem("AND logic", "Every active field must match. A document appears only if it satisfies the keywords, every entity field, the date range, and at least one selected subject."),
                        HelpItem("Empty fields", "Leaving a field blank places no restriction on that dimension — it is simply ignored."),
                    ]
                )
            }
#if os(macOS)
            .listStyle(.inset)
#else
            .listStyle(.insetGrouped)
#endif
            .navigationTitle("Search Guide")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Help section builder

    private struct HelpItem {
        let label: String
        let description: String
        init(_ label: String, _ description: String) {
            self.label = label
            self.description = description
        }
    }

    @ViewBuilder
    private func helpSection(
        icon: String,
        iconColor: Color,
        title: String,
        items: [HelpItem],
        note: String? = nil
    ) -> some View {
        Section {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(item.description)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 2)
            }
            if let note {
                Text(note)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 4)
                    .listRowBackground(Color.secondary.opacity(0.06))
            }
        } header: {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(iconColor)
                .textCase(nil)
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

// MARK: - SubjectPickerSheet

/// A full-screen sheet for selecting subject taxonomy filters.
/// Subjects are listed by category → subcategory with a live search bar for narrowing.
struct SubjectPickerSheet: View {
    @Environment(TaxonomyStore.self) private var taxonomyStore: TaxonomyStore
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIDs: Set<String>

    @State private var searchText = ""

    private var filteredCategories: [TaxonomyCategory] {
        guard !searchText.isEmpty else { return taxonomyStore.categories }
        let q = searchText.lowercased()
        return taxonomyStore.categories.compactMap { cat in
            let matchingSubs = cat.subcategories.compactMap { sub -> TaxonomySubcategory? in
                let matchingSubjects = sub.subjects.filter { s in
                    s.name.lowercased().contains(q)
                    || s.variants.contains { $0.lowercased().contains(q) }
                }
                return matchingSubjects.isEmpty ? nil
                    : TaxonomySubcategory(label: sub.label,
                                          annotationCount: sub.annotationCount,
                                          subjects: matchingSubjects)
            }
            return matchingSubs.isEmpty ? nil
                : TaxonomyCategory(label: cat.label,
                                   annotationCount: cat.annotationCount,
                                   subcategories: matchingSubs)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if taxonomyStore.categories.isEmpty {
                    ContentUnavailableView("Taxonomy Loading", systemImage: "tag",
                        description: Text("Subject index is still loading. Please try again in a moment."))
                } else {
                    List {
                        ForEach(filteredCategories) { category in
                            Section(header: categoryHeader(category)) {
                                ForEach(category.subcategories, id: \.label) { sub in
                                    ForEach(sub.subjects) { subject in
                                        subjectRow(subject)
                                    }
                                }
                            }
                        }
                    }
#if os(macOS)
                    .listStyle(.inset)
#else
                    .listStyle(.insetGrouped)
#endif
                }
            }
            .searchable(text: $searchText, prompt: "Search subjects…")
            .navigationTitle("Filter by Subject")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                if !selectedIDs.isEmpty {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Clear") { selectedIDs.removeAll() }
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }

    private func categoryHeader(_ category: TaxonomyCategory) -> some View {
        HStack {
            Text(category.label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.3)
            Spacer()
            Text("\(category.annotationCount.formattedWithCommas) documents")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
    }

    private func subjectRow(_ subject: TaxonomySubject) -> some View {
        let isSelected = selectedIDs.contains(subject.id)
        return Button {
            if isSelected {
                selectedIDs.remove(subject.id)
            } else {
                selectedIDs.insert(subject.id)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? Color.frusRuby : Color.frusAmber)

                VStack(alignment: .leading, spacing: 2) {
                    Text(subject.name)
                        .font(.system(.callout, design: .serif))
                        .foregroundStyle(.primary)
                    Text("\(subject.annotationCount.formattedWithCommas) documents · \(subject.volumeCount) volumes")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                SubjectChip(subject: subject)
            }
        }
        .buttonStyle(.plain)
    }
}

extension Int {
    fileprivate var formattedWithCommas: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
