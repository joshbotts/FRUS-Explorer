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
/// ## The `lines:` field, since #1424
///
/// The key is still the address, but the owner navigates by the range, and a stale one sends them
/// to another string's line. Until #1424 this suite deliberately left the field unpinned, on the
/// argument that it "would fail on almost every commit that touches a view". It rotted exactly as
/// predicted and nothing said so: **19 ranged blocks** named lines that no longer held their key on
/// `v2` at `1e11d7ae` (16 in `SettingsView.swift`, all 18 lines low; two in
/// `DocumentDisplayTitle.swift`; and the RETIRED `search.kwic.show.help.v2`, whose range pointed at
/// whatever now sits there). The cost the old argument feared is real but bounded: a change that
/// moves lines re-points the ranged blocks citing that file, and the failure message names each
/// key's actual line, so the edit is mechanical. No re-point script is committed; the build-48 lanes
/// that kept their ranges right used session scripts outside the repository.
///
/// **Gating the ranges is an owner decision this suite has taken provisionally.** #1424's fix asked
/// for this test and left open whether ranges should instead stay advisory, or be checked with a
/// tolerance or an exemption list. It checks exact containment with no tolerance; if the owner
/// prefers advisory ranges, ``everyRangedBlockHoldsItsKey()`` is the one test to delete, together
/// with the note on the `lines:` field in `EditableContent.md`.
///
/// So ``everyRangedBlockHoldsItsKey()`` now fails when a block's key is not inside its range. The
/// rule, and each branch of it, is ``rangeDrift(in:source:)`` driven by a fixture of its own:
/// - a range must contain the key's **quoted literal** — `"settings.sync.footer"` — so a key that is
///   a prefix of another (`…footer` and `…footer.mac`) cannot satisfy it;
/// - a two-part range (`lines: 3769–3769, 4261–4261`, a key declared at two call sites) must hold
///   the key in **each** part, because each part is a place the owner will be sent;
/// - every key of a `keys:` list is checked, and a wildcard (`onboarding.*`) is not a key;
/// - a block with no `lines:` field is not checked (104 of them when this landed — whether ranges
///   become mandatory is the owner's call, not this test's);
/// - a RETIRED block may carry **no** range: its string is gone, so any line it names now belongs
///   to something else.
///
/// ## What this test does NOT check
///
/// **The body text.** A block's prose deliberately differs from the shipped string: where the code
/// interpolates (`\(inspection.indexedVolumeCount)`), the document writes a note to the editor
/// (*"Interpolated with the indexed-volume count."*) and a `%lld`. Comparing bodies for equality
/// would fail on every interpolated string in the file and teach the reader to ignore it.
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
///   1.2 — #1424: the `lines:` range must hold its key; `keys:` lists are parsed and checked too
///   1.3 — #1424 review round 1: one fixture per conjunct of `parseRanges`'s guard, two of which
///         stand between a typo and a trap
///   1.4 — #1424 review round 2: the line-0 fixture asks `parseRanges` first, so its mutant fails
///         the test cleanly instead of trapping the host
///   1.5 — FRUSCoreKit, part 1: the Search Tips key scan reads `FRUSCoreKit/` as well as
///         `FRUSExplorer/`, through `AppSourceTree`
@Suite("EditableContent blocks address a live localization key")
struct EditableContentKeyTests {

    /// The repository root, derived from this file's own path.
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // FRUSExplorerTests
            .deletingLastPathComponent()   // repo root
    }

    /// The owner's editing surface: every markdown file directly inside `Docs/EditableContent/`
    /// (not `History/`, whose snapshots name retired keys), in name order. The single
    /// `Docs/EditableContent.md` was split by app area on 2026-09-28; a block may sit in any file,
    /// because write-back is by key.
    static func editableContentFiles() throws -> [(name: String, text: String)] {
        let folder = repoRoot.appendingPathComponent("Docs/EditableContent")
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path)
            .filter { $0.hasSuffix(".md") }
            .sorted()
        return try names.map { name in
            (name, try String(contentsOf: folder.appendingPathComponent(name), encoding: .utf8))
        }
    }

    /// The banner that makes a block's dead key deliberate rather than rot.
    private static let retiredBanner = "RETIRED — editing this block has no effect"

    /// One `<!-- SOURCE: … -->` annotation.
    struct Block {
        /// The repository-relative Swift file the block mirrors.
        let path: String
        /// The keys named by `key:` or `keys:`, with wildcards (`onboarding.*`) dropped.
        let keys: [String]
        /// The raw `lines:` value, or `nil` when the block states no range.
        let linesField: String?
        /// The annotation's 1-based line in the markdown.
        let line: Int
        /// Whether a RETIRED banner sits in the five lines above the annotation.
        let isRetired: Bool
    }

    /// Parses every SOURCE annotation. The trailing fields are free-form — a block may carry
    /// `| shared: iOS+macOS (…)` after the key, or a view name before `key:` — so fields are split
    /// on `|` and matched by prefix rather than by position. A block naming no Swift file, or only
    /// wildcard keys, is not returned: there is no literal to look for.
    static func blocks(in markdown: String) -> [Block] {
        let lines = markdown.components(separatedBy: "\n")
        var out: [Block] = []
        for (index, line) in lines.enumerated() {
            guard let range = line.range(of: "<!-- SOURCE:"),
                  let close = line.range(of: "-->", range: range.upperBound..<line.endIndex)
            else { continue }
            let inner = String(line[range.upperBound..<close.lowerBound])
            let fields = inner.components(separatedBy: "|").map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard let path = fields.first, path.hasSuffix(".swift") else { continue }
            var keys: [String] = []
            var linesField: String?
            for field in fields.dropFirst() {
                for prefix in ["key:", "keys:"] where field.hasPrefix(prefix) {
                    keys += field.dropFirst(prefix.count)
                        .components(separatedBy: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty && !$0.contains("*") }
                }
                if field.hasPrefix("lines:") {
                    linesField = String(field.dropFirst("lines:".count))
                        .trimmingCharacters(in: .whitespaces)
                }
            }
            guard !keys.isEmpty else { continue }
            // The banner sits in the five lines above the annotation — the window #990 set. A
            // banner of more than four lines (plus its blank line) pushes its first line, which
            // carries the marker, out of the window: the block stops being RETIRED and
            // `everyBlockKeyIsLive` fails on its dead key.
            let bannerStart = max(0, index - 5)
            let isRetired = lines[bannerStart..<index].contains { $0.contains(retiredBanner) }
            out.append(Block(path: path, keys: keys, linesField: linesField,
                             line: index + 1, isRetired: isRetired))
        }
        return out
    }

    /// Parses a `lines:` value — `270–280`, or `3769–3769, 4261–4261` for a key at two call sites.
    /// Returns `nil` for anything else, so a malformed field is reported rather than skipped.
    ///
    /// Two of the guard's conjuncts prevent a trap, not just a wrong answer: without `low >= 1` a
    /// `0–1` reaches `text[$0 - 1]` at index −1, and without `low <= high` a `5–2` fails
    /// `ClosedRange`'s precondition — either would take the test host down instead of reporting the
    /// block. Each conjunct has a fixture of its own; the `low >= 1` one calls this function before
    /// ``rangeDrift(in:source:)``, so removing that conjunct fails the test instead of crashing it.
    static func parseRanges(_ field: String) -> [ClosedRange<Int>]? {
        var parts: [ClosedRange<Int>] = []
        for part in field.components(separatedBy: ",") {
            let bounds = part.components(separatedBy: CharacterSet(charactersIn: "–-"))
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard bounds.count == 2, let low = Int(bounds[0]), let high = Int(bounds[1]),
                  low >= 1, low <= high else { return nil }
            parts.append(low...high)
        }
        return parts.isEmpty ? nil : parts
    }

    /// What a range check found.
    struct RangeDrift {
        /// Ranged, non-RETIRED blocks whose ranges were checked against their keys.
        var checked = 0
        /// Of those, the blocks whose range has more than one part.
        var multiPart = 0
        /// Blocks with no `lines:` field, which are not checked.
        var unranged = 0
        /// One line per defect, naming the block, the key, the stated range and where the key is.
        var failures: [String] = []

        /// Adds another file's counts and defects to these.
        mutating func absorb(_ other: RangeDrift) {
            checked += other.checked
            multiPart += other.multiPart
            unranged += other.unranged
            failures += other.failures
        }
    }

    /// Checks every ranged block's keys against its `lines:` range.
    ///
    /// - Parameters:
    ///   - markdown: The text of one `Docs/EditableContent/` file (or a fixture).
    ///   - file: The file's name, which starts each defect line.
    ///   - source: The lines of a repository-relative Swift file, or `nil` when it does not exist.
    /// - Returns: The counts and the defects.
    static func rangeDrift(in markdown: String, file: String = "EditableContent.md",
                           source: (String) -> [String]?) -> RangeDrift {
        var result = RangeDrift()
        var cache: [String: [String]?] = [:]
        for block in blocks(in: markdown) {
            guard let field = block.linesField else {
                if !block.isRetired { result.unranged += 1 }
                continue
            }
            if block.isRetired {
                result.failures.append("\(file):\(block.line) — the RETIRED block for "
                    + "\(block.keys.joined(separator: ", ")) still names lines \(field) of \(block.path); "
                    + "its string is gone, so those lines hold something else. Drop the `lines:` field.")
                continue
            }
            guard let ranges = parseRanges(field) else {
                result.failures.append("\(file):\(block.line) — `lines: \(field)` is not "
                    + "a range such as 270–280 or 3769–3769, 4261–4261")
                continue
            }
            if cache[block.path] == nil { cache[block.path] = .some(source(block.path)) }
            guard let text = cache[block.path] ?? nil else {
                result.failures.append("\(file):\(block.line) — \(block.path) not found")
                continue
            }
            result.checked += 1
            if ranges.count > 1 { result.multiPart += 1 }
            for key in block.keys {
                let literal = "\"\(key)\""
                let holds = { (range: ClosedRange<Int>) in
                    range.contains { $0 <= text.count && text[$0 - 1].contains(literal) }
                }
                let missed = ranges.filter { !holds($0) }
                guard !missed.isEmpty else { continue }
                let actual = text.indices.filter { text[$0].contains(literal) }.map { String($0 + 1) }
                let whereItIs = actual.isEmpty
                    ? "the key is absent from the file"
                    : "the key is on line \(actual.joined(separator: ", "))"
                let stated = missed.map { "\($0.lowerBound)–\($0.upperBound)" }.joined(separator: ", ")
                result.failures.append("\(file):\(block.line) — \(key): stated \(stated) "
                    + "in \(block.path), but \(whereItIs)")
            }
        }
        return result
    }

    @Test("Every block's key exists in the source file it names")
    func everyBlockKeyIsLive() throws {
        let parsed = try Self.editableContentFiles().flatMap { doc in
            Self.blocks(in: doc.text).map { (file: doc.name, block: $0) }
        }

        // A parser that silently matched nothing would make this test vacuously green — the exact
        // failure mode the repo has been bitten by before.
        #expect(parsed.count > 300, """
            parsed only \(parsed.count) SOURCE annotations; the annotation format has changed and \
            this test is no longer reading the file
            """)

        var sources: [String: String] = [:]
        var dead: [String] = []

        for (file, block) in parsed {
            // A block marked RETIRED is a known, deliberate exception: the string is gone and the
            // wording is kept on purpose. The banner is what makes it deliberate rather than rot.
            if block.isRetired { continue }

            let source: String
            if let cached = sources[block.path] {
                source = cached
            } else {
                let url = Self.repoRoot.appendingPathComponent(block.path)
                guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                    dead.append("\(block.path):\(block.line) — file not found "
                                + "(keys \(block.keys.joined(separator: ", ")))")
                    continue
                }
                sources[block.path] = text
                source = text
            }
            for key in block.keys where !source.contains("\"\(key)\"") {
                dead.append("\(file):\(block.line) — key \"\(key)\" is absent from "
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

    @Test("Every ranged block's `lines:` range holds its key (#1424)")
    func everyRangedBlockHoldsItsKey() throws {
        var drift = RangeDrift()
        for doc in try Self.editableContentFiles() {
            let part = Self.rangeDrift(in: doc.text, file: doc.name) { path in
                let url = Self.repoRoot.appendingPathComponent(path)
                return (try? String(contentsOf: url, encoding: .utf8))?.components(separatedBy: "\n")
            }
            drift.absorb(part)
        }

        // The walk is real: 1,007 ranged blocks were checked when this landed, one of them in two
        // parts (`menu.find.searchTips`). A parser that stopped reading `lines:` would check none.
        #expect(drift.checked > 900, "checked only \(drift.checked) ranged blocks; the parser is not reading the file")
        #expect(drift.multiPart >= 1, "no two-part range was checked; the `, ` form is not being parsed")

        #expect(drift.failures.isEmpty, """
            \(drift.failures.count) EditableContent block(s) state a `lines:` range that does not hold \
            their key, so the owner is sent to another string's line. Re-point each range to start \
            on its key's line (it keeps its length), or drop the field from a RETIRED block:

            \(drift.failures.joined(separator: "\n"))
            """)
    }

    // MARK: - The range rule, one fixture per branch

    /// Runs ``rangeDrift(in:source:)`` over a fixture document and fixture files.
    private static func drift(_ markdown: String, files: [String: [String]]) -> RangeDrift {
        rangeDrift(in: markdown) { files[$0] }
    }

    /// A three-line Swift file with the key on line 2.
    private static let oneKeyFile = ["// header", #"Text(String(localized: "a.key", defaultValue: "A"))"#, "// end"]

    @Test("A range holding its key's line passes")
    func rangeHoldingKeyPasses() {
        let result = Self.drift("<!-- SOURCE: F.swift | lines: 2–3 | key: a.key -->",
                                files: ["F.swift": Self.oneKeyFile])
        #expect(result.checked == 1)
        #expect(result.failures.isEmpty)
    }

    @Test("A range that misses its key fails and names the key's real line")
    func rangeMissingKeyFails() throws {
        let result = Self.drift("<!-- SOURCE: F.swift | lines: 1–1 | key: a.key -->",
                                files: ["F.swift": Self.oneKeyFile])
        let failure = try #require(result.failures.first)
        #expect(result.failures.count == 1)
        #expect(failure.contains("a.key: stated 1–1"))
        #expect(failure.contains("the key is on line 2"))
    }

    @Test("A key that is only a prefix of the literal on the line does not satisfy the range")
    func prefixKeyDoesNotMatch() throws {
        let file = ["", #"Text(String(localized: "a.key.mac", defaultValue: "A"))"#]
        let result = Self.drift("<!-- SOURCE: F.swift | lines: 2–2 | key: a.key -->", files: ["F.swift": file])
        let failure = try #require(result.failures.first)
        #expect(failure.contains("the key is absent from the file"))
    }

    @Test("A two-part range holding the key in both parts passes")
    func twoPartRangeBothPartsPass() {
        let file = ["", #"localized: "a.key""#, "", #"localized: "a.key""#]
        let result = Self.drift("<!-- SOURCE: F.swift | lines: 2–2, 4–4 | key: a.key -->", files: ["F.swift": file])
        #expect(result.checked == 1)
        #expect(result.multiPart == 1)
        #expect(result.failures.isEmpty)
    }

    @Test("A two-part range whose second part misses the key fails, naming only that part")
    func twoPartRangeOnePartFails() throws {
        let file = ["", #"localized: "a.key""#, "", "// moved"]
        let result = Self.drift("<!-- SOURCE: F.swift | lines: 2–2, 4–4 | key: a.key -->", files: ["F.swift": file])
        let failure = try #require(result.failures.first)
        #expect(result.failures.count == 1)
        #expect(failure.contains("stated 4–4"))
        #expect(!failure.contains("2–2"))
    }

    @Test("A format key with a placeholder is matched as the literal it is")
    func formatKeyMatches() {
        let file = [#"String(localized: "a.key %@ %lld","#, #"defaultValue: "…")"#]
        let result = Self.drift("<!-- SOURCE: F.swift | lines: 1–2 | key: a.key %@ %lld -->", files: ["F.swift": file])
        #expect(result.checked == 1)
        #expect(result.failures.isEmpty)
    }

    @Test("Every key of a `keys:` list is checked, and only the one outside the range is named")
    func keysListChecksEachKey() throws {
        let file = [#"localized: "a.one""#, #"localized: "a.two""#, "", #"localized: "a.three""#]
        let result = Self.drift("<!-- SOURCE: F.swift | lines: 1–2 | keys: a.one, a.two, a.three -->",
                                files: ["F.swift": file])
        let failure = try #require(result.failures.first)
        #expect(result.failures.count == 1)
        #expect(failure.contains("a.three"))
        #expect(failure.contains("the key is on line 4"))
    }

    @Test("A wildcard-only block names no key and is not checked")
    func wildcardOnlyBlockIsSkipped() {
        let result = Self.drift("<!-- SOURCE: F.swift | lines: 1–1 | keys: onboarding.* -->",
                                files: ["F.swift": Self.oneKeyFile])
        #expect(result.checked == 0)
        #expect(result.failures.isEmpty)
    }

    @Test("A block with no `lines:` field is counted and not checked")
    func unrangedBlockIsSkipped() {
        let result = Self.drift("<!-- SOURCE: F.swift | key: a.key -->", files: ["F.swift": Self.oneKeyFile])
        #expect(result.checked == 0)
        #expect(result.unranged == 1)
        #expect(result.failures.isEmpty)
    }

    @Test("A RETIRED block that still names lines fails")
    func retiredBlockWithRangeFails() throws {
        let markdown = """
            > ⚠️ **RETIRED — editing this block has no effect.** Gone.

            <!-- SOURCE: F.swift | lines: 2–3 | key: gone.key -->
            """
        let result = Self.drift(markdown, files: ["F.swift": Self.oneKeyFile])
        let failure = try #require(result.failures.first)
        #expect(failure.contains("RETIRED"))
        #expect(result.checked == 0)
    }

    @Test("A RETIRED block with no range passes and is not counted as unranged")
    func retiredBlockWithoutRangePasses() {
        let markdown = """
            > ⚠️ **RETIRED — editing this block has no effect.** Gone.

            <!-- SOURCE: F.swift | key: gone.key -->
            """
        let result = Self.drift(markdown, files: ["F.swift": Self.oneKeyFile])
        #expect(result.failures.isEmpty)
        #expect(result.unranged == 0)
    }

    @Test("A malformed `lines:` field fails rather than being skipped")
    func malformedRangeFails() throws {
        let result = Self.drift("<!-- SOURCE: F.swift | lines: 12 | key: a.key -->", files: ["F.swift": Self.oneKeyFile])
        let failure = try #require(result.failures.first)
        #expect(failure.contains("is not a range"))
    }

    // One fixture per conjunct of `parseRanges`'s guard, each alone. `malformedRangeFails` above
    // is the `bounds.count == 2` one; these are the other four.
    //
    // The two trap-guarding conjuncts fail differently when removed. Without `low >= 1`,
    // `parseRanges` indexes nothing and returns `[0...1]`, so `zeroLowerBoundFails` asks it
    // directly FIRST and stops there — a clean failure, rather than `rangeDrift` reading index −1
    // and taking the test host down in a run that reports "0 tests" and never finishes. Without
    // `low <= high` the trap is `ClosedRange`'s precondition INSIDE `parseRanges`, which no test
    // can step round: `reversedBoundsFail` catches that mutant only by crashing the host, and the
    // run then ends TEST EXECUTE FAILED rather than passing.

    @Test("A range starting at line 0 is reported as malformed, not read at index −1")
    func zeroLowerBoundFails() throws {
        try #require(Self.parseRanges("0–1") == nil)
        let result = Self.drift("<!-- SOURCE: F.swift | lines: 0–1 | key: a.key -->", files: ["F.swift": Self.oneKeyFile])
        let failure = try #require(result.failures.first)
        #expect(result.failures.count == 1)
        #expect(failure.contains("`lines: 0–1` is not a range"))
        #expect(result.checked == 0)
    }

    @Test("A range whose bounds are reversed is reported as malformed, not built")
    func reversedBoundsFail() throws {
        let result = Self.drift("<!-- SOURCE: F.swift | lines: 5–2 | key: a.key -->", files: ["F.swift": Self.oneKeyFile])
        let failure = try #require(result.failures.first)
        #expect(result.failures.count == 1)
        #expect(failure.contains("`lines: 5–2` is not a range"))
        #expect(result.checked == 0)
    }

    @Test("A range whose lower bound is not a number is reported as malformed")
    func nonNumericLowerBoundFails() throws {
        let result = Self.drift("<!-- SOURCE: F.swift | lines: a–3 | key: a.key -->", files: ["F.swift": Self.oneKeyFile])
        let failure = try #require(result.failures.first)
        #expect(result.failures.count == 1)
        #expect(failure.contains("`lines: a–3` is not a range"))
        #expect(result.checked == 0)
    }

    @Test("A range whose upper bound is not a number is reported as malformed")
    func nonNumericUpperBoundFails() throws {
        let result = Self.drift("<!-- SOURCE: F.swift | lines: 3–b | key: a.key -->", files: ["F.swift": Self.oneKeyFile])
        let failure = try #require(result.failures.first)
        #expect(result.failures.count == 1)
        #expect(failure.contains("`lines: 3–b` is not a range"))
        #expect(result.checked == 0)
    }

    @Test("A block naming a file that does not exist fails")
    func missingFileFails() throws {
        let result = Self.drift("<!-- SOURCE: Gone.swift | lines: 1–2 | key: a.key -->", files: [:])
        let failure = try #require(result.failures.first)
        #expect(failure.contains("Gone.swift not found"))
    }

    @Test("A range running past the end of the file does not trap and still finds the key")
    func rangePastEndOfFile() {
        let result = Self.drift("<!-- SOURCE: F.swift | lines: 2–40 | key: a.key -->", files: ["F.swift": Self.oneKeyFile])
        #expect(result.checked == 1)
        #expect(result.failures.isEmpty)
    }

    /// The literal localization keys under `FRUSExplorer/` and `FRUSCoreKit/` that begin with one of
    /// `prefixes`, each with the files that declare it.
    private static func sourceKeys(withPrefixes prefixes: [String]) throws -> [String: Set<String>] {
        let pattern = try NSRegularExpression(pattern: #"localized:\s*"([^"\\]+)""#)
        var keys: [String: Set<String>] = [:]
        for url in AppSourceTree.swiftFiles(in: repoRoot) {
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
        let blockKeys = Set(try Self.editableContentFiles().flatMap { Self.blocks(in: $0.text) }.flatMap(\.keys))

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
