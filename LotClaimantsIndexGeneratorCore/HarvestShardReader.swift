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
            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: K.self)
                recordGroupNumber = Record.looseString(c, .recordGroupNumber)
            }
            private enum K: String, CodingKey { case recordGroupNumber }
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

            // The record group lives on the record for a series, and on its ancestors otherwise.
            let own = Record.looseString(c, .recordGroupNumber)
            if let own {
                recordGroupNumber = own
            } else {
                let ancestors = (try? c.decode([Ancestor].self, forKey: .ancestors)) ?? []
                recordGroupNumber = ancestors.compactMap(\.recordGroupNumber).first
            }

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
    public static func read(_ url: URL) throws -> ([Record], String?) {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let shard = try JSONDecoder().decode(Shard.self, from: data)
        return (shard.records, shard.generated)
    }
}
