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

/// Settings screen for the experimental semantic axis: what it is, what is unknown about it, what the
/// tester has said so far, and how to send it back.
///
/// This screen is the other half of a decision. The design specified a blind quality panel before the
/// axis could ship; the owner retired it in favour of tester judgement, and that trade is only real if
/// testers can (a) understand what they are judging and (b) get their verdicts out of the app. The
/// prose here is deliberately specific about the *pre-1900* question, because that is the one the
/// panel existed to answer and the one no automatic gate can reach.
///
/// Version history:
///   1.0 — V-3 follow-up: initial implementation
struct SemanticFeedbackView: View {

    /// Verdict totals, loaded on appear.
    @State private var summary: (total: Int, helpful: Int, byEra: [(era: String, count: Int)])?
    /// The export file, written on demand.
    @State private var exportURL: URL?
    /// Whether the clear-confirmation is showing.
    @State private var isConfirmingClear = false

    var body: some View {
        Form {
            Section {
                Text(String(
                    localized: "settings.semanticFeedback.what",
                    defaultValue: """
                        The “Semantically similar (experimental)” axis in Related Documents finds \
                        documents by the shape of their language rather than by citations or \
                        archival provenance. It is off by default — raise its weight in any Related \
                        Documents view to try it.
                        """))
                Text(String(
                    localized: "settings.semanticFeedback.unknown",
                    defaultValue: """
                        What we do not know is how good it is before 1900. The automatic check we \
                        can run relies on the editors’ cross-references, and that citation style \
                        only becomes common after 1945 — so it reaches barely 500 early documents \
                        out of the whole corpus. Nineteenth-century volumes are exactly where this \
                        axis is meant to help most, and exactly where nothing has measured it.
                        """))
                .foregroundStyle(.secondary)
            } header: {
                Text(String(localized: "settings.semanticFeedback.about.header",
                            defaultValue: "About this experiment"))
            }

            Section {
                Text(String(
                    localized: "settings.semanticFeedback.how",
                    defaultValue: """
                        Long-press (or right-click) any related document that shows the magnifier \
                        icon, then choose whether the match was helpful. Nineteenth-century \
                        verdicts are worth the most.
                        """))
            } header: {
                Text(String(localized: "settings.semanticFeedback.how.header",
                            defaultValue: "How to give feedback"))
            }

            Section {
                if let summary {
                    LabeledContent(
                        String(localized: "settings.semanticFeedback.total",
                               defaultValue: "Verdicts recorded"),
                        value: "\(summary.total)")
                    LabeledContent(
                        String(localized: "settings.semanticFeedback.helpful",
                               defaultValue: "Marked helpful"),
                        value: "\(summary.helpful)")
                    // The era split is on screen rather than only in the export, because it is what
                    // says whether the feedback can answer the question it replaced.
                    ForEach(summary.byEra, id: \.era) { row in
                        LabeledContent(Self.eraLabel(row.era), value: "\(row.count)")
                    }
                } else {
                    ProgressView()
                }
            } header: {
                Text(String(localized: "settings.semanticFeedback.recorded.header",
                            defaultValue: "Recorded on this device"))
            } footer: {
                Text(String(
                    localized: "settings.semanticFeedback.privacy",
                    defaultValue: """
                        Stored only on this device and never synced to iCloud. Each verdict records \
                        the two documents, your judgement, the match score, and which release of the \
                        vectors it applies to.
                        """))
            }

            Section {
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label(String(localized: "settings.semanticFeedback.share",
                                     defaultValue: "Share Feedback File"),
                              systemImage: "square.and.arrow.up")
                    }
                } else {
                    Button {
                        Task { await prepareExport() }
                    } label: {
                        Label(String(localized: "settings.semanticFeedback.export",
                                     defaultValue: "Prepare Feedback File"),
                              systemImage: "doc.badge.arrow.up")
                    }
                    .disabled((summary?.total ?? 0) == 0)
                }

                Button(role: .destructive) {
                    isConfirmingClear = true
                } label: {
                    Text(String(localized: "settings.semanticFeedback.clear",
                                defaultValue: "Clear Recorded Feedback"))
                }
                .disabled((summary?.total ?? 0) == 0)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(String(localized: "settings.semanticFeedback.title",
                                defaultValue: "Semantic Match Feedback"))
        .task { await reload() }
        .confirmationDialog(
            String(localized: "settings.semanticFeedback.clear.confirm",
                   defaultValue: "Delete every recorded verdict on this device?"),
            isPresented: $isConfirmingClear, titleVisibility: .visible
        ) {
            Button(String(localized: "settings.semanticFeedback.clear.confirmAction",
                          defaultValue: "Delete Feedback"), role: .destructive) {
                Task {
                    await SemanticFeedbackLog.shared.clear()
                    exportURL = nil
                    await reload()
                }
            }
            Button(String(localized: "common.cancel", defaultValue: "Cancel"), role: .cancel) {}
        }
    }

    /// Loads the totals.
    private func reload() async {
        summary = await SemanticFeedbackLog.shared.summary()
    }

    /// Writes the export file to a temporary location for `ShareLink`.
    private func prepareExport() async {
        guard let data = await SemanticFeedbackLog.shared.exportData() else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-semantic-feedback.json")
        guard (try? data.write(to: url, options: .atomic)) != nil else { return }
        exportURL = url
    }

    /// A readable label for a stored era value.
    ///
    /// The stored value is `CoverageEra`'s raw `Int` as a string — the app's own banding, so a
    /// verdict is comparable with every other era-split surface rather than with a second scheme
    /// invented here.
    ///
    /// - Parameter raw: The stored era value.
    /// - Returns: A display label.
    static func eraLabel(_ raw: String) -> String {
        guard let value = Int(raw), let era = CoverageEra(rawValue: value) else {
            return String(localized: "settings.semanticFeedback.era.unknown",
                          defaultValue: "Undated anchor")
        }
        return era.label
    }
}
