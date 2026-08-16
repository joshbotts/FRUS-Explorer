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

import CryptoKit
import Foundation

/// Fetches Tier-2 shards from the app-owned vectors repository.
///
/// ## Why this does not reuse `DownloadManager`
///
/// The design proposed fetching shards "with the exact `DownloadManager` machinery that already
/// fetches volumes from GitHub". Three properties of that machinery make it the wrong tool here, and
/// each would have to be changed rather than reused:
///
/// * `BackgroundDownloadEngine` **hardcodes the destination** as `<volumesDirectory>/<id>.xml` and
///   routes every transfer by `taskDescription == volumeId`, so a second per-volume transfer has no
///   representable key and would land on top of the volume's own XML.
/// * Its delegate callback is a **single slot** that `attach` replaces; a second attacher displaces
///   `DownloadManager`'s and breaks volume downloads.
/// * A shard is ~148 KB. Background sessions exist for multi-megabyte transfers that must survive
///   suspension; this is one request that either completes in a second or is retried later.
///
/// ## What it verifies
///
/// Everything the bundled manifest can prove. The transfer is checked against the manifest's byte
/// length and SHA-256 **before** the bytes reach the store, and the store then re-validates the
/// header, the provenance digest and the row count before keeping the file. That is deliberately
/// more than the app does for volume XML, which is verified only by HTTP status — a corrupt volume
/// is visibly wrong, while a corrupt vector is a plausible wrong answer.
///
/// Version history:
///   1.0 — V-2b: initial implementation
public actor SemanticShardFetcher {

    /// Base URL of the vectors repository's raw content.
    ///
    /// Beta hosting is an app-owned public GitHub repository, fetched the way volumes are: no API,
    /// no credentials, no rate limit worth modelling. The bundled manifest — not a directory listing
    /// — is what says which shards exist, so nothing here needs the contents API.
    public static let defaultBaseURL = URL(
        string: "https://raw.githubusercontent.com/joshbotts/frus-semantic-vectors/main/shards")!

    /// One shard's expected identity, from the bundled manifest.
    public struct Expectation: Sendable {
        /// Expected byte length.
        public let bytes: Int
        /// Expected SHA-256, lower-case hex.
        public let sha256: String

        /// Creates an expectation.
        /// - Parameters:
        ///   - bytes: Expected byte length.
        ///   - sha256: Expected digest.
        public init(bytes: Int, sha256: String) {
            self.bytes = bytes
            self.sha256 = sha256
        }
    }

    /// Why a fetch did not produce a usable shard.
    public enum FetchError: Error, Equatable {
        /// The bundled manifest does not list this volume, so there is nothing to ask for.
        case notInManifest(String)
        /// The server answered with a non-success status.
        case httpStatus(Int)
        /// The bytes that arrived are not the bytes the manifest describes.
        case integrityMismatch(volumeID: String, expected: String, found: String)
        /// The transfer failed.
        case transport(String)
        /// The bytes arrived intact and the **store** would not keep them.
        ///
        /// Added in #900 for a failure mode that was previously recorded nowhere at all. The
        /// `SemanticUnavailable` thrown by `adoptShard` used to be rethrown without touching
        /// `failed`, which had two consequences: the volume appeared in no diagnostic list, and —
        /// because `failed` is also the "do not retry this session" gate — it was re-downloaded and
        /// re-refused on every launch. It is the exact generation-skew case the digest check exists
        /// to catch, so it is the last one that should have been silent.
        case rejectedByStore(volumeID: String, reason: String)
    }

    /// Where shards are fetched from.
    private let baseURL: URL
    /// Expected identity per volume, from the bundled manifest.
    private let expectations: [String: Expectation]
    /// The session used for transfers.
    private let session: URLSession
    /// Volumes with a fetch already running, so a download hook and a lazy request cannot both pull
    /// the same shard.
    private var inFlight: Set<String> = []
    /// Volumes whose fetch failed this session, so a lazy path does not retry on every query.
    private var failed: [String: FetchError] = [:]

    /// Creates a fetcher.
    ///
    /// - Parameters:
    ///   - baseURL: Root the shard files hang from.
    ///   - expectations: Per-volume byte length and digest, from the bundled manifest.
    ///   - session: Session to transfer with; injectable for tests.
    public init(
        baseURL: URL = SemanticShardFetcher.defaultBaseURL,
        expectations: [String: Expectation],
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.expectations = expectations
        self.session = session
    }

    /// Whether the bundled manifest knows this volume.
    ///
    /// - Parameter volumeID: Manifest `volumeId`.
    /// - Returns: `true` when a shard is expected to exist for it.
    public func hasShard(for volumeID: String) -> Bool { expectations[volumeID] != nil }

    /// Fetches one volume's shard and hands it to `store`, verifying it on the way.
    ///
    /// Idempotent and de-duplicated: a second call while a fetch is running returns without starting
    /// another, and a failure is remembered for the session so the lazy path does not retry on every
    /// query. The temporary file is always removed, including on the failure paths.
    ///
    /// - Parameters:
    ///   - volumeID: Manifest `volumeId`.
    ///   - store: Where a verified shard is adopted.
    /// - Throws: `FetchError` or the store's `SemanticUnavailable`.
    public func fetchShard(for volumeID: String, into store: SemanticShardStore) async throws {
        guard let expectation = expectations[volumeID] else {
            throw FetchError.notInManifest(volumeID)
        }
        guard !inFlight.contains(volumeID) else { return }
        if let previous = failed[volumeID] { throw previous }
        inFlight.insert(volumeID)
        defer { inFlight.remove(volumeID) }

        do {
            let url = baseURL.appendingPathComponent("\(volumeID).vec")
            let (temporary, response) = try await session.download(from: url)
            defer { try? FileManager.default.removeItem(at: temporary) }

            if let http = response as? HTTPURLResponse,
               !(200..<300).contains(http.statusCode) {
                throw FetchError.httpStatus(http.statusCode)
            }
            let data = try Data(contentsOf: temporary)
            guard data.count == expectation.bytes else {
                throw FetchError.integrityMismatch(
                    volumeID: volumeID, expected: "\(expectation.bytes) bytes",
                    found: "\(data.count) bytes")
            }
            let digest = Data(SHA256.hash(data: data))
                .map { String(format: "%02x", $0) }.joined()
            guard digest == expectation.sha256 else {
                throw FetchError.integrityMismatch(
                    volumeID: volumeID, expected: expectation.sha256, found: digest)
            }
            // The store re-validates header, provenance and row count before keeping it — the
            // manifest proves the bytes arrived intact, the header proves they belong to this
            // generation of the artifact.
            try await store.adoptShard(from: temporary, for: volumeID)
        } catch let error as FetchError {
            failed[volumeID] = error
            throw error
        } catch let error as SemanticUnavailable {
            // RECORDED, not merely rethrown (#900). Rethrowing alone left this case out of `failed`,
            // so it was invisible to every diagnostic AND exempt from the do-not-retry gate — the
            // one failure that repeated on every launch was also the one nothing could report. The
            // original error still propagates; only the bookkeeping is new.
            failed[volumeID] = .rejectedByStore(volumeID: volumeID, reason: "\(error)")
            throw error
        } catch {
            let wrapped = FetchError.transport("\(error)")
            failed[volumeID] = wrapped
            throw wrapped
        }
    }

    /// Clears the remembered failures so a later attempt can retry — for a connectivity change.
    public func clearFailures() { failed.removeAll() }

    /// Every failure recorded this session, as a snapshot.
    ///
    /// **Session-scoped, and callers must say so.** `failed` is in-memory and starts empty at every
    /// launch, so a volume that failed yesterday is simply absent today. A screen built on this may
    /// report what it has noticed; it may not report that everything succeeded.
    ///
    /// This exists because `failure(for:)` had **no readers anywhere in the app** (#900): the fetch
    /// recorded a diagnosis and `AppState.fetchSemanticShardIfNeeded` swallowed the throw into a
    /// `#if DEBUG print`, so the information was computed and shown to nobody.
    public var recordedFailures: [String: FetchError] { failed }

    /// Total bytes every published shard would occupy, from the bundled manifest.
    ///
    /// The denominator a storage screen needs to say "8 of 552" and "12 MB of 79 MB".
    public var publishedTotals: (volumes: Int, bytes: Int) {
        (expectations.count, expectations.values.reduce(0) { $0 + $1.bytes })
    }

    /// Why a volume's fetch failed this session, if it did.
    ///
    /// - Parameter volumeID: Manifest `volumeId`.
    /// - Returns: The failure, if one was recorded.
    public func failure(for volumeID: String) -> FetchError? { failed[volumeID] }

    // MARK: - Bundled manifest

    /// The bundled shard manifest's expectations, or `nil` when the resource is missing.
    ///
    /// - Returns: Per-volume expectations keyed by volume id.
    public static func bundledExpectations() -> [String: Expectation]? {
        guard let url = Bundle.main.url(
                forResource: "semantic-shards-manifest", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else {
            #if DEBUG
            print("[SemanticShardFetcher] semantic-shards-manifest.json not in bundle")
            #endif
            return nil
        }
        struct Manifest: Decodable {
            struct Shard: Decodable {
                let volumeID: String
                let sha256: String
                let bytes: Int
            }
            let shards: [Shard]
            let provenanceDigest: String
        }
        guard let manifest = try? JSONDecoder().decode(Manifest.self, from: data) else {
            return nil
        }
        return Dictionary(
            manifest.shards.map {
                ($0.volumeID, Expectation(bytes: $0.bytes, sha256: $0.sha256))
            },
            uniquingKeysWith: { first, _ in first })
    }

    /// The provenance digest the bundled shard manifest was written against.
    ///
    /// Checked against the bundled index's digest at wiring time: a manifest describing a different
    /// generation would have the app verify downloads against digests for vectors it cannot use.
    ///
    /// - Returns: The hex digest, or `nil` when the resource is missing.
    public static func bundledProvenanceDigest() -> String? {
        guard let url = Bundle.main.url(
                forResource: "semantic-shards-manifest", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return object["provenanceDigest"] as? String
    }
}
