// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CountryAbbreviationReader

/// Reads the handbooks' COUNTRY ABBREVIATIONS appendix — the vocabulary of the tail that 90% of
/// the corpus's subject-numeric keys carry (#1254).
///
/// ## The first table runs the wrong way for the question, and the second the right way
/// It is a finding aid, so its first table maps NAME to CODE and does so many-to-one: every
/// island of the British West Indies is its own row against `BWI`. What a reader needs is the
/// other direction — given `VIET S`, what is it — and inverting that table leaves a code holding
/// a list of names, most of which are not what the code is called.
///
/// The appendix is printed a second time from CODE to NAME, and since #1644 that is where a
/// code's name is taken from (``codeNames(from:verified:)``): the row states it, where the first
/// table only lets one be chosen. The first table checks the second's spelling, and every row of
/// both is a name the resolver may match a tail to when no printed code answers. A code that no
/// row names cleanly is left unnamed rather than given the first row that mentioned it.
///
/// Version history:
///   1.0 — #1254: initial implementation
///   1.1 — #1644: reads ``Handbook`` pages; each row says which of the appendix's two tables it
///          is from, and `codeNames(from:verified:)` gives each printed code its own name
enum CountryAbbreviationReader {

    /// Whether a page belongs to the country appendix, by its own corner mark.
    ///
    /// - Parameter page: The page to test.
    /// - Returns: `true` when the page is part of the appendix.
    static func isCountryPage(_ page: HandbookPage) -> Bool {
        let text = page.text(inTop: 60)
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
    /// - Returns: The pairs, in page order, each marked with the table it was read from:
    ///   `reverse` is `true` for a row of the code-first table, which states a code's own name.
    static func pairs(in document: Handbook) -> [(name: String, code: String, reverse: Bool)] {
        let marked = document.pages.indices.filter { isCountryPage(document.pages[$0]) }
        guard let first = marked.first, let last = marked.last else { return [] }
        var out: [(name: String, code: String, reverse: Bool)] = []
        for page in document.pages[first...last] {
            // A section letter stands at the head of each letter of the alphabet, set large.
            // Left in, it is read as the last word of the name above it (`Turkey u`).
            let lines = page.lines.filter {
                $0.y > 100 && !OutlineEntryParser.isFurniture($0.text)
                    && !($0.text.count == 1 && $0.height >= sectionLetterHeight)
            }
            let middle = page.width / 2
            let halves = [lines.filter { $0.x < middle }, lines.filter { $0.x >= middle }]
            // DIRECTION IS A PROPERTY OF THE PAGE, not of a half. Deciding per half lets a few
            // OCR-damaged leading tokens flip one side of a reverse page into the forward reading,
            // whose parser then takes the code as part of the name — measured, that is where names
            // like `& NYAS Rhodesia and Nyasaland Federation` came from. Both halves vote.
            let reverse = isReverseHalf(halves[0]) || isReverseHalf(halves[1])
            for half in halves {
                let found = reverse ? reversePairs(inHalf: half) : pairs(inHalf: half)
                out.append(contentsOf: found.map { ($0.name, $0.code, reverse) })
            }
        }
        return out
    }

    /// The least type size of a section letter: the appendix's text is set at nine points and
    /// its section letters at fifteen and over.
    static let sectionLetterHeight = 13.0

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
            // A ROW AT THE CODE COLUMN IS A NEW ENTRY, whatever condition the scan left it in.
            // Letting one that fails to parse fall through to the continuation branch glues it to
            // the entry above: measured, that produced names like `0 Pacific Ocean PAl<: Pakistan`
            // and `& NYAS Rhodesia and Nyasaland Federation` — two entries in one string, and the
            // leading junk (`&`, `0`) is why the row failed to open in the first place.
            guard row.x > codeX + 6 else {
                close()
                if let (head, rest) = splitLeadingCode(row.text) {
                    code = head
                    name = rest.isEmpty ? [] : [rest]
                }
                continue
            }
            if code != nil { name.append(row.text) }
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

// MARK: - The printed code table

extension CountryAbbreviationReader {

    /// The name the appendix gives each code it prints (#1644).
    ///
    /// ## The code-first table says it outright, and the name-first table checks its spelling
    /// The appendix is printed twice. Its second table runs from code to name and gives each
    /// code ITS OWN name, followed in parentheses by the places filed under it: `UK United
    /// Kingdom (England, Great Britain, Wales)`. The first runs from name to code and files many
    /// places under one: `England (United Kingdom) UK`. So a code's name is the second table's
    /// row with its parenthesis dropped, or a row of the first table that has no parenthesis.
    ///
    /// Both are a rough scan (`Belgimn`, `Sam.a.li Republic`, `Yugoslovia`), and seldom in the
    /// same place. A candidate is therefore taken in this order: one the decimal schedules'
    /// country tables also carry, which are verified; one both tables print alike; the
    /// code-first table's, if it is clean text; the name-first table's only plain name, if it
    /// is. A code none of these names is left out, and its tail is read from the names instead.
    ///
    /// - Parameters:
    ///   - pairs: Every row the appendix prints.
    ///   - verified: Names whose spelling is known good.
    /// - Returns: `code key -> name`, keyed by ``AreaResolver/codeKey(_:)``.
    static func codeNames(from pairs: [(name: String, code: String, reverse: Bool)],
                          verified: Set<String>) -> [String: String] {
        var rows: [String: [(name: String, reverse: Bool)]] = [:]
        var order: [String] = []
        for pair in pairs {
            let key = AreaResolver.codeKey(AreaResolver.normalized(pair.code))
            guard !key.isEmpty else { continue }
            if rows[key] == nil { order.append(key) }
            rows[key, default: []].append((pair.name, pair.reverse))
        }
        var out: [String: String] = [:]
        for key in order {
            let found = rows[key] ?? []
            // A NAME IS A CODE'S ONLY IF THE CODE ABBREVIATES IT. The scan misreads codes as
            // well as names, and a row whose code is misread pairs a real code with another
            // place's name: `PORT INDIA`, its first word lost, gave `INDIA` the name
            // *Portuguese India*, and a row split after its first letter gave `S` the whole of
            // South Viet-Nam's.
            let own = found.filter(\.reverse).map { ownName($0.name) }
                .filter { abbreviates(key, $0) }
            let plain = found.filter { !$0.reverse && !$0.name.contains("(") }
                .map { trimmedName($0.name) }.filter { abbreviates(key, $0) }
            if let name = (own + plain).first(where: verified.contains) {
                out[key] = name
            } else if let name = (own + plain).lazy
                        .compactMap({ shortForm(of: $0, among: verified) }).first {
                out[key] = name
            } else if let name = own.first(where: plain.contains) {
                out[key] = name
            } else if own.count == 1, isCleanName(own[0]) {
                out[key] = own[0]
            } else if own.isEmpty || !own.contains(where: isCleanName),
                      Set(plain).count == 1, isCleanName(plain[0]) {
                out[key] = plain[0]
            }
        }
        return out
    }

    /// The verified name a printed name only adds a formal ending to, if there is one.
    ///
    /// The appendix names a state in full, inverted for the index: *United States of America*,
    /// *Kuwait, State of*, *Guinea, Republic of*. The decimal schedules' tables carry the same
    /// countries as *United States*, *Kuwait* and *Guinea*, verified and already what the app
    /// calls them, and `US` stands in some five hundred paired tails. So where a verified name
    /// is the printed one less such an ending, the verified name is the code's.
    ///
    /// - Parameters:
    ///   - name: A code-first row's name.
    ///   - verified: Names whose spelling is known good.
    /// - Returns: The verified name, or `nil` when the printed name is not one with an ending.
    static func shortForm(of name: String, among verified: Set<String>) -> String? {
        for ending in formalEndings {
            guard let range = name.range(of: ending, options: [.regularExpression,
                                                               .caseInsensitive]) else { continue }
            let head = String(name[..<range.lowerBound])
            if verified.contains(head) { return head }
        }
        return nil
    }

    /// The endings the appendix adds to a country's plain name.
    private static let formalEndings = [
        #" of America$"#,
        #", (?:State|Republic|Federation|Kingdom|Federal Republic|Islamic Republic) of(?: the)?$"#,
    ]

    /// A code-first row's name, without the places filed under the code.
    ///
    /// - Parameter name: `Canada (Alberta, British Columbia, …)`.
    /// - Returns: `Canada`.
    static func ownName(_ name: String) -> String {
        guard let open = name.range(of: " (") else { return trimmedName(name) }
        return trimmedName(String(name[..<open.lowerBound]))
    }

    /// A name without the marks the scan leaves at its ends (`Canada.`, `Mexico'`).
    ///
    /// The full stop of an initial is the name's own and is kept (`Canal Zone, U. S.`).
    ///
    /// - Parameter name: A name as read.
    /// - Returns: The name, trimmed.
    static func trimmedName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: CharacterSet(charactersIn: " .,;:'\"~"))
        let initial = #"(?:^| )[A-Z]$"#
        guard name.contains(trimmed + "."),
              trimmed.range(of: initial, options: .regularExpression) != nil
        else { return trimmed }
        return trimmed + "."
    }

    /// Whether a code can be an abbreviation of a name: they begin with the same letter, and
    /// the code's letters all occur in the name, in order.
    ///
    /// Loose on purpose. The printed codes are contractions as often as they are first letters
    /// (`NR EAST` for *Near East*, `AUSTL` for *Australia*, `CZ` for *Canal Zone*), and all this
    /// has to refuse is a name that belongs to another code.
    ///
    /// - Parameters:
    ///   - key: A code's key (its tokens, spaced).
    ///   - name: A candidate name.
    /// - Returns: `true` when the code's letters run through the name's.
    static func abbreviates(_ key: String, _ name: String) -> Bool {
        let letters = name.uppercased().filter(\.isLetter)
        guard let first = letters.first else { return false }
        // The key's tokens are sorted, so the code's own first letter is not known from it:
        // any token may open the code, and one of them must open the name.
        let tokens = key.split(separator: " ").map { $0.filter(\.isLetter) }
        guard tokens.contains(where: { $0.first == first }) else { return false }
        return tokens.allSatisfy { token in
            var rest = Substring(letters)
            for letter in token {
                guard let found = rest.firstIndex(of: letter) else { return false }
                rest = rest[rest.index(after: found)...]
            }
            return true
        }
    }

    /// Whether a name is made of words alone: letters, with a space, a hyphen, a comma and a
    /// space, a full stop and a space, or an apostrophe between them.
    ///
    /// - Parameter name: A candidate name.
    /// - Returns: `false` for a name the scan has visibly damaged (`Det:lIl:l.S.!'k`).
    static func isCleanName(_ name: String) -> Bool {
        // The last full stop is an initial's (`Canal Zone, U. S.`), and only that.
        name.range(of: #"^[A-Z][A-Za-z]*(?:(?:[ -]|, |\. |')[A-Za-z]+)*(?:(?<= [A-Z])\.)?$"#,
                   options: .regularExpression) != nil
    }
}
