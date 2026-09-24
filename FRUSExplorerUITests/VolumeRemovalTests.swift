// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import XCTest
#if canImport(UIKit)
import UIKit
#endif

/// Removing a volume from Settings ▸ Volumes & Storage ▸ **Show all N** (*Volumes on This Device*),
/// and the two confirmations that ask first (#1356, #1357).
///
/// ## What each test can catch, and on which device
/// - ``testRemoveConfirmationPointsAtTheSwipedRow()`` — **iPad only** (#1357). In a regular-width
///   size class SwiftUI presents a confirmation dialog as a popover whose source is the view that
///   carries the modifier. The dialog used to be attached to the whole `List`, so its arrow pointed
///   at the list, not at the row the reader swiped. The test swipes a row in the MIDDLE of the list
///   and requires the popover to be presented from that row — ``isPresented(_:from:)`` says what
///   that means on iPadOS 26, where it is not always "directly above or below". On a phone the
///   dialog is an action sheet with no source, so the test skips there — it would pass either way,
///   which makes a phone run a control, not a guard. Against unfixed `v2` on iPad Pro 13-inch
///   (iOS 26.4) it fails: popover at y 62–387, the row at 503–570.
/// - ``testFreeUpSpaceConfirmationPointsAtItsButton()`` — **iPad only**, same mechanism. Free Up
///   Space's *Remove these volumes?* was attached to the sheet's content and asked from a toolbar
///   button; the popover must be presented from that button. Against unfixed `v2` it fails: the
///   popover spans x 372–660, and the button's centre is at x 711.
/// - ``testRemovedRowLeavesTheListWithoutATouch()`` — **both idioms**, and a CONTROL against `v2`,
///   not a guard of #1356's symptom. #1356's capture had the row on screen six seconds after its
///   file was gone, and gone only at the next touch; the test removes the row and waits, touching
///   nothing. Against unfixed `v2` it PASSES — the row left 1.1 s after the confirmation on iPad
///   Pro 13-inch at iOS 26.4 and again at iOS 27.0 — so the capture's delay was not reproduced on
///   a simulator. What it does guard is the fix's own wiring: the list now draws from the hub's
///   model, and a hub that stopped writing its re-measured report there would leave the row in
///   place and fail this test. It is deliberately NOT the test of the in-progress state: a
///   timing-based assertion about what the row reads mid-removal passes on a fast removal and
///   flakes under load. That state is `DownloadedVolumesListModelTests`', which suspends the
///   removal on a continuation.
///
/// ## The rows
/// `FRUS_UI_TEST_SEED_STORAGE_ROWS=1` makes the app write five side-loaded volumes,
/// `uitest-storage-01` … `-05`, at boot, and every launch without it removes them again
/// (`UITestVolumeSeeder.prepareStorageRows`). The tests use the fourth: rows on both sides of it,
/// and far enough from where a list-anchored popover lands that it cannot sit beside it by accident
/// (``targetVolumeId`` has the measurement). `FRUS_UI_TEST_SEED_VOLUME`
/// writes the browse fixture as well, because Free Up Space offers only volumes the app can
/// download again, and a side-loaded row is never one.
///
/// Version history:
///   1.0 — #1356/#1357: initial implementation
//
// Note: the XCUI APIs are main-actor isolated, so the class is `@MainActor` and overrides the ASYNC
// `setUp`/`tearDown` (see the note at the head of `UIObstructionTests`).
@MainActor
final class VolumeRemovalTests: XCTestCase {

    /// The row the tests act on: the fourth of the five the seam writes, with three seeded rows above
    /// it and one below.
    ///
    /// Not the third, and that was measured. Against unfixed `v2` on iPad Pro 13-inch the
    /// list-anchored popover drew at y 62–387 with the third row at 436–503: a 49 pt miss, only
    /// 25 pt outside ``adjacency``, and inside it for the row above. The fourth row sits a full row
    /// further from where a list-anchored popover lands.
    private static let targetVolumeId = "uitest-storage-04"

    /// The catalogue volume the browse fixture is written for — Free Up Space's one candidate.
    private static let catalogueVolumeId = "frus1961-63v06"

    /// How far, in points, a popover's frame may stop short of its source and still reach it.
    /// Covers the arrow, which XCUI may or may not count in the popover's frame; a row here is 67 pt
    /// tall, so a popover beside a NEIGHBOURING row's far edge is outside it.
    private static let adjacency: CGFloat = 24

    var app: XCUIApplication!

    /// Resolves the Settings tab in whichever representation iPadOS has chosen.
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_STORAGE_ROWS"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_VOLUME"] = Self.catalogueVolumeId
        app.launchArguments = UITestLaunch.arguments(startingOn: .settings)
        app.launch()
        settleAfterLaunch()
    }

    override func tearDown() async throws {
        // CLAUDE.md's rule — close what the suite opened, not merely terminate — even though
        // nothing opened here restores across a launch (a `.sheet` and a popover on plain
        // `@State`, a navigation stack with no stored path). A cleanup tap that fails must not
        // STOP the test: measured, one did, with `continueAfterFailure` still false, and the run
        // then sat out its five-minute allowance.
        continueAfterFailure = true
        closePresentations()
        app = nil
    }

    // MARK: - #1357

    /// The row's confirmation hangs from the row the reader swiped, not from the list.
    func testRemoveConfirmationPointsAtTheSwipedRow() throws {
        try skipUnlessPad()
        try openVolumeList()
        let row = try requireRow(Self.targetVolumeId)

        row.swipeLeft()
        let remove = app.buttons["Remove"].firstMatch
        XCTAssertTrue(remove.waitForExistence(timeout: 5), "The row's Remove swipe action never appeared")
        remove.tap()

        let popover = app.popovers.firstMatch
        XCTAssertTrue(popover.waitForExistence(timeout: 5), """
            "Remove this volume?" did not open as a popover on iPad. Tree:
            \(app.debugDescription)
            """)
        let rowFrame = row.frame
        let popoverFrame = popover.frame
        print("[VolumeRemovalTests] row \(rowFrame), popover \(popoverFrame)")
        keepScreenshot(named: "Remove this volume? over \(Self.targetVolumeId)")
        XCTAssertTrue(isPresented(popoverFrame, from: rowFrame), """
            "Remove this volume?" is not anchored to the swiped row: popover \(popoverFrame), \
            row \(Self.targetVolumeId) \(rowFrame). A popover that stops more than \
            \(Self.adjacency) pt short of the row points at something else — before #1357, the \
            whole list.
            """)
    }

    /// Free Up Space's confirmation hangs from the button that asks it.
    func testFreeUpSpaceConfirmationPointsAtItsButton() throws {
        try skipUnlessPad()
        try openHub()

        let freeUp = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Free Up Space")).firstMatch
        XCTAssertTrue(scrollUntilHittable(freeUp), "The hub's Free Up Space… button is not reachable")
        freeUp.tap()
        let sheetBar = app.navigationBars["Free Up Space"]
        XCTAssertTrue(sheetBar.waitForExistence(timeout: 10), "The Free Up Space sheet never opened")

        let candidate = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Kennedy-Khrushchev")).firstMatch
        XCTAssertTrue(candidate.waitForExistence(timeout: 10), """
            Free Up Space does not offer the seeded catalogue volume \(Self.catalogueVolumeId). Tree:
            \(app.debugDescription)
            """)
        candidate.tap()

        let ask = sheetBar.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Remove ")).firstMatch
        XCTAssertTrue(ask.waitForExistence(timeout: 5), "The sheet's Remove button never appeared")
        XCTAssertTrue(ask.isEnabled, "The sheet's Remove button is still disabled after selecting a volume")
        let buttonFrame = ask.frame
        ask.tap()

        let popover = app.popovers.firstMatch
        XCTAssertTrue(popover.waitForExistence(timeout: 5), """
            "Remove these volumes?" did not open as a popover on iPad. Tree:
            \(app.debugDescription)
            """)
        let popoverFrame = popover.frame
        print("[VolumeRemovalTests] Free Up Space button \(buttonFrame), popover \(popoverFrame)")
        keepScreenshot(named: "Remove these volumes? over Free Up Space")
        XCTAssertTrue(isPresented(popoverFrame, from: buttonFrame), """
            "Remove these volumes?" is not anchored to the button that asks it: popover \
            \(popoverFrame), button \(buttonFrame). A popover from the button reaches it and spans \
            its centre; one anchored to the sheet's content — before #1357 — is centred on the sheet.
            """)
    }

    // MARK: - #1356

    /// A removed row leaves the list on its own, with nothing touched after the confirmation.
    func testRemovedRowLeavesTheListWithoutATouch() throws {
        try openVolumeList()
        let row = try requireRow(Self.targetVolumeId)

        row.swipeLeft()
        let remove = app.buttons["Remove"].firstMatch
        XCTAssertTrue(remove.waitForExistence(timeout: 5), "The row's Remove swipe action never appeared")
        remove.tap()
        let confirm = try requireConfirmButton()
        confirm.tap()
        let confirmedAt = Date()

        // Nothing is touched from here on: #1356's row left only at the NEXT touch.
        let left = row.waitForNonExistence(timeout: 30)
        print("[VolumeRemovalTests] the removed row \(left ? "left" : "was still listed") "
              + String(format: "%.1f s after the confirmation", Date().timeIntervalSince(confirmedAt)))
        XCTAssertTrue(left, """
            The removed row \(Self.targetVolumeId) is still in the list 30 s after its removal was \
            confirmed, with nothing touched since. The list did not redraw from the hub's new \
            measurement (#1356). Tree:
            \(app.debugDescription)
            """)
    }

    // MARK: - Navigation

    /// Waits out a boot indexing pass, closing the education sheet its banner opens.
    ///
    /// The first launch after an index-version bump re-indexes every volume on disk, AFTER the
    /// pipeline is published, and the banner that reports it opens *Learn about FRUS* over the
    /// screen once per session. Measured in this suite's first run on iPad Pro 13-inch: the sheet
    /// covered the Settings row, and all three tests failed tapping it. The seeded rows themselves
    /// are indexed before the pipeline is published (`UITestVolumeSeeder.prepareStorageRowIndex`),
    /// so a warm simulator never shows either and this returns within its first wait.
    private func settleAfterLaunch() {
        let banner = app.staticTexts.matching(
            NSPredicate(format: "label MATCHES %@", "Volume [0-9]+ of [0-9]+")).firstMatch
        if banner.waitForExistence(timeout: 3) {
            // Let the pass finish rather than racing it: the sheet can open at any point in it.
            _ = banner.waitForNonExistence(timeout: 240)
        }
        // The sheet opens 0.6 s after the banner first appears, so a short pass can leave it behind.
        Thread.sleep(forTimeInterval: 1)
        closeEducationSheetIfPresent()
    }

    /// Pages *Learn about FRUS* to its end and closes it with **Start exploring**, if it is open.
    ///
    /// Paging rather than tapping outside, because on a phone the sheet has no outside. Every tap is
    /// preceded by a wait and followed by a pause: the pages change with an animation, and a
    /// **Next** that existed a moment ago can be gone by the time it is tapped, which fails the test
    /// in `setUp` — measured, it did, and the run then sat out its five-minute allowance.
    private func closeEducationSheetIfPresent() {
        let start = app.buttons["Start exploring"]
        let next = app.buttons["Next"]
        // The sheet's first page, which is where an auto-opened sheet always starts.
        let firstPage = app.staticTexts["The Official Record of American Foreign Policy"]
        guard start.exists || (next.exists && firstPage.exists) else { return }
        var pages = 0
        while !start.exists, pages < 20 {
            guard next.waitForExistence(timeout: 2), next.isHittable else { break }
            next.tap()
            pages += 1
            Thread.sleep(forTimeInterval: 0.8)
        }
        if start.waitForExistence(timeout: 2), start.isHittable { start.tap() }
        _ = start.waitForNonExistence(timeout: 3)
    }

    /// Skips on a phone, where a confirmation dialog is an action sheet with no source to point at.
    private func skipUnlessPad() throws {
        #if canImport(UIKit)
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, """
            The confirmation is a popover only in a regular-width size class; on a phone it is an \
            action sheet with no anchor, so this test would pass either way. Run it on an iPad.
            """)
        #else
        throw XCTSkip("UIKit-only test")
        #endif
    }

    /// Settings ▸ Volumes & Storage, waiting for the first storage measurement to land.
    private func openHub() throws {
        if !app.navigationBars["Settings"].waitForExistence(timeout: 20) {
            let outcome = navigator.select(.settings, resolveTimeout: 20)
            XCTAssertTrue(outcome.tapped, "The Settings tab could not be selected")
        }
        let pane = app.buttons["Volumes & Storage"].firstMatch
        XCTAssertTrue(pane.waitForExistence(timeout: 10), "Settings has no Volumes & Storage row")
        pane.tap()
        XCTAssertTrue(app.navigationBars["Volumes & Storage"].waitForExistence(timeout: 10),
                      "The Volumes & Storage hub never opened")
    }

    /// The hub, then **Show all N**.
    private func openVolumeList() throws {
        try openHub()
        let showAll = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Show all ")).firstMatch
        XCTAssertTrue(showAll.waitForExistence(timeout: 20), """
            The hub has no Show all row — the seeded rows did not reach the storage report. Tree:
            \(app.debugDescription)
            """)
        XCTAssertTrue(scrollUntilHittable(showAll), "The hub's Show all row is not reachable")
        showAll.tap()
        XCTAssertTrue(app.navigationBars["Volumes on This Device"].waitForExistence(timeout: 10),
                      "Volumes on This Device never opened")
    }

    /// The list cell for `volumeId`, found by the status line that begins with its id.
    private func requireRow(_ volumeId: String) throws -> XCUIElement {
        let row = app.cells.containing(NSPredicate(format: "label BEGINSWITH %@", "\(volumeId) ·")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), """
            No row for \(volumeId) in Volumes on This Device. Tree:
            \(app.debugDescription)
            """)
        XCTAssertTrue(scrollUntilHittable(row), "The row for \(volumeId) is not reachable")
        return row
    }

    /// The confirmation's destructive button, in whichever form the idiom presents it.
    private func requireConfirmButton() throws -> XCUIElement {
        let candidates = [app.popovers.buttons["Remove"], app.sheets.buttons["Remove"],
                          app.alerts.buttons["Remove"]]
        var found: XCUIElement?
        let deadline = Date().addingTimeInterval(5)
        repeat {
            found = candidates.first { $0.exists }
            if found == nil { Thread.sleep(forTimeInterval: 0.25) }
        } while found == nil && Date() < deadline
        return try XCTUnwrap(found, """
            "Remove this volume?" offered no Remove button in a popover, sheet or alert. Tree:
            \(app.debugDescription)
            """)
    }

    /// Swipes the frontmost scroll view up until `element` is hittable, or gives up.
    @discardableResult
    private func scrollUntilHittable(_ element: XCUIElement, attempts: Int = 8) -> Bool {
        for _ in 0..<attempts {
            if element.exists && element.isHittable { return true }
            app.swipeUp()
        }
        return element.exists && element.isHittable
    }

    /// Whether `popover` is presented FROM `source`: its frame reaches the source, within
    /// ``adjacency``, and spans the source's horizontal centre.
    ///
    /// Two shapes pass, because iPadOS 26 draws two. A popover from a list row sits beside the row
    /// with its arrow on it. A popover from a toolbar button grows out of the button and covers it
    /// — measured with the fix, *Remove these volumes?* drew at x 567–855 × y 274–506 over its
    /// button at 630–792 × 372–408 — so "directly above or below", the rule #1357 proposed, fails a
    /// correctly anchored popover there. The centre condition is what refuses a popover anchored to
    /// a container: against unfixed `v2` the same dialog, anchored to the sheet's content, drew
    /// centred on the sheet at x 372–660 and missed its button's centre at x 711 while its frame,
    /// widened by ``adjacency``, still reached the button.
    private func isPresented(_ popover: CGRect, from source: CGRect) -> Bool {
        let reaches = popover.insetBy(dx: -Self.adjacency, dy: -Self.adjacency).intersects(source)
        let spansCentre = popover.minX <= source.midX && source.midX <= popover.maxX
        return reaches && spansCentre
    }

    /// Keeps a screenshot in the result bundle whether the test passes or fails, so the anchor a
    /// frame check accepted can also be seen.
    private func keepScreenshot(named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Closes an open popover and the Free Up Space sheet, if either is open.
    ///
    /// The dismiss region is taken by COUNT, not by subscript: with the confirmation open over Free
    /// Up Space there are two — one for the sheet, one for the popover — and a subscript that
    /// matches two elements fails the test. Measured: it did, in `tearDown`.
    private func closePresentations() {
        guard let app, app.state == .runningForeground else { return }
        let regions = app.otherElements.matching(identifier: "PopoverDismissRegion")
        let count = regions.count
        if count > 0 {
            regions.element(boundBy: count - 1).tap()
            Thread.sleep(forTimeInterval: 0.5)
        }
        let freeUpCancel = app.navigationBars["Free Up Space"].buttons["Cancel"]
        if freeUpCancel.exists { freeUpCancel.tap() }
    }
}
