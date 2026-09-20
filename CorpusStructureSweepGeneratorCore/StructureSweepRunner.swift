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

/// Sweeps the corpus for structural defects and writes the report OH can act on (#1309).
///
/// Version history:
///   1.0 — 2026-09-20: #1309
public enum StructureSweepRunner {

    /// One rule, with the name the report prints and the finder that implements it.
    struct Rule: Sendable {
        let id: String
        let label: String
        let find: @Sendable ([DivNode]) -> [Int]
    }

    static let rules: [Rule] = [
        Rule(id: "R1-rank", label: "structural rank violation", find: StructureRules.rankViolations),
        Rule(id: "R2-day-in-day", label: "a conference day inside another day",
             find: StructureRules.dayInDay),
        Rule(id: "R3-session-in-session", label: "a session inside another session",
             find: StructureRules.sessionInSession),
        Rule(id: "R4-chapter-in-historical-document", label: "a chapter inside a historical document",
             find: StructureRules.chapterInHistoricalDocument),
        Rule(id: "R5-apparatus", label: "apparatus below the volume root",
             find: StructureRules.displacedApparatus),
        Rule(id: "R6-id-level", label: "the volume's own id grammar puts this one level up",
             find: StructureRules.idLevelViolations),
        Rule(id: "R7-expelled", label: "a subchapter with no chapter to belong to",
             find: StructureRules.expelledSubchapters),
        Rule(id: "R8-document-in-editorial-note", label: "a document inside an editorial note",
             find: StructureRules.documentInEditorialNote),
        Rule(id: "R1b-mistyped-container", label: "a container typed chapter that its own id calls a compilation",
             find: StructureRules.mistypedContainers),
    ]

    /// Runs the sweep.
    public static func run() {
        let environment = ProcessInfo.processInfo.environment
        let volumesPath = environment["VOLUMES_DIR"] ?? "/Users/jbotts/Development/frus/volumes"
        let outputPath = environment["OUTPUT_DIR"] ?? "Planning/corpus-structure-sweep"
        let generated = generatorDateStamp(override: environment["GENERATED_DATE"])

        // REQUIRED, with no default: every line and byte offset in this report is meaningless
        // without the revision it was measured at. #1309's own offsets are from an earlier commit
        // and are wrong at HEAD by 6,468 to 11,129 bytes.
        guard let corpusCommit = environment["CORPUS_COMMIT"], !corpusCommit.isEmpty else {
            generatorLog("[sweep] ERROR: " + "CORPUS_COMMIT is required: every offset in this report is relative to one "
                      + "revision of the corpus, and a report that cannot name it cannot be acted on")
            exit(1)
        }

        let volumesURL = URL(fileURLWithPath: volumesPath, isDirectory: true)
        let files = (try? FileManager.default.contentsOfDirectory(atPath: volumesPath))?
            .filter { $0.hasSuffix(".xml") }.sorted() ?? []
        guard !files.isEmpty else {
            generatorLog("[sweep] ERROR: " + "no volumes at \(volumesPath)")
            exit(1)
        }
        generatorLog("[sweep] scanning \(files.count) files at corpus \(corpusCommit)")

        var findings: [StructureFinding] = []
        var scanned = 0
        var divCount = 0
        var parityFailures: [String] = []
        var volumesWithContents = 0
        var candidatesByRule: [String: Int] = [:]
        var singleMoveVolumes = 0
        // The report's one CERTAIN claim is a negative, so this run must measure it rather than
        // inherit it from the analysis that designed the sweep. A generated report may not assert
        // what its own run did not check.
        var duplicateIdFiles: [String] = []
        var duplicateDocumentNumberFiles: [String] = []

        for file in files {
            let url = volumesURL.appendingPathComponent(file)
            guard let data = try? Data(contentsOf: url),
                  let xml = String(data: data, encoding: .utf8) else { continue }
            scanned += 1
            let nodes = DivScanner.scan(data)
            divCount += nodes.count

            // The scan is cross-checked against an element tree on every file. The first version
            // of this scanner disagreed on three files, because the PubDip volumes embed XHTML
            // `<div>`s from a video player in a foreign namespace.
            if let mismatch = ElementTreeParity.check(data: data, against: nodes) {
                parityFailures.append("\(file): \(mismatch)")
            }

            var ids: Set<String> = []
            var documentNumbers: Set<String> = []
            for node in nodes {
                if let id = node.id, !ids.insert(id).inserted {
                    duplicateIdFiles.append("\(file):\(id)")
                }
                if node.type == "document", let number = node.n,
                   !documentNumbers.insert(number).inserted {
                    duplicateDocumentNumberFiles.append("\(file):\(number)")
                }
            }

            let contents = ContentsAdjudicator.entries(in: xml)
            if !contents.isEmpty { volumesWithContents += 1 }
            let volumeId = String(file.dropLast(4))

            var volumeFindings: [StructureFinding] = []
            for rule in rules {
                let flagged = rule.find(nodes)
                if !flagged.isEmpty { candidatesByRule[rule.id, default: 0] += flagged.count }
                for index in flagged {
                    volumeFindings.append(finding(for: nodes[index], rule: rule, nodes: nodes,
                                                  volumeId: volumeId, file: file, xml: xml,
                                                  contents: contents))
                }
            }

            // One displaced tag produces many symptoms. Before reporting N rows, TEST whether a
            // single move explains them all — the tool does not reason about the cascade.
            let moves = candidateMoves(for: volumeFindings, nodes: nodes)
            if volumeFindings.count > 1,
               let single = VolumeRepair.singleMoveThatClearsTheVolume(
                    xml: xml, moves: moves, allRules: rules.map(\.find)) {
                volumeFindings = [collapsed(volumeFindings, to: single, volumeId: volumeId)]
                singleMoveVolumes += 1
            } else {
                volumeFindings = groupedByFixSite(volumeFindings, nodes: nodes)
            }
            findings.append(contentsOf: volumeFindings)
        }

        // A scanner that disagrees with an element tree has invalidated every offset it produced.
        guard parityFailures.isEmpty else {
            generatorLog("[sweep] ERROR: " + "byte scan disagrees with the element tree in \(parityFailures.count) file(s):")
            for failure in parityFailures.prefix(10) { generatorLog("[sweep] ERROR:   \(failure)") }
            exit(1)
        }
        guard !findings.isEmpty else {
            generatorLog("[sweep] ERROR: " + "no findings: a sweep that reports nothing is a broken sweep, not a clean corpus")
            exit(1)
        }

        findings.sort { ($0.volumeId, $0.line, $0.rule) < ($1.volumeId, $1.line, $1.rule) }
        let outputURL = URL(fileURLWithPath: outputPath, isDirectory: true)
        try? FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        SweepReportWriter.write(findings: findings, to: outputURL, generated: generated,
                                corpusCommit: corpusCommit, filesScanned: scanned,
                                divCount: divCount, volumesWithContents: volumesWithContents,
                                candidatesByRule: candidatesByRule,
                                duplicateIds: duplicateIdFiles.count,
                                duplicateDocumentNumbers: duplicateDocumentNumberFiles.count)
        SweepReportWriter.writeReport(findings: findings, to: outputURL, generated: generated,
                                      corpusCommit: corpusCommit, filesScanned: scanned,
                                      divCount: divCount, volumesWithContents: volumesWithContents,
                                      duplicateIds: duplicateIdFiles.count,
                                      duplicateDocumentNumbers: duplicateDocumentNumberFiles.count)

        let confirmed = findings.filter { $0.confidence == .confirmed }.count
        generatorLog("[sweep] \(findings.count) findings in \(Set(findings.map(\.volumeId)).count) "
                     + "volumes (\(confirmed) confirmed, \(findings.count - confirmed) to verify "
                     + "against print); \(singleMoveVolumes) volume(s) reduced to one move by "
                     + "simulation")
    }

    /// Collapses findings that name the SAME EDIT into one row each.
    ///
    /// A volume with several displaced tags does not collapse to one move, but its rows still must
    /// not repeat an edit: five sessions absorbed by one tag are one fix, not five. Grouping is by
    /// the tag that moves — or, where no move is proposed, by (rule, parent), which is the same
    /// question asked of the rows that state an inconsistency rather than a fix.
    ///
    /// Contiguity in the children array cannot do this job: printed documents sit between the
    /// absorbed sessions, so the flagged divs are siblings but not adjacent.
    static func groupedByFixSite(_ findings: [StructureFinding], nodes: [DivNode])
        -> [StructureFinding] {
        var seen: Set<String> = []
        var grouped: [StructureFinding] = []
        var extras: [String: Int] = [:]
        for finding in findings {
            let parentId = nodes.first { $0.openByte == finding.byteOffset }
                .flatMap { StructureRules.nearestStructuralAncestor(of: $0, in: nodes) }
                .flatMap { nodes[$0].id } ?? "-"
            let key = finding.donorLine.map { "move:\($0)" } ?? "\(finding.rule)|\(parentId)"
            if seen.insert(key).inserted {
                grouped.append(finding)
            } else {
                extras[key, default: 0] += 1
            }
        }
        return grouped.map { finding in
            let parentId = nodes.first { $0.openByte == finding.byteOffset }
                .flatMap { StructureRules.nearestStructuralAncestor(of: $0, in: nodes) }
                .flatMap { nodes[$0].id } ?? "-"
            let key = finding.donorLine.map { "move:\($0)" } ?? "\(finding.rule)|\(parentId)"
            guard let extra = extras[key], extra > 0 else { return finding }
            return StructureFinding(
                volumeId: finding.volumeId, elementId: finding.elementId, rule: finding.rule,
                whatIsWrong: finding.whatIsWrong
                    + " — and \(extra) further div(s) at the same level are absorbed by the same tag",
                correctedEncoding: finding.correctedEncoding, evidence: finding.evidence,
                adjudication: finding.adjudication, confidence: finding.confidence,
                byteOffset: finding.byteOffset, line: finding.line, donorLine: finding.donorLine)
        }
    }

    /// Every move the volume's own findings propose, as the whole-volume simulator needs them.
    static func candidateMoves(for findings: [StructureFinding], nodes: [DivNode])
        -> [(donorByte: Int, donorLine: Int, insertByte: Int, insertLine: Int, id: String)] {
        // EVERY structural ancestor's close, not just the nearest. The tag that is actually out of
        // place can be several levels up: in `frus1945Malta` the nearest parent of the first
        // absorbed div is a meeting, while the displaced tag belongs to the chapter three levels
        // above it. A candidate set built from nearest parents alone cannot find that move, and
        // the volume then reports six symptoms instead of one cause.
        var moves: [(donorByte: Int, donorLine: Int, insertByte: Int, insertLine: Int, id: String)] = []
        for finding in findings {
            guard let node = nodes.first(where: { $0.openByte == finding.byteOffset }) else {
                continue
            }
            var ancestor = StructureRules.nearestStructuralAncestor(of: node, in: nodes)
            while let index = ancestor, index >= 0 {
                let candidate = nodes[index]
                if candidate.closeByte > node.openByte {
                    moves.append((candidate.closeByte, candidate.closeLine, node.openByte,
                                  node.openLine, node.id ?? "(no xml:id)"))
                }
                ancestor = StructureRules.nearestStructuralAncestor(of: candidate, in: nodes)
            }
        }
        return moves
    }

    /// The one row a volume gets when simulation shows a single move clears it.
    static func collapsed(_ findings: [StructureFinding], to move: VolumeRepair.Candidate,
                          volumeId: String) -> StructureFinding {
        // One element flagged by two rules is one symptom, not two.
        var seenElements: Set<String> = []
        let symptoms = findings.filter { seenElements.insert($0.elementId).inserted }
            .map { "\($0.elementId) (\($0.rule))" }.joined(separator: ", ")
        let leader = findings.min { $0.line < $1.line } ?? findings[0]
        return StructureFinding(
            volumeId: volumeId, elementId: move.insertBeforeId, rule: "displaced-close-tag",
            whatIsWrong: "one </div> sits after the divs it should close before, so "
                + "\(findings.count) divs are nested one level too deep: \(symptoms)",
            correctedEncoding: "move the </div> at line \(move.donorLine) to line "
                + "\(move.insertLine), immediately before <div xml:id=\"\(move.insertBeforeId)\">; "
                + "tag count unchanged",
            evidence: leader.evidence
                + "; repair simulated over the WHOLE volume — this single move takes it from "
                + "\(move.before) structural violation(s) to \(move.after), and the file still parses",
            adjudication: leader.adjudication,
            confidence: move.after == 0 && leader.adjudication != .unadjudicated
                ? .confirmed : .pleaseVerify,
            byteOffset: move.insertByte, line: move.insertLine, donorLine: move.donorLine)
    }

    /// Builds one report row, adjudicating it and simulating its repair.
    static func finding(for node: DivNode, rule: Rule, nodes: [DivNode], volumeId: String,
                        file: String, xml: String,
                        contents: [ContentsAdjudicator.Entry]) -> StructureFinding {
        let parentIndex = StructureRules.nearestStructuralAncestor(of: node, in: nodes)
        let parent = parentIndex.map { nodes[$0] }
        let elementId = node.id ?? "(no xml:id)"

        var adjudication = StructureFinding.Adjudication.unadjudicated
        var evidence = "no machine-readable table of contents in this volume, so nothing in the "
            + "file settles the level; offered as a question"
        if contents.isEmpty {
            adjudication = .unadjudicated
        } else if let parent, ContentsAdjudicator.contradicts(parentHead: parent.headText,
                                                             childHead: node.headText,
                                                             entries: contents) {
            adjudication = .tocContradicts
            evidence = "the volume's own table of contents prints “\(parent.headText)” and "
                + "“\(node.headText)” at the SAME level, so the book makes them siblings while the "
                + "file nests one inside the other"
        } else if rule.id == "R6-id-level" || rule.id == "R7-expelled" {
            adjudication = .intraVolumeConvention
            evidence = "the volume's own xml:id grammar names a parent this div does not have: "
                + "\(elementId) belongs under a subchapter of its own chapter"
        } else {
            adjudication = .baseRate
            evidence = "this shape is exceptional corpus-wide; the volume's contents does not "
                + "name both headings, so the level rests on the base rate alone"
        }

        // A move is proposed only when the parent's close is the tag that is out of place.
        var corrected = "review the level of this div against the printed volume"
        var donorLine: Int?
        var confidence = StructureFinding.Confidence.pleaseVerify
        if rule.id == "R1b-mistyped-container" {
            // The nesting is right and the type is wrong, so the edit is a retype. Reported as one
            // row rather than one per child: an editor opening a child's row would find nothing
            // wrong there, and the live site already renders this volume correctly.
            return StructureFinding(
                volumeId: volumeId, elementId: elementId, rule: rule.id,
                whatIsWrong: "\(rule.label): \(elementId) is typed type=\"chapter\" but its own "
                    + "xml:id names a compilation, and it holds "
                    + "\(node.children.filter { nodes[$0].type == "chapter" }.count) chapters",
                correctedEncoding: "change type=\"chapter\" to type=\"compilation\" on this div; "
                    + "the nesting below it is already correct and no tag moves",
                evidence: "the volume's own id-minting calls this div a compilation, and its "
                    + "children are chapters; the published site renders it as a compilation",
                adjudication: .intraVolumeConvention, confidence: .pleaseVerify,
                byteOffset: node.openByte, line: node.openLine, donorLine: nil)
        }
        if let parent, parent.closeByte > node.openByte {
            let outcome = RepairSimulator.simulateMove(
                xml: xml, donorCloseByte: parent.closeByte, insertByte: node.openByte,
                recheck: rule.find)
            if outcome.isConfirmed {
                donorLine = parent.closeLine
                corrected = "move the </div> at line \(parent.closeLine) to line \(node.openLine), "
                    + "immediately before this div; tag count unchanged"
                // Confirmed needs a SECOND symptom as well as a clean simulation.
                if adjudication == .tocContradicts || adjudication == .intraVolumeConvention {
                    confidence = .confirmed
                }
                evidence += "; repair simulated — the file still parses and the rule goes from "
                    + "\(outcome.violationsBefore) violation(s) to \(outcome.violationsAfter)"
            } else if let refusal = outcome.refusal {
                evidence += "; repair NOT simulated (\(refusal)), so this row states the "
                    + "inconsistency and not the fix"
            }
        }

        let parentDescription = parent.map { "“\($0.headText)” (\($0.id ?? "?"), \($0.type))" }
            ?? "its parent"
        return StructureFinding(
            volumeId: volumeId, elementId: elementId, rule: rule.id,
            whatIsWrong: "\(rule.label): “\(node.headText)” (\(elementId), \(node.type)) sits "
                + "inside \(parentDescription)",
            correctedEncoding: corrected, evidence: evidence, adjudication: adjudication,
            confidence: confidence, byteOffset: node.openByte, line: node.openLine,
            donorLine: donorLine)
    }
}
