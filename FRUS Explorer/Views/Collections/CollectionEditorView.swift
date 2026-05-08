// Views/Collections/CollectionEditorView.swift
// Detail view for a single collection: reorderable item list, annotation editor, PDF export.

import SwiftUI

struct CollectionEditorView: View {
    @Environment(AppStore.self) private var store: AppStore
    @Environment(CollectionStore.self) private var collectionStore: CollectionStore
    @Environment(\.platformViewReference) private var platformRef: PlatformViewReference?

    let collectionID: UUID

    @State private var selectedItemID: UUID?
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var showingExportError = false
    @State private var editingNotes = false
    @State private var draftNotes = ""

    private var collection: DocumentCollection? {
        collectionStore.collections.first { $0.id == collectionID }
    }

    var body: some View {
        if let col = collection {
#if os(macOS)
            // macOS: compact header + HSplitView side-by-side
            VStack(spacing: 0) {
                collectionHeader(col)
                Divider()
                HSplitView {
                    itemListPane(col)
                        .frame(minWidth: 260, idealWidth: 300)
                    annotationPane(col)
                }
            }
            .toolbar { toolbarContent(col) }
            .alert("Export Failed", isPresented: $showingExportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportError ?? "Unknown error.")
            }
#else
            // iPadOS: NavigationSplitView must be the root view.
            // The header is placed as a safeAreaInset on the sidebar column
            // so it stays visible while the split adapts to screen size.
            NavigationSplitView {
                itemListPane(col)
                    .safeAreaInset(edge: .top, spacing: 0) {
                        VStack(spacing: 0) {
                            collectionHeader(col)
                            Divider()
                        }
                        .background(.bar)
                    }
                    .navigationTitle(col.name)
                    .navigationBarTitleDisplayMode(.inline)
            } detail: {
                annotationPane(col)
            }
            .toolbar { toolbarContent(col) }
            .alert("Export Failed", isPresented: $showingExportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportError ?? "Unknown error.")
            }
#endif
        }
    }

    // MARK: - Collection header

    private func collectionHeader(_ col: DocumentCollection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(col.name)
                .font(.system(.title2, design: .serif))
                .fontWeight(.bold)

            HStack(spacing: 14) {
                let itemPlural = col.items.count == 1 ? "" : "s"
                Label("\(col.items.count) item\(itemPlural)",
                      systemImage: "doc.on.doc")
                    .font(.caption).foregroundStyle(.secondary)
                Label(relativeDateString(col.modifiedAt),
                      systemImage: "calendar")
                    .font(.caption).foregroundStyle(.secondary)
            }

            // Collection-level notes
            Group {
                if editingNotes {
                    VStack(alignment: .leading, spacing: 6) {
                        TextEditor(text: $draftNotes)
                            .font(.system(.callout, design: .serif))
                            .frame(height: 64)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                        HStack {
                            Button("Cancel") { editingNotes = false }
                            Button("Save") {
                                collectionStore.updateNotes(col, notes: draftNotes)
                                editingNotes = false
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                } else {
                    if col.notes.isEmpty {
                        Button("Add research notes…") {
                            draftNotes = ""
                            editingNotes = true
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    } else {
                        Text(col.notes)
                            .font(.system(.callout, design: .serif))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .onTapGesture {
                                draftNotes = col.notes
                                editingNotes = true
                            }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }

    // MARK: - Item list pane

    private func itemListPane(_ col: DocumentCollection) -> some View {
        VStack(spacing: 0) {
            List(selection: $selectedItemID) {
                ForEach(col.items) { item in
                    CollectionItemRow(item: item,
                                     isLoaded: store.loadedVolumes[item.volumeID] != nil)
                        .tag(item.id)
                        .contextMenu {
                            Button("Remove from Collection", role: .destructive) {
                                if selectedItemID == item.id { selectedItemID = nil }
                                collectionStore.removeItem(item, from: col)
                            }
                        }
                }
                .onMove { src, dst in
                    collectionStore.moveItems(in: col, from: src, to: dst)
                }
                .onDelete { offsets in
                    offsets.map { col.items[$0] }.forEach {
                        collectionStore.removeItem($0, from: col)
                    }
                }
            }
            .listStyle(.inset)
            .overlay {
                if col.items.isEmpty {
                    ContentUnavailableView(
                        "Empty Collection",
                        systemImage: "plus.rectangle.on.rectangle",
                        description: Text("Right-click a document in the outline view and choose \"Add to Collection\".")
                    )
                }
            }

            Divider()

            HStack {
                let docPlural = col.items.count == 1 ? "" : "s"
                Text("\(col.items.count) document\(docPlural)")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                Text("Drag to reorder")
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
        }
    }

    // MARK: - Annotation pane

    @ViewBuilder
    private func annotationPane(_ col: DocumentCollection) -> some View {
        if let itemID = selectedItemID,
           let item = col.items.first(where: { $0.id == itemID }) {
            CollectionItemDetailView(item: item, collection: col)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "hand.point.left")
                    .font(.title2).foregroundStyle(.tertiary)
                Text("Select an item to edit its annotation or view its metadata.")
                    .font(.callout).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 220)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private func toolbarContent(_ col: DocumentCollection) -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                Task { await runExport(col) }
            } label: {
                if isExporting {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Label("Export PDF", systemImage: "arrow.down.doc")
                }
            }
            .help("Export collection as PDF")
            .disabled(col.items.isEmpty || isExporting)
        }
    }

    // MARK: - Export

    private func runExport(_ col: DocumentCollection) async {
        isExporting = true
        defer { isExporting = false }

        var resolved: [UUID: Division] = [:]
        for item in col.items {
            if let div = collectionStore.resolve(item, in: store.loadedVolumes) {
                resolved[item.id] = div
            }
        }

        await exportCollectionToPDF(
            collection: col,
            resolvedItems: resolved,
            loadedVolumes: store.loadedVolumes,
            presentingView: platformRef ?? PlatformViewReference()
        )
    }

    // MARK: - Helpers

    private func relativeDateString(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        return "Modified \(df.string(from: date))"
    }
}

// MARK: - CollectionItemRow

struct CollectionItemRow: View {
    let item: CollectionItem
    let isLoaded: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.isEditorialNote ? "quote.bubble.fill" : "doc.fill")
                .font(.system(size: 11))
                .foregroundStyle(item.isEditorialNote ? Color.purple : Color.primary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.cachedTitle)
                    .font(.system(.caption, design: .serif))
                    .fontWeight(.medium)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if let dl = item.cachedDateline {
                        Text(dl)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    Text(item.volumeID)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.quaternary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if !isLoaded {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
                    .help("Volume not loaded — full text will be omitted from PDF export")
            }

            if !item.annotation.isEmpty {
                Image(systemName: "pencil.line")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .help("Has annotation")
            }
        }
        .padding(.vertical, 3)
    }
}

// MARK: - CollectionItemDetailView

private struct CollectionItemDetailView: View {
    @Environment(AppStore.self) private var store: AppStore
    @Environment(CollectionStore.self) private var collectionStore: CollectionStore
    @Environment(SummaryStore.self) private var summaryStore: SummaryStore

    let item: CollectionItem
    let collection: DocumentCollection

    @State private var annotationText = ""
    @State private var dirty = false
    @State private var isLoadingVolume = false

    private var availableSummaries: [SummaryRecord] {
        summaryStore.records.filter {
            $0.volumeID == item.volumeID && $0.divisionID == item.divisionID
        }
    }

    private func insertSummary(_ record: SummaryRecord) {
        annotationText = record.text
        dirty = true
    }

    private var resolvedDivision: Division? {
        collectionStore.resolve(item, in: store.loadedVolumes)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Full document content (when volume is loaded)
                if let div = resolvedDivision {
                    FRUSDocumentView(division: div, volumeID: item.volumeID)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 8)
                } else {
                    volumeNotLoadedBanner
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                }

                // Annotation section
                Divider()
                    .padding(.vertical, 16)

                annotationSection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
            }
        }
        .onAppear { annotationText = item.annotation }
        .onChange(of: item.id) { _, _ in
            annotationText = item.annotation
            dirty = false
        }
    }

    // MARK: - Volume not loaded banner

    private var volumeNotLoadedBanner: some View {
        VStack(spacing: 12) {
            Image(systemName: "books.vertical")
                .font(.title2)
                .foregroundStyle(.tertiary)
            VStack(spacing: 4) {
                Text(item.cachedTitle)
                    .font(.system(.headline, design: .serif))
                    .multilineTextAlignment(.center)
                if let dl = item.cachedDateline {
                    Text(dl)
                        .font(.system(.callout, design: .serif))
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }
            Text("Volume \(item.volumeID) is not loaded — document text is unavailable.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task {
                    isLoadingVolume = true
                    await store.loadVolumeByID(item.volumeID)
                    isLoadingVolume = false
                }
            } label: {
                if isLoadingVolume {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Label("Load Volume", systemImage: "arrow.down.circle")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isLoadingVolume)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Annotation editor

    @ViewBuilder
    private var summaryDraftControl: some View {
        if availableSummaries.count == 1, let record = availableSummaries.first {
            Button {
                insertSummary(record)
            } label: {
                Label("Use \(record.profileName) Summary as Draft", systemImage: "text.badge.plus")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
        } else {
            Menu {
                ForEach(availableSummaries) { record in
                    Button(record.profileName) { insertSummary(record) }
                }
            } label: {
                Label("Use Summary as Draft…", systemImage: "text.badge.plus")
                    .font(.system(size: 10))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .foregroundStyle(.tint)
        }
    }

    private var annotationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Research Annotation", systemImage: "pencil.line")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("Annotations appear in the PDF export beneath each document.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            if !availableSummaries.isEmpty {
                summaryDraftControl
            }

            TextEditor(text: $annotationText)
                .font(.system(.callout, design: .serif))
                .frame(minHeight: 90)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.black, lineWidth: 1)
                )
                .onChange(of: annotationText) { _, _ in dirty = true }

            if dirty {
                HStack {
                    Spacer()
                    Button("Save") {
                        collectionStore.updateAnnotation(item, in: collection, annotation: annotationText)
                        dirty = false
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
    }
}
