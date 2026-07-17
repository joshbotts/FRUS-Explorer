// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import VolumeSourcesIndexGeneratorCore

// MARK: - SourceExplorerExportRecord

/// One document's row in the corpus-wide Source Explorer export (#335): the canonical id,
/// the raw source-note string the app stores, the parsed value handed to Source Explorer
/// logic, the strategy that applies, and the dictionary of offline resolution results.
public struct SourceExplorerExportRecord: Codable, Sendable, Equatable {
    /// Canonical `volumeId/documentId` (e.g. `"frus1946v06/d475"`). The document id is the
    /// TEI `xml:id`; empty after the slash when the document div carries none.
    public let id: String
    /// The normalized source-note text the app's indexing pipeline stores — the exact string
    /// Source Explorer receives (parity-pinned `DocumentNoteExtractor` output).
    public let rawNote: String
    /// The document's coverage year from the authoritative `frus:doc-dateTime-min` attribute,
    /// when present — gates the 1906–1910 Numerical File path exactly as the app does.
    public let documentYear: Int?
    /// The parsed value passed to Source Explorer logic (`SourceNoteParser.parse`).
    public let parsed: ParsedNoteDescription
    /// The Source Explorer strategy for this document — the stable `ProvenanceCategory` slug
    /// (`lotFile`, `centralDecimalFile`, `presidentialLibrary`, …).
    public let strategy: String
    /// The derived keys the app computes from the parse (what actually drives lookups).
    public let derived: DerivedKeys
    /// The offline resolution results, one entry per resolution surface.
    public let resolution: ResolutionResults
    /// The single-token offline outcome, for aggregate analysis
    /// (see `OfflineOutcome` for the vocabulary).
    public let offlineOutcome: String

    public init(id: String, rawNote: String, documentYear: Int?, parsed: ParsedNoteDescription,
                strategy: String, derived: DerivedKeys, resolution: ResolutionResults,
                offlineOutcome: String) {
        self.id = id
        self.rawNote = rawNote
        self.documentYear = documentYear
        self.parsed = parsed
        self.strategy = strategy
        self.derived = derived
        self.resolution = resolution
        self.offlineOutcome = offlineOutcome
    }
}

// MARK: - ParsedNoteDescription

/// A serialization of `ParsedSourceNote` — the enum case name plus its associated values as a
/// sorted string dictionary, so the export is inspectable without Swift.
public struct ParsedNoteDescription: Codable, Sendable, Equatable {
    /// The `ParsedSourceNote` case name (`centralFiles`, `lotFile`, `unrecognized`, …).
    public let kind: String
    /// The case's associated values, keyed by their labels; absent optionals omitted.
    public let fields: [String: String]

    public init(kind: String, fields: [String: String]) {
        self.kind = kind
        self.fields = fields
    }
}

// MARK: - DerivedKeys

/// The keys the app derives from a parsed note — the values that drive archival-neighbor
/// matching, decimal-class display, and collection-authority lookup.
public struct DerivedKeys: Codable, Sendable, Equatable {
    /// Whether the parse supports the "Documents from This Collection" neighbors query.
    public let supportsArchivalNeighbors: Bool
    /// The neighbors key (`"Lot 64 D 199"`, `"Johnson Library: NSF"`, decimal-class base), if any.
    public let archivalNeighborKey: String?
    /// The canonical compact lot key (`SourceNoteParser.lotFileNorm`) for lot-carrying parses.
    public let lotFileNorm: String?
    /// The decimal/subject-numeric class (`CollectionKeying.centralFilesClass` gate +
    /// `decimalClassLocation`), for central-files-shaped parses.
    public let decimalClass: String?
    /// The classification-marking sentence (`Secret; Nodis`), when the note carries one.
    public let classificationMarking: String?

    public init(supportsArchivalNeighbors: Bool, archivalNeighborKey: String?,
                lotFileNorm: String?, decimalClass: String?, classificationMarking: String?) {
        self.supportsArchivalNeighbors = supportsArchivalNeighbors
        self.archivalNeighborKey = archivalNeighborKey
        self.lotFileNorm = lotFileNorm
        self.decimalClass = decimalClass
        self.classificationMarking = classificationMarking
    }
}

// MARK: - ResolutionResults

/// The dictionary of offline resolution results for one document — one entry per resolution
/// surface the app consults, plus the live-lookup route it would offer for the rest.
public struct ResolutionResults: Codable, Sendable, Equatable {
    /// The NARA Catalog query route the app UI offers for this strategy — recorded, never
    /// executed (the export is offline). See `LiveLookupRoute`.
    public let liveLookupRoute: String
    /// The bundled central-files lot resolution (`BundledLotResolver`, #321 guard applied).
    public let lotBundle: ResolvedNAID?
    /// Why a lot-carrying parse did NOT resolve through the bundle:
    /// `"notInBundle"` or `"flaggedAncestryLacksRecordGroup"`. `nil` when resolved or lot-less.
    public let lotBundleMiss: String?
    /// The 1906–1910 Numerical File rolls containing the citation's case number (all rolls —
    /// cases split across rolls), when the strategy + document year gate applies.
    public let numericalFileRolls: [NumericalRollRef]?
    /// `true` when the numerical-file gate applied but no roll contained the case number (a
    /// coverage gap — the app falls back to the M862 series + card-index links).
    public let numericalFileCoverageGap: Bool?
    /// The volume-sources resolution (lot-over-record-group precedence, ported from the app).
    public let volumeSources: ResolvedNAID?
    /// The key that produced `volumeSources` (`"lot:63D135"` / `"rg:59"`), for auditability.
    public let volumeSourcesKey: String?
    /// The bundled collection-authority record (the app's 4-step alias lookup, ported).
    public let collectionAuthority: AuthorityRef?

    public init(liveLookupRoute: String, lotBundle: ResolvedNAID?, lotBundleMiss: String?,
                numericalFileRolls: [NumericalRollRef]?, numericalFileCoverageGap: Bool?,
                volumeSources: ResolvedNAID?, volumeSourcesKey: String?,
                collectionAuthority: AuthorityRef?) {
        self.liveLookupRoute = liveLookupRoute
        self.lotBundle = lotBundle
        self.lotBundleMiss = lotBundleMiss
        self.numericalFileRolls = numericalFileRolls
        self.numericalFileCoverageGap = numericalFileCoverageGap
        self.volumeSources = volumeSources
        self.volumeSourcesKey = volumeSourcesKey
        self.collectionAuthority = collectionAuthority
    }
}

/// A Numerical File roll reference (subset of the bundled roll record).
public struct NumericalRollRef: Codable, Sendable, Equatable {
    public let naId: String
    public let title: String
    public let catalogURL: String

    public init(naId: String, title: String, catalogURL: String) {
        self.naId = naId
        self.title = title
        self.catalogURL = catalogURL
    }
}

/// A collection-authority record reference (identity subset — the authority carries no counts).
public struct AuthorityRef: Codable, Sendable, Equatable {
    /// The record's dedup key (`"lot:64D199"`, `"txt:johnson library|national security file"`).
    public let id: String
    /// The record's canonical display name.
    public let name: String
    /// The resolved NAID, when the authority carries one.
    public let naId: String?
    /// The catalog URL, when resolved.
    public let catalogURL: String?

    public init(id: String, name: String, naId: String?, catalogURL: String?) {
        self.id = id
        self.name = name
        self.naId = naId
        self.catalogURL = catalogURL
    }
}

// MARK: - OfflineOutcome

/// The single-token offline outcome vocabulary for `offlineOutcome` — the strongest offline
/// resolution a record achieved, in precedence order.
public enum OfflineOutcome: String, Sendable, CaseIterable {
    /// The lot resolved through the bundled central-files index (the strongest offline claim).
    case resolvedLotBundle
    /// The 1906–1910 Numerical File rolls resolved the citation's case number.
    case resolvedNumericalFile
    /// The volume-sources index resolved the citation (lot or record-group key).
    case resolvedVolumeSources
    /// Only the collection-authority identity matched (a name/NAID, not a document-level link).
    case resolvedAuthorityOnly
    /// Nothing resolved offline, but the strategy has an onward route — a live NARA Catalog
    /// query (`catalog*Query`) **or** a static guidance link (`staticSeriesLink` /
    /// `staticCFPFGuidance`); consult `liveLookupRoute` to distinguish the two.
    case liveRouteOnly
    /// Nothing resolved offline and the strategy has no catalog route (CIA, foreign archive,
    /// previously published, unrecognized).
    case noResolution
}

// MARK: - Summary

/// The committed aggregate summary of a corpus-wide export run.
public struct SourceExplorerExportSummary: Codable, Sendable, Equatable {
    /// Summary schema version.
    public var schemaVersion: Int
    /// Generation date stamp (`yyyy-MM-dd`).
    public var generated: String
    /// Volumes scanned (manifest-shippable set found in the corpus directory).
    public var volumeCount: Int
    /// Corpus volumes skipped because they are outside the app manifest.
    public var volumesOutsideManifest: Int
    /// Total exported records (documents with a stored source note).
    public var recordCount: Int
    /// Documents whose div carried no `xml:id` (keyed `volumeId/`).
    public var documentsWithoutId: Int
    /// Record counts by strategy slug.
    public var byStrategy: [String: Int]
    /// Record counts by `strategy|offlineOutcome` composite key.
    public var byStrategyOutcome: [String: Int]
    /// Record counts by coverage decade (`"1900"`, `"1950"`, …; `"unknown"` for undated).
    public var byDecade: [String: Int]
    /// Record counts by offline outcome token.
    public var byOutcome: [String: Int]

    public init(schemaVersion: Int, generated: String, volumeCount: Int,
                volumesOutsideManifest: Int, recordCount: Int, documentsWithoutId: Int,
                byStrategy: [String: Int], byStrategyOutcome: [String: Int],
                byDecade: [String: Int], byOutcome: [String: Int]) {
        self.schemaVersion = schemaVersion
        self.generated = generated
        self.volumeCount = volumeCount
        self.volumesOutsideManifest = volumesOutsideManifest
        self.recordCount = recordCount
        self.documentsWithoutId = documentsWithoutId
        self.byStrategy = byStrategy
        self.byStrategyOutcome = byStrategyOutcome
        self.byDecade = byDecade
        self.byOutcome = byOutcome
    }
}
