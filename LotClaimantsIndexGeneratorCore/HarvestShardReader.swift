// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - HarvestShardReader

/// Reads the fields this generator needs out of one record-group harvest shard.
///
/// The shards are plain JSON, not NDJSON, and `rg_59.json` is **3.3 GB** — so it is memory-mapped
/// and decoded through a narrow `Decodable` that names only the seven fields used here. Decoding
/// the full record shape would materialise every scope note and digital-object list in the file.
///
/// Version history:
///   1.0 — Session 2026-08-05: #675 / N-8b
///   1.1 — Session 2026-08-19: #372 item 1b — `forEachRecord`, the streaming walk
///   1.2 — W-8: `seriesAncestorNaId` + `digitalObjectCount`, for the consular-tail pass
///         (added to THIS reader, not a parallel one — the header's anti-drift rule)
public enum HarvestShardReader {

    /// The projection this generator needs.
    public struct Record: Decodable, Sendable {
        public let naId: String
        public let title: String
        public let levelOfDescription: String?
        public let recordGroupNumber: String?
        public let variantControlNumbers: [String]
        public let controlNumberNotes: [String]
        public let hmsMlrEntryNumbers: [String]
        public let dateRange: String?
        /// The NAID of the record's SERIES ancestor, when one exists — how a file unit names
        /// the series it belongs to (W-8: the consular-tail pass selects file units by it).
        public let seriesAncestorNaId: String?
        /// NARA's count of digitized page images on this record. The offline analogue of the
        /// keyed route's `availableOnline=true` filter: a record with `nil`/`0` here is not
        /// browsable page by page (W-8).
        public let digitalObjectCount: Int?
        /// NARA's own statement of how many file units a SERIES holds — the completeness
        /// check for any pass that collects a series' file units from the shard (W-8), the
        /// same self-detecting-truncation rule the record-group harvest itself uses.
        public let fileUnitCount: Int?
        /// The organisational bodies NARA credits with creating this series (#405).
        ///
        /// Added to **this** reader rather than a second one for the reason its own header gives:
        /// three analysis errors in this workstream came from a parallel implementation that
        /// tokenised differently from the shipped one. `creators` is present on exactly the
        /// series layer — 20,180 of 751,880 harvested records (2.7%) — so file units decode it
        /// as empty by construction, not by accident.
        public let creators: [Creator]

        /// NARA's own catalogue facts about the series, as a researcher planning a visit needs
        /// them (#663 / F-7). All four are present on 100% of the app-reachable series;
        /// `findingAids` on 19.6%.
        public let facts: Facts

        /// The trip-planning facts. `numberingNote` is deliberately absent: it is projected on
        /// 385 records corpus-wide but reaches **1** of the 622 series the app can name, which is
        /// not a feature.
        public struct Facts: Sendable, Equatable {
            /// Memberwise init, public so tests in sibling generator targets can build fixtures.
            public init(accessStatus: String? = nil, accessRestrictions: [String] = [],
                        useStatus: String? = nil, useRestrictions: [String] = [],
                        extent: String? = nil, referenceUnit: String? = nil,
                        findingAids: [String] = [], startYear: Int? = nil, endYear: Int? = nil) {
                self.accessStatus = accessStatus
                self.accessRestrictions = accessRestrictions
                self.useStatus = useStatus
                self.useRestrictions = useRestrictions
                self.extent = extent
                self.referenceUnit = referenceUnit
                self.findingAids = findingAids
                self.startYear = startYear
                self.endYear = endYear
            }

            /// `Unrestricted` / `Restricted - Partly` / `Restricted - Fully` /
            /// `Restricted - Possibly`. Measured over the app-reachable series: 414 of 622 are
            /// restricted in some degree — this is the field that decides whether a trip is
            /// worth taking.
            public var accessStatus: String?
            /// The FOIA exemptions behind an access restriction — 338 of 622 cite
            /// `(b)(1) National Security`. Distinct from the status: *why*, not *whether*.
            public var accessRestrictions: [String]
            /// Copyright and similar limits on *publishing* what you find, which is a different
            /// question from whether you may read it. 205 of 622 are copyright-restricted.
            public var useStatus: String?
            /// The use-restriction categories, chiefly `Copyright`.
            public var useRestrictions: [String]
            /// NARA's own extent statement — "1 linear foot, 3 linear inches".
            public var extent: String?
            /// Which NARA facility holds it. 621 of 622 are College Park textual reference.
            public var referenceUnit: String?
            /// Finding-aid types NARA offers (`Folder List`, `Container List`, `Index`), when any.
            public var findingAids: [String]
            /// Coverage years as NARA states them, for sanity-checking a resolution against the
            /// citation's own date.
            public var startYear: Int?
            public var endYear: Int?
        }

        /// One creating body: NARA's heading, its own authority NAID, and which era it belongs to.
        public struct Creator: Decodable, Sendable, Equatable {
            /// The full hierarchical heading, verbatim, e.g.
            /// `"Department of State. Office of the Secretary. Executive Secretariat. (1789 - )"`.
            public let heading: String
            /// The creator's own authority-record NAID, when NARA states one.
            public let naId: String?
            /// `"Most Recent"` for the body that last held the records; `"Predecessor"` for an
            /// earlier one. A series may carry several.
            public let creatorType: String?

            public init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: K.self)
                heading = ((try? c.decode(String.self, forKey: .heading)) ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                naId = Record.looseString(c, .naId)
                creatorType = try? c.decode(String.self, forKey: .creatorType)
            }
            private enum K: String, CodingKey { case heading, naId, creatorType }
        }

        private enum CodingKeys: String, CodingKey {
            case naId, title, levelOfDescription, recordGroupNumber
            case variantControlNumbers, inclusiveStartDate, inclusiveEndDate, ancestors
            case creators, accessRestriction, useRestriction, findingAids, physicalOccurrences
            case digitalObjectCount, fileUnitCount
        }
        private struct ControlNumber: Decodable {
            let number: String?
            let type: String?
            let note: String?
        }
        private struct YearBox: Decodable { let year: Int? }
        private struct Restriction: Decodable {
            let status: String?
            let specificRestrictions: [String]
            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: K.self)
                status = try? c.decode(String.self, forKey: .status)
                // NARA sends these as bare strings in the bulk export; tolerate an object form
                // too rather than silently dropping the categories if that ever changes.
                if let strings = try? c.decode([String].self, forKey: .specificRestrictions) {
                    specificRestrictions = strings
                } else {
                    specificRestrictions = []
                }
            }
            private enum K: String, CodingKey { case status, specificRestrictions }
        }
        private struct FindingAid: Decodable { let findingAidType: String? }
        private struct Occurrence: Decodable {
            let extent: String?
            let referenceUnitNames: [String]
            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: K.self)
                extent = try? c.decode(String.self, forKey: .extent)
                referenceUnitNames = (try? c.decode([String].self, forKey: .referenceUnitNames)) ?? []
            }
            private enum K: String, CodingKey { case extent, referenceUnitNames }
        }
        private struct Ancestor: Decodable {
            let recordGroupNumber: String?
            let naId: String?
            let levelOfDescription: String?
            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: K.self)
                recordGroupNumber = Record.looseString(c, .recordGroupNumber)
                naId = Record.looseString(c, .naId)
                levelOfDescription = try? c.decode(String.self, forKey: .levelOfDescription)
            }
            private enum K: String, CodingKey { case recordGroupNumber, naId, levelOfDescription }
        }

        /// NARA types the same field differently between the bulk export and the API —
        /// `recordGroupNumber` is an **Int** in the shards and a String in API responses, and
        /// `naId` varies the same way. Decoding one shape only silently yields `nil`, which the
        /// acceptance test then reads as "no record group" and refuses. That produced an
        /// artifact with zero rows on the first run of this generator.
        public static func looseString<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> String? {
            if let s = try? c.decode(String.self, forKey: key) { return s }
            if let i = try? c.decode(Int.self, forKey: key) { return String(i) }
            return nil
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            // NARA emits naId as a string in the bulk export and an int in the API.
            naId = Record.looseString(c, .naId) ?? ""
            title = (try? c.decode(String.self, forKey: .title)) ?? ""
            levelOfDescription = try? c.decode(String.self, forKey: .levelOfDescription)

            // The record group lives on the record for a series, and on its ancestors
            // otherwise. Ancestors are decoded unconditionally (not only when the record
            // group is missing) because the series ancestor below comes from the same list —
            // a conditional decode would make one field's presence depend on another's.
            let ancestors = (try? c.decode([Ancestor].self, forKey: .ancestors)) ?? []
            let own = Record.looseString(c, .recordGroupNumber)
            recordGroupNumber = own ?? ancestors.compactMap(\.recordGroupNumber).first
            seriesAncestorNaId = ancestors.first { $0.levelOfDescription == "series" }?.naId
            digitalObjectCount = try? c.decode(Int.self, forKey: .digitalObjectCount)
            fileUnitCount = try? c.decode(Int.self, forKey: .fileUnitCount)

            let controls = (try? c.decode([ControlNumber].self, forKey: .variantControlNumbers)) ?? []
            variantControlNumbers = controls.compactMap(\.number)
            controlNumberNotes = controls.compactMap(\.note)
            hmsMlrEntryNumbers = controls
                .filter { $0.type == "HMS/MLR Entry Number" }
                .compactMap(\.number)

            creators = ((try? c.decode([Creator].self, forKey: .creators)) ?? [])
                .filter { !$0.heading.isEmpty }

            let access = try? c.decode(Restriction.self, forKey: .accessRestriction)
            let use = try? c.decode(Restriction.self, forKey: .useRestriction)
            let aids = (try? c.decode([FindingAid].self, forKey: .findingAids)) ?? []
            let occurrences = (try? c.decode([Occurrence].self, forKey: .physicalOccurrences)) ?? []
            let startBox = try? c.decode(YearBox.self, forKey: .inclusiveStartDate)
            let endBox = try? c.decode(YearBox.self, forKey: .inclusiveEndDate)
            facts = Facts(
                accessStatus: access?.status,
                accessRestrictions: access?.specificRestrictions ?? [],
                useStatus: use?.status,
                useRestrictions: use?.specificRestrictions ?? [],
                extent: occurrences.first?.extent,
                referenceUnit: occurrences.first?.referenceUnitNames.first,
                findingAids: aids.compactMap(\.findingAidType),
                startYear: startBox?.year,
                endYear: endBox?.year)

            let start = (try? c.decode(YearBox.self, forKey: .inclusiveStartDate))?.year
            let end = (try? c.decode(YearBox.self, forKey: .inclusiveEndDate))?.year
            switch (start, end) {
            case let (s?, e?): dateRange = s == e ? "\(s)" : "\(s)–\(e)"
            case let (s?, nil): dateRange = "\(s)–"
            case let (nil, e?): dateRange = "–\(e)"
            default: dateRange = nil
            }
        }
    }

    private struct Shard: Decodable {
        let generated: String?
        let records: [Record]
    }

    /// Decodes one shard, returning its records and the harvest's `generated` stamp.
    ///
    /// Holds every record of the shard at once. For `rg_59.json` that is measured at **7.01 GB
    /// resident**; prefer ``forEachRecord(_:_:)`` for anything that only needs one record at a
    /// time. This entry point is kept because two callers legitimately want the whole array and
    /// because it is the parity reference the streaming path is tested against.
    public static func read(_ url: URL) throws -> ([Record], String?) {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let shard = try JSONDecoder().decode(Shard.self, from: data)
        return (shard.records, shard.generated)
    }

    /// What can go wrong walking a shard at the byte level.
    public enum ShardScanError: Error, CustomStringConvertible {
        /// No `"records"` array was found at the top level.
        case noRecordsArray(String)
        /// The array ended mid-element — a truncated or corrupt shard.
        case unterminatedElement(String, offset: Int)

        public var description: String {
            switch self {
            case .noRecordsArray(let path):
                return "no top-level \"records\" array in \(path)"
            case .unterminatedElement(let path, let offset):
                return "unterminated record starting at byte \(offset) in \(path)"
            }
        }
    }

    /// Streams one shard, handing each record to `body` as it is decoded, and returns the
    /// harvest's `generated` stamp.
    ///
    /// ## Why this exists (#372 item 1b)
    /// ``read(_:)`` decodes the whole `records` array in a single `JSONDecoder` call, so every
    /// `Record` in the shard is materialised before the caller sees the first one. Measured on
    /// `rg_59.json` — 3.5 GB, 240,929 records — that peaks at **7.01 GB resident**. That is
    /// survivable on a large machine and fatal on a 16 GB one, which made it a prerequisite
    /// rather than a nicety for any pass that has to visit all 22 shards.
    ///
    /// This path maps the same file, walks the `records` array once at the byte level to find
    /// each element's extent, then decodes them one at a time. Resident memory is one record
    /// plus the range table (16 bytes per record, ~3.7 MB for RG 59); the mapped 3.5 GB stays as
    /// pages the kernel is free to evict.
    ///
    /// ## The scan is JSON-aware, and has to be
    /// It tracks brace depth while skipping over string literals and their `\` escapes. A search
    /// for the next `}` would end an element early on any title containing a brace — and the
    /// resulting failure is a decode error at a byte offset that tells the operator nothing.
    /// `HarvestShardReaderStreamingTests` pins the streaming path against ``read(_:)`` over
    /// fixtures built to contain exactly those shapes.
    ///
    /// - Parameters:
    ///   - url: The shard to read.
    ///   - body: Called once per record, in file order. Throwing from it aborts the walk.
    /// - Returns: The shard's `generated` stamp, or `nil` when it carries none.
    @discardableResult
    public static func forEachRecord(_ url: URL,
                                     _ body: (Record) throws -> Void) throws -> String? {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let path = url.lastPathComponent
        var ranges: [Range<Int>] = []
        var generated: String?

        try data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            let bytes = raw.bindMemory(to: UInt8.self)
            guard let arrayStart = recordsArrayStart(bytes) else {
                throw ShardScanError.noRecordsArray(path)
            }
            var arrayEnd: Int?
            var i = arrayStart                              // just past the '['
            walk: while i < bytes.count {
                switch bytes[i] {
                case 0x20, 0x09, 0x0A, 0x0D, 0x2C:          // space, tab, LF, CR, comma
                    i += 1
                case 0x5D:                                  // ']' — the array is closed
                    arrayEnd = i + 1
                    break walk
                default:
                    guard let end = elementEnd(bytes, from: i) else {
                        throw ShardScanError.unterminatedElement(path, offset: i)
                    }
                    ranges.append(i..<end)
                    i = end
                }
            }
            // The stamp is read only from the bytes OUTSIDE the records array — before it, and
            // failing that after it. A `"generated"` inside a record (the shards carry none
            // today, but nothing stops one appearing) can therefore never be mistaken for the
            // shard's own, while a shard that puts `records` first still yields its stamp, which
            // is what keeps this at parity with `read(_:)`.
            generated = stringValue(of: "generated", in: bytes, from: 0, before: arrayStart)
                ?? arrayEnd.flatMap {
                    stringValue(of: "generated", in: bytes, from: $0, before: bytes.count)
                }
        }

        let decoder = JSONDecoder()
        for range in ranges {
            try body(try decoder.decode(Record.self, from: data.subdata(in: range)))
        }
        return generated
    }

    /// The offset just past the `[` opening the top-level `records` array, or `nil`.
    ///
    /// Matches on the quoted key so a record's own `"records"`-valued prose cannot be mistaken
    /// for it, and requires the value to be an array — a `"records": null` shard is "no array"
    /// rather than a silent zero-record success.
    private static func recordsArrayStart(_ bytes: UnsafeBufferPointer<UInt8>) -> Int? {
        let key = Array(#""records""#.utf8)
        var i = 0
        while let found = firstIndex(of: key, in: bytes, from: i) {
            var j = found + key.count
            while j < bytes.count, isSpace(bytes[j]) { j += 1 }
            if j < bytes.count, bytes[j] == 0x3A {          // ':'
                j += 1
                while j < bytes.count, isSpace(bytes[j]) { j += 1 }
                if j < bytes.count, bytes[j] == 0x5B { return j + 1 }   // '['
            }
            i = found + key.count
        }
        return nil
    }

    /// The string value of a `"key"` occurring in `from..<limit`, or `nil`.
    private static func stringValue(of key: String, in bytes: UnsafeBufferPointer<UInt8>,
                                    from: Int, before limit: Int) -> String? {
        let needle = Array("\"\(key)\"".utf8)
        guard let found = firstIndex(of: needle, in: bytes, from: from), found < limit else {
            return nil
        }
        var j = found + needle.count
        while j < limit, isSpace(bytes[j]) { j += 1 }
        guard j < limit, bytes[j] == 0x3A else { return nil }
        j += 1
        while j < limit, isSpace(bytes[j]) { j += 1 }
        guard j < limit, bytes[j] == 0x22 else { return nil }           // '"'
        j += 1
        var out = [UInt8]()
        while j < limit {
            let b = bytes[j]
            if b == 0x5C { j += 2; continue }               // skip an escape pair wholesale
            if b == 0x22 { return String(decoding: out, as: UTF8.self) }
            out.append(b)
            j += 1
        }
        return nil
    }

    /// The offset one past the element beginning at `start`, tracking nesting and strings.
    private static func elementEnd(_ bytes: UnsafeBufferPointer<UInt8>, from start: Int) -> Int? {
        var depth = 0
        var inString = false
        var i = start
        while i < bytes.count {
            let b = bytes[i]
            if inString {
                if b == 0x5C { i += 2; continue }           // an escape consumes the next byte
                if b == 0x22 { inString = false }
            } else {
                switch b {
                case 0x22: inString = true                  // '"'
                case 0x7B, 0x5B: depth += 1                 // '{' '['
                case 0x7D, 0x5D:                            // '}' ']'
                    depth -= 1
                    if depth == 0 { return i + 1 }
                    if depth < 0 { return nil }             // the array closed mid-element
                default: break
                }
            }
            i += 1
        }
        return nil
    }

    private static func isSpace(_ b: UInt8) -> Bool {
        b == 0x20 || b == 0x09 || b == 0x0A || b == 0x0D
    }

    /// First occurrence of `needle` at or after `from`. A plain scan: the needles here are short
    /// and matched a handful of times per shard, so a substring algorithm would be ceremony.
    private static func firstIndex(of needle: [UInt8], in bytes: UnsafeBufferPointer<UInt8>,
                                   from: Int) -> Int? {
        guard !needle.isEmpty, bytes.count >= needle.count else { return nil }
        let last = bytes.count - needle.count
        var i = max(0, from)
        while i <= last {
            if bytes[i] == needle[0] {
                var k = 1
                while k < needle.count, bytes[i + k] == needle[k] { k += 1 }
                if k == needle.count { return i }
            }
            i += 1
        }
        return nil
    }
}
