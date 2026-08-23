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
import CoreText

// MARK: - TripPacketSheet

/// Presents a generated research-trip packet (#830 T-2).
///
/// ## One sheet, both entry points
/// The scope doc says Project Home and a collection's overflow menu "feed the same aggregation".
/// They feed the same VIEW too — a second presenter would be a second place for the packet's
/// honesty rules to be applied differently, and those rules are the whole point of the feature.
///
/// ## The visit date is optional here, not merely nullable
/// D5: a packet is most useful *before* the trip is booked. The date picker is opt-in, and with no
/// date the checklist prints relative lead times. Nothing about the packet is withheld for want of
/// a date.
///
/// Version history:
///   1.0 — Session 2026-08-22: #830 T-2
///   1.1 — Session 2026-08-23: #830 — the roster's citations come from the real formatter
///          (the data source gains the manifest map), and a PDF share rides beside the
///          plain-text one — the SAME string paginated, never a second composition
struct TripPacketSheet: View {

    /// The reading list.
    let documents: [(volumeId: String, documentId: String)]
    /// Names the packet, and seeds nothing else.
    let title: String
    /// Seeds the inquiry's topic sentence (D8); `nil` yields the placeholder.
    let researchQuestion: String?

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var packet: String?
    /// The packet paginated as a PDF, regenerated with the packet itself.
    @State private var packetPDF: URL?
    @State private var hasDate = false
    @State private var arrival = Date()
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
                        Text(packet)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                } else {
                    // Not an error state: a project whose documents carry no indexed source notes
                    // genuinely has no packet to build, and saying so beats an empty page.
                    ContentUnavailableView(
                        String(localized: "packet.empty.title", defaultValue: "Nothing to plan yet"),
                        systemImage: "doc.text.magnifyingglass",
                        description: Text(String(
                            localized: "packet.empty.message",
                            defaultValue: "None of these documents has an indexed source note, so there is no archival trail to plan a visit around. Index the volumes they come from and try again.")))
                }
            }
            .navigationTitle(String(localized: "packet.title", defaultValue: "Archive visit"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .safeAreaInset(edge: .top) { dateBar }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done", defaultValue: "Done")) { dismiss() }
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
            .onChange(of: hasDate) { _, _ in Task { await rebuild() } }
            .onChange(of: arrival) { _, _ in Task { await rebuild() } }
        }
        #if os(macOS)
        .frame(minWidth: 620, minHeight: 640)
        #endif
    }

    /// The optional visit date (D5) — opt-in, and captioned so its absence reads as a choice.
    @ViewBuilder
    private var dateBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: $hasDate) {
                Text(String(localized: "packet.date.toggle", defaultValue: "I have a visit date"))
                    .font(.callout)
            }
            if hasDate {
                DatePicker(String(localized: "packet.date.label", defaultValue: "Arriving"),
                           selection: $arrival, displayedComponents: .date)
            } else {
                Text(String(localized: "packet.date.caption",
                            defaultValue: "Deadlines will be relative — this packet is meant to help you decide whether to go."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func rebuild() async {
        isBuilding = true
        defer { isBuilding = false }
        guard let pipeline = appState.indexingPipeline else {
            packet = nil
            packetPDF = nil
            return
        }
        // The same manifest set CollectionContentResolver batches, keyed once — what lets
        // the roster's citations come from the real formatter rather than the fallback.
        let manifest = appState.manifestStore.diffResult?.known
            ?? appState.manifestStore.bundledEntries
        let model = await TripPacketBuilder.build(
            documents: documents, researchQuestion: researchQuestion,
            dataSource: TripPacketDataSource(
                pipeline: pipeline,
                manifestMap: Dictionary(manifest.map { ($0.volumeId, $0) },
                                        uniquingKeysWith: { first, _ in first })))
        guard !model.groups.isEmpty || model.triage.unresolvedDocumentCount > 0 else {
            packet = nil
            packetPDF = nil
            return
        }
        let rendered = TripPacketExporter(model: model, projectName: title,
                                          arrival: hasDate ? arrival : nil).export()
        packet = rendered
        packetPDF = TripPacketPDFRenderer.render(packet: rendered, title: title)
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
            .appendingPathComponent("Archive visit — \(safeName).pdf")
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
