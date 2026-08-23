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

import Testing
import Foundation

// MARK: - TripPacketEntryPointParityTests

/// Pins the collection route into the trip packet, on every platform (#830).
///
/// ## The defect this exists for, and why the obvious test would have missed it
/// The collection entry point shipped in T-2 and **never worked on any platform**. The control that
/// sets `showTripPacket` lived in `iPhoneAddMenu`; the `.sheet` that observes it lived inside
/// `macBody`. `CollectionEditorView.body` renders `macBody` only under `#if os(macOS)`, so on iOS
/// the button set a flag nothing watched, and on macOS the presenter had no control to open it.
/// `iPadAddMenu` and the macOS manager pane had no item at all.
///
/// **A same-file check could not have caught it**, because the setter and the presenter were in the
/// same file — separated by a platform branch, not by a file boundary. So this suite asserts the
/// stronger property that actually failed: **the presenter must sit in the shared `body`**, above
/// the per-platform split, so no `#if` can strand it away from the control.
///
/// A UI test would also catch it, and would be better evidence — but it would catch it only on
/// whichever platform and size class the test happens to run at, and this defect was specifically
/// one of a *size class* (regular width had no item at all). A source scan covers all six
/// surface/size combinations at once, which is the shape of the bug.
///
/// Version history:
///   1.0 — Session 2026-08-23: #830, the dead collection entry point
@Suite("Trip packet entry-point parity (#830)")
struct TripPacketEntryPointParityTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func source(_ relativePath: String) throws -> String {
        try String(contentsOf: repoRoot.appending(path: relativePath), encoding: .utf8)
    }

    private static let editor = "FRUSExplorer/Collections/CollectionEditorView.swift"
    private static let macManager = "FRUSExplorer/Collections/MacCollectionManagerView.swift"

    /// Every surface that offers the action, keyed on the SHARED localization key rather than on
    /// the visible words — a menu that spelled its own label would be a different bug, and this
    /// suite is about wiring.
    private static let planVisitKey = "collection.planVisit"

    // MARK: - The presenter must be platform-independent

    /// **The exact failure.** `.sheet(isPresented: $showTripPacket)` must appear in the shared
    /// `body`, not inside `macBody` or `iOSBody`.
    ///
    /// Asserted by ORDER rather than by string proximity: `body` is declared before the two
    /// per-platform bodies, so the presenter's offset must fall between `var body` and whichever
    /// per-platform body is declared first. That is what makes this test fail on the original code
    /// — where the presenter sat several hundred lines *after* `private var macBody`.
    @Test("The collection presenter lives in the shared body, not a per-platform one")
    func presenterIsPlatformIndependent() throws {
        let text = try Self.source(Self.editor)

        guard let bodyStart = text.range(of: "\n    var body: some View {"),
              let macBody = text.range(of: "\n    private var macBody: some View {"),
              let iOSBody = text.range(of: "\n    private var iOSBody: some View {"),
              let presenter = text.range(of: ".sheet(isPresented: $showTripPacket)")
        else {
            Issue.record("CollectionEditorView no longer declares body / macBody / iOSBody / the presenter — re-derive this test against the new shape rather than deleting it")
            return
        }

        let firstPlatformBody = min(macBody.lowerBound, iOSBody.lowerBound)
        #expect(presenter.lowerBound > bodyStart.lowerBound, """
            The trip-packet sheet is declared before `var body`. Expected it inside the shared body.
            """)
        #expect(presenter.lowerBound < firstPlatformBody, """
            The trip-packet sheet sits inside a PER-PLATFORM body. That is exactly how this entry \
            point shipped dead: the presenter was in `macBody`, the control was in `iPhoneAddMenu`, \
            and `body` renders `macBody` only under `#if os(macOS)` — so neither platform had both \
            halves. Attach it to the shared `body`.
            """)
    }

    // MARK: - Every surface offers the action

    /// The action must be reachable at BOTH size classes on iOS. `iPadAddMenu` had no item, so at
    /// regular width — every iPad, and the larger iPhones in landscape — a collection could not
    /// reach the packet at all.
    @Test("Both iOS add-menus offer Plan an Archive Visit")
    func bothIOSMenusOfferTheAction() throws {
        let text = try Self.source(Self.editor)
        for menu in ["iPhoneAddMenu", "iPadAddMenu"] {
            guard let start = text.range(of: "\n    private var \(menu): some View {") else {
                Issue.record("\(menu) no longer exists — re-derive this test")
                continue
            }
            // Scope to THIS menu: from its declaration to the next one, so a match cannot be
            // borrowed from a sibling menu that happens to sit nearby.
            let rest = text[start.upperBound...]
            let end = rest.range(of: "\n    private var ")?.lowerBound ?? rest.endIndex
            let menuBody = rest[..<end]
            #expect(menuBody.contains(Self.planVisitKey), """
                \(menu) does not offer the trip packet. Every collection add-menu must, or the \
                route disappears at one size class — which is how `iPadAddMenu` shipped without it.
                """)
            #expect(menuBody.contains("showTripPacket = true"),
                    "\(menu) names the action but sets no state")
        }
    }

    /// macOS edits collections in `MacCollectionManagerView`, not in `CollectionEditorView.macBody`
    /// (which offers only a Done button). So the macOS route needs its own control AND its own
    /// presenter, both in that file.
    @Test("The macOS manager carries both halves of the route")
    func macManagerHasControlAndPresenter() throws {
        let text = try Self.source(Self.macManager)
        #expect(text.contains(Self.planVisitKey), """
            MacCollectionManagerView offers no Plan-an-Archive-Visit control. This is the pane \
            where macOS actually edits a collection — `CollectionEditorView.macBody` has only a \
            Done button — so without an item here macOS has no collection route to the packet.
            """)
        #expect(text.contains("showTripPacket = true"), "the macOS control sets no state")
        #expect(text.contains(".sheet(isPresented: $showTripPacket)"), """
            MacCollectionManagerView sets `showTripPacket` but never presents it — the same \
            half-wired shape that made this entry point dead on every platform.
            """)
        #expect(text.contains("TripPacketSheet("), "the macOS presenter builds no packet")
    }

    /// All three surfaces must use one localization key. Three hand-written labels would be three
    /// places for the menus to disagree about what the action is called.
    @Test("All three surfaces share one localization key")
    func surfacesShareOneKey() throws {
        let editor = try Self.source(Self.editor)
        let mac = try Self.source(Self.macManager)
        let occurrences = editor.components(separatedBy: Self.planVisitKey).count - 1
        #expect(occurrences == 2, """
            Expected the key exactly twice in CollectionEditorView (iPhone and iPad menus), \
            found \(occurrences).
            """)
        #expect(mac.components(separatedBy: Self.planVisitKey).count - 1 == 1,
                "Expected the key exactly once in MacCollectionManagerView")
    }
}
