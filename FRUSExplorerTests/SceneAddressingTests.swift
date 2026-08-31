// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - SceneAddressingTests

/// The #752 tail (F-2): an action reaches the window it belongs to, and only that window.
///
/// ## The family, and what it is not
/// PR #769 closed the high-severity half — a standalone iPad document window shipping its reading
/// actions to the window that launched it. This is the low-severity remainder, and it shares one
/// shape: **a producer that cannot name a window addresses `.anyWindow`, which is
/// first-observer-wins.** That is a correct *rescue* for something with no window (a Spotlight
/// continuation once had none) and wrong as a *destination* for something a user did in a live one.
///
/// Three of the four items are here. The fourth, L-48, does not reproduce and was closed with a
/// documentation correction rather than code — see `AppState.pendingAuxWindowOriginRaw`.
///
/// ## What these tests can and cannot prove
/// They are source-text audits, following the five precedents in this bundle. Multi-window iPad
/// behaviour is unreachable from XCTest: both test bundles are `platform: iOS`, a simulator hosts
/// one scene, and the failures here are about *which of several live windows* observes a value.
/// So these pin the wiring — the producer names a scene, the pair travels together, the shared flag
/// is gone — and the PR carries a device checklist for the behaviour itself.
///
/// Version history:
///   1.0 — Session 2026-08-10: #752 F-2 (audit M-25, L-40, L-43)
@Suite("Scene addressing (#752 F-2)")
struct SceneAddressingTests {

    // MARK: - Helpers

    private static var appSourceRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer")
    }

    private static func source(_ relative: String) throws -> String {
        try String(contentsOf: appSourceRoot.appendingPathComponent(relative), encoding: .utf8)
    }

    /// Every `.swift` under `FRUSExplorer/`, as (path, contents).
    private static func allSources() throws -> [(path: String, text: String)] {
        let root = appSourceRoot
        guard let walker = FileManager.default.enumerator(at: root,
                                                          includingPropertiesForKeys: nil) else {
            return []
        }
        var result: [(String, String)] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            let relative = url.path.replacingOccurrences(of: root.path + "/", with: "")
            result.append((relative, try String(contentsOf: url, encoding: .utf8)))
        }
        return result.sorted { $0.0 < $1.0 }
    }

    /// Source lines with comment-only lines removed, keeping 1-based numbers.
    ///
    /// Without this every assertion below can be satisfied — or broken — by prose. The suites this
    /// one follows learned that the hard way.
    static func codeLines(_ source: String) -> [(line: Int, text: String)] {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .map { (line: $0.offset + 1, text: $0.element.trimmingCharacters(in: .whitespaces)) }
            .filter { !$0.text.hasPrefix("//") && !$0.text.hasPrefix("///") && !$0.text.hasPrefix("*") }
    }

    @Test("codeLines keeps code and drops prose")
    func codeLinesFilters() {
        let sample = """
            // appState.openBrowseDocument(entry, from: .anyWindow)
            /// and again in a doc comment
            appState.openBrowseDocument(entry, from: sceneID)
            """
        let kept = Self.codeLines(sample)
        #expect(kept.count == 1)
        #expect(kept.first?.text == "appState.openBrowseDocument(entry, from: sceneID)")
    }

    /// The target expression of an `openTab`/`openBrowseDocument` call — the text after `from:`.
    static func target(in line: String) -> String? {
        guard let from = line.range(of: "from: ") else { return nil }
        let rest = line[from.upperBound...]
        guard let close = rest.firstIndex(of: ")") else { return nil }
        return String(rest[..<close]).trimmingCharacters(in: .whitespaces)
    }

    @Test("target reads the argument, not the whole call")
    func targetParses() {
        #expect(Self.target(in: "appState.openTab(.browse, from: sceneID)") == "sceneID")
        #expect(Self.target(in: "appState.openBrowseDocument(entry, from: .anyWindow)") == ".anyWindow")
        #expect(Self.target(in: "somethingElse()") == nil)
    }

    // MARK: - M-25 + L-40: the pair travels together, to one window

    /// How far apart the two halves of the pair may sit, in code lines.
    ///
    /// Three, not a character window: `DocumentView` legitimately separates them with an
    /// `#if os(iOS)` / `#endif`. A generous *character* window is what let an earlier suite's
    /// assertion spill into a neighbouring block and pass with the thing it tested deleted.
    private static let pairSpan = 3

    @Test("Every openBrowseDocument producer pairs an openTab, addressed to the same window")
    func everyProducerPairsItsTab() throws {
        // The invariant `AppState.openTab`'s own doc comment claims: the tab switch and its content
        // "land in the SAME window — the two can no longer split across windows (BUG-7)". That is
        // only true when both name the same target. With two `.anyWindow` wildcards it was false,
        // because the two channels are consumed by different views with different eligibility:
        // `MainTabView` exists in every window, `BrowserView` only once its view model has
        // bootstrapped. A window that never visited Browse could take the tab and another the
        // document.
        //
        // Anchored on `appState.openBrowseDocument(` rather than the bare name so the declaration
        // in `AppState.swift` — a code line this filter does not strip — cannot fail the test.
        var unpaired: [String] = []
        var mismatched: [String] = []
        var checked = 0
        for (path, text) in try Self.allSources() {
            let lines = Self.codeLines(text)
            for (index, line) in lines.enumerated()
            where line.text.contains("appState.openBrowseDocument(") {
                checked += 1
                let lower = max(0, index - Self.pairSpan)
                let upper = min(lines.count - 1, index + Self.pairSpan)
                let neighbours = lines[lower...upper].filter { $0.text.contains("appState.openTab(") }
                guard let tab = neighbours.first else {
                    unpaired.append("\(path):\(line.line)")
                    continue
                }
                if Self.target(in: tab.text) != Self.target(in: line.text) {
                    mismatched.append("""
                        \(path):\(line.line) — document → \(Self.target(in: line.text) ?? "?"), \
                        tab → \(Self.target(in: tab.text) ?? "?")
                        """)
                }
            }
        }
        #expect(checked >= 10, """
            Only \(checked) producers found — the anchor `appState.openBrowseDocument(` has \
            probably been renamed, and this test is passing vacuously.
            """)
        #expect(unpaired.isEmpty, """
            These producers open a document without switching the window to Browse (#752 / L-40). \
            The document lands in a Browse stack the user is not looking at and surfaces whenever \
            they next visit that tab: \(unpaired.joined(separator: ", "))
            """)
        #expect(mismatched.isEmpty, """
            These producers send the tab switch and the document to DIFFERENT windows (#752 / \
            M-25): \(mismatched.joined(separator: " | "))
            """)
    }

    @Test("The Source Explorer window's related-doc tap reads a scene rather than the wildcard")
    func sourceExplorerWindowNamesItsScene() throws {
        // L-40. It was the one unpaired producer of eleven, and it addressed `.anyWindow` because
        // the tap lived in a plain closure inside the scene builder — closures cannot read
        // `\.sceneID`. The fix is a View that can.
        let source = try Self.source("App/FRUSExplorerApp.swift")
        #expect(source.contains("struct SourceExplorerWindowContent"), """
            The Source Explorer window's content must be a View, not an inline closure, or its \
            related-documents tap has no window to name (#752 / L-40).
            """)
        let body = try #require(source.range(of: "private struct SourceExplorerWindowContent"))
            .upperBound
        let extracted = String(source[body...].prefix(2_000))
        #expect(extracted.contains("@Environment(\\.sceneID) private var sceneID"),
                "and it must read the scene `.auxWindowOrigin` publishes above it")
        #expect(!extracted.contains(".anyWindow"), """
            The tap must address the window that opened this one, not the first-wins wildcard. \
            `.anyWindow` is reached through `resolveOriginScene` when that window has closed — \
            which is the correct degradation, and is not spelled here.
            """)
    }

    @Test("The continuation handlers can name the window they fired in")
    func continuationsAddressTheirScene() throws {
        // M-25. The three continuation modifiers hang on the WindowGroup's content, but the scene
        // identity was minted two levels below them in MainTabView, so they had no window to name.
        let source = try Self.source("App/FRUSExplorerApp.swift")
        #expect(source.contains("private struct ContinuationHost: ViewModifier"), """
            The Spotlight / Handoff / open-with handlers must sit inside a per-window host that \
            publishes a scene identity above the tab view (#752 / M-25).
            """)
        for handler in ["continueDocumentActivity(activity, from: sceneID)",
                        "continueSpotlightActivity(activity, from: sceneID)",
                        "importOpenedCollection(url, from: sceneID)"] {
            #expect(source.contains(handler), "\(handler) must receive the receiving window's scene")
        }

        let navigate = try #require(source.range(of:
            "private func navigateToDocument(volumeId: String, documentId: String, title: String?,"))
        let body = String(source[navigate.upperBound...].prefix(1_600))
        // Comment-stripped: the region's prose explains what `.anyWindow` used to do, and a raw
        // `contains` reads its own explanation as the defect it describes.
        let ios = Self.codeLines(String(body[(body.range(of: "#else")?.upperBound ?? body.startIndex)...]))
            .map(\.text).joined(separator: "\n")
        #expect(!ios.contains(".anyWindow"), """
            The iOS branch must address the continuation's own scene, not the wildcard (#752 / \
            M-25). `openTab`/`openBrowseDocument` fall back to `.anyWindow` themselves when the \
            scene is nil, so spelling it here would defeat the fix.
            """)
    }

    @Test("ContinuationHost publishes a per-window identity, not just mints one")
    func continuationHostPublishesItsScene() throws {
        // Both of these survived the first mutation sweep, and each is the worst regression this
        // change could cause:
        //
        // - Delete the `.environment(\.sceneID, …)` line and the host still compiles, the handlers
        //   still receive a scene, and MainTabView — finding nothing published — falls back to its
        //   own mint. Every continuation is then addressed to a token no consumer holds, so
        //   Spotlight, Handoff and open-with all black-hole. Strictly worse than the `.anyWindow`
        //   this replaces, which at least always landed somewhere.
        // - Make the token a constant and every window publishes the same identity, so addressing
        //   is meaningless and the fan-out this fixes returns silently.
        let source = try Self.source("App/FRUSExplorerApp.swift")
        let start = try #require(source.range(of: "private struct ContinuationHost: ViewModifier"))
        let body = Self.codeLines(String(source[start.upperBound...].prefix(2_000)))
            .map(\.text).joined(separator: "\n")

        #expect(body.contains("@State private var sceneIDToken = UUID().uuidString"), """
            The token must be per-window `@State` minted from a UUID. A `let` constant, or one \
            shared across windows, publishes the same identity everywhere and addressing a \
            hand-off to it targets all of them (#752 / M-25).
            """)
        #expect(body.contains(".environment(\\.sceneID, sceneID)"), """
            The host must PUBLISH the identity it mints, or `MainTabView` inherits nothing, falls \
            back to its own mint, and every continuation is addressed to a scene no consumer \
            holds — a black hole where `.anyWindow` at least always landed somewhere.
            """)
        // Adjacency, not "appears somewhere": the publish has to be on the same chain as the
        // handlers, which is what puts the three modifiers inside this window's identity.
        let publishIndex = try #require(body.range(of: ".environment(\\.sceneID, sceneID)"))
        let firstHandler = try #require(body.range(of: ".onContinueUserActivity("))
        #expect(publishIndex.lowerBound < firstHandler.lowerBound,
                "the scene must be published on the chain the handlers are attached to")
    }

    @Test("MainTabView adopts a scene published above it, and still mints one when there is none")
    func mainTabViewAdoptsTheHoistedScene() throws {
        // Both halves matter. Without adoption the continuation targets a token no consumer holds
        // and the hand-off black-holes; without the fallback mint, a host not wrapped in
        // `ContinuationHost` publishes nothing and every per-window hand-off breaks.
        let source = try Self.source("App/MainTabView.swift")
        #expect(source.contains("@Environment(\\.sceneID) private var inheritedSceneID"),
                "MainTabView must read a scene identity published above it (#752 / M-25)")
        #expect(source.contains("private var sceneIDToken: String { inheritedSceneID?.raw ?? mintedSceneIDToken }"),
                "…and fall back to its own mint when there is none")
    }

    // MARK: - M-25: the claim that makes the fix safe on an unmeasured platform

    @Test("A continuation is claimed once, and released for the next turn")
    @MainActor
    func continuationIsClaimedOnce() {
        // UIKit delivers a user activity to ONE scene and SwiftUI bridges that per scene, so this
        // guard should never fire in production. It exists because that is not verified on a
        // device and the cost of being wrong is asymmetric: now that each handler addresses its own
        // window, a fan-out would open the document in EVERY window rather than one.
        let state = AppState()
        #expect(state.claimContinuation("spotlight|frus1952-54v01/d1"))
        #expect(!state.claimContinuation("spotlight|frus1952-54v01/d1"), """
            A second window handling the same continuation must not act on it. Without this the \
            fan-out reading opens the document once per open window.
            """)
        #expect(state.claimContinuation("spotlight|frus1952-54v01/d2"),
                "a different continuation is a different claim")

        state.releaseContinuationClaim("spotlight|frus1952-54v01/d2")
        #expect(state.claimContinuation("spotlight|frus1952-54v01/d2"), """
            After the release the same continuation must be claimable again — a user tapping the \
            same Spotlight result twice is two events, not one.
            """)
    }

    @Test("Releasing a stale key does not free the current claim")
    @MainActor
    func releaseIsKeyed() {
        let state = AppState()
        #expect(state.claimContinuation("a"))
        state.releaseContinuationClaim("b")
        #expect(!state.claimContinuation("a"),
                "releasing some other continuation must not unlock this one")
    }

    @Test("Every continuation entry point takes a claim")
    func everyContinuationClaims() throws {
        // Handoff, Spotlight, and the URL entry point — which since W-19 L-5 carries both the
        // `.fruscollection` open-with AND the `frusexplorer://` deep link, routed ahead of it.
        // The scheme's links INSIDE rendered documents still never reach the OS; the web view
        // intercepts them.
        let source = try Self.source("App/FRUSExplorerApp.swift")
        for claim in ["appState.claimContinuation(\"handoff|",
                      "appState.claimContinuation(\"spotlight|",
                      "appState.claimContinuation(\"openURL|"] {
            #expect(source.contains(claim), """
                \(claim)…) is missing. An unclaimed entry point is the one that fans out if the \
                platform delivers to every scene (#752 / M-25).
                """)
        }
    }

    // MARK: - L-43: no presentation flag is shared across windows

    /// The spelling this scan catches.
    private static let sharedFlagNeedle = "isPresented: $appState."

    @Test("The scan finds a shared presentation flag when there is one")
    func sharedFlagScanIsNotVacuous() {
        let sample = "        .sheet(isPresented: $appState.showFoo) {"
        #expect(Self.codeLines(sample).contains { $0.text.contains(Self.sharedFlagNeedle) })
    }

    @Test("No sheet or alert is presented from a Bool on the shared AppState")
    func noSharedPresentationFlags() throws {
        // L-43: `showResearchGuide` was a Bool on the app-wide AppState driving a
        // `.sheet(isPresented:)` in SettingsView, so on an iPad every open window's Settings tab
        // was bound to the same flag. The audit prescribed converting it to a scene-addressed
        // hand-off; the right answer was to delete it, because the row that sets it and the sheet
        // that shows it are one view in one window.
        var hits: [String] = []
        for (path, text) in try Self.allSources() {
            for line in Self.codeLines(text) where line.text.contains(Self.sharedFlagNeedle) {
                hits.append("\(path):\(line.line)")
            }
        }
        #expect(hits.isEmpty, """
            A presentation flag on the shared AppState fans out to every open iPad window \
            (#752 / L-43): \(hits.joined(separator: ", ")).

            KNOWN LIMIT — this catches one spelling. `ProjectPickerMenu`'s `nudgePresented` and \
            `StoreSchemaMismatchAlert` reach the same shared state through hand-rolled `Binding`s \
            and are invisible here; both are documented as accepted. Green does NOT mean "no \
            shared presentation state remains".
            """)
    }

    @Test("The Research Guide presents from the view that owns its row")
    func researchGuideIsSceneLocal() throws {
        #expect(!(try Self.source("App/AppState.swift")).contains("var showResearchGuide"), """
            The flag must be gone, not merely unused — a live property invites a second producer \
            (#752 / L-43).
            """)
        let about = try Self.source("Settings/AboutView.swift")
        #expect(about.contains("@State private var showsResearchGuide"),
                "AboutView owns the state now")
        #expect(about.contains(".sheet(isPresented: $showsResearchGuide)"),
                "and presents the sheet itself, in its own window")
        #expect(!(try Self.source("Settings/SettingsView.swift")).contains("ResearchGuideView()"), """
            SettingsView must no longer present the guide, or both presenters fire and the second \
            one's sheet is the one that shows.
            """)
    }
}

// MARK: - Deep links (W-19 row L-5)

/// The `frusexplorer://` route: what it accepts, what it refuses, and that the OS knows about it.
///
/// Version history:
///   1.0 — W-19 L-5: initial implementation
@Suite("Deep link route")
struct DeepLinkRouteTests {

    private static func repoFile(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    @Test("A document link parses into its two ids")
    func documentLinkParses() throws {
        let url = try #require(URL(string: "frusexplorer://document/frus1961-63v11/d1"))
        #expect(DeepLinkRoute.from(url: url)
                == .document(volumeID: "frus1961-63v11", documentID: "d1"))
        // Scheme match is case-insensitive; the OS does not promise a case.
        let upper = try #require(URL(string: "FRUSEXPLORER://DOCUMENT/frus1861/d373a"))
        #expect(DeepLinkRoute.from(url: upper)
                == .document(volumeID: "frus1861", documentID: "d373a"))
    }

    @Test("The renderer's own hosts are recognised and refused by name")
    func inDocumentHostsAreNamed() throws {
        // These four have been serialized into exported collection HTML since long before the
        // scheme was registered. Recognising them is what stops those files launching the app to
        // do nothing.
        for host in ["person", "gloss", "doc", "brokenref"] {
            let url = try #require(URL(string: "frusexplorer://\(host)/whatever/else"))
            #expect(DeepLinkRoute.from(url: url) == .inAppOnly(host: host))
        }
    }

    @Test("Traversal and malformed shapes are refused before anything reaches the filesystem")
    func unsafeInputIsRefused() throws {
        // `DownloadManager.volumeURL(for:)` interpolates the volume id into a path with
        // `appendingPathComponent`, which does NOT resolve `..`. The parser is what makes that
        // safe, so these are the assertions standing between a web page and the container.
        //
        // Foundation does NOT normalise these away — measured: `document/../../etc/d1` yields
        // pathComponents ["/", "..", "..", "etc", "d1"] and the encoded form yields
        // ["/", "../../etc", "d1"]. So each of these is refused by a DIFFERENT rule, and the
        // bare-`..` case is the one that isolates the character set: it arrives as exactly two
        // components, so nothing but `isSafeIdentifier` stands between it and the container.
        let refusals = [
            "frusexplorer://document/../d1",             // ISOLATES the dot rule: two components
            "frusexplorer://document/../../etc/d1",      // refused on component count
            "frusexplorer://document/..%2F..%2Fetc/d1",  // refused on the embedded separator
            "frusexplorer://document/frus1861",          // one component
            "frusexplorer://document/a/b/c",             // three
            "frusexplorer://document//d1",               // empty volume
            "frusexplorer://elsewhere/a/b",              // unknown host
            "https://example.com/document/a/b",          // not our scheme
        ]
        for raw in refusals {
            guard let url = URL(string: raw) else { continue }
            #expect(DeepLinkRoute.from(url: url) == nil, "must refuse \(raw)")
        }
        // And the rule underneath, directly: a dot is not admissible, which is what makes ".."
        // unspellable rather than merely unlikely.
        #expect(!DeepLinkRoute.isSafeIdentifier(".."))
        #expect(!DeepLinkRoute.isSafeIdentifier("a/b"))
        #expect(!DeepLinkRoute.isSafeIdentifier(""))
        #expect(DeepLinkRoute.isSafeIdentifier("frus1969-76ve11p1"))
    }

    @Test("The in-app host list matches the renderer's own switch")
    func inAppHostsMatchTheRenderer() throws {
        // Two lists of the same four strings in different files is a drift waiting to happen: add
        // a host to the renderer and exported HTML gains a link this router silently ignores.
        let handler = try Self.repoFile("FRUSExplorer/TEI/FRUSURLSchemeHandler.swift")
        for host in DeepLinkRoute.inAppHosts {
            #expect(handler.contains("case \"\(host)\""),
                    "\(host) is routed here but absent from FRUSURLSchemeHandler's switch")
        }
    }

    @Test("The scheme is registered with the OS on both platforms")
    func schemeIsRegisteredInBothPlists() throws {
        // The wiring can be perfect and the feature inert because a plist key is missing — the
        // failure Handoff shipped with once. Both plists are GENERATED from project.yml, so a
        // future xcodegen run against an edited-back spec would silently unregister it.
        for plist in ["FRUSExplorer/Info.plist", "FRUSExplorer/Info-macOS.plist"] {
            let source = try Self.repoFile(plist)
            #expect(source.contains("CFBundleURLTypes"), "\(plist) lost the URL types block")
            #expect(source.contains("frusexplorer"), "\(plist) lost the scheme")
        }
        // And the source of truth, so the spec and the generated files cannot disagree.
        let spec = try Self.repoFile("project.yml")
        #expect(spec.components(separatedBy: "CFBundleURLTypes:").count == 3,
                "project.yml must declare the URL types on exactly the two app targets")
    }

    @Test("The URL entry point routes deep links ahead of the collection import")
    func deepLinksRouteBeforeTheCollectionImport() throws {
        let source = try Self.repoFile("FRUSExplorer/App/FRUSExplorerApp.swift")
        // Order matters: the import's only filter is a path-extension test, which
        // `frusexplorer://x/y.fruscollection` satisfies.
        #expect(source.contains("if let route = DeepLinkRoute.from(url: url)"))
        // And the import now refuses anything that is not a file, which is the guard that makes
        // the ordering a defence in depth rather than the only defence.
        #expect(source.contains("guard url.isFileURL else { return }"))
    }
}
