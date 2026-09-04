// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import SwiftUI
import SwiftData

// MARK: - ClassificationCorrectionsSheet

/// The document-classification corrections manager (#279 / W-4): every reclassification the
/// user has made — a document asserted to be an editorial note, or the reverse — with a
/// per-row Undo that removes the override and restores FRUS's own value in the index.
/// Settings ▸ Search opens it.
///
/// Follows `PersonCorrectionsSheet`'s hard-won shape: rows hold VALUE snapshots, never the
/// live CloudKit-synced `@Model` (another device can delete an override while this sheet is
/// open, leaving a dangling managed object); Undo re-fetches by `id` at action time and
/// treats a miss as already-undone elsewhere.
///
/// Each row labels the document by its cached header when the volume is indexed here, and
/// falls back to the raw `volumeId · documentId` anchor when it is not — an override for an
/// un-indexed volume is real (it will reactivate when the volume indexes) and must not be
/// hidden or rendered blank.
///
/// Version history:
///   1.0 — W-4 (#279): initial implementation
struct ClassificationCorrectionsSheet: View {

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// One resolved correction row — a value snapshot (see the type doc for why).
    private struct CorrectionRow: Identifiable {
        /// The override's stable model `id`, for the undo-time re-fetch.
        let id: UUID
        /// The document's label: its cached header, or the raw anchor.
        let title: String
        /// Prose describing the correction's direction.
        let direction: String
        /// The correction date, formatted, or `nil`.
        let dateText: String?
    }

    @State private var rows: [CorrectionRow] = []
    @State private var isLoading = true
    @State private var isBusy = false

    var body: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            HStack {
                Text(String(localized: "classification.corrections.title",
                            defaultValue: "Classification Corrections"))
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 12)
            Divider()
            content
            Divider()
            HStack {
                Spacer()
                Button(String(localized: "common.done", defaultValue: "Done")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
        }
        .frame(minWidth: 420, minHeight: 420)
        .task { await load() }
        #else
        NavigationStack {
            content
                .navigationTitle(String(localized: "classification.corrections.title",
                                        defaultValue: "Classification Corrections"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "common.done", defaultValue: "Done")) { dismiss() }
                    }
                }
        }
        .task { await load() }
        #endif
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if rows.isEmpty {
            ContentUnavailableView(
                String(localized: "classification.corrections.empty.title",
                       defaultValue: "No Corrections"),
                systemImage: "arrow.uturn.backward.circle",
                description: Text(String(localized: "classification.corrections.empty.detail",
                    defaultValue: "Documents you reclassify from the Research panel appear here, where you can restore FRUS's own classification."))
            )
        } else {
            List {
                Section {
                    ForEach(rows) { row in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.title).font(.body).lineLimit(2)
                                Text(row.direction).font(.caption).foregroundStyle(.secondary)
                                if let dateText = row.dateText {
                                    Text(dateText).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button(role: .destructive) {
                                Task { await undo(id: row.id) }
                            } label: {
                                Text(String(localized: "classification.corrections.undo",
                                            defaultValue: "Undo"))
                            }
                            .buttonStyle(.borderless)
                            .disabled(isBusy)
                            .accessibilityLabel(String(format: String(
                                localized: "classification.corrections.undo.a11y %@",
                                defaultValue: "Undo: %@"), row.title))
                        }
                    }
                } footer: {
                    Text(String(localized: "classification.corrections.footer",
                        defaultValue: "Undoing a correction restores FRUS's own classification and syncs across your devices. A correction for a volume not indexed on this device takes effect when the volume is indexed."))
                }
            }
            #if os(macOS)
            .listStyle(.inset)
            #endif
        }
    }

    // MARK: - Data

    private func load() async {
        let overrides = DocumentClassificationOverrideStore.fetchAll(context: modelContext)
        let pipeline = appState.indexingPipeline
        var built: [CorrectionRow] = []
        for override in overrides {
            let header = try? await pipeline?.documentHeader(
                volumeId: override.volumeId, documentId: override.documentId)
            let title = (header ?? nil) ?? "\(override.volumeId) · \(override.documentId)"
            let direction = override.isEditorialNote
                ? String(localized: "classification.corrections.row.toNote",
                         defaultValue: "Reclassified as an editorial note")
                : String(localized: "classification.corrections.row.toDocument",
                         defaultValue: "Reclassified as a document")
            built.append(CorrectionRow(
                id: override.id, title: title, direction: direction,
                dateText: override.createdAt.map { Self.dateFormatter.string(from: $0) }))
        }
        rows = built
        isLoading = false
    }

    /// Undoes the correction with the given model `id`: re-fetches the live override at
    /// action time (a sync from another device may have deleted it — a miss is treated as
    /// already-undone), removes it, and restores the index column through the store's
    /// shared persist-and-apply tail.
    private func undo(id: UUID) async {
        guard let pipeline = appState.indexingPipeline else { return }
        isBusy = true
        defer { isBusy = false }
        let descriptor = FetchDescriptor<DocumentClassificationOverride>(
            predicate: #Predicate { $0.id == id })
        guard let override = (try? modelContext.fetch(descriptor))?.first else {
            await load()
            return
        }
        AccessibilityNotification.Announcement(
            String(localized: "classification.corrections.undo.inProgress",
                   defaultValue: "Restoring FRUS's classification…")).post()
        // R-5 P3b-5 (design Q-11 i): restore FRUS's CURRENT classification, not the one recorded
        // when the correction was made. The stored `parsedIsEditorialNote` is frozen at override
        // time and never refreshed, so if the Office of the Historian has since fixed the same
        // mistag, this button wrote the OLD parse back into the index and called it "Restore
        // FRUS's Classification". Falls back to the stored value when the volume is not on this
        // device, which is today's behaviour and the ordinary case here.
        //
        // VALUES ACROSS THE AWAIT, AND A RE-FETCH AFTER IT. The parse reads a file, so it suspends
        // — and this type's whole shape (see its doc comment) is that Undo re-fetches by id at
        // action time, because another device can delete the override while the sheet is open.
        // Holding the live `@Model` across the suspension would be the one place that rule is
        // broken, and the window is now seconds wide rather than instantaneous.
        let frozen = override.snapshot
        let live = await DocumentClassificationOverrideStore.liveParsedIsEditorialNote(
            volumeId: frozen.volumeId,
            documentId: frozen.documentId,
            volumeURL: appState.downloadManager?.volumeURL(for: frozen.volumeId))
        guard let current = (try? modelContext.fetch(descriptor))?.first else {
            await load()
            return
        }
        let restore = DocumentClassificationOverrideData(
            volumeId: frozen.volumeId,
            documentId: frozen.documentId,
            isEditorialNote: frozen.isEditorialNote,
            parsedIsEditorialNote: live ?? frozen.parsedIsEditorialNote)
        DocumentClassificationOverrideStore.remove(current, context: modelContext)
        await DocumentClassificationOverrideStore.saveAndApply(
            context: modelContext, pipeline: pipeline, restoring: restore)
        AccessibilityNotification.Announcement(
            String(localized: "classification.corrections.undo.done",
                   defaultValue: "Classification restored")).post()
        await load()
    }

    /// Shared medium-date formatter for the correction timestamps.
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}
