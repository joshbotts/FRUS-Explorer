// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - TextLayerDocument

/// One document of the R-0 text layer: `{"d": docId, "o": ordinal, "t": text}`.
public struct TextLayerDocument: Sendable, Equatable {

    /// The document's TEI `xml:id`.
    public let id: String

    /// Its ordinal within the volume.
    public let ordinal: Int

    /// Its extracted body text — the coordinate space every span in this program indexes.
    public let text: String

    /// Creates a document.
    public init(id: String, ordinal: Int, text: String) {
        self.id = id
        self.ordinal = ordinal
        self.text = text
    }
}

// MARK: - MarkedMention

/// One row of the `marked/` layer: an editor `<persName>` span placed in R-0 coordinates.
public struct MarkedMention: Sendable, Equatable {

    /// The document the span is in.
    public let document: String

    /// Code-point offset of the first scalar.
    public let start: Int

    /// Code-point offset one past the last.
    public let end: Int

    /// Creates a marked mention.
    public init(document: String, start: Int, end: Int) {
        self.document = document
        self.start = start
        self.end = end
    }
}

// MARK: - NERStoreIO

/// Reading the two stores this tool joins, and writing its own layer.
///
/// **Why the gzip handling looks like this.** Nothing else in the repo reads gzip — the NARA bulk
/// export is streamed uncompressed by design — so there is no in-repo helper to copy, and Apple's
/// `Compression` framework speaks raw DEFLATE rather than the gzip container. Rather than hand-roll
/// a header parser in code that ships without a compile on the machine that wrote it, this reads a
/// plain `<volume>.jsonl` when one is present and otherwise shells out to `/usr/bin/gunzip -c`.
/// That gives an operator a way around the subprocess entirely (`gunzip` one volume — plain, NOT
/// `-k`, which keeps the `.gz` and leaves both present, the one state `jsonLines` refuses) if it ever
/// misbehaves, which a bespoke inflater would not.
///
/// Output is written **uncompressed** for the same reason inverted: the store is read by
/// `score_detections.py`, whose reader takes either extension, so compressing it would add a
/// second subprocess to save disk that nobody is short of. `gzip -n` it afterwards if you want to.
///
/// Version history:
///   1.0 — Session 2026-08-11: #234 R-1 control detector.
public enum NERStoreIO {

    // MARK: Reading

    /// The R-0 text layer for one volume.
    ///
    /// - Parameters:
    ///   - volume: Volume id, e.g. `frus1895p1`.
    ///   - directory: The embeddings store's `text/` directory.
    /// - Returns: Documents in the order the layer lists them.
    /// - Throws: ``DetectorError`` when the file is absent or unreadable.
    public static func textLayer(volume: String, in directory: URL) throws -> [TextLayerDocument] {
        let data = try jsonLines(volume: volume, in: directory)
        let decoder = JSONDecoder()
        return try lines(of: data).map { line in
            let row = try decoder.decode(TextRow.self, from: line)
            return TextLayerDocument(id: row.d, ordinal: row.o, text: row.t)
        }
    }

    /// The `marked/` layer for one volume, or an empty array when the volume has no file.
    ///
    /// - Parameters:
    ///   - volume: Volume id.
    ///   - directory: The NER store's `marked/` directory.
    /// - Returns: The editors' spans.
    /// - Throws: ``DetectorError`` when a present file cannot be read.
    public static func markedLayer(volume: String, in directory: URL) throws -> [MarkedMention] {
        guard fileExists(volume: volume, in: directory) else { return [] }
        let data = try jsonLines(volume: volume, in: directory)
        let decoder = JSONDecoder()
        return try lines(of: data).map { line in
            let row = try decoder.decode(MarkedRow.self, from: line)
            return MarkedMention(document: row.d, start: row.s, end: row.e)
        }
    }

    /// The volume ids in a store's `scope.json`.
    ///
    /// - Parameter store: The NER store directory.
    /// - Returns: The scope, in the order the file lists it.
    /// - Throws: ``DetectorError/missingInput(_:)`` when there is no scope file.
    public static func scopeVolumes(store: URL) throws -> [String] {
        let url = store.appendingPathComponent("scope.json")
        guard let data = try? Data(contentsOf: url) else {
            throw DetectorError.missingInput(url.path + " (run harvest_ner.py first — N-0)")
        }
        return try JSONDecoder().decode(Scope.self, from: data).volumes
    }

    /// The `(volume, document)` pairs named by an M2a ground-truth file.
    ///
    /// Used by `ONLY_DOCUMENTS` to restrict a run to the annotated documents, which is what makes
    /// the control immediately scoreable without a full-corpus pass.
    ///
    /// - Parameter url: Path to `m2a-ground-truth.jsonl`.
    /// - Returns: Document ids grouped by volume.
    /// - Throws: ``DetectorError/missingInput(_:)`` when the file is absent.
    public static func groundTruthDocuments(at url: URL) throws -> [String: Set<String>] {
        guard let data = try? Data(contentsOf: url) else {
            throw DetectorError.missingInput(url.path)
        }
        let decoder = JSONDecoder()
        var grouped: [String: Set<String>] = [:]
        for line in lines(of: data) {
            let row = try decoder.decode(GroundTruthRow.self, from: line)
            grouped[row.v, default: []].insert(row.d)
        }
        return grouped
    }

    // MARK: Writing

    /// Writes one volume's detected rows as JSON lines, in the store's row shape.
    ///
    /// - Parameters:
    ///   - rows: Already sorted; this does not re-order them.
    ///   - url: Destination file.
    /// - Throws: Whatever `Data.write(to:)` throws.
    public static func writeDetected(_ rows: [DetectedRow], to url: URL) throws {
        var out = ""
        for row in rows {
            // Hand-built rather than encoded so the key ORDER matches the Python writer's rows,
            // which keeps the two producers' output diffable. `ci` is deliberately ABSENT: it is
            // the chunk index a windowed LLM pass emits, this detector does not chunk, and
            // writing a constant 0 would fabricate a field a reader could believe. Its absence
            // raises a KeyError in a Python consumer that wants it, which is the loud failure;
            // a real value would have to come from the same chunker harvest_embeddings.py uses,
            // and that lives on the Python side.
            out += "{\"d\":\(quote(row.document)),\"o\":\(row.ordinal),\"s\":\(row.start),"
            out += "\"e\":\(row.end),\"n\":\(quote(row.surface))}\n"
        }
        try Data(out.utf8).write(to: url)
    }

    /// Encodes a value as pretty, key-sorted JSON — the shape every head/manifest file in this
    /// program uses, so a diff between runs shows content and not ordering.
    ///
    /// - Parameter value: The value to encode.
    /// - Returns: JSON data.
    /// - Throws: Whatever `JSONEncoder` throws.
    public static func encodeJSON<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    // MARK: Private

    private struct TextRow: Decodable { let d: String; let o: Int; let t: String }
    private struct MarkedRow: Decodable { let d: String; let s: Int; let e: Int }
    private struct GroundTruthRow: Decodable { let v: String; let d: String }
    private struct Scope: Decodable { let volumes: [String] }

    private static func fileExists(volume: String, in directory: URL) -> Bool {
        let plain = directory.appendingPathComponent(volume + ".jsonl")
        let zipped = directory.appendingPathComponent(volume + ".jsonl.gz")
        return FileManager.default.fileExists(atPath: plain.path)
            || FileManager.default.fileExists(atPath: zipped.path)
    }

    private static func jsonLines(volume: String, in directory: URL) throws -> Data {
        let plain = directory.appendingPathComponent(volume + ".jsonl")
        let bothPresent = FileManager.default.fileExists(atPath: plain.path)
            && FileManager.default.fileExists(
                atPath: directory.appendingPathComponent(volume + ".jsonl.gz").path)
        guard !bothPresent else {
            // The two readers resolved this ambiguity in opposite orders, so one stale copy
            // beside a fresh one meant Swift and Python scored different rows and neither said
            // anything. Refusing costs an `rm`; disagreeing costs a wrong comparison.
            throw DetectorError.unreadableTextLayer(
                "\(volume) exists as BOTH .jsonl and .jsonl.gz in \(directory.path) — "
                + "delete the stale one; a reader cannot tell which you meant")
        }
        if FileManager.default.fileExists(atPath: plain.path) {
            guard let data = try? Data(contentsOf: plain) else {
                throw DetectorError.unreadableTextLayer(plain.path)
            }
            return data
        }
        let zipped = directory.appendingPathComponent(volume + ".jsonl.gz")
        guard FileManager.default.fileExists(atPath: zipped.path) else {
            throw DetectorError.missingInput(zipped.path)
        }
        return try gunzip(zipped)
    }

    private static func gunzip(_ url: URL) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/gunzip")
        process.arguments = ["-c", url.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            throw DetectorError.unreadableTextLayer("/usr/bin/gunzip could not start: \(error)")
        }
        // Drain before waiting: a volume's text layer is far larger than a pipe buffer, and
        // waiting first would deadlock as soon as gunzip filled it.
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw DetectorError.unreadableTextLayer("gunzip exited \(process.terminationStatus) "
                                                    + "for \(url.lastPathComponent)")
        }
        return data
    }

    private static func lines(of data: Data) -> [Data] {
        // `.map { Data($0) }` rather than `.map(Data.init)`: Data has many single-argument
        // initializers and an unapplied reference makes the compiler resolve them all.
        // Trailing CR is dropped, the way CatalogBulkExportClient's NDJSON reader does — a
        // CRLF-terminated file would otherwise hand the decoder a stray byte.
        data.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: true)
            .map { slice -> Data in
                var line = Data(slice)
                if line.last == UInt8(ascii: "\r") { line.removeLast() }
                return line
            }
    }

    private static func quote(_ value: String) -> String {
        // Escaped by hand, to the same set `harvest_ner.py` emits: it writes with
        // `ensure_ascii=False`, so non-ASCII scalars stay raw on BOTH sides and an accented
        // surname is one UTF-8 string rather than `\uXXXX` in one store and `José` in the other.
        var out = "\""
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case "\u{08}": out += "\\b"
            case "\u{0C}": out += "\\f"
            default:
                if scalar.value < 0x20 {
                    let hex = String(scalar.value, radix: 16)
                    out += "\\u" + String(repeating: "0", count: 4 - hex.count) + hex
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        return out + "\""
    }
}

// MARK: - DetectedRow

/// One row of the `detected/` layer, in the shape `harvest_ner.py` writes and
/// `score_detections.py` reads.
public struct DetectedRow: Sendable, Equatable {

    /// The document's `xml:id`.
    public let document: String

    /// Its ordinal in the volume.
    public let ordinal: Int

    /// Code-point offset of the first scalar.
    public let start: Int

    /// Code-point offset one past the last.
    public let end: Int

    /// The text the span covers.
    public let surface: String

    /// Creates a row.
    public init(document: String, ordinal: Int, start: Int, end: Int, surface: String) {
        self.document = document
        self.ordinal = ordinal
        self.start = start
        self.end = end
        self.surface = surface
    }
}
