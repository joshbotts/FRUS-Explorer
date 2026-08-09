// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - ArchivalFlowsView

/// Where FRUS's editors sent the reader when they cross-referenced one document from another,
/// aggregated to the archival unit each document came from — the Flows mode (#765, design
/// direction 2b), over the bundled `provenance-flow-index.json` (#764).
///
/// ## The sentence this surface owes
/// 95.3% of these references are footnotes. A ribbon says *the editors, annotating material from
/// this collection, pointed the reader at material from that one* — it does **not** say the two
/// archives cite each other. The share is recomputed from the artifact so it cannot go stale.
///
/// ## No silent truncation
/// A focused collection can have up to 238 destinations. The diagram draws the ten heaviest as
/// blocks and folds every remaining one into a single dashed remainder block that states its own
/// count and reference total, and expands to a full list. Nothing is dropped without being
/// counted somewhere the reader can see.
///
/// Version history:
///   1.0 — Session 2026-08-09: #765 stage 2
struct ArchivalFlowsView: View {

    /// The bundled flow index.
    let index: ProvenanceFlowIndex
    /// The bundled authority, for names and repositories.
    let authority: CollectionAuthorityIndex
    /// Opens Archival Neighbors for a collection.
    let onOpenNeighbors: (AuthorityCollectionRecord) -> Void
    /// Volumes indexed on this device, for the export's provenance line.
    let indexedVolumeCount: Int
    /// Hands a table and its methods statement up to the shell, which owns the share sheet.
    let onExport: (ArchivalExportRequest) -> Void

    /// The focused collection, or `nil` for the corpus-wide view.
    @State private var focus: AuthorityCollectionRecord?
    /// Which way the focused hand-off runs.
    @State private var direction: ArchivalFlowDirection = .outgoing
    /// The selected endpoint's id, which pins the flow card.
    @State private var selectedEndpointId: String?
    /// Whether the remainder block has been expanded into a list.
    @State private var isRemainderExpanded = false
    /// Whether the focus picker is showing.
    @State private var isChoosingFocus = false
    /// The focus search field's text.
    @State private var searchText = ""

    /// The derivation. Cached in state rather than computed per body pass: the corpus-wide view
    /// sorts all 4,871 stored flows, and a focused view linear-scans them after a `firstIndex`
    /// over 1,111 ids — cheap once, wasteful on every frame.
    @State private var cached: ArchivalFlowsData?

    var body: some View {
        let data = cached ?? ArchivalFlowsData.corpusWide(index: index, authority: authority)
        content(data)
            .sheet(isPresented: $isChoosingFocus) { focusPicker }
            .task(id: "\(focus?.id ?? "")|\(direction.rawValue)") { await rebuild() }
    }

    /// Rebuilds off the main actor, for the same reason the Network does.
    private func rebuild() async {
        let inputs = (index: index, authority: authority, focus: focus, direction: direction)
        let built = await Task.detached(priority: .userInitiated) {
            guard let focus = inputs.focus else {
                return ArchivalFlowsData.corpusWide(index: inputs.index,
                                                    authority: inputs.authority)
            }
            return ArchivalFlowsData.focused(on: focus, direction: inputs.direction,
                                             index: inputs.index, authority: inputs.authority)
        }.value
        // A detached child outlives its parent's cancellation; without this a superseded
        // derivation could land after the current one and pin the wrong diagram.
        guard !Task.isCancelled else { return }
        cached = built
    }

    @ViewBuilder
    private func content(_ data: ArchivalFlowsData) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            intro(data)
            filterRow
            if data.focus == nil {
                corpusWideCard(data)
            } else if data.endpoints.isEmpty {
                noFlowsState(data)
            } else {
                diagramCard(data)
                if isRemainderExpanded { remainderList(data) }
            }
            if let selected = data.endpoints.first(where: { $0.id == selectedEndpointId }),
               !selected.isRemainder {
                flowCard(selected, data: data)
            }
            caveats(data)
        }
    }

    // MARK: - Intro and filters

    private func intro(_ data: ArchivalFlowsData) -> some View {
        Text(String(localized: "archival.flows.intro",
                    defaultValue: "When a FRUS editor annotated one published document by pointing to another, the two documents usually came from different archives. Added up across the series, those pointers map the paths the editors walked between bodies of records."))
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var filterRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { filterChips; Spacer(minLength: 0) }
            VStack(alignment: .leading, spacing: 8) { filterChips }
        }
    }

    @ViewBuilder
    private var filterChips: some View {
        Button {
            isChoosingFocus = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "scope").font(.caption2)
                Text(String(localized: "archival.flows.focus", defaultValue: "Focus"))
                    .font(.caption).foregroundStyle(.secondary)
                Text(focus?.name ?? String(localized: "archival.flows.focus.all",
                                           defaultValue: "The whole series"))
                    .font(.caption.weight(.medium)).lineLimit(1)
                Image(systemName: "chevron.down").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        if focus != nil {
            Button {
                clearFocus()
            } label: {
                Label(String(localized: "archival.flows.clearFocus", defaultValue: "Clear focus"),
                      systemImage: "xmark.circle.fill")
                    .font(.caption)
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel(String(localized: "archival.flows.clearFocus",
                                       defaultValue: "Clear focus"))

            Picker(String(localized: "archival.flows.direction", defaultValue: "Direction"),
                   selection: $direction) {
                ForEach(ArchivalFlowDirection.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)
            .onChange(of: direction) { _, _ in
                selectedEndpointId = nil
                isRemainderExpanded = false
            }
        }

        // CSV only, for the same reason as the Network: the ribbons are a `Canvas`, and no figure
        // has ever been rendered from one in this app.
        AnalyticsSectionExportControl(exportCSV: { export(cached) })
    }

    /// Exports the diagram's rows — every destination, including the ones folded into the
    /// remainder block, because a CSV that stopped at the drawn blocks would be the silent
    /// truncation the diagram itself refuses.
    private func export(_ data: ArchivalFlowsData?) {
        let data = data ?? ArchivalFlowsData.corpusWide(index: index, authority: authority)
        let title: String
        let axis: String
        let columns: [String]
        let rows: [[String]]
        if let focus = data.focus {
            title = String(format: String(localized: "archival.export.title.flows %@ %@",
                                          defaultValue: "%1$@ — %2$@"),
                           focus.name, direction.title)
            axis = direction == .outgoing
                ? String(localized: "archival.export.axis.flows.outgoing",
                         defaultValue: "References out of this collection")
                : String(localized: "archival.export.axis.flows.incoming",
                         defaultValue: "References into this collection")
            columns = [
                String(localized: "archival.table.unit", defaultValue: "Archival unit"),
                String(localized: "archival.table.custodian", defaultValue: "Custodian"),
                String(localized: "archival.export.unit.references", defaultValue: "References"),
            ]
            rows = data.allEndpoints.map {
                [$0.label, $0.category.displayName, "\($0.count)"]
            }
        } else {
            title = String(localized: "archival.flows.top.title",
                           defaultValue: "The heaviest hand-offs in the series")
            axis = String(localized: "archival.export.axis.flows.top",
                          defaultValue: "Ranked by references between the pair")
            columns = [
                String(localized: "archival.export.column.source", defaultValue: "From"),
                String(localized: "archival.export.column.target", defaultValue: "To"),
                String(localized: "archival.export.unit.references", defaultValue: "References"),
            ]
            rows = data.topPairs.map { [$0.source.label, $0.target.label, "\($0.source.count)"] }
        }
        onExport(ArchivalExportRequest(
            table: ChartInspectorData(id: "archival.flows", title: title, columns: columns,
                                      rowCells: rows),
            provenance: ArchivalAnalyticsExport.flows(
                title: title, axisLabel: axis, data: data,
                indexedVolumeCount: indexedVolumeCount)))
    }

    // MARK: - Corpus-wide

    private func corpusWideCard(_ data: ArchivalFlowsData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "archival.flows.top.title",
                        defaultValue: "The heaviest hand-offs in the series"))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text(String(localized: "archival.flows.top.caption",
                        defaultValue: "Choose a focus collection above to see everywhere its documents point."))
                .font(.caption).foregroundStyle(.secondary)
            ForEach(Array(data.topPairs.enumerated()), id: \.offset) { _, pair in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Circle().fill(pair.source.category.color).frame(width: 7, height: 7)
                    Text(pair.source.label).font(.callout).lineLimit(1)
                    Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
                    Circle().fill(pair.target.category.color).frame(width: 7, height: 7)
                    Text(pair.target.label).font(.callout).lineLimit(1)
                    Spacer(minLength: 8)
                    Text(pair.source.count, format: .number)
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(format: String(
                    localized: "archival.flows.top.a11y %@ %@ %lld",
                    defaultValue: "%1$@ to %2$@, %3$lld references"),
                    pair.source.label, pair.target.label, Int64(pair.source.count)))
                Divider()
            }
        }
    }

    // MARK: - The focused diagram

    private func diagramCard(_ data: ArchivalFlowsData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(diagramTitle(data)).font(.headline).accessibilityAddTraits(.isHeader)
                Spacer()
                Text(String(format: direction == .outgoing
                            ? String(localized: "archival.flows.showingAll.outgoing %lld",
                                     defaultValue: "all %lld destinations")
                            : String(localized: "archival.flows.showingAll.incoming %lld",
                                     defaultValue: "all %lld origins"),
                            Int64(data.allEndpoints.count)))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text(diagramCaption(data)).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    ribbonCanvas(data, size: geometry.size)
                    blockOverlay(data, size: geometry.size)
                }
            }
            .frame(height: diagramHeight(data))
        }
    }

    private func diagramTitle(_ data: ArchivalFlowsData) -> String {
        direction == .outgoing
            ? String(localized: "archival.flows.title.outgoing",
                     defaultValue: "Where these documents point")
            : String(localized: "archival.flows.title.incoming",
                     defaultValue: "What points at these documents")
    }

    private func diagramCaption(_ data: ArchivalFlowsData) -> String {
        String(format: direction == .outgoing
                ? String(localized: "archival.flows.caption.outgoing %lld %lld",
                         defaultValue: "%1$lld references run from this collection to others. A further %2$lld stay inside the collection itself and are excluded — a hand-off to yourself is not a hand-off.")
                : String(localized: "archival.flows.caption.incoming %lld %lld",
                         defaultValue: "%1$lld references run from other collections to this one. A further %2$lld stay inside the collection itself and are excluded — a hand-off to yourself is not a hand-off."),
            Int64(data.totalReferences), Int64(data.sameUnitReferences))
    }

    private func diagramHeight(_ data: ArchivalFlowsData) -> CGFloat {
        CGFloat(max(data.endpoints.count, 1)) * 44 + 24
    }

    /// Block geometry, shared by the canvas and the button overlay so a ribbon always lands on
    /// the block a reader can actually tap.
    private func blockFrames(_ data: ArchivalFlowsData, size: CGSize) -> [String: CGRect] {
        let width = destinationWidth(for: size)
        let rowHeight: CGFloat = 44
        var frames: [String: CGRect] = [:]
        for (index, endpoint) in data.endpoints.enumerated() {
            frames[endpoint.id] = CGRect(x: size.width - width,
                                         y: CGFloat(index) * rowHeight + 12,
                                         width: width, height: rowHeight - 8)
        }
        return frames
    }

    /// The two columns are budgeted from ONE width so they cannot collide. Clamping each
    /// independently let their minimums (100 + 120) exceed a narrow canvas, and below about
    /// 220pt the destination blocks were drawn on top of the focus block with every ribbon
    /// running backwards.
    private func destinationWidth(for size: CGSize) -> CGFloat {
        max(min(size.width * 0.42, 260), size.width * 0.34)
    }

    private func focusFrame(_ data: ArchivalFlowsData, size: CGSize) -> CGRect {
        let width = max(size.width - destinationWidth(for: size) - 48, 60)
        let height = min(CGFloat(data.endpoints.count) * 44, size.height - 24)
        return CGRect(x: 0, y: 12, width: width, height: max(height - 8, 44))
    }

    private func ribbonCanvas(_ data: ArchivalFlowsData, size: CGSize) -> some View {
        let frames = blockFrames(data, size: size)
        let origin = focusFrame(data, size: size)
        let maxCount = data.endpoints.map(\.count).max() ?? 1
        return Canvas { context, _ in
            // The focus block.
            context.fill(Path(roundedRect: origin, cornerRadius: 8),
                         with: .color((data.focusCategory ?? .otherInstitution).color.opacity(0.18)))
            for endpoint in data.endpoints {
                guard let frame = frames[endpoint.id] else { continue }
                let thickness = max(2, CGFloat(endpoint.count) / CGFloat(maxCount) * 22)
                let startY = origin.midY
                let endY = frame.midY
                var path = Path()
                path.move(to: CGPoint(x: origin.maxX, y: startY - thickness / 2))
                path.addCurve(to: CGPoint(x: frame.minX, y: endY - thickness / 2),
                              control1: CGPoint(x: origin.maxX + 60, y: startY - thickness / 2),
                              control2: CGPoint(x: frame.minX - 60, y: endY - thickness / 2))
                path.addLine(to: CGPoint(x: frame.minX, y: endY + thickness / 2))
                path.addCurve(to: CGPoint(x: origin.maxX, y: startY + thickness / 2),
                              control1: CGPoint(x: frame.minX - 60, y: endY + thickness / 2),
                              control2: CGPoint(x: origin.maxX + 60, y: startY + thickness / 2))
                path.closeSubpath()
                let isSelected = selectedEndpointId == endpoint.id
                context.fill(path, with: .color(endpoint.category.color
                    .opacity(isSelected ? 0.55 : 0.28)))
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func blockOverlay(_ data: ArchivalFlowsData, size: CGSize) -> some View {
        let frames = blockFrames(data, size: size)
        let origin = focusFrame(data, size: size)
        VStack(alignment: .leading, spacing: 2) {
            Text(data.focus?.name ?? "").font(.caption.weight(.semibold)).lineLimit(2)
            Text(String(format: String(localized: "archival.flows.focusBlock %lld",
                                       defaultValue: "%lld references"),
                        Int64(data.totalReferences)))
                .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
        }
        .padding(6)
        .frame(width: origin.width, height: origin.height, alignment: .topLeading)
        .position(x: origin.midX, y: origin.midY)
        .accessibilityElement(children: .combine)

        ForEach(data.endpoints) { endpoint in
            if let frame = frames[endpoint.id] {
                Button {
                    if endpoint.isRemainder {
                        isRemainderExpanded.toggle()
                    } else {
                        selectedEndpointId = selectedEndpointId == endpoint.id ? nil : endpoint.id
                    }
                } label: {
                    HStack(spacing: 6) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(endpoint.label).font(.caption).lineLimit(1)
                            if let repository = endpoint.repository {
                                Text(repository).font(.system(size: 9)).foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 4)
                        Text(endpoint.count, format: .number)
                            .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .frame(width: frame.width, height: frame.height, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(endpoint.category.color.opacity(0.14))
                            .overlay {
                                RoundedRectangle(cornerRadius: 7)
                                    .strokeBorder(endpoint.category.color.opacity(0.5),
                                                  style: StrokeStyle(lineWidth: 1,
                                                                     dash: endpoint.isRemainder ? [4, 3] : []))
                            }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .position(x: frame.midX, y: frame.midY)
                .accessibilityLabel(endpoint.label)
                .accessibilityValue(String(format: String(
                    localized: "archival.flows.block.a11y %lld",
                    defaultValue: "%lld references"), Int64(endpoint.count)))
                .accessibilityHint(endpoint.isRemainder
                                   ? String(localized: "archival.flows.block.hint.remainder",
                                            defaultValue: "Expands the collections folded into this block")
                                   : String(localized: "archival.flows.block.hint",
                                            defaultValue: "Selects this hand-off"))
            }
        }
    }

    /// The expanded remainder — every collection the diagram folded, listed in full.
    private func remainderList(_ data: ArchivalFlowsData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(direction == .outgoing
                 ? String(localized: "archival.flows.remainder.title.outgoing",
                          defaultValue: "The rest of the destinations")
                 : String(localized: "archival.flows.remainder.title.incoming",
                          defaultValue: "The rest of the origins"))
                .font(.subheadline.weight(.medium))
            ForEach(Array(data.allEndpoints.dropFirst(ArchivalFlowsData.endpointCap))) { endpoint in
                HStack(spacing: 8) {
                    Circle().fill(endpoint.category.color).frame(width: 6, height: 6)
                    Text(endpoint.label).font(.caption).lineLimit(1)
                    Spacer(minLength: 8)
                    Text(endpoint.count, format: .number)
                        .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: - Flow card

    private func flowCard(_ endpoint: ArchivalFlowEndpoint,
                          data: ArchivalFlowsData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(format: String(localized: "archival.flows.card.title %@ %@",
                                       defaultValue: "%1$@ → %2$@"),
                        direction == .outgoing ? (data.focus?.name ?? "") : endpoint.label,
                        direction == .outgoing ? endpoint.label : (data.focus?.name ?? "")))
                .font(.headline)
            Text(String(format: direction == .outgoing
                        ? String(localized: "archival.flows.card.detail.outgoing %lld %lld",
                                 defaultValue: "%1$lld references, %2$lld%% of everything this collection hands off.")
                        : String(localized: "archival.flows.card.detail.incoming %lld %lld",
                                 defaultValue: "%1$lld references, %2$lld%% of everything handed off to this collection."),
                Int64(endpoint.count),
                Int64(data.totalReferences > 0
                      ? (endpoint.count * 100 / data.totalReferences) : 0)))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            // "Browse these citations" is deliberately absent — see the caveats. What the app can
            // honestly offer is the other half of the pair, through a route that exists.
            if let record = authority.record(id: endpoint.id) {
                Button {
                    onOpenNeighbors(record)
                } label: {
                    Label(String(localized: "archival.flows.card.neighbors",
                                 defaultValue: "Show Archival Neighbors"),
                          systemImage: "square.stack.3d.up")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Empty state

    private func noFlowsState(_ data: ArchivalFlowsData) -> some View {
        ContentUnavailableView(
            String(localized: "archival.flows.none.title", defaultValue: "No Hand-Offs Recorded"),
            systemImage: "arrow.triangle.branch",
            description: Text(String(format: String(
                localized: "archival.flows.none.detail %@ %lld %lld",
                defaultValue: "No cross-reference runs between %1$@ and another collection in this direction. The cross-reference style these come from postdates 1945. Only %2$lld of the %3$lld volumes in the series carry any of these references."),
                data.focus?.name ?? "", Int64(data.volumesWithEdges),
                Int64(data.volumesScanned)))
        )
    }

    // MARK: - Caveats

    private func caveats(_ data: ArchivalFlowsData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "archival.caveats.title", defaultValue: "About these figures"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(String(format: String(
                localized: "archival.flows.caveats.footnotes %@",
                defaultValue: "%@ of these references are footnotes. A ribbon therefore describes how the editors annotated. While annotating material from one collection, they pointed the reader to material from another. It is not a relationship between the archives themselves."),
                data.footnoteShare.formatted(.percent.precision(.fractionLength(1)))))
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(String(format: String(
                localized: "archival.flows.caveats.body.v2 %lld %lld %lld %lld",
                defaultValue: "Coverage is uneven, and the gap is itself a finding. Only %1$lld of the %2$lld volumes in the series contribute a single reference. The cross-reference style these come from postdates 1945. The figures cover the whole series whatever you have downloaded, but they carry no dates. The stored data is a pair of archival units and a count, with no volume or year attached. So you cannot narrow this mode to a period. Central-file classes are left out on purpose. Across the whole series they carry %3$lld references over %4$lld pairs, which is under two per pair. That is too thin to rank, and there are no labels to rank it with."),
                Int64(data.volumesWithEdges), Int64(data.volumesScanned),
                Int64(data.classBetweenReferences), Int64(data.classBetweenPairs)))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(String(localized: "archival.flows.caveats.browse",
                        defaultValue: "You cannot browse the individual citations here. The app can list the references inside the volumes you have indexed. It cannot tell which of those are the footnotes this measure is built on. A list would therefore disagree with the diagram above it, and nothing on screen would explain why."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    // MARK: - Focus picker

    private var focusPicker: some View {
        NavigationStack {
            List(pickerCandidates, id: \.record.id) { candidate in
                Button {
                    focus = candidate.record
                    selectedEndpointId = nil
                    isRemainderExpanded = false
                    isChoosingFocus = false
                } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(candidate.record.name).font(.callout)
                        Text(String(format: String(
                            localized: "archival.flows.picker.caption %@ %lld",
                            defaultValue: "%1$@ · %2$lld references"),
                            candidate.record.repository
                                ?? ArchivalRepositoryCategory.from(candidate.record).displayName,
                            Int64(candidate.references)))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $searchText,
                        prompt: Text(String(localized: "archival.flows.picker.prompt",
                                            defaultValue: "Set focus collection…")))
            .navigationTitle(String(localized: "archival.flows.picker.title",
                                    defaultValue: "Focus Collection"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel", defaultValue: "Cancel")) {
                        isChoosingFocus = false
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 460)
        #endif
    }

    /// Only collections that actually appear in a between-unit flow are offered — a picker that
    /// listed all 4,423 records would mostly lead to the empty state.
    private var pickerCandidates: [(record: AuthorityCollectionRecord, references: Int)] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ArchivalFlowsData.focusCandidates(index: index, authority: authority)
            .filter {
                query.isEmpty || $0.record.name.lowercased().contains(query)
                    || ($0.record.repository?.lowercased().contains(query) ?? false)
            }
            .prefix(200)
            .map { $0 }
    }

    private func clearFocus() {
        focus = nil
        selectedEndpointId = nil
        isRemainderExpanded = false
    }
}
