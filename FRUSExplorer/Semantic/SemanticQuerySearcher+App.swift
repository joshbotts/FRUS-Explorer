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

// MARK: - SemanticOnDeviceEncoder

/// The app's encoder for search by meaning (V-5 s3): the model through the store's verified door, and the
/// llama encoder created on the first question and dropped after an idle window.
///
/// `SemanticQuerySearcher` moved into FRUSCoreKit for FRUS Explorer Light's S27a, and asks its host's
/// ``SemanticQueryEncoding`` for a question's vector where it held this app's encoder. Its embed step and its
/// idle rule are here, line for line as the searcher had them: the store's verified door is the one the
/// encoder loads through, a query past the model's context is `queryTooLong`, and the model stays resident
/// for ``encoderIdleSeconds`` after the last question.
///
/// Version history:
///   1.0 — 2026-11-24: FRUS Explorer Light's S27a — the searcher's embed step and idle rule, moved here from
///          `SemanticQuerySearcher` unchanged
actor SemanticOnDeviceEncoder: SemanticQueryEncoding {

    /// Where the verified model file is.
    private let modelStore: SemanticModelStore

    /// The encoder, created lazily on first search and dropped by the idle watchdog.
    private var encoder: SemanticQueryEncoder?
    /// Bumped per search; the idle watchdog unloads only if nothing newer ran.
    private var searchGeneration = 0

    /// How long the encoder stays resident after the last search. The measured cost of being
    /// wrong in either direction: resident is ~250 MB footprint (the s2 measurement), reload is
    /// ~0.4 s cold — so a short idle window that drops the big number and re-pays the small one.
    static let encoderIdleSeconds: UInt64 = 180

    /// Creates the encoder over the model store.
    ///
    /// - Parameter modelStore: The store whose verified door the model loads through.
    init(modelStore: SemanticModelStore) {
        self.modelStore = modelStore
    }

    /// Embeds through the real encoder, managing the encoder's lifetime.
    ///
    /// - Parameter query: The reader's text, verbatim; the encoder applies the query template.
    /// - Returns: The model's vector, of unit length.
    /// - Throws: `SemanticQuerySearcher.SearchUnavailable`.
    func embed(_ query: String) async throws -> [Double] {
        guard let modelURL = await modelStore.verifiedModelURL() else {
            throw SemanticQuerySearcher.SearchUnavailable.modelNotDownloaded
        }
        let encoder = self.encoder ?? SemanticQueryEncoder()
        self.encoder = encoder
        searchGeneration += 1
        let generation = searchGeneration
        defer { scheduleIdleUnload(after: generation) }
        do {
            try await encoder.load(modelPath: modelURL.path)
            return try await encoder.encodeQuery(query)
        } catch SemanticQueryEncoder.EncoderError.queryTooLong {
            throw SemanticQuerySearcher.SearchUnavailable.queryTooLong
        } catch let error as SemanticQuerySearcher.SearchUnavailable {
            throw error
        } catch {
            throw SemanticQuerySearcher.SearchUnavailable.encodingFailed("\(error)")
        }
    }

    /// Drops the encoder after the idle window unless a newer search has run.
    private func scheduleIdleUnload(after generation: Int) {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.encoderIdleSeconds * 1_000_000_000)
            await self?.unloadIfIdle(since: generation)
        }
    }

    private func unloadIfIdle(since generation: Int) async {
        guard generation == searchGeneration, let encoder else { return }
        await encoder.unload()
        self.encoder = nil
    }
}

// MARK: - SemanticQuerySearcher + the app's stores

/// The searcher as the app makes it: over its model store and shard store, with the embed step a test or the UI
/// test seam may give in place of the encoder (#1577 lane 3).
///
/// Version history:
///   1.0 — 2026-11-24: FRUS Explorer Light's S27a — the searcher's initialiser as it was, over the kit's
///          `init(index:corpus:shards:encoder:requestShardFetch:)`
extension SemanticQuerySearcher {

    /// Creates a searcher over the app's stores.
    ///
    /// - Parameters:
    ///   - index: The bundled row index.
    ///   - corpus: The bundled sign bits.
    ///   - modelStore: The model store, whose verified door the on-device encoder loads through.
    ///   - shardStore: The match-file store.
    ///   - requestShardFetch: `AppState.requestSemanticShardForSearch`, answering whether a download is under way.
    ///   - embedOverride: The embed step, injectable so tests can drive the funnel with fixture vectors and no
    ///     310 MB model. `nil` means the real encoder through the model store's verified door
    ///     (``SemanticOnDeviceEncoder``).
    init(
        index: SemanticVectorIndex,
        corpus: SemanticCorpusVectors,
        modelStore: SemanticModelStore,
        shardStore: SemanticShardStore,
        requestShardFetch: @escaping @Sendable (String) async -> Bool,
        embedOverride: (@Sendable (String) async throws -> [Double])? = nil
    ) {
        let encoder: any SemanticQueryEncoding
        if let embedOverride {
            encoder = SemanticEmbedFunction(embedOverride)
        } else {
            encoder = SemanticOnDeviceEncoder(modelStore: modelStore)
        }
        self.init(index: index, corpus: corpus, shards: shardStore, encoder: encoder,
                  requestShardFetch: requestShardFetch)
    }
}
