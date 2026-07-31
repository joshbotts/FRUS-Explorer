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

import SwiftData
import SwiftUI

// MARK: - WorkingCorporaView

/// Manages named working corpora — the document-grain scope (M-1).
///
/// The sibling of `CustomScopesView`, and deliberately its twin in shape: a `@Query`-driven list,
/// rename in place, swipe or menu to delete. The two are one family in Settings because they are
/// the same idea at two grains, and a researcher who has learned one should not have to learn the
/// other.
///
/// There is **no "new" button**. A working corpus is captured from a result set — a name with no
/// documents is not a corpus, and offering to create an empty one would invite exactly that. The
/// empty state says where they come from instead.
///
/// Version history:
///   1.0 — M-1: initial implementation
struct WorkingCorporaView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkingCorpus.name) private var corpora: [WorkingCorpus]

    @State private var renaming: WorkingCorpus?
    @State private var draftName = ""

    var body: some View {
        List {
            if corpora.isEmpty {
                Section {
                    ContentUnavailableView(
                        String(localized: "corpora.empty.title", defaultValue: "No Working Corpora"),
                        systemImage: "tray.full",
                        description: Text(String(
                            localized: "corpora.empty.detail",
                            defaultValue: "Run a search, then choose “Save as Working Corpus” to fix those results as a named set you can search inside later."))
                    )
                }
            } else {
                Section {
                    ForEach(corpora) { corpus in row(corpus) }
                        .onDelete(perform: delete)
                }

                Section {
                    Text(String(localized: "corpora.footer",
                                defaultValue: "A working corpus is a fixed set of documents, captured once. It syncs to your other devices whole, so a count taken inside it means the same thing everywhere — even where fewer of its volumes are indexed."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .navigationTitle(String(localized: "corpora.title", defaultValue: "Working Corpora"))
        .alert(String(localized: "corpora.rename.title", defaultValue: "Rename Corpus"),
               isPresented: Binding(get: { renaming != nil },
                                    set: { if !$0 { renaming = nil } })) {
            TextField(String(localized: "corpora.rename.placeholder", defaultValue: "Name"),
                      text: $draftName)
            Button(String(localized: "common.cancel", defaultValue: "Cancel"), role: .cancel) {
                renaming = nil
            }
            Button(String(localized: "common.save", defaultValue: "Save")) { commitRename() }
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func row(_ corpus: WorkingCorpus) -> some View {
        let resolution = WorkingCorpusResolver(
            indexedVolumeIds: Set(appState.indexedVolumeIds)).resolve(corpus)
        VStack(alignment: .leading, spacing: 3) {
            Text(corpus.name).font(.body)
            Text(resolution.coverageDescription)
                .font(.caption)
                .foregroundStyle(resolution.isComplete ? Color.secondary : Color.orange)
            if let provenance = provenanceLine(corpus) {
                Text(provenance)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button {
                draftName = corpus.name
                renaming = corpus
            } label: {
                Label(String(localized: "common.rename", defaultValue: "Rename"),
                      systemImage: "pencil")
            }
            Button(role: .destructive) {
                modelContext.delete(corpus)
                try? modelContext.save()
            } label: {
                Label(String(localized: "common.delete", defaultValue: "Delete"), systemImage: "trash")
            }
        }
    }

    /// Where the corpus came from and when — the part that makes it citable.
    private func provenanceLine(_ corpus: WorkingCorpus) -> String? {
        var parts: [String] = []
        if let captured = corpus.capturedAt {
            parts.append(String(format: String(localized: "corpora.captured %@",
                                               defaultValue: "Captured %@"),
                                captured.formatted(date: .abbreviated, time: .omitted)))
        }
        if let query = corpus.sourceQuery, !query.isEmpty {
            parts.append(String(format: String(localized: "corpora.fromQuery %@",
                                               defaultValue: "from “%@”"), query))
        }
        if let indexed = corpus.indexedVolumeCountAtCapture {
            parts.append(String(format: String(localized: "corpora.againstVolumes %lld",
                                               defaultValue: "against %lld indexed volumes"),
                                Int64(indexed)))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: - Actions

    private func delete(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(corpora[index]) }
        try? modelContext.save()
    }

    private func commitRename() {
        guard let corpus = renaming else { return }
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        // Through the model's method, which stamps `lastModified` — the field CloudKit's
        // last-writer-wins resolves on. Assigning `name` directly would leave it where it was.
        if !trimmed.isEmpty { corpus.rename(to: trimmed) }
        try? modelContext.save()
        renaming = nil
    }
}
