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
import CoreText
#if os(iOS)
import UIKit
#else
import AppKit
#endif

// MARK: - TripPacketSheet

/// Presents a generated research-trip packet (#830 T-2).
///
/// ## One sheet, both entry points
/// The scope doc says Project Home and a collection's overflow menu "feed the same aggregation".
/// They feed the same VIEW too — a second presenter would be a second place for the packet's
/// honesty rules to be applied differently, and those rules are the whole point of the feature.
///
/// ## Scoping is a render filter, never a rebuild
/// The repository scope and the citation-appendix toggle re-run the exporter over the model
/// already in hand (the export-scoping amendment: "a scoped export is a render filter, not a
/// second pipeline"). Only the seed changing rebuilds.
///
/// Version history:
///   1.0 — Session 2026-08-22: #830 T-2
///   1.1 — Session 2026-08-23: #830 — the roster's citations come from the real formatter
///          (the data source gains the manifest map), and a PDF share rides beside the
///          plain-text one — the SAME string paginated, never a second composition
///   1.2 — Archive Visits Phase 0: (a) the sheet takes a ``TripPacketSeed`` — a document list,
///          or a Collection resolved HERE, so a smart (saved-search) collection finally has a
///          route and excerpt entries count as the documents they quote; one sheet stays the
///          one place the packet's rules are applied. (b) The inquiry's topic sentence gains
///          its editor — `TripPacketTopicSentence.edited` was designed for exactly this and
///          written by nothing; the drafts send what the researcher types here, never the
///          stored project note. (c) The empty state stopped naming a cause it cannot have:
///          it is reachable only with an empty reading list or no search index, never by
///          "no source notes" (that case builds a real packet with a help-me-locate list).
///   1.3 — Archive Visits Phase 1: the visit-date bar leaves with chapter 1 (its checklist
///          was the only reader of the date); the share surface gains the repository scope
///          (§3's export-scoping amendment), each facility's inquiry draft gains its own
///          Copy (a draft's whole purpose is to be pasted into one email), and the citation
///          appendix becomes an opt-in toggle, default off (§3a)
///   1.4 — Archive Visits Phase 3: the `.plan` seed — derivation through the editor's own
///          path, topic edits persisting to `plan.inquiryText`, and the 1f deliverables
///          section writing the plan's stored toggles rather than sheet-local state

/// What a packet is built over (Phase 0).
///
/// The `collection` case exists so that resolution happens INSIDE the one sheet: a smart
/// collection's membership comes from its saved search (matching export behavior — the editor
/// itself tells the user "static entries are ignored"), and a static collection contributes its
/// document entries AND its excerpts, whose `volumeId`/`documentId` provenance is a real
/// document reference the old filter dropped.
enum TripPacketSeed {
    /// An explicit reading list (Project Home's engaged set).
    case documents([(volumeId: String, documentId: String)])
    /// A collection, resolved at build time (smart → saved search; static → documents + excerpts).
    case collection(Collection)
    /// A persistent Archive Visit plan (Phase 3): seeds resolve through the plan's own
    /// contribution flags via `ArchiveVisitDerivation` — the same derivation the editor
    /// renders from — and the sheet's topic edits and deliverable toggles PERSIST to the
    /// plan rather than living for the sheet's lifetime.
    case plan(ArchiveVisitPlan)

    /// Resolves a collection to its reading list — the ONE membership rule every surface
    /// shares (Phase 3 factored it out of the sheet so the add-to-plan flows resolve the
    /// same set the packet does): smart → the export's own `smartRefs`; static → documents
    /// + excerpts through ``staticSeedDocuments(from:)``. Returns `nil` when a smart
    /// collection's search cannot run yet.
    @MainActor
    static func resolve(collection: Collection, appState: AppState,
                        modelContext: ModelContext)
        async -> [(volumeId: String, documentId: String)]? {
        if collection.savedSearchId != nil {
            let resolver = CollectionContentResolver(appState: appState,
                                                     modelContext: modelContext)
            guard let refs = try? await resolver.smartRefs(for: collection) else { return nil }
            return refs.sorted { $0.sortOrder < $1.sortOrder }
                .map { (volumeId: $0.volumeId, documentId: $0.documentId) }
        }
        return staticSeedDocuments(from: collection.documentEntries ?? [])
    }

    /// The static-collection seed rule, separated so it is testable: document and excerpt
    /// entries with non-empty ids, in `sortOrder`, de-duplicated first-occurrence-wins.
    static func staticSeedDocuments(from entries: [CollectionEntry])
        -> [(volumeId: String, documentId: String)] {
        var seen = Set<String>()
        var out: [(volumeId: String, documentId: String)] = []
        for entry in entries.sorted(by: { $0.sortOrder < $1.sortOrder })
        where (entry.entryKind == .document || entry.entryKind == .excerpt)
            && !entry.volumeId.isEmpty && !entry.documentId.isEmpty {
            let key = "\(entry.volumeId)/\(entry.documentId)"
            if seen.insert(key).inserted {
                out.append((volumeId: entry.volumeId, documentId: entry.documentId))
            }
        }
        return out
    }
}

struct TripPacketSheet: View {

    /// What the packet is built over.
    let seed: TripPacketSeed
    /// Names the packet, and seeds nothing else.
    let title: String
    /// Seeds the inquiry's topic sentence (D8); `nil` yields the placeholder.
    let researchQuestion: String?

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Why there is no packet, when there is none — each state names its actual cause.
    enum UnavailableReason {
        /// The seed resolved to zero documents.
        case noDocuments
        /// `appState.indexingPipeline` is nil — nothing can be read.
        case indexUnavailable
        /// A smart collection's saved search could not run (no search service).
        case smartSearchUnavailable
    }

    @State private var packet: String?
    /// The packet paginated as a PDF, regenerated with the packet itself.
    @State private var packetPDF: URL?
    /// The built model, held so the topic-sentence edit re-renders WITHOUT a rebuild.
    @State private var model: TripPacketModel?
    /// The inquiry topic sentence as typed; committed to `model.topicSentence.edited`.
    @State private var topicDraft = ""
    /// Debounces the re-render while typing — the export is cheap, the PDF is not.
    @State private var topicRenderTask: Task<Void, Never>?
    @State private var unavailableReason: UnavailableReason?
    /// The repository scope — `nil` renders the whole plan (the default and the master
    /// reference); a facility name renders that repository's self-contained slice.
    @State private var facilityScope: String?
    /// The deliverable toggles in force. For an EPHEMERAL packet this is sheet-local state
    /// (defaults per §3b); for a `.plan` seed it mirrors the plan's stored toggles, and
    /// every change writes back through ``persistDeliverablesIfPlan()`` so the choice
    /// travels with the plan (1f: part of the plan, not an app preference).
    @State private var deliverables = ArchiveVisitDeliverables()
    /// The plan's stored per-target state, derived alongside the model for a `.plan` seed.
    @State private var overlay: ArchiveVisitOverlay?
    /// The plan's seed-coverage numbers, for the 1h documents line.
    @State private var seedCoverage: (seeded: Int, indexed: Int)?
    @State private var isBuilding = true

    var body: some View {
        NavigationStack {
            Group {
                if isBuilding {
                    BootPlaceholderView(detail: String(
                        localized: "packet.building",
                        defaultValue: "Reading your documents' source notes…"))
                } else if let packet {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            topicEditor
                            Divider()
                            Text(packet)
                                .font(.system(.footnote, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                    }
                } else {
                    // Each unavailable state names its ACTUAL cause. The old single message
                    // ("none of these documents has an indexed source note") described a state
                    // this branch cannot be shown in — a no-source-notes reading list builds a
                    // real packet whose inquiry lists them as help-me-locate items.
                    switch unavailableReason {
                    case .indexUnavailable:
                        ContentUnavailableView(
                            String(localized: "packet.empty.noIndex.title",
                                   defaultValue: "The search index isn't ready"),
                            systemImage: "doc.text.magnifyingglass",
                            description: Text(String(
                                localized: "packet.empty.noIndex.message",
                                defaultValue: "The packet reads source notes from the search index, which isn't available yet. Finish indexing and try again.")))
                    case .smartSearchUnavailable:
                        ContentUnavailableView(
                            String(localized: "packet.empty.smart.title",
                                   defaultValue: "This collection's search can't run yet"),
                            systemImage: "doc.text.magnifyingglass",
                            description: Text(String(
                                localized: "packet.empty.smart.message",
                                defaultValue: "This collection's documents come from its saved search, and search isn't available yet. Finish indexing and try again.")))
                    case .noDocuments, nil:
                        ContentUnavailableView(
                            String(localized: "packet.empty.title", defaultValue: "Nothing to plan yet"),
                            systemImage: "doc.text.magnifyingglass",
                            description: Text(String(
                                localized: "packet.empty.noDocuments.message",
                                defaultValue: "There are no documents here to plan over. Add documents to a collection, write a note on one, or apply a focus tag — the packet is built from the documents you have engaged with.")))
                    }
                }
            }
            .navigationTitle(String(localized: "packet.title", defaultValue: "Archive Visit"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done", defaultValue: "Done")) { dismiss() }
                }
                if model != nil {
                    ToolbarItem(placement: .secondaryAction) { optionsMenu }
                }
                if let packet {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: packet) {
                            Label(String(localized: "packet.share", defaultValue: "Share"),
                                  systemImage: "square.and.arrow.up")
                        }
                    }
                }
                // The PDF beside the text, never instead of it: plain text is the format
                // the inquiry draft must survive in (it is pasted into a mail client),
                // and the PDF is the same string paginated for printing and filing.
                if let packetPDF {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: packetPDF) {
                            Label(String(localized: "packet.share.pdf", defaultValue: "Share as PDF"),
                                  systemImage: "doc.richtext")
                        }
                    }
                }
            }
            .task { await rebuild() }
            // Scope and deliverables are render filters over the model already in hand — the
            // export-scoping amendment's whole point. Only the seed changing rebuilds. A plan's
            // deliverable change also persists (1f).
            .onChange(of: facilityScope) { _, _ in if let model { render(model) } }
            .onChange(of: deliverables) { _, _ in
                persistDeliverablesIfPlan()
                if let model { render(model) }
            }
        }
        #if os(macOS)
        .frame(minWidth: 620, minHeight: 640)
        #endif
    }

    /// The facilities the built model can scope or draft for, in section order.
    private var facilities: [String] {
        guard let model else { return [] }
        var seen = Set<String>()
        return model.targets.compactMap(\.facility.chapterHeading)
            .filter { seen.insert($0).inserted }
    }

    /// The export options: the repository scope (the export-scoping amendment — a
    /// single-repository export is a self-contained artifact, so no one divides one by
    /// hand), each facility's own Copy for its inquiry draft, and the citation appendix.
    @ViewBuilder
    private var optionsMenu: some View {
        Menu {
            Picker(String(localized: "packet.scope.picker", defaultValue: "Repository"),
                   selection: $facilityScope) {
                Text(String(localized: "packet.scope.all", defaultValue: "All repositories"))
                    .tag(String?.none)
                ForEach(facilities, id: \.self) { facility in
                    Text(facility).tag(String?.some(facility))
                }
            }
            if !facilities.isEmpty {
                Section(String(localized: "packet.copyDraft.section",
                               defaultValue: "Copy inquiry draft")) {
                    ForEach(facilities, id: \.self) { facility in
                        Button(facility) { copyDraft(for: facility) }
                    }
                }
            }
            if seededPlan != nil {
                // 1f: the full per-plan deliverables — what to include travels WITH the plan.
                Section(String(localized: "packet.deliverables.section",
                               defaultValue: "What to Include")) {
                    Toggle(String(localized: "packet.deliverables.links",
                                  defaultValue: "Repository visit-planning links"),
                           isOn: $deliverables.includeLinks)
                    Toggle(String(localized: "packet.deliverables.targets",
                                  defaultValue: "Target list"),
                           isOn: $deliverables.includeTargets)
                    Toggle(String(localized: "packet.deliverables.inquiry",
                                  defaultValue: "Inquiry email drafts"),
                           isOn: $deliverables.includeInquiry)
                    Toggle(String(localized: "packet.appendix.crib",
                                  defaultValue: "Include NARA citation guidance"),
                           isOn: $deliverables.includeCitationCrib)
                }
            } else {
                Toggle(String(localized: "packet.appendix.crib",
                              defaultValue: "Include NARA citation guidance"),
                       isOn: $deliverables.includeCitationCrib)
            }
        } label: {
            Label(String(localized: "packet.options", defaultValue: "Options"),
                  systemImage: "slider.horizontal.3")
        }
    }

    /// Copies one facility's inquiry draft to the pasteboard — a draft's entire purpose is
    /// to be pasted into an email to that one archivist, so it must not need carving out of
    /// the grouped document by hand.
    private func copyDraft(for facility: String) {
        guard let model else { return }
        var exporter = TripPacketExporter(model: model, projectName: title)
        exporter.facilityScope = facility
        let draft = exporter.inquiryDrafts
        #if os(iOS)
        UIPasteboard.general.string = draft
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(draft, forType: .string)
        #endif
    }

    /// The inquiry's topic sentence, editable in place (Phase 0 — the missing
    /// `TripPacketTopicSentence.edited` writer). The caption states the rule that is the whole
    /// point: the drafts send what is typed HERE, never the stored project note — the note is
    /// internal, the draft is an email to reference staff.
    @ViewBuilder
    private var topicEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "packet.topic.header", defaultValue: "Inquiry topic sentence"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            TextField(String(localized: "packet.topic.field", defaultValue: "Topic sentence"),
                      text: $topicDraft,
                      prompt: Text(TripPacketTopicSentence.placeholder),
                      axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)
                .onChange(of: topicDraft) { _, _ in scheduleTopicRender() }
                .onSubmit { applyTopicEdit() }
            Text(researchQuestion?.isEmpty == false
                 ? String(localized: "packet.topic.caption.seeded",
                          defaultValue: "Seeded from your project's research question — edit freely. The drafts send what you write here, never the stored note.")
                 : String(localized: "packet.topic.caption.unseeded",
                          defaultValue: "The inquiry drafts send what you write here."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    /// Debounce the re-render while typing: the export is a cheap string build, the PDF is not.
    private func scheduleTopicRender() {
        topicRenderTask?.cancel()
        topicRenderTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            applyTopicEdit()
        }
    }

    /// Writes the draft into the model's `edited` slot and re-renders — no rebuild, the model
    /// is already assembled; only the export string and its PDF change. For a `.plan` seed the
    /// edit also PERSISTS to `plan.inquiryText` — the whole reason the plan carries the field:
    /// the draft survives the sheet, and re-opens identically on another device.
    private func applyTopicEdit() {
        guard var model else { return }
        let trimmed = topicDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        model.topicSentence.edited = trimmed.isEmpty ? nil : topicDraft
        self.model = model
        if let plan = seededPlan {
            plan.inquiryText = trimmed.isEmpty ? nil : topicDraft
            try? modelContext.save()
        }
        render(model)
    }

    /// One render path for build, edit, scope, and appendix, so no pair can compose differently.
    private func render(_ model: TripPacketModel) {
        var exporter = TripPacketExporter(model: model, projectName: title)
        exporter.facilityScope = facilityScope
        exporter.deliverables = deliverables
        exporter.overlay = overlay
        if let seedCoverage {
            exporter.seededDocumentCount = seedCoverage.seeded
            exporter.resolvedDocumentCount = seedCoverage.indexed
        }
        exporter.generatedOn = Date()
        let rendered = exporter.export()
        packet = rendered
        packetPDF = TripPacketPDFRenderer.render(packet: rendered, title: title)
    }

    /// Writes the sheet's deliverable toggles back to the plan (1f: they are part of the
    /// plan, not an app preference). A no-op for ephemeral packets.
    private func persistDeliverablesIfPlan() {
        guard let plan = seededPlan else { return }
        plan.deliverables = deliverables
        try? modelContext.save()
    }

    /// The plan behind a `.plan` seed, or `nil`.
    private var seededPlan: ArchiveVisitPlan? {
        if case .plan(let plan) = seed { return plan }
        return nil
    }

    /// Resolves the seed to a reading list. A smart collection resolves through the SAME
    /// resolver its exports use (`CollectionContentResolver.smartRefs`), so the packet and the
    /// export cannot describe different membership; a static collection contributes documents
    /// and excerpts through ``TripPacketSeed/staticSeedDocuments(from:)``. A `.plan` seed never
    /// reaches this — `rebuild()` derives it through `ArchiveVisitDerivation` instead, so the
    /// sheet and the plan editor cannot disagree about a plan's targets.
    private func resolveSeedDocuments() async -> [(volumeId: String, documentId: String)]? {
        switch seed {
        case .documents(let docs):
            return docs
        case .plan:
            return nil   // unreachable — rebuild() branches before calling this
        case .collection(let collection):
            guard let docs = await TripPacketSeed.resolve(
                collection: collection, appState: appState, modelContext: modelContext) else {
                unavailableReason = .smartSearchUnavailable
                return nil
            }
            return docs
        }
    }

    private func rebuild() async {
        isBuilding = true
        defer { isBuilding = false }
        unavailableReason = nil
        guard let pipeline = appState.indexingPipeline else {
            packet = nil
            packetPDF = nil
            model = nil
            unavailableReason = .indexUnavailable
            return
        }
        // The same manifest set CollectionContentResolver batches, keyed once — what lets
        // the roster's citations come from the real formatter rather than the fallback.
        let manifest = appState.manifestStore.diffResult?.known
            ?? appState.manifestStore.bundledEntries
        let dataSource = TripPacketDataSource(
            pipeline: pipeline,
            manifestMap: Dictionary(manifest.map { ($0.volumeId, $0) },
                                    uniquingKeysWith: { first, _ in first }))

        // A plan derives through the ONE derivation path the editor renders from, and its
        // stored toggles and inquiry text load into the sheet's state.
        if let plan = seededPlan {
            deliverables = plan.deliverables
            guard !(plan.documents ?? []).isEmpty else {
                packet = nil
                packetPDF = nil
                model = nil
                unavailableReason = .noDocuments
                return
            }
            let derived = await ArchiveVisitDerivation.derive(
                plan: plan,
                indexedVolumeIds: Set(appState.indexedVolumeIds),
                dataSource: dataSource)
            overlay = derived.overlay
            seedCoverage = (seeded: derived.seededDocumentCount,
                            indexed: derived.indexedDocumentCount)
            var planModel = derived.model
            // A live sheet edit wins over the stored text until committed (the rebuild-
            // preserves-the-edit rule below); with no live edit, mirror the stored text.
            let trimmed = topicDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                planModel.topicSentence.edited = topicDraft
            } else if topicDraft.isEmpty, let stored = plan.inquiryText, !stored.isEmpty {
                topicDraft = stored
            }
            model = planModel
            if let scope = facilityScope, !facilities.contains(scope) { facilityScope = nil }
            render(planModel)
            return
        }

        guard let documents = await resolveSeedDocuments() else {
            packet = nil
            packetPDF = nil
            model = nil
            return   // resolveSeedDocuments set the reason
        }
        guard !documents.isEmpty else {
            packet = nil
            packetPDF = nil
            model = nil
            unavailableReason = .noDocuments
            return
        }
        var built = await TripPacketBuilder.build(
            documents: documents, researchQuestion: researchQuestion,
            dataSource: dataSource)
        guard !built.targets.isEmpty || built.triage.unresolvedDocumentCount > 0 else {
            // Unreachable in practice (a note-less reading list lands in the help-me-locate
            // branch), kept as a guard: an empty page must never render as a packet.
            packet = nil
            packetPDF = nil
            model = nil
            unavailableReason = .noDocuments
            return
        }
        // A rebuild must not discard the researcher's edit.
        let trimmed = topicDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { built.topicSentence.edited = topicDraft }
        model = built
        // A re-resolved seed can lose the scoped facility; falling back to the whole plan
        // beats rendering an empty slice under a stale heading.
        if let scope = facilityScope, !facilities.contains(scope) { facilityScope = nil }
        render(built)
    }
}

// MARK: - TripPacketPDFRenderer

/// Paginates the packet string into a US-Letter PDF (#830).
///
/// ## The same string, never a second composition
/// The exporter's one-format rule stands: this renders the EXACT plain text the reader
/// reviewed, in a monospaced face, flowed across pages by CoreText. A structured PDF
/// (styled headings, laid-out tables) would be a second composition of the packet — a
/// second place for its honesty rules to be applied differently — which is the exact
/// failure #960 measured across the collection exporters. The technique is
/// `PDFCollectionExporter`'s (CoreText framesetter into a `CGContext` PDF); the ambition
/// deliberately is not.
///
/// Version history:
///   1.0 — Session 2026-08-23: #830
enum TripPacketPDFRenderer {

    /// Renders the packet to a temporary PDF, or `nil` when the context cannot be made.
    ///
    /// - Parameters:
    ///   - packet: The exporter's plain-text output.
    ///   - title: Names the file, sanitized.
    /// - Returns: A `file://` URL in the temporary directory.
    static func render(packet: String, title: String) -> URL? {
        var pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)   // US Letter, points
        let textRect = pageRect.insetBy(dx: 54, dy: 54)              // 0.75" margins

        let font = CTFontCreateWithName("Menlo" as CFString, 9, nil)
        let attributed = NSAttributedString(
            string: packet,
            attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String):
                    CGColor(gray: 0, alpha: 1),
            ])
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)

        let safeName = title.components(separatedBy: CharacterSet(charactersIn: "/\\:"))
            .joined(separator: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Archive Visit — \(safeName).pdf")
        guard let consumer = CGDataConsumer(url: url as CFURL),
              let context = CGContext(consumer: consumer, mediaBox: &pageRect, nil) else {
            return nil
        }

        var location = 0
        let length = attributed.length
        var pages = 0
        // The page cap is a runaway guard, not a feature limit: at ~60 lines a page it
        // sits far above any packet a reading list can produce.
        while location < length && pages < 500 {
            context.beginPDFPage(nil)
            let path = CGPath(rect: textRect, transform: nil)
            let frame = CTFramesetterCreateFrame(
                framesetter, CFRange(location: location, length: 0), path, nil)
            CTFrameDraw(frame, context)
            context.endPDFPage()
            let visible = CTFrameGetVisibleStringRange(frame)
            // Always advances, so a zero-visible frame (a degenerate rect) cannot loop.
            location += max(visible.length, 1)
            pages += 1
        }
        context.closePDF()
        return url
    }
}
