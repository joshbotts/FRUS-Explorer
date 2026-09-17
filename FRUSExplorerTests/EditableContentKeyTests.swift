// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation

// MARK: - EditableContentKeyTests

/// Pins `Docs/EditableContent.md` against the source it claims to mirror.
///
/// That file is the owner's editing surface for every piece of user-facing prose in the app: each
/// block is wrapped in an HTML comment naming the file and the localization key it came from, and
/// revisions are mapped back to code **by that key**. So a block naming a key the source no longer
/// has is not a documentation nit — it is an edit that silently does nothing. The prose is revised,
/// handed back, and there is nothing to write it to.
///
/// A sweep on 2026-08-19 found **31 of 443 blocks** in that state. Three were already recorded in
/// the file's own preamble; the other 28 had accumulated unnoticed, because nothing checked. The
/// causes were ordinary and would recur: a string gained a format placeholder (`related.why.cohort`
/// became `related.why.cohort %@ %lld`), or a rewrite bumped it to `.v2` (`archival.info.weights.*`
/// after the third Count-by weight landed), or a feature was retired and took its string with it
/// (`settings.erase.warning.trail`, removed with the research-trail schema in R-2b).
///
/// ## What this test does NOT check
///
/// **The body text.** A block's prose deliberately differs from the shipped string: where the code
/// interpolates (`\(inspection.indexedVolumeCount)`), the document writes a note to the editor
/// (*"Interpolated with the indexed-volume count."*) and a `%lld`. Comparing bodies for equality
/// would fail on every interpolated string in the file and teach the reader to ignore it.
///
/// **The `lines:` field.** The file's own preamble calls it advisory and says it rots — "if a
/// `lines:` range and a `key:` disagree, the key wins". Pinning it would fail on almost every
/// commit that touches a view.
///
/// So this checks exactly the thing that is load-bearing and cheap to verify: the key exists in the
/// file the block points at.
///
/// ## And, for the Search Tips family, the reverse
///
/// A key with NO block is the opposite failure: a shipped string the owner cannot find to edit.
/// Deleting §7.13's `search.tips.link` block passed this suite (#1299 mutation M36), because the
/// forward check only walks the blocks that exist. The reverse check is scoped to the families
/// #1299 documented in full — `search.tips.*`, `search.error.*` and `menu.find.searchTips` — rather
/// than to every key in the app, which EditableContent has never claimed to cover.
///
/// Version history:
///   1.0 — #990: initial implementation (the forward check)
///   1.1 — #1299 follow-up: the reverse check for the Search Tips and search-error keys
@Suite("EditableContent blocks address a live localization key")
struct EditableContentKeyTests {

    /// The repository root, derived from this file's own path.
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // FRUSExplorerTests
            .deletingLastPathComponent()   // repo root
    }

    /// One `<!-- SOURCE: … -->` annotation.
    private struct Block {
        let path: String
        let key: String
        let line: Int
    }

    /// Parses every SOURCE annotation. The trailing fields are free-form — a block may carry
    /// `| shared: iOS+macOS (…)` after the key, or a view name before `key:` — so fields are split
    /// on `|` and matched by prefix rather than by position.
    private static func blocks(in markdown: String) -> [Block] {
        var out: [Block] = []
        for (index, line) in markdown.components(separatedBy: "\n").enumerated() {
            guard let range = line.range(of: "<!-- SOURCE:"),
                  let close = line.range(of: "-->", range: range.upperBound..<line.endIndex)
            else { continue }
            let inner = String(line[range.upperBound..<close.lowerBound])
            let fields = inner.components(separatedBy: "|").map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard let path = fields.first, path.hasSuffix(".swift") else { continue }
            guard let keyField = fields.first(where: { $0.hasPrefix("key:") }) else { continue }
            let key = String(keyField.dropFirst("key:".count)).trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            out.append(Block(path: path, key: key, line: index + 1))
        }
        return out
    }

    @Test("Every block's key exists in the source file it names")
    func everyBlockKeyIsLive() throws {
        let docURL = Self.repoRoot.appendingPathComponent("Docs/EditableContent.md")
        let markdown = try String(contentsOf: docURL, encoding: .utf8)
        let parsed = Self.blocks(in: markdown)

        // A parser that silently matched nothing would make this test vacuously green — the exact
        // failure mode the repo has been bitten by before.
        #expect(parsed.count > 300, """
            parsed only \(parsed.count) SOURCE annotations; the annotation format has changed and \
            this test is no longer reading the file
            """)

        var sources: [String: String] = [:]
        var dead: [String] = []

        for block in parsed {
            // A block marked RETIRED is a known, deliberate exception: the string is gone and the
            // wording is kept on purpose. The banner is what makes it deliberate rather than rot.
            let bannerWindow = markdown.components(separatedBy: "\n")
            let start = max(0, block.line - 6)
            let preceding = bannerWindow[start..<max(start, block.line - 1)].joined(separator: "\n")
            if preceding.contains("RETIRED — editing this block has no effect") { continue }

            let source: String
            if let cached = sources[block.path] {
                source = cached
            } else {
                let url = Self.repoRoot.appendingPathComponent(block.path)
                guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                    dead.append("\(block.path):\(block.line) — file not found (key \(block.key))")
                    continue
                }
                sources[block.path] = text
                source = text
            }
            if !source.contains("\"\(block.key)\"") {
                dead.append("EditableContent.md:\(block.line) — key \"\(block.key)\" is absent from "
                            + block.path)
            }
        }

        #expect(dead.isEmpty, """
            \(dead.count) EditableContent block(s) name a localization key the source does not have. \
            Editing such a block has no effect, because revisions are mapped back by key.

            Fix by repointing the block's `key:` at the live string, or — when the string is gone \
            for good — adding the RETIRED banner above it so the exception is deliberate and \
            legible. Do not delete the annotation.

            \(dead.joined(separator: "\n"))
            """)
    }

    /// The literal localization keys under `FRUSExplorer/` that begin with one of `prefixes`, each
    /// with the files that declare it.
    private static func sourceKeys(withPrefixes prefixes: [String]) throws -> [String: Set<String>] {
        let appRoot = repoRoot.appendingPathComponent("FRUSExplorer")
        let enumerator = try #require(FileManager.default.enumerator(at: appRoot, includingPropertiesForKeys: nil))
        let pattern = try NSRegularExpression(pattern: #"localized:\s*"([^"\\]+)""#)
        var keys: [String: Set<String>] = [:]
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let text = try String(contentsOf: url, encoding: .utf8)
            let whole = NSRange(text.startIndex..., in: text)
            for match in pattern.matches(in: text, range: whole) {
                guard let range = Range(match.range(at: 1), in: text) else { continue }
                let key = String(text[range])
                guard prefixes.contains(where: { key.hasPrefix($0) }) else { continue }
                keys[key, default: []].insert(url.lastPathComponent)
            }
        }
        return keys
    }

    @Test("Every Search Tips, Find-menu Search Tips and search-error key in the source has a block")
    func everySearchTipsKeyHasABlock() throws {
        let docURL = Self.repoRoot.appendingPathComponent("Docs/EditableContent.md")
        let blockKeys = Set(Self.blocks(in: try String(contentsOf: docURL, encoding: .utf8)).map(\.key))

        let keys = try Self.sourceKeys(withPrefixes: ["search.tips.", "search.error.", "menu.find.searchTips"])
        // The walk is real: #1299 declared 26 row strings, 4 notes, the refusal, 8 pieces of chrome and the Find item.
        #expect(keys.count >= 40, "found only \(keys.count) keys; the source walk is not reading the app")
        #expect(keys["search.tips.near.detail"] != nil, "the walk missed a key it must find")

        let missing = keys.keys.filter { !blockKeys.contains($0) }.sorted()
        #expect(missing.isEmpty, """
            \(missing.count) shipped key(s) have no EditableContent block, so the owner has nowhere to edit them:
            \(missing.map { "\($0) (\(keys[$0, default: []].sorted().joined(separator: ", ")))" }.joined(separator: "\n"))
            """)
    }
}
