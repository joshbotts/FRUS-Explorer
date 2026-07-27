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

/// The (c) word cloud, as the indexing banners' own background.
///
/// ## Why the banner and not a sheet
/// O-3 put this behind `IndexingEducationView`, reachable only from a "Learn about FRUS
/// while you wait" link — which exists **only** in the multi-volume queue banner, so a
/// single-volume download could never reach it. The cloud was effectively invisible.
/// Owner decision 2026-07-27: it belongs on the banner strip, where it is present for the
/// whole wait without a tap.
///
/// ## Legibility comes first
/// The strip is short and carries live progress text, so the cloud sits **over** the bar
/// material at a low opacity rather than replacing it. The text is above both. A backdrop
/// that makes a progress read harder has failed at being a backdrop.
///
/// macOS is unaffected: the banners are `MainTabView` only, and the Mac surfaces indexing
/// inside the Volumes & Storage pane. See the plan for why (c) is deliberately iOS-shaped.
///
/// Version history:
///   1.0 — O-3b: initial implementation
struct IndexingCloudStrip: ViewModifier {

    /// The scope currently landing.
    let scope: BundledCloudVectors.Scope

    /// Whether the arbiter says this surface is live.
    let isActive: Bool

    /// Minimum strip height, so the cloud has room to read as one.
    ///
    /// The banner was ~40 pt of padding-driven height, in which a 25-word cloud placed two
    /// or three words and looked like noise. This gives it a band.
    static let minimumHeight: CGFloat = 96

    func body(content: Content) -> some View {
        content
            .frame(minHeight: isActive ? Self.minimumHeight : nil, alignment: .top)
            .background {
                ZStack {
                    Rectangle().fill(.bar)
                    if isActive {
                        WordCloudBackdropView(
                            scope: scope,
                            dim: FRUSTheme.cloudDimIndexingStrip,
                            showsChip: false
                        )
                        .allowsHitTesting(false)
                        .clipped()
                        .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.35), value: isActive)
            }
    }
}

extension View {

    /// Backs an indexing banner with the word cloud for the volumes currently landing.
    func indexingCloudStrip(scope: BundledCloudVectors.Scope, isActive: Bool) -> some View {
        modifier(IndexingCloudStrip(scope: scope, isActive: isActive))
    }
}
