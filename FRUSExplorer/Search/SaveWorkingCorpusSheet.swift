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
/// is an accident of pagination. It records the query text, what narrowed the search beyond it
/// (`ResultSetScope.narrowing`, inside `sourceDescription`), and the device's indexed-volume count
/// alongside, because a corpus captured against 40 volumes and one captured against 553 are
/// different evidence and nothing else would say so.
///
/// It does **not** record the query as a re-resolution rule. The keys are the artifact; see
/// ``WorkingCorpus``.
///
/// Version history:
///   1.0 — M-1: initial implementation
///   1.1 — #1598: the stored truncation flag is `ResultSetScope.isCapturePartial`, so a Meaning capture is not
///         recorded as every matching document
///   1.2 — #1758: a Narrowed by row, and the record's description, say what narrowed the search beyond its
///         words, where both said only the query, so a corpus did not say how its documents were chosen
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
                    // How the documents were chosen beyond the words, which the corpus records with them
                    // (#1758): "years 1945" for a search narrowed by Facets to 1945.
                    if !scope.narrowing.isEmpty {
                        LabeledContent(String(localized: "corpus.save.narrowedBy", defaultValue: "Narrowed by")) {
                            Text(scope.narrowing.joined(separator: "; "))
                                .multilineTextAlignment(.trailing)
                                .fixedSize(horizontal: false, vertical: true)
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
            // Typed alongside the prose, not instead of it. The prose is what a READER needs; a
            // guard needs a Bool, and a fraction needs an Int. `didHitFetchLimit` is recorded
            // even when the total is unknown, which is the iPhone case.
            indexedVolumeCountAtCapture: indexedVolumeCount,
            // `isPartialEvidence`, not `didHitFetchLimit`. Capturing a corpus while already
            // inside a truncated one produces a set that is partial for a reason this fetch
            // cannot see — the fetch did not cap, because the corpus it ran in was already
            // smaller than the ceiling. Recording the fetch's own answer would stamp that
            // capture "complete", which is the precise defect these fields exist to end, one
            // level of nesting down. `isCapturePartial` is that rule, and also `true` for a
            // Meaning search, whose list is never every matching document (#1598).
            wasTruncatedAtCapture: scope.isCapturePartial,
            totalMatchCountAtCapture: scope.totalMatchCount)
        modelContext.insert(corpus)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Saving a capture (#1990, L42)

/// A capture the reader has asked to save as a working corpus, with what its screen adds about what the
/// save leaves out — the sentences ``WorkingCorpusCapture/statement(coverage:notes:locale:)`` says after
/// the coverage. The value ``SwiftUI/View/workingCorpusSave(_:outcome:)`` presents on.
///
/// Version history:
///   1.0 — 2026-11-27 (#1990, L42): initial implementation, for the cross-reference graph's save
struct WorkingCorpusSaveRequest: Identifiable {
    /// The request's identity, so a second request for the same set is presented anew.
    let id = UUID()
    /// What the save writes.
    let capture: WorkingCorpusCapture
    /// What the screen adds, said before the save.
    var notes: [String] = []
}

extension WorkingCorpusCapture {

    /// Writes the capture as a working corpus and saves the context: the record the Clusters index and the
    /// semantic map's lasso write — the kept keys, no query, the description, the volumes indexed at capture
    /// and both truncation fields.
    ///
    /// The one write a screen's capture goes through (#1990): the cross-reference graph's, and Chronology's
    /// after it (L56). A save that fails takes its corpus out of the context again, so a later save of the
    /// context cannot write the corpus the reader was told was not saved.
    ///
    /// - Parameters:
    ///   - context: The context to write to.
    ///   - indexedVolumeCount: How many volumes this device has indexed.
    /// - Returns: The new corpus.
    /// - Throws: The context's save error.
    @discardableResult
    func save(in context: ModelContext, indexedVolumeCount: Int) throws -> WorkingCorpus {
        let corpus = WorkingCorpus(
            name: name,
            documentKeys: documentKeys,
            // No query produced the set: `sourceQuery` exists so a corpus can be re-derived by hand from
            // its words, and the description says how this one can be.
            sourceQuery: nil,
            sourceDescription: sourceDescription,
            indexedVolumeCountAtCapture: indexedVolumeCount,
            wasTruncatedAtCapture: isTruncated,
            totalMatchCountAtCapture: total)
        context.insert(corpus)
        do {
            try context.save()
        } catch {
            context.delete(corpus)
            throw error
        }
        return corpus
    }
}

/// Asks before a capture is saved as a working corpus and says after what the save did (#1990, L42):
/// what the save holds, before it, as the semantic map's lasso card says it, and what it did, after it,
/// as Add to Collection says it (L19). See ``SwiftUI/View/workingCorpusSave(_:outcome:)``.
private struct WorkingCorpusSaveModifier: ViewModifier {

    @Binding var request: WorkingCorpusSaveRequest?
    @Binding var outcome: String?

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    func body(content: Content) -> some View {
        content.alert(
            String(localized: "workingCorpus.capture.confirm.title", defaultValue: "Save as Working Corpus?"),
            isPresented: Binding(get: { request != nil }, set: { if !$0 { request = nil } }),
            presenting: request
        ) { request in
            Button(String(localized: "common.save", defaultValue: "Save")) { save(request) }
            Button(String(localized: "common.cancel", defaultValue: "Cancel"), role: .cancel) {}
        } message: { request in
            Text(verbatim: request.capture.statement(coverage: coverage(of: request.capture), notes: request.notes))
        }
    }

    /// How much of the capture this device has indexed, through the resolver that decides what a corpus
    /// searches when it is applied, so the number said at capture is the number the corpus gives.
    private func coverage(of capture: WorkingCorpusCapture) -> WorkingCorpusResolution {
        WorkingCorpusResolver(indexedVolumeIds: appState.indexedVolumeIds).resolve(documentKeys: capture.documentKeys)
    }

    private func save(_ request: WorkingCorpusSaveRequest) {
        do {
            let corpus = try request.capture.save(in: modelContext,
                                                  indexedVolumeCount: appState.indexedVolumeIds.count)
            outcome = WorkingCorpusCapture.outcome(savedName: corpus.name)
        } catch {
            outcome = WorkingCorpusCapture.outcome(savedName: nil)
            #if DEBUG
            print("[WorkingCorpusSave] save failed: \(error)")
            #endif
        }
    }
}

extension View {

    /// Presents `request` as a question before its capture is saved as a working corpus — what it holds,
    /// how much of it this device has indexed, and what it leaves out — and on Save writes it
    /// (``WorkingCorpusCapture/save(in:indexedVolumeCount:)``) and sets `outcome` to what the save did,
    /// which the screen shows in its toast (`transientToast(_:)`), whose announcement VoiceOver hears.
    ///
    /// The one way a screen asks to save a capture (#1990): the cross-reference graph's, and Chronology's
    /// after it (L56).
    ///
    /// - Parameters:
    ///   - request: The capture to save; the screen sets it, and the question clears it.
    ///   - outcome: Where the sentence that says what the save did goes.
    /// - Returns: The view, with the question.
    func workingCorpusSave(_ request: Binding<WorkingCorpusSaveRequest?>, outcome: Binding<String?>) -> some View {
        modifier(WorkingCorpusSaveModifier(request: request, outcome: outcome))
    }
}
