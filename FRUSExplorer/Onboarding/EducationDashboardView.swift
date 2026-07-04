// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import Charts

// MARK: - EducationDashboard

/// Identifies a live SwiftUI dashboard rendered in place of a Research Guide
/// page's static prose `sections`.
///
/// When an `EducationPage` carries a non-`nil` `dashboard`, both platform
/// content renderers (`macContentArea` on macOS, `iOSPageView` on iOS/iPadOS)
/// substitute an `EducationDashboardView` for the usual prose section stack —
/// the additive content-model extension introduced by Analytics Prep-A so the
/// forthcoming "About the Series" dashboards (SA-1…SA-3) can live inside the
/// guide.
///
/// Prep-A ships only `.placeholder`, a development-only proof-of-pipe. The
/// Series Analytics sessions extend this enum (production / administration /
/// archival cases) and the `switch` in `EducationDashboardView`.
///
/// Version history:
///   1.0 — Analytics Prep-A: initial implementation; `.placeholder` only
enum EducationDashboard: String, Hashable {
    /// A development-only placeholder proving an arbitrary live SwiftUI view —
    /// including a Swift Charts chart reading bundled `manifest.json` — renders
    /// inside the guide content pane offline and with zero index. Replaced by
    /// the real Series dashboards in SA-1…SA-3. `#if DEBUG`-gated at its only
    /// construction site, so release builds never surface it.
    case placeholder
}

// MARK: - EducationDashboardView

/// The single enum-to-view mapping site that renders the concrete dashboard for
/// an `EducationDashboard` value.
///
/// This is deliberately the one extension point the Series Analytics sessions
/// (SA-1…SA-3) grow: each new `EducationDashboard` case adds one `switch` arm
/// here pointing at its own dashboard view. Keeping the mapping centralised
/// means the two content renderers in `IndexingEducationView` need no knowledge
/// of individual dashboards — they only branch on `page.dashboard != nil`.
///
/// Version history:
///   1.0 — Analytics Prep-A: initial implementation; renders `.placeholder`
struct EducationDashboardView: View {

    /// Which dashboard to render.
    let dashboard: EducationDashboard

    var body: some View {
        switch dashboard {
        case .placeholder:
            PlaceholderDashboard()
        }
    }
}

// MARK: - Placeholder dashboard

/// Development-only dashboard that proves the Prep-A pipe end-to-end: a live
/// SwiftUI view — with a real Swift Charts bar chart — computed from the always-
/// available bundled `manifest.json`, so it renders offline, with zero index,
/// and mid-onboarding.
///
/// It reads `AppState.manifestStore.bundledEntries` to derive two genuinely
/// live figures (total volume count and distinct subseries count) and a bar
/// chart of volumes bucketed by `VolumeStatus`. `AppState` is read as an
/// optional environment value so an absent environment degrades to a neutral
/// empty state rather than trapping.
///
/// Version history:
///   1.0 — Analytics Prep-A: initial implementation
private struct PlaceholderDashboard: View {

    /// Optional so a missing environment yields a neutral empty state instead
    /// of a trap. Both live presentation paths (the onboarding sheet and the
    /// standalone Research Guide) inject `AppState` at the scene root, so this
    /// normally resolves; the optionality is purely defensive and adds no
    /// second injection.
    @Environment(AppState.self) private var appState: AppState?

    /// One bucket of the by-status bar chart: a `VolumeStatus` and how many
    /// bundled volumes carry it.
    private struct StatusBucket: Identifiable {
        let status: VolumeStatus
        let count: Int
        var id: String { status.rawValue }
    }

    /// The bundled manifest entries, or an empty array when `AppState` is
    /// absent (defensive) — never crashes.
    private var entries: [VolumeManifestEntry] {
        appState?.manifestStore.bundledEntries ?? []
    }

    /// Distinct subseries identifiers across the bundled manifest.
    private var distinctSubseriesCount: Int {
        Set(entries.map(\.subseries)).count
    }

    /// Volumes bucketed by publication status, in a stable display order.
    private var statusBuckets: [StatusBucket] {
        let order: [VolumeStatus] = [.published, .partiallyPublished, .planned]
        return order.map { status in
            StatusBucket(status: status, count: entries.filter { $0.status == status }.count)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            Label(
                String(localized: "education.dashboard.placeholder.badge",
                       defaultValue: "Development placeholder"),
                systemImage: "hammer"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

            Text(String(localized: "education.dashboard.placeholder.caption",
                        defaultValue: "This is a Prep-A pipe check: an arbitrary live SwiftUI view — including a real chart — rendered in place of a page's prose, computed from the bundled manifest so it works offline, with no index, mid-onboarding."))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if entries.isEmpty {
                // Neutral empty state — the bundled manifest was unavailable
                // (e.g. AppState absent). Never a crash.
                ContentUnavailableViewCompat(
                    title: String(localized: "education.dashboard.placeholder.empty.title",
                                  defaultValue: "No manifest data"),
                    message: String(localized: "education.dashboard.placeholder.empty.message",
                                    defaultValue: "The bundled volume manifest is unavailable in this context.")
                )
            } else {
                liveFigures
                statusChart
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The two live scalar figures derived from the bundled manifest.
    private var liveFigures: some View {
        HStack(spacing: 28) {
            figure(
                value: entries.count,
                label: String(localized: "education.dashboard.placeholder.figure.volumes",
                              defaultValue: "Volumes")
            )
            figure(
                value: distinctSubseriesCount,
                label: String(localized: "education.dashboard.placeholder.figure.subseries",
                              defaultValue: "Subseries")
            )
        }
    }

    /// A single large-number + caption figure.
    private func figure(value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value, format: .number)
                .font(.largeTitle.weight(.bold))
                .monospacedDigit()
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    /// A minimal Swift Charts bar chart of volumes by publication status,
    /// mirroring the `AnalyticsView` bar-chart idiom (`BarMark` +
    /// `.foregroundStyle(by:)`).
    private var statusChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "education.dashboard.placeholder.chart.title",
                        defaultValue: "Volumes by publication status"))
                .font(.headline)

            Chart {
                ForEach(statusBuckets) { bucket in
                    BarMark(
                        x: .value(
                            String(localized: "education.dashboard.placeholder.chart.status",
                                   defaultValue: "Status"),
                            statusLabel(bucket.status)
                        ),
                        y: .value(
                            String(localized: "education.dashboard.placeholder.chart.volumes",
                                   defaultValue: "Volumes"),
                            bucket.count
                        )
                    )
                    .foregroundStyle(by: .value(
                        String(localized: "education.dashboard.placeholder.chart.status",
                               defaultValue: "Status"),
                        statusLabel(bucket.status)
                    ))
                    .accessibilityLabel(Text(statusLabel(bucket.status)))
                    .accessibilityValue(Text(bucket.count, format: .number))
                }
            }
            .frame(height: 200)
        }
    }

    /// Localised display label for a `VolumeStatus`.
    private func statusLabel(_ status: VolumeStatus) -> String {
        switch status {
        case .published:
            return String(localized: "education.dashboard.placeholder.status.published",
                          defaultValue: "Published")
        case .partiallyPublished:
            return String(localized: "education.dashboard.placeholder.status.partial",
                          defaultValue: "Partial")
        case .planned:
            return String(localized: "education.dashboard.placeholder.status.planned",
                          defaultValue: "Planned")
        }
    }
}

// MARK: - Compatibility empty state

/// Minimal neutral empty-state view used by `PlaceholderDashboard` when the
/// bundled manifest is unavailable.
///
/// A small hand-rolled placeholder (rather than `ContentUnavailableView`) keeps
/// this development-only dashboard free of availability branching; it is never
/// shown in a shipping build.
///
/// Version history:
///   1.0 — Analytics Prep-A: initial implementation
private struct ContentUnavailableViewCompat: View {

    /// Bold title line.
    let title: String
    /// Secondary explanatory line.
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 12)
    }
}
