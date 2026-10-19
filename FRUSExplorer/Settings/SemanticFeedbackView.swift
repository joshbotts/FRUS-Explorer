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
#if os(iOS)
import MessageUI
#elseif os(macOS)
import AppKit
#endif

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
///   1.1 — 2026-10-18 (#1545, plan of record decision 26): **Email Feedback File** writes a mail draft
///         to ``SemanticFeedbackMail/address`` with the file attached, beside Share Feedback File
struct SemanticFeedbackView: View {

    /// Verdict totals, loaded on appear.
    @State private var summary: (total: Int, helpful: Int, byEra: [(era: String, count: Int)])?
    /// The export file, written on demand.
    @State private var exportURL: URL?
    #if os(iOS)
    /// The file Mail's compose sheet is attaching while it shows; the sheet carries it as its item,
    /// so it never reads a sibling state that has moved on.
    @State private var mailAttachment: URL?
    #endif
    /// Whether the clear-confirmation is showing.
    @State private var isConfirmingClear = false

    var body: some View {
        Form {
            Section {
                Text(String(
                    localized: "settings.semanticFeedback.what",
                    defaultValue: """
                        The “Semantically similar (experimental)” axis in Related Documents finds \
                        documents by an AI model’s scoring of the meaning of their language rather than by citations or \
                        archival provenance. It contributes to every Related Documents list unless \
                        you lower its weight there. It is still experimental: how well it works on \
                        nineteenth-century material is not established, which is what the verdicts \
                        below are for.
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
                    localized: "settings.semanticFeedback.privacy.v2",
                    defaultValue: """
                        Stored on-device and not synced to iCloud. Each verdict records the two \
                        documents, your judgement, the match score, which release of the vectors it \
                        applies to, and when you gave it. The app sends none of it: to share your \
                        verdicts, choose Prepare Feedback File, then send the file to \
                        \(SemanticFeedbackMail.address). Where this device can send mail, Email \
                        Feedback File writes that message with the file attached; Share Feedback \
                        File sends the file any other way.
                        """))
            }

            Section {
                if let exportURL {
                    if SemanticFeedbackMail.canCompose(attaching: exportURL) {
                        Button {
                            composeMail(attaching: exportURL)
                        } label: {
                            Label(String(localized: "settings.semanticFeedback.email",
                                         defaultValue: "Email Feedback File"),
                                  systemImage: "envelope")
                        }
                    }
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
        #if os(iOS)
        .sheet(item: $mailAttachment) { url in
            SemanticFeedbackMailComposer(draft: .current, attachmentURL: url) {
                mailAttachment = nil
            }
            .ignoresSafeArea()
        }
        #endif
    }

    /// Loads the totals.
    private func reload() async {
        summary = await SemanticFeedbackLog.shared.summary()
    }

    /// Opens the mail draft for the prepared file: Mail's compose sheet on iPhone and iPad, and a new
    /// message in the default mail app on the Mac. The reader sends it, or does not.
    ///
    /// - Parameter url: The file Prepare Feedback File wrote.
    private func composeMail(attaching url: URL) {
        #if os(iOS)
        mailAttachment = url
        #elseif os(macOS)
        SemanticFeedbackMail.current.compose(attaching: url)
        #endif
    }

    /// Writes the export file to a temporary location for `ShareLink` and the mail draft.
    private func prepareExport() async {
        guard let data = await SemanticFeedbackLog.shared.exportData() else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(SemanticFeedbackMail.fileName)
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

// MARK: - The mail draft (#1545)

/// The message Semantic Match Feedback offers to write (#1545, plan of record decision 26): the
/// feedback file attached and ``address`` filled in, sent by the reader from their own mail app.
///
/// The app still sends nothing. The draft opens in Mail, where the reader can read it, change it or
/// throw it away, and Share Feedback File stays beside it for every other way. The address is this
/// one constant: the footer names it from here, and both platforms' drafts address it from here.
struct SemanticFeedbackMail: Equatable, Sendable {

    /// Where the verdicts go, the address the owner named on 2026-10-18.
    static let address = "feedback@frusexplorer.app"

    /// The attachment's name, the one Prepare Feedback File writes.
    static let fileName = "frus-semantic-feedback.json"

    /// The attachment's type.
    static let mimeType = "application/json"

    /// The draft's To: line, ``address`` alone.
    let recipients: [String]
    /// The draft's subject.
    let subject: String
    /// The draft's body: which build wrote the file.
    let body: String

    /// A draft naming the build that wrote the file.
    ///
    /// - Parameter version: The app's version and build, as About writes them (`1.0 (1861)`).
    init(version: String) {
        recipients = [Self.address]
        subject = String(localized: "settings.semanticFeedback.mail.subject",
                         defaultValue: "FRUS Explorer Semantic Match Feedback")
        body = String(localized: "settings.semanticFeedback.mail.body",
                      defaultValue: "My Semantic Match Feedback verdicts from FRUS Explorer \(version) are attached.")
    }

    /// The draft for the running build.
    static var current: SemanticFeedbackMail {
        SemanticFeedbackMail(version: "\(SyncDiagnosticsLog.appVersion) (\(SyncDiagnosticsLog.appBuild))")
    }
}

#if os(iOS)
extension SemanticFeedbackMail {

    /// Whether this device can write the draft: Mail must have an account. Where it cannot, the
    /// screen offers Share Feedback File alone, and its footer still names ``address``.
    ///
    /// - Parameter url: The prepared file (unused on iPhone and iPad, where Mail decides alone).
    /// - Returns: `true` when Mail's compose sheet can open.
    @MainActor
    static func canCompose(attaching url: URL) -> Bool {
        MFMailComposeViewController.canSendMail()
    }
}

/// Mail's compose sheet holding a ``SemanticFeedbackMail`` draft with the feedback file attached.
struct SemanticFeedbackMailComposer: UIViewControllerRepresentable {

    /// The message to write.
    let draft: SemanticFeedbackMail
    /// The file Prepare Feedback File wrote.
    let attachmentURL: URL
    /// Ends the sheet once Mail is done with the draft: sent, saved, cancelled or failed.
    let onFinish: @MainActor () -> Void

    /// The delegate that hears Mail finish.
    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    /// Builds the compose sheet with the address, subject, body and attachment filled in.
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients(draft.recipients)
        controller.setSubject(draft.subject)
        controller.setMessageBody(draft.body, isHTML: false)
        if let data = try? Data(contentsOf: attachmentURL) {
            controller.addAttachmentData(data, mimeType: SemanticFeedbackMail.mimeType,
                                         fileName: SemanticFeedbackMail.fileName)
        }
        return controller
    }

    /// Nothing to update: the draft is written once, when the sheet opens.
    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}

    /// Hears Mail finish with the draft and ends the sheet.
    ///
    /// `MFMailComposeViewControllerDelegate` carries no actor, so the callback is nonisolated here;
    /// Mail calls it on the main thread, which `assumeIsolated` states.
    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate, @unchecked Sendable {

        /// Ends the sheet.
        let onFinish: @MainActor () -> Void

        /// - Parameter onFinish: Ends the sheet.
        init(onFinish: @escaping @MainActor () -> Void) {
            self.onFinish = onFinish
        }

        /// Mail is done with the draft, however it ended.
        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult, error: (any Error)?) {
            MainActor.assumeIsolated { onFinish() }
        }
    }
}
#elseif os(macOS)
extension SemanticFeedbackMail {

    /// Whether this Mac's default mail app can take the draft.
    ///
    /// - Parameter url: The prepared file.
    /// - Returns: `true` when the compose-email sharing service can perform with the file.
    @MainActor
    static func canCompose(attaching url: URL) -> Bool {
        NSSharingService(named: .composeEmail)?.canPerform(withItems: [url]) ?? false
    }

    /// Opens a new message in the default mail app with the address, subject, body and file.
    ///
    /// - Parameter url: The prepared file.
    @MainActor
    func compose(attaching url: URL) {
        guard let service = NSSharingService(named: .composeEmail) else { return }
        service.recipients = recipients
        service.subject = subject
        service.perform(withItems: [body, url])
    }
}
#endif
