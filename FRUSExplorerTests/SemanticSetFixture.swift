// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
@testable import FRUSExplorer

/// A synthetic semantic corpus for the tests of a Meaning search inside a document set (#1577).
///
/// ## Why it is synthetic
///
/// `SemanticQuerySearcherTests` drives the searcher over the bundled vectors and two real shards,
/// and those shard files are gitignored, so on a new checkout that suite is disabled and reports
/// green. A rule this consequential needs a suite that cannot skip. So the index, the corpus-wide
/// sign bits and every shard here are written with the kit's own writers
/// (`SemanticVectorsArtifacts.corpusBinary` and `.volumeShard`) from vectors planted below, and the
/// embedding is injected. Nothing is read from the bundle, the repository or the network.
///
/// ## What is planted
///
/// Sixty-four dimensions, the narrowest width the kit's Hamming scan reads (it takes a row as
/// 64-bit words). The query is the all-ones vector. A document's vector has its first `positives`
/// components at +1 and the rest at −1, so its cosine with the query is `positives / 32 − 1`, and
/// its Hamming distance from the query is `64 − positives`.
///
/// - ``crowd``: 120 documents, all sixteen components positive in slightly different sizes. They
///   are at Hamming distance 0 and so fill the corpus-wide search's whole candidate pool: no
///   document of any other volume is ever a corpus-wide candidate here.
/// - ``held``: twelve documents with their match file on the device. Ten are in the set. The other
///   two, `d11` and `d12`, are closer to the query than any member and are not in it.
/// - ``absent``: six documents with vectors in the index and no match file on the device.
/// - ``twinSecond`` and ``twinFirst``: an edition pair with identical vectors. The second edition
///   is listed first in the index, so its rows come first while its keys sort last: a tie broken by
///   key would order the pair the other way round from a tie broken by row.
///
/// `d9` and `d10` of ``held`` tie as well, at rows 128 and 129, and `"…/d10"` sorts before
/// `"…/d9"`, for the same reason.
///
/// Version history:
///   1.0 — #1577 lane 1: initial implementation
enum SemanticSetFixture {

    /// The vectors' width, native and shipping.
    static let dims = 64

    /// The volume that fills the corpus-wide candidate pool.
    static let crowd = "frus1969-76v01"
    /// The volume most of the set is in; its match file is on the device.
    static let held = "frus1977-80v02"
    /// A volume whose match file is not on the device.
    static let absent = "frus1981-88v03"
    /// The first edition of the twin pair, listed second in the index.
    static let twinFirst = "frus1951-54Iran"
    /// The second edition of the twin pair, listed first in the index.
    static let twinSecond = "frus1951-54IranEd2"

    /// How many documents ``crowd`` holds: more than the corpus-wide list's hundred.
    static let crowdCount = 120

    /// `positives` for each document of ``held``, `d1` first.
    static let heldPositives = [8, 24, 4, 20, 0, 16, 28, 32, 12, 12, 36, 40]
    /// `positives` for each document of ``absent``.
    static let absentPositives = [4, 4, 4, 4, 4, 4]
    /// `positives` for each document of either twin volume.
    static let twinPositives = [36, 8, 4]

    /// One planted volume: its id and each document's vector, in row order.
    struct Volume {
        let id: String
        let vectors: [[Float]]
        /// Document ids in row order: `d1`, `d2`, ….
        var documentIDs: [String] { (1...vectors.count).map { "d\($0)" } }
    }

    /// Every planted volume, in the index's row order.
    static let volumes: [Volume] = [
        Volume(id: crowd, vectors: (0..<crowdCount).map(crowdVector)),
        Volume(id: held, vectors: heldPositives.map(vector(positives:))),
        Volume(id: absent, vectors: absentPositives.map(vector(positives:))),
        Volume(id: twinSecond, vectors: twinPositives.map(vector(positives:))),
        Volume(id: twinFirst, vectors: twinPositives.map(vector(positives:))),
    ]

    /// The volumes whose match files the fixture puts on the device: all but ``absent``.
    static let volumesWithShards = [crowd, held, twinSecond, twinFirst]

    /// The query's embedding: the all-ones vector.
    static let queryEmbedding = [Double](repeating: 1, count: dims)

    /// The set the tests search inside, as `SearchParameters.documentIds` keys it.
    ///
    /// Seventeen distinct keys, given in an order that is neither row order nor score order, with
    /// one key repeated:
    /// - twelve that can be ranked: `d1`…`d10` of ``held`` and `d1` of each twin volume;
    /// - two whose volume's match file is absent: `d2` and `d5` of ``absent``;
    /// - three with no vector: an id the index does not hold, a volume it does not cover, and a
    ///   key with no volume at all.
    static let documentSet: [String] = [
        "\(held)/d10", "\(held)/d3", "\(twinFirst)/d1", "\(held)/d7", "\(absent)/d5",
        "\(held)/d1", "\(held)/frontmatter", "\(held)/d9", "\(held)/d2", "frus2099v01/d1",
        "\(twinSecond)/d1", "\(held)/d5", "\(held)/d8", "not-a-key", "\(held)/d4",
        "\(absent)/d2", "\(held)/d6", "\(held)/d1",
    ]

    /// How many distinct keys ``documentSet`` holds.
    static let documentSetSize = 17
    /// Members of ``documentSet`` with no vector.
    static let plantedWithoutVector = 3
    /// Members of ``documentSet`` whose volume's match file is absent, all in one volume.
    static let plantedWithoutShard = 2

    // MARK: - Vectors

    /// A vector with its first `positives` components at +1 and the rest at −1.
    static func vector(positives: Int) -> [Float] {
        (0..<dims).map { $0 < positives ? 1 : -1 }
    }

    /// The `index`th crowd vector: every component positive, in sizes that differ by document.
    static func crowdVector(_ index: Int) -> [Float] {
        (0..<dims).map { 1 + 0.02 * Float((index * 7 + $0 * 3) % 5) }
    }

    /// `vector` at unit length.
    static func unit(_ vector: [Float]) -> [Float] {
        let norm = vector.reduce(0.0) { $0 + Double($1) * Double($1) }.squareRoot()
        return vector.map { Float(Double($0) / norm) }
    }

    /// The exact cosine between `vector` and the query, computed here in floating point and by no
    /// code the app ships.
    static func cosineWithQuery(_ vector: [Float]) -> Double {
        var dot = 0.0, vectorNorm = 0.0, queryNorm = 0.0
        for (component, query) in zip(vector, queryEmbedding) {
            dot += Double(component) * query
            vectorNorm += Double(component) * Double(component)
            queryNorm += query * query
        }
        return dot / (vectorNorm.squareRoot() * queryNorm.squareRoot())
    }

    // MARK: - The expected ranking

    /// One document as the brute-force ranking sees it.
    struct Ranked: Equatable {
        let key: String
        let score: Double
        let row: Int
    }

    /// The members of `keys` that can be scored, ranked by brute force: every planted vector's
    /// cosine with the query, best first, a tie going to the lower corpus row.
    ///
    /// A member is left out when the index holds no row for it or its volume is ``absent``, which
    /// are the two things the searcher counts and does not rank.
    static func bruteForceRanking(of keys: [String]) -> [Ranked] {
        var rowOffset = 0
        var table: [String: Ranked] = [:]
        for volume in volumes {
            for (local, id) in volume.documentIDs.enumerated() where volume.id != absent {
                let key = "\(volume.id)/\(id)"
                table[key] = Ranked(key: key, score: cosineWithQuery(volume.vectors[local]),
                                    row: rowOffset + local)
            }
            rowOffset += volume.vectors.count
        }
        return Set(keys).compactMap { table[$0] }
            .sorted { $0.score == $1.score ? $0.row < $1.row : $0.score > $1.score }
    }

    // MARK: - Artifacts

    /// The provenance every synthetic artifact carries.
    static let provenance = SemanticVectorsArtifacts.Provenance(
        model: "synthetic-set-fixture", modelFileSHA256: "00", nativeDims: dims,
        shippingDims: dims, chunkChars: 1, overlapChars: 0, prefix: "", pooling: "none",
        quantization: "the kit's own")

    /// The synthetic index: every volume's row block and ids, and a candidate pool of 8, so that
    /// the corpus-wide search's pool is its caller's limit.
    ///
    /// - Parameter volumes: The volumes to index, in row order; the planted ones by default.
    static func makeIndex(volumes: [Volume] = volumes) -> SemanticVectorIndex {
        var rowOffset = 0
        var entries: [SemanticVectorsArtifacts.VolumeEntry] = []
        for volume in volumes {
            entries.append(SemanticVectorsArtifacts.VolumeEntry(
                volumeID: volume.id, rowOffset: rowOffset, documentCount: volume.vectors.count,
                idSegments: DocumentIDSegments.encode(volume.documentIDs)))
            rowOffset += volume.vectors.count
        }
        return SemanticVectorIndex(file: SemanticVectorsArtifacts.Index(
            schema: 1, generated: "2026-10-10", provenance: provenance,
            harvestGenerated: "2026-10-10", harvestScriptSHA256: "00",
            documentCount: rowOffset, volumes: entries, subseries: [],
            retrieval: .init(rerankPool: 8, measuredRecallAt10: 0, measuredBy: "not measured")))
    }

    /// What a searcher over the fixture needs, written under `directory`.
    struct Artifacts {
        let index: SemanticVectorIndex
        let corpus: SemanticCorpusVectors
        let shardStore: SemanticShardStore
        let modelStore: SemanticModelStore
    }

    /// Writes the corpus binary and the shards of `withShards` under `directory`, and opens them
    /// through the readers the app uses.
    ///
    /// - Parameters:
    ///   - directory: An empty directory the caller removes afterwards.
    ///   - volumes: The volumes to write, in row order; the planted ones by default.
    ///   - withShards: The volumes whose match files are written; ``volumesWithShards`` by default.
    /// - Returns: The index, the mapped corpus tier, and a shard store over the written shards.
    static func writeArtifacts(
        in directory: URL, volumes: [Volume] = volumes, withShards: [String] = volumesWithShards
    ) throws -> Artifacts {
        let index = makeIndex(volumes: volumes)
        let shardDirectory = directory.appendingPathComponent("shards", isDirectory: true)
        try FileManager.default.createDirectory(at: shardDirectory, withIntermediateDirectories: true)

        var signBits: [[UInt8]] = []
        for volume in volumes {
            let units = volume.vectors.map(unit)
            signBits += units.map(SemanticQuantization.packSignBits)
            guard withShards.contains(volume.id) else { continue }
            var codes: [[Int8]] = []
            var scales: [Float] = []
            for vector in units {
                guard let quantized = SemanticQuantization.quantizeInt8(vector) else {
                    throw CocoaError(.fileWriteUnknown)
                }
                codes.append(quantized.codes)
                scales.append(quantized.scale)
            }
            try SemanticVectorsArtifacts.volumeShard(
                codes: codes, scales: scales, dims: dims, provenance: provenance
            ).write(to: shardDirectory.appendingPathComponent("\(volume.id).vec"))
        }

        let corpusURL = directory.appendingPathComponent("corpus.bin")
        try SemanticVectorsArtifacts.corpusBinary(
            signBits: signBits, centroids: [], dims: dims, provenance: provenance
        ).write(to: corpusURL)

        return Artifacts(
            index: index,
            corpus: try SemanticCorpusVectors(contentsOf: corpusURL, expecting: provenance),
            shardStore: SemanticShardStore(
                directory: shardDirectory, provenance: provenance,
                expectedCounts: Dictionary(
                    uniqueKeysWithValues: volumes.map { ($0.id, $0.vectors.count) })),
            modelStore: SemanticModelStore(
                directory: directory.appendingPathComponent("model", isDirectory: true),
                expectedSHA256: provenance.modelFileSHA256))
    }

    /// Writes one TEI file per planted volume into `volumesDirectory`, each document a heading and
    /// a sentence, so a test index holds a row for every planted document.
    ///
    /// - Parameters:
    ///   - volumesDirectory: The directory an `IndexingPipeline` reads volumes from.
    ///   - omitting: Keys (`"volumeId/documentId"`) to leave out of the files, for a document the
    ///     vectors name and the device's volume does not hold.
    static func writeTEIVolumes(to volumesDirectory: URL, omitting: Set<String> = []) throws {
        try FileManager.default.createDirectory(at: volumesDirectory, withIntermediateDirectories: true)
        for volume in volumes {
            var xml = "<?xml version=\"1.0\"?>\n<TEI><text><body>\n"
            for id in volume.documentIDs where !omitting.contains("\(volume.id)/\(id)") {
                xml += "<div type=\"document\" xml:id=\"\(id)\"><head>Paper \(id)</head>"
                    + "<p>The mission reported on the talks.</p></div>\n"
            }
            xml += "</body></text></TEI>"
            try Data(xml.utf8).write(to: volumesDirectory.appendingPathComponent("\(volume.id).xml"))
        }
    }
}
