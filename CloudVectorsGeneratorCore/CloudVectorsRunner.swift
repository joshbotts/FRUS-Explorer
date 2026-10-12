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
/// roll up, write four artifacts — the two cloud-vector files, the keyness reference in
/// dictionary forms and, since #1608, the same reference counted as printed.
///
/// Entirely offline and deterministic — a filename-sorted scan, explicit sorts at every
/// ranking step, and `.sortedKeys` output, so two runs over the same corpus are
/// byte-identical.
///
/// ## The reference counted as printed (#1608)
/// It is written from the pass that writes the other three: `WordCloudMultiLensTokenizer` counts
/// each word's printed form beside its dictionary form, so the corpus is tagged once. What the app
/// compares with it is a scope counted by a tagger with no lemma scheme, which is other code, and
/// the two agree only while two properties of `NLTagger` hold (see that tokenizer's "Both forms
/// from one pass"). `VERIFY_PRINTED_WALK=1` measures it instead of assuming it: every document is
/// walked again with no lemma scheme, the way a launch with no lemmatiser walks it, and the run
/// stops before it writes anything if a volume's tallies differ in one count. A device builds two
/// taggers for that walk, one that also holds the lexical classes and one that holds the token type
/// alone, so the verification makes both walks (``printedVerificationWalks(tuning:stopwords:lexicons:markings:)``).
///
/// ## Memory
/// Each document is tagged inside an autorelease pool of its own (#1608). Without one the run kept
/// every object the tagger autoreleased until it ended: the unchanged generator peaked at a
/// 24.9 GB memory footprint over the corpus on 2026-10-12, and the verification walk, which tags
/// every document twice, at 49.1 GB, on a Mac with 32 GB. Measured on a 40-volume subset with the
/// walk on, the pools took the peak from 3.89 GB to 235 MB and the four files came out byte for
/// byte the same.
///
/// Version history:
///   1.0 — O-1: initial implementation
///   1.1 — #1373: refuses to run when `NaturalLanguageReadiness`'s canary finds no lemmas or no
///          lexical classes in this process
///   1.2 — #1608: counts printed forms in the same pass and writes `keyness-baseline-printed.json`;
///          `VERIFY_PRINTED_WALK`, which walks with both taggers a device builds; refuses to
///          write a printed reference that lacks a lens; an autorelease pool for each document
public enum CloudVectorsRunner {

    /// Every lens the run tokenises: the four the cloud draws, plus the two extra the keyness
    /// baseline needs. Named once so the artifact test and the parity suite can assert against the
    /// same list rather than a repeated literal.
    public static let baselineLenses: [WordCloudLens] =
        [.allTerms, .descriptors] + WordCloudLens.bundledCloudLenses

    /// Runs the generator, honouring the environment overrides documented in
    /// `Planning/Generators-Runbook.md`.
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
        // The same canary the app's word cloud and Distinctive measure consult (#1373), because
        // this run writes the reference Distinctive compares against: counted without lemmas it
        // would be a reference of printed forms, and every lemmatised scope would be scored
        // against the wrong vocabulary with nothing on screen to say so.
        try requireLanguageAnalysis(NaturalLanguageReadiness.health)

        let manifest = try loadManifest(URL(fileURLWithPath: manifestPath))
        generatorLog("manifest: \(manifest.count) shippable volumes")

        let tuning = WordCloudTuning.standard
        // The diplomatic layer matches the app's default (`excludeBoilerplate` on): without
        // it every cloud is "telegram / department / washington" and previews nothing.
        let includeDiplomatic = true
        let stopwords = stopwordSet.active(includeDiplomatic: includeDiplomatic)
        let markings = tuning.filterMarkings ? stopwordSet.markings : []

        // The keyness baseline pins itself to the payloads it was built from. Digested here, from
        // the same bytes the app will digest at read time — a lexicon edit without a regeneration
        // would otherwise give every newly-added concept a reference count of zero and float it to
        // the top of the concepts keyness list, silently, forever.
        guard let lexiconsDigest = WordCloudPayloadDigest.digest(
                  ofFileAt: URL(fileURLWithPath: lexiconsPath)),
              let stopwordsDigest = WordCloudPayloadDigest.digest(
                  ofFileAt: URL(fileURLWithPath: stopwordsPath))
        else { throw RunError.undigestiblePayloads(lexiconsPath, stopwordsPath) }
        let configuration = KeynessBaselineFile.Configuration(
            tuning: tuning, includeDiplomatic: includeDiplomatic,
            lexiconsDigest: lexiconsDigest, stopwordsDigest: stopwordsDigest)

        guard let tokenizer = WordCloudMultiLensTokenizer(
            // `.allTerms` and `.descriptors` join the four bundled cloud lenses because the keyness
            // baseline needs them and the cloud does not. `WordCloudView` offers every
            // `WordCloudLens.allCases`, and DEFAULTS to `.allTerms`; a baseline without it could
            // not price the lens a researcher sees first, and one without `.descriptors` would make
            // keyness silently unavailable on a lens the picker offers. Both cost nothing extra —
            // `WordCloudMultiLensTokenizer` counts every lens in ONE NLTagger pass — and the cloud
            // artifacts ignore them, since a fifth and sixth list are not something the cloud draws.
            //
            // The three ENTITY lenses (people/places/organizations) remain unpriced: the multi-lens
            // tokenizer refuses them outright, so their gap is structural rather than an omission.
            lenses: Self.baselineLenses,
            tuning: tuning,
            stopwords: stopwords,
            lexicons: lexicons,
            markings: markings
        ) else { throw RunError.tokenizerConfiguration }

        // VERIFY_PRINTED_WALK=1 (#1608): the same lenses and sets, told to count as printed, so
        // they ask for a tagger with no lemma scheme — the walk a launch with no lemmatiser makes.
        // Two walks, because a device builds two taggers when it counts as printed: one that also
        // holds the lexical classes, for a part-of-speech lens, and one that holds the token type
        // alone, for All terms (Collocates, Related Documents' shared words, the default cloud),
        // Concepts and Sentiment. The first walk counts all six lenses with the first tagger; the
        // second counts the three that read no lexical class with the second. It roughly doubles
        // the tagging; the artifacts are the same bytes with it on or off.
        let printedWalks: [WordCloudMultiLensTokenizer]
        if env["VERIFY_PRINTED_WALK"] == "1" {
            printedWalks = try Self.printedVerificationWalks(
                tuning: tuning, stopwords: stopwords, lexicons: lexicons, markings: markings)
            generatorLog("VERIFY_PRINTED_WALK: every document is also walked with no lemma scheme, "
                         + "by a tagger that holds the lexical classes and by one that does not")
        } else {
            printedWalks = []
        }

        let files = try VolumeCorpusEnumerator.volumeFiles(in: volumesDir)
        generatorLog("corpus: \(files.count) volume files in \(volumesDir.path)")

        // Only manifest volumes ship, so only they are tokenised — the corpus directory
        // carries 694 files against the manifest's 552.
        let shippable = files.filter { manifest[VolumeCorpusEnumerator.volumeId(for: $0)] != nil }
        generatorLog("tokenising \(shippable.count) volumes present in the manifest")

        var volumeCounts: [CloudVectorsAggregator.VolumeCounts] = []
        // Only the corpus total of the printed tally is kept: the reference is corpus-wide, and
        // the cloud files draw dictionary forms.
        var printedCorpus: [WordCloudLens: [String: Int]] = [:]
        var verifiedDocuments = 0
        var emptyVolumes: [String] = []
        for (n, file) in shippable.enumerated() {
            let volumeId = VolumeCorpusEnumerator.volumeId(for: file)
            guard let subseries = manifest[volumeId] else { continue }
            let xml = try String(contentsOf: file, encoding: .utf8)
            let documents = TEIBodyTextExtractor.documents(in: xml)

            var counts: [WordCloudLens: [String: Int]] = [:]
            var printed: [WordCloudLens: [String: Int]] = [:]
            for document in documents {
                // A pool for each document: the tagger hands back autoreleased objects, and a
                // command-line tool has no run loop to drain them (#1608, "Memory" above).
                autoreleasepool {
                    tokenizer.accumulate(from: document.bodyText, into: &counts, printedInto: &printed)
                }
            }
            for printedWalk in printedWalks {
                var direct: [WordCloudLens: [String: Int]] = [:]
                for document in documents {
                    autoreleasepool {
                        printedWalk.accumulate(from: document.bodyText, into: &direct)
                    }
                }
                // Each walk is held to the lemma pass's tally for the lenses it counts.
                let walked = Set(printedWalk.lenses)
                if let divergence = printedWalkDivergence(
                    onePass: printed.filter { walked.contains($0.key) }, direct: direct) {
                    throw RunError.printedWalkDiverged(volume: volumeId, detail: divergence)
                }
            }
            if !printedWalks.isEmpty { verifiedDocuments += documents.count }
            add(printed, to: &printedCorpus)
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

        if !printedWalks.isEmpty {
            generatorLog("VERIFY_PRINTED_WALK: in all \(volumeCounts.count) volumes "
                         + "(\(verifiedDocuments) documents) the printed forms counted in the lemma pass "
                         + "are what a walk with no lemma scheme counts, in every lens, with the "
                         + "lexical-class scheme held and without it")
        }

        let output = CloudVectorsAggregator(lexicons: lexicons)
            .pack(volumes: volumeCounts, generated: generated, tuning: tuning,
                  configuration: configuration, printedCorpus: printedCorpus)
        // Before the first write, so a run that would ship a printed reference without a lens
        // leaves the four files as they were.
        try requireCompletePrintedReference(output)

        try write(output.core, to: outputDir.appendingPathComponent("cloud-vectors-core.json"))
        try write(output.volumes, to: outputDir.appendingPathComponent("cloud-vectors-volumes.json"))
        for baseline in [output.keynessBaseline, output.printedKeynessBaseline] {
            let name = KeynessBaselineFile.resourceName(for: baseline.configuration.wordForm)
            try writeBaseline(baseline, to: outputDir.appendingPathComponent(name + ".json"))
        }
    }

    // MARK: - The printed tally (#1608)

    /// The tokenizers `VERIFY_PRINTED_WALK` walks every document with (#1608): each counts as
    /// printed, and between them they build the two taggers a device builds when it does.
    ///
    /// The first counts every baseline lens. A part-of-speech lens is among them, so its tagger
    /// holds the token type and the lexical classes, which is the tagger a device builds for Topics,
    /// Actions or Descriptors. The second counts the lenses that read no lexical class, so its
    /// tagger holds the token type alone: the one a device builds for All terms, Concepts or
    /// Sentiment. Until the #1608 review the run made the first walk only, and All terms — the lens
    /// Collocates and Related Documents count in — was held to the device's own tagger on the
    /// kit's two fixture paragraphs and nowhere else.
    ///
    /// - Returns: The two tokenizers, the one over every lens first.
    /// - Throws: ``RunError/tokenizerConfiguration`` when either cannot be built, or when the
    ///   baseline lenses hold no lens of one kind and one of the two taggers would go unwalked.
    static func printedVerificationWalks(
        tuning: WordCloudTuning, stopwords: Set<String>, lexicons: WordCloudLexiconSet,
        markings: Set<String>
    ) throws -> [WordCloudMultiLensTokenizer] {
        let withoutLexicalClass = baselineLenses.filter {
            !WordCloudMultiLensTokenizer.readsLexicalClass($0)
        }
        guard withoutLexicalClass.count < baselineLenses.count,
              let everyLens = WordCloudMultiLensTokenizer(
                lenses: baselineLenses, tuning: tuning, stopwords: stopwords,
                lexicons: lexicons, markings: markings, wordForm: .printed),
              let plainLenses = WordCloudMultiLensTokenizer(
                lenses: withoutLexicalClass, tuning: tuning, stopwords: stopwords,
                lexicons: lexicons, markings: markings, wordForm: .printed)
        else { throw RunError.tokenizerConfiguration }
        return [everyLens, plainLenses]
    }

    /// Adds one volume's printed tally to the corpus's.
    /// - Parameters:
    ///   - volume: Lens → term → occurrences in one volume, counted as printed.
    ///   - corpus: The running corpus tally, mutated in place.
    static func add(_ volume: [WordCloudLens: [String: Int]],
                    to corpus: inout [WordCloudLens: [String: Int]]) {
        for (lens, terms) in volume {
            for (term, count) in terms {
                corpus[lens, default: [:]][term, default: 0] += count
            }
        }
    }

    /// Where one volume's printed tally from the lemma pass and its tally from a walk with no lemma
    /// scheme differ, or `nil` when they are the same count (`VERIFY_PRINTED_WALK`).
    ///
    /// - Parameters:
    ///   - onePass: The printed tally `accumulate(from:into:printedInto:)` made.
    ///   - direct: The tally a `.printed` tokenizer made over the same documents.
    /// - Returns: Each differing lens with how many terms differ and the first five, or `nil`.
    static func printedWalkDivergence(onePass: [WordCloudLens: [String: Int]],
                                      direct: [WordCloudLens: [String: Int]]) -> String? {
        guard onePass != direct else { return nil }
        var parts: [String] = []
        for lens in Set(onePass.keys).union(direct.keys).sorted(by: { $0.rawValue < $1.rawValue }) {
            let first = onePass[lens] ?? [:]
            let second = direct[lens] ?? [:]
            let differing = Set(first.keys).union(second.keys).filter { first[$0] != second[$0] }.sorted()
            guard !differing.isEmpty else { continue }
            let examples = differing.prefix(5)
                .map { "\($0) \(first[$0] ?? 0)/\(second[$0] ?? 0)" }
                .joined(separator: ", ")
            parts.append("\(lens.rawValue): \(differing.count) term(s), lemma pass/direct walk — \(examples)")
        }
        return parts.joined(separator: "; ")
    }

    /// Refuses a run whose printed reference lacks a lens the dictionary one prices.
    ///
    /// The two are counted in one pass over the same words, so a lens with tokens in one and none
    /// in the other means the printed tally never reached `pack` — and the app would tell every
    /// scope counted as printed that the lens has no reference. Every lens the dictionary reference
    /// holds has tokens: `pack` makes a lens only from a word it counted.
    /// - Parameter output: The packed artifacts, before anything is written.
    /// - Throws: ``RunError/printedReferenceIncomplete(_:)`` naming the lenses.
    static func requireCompletePrintedReference(_ output: CloudVectorsAggregator.Output) throws {
        let missing = output.keynessBaseline.lenses.keys
            .filter { (output.printedKeynessBaseline.lenses[$0]?.totalTokens ?? 0) == 0 }
            .sorted()
        guard missing.isEmpty else { throw RunError.printedReferenceIncomplete(missing) }
    }

    // MARK: - IO

    /// Writes the keyness baseline, with the same determinism guarantees as the cloud files.
    ///
    /// The per-lens line it logs is the acceptance number: `retained of distinct` states how much
    /// of the corpus vocabulary the artifact prices, and `tokens` is the denominator every
    /// reference frequency divides by. A `totalTokens` close to the sum of the retained counts
    /// would mean the total was taken from the truncated head rather than the whole lens.
    private static func writeBaseline(_ file: KeynessBaselineFile, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(file)
        try data.write(to: url)
        // The dictionary-form lines read as they always have; the printed file's say which it is.
        let label = file.configuration.wordForm == .printed ? "keyness baseline (printed)" : "keyness baseline"
        for (lens, values) in file.lenses.sorted(by: { $0.key < $1.key }) {
            let priced = values.totalTokens == 0 ? 0
                : Double(values.terms.values.reduce(0, +)) / Double(values.totalTokens)
            generatorLog(String(
                format: "%@ %@: %d of %d terms (cut at count %d), %d tokens, %.2f%% of token mass priced",
                label, lens, values.terms.count, values.distinctTerms, values.cutoffCount,
                values.totalTokens, priced * 100))
        }
        generatorLog("\(label) pinned to lexicons \(file.configuration.lexiconsDigest.prefix(12))… "
                     + "stopwords \(file.configuration.stopwordsDigest.prefix(12))…; "
                     + "\(data.count) bytes in \(url.lastPathComponent)")
    }

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

    /// Refuses the run unless the tagger lemmatises and classifies words in this process.
    ///
    /// Every lens this run counts reads the lemmatiser, and Topics, Actions and Descriptors read
    /// the lexical classes; names are not required, since the run refuses the entity lenses.
    /// A separate function so a test can hand it a failed verdict — this process's own is set once
    /// and cannot be made to fail on demand.
    ///
    /// - Parameter health: The tagger verdict to check, `NaturalLanguageReadiness.health` in a run.
    /// - Throws: ``RunError/languageAnalysisUnavailable(_:)`` when either is missing.
    public static func requireLanguageAnalysis(_ health: NaturalLanguageHealth) throws {
        guard health.lemmatizes, health.classifiesWords else {
            throw RunError.languageAnalysisUnavailable(health)
        }
    }

    /// Failures that should stop the run rather than produce a plausible-looking artifact.
    public enum RunError: Error, CustomStringConvertible {
        case emptyStopwords(String)
        case emptyLexicons(String)
        case tokenizerConfiguration
        case undigestiblePayloads(String, String)
        /// The tagger canary failed in this process (#1373).
        case languageAnalysisUnavailable(NaturalLanguageHealth)
        /// `VERIFY_PRINTED_WALK` found a volume whose printed forms, counted in the lemma pass, are
        /// not what a walk with no lemma scheme counts (#1608).
        case printedWalkDiverged(volume: String, detail: String)
        /// The printed reference has no tokens for a lens the dictionary reference prices (#1608).
        case printedReferenceIncomplete([String])

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
            case .undigestiblePayloads(let lexicons, let stopwords):
                return "Could not digest \(lexicons) or \(stopwords). The keyness baseline pins "
                     + "itself to these payloads; writing it unpinned would let a later lexicon "
                     + "edit corrupt every keyness ranking with nothing to detect it."
            case .languageAnalysisUnavailable(let health):
                return "NLTagger failed its canary in this process (lemmas: \(health.lemmatizes), "
                     + "lexical classes: \(health.classifiesWords)). Counting the corpus now would "
                     + "write a keyness reference of printed forms, or empty part-of-speech lenses; "
                     + "refusing to write an artifact. Re-run in a new process."
            case .printedWalkDiverged(let volume, let detail):
                return "VERIFY_PRINTED_WALK: in \(volume) the printed forms counted in the lemma pass "
                     + "are not what a walk with no lemma scheme counts (\(detail)). The reference "
                     + "counted as printed is written from the first, and a launch with no lemmatiser "
                     + "counts the second, so the two would not be comparable; refusing to write an "
                     + "artifact."
            case .printedReferenceIncomplete(let lenses):
                return "The reference counted as printed has no tokens for "
                     + "\(lenses.joined(separator: ", ")), which the dictionary-form reference "
                     + "prices. The printed tally did not reach the packer; refusing to write an "
                     + "artifact."
            }
        }
    }
}
