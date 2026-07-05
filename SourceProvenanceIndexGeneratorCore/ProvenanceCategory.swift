// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SourceNoteKit

/// A stable, coarse provenance class for a FRUS document source note.
///
/// One case per meaningful archival-provenance type traced by the app's real
/// `SourceNoteParser`. This is the categorization axis of the SA-3 "Archival Sourcing
/// Over Time" dashboard: the raw-string cases of `ParsedSourceNote` collapse to these
/// stable slugs so a decade's counts are comparable across the whole corpus and the
/// bundled artifact stays small.
///
/// The whole point of SA-3a is to reuse the app's grammar rather than re-classify with
/// regexes — in particular `.cfpfFile` (the Central Foreign Policy File / P-reel format,
/// dominant post-1960) maps here to `.centralForeignPolicyFile`, so the 1960s+ show their
/// real CFPF share instead of the 0% a naive central-decimal-only regex reports.
///
/// Version history:
///   1.0 — SA-3a (Session 2026-07-04): initial implementation
public enum ProvenanceCategory: String, Codable, Sendable, CaseIterable {

    /// State Department Central Decimal File (and the pre-1910 Numerical File / bare
    /// "File No." forms) — `ParsedSourceNote.centralFiles`. Dominant ~1900–1945.
    case centralDecimalFile

    /// State Department Central Foreign Policy File (CFPF), 1973–1979 — the P/D/N-reel
    /// and AAD Electronic Telegrams format — `ParsedSourceNote.cfpfFile`. The post-1960
    /// successor to the decimal file; the key class a naive regex misses.
    case centralForeignPolicyFile

    /// A State Department (RG 59) or diplomatic-post (RG 84) lot file —
    /// `ParsedSourceNote.lotFile`. Rises sharply from the 1950s onward.
    case lotFile

    /// A presidential library collection (Kennedy, Johnson, Nixon, …) —
    /// `ParsedSourceNote.presidentialLibrary`. Appears from the 1950s onward.
    case presidentialLibrary

    /// A National Archives / records-center record with an extractable record group —
    /// `ParsedSourceNote.naraCollection`.
    case naraCollection

    /// A CIA accession ("Job" number) citation — `ParsedSourceNote.ciaCollection`.
    case intelligence

    /// A named office-file series or manuscript collection cited without a lot number or
    /// repository — `ParsedSourceNote.namedFileSeries`.
    case namedFileSeries

    /// A foreign government archive — `ParsedSourceNote.foreignGovernmentArchive`.
    case foreignArchive

    /// A previously published source (books, journals, other FRUS volumes) —
    /// `ParsedSourceNote.previouslyPublished`.
    case previouslyPublished

    /// No known pattern matched — `ParsedSourceNote.unrecognized`.
    case unrecognized

    /// The stable, deterministic display/serialization order of the categories, used for
    /// the `categories` field of the output index (provenance-narrative order:
    /// decimal file → CFPF → lot files → presidential libraries → the remaining
    /// repositories → previously published → unrecognized).
    public static let orderedCases: [ProvenanceCategory] = [
        .centralDecimalFile,
        .centralForeignPolicyFile,
        .lotFile,
        .presidentialLibrary,
        .naraCollection,
        .intelligence,
        .namedFileSeries,
        .foreignArchive,
        .previouslyPublished,
        .unrecognized,
    ]

    /// Maps a parsed source note to its stable provenance category.
    ///
    /// Exhaustive over every `ParsedSourceNote` case — the compiler enforces that a new
    /// parser case cannot be added without assigning it a category here.
    ///
    /// - Parameter parsed: The result of `SourceNoteParser.parse`.
    /// - Returns: The stable category for aggregation.
    public static func from(_ parsed: ParsedSourceNote) -> ProvenanceCategory {
        switch parsed {
        case .centralFiles:             return .centralDecimalFile
        case .cfpfFile:                 return .centralForeignPolicyFile
        case .lotFile:                  return .lotFile
        case .presidentialLibrary:      return .presidentialLibrary
        case .naraCollection:           return .naraCollection
        case .ciaCollection:            return .intelligence
        case .namedFileSeries:          return .namedFileSeries
        case .foreignGovernmentArchive: return .foreignArchive
        case .previouslyPublished:      return .previouslyPublished
        case .unrecognized:             return .unrecognized
        }
    }
}
