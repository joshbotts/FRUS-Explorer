// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import CryptoKit
import GeneratorKit

// MARK: - DocumentSubjectIndexRunner

/// Builds `document-subject-index.json` from the Office of the Historian's frus-subjects drop
/// (#308 Phase 3).
///
/// Entirely offline and deterministic: the source is one JSON file, the vocabulary is sorted by
/// ref, every document's subject list is sorted, and the encoder uses `.sortedKeys`. A rebuild from
/// the same drop is byte-identical.
///
/// ## The source shape, and the one that is superseded
/// Reads `frus-subject-taxonomy/exports/document_subjects.json` — the **corrected** export. The
/// older `frus-subjects/data` drop has the same filename and a different, superseded content
/// (1,423,734 references against 877,817), and pointing at it silently reverts #994. CLAUDE.md
/// records the same warning for `VolumeSubjectProfilesGenerator`, which reads the same file.
///
/// ## What it does NOT do
/// No breadth filter and no era gate — see `DocumentSubjectIndexArtifact` for the measurements
/// behind both. Everything the source asserts is carried through, and the three consuming features
/// tune their own use of it.
///
/// Version history:
///   1.0 — Session 2026-08-21: #308 Phase 3
public enum DocumentSubjectIndexRunner {

    /// The artifact schema version.
    public static let schemaVersion = 1

    /// Reads configuration from the environment and runs the build.
    public static func run() throws {
        let env = ProcessInfo.processInfo.environment
        try run(documentSubjectsPath: env["DOCUMENT_SUBJECTS"]
                    ?? "/Users/jbotts/Development/frus-subject-taxonomy/exports/document_subjects.json",
                outputPath: env["OUTPUT"]
                    ?? "FRUSExplorer/Resources/document-subject-index.json",
                generated: generatorDateStamp(override: env["GENERATED_DATE"]))
    }

    /// The parameterized build, callable from tests without touching the environment.
    public static func run(documentSubjectsPath: String, outputPath: String,
                           generated: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: documentSubjectsPath))
        let source = try JSONDecoder().decode(SourceDrop.self, from: data)
        let md5 = Insecure.MD5.hash(data: data).map { String(format: "%02hhx", $0) }.joined()

        let artifact = try build(source: source, sourceMD5: md5,
                                 sourcePath: documentSubjectsPath, generated: generated)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let out = try encoder.encode(artifact)
        try out.write(to: URL(fileURLWithPath: outputPath))

        let pairs = artifact.documents.values.reduce(0) { $0 + $1.values.reduce(0) { $0 + $1.count } }
        generatorLog("""
        document-subject-index.json written to \(outputPath)
          source:                 \(source.generated) (md5 \(md5))
          subjects in vocabulary: \(artifact.vocab.count)
          documents:              \(artifact.documentCount)
          (document, subject):    \(pairs)
          co-occurring pairs:     \(artifact.coOccurrence.counts.count)
          bytes:                  \(out.count)
          breadth filter:         NONE (owner decision — a max-volumes cut empties 72% of documents)
          era-sanity:             NOT APPLIED (retired for both grains)
        """)
    }

    // MARK: - Build

    /// Assembles the artifact. Separated from IO so tests can drive it over a fixture.
    public static func build(source: SourceDrop, sourceMD5: String, sourcePath: String,
                             generated: String) throws -> DocumentSubjectIndexArtifact {
        // Vocabulary first, sorted by ref, so indices are stable across runs.
        let refs = source.subjects.keys.sorted()
        guard !refs.isEmpty else { throw DocumentSubjectIndexError.noMappings(path: sourcePath) }

        // Pass 1: invert to documents, and count each subject's document frequency. Both come out
        // of one walk — a second pass would be a second thing that can disagree with the first.
        var documents: [String: [String: [Int]]] = [:]
        var documentFrequency = [Int](repeating: 0, count: refs.count)
        var seenDocuments: Set<String> = []
        for (index, ref) in refs.enumerated() {
            guard source.subjectsIndex[ref] != nil else {
                throw DocumentSubjectIndexError.unknownSubject(ref: ref)
            }
            for (volumeId, documentList) in source.subjects[ref] ?? [:] {
                for raw in documentList.split(separator: ",") {
                    let documentId = raw.trimmingCharacters(in: .whitespaces)
                    guard !documentId.isEmpty else { continue }
                    documents[volumeId, default: [:]][documentId, default: []].append(index)
                    documentFrequency[index] += 1
                    seenDocuments.insert("\(volumeId)/\(documentId)")
                }
            }
        }
        guard !documents.isEmpty else { throw DocumentSubjectIndexError.noMappings(path: sourcePath) }

        // Sort every document's list so the artifact is order-stable and a diff is meaningful.
        for volumeId in documents.keys {
            for documentId in documents[volumeId]!.keys {
                documents[volumeId]![documentId]!.sort()
            }
        }

        // Pass 2: co-occurrence, over the SAME `documents` map that ships — so the stored counts
        // and the rows they describe cannot disagree even in principle.
        var pairCounts: [Int64: Int] = [:]
        for (_, byDocument) in documents {
            for (_, list) in byDocument {
                guard list.count > 1 else { continue }
                for i in 0..<(list.count - 1) {
                    for j in (i + 1)..<list.count {
                        // The list is sorted, so list[i] < list[j] and the key is canonical.
                        pairCounts[Int64(list[i]) << 32 | Int64(list[j]), default: 0] += 1
                    }
                }
            }
        }
        let orderedPairs = pairCounts.keys.sorted()
        let coOccurrence = DocumentSubjectIndexArtifact.CoOccurrence(
            lower: orderedPairs.map { Int($0 >> 32) },
            higher: orderedPairs.map { Int($0 & 0xFFFF_FFFF) },
            counts: orderedPairs.map { pairCounts[$0]! })

        let vocab = refs.enumerated().map { index, ref -> DocumentSubjectIndexArtifact.VocabEntry in
            let meta = source.subjectsIndex[ref]!
            return .init(ref: ref, name: meta.name, category: meta.category,
                         subcategory: meta.subcategory,
                         documentFrequency: documentFrequency[index])
        }

        return DocumentSubjectIndexArtifact(
            schemaVersion: schemaVersion, generated: generated,
            provenance: """
                Derived from the Office of the Historian public-domain frus-subjects handoff \
                (document_subjects.json, source generated \(source.generated), md5 \(sourceMD5)) by \
                DocumentSubjectIndexGenerator. Detected topics from case-insensitive string \
                matching of subject names and variants, NOT semantic analysis — treat as \
                recall-oriented candidates rather than ground truth. Complete: no breadth filter \
                and no era-sanity gate are applied, because both were measured to remove more \
                legitimate content than error.
                """,
            documentCount: seenDocuments.count, vocab: vocab, documents: documents,
            coOccurrence: coOccurrence)
    }

    // MARK: - Source

    /// The upstream drop, decoded only as far as this generator needs it.
    public struct SourceDrop: Decodable, Sendable {
        public struct SubjectMeta: Decodable, Sendable {
            public let name: String
            public let category: String
            public let subcategory: String
        }
        public let generated: String
        /// subject ref → display metadata.
        public let subjectsIndex: [String: SubjectMeta]
        /// subject ref → volumeId → `"d1, d2, d3"`.
        public let subjects: [String: [String: String]]
    }
}
