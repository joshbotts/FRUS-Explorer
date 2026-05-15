// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CitationInput

/// The structured representation of a parsed or manually entered FRUS citation.
///
/// All fields are optional — the matcher uses whatever is available.
/// Raw text is preserved alongside parsed fields for display and debugging.
///
/// Version history:
///   1.0 — Session 30: initial implementation
public struct CitationInput: Sendable {

    /// Original pasted string; `nil` if the user typed fields directly.
    public let rawText: String?

    /// Chronological subseries identifier, e.g. `"1969-76"`.
    /// Normalized: hyphens and en dashes unified, both-year variants collapsed.
    public let subseries: String?

    /// Volume number string, e.g. `"I"`, `"1"`, `"01"`.
    /// Normalized to uppercase Roman if parseable; raw otherwise.
    public let volumeNumber: String?

    /// Parsed document number.
    public let documentNumber: Int?

    /// Parsed page number.
    public let pageNumber: Int?

    /// Partial title text for volume disambiguation.
    public let titleFragment: String?

    /// Confidence in the automatic parsing outcome.
    public let parserConfidence: ParserConfidence

    public init(
        rawText: String? = nil,
        subseries: String? = nil,
        volumeNumber: String? = nil,
        documentNumber: Int? = nil,
        pageNumber: Int? = nil,
        titleFragment: String? = nil,
        parserConfidence: ParserConfidence = .structured
    ) {
        self.rawText = rawText
        self.subseries = subseries
        self.volumeNumber = volumeNumber
        self.documentNumber = documentNumber
        self.pageNumber = pageNumber
        self.titleFragment = titleFragment
        self.parserConfidence = parserConfidence
    }

    /// Returns `true` when enough data is present to attempt a match.
    /// At minimum one of (documentNumber, pageNumber, volumeNumber) is required.
    public var isActionable: Bool {
        documentNumber != nil || pageNumber != nil || volumeNumber != nil
    }
}

// MARK: - ParserConfidence

/// How well a raw citation string was parsed.
public enum ParserConfidence: Sendable, Equatable {
    /// All key fields extracted unambiguously.
    case high
    /// Some fields ambiguous or inferred.
    case medium
    /// Minimal fields extracted; much uncertainty.
    case low
    /// User entered fields directly; no parsing confidence issue.
    case structured
}

// MARK: - CitationMatch

/// A single candidate match from the citation lookup engine.
///
/// Always displayed using the standard `SearchResultRow` view component.
/// `confidenceLabel` provides an explicit human-readable explanation
/// of how the match was made and any corrections or assumptions applied.
///
/// Version history:
///   1.0 — Session 30: initial implementation
public struct CitationMatch: Sendable, Identifiable {

    public let documentId: String
    public let volumeId: String
    /// 1 = most likely
    public let rank: Int
    public let matchStrategy: MatchStrategy
    /// Explicit, plain-language label shown in UI above the result card.
    public let confidenceLabel: String
    /// Explanation shown below the result card when a correction was applied.
    public let correctionNote: String?
    /// `true` when the volume is not in the local downloaded corpus.
    public let requiresDownload: Bool
    /// Populated for `requiresDownload == true` results so the UI can show
    /// volume metadata before the user confirms a download.
    public let volumeManifestEntry: VolumeManifestEntry?

    public var id: String { "\(volumeId)/\(documentId)/\(rank)" }

    public init(
        documentId: String,
        volumeId: String,
        rank: Int,
        matchStrategy: MatchStrategy,
        confidenceLabel: String,
        correctionNote: String? = nil,
        requiresDownload: Bool = false,
        volumeManifestEntry: VolumeManifestEntry? = nil
    ) {
        self.documentId = documentId
        self.volumeId = volumeId
        self.rank = rank
        self.matchStrategy = matchStrategy
        self.confidenceLabel = confidenceLabel
        self.correctionNote = correctionNote
        self.requiresDownload = requiresDownload
        self.volumeManifestEntry = volumeManifestEntry
    }
}

// MARK: - MatchStrategy

/// How the match was made.
public enum MatchStrategy: Sendable, Equatable {
    /// Subseries + volume + doc number → direct hit (post-1955–57).
    case exactDocumentNumber
    /// Subseries + volume + page → document containing that page.
    case pageRange
    /// Pre-1955–57 volume; doc number editorially assigned during digitization.
    case superimposedDocumentNumber
    /// Doc number not found; nearest existing document surfaced.
    case fuzzyDocumentNumber(nearest: Int)
    /// Volume resolved via title fragment; doc/page then matched.
    case titleFragmentMatch
    /// Volume not downloaded; match to volume metadata only.
    case manifestOnly
    /// Multiple corrections applied; explanation is in `correctionNote`.
    case bestGuess(explanation: String)
}

// MARK: - CitationLookupMode

/// The two input modes in the Citation Lookup view.
public enum CitationLookupMode: Sendable, CaseIterable, Equatable {
    case paste
    case structured

    public var label: String {
        switch self {
        case .paste:
            return String(localized: "citation.mode.paste", defaultValue: "Paste Citation")
        case .structured:
            return String(localized: "citation.mode.structured", defaultValue: "Structured Entry")
        }
    }
}
