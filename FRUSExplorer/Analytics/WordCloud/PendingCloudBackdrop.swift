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

/// The drift cloud behind a surface that is waiting, with nothing else to show.
///
/// ## Empty-pending only, and that is the whole rule
/// This attaches to states where the surface would otherwise be blank — a spinner on an
/// empty area — never behind or beside content the user is reading. That constraint is what
/// makes the cloud honest here. Set against a half-populated result list, drifting words
/// invite the reading "this is what my search is turning up", which they are not: the
/// vectors are the *scope's* ambient vocabulary, precomputed, and the results do not exist
/// yet. With nothing else on screen there is nothing to misread them against.
///
/// The owner's judgement, recorded because it is the load-bearing decision: a 25-word
/// corpus or subseries cloud is not specific enough to mislead anyone about the
/// characteristics of individual documents, and the more surfaces carry the effect the more
/// it reads as the app's own character rather than as an indexing curiosity.
///
/// ## One caveat that is real and accepted
/// The bundled vectors describe the whole *published* series; a search only ever covers the
/// volumes the user has actually indexed. So at corpus scope the cloud describes a superset
/// of what is being searched. At the grain these lists are drawn — twenty-five common terms
/// — that gap is not legible, which is why it was accepted rather than engineered around.
/// It would matter if the cloud were ever made document-specific.
///
/// ## Why the delay
/// A rare term returns in 4–47 ms (measured against the real 316,839-document index). A
/// cloud that faded in and out inside 40 ms is a flicker, not an effect. The cloud waits;
/// the host's own spinner still appears immediately, so a fast search looks exactly as it
/// does today and only a genuine wait grows a backdrop.
///
/// Version history:
///   1.0 — P-2: initial implementation, search as the first consumer
struct PendingCloudBackdrop: ViewModifier {

    /// Which scope's vocabulary to show — normally what the user filtered the wait down to.
    let scope: BundledCloudVectors.Scope

    /// Whether the host is currently waiting on something.
    let isPending: Bool

    @Environment(AppState.self) private var appState
    @State private var isShowing = false

    /// How long a wait must last before the cloud appears.
    ///
    /// Long enough that the fast half of the search latency distribution never sees it, short
    /// enough that a wait which *is* worth filling does not sit blank first.
    static let appearanceDelay: Duration = .milliseconds(400)

    func body(content: Content) -> some View {
        content
            .background {
                if isShowing {
                    WordCloudBackdropView(
                        scope: scope,
                        dim: FRUSTheme.cloudDimPendingSurface,
                        showsChip: false,
                        drift: true
                    )
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.45), value: isShowing)
            .task(id: isPending) {
                guard isPending, canShow else { isShowing = false; return }
                try? await Task.sleep(for: Self.appearanceDelay)
                guard !Task.isCancelled else { return }
                isShowing = true
            }
    }

    /// Whether a cloud is appropriate at all right now.
    private var canShow: Bool {
        PendingCloudRule.shouldShow(
            isCoreReady: BundledCloudVectors.isCoreReady,
            isUITestMode: ProcessInfo.processInfo.environment["FRUS_UI_TEST_MODE"] == "1",
            isIndexing: appState.indexingBatch != nil)
    }
}

/// When a pending surface may carry a cloud.
///
/// A plain value, separated from the modifier so the rules can be exercised without a view
/// host. Three of the four surfaces this project has shipped had a gating defect that only a
/// person looking at a device could see — an arbiter branch that never fired, a strip that
/// was never placed in the hierarchy, a lens pinned to the wrong index. Rules that can be
/// evaluated are rules that can be wrong out loud.
///
/// Version history:
///   1.0 — P-2: initial implementation
enum PendingCloudRule {

    /// The decision, in the order the reasons matter.
    static func shouldShow(isCoreReady: Bool, isUITestMode: Bool, isIndexing: Bool) -> Bool {
        // A cloud fading in over the results area would race every UI test's first element
        // lookup — the same bypass `ContentView` and the arbiter already apply.
        guard !isUITestMode else { return false }
        // With no vectors resident the backdrop renders nothing at all, by contract. Showing
        // an empty one would just be a slower blank.
        guard isCoreReady else { return false }
        // Never two drifting clouds at once. During an indexing run the banner strip already
        // carries one directly below this area: a second doubles the per-frame cost on a main
        // thread the indexer is already contending for, and reads as noise rather than
        // character.
        return !isIndexing
    }
}

extension View {

    /// Fills an otherwise-blank waiting surface with the drift cloud, after a short delay.
    ///
    /// Attach only to states that are genuinely empty while pending — see
    /// ``PendingCloudBackdrop`` for why that constraint is not cosmetic.
    func pendingCloudBackdrop(scope: BundledCloudVectors.Scope, isPending: Bool) -> some View {
        modifier(PendingCloudBackdrop(scope: scope, isPending: isPending))
    }
}

extension CloudSurfaceArbiter {

    /// The scope a search's cloud should describe: what the user filtered to, or the corpus.
    ///
    /// Reuses `indexingScope`'s volumeIds → `Scope` reduction rather than restating it, so
    /// the two surfaces can never disagree about what a set of volumes is called.
    ///
    /// A search can also be narrowed by things the bundled vectors cannot express at all —
    /// a date range, a person, user tags, an explicit document set. Those fall back to the
    /// volume scope, which remains true if less precise: every document the search can reach
    /// is inside it.
    static func searchScope(volumeIds: [String]?, manifest: ManifestStore) -> BundledCloudVectors.Scope {
        guard let volumeIds, !volumeIds.isEmpty else { return .corpus }
        return indexingScope(queuedVolumeIds: volumeIds, manifest: manifest)
    }
}
