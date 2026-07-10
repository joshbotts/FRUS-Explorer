// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import GeneratorKit

struct GeneratorKitTests {

    // MARK: - CSVWriter

    @Test("Plain fields pass through unquoted")
    func csvPlainFields() {
        #expect(CSVWriter.field("frus1901") == "frus1901")
        #expect(CSVWriter.field("d123") == "d123")
        #expect(CSVWriter.field("") == "")
    }

    @Test("Fields with commas, quotes, or newlines are quoted and escaped")
    func csvSpecialFields() {
        #expect(CSVWriter.field("a,b") == "\"a,b\"")
        #expect(CSVWriter.field("say \"hi\"") == "\"say \"\"hi\"\"\"")
        #expect(CSVWriter.field("line1\nline2") == "\"line1\nline2\"")
        #expect(CSVWriter.field("cr\rlf") == "\"cr\rlf\"")
    }

    @Test("Rows are comma-joined and CRLF-terminated")
    func csvRow() {
        #expect(CSVWriter.row(["a", "b,c", "d"]) == "a,\"b,c\",d\r\n")
    }

    @Test("A document is a header row plus data rows")
    func csvDocument() {
        let doc = CSVWriter.document(header: ["vol", "target"],
                                     rows: [["frus1901", "frus1877#pg_1077"],
                                            ["frus1910", "#in3"]])
        #expect(doc == "vol,target\r\nfrus1901,frus1877#pg_1077\r\nfrus1910,#in3\r\n")
    }

    // MARK: - Date stamp

    @Test("An explicit GENERATED_DATE override is returned verbatim")
    func dateStampOverride() {
        #expect(generatorDateStamp(override: "2026-07-10") == "2026-07-10")
    }

    @Test("A nil or empty override falls back to a well-formed yyyy-MM-dd stamp")
    func dateStampFallback() {
        let stamp = generatorDateStamp(override: nil)
        #expect(stamp.wholeMatch(of: /\d{4}-\d{2}-\d{2}/) != nil)
        #expect(generatorDateStamp(override: "") == stamp)
    }

    // MARK: - VolumeCorpusEnumerator

    @Test("Enumerates only .xml files, sorted by filename")
    func enumeratorSortsAndFilters() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gkit-enum-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        for name in ["frus1910.xml", "frus1861.xml", "readme.txt", "frus1901.xml"] {
            try Data("x".utf8).write(to: dir.appendingPathComponent(name))
        }
        let files = try VolumeCorpusEnumerator.volumeFiles(in: dir)
        #expect(files.map { $0.lastPathComponent } == ["frus1861.xml", "frus1901.xml", "frus1910.xml"])
        #expect(VolumeCorpusEnumerator.volumeId(for: files[0]) == "frus1861")
    }
}
