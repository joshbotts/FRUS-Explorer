// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// One presidential administration decoded from the bundled `administrations.json`.
///
/// Administrations are **per president**: a president's continuous term of office. A
/// succession due to death or resignation begins on the succession date, and Grover
/// Cleveland's two non-consecutive terms (and Donald Trump's) are two separate entries.
/// Nixon and Ford are distinct even though FRUS's `1969-76` sub-series combines them.
///
/// Intervals are **half-open** `[start, end)`: a point date `d` belongs to the
/// administration whose `start <= d < end`. `end` mirrors the successor's `start`; the
/// sitting administration has a `nil` end (matching any `d >= start`).
///
/// Version history:
///   1.0 — SA-2a (Session 2026-07-05): initial implementation
public struct Administration: Decodable, Sendable, Equatable {

    /// Stable slug id (e.g. `truman`, `cleveland-1`).
    public let id: String
    /// Presidential ordinal number (e.g. `33` for Truman).
    public let number: Int
    /// President's full name.
    public let president: String
    /// Party label.
    public let party: String
    /// Inclusive start date, `yyyy-MM-dd`.
    public let start: String
    /// Exclusive end date, `yyyy-MM-dd`, or `nil` for the sitting administration.
    public let end: String?

    /// Creates an administration record.
    public init(id: String, number: Int, president: String, party: String,
                start: String, end: String?) {
        self.id = id
        self.number = number
        self.president = president
        self.party = party
        self.start = start
        self.end = end
    }

    /// The `start` date as a comparable `yyyy-MM-dd` string (already ISO-lexicographic).
    var startDay: String { String(start.prefix(10)) }
    /// The `end` date as a comparable `yyyy-MM-dd` string, or `nil` when ongoing.
    var endDay: String? { end.map { String($0.prefix(10)) } }

    /// Whether a **point** date falls inside this administration's half-open interval
    /// `[start, end)`.
    ///
    /// Comparison is lexicographic on the `yyyy-MM-dd` prefix, which is order-preserving
    /// for ISO dates. `start` is inclusive, `end` is exclusive; a `nil` end matches any
    /// date on or after `start`. So a document dated on a succession day belongs to the
    /// **successor**, not the predecessor (e.g. `1945-04-12` → Truman, not FDR).
    ///
    /// - Parameter day: A `yyyy-MM-dd` calendar date.
    /// - Returns: `true` when `startDay <= day < endDay` (or `day >= startDay` when ongoing).
    public func contains(day: String) -> Bool {
        guard day >= startDay else { return false }
        if let endDay { return day < endDay }
        return true
    }

    /// Whether a **date range** `[rangeStart, rangeEnd]` (both inclusive, `yyyy-MM-dd`)
    /// overlaps this administration's half-open interval `[start, end)`.
    ///
    /// Two intervals overlap when each starts on or before the other ends. Because the
    /// administration interval is half-open at `end`, the range overlaps iff
    /// `rangeStart < endDay` (range begins before the admin ends) **and**
    /// `rangeEnd >= startDay` (range ends on or after the admin begins). A `nil` end drops
    /// the upper bound. This is the any-overlap rule: a range spanning two administrations
    /// counts toward both.
    ///
    /// - Parameters:
    ///   - rangeStart: The range's inclusive lower bound (`yyyy-MM-dd`).
    ///   - rangeEnd: The range's inclusive upper bound (`yyyy-MM-dd`).
    /// - Returns: `true` when the range intersects `[start, end)`.
    public func rangeOverlaps(rangeStart: String, rangeEnd: String) -> Bool {
        guard rangeEnd >= startDay else { return false }
        if let endDay { return rangeStart < endDay }
        return true
    }
}

/// The decoded top-level `administrations.json` document.
///
/// Only the `administrations` array is consumed; the descriptive `source`/`note` fields
/// are ignored.
public struct AdministrationsTable: Decodable, Sendable {
    /// The per-president administration entries, in chronological order.
    public let administrations: [Administration]

    /// Decodes the bundled `administrations.json` at `url`.
    ///
    /// - Parameter url: The file URL of `administrations.json`.
    /// - Returns: The decoded table.
    public static func load(from url: URL) throws -> AdministrationsTable {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(AdministrationsTable.self, from: data)
    }
}
