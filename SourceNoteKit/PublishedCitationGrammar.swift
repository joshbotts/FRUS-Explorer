// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// The published-source citation grammar (W-11): decomposes a `previouslyPublished`
/// source note into the publication it names and the search guidance a researcher
/// needs to find the document in that publication's digitized run.
///
/// `SourceNoteParser` classifies a note as previously published but carries the raw
/// string only — `case previouslyPublished(citation: String)` decomposes nothing. This
/// grammar is the extraction layer on top, for exactly the four publication families
/// that dominate the population (measured over the live index, 2026-08-27: 916
/// published notes; Treaty Series 333 + *Bulletin* ~184 + *Public Papers* 106 + EAS
/// 102 = 79.8%). The tail — Miller's *Treaties*, League of Nations prints, bare
/// Statutes-at-Large cites, FRUS self-citations — deliberately parses to `nil`:
/// a wrong link is worse than the honest generic copy the panel already shows.
///
/// Input is the classifier's own `citation` string (the note body after any `Source:`
/// strip), so family detection anchors exactly where `previouslyPublishedLeads`
/// anchors. Two corpus landmines are load-bearing in the fixtures: the TEI-to-text
/// pass leaves a spurious space before punctuation around unwrapped italics
/// (`Bulletin , May 5, 1946`), and *Bulletin* volume numbers print as roman numerals
/// (`vol. iii , No. 73`) — which is one reason the designation is date + page and the
/// volume number is not extracted.
public enum PublishedPublication: String, Sendable, CaseIterable {
    /// The Department of State's numbered Treaty Series prints (TS, through 1945).
    case treatySeries
    /// The Department of State's numbered Executive Agreement Series prints (EAS).
    case executiveAgreementSeries
    /// The *Department of State Bulletin* (1939–1989 weekly/monthly).
    case stateBulletin
    /// *Public Papers of the Presidents of the United States* (GPO annual volumes).
    case publicPapers
}

/// One parsed published-source citation: the publication family plus the extracted
/// search guidance (`nil` when the family matched but no number/date/page could be
/// read — the panel then shows the link without a guidance line).
public struct PublishedCitation: Equatable, Sendable {
    /// Which publication the note cites.
    public let publication: PublishedPublication
    /// What to look for inside it — `"No. 592"`, `"September 5, 1948, p. 300"`,
    /// `"Johnson, 1965, Book II, pp. 1003–1006"` — cleaned of the italic-space
    /// artifact, or `nil` when nothing beyond the family name could be extracted.
    public let designation: String?

    /// Memberwise initializer (public so app-side tests can build fixtures).
    public init(publication: PublishedPublication, designation: String?) {
        self.publication = publication
        self.designation = designation
    }
}

/// Parses `previouslyPublished` citation strings into ``PublishedCitation`` values.
public enum PublishedCitationGrammar {

    /// Parse one classifier-shaped citation string. Returns `nil` for the honest-tail
    /// publications this grammar does not cover.
    public static func parse(_ citation: String) -> PublishedCitation? {
        var body = citation.trimmingCharacters(in: .whitespacesAndNewlines)
        // Defensive: the classifier hands the post-`Source:` body, but tolerate the
        // prefix so a caller holding the raw note gets the same answer.
        if body.hasPrefix("Source:") {
            body = String(body.dropFirst("Source:".count))
                .trimmingCharacters(in: .whitespaces)
        }
        if let ts = parseNumberedSeries(body, lead: "Treaty Series") {
            return PublishedCitation(publication: .treatySeries, designation: ts)
        }
        if body.hasPrefix("Treaty Series") {
            return PublishedCitation(publication: .treatySeries, designation: nil)
        }
        if let eas = parseNumberedSeries(body, lead: "Executive Agreement Series") {
            return PublishedCitation(publication: .executiveAgreementSeries, designation: eas)
        }
        if body.hasPrefix("Executive Agreement Series") {
            return PublishedCitation(publication: .executiveAgreementSeries, designation: nil)
        }
        if let bulletin = parseBulletin(body) {
            return bulletin
        }
        if let papers = parsePublicPapers(body) {
            return papers
        }
        return nil
    }

    // MARK: - Numbered series (TS / EAS)

    /// `Treaty Series No. 592.]` / `Treaty Series, No. 589.` → `"No. 592"`. The number
    /// may carry a letter suffix (`673–A`); trailing `.` and the bracketed-note `]`
    /// fall outside the capture. `No` tolerates a colon for its period — the corpus
    /// prints one OCR-bent `Treaty Series No: 596:]`.
    private static func parseNumberedSeries(_ body: String, lead: String) -> String? {
        guard body.hasPrefix(lead) else { return nil }
        let pattern = "^" + NSRegularExpression.escapedPattern(for: lead)
            + #"\s*,?\s*No[.:]?\s*([0-9]+(?:\s*[-–—]\s*[A-Za-z0-9]+)?)"#
        guard let number = firstCapture(pattern, in: body) else { return nil }
        return "No. " + cleanArtifacts(number)
    }

    // MARK: - Department of State Bulletin

    /// Head-anchored (`Department of State Bulletin , September 5, 1948, p. 300.`) or
    /// the reprint phrase anywhere (`…; reprinted from Department of State, Bulletin ,
    /// September 28, 1940 (vol. iii , No. 66), p. 243.`) — the same two shapes the
    /// classifier admits. `Department of State` must immediately precede `Bulletin`,
    /// which is what keeps the *Official U. S. Bulletin* and the American Relief
    /// Administration's *Bulletin* out of this family.
    private static func parseBulletin(_ body: String) -> PublishedCitation? {
        let headPattern = #"^Department of State\s*,?\s*Bulletin"#
        let reprintPattern =
            #"(?:[Rr]eprinted|[Pp]rinted)\s+(?:from|in)\s+(?:the\s+)?Department of State\s*,?\s*Bulletin"#
        let tail: String
        if let range = firstMatchRange(headPattern, in: body) {
            tail = String(body[range.upperBound...])
        } else if let range = firstMatchRange(reprintPattern, in: body) {
            tail = String(body[range.upperBound...])
        } else {
            return nil
        }
        // Leftmost date and page after the anchor are the citation's own; trailing
        // editorial prose can repeat dates but never precedes them. Monthly issues
        // (1978+) cite month-year with no day, and their front-matter pages are
        // lettered (`September 1980, pp. A–C`).
        let date = firstCapture(
            #"([A-Z][a-z]+\.?\s+[0-9]{1,2},\s*[0-9]{4})"#, in: tail)
            ?? firstCapture(#"([A-Z][a-z]+\.?\s+[0-9]{4})"#, in: tail)
        let page = firstCapture(
            #"\bpp?\.\s*((?:[0-9]+|[A-Z])(?:\s*[-–—]\s*(?:[0-9]+|[A-Z]))?)\b"#, in: tail)
        var parts: [String] = []
        if let date { parts.append(cleanArtifacts(date)) }
        if let page {
            let plural = page.rangeOfCharacter(from: CharacterSet(charactersIn: "-–—")) != nil
            parts.append((plural ? "pp. " : "p. ") + cleanArtifacts(page))
        }
        return PublishedCitation(publication: .stateBulletin,
                                 designation: parts.isEmpty ? nil : parts.joined(separator: ", "))
    }

    // MARK: - Public Papers of the Presidents

    /// Both corpus forms: the long
    /// `Public Papers of the Presidents of the United States: Harry S. Truman , 1945, p. 331.`
    /// and the short `Public Papers: Johnson , 1965 , Book II, pp. 1003–1006.` used by
    /// 1977+ volumes. President names arrive OCR-bent (`John E Kennedy`) — the name is
    /// display guidance, never a key, so it ships as printed (whitespace-collapsed).
    private static func parsePublicPapers(_ body: String) -> PublishedCitation? {
        let headPattern =
            #"^Public Papers(?:\s+of the Presidents(?:\s+of the United States)?)?\s*:?\s*"#
        guard let head = firstMatchRange(headPattern, in: body) else { return nil }
        let tail = String(body[head.upperBound...])
        var parts: [String] = []
        if let named = firstCaptures(
            #"^([A-Z][^,]{0,60}?)\s*,\s*([0-9]{4})"#, in: tail, count: 2) {
            parts.append(cleanArtifacts(named[0]))
            parts.append(named[1])
        } else if let year = firstCapture(#"^([0-9]{4})"#, in: tail) {
            parts.append(year)
        }
        if let book = firstCapture(#"\b(Book\s+[IVXLC]+)\b"#, in: tail) {
            parts.append(cleanArtifacts(book))
        }
        if let page = firstCapture(
            #"\bpp?\.\s*([0-9]+(?:\s*[-–—]\s*[0-9]+)?)"#, in: tail) {
            let plural = page.rangeOfCharacter(from: CharacterSet(charactersIn: "-–—")) != nil
            parts.append((plural ? "pp. " : "p. ") + cleanArtifacts(page))
        }
        return PublishedCitation(publication: .publicPapers,
                                 designation: parts.isEmpty ? nil : parts.joined(separator: ", "))
    }

    // MARK: - Shared plumbing

    /// Collapses runs of whitespace and removes the space the TEI-to-text pass leaves
    /// before punctuation around unwrapped italics (`Johnson , 1965` → `Johnson, 1965`).
    private static func cleanArtifacts(_ text: String) -> String {
        let collapsed = text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return collapsed
            .replacingOccurrences(of: #"\s+([,.;:])"#,
                                  with: "$1",
                                  options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    /// The first match's whole range, or `nil`.
    private static func firstMatchRange(_ pattern: String, in body: String) -> Range<String.Index>? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = NSRange(body.startIndex..., in: body)
        guard let match = regex.firstMatch(in: body, range: ns) else { return nil }
        return Range(match.range, in: body)
    }

    /// The first match's capture group 1, or `nil`.
    private static func firstCapture(_ pattern: String, in body: String) -> String? {
        firstCaptures(pattern, in: body, count: 1)?.first
    }

    /// The first match's capture groups 1…count, or `nil` when the pattern misses or a
    /// group did not participate.
    private static func firstCaptures(_ pattern: String, in body: String, count: Int) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = NSRange(body.startIndex..., in: body)
        guard let match = regex.firstMatch(in: body, range: ns) else { return nil }
        var out: [String] = []
        for group in 1...count {
            guard let range = Range(match.range(at: group), in: body) else { return nil }
            out.append(String(body[range]))
        }
        return out
    }
}
