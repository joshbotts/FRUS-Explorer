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

import CollectionAuthorityGeneratorCore
import CrossRefKit
import CrossRefValidationGeneratorCore
import Foundation
import GeneratorKit
import SourceExplorerExportGeneratorCore
import SourceNoteKit

/// The two measurements #831 gates its own scope on — run BEFORE any surface exists.
///
/// #831 asks for two things and makes the second conditional on the first: key the flow pairs by
/// coverage band, and measure the collection→class density, "build a surface for it only if the
/// numbers clear the bar #764 set". This runs the same two passes
/// `ProvenanceFlowIndexRunner.build` runs — the same extractor, parser, authority lookup and
/// classification — and reports the numbers instead of writing an artifact, so the decision is
/// made on measurement rather than on expectation.
///
/// ## The bar, from #764
/// The class→class axis shipped as a measurement rather than a feature because it scored
/// 1.7 references per pair, a largest single cell of 31, and a top-100 concentration of 18.6%
/// against the collection axis's 42.5%. Those are the comparanda printed below.
public enum ProvenanceFlowMeasurement {

    /// The five era bands the archival surfaces use, as (firstYear, lastYear, title).
    ///
    /// Mirrored from `ArchivalEraBand.all` + `CollectionRelations.coverageEras`, which live in the
    /// app target and cannot be imported here. Mirrored deliberately and narrowly: a measurement
    /// that invented its own boundaries would answer a different question from the chip it is
    /// deciding. If the app's bands ever move, this table is wrong and the numbers below expire.
    static let bands: [(first: Int, last: Int, title: String)] = [
        (1861, 1947, "Through 1947"),
        (1948, 1960, "1948–1960"),
        (1961, 1968, "1961–1968"),
        (1969, 1976, "1969–1976"),
        (1977, 1992, "1977–1992"),
    ]

    static func band(forMidpoint year: Int) -> Int {
        for (i, b) in bands.enumerated() where year <= b.last { return i }
        return bands.count - 1
    }

    /// Volume → coverage-midpoint band, by the same `(earliest + latest) / 2` rule
    /// `CollectionRelations.midpointYear` uses.
    static func bandByVolume(manifestPath: String) throws -> [String: Int] {
        struct Entry: Decodable {
            let volumeId: String
            struct Range: Decodable { let earliest: String?; let latest: String? }
            let dateRange: Range?
        }
        let entries = try JSONDecoder().decode(
            [Entry].self, from: Data(contentsOf: URL(fileURLWithPath: manifestPath)))
        var out: [String: Int] = [:]
        for e in entries {
            let first = year(in: e.dateRange?.earliest)
            let last = year(in: e.dateRange?.latest)
            guard let a = first ?? last, let b = last ?? first else { continue }
            out[e.volumeId] = band(forMidpoint: (min(a, b) + max(a, b)) / 2)
        }
        return out
    }

    private static func year(in iso: String?) -> Int? {
        guard let iso, iso.count >= 4 else { return nil }
        return Int(iso.prefix(4))
    }

    struct Pair: Hashable { let from: String; let to: String }

    public static func run() throws {
        let env = ProcessInfo.processInfo.environment
        let volumesDir = URL(fileURLWithPath:
            env["VOLUMES_DIR"] ?? "/Users/jbotts/Development/frus/volumes")
        let manifestPath = env["MANIFEST"] ?? "FRUSExplorer/Resources/manifest.json"
        let authorityPath = env["COLLECTION_AUTHORITY"]
            ?? "FRUSExplorer/Resources/collection-authority.json"

        let shippable = try ProvenanceFlowIndexRunner.shippableVolumeIds(manifestPath: manifestPath)
        let bandOf = try bandByVolume(manifestPath: manifestPath)
        let authority = try AuthorityLookup(indexURL: URL(fileURLWithPath: authorityPath))
        let files = try VolumeCorpusEnumerator.volumeFiles(in: volumesDir)
            .filter { shippable.contains(VolumeCorpusEnumerator.volumeId(for: $0)) }
        generatorLog("[Measure] \(files.count) shippable volumes; "
                     + "\(bandOf.count) with a coverage band")

        let parser = SourceNoteParser()
        var collectionOf: [String: String] = [:]
        var classOf: [String: String] = [:]
        var documentIds: [String: Set<String>] = [:]
        for file in files {
            let data = try Data(contentsOf: file)
            let volumeId = VolumeCorpusEnumerator.volumeId(for: file)
            documentIds[volumeId] = DocumentIdInventory.documentIds(in: data)
            for note in DocumentNoteExtractor.extract(fromXML: data) where !note.documentId.isEmpty {
                let key = "\(volumeId)/\(note.documentId)"
                let parsed = parser.parse(note.note)
                if let record = authority.record(forParsed: parsed, note: note.note) {
                    collectionOf[key] = record.id
                }
                if let cls = ExportClassification
                    .derivedKeys(for: parsed, note: note.note).decimalClass {
                    classOf[key] = cls
                }
            }
        }
        generatorLog("[Measure] pass 1 done: \(collectionOf.count) collection-keyed, "
                     + "\(classOf.count) class-keyed documents")

        // Quadrant counts over every document-to-document edge, plus banded pair tables.
        var q = (bothCollection: 0, bothClass: 0, mixedCtoK: 0, mixedKtoC: 0, neither: 0)
        var collectionFlows: [Pair: Int] = [:]
        var mixedFlows: [Pair: Int] = [:]
        var mixedDirection: [Pair: String] = [:]
        var mixedExemplar: [Pair: String] = [:]
        var bandedCollection: [Int: [Pair: Int]] = [:]
        var bandedClass: [Int: [Pair: Int]] = [:]
        var edgesWithoutBand = 0

        for file in files {
            let data = try Data(contentsOf: file)
            let sourceVolume = VolumeCorpusEnumerator.volumeId(for: file)
            for ref in RefHarvester.harvest(from: data) {
                guard let sourceDocument = ref.enclosingDocument else { continue }
                guard case .document(let volumeOverride, let targetDocument) =
                        CrossRefGrammar.resolveDestination(ref.rawTarget, volumeId: sourceVolume)
                else { continue }
                let targetVolume = volumeOverride ?? sourceVolume
                guard documentIds[targetVolume]?.contains(targetDocument) == true else { continue }

                let sourceKey = "\(sourceVolume)/\(sourceDocument)"
                let targetKey = "\(targetVolume)/\(targetDocument)"
                let fc = collectionOf[sourceKey], tc = collectionOf[targetKey]
                let fk = classOf[sourceKey], tk = classOf[targetKey]

                if let fc, let tc {
                    q.bothCollection += 1
                    collectionFlows[Pair(from: fc, to: tc), default: 0] += 1
                }
                if let fk, let tk { q.bothClass += 1 }
                // A MIXED edge: one end keyed to a collection, the other to a class, and NOT
                // representable on either single-axis table — #831's "invisible" case.
                if let fc, let tk, tc == nil {
                    q.mixedCtoK += 1
                    let pair = Pair(from: fc, to: tk)
                    mixedFlows[pair, default: 0] += 1
                    mixedDirection[pair] = "collection→class"
                    if mixedExemplar[pair] == nil {
                        mixedExemplar[pair] = "\(sourceKey) → \(targetKey)"
                    }
                }
                if let fk, let tc, fc == nil {
                    q.mixedKtoC += 1
                    let pair = Pair(from: fk, to: tc)
                    mixedFlows[pair, default: 0] += 1
                    mixedDirection[pair] = "class→collection"
                    if mixedExemplar[pair] == nil {
                        mixedExemplar[pair] = "\(sourceKey) → \(targetKey)"
                    }
                }
                if fc == nil && tc == nil && fk == nil && tk == nil { q.neither += 1 }

                // Banding keys on the SOURCE volume's coverage band — the chip narrows "flows
                // out of documents published in this period".
                guard let band = bandOf[sourceVolume] else { edgesWithoutBand += 1; continue }
                if let fc, let tc {
                    bandedCollection[band, default: [:]][Pair(from: fc, to: tc), default: 0] += 1
                }
                if let fk, let tk {
                    bandedClass[band, default: [:]][Pair(from: fk, to: tk), default: 0] += 1
                }
            }
        }

        report(q: q, collectionFlows: collectionFlows, mixedFlows: mixedFlows,
               bandedCollection: bandedCollection, bandedClass: bandedClass,
               edgesWithoutBand: edgesWithoutBand)

        // The decisive question for the mixed axis: is its largest cell one fact or a family?
        var names: [String: String] = [:]
        for c in authority.collections { names[c.id] = c.name }
        func label(_ key: String) -> String { names[key] ?? key }
        var lines = ["", "── C. The mixed axis's largest cells ──"]
        for (pair, n) in mixedFlows.sorted(by: { $0.value > $1.value }).prefix(12) {
            lines.append(String(format: "  %5d  [%@]", n, mixedDirection[pair] ?? "?"))
            lines.append("         from: \(label(pair.from))")
            lines.append("         to:   \(label(pair.to))")
            lines.append("         e.g.  \(mixedExemplar[pair] ?? "-")")
        }
        let total = mixedFlows.values.reduce(0, +)
        let topOne = mixedFlows.values.max() ?? 0
        lines.append(String(format: "  largest cell is %.1f%% of the mixed axis; "
                            + "top 5 are %.1f%%", Double(topOne) / Double(total) * 100,
                            Double(mixedFlows.values.sorted(by: >).prefix(5).reduce(0, +))
                                / Double(total) * 100))
        generatorLog(lines.joined(separator: "\n"))
    }

    private static func concentration(_ flows: [Pair: Int], top: Int) -> Double {
        let total = flows.values.reduce(0, +)
        guard total > 0 else { return 0 }
        let head = flows.values.sorted(by: >).prefix(top).reduce(0, +)
        return Double(head) / Double(total) * 100
    }

    private static func summarize(_ label: String, _ flows: [Pair: Int]) -> String {
        let refs = flows.values.reduce(0, +)
        let cross = flows.filter { $0.key.from != $0.key.to }
        let crossRefs = cross.values.reduce(0, +)
        let perPair = cross.isEmpty ? 0 : Double(crossRefs) / Double(cross.count)
        return String(
            format: "%@: %d refs over %d pairs (%d between units over %d pairs, %.1f/pair); "
                + "largest cell %d; top-100 %.1f%%",
            label, refs, flows.count, crossRefs, cross.count, perPair,
            cross.values.max() ?? 0, concentration(cross, top: 100))
    }

    private static func report(
        q: (bothCollection: Int, bothClass: Int, mixedCtoK: Int, mixedKtoC: Int, neither: Int),
        collectionFlows: [Pair: Int], mixedFlows: [Pair: Int],
        bandedCollection: [Int: [Pair: Int]], bandedClass: [Int: [Pair: Int]],
        edgesWithoutBand: Int
    ) {
        var out = ["", "════════ #831 MEASUREMENT ════════", "",
                   "── A. Mixed (collection→class) density ──",
                   "  both ends collection: \(q.bothCollection)",
                   "  both ends class:      \(q.bothClass)",
                   "  MIXED collection→class: \(q.mixedCtoK)",
                   "  MIXED class→collection: \(q.mixedKtoC)",
                   "  neither end keyed:    \(q.neither)",
                   "  " + summarize("mixed axis", mixedFlows),
                   "  " + summarize("collection axis (comparand)", collectionFlows),
                   "", "── B. Banded pairs (source volume's coverage band) ──"]
        for (i, b) in bands.enumerated() {
            let c = bandedCollection[i] ?? [:]
            let k = bandedClass[i] ?? [:]
            out.append("  [\(b.title)]")
            out.append("     " + summarize("collections", c))
            out.append("     " + summarize("classes    ", k))
        }
        out.append("  edges whose source volume had no coverage band: \(edgesWithoutBand)")
        out.append("")
        generatorLog(out.joined(separator: "\n"))
    }
}
