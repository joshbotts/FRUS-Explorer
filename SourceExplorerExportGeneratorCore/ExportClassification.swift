// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SourceNoteKit

// MARK: - ExportClassification

/// Pure helpers turning a `ParsedSourceNote` into the export's serializable description, the
/// derived keys, and the live NARA Catalog route the app UI would offer.
public enum ExportClassification {

    /// Serializes a parse as its case name + associated values (absent optionals omitted),
    /// so the export is inspectable without Swift. Exhaustive by the compiler.
    public static func describe(_ parsed: ParsedSourceNote) -> ParsedNoteDescription {
        switch parsed {
        case .centralFiles(let recordGroup, let fileIdentifier):
            return .init(kind: "centralFiles", fields: compact([
                "recordGroup": recordGroup, "fileIdentifier": fileIdentifier]))
        case .cfpfFile(let fileIdentifier):
            return .init(kind: "cfpfFile", fields: compact(["fileIdentifier": fileIdentifier]))
        case .lotFile(let recordGroup, let lotNumber, let fileIdentifier):
            return .init(kind: "lotFile", fields: compact([
                "recordGroup": recordGroup, "lotNumber": lotNumber,
                "fileIdentifier": fileIdentifier]))
        case .presidentialLibrary(let library, let collection, let fileIdentifier):
            return .init(kind: "presidentialLibrary", fields: compact([
                "library": library, "collection": collection, "fileIdentifier": fileIdentifier]))
        case .naraCollection(let recordGroup, let series, let lotFile, let box):
            return .init(kind: "naraCollection", fields: compact([
                "recordGroup": recordGroup, "series": series, "lotFile": lotFile, "box": box]))
        case .ciaCollection(let jobNumber, let box, let description):
            return .init(kind: "ciaCollection", fields: compact([
                "jobNumber": jobNumber, "box": box, "description": description]))
        case .namedFileSeries(let seriesName, let fileIdentifier):
            return .init(kind: "namedFileSeries", fields: compact([
                "seriesName": seriesName, "fileIdentifier": fileIdentifier]))
        case .foreignGovernmentArchive(let description):
            return .init(kind: "foreignGovernmentArchive", fields: compact([
                "description": description]))
        case .previouslyPublished(let citation):
            return .init(kind: "previouslyPublished", fields: compact(["citation": citation]))
        case .unrecognized(let rawText):
            return .init(kind: "unrecognized", fields: compact(["rawText": rawText]))
        }
    }

    /// The live NARA Catalog route the app UI offers per strategy — recorded for the audit,
    /// never executed by the export.
    ///
    /// **Parity:** mirrors the app's live-query switch (`SourceExplorerView.swift:1164-1186`),
    /// which executes catalog queries for exactly three cases — `.lotFile`
    /// (`resolveLotFileVariants`), `.naraCollection` (`searchByRecordGroup` + keywords), and
    /// `.presidentialLibrary` (`searchByPresidentialMaterials`) — and the static-link
    /// treatments in the view body (`:265-292`) for the rest.
    public static func liveLookupRoute(for parsed: ParsedSourceNote) -> String {
        switch parsed {
        case .lotFile:
            return "catalogLotVariantsQuery"
        case .naraCollection:
            return "catalogRecordGroupKeywordQuery"
        case .presidentialLibrary:
            return "catalogPresidentialMaterialsQuery"
        case .centralFiles:
            return "staticSeriesLink"
        case .cfpfFile:
            return "staticCFPFGuidance"
        case .ciaCollection, .namedFileSeries, .foreignGovernmentArchive,
             .previouslyPublished, .unrecognized:
            return "noCatalogRoute"
        }
    }

    /// The raw lot number carried by a parse, when it has one — the input to the bundled
    /// lot resolution and to `lotFileNorm`.
    public static func rawLot(of parsed: ParsedSourceNote) -> String? {
        switch parsed {
        case .lotFile(_, let lotNumber, _):
            return lotNumber
        case .naraCollection(_, _, let lotFile, _):
            return lotFile
        default:
            return nil
        }
    }

    /// The derived keys the app computes from a parse + note (neighbor key, lot norm, gated
    /// decimal class, classification marking).
    public static func derivedKeys(for parsed: ParsedSourceNote, note: String) -> DerivedKeys {
        // The decimal class is caller-gated exactly as the app gates it: only for
        // central-files-shaped parses (CollectionKeying.centralFilesClass encodes the gate).
        let decimalClass = CollectionKeying.centralFilesClass(parsed: parsed, note: note)
        return DerivedKeys(
            supportsArchivalNeighbors: parsed.supportsArchivalNeighbors,
            archivalNeighborKey: parsed.archivalNeighborKey,
            lotFileNorm: rawLot(of: parsed).map { SourceNoteParser.lotFileNorm($0) },
            decimalClass: decimalClass,
            classificationMarking: SourceNoteParser.classificationMarking(fromSourceNote: note))
    }

    /// Drops nil values so the serialized field dictionary omits absent optionals.
    private static func compact(_ fields: [String: String?]) -> [String: String] {
        fields.compactMapValues { $0 }
    }
}
