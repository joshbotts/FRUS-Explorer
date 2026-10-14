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

// MARK: - TEIPublicationYearTests

/// The print year a citation reads from a volume's TEI header (e67bed9), which both apps and the
/// web edition read with the kit's one scan.
///
/// Version history:
///   1.0 — FRUS Explorer Light: initial implementation, with the scan moved into the kit
@Suite("TEI publication year")
struct TEIPublicationYearTests {

    /// A header shaped as the corpus prints it: the publication date as the element's text, and the
    /// content date after it, whose first year is the coverage's and not the print year.
    private func header(_ publicationDate: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0"><teiHeader><fileDesc>
            <publicationStmt>
                <publisher>United States Government Printing Office</publisher>
                <pubPlace>Washington</pubPlace>
                \(publicationDate)
                <idno type="frus">frus1961-63v06</idno>
                <date calendar="gregorian" notAfter="1963-12-01T23:59:59-05:00"
                    notBefore="1960-11-09T00:00:00-05:00" type="content-date">1960 to 1963</date>
            </publicationStmt>
        </fileDesc></teiHeader>
        """
    }

    @Test("The publication date printed as the element's text is the year")
    func bareYear() {
        #expect(TEIPublicationYear.year(inHeader: header(
            #"<date calendar="gregorian" type="publication-date">1996</date>"#)) == "1996")
    }

    @Test("A @when year wins over the element's text")
    func whenWins() {
        #expect(TEIPublicationYear.year(inHeader: header(
            #"<date type="publication-date" when="2010">2011</date>"#)) == "2010")
    }

    @Test("A year outside 1751–2099 is not a publication year")
    func implausibleYears() {
        #expect(TEIPublicationYear.year(inHeader: header(#"<date when="1750">1750</date>"#)) == nil)
        #expect(TEIPublicationYear.year(inHeader: header(#"<date when="2100">2100</date>"#)) == nil)
        #expect(TEIPublicationYear.year(inHeader: header(#"<date when="1751"/>"#)) == "1751")
    }

    @Test("A header with no publication statement states no year")
    func noStatement() {
        #expect(TEIPublicationYear.year(inHeader: "<TEI><teiHeader><fileDesc/></teiHeader>") == nil)
        #expect(TEIPublicationYear.year(inHeader: "</publicationStmt><publicationStmt>1996") == nil)
    }

    @Test("A volume's file is read from its first 8 KB, and a missing file states nothing")
    func readsTheFile() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSPubYear-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("frus1961-63v06.xml")
        let body = String(repeating: "<p>text</p>\n", count: 2_000)
        try Data((header(#"<date type="publication-date">1996</date>"#) + body).utf8).write(to: file)
        #expect(TEIPublicationYear.read(from: file) == "1996")

        // A statement that begins after the first 8 KB is not read.
        let late = dir.appendingPathComponent("late.xml")
        try Data((String(repeating: " ", count: TEIPublicationYear.headerPrefixBytes)
                  + header(#"<date>1996</date>"#)).utf8).write(to: late)
        #expect(TEIPublicationYear.read(from: late) == nil)
        #expect(TEIPublicationYear.read(from: dir.appendingPathComponent("absent.xml")) == nil)
    }
}
