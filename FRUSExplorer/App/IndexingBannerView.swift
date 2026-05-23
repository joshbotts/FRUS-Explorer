// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

#if os(iOS)

import SwiftUI

// MARK: - IndexingBannerView

/// Compact progress banner shown above the iOS tab bar while a volume is being indexed.
///
/// Mirrors the centre-zone of the macOS `StatusBarView`: a system image, a volume ID
/// label, a linear progress bar, and an ETA estimate derived from `docsPerSecond`.
///
/// ## Placement
/// Injected via `.safeAreaInset(edge: .bottom, spacing: 0)` on each tab's root view
/// in `MainTabView`. This placement adds the banner height to the tab content's bottom
/// safe area so list content is never hidden behind the banner, and the banner floats
/// above the system tab bar without a hardcoded height offset.
///
/// ## ActivityKit
/// A Live Activity / Dynamic Island integration was evaluated in Session 93 and
/// deferred. The Widget Extension overhead (separate target, WidgetKit entitlements,
/// shared `ActivityAttributes` framework) is not justified for the typically brief
/// indexing window. The inline `IndexingCapsule` already covers the Browse tab;
/// this banner covers the case where the user switches away during indexing.
///
/// Version history:
///   1.0 — Session 93: initial implementation
struct IndexingBannerView: View {

    let update: IndexingProgressUpdate

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: FRUSTheme.captionSize))
                    .foregroundStyle(.secondary)

                Text(String(
                    localized: "indexing.banner.label",
                    defaultValue: "Indexing \(update.volumeId)…"
                ))
                .font(.system(size: FRUSTheme.captionSize))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

                Spacer()

                if update.totalDocuments > 0 {
                    ProgressView(
                        value: Double(update.completedDocuments),
                        total: Double(update.totalDocuments)
                    )
                    .progressViewStyle(.linear)
                    .frame(width: 80)
                    .tint(.accentColor)

                    if let eta = etaString {
                        Text(eta)
                            .font(.system(size: FRUSTheme.captionSmallSize))
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                } else {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .frame(width: 80)
                        .tint(.accentColor)
                }
            }
            .padding(.horizontal, FRUSTheme.documentHorizontalPadding)
            .padding(.vertical, 5)
            .background(.bar)
        }
    }

    private var etaString: String? {
        guard update.docsPerSecond > 0,
              update.totalDocuments > update.completedDocuments else { return nil }
        let remaining = update.totalDocuments - update.completedDocuments
        let seconds = Double(remaining) / update.docsPerSecond
        return "~\(Int(seconds.rounded()))s"
    }
}

#endif // os(iOS)
