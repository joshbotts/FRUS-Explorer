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

// MARK: - DivNode

/// One `<div>` in a volume, with the byte offsets a correction has to name.
///
/// The offsets are the product of this tool, which is why the corpus is byte-scanned rather than
/// parsed into an object tree: an OH editor opens the file at a line, and a correction reads "move
/// the tag at line C to line B".
///
/// Version history:
///   1.0 — 2026-09-20: #1309
public struct DivNode: Sendable, Equatable {
    /// Index into the volume's flat node array; `-1` for the synthetic root.
    public let index: Int
    /// Parent's index, or `nil` at the root.
    public let parent: Int?
    /// Child indices, in document order.
    public var children: [Int]
    /// `@type` — `compilation`, `chapter`, `subchapter`, `section`, `document`, or another value.
    public let type: String
    /// `@subtype`, when present.
    public let subtype: String?
    /// `@xml:id`, when present.
    public let id: String?
    /// `@n`, when present.
    public let n: String?
    /// Byte offset of the `<` that opens this div.
    public let openByte: Int
    /// 1-based line of the opening tag.
    public let openLine: Int
    /// Byte offset of the `<` that opens this div's `</div>`.
    public var closeByte: Int
    /// 1-based line of the closing tag.
    public var closeLine: Int
    /// Depth below the volume root (a root-level div is 0).
    public let depth: Int
    /// The div's own `<head>` text, whitespace-collapsed, with `<note>` subtrees REMOVED.
    ///
    /// Stripping notes is load-bearing for the day grammar: a conference day's head often carries
    /// an editorial note whose text would otherwise defeat an anchored `^…$` match, which is how
    /// a whole volume's worth of day headings went unseen in the first measurement pass.
    public var headText: String

    /// Whether this div is one of the five structural kinds the sweep reasons about.
    public var isStructural: Bool { Self.structuralTypes.contains(type) }

    /// The structural kinds, in the corpus's own vocabulary.
    public static let structuralTypes: Set<String> = ["compilation", "chapter", "subchapter", "section"]

    /// Memberwise initializer (fields documented on the properties).
    public init(index: Int, parent: Int?, children: [Int] = [], type: String, subtype: String?,
                id: String?, n: String?, openByte: Int, openLine: Int, closeByte: Int,
                closeLine: Int, depth: Int, headText: String = "") {
        self.index = index
        self.parent = parent
        self.children = children
        self.type = type
        self.subtype = subtype
        self.id = id
        self.n = n
        self.openByte = openByte
        self.openLine = openLine
        self.closeByte = closeByte
        self.closeLine = closeLine
        self.depth = depth
        self.headText = headText
    }
}

// MARK: - StructureFinding

/// One row of the report: a div that sits at the wrong level, with the edit that would fix it.
public struct StructureFinding: Sendable, Equatable {
    /// The volume id (`frus1945Malta`).
    public let volumeId: String
    /// The `xml:id` of the div that is in the wrong place.
    public let elementId: String
    /// Which rule fired.
    public let rule: String
    /// The reader-facing statement of what is wrong.
    public let whatIsWrong: String
    /// The edit, stated as an edit: which tag moves, from where, to where.
    public let correctedEncoding: String
    /// The level test that fired, in words.
    public let evidence: String
    /// How the printed book (or the volume's own convention) adjudicated it.
    public let adjudication: Adjudication
    /// Whether the row is asserted or offered as a question.
    public let confidence: Confidence
    /// Byte offset and line of the div itself.
    public let byteOffset: Int
    public let line: Int
    /// The `</div>` that would move, when the correction is a move.
    public let donorLine: Int?

    /// How a finding was corroborated.
    public enum Adjudication: String, Sendable, CaseIterable {
        /// The volume's own printed table of contents contradicts the file.
        case tocContradicts = "TOC-CONTRADICTS"
        /// The volume's own `xml:id` grammar or parallel structure contradicts the file.
        case intraVolumeConvention = "INTRA-VOLUME-CONVENTION"
        /// A sibling volume in the same subseries encodes the same thing at another level.
        case siblingVolume = "SIBLING-VOLUME"
        /// A corpus-wide base rate makes this shape exceptional.
        case baseRate = "BASE-RATE"
        /// The volume carries no machine-readable contents, so nothing in it settles the question.
        case unadjudicated = "NO-TOC-UNADJUDICATED"
    }

    /// Whether a row is asserted or offered for checking against the printed volume.
    ///
    /// **Nothing ships as `confirmed` without a second independent symptom AND a repair
    /// simulation that re-parses.** A wrong correction is worse than a missed defect: it would be
    /// applied by an editor who trusted us.
    public enum Confidence: String, Sendable {
        case confirmed
        case pleaseVerify = "please-verify-against-print"
    }

    /// Memberwise initializer (fields documented on the properties).
    public init(volumeId: String, elementId: String, rule: String, whatIsWrong: String,
                correctedEncoding: String, evidence: String, adjudication: Adjudication,
                confidence: Confidence, byteOffset: Int, line: Int, donorLine: Int? = nil) {
        self.volumeId = volumeId
        self.elementId = elementId
        self.rule = rule
        self.whatIsWrong = whatIsWrong
        self.correctedEncoding = correctedEncoding
        self.evidence = evidence
        self.adjudication = adjudication
        self.confidence = confidence
        self.byteOffset = byteOffset
        self.line = line
        self.donorLine = donorLine
    }

    /// The history.state.gov URL an editor opens to see the defect on their own site.
    public var publicURL: String {
        "https://history.state.gov/historicaldocuments/\(volumeId)/\(elementId)"
    }
}
