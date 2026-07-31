// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import Testing
#if canImport(UIKit)
import UIKit
#endif

// MARK: - SymbolNameAuditTests

/// Every SF Symbol the app names by literal must exist.
///
/// ## Why this is a whole test suite
/// A `systemImage:` naming a symbol that is not in the catalog is invisible everywhere it could be
/// caught: it compiles, it raises no warning, it throws nothing at runtime, and it reads perfectly
/// in review because the name follows the family's own conventions. It renders as **nothing** — an
/// empty space where an icon should be — and only a human looking at that exact screen will notice.
///
/// The app shipped one: `WordCloudView` used `cloud.slash`, which does not exist. `icloud.slash`
/// does, and the whole `cloud.*` family is weather, so the name was two plausible steps from a real
/// one. It survived because the empty state it decorates only appears when the search index cannot
/// be opened, which is rare enough that nobody had seen it.
///
/// ## Scope, and why the extraction is trustworthy here
/// Literal arguments to `systemImage:` and `systemName:` only. Symbols built from variables,
/// interpolation or an enum's computed property are out of reach of a text scan and are not
/// claimed to be covered — ``ResultReadingTests`` checks `ResultReading`'s the runtime way, which
/// is the pattern to follow for any future symbol-bearing type.
///
/// The extraction takes literals appearing *after* the marker on the same line, which keeps
/// localization keys out: `Label(String(localized: "search.mode.facets", …), systemImage: "…")`
/// has a key that matches the symbol-name shape exactly, and a naive whole-line scan would flag it.
/// Measured at the time of writing: 183 distinct literals extracted, **zero** false positives.
///
/// Version history:
///   1.0 — Q wave: initial implementation
@Suite("SF Symbol name audit")
struct SymbolNameAuditTests {

    /// A literal symbol name and where it was written.
    private struct Named {
        let symbol: String
        let location: String
    }

    /// Whether a literal has the shape of a symbol name: lowercase, dot-separated, alphanumeric.
    /// Anything else is not a candidate, which is what keeps prose and identifiers out.
    ///
    /// Hand-written rather than a stored `Regex`, which is not `Sendable` and cannot be a static.
    private static func hasSymbolShape(_ value: String) -> Bool {
        guard let first = value.first, first.isLowercase else { return false }
        for part in value.split(separator: ".", omittingEmptySubsequences: false) {
            guard !part.isEmpty,
                  part.allSatisfy({ $0.isLowercase && $0.isASCII || $0.isNumber && $0.isASCII })
            else { return false }
        }
        return true
    }

    private static func appSources() throws -> [URL] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "FRUSExplorer")
        let walker = FileManager.default.enumerator(at: root,
                                                   includingPropertiesForKeys: nil)
        var out: [URL] = []
        while let url = walker?.nextObject() as? URL {
            if url.pathExtension == "swift" { out.append(url) }
        }
        return out
    }

    /// Every literal passed to `systemImage:` / `systemName:` across the app's sources.
    private static func literals() throws -> [Named] {
        var found: [Named] = []
        for url in try appSources() {
            let text = try String(contentsOf: url, encoding: .utf8)
            for (offset, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let row = String(line)
                var searchFrom = row.startIndex
                while let marker = row.range(of: "systemImage:", range: searchFrom..<row.endIndex)
                    ?? row.range(of: "systemName:", range: searchFrom..<row.endIndex) {
                    // Everything after the marker on this line — which captures both sides of a
                    // ternary (`systemName: on ? "a.fill" : "a"`) and excludes any localization
                    // key that preceded it.
                    let rest = String(row[marker.upperBound...])
                    for candidate in Self.quoted(in: rest) where Self.hasSymbolShape(candidate) {
                        found.append(Named(symbol: candidate,
                                           location: "\(url.lastPathComponent):\(offset + 1)"))
                    }
                    searchFrom = marker.upperBound
                }
            }
        }
        return found
    }

    /// The double-quoted runs in a fragment.
    private static func quoted(in fragment: String) -> [String] {
        var out: [String] = []
        var current: String?
        for character in fragment {
            if character == "\"" {
                if let value = current { out.append(value); current = nil } else { current = "" }
            } else if current != nil {
                current?.append(character)
            }
        }
        return out
    }

    #if canImport(UIKit)
    @Test("Every symbol the app names by literal exists")
    func everyLiteralSymbolResolves() throws {
        let named = try Self.literals()
        // Anti-vacuity floor: if the walk or the regex breaks, this suite must fail loudly rather
        // than pass over an empty list. 183 were found when this was written.
        #expect(named.count > 120, "only \(named.count) symbol literals found — did the scan break?")

        var unresolved: [String] = []
        for entry in named where UIImage(systemName: entry.symbol) == nil {
            unresolved.append("\(entry.symbol) at \(entry.location)")
        }
        if !unresolved.isEmpty {
            let list = unresolved.sorted().joined(separator: "\n")
            Issue.record("these names are not in the SF Symbols catalog and render as blanks:\n\(list)")
        }
    }

    /// Proves the check above can fail — otherwise a broken `UIImage(systemName:)` would make the
    /// whole suite a no-op that reads as coverage.
    @Test("The resolution check can fail")
    func checkIsNotVacuous() {
        #expect(UIImage(systemName: "cloud.slash") == nil, "the bug this suite exists for")
        #expect(UIImage(systemName: "icloud.slash") != nil, "…and the name it was two steps from")
    }

    /// The extraction must not mistake a localization key for a symbol. The keys in this app share
    /// the exact shape of a symbol name, so this is the failure mode that would make the audit
    /// noisy enough to be disabled.
    @Test("Localization keys are not mistaken for symbol names")
    func keysAreNotExtracted() throws {
        let symbols = Set(try Self.literals().map(\.symbol))
        #expect(!symbols.contains("search.mode.facets"))
        #expect(!symbols.contains("search.corpus.save"))
        #expect(!symbols.contains("wordcloud.unavailable.title"))
    }
    #endif
}
