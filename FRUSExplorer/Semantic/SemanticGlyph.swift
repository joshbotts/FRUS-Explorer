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

import Foundation

// MARK: - SemanticGlyph

/// The one visual identity for every surface built on the semantic-vector methodology, so a
/// reader can recognise "this comes from the language model's reading of the corpus" wherever
/// it appears (the ``WordCloudGlyph`` pattern).
///
/// ## Why this exists
/// Before this type, the semantic surfaces had three unrelated icons, two of them borrowed:
/// the map's entry points and the Research rail's "On the Map" tile used
/// `point.3.filled.connected.trianglepath.dotted` — one fill-state away from the
/// cross-reference graph's long-standing identity, an unreadable distinction at tile size and
/// an outright collision in Settings, where the vector-storage row used the graph's *exact*
/// glyph — while the Related-documents semantic axis used `text.magnifyingglass` and the
/// Clusters browse axis used `circle.hexagongrid`. Nothing said the three surfaces share one
/// methodology, which they do (one embedding space produces the map, the clusters, and the
/// similarity axis).
///
/// ## The family
/// The root motif is the **hexagon grid** — already the map's own idiom for "a region of the
/// corpus's language" (the region card and the compact region pill use it) and the Clusters
/// axis's icon since it shipped. Three variants, one per relationship to the corpus:
///
/// - ``feature`` (`circle.hexagongrid.fill`) — doors to the whole-corpus surface: the
///   "Semantic Analytics" menu items, the map's about header, the guide section, the
///   vector-storage row, "See on the semantic map".
/// - ``clusters`` (`circle.hexagongrid`) — the groupings themselves: the Clusters browse axis
///   and the map's region card/pill. (Those sites predate this type and already agree; the
///   constant exists so the next surface has a name to reach for, and so the audit test covers
///   the whole family from one place.)
/// - ``document`` (`circle.hexagongrid.circle`) — one document seen against the corpus: the
///   rail's "On the Map" tile and the Related-documents semantic-similarity axis.
///
/// The cross-reference graph keeps `point.3.connected.trianglepath.dotted` everywhere; no
/// graph surface changes. All three names are runtime-verified by `SymbolNameAuditTests`,
/// because an enum's constants are exactly what its literal scan cannot reach.
///
/// Version history:
///   1.0 — Semantic iconography: introduced the family (pre-build-43 consistency pass)
enum SemanticGlyph {
    /// Doors to the whole-corpus semantic surface (the map / Semantic Analytics).
    static let feature = "circle.hexagongrid.fill"
    /// The corpus's language groupings (the Clusters axis, the map's region card).
    static let clusters = "circle.hexagongrid"
    /// One document placed against the corpus (rail tile, Related's semantic axis).
    static let document = "circle.hexagongrid.circle"
}
