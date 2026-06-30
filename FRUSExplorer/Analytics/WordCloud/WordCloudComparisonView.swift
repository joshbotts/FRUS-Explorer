// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

/// Side-by-side comparison of two word clouds.
///
/// Renders two `ComparativeCloudColumn`s — laid out horizontally when there's room
/// and stacked vertically on a narrow (iPhone) width. Pushed onto `WordCloudView`'s
/// navigation stack via its "Compare with…" menu.
///
/// Version history:
///   1.0 — Word Cloud feature: Phase 4 comparative clouds
struct WordCloudComparisonView: View {

    /// The originating scope (left/top column).
    let primary: WordCloudScope
    /// The scope being compared against (right/bottom column).
    let secondary: WordCloudScope

    /// Shared with `WordCloudView` so the comparison honours the same stopword policy.
    @AppStorage("frus.wordcloud.excludeBoilerplate") private var excludeBoilerplate = true

    var body: some View {
        GeometryReader { geo in
            let horizontal = geo.size.width > geo.size.height && geo.size.width > 700
            Group {
                if horizontal {
                    HStack(spacing: 0) {
                        ComparativeCloudColumn(scope: primary, excludeBoilerplate: excludeBoilerplate)
                        Divider()
                        ComparativeCloudColumn(scope: secondary, excludeBoilerplate: excludeBoilerplate)
                    }
                } else {
                    VStack(spacing: 0) {
                        ComparativeCloudColumn(scope: primary, excludeBoilerplate: excludeBoilerplate)
                        Divider()
                        ComparativeCloudColumn(scope: secondary, excludeBoilerplate: excludeBoilerplate)
                    }
                }
            }
        }
        .navigationTitle(String(localized: "wordcloud.compare.title", defaultValue: "Compare"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

/// One column of a word-cloud comparison: a compact, read-only spiral cloud with a
/// header. Loads its own result via `WordCloudLoader`.
///
/// Version history:
///   1.0 — Word Cloud feature: Phase 4 comparative clouds
struct ComparativeCloudColumn: View {

    /// The scope this column visualises.
    let scope: WordCloudScope
    /// Whether the diplomatic stopword layer is active.
    let excludeBoilerplate: Bool

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    // Device-local appearance, shared with the main word-cloud view.
    @AppStorage(WordCloudSettings.Keys.fontDesign) private var fontDesignRaw = WordCloudFontDesign.rounded.rawValue
    @AppStorage(WordCloudSettings.Keys.density) private var densityRaw = WordCloudDensity.balanced.rawValue

    @State private var result: WordCloudResult = .empty
    @State private var title: String = ""
    @State private var isLoading = false
    @State private var placements: [PlacedWord] = []

    /// The resolved typeface family for the column.
    private var fontDesign: WordCloudFontDesign { WordCloudFontDesign(rawValue: fontDesignRaw) ?? .rounded }
    /// The resolved packing density for the column.
    private var density: WordCloudDensity { WordCloudDensity(rawValue: densityRaw) ?? .balanced }

    /// Fewer words than the full view — these columns are smaller.
    private static let termLimit = 80

    private static let palette: [Color] = [
        .blue, .teal, .indigo, .purple, .pink, .orange, .green, .red, .cyan, .mint
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if result.terms.isEmpty {
                ContentUnavailableView(
                    String(localized: "wordcloud.compare.empty", defaultValue: "No Terms"),
                    systemImage: WordCloudGlyph.fallbackSymbol
                )
            } else {
                cloud
            }
        }
        .task(id: TaskKey(signature: scope.signature, exclude: excludeBoilerplate)) {
            await load()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text(String(
                format: String(localized: "wordcloud.provenance %lld %lld",
                               defaultValue: "%lld terms from %lld documents"),
                Int64(result.terms.count), Int64(result.documentCount)
            ))
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var cloud: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(placements) { word in
                    Text(word.term)
                        .font(.system(size: word.fontSize, weight: .semibold, design: fontDesign.swiftUIDesign))
                        .foregroundStyle(Self.palette[word.colorIndex % Self.palette.count])
                        .fixedSize()
                        .rotationEffect(.degrees(word.rotationDegrees))
                        .position(word.center)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .task(id: LayoutKey(width: geo.size.width, height: geo.size.height,
                                signature: scope.signature, termCount: result.terms.count,
                                fontDesign: fontDesign, density: density)) {
                placements = WordCloudLayout.place(
                    terms: result.terms, in: geo.size,
                    maxWords: Self.termLimit, minFontSize: 11, maxFontSize: 46,
                    spacingScale: density.spacingScale, widthFactor: fontDesign.widthFactor
                )
            }
        }
        .accessibilityRepresentation {
            List(Array(result.terms.enumerated()), id: \.element.id) { index, term in
                Text(verbatim: "\(index + 1). \(term.term) — \(term.count)")
            }
        }
    }

    private func load() async {
        isLoading = true
        let hidden = WordCloudOverrides.hidden(for: scope.signature)
        do {
            let (computed, loadedTitle) = try await WordCloudLoader.load(
                scope: scope, excludeBoilerplate: excludeBoilerplate,
                hiddenWords: hidden, limit: Self.termLimit,
                appState: appState, modelContext: modelContext
            )
            if Task.isCancelled { return }
            title = loadedTitle
            result = computed
        } catch {
            result = .empty
        }
        isLoading = false
    }

    private struct TaskKey: Equatable {
        let signature: String
        let exclude: Bool
    }

    private struct LayoutKey: Equatable {
        let width: CGFloat
        let height: CGFloat
        let signature: String
        let termCount: Int
        let fontDesign: WordCloudFontDesign
        let density: WordCloudDensity
    }
}
