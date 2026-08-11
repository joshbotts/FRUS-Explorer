// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - ArchivalAllUnitsSheet

/// Every archival unit an era reaches, not just the twelve the chart draws (#825c).
///
/// ## Why this exists as its own screen
/// The Collections ranking has always capped at twelve rows, and its caption has always counted
/// the units reached in the hundreds — 214 collections in a scoped era, 1,800-odd in the widest.
/// The rows past the cap were reachable nowhere: the table inspector and the CSV export both
/// carried the *capped* twelve, so the full list could not be obtained inside the app or taken
/// out of it. A reader who saw "draw on 214 collections" and wanted the other 202 had no move.
///
/// ## What it does not do
/// It does not re-rank, re-weight or re-filter. It is the same derivation the chart above it
/// used, with the row cap lifted, so the two can never tell different stories — the era, the
/// unit lens, the weight and the umbrella chip all arrive as parameters rather than being
/// re-decided here.
///
/// Rows that cannot open (a collection id the authority does not carry) render without a
/// chevron rather than as a control that does nothing.
///
/// Version history:
///   1.0 — Session 2026-08-10: #825(c)
struct ArchivalAllUnitsSheet: View {

    /// The era the rows describe.
    let band: ArchivalEraBand
    /// Named collections or central-file classes.
    let lens: ArchivalUnitLens
    /// Documents or volumes.
    let weight: ArchivalWeight
    /// Whether the `Central Files` umbrella is withheld, exactly as the chart had it.
    let hidingUmbrella: Bool
    /// The derivation the chart used.
    let data: ArchivalCollectionsData
    /// Volumes indexed on this device, for the export's methods statement.
    let indexedVolumeCount: Int
    /// Opens one row, delegated to the host so the destination logic lives in one place.
    let onOpen: (ArchivalRankingRow) -> Void
    /// Whether a row has a destination at all.
    let canOpen: (ArchivalRankingRow) -> Bool

    @Environment(\.dismiss) private var dismiss
    /// Delivery for this table's own CSV — the uncapped one.
    @State private var exportBox = SeriesExportBox()

    /// The uncapped ranking. `limit:` is the row cap the chart applies; `.max` lifts it.
    private var ranking: ArchivalRanking {
        data.ranking(band: band, lens: lens, weight: weight,
                     hidingUmbrella: hidingUmbrella, limit: .max)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(ranking.rows.enumerated()), id: \.element.id) { index, row in
                        rowView(index: index, row: row)
                    }
                } header: {
                    Text(header)
                } footer: {
                    Text(footer)
                }
            }
            .navigationTitle(String(localized: "archival.allUnits.title",
                                    defaultValue: "Every Unit"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    AnalyticsSectionExportControl(
                        isEnabled: !ranking.rows.isEmpty,
                        exportCSV: { exportBox.deliver(table, provenance) })
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done", defaultValue: "Done")) { dismiss() }
                }
            }
        }
        .seriesExportPresentation(exportBox)
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 520)
        #endif
    }

    @ViewBuilder
    private func rowView(index: Int, row: ArchivalRankingRow) -> some View {
        let opens = canOpen(row)
        Button {
            guard opens else { return }
            onOpen(row)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(index + 1).")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
                // `label`, not `name`: `disambiguate` appends the repository (and, failing that,
                // the authority id) to names carried by more than one record. Drawing `name`
                // here would print `White House Central Files` six times over in one band —
                // six identical rows, each opening a different collection.
                Text(row.label)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(row.value, format: .number)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                if opens {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            // A greedy frame first, then the shape: without both, only the glyphs are tappable.
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!opens)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(opens ? .isButton : [])
    }

    private var header: String {
        String(format: String(localized: "archival.allUnits.header %lld %@",
                              defaultValue: "%1$lld units · %2$@"),
               Int64(ranking.rows.count), band.title)
    }

    private var footer: String {
        String(format: String(
            localized: "archival.allUnits.footer %@ %@",
            defaultValue: "Ranked by %1$@, same as the chart. %2$@"),
            weight.title.lowercased(),
            hidingUmbrella && lens == .namedCollections
                ? String(localized: "archival.allUnits.footer.umbrella",
                         defaultValue: "The Central Files umbrella record is withheld here too, so this list and the chart above count the same population.")
                : String(localized: "archival.allUnits.footer.everything",
                         defaultValue: "Nothing is withheld."))
    }

    /// The whole list as a table — the value the CSV writes, so the export and the screen cannot
    /// disagree about which rows are in it.
    private var table: ChartInspectorData {
        ChartInspectorData(
            id: "archival.allUnits",
            title: String(format: String(localized: "archival.allUnits.export.title %@ %@",
                                         defaultValue: "%1$@ — every unit, %2$@"),
                          lens.title, band.title),
            columns: [
                String(localized: "archival.table.unit", defaultValue: "Archival unit"),
                String(localized: "archival.table.custodian", defaultValue: "Custodian"),
                weight.title,
            ],
            rowCells: ranking.rows.map { [$0.label, $0.category.displayName, "\($0.value)"] })
    }

    private var provenance: AnalyticsProvenance {
        ArchivalAnalyticsExport.ranking(
            band: band, lens: lens, weight: weight,
            hiddenUmbrella: ranking.hiddenUmbrellaValue, unitsReached: ranking.unitsReached,
            bandVolumeCount: ranking.bandVolumeCount, indexedVolumeCount: indexedVolumeCount,
            noteCount: ranking.bandNoteCount, shownValue: ranking.shownValue,
            rowCapApplied: false)
    }
}
