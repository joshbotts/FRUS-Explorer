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

/// The device's Tier-2 store: per-volume int8 shards on disk, mapped on demand.
///
/// ## Why there is no registry table
///
/// The design specifies "a registry table in the SQLite store [recording] shard presence + provenance
/// per volume". This does not build one, and the reason is a precedent in this codebase rather than a
/// preference: **downloaded-ness is already read straight from the filesystem** —
/// `IndexingPipeline.findDownloadedVolumes` lists the directory — and nothing here reconciles a table
/// against disk. A registry would be a second source of truth for a question the filesystem answers
/// authoritatively, and the two would drift the first time a file was removed outside the app.
///
/// It would also have to be maintained in three hand-kept places that already disagree in spirit:
/// `auxDeleteVolume`'s eleven-table list, `removeAllVolumesFromIndex`'s parallel list of the same
/// names, and `PRAGMA user_version`, which `FTS5Connection` already owns. Presence is therefore a
/// `stat`, and provenance is the shard's own 32-byte header — both cheap, neither able to lie.
///
/// ## What a missing shard means
///
/// Not zero similarity. A volume without a shard is *typed-unavailable* for exact scoring; the
/// bundled Tier-1 block still ranks it by Hamming distance, at the lower recall that implies (0.53
/// against 0.745 — measured, `Phase3-Store-Assessment.md` §5). Callers must distinguish the two, and
/// `SemanticUnavailable.shardMissing` is how.
///
/// Version history:
///   1.0 — V-2: initial implementation
public actor SemanticShardStore {

    /// Directory holding `<volumeId>.vec`.
    public let directory: URL

    /// The pin every shard must carry.
    private let provenance: SemanticVectorsArtifacts.Provenance

    /// Expected row counts per volume, from the bundled index — a shard whose length disagrees is
    /// refused rather than mapped, because a length mismatch misaligns every row after it.
    private let expectedCounts: [String: Int]

    /// Mapped shards, by volume id. Mapping is cheap and the kernel touches pages lazily, so shards
    /// stay mapped once opened rather than being re-opened per query.
    private var mapped: [String: SemanticShard] = [:]

    /// Volumes known to have no usable shard, with the reason. Cached so a missing file is not
    /// re-`stat`ed on every query.
    private var refused: [String: SemanticUnavailable] = [:]

    /// Creates a store over a directory.
    ///
    /// - Parameters:
    ///   - directory: Where `<volumeId>.vec` files live.
    ///   - provenance: The bundled pin shards must match.
    ///   - expectedCounts: Per-volume row counts from the bundled index.
    public init(
        directory: URL,
        provenance: SemanticVectorsArtifacts.Provenance,
        expectedCounts: [String: Int]
    ) {
        self.directory = directory
        self.provenance = provenance
        self.expectedCounts = expectedCounts
    }

    /// The on-disk location of a volume's shard.
    ///
    /// - Parameter volumeID: Manifest `volumeId`.
    /// - Returns: The file URL, whether or not it exists.
    public nonisolated func shardURL(for volumeID: String) -> URL {
        directory.appendingPathComponent("\(volumeID).vec")
    }

    /// The mapped shard for a volume, opening it if needed.
    ///
    /// - Parameter volumeID: Manifest `volumeId`.
    /// - Returns: The shard, or `nil` when this device has no usable one.
    public func shard(for volumeID: String) -> SemanticShard? {
        if let shard = mapped[volumeID] { return shard }
        if refused[volumeID] != nil { return nil }
        do {
            let shard = try SemanticShard(
                contentsOf: shardURL(for: volumeID),
                provenance: provenance,
                expectedDocumentCount: expectedCounts[volumeID])
            mapped[volumeID] = shard
            return shard
        } catch let error as SemanticUnavailable {
            refused[volumeID] = error
            #if DEBUG
            if case .noArtifact = error {} else {
                print("[SemanticShardStore] \(volumeID) refused: \(error)")
            }
            #endif
            return nil
        } catch {
            refused[volumeID] = .malformedArtifact("\(error)")
            return nil
        }
    }

    /// Why a volume has no usable shard, or `nil` when it has one (or has not been asked for).
    ///
    /// - Parameter volumeID: Manifest `volumeId`.
    /// - Returns: The reason, if the shard was refused.
    public func refusal(for volumeID: String) -> SemanticUnavailable? { refused[volumeID] }

    /// Volumes with a shard currently mapped.
    public var mappedVolumeIDs: Set<String> { Set(mapped.keys) }

    /// Volume ids with a shard file on disk, by listing the directory.
    ///
    /// The filesystem is the source of truth, so this is what "which volumes are semantic-ready"
    /// means. Cheap enough to call on demand: 552 entries is one `contentsOfDirectory`.
    ///
    /// - Returns: The volume ids, sorted.
    public func volumeIDsOnDisk() -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names.compactMap { name in
            name.hasSuffix(".vec") ? String(name.dropLast(4)) : nil
        }.sorted()
    }

    /// Bytes the shards on disk occupy, and how many there are.
    ///
    /// One `contentsOfDirectory` plus a `stat` per entry — the same listing `volumeIDsOnDisk()`
    /// does, with the sizes it already had to walk past. Returned together because every caller
    /// wants both and two passes over the directory could disagree if a fetch landed between them.
    ///
    /// The filesystem is the source of truth here for the reason the type's header gives: a
    /// registry would be a second answer to a question `stat` answers authoritatively.
    ///
    /// - Returns: The count and the total byte size.
    public func diskUsage() -> (volumes: Int, bytes: Int) {
        // Built on `volumeIDsOnDisk()` rather than a second directory walk **on purpose**. A first
        // draft listed the directory itself with `.skipsHiddenFiles`, which counts a different set
        // of files than the plain `contentsOfDirectory(atPath:)` this reuses — so a dotfile could
        // be sized by one and deleted by the other, and the count a screen showed would not be the
        // count `removeAllShards()` acts on. One reader, one answer.
        let ids = volumeIDsOnDisk()
        let bytes = ids.reduce(0) { total, id in
            let size = (try? FileManager.default.attributesOfItem(
                atPath: shardURL(for: id).path)[.size] as? Int) ?? nil
            return total + (size ?? 0)
        }
        return (ids.count, bytes)
    }

    /// Every refusal recorded so far, as a snapshot.
    ///
    /// **Partial by construction, and callers must say so.** `refused` is populated by
    /// `shard(for:)`, so it holds only volumes some surface has already asked about — a damaged
    /// shard for a volume nobody has searched is not in here. A screen built on this may report
    /// what it has noticed; it may not report that there is nothing wrong.
    public var recordedRefusals: [String: SemanticUnavailable] { refused }

    /// Removes a volume's shard and forgets any mapping of it.
    ///
    /// Called from volume teardown. Idempotent, because teardown runs twice on the Settings storage
    /// paths — `removeVolumes` calls the pipeline and then `DownloadManager.deleteVolume`, whose
    /// `onVolumeDeleted` callback runs teardown again.
    ///
    /// - Parameter volumeID: Manifest `volumeId`.
    public func removeShard(for volumeID: String) {
        mapped.removeValue(forKey: volumeID)
        refused.removeValue(forKey: volumeID)
        try? FileManager.default.removeItem(at: shardURL(for: volumeID))
    }

    /// The file recording which generation the shards on disk belong to.
    private var generationMarkerURL: URL { directory.appendingPathComponent(".generation") }

    /// Discards every shard when the bundled generation has moved, and records the new one.
    ///
    /// ## Why a marker rather than checking the shards
    /// A stale shard is otherwise discovered one at a time, by `shard(for:)` throwing
    /// `provenanceMismatch` when some surface happens to ask — so after a generation change the
    /// bytes sit on disk indefinitely, the storage screen counts them as present, and the reader is
    /// told they have vectors they cannot use. Verifying them eagerly means opening 552 files and
    /// reading 552 headers at launch. One marker file makes it one string comparison.
    ///
    /// ## An ABSENT marker is treated as stale, deliberately
    /// Shards written before this mechanism existed carry no marker and their generation cannot be
    /// recovered cheaply. Purging them costs a re-download of files the reader can re-fetch; keeping
    /// them risks presenting another generation's vectors as usable, which the family rule exists to
    /// forbid. Owner decision 2026-08-16, taken with the 256 → 512 move in view: clear them.
    ///
    /// - Returns: How many shards were discarded, so a caller can log or report it.
    @discardableResult
    public func purgeIfGenerationChanged() -> Int {
        let current = provenance.digestHex
        let recorded = try? String(contentsOf: generationMarkerURL, encoding: .utf8)
        let present = volumeIDsOnDisk()

        if recorded?.trimmingCharacters(in: .whitespacesAndNewlines) == current {
            return 0
        }
        if !present.isEmpty {
            removeAllShards()
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? current.write(to: generationMarkerURL, atomically: true, encoding: .utf8)
        return present.count
    }

    /// Removes every shard — the corpus-wide teardown partner.
    ///
    /// `ResetService.resetLocalData` deletes volume XML directly through `FileManager`, bypassing
    /// `DownloadManager.deleteVolume` entirely, so without an explicit call here a "reset local data"
    /// would leave 79 MB of vectors behind for volumes that no longer exist.
    public func removeAllShards() {
        mapped.removeAll()
        refused.removeAll()
        for volumeID in volumeIDsOnDisk() {
            try? FileManager.default.removeItem(at: shardURL(for: volumeID))
        }
    }

    /// Adopts a shard file from elsewhere on disk, validating it before it is kept.
    ///
    /// This is the seam the download channel will use, and the one an operator uses today: Tier 2 has
    /// no host yet (design §4.3 names an app-owned repo, which is the owner's call to create), so
    /// shards arrive by sideload. Validation happens here rather than at the source, so an adopted
    /// file and a fetched one are held to the same header, digest and row-count checks.
    ///
    /// - Parameters:
    ///   - source: The file to adopt.
    ///   - volumeID: The volume it belongs to.
    /// - Throws: `SemanticUnavailable` when the file is not a shard this build can use; the source is
    ///   left untouched in that case.
    public func adoptShard(from source: URL, for volumeID: String) throws {
        // Validate BEFORE moving: a shard that fails its checks must not land in the store's
        // directory, where a later listing would report the volume as semantic-ready.
        _ = try SemanticShard(
            contentsOf: source, provenance: provenance,
            expectedDocumentCount: expectedCounts[volumeID])
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
        let destination = shardURL(for: volumeID)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.copyItem(at: source, to: destination)
        mapped.removeValue(forKey: volumeID)
        refused.removeValue(forKey: volumeID)
    }
}
