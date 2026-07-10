// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import CrossRefValidationGeneratorCore

struct AnchorInventoryTests {

    @Test("Extracts every xml:id, including pb page ids and single-quoted values")
    func extractsIds() {
        let xml = """
        <TEI xml:id="frus1901">
        <div type="document" xml:id="d1"><pb n="5" xml:id="pg_5"/><note xml:id="d1fn1">x</note></div>
        <term xml:id='t_ABC1'>y</term>
        <item xml:id="in14">z</item>
        </TEI>
        """
        let ids = AnchorInventory.xmlIds(in: Data(xml.utf8))
        #expect(ids == ["frus1901", "d1", "pg_5", "d1fn1", "t_ABC1", "in14"])
    }

    @Test("Does not false-match an attribute that merely ends in the id substring")
    func boundaryGuard() {
        // A hypothetical attribute like `dataxml:id` must not be picked up as an xml:id.
        let xml = #"<x dataxml:id="nope" xml:id="yes"/>"#
        let ids = AnchorInventory.xmlIds(in: Data(xml.utf8))
        #expect(ids == ["yes"])
    }

    @Test("Empty input yields an empty inventory")
    func empty() {
        #expect(AnchorInventory.xmlIds(in: Data()).isEmpty)
    }

    @Test("xml:id inside comments, CDATA, and PIs is never inventoried (phantom-anchor guard)")
    func skipsNonMarkupRegions() {
        // Mirrors the real-corpus failure class: frus1981-88v10 has 2,215 commented-out
        // facsimile page breaks; frus1977-80v09 comments out its named front-matter divisions.
        let xml = """
        <body>
        <!-- <pb facs="d1-1" n="1" type="facsimile" xml:id="d1-1"/> -->
        <!-- <div xml:id="persons" type="section"/> -->
        <p><![CDATA[ xml:id="cdata-id" ]]></p>
        <?pi xml:id="pi-id" ?>
        <div type="document" xml:id="d1"><pb n="5" xml:id="pg_5"/></div>
        </body>
        """
        let ids = AnchorInventory.xmlIds(in: Data(xml.utf8))
        #expect(ids == ["d1", "pg_5"])
    }

    @Test("An unterminated quoted value at EOF is rejected, not truncated into a phantom id")
    func unterminatedQuote() {
        let ids = AnchorInventory.xmlIds(in: Data(#"<x xml:id="good"/><y xml:id="trunc"#.utf8))
        #expect(ids == ["good"])
    }
}
