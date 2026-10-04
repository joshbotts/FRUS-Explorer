// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif

// MARK: - ReaderRenderingTests

/// The reader's lookups and converter (`ReaderRendering.swift`), which `DocumentViewModel.load`
/// and FRUS Explorer Light both render through. The page they produce is pinned by the web
/// edition's golden HTML; these pin the rules the lookups carry.
@Suite("Reader rendering — the lookups the reader resolves a document's links against")
struct ReaderRenderingTests {

    private let persons = [
        PersonEntry(ref: "p_AD1", name: "Acheson, Dean"),
        PersonEntry(ref: "p_KGF1", name: "Kennan, George F."),
        PersonEntry(ref: "p_AD1", name: "Acheson, Dean G."),
    ]

    private let terms = [
        GlossEntry(ref: "t_NSC1", term: "NSC", definition: "National Security Council"),
        GlossEntry(ref: "t_JCS1", term: "JCS", definition: "Joint Chiefs of Staff"),
        GlossEntry(ref: "t_NSC2", term: "nsc", definition: "the Council"),
    ]

    @Test("Persons and terms are keyed by ref, and terms by lowercased text; a repeated key keeps its last entry")
    func lookupsKeyTheEntries() {
        let lookups = ReaderLookups(persons: persons, terms: terms)
        #expect(lookups.personsByRef.count == 2)
        #expect(lookups.personsByRef["p_AD1"]?.name == "Acheson, Dean G.")
        #expect(lookups.termsByRef.count == 3)
        #expect(lookups.termsByRef["t_NSC1"]?.definition == "National Security Council")
        #expect(lookups.termsByText.count == 2)
        #expect(lookups.termsByText["nsc"]?.ref == "t_NSC2")
        #expect(lookups.termsByText["NSC"] == nil)
    }

    @Test("The reader's converter resolves persons and terms by ref, and an <abbr> by its text in any case")
    func converterResolvesThroughTheLookups() {
        let converter = ASTToRenderNodeConverter(
            readerOf: "frus1961-63v06", lookups: ReaderLookups(persons: persons, terms: terms), brokenRefs: nil)
        #expect(converter.volumeId == "frus1961-63v06")
        #expect(converter.personLookup?("p_KGF1")?.name == "Kennan, George F.")
        #expect(converter.personLookup?("p_none") == nil)
        #expect(converter.glossLookup?("t_JCS1")?.term == "JCS")
        #expect(converter.abbrLookup?("JcS")?.ref == "t_JCS1")
        #expect(converter.abbrLookup?("NSC")?.ref == "t_NSC2")
        // No index: nothing is degraded.
        #expect(converter.brokenRefLookup?("#dX") == nil)
    }

    @Test("A broken reference is degraded by the index for the converter's volume only")
    func brokenReferencesAreVolumeScoped() throws {
        let json = """
        {"schemaVersion":1,"generated":"2026-10-04","corpusVolumeCount":1,"seriesVolumeCount":1,\
        "totalBroken":1,"fullDetail":true,"records":[\
        {"sv":"frus1901","sd":"d1","t":"#dX","r":"unknownAnchor","rv":"frus1901","ra":"dX"}]}
        """
        let index = try JSONDecoder().decode(BrokenRefsIndex.self, from: Data(json.utf8))
        let lookups = ReaderLookups(persons: [], terms: [])
        let inVolume = ASTToRenderNodeConverter(readerOf: "frus1901", lookups: lookups, brokenRefs: index)
        #expect(inVolume.brokenRefLookup?("#dX")?.reason == "unknownAnchor")
        #expect(inVolume.brokenRefLookup?("#d1") == nil)
        let elsewhere = ASTToRenderNodeConverter(readerOf: "frus1902", lookups: lookups, brokenRefs: index)
        #expect(elsewhere.brokenRefLookup?("#dX") == nil)
    }
}
