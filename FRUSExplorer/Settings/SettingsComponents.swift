// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - StorageUsageBreakdown

/// The proportional split of managed storage, ready to draw (S-2).
///
/// Pure value type with no SwiftUI in it, so the arithmetic that decides how a usage bar looks —
/// including the awkward cases — is unit-testable. `SettingsUsageBar` renders it.
///
/// Version history:
///   1.0 — S-2a: initial implementation
struct StorageUsageBreakdown: Equatable, Sendable {

    /// One labelled slice of the bar.
    struct Segment: Equatable, Sendable, Identifiable {
        /// Stable identity for `ForEach`; also the legend key.
        let id: String
        /// The legend label, already localized.
        let label: String
        /// Bytes this segment accounts for.
        let bytes: Int
        /// Fraction of the total, `0...1`. Zero when the total is zero.
        let share: Double
    }

    /// The segments, in draw order, **excluding** any that measure zero bytes.
    ///
    /// A zero-byte segment is dropped rather than drawn at zero width: a summaries figure of 0 is
    /// the normal state before any summary is generated, and a hairline artifact there reads as a
    /// rendering bug. Dropping it also keeps the legend honest — a legend entry for something
    /// occupying none of the bar is noise.
    let segments: [Segment]

    /// Total bytes across every segment, zero included.
    let totalBytes: Int

    /// Whether there is anything to draw. False on a fresh install, where the bar should be
    /// replaced by an empty state rather than rendered as an empty track.
    var isEmpty: Bool { totalBytes <= 0 }

    /// Builds the breakdown from the three figures `StorageReport` measures.
    ///
    /// - Parameters:
    ///   - volumeBytes: Downloaded volume XML.
    ///   - indexBytes: The FTS5 search index.
    ///   - summaryBytes: Stored AI summaries.
    /// - Returns: The breakdown, with zero-byte segments omitted and shares summing to 1 (or all
    ///   zero when nothing is stored).
    static func make(volumeBytes: Int, indexBytes: Int, summaryBytes: Int) -> StorageUsageBreakdown {
        let raw: [(id: String, label: String, bytes: Int)] = [
            ("xml", String(localized: "settings.storage.segment.xml", defaultValue: "XML"), max(0, volumeBytes)),
            ("index", String(localized: "settings.storage.segment.index", defaultValue: "Index"), max(0, indexBytes)),
            ("summaries", String(localized: "settings.storage.segment.summaries", defaultValue: "Summaries"), max(0, summaryBytes)),
        ]
        let total = raw.reduce(0) { $0 + $1.bytes }
        let segments = raw.filter { $0.bytes > 0 }.map { entry in
            Segment(id: entry.id,
                    label: entry.label,
                    bytes: entry.bytes,
                    share: total > 0 ? Double(entry.bytes) / Double(total) : 0)
        }
        return StorageUsageBreakdown(segments: segments, totalBytes: total)
    }
}

// MARK: - LibraryStatusSummary

/// The hub hero's one-line state of the library (S-2).
///
/// Pure so the sentence can be tested; the hero card just renders `text`. The clauses are ordered
/// most-actionable-last, so the eye lands on the thing that needs doing.
///
/// Version history:
///   1.0 — S-2a: initial implementation
///   1.1 — S-2b: the attention clause agrees in number ("1 needs" / "2 need"), which the single
///          `%lld needs attention` form got wrong for every count but one
struct LibraryStatusSummary: Equatable, Sendable {

    /// Volumes downloaded to this device.
    let downloadedCount: Int
    /// Volumes the manifest knows about.
    let catalogCount: Int
    /// Downloaded volumes that carry a search index.
    let indexedCount: Int
    /// Volumes whose indexing was interrupted and needs re-running.
    let interruptedCount: Int

    /// The rendered summary, e.g. `"12 of 540 downloaded · all indexed · nothing needs attention"`.
    ///
    /// Reads three facts in a fixed order — how much of the corpus is here, whether it is
    /// searchable, and whether anything is broken — so the line's shape is stable enough to scan
    /// even as the numbers change.
    var text: String {
        var clauses: [String] = [
            String(format: String(localized: "settings.hub.summary.downloaded %lld %lld",
                                  defaultValue: "%lld of %lld downloaded"),
                   Int64(downloadedCount), Int64(catalogCount))
        ]

        if downloadedCount == 0 {
            // Nothing downloaded: an index clause would be vacuous ("0 of 0 indexed").
            clauses.append(String(localized: "settings.hub.summary.nothingYet",
                                  defaultValue: "nothing indexed yet"))
        } else if indexedCount >= downloadedCount {
            clauses.append(String(localized: "settings.hub.summary.allIndexed",
                                  defaultValue: "all indexed"))
        } else {
            clauses.append(String(format: String(localized: "settings.hub.summary.someIndexed %lld",
                                                 defaultValue: "%lld not yet indexed"),
                                  Int64(downloadedCount - indexedCount)))
        }

        if interruptedCount == 1 {
            clauses.append(String(localized: "settings.hub.summary.needsAttention.one",
                                  defaultValue: "1 needs attention"))
        } else if interruptedCount > 1 {
            clauses.append(String(format: String(localized: "settings.hub.summary.needsAttention %lld",
                                                 defaultValue: "%lld need attention"),
                                  Int64(interruptedCount)))
        } else if downloadedCount > 0 {
            clauses.append(String(localized: "settings.hub.summary.allWell",
                                  defaultValue: "nothing needs attention"))
        }

        return clauses.joined(separator: " · ")
    }

    /// Whether the library is in a state the user should act on — drives the hero's tint.
    var needsAttention: Bool { interruptedCount > 0 }
}

// MARK: - SettingsUsageBar

/// A proportional, segmented storage bar (S-2).
///
/// The app had no stacked bar of any kind before this; the nearest thing was the single-value
/// `influenceBar` in Cross-Reference Analytics. Draws nothing when the breakdown is empty, so a
/// fresh install shows no empty track.
///
/// Accessibility: the bar itself is one element speaking the whole breakdown, because a VoiceOver
/// user gains nothing from three separately-focusable coloured rectangles.
///
/// Version history:
///   1.0 — S-2a: initial implementation
struct SettingsUsageBar: View {

    /// What to draw.
    let breakdown: StorageUsageBreakdown
    /// Bar thickness.
    var height: CGFloat = 8

    /// Segment tints, keyed by `Segment.id`. Semantic colors so light/dark is the OS's problem.
    private func color(for id: String) -> Color {
        switch id {
        case "xml":       return .accentColor
        case "index":     return .teal
        case "summaries": return .purple
        default:          return .secondary
        }
    }

    var body: some View {
        if !breakdown.isEmpty {
            GeometryReader { geo in
                HStack(spacing: 0) {
                    ForEach(breakdown.segments) { segment in
                        Rectangle()
                            .fill(color(for: segment.id))
                            .frame(width: max(0, geo.size.width * segment.share))
                    }
                }
            }
            .frame(height: height)
            .clipShape(Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(accessibilityDescription))
        }
    }

    /// The spoken breakdown — label and size per segment.
    private var accessibilityDescription: String {
        breakdown.segments
            .map { "\($0.label) \(ByteCountFormatter.string(fromByteCount: Int64($0.bytes), countStyle: .file))" }
            .joined(separator: ", ")
    }
}

// MARK: - SettingsUsageLegend

/// The swatch-and-size legend that sits under a `SettingsUsageBar` (S-2).
///
/// Version history:
///   1.0 — S-2a: initial implementation
struct SettingsUsageLegend: View {

    /// What to describe.
    let breakdown: StorageUsageBreakdown

    var body: some View {
        // ViewThatFits, not a size-class check: this legend appears inside an iPad sheet as well
        // as a phone, and a sheet reports compact width at ~540 pt.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { entries }
            VStack(alignment: .leading, spacing: 4) { entries }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)   // the bar already speaks this
    }

    @ViewBuilder
    private var entries: some View {
        ForEach(breakdown.segments) { segment in
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(SettingsUsageBar(breakdown: breakdown).legendColor(for: segment.id))
                    .frame(width: 8, height: 8)
                Text("\(segment.label) \(ByteCountFormatter.string(fromByteCount: Int64(segment.bytes), countStyle: .file))")
            }
        }
    }
}

extension SettingsUsageBar {
    /// The segment tint, exposed so the legend draws matching swatches.
    func legendColor(for id: String) -> Color { color(for: id) }
}

// MARK: - SettingsHeroCard

/// The status-first card that heads a settings destination (S-2).
///
/// The North Star's cross-cutting rule is *status first, then the primary action* — the reader
/// should learn where they stand before being offered a button. This renders a title, an optional
/// visual (the usage bar), the status line, and one trailing action.
///
/// Version history:
///   1.0 — S-2a: initial implementation
struct SettingsHeroCard<Visual: View, Action: View>: View {

    /// Small uppercase label above the headline figure.
    let title: String
    /// The headline value — a formatted size, a count.
    let value: String
    /// The state-of-play sentence beneath the visual.
    let status: String
    /// Whether `status` describes something the user should act on.
    var needsAttention: Bool = false
    /// Optional visual between the headline and the status line (the usage bar and its legend).
    @ViewBuilder var visual: () -> Visual
    /// The card's single primary action.
    @ViewBuilder var action: () -> Action

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
            }
            visual()
            HStack(alignment: .center, spacing: 12) {
                Label {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(needsAttention ? .primary : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    if needsAttention {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
                .labelStyle(.titleAndIcon)
                Spacer(minLength: 8)
                action()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FRUSTheme.settingsCardFill,
                    in: RoundedRectangle(cornerRadius: FRUSTheme.settingsCardCornerRadius))
        .accessibilityElement(children: .contain)
    }
}

extension SettingsHeroCard where Visual == EmptyView {
    /// A hero with no visual — a title, a value, a status line, and an action.
    init(title: String,
         value: String,
         status: String,
         needsAttention: Bool = false,
         @ViewBuilder action: @escaping () -> Action) {
        self.init(title: title, value: value, status: status, needsAttention: needsAttention,
                  visual: { EmptyView() }, action: action)
    }
}

// MARK: - SettingsStatusRow

/// A row that states a condition and offers its remedy (S-2).
///
/// Replaces roughly ten hand-rolled "green check + label" constructions that had drifted to four
/// different fonts across the two settings surfaces.
///
/// Version history:
///   1.0 — S-2a: initial implementation
struct SettingsStatusRow<Action: View>: View {

    /// What the row is about.
    let label: String
    /// The current state, in a sentence.
    let detail: String
    /// How the state reads.
    var state: State = .ok
    /// Optional trailing control.
    @ViewBuilder var action: () -> Action

    /// The three states a settings condition can be in.
    enum State {
        /// Nothing to do.
        case ok
        /// Worth the user's attention, but not broken.
        case warning
        /// Broken; needs action.
        case error

        /// SF Symbol for the state.
        var systemImage: String {
            switch self {
            case .ok:      return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error:   return "xmark.octagon.fill"
            }
        }

        /// Tint for the state.
        var tint: Color {
            switch self {
            case .ok:      return .green
            case .warning: return .orange
            case .error:   return .red
            }
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: state.systemImage)
                .foregroundStyle(state.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            action()
        }
        .accessibilityElement(children: .combine)
    }
}

extension SettingsStatusRow where Action == EmptyView {
    /// A status row with no trailing control.
    init(label: String, detail: String, state: State = .ok) {
        self.init(label: label, detail: detail, state: state, action: { EmptyView() })
    }
}

// MARK: - SettingsNavRow

/// Label · optional detail line · optional trailing value (S-2).
///
/// The settled list grammar: a row states what it is, what it will do, and its current value. Used
/// as a `NavigationLink` label on iOS and as a plain row on macOS.
///
/// Version history:
///   1.0 — S-2a: initial implementation
struct SettingsNavRow: View {

    /// Row title.
    let label: String
    /// Optional SF Symbol.
    var systemImage: String? = nil
    /// Optional consequence/explanation line. The North Star rule is that a detail line is
    /// content, never a tooltip.
    var detail: String? = nil
    /// Optional trailing value.
    var value: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let value {
                Spacer(minLength: 8)
                Text(value)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
    }
}
