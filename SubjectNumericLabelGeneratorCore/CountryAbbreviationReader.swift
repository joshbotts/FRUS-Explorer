// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CoreGraphics
import Foundation
import PDFKit

// MARK: - CountryAbbreviationReader

/// Reads the handbooks' COUNTRY ABBREVIATIONS appendix — the vocabulary of the tail that 90% of
/// the corpus's subject-numeric keys carry (#1254).
///
/// ## The table runs the wrong way for the question
/// It is a finding aid, so it maps NAME to CODE and does so many-to-one: every island of the
/// British West Indies is its own row against `BWI`. What a reader needs is the other direction —
/// given `VIET S`, what is it — and inverting the table leaves a code holding a list of names,
/// most of which are not what the code is called.
///
/// So a code's name is CHOSEN from its candidates rather than taken: the head entry is the one
/// whose own words the code was abbreviated from. `VIET S` takes *Vietnam, South* over *Vinh Long
/// (Vietnam, South)* because its two tokens open the candidate's two words; `BWI` takes *British
/// West Indies* on the initials of its three. A code whose candidates fit neither test is left
/// unnamed rather than given the first row that mentioned it.
///
/// Version history:
///   1.0 — #1254: initial implementation
enum CountryAbbreviationReader {

    /// Whether a page belongs to the country appendix, by its own corner mark.
    ///
    /// - Parameter page: The page to test.
    /// - Returns: `true` when the page is part of the appendix.
    static func isCountryPage(_ page: PDFPage) -> Bool {
        let bounds = page.bounds(for: .mediaBox)
        let strip = CGRect(x: bounds.minX, y: bounds.maxY - 60, width: bounds.width, height: 60)
        let text = (page.selection(for: strip)?.string ?? "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
        return text.contains("Ctry.Abbrev")
    }

    /// Every (name, code) pair the appendix prints.
    ///
    /// The page is FOUR columns — two name/code pairs side by side — so it is halved before
    /// anything is read. Grouping rows by `y` across the whole width would pair a name from the
    /// left half with a code from the right.
    ///
    /// - Parameter document: An open handbook.
    /// - Returns: The pairs, in page order.
    static func pairs(in document: PDFDocument) -> [(name: String, code: String)] {
        let marked = (0..<document.pageCount).filter {
            document.page(at: $0).map(isCountryPage) == true
        }
        guard let first = marked.first, let last = marked.last else { return [] }
        var out: [(name: String, code: String)] = []
        for index in first...last {
            guard let page = document.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let lines = OutlinePageReader.lines(of: page, maxX: .greatestFiniteMagnitude)
                .filter { $0.y > 100 && !OutlineEntryParser.isFurniture($0.text) }
            let middle = Double(bounds.midX)
            for half in [lines.filter { $0.x < middle }, lines.filter { $0.x >= middle }] {
                let found = isReverseHalf(half) ? reversePairs(inHalf: half) : pairs(inHalf: half)
                out.append(contentsOf: found)
            }
        }
        return out
    }

    /// One half-page's pairs.
    ///
    /// - Parameter lines: The half's lines, geometry-ordered.
    /// - Returns: The pairs found.
    static func pairs(inHalf lines: [PageLine]) -> [(name: String, code: String)] {
        guard let nameX = nameColumn(of: rows(lines)) else { return [] }
        var out: [(name: String, code: String)] = []
        var name: [String] = []
        var code: String?

        func close() {
            let joined = OutlineEntryParser.tidy(name.joined(separator: " "))
            if let code, !joined.isEmpty, !code.isEmpty { out.append((joined, code)) }
            name = []
            code = nil
        }

        for row in rows(lines) {
            // A row starting at the name column opens an entry; anything further in continues the
            // name it wrapped from. The code sits in its own column, so it arrives either as its
            // own piece of the row or welded to the end of the name.
            if row.x <= nameX + 6 {
                close()
                let (head, tail) = splitTrailingCode(row.text)
                name = [head]
                code = tail
            } else if code == nil, isCode(row.text) {
                code = row.text
            } else if !name.isEmpty {
                let (head, tail) = splitTrailingCode(row.text)
                name.append(head)
                if let tail { code = tail }
            }
        }
        close()
        return out
    }

    /// Whether this half is the appendix's REVERSE index — code first, then name.
    ///
    /// ## The appendix is printed twice, in both directions
    /// Its first eight pages alphabetise by NAME and put the code beside it; its last six
    /// alphabetise by CODE and put the name beside that. Reading both halves as name-first is not
    /// a partial success — it is a near-total failure over the second table, and a silent one:
    /// measured, pages 292–299 gave 22–26 pairs per half while pages 301–306 gave **0 to 2**, and
    /// what disappeared was the back of the alphabet. `Iraq`, `Yemen`, `Vietnam`, `Pakistan` and
    /// `Greece` were all missing while their neighbours resolved.
    ///
    /// The reverse table is also the better source, because it needs no inference: it states the
    /// code's own name where the forward table only lets one be chosen from the places filed
    /// under it.
    ///
    /// - Parameter lines: The half's lines.
    /// - Returns: `true` when the half's leading column is codes.
    static func isReverseHalf(_ lines: [PageLine]) -> Bool {
        let grouped = rows(lines)
        guard let column = nameColumn(of: grouped) else { return false }
        let leading = grouped.filter { $0.x <= column + 6 }
        guard leading.count >= 5 else { return false }
        // A row of the reverse table opens with its code, so its first token is capitals. A row of
        // the forward table opens with a name, whose words are Title Case.
        let codeFirst = leading.filter {
            guard let first = $0.text.split(separator: " ").first else { return false }
            return isCodeToken(String(first))
        }
        return codeFirst.count * 2 > leading.count
    }

    /// One reverse half's pairs — the code opens the row and the name follows it.
    ///
    /// - Parameter lines: The half's lines, geometry-ordered.
    /// - Returns: The pairs found.
    static func reversePairs(inHalf lines: [PageLine]) -> [(name: String, code: String)] {
        let grouped = rows(lines)
        guard let codeX = nameColumn(of: grouped) else { return [] }
        var out: [(name: String, code: String)] = []
        var code: String?
        var name: [String] = []

        func close() {
            let joined = OutlineEntryParser.tidy(name.joined(separator: " "))
            if let code, !joined.isEmpty { out.append((joined, code)) }
            code = nil
            name = []
        }

        for row in grouped {
            if row.x <= codeX + 6, let (head, rest) = splitLeadingCode(row.text) {
                close()
                code = head
                name = rest.isEmpty ? [] : [rest]
            } else if code != nil {
                name.append(row.text)
            }
        }
        close()
        return out
    }

    /// Splits a reverse row into its leading code and the name after it.
    ///
    /// - Parameter text: A joined row.
    /// - Returns: The code and the name, or `nil` when the row does not open with a code.
    static func splitLeadingCode(_ text: String) -> (String, String)? {
        let tokens = text.split(separator: " ").map(String.init)
        var cut = 0
        while cut < tokens.count, isCodeToken(tokens[cut]) { cut += 1 }
        // All code and no name is the code column's own line; no code at all is a wrapped name.
        guard cut > 0, cut < tokens.count else { return nil }
        return (tokens[..<cut].joined(separator: " "),
                tokens[cut...].joined(separator: " "))
    }

    /// Where the name column stands, as the BUSIEST row start rather than the leftmost.
    ///
    /// ## A minimum is one stray mark away from silencing a whole half-page
    /// Taking the leftmost row start reads this appendix correctly wherever the scan is clean, and
    /// yields NOTHING on a page carrying a speck, a bleed-through or a spine artifact further out:
    /// every real row then fails the `<= nameX + 6` test and no entry is ever opened. It does not
    /// fail loudly — the half simply contributes nothing, and the table comes out thin. Measured
    /// with the minimum, the appendix gave 380 pairs from 864 rows while a clean page gave 49 from
    /// 67, which is the signature of exactly this.
    ///
    /// The names outnumber everything else on the page, so their column is the modal one.
    ///
    /// - Parameter rows: The half's rows.
    /// - Returns: The column's left edge, or `nil` when the half has no rows.
    static func nameColumn(of rows: [(text: String, x: Double)]) -> Double? {
        var histogram: [Int: Int] = [:]
        for row in rows { histogram[Int(row.x / 5) * 5, default: 0] += 1 }
        guard let (bucket, _) = histogram.max(by: { $0.value < $1.value }) else { return nil }
        return Double(bucket)
    }

    /// Groups a half's lines into rows, keeping each row's leftmost edge.
    ///
    /// - Parameter lines: Geometry-ordered lines.
    /// - Returns: One entry per row.
    static func rows(_ lines: [PageLine]) -> [(text: String, x: Double)] {
        var out: [(text: String, x: Double)] = []
        var bucket: [PageLine] = []

        func flush() {
            guard !bucket.isEmpty else { return }
            let sorted = bucket.sorted { $0.x < $1.x }
            // The code column is far enough right that a joined row still reads name-then-code.
            out.append((sorted.map(\.text).joined(separator: " "), sorted[0].x))
            bucket = []
        }

        for line in lines {
            if let firstLine = bucket.first, abs(firstLine.y - line.y) > 5 { flush() }
            bucket.append(line)
        }
        flush()
        return out
    }

    /// Splits a row into its name and the code welded to its end, when there is one.
    ///
    /// The code is the maximal run of ALL-CAPS tokens closing the row — `Bougainville Island SOL
    /// IS` and `Branco Island CAPE VERDE IS` both divide correctly, and a name that merely ends in
    /// a capitalised word does not, because a name's words are Title Case rather than caps.
    ///
    /// - Parameter text: A joined row.
    /// - Returns: The name and the code, the code being `nil` when the row carries none.
    static func splitTrailingCode(_ text: String) -> (String, String?) {
        let tokens = text.split(separator: " ").map(String.init)
        var cut = tokens.count
        while cut > 0, isCodeToken(tokens[cut - 1]) { cut -= 1 }
        // A row that is ALL code is a code column's own line, not a name.
        guard cut > 0, cut < tokens.count else { return (text, nil) }
        return (tokens[..<cut].joined(separator: " "), tokens[cut...].joined(separator: " "))
    }

    /// Whether a whole row is a code rather than a name.
    ///
    /// - Parameter text: A joined row.
    /// - Returns: `true` when every token is a code token.
    static func isCode(_ text: String) -> Bool {
        let tokens = text.split(separator: " ").map(String.init)
        return !tokens.isEmpty && tokens.allSatisfy(isCodeToken)
    }

    /// Whether one token could belong to a code: capitals and digits, no lower case.
    ///
    /// - Parameter token: A row token.
    /// - Returns: `true` when the token is code-shaped.
    static func isCodeToken(_ token: String) -> Bool {
        let stripped = token.trimmingCharacters(in: CharacterSet(charactersIn: ".,()"))
        guard !stripped.isEmpty, stripped.count <= 12 else { return false }
        guard stripped.contains(where: { $0.isLetter }) else { return false }
        return !stripped.contains { $0.isLowercase }
    }
}

// MARK: - Choosing a code's own name

extension CountryAbbreviationReader {

    /// The weakest reading of a code accepted as its name.
    ///
    /// **3, a FULL cover: every token of the code accounts for a word of the name, and every word
    /// is accounted for.** A partial cover was tried and ships wrong answers, not thin ones:
    /// `GER W` matched *Saar (West Germany)* — GER on GERMANY, W on WEST, with SAAR left over —
    /// so a caption reading "Saar" would have stood over every West German document in the
    /// corpus. A place filed UNDER a code is not what the code means, and nothing short of a full
    /// cover distinguishes the two.
    static let minimumHeadEntryScore = 3

    /// Inverts the appendix: for each code, the name it was abbreviated FROM.
    ///
    /// - Parameter pairs: Every (name, code) row the appendix prints.
    /// - Returns: `code -> name`, holding only the codes whose head entry could be identified.
    static func canonicalNames(from pairs: [(name: String, code: String)]) -> [String: String] {
        var best: [String: (name: String, score: Int)] = [:]
        for pair in pairs {
            let code = normalizedCode(pair.code)
            guard !code.isEmpty else { continue }
            let score = headEntryScore(name: pair.name, code: code)
            guard score >= minimumHeadEntryScore else { continue }
            // Ties go to the SHORTER name, which is the plain country rather than a place inside
            // it: `VIET S` scores on both `Vietnam, South` and `Vietnam, South (Saigon)`.
            let existing = best[code]
            if existing == nil || score > existing!.score
                || (score == existing!.score && pair.name.count < existing!.name.count) {
                best[code] = (pair.name, score)
            }
        }
        return best.mapValues(\.name)
    }

    /// How well a name reads as the source of a code.
    ///
    /// ## The code's tokens do not follow the name's word order
    /// The appendix inverts names for alphabetising and the codes do not follow: `VIET S` is
    /// printed against *South Vietnam*, and `THE CONGO` against *Congo, Republic of the*. A test
    /// that walked the two in step scored both at zero — measured, it left the two heaviest tails
    /// in the corpus unnamed while resolving their neighbours, which reads as a thin table rather
    /// than as a wrong rule. So each code token is matched to SOME distinct word of the name.
    ///
    /// Covering every word scores higher than covering some, which is what keeps `VIET S` on
    /// *South Vietnam* rather than on a district inside it.
    ///
    /// The initials reading is separate and weaker: `BWI` is *British West Indies* and `US` is
    /// *United States of America*, where the code stops short of the name's own initials — so the
    /// test is a PREFIX of them, and it skips the words English does not initialise.
    ///
    /// - Parameters:
    ///   - name: A candidate name.
    ///   - code: The normalized code.
    /// - Returns: 3 for a full cover, 2 for a partial one, 1 for the initials reading, 0 for none.
    static func headEntryScore(name: String, code: String) -> Int {
        let words = name.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map { $0.uppercased() }
        guard !words.isEmpty else { return 0 }
        let codeTokens = code.split(separator: " ").map(String.init)

        var unused = words
        var matchedAll = true
        for token in codeTokens {
            if let index = unused.firstIndex(where: { $0.hasPrefix(token) }) {
                unused.remove(at: index)
            } else {
                matchedAll = false
                break
            }
        }
        if matchedAll { return unused.isEmpty ? 3 : 2 }

        let significant = words.filter { !Self.unInitialised.contains($0) }
        let initials = significant.compactMap(\.first).map(String.init).joined()
        let flat = code.replacingOccurrences(of: " ", with: "")
        if !flat.isEmpty, initials.hasPrefix(flat) { return 1 }
        return 0
    }

    /// The words an English abbreviation passes over.
    static let unInitialised: Set<String> = ["OF", "THE", "AND", "DE", "DU", "LA", "EL"]

    /// A code as the corpus writes it: upper-cased, punctuation dropped, spacing collapsed.
    ///
    /// - Parameter raw: A code as the appendix prints it.
    /// - Returns: The normalized form.
    static func normalizedCode(_ raw: String) -> String {
        raw.uppercased()
            .replacingOccurrences(of: #"[^A-Z0-9 -]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
}
