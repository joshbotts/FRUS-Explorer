// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - DocumentSubjectsInput

/// The decoded `document_subjects.json` from the public-domain `frus-subjects`
/// handoff — the sole generator input. Everything the aggregator needs is here:
/// `subjectsIndex` supplies each ref's display metadata and `subjects` supplies the
/// per-volume document appearances.
///
/// The parallel `taxonomy.json` in the handoff is deliberately NOT read: it only adds
/// variants / LCSH links / corpus totals the volume-level profile does not use, and
/// its subject set is a superset (23 refs with zero appearances) that would need
/// filtering anyway.
struct DocumentSubjectsInput: Decodable {

    /// The source dataset's own generated date (e.g. `"2026-06-16"`) — carried into
    /// the output provenance so a stale handoff is traceable.
    let generated: String

    /// `ref → { name, category, subcategory }`. 520 real refs (those with appearances).
    let subjectsIndex: [String: SubjectMeta]

    /// `ref → { volumeId → "d10, d111, …" }`. The inner value is a comma+space-joined
    /// list of TEI div ids (the appearances of the subject in that volume).
    let subjects: [String: [String: String]]

    /// One subject's display metadata.
    struct SubjectMeta: Decodable {
        /// Display name (e.g. `"Neutrality"`).
        let name: String
        /// Top-level category (one of the source taxonomy's 13).
        let category: String
        /// Second-level subcategory.
        let subcategory: String
    }

    /// Decodes the input from already-loaded JSON bytes (the runner reads the file
    /// once so the same bytes can be MD5-pinned into the provenance).
    ///
    /// - Parameter data: The raw `document_subjects.json` contents.
    /// - Returns: The decoded input.
    /// - Throws: If the data cannot be decoded.
    static func load(from data: Data) throws -> DocumentSubjectsInput {
        try JSONDecoder().decode(DocumentSubjectsInput.self, from: data)
    }

    /// Splits a comma+space-joined document-id list (`"d10, d111, d113"`) into its
    /// distinct trimmed ids.
    ///
    /// - Parameter joined: The raw joined string from `subjects[ref][volumeId]`.
    /// - Returns: The distinct, non-empty document ids (order not significant).
    static func documentIds(from joined: String) -> Set<String> {
        var out: Set<String> = []
        for piece in joined.split(separator: ",") {
            let trimmed = piece.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { out.insert(trimmed) }
        }
        return out
    }
}
