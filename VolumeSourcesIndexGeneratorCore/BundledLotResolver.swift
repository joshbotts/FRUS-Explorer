// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// A NARA Catalog match for an archival collection: the resolved authority record.
public struct ResolvedNAID: Sendable, Equatable, Codable {
    public let naId: String
    public let catalogURL: String
    public let title: String
    public let recordGroup: String?
    /// How the match was made: `lot` (bundled lot-file index), `api` (NARA Catalog query),
    /// or `manual` (a curated record-group/repository mapping).
    public let matchType: String
    /// The series' **HMS/MLR Entry Number(s)** — the identifier NARA staff ask researchers to
    /// quote when requesting the records (#315/#322). Carried through from the enriched
    /// `central-files-index` so the volume-sources surface shows the same detail Source Explorer
    /// does. `nil` for record-group / API resolutions and un-enriched entries.
    public let hmsMlrEntryNumbers: [String]?
    /// The resolved record's catalog level (`series`, `fileUnit`, …), so a consumer can tell
    /// whether `title` is really a series title (#315/#322).
    public let levelOfDescription: String?
    /// NAID of the enclosing file series, when the record is a file unit (#315/#322).
    public let seriesNaId: String?
    /// Title of the enclosing file series, for records whose own `title` names a file unit.
    public let seriesTitle: String?
    /// The enclosing series' HMS/MLR entry numbers — the parent's identifiers, not this
    /// record's (kept separate because a parent series may carry many; #315/#322).
    public let seriesHmsMlrEntryNumbers: [String]?

    /// Memberwise initializer (public so sibling generators — the Phase 4
    /// `CollectionAuthorityGeneratorCore` offline resolver — can construct records
    /// from cached resolutions). The enrichment fields default to `nil` so existing
    /// call sites (record-group / API resolutions) are unchanged.
    public init(naId: String, catalogURL: String, title: String,
                recordGroup: String?, matchType: String,
                hmsMlrEntryNumbers: [String]? = nil, levelOfDescription: String? = nil,
                seriesNaId: String? = nil, seriesTitle: String? = nil,
                seriesHmsMlrEntryNumbers: [String]? = nil) {
        self.naId = naId
        self.catalogURL = catalogURL
        self.title = title
        self.recordGroup = recordGroup
        self.matchType = matchType
        self.hmsMlrEntryNumbers = hmsMlrEntryNumbers
        self.levelOfDescription = levelOfDescription
        self.seriesNaId = seriesNaId
        self.seriesTitle = seriesTitle
        self.seriesHmsMlrEntryNumbers = seriesHmsMlrEntryNumbers
    }
}

/// Resolves lot-file citations to NARA Catalog records offline, using the bundled
/// `central-files-index.json` (the same artifact the app's `CentralFilesIndexStore` reads).
///
/// Only the `lotFiles` component is needed for harvesting; the numerical-file and
/// country-series components are decoded leniently and ignored.
public struct BundledLotResolver: Sendable {

    private struct Index: Decodable {
        struct LotFile: Decodable {
            let lotNumber: String
            let recordGroup: String
            let naId: String
            let title: String
            let catalogURL: String
            // #322 enrichment fields, carried through to the volume-sources surface.
            // decodeIfPresent so a pre-enrichment central-files-index still loads.
            let hmsMlrEntryNumbers: [String]?
            let levelOfDescription: String?
            let seriesNaId: String?
            let seriesTitle: String?
            let seriesHmsMlrEntryNumbers: [String]?
            /// `true` when the record's ancestry contains no record group — a candidate
            /// mis-resolution (#321). Treated as unresolved here, mirroring the app's
            /// `CentralFilesIndex` guard, so a wrong resolution never enters volume-sources.
            let ancestryLacksRecordGroup: Bool?
        }
        let lotFiles: [LotFile]?
    }

    private let byLotKey: [String: Index.LotFile]

    /// Loads the bundled index from `central-files-index.json`. Throws if the file is
    /// unreadable or malformed.
    public init(indexURL: URL) throws {
        let data = try Data(contentsOf: indexURL)
        let index = try JSONDecoder().decode(Index.self, from: data)
        var map: [String: Index.LotFile] = [:]
        for lf in index.lotFiles ?? [] { map[lf.lotNumber] = lf }
        byLotKey = map
    }

    /// The number of pre-resolved lot files available.
    public var lotFileCount: Int { byLotKey.count }

    /// Resolves a raw lot number (`"63 D 135"`, `"Lot 80 D 212"`) to its bundled record, or
    /// `nil` when the bundle has no exact match — or when the match is flagged
    /// `ancestryLacksRecordGroup` (#321): those are treated as **unresolved**, exactly as the
    /// app's `CentralFilesIndex` does, so a candidate mis-resolution never propagates into
    /// volume-sources. The #315 enrichment fields ride through for accepted matches (#322).
    public func resolve(rawLot: String) -> ResolvedNAID? {
        guard let lf = byLotKey[Self.normalizeLot(rawLot)],
              lf.ancestryLacksRecordGroup != true else { return nil }
        return ResolvedNAID(naId: lf.naId, catalogURL: lf.catalogURL, title: lf.title,
                            recordGroup: lf.recordGroup, matchType: "lot",
                            hmsMlrEntryNumbers: lf.hmsMlrEntryNumbers,
                            levelOfDescription: lf.levelOfDescription,
                            seriesNaId: lf.seriesNaId, seriesTitle: lf.seriesTitle,
                            seriesHmsMlrEntryNumbers: lf.seriesHmsMlrEntryNumbers)
    }

    /// Compact upper-cased lot key (`61–D 146` → `61D146`), matching the bundle's form and
    /// the app's `CentralFilesIndex.normalizeLot`.
    public static func normalizeLot(_ raw: String) -> String {
        raw.uppercased()
            .replacingOccurrences(of: "LOT ", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "–", with: "")
            .replacingOccurrences(of: "—", with: "")
    }
}
