// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Errors thrown by `TEIHeaderFetcher`.
public enum TEIHeaderFetcherError: Error, Sendable {
    case badHTTPStatus(Int)
    case unexpectedResponseType
    case headerNotFound
}

/// Streams a FRUS volume XML file and returns only the `<teiHeader>` portion.
///
/// FRUS volumes range from 1 MB to 30+ MB, but the `<teiHeader>` is always within
/// the first ~50 KB. This fetcher reads the response byte-by-byte in 4 KB chunks and
/// stops as soon as `</teiHeader>` is encountered, avoiding the cost of downloading the
/// full file.
///
/// The returned `Data` ends with `</teiHeader>` and may be appended with `</TEI>` to
/// form valid XML for passing to `TEIHeaderParser`.
///
/// Version history:
///   1.0 — Session 02: initial implementation
///   1.1 — Session 2026-10-04: imports `FoundationNetworking` where it exists (Linux), which holds
///          `URLSession` there. swift-corelibs-foundation has no `URLSession.bytes(for:)`, so on
///          Linux the response is read whole with `data(for:)` and then scanned for `</teiHeader>`
///          as before; Apple platforms still stream it with `bytes(for:)`
public struct TEIHeaderFetcher {

    /// Maximum bytes to read before giving up on finding `</teiHeader>`.
    /// Headers are always within the first 512 KB; this guards against malformed files.
    private static let maxBytesToRead = 512_000

    /// Byte buffer chunk size. Balances memory use with search frequency.
    private static let chunkSize = 4_096

    private init() {}

    /// Fetches a FRUS volume XML file and returns bytes up to and including `</teiHeader>`.
    ///
    /// - Parameters:
    ///   - url: The raw download URL for the volume XML.
    ///   - session: URLSession to use. Defaults to `.shared`.
    /// - Returns: Raw XML bytes from the start of the file through `</teiHeader>`.
    /// - Throws: `TEIHeaderFetcherError` if the request fails or the header is not found
    ///   within `maxBytesToRead` bytes.
    public static func fetch(from url: URL, session: URLSession = .shared) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("FRUSExplorer/ManifestGenerator 2.0", forHTTPHeaderField: "User-Agent")

        #if canImport(FoundationNetworking)
        // URLSession.bytes(for:) does not exist in swift-corelibs-foundation.
        let (fullData, response) = try await session.data(for: request)
        let asyncBytes = AsyncStream<UInt8> { c in for b in fullData { c.yield(b) }; c.finish() }
        #else
        let (asyncBytes, response) = try await session.bytes(for: request)
        #endif

        guard let http = response as? HTTPURLResponse else {
            throw TEIHeaderFetcherError.unexpectedResponseType
        }
        guard (200..<300).contains(http.statusCode) else {
            throw TEIHeaderFetcherError.badHTTPStatus(http.statusCode)
        }

        let terminator = Data("</teiHeader>".utf8)
        var buffer = Data()
        var chunk = [UInt8]()
        chunk.reserveCapacity(chunkSize)

        for try await byte in asyncBytes {
            chunk.append(byte)

            if chunk.count >= chunkSize {
                buffer.append(contentsOf: chunk)
                chunk.removeAll(keepingCapacity: true)

                if buffer.range(of: terminator) != nil {
                    break
                }
                if buffer.count > maxBytesToRead {
                    break
                }
            }
        }

        // Flush any remaining bytes from the last partial chunk.
        if !chunk.isEmpty {
            buffer.append(contentsOf: chunk)
        }

        guard buffer.range(of: terminator) != nil else {
            throw TEIHeaderFetcherError.headerNotFound
        }

        // Truncate at the end of </teiHeader> to discard any partial body bytes.
        if let range = buffer.range(of: terminator) {
            buffer = Data(buffer[..<range.upperBound])
        }

        // Append </TEI> to close the root element, making the fragment valid XML
        // for Foundation's XMLParser. The <text> element was never opened in this chunk.
        buffer.append(contentsOf: Data("</TEI>".utf8))

        return buffer
    }
}
