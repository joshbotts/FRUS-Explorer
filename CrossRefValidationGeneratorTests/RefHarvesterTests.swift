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

struct RefHarvesterTests {

    @Test("Harvests refs with line, enclosing document, and a `<ref`-anchored byte offset")
    func harvestsWithLocation() {
        let xml = [
            "<body>",
            "<div type=\"document\" xml:id=\"d1\"><p><ref target=\"#d2\">a</ref></p></div>",
            "<div type=\"section\" xml:id=\"toc\"><ref target=\"#pg_5\"/></div>",
            "<!-- <ref target=\"#ignoreme\">c</ref> -->",
            "</body>",
        ].joined(separator: "\n")

        let refs = RefHarvester.harvest(from: Data(xml.utf8))

        // The ref inside the comment is skipped.
        #expect(refs.count == 2)

        #expect(refs[0].rawTarget == "#d2")
        #expect(refs[0].line == 2)
        #expect(refs[0].enclosingDocument == "d1")

        // A self-closing ref inside a non-document section div → no enclosing document.
        #expect(refs[1].rawTarget == "#pg_5")
        #expect(refs[1].line == 3)
        #expect(refs[1].enclosingDocument == nil)

        // Byte offsets point at the '<' of each `<ref`.
        let bytes = Array(xml.utf8)
        for ref in refs {
            #expect(ref.byteOffset >= 0 && ref.byteOffset + 4 <= bytes.count)
            #expect(Array(bytes[ref.byteOffset..<ref.byteOffset + 4]) == Array("<ref".utf8))
        }
    }

    @Test("Nested divs attribute a ref to the innermost enclosing document")
    func innermostDocument() {
        let xml = "<div type=\"section\" xml:id=\"s1\">"
            + "<div type=\"document\" xml:id=\"d5\"><ref target=\"#x\"/></div></div>"
        let refs = RefHarvester.harvest(from: Data(xml.utf8))
        #expect(refs.count == 1)
        #expect(refs[0].enclosingDocument == "d5")
    }

    @Test("A ref with no target attribute is skipped")
    func noTarget() {
        let refs = RefHarvester.harvest(from: Data("<p><ref>bare</ref></p>".utf8))
        #expect(refs.isEmpty)
    }

    @Test("A multi-line <ref> tag (46% of the real corpus) reports the '<' line and keeps the count in sync")
    func multiLineRefTag() {
        let xml = [
            "<div type=\"document\" xml:id=\"d1\"><p>",   // line 1
            "<ref",                                        // line 2 — the '<' of the first ref
            "    target=\"#d2\">a</ref>",                  // line 3
            "</p></div>",                                  // line 4
            "<p><ref target=\"#d3\"/></p>",                // line 5 — sync check after the tag
        ].joined(separator: "\n")
        let refs = RefHarvester.harvest(from: Data(xml.utf8))
        #expect(refs.count == 2)
        #expect(refs[0].rawTarget == "#d2")
        #expect(refs[0].line == 2)
        #expect(refs[0].enclosingDocument == "d1")
        #expect(refs[1].rawTarget == "#d3")
        #expect(refs[1].line == 5)
        let bytes = Array(xml.utf8)
        #expect(Array(bytes[refs[0].byteOffset..<refs[0].byteOffset + 4]) == Array("<ref".utf8))
    }

    @Test("Refs inside CDATA and processing instructions are skipped")
    func cdataAndPISkipped() {
        let xml = "<p><![CDATA[<ref target=\"#no1\">x</ref>]]>"
            + "<?pi <ref target=\"#no2\"?><ref target=\"#yes\"/></p>"
        let refs = RefHarvester.harvest(from: Data(xml.utf8))
        #expect(refs.map(\.rawTarget) == ["#yes"])
    }

    @Test("A single-quoted target attribute is captured")
    func singleQuotedTarget() {
        let refs = RefHarvester.harvest(from: Data("<p><ref target='#d5'>x</ref></p>".utf8))
        #expect(refs.map(\.rawTarget) == ["#d5"])
    }

    @Test("A stray </div> with an empty stack does not crash or corrupt attribution")
    func extraDivClose() {
        let refs = RefHarvester.harvest(from: Data("</div><p><ref target=\"#x\"/></p>".utf8))
        #expect(refs.count == 1)
        #expect(refs[0].enclosingDocument == nil)
    }

    @Test("A self-closing <div/> is not pushed onto the stack")
    func selfClosingDiv() {
        let xml = "<div type=\"document\" xml:id=\"d9\"/><p><ref target=\"#x\"/></p>"
        let refs = RefHarvester.harvest(from: Data(xml.utf8))
        #expect(refs.count == 1)
        #expect(refs[0].enclosingDocument == nil)
    }
}
