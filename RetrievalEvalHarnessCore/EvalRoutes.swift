// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SQLite3
import FTS5Store
import SemanticVectorsKit
import SemanticVectorsGeneratorCore

/// One ranked result row, route-agnostic.
public struct EvalResult: Sendable, Equatable {
    /// The document's volume.
    public let volumeId: String
    /// The document's id.
    public let documentId: String
    /// The route's own score — negative BM25 for the lexical route, approximate cosine for
    /// the semantic one. Comparable within a route, never across routes.
    public let score: Double

    /// Creates a result.
    public init(volumeId: String, documentId: String, score: Double) {
        self.volumeId = volumeId
        self.documentId = documentId
        self.score = score
    }

    /// The composite key.
    public var key: String { "\(volumeId)/\(documentId)" }
}

// MARK: - Lexical route

/// The lexical route: the app's own search — `FTS5InlineQueryParser`'s rendered MATCH
/// expression, unrestricted columns, BM25 order — against the live index, opened read-only
/// and immutable so the harness cannot write a byte into the owner's database.
public final class LexicalEvalRoute {

    private var db: OpaquePointer?

    /// Opens the index read-only.
    public init(databasePath: String) throws {
        var handle: OpaquePointer?
        let uri = "file:\(databasePath)?immutable=1"
        guard sqlite3_open_v2(uri, &handle,
                              SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK,
              let handle else {
            throw EvalError("could not open the index read-only at \(databasePath)")
        }
        self.db = handle
    }

    deinit { sqlite3_close(db) }

    /// Top results for a raw typed query, exactly as the search box would run it.
    ///
    /// Returns the rendered expression alongside the rows so the report can show what
    /// actually executed — the honesty the Query Inspector exists for, carried into the
    /// evaluation.
    public func search(_ raw: String, limit: Int) throws -> (expression: String?, rows: [EvalResult]) {
        guard let expression = FTS5InlineQueryParser.parse(raw) else { return (nil, []) }
        let sql = """
            SELECT volume_id, document_id, bm25(frus_documents) AS score
            FROM frus_documents
            WHERE frus_documents MATCH ?
            ORDER BY score
            LIMIT ?
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw EvalError("lexical prepare failed: \(String(cString: sqlite3_errmsg(db)))")
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, expression, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_int64(stmt, 2, Int64(limit))
        var rows: [EvalResult] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let v = sqlite3_column_text(stmt, 0), let d = sqlite3_column_text(stmt, 1)
            else { continue }
            rows.append(EvalResult(volumeId: String(cString: v),
                                   documentId: String(cString: d),
                                   score: sqlite3_column_double(stmt, 2)))
        }
        return (expression, rows)
    }

    /// Display fields for a result key: header, dateline, and the **prose-first** snippet —
    /// `EvalSnippet` strips the body's own front-matter echo (header, stored source note,
    /// dateline, despatch serial) so the judge reads text the row has not already shown.
    /// The body window is fetched at ~10× the snippet target so stripping has room to work.
    public func display(volumeId: String, documentId: String)
        -> (header: String, dateline: String?, snippet: String)? {
        let sql = """
            SELECT dc.header, dc.dateline, substr(dc.body_text, 1, 3000), ds.raw_text
            FROM document_cache dc
            LEFT JOIN document_sources ds
                ON ds.volume_id = dc.volume_id AND ds.document_id = dc.document_id
            WHERE dc.volume_id = ? AND dc.document_id = ? LIMIT 1
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return nil }
        defer { sqlite3_finalize(stmt) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, volumeId, -1, transient)
        sqlite3_bind_text(stmt, 2, documentId, -1, transient)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        let header = sqlite3_column_text(stmt, 0).map { String(cString: $0) } ?? documentId
        let dateline = sqlite3_column_text(stmt, 1).map { String(cString: $0) }
        let body = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
        let note = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
        let snippet = EvalSnippet.prose(
            header: header, dateline: dateline, sourceNote: note, body: body)
        return (header, dateline, snippet)
    }
}

// MARK: - Semantic route

/// The semantic route: the exact shipped funnel — Hamming over the bundled sign-bit tier at
/// the artifact's own rerank pool, exact int8 cosine against the per-volume shards — entered
/// through `SemanticRetrievalKernel`'s external-query overload, whose parity with the shipped
/// row path is pinned in the kit's tests. The transforms between the raw embedding and the
/// funnel (Matryoshka truncate + renormalize, int8 symmetric, sign packing) are the
/// generator's own `SemanticQuantization` — one definition, never a re-implementation.
public final class SemanticEvalRoute {

    /// The decoded bundled index.
    public let index: SemanticVectorIndex
    private let corpus: SemanticCorpusVectors
    private let shardsDirectory: URL
    private var shards: [String: SemanticShard?] = [:]

    /// Loads the bundled tiers.
    public init(indexDirectory: URL, shardsDirectory: URL) throws {
        let file = try JSONDecoder().decode(
            SemanticVectorsArtifacts.Index.self,
            from: Data(contentsOf: indexDirectory.appendingPathComponent("semantic-vectors-index.json")))
        self.index = SemanticVectorIndex(file: file)
        self.corpus = try SemanticCorpusVectors(
            contentsOf: indexDirectory.appendingPathComponent("semantic-vectors-binary.bin"),
            expecting: file.provenance)
        self.shardsDirectory = shardsDirectory
    }

    /// The artifact's pinned model-file SHA-256.
    public var pinnedModelSHA256: String { index.provenance.modelFileSHA256 }

    /// Top neighbours for an already-embedded query vector (native width).
    public func search(embedding: [Double], limit: Int) throws -> [EvalResult] {
        let dims = index.provenance.shippingDims
        guard let cut = SemanticQuantization.truncate(embedding, to: dims) else {
            throw EvalError("query vector would not truncate to \(dims) dims")
        }
        guard let int8 = SemanticQuantization.quantizeInt8(cut) else {
            throw EvalError("query vector quantized to nothing")
        }
        let bits = SemanticQuantization.packSignBits(cut)
        let pool = max(limit, index.file.retrieval.rerankPool)
        let candidates = SemanticRetrievalKernel.hammingCandidates(
            queryBits: bits, in: corpus, limit: pool)

        let neighbours = SemanticRetrievalKernel.rerank(candidates: candidates, limit: limit) { row in
            guard let located = index.volumeSlot(containing: row) else { return nil }
            let volumeID = index.volumes[located.slot].volumeID
            guard let shard = shard(for: volumeID) else { return nil }
            return shard.cosine(row: located.localRow, query: int8.codes, queryScale: int8.scale)
        }
        return neighbours.compactMap { neighbour in
            guard let document = index.document(at: neighbour.row) else { return nil }
            return EvalResult(volumeId: document.volumeID, documentId: document.documentID,
                              score: neighbour.score)
        }
    }

    /// Lazily maps a volume's shard; a missing or mismatched shard is recorded as absent, and
    /// its rows are dropped rather than scored — the kernel's own missing-evidence rule.
    private func shard(for volumeID: String) -> SemanticShard? {
        if let cached = shards[volumeID] { return cached }
        let url = shardsDirectory.appendingPathComponent("\(volumeID).vec")
        let loaded = try? SemanticShard(
            contentsOf: url, provenance: index.provenance,
            expectedDocumentCount: index.volume(volumeID)?.documentCount)
        shards[volumeID] = loaded
        return loaded
    }
}
