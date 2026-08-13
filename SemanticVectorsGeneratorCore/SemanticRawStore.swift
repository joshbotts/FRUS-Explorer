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

/// Reader for the raw embedding store written by `tools/semantic-harvest/harvest_embeddings.py`.
///
/// The store is the expensive, non-reproducible half of the pipeline — a 2 GB neural harvest that
/// took an overnight Studio run — and is treated exactly like `RecordGroupCatalogGenerator`'s raw
/// NDJSON: read, never rewritten, and pinned by provenance rather than by re-derivation. Everything
/// this type produces is deterministic given the store's bytes.
///
/// Store contract (validated end to end 2026-08-12, `Planning/semantic-spike/Phase3-Store-Assessment.md`):
///
/// ```
/// vectors/<vol>.bin         float32-LE chunk vectors, meta order, dim × chunks
/// vectors/<vol>.meta.jsonl  {"d","o","ci","c0","c1"} per chunk — pooling weights come from c1-c0
/// vectors/<vol>.head.json   {"volume","model","dim","docs","chunks","chars","secs"} — written LAST
/// run-manifest.json         model id + GGUF SHA + chunk/prefix params + machine + totals
/// ```
///
/// The vector pack does not read the text layer (`text/<vol>.jsonl.gz`): it needs document identity
/// and chunk spans, both of which live in the meta layer, and skipping the 400 MB of gzipped prose
/// keeps a full pack to minutes. The integrity sweep already proved the two layers carry identical
/// document-id sets per volume. The **map** pack does read it, for cluster labels — see
/// `documentTexts(for:at:)`, which explains why those labels come from this text and not from the
/// TEI.
public enum SemanticRawStore {

    // MARK: - Provenance

    /// The run manifest the harvester wrote — the pin every emitted artifact carries forward.
    ///
    /// Decoded field-by-field rather than as a free dictionary so a harvest that silently changed
    /// its parameter names fails here instead of producing artifacts whose provenance says nothing.
    public struct RunManifest: Decodable, Sendable {
        /// LM Studio model id the whole corpus was embedded under.
        public let model: String
        /// SHA-256 of the GGUF weights file, or `"not captured"` on a run that omitted `MODEL_FILE`.
        public let modelFileSHA256: String
        /// Native embedding width (768 for EmbeddingGemma-300M).
        public let dim: Int
        /// Characters per chunk window.
        public let chunkChars: Int
        /// Characters of overlap between consecutive windows.
        public let overlapChars: Int
        /// Document-side prompt prepended to every chunk — part of the vector contract, trailing
        /// space included.
        public let prefix: String
        /// Timestamp the harvester stamped when it finished.
        public let generated: String
        /// SHA-256 of the harvester script that ran.
        public let scriptSHA256: String

        private enum CodingKeys: String, CodingKey {
            case model
            case modelFileSHA256 = "model_file_sha256"
            case dim
            case chunkChars = "chunk_chars"
            case overlapChars = "overlap_chars"
            case prefix
            case generated
            case scriptSHA256 = "script_sha256"
        }
    }

    /// One volume's done-marker header. Written last by the harvester, so its presence plus a size
    /// check is what makes a volume "complete".
    public struct VolumeHead: Decodable, Sendable {
        /// Volume id, matching the manifest's `volumeId`.
        public let volume: String
        /// Model id this volume was embedded under — checked against the run manifest so a store
        /// assembled from two different models cannot pack silently.
        public let model: String
        /// Embedding width for this volume.
        public let dim: Int
        /// Document count.
        public let docs: Int
        /// Chunk count.
        public let chunks: Int
        /// Body-text characters.
        public let chars: Int
    }

    // MARK: - Pooled output

    /// One document's pooled, L2-normalised vector at the store's native width.
    public struct PooledDocument: Sendable {
        /// The document's TEI `xml:id` exactly as harvested (`d1`, `d373a`, `appA`, …).
        public let documentID: String
        /// The harvester's document ordinal. Recorded for diagnostics only — the artifact keys
        /// documents by row order, never by this number, because the extractor skips empty divs and
        /// the sequence may therefore carry gaps.
        public let ordinal: Int
        /// Total characters across the document's chunk spans (the pooling denominator).
        public let weight: Int
        /// The pooled unit-norm vector at native width.
        public let vector: [Double]
    }

    // MARK: - Errors

    /// Every way a store can fail to be readable as the artifact source.
    public enum StoreError: Error, CustomStringConvertible {
        /// A file the contract requires is absent.
        case missing(String)
        /// `<vol>.bin` is not `dim × 4 × chunks` bytes.
        case binarySizeMismatch(volume: String, expected: Int, actual: Int)
        /// The meta line count disagrees with the head's chunk count.
        case chunkCountMismatch(volume: String, head: Int, meta: Int)
        /// The pooled document count disagrees with the head's document count.
        case documentCountMismatch(volume: String, head: Int, pooled: Int)
        /// A volume was embedded under a different model or width than the run manifest states.
        case modelMismatch(volume: String, expected: String, actual: String)
        /// A meta line could not be decoded.
        case malformedMeta(volume: String, line: Int)
        /// A document's chunk weights summed to zero, or its pooled vector had no length — either
        /// makes the normalisation step a division by zero and the vector meaningless.
        case degenerateDocument(volume: String, documentID: String)
        /// One chunk row is all zeros, so it has no direction to contribute.
        ///
        /// Distinct from `degenerateDocument` because the two mean different things to whoever reads
        /// the failure: this one says the *store* holds a bad row (the model returned nothing for a
        /// chunk), while that one says a document's vectors cancelled. Reporting a chunk fault as a
        /// document fault sends the reader to inspect a document that is very likely fine.
        case degenerateChunk(volume: String, documentID: String, chunkIndex: Int)

        public var description: String {
            switch self {
            case .missing(let path):
                return "Raw store file not found: \(path)"
            case .binarySizeMismatch(let volume, let expected, let actual):
                return "\(volume).bin is \(actual) bytes, expected \(expected) (dim × 4 × chunks)"
            case .chunkCountMismatch(let volume, let head, let meta):
                return "\(volume): head says \(head) chunks, meta.jsonl has \(meta) lines"
            case .documentCountMismatch(let volume, let head, let pooled):
                return "\(volume): head says \(head) docs, pooling produced \(pooled)"
            case .modelMismatch(let volume, let expected, let actual):
                return "\(volume) was embedded under \(actual), run manifest says \(expected)"
            case .malformedMeta(let volume, let line):
                return "\(volume).meta.jsonl line \(line) is not a decodable chunk record"
            case .degenerateDocument(let volume, let documentID):
                return "\(volume)/\(documentID) pooled to a zero-length vector"
            case .degenerateChunk(let volume, let documentID, let chunkIndex):
                return "\(volume)/\(documentID): chunk vector at meta line \(chunkIndex) is all "
                    + "zeros — the raw store holds a row the model returned no direction for"
            }
        }
    }

    // MARK: - Reading

    /// Loads and validates the store's run manifest.
    ///
    /// - Parameter storeURL: Root of the raw store.
    /// - Returns: The decoded manifest.
    /// - Throws: `StoreError.missing` when the file is absent; a decoding error when its shape
    ///   changed.
    public static func runManifest(at storeURL: URL) throws -> RunManifest {
        let url = storeURL.appendingPathComponent("run-manifest.json")
        guard let data = try? Data(contentsOf: url) else {
            throw StoreError.missing(url.path)
        }
        return try JSONDecoder().decode(RunManifest.self, from: data)
    }

    /// Loads one volume's head.
    ///
    /// - Parameters:
    ///   - volumeID: The volume to read.
    ///   - storeURL: Root of the raw store.
    /// - Returns: The decoded head, or `nil` when the volume is absent from the store.
    public static func head(for volumeID: String, at storeURL: URL) -> VolumeHead? {
        let url = storeURL
            .appendingPathComponent("vectors")
            .appendingPathComponent("\(volumeID).head.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(VolumeHead.self, from: data)
    }

    /// Pools one volume's chunk vectors into document vectors.
    ///
    /// The pooling rule is **pinned** and is the one every measured gate ran under
    /// (`Planning/semantic-spike/spike-gates.json`, `"pooling"`): a char-length-weighted mean of
    /// unit-norm chunk vectors, L2-renormalised. Two details are load-bearing:
    ///
    /// * **Chunk vectors are unit-normalised before the mean** even though the model already emits
    ///   them unit-norm (measured max deviation 7e-8 over 50,471 sampled chunks). Normalising makes
    ///   the stated rule true by construction rather than by a property of one model, so swapping
    ///   encoders later cannot silently change what "pooled" means.
    /// * **The accumulation is `Double`**, mirroring the numpy pipeline the gates ran through
    ///   (`float32` rows times an integer weight vector promote to `float64` there). Matching the
    ///   measured configuration matters more than saving a few bytes of intermediate width.
    ///
    /// Documents come back in **store order** — the order their first chunk appears in the meta
    /// layer, which is the harvester's extraction order. That order, not the ordinal field, is the
    /// artifact's row order.
    ///
    /// - Parameters:
    ///   - volumeID: The volume to pool.
    ///   - storeURL: Root of the raw store.
    ///   - manifest: The run manifest, for the model/width cross-check.
    /// - Returns: Pooled documents in store order.
    /// - Throws: `StoreError` on any contract violation.
    public static func pooledDocuments(
        for volumeID: String,
        at storeURL: URL,
        manifest: RunManifest
    ) throws -> [PooledDocument] {
        let vectors = storeURL.appendingPathComponent("vectors")
        let headURL = vectors.appendingPathComponent("\(volumeID).head.json")
        let binURL = vectors.appendingPathComponent("\(volumeID).bin")
        let metaURL = vectors.appendingPathComponent("\(volumeID).meta.jsonl")

        guard let headData = try? Data(contentsOf: headURL) else {
            throw StoreError.missing(headURL.path)
        }
        let head = try JSONDecoder().decode(VolumeHead.self, from: headData)
        guard head.model == manifest.model, head.dim == manifest.dim else {
            throw StoreError.modelMismatch(
                volume: volumeID, expected: manifest.model, actual: head.model)
        }

        guard let binData = try? Data(contentsOf: binURL) else {
            throw StoreError.missing(binURL.path)
        }
        let expectedBytes = head.dim * 4 * head.chunks
        guard binData.count == expectedBytes else {
            throw StoreError.binarySizeMismatch(
                volume: volumeID, expected: expectedBytes, actual: binData.count)
        }

        guard let metaText = try? String(contentsOf: metaURL, encoding: .utf8) else {
            throw StoreError.missing(metaURL.path)
        }
        let metaLines = metaText.split(separator: "\n", omittingEmptySubsequences: true)
        guard metaLines.count == head.chunks else {
            throw StoreError.chunkCountMismatch(
                volume: volumeID, head: head.chunks, meta: metaLines.count)
        }

        // Chunk rows are contiguous per document in meta order, but the pooling groups by document
        // id rather than by adjacency — the same thing the measured numpy pass did, and robust to a
        // future chunker that interleaves.
        let dim = head.dim
        var order: [String] = []
        var ordinals: [String: Int] = [:]
        var weights: [String: Double] = [:]
        var sums: [String: [Double]] = [:]
        order.reserveCapacity(head.docs)

        let decoder = JSONDecoder()
        try binData.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            for (index, line) in metaLines.enumerated() {
                guard let row = try? decoder.decode(ChunkMetaRow.self, from: Data(line.utf8)) else {
                    throw StoreError.malformedMeta(volume: volumeID, line: index + 1)
                }
                let weight = Double(row.c1 - row.c0)
                if sums[row.d] == nil {
                    order.append(row.d)
                    ordinals[row.d] = row.o
                    sums[row.d] = [Double](repeating: 0, count: dim)
                    weights[row.d] = 0
                }

                // Unit-normalise this chunk, then accumulate it at its character weight.
                var norm = 0.0
                let base = index * dim
                for component in 0..<dim {
                    let value = Double(raw.loadUnaligned(
                        fromByteOffset: (base + component) * 4, as: Float32.self))
                    norm += value * value
                }
                norm = norm.squareRoot()
                guard norm > 0 else {
                    throw StoreError.degenerateChunk(
                        volume: volumeID, documentID: row.d, chunkIndex: index + 1)
                }
                sums[row.d]!.withUnsafeMutableBufferPointer { accumulator in
                    for component in 0..<dim {
                        let value = Double(raw.loadUnaligned(
                            fromByteOffset: (base + component) * 4, as: Float32.self))
                        accumulator[component] += (value / norm) * weight
                    }
                }
                weights[row.d]! += weight
            }
        }

        guard order.count == head.docs else {
            throw StoreError.documentCountMismatch(
                volume: volumeID, head: head.docs, pooled: order.count)
        }

        return try order.map { documentID in
            guard let total = weights[documentID], total > 0, var pooled = sums[documentID] else {
                throw StoreError.degenerateDocument(volume: volumeID, documentID: documentID)
            }
            var norm = 0.0
            for component in 0..<dim {
                pooled[component] /= total
                norm += pooled[component] * pooled[component]
            }
            norm = norm.squareRoot()
            guard norm > 0 else {
                throw StoreError.degenerateDocument(volume: volumeID, documentID: documentID)
            }
            for component in 0..<dim { pooled[component] /= norm }
            return PooledDocument(
                documentID: documentID,
                ordinal: ordinals[documentID] ?? 0,
                weight: Int(total),
                vector: pooled)
        }
    }

    /// Reads a volume's R-0 text layer — the exact text the vectors were computed from.
    ///
    /// The map's cluster labels describe clusters of *vectors*, so they should be built from the text
    /// those vectors saw. The alternative on hand, `TEIBodyTextExtractor`, re-derives body text from
    /// the TEI and differs from the harvest's extraction by the truncate-at-next-div rule — 40.9 M
    /// characters of back-of-book index bleed, measured. That difference is immaterial to a top-terms
    /// label and material to the principle: one extraction, many consumers.
    ///
    /// Decompressed through `/usr/bin/gunzip -c` because nothing in this repository's Swift speaks
    /// gzip and the R-0 layer is `.jsonl.gz`; the NER control established the same route. A plain
    /// `<volume>.jsonl` is preferred when present, so an operator can bypass the subprocess.
    ///
    /// - Parameters:
    ///   - volumeID: The volume to read.
    ///   - storeURL: Root of the raw store.
    /// - Returns: Document id to body text, or `nil` when the layer is unreadable.
    public static func documentTexts(for volumeID: String, at storeURL: URL) -> [String: String]? {
        let directory = storeURL.appendingPathComponent("text")
        let plain = directory.appendingPathComponent("\(volumeID).jsonl")
        let gzipped = directory.appendingPathComponent("\(volumeID).jsonl.gz")

        let payload: Data?
        if let data = try? Data(contentsOf: plain) {
            payload = data
        } else if FileManager.default.fileExists(atPath: gzipped.path) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/gunzip")
            process.arguments = ["-c", gzipped.path]
            let pipe = Pipe()
            process.standardOutput = pipe
            guard (try? process.run()) != nil else { return nil }
            // Read before waiting: a volume's text layer is megabytes and a full pipe buffer would
            // deadlock a process this waited on first.
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            payload = process.terminationStatus == 0 ? data : nil
        } else {
            payload = nil
        }
        guard let payload, let text = String(data: payload, encoding: .utf8) else { return nil }

        var texts: [String: String] = [:]
        let decoder = JSONDecoder()
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let row = try? decoder.decode(TextRow.self, from: Data(line.utf8)) else { continue }
            texts[row.d] = row.t
        }
        return texts
    }

    /// One `text/<volume>.jsonl` row.
    private struct TextRow: Decodable {
        let d: String
        let t: String
    }

    /// One `meta.jsonl` row: the document id, its ordinal, the chunk index, and the chunk's
    /// character span within the document's text.
    private struct ChunkMetaRow: Decodable {
        let d: String
        let o: Int
        let c0: Int
        let c1: Int
    }
}
