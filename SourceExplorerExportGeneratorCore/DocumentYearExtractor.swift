// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
// The one file of this core that imports the kit, which declares `CentralFilesIndex`,
// `NumericalFileIndex` and `VolumeSourcesIndex` too: the runner's file reads the generators' own.
import FRUSCoreKit

// MARK: - DocumentYearExtractor

/// Extracts each document's year from a volume's TEI, keyed by its `xml:id`: the year Source Explorer
/// gives it (#1976). The dateline's year comes first, by the one rule the views read it by, and the
/// document's own date after it, as the index stores it; the record files the document under that year
/// and opens the 1906–1910 Numerical File's window by it.
///
/// It parses the volume as the index does (`FRUSDocumentParser.parseVolumeFull(volumeData:named:)`) and asks
/// the kit for each document's year (`SourceExplorerDocumentContext.year(of:)`, over the dateline and the
/// first day the index stores, by the functions it stores them by), so the export reads the year the
/// views hydrate from an index of the same file. Until #1976 it read the leading four digits of
/// `frus:doc-dateTime-min` alone, where the views read the dateline alone: over the 553 catalogue volumes,
/// 8,175 documents had one year in the export and another on screen, 23 of them in what they resolved.
///
/// Version history:
///   1.0 — #335: initial implementation
///   1.1 — 2026-11-10 (FRUS Explorer Light, S22b): `XMLParser` from FoundationXML behind `canImport`,
///         where Linux keeps it, and `parse()`'s unused result discarded with `_ =`, which Linux's
///         Foundation warns of, so the web edition compiles this core for check 8's comparator;
///         nothing changes on Apple platforms
///   2.0 — 2026-11-26 (#1976, plan of record row L31, the owner's decision 175): the year Source Explorer reads,
///         the dateline's and then the document's date, from the kit's parse of the volume, in place of the
///         attribute's leading four digits; `extract(fromXML:named:)` is `async throws`, as the parse is
public enum DocumentYearExtractor {

    /// The `documentId → year` map of a volume's TEI XML: each document the parse gives whose dateline or
    /// date gives a year. A document with neither is omitted.
    ///
    /// - Parameters:
    ///   - data: The volume file's bytes.
    ///   - name: The file's name, for the parser's debug log.
    /// - Throws: `FRUSParserError` when the XML is malformed.
    public static func extract(fromXML data: Data, named name: String = "volume.xml") async throws -> [String: Int] {
        let parsed = try await FRUSDocumentParser().parseVolumeFull(volumeData: data, named: name)
        var years: [String: Int] = [:]
        for document in parsed.documents where !document.documentId.isEmpty {
            if let year = SourceExplorerDocumentContext.year(of: document) { years[document.documentId] = year }
        }
        return years
    }
}
