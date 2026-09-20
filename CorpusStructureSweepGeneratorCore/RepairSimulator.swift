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

/// Applies a proposed correction in memory and checks that it holds.
///
/// **A wrong correction is worse than a missed defect**, because an editor who trusted us would
/// apply it. So no row ships as `confirmed` unless the move has been made in a scratch copy, the
/// result still parses, and the rule that fired no longer fires. The measurement pass that
/// designed this sweep produced four repair line numbers that were wrong and three that did not
/// contain a `</div>` at all — every one of them caught by simulating rather than asserting.
///
/// Version history:
///   1.0 — 2026-09-20: #1309
public enum RepairSimulator {

    /// The outcome of simulating one move.
    public struct Outcome: Sendable, Equatable {
        /// Whether the repaired text still parses as XML.
        public let parses: Bool
        /// Whether the rule that fired is silent afterwards.
        public let ruleCleared: Bool
        /// Violations before and after, for the report's own evidence line.
        public let violationsBefore: Int
        public let violationsAfter: Int
        /// Why the simulation could not run, when it could not.
        public let refusal: String?

        /// Whether this repair may be asserted.
        public var isConfirmed: Bool { parses && ruleCleared && refusal == nil }
    }

    /// Moves the `</div>` that closes `donor` to just before `insertBefore`, then re-checks.
    ///
    /// - Parameters:
    ///   - xml: the volume's text.
    ///   - donorCloseByte: byte offset of the `<` of the `</div>` that is in the wrong place.
    ///   - insertByte: byte offset the tag should move to — the start of the absorbed div.
    ///   - recheck: the rule to re-run over the repaired tree.
    public static func simulateMove(xml: String, donorCloseByte: Int, insertByte: Int,
                                    recheck: ([DivNode]) -> [Int]) -> Outcome {
        var bytes = [UInt8](Data(xml.utf8))
        let tag = Array("</div>".utf8)
        guard donorCloseByte >= 0, donorCloseByte + tag.count <= bytes.count,
              insertByte >= 0, insertByte <= bytes.count else {
            return Outcome(parses: false, ruleCleared: false, violationsBefore: 0,
                           violationsAfter: 0, refusal: "offsets outside the file")
        }
        // The donor must actually be a `</div>`; the measurement pass proposed three moves of
        // tags that were not there.
        guard Array(bytes[donorCloseByte..<(donorCloseByte + tag.count)]) == tag else {
            return Outcome(parses: false, ruleCleared: false, violationsBefore: 0,
                           violationsAfter: 0,
                           refusal: "no </div> at the donor offset \(donorCloseByte)")
        }
        guard insertByte < donorCloseByte else {
            return Outcome(parses: false, ruleCleared: false, violationsBefore: 0,
                           violationsAfter: 0, refusal: "the tag does not move backwards")
        }

        let before = recheck(DivScanner.scan(Data(bytes))).count
        bytes.removeSubrange(donorCloseByte..<(donorCloseByte + tag.count))
        bytes.insert(contentsOf: tag, at: insertByte)
        let repaired = Data(bytes)
        let after = recheck(DivScanner.scan(repaired)).count

        return Outcome(parses: parses(repaired), ruleCleared: after < before,
                       violationsBefore: before, violationsAfter: after, refusal: nil)
    }

    /// Whether `data` parses as XML — the guard that a repair has not broken well-formedness.
    public static func parses(_ data: Data) -> Bool {
        let parser = XMLParser(data: data)
        let delegate = SilentDelegate()
        parser.delegate = delegate
        return parser.parse()
    }

    /// Accepts every event and records nothing: the question is only whether the parse succeeds.
    private final class SilentDelegate: NSObject, XMLParserDelegate {}
}

// MARK: - VolumeRepair

/// Finds the single edit that explains a whole volume's findings, when there is one.
///
/// **One displaced `</div>` produces many symptoms.** `frus1945Malta` reports a session inside a
/// session, four days inside one day, and three chapters inside one chapter — nine rows for what
/// is, if the simulation says so, ONE moved tag. A report that asked an editor to make that edit
/// nine times would be wrong about the corpus and exhausting to act on.
///
/// So the tool does not reason about the cascade; it TESTS it. Each candidate move is applied in a
/// scratch copy and every rule is re-run over the repaired tree. A move that takes the volume to
/// zero violations is the fix, and the other rows are its consequences.
public enum VolumeRepair {

    /// One candidate edit and what it achieved.
    public struct Candidate: Sendable {
        /// Byte offset of the `</div>` that moves.
        public let donorByte: Int
        /// 1-based line of that tag.
        public let donorLine: Int
        /// Byte offset it moves to.
        public let insertByte: Int
        /// 1-based line it moves to.
        public let insertLine: Int
        /// The element the tag moves in front of.
        public let insertBeforeId: String
        /// Violations across every rule, before and after.
        public let before: Int
        public let after: Int
        /// Whether the repaired file still parses.
        public let parses: Bool
    }

    /// Tries every proposed move in `candidates` and returns the one that clears the most, when it
    /// clears everything. Returns `nil` when no single move does.
    ///
    /// - Parameters:
    ///   - xml: the volume's text.
    ///   - moves: `(donorByte, donorLine, insertByte, insertLine, insertBeforeId)` per candidate.
    ///   - allRules: every rule, so the count is the volume's whole violation total.
    public static func singleMoveThatClearsTheVolume(
        xml: String,
        moves: [(donorByte: Int, donorLine: Int, insertByte: Int, insertLine: Int, id: String)],
        allRules: [([DivNode]) -> [Int]]
    ) -> Candidate? {
        func violations(_ data: Data) -> Int {
            let nodes = DivScanner.scan(data)
            return allRules.reduce(0) { $0 + $1(nodes).count }
        }
        let original = Data(xml.utf8)
        let before = violations(original)
        guard before > 0 else { return nil }

        var best: Candidate?
        let tag = Array("</div>".utf8)
        for move in moves {
            var bytes = [UInt8](original)
            guard move.donorByte >= 0, move.donorByte + tag.count <= bytes.count,
                  move.insertByte >= 0, move.insertByte < move.donorByte,
                  Array(bytes[move.donorByte..<(move.donorByte + tag.count)]) == tag else { continue }
            bytes.removeSubrange(move.donorByte..<(move.donorByte + tag.count))
            bytes.insert(contentsOf: tag, at: move.insertByte)
            let repaired = Data(bytes)
            let after = violations(repaired)
            let candidate = Candidate(donorByte: move.donorByte, donorLine: move.donorLine,
                                      insertByte: move.insertByte, insertLine: move.insertLine,
                                      insertBeforeId: move.id, before: before, after: after,
                                      parses: RepairSimulator.parses(repaired))
            if candidate.parses, candidate.after == 0 { return candidate }
            if candidate.parses, best == nil || candidate.after < best!.after { best = candidate }
        }
        // Only a move that clears the volume entirely may be reported as "the" fix.
        return nil
    }
}
