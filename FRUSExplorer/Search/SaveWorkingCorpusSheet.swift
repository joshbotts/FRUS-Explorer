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

// MARK: - SaveWorkingCorpusSheet

/// Promotes a result set into a named working corpus.
///
/// Shared by both search surfaces, like the concordance and the collocation panel, so a corpus
/// captured on one platform is captured identically on the other.
///
/// ## What it captures, and what it does not
/// The **whole retained result set**, not the page — a corpus is the answer to a query, and a page
/// is an accident of pagination. It records the query text and the device's indexed-volume count
/// alongside, because a corpus captured against 40 volumes and one captured against 552 are
/// different evidence and nothing else would say so.
///
/// It does **not** record the query as a re-resolution rule. The keys are the artifact; see
/// ``WorkingCorpus``.
///
/// Version history:
///   1.0 — M-1: initial implementation
struct SaveWorkingCorpusSheet: View {

    /// The results to capture, in the order the search returned them.
    let results: [SearchResult]
    /// The query that produced them, for provenance.
    let queryText: String
    /// Volumes indexed on this device, recorded with the capture.
    let indexedVolumeCount: Int
    /// Which set these results are, so the capture can say what it is a capture OF.
    ///
    /// A working corpus is the one artifact here that is durable, synced and cited. Its
    /// `documentCount` becomes the denominator of a claim, and the same query captured on an
    /// iPhone and a Mac at the same instant against the same index yields 1,000 keys and 7,500 —
    /// with nothing on either record to say so.
    let scope: ResultSetScope

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkingCorpus.name) private var existing: [WorkingCorpus]

    @State private var name: String = ""

    /// The keys the corpus will hold, canonicalised the way the model does so the preview count
    /// matches what is actually stored.
    private var keys: [String] {
        Array(Set(results.map { "\($0.volumeId)/\($0.documentId)" })).sorted()
    }

    /// Whether the typed name duplicates one already in use.
    ///
    /// A warning rather than a block: names are not unique by design — uniqueness cannot be
    /// guaranteed across CloudKit devices — so refusing here would enforce locally what the model
    /// deliberately does not enforce globally.
    private var isDuplicateName: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && existing.contains { $0.name == trimmed }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !keys.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "corpus.save.name.placeholder",
                                     defaultValue: "Corpus name"), text: $name)
                        #if os(iOS)
                        .textInputAutocapitalization(.words)
                        #endif
                    if isDuplicateName {
                        Label(String(localized: "corpus.save.duplicate",
                                     defaultValue: "You already have a corpus with this name. Both will be kept."),
                              systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(Color.orange)
                    }
                } header: {
                    Text(String(localized: "corpus.save.name.header", defaultValue: "Name"))
                }

                Section {
                    LabeledContent(String(localized: "corpus.save.documents",
                                          defaultValue: "Documents")) {
                        Text("\(keys.count)").monospacedDigit()
                    }
                    if !queryText.isEmpty {
                        LabeledContent(String(localized: "corpus.save.query", defaultValue: "From")) {
                            Text(queryText).lineLimit(2).multilineTextAlignment(.trailing)
                        }
                    }
                    LabeledContent(String(localized: "corpus.save.indexed",
                                          defaultValue: "Volumes indexed now")) {
                        Text("\(indexedVolumeCount)").monospacedDigit()
                    }
                    // The modal states the WHOLE chain, unlike the panels: nothing is visible
                    // behind it, so there is no other copy on screen to duplicate.
                    if let truncation = scope.captureTruncationWarning {
                        Label(truncation, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(Color.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let checklist = scope.captureChecklistWarning {
                        Label(checklist, systemImage: "checklist")
                            .font(.caption)
                            .foregroundStyle(Color.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } header: {
                    Text(String(localized: "corpus.save.provenance.header", defaultValue: "Captured"))
                } footer: {
                    Text(String(localized: "corpus.save.footer",
                                defaultValue: "The set is fixed at capture. Re-running the query later may find different documents; this corpus will not change, which is what makes counts taken inside it reproducible."))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            #if os(macOS)
            // Plain `Form` on macOS lays labels into a narrow leading column and pushes section
            // footers into the value column — the cramped result in the seeding run. Grouped is
            // what every other macOS Form in this app uses.
            .formStyle(.grouped)
            #endif
            .navigationTitle(String(localized: "corpus.save.title",
                                    defaultValue: "Save Working Corpus"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel", defaultValue: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save", defaultValue: "Save")) { save() }
                        .disabled(!canSave)
                }
            }
        }
        #if os(macOS)
        // Wider than the first attempt: at 420 the grouped form's label column squeezed the
        // provenance values into two lines each.
        .frame(minWidth: 520, minHeight: 420)
        #endif
    }

    private func save() {
        let corpus = WorkingCorpus(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            documentKeys: keys,
            sourceQuery: queryText.isEmpty ? nil : queryText,
            // Into `sourceDescription`, an existing stored property already in
            // `installedIdentifiers` — so the record becomes self-describing at zero CloudKit
            // schema cost. Read on another device, or a year later, it carries its truncation.
            sourceDescription: scope.captureProvenanceDescription,
            indexedVolumeCountAtCapture: indexedVolumeCount)
        modelContext.insert(corpus)
        try? modelContext.save()
        dismiss()
    }
}
