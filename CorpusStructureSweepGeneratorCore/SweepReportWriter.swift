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
import GeneratorKit

/// Writes the sweep's three artifacts.
///
/// **Every number the covering text quotes comes from `counts.json`**, written by the same run
/// that wrote the rows. A report whose arithmetic does not reconcile loses its reader before it
/// reaches its findings, and the measurement pass that designed this sweep produced several
/// censuses that did not sum to their own components.
///
/// Version history:
///   1.0 — 2026-09-20: #1309
public enum SweepReportWriter {

    /// The CSV's columns. `hsg_url` is first among the identifying fields on purpose: an OH editor
    /// must be able to see the defect on their own site without opening any of our code.
    static let header = ["volume_id", "element_id", "hsg_url", "file", "line", "byte_offset",
                         "defect_class", "what_is_wrong", "corrected_encoding", "evidence",
                         "adjudication", "confidence"]

    /// Writes `structure-sweep.csv`, `structure-sweep.json` and `counts.json`.
    public static func write(findings: [StructureFinding], to directory: URL, generated: String,
                             corpusCommit: String, filesScanned: Int, divCount: Int,
                             volumesWithContents: Int, candidatesByRule: [String: Int],
                             duplicateIds: Int, duplicateDocumentNumbers: Int) {
        let rows = findings.map { finding in
            [finding.volumeId, finding.elementId, finding.publicURL, "\(finding.volumeId).xml",
             "\(finding.line)", "\(finding.byteOffset)", finding.rule, finding.whatIsWrong,
             finding.correctedEncoding, finding.evidence, finding.adjudication.rawValue,
             finding.confidence.rawValue]
        }
        let csv = CSVWriter.document(header: header, rows: rows)
        try? csv.write(to: directory.appendingPathComponent("structure-sweep.csv"),
                       atomically: true, encoding: .utf8)

        let confirmed = findings.filter { $0.confidence == .confirmed }
        var byAdjudication: [String: Int] = [:]
        for finding in findings {
            byAdjudication[finding.adjudication.rawValue, default: 0] += 1
        }
        let counts: [String: Any] = [
            "generated": generated,
            "corpusCommit": corpusCommit,
            "filesScanned": filesScanned,
            "divsScanned": divCount,
            "volumesWithMachineReadableContents": volumesWithContents,
            "findings": findings.count,
            "volumesAffected": Set(findings.map(\.volumeId)).count,
            "confirmed": confirmed.count,
            "pleaseVerify": findings.count - confirmed.count,
            "candidatesByRule": candidatesByRule,
            "duplicateXmlIds": duplicateIds,
            "duplicateDocumentNumbers": duplicateDocumentNumbers,
            "findingsByAdjudication": byAdjudication,
        ]
        writeJSON(counts, to: directory.appendingPathComponent("counts.json"))

        let detail: [[String: Any]] = findings.map { finding in
            [
                "volumeId": finding.volumeId, "elementId": finding.elementId,
                "url": finding.publicURL, "rule": finding.rule, "line": finding.line,
                "byteOffset": finding.byteOffset, "whatIsWrong": finding.whatIsWrong,
                "correctedEncoding": finding.correctedEncoding, "evidence": finding.evidence,
                "adjudication": finding.adjudication.rawValue,
                "confidence": finding.confidence.rawValue,
            ]
        }
        writeJSON(["generated": generated, "corpusCommit": corpusCommit, "findings": detail],
                  to: directory.appendingPathComponent("structure-sweep.json"))

        generatorLog("[sweep] wrote structure-sweep.csv, structure-sweep.json and counts.json to "
                     + directory.path)
    }

    /// A count with thousands separators, so the report reads as prose.
    ///
    /// The separator is set explicitly rather than taken from a locale: `en_US_POSIX`, the locale
    /// every other generator here pins for reproducibility, suppresses grouping entirely — so the
    /// obvious spelling of this function silently returns the bare digits.
    static func grouped(_ value: Int) -> String {
        let digits = Array(String(value))
        var out: [String] = []
        for (offset, digit) in digits.enumerated() {
            if offset > 0, (digits.count - offset) % 3 == 0 { out.append(",") }
            out.append(String(digit))
        }
        return out.joined()
    }

    /// Writes sorted-key JSON, so a re-run at a pinned date is byte-identical.
    static func writeJSON(_ value: [String: Any], to url: URL) {
        guard let data = try? JSONSerialization.data(
            withJSONObject: value, options: [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes])
        else { return }
        try? data.write(to: url)
    }
}

// MARK: - The covering report

extension SweepReportWriter {

    /// Writes `REPORT.md` — the text an editor reads, with every figure taken from this same run.
    ///
    /// **The numbers are not retyped.** A report whose arithmetic does not reconcile loses its
    /// reader before it reaches its findings, and the measurement pass that designed this sweep
    /// produced several censuses that did not sum to their own components.
    public static func writeReport(findings: [StructureFinding], to directory: URL,
                                   generated: String, corpusCommit: String, filesScanned: Int,
                                   divCount: Int, volumesWithContents: Int,
                                   duplicateIds: Int, duplicateDocumentNumbers: Int) {
        let volumes = Set(findings.map(\.volumeId)).count
        let confirmed = findings.filter { $0.confidence == .confirmed }
        let unadjudicated = findings.filter { $0.adjudication == .unadjudicated }
        var text = """
        # FRUS TEI — structural encoding defects found by an independent scan

        Generated \(generated) against the corpus at commit `\(corpusCommit)`. \
        **Every line and byte offset below is relative to that revision.**

        ## What this is

        We maintain [FRUS Explorer](https://github.com/joshbotts/FRUS-Explorer), an independent \
        reader that parses your TEI. Scanning all \(filesScanned) files (\(grouped(divCount)) `<div>` \
        elements) for structural consistency turned up **\(findings.count) places in \(volumes) \
        volumes** where a `</div>` appears to sit in the wrong place, nesting material one level \
        deeper than the printed book puts it.

        **Every one of these files is well-formed, and every `</div>` count balances.** The closing \
        tag is simply written after the divisions it should close before, so no XML validator, no \
        schema and no ODD can see any of it — which is presumably why it has gone unnoticed. It \
        follows that **every correction below is a move, never an insertion**: the tag count does \
        not change.

        ## How each row was checked

        A row is `confirmed` only when two independent things agree AND the repair has been \
        simulated: the edit is applied to a scratch copy, the file is re-parsed, and the rule that \
        fired is checked to be silent afterwards. \
        **\(confirmed.count) of \(findings.count)** rows meet that bar. The rest are offered as \
        questions, marked `please-verify-against-print`.

        The strongest check available is the volume's own printed table of contents: where it \
        prints two headings at the same level, the book itself says they are siblings. \
        \(volumesWithContents) of \(filesScanned) files carry a machine-readable contents list.

        ## What this scan does NOT claim

        - **It is not complete.** It finds a tag displaced *later* — material absorbed into its \
        predecessor — and, through the id grammar, some displaced *earlier*. Other shapes exist \
        that these rules cannot see.
        - **It is not series-wide in practice.** Modern FRUS is structurally flat: most volumes \
        after 1977 have almost no nested structure for this scan to test, so a clean result there \
        says nothing about their quality.
        - **Where the findings concentrate, the adjudicator is weakest.** The older volumes hold \
        most of these, and they are the least likely to carry a machine-readable contents list. \
        \(unadjudicated.count) row(s) are marked `NO-TOC-UNADJUDICATED` and are offered as \
        questions rather than assertions.
        - **It says nothing about whether a `<ref target>` resolves.** That is a separate scan.
        - The one clean NEGATIVE, measured by this same run: across all \(filesScanned) files the \
        scan finds **\(duplicateIds) duplicate `xml:id`** and **\(duplicateDocumentNumbers) \
        duplicate document `@n` within a volume**. The anchor layer everything else depends on is \
        sound.

        ## The rows

        The full set is attached as `structure-sweep.csv`, one row per fix site, with a \
        `corrected_encoding` column stating each edit precisely enough to apply by hand. \
        The confirmed rows:


        """
        text += "| Volume | Element | What is wrong | The edit |\n|---|---|---|---|\n"
        for finding in confirmed {
            let wrong = finding.whatIsWrong.replacingOccurrences(of: "|", with: "\\|")
            let fix = finding.correctedEncoding.replacingOccurrences(of: "|", with: "\\|")
            text += "| `\(finding.volumeId)` | [`\(finding.elementId)`](\(finding.publicURL)) "
                + "| \(wrong) | \(fix) |\n"
        }
        text += """

        ## Worth naming separately

        Where a single displaced tag explains several symptoms, this report says so in one row \
        rather than repeating the same edit: the tool applies each candidate move to a scratch \
        copy and keeps the one that takes the whole volume to zero violations.

        We are not asking for anything but the correction, and we would rather hear that a row is \
        wrong than not hear at all — each one names what we checked, so it should be quick to \
        dismiss the ones that are deliberate.

        """
        try? text.write(to: directory.appendingPathComponent("REPORT.md"), atomically: true,
                        encoding: .utf8)
        generatorLog("[sweep] wrote REPORT.md")
    }
}
