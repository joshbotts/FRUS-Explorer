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
@testable import FRUSExplorer

// MARK: - DiscoveryTipWiringAuditTests

/// A declared tip must have a live display site, on every platform it claims.
///
/// ## The bug this exists to stop happening again
/// `ExploreCrossReferencesTip` shipped for months with **no `.popoverTip` anywhere**. It pointed at
/// a Cross-References toolbar button; the Research Rail redesign deleted that button and the
/// modifier went with it. The declaration still compiled, `import TipKit` was still required (an
/// orphaned `.invalidate` kept it alive), and the diff showed only a removed modifier. Nothing was
/// red, and the tip could never display again.
///
/// The failure is silent by construction: a `.popoverTip` registers nothing queryable, and a tip's
/// declaration has no compile-time relationship to its display site. `DiscoveryTipRegistry` restores
/// that relationship as data; this suite checks it.
///
/// ## What a source scan can and cannot prove
/// It proves the modifier is in the file. It cannot prove the file is on screen — a view can be
/// dead code and still contain a perfectly good `.popoverTip`, which is why
/// ``forbiddenAnchorsAreRefused`` exists and why every tip PR carries a visual-review checklist.
///
/// The platform assertion is also honest about its limit: it is sound for files gated at the top
/// (`DocumentView.swift` is `#if os(iOS)` in its entirety, `MacDocumentView.swift` `#if os(macOS)`),
/// and **unsound for a file with inner `#if os` fences** — `ResearchRailView` declares the same
/// tiles twice inside one file. A tip anchored in such a file must declare only the platforms whose
/// branch really carries the modifier, and no scan here can confirm that.
///
/// Version history:
///   1.0 — #597 Phase 0: initial implementation
@Suite("Discovery tip wiring")
struct DiscoveryTipWiringAuditTests {

    /// The repo root, derived from this file's location.
    private static var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    /// Reads a source file, refusing an implausibly small one — a truncated read would make every
    /// "does it contain X" assertion below fail for the wrong reason, or a rewritten stub pass.
    private static func source(_ path: String) throws -> String {
        let text = try String(contentsOf: root.appending(path: path), encoding: .utf8)
        #expect(text.count > 500, "\(path) is implausibly small — did it move or get truncated?")
        return text
    }

    /// Every `.swift` file under `FRUSExplorer/`, with its repo-relative path.
    private static func appSources() throws -> [(path: String, text: String)] {
        let appRoot = root.appending(path: "FRUSExplorer")
        guard let walker = FileManager.default.enumerator(at: appRoot,
                                                          includingPropertiesForKeys: nil) else {
            Issue.record("could not enumerate FRUSExplorer/")
            return []
        }
        var out: [(String, String)] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let path = "FRUSExplorer" + url.path.replacingOccurrences(of: appRoot.path, with: "")
            out.append((path, text))
        }
        #expect(out.count > 100, "found only \(out.count) app sources — the walk is broken")
        return out
    }

    /// Type names of everything declaring conformance to `Tip`.
    private static func declaredTipTypes() throws -> Set<String> {
        var names: Set<String> = []
        // `struct SomeTip: Tip {` — the only shape used in this app. A future `final class` or a
        // multi-protocol conformance list would need this widened, which the count check below
        // surfaces rather than silently missing.
        let pattern = try NSRegularExpression(
            pattern: #"(?m)^\s*(?:public\s+|internal\s+)?struct\s+(\w+)\s*:\s*Tip\s*\{"#)
        for (_, text) in try appSources() {
            let range = NSRange(text.startIndex..., in: text)
            for match in pattern.matches(in: text, range: range) {
                if let r = Range(match.range(at: 1), in: text) { names.insert(String(text[r])) }
            }
        }
        return names
    }

    // MARK: - A · the registry covers the declarations

    @Test("Every declared tip is registered")
    func everyDeclaredTipIsRegistered() throws {
        let declared = try Self.declaredTipTypes()
        #expect(!declared.isEmpty, "no `struct …: Tip {` found at all — has the shape changed?")
        let registered = Set(DiscoveryTipRegistry.entries.map(\.typeName))
        #expect(declared == registered,
                """
                The tip registry and the declared tips disagree.
                Declared but unregistered: \(declared.subtracting(registered).sorted())
                Registered but undeclared: \(registered.subtracting(declared).sorted())
                Adding a tip means adding a row to `DiscoveryTipRegistry.entries`.
                """)
    }

    // MARK: - B · every registered anchor really holds the modifier

    /// The assertion `ExploreCrossReferencesTip` would have failed the day the rail landed.
    @Test("Every registered anchor file contains the tip's display site")
    func everyAnchorHoldsItsModifier() throws {
        for entry in DiscoveryTipRegistry.entries {
            #expect(!entry.anchors.isEmpty, "\(entry.typeName) is registered with no anchor")
            for anchor in entry.anchors {
                let text = try Self.source(anchor.file)
                // The PAIR, not either half: `.popoverTip(` alone would be satisfied by a different
                // tip in the same file, and the bare type name by a doc comment mentioning it.
                #expect(text.contains(".popoverTip(\(entry.typeName)("),
                        """
                        \(anchor.file) does not display `\(entry.typeName)`. A tip with no live \
                        `.popoverTip` can never appear — that is exactly how \
                        ExploreCrossReferencesTip shipped dead for months.
                        """)
            }
        }
    }

    // MARK: - C · no display site names an unregistered tip

    @Test("Every .popoverTip in the tree names a registered tip")
    func everyDisplaySiteIsRegistered() throws {
        let registered = Set(DiscoveryTipRegistry.entries.map(\.typeName))
        let pattern = try NSRegularExpression(pattern: #"\.popoverTip\(\s*(\w+)\s*\("#)
        var found = 0
        for (path, text) in try Self.appSources() {
            let range = NSRange(text.startIndex..., in: text)
            for match in pattern.matches(in: text, range: range) {
                guard let r = Range(match.range(at: 1), in: text) else { continue }
                let name = String(text[r])
                found += 1
                #expect(registered.contains(name),
                        "\(path) displays `\(name)`, which is not in DiscoveryTipRegistry")
            }
        }
        // Anti-vacuity: if the regex ever stops matching, every assertion above passes silently.
        #expect(found >= DiscoveryTipRegistry.entries.count,
                """
                Found \(found) display sites for \(DiscoveryTipRegistry.entries.count) registered \
                tips — the scan is broken, not the wiring.
                """)
    }

    // MARK: - D · the id is the persistence key, and it is the type name

    /// TipKit derives a tip's identity from its type. Renaming the type therefore mints a **new**
    /// tip and re-fires it for every existing user, while the old id stays invalidated forever —
    /// which is the mechanism that killed `ExploreCrossReferencesTip`'s reusability. A rename is a
    /// user-visible change, so it must be a deliberate registry edit rather than a refactor's
    /// silent side effect.
    @Test("Registered type names are pinned")
    func typeNamesArePinned() {
        #expect(Set(DiscoveryTipRegistry.entries.map(\.typeName))
                == ["ResearchRailTip", "EdgeTapNavigationTip", "ExamineResultsTip",
                    "FacetNarrowTip", "GraphReferenceListTip", "TimelineLayoutTip"],
                """
                A registered tip's type name changed. TipKit keys its datastore on the type, so a \
                rename re-fires the tip for every existing user and burns the old id. If that is \
                intended, update this pin and say so in the PR.
                """)
        // And the retired one must not come back under its old name: that id is already recorded
        // as invalidated on every existing install, so it could never display.
        #expect(!DiscoveryTipRegistry.entries.contains { $0.typeName == "ExploreCrossReferencesTip" },
                "ExploreCrossReferencesTip's id is burned — its replacement needs a NEW type name")
    }

    // MARK: - E · per-platform coverage

    /// A tip claiming iOS whose only anchor lives in a `#if os(macOS)` file reaches no iOS user —
    /// the same class of defect as #617 hiding a collection toggle from every Mac user. Coverage is
    /// therefore asserted as `(file, platform)` pairs.
    ///
    /// Sound only for **whole-file** gates; see the suite's doc comment for the inner-fence limit.
    @Test("Each claimed platform has an anchor compiled for it")
    func platformCoverageIsReal() throws {
        for entry in DiscoveryTipRegistry.entries {
            for anchor in entry.anchors {
                let text = try Self.source(anchor.file)
                guard let gate = Self.wholeFileGate(text) else { continue }
                for platform in anchor.platforms where platform.rawValue != gate {
                    Issue.record("""
                        \(entry.typeName) claims \(platform.rawValue) through \(anchor.file), but \
                        that file is gated `#if os(\(gate))` in its entirety, so the modifier is \
                        not compiled for \(platform.rawValue).
                        """)
                }
            }
        }
    }

    /// The platform a file is gated to as a whole, or `nil` when it is not.
    ///
    /// "Whole file" means the first line of *code* — past the licence header, blank lines and
    /// imports — opens `#if os(…)` **and its matching `#endif` is the last code in the file**.
    /// That second half is not optional: `CrossReferenceGraphView.swift` opens with an
    /// `#if os(iOS)` that closes eight lines later around a private enum, and both of its tips sit
    /// outside it. Stopping at the first `#if` would report that file as iOS-only and fail a
    /// correct registration.
    ///
    /// A file with inner fences returns `nil`, deliberately: an inner fence says nothing about
    /// whether *the anchor* is inside it, and guessing would either wave through a real
    /// #617-shaped defect or reject a correct claim. See the suite's doc comment.
    private static func wholeFileGate(_ text: String) -> String? {
        var gate: String?
        var depth = 0
        var closedAtDepthZero = false
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("//") || line.hasPrefix("import") { continue }

            if gate == nil {
                // The first code line has to be the gate, or the file is not whole-file gated.
                guard line.hasPrefix("#if os(") else { return nil }
                gate = line.contains("os(iOS)") ? "iOS" : line.contains("os(macOS)") ? "macOS" : nil
                if gate == nil { return nil }
                depth = 1
                continue
            }

            // Anything after the outer `#endif` means the gate did not span the file.
            if closedAtDepthZero { return nil }

            if line.hasPrefix("#if") {
                depth += 1
            } else if line.hasPrefix("#endif") {
                depth -= 1
                if depth == 0 { closedAtDepthZero = true }
            }
        }
        return closedAtDepthZero ? gate : nil
    }

    // MARK: - F · the denylist

    /// The live traps, refused by name. Both files render in no shipping build, so a `.popoverTip`
    /// placed in either would pass every assertion above while displaying to nobody.
    @Test("No tip is anchored in a known-dead view")
    func forbiddenAnchorsAreRefused() {
        for entry in DiscoveryTipRegistry.entries {
            for anchor in entry.anchors {
                if let reason = DiscoveryTipRegistry.forbiddenAnchors[anchor.file] {
                    Issue.record("""
                        \(entry.typeName) is anchored in \(anchor.file), which is on the denylist: \
                        \(reason)
                        """)
                }
            }
        }
    }

    /// And the denylist itself must stay honest: an entry naming a file that no longer exists is a
    /// guard protecting nothing, and would quietly stop covering a real hazard.
    @Test("Every denylisted file still exists")
    func denylistIsCurrent() throws {
        for (path, reason) in DiscoveryTipRegistry.forbiddenAnchors {
            let url = Self.root.appending(path: path)
            #expect(FileManager.default.fileExists(atPath: url.path),
                    "denylisted \(path) no longer exists — drop the entry (reason was: \(reason))")
        }
    }

    // MARK: - The launch configuration

    /// Both halves of the Phase-0 config change, pinned where a scan can see them. A popover
    /// intercepts a UI test's tap and reads as "the tap did nothing".
    @Test("TipKit is configured for hourly display and suppressed under UI test")
    func launchConfigurationIsCorrect() throws {
        let app = try Self.source("FRUSExplorer/App/FRUSExplorerApp.swift")
        #expect(app.contains(".displayFrequency(.hourly)"),
                "`.immediate` lets a first session collect several popovers at once")
        #expect(app.contains("Tips.hideAllTipsForTesting()"))
        #expect(!app.contains("Tips.showAllTipsForTesting()"),
                "showAllTipsForTesting forces display regardless of rules — never ship it")
        #expect(app.contains("FRUS_UI_TEST_MODE"),
                "the suppression must be gated on the UI-test flag, not applied unconditionally")
        // The one deliberate escape hatch, so `UIObstructionTests` can put a real popover on
        // screen and prove it clears the navigation bar.
        #expect(app.contains("FRUS_UI_TEST_SHOW_TIPS"),
                "the opt-in that lets an obstruction scenario test a tip has gone")
    }
}
