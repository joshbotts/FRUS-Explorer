// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import GeneratorKit
import LotClaimantsIndexGeneratorCore

// MARK: - AccessionSeriesIndexRunner

/// Builds `accession-series-index.json` (#1203): which NARA series a Federal Records Center
/// accession became.
///
/// ## What this answers, and what it does not
/// FRUS front matter names the accession a body of records was retired under — *"now part of
/// Washington National Records Center Accession No. 71 A 6682 (15 ft.)"* — and NARA records the
/// same accession on the series that material became, in `recordsCenterTransferNumbers`. That is
/// a join the lot number cannot make, and nothing bundled projected it.
///
/// It is a **data artifact with no app reader**, by the owner's decision, and the reason is the
/// measurement below rather than effort: the join answers a minority of citations and usually
/// answers them with a long list. The Agentic Analysis Guide documents it for analysts working
/// against the bundled JSON; the app renders nothing, so nothing here needed a TEI parse change,
/// an index-version bump, or a reindex.
///
/// ## Measured, and the issue's premise is weaker than it reads
/// #1203 cites "240,929 occurrences in the RG 59 shard". That is the shard's total RECORD count;
/// the field itself appears on **1,058 records / 1,437 occurrences**, series-level only.
///
/// Demand, counted anchor-first over the corpus (the accession must directly follow *FRC* /
/// *Federal Records Center* / *WNRC* / *Accession*, because a proximity window sweeps in the lot
/// numbers printed beside it and inflates the count several-fold): **995 mentions, 116 distinct
/// accessions, 84 volumes.** Of those, **22 keys resolve in some record group — 150 of 995
/// mentions, 15%**; scoped to RG 59 alone it is 8 keys and 7%. The top-cited accession of all,
/// `53A278` (115 mentions), is **absent from the entire 4.5 GB harvest in any field**, so the
/// ceiling is a property of NARA's catalogue and not of this pass.
///
/// ## The record-group prefix is load-bearing, and dropping it is the trap
/// An accession number is unique only **within** a record group. `68A5612` names **1** series in
/// RG 59 and **18** in RG 84; `71A6682` names 58 in RG 59 and 1 in RG 353. So keys are stored
/// `"<record group>/<accession>"`, never bare: an unscoped map raises coverage from 7% to 15% by
/// answering State citations with Foreign Service Post records, which is not coverage.
///
/// NARA writes the prefix inconsistently — `059-71A6682`, `59-71A-6682`, `71A6682`,
/// `306-72A-5121`, `W084-70-1` — so it is split off and normalised rather than string-matched.
/// A row with no prefix at all inherits the shard's own record group, which is the only reading
/// available and is recorded as such in `prefixInferred`.
///
/// ## Why every claimant is stored
/// #679 refused this join for *lot acceptance* because the keys "average 1.5 claimants and reach
/// 57" — measured here, they reach **58**. That refusal stands and this artifact does not
/// reopen it: it is consulted only when a FRUS citation names an accession outright, and it
/// stores the whole claimant list so a consumer states the division rather than picking from it,
/// the same rule `lot-claimants-index.json` follows.
///
/// Version history:
///   1.0 — Session 2026-09-06: #1203
public enum AccessionSeriesIndexRunner {

    /// The bundled projection.
    public struct Index: Codable, Sendable, Equatable {
        /// Bumped when the row shape changes.
        public var schemaVersion: Int
        /// `yyyy-MM-dd` build stamp.
        public var generated: String
        /// How to read a key, for a consumer who arrives before the guide.
        public var note: String
        /// What a claimant's one-letter keys mean (#1202's convention).
        public var legend: [String: String]
        /// `"<record group>/<accession>"` → every series NARA records under it.
        public var byAccession: [String: [Claimant]]

        /// Creates the index.
        public init(schemaVersion: Int, generated: String, note: String,
                    legend: [String: String], byAccession: [String: [Claimant]]) {
            self.schemaVersion = schemaVersion
            self.generated = generated
            self.note = note
            self.legend = legend
            self.byAccession = byAccession
        }
    }

    /// One series NARA records under an accession.
    ///
    /// Wire keys are one letter, the same trade `series-facts-index.json` makes and for the same
    /// reason: spelling them out costs **351 KB of key names across 7,349 rows**, 39% of the file,
    /// on an artifact no app code reads. `legend` states what each means, so the saving does not
    /// buy a guessing game — that is the #1202 lesson applied rather than re-learned.
    public struct Claimant: Codable, Sendable, Equatable {
        /// NARA unique identifier.
        public var naId: String
        /// The series title as NARA describes it.
        public var title: String
        /// NARA's own spelling of the transfer number, kept verbatim so a reader can see which
        /// variant matched — the punctuation is not consistent and the raw form is the evidence.
        public var asPrinted: String
        /// `true` when the stored string carried no record-group prefix and the shard's own group
        /// was used. **Omitted when false** — it is true on 230 of 7,349 rows, and writing the
        /// key on the other 7,119 cost 132 KB to say "nothing unusual here".
        public var prefixInferred: Bool?

        enum CodingKeys: String, CodingKey {
            case naId = "n"
            case title = "t"
            case asPrinted = "a"
            case prefixInferred = "i"
        }

        /// Creates a claimant.
        public init(naId: String, title: String, asPrinted: String, prefixInferred: Bool?) {
            self.naId = naId
            self.title = title
            self.asPrinted = asPrinted
            self.prefixInferred = prefixInferred
        }
    }

    /// What a claimant's one-letter keys mean.
    public static let legend: [String: String] = [
        "n": "naId — NARA unique identifier for the series",
        "t": "title — the series title as NARA describes it",
        "a": "asPrinted — NARA's own spelling of the transfer number, verbatim",
        "i": "prefixInferred — true when the stored string carried no record-group prefix and the "
           + "shard's own group was used; ABSENT means false",
    ]

    /// Anything that stops the artifact being trustworthy.
    public enum RunError: Error, CustomStringConvertible {
        /// The harvest is absent — this generator has no other source.
        case noHarvest(String)
        /// The pass resolved nothing, which would ship a feature-disabling empty file.
        case empty

        public var description: String {
            switch self {
            case .noHarvest(let path):
                return "no shard directory at \(path). This generator reads ONLY the offline "
                     + "record-group harvest and needs no CATALOG_API_KEY; it cannot run from a "
                     + "clone."
            case .empty:
                return "no accession resolved. An empty index disables the join while the build "
                     + "exits 0, so this throws instead."
            }
        }
    }

    /// Folds a transfer number the way a FRUS citation must be folded to match it.
    ///
    /// Case and punctuation are dropped, exactly as `LotResolutionAcceptance.foldControlNumber`
    /// does for lots, so `71 A 6682`, `71A6682` and `71-A-6682` are one key.
    public static func fold(_ raw: String) -> String {
        raw.uppercased().filter { $0.isLetter || $0.isNumber }
    }

    /// Splits NARA's record-group prefix off a transfer number.
    ///
    /// - Returns: the record group (bare, leading zeros dropped) and the folded accession, or
    ///   `nil` for the group when the string carries no prefix.
    public static func split(_ raw: String) -> (recordGroup: String?, accession: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        // `W084-70-1`: NARA prefixes some groups with a W. It is part of the prefix, not the
        // accession, and leaving it on makes the group unmatchable against a bare "84".
        let body = trimmed.hasPrefix("W") || trimmed.hasPrefix("w")
            ? String(trimmed.dropFirst()) : trimmed
        guard let dash = body.firstIndex(of: "-") else { return (nil, fold(trimmed)) }
        let head = String(body[body.startIndex..<dash])
        guard !head.isEmpty, head.count <= 3, head.allSatisfy(\.isNumber),
              let number = Int(head) else { return (nil, fold(trimmed)) }
        var tail = String(body[body.index(after: dash)...])
        // An ITEM number inside the accession — `059-71A6682-9` — belongs to accession
        // `71A6682`, and FRUS cites the accession, never the item. Stripping it is what makes
        // #1203's own acceptance case work: without it `71A6682` misses NAIDs 26309419 and
        // 27022878, the two series carrying items -9/-29/-31/-33, and `68A5159` (34 citations)
        // resolves to nothing at all.
        //
        // Guarded on the LETTERED accession shape, because the unlettered form is not the same
        // grammar: `059-96-564` is accession `96-564`, and stripping its tail would invent an
        // accession `96` and merge unrelated series under it. Measured: 5 of 7,349 transfer
        // numbers carry an item suffix, over 2 base accessions.
        if let match = tail.range(of: #"^\d{2}\s?A\s?-?\s?\d{3,5}(?=-\d{1,3}$)"#,
                                  options: [.regularExpression, .caseInsensitive]) {
            tail = String(tail[match])
        }
        guard !fold(tail).isEmpty else { return (nil, fold(trimmed)) }
        return (String(number), fold(tail))
    }

    /// Builds the index from the harvest.
    ///
    /// - Parameter environment: Process environment.
    /// - Throws: ``RunError`` when the harvest is absent or the pass resolves nothing.
    public static func run(environment: [String: String] = ProcessInfo.processInfo.environment)
        throws {
        let harvestDir = environment["HARVEST_DIR"]
            ?? "/Users/jbotts/Development/nara-record-group-catalog"
        let output = environment["OUTPUT"]
            ?? "FRUSExplorer/Resources/accession-series-index.json"
        let generated = environment["GENERATED_DATE"] ?? Self.today()

        let shardDir = URL(fileURLWithPath: harvestDir).appending(path: "series")
        guard FileManager.default.fileExists(atPath: shardDir.path) else {
            throw RunError.noHarvest(shardDir.path)
        }
        let shards = try FileManager.default
            .contentsOfDirectory(at: shardDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var byAccession: [String: [Claimant]] = [:]
        var occurrences = 0
        var inferred = 0
        for shard in shards {
            // `rg_59.json` → `59`, the group to fall back on when a row states no prefix.
            let shardGroup = shard.deletingPathExtension().lastPathComponent
                .replacingOccurrences(of: "rg_", with: "")
            let (records, _) = try HarvestShardReader.read(shard)
            var here = 0
            for record in records {
                for raw in record.recordsCenterTransferNumbers {
                    let parts = split(raw)
                    guard !parts.accession.isEmpty else { continue }
                    let group = parts.recordGroup ?? shardGroup
                    if parts.recordGroup == nil { inferred += 1 }
                    occurrences += 1
                    here += 1
                    byAccession["\(group)/\(parts.accession)", default: []].append(
                        Claimant(naId: record.naId,
                                 title: record.title,
                                 asPrinted: raw,
                                 prefixInferred: parts.recordGroup == nil ? true : nil))
                }
            }
            generatorLog("\(shard.lastPathComponent): \(records.count) records, \(here) accessions")
        }
        guard !byAccession.isEmpty else { throw RunError.empty }

        // Sorted by NAID so a rebuild is byte-identical, and deduplicated: a series listing the
        // same accession twice under two spellings is one claimant, not two.
        for (key, claimants) in byAccession {
            var seen: Set<String> = []
            byAccession[key] = claimants
                .sorted { $0.naId == $1.naId ? $0.asPrinted < $1.asPrinted : $0.naId < $1.naId }
                .filter { seen.insert($0.naId).inserted }
        }

        let index = Index(
            schemaVersion: 1,
            generated: generated,
            note: "Keys are `<record group>/<accession>`, the accession folded to letters and "
                + "digits (`71 A 6682` -> `71A6682`). THE RECORD GROUP IS PART OF THE KEY AND "
                + "MUST BE MATCHED: an accession number is unique only within its group — "
                + "`68A5612` names 1 series in RG 59 and 18 in RG 84 — so a lookup that ignores "
                + "it answers a State citation with Foreign Service Post records. Every series "
                + "NARA records under an accession is stored; state the count rather than "
                + "choosing, because a key reaches 58 claimants. `prefixInferred` marks the rows "
                + "where NARA's string carried no prefix and the shard's own group was used.",
            legend: Self.legend,
            byAccession: byAccession)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(index)
        try data.write(to: URL(fileURLWithPath: output))

        let counts = byAccession.values.map(\.count)
        generatorLog("""
            accession-series-index.json written to \(output)
              accession keys:   \(byAccession.count)
              occurrences:      \(occurrences) (\(inferred) with no stated record group)
              max claimants:    \(counts.max() ?? 0)
              single-claimant:  \(counts.filter { $0 == 1 }.count)
              bytes:            \(data.count)
            """)
    }

    /// The reproducible build stamp.
    private static func today() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
}
