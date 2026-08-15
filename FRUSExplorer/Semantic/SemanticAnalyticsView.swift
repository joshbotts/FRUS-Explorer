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

/// The corpus seen through its own vocabulary — the semantic map, its lenses, and its axis slices.
///
/// A sibling of Corpus, Person, Cross-Reference and Archival Analytics, reached from the same
/// Analytics menu, and the home the map earned by becoming usable: it began as a `#if DEBUG`
/// diagnostics row in Settings ▸ Data & Recovery, where it sat because it was a *measurement* —
/// could one draw call hold 314,483 points — and stayed there through labels, tap-to-open, lasso
/// capture and slices, long after it had stopped being one.
///
/// ## What it is honest about
///
/// Every other analytics surface measures something the corpus states: who is named, what cites
/// what, where a document came from. This one measures **how the language sits**, which is a model's
/// opinion rather than an editorial fact — so the header says so once, plainly, and the map carries
/// its own caveat about what its plane does and does not preserve. The design asked for exactly this
/// posture and named the reason: a projection onto a stated axis looks like a measurement, and the
/// layout behind it is not one.
///
/// The vectors also ship **experimental** by an owner decision that traded a blind quality panel for
/// tester judgement, and pre-1900 quality is a declared unknown rather than a measured pass. A
/// reader meeting this window for the first time should learn that here, not from a release note.
///
/// Version history:
///   1.0 — V-4: promoted out of Settings ▸ Data & Recovery into its own analytics surface
///   1.1 — V-4: the header collapses to its experimental warning rather than disappearing. The
///         dismiss was a one-way door — `@AppStorage` remembers it and nothing restored it — so one
///         tap on first open retired the caveat permanently on that device.
struct SemanticAnalyticsView: View {

    /// The app state the map's lenses and open actions need.
    let appState: AppState

    /// The scope and lens a Handoff continuation arrived with (UI review F-28), or `nil` for a map
    /// the reader opened here. Passed straight through to the map, which applies it once.
    var continued: SemanticMapRequest?

    /// Whether the explanatory header is showing.
    ///
    /// Defaults to **shown**, and is remembered: the first thing a reader needs is what this surface
    /// is measuring, and the second thing they need is for it to get out of the way.
    @AppStorage("semanticAnalytics.showsAbout") private var showsAbout = true

    var body: some View {
        // **A NavigationStack of its own, exactly as `PersonAnalyticsView` and
        // `CrossReferenceAnalyticsView` do**, and it is load-bearing rather than decorative. The map
        // puts its Lasso toggle in a `.toolbar` and registers a `navigationDestination(item:)` to
        // push an opened document; both need a stack to render into. Presented from an iOS sheet
        // without one, the toggle has nowhere to go and the destination has no stack — the lasso
        // becomes unreachable and Open Document silently does nothing. This surface has now shipped
        // several controls that drew correctly and did nothing — the Open button twice, the lasso
        // toggle twice, and an axis slice with no way out — so the mechanism is stated rather than
        // left to be rediscovered.
        NavigationStack {
            VStack(spacing: 0) {
                if showsAbout { about } else { collapsedAbout }
                SemanticMapSpikeView(appState: appState, continued: continued)
            }
        }
        #if os(macOS)
        .frame(minWidth: 640, minHeight: 520)
        #endif
    }

    /// The one line that survives dismissal, and the way back to the rest.
    ///
    /// **The dismiss used to be a one-way door.** `@AppStorage` remembers it forever and nothing
    /// restored it, so a reader who tapped the ✕ once — plausibly on first open, to see the map —
    /// never saw the experimental caveat again on that device, on either platform. The caveat is the
    /// part that cannot be optional: this surface is a model's reading of the language, unmeasured
    /// before 1900, sitting beside four analytics windows that report facts the corpus states. So the
    /// header collapses to its warning rather than disappearing, and the warning is the button that
    /// brings the rest back.
    private var collapsedAbout: some View {
        Button {
            showsAbout = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(String(localized: "semanticAnalytics.about.collapsed",
                            defaultValue: "Experimental — a model's reading of the language"))
                Spacer(minLength: 8)
                Image(systemName: "info.circle")
            }
            .font(.caption)
            .foregroundStyle(.orange)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(.bar)
        .accessibilityLabel(String(localized: "semanticAnalytics.about.restore",
                                   defaultValue: "Experimental. Show what this window measures"))
    }

    /// What this window measures, and what that is worth.
    private var about: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Label(
                    String(localized: "semanticAnalytics.about.title",
                           defaultValue: "How the corpus's language sits"),
                    systemImage: "point.3.filled.connected.trianglepath.dotted")
                    .font(.headline)
                Spacer(minLength: 12)
                Button {
                    showsAbout = false
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "semanticAnalytics.about.dismiss",
                                           defaultValue: "Hide this explanation"))
            }
            // **"Not by … dates" was true of the map and false of a slice.** Picking two poles
            // replaces the vertical axis with the volume's coverage midpoint year — the map's own
            // caveat says so, in smaller type below the map — while this banner sat above it
            // asserting the opposite. The sentence now states the rule for the base map and names
            // the one thing a slice changes, so it is true in both modes without needing to read
            // the model's state from up here.
            Text(String(
                localized: "semanticAnalytics.about.body.v2",
                defaultValue: """
                    Every document in the corpus placed by the shape of its language, not by \
                    citations or archival provenance. Regions are named by the vocabulary that \
                    distinguishes them. Tap a document to open it, draw a lasso to keep a set, or \
                    pick two poles to lay the corpus along an axis you can state — which replaces \
                    the vertical axis with each volume's coverage year.
                    """))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(String(
                localized: "semanticAnalytics.about.experimental",
                defaultValue: """
                    Experimental. This is a model's reading of the language, not an editorial fact, \
                    and its quality before 1900 has not been measured.
                    """))
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }
}
