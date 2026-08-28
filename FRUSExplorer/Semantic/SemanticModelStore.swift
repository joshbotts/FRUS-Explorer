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

/// The on-device home of the query-encoder model file — one optional 229 MB GGUF, downloaded at
/// the reader's request, verified before it is kept (V-5 s2).
///
/// ## The pin is the artifact's, not this type's
///
/// The file this store accepts is decided by `SemanticVectorsArtifacts.Provenance.modelFileSHA256`:
/// the corpus vectors were embedded by exactly one weights file, and a query embedded by any other
/// file lives in a different space — the family rule (`refuse, re-fetch, or degrade; never blend`)
/// applied to weights instead of vectors. The SHA is checked **once, at adoption**, and recorded in
/// a sidecar marker. It is deliberately not re-hashed at every load: hashing 229 MB costs most of a
/// second and pages in the whole file, defeating the mmap-lazy load the encoder relies on. The
/// marker plus a byte-length `stat` is the steady-state check; anyone who edits the file in place
/// on a device defeats a check that exists to catch transfer corruption, not tampering.
///
/// ## Why the filesystem is the registry
///
/// Same argument as `SemanticShardStore`, one file instead of 552: presence is a `stat`, and a
/// table recording it would drift the first time the file was removed outside the app.
///
/// Version history:
///   1.0 — V-5 s2: initial implementation
public actor SemanticModelStore {

    /// Directory holding the model file and its marker.
    public let directory: URL

    /// The SHA-256 the model file must have — `provenance.modelFileSHA256`.
    private let expectedSHA256: String

    /// The byte length the file must have. Checked before the digest at adoption (cheaper, and a
    /// truncated download is the common failure), and the steady-state presence check.
    private let expectedBytes: Int

    /// The published file's exact byte length — the default pin, injectable only so tests can
    /// exercise the adopt path with fixture-sized bytes.
    public static let publishedBytes = 229_093_184

    /// The on-disk file name — the upstream release's own, so what a reader sees in a file browser
    /// matches what the notices name.
    public static let fileName = "embeddinggemma-300m-qat-Q4_0.gguf"

    /// Creates a store over a directory.
    ///
    /// - Parameters:
    ///   - directory: Where the model file lives.
    ///   - expectedSHA256: The artifact pin (`provenance.modelFileSHA256`).
    ///   - expectedBytes: The pinned file length; leave defaulted outside tests.
    public init(
        directory: URL,
        expectedSHA256: String,
        expectedBytes: Int = SemanticModelStore.publishedBytes
    ) {
        self.directory = directory
        self.expectedSHA256 = expectedSHA256
        self.expectedBytes = expectedBytes
    }

    /// The on-disk location of the model file, whether or not it exists.
    public nonisolated var modelFileURL: URL {
        directory.appendingPathComponent(Self.fileName)
    }

    /// The sidecar recording which pin the stored file was verified against.
    private var markerURL: URL { directory.appendingPathComponent(".sha256") }

    /// The model file's URL if a verified copy is present, else `nil`.
    ///
    /// "Verified" means: the marker records the current pin, the file exists, and its byte length
    /// matches — the steady-state checks the header explains. This is the only door the encoder
    /// loads through.
    public func verifiedModelURL() -> URL? {
        guard recordedPin() == expectedSHA256 else { return nil }
        guard bytesOnDisk() == expectedBytes else { return nil }
        return modelFileURL
    }

    /// Whether a verified copy is present.
    public func isModelPresent() -> Bool { verifiedModelURL() != nil }

    /// The stored file's byte length, or 0 when absent.
    public func bytesOnDisk() -> Int {
        (try? FileManager.default.attributesOfItem(
            atPath: modelFileURL.path)[.size] as? Int) ?? 0
    }

    /// Adopts a downloaded model file, validating it before it is kept.
    ///
    /// Length first, then the digest — a truncated transfer fails on the cheap check. The source is
    /// left where it is on refusal (the fetcher's `defer` cleans it up), and the marker is written
    /// only after the copy lands, so a crash between the two reads as "unverified" and re-downloads
    /// rather than trusting a file nothing vouched for.
    ///
    /// - Parameter source: The file to adopt.
    /// - Throws: `SemanticModelError` when the file is not the pinned weights.
    public func adoptModel(from source: URL) throws {
        let bytes = (try? FileManager.default.attributesOfItem(
            atPath: source.path)[.size] as? Int) ?? 0
        guard bytes == expectedBytes else {
            throw SemanticModelError.wrongLength(expected: expectedBytes, found: bytes)
        }
        let digest = try Self.sha256Hex(of: source)
        guard digest == expectedSHA256 else {
            throw SemanticModelError.wrongDigest(expected: expectedSHA256, found: digest)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: modelFileURL)
        try? FileManager.default.removeItem(at: markerURL)
        try FileManager.default.copyItem(at: source, to: modelFileURL)
        try expectedSHA256.write(to: markerURL, atomically: true, encoding: .utf8)
    }

    /// Removes the model file and its marker. Idempotent.
    public func removeModel() {
        try? FileManager.default.removeItem(at: modelFileURL)
        try? FileManager.default.removeItem(at: markerURL)
    }

    /// Discards the stored file when the artifact pin has moved (or the marker is absent).
    ///
    /// Mirrors `SemanticShardStore.purgeIfGenerationChanged`, including the owner's 2026-08-16
    /// decision that an ABSENT marker is stale: keeping an unverifiable 229 MB file risks encoding
    /// queries into another generation's space, and purging it costs a re-download the reader is
    /// asked for anyway.
    ///
    /// - Returns: Whether a file was discarded, so a caller can log it.
    @discardableResult
    public func purgeIfPinChanged() -> Bool {
        guard bytesOnDisk() > 0 || recordedPin() != nil else { return false }
        guard recordedPin() != expectedSHA256 else { return false }
        removeModel()
        return true
    }

    /// The pin the sidecar records, or `nil`.
    private func recordedPin() -> String? {
        (try? String(contentsOf: markerURL, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// SHA-256 of a file, streamed in 4 MB slices so 229 MB never sits in memory at once.
    ///
    /// - Parameter url: The file to hash.
    /// - Returns: Lowercase hex.
    static func sha256Hex(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 4 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

/// Why a model file was refused or a fetch failed — the storage screen's vocabulary.
public enum SemanticModelError: Error, Equatable {
    /// The transfer did not deliver the pinned file's byte length.
    case wrongLength(expected: Int, found: Int)
    /// The bytes are complete but are not the pinned weights.
    case wrongDigest(expected: String, found: String)
    /// The server answered with a non-success status.
    case httpStatus(Int)
    /// The transfer itself failed.
    case transport(String)
}
