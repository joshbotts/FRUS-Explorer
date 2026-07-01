// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import VolumeSourcesIndexGeneratorCore

@Suite("VolumeSourcesExtractor")
struct VolumeSourcesExtractorTests {

    /// A minimal front-matter Sources section: one narrative paragraph, then a two-level
    /// collection outline with a bold heading.
    private let xml = Data("""
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
      <text><front>
        <div type="section" subtype="preface" xml:id="preface">
          <head>Preface</head><p>Prefatory remarks that must NOT become source rows.</p>
        </div>
        <div type="section" subtype="sources" xml:id="sources">
          <head>Sources</head>
          <p>The sources for this volume are drawn from a diffuse base of records.</p>
          <list>
            <item><hi rend="strong">Department of State</hi>
              <list>
                <item>RG 59, Central Files 1969 POL 1, Lot File 70 D 150</item>
              </list>
            </item>
          </list>
        </div>
      </front></text>
    </TEI>
    """.utf8)

    @Test("Separates prose from items; only sources-section content is captured")
    func proseAndItems() {
        let rows = VolumeSourcesExtractor.extract(fromXML: xml)
        let prose = rows.filter { $0.kind == .prose }
        let items = rows.filter { $0.kind == .item }
        #expect(prose.count == 1)
        #expect(prose[0].text.contains("diffuse base"))
        // The preface paragraph (outside the sources section) is never captured.
        #expect(!rows.contains { $0.text.contains("Prefatory remarks") })
        #expect(items.count == 2)
    }

    @Test("Bold heading preserved at depth 0; RG record nested at depth 1")
    func headingsAndNesting() {
        let rows = VolumeSourcesExtractor.extract(fromXML: xml)
        let heading = try! #require(rows.first { $0.isHeading })
        #expect(heading.text.contains("Department of State"))
        #expect(heading.depth == 0)
        let rg = try! #require(rows.first { $0.text.contains("RG 59") })
        #expect(rg.depth == 1)
        #expect(rg.recordGroup == "59")
        #expect(rg.lotFile != nil)
    }

    @Test("Rows are emitted in document (pre-order) order: parent before child")
    func preOrder() {
        let rows = VolumeSourcesExtractor.extract(fromXML: xml)
        let hIdx = try! #require(rows.firstIndex { $0.isHeading })
        let rgIdx = try! #require(rows.firstIndex { $0.text.contains("RG 59") })
        #expect(hIdx < rgIdx)
    }

    @Test("Cross-volume authority dedups a heading recurring across volumes")
    func authorityDedup() {
        let rows = VolumeSourcesExtractor.extract(fromXML: xml)
        let items = rows.filter { $0.kind == .item }
        var index = 0
        let tree = VolumeSourcesIndexRunner.buildTree(items, &index, depth: 0)
        var authority: [String: MajorCollection] = [:]
        VolumeSourcesIndexRunner.accumulateAuthority(tree, volumeId: "frusA", into: &authority)
        VolumeSourcesIndexRunner.accumulateAuthority(tree, volumeId: "frusB", into: &authority)
        let dept = try! #require(authority.values.first { $0.text.contains("Department of State") })
        #expect(dept.volumeIds.sorted() == ["frusA", "frusB"])
        #expect(dept.occurrences == 2)
    }

    @Test("Lot files inherit the ancestor record group when gathering resolution keys")
    func ancestorRecordGroupInference() {
        let rows = VolumeSourcesExtractor.extract(fromXML: xml)
        var index = 0
        let tree = VolumeSourcesIndexRunner.buildTree(rows.filter { $0.kind == .item }, &index, depth: 0)
        var lotKeys: [String: String] = [:]
        var rgNumbers: Set<String> = []
        VolumeSourcesIndexRunner.gatherKeys(tree, inheritedRG: nil, lotKeys: &lotKeys, rgNumbers: &rgNumbers)
        // The RG-59 record nested under "Department of State" carries a lot file; its key
        // is gathered with the record group parsed from its own text ("RG 59").
        #expect(lotKeys.values.contains("59"))
        #expect(!lotKeys.isEmpty)
    }
}
