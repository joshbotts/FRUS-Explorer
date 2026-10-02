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
/// regexes. Three of the cases are the State Department's central filing systems, and a
/// central-files citation is placed among them by its FORM, which
/// `CollectionKeying.centralFilesForm(parsed:note:)` reads from the parse and the note text: a
/// decimal file number, a Subject-Numeric file designation or its block of years, or the Central
/// Foreign Policy File's name or a film number (#1543). The parse case alone does not say: a
/// Subject-Numeric citation parses as `.centralFiles` when the Department leads it, as
/// `.naraCollection` when the National Archives does, and as `.cfpfFile` when a remark names that
/// file.
///
/// Version history:
///   1.0 — SA-3a (Session 2026-07-04): initial implementation
///   1.1 — 2026-10-02 (#1543): `subjectNumericFile`, the eleventh category; `from(_:note:)` reads
///          the note text, and the one-argument form is gone so no caller can omit it
public enum ProvenanceCategory: String, Codable, Sendable, CaseIterable {

    /// State Department Central Decimal File (and the pre-1910 Numerical File / bare
    /// "File No." forms) — `ParsedSourceNote.centralFiles`, and a decimal file number cited
    /// through the National Archives (`.naraCollection`). Dominant ~1900–1945.
    case centralDecimalFile

    /// State Department Subject-Numeric File, February 1963–1973 — a file designation
    /// (`POL 27 VIET S`) or its block of years (`Central Files 1964–66`), in either wording. It
    /// replaced the decimal file, and it is what the 1960s volumes cite.
    case subjectNumericFile

    /// State Department Central Foreign Policy File (CFPF), from July 1973 — the P/D/N-reel
    /// and AAD Electronic Telegrams format — `ParsedSourceNote.cfpfFile`, less the notes whose
    /// citation sentence gives a Subject-Numeric file.
    case centralForeignPolicyFile

    /// A State Department (RG 59) or diplomatic-post (RG 84) lot file —
    /// `ParsedSourceNote.lotFile`. Rises sharply from the 1950s onward.
    case lotFile

    /// A presidential library collection (Kennedy, Johnson, Nixon, …) —
    /// `ParsedSourceNote.presidentialLibrary`. Appears from the 1950s onward.
    case presidentialLibrary

    /// A National Archives / records-center record with an extractable record group —
    /// `ParsedSourceNote.naraCollection`, less the central-files citations worded that way.
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
    /// decimal file → Subject-Numeric File → CFPF → lot files → presidential libraries → the
    /// remaining repositories → previously published → unrecognized).
    public static let orderedCases: [ProvenanceCategory] = [
        .centralDecimalFile,
        .subjectNumericFile,
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
    /// The form of a central-files citation is read first (#1543). A Subject-Numeric citation is
    /// `subjectNumericFile` whichever of three parse cases it took, and a decimal file number
    /// cited through the National Archives (`RG 59, Central Files 1960–63, 399.731/7–2561`) is
    /// `centralDecimalFile` rather than a NARA collection. Everything else keeps the category its
    /// parse case names, so a `.centralFiles` note that gives no readable form stays
    /// `centralDecimalFile`.
    ///
    /// - Parameters:
    ///   - parsed: The result of `SourceNoteParser.parse`.
    ///   - note: The note text that was parsed.
    /// - Returns: The stable category for aggregation.
    public static func from(_ parsed: ParsedSourceNote, note: String) -> ProvenanceCategory {
        switch CollectionKeying.centralFilesForm(parsed: parsed, note: note) {
        case .subjectNumeric:
            return .subjectNumericFile
        case .decimal:
            if case .naraCollection = parsed { return .centralDecimalFile }
        case nil:
            break
        }
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
