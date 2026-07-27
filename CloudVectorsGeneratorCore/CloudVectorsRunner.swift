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
import WordCloudKit
import GeneratorKit

/// Drives the cloud-vector generation: read the corpus, tokenise every volume once,
/// roll up, write two artifacts.
///
/// Entirely offline and deterministic — a filename-sorted scan, explicit sorts at every
/// ranking step, and `.sortedKeys` output, so two runs over the same corpus are
/// byte-identical.
///
/// Version history:
///   1.0 — O-1: initial implementation
public enum CloudVectorsRunner {

    /// Runs the generator, honouring the environment overrides documented in `CLAUDE.md`.
    public static func run() throws {
        let env = ProcessInfo.processInfo.environment
        let volumesDir = URL(fileURLWithPath: env["VOLUMES_DIR"] ?? "/Users/jbotts/Development/frus/volumes")
        let manifestPath = env["MANIFEST"] ?? "FRUSExplorer/Resources/manifest.json"
        let lexiconsPath = env["LEXICONS"] ?? "FRUSExplorer/Resources/word-cloud-lexicons.json"
        let stopwordsPath = env["STOPWORDS"] ?? "FRUSExplorer/Resources/word-cloud-stopwords.json"
        let outputDir = URL(fileURLWithPath: env["OUTPUT_DIR"] ?? "FRUSExplorer/Resources")
        let generated = generatorDateStamp(override: env["GENERATED_DATE"])

        // The generator THROWS on a bad lexicon or stopword file where the app degrades to
        // empty lists. A shipped artifact built without stopwords would bury every cloud
        // under "the"/"of"/"department" and nothing downstream would notice.
        let lexicons = try WordCloudLexiconSet(contentsOf: URL(fileURLWithPath: lexiconsPath))
        let stopwordSet = try WordCloudStopwordSet(contentsOf: URL(fileURLWithPath: stopwordsPath))
        guard !stopwordSet.english.isEmpty else {
            throw RunError.emptyStopwords(stopwordsPath)
        }
        guard !lexicons.concepts.isEmpty, !lexicons.sentimentAll.isEmpty else {
            throw RunError.emptyLexicons(lexiconsPath)
        }

        let manifest = try loadManifest(URL(fileURLWithPath: manifestPath))
        generatorLog("manifest: \(manifest.count) shippable volumes")

        let tuning = WordCloudTuning.standard
        // The diplomatic layer matches the app's default (`excludeBoilerplate` on): without
        // it every cloud is "telegram / department / washington" and previews nothing.
        let stopwords = stopwordSet.active(includeDiplomatic: true)
        let markings = tuning.filterMarkings ? stopwordSet.markings : []

        guard let tokenizer = WordCloudMultiLensTokenizer(
            lenses: WordCloudLens.bundledCloudLenses,
            tuning: tuning,
            stopwords: stopwords,
            lexicons: lexicons,
            markings: markings
        ) else { throw RunError.tokenizerConfiguration }

        let files = try VolumeCorpusEnumerator.volumeFiles(in: volumesDir)
        generatorLog("corpus: \(files.count) volume files in \(volumesDir.path)")

        // Only manifest volumes ship, so only they are tokenised — the corpus directory
        // carries 694 files against the manifest's 552.
        let shippable = files.filter { manifest[VolumeCorpusEnumerator.volumeId(for: $0)] != nil }
        generatorLog("tokenising \(shippable.count) volumes present in the manifest")

        var volumeCounts: [CloudVectorsAggregator.VolumeCounts] = []
        var emptyVolumes: [String] = []
        for (n, file) in shippable.enumerated() {
            let volumeId = VolumeCorpusEnumerator.volumeId(for: file)
            guard let subseries = manifest[volumeId] else { continue }
            let xml = try String(contentsOf: file, encoding: .utf8)
            let documents = TEIBodyTextExtractor.documents(in: xml)

            var counts: [WordCloudLens: [String: Int]] = [:]
            for document in documents {
                tokenizer.accumulate(from: document.bodyText, into: &counts)
            }
            if documents.isEmpty || counts.isEmpty { emptyVolumes.append(volumeId) }

            volumeCounts.append(.init(volumeId: volumeId, subseries: subseries,
                                      documentCount: documents.count, counts: counts))
            if (n + 1) % 50 == 0 { generatorLog("  \(n + 1)/\(shippable.count)…") }
        }

        // A volume that tokenises to nothing is a finding, not a small cloud: it means the
        // extractor failed to see its documents. Reported, never silently shipped as empty.
        if !emptyVolumes.isEmpty {
            generatorLog("WARNING: \(emptyVolumes.count) volume(s) produced no terms: "
                         + emptyVolumes.prefix(10).joined(separator: ", ")
                         + (emptyVolumes.count > 10 ? " …" : ""))
        }

        let output = CloudVectorsAggregator(lexicons: lexicons)
            .pack(volumes: volumeCounts, generated: generated, tuning: tuning)

        try write(output.core, to: outputDir.appendingPathComponent("cloud-vectors-core.json"))
        try write(output.volumes, to: outputDir.appendingPathComponent("cloud-vectors-volumes.json"))
    }

    // MARK: - IO

    /// Encodes deterministically and reports the size, which is the acceptance number:
    /// a core file over ~500 KB or a volumes file over ~2.5 MB means the vocabulary
    /// factoring is not working and is a finding, not a tolerance to widen.
    private static func write(_ file: CloudVectorsFile, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(file)
        try data.write(to: url)
        let kb = Double(data.count) / 1024
        generatorLog(String(format: "wrote %@ — %.0f KB, %d scopes, %d vocabulary terms",
                            url.lastPathComponent, kb, file.scopes.count, file.vocabulary.count))
    }

    /// volumeId → subseries, from the shippable manifest.
    private static func loadManifest(_ url: URL) throws -> [String: String] {
        struct Entry: Decodable { let volumeId: String; let subseries: String }
        let data = try Data(contentsOf: url)
        let entries = try JSONDecoder().decode([Entry].self, from: data)
        return Dictionary(entries.map { ($0.volumeId, $0.subseries) }, uniquingKeysWith: { a, _ in a })
    }

    /// Failures that should stop the run rather than produce a plausible-looking artifact.
    public enum RunError: Error, CustomStringConvertible {
        case emptyStopwords(String)
        case emptyLexicons(String)
        case tokenizerConfiguration

        public var description: String {
            switch self {
            case .emptyStopwords(let path):
                return "Stopword list at \(path) decoded to an empty English layer. Every cloud "
                     + "would be dominated by function words; refusing to write an artifact."
            case .emptyLexicons(let path):
                return "Lexicons at \(path) decoded empty. The concepts and sentiment lenses "
                     + "would be blank; refusing to write an artifact."
            case .tokenizerConfiguration:
                return "WordCloudMultiLensTokenizer rejected the configured lenses "
                     + "(empty, or an entity lens was included)."
            }
        }
    }
}
