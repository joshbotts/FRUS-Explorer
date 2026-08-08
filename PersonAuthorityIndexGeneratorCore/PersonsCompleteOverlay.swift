// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - PersonsCompleteOverlay

/// Reads `frus-name-authority/4_Outputs/persons-complete.xml` — the Office of the Historian's
/// name-reconciliation output — for two things the `HistoryAtState/people` registry does not
/// carry (#736, folding in #260).
///
/// 1. **Enrichment**: Wikidata QIDs, far more VIAF ids than the registry has, and short role text.
/// 2. **Crosswalk expansion**: 13,439 additional `(volume, anchor)` pairs across 56 more volumes,
///    lifting the app's coverage of its own person rows from 78.5% to 90.1%.
///
/// ## The anchor form, which the plan for this work got wrong
/// Both #260 and the Session-8 plan describe these anchors as `<source-url>` values. **This file
/// contains no `source-url` elements and no `historicaldocuments` URLs at all.** The anchors ride
/// on
///
/// ```xml
/// <idno type="frus-ref">frus1917-72PubDipv07/persons#p_AR_1</idno>
/// ```
///
/// The `source-url` form belongs to the *other* upstream repo, which
/// ``PersonAuthorityIndexBuilder`` reads. A parser written from the plan's description finds
/// nothing and reports success — measured, it returned 0 pairs from 30,776 correctly-read entries.
///
/// ## Three joining rules, none of them optional
/// - **Key strictly on `people-id`.** The `FRUS-NNNNN` `xml:id`s are renumbered between files and
///   upstream plans a v2 re-mint; only `people-id` survives it.
/// - **Take every `people-id` in an entry, not the first.** 64 entries carry several because they
///   are auto-merges, and 46 ids the app uses exist *only* as an entry's secondary idno. A
///   one-id-per-entry parse silently orphans them.
/// - **Skip audit-flagged entries.** 32 pairs in `merge_audit_report.csv` are `unmerge`,
///   `unmerge_likely`, or `uncertain` — auto-merges a human review rejected or doubted. Enriching
///   from them means attaching one person's Wikidata id to another person's record.
///
/// ## Why the audit guard needs the identifier the rules forbid
/// `merge_audit_report.csv`'s `pid_a`/`pid_b` columns hold **`FRUS-NNNNN` xml:ids, not
/// people-ids** — so the mandated guard can only be applied through the key that must never be
/// relied on across file versions. The resolution is legitimate but has exactly one safe form:
/// resolve the xml:ids to people-ids **inside this same file**, at generation time, and record the
/// resolved list in provenance. It cannot be recomputed later against a re-minted file, because by
/// then those xml:ids name different people. ``flaggedPeopleIds(auditCSV:entries:)`` does the
/// resolution and the runner pins the result.
public enum PersonsCompleteOverlay {

    // MARK: - Parsed entry

    /// One `<person>` from persons-complete, reduced to what this build uses.
    public struct Entry: Sendable, Equatable {
        /// The volatile `xml:id`. Kept **only** to resolve the audit CSV against this same file —
        /// never used to join to the app.
        public let xmlId: String?
        /// Every `people-id` idno on the entry, in document order.
        public let peopleIds: [String]
        /// `(volumeId, ref)` anchors from `frus-ref` idnos.
        public let anchors: [FRUSAnchor]
        /// Wikidata QID, if reconciled.
        public let wikidata: String?
        /// VIAF id, if reconciled.
        public let viaf: String?
        /// Occupation or bio text, whichever is present and shorter — see ``roleText(from:)``.
        public let role: String?
    }

    // MARK: - Parsing

    /// Splits the file into entries and parses each.
    ///
    /// Scans rather than building an `XMLDocument`: the file is 31 MB, and the sibling
    /// `persons.xml` is documented as not well-formed (13 broken entities), so a strict whole-file
    /// parse is a liability for a marginal gain on a flat, machine-generated structure.
    public static func parse(xml: String) -> [Entry] {
        var entries: [Entry] = []
        var cursor = xml.startIndex
        while let open = xml.range(of: "<person ", range: cursor..<xml.endIndex)
                ?? xml.range(of: "<person>", range: cursor..<xml.endIndex) {
            let close = xml.range(of: "</person>", range: open.upperBound..<xml.endIndex)
            let end = close?.lowerBound ?? xml.endIndex
            entries.append(parseEntry(String(xml[open.lowerBound..<end])))
            cursor = close?.upperBound ?? xml.endIndex
        }
        return entries
    }

    /// Parses a single `<person>…</person>` chunk.
    public static func parseEntry(_ chunk: String) -> Entry {
        var peopleIds: [String] = []
        var anchors: [FRUSAnchor] = []
        for (type, value) in idnos(in: chunk) {
            switch type {
            case "people-id":
                let trimmed = value.trimmed
                if !trimmed.isEmpty { peopleIds.append(trimmed) }
            case "frus-ref":
                if let anchor = parseFRUSRef(value) { anchors.append(anchor) }
            default:
                continue
            }
        }
        return Entry(xmlId: attribute("xml:id", in: chunk),
                     peopleIds: peopleIds,
                     anchors: anchors,
                     wikidata: identifier("wikidata", in: chunk),
                     viaf: identifier("viaf", in: chunk),
                     role: roleText(from: chunk))
    }

    /// `volume/persons#anchor` → an anchor. Returns `nil` for anything else.
    public static func parseFRUSRef(_ raw: String) -> FRUSAnchor? {
        let s = raw.trimmed
        guard let hash = s.firstIndex(of: "#") else { return nil }
        let head = s[s.startIndex..<hash]
        guard head.hasSuffix("/persons") else { return nil }
        let volume = String(head.dropLast("/persons".count))
        let ref = String(s[s.index(after: hash)...]).trimmed
        guard volume.hasPrefix("frus"), !ref.isEmpty else { return nil }
        return FRUSAnchor(volumeId: volume, ref: ref)
    }

    /// Role text for display: the occupation if present, else the bio note.
    ///
    /// Upstream duplicates the two on many entries, so taking both would ship the same sentence
    /// twice. Whitespace is collapsed because the source hard-wraps inside the element, which
    /// would otherwise reach the UI as newlines mid-sentence.
    public static func roleText(from chunk: String) -> String? {
        let raw = firstElementText("occupation", in: chunk)
            ?? noteText(type: "bio", in: chunk)
        guard let raw else { return nil }
        let collapsed = raw.split(whereSeparator: \.isWhitespace).joined(separator: " ").trimmed
        return collapsed.isEmpty ? nil : collapsed
    }

    // MARK: - The audit guard

    /// The `people-id`s of entries a human review flagged as wrongly or doubtfully merged.
    ///
    /// Resolves the CSV's `FRUS-NNNNN` xml:ids through `entries` — **the same file version** —
    /// because that is the only correspondence that exists. Measured on the current drop: 32
    /// flagged pairs, 62 distinct xml:ids, all 62 resolvable, yielding 30 distinct people-ids.
    ///
    /// - Parameter auditCSV: the raw text of `merge_audit_report.csv`.
    public static func flaggedPeopleIds(auditCSV: String, entries: [Entry]) -> Set<String> {
        let flaggedVerdicts: Set<String> = ["unmerge", "unmerge_likely", "uncertain"]
        // Split on ANY newline. The shipped `merge_audit_report.csv` uses bare `\r` line endings,
        // so splitting on `\n` yields the whole file as one row, no verdict is ever found, and the
        // guard is silently inert — which is precisely the failure the runner's
        // resolved-zero-ids check exists to make fatal.
        let rows = auditCSV.components(separatedBy: .newlines)
        guard let header = rows.first else { return [] }
        let columns = splitCSVRow(String(header))
        guard let aIndex = columns.firstIndex(of: "pid_a"),
              let bIndex = columns.firstIndex(of: "pid_b"),
              let verdictIndex = columns.firstIndex(of: "verdict") else { return [] }

        var flaggedXMLIds = Set<String>()
        for row in rows.dropFirst() where !row.isEmpty {
            let fields = splitCSVRow(String(row))
            guard fields.count > max(aIndex, max(bIndex, verdictIndex)) else { continue }
            guard flaggedVerdicts.contains(fields[verdictIndex].trimmed.lowercased()) else { continue }
            flaggedXMLIds.insert(fields[aIndex].trimmed)
            flaggedXMLIds.insert(fields[bIndex].trimmed)
        }

        var result = Set<String>()
        for entry in entries {
            guard let xmlId = entry.xmlId, flaggedXMLIds.contains(xmlId) else { continue }
            result.formUnion(entry.peopleIds)
        }
        return result
    }

    // MARK: - Scanning helpers

    /// Every `<idno type="…">value</idno>` in a chunk, in document order.
    static func idnos(in chunk: String) -> [(type: String, value: String)] {
        var result: [(String, String)] = []
        var cursor = chunk.startIndex
        while let open = chunk.range(of: "<idno", range: cursor..<chunk.endIndex),
              let tagEnd = chunk.range(of: ">", range: open.upperBound..<chunk.endIndex),
              let close = chunk.range(of: "</idno>", range: tagEnd.upperBound..<chunk.endIndex) {
            let attributes = String(chunk[open.upperBound..<tagEnd.lowerBound])
            let value = String(chunk[tagEnd.upperBound..<close.lowerBound])
            if let type = attributeValue("type", in: attributes) {
                result.append((type, value))
            }
            cursor = close.upperBound
        }
        return result
    }

    /// Text of the first `<name>…</name>` element.
    static func firstElementText(_ name: String, in chunk: String) -> String? {
        guard let open = chunk.range(of: "<\(name)>"),
              let close = chunk.range(of: "</\(name)>", range: open.upperBound..<chunk.endIndex)
        else { return nil }
        return String(chunk[open.upperBound..<close.lowerBound]).trimmed.nonEmpty
    }

    /// Text of the first `<note type="…">`.
    static func noteText(type: String, in chunk: String) -> String? {
        guard let open = chunk.range(of: "<note type=\"\(type)\">"),
              let close = chunk.range(of: "</note>", range: open.upperBound..<chunk.endIndex)
        else { return nil }
        return String(chunk[open.upperBound..<close.lowerBound]).trimmed.nonEmpty
    }

    /// The value of an identifier idno, matched **case-insensitively** and preferring the bare
    /// form over the `-URL` one.
    ///
    /// The drop spells these `Wikidata` and `VIAF`, not `wikidata`/`viaf`, and ships each twice —
    /// `<idno type="Wikidata">Q108409343</idno>` beside
    /// `<idno type="Wikidata-URL">https://…/Q108409343</idno>`. Matching the lower-case spelling
    /// found **zero** of 7,500 Wikidata and 6,442 VIAF ids and reported a clean build; matching
    /// with a prefix would have stored the URL for half of them.
    static func identifier(_ kind: String, in chunk: String) -> String? {
        let wanted = kind.lowercased()
        return idnos(in: chunk)
            .first { $0.type.lowercased() == wanted }?
            .value.trimmed.nonEmpty
    }

    static func attribute(_ name: String, in chunk: String) -> String? {
        guard let tagEnd = chunk.firstIndex(of: ">") else { return nil }
        return attributeValue(name, in: String(chunk[chunk.startIndex..<tagEnd]))
    }

    static func attributeValue(_ name: String, in attributes: String) -> String? {
        guard let key = attributes.range(of: "\(name)=\""),
              let close = attributes.range(of: "\"", range: key.upperBound..<attributes.endIndex)
        else { return nil }
        return String(attributes[key.upperBound..<close.lowerBound])
    }

    /// Splits one CSV row, honouring double-quoted fields (the rationale column contains commas).
    static func splitCSVRow(_ row: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var iterator = row.makeIterator()
        while let character = iterator.next() {
            if character == "\"" {
                inQuotes.toggle()
            } else if character == "," && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        fields.append(current)
        return fields
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nonEmpty: String? { isEmpty ? nil : self }
}
