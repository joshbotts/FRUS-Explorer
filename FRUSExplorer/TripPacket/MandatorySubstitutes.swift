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

// MARK: - SubstituteRoute

/// Which of NARA's two published substitute forms a row names (#830 T-3, advisory A6).
///
/// Kept as an explicit axis rather than inferred from the row's shape, because the two carry
/// different citation obligations: NARA's *Citing Foreign Affairs Records* asks a microfilm
/// citation to name its **publication number** (`M862`), and an online one to carry "the elements
/// noted above, not just the URL".
enum SubstituteRoute: String, Sendable, Equatable, CaseIterable {
    /// NARA's scans of a decimal-file serial range.
    case digitizedRange
    /// A roll of Microfilm Publication M862, the 1906–1910 Numerical File.
    case microfilmRoll

    /// How the packet names this route in prose.
    var label: String {
        switch self {
        case .digitizedRange: return "Digitised file range"
        case .microfilmRoll:  return "Microfilm Publication M862"
        }
    }
}

// MARK: - MandatorySubstitutes

/// Records the reader must consult online or on microfilm **instead of** pulling the originals
/// (#830 T-3, chapter 4, advisory A6).
///
/// ## Why this is a chapter and not a convenience list
/// NARA's research-visit FAQ states the rule as an obligation — *"Researchers must use microfilm
/// and online resources when those options are available."* A pull slip written for a record that
/// has been filmed is a slip the reading room will decline, so this is scheduling information, not
/// a shortcut. That is why A6 asks for these to lead rather than to appear as an appendix.
///
/// ## What it reaches, and why the chapter must say so out loud
/// Two routes exist in the bundled data, and between them they are **narrow**:
///
/// | route | reach |
/// |---|---|
/// | digitised decimal ranges | 5,326 of 185,694 decimal citations — **2.9%** |
/// | M862 rolls (1906–1910 Numerical File) | the pre-decimal era only |
///
/// The digitised half is concentrated almost entirely in `763.72`, the European War 1914–18 file:
/// in practice *the WWI supplements get their microfilm*. The classes FRUS cites most have zero
/// digitised units, because NARA's RG 59 digitisation followed the microfilm publications.
///
/// So an empty chapter means **"the app found none by the two routes it can see"**, never "nothing
/// is digitised", and ``coverageNote`` is what says so. A silent empty section would be read as a
/// clearance to pull everything, which is precisely the error A6 exists to prevent.
///
/// ## Three rules that are load-bearing
/// 1. **A multi-range match is never collapsed to its first row.** `DigitizedRangeMatch` returns
///    `.multipleRanges` narrowest-first and claims nothing about which is *the* one — NARA's
///    digitisation is layered, and one file unit (`763.72/354-13348A`) spans 12,994 serials and
///    overlaps every narrow roll in its class. Each claimant gets a row and is marked
///    ``Row/isSoleClaimant`` `false`, because picking the narrowest would send a reader into a
///    scan that may not hold their document.
/// 2. **"The class is digitised but not this serial" is counted, not tabled.** It is genuinely
///    informative — it is not "no scans" — but it is not a *substitute*, because the reader still
///    has to pull. It belongs in the coverage sentence, not in a list headed "use these instead".
/// 3. **The link is the Catalog record, never the raw object.** NARA's own worked example cites
///    `Online at https://catalog.archives.gov/id/177380725`; the artifacts' `objectUrl` values are
///    a `.tif` for a range and a whole-roll `.pdf`, neither of which is a usable citation target in
///    a printed packet.
///
/// ## Why these URLs carry no `verifiedDate`, and D12 is not being dodged
/// D12 stamps the links in ``RepositoryFactTable`` because they are *guidance pages* — prose that
/// can be reorganised, rewritten, or quietly stop saying what the packet claims about it, which a
/// status code cannot detect. A `catalog.archives.gov/id/<naId>` URL is not that: it is a record
/// **identifier** rendered as a link, the app already emits it from `NARACatalogClient` and from
/// each roll's own `catalogURL`, and NARA's citation guidance prints this exact form. Stamping an
/// identifier would imply a freshness claim about a permalink and would put a date on 624 rows that
/// no one could ever re-check.
///
/// Version history:
///   1.0 — Session 2026-08-22: #830 T-3, chapter 4
struct MandatorySubstitutes: Equatable, Sendable {

    /// One scan or roll the reader must use in place of a pull.
    struct Row: Equatable, Sendable, Identifiable {
        /// The NARA NAID of the digitised unit.
        let naId: String
        /// The unit's title, as NARA states it.
        let title: String
        /// Which substitute form this is.
        let route: SubstituteRoute
        /// How many images NARA reports for the unit; `0` when it reports none.
        let objectCount: Int
        /// How many of the reader's documents land in this unit.
        let documentCount: Int
        /// `false` when at least one document reached this unit alongside other claimants.
        ///
        /// The distinction is the reader's, not the catalogue's: a sole claimant can be walked to
        /// directly, an ambiguous one has to be checked against its neighbours first.
        let isSoleClaimant: Bool

        var id: String { naId }

        /// The Catalog record — the form NARA's own citation guidance prints.
        var catalogURL: URL? { URL(string: "https://catalog.archives.gov/id/\(naId)") }
    }

    /// Units to use instead of pulling, most of the reader's documents first.
    let rows: [Row]

    /// Documents whose source note named a file identifier, so a substitute could be looked up.
    ///
    /// The denominator. Reported rather than assumed equal to the packet's document count, because
    /// a note that named no file was never tested and must not read as a tested miss.
    let documentsTested: Int

    /// Documents that landed in at least one substitute.
    let documentsWithSubstitute: Int

    /// Documents whose decimal class has digitised ranges, none of which covers their serial.
    ///
    /// Counted and stated, never tabled — see the type's rule 2.
    let partiallyDigitizedCount: Int

    /// Whether there is any substitute to print.
    var isEmpty: Bool { rows.isEmpty }

    /// The sentence the chapter owes the reader about its own reach.
    ///
    /// Exists on the model rather than in the exporter so that the numbers and the caveat cannot
    /// drift apart: any surface that prints ``rows`` can print this beside them.
    var coverageNote: String {
        guard documentsTested > 0 else {
            return "None of these documents cites a file number the app can test for a digitized "
                + "substitute, so this chapter can say nothing either way. Ask staff whether any "
                + "of the records you have listed have been filmed or scanned."
        }
        var sentence = "Checked \(documentsTested) "
            + (documentsTested == 1 ? "document" : "documents")
            + " that cite a file number; \(documentsWithSubstitute) "
            + (documentsWithSubstitute == 1 ? "lands" : "land")
            + " in a digitized range or a filmed roll."
        if partiallyDigitizedCount > 0 {
            sentence += " A further \(partiallyDigitizedCount) "
                + (partiallyDigitizedCount == 1 ? "cites a file that is" : "cite files that are")
                + " partly digitized, but not the part they name."
        }
        sentence += " The app sees two routes only — NARA's scans of decimal-file ranges, and the "
            + "M862 rolls of the 1906–1910 Numerical File — so silence here is not evidence that "
            + "a record has not been filmed. Confirm with staff."
        return sentence
    }

    /// One document's cited file number and the year it was written.
    ///
    /// The year is not decoration — see ``build(citedFiles:ranges:rolls:numericalFile:)`` for why
    /// the two routes cannot be told apart without it.
    struct CitedFile: Equatable, Sendable {
        /// The central-file number the source note names, or `nil` when it names none.
        let identifier: String?
        /// The document's year, where the index knows it.
        let year: Int?

        /// Memberwise, spelled out so call sites read as pairs rather than as positional tuples.
        init(identifier: String?, year: Int?) {
            self.identifier = identifier
            self.year = year
        }
    }

    /// Builds the chapter from the file numbers a reading list cites.
    ///
    /// - Parameters:
    ///   - citedFiles: one entry per document, carrying `nil` where the source note named no file.
    ///     Passing the nils is what keeps ``documentsTested`` honest.
    ///   - ranges: the digitised decimal-range index; injected so tests drive the real rule.
    ///   - rolls: the M862 roll-scan index, for the image counts.
    ///   - numericalFile: the 1906–1910 case-number → roll lookup.
    ///
    /// ## Routing takes BOTH the year and the number's form, because each alone is wrong
    /// Measured against real corpus notes (`source-explorer-export-sample.json`), neither signal
    /// separates the two routes on its own, and each fails in a different direction:
    ///
    /// - **Form alone fails silently-but-confidently.** Decimal classes are not all dotted — the
    ///   shipped range index's first row is class `131` — so a real decimal citation reads
    ///   `131/423`, which `isDecimalFileForm` rejects (it stops at the first `/` before seeing a
    ///   dot) and `caseNumber(fromFileNumber:)` therefore parses as **case 131**. A 1930s decimal
    ///   citation would be handed a 1906–1910 microfilm roll: film that cannot hold the document.
    /// - **Year alone drops the transition.** The Numerical File ran to 1910 and the decimal system
    ///   began in it, so **1910 carries both forms**. The sample holds `File No. 811.304M28/45`
    ///   dated 1910 — a dotted decimal citation inside the numerical-file band. A pure year gate
    ///   sends it to the rolls, `caseNumber` returns `nil` for decimal form, and the citation
    ///   reaches neither route.
    ///
    /// So the roll route requires **a known year in 1906–1910 _and_ a non-decimal number**, and
    /// everything else — later years, unknown years, and dotted numbers inside the band — takes the
    /// decimal-range route. Both real spellings in the transition year then land correctly:
    /// `6775/57` (1907) on the rolls, `811.304M28/45` (1910) in the ranges.
    static func build(
        citedFiles: [CitedFile],
        ranges: DigitizedRangeIndex? = DigitizedRangeIndexStore.shared,
        rolls: RollScansIndex? = RollScansIndexStore.shared,
        numericalFile: NumericalFileIndex? = CentralFilesIndexStore.shared?.numericalFile
    ) -> MandatorySubstitutes {
        var counts: [String: Int] = [:]
        var meta: [String: (title: String, route: SubstituteRoute, objects: Int)] = [:]
        var ambiguous: Set<String> = []
        var tested = 0
        var withSubstitute = 0
        var partial = 0

        for file in citedFiles {
            guard let identifier = file.identifier else { continue }
            let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            tested += 1

            var hit = false
            let inNumericalFileEra = file.year.map { (1906...1910).contains($0) } ?? false
            let isDecimal = CentralFilesIndex.isDecimalFileForm(trimmed)

            if inNumericalFileEra && !isDecimal {
                // Route 1 — a 1906–1910 case number, against the M862 rolls. A case regularly
                // spills across consecutive rolls, so every roll holding it is named.
                if let numericalFile {
                    let matched = numericalFile.rolls(forFileNumber: trimmed)
                    for roll in matched {
                        counts[roll.naId, default: 0] += 1
                        meta[roll.naId] = (roll.title, .microfilmRoll,
                                           rolls?.scan(forNaId: roll.naId)?.objectCount ?? 0)
                        if matched.count > 1 { ambiguous.insert(roll.naId) }
                    }
                    hit = !matched.isEmpty
                }
            } else if let ranges, let (cls, serial) = DigitizedRangeIndex.classAndSerial(
                fromFileIdentifier: trimmed) {
                // Route 2 — a decimal class and serial, against NARA's digitised ranges.
                switch ranges.match(decimalClass: cls, serial: serial) {
                case .resolved(let range):
                    counts[range.naId, default: 0] += 1
                    meta[range.naId] = (range.title, .digitizedRange, range.objectCount)
                    hit = true
                case .multipleRanges(let claimants):
                    // Every claimant counts. Collapsing to the narrowest would assert a
                    // resolution the catalogue does not make.
                    for range in claimants {
                        counts[range.naId, default: 0] += 1
                        meta[range.naId] = (range.title, .digitizedRange, range.objectCount)
                        ambiguous.insert(range.naId)
                    }
                    hit = !claimants.isEmpty
                case .classDigitizedButSerialNotCovered:
                    partial += 1
                case .none:
                    break
                }
            }

            // Counted per DOCUMENT, not per row: a citation claimed by three overlapping ranges is
            // one document that need not be pulled, not three.
            if hit { withSubstitute += 1 }
        }

        let built = counts.compactMap { naId, count -> Row? in
            guard let info = meta[naId] else { return nil }
            return Row(naId: naId, title: info.title, route: info.route,
                       objectCount: info.objects, documentCount: count,
                       isSoleClaimant: !ambiguous.contains(naId))
        }
        .sorted { lhs, rhs in
            if lhs.documentCount != rhs.documentCount { return lhs.documentCount > rhs.documentCount }
            if lhs.route != rhs.route { return lhs.route == .microfilmRoll }
            return lhs.naId < rhs.naId
        }

        return MandatorySubstitutes(rows: built,
                                    documentsTested: tested,
                                    documentsWithSubstitute: withSubstitute,
                                    partiallyDigitizedCount: partial)
    }
}
