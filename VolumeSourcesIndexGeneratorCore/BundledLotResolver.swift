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
    /// `nil` when the bundle has no exact match.
    public func resolve(rawLot: String) -> ResolvedNAID? {
        guard let lf = byLotKey[Self.normalizeLot(rawLot)] else { return nil }
        return ResolvedNAID(naId: lf.naId, catalogURL: lf.catalogURL, title: lf.title,
                            recordGroup: lf.recordGroup, matchType: "lot")
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
