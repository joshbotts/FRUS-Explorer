// Search/SearchEngine.swift
// Full-text search across loaded FRUS volumes, generated summaries, and research annotations.
//
// Query language reference:
//   kissinger vietnam          – implicit AND (both words must appear)
//   "national security"        – exact phrase
//   kissinger AND (vietnam OR cambodia) – explicit boolean with grouping
//   NOT vietnam  /  -vietnam   – negation
//   kiss*                      – wildcard prefix
//   person:Kissinger           – match only <persName> elements
//   place:Vietnam              – match only <placeName> elements
//   org:NSC                    – match only <orgName> elements
//   term:MIRV                  – match only <term> elements (abbreviations, diplomatic terms)
//   date:1969                  – documents dated in 1969
//   date:1969-03..1969-06      – date range (inclusive)
//   after:1969-06-01           – documents after this date
//   before:1970-01-01          – documents before this date

import Foundation
import FRUSKit

// MARK: - SearchRecord

/// One indexed, searchable unit — a document-level or section division.
struct SearchRecord: Identifiable, Sendable {
    /// Matches OutlineNode.id format: "\(volumeID)__\(divisionID)"
    let id: String
    let volumeID: String
    let divisionID: String

    let title: String
    let dateline: String?
    let isEditorialNote: Bool

    /// ISO-format date from the first @when attribute in the dateline.
    /// May be partial: "1969", "1969-03", or "1969-03-15".
    let isoDate: String?

    /// Lowercased, whitespace-normalised concatenation of all body paragraphs.
    let normalizedBody: String

    // Structured entities extracted from TEI markup
    let personNames: [String]   // lowercased, de-duped
    let placeNames:  [String]
    let orgNames:    [String]
    let terms:       [String]   // diplomatic terms and abbreviations
}

// MARK: - SearchResult

struct SearchResult: Identifiable, Sendable {
    let id: String              // same as SearchRecord.id
    let record: SearchRecord
    let matchedFields: Set<MatchField>

    enum MatchField: Hashable, Sendable {
        case title, body, person, place, org, term, summary, annotation, date
    }
}

// MARK: - DateFilter

struct DateFilter: Sendable {

    enum Bound: Sendable {
        case year(Int)
        case yearMonth(Int, Int)
        case full(Int, Int, Int)

        var prefix: String {
            switch self {
            case .year(let y):               return String(format: "%04d", y)
            case .yearMonth(let y, let m):   return String(format: "%04d-%02d", y, m)
            case .full(let y, let m, let d): return String(format: "%04d-%02d-%02d", y, m, d)
            }
        }
    }

    var from: Bound?
    var to: Bound?

    var isEmpty: Bool { from == nil && to == nil }

    func matches(_ isoDate: String?) -> Bool {
        guard let isoDate, !isoDate.isEmpty else { return false }
        if let from, isoDate < from.prefix { return false }
        if let to {
            let ceiling: String
            switch to {
            case .year(let y):               ceiling = String(format: "%04d-99", y)
            case .yearMonth(let y, let m):   ceiling = String(format: "%04d-%02d-99", y, m)
            case .full(let y, let m, let d): ceiling = String(format: "%04d-%02d-%02d", y, m, d)
            }
            if isoDate > ceiling { return false }
        }
        return true
    }
}

// MARK: - Query AST

indirect enum SearchPredicate: Sendable {
    case keyword(String, wildcard: Bool)
    case phrase(String)
    case field(FieldType, String)
    case dateFilter(DateFilter)
    case not(SearchPredicate)
    case and([SearchPredicate])
    case or([SearchPredicate])

    enum FieldType: Sendable { case person, place, org, term }
}

// MARK: - Query parser

enum SearchQueryParser {

    static func parse(_ input: String) -> SearchPredicate? {
        var tokens = tokenize(input)
        return parseOr(&tokens)
    }

    // MARK: Tokens

    private enum Token {
        case word(String), phrase(String), and, or, not, minus, lparen, rparen, eof
    }

    private static func tokenize(_ input: String) -> [Token] {
        var tokens: [Token] = []
        var i = input.startIndex
        while i < input.endIndex {
            let c = input[i]
            if c.isWhitespace  { i = input.index(after: i); continue }
            if c == "(" { tokens.append(.lparen); i = input.index(after: i); continue }
            if c == ")" { tokens.append(.rparen); i = input.index(after: i); continue }
            if c == "-" { tokens.append(.minus);  i = input.index(after: i); continue }
            if c == "\"" {
                var j = input.index(after: i)
                while j < input.endIndex, input[j] != "\"" { j = input.index(after: j) }
                tokens.append(.phrase(String(input[input.index(after: i)..<j]).lowercased()))
                i = j < input.endIndex ? input.index(after: j) : input.endIndex
                continue
            }
            var j = i
            while j < input.endIndex, !input[j].isWhitespace,
                  input[j] != "(", input[j] != ")" { j = input.index(after: j) }
            let word = String(input[i..<j])
            switch word.uppercased() {
            case "AND": tokens.append(.and)
            case "OR":  tokens.append(.or)
            case "NOT": tokens.append(.not)
            default:    tokens.append(.word(word))
            }
            i = j
        }
        tokens.append(.eof)
        return tokens
    }

    // MARK: Recursive descent (OR < AND < NOT < atom)

    private static func peek(_ t: [Token]) -> Token { t.first ?? .eof }

    private static func parseOr(_ tokens: inout [Token]) -> SearchPredicate? {
        guard let left = parseAnd(&tokens) else { return nil }
        var parts = [left]
        while case .or = peek(tokens) {
            tokens.removeFirst()
            if let r = parseAnd(&tokens) { parts.append(r) }
        }
        return parts.count == 1 ? parts[0] : .or(parts)
    }

    private static func parseAnd(_ tokens: inout [Token]) -> SearchPredicate? {
        guard let left = parseNot(&tokens) else { return nil }
        var parts = [left]
        loop: while true {
            switch peek(tokens) {
            case .and:
                tokens.removeFirst()
                if let r = parseNot(&tokens) { parts.append(r) }
            case .or, .rparen, .eof: break loop
            default:
                guard let r = parseNot(&tokens) else { break loop }
                parts.append(r)
            }
        }
        return parts.count == 1 ? parts[0] : .and(parts)
    }

    private static func parseNot(_ tokens: inout [Token]) -> SearchPredicate? {
        switch peek(tokens) {
        case .not, .minus:
            tokens.removeFirst()
            return parseAtom(&tokens).map { .not($0) }
        default:
            return parseAtom(&tokens)
        }
    }

    private static func parseAtom(_ tokens: inout [Token]) -> SearchPredicate? {
        switch peek(tokens) {
        case .lparen:
            tokens.removeFirst()
            let p = parseOr(&tokens)
            if case .rparen = peek(tokens) { tokens.removeFirst() }
            return p
        case .phrase(let p):
            tokens.removeFirst()
            return .phrase(p)
        case .word(let w):
            tokens.removeFirst()
            return interpretWord(w)
        default:
            return nil
        }
    }

    private static func interpretWord(_ w: String) -> SearchPredicate? {
        if let colon = w.firstIndex(of: ":") {
            let field = String(w[..<colon]).lowercased()
            let value = String(w[w.index(after: colon)...])
            switch field {
            case "person": return .field(.person, value.lowercased())
            case "place":  return .field(.place,  value.lowercased())
            case "org":    return .field(.org,    value.lowercased())
            case "term":   return .field(.term,   value.lowercased())
            case "date":   return parseDate(value, mode: .range)
            case "after":  return parseDate(value, mode: .after)
            case "before": return parseDate(value, mode: .before)
            default: break
            }
        }
        let lower = w.lowercased()
        return lower.hasSuffix("*")
            ? .keyword(String(lower.dropLast()), wildcard: true)
            : .keyword(lower, wildcard: false)
    }

    private enum DateMode { case range, after, before }

    private static func parseDate(_ spec: String, mode: DateMode) -> SearchPredicate? {
        if let r = spec.range(of: "..") {
            var f = DateFilter()
            f.from = parseBound(String(spec[..<r.lowerBound]))
            f.to   = parseBound(String(spec[r.upperBound...]))
            return .dateFilter(f)
        }
        guard let bound = parseBound(spec) else { return nil }
        var f = DateFilter()
        switch mode {
        case .range:  f.from = bound; f.to = bound
        case .after:  f.from = bound
        case .before: f.to   = bound
        }
        return .dateFilter(f)
    }

    private static func parseBound(_ s: String) -> DateFilter.Bound? {
        let parts = s.split(separator: "-", omittingEmptySubsequences: false)
        switch parts.count {
        case 1: return Int(parts[0]).map { .year($0) }
        case 2:
            guard let y = Int(parts[0]), let m = Int(parts[1]) else { return nil }
            return .yearMonth(y, m)
        case 3:
            guard let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { return nil }
            return .full(y, m, d)
        default: return nil
        }
    }
}

// MARK: - Search engine

/// Thread-safe, actor-isolated search engine.
/// Indexes are built off the main thread and added here; searches run off the main thread.
actor SearchEngine {

    private var indexes: [String: [SearchRecord]] = [:]

    func addIndex(volumeID: String, records: [SearchRecord]) {
        indexes[volumeID] = records
    }

    func removeIndex(volumeID: String) {
        indexes.removeValue(forKey: volumeID)
    }

    var indexedVolumeCount: Int { indexes.count }

    // MARK: Search

    func search(
        queryString: String,
        explicitDateFilter: DateFilter? = nil,
        summaries: [String: String],
        annotations: [String: String]
    ) -> [SearchResult] {
        // Build combined predicate
        var predicates: [SearchPredicate] = []
        let trimmed = queryString.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, let p = SearchQueryParser.parse(trimmed) {
            predicates.append(p)
        }
        if let df = explicitDateFilter, !df.isEmpty {
            predicates.append(.dateFilter(df))
        }
        guard !predicates.isEmpty else { return [] }
        let predicate: SearchPredicate = predicates.count == 1 ? predicates[0] : .and(predicates)

        var results: [SearchResult] = []
        for records in indexes.values {
            for record in records {
                let summary    = summaries[record.id]
                let annotation = annotations[record.id]
                if let fields = evaluate(predicate, record: record,
                                         summary: summary, annotation: annotation) {
                    results.append(SearchResult(id: record.id, record: record, matchedFields: fields))
                }
            }
        }

        // Sort most-recent-first, then by stable ID
        results.sort {
            let da = $0.record.isoDate ?? "0000"
            let db = $1.record.isoDate ?? "0000"
            return da != db ? da > db : $0.record.id < $1.record.id
        }
        return results
    }

    // MARK: Predicate evaluation

    private func evaluate(
        _ pred: SearchPredicate,
        record: SearchRecord,
        summary: String?,
        annotation: String?
    ) -> Set<SearchResult.MatchField>? {
        switch pred {
        case .keyword(let w, let wildcard):
            return matchKeyword(w, wildcard: wildcard,
                                record: record, summary: summary, annotation: annotation)
        case .phrase(let p):
            return matchPhrase(p, record: record, summary: summary, annotation: annotation)
        case .field(let type, let value):
            return matchField(type, value: value, record: record)
        case .dateFilter(let df):
            return df.matches(record.isoDate) ? [.date] : nil
        case .not(let inner):
            return evaluate(inner, record: record,
                            summary: summary, annotation: annotation) == nil ? [] : nil
        case .and(let preds):
            var combined: Set<SearchResult.MatchField> = []
            for p in preds {
                guard let f = evaluate(p, record: record,
                                       summary: summary, annotation: annotation) else { return nil }
                combined.formUnion(f)
            }
            return combined
        case .or(let preds):
            var combined: Set<SearchResult.MatchField> = []
            var any = false
            for p in preds {
                if let f = evaluate(p, record: record,
                                    summary: summary, annotation: annotation) {
                    combined.formUnion(f); any = true
                }
            }
            return any ? combined : nil
        }
    }

    // MARK: Keyword matching (whole-word, optional prefix wildcard)

    private func matchKeyword(
        _ word: String, wildcard: Bool,
        record: SearchRecord, summary: String?, annotation: String?
    ) -> Set<SearchResult.MatchField>? {
        var matched: Set<SearchResult.MatchField> = []
        let escaped = NSRegularExpression.escapedPattern(for: word)
        let pattern = wildcard ? "\\b\(escaped)\\w*" : "\\b\(escaped)\\b"
        let opts: String.CompareOptions = [.regularExpression, .caseInsensitive]

        if record.title.range(of: pattern, options: opts) != nil          { matched.insert(.title) }
        if record.normalizedBody.range(of: pattern, options: opts) != nil { matched.insert(.body)  }
        if let s = summary,    s.range(of: pattern, options: opts) != nil { matched.insert(.summary) }
        if let a = annotation, a.range(of: pattern, options: opts) != nil { matched.insert(.annotation) }

        let entityHit = { (list: [String]) -> Bool in
            wildcard ? list.contains { $0.hasPrefix(word) } : list.contains { $0 == word }
        }
        if entityHit(record.personNames) { matched.insert(.person) }
        if entityHit(record.placeNames)  { matched.insert(.place)  }
        if entityHit(record.orgNames)    { matched.insert(.org)    }
        if entityHit(record.terms)       { matched.insert(.term)   }

        return matched.isEmpty ? nil : matched
    }

    // MARK: Phrase matching (substring, case-insensitive)

    private func matchPhrase(
        _ phrase: String,
        record: SearchRecord, summary: String?, annotation: String?
    ) -> Set<SearchResult.MatchField>? {
        var matched: Set<SearchResult.MatchField> = []
        if record.title.lowercased().contains(phrase)        { matched.insert(.title) }
        if record.normalizedBody.contains(phrase)            { matched.insert(.body)  }
        if summary?.lowercased().contains(phrase) == true    { matched.insert(.summary) }
        if annotation?.lowercased().contains(phrase) == true { matched.insert(.annotation) }
        return matched.isEmpty ? nil : matched
    }

    // MARK: Entity field matching (substring within entity list entries)

    private func matchField(
        _ type: SearchPredicate.FieldType, value: String, record: SearchRecord
    ) -> Set<SearchResult.MatchField>? {
        let (list, field): ([String], SearchResult.MatchField)
        switch type {
        case .person: (list, field) = (record.personNames, .person)
        case .place:  (list, field) = (record.placeNames,  .place)
        case .org:    (list, field) = (record.orgNames,    .org)
        case .term:   (list, field) = (record.terms,       .term)
        }
        return list.contains(where: { $0.contains(value) }) ? [field] : nil
    }
}

// MARK: - Index builder

/// Builds a flat `[SearchRecord]` from every indexable division in a volume.
/// Designed to be called from a `Task.detached` alongside XML parsing.
enum SearchIndexBuilder {

    static func build(from volume: FRUSVolume, volumeID: String) -> [SearchRecord] {
        var records: [SearchRecord] = []
        let sections: [[Division]] = [
            volume.text.body.divisions,
            volume.text.front?.divisions ?? [],
            volume.text.back?.divisions  ?? [],
        ]
        for section in sections {
            for div in section { collect(div, volumeID: volumeID, into: &records) }
        }
        return records
    }

    private static func collect(
        _ div: Division, volumeID: String, into records: inout [SearchRecord]
    ) {
        let shouldIndex: Bool
        switch div.type {
        case .document, .preface, .sources, .persons,
             .terms, .appendix, .index, .section: shouldIndex = true
        default: shouldIndex = false
        }
        if shouldIndex, let divID = div.id {
            records.append(makeRecord(div, volumeID: volumeID, divisionID: divID))
        }
        for child in div.children { collect(child, volumeID: volumeID, into: &records) }
    }

    private static func makeRecord(
        _ div: Division, volumeID: String, divisionID: String
    ) -> SearchRecord {
        // Title — mirrors OutlineBuilder.divNode logic
        let subjectHeading = div.headings.first(where: { $0.type == "subject" })
            ?? (div.headings.count > 1 ? div.headings[1] : nil)
        let subjectText = subjectHeading.map { plainText(from: $0.content) }
            ?? div.headings.first.map { plainText(from: $0.content) }
            ?? "Document"
        let title = div.number.map { "\($0). \(subjectText)" } ?? subjectText

        let dateline = div.dateline.map {
            plainText(from: $0.content).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let isoDate = div.dateline?.dates.first?.when

        // Body text — paragraphs, opener, closer (not footnotes)
        var bodyParts: [String] = div.paragraphs.map { plainText(from: $0.content) }
        if let op = div.opener { bodyParts.append(plainText(from: op.content)) }
        if let cl = div.closer { bodyParts.append(plainText(from: cl.content)) }

        // Entity extraction (recursive through inline markup)
        var persons: Set<String> = []
        var places:  Set<String> = []
        var orgs:    Set<String> = []
        var terms:   Set<String> = []

        func extract(_ content: [InlineContent]) {
            for item in content {
                switch item {
                case .persName(let p):  persons.insert(p.text.lowercased())
                case .placeName(let p): places.insert(p.text.lowercased())
                case .orgName(let o):   orgs.insert(o.text.lowercased())
                case .term(let t):      terms.insert(t.text.lowercased())
                case .hi(let h):        extract(h.content)
                case .list(let l):      l.items.forEach { extract($0.content) }
                default: break
                }
            }
        }
        for para in div.paragraphs { extract(para.content) }
        if let op = div.opener { extract(op.content) }
        if let cl = div.closer { extract(cl.content) }
        for note in div.notes  { note.paragraphs.forEach { extract($0.content) } }

        return SearchRecord(
            id: "\(volumeID)__\(divisionID)",
            volumeID: volumeID,
            divisionID: divisionID,
            title: title,
            dateline: dateline,
            isEditorialNote: false,
            isoDate: isoDate,
            normalizedBody: bodyParts.joined(separator: " ").lowercased(),
            personNames: Array(persons),
            placeNames:  Array(places),
            orgNames:    Array(orgs),
            terms:       Array(terms)
        )
    }
}
