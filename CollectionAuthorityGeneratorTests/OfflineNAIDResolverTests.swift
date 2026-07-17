// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import CollectionAuthorityGeneratorCore
import VolumeSourcesIndexGeneratorCore

/// Tests the #352 fileUnit guard on `OfflineNAIDResolver`'s volume-sources fallback — the
/// collection-authority generator must not resolve a lot cluster to a `fileUnit`-level
/// mis-resolution carried in the bundled `volume-sources-index.json` `lots` map (the
/// 60 D 627 → "Operation Mongoose" class). Without the guard, cleaning `central-files` (so its
/// entry is gone) would let the resolver fall through to the wrong volume-sources NAID and
/// re-poison the authority clusters.
struct OfflineNAIDResolverTests {

    /// Builds a resolver whose only source is a synthetic volume-sources `lots` map.
    private func resolver(lotsJSON: String) throws -> OfflineNAIDResolver {
        let json = "{\"recordGroups\":{},\"lots\":{\(lotsJSON)},\"majorCollections\":[]}"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("vs-\(UUID().uuidString).json")
        try Data(json.utf8).write(to: url)
        return OfflineNAIDResolver(centralFilesIndexURL: nil,
                                   volumeSourcesIndexURL: url, cacheDirectory: nil)
    }

    @Test("Skips a fileUnit-level volume-sources lot resolution; resolves a series-level one")
    func skipsFileUnitFromVolumeSources() throws {
        let r = try resolver(lotsJSON: """
        "60D627":{"naId":"609235170","catalogURL":"https://catalog.archives.gov/id/609235170",
                  "title":"Lot File 660501, Cuba - 1963","matchType":"lot","levelOfDescription":"fileUnit"},
        "64D199":{"naId":"602231","catalogURL":"https://catalog.archives.gov/id/602231",
                  "title":"Conference Files","matchType":"lot","levelOfDescription":"series"}
        """)
        #expect(r.resolve(lotNorm: "60D627") == nil, "the fileUnit mis-resolution must not resolve")
        #expect(r.resolve(lotNorm: "64D199")?.naId == "602231", "a series-level lot still resolves")
    }

    @Test("A volume-sources lot with no level (un-enriched) still resolves")
    func resolvesUnleveledVolumeSourcesLot() throws {
        let r = try resolver(lotsJSON: """
        "70D100":{"naId":"3","catalogURL":"https://catalog.archives.gov/id/3","title":"x","matchType":"lot"}
        """)
        #expect(r.resolve(lotNorm: "70D100")?.naId == "3")
    }
}
