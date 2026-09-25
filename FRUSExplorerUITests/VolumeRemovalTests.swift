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
///   at the list, not at the row the reader swiped. The test asks from TWO rows — the catalogue
///   volume's and a seeded row four below it — and requires each popover to hang from its own row
///   (``rowAnchorFailure(_:row:)`` says what that means). Each popover must also carry its row's
///   #777 message: the promise of a re-download for the catalogue volume, the side-loaded warning
///   for the seeded row. With the dialog moved back onto the list, it fails on iPad Pro 11-inch at
///   iOS 26.4 and at iOS 27.0, where #1357 was reported, on the catalogue row: the list-anchored
///   popover covers that row's middle.
/// - ``testFreeUpSpaceConfirmationPointsAtItsButton()`` — **iPad only**, same mechanism. Free Up
///   Space's *Remove these volumes?* was attached to the sheet's content and asked from a toolbar
///   button; the popover must be presented from that button (``buttonAnchorFailure(_:button:)``).
///   With the dialog back on the sheet's content it fails: on iPad Pro 13-inch (iOS 26.4) the
///   popover spanned x 372–660 against the button's centre at x 711; on iPad Pro 11-inch it spanned
///   x 273–561 against x 612 at iOS 26.4, and at iOS 27.0 it drew at y 935–1180, nowhere near the
///   button at y 289–325.
/// - ``testRemovedRowLeavesTheListWithoutATouch()`` — **both idioms**. #1356's capture had the row
///   on screen six seconds after its file was gone, and gone only at the next touch; this test
///   removes the row and waits, touching nothing, and then requires the LIST to be still there
///   with the removed row's neighbour in it — a list that popped or emptied loses the row too.
///   Against unfixed `v2` it PASSES (the row left 1.1 s after the confirmation on iPad Pro 13-inch,
///   iOS 26.4 and 27.0), so it guards the wiring rather than the reported symptom. It also reads
///   the side-loaded warning out of the dialog on both idioms.
/// - ``testRemovalMarkSurvivesLeavingTheHub()`` — **both idioms**, and the test of what the row
///   reads WHILE it is being removed. The launch holds every removal open for
///   ``removalHoldSeconds`` before its first step (`FRUS_UI_TEST_HOLD_STORAGE_REMOVAL`), so on the
///   fixed code the mark is on screen for as long as the hold lasts, and on code that does not
///   draw it the mark is never there at all — nothing races a fast removal. The test requires the
///   row to read *removing…*, goes Back to Settings and in again — a NEW hub — requires the
///   re-entered list to read it too, and then to lose the row with nothing touched. That is the
///   whole chain no unit test reaches: the row's Remove, the hub's routing, `AppState`'s model
///   and the row's status line. With the model held by the hub, as this PR first had it, the
///   re-entered list read `… · indexed · never opened`; with the hub removing inline, as `v2` did,
///   or the row drawing a status line of its own, the first list never read *removing…* at all.
/// - ``testFreeUpSpaceKeepsItsVolumeWhileRemovingIt()`` — **both idioms**, and the one test that
///   presses the Remove of *Remove these volumes?*. It holds the removal open for
///   ``freeUpHoldSeconds`` and requires the sheet to go on listing the volume it is removing, then
///   to close on its own when the removal ends. Round 1 of #1356's review had the hub hand the sheet
///   a plan that leaves out every volume being removed, and the sheet drew it live: the routing
///   marks the chosen volumes before its first step, so from the confirmation to the re-measure the
///   sheet said "No Removable Volumes" beside its own spinner. Against that code this test fails
///   on iPad Pro 11-inch and on iPhone 17 Pro, both at iOS 26.4: 2.5 s and 2.4 s after the
///   confirmation, the sheet read "No Removable Volumes" and no longer listed the volume. What the
///   sheet may NOT keep — a volume another removal took meanwhile — needs a second removal in a
///   second window, which this suite cannot drive; `DownloadedVolumesListModelTests` pins it.
///
/// A phone runs the two anchor tests only to skip them: there the dialog is an action sheet with
/// no source, which neither guards nor controls anything.
///
/// ## The rows
/// `FRUS_UI_TEST_SEED_STORAGE_ROWS=1` makes the app write five side-loaded volumes,
/// `uitest-storage-01` … `-05`, at boot, and every launch without it removes them again
/// (`UITestVolumeSeeder.prepareStorageRows`). `FRUS_UI_TEST_SEED_VOLUME` writes the browse fixture
/// as well — the catalogue row the anchor test asks from first, and the one volume Free Up Space
/// offers, since it offers only volumes the app can download again. The list sorts by id, so the
/// fixture's row comes first and the seeded rows follow it. ``requireRow(_:)`` scrolls to a row
/// rather than assuming it is on screen, so volumes left on a simulator move the rows without
/// breaking the tests.
///
/// ## Animations are off
/// `FRUS_UI_TEST_DISABLE_ANIMATIONS=1`, as CLAUDE.md asks of a suite that measures a screen at
/// rest: two tests read popover frames, and on iOS 27 an interrupted system animation can leave
/// XCTest waiting before every action for an idle that never comes. None of these tests is about
/// an animated transition.
///
/// Version history:
///   1.0 — #1356/#1357: initial implementation
///   1.1 — #1356 review, round 1: the row anchor is asked from two rows and read against each row's
///          own frame; the #777 messages; the list must stay after a removal;
///          `testRemovalMarkSurvivesLeavingTheHub`; animations off; rows found by scrolling
///   1.2 — #1356 review, round 2: `testFreeUpSpaceKeepsItsVolumeWhileRemovingIt`; the two Free Up
///          Space tests open the sheet through one helper
//
// Note: the XCUI APIs are main-actor isolated, so the class is `@MainActor` and overrides the ASYNC
// `setUp`/`tearDown` (see the note at the head of `UIObstructionTests`).
@MainActor
final class VolumeRemovalTests: XCTestCase {

    /// The seeded row the tests remove and ask from: the fourth of the five the seam writes, with
    /// the catalogue row and three seeded rows above it and one below.
    private static let targetVolumeId = "uitest-storage-04"

    /// The row above ``targetVolumeId``, which must still be listed after the removal.
    private static let neighbourVolumeId = "uitest-storage-03"

    /// The catalogue volume the browse fixture is written for — the anchor test's first row, and
    /// Free Up Space's one candidate.
    private static let catalogueVolumeId = "frus1961-63v06"

    /// A phrase from the catalogue volume's title, which is how Free Up Space names its row.
    private static let catalogueTitle = "Kennedy-Khrushchev"

    /// How long `testRemovalMarkSurvivesLeavingTheHub` holds the removal open, in seconds. Leaving
    /// and re-entering takes Back, Back, the Volumes & Storage row and Show all at XCUITest's pace:
    /// measured, 13.8 s on iPad Pro 11-inch at iOS 26.4 and 17.1 s at iOS 27.0, so 25 s left too
    /// little room for a loaded machine. The test checks that the re-entry finished inside the
    /// hold rather than assuming it.
    private static let removalHoldSeconds = 40

    /// How long `testFreeUpSpaceKeepsItsVolumeWhileRemovingIt` holds the removal open, in seconds.
    /// The test reads the sheet once, within a few seconds of the confirmation, and checks that it
    /// did so inside the hold. Removing the catalogue volume costs the suite nothing: every launch
    /// writes the fixture again and re-indexes it before the pipeline is published.
    private static let freeUpHoldSeconds = 20

    /// What Free Up Space says when it has nothing to offer — its title, and the start of its
    /// explanation, which blames notes, collections and summaries.
    private static let noCandidatesTitle = "No Removable Volumes"
    private static let noCandidatesDetail = "Every downloaded volume has attached"

    /// What a row's status line ends with while its removal is under way. The app ships no
    /// localization, so the default value is what renders.
    private static let removingLabel = "removing…"

    /// A phrase only the side-loaded confirmation carries (#777).
    private static let sideLoadedWarning = "side-loaded"

    /// A phrase only the catalogue confirmation carries.
    private static let redownloadPromise = "can be downloaded again"

    /// How far, in points, a popover's facing edge may sit from its source's facing edge. Covers
    /// the arrow, which XCUI may or may not count in the popover's frame (measured with the fix, it
    /// reached 15 pt into the row); a row here is 67 pt tall.
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
        app.launchEnvironment["FRUS_UI_TEST_DISABLE_ANIMATIONS"] = "1"
        app.launchArguments = UITestLaunch.arguments(startingOn: .settings)
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

    /// Launches the app — holding every storage removal open for `holdSeconds` when given — and
    /// waits out anything a boot pass puts over the screen.
    private func launchApp(holdingRemovalsFor holdSeconds: Int? = nil) {
        if let holdSeconds {
            app.launchEnvironment["FRUS_UI_TEST_HOLD_STORAGE_REMOVAL"] = String(holdSeconds)
        }
        app.launch()
        settleAfterLaunch()
    }

    // MARK: - #1357

    /// Each row's confirmation hangs from the row the reader swiped, not from the list, and says
    /// what removing that row means.
    func testRemoveConfirmationPointsAtTheSwipedRow() throws {
        try skipUnlessPad()
        launchApp()
        try openVolumeList()

        // The catalogue row first: it sorts above the seeded rows, and `requireRow` scrolls down.
        let catalogue = try askToRemove(Self.catalogueVolumeId)
        let catalogueAsk = measurePopover(askedFrom: catalogue, named: Self.catalogueVolumeId)
        requireDialog(saying: Self.redownloadPromise, notSaying: Self.sideLoadedWarning,
                      for: Self.catalogueVolumeId)
        dismissPopover()

        let target = try askToRemove(Self.targetVolumeId)
        let targetAsk = measurePopover(askedFrom: target, named: Self.targetVolumeId)
        requireDialog(saying: Self.sideLoadedWarning, notSaying: Self.redownloadPromise,
                      for: Self.targetVolumeId)

        for (volumeId, ask) in [(Self.catalogueVolumeId, catalogueAsk), (Self.targetVolumeId, targetAsk)] {
            XCTAssertNil(rowAnchorFailure(ask.popover, row: ask.row), """
                "Remove this volume?" asked from \(volumeId) is not anchored to that row: popover \
                \(ask.popover), row \(ask.row) — \(rowAnchorFailure(ask.popover, row: ask.row) ?? ""). \
                Before #1357 it was anchored to the whole list, and landed in one place whichever \
                row asked.
                """)
        }
    }

    /// Free Up Space's confirmation hangs from the button that asks it.
    func testFreeUpSpaceConfirmationPointsAtItsButton() throws {
        try skipUnlessPad()
        launchApp()
        let sheet = try openFreeUpSpaceWithTheCatalogueVolumeSelected()
        let buttonFrame = sheet.ask.frame
        sheet.ask.tap()

        let popover = app.popovers.firstMatch
        XCTAssertTrue(popover.waitForExistence(timeout: 5), """
            "Remove these volumes?" did not open as a popover on iPad. Tree:
            \(app.debugDescription)
            """)
        let popoverFrame = popover.frame
        print("[VolumeRemovalTests] Free Up Space button \(buttonFrame), popover \(popoverFrame)")
        keepScreenshot(named: "Remove these volumes? over Free Up Space")
        XCTAssertNil(buttonAnchorFailure(popoverFrame, button: buttonFrame), """
            "Remove these volumes?" is not anchored to the button that asks it: popover \
            \(popoverFrame), button \(buttonFrame) — \
            \(buttonAnchorFailure(popoverFrame, button: buttonFrame) ?? ""). One anchored to the \
            sheet's content — before #1357 — is centred on the sheet.
            """)
    }

    // MARK: - #1356

    /// Free Up Space goes on listing the volume it is removing until the removal ends, and then
    /// closes on its own. This is the test that presses the Remove of *Remove these volumes?*.
    func testFreeUpSpaceKeepsItsVolumeWhileRemovingIt() throws {
        launchApp(holdingRemovalsFor: Self.freeUpHoldSeconds)
        let sheet = try openFreeUpSpaceWithTheCatalogueVolumeSelected()
        sheet.ask.tap()
        try requireConfirmButton().tap()
        let confirmedAt = Date()

        // The sheet withdraws its Cancel while it removes: the removal has started, and it is held
        // at its first step.
        let cancel = sheet.bar.buttons["Cancel"]
        let removing = XCTWaiter().wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND enabled == false"), object: cancel)],
                                        timeout: 10) == .completed
        XCTAssertTrue(removing, """
            Free Up Space's Cancel is still enabled after its removal was confirmed: the sheet never \
            started removing. Tree:
            \(app.debugDescription)
            """)

        // Read while the removal is held. The claim, when it comes, comes with the first render
        // after the confirmation.
        let claim = app.staticTexts.matching(NSPredicate(
            format: "label == %@ OR label BEGINSWITH %@",
            Self.noCandidatesTitle, Self.noCandidatesDetail)).firstMatch
        let claimed = claim.waitForExistence(timeout: 3)
        let listed = sheet.candidate.exists && sheet.candidate.isSelected
        let readAt = Date().timeIntervalSince(confirmedAt)
        print("[VolumeRemovalTests] Free Up Space, "
              + String(format: "%.1f s after the confirmation: ", readAt)
              + (claimed ? "says \"\(claim.label)\"" : "makes no claim of none")
              + (listed ? ", and still lists the volume selected" : ", and no longer lists the volume"))
        XCTAssertLessThan(readAt, Double(Self.freeUpHoldSeconds) - 2, """
            Reading the sheet took \(Int(readAt)) s, so the \(Self.freeUpHoldSeconds)-s hold may have \
            ended and what was read may be the sheet after the removal. Raise `freeUpHoldSeconds`.
            """)
        XCTAssertFalse(claimed, """
            While it removes \(Self.catalogueVolumeId), Free Up Space says "\(claim.label)". It lists \
            a plan that leaves out the volumes whose removal is under way, which from the \
            confirmation on are its own. Tree:
            \(app.debugDescription)
            """)
        XCTAssertTrue(listed, """
            While it removes \(Self.catalogueVolumeId), Free Up Space no longer lists that volume as \
            selected: the rows it is removing left the sheet when the removal started. Tree:
            \(app.debugDescription)
            """)

        // The removal ends, and the sheet closes itself.
        let closed = sheet.bar.waitForNonExistence(timeout: TimeInterval(Self.freeUpHoldSeconds + 30))
        print("[VolumeRemovalTests] Free Up Space \(closed ? "closed" : "was still open") "
              + String(format: "%.1f s after the confirmation", Date().timeIntervalSince(confirmedAt)))
        XCTAssertTrue(closed, """
            Free Up Space is still open \(Self.freeUpHoldSeconds + 30) s after the removal it held for \
            \(Self.freeUpHoldSeconds) s: the removal never finished, or the sheet did not close. Tree:
            \(app.debugDescription)
            """)
    }

    /// A removed row leaves the list on its own, with nothing touched after the confirmation, and
    /// the list it left is still there.
    func testRemovedRowLeavesTheListWithoutATouch() throws {
        launchApp()
        try openVolumeList()
        let row = try askToRemove(Self.targetVolumeId)
        requireDialog(saying: Self.sideLoadedWarning, notSaying: Self.redownloadPromise,
                      for: Self.targetVolumeId)
        try requireConfirmButton().tap()
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
        requireListStillShowsTheNeighbour()
    }

    /// The row reads *removing…* while its removal runs — in the list it was removed from, and in
    /// the list of a hub the reader leaves and re-enters — and leaves that second list on its own.
    func testRemovalMarkSurvivesLeavingTheHub() throws {
        launchApp(holdingRemovalsFor: Self.removalHoldSeconds)
        try openVolumeList()
        _ = try askToRemove(Self.targetVolumeId)
        try requireConfirmButton().tap()
        let confirmedAt = Date()

        // The removal is held at its first step, so the mark has to be on now.
        let status = statusText(of: Self.targetVolumeId)
        let marked = waitForLabel(of: status, toEndWith: Self.removingLabel, timeout: 10)
        // A row already gone means the removal was never held: the hold is in the shared routing.
        let seen = status.exists ? "\"\(status.label)\"" : "nothing (it has already left the list)"
        XCTAssertTrue(marked, """
            While its removal is held open, \(Self.targetVolumeId)'s row reads \(seen), not \
            "… · \(Self.removingLabel)" — the list does not draw the removal in progress, or the hub \
            does not remove through the shared routing that holds it (#1356).
            """)

        // Back to Settings, and in again: a NEW hub, and a new list.
        goBack(from: "Volumes on This Device")
        goBack(from: "Volumes & Storage")
        try openVolumeList()
        _ = try requireRow(Self.targetVolumeId)
        let reentered = Date().timeIntervalSince(confirmedAt)
        print("[VolumeRemovalTests] re-entered the list "
              + String(format: "%.1f s after the confirmation", reentered)
              + "; the row reads \"\(status.label)\"")
        XCTAssertLessThan(reentered, Double(Self.removalHoldSeconds) - 2, """
            Leaving and re-entering the hub took \(Int(reentered)) s, so the \
            \(Self.removalHoldSeconds)-s hold may have ended and nothing below can be read. Raise \
            `removalHoldSeconds`.
            """)
        XCTAssertTrue(status.label.hasSuffix(Self.removingLabel), """
            A hub re-entered while \(Self.targetVolumeId) is being removed draws its row as \
            "\(status.label)": the removal's mark belonged to the hub the reader left.
            """)

        // The removal finishes; nothing is touched.
        let left = rowQuery(Self.targetVolumeId).waitForNonExistence(
            timeout: TimeInterval(Self.removalHoldSeconds + 30))
        print("[VolumeRemovalTests] the removed row \(left ? "left" : "was still listed") "
              + String(format: "%.1f s after the confirmation", Date().timeIntervalSince(confirmedAt)))
        XCTAssertTrue(left, """
            The re-entered list still shows \(Self.targetVolumeId) after its removal ended: the \
            removal's re-measure went to the hub the reader left, not the one on screen. Tree:
            \(app.debugDescription)
            """)
        requireListStillShowsTheNeighbour()
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
    ///
    /// The skip reads the idiom, not the size class, because a UI test cannot read the app's size
    /// class: an iPad in a compact window (Split View, Slide Over, a small Stage Manager window)
    /// would present an action sheet too, and fail on `app.popovers` rather than skip — reasoned
    /// from SwiftUI's rule, not measured. Run the suite full-screen.
    private func skipUnlessPad() throws {
        #if canImport(UIKit)
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, """
            The confirmation is a popover only in a regular-width size class; on a phone it is an \
            action sheet with no anchor, so there is nothing for this test to measure. Run it on \
            an iPad.
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

    /// The hub, then **Free Up Space…**, with the catalogue volume — its one candidate — selected.
    ///
    /// - Returns: The sheet's navigation bar, the candidate's row, and the sheet's **Remove 1
    ///   volume**, which asks *Remove these volumes?*.
    private func openFreeUpSpaceWithTheCatalogueVolumeSelected() throws
        -> (bar: XCUIElement, candidate: XCUIElement, ask: XCUIElement) {
        try openHub()
        let freeUp = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Free Up Space")).firstMatch
        XCTAssertTrue(scrollUntilHittable(freeUp), "The hub's Free Up Space… button is not reachable")
        freeUp.tap()
        let bar = app.navigationBars["Free Up Space"]
        XCTAssertTrue(bar.waitForExistence(timeout: 10), "The Free Up Space sheet never opened")

        let candidate = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", Self.catalogueTitle)).firstMatch
        XCTAssertTrue(candidate.waitForExistence(timeout: 10), """
            Free Up Space does not offer the seeded catalogue volume \(Self.catalogueVolumeId). Tree:
            \(app.debugDescription)
            """)
        candidate.tap()

        let ask = bar.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Remove ")).firstMatch
        XCTAssertTrue(ask.waitForExistence(timeout: 5), "The sheet's Remove button never appeared")
        XCTAssertTrue(ask.isEnabled, "The sheet's Remove button is still disabled after selecting a volume")
        return (bar, candidate, ask)
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

    /// Leaves the screen titled `title` by its Back button.
    private func goBack(from title: String) {
        let bar = app.navigationBars[title]
        XCTAssertTrue(bar.waitForExistence(timeout: 5), "\(title) is not on screen to leave")
        let back = bar.buttons.matching(
            NSPredicate(format: "identifier == %@ OR label == %@", "BackButton", "Back")).firstMatch
        (back.exists ? back : bar.buttons.element(boundBy: 0)).tap()
        XCTAssertTrue(bar.waitForNonExistence(timeout: 10), "Back did not leave \(title)")
    }

    /// Every list cell for `volumeId`, found by the status line that begins with its id.
    private func rowQuery(_ volumeId: String) -> XCUIElement {
        app.cells.containing(NSPredicate(format: "label BEGINSWITH %@", "\(volumeId) ·")).firstMatch
    }

    /// The status line of `volumeId`'s row: `id · size · …`.
    private func statusText(of volumeId: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "\(volumeId) ·")).firstMatch
    }

    /// The list cell for `volumeId`, scrolled to.
    ///
    /// It scrolls BEFORE requiring the row: the list builds cells only near the screen, and on a
    /// simulator carrying other volumes a row further down does not exist until it is scrolled to.
    private func requireRow(_ volumeId: String) throws -> XCUIElement {
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 10),
                      "Volumes on This Device lists nothing")
        let row = rowQuery(volumeId)
        XCTAssertTrue(scrollUntilHittable(row, attempts: 12), """
            No reachable row for \(volumeId) in Volumes on This Device. Tree:
            \(app.debugDescription)
            """)
        return row
    }

    /// Swipes `volumeId`'s row and taps its Remove, which asks *Remove this volume?*.
    private func askToRemove(_ volumeId: String) throws -> XCUIElement {
        let row = try requireRow(volumeId)
        row.swipeLeft()
        let remove = app.buttons["Remove"].firstMatch
        XCTAssertTrue(remove.waitForExistence(timeout: 5), "\(volumeId)'s Remove swipe action never appeared")
        remove.tap()
        return row
    }

    /// The popover *Remove this volume?* opened in, and the frame of the row that asked, read
    /// together while the popover is up.
    private func measurePopover(askedFrom row: XCUIElement, named volumeId: String)
        -> (popover: CGRect, row: CGRect) {
        let popover = app.popovers.firstMatch
        XCTAssertTrue(popover.waitForExistence(timeout: 5), """
            "Remove this volume?" did not open as a popover on iPad. Tree:
            \(app.debugDescription)
            """)
        let frames = (popover: popover.frame, row: row.frame)
        print("[VolumeRemovalTests] row \(volumeId) \(frames.row), popover \(frames.popover)")
        keepScreenshot(named: "Remove this volume? over \(volumeId)")
        return frames
    }

    /// Requires the open confirmation to carry `expected` and not `unexpected` (#777).
    private func requireDialog(saying expected: String, notSaying unexpected: String, for volumeId: String) {
        let says = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", expected)).firstMatch
        XCTAssertTrue(says.waitForExistence(timeout: 5), """
            The confirmation for \(volumeId) does not say "\(expected)" (#777). Tree:
            \(app.debugDescription)
            """)
        XCTAssertFalse(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", unexpected)).firstMatch.exists, """
            The confirmation for \(volumeId) says "\(unexpected)", which is another kind of \
            volume's message (#777).
            """)
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
            The confirmation offered no Remove button in a popover, sheet or alert. Tree:
            \(app.debugDescription)
            """)
    }

    /// Requires *Volumes on This Device* to be still on screen with ``neighbourVolumeId`` in it:
    /// a list that popped back to the hub, or emptied, loses the removed row as well.
    private func requireListStillShowsTheNeighbour() {
        XCTAssertTrue(app.navigationBars["Volumes on This Device"].exists, """
            Volumes on This Device is no longer on screen: the removal took the whole list away, \
            not the row. Tree:
            \(app.debugDescription)
            """)
        XCTAssertTrue(rowQuery(Self.neighbourVolumeId).waitForExistence(timeout: 5), """
            \(Self.neighbourVolumeId), the removed row's neighbour, is no longer listed: the \
            removal emptied the list rather than taking out one row. Tree:
            \(app.debugDescription)
            """)
    }

    /// Waits until `element`'s label ends with `suffix`.
    private func waitForLabel(of element: XCUIElement, toEndWith suffix: String,
                              timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND label ENDSWITH %@", suffix)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
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

    /// Why `popover` does not hang from the list row framed by `row`, or `nil` when it does.
    ///
    /// A popover from a row is centred on it, sits on ONE side of it, and has its facing edge — the
    /// one its arrow leaves from — at the row's own facing edge, within ``adjacency``.
    /// - *Centred on the row*: horizontal alignment. A list row spans the list, so a popover
    ///   centred on the list passes this too; it is necessary, not sufficient.
    /// - *Clear of the row's middle*: refuses a popover drawn over the row — where one anchored to
    ///   the next row down opens, upward across this one.
    /// - *Facing edge at the row's facing edge*: refuses one anchored a row or more away, and one
    ///   anchored to a container, which lands where the container puts it.
    ///
    /// The last two read the row's own frame, and asking from two rows is what makes them binding:
    /// a popover anchored to anything but the row lands in one place whichever row asked, and a
    /// place against two rows four apart would have to fill the space between them exactly.
    ///
    /// Measured on iPad Pro 11-inch (M5) at iOS 26.4. With the fix, the catalogue row at y 235–302
    /// drew its popover BELOW it, at 287–552, and the fourth seeded row at 503–570 drew its popover
    /// ABOVE it, at 193–518 — each facing edge 15 pt inside its row, and each centred on x 417.
    /// Anchored to the list, both drew at the top of the list (y 62–327 and 62–387; at iOS 27.0,
    /// 32–297 and 32–357), over the catalogue row's middle and more than 100 pt short of the
    /// fourth row.
    private func rowAnchorFailure(_ popover: CGRect, row: CGRect) -> String? {
        if abs(popover.midX - row.midX) > Self.adjacency {
            return "its centre is \(Int(popover.midX - row.midX)) pt across from the row's"
        }
        let above = popover.midY < row.midY
        let clearOfMiddle = above ? popover.maxY <= row.midY : popover.minY >= row.midY
        if !clearOfMiddle { return "it covers the middle of the row" }
        let gap = above ? row.minY - popover.maxY : popover.minY - row.maxY
        if abs(gap) > Self.adjacency {
            return "its \(above ? "bottom" : "top") edge is \(Int(abs(gap))) pt from the row's "
                + "\(above ? "top" : "bottom") edge"
        }
        return nil
    }

    /// Why `popover` is not presented from the toolbar `button`, or `nil` when it is: its frame
    /// reaches the button, within ``adjacency``, and spans the button's horizontal centre.
    ///
    /// A popover from a toolbar button grows out of the button and COVERS it — measured with the
    /// fix on iPad Pro 13-inch, *Remove these volumes?* drew at x 567–855 × y 274–506 over its
    /// button at 630–792 × 372–408 — so the row rule, which refuses a popover over its source, does
    /// not apply here, and neither does "directly above or below", the rule #1357 proposed. The
    /// centre condition is what refuses a popover anchored to the sheet: against unfixed `v2` it
    /// drew centred on the sheet at x 372–660 and missed its button's centre at x 711, while its
    /// frame, widened by ``adjacency``, still reached the button.
    private func buttonAnchorFailure(_ popover: CGRect, button: CGRect) -> String? {
        if !popover.insetBy(dx: -Self.adjacency, dy: -Self.adjacency).intersects(button) {
            return "it does not reach the button"
        }
        if !(popover.minX <= button.midX && button.midX <= popover.maxX) {
            return "it does not span the button's centre"
        }
        return nil
    }

    /// Keeps a screenshot in the result bundle whether the test passes or fails, so the anchor a
    /// frame check accepted can also be seen.
    private func keepScreenshot(named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Closes the open popover by tapping outside it.
    ///
    /// The tap lands near the dismiss region's lower-left corner, not its centre: the region
    /// covers the screen, and a popover can sit over the centre — a tap there would land on the
    /// popover, and possibly on its Remove.
    private func dismissPopover() {
        let regions = app.otherElements.matching(identifier: "PopoverDismissRegion")
        let count = regions.count
        XCTAssertGreaterThan(count, 0, "No popover to dismiss")
        regions.element(boundBy: count - 1).coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.97)).tap()
        XCTAssertTrue(app.popovers.firstMatch.waitForNonExistence(timeout: 5), "The popover did not close")
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
            regions.element(boundBy: count - 1)
                .coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.97)).tap()
            Thread.sleep(forTimeInterval: 0.5)
        }
        let freeUpCancel = app.navigationBars["Free Up Space"].buttons["Cancel"]
        if freeUpCancel.exists { freeUpCancel.tap() }
    }
}
