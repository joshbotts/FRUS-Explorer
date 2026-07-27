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

/// Reads the bundled cloud vectors so the onboarding backdrop renders with **zero volumes
/// downloaded** — the whole reason the vectors are generated at build time.
///
/// ## Two files, loaded on different schedules
/// - **Core** (~255 KB — corpus + all 107 subseries) is loaded once, early, and **off the
///   main actor**. It backs the splash, Welcome, Ready, and the Corpus and Subseries scopes.
/// - **Volumes** (~1.26 MB — all 552) is loaded lazily, the first time the Volume segment is
///   selected, behind a screen the user is already reading.
///
/// ## The one rule
/// **Neither file may be first touched on the render path.** O-0 measured
/// `FRUSExplorerApp.init()` at 119–158 ms, 72–87% of it a synchronous SwiftData store open;
/// adding a 1.5 MB decode to that window would make the launch this feature exists to
/// decorate measurably worse. `prepareCore()` is called from the app's first `.task`, after
/// the first frame. A view that asks for terms before the load completes gets `nil` and
/// shows nothing, which is correct: a backdrop is decoration, and decoration must never
/// gate content.
///
/// This is why the type deviates from the house `enum Store { static let shared }` shape —
/// a `static let` would decode on first touch, and first touch would be a view body.
///
/// Version history:
///   1.0 — O-2: initial implementation
@MainActor
enum BundledCloudVectors {

    // MARK: - State

    private static var core: CloudVectorsFile?
    private static var volumes: CloudVectorsFile?
    private static var volumesLoadStarted = false

    /// `true` once the core file is resident. Views may render a backdrop from this point.
    static var isCoreReady: Bool { core != nil }

    // MARK: - Loading

    /// Decodes the core file off the main actor. Idempotent; safe to call from every scene.
    ///
    /// Call from a `.task`, never from a view body or an initialiser.
    static func prepareCore() async {
        guard core == nil else { return }
        core = await decode(resource: "cloud-vectors-core")
    }

    /// Decodes the volumes file off the main actor, once.
    ///
    /// Called when the Volume scope is first selected. Until it resolves, callers asking
    /// for a volume scope fall back to that volume's subseries — see ``terms(forScope:lens:)``.
    static func prepareVolumes() async {
        guard volumes == nil, !volumesLoadStarted else { return }
        volumesLoadStarted = true
        volumes = await decode(resource: "cloud-vectors-volumes")
    }

    /// Decodes a bundled artifact on a background task.
    ///
    /// A missing or malformed file yields `nil` and leaves the backdrop empty rather than
    /// trapping — the same posture every other bundled store in the app takes, and the right
    /// one for decoration.
    private static func decode(resource: String) async -> CloudVectorsFile? {
        await Task.detached(priority: .utility) { () -> CloudVectorsFile? in
            guard let url = Bundle.main.url(forResource: resource, withExtension: "json") else {
                #if DEBUG
                print("[BundledCloudVectors] \(resource).json not found in bundle.")
                #endif
                return nil
            }
            do {
                return try JSONDecoder().decode(CloudVectorsFile.self, from: Data(contentsOf: url))
            } catch {
                #if DEBUG
                print("[BundledCloudVectors] Failed to decode \(resource).json — \(error)")
                #endif
                return nil
            }
        }.value
    }

    // MARK: - Reading

    /// A scope the backdrop can render.
    enum Scope: Equatable, Sendable {
        /// The whole series — the splash, Welcome, Ready, and the Corpus segment.
        case corpus
        /// One subseries, by manifest identifier (`"1969-76"`).
        case subseries(String)
        /// One volume, by manifest id (`"frus1969-76v32"`), with its subseries for fallback.
        case volume(volumeId: String, subseries: String)
    }

    /// What the chip should say about where these terms came from.
    enum Provenance: Equatable, Sendable {
        /// The requested scope's own vectors.
        case exact
        /// The volume's *era* stood in, because the volume's own list was too thin or the
        /// volumes file is not loaded yet. **The chip must say so** — a user reading a
        /// volume's cloud to decide whether to download it would otherwise attribute the
        /// era's vocabulary to the volume (decision O-4-2).
        case subseriesFallback(String)
    }

    /// Ranked terms for a scope and lens, plus whether they are really that scope's.
    ///
    /// - Returns: `nil` when nothing is available — the core file has not loaded, or the
    ///   scope is absent. Callers render no backdrop.
    static func terms(forScope scope: Scope, lens: WordCloudLens) -> (terms: [TermCount], provenance: Provenance)? {
        switch scope {
        case .corpus:
            return list(in: core, scope: CloudVectorsAggregatorScopeKeys.corpus, lens: lens)
                .map { ($0, .exact) }

        case .subseries(let id):
            return list(in: core, scope: id, lens: lens).map { ($0, .exact) }

        case .volume(let volumeId, let subseries):
            // The volumes file may not be resident yet; the era is a truthful stand-in as
            // long as the chip says it is one.
            if let own = list(in: volumes, scope: volumeId, lens: lens),
               !isBelowSignal(volumes, volumeId, lens) {
                return (own, .exact)
            }
            return list(in: core, scope: subseries, lens: lens)
                .map { ($0, .subseriesFallback(subseries)) }
        }
    }

    /// Whether the stored list was flagged below its lens's signal threshold by the
    /// generator.
    private static func isBelowSignal(_ file: CloudVectorsFile?, _ scope: String, _ lens: WordCloudLens) -> Bool {
        file?.scopes[scope]?.lists[lens.rawValue]?.belowSignalThreshold ?? false
    }

    /// Resolves one scope's lens list into `TermCount`s, de-indexing the shared vocabulary.
    ///
    /// Counts are the generator's **raw** counts, so `WordCloudLayout` sizes words on the
    /// same scale it uses for a live cloud and no separate normalisation step is needed.
    private static func list(in file: CloudVectorsFile?, scope: String, lens: WordCloudLens) -> [TermCount]? {
        guard let file, let stored = file.scopes[scope]?.lists[lens.rawValue], !stored.entries.isEmpty
        else { return nil }
        return stored.entries.compactMap { entry in
            guard entry.term >= 0, entry.term < file.vocabulary.count else { return nil }
            return TermCount(term: file.vocabulary[entry.term], count: entry.count)
        }
    }

    /// The polarity the generator recorded for a sentiment term in a scope, if any.
    ///
    /// The sentiment lens colours by polarity, and the splash renders before any lexicon
    /// question can be asked of a downloaded corpus — so the value ships with the term.
    static func polarity(of term: String, inScope scope: Scope, lens: WordCloudLens) -> Int? {
        guard lens == .sentiment else { return nil }
        let (file, key): (CloudVectorsFile?, String) = switch scope {
        case .corpus: (core, CloudVectorsAggregatorScopeKeys.corpus)
        case .subseries(let id): (core, id)
        case .volume(let volumeId, let subseries):
            volumes?.scopes[volumeId] != nil ? (volumes, volumeId) : (core, subseries)
        }
        guard let file, let stored = file.scopes[key]?.lists[lens.rawValue] else { return nil }
        guard let index = file.vocabulary.firstIndex(of: term) else { return nil }
        return stored.entries.first { $0.term == index }?.polarity
    }

    #if DEBUG
    /// Test seam: injects decoded files without touching the bundle.
    static func injectForTesting(core: CloudVectorsFile?, volumes: CloudVectorsFile?) {
        self.core = core
        self.volumes = volumes
        self.volumesLoadStarted = volumes != nil
    }
    #endif
}

/// Scope keys shared with the generator.
///
/// The generator owns `"corpus"` as a literal in `CloudVectorsAggregator`, which the app
/// does not compile. Rather than repeat a bare string at the read site, it is named once
/// here — a mismatch would silently produce an empty corpus backdrop with no error anywhere.
enum CloudVectorsAggregatorScopeKeys {
    /// The whole-series scope key written by `CloudVectorsAggregator.corpusScopeKey`.
    static let corpus = "corpus"
}
