// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - CorpusView

/// The top-level Browser view showing corpus-wide statistics and the subseries list.
///
/// Tapping a subseries row navigates to `SubseriesView` via `BrowserViewModel.navigationPath`.
///
/// Version history:
///   1.0 — Session 11: initial implementation
///   1.1 — Session 58: wrap bare interpolation in accessibilityLabel with String(localized:) (F-022)
///   1.2 — Session 87: People cross-volume index entry
///   1.3 — Session 130: removed CorpusStatsView section (volume/document counts and date ranges
///          from the manifest were inaccurate or irrelevant to in-app navigation)
///   1.4 — #312: both row types are now tappable across the full row width. They were
///          `Button … .buttonStyle(.plain)` wrapping an intrinsically-sized label, so only the
///          label's own glyphs were hit-testable and most of a ~370pt row was dead space —
///          for a finger, not just for the UI-test harness that spent three investigations
///          (`UIObstructionTests` 1.6/1.7/1.9) blaming XCUITest for it.
struct CorpusView: View {

    let vm: BrowserViewModel

    var body: some View {
        List {
            // Cross-volume indices
            Section {
                Button {
                    vm.navigationPath.append(.people)
                } label: {
                    Label(
                        String(localized: "browser.corpus.people", defaultValue: "People"),
                        systemImage: "person.2"
                    )
                    .foregroundStyle(.primary)
                    // Both modifiers are required, and in this order. `.contentShape` reshapes the
                    // hit area WITHIN the view's frame; it does not widen the frame, and a bare
                    // `Label` in a List row is only as wide as its glyphs (~65pt of a ~370pt row).
                    // So contentShape alone buys nothing here — it just fills the gaps between the
                    // glyphs it already covers.
                    //
                    // A/B-MEASURED, not assumed (iPhone 17, iOS 26.3.1), against
                    // `UIObstructionTests.testBreadcrumbBarNotObstructingFirstRow`, which taps a row
                    // and requires a push: with contentShape ALONE the test FAILS ("did not push a
                    // browser level"); with the frame restored it PASSES, on iPhone and iPad both.
                    // Do not "simplify" by deleting the frame — that silently restores the dead zone
                    // and turns that test red. Same idiom as the Settings rows, where the greed comes
                    // from an `HStack { … Spacer() }` rather than an explicit frame.
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    String(localized: "browser.corpus.people.a11y",
                           defaultValue: "Browse people mentioned across all indexed volumes")
                )
                .help(String(localized: "browser.corpus.people.help",
                             defaultValue: "Browse an alphabetical index of all people mentioned across your indexed volumes — tap a name to search for every document where they appear"))
            }

            // Subseries list
            Section(header: Text(String(localized: "browser.corpus.subseries.header",
                                        defaultValue: "Subseries"))) {
                ForEach(vm.allSubseriesGroups) { group in
                    Button {
                        vm.navigationPath.append(.subseries(group))
                        #if DEBUG
                        print("[BrowserView] Navigate → subseries \(group.subseries)")
                        #endif
                    } label: {
                        SubseriesRowLabel(group: group)
                            // See the People row above for why the frame has to precede the
                            // contentShape, and for the measurement: the label's VStack is only as
                            // wide as its longest line, so contentShape alone does not reach the
                            // rest of the row. Both modifiers, in this order.
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        String(localized: "browser.corpus.subseries.a11y",
                               defaultValue: "Subseries \(group.subseries), \(group.totalVolumes) volumes")
                    )
                    .help(String(
                        localized: "browser.corpus.subseries.help",
                        defaultValue: "Browse the volumes and documents in this subseries"
                    ))
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
        .navigationTitle(String(localized: "browser.corpus.title", defaultValue: "FRUS Corpus"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        // #377 Phase 5: on regular-width iPad the top-inset "Working on:" banner is suppressed (it
        // collides with the floating tab bar, #238); surface the research question here instead.
        .workingOnSubtitle()
    }
}

// MARK: - SubseriesRowLabel

struct SubseriesRowLabel: View {
    let group: SubseriesGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(group.subseries)
                .font(.headline)
            HStack(spacing: 12) {
                Text("\(group.totalVolumes) vol.")
                if group.totalDocuments > 0 {
                    Text("\(group.totalDocuments) docs")
                }
                if let e = group.earliestDate, let l = group.latestDate {
                    Text("\(e.prefix(4))–\(l.prefix(4))")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }
}
