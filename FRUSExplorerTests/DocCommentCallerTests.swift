// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing

/// A doc comment that names its caller must be telling the truth.
///
/// ## Why this exists
/// `CrossReferenceStore.volumeLevelConnections` carried *"Used by `VolumeConnectionGraphView` in
/// the Corpus Browser"* long after that view was redesigned onto a different query. Its only real
/// caller was the analytics heat matrix. The cost was not cosmetic: an assessment of whether those
/// two surfaces should integrate started from that comment and had to discover, by reading the
/// code, that the two reach the same counts by **two different queries**.
///
/// This is the same failure this program keeps finding in the *review* — a claim that outlived its
/// own refutation because nothing re-reads a comment when the code beneath it changes. A
/// `Used by` claim is the one kind of comment a test can check, so it should be checked.
///
/// ## What it does not claim to do
/// It verifies **mention, not invocation** — that the named type's file references the documented
/// symbol at all. A test that tried to prove a real call would need a compiler. Mention is enough
/// to catch the failure that actually happens: the caller moves away entirely and the comment stays
/// behind.
///
/// Version history:
///   1.0 — created with the `volumeLevelConnections` correction
@Suite("Doc comment callers")
struct DocCommentCallerTests {

    private static var appRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "FRUSExplorer")
    }

    /// Every `.swift` file in the app target, by path.
    private static func swiftFiles() -> [URL] {
        guard let walker = FileManager.default.enumerator(at: appRoot,
                                                          includingPropertiesForKeys: nil) else {
            return []
        }
        return walker.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    /// One `Used by` claim: the type it names, the symbol it documents, and where it sits.
    private struct Claim {
        let namedType: String
        let documentedSymbol: String
        let file: String
        let line: Int
    }

    /// Parses `/// Used by \`Type\`` claims and pairs each with the declaration it precedes.
    private static func claims(in url: URL) -> [Claim] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let lines = text.components(separatedBy: .newlines)
        var found: [Claim] = []

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("/// Used by `") else { continue }
            guard let open = trimmed.range(of: "`"),
                  let close = trimmed.range(of: "`", range: open.upperBound..<trimmed.endIndex)
            else { continue }
            // A bare type name only. `Type.method()` forms and prose lists are skipped rather than
            // half-parsed — a wrong parse here would fail open, which is the failure this suite
            // exists to prevent.
            let named = String(trimmed[open.upperBound..<close.lowerBound])
            guard named.allSatisfy({ $0.isLetter || $0.isNumber }) else { continue }

            // The first declaration after the comment block.
            var cursor = index + 1
            var symbol: String?
            while cursor < lines.count, cursor < index + 25 {
                let candidate = lines[cursor].trimmingCharacters(in: .whitespaces)
                if candidate.hasPrefix("///") || candidate.isEmpty { cursor += 1; continue }
                for keyword in ["func ", "var ", "let ", "struct ", "enum ", "class "] {
                    if let range = candidate.range(of: keyword) {
                        let tail = candidate[range.upperBound...]
                        let name = tail.prefix { $0.isLetter || $0.isNumber || $0 == "_" }
                        if !name.isEmpty { symbol = String(name) }
                        break
                    }
                }
                break
            }
            guard let symbol else { continue }
            found.append(Claim(namedType: named, documentedSymbol: symbol,
                               file: url.lastPathComponent, line: index + 1))
        }
        return found
    }

    @Test("every `Used by` doc comment names a file that mentions the documented symbol")
    func usedByClaimsAreTrue() throws {
        let files = Self.swiftFiles()
        let sources = Dictionary(uniqueKeysWithValues: files.compactMap { url -> (String, String)? in
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            return (url.deletingPathExtension().lastPathComponent, text)
        })

        var checked = 0
        for file in files {
            for claim in Self.claims(in: file) {
                // Only claims naming a type that IS a file in the app target — the rest (test
                // targets, methods, prose) are out of scope and skipped rather than guessed at.
                guard let namedSource = sources[claim.namedType] else { continue }
                checked += 1
                #expect(namedSource.contains(claim.documentedSymbol), """
                    \(claim.file):\(claim.line) says `\(claim.documentedSymbol)` is used by \
                    `\(claim.namedType)`, but \(claim.namedType).swift never mentions it. Either \
                    the caller moved away and the comment stayed behind — the \
                    `volumeLevelConnections` failure, which sent a design assessment down a false \
                    trail — or the comment names the wrong type. Correct it rather than deleting \
                    it: which surface uses a query is load-bearing information.
                    """)
            }
        }

        // Guards against the parse silently matching nothing, which would make every assertion
        // above vacuous — the way a scanning test goes green having measured zero things.
        #expect(checked >= 5, "expected several checkable `Used by` claims, found \(checked)")
    }
}
