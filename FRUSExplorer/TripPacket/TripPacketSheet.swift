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
        guard let pipeline = appState.indexingPipeline else { packet = nil; return }
        let model = await TripPacketBuilder.build(
            documents: documents, researchQuestion: researchQuestion,
            dataSource: TripPacketDataSource(pipeline: pipeline))
        guard !model.groups.isEmpty || model.triage.unresolvedDocumentCount > 0 else {
            packet = nil
            return
        }
        packet = TripPacketExporter(model: model, projectName: title,
                                    arrival: hasDate ? arrival : nil).export()
    }
}
