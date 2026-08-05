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
enum HarvestShardReader {

    /// The projection this generator needs.
    struct Record: Decodable {
        let naId: String
        let title: String
        let levelOfDescription: String?
        let recordGroupNumber: String?
        let variantControlNumbers: [String]
        let controlNumberNotes: [String]
        let hmsMlrEntryNumbers: [String]
        let dateRange: String?

        private enum CodingKeys: String, CodingKey {
            case naId, title, levelOfDescription, recordGroupNumber
            case variantControlNumbers, inclusiveStartDate, inclusiveEndDate, ancestors
        }
        private struct ControlNumber: Decodable {
            let number: String?
            let type: String?
            let note: String?
        }
        private struct YearBox: Decodable { let year: Int? }
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
        static func looseString<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> String? {
            if let s = try? c.decode(String.self, forKey: key) { return s }
            if let i = try? c.decode(Int.self, forKey: key) { return String(i) }
            return nil
        }

        init(from decoder: Decoder) throws {
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
    static func read(_ url: URL) throws -> ([Record], String?) {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let shard = try JSONDecoder().decode(Shard.self, from: data)
        return (shard.records, shard.generated)
    }
}
