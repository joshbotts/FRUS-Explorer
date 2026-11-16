// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import XCTest
import notify

/// The volume page's "Editors’ Annotations" section on a real page (the editors' annotations
/// design, lane B, `Planning/Editors-Annotations-Design-2026-11-06.md` §5):
/// - the seeded volume's page shows it, each row read by VoiceOver as one sentence with the bundled
///   file's counts, and no "Not in this volume" list, since the volume carries every standard layer;
/// - at the largest accessibility text size its rows wrap inside the window rather than run off it.
///
/// A row is one accessibility element whose children are hidden, so this suite cannot read whether
/// a row's visible text is truncated; the view sets no line limit, and the frame check is what a
/// run can see.
///
/// Devices: an iPhone 17 and an iPad Pro 13-inch (M5), both under iOS 27.0
/// (`Planning/UI-Test-Destinations-Runbook.md`, `VolumeAnnotationsSectionTests`). Neither test skips.
///
/// Version history:
///   1.0 — 2026-11-06: the editors' annotations design, lane B
//
// Note: the XCUI APIs are main-actor isolated, so the class is `@MainActor` and overrides the ASYNC
// `setUp`/`tearDown` (see the note at the head of `UIObstructionTests`).
@MainActor
final class VolumeAnnotationsSectionTests: XCTestCase {

    /// The volume `BrowseNestedSectionTests` seeds. The bundled file holds it, and it carries every
    /// standard layer: 120 documents, people tagged in all 120, 58 people listed, classification in 113.
    private static let seededVolumeId = "frus1961-63v06"

    /// Its subseries row's label, matched by name: the launch shows downloaded volumes only, and the
    /// simulator may hold other volumes from other runs.
    private static let seededSubseriesLabel = "Subseries 1961-63"

    /// What VoiceOver reads for the seeded volume's People row.
    private static let peopleSpoken = "People tagged: 120 of 120 documents; 58 people listed."

    var app: XCUIApplication!

    /// Resolves tab destinations across every representation. Shared with every other suite.
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_VOLUME"] = Self.seededVolumeId
    }

    override func tearDown() async throws {
        app = nil
    }

    /// Launches on Browse, collapsed to the seeded volume, at `contentSizeCategory` if one is given.
    private func launch(contentSizeCategory: String? = nil) {
        app.launchArguments = UITestLaunch.arguments(contentSizeCategory: contentSizeCategory)
            + ["-frus.filterDownloadedOnly", "YES"]
        app.launch()
    }

    /// Browse → the Subseries tile → 1961–63 → the seeded volume's page, failing with a distinct
    /// message at each step.
    ///
    /// At AX5 on an iPhone 17 under iOS 27.0 (the runs of 2026-11-06), the tab shell's "Local Only"
    /// banner covers the lower 323 pt of the screen, and the Subseries tile sat under it in one run;
    /// in another the tile was clear of it and the first tap was lost. So each try brings the tile
    /// above the banner and taps it, then waits for what the walk needs, the subseries row, scrolling
    /// the list in case the row is below the fold: three tries at most. Leaving the root is not the
    /// test, since an iPad keeps the root on screen beside the list.
    private func openSeededVolume() {
        _ = navigator.select(.browse).tapped
        let tile = app.buttons["browse.root.subseriesTile"].firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 15), "The Browse root's Subseries tile did not appear.")

        let subseries = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", Self.seededSubseriesLabel)).firstMatch
        for _ in 0..<3 {
            scrollUntilHittable(tile, attempts: 4)
            if tile.exists && tile.isHittable { tile.tap() }
            if subseries.waitForExistence(timeout: 5) { break }
            scrollUntilHittable(subseries, attempts: 4)
            if subseries.exists { break }
        }
        XCTAssertTrue(subseries.exists, """
            No 1961–63 subseries row with filterDownloadedOnly=YES after three taps on the Subseries \
            tile: the volume was probably not seeded (look for a [UITestVolumeSeeder] line in the app \
            log), or the tile's taps never reached it.
            """)
        scrollUntilHittable(subseries, attempts: 6)
        subseries.tap()
        Thread.sleep(forTimeInterval: 0.8)

        let volume = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Kennedy-Khrushchev'")).firstMatch
        if !volume.waitForExistence(timeout: 10) { scrollUntilHittable(volume, attempts: 6) }
        XCTAssertTrue(volume.exists, "The seeded volume's row did not appear in the subseries list.")
        scrollUntilHittable(volume, attempts: 6)
        volume.tap()
        Thread.sleep(forTimeInterval: 0.8)
    }

    /// The element with `identifier`, of any type.
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// Keeps a screenshot of the page in the result bundle, for a reader to check the rows by eye: a
    /// run reads their labels and frames, not whether their symbols line up or their text wraps well.
    private func keepScreenshot(named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Drags the list up until `row`'s foot is just above the tab shell's banner, which a simulator
    /// with no iCloud account always shows, so that a screenshot shows the end of the row's wrapped
    /// text, and the whole row where it fits. At AX5 on an iPhone 17 the strip between the pinned
    /// breadcrumb and the banner is about 190 pt, shorter than the row (2026-11-06). The drag holds
    /// before it lifts, so that the list does not coast on (`CollectionEditorTitleTests.reveal`).
    private func liftAboveTheBanner(_ row: XCUIElement) {
        let banner = app.descendants(matching: .any).matching(identifier: "tabShell.syncBanner").firstMatch
        guard banner.exists else { return }
        let lift = row.frame.maxY - banner.frame.minY + 12
        guard lift > 0 else { return }
        // Frames are in the screen's coordinates, whose origin is the app element's.
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: row.frame.midX, dy: banner.frame.minY - 10))
        let end = origin.withOffset(CGVector(dx: row.frame.midX, dy: banner.frame.minY - 10 - lift))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
    }

    /// Swipes up until `element` is present and hittable. A SwiftUI `List` is lazy, so a row below
    /// the fold is absent from the accessibility tree, not merely invisible.
    private func scrollUntilHittable(_ element: XCUIElement, attempts: Int) {
        for _ in 0..<attempts {
            if element.exists && element.isHittable { return }
            app.swipeUp(velocity: .slow)
        }
    }

    func testTheSectionReadsTheVolumesAnnotations() throws {
        launch()
        openSeededVolume()
        let header = element("volume.annotations.header")
        XCTAssertTrue(header.waitForExistence(timeout: 15),
                      "The seeded volume's page has no Editors’ Annotations section.")

        let people = element("volume.annotations.people")
        scrollUntilHittable(people, attempts: 6)
        XCTAssertTrue(people.exists, "The section has no People row.")
        XCTAssertEqual(people.label, Self.peopleSpoken,
                       "VoiceOver must read the People row as one sentence with the bundled counts.")
        keepScreenshot(named: "Editors’ Annotations")

        for group in ["named", "provenance", "connects"] {
            let heading = element("volume.annotations.group.\(group)")
            scrollUntilHittable(heading, attempts: 8)
            XCTAssertTrue(heading.exists, "The section has no '\(group)' group heading.")
        }

        let classification = element("volume.annotations.classification")
        scrollUntilHittable(classification, attempts: 8)
        XCTAssertEqual(classification.label, "Classification markings: 113 of 120 documents.")

        XCTAssertFalse(element("volume.annotations.absent").exists, """
            The seeded volume carries every standard layer, so its section must not offer a \
            "Not in this volume" list.
            """)
    }

    func testRowsWrapInsideTheWindowAtTheLargestTextSize() throws {
        launch(contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL")
        openSeededVolume()
        let people = element("volume.annotations.people")
        scrollUntilHittable(people, attempts: 12)
        XCTAssertTrue(people.exists, "At AX5 the section's People row never came into view.")
        XCTAssertEqual(people.label, Self.peopleSpoken)

        let window = app.windows.firstMatch.frame
        let row = people.frame
        XCTAssertGreaterThanOrEqual(row.minX, window.minX - 0.5, "At AX5 the People row starts left of the window.")
        XCTAssertLessThanOrEqual(row.maxX, window.maxX + 0.5, """
            At AX5 the People row runs past the window's right edge (row \(row), window \(window)): its \
            text must wrap, not overflow.
            """)
        liftAboveTheBanner(people)
        keepScreenshot(named: "Editors’ Annotations at AX5")
    }
}

// MARK: - VolumeDownloadFailureTests (L20, #1920, HCD-3)

/// A volume's download that fails with its retries spent shows on the volume's page, in Keeping
/// Current's words, with **Retry** in Download Volume's place (L20, #1920, HCD-3).
///
/// The download seam's `fail` makes every attempt fail as with no connection, after a second and a
/// half, so the page shows "Downloading…" first (`UITestBrowseSeams.downloadSeam`); nothing reaches
/// the network. The volume is *Soviet Union* (1961–1963, Volume V), which no suite downloads. Before
/// L20 the page offered Download Volume again with no word, so the test fails at the failure's line
/// on that code. Retry is shown to queue the volume again by the "Downloading…" it brings back.
///
/// Devices: an iPhone 17 and an iPad Pro 13-inch (M5), both under iOS 27.0. It never skips. The Mac's
/// Corpus Browser page, which before L20 stayed on "Downloading…" for good, is walked in the check copy.
///
/// Version history:
///   1.0 — L20 (#1920, HCD-3): initial implementation
@MainActor
final class VolumeDownloadFailureTests: XCTestCase {

    var app: XCUIApplication!

    /// Resolves tab destinations across every representation.
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_DOWNLOADS"] = "fail"
        app.launchEnvironment["FRUS_UI_TEST_DISABLE_ANIMATIONS"] = "1"
        app.launchArguments = UITestLaunch.arguments() + ["-frus.filterDownloadedOnly", "NO"]
    }

    override func tearDown() async throws {
        UITestPresentation.dismissAnyPresentation(in: app)
        app = nil
    }

    func testAFailedDownloadIsShownWithRetry() throws {
        app.launch()
        UndownloadedVolumeWalk.open(in: app, navigator: navigator)

        let download = app.buttons["Download Volume"].firstMatch
        XCTAssertTrue(download.waitForExistence(timeout: 15), """
            The volume's page offers no Download Volume: is \(UndownloadedVolumeWalk.volumeId) on this simulator?
            """)
        download.tap()
        XCTAssertTrue(UndownloadedVolumeWalk.downloading(in: app).waitForExistence(timeout: 10),
                      "Download Volume did not start the download")

        // The identifier names two elements, the line and its warning glyph ("Warning"), so the line
        // is found by identifier AND label (the iPad's first run read the glyph and failed).
        let named = app.descendants(matching: .any).matching(identifier: "volume.download.failure")
        let failure = named.matching(NSPredicate(format: "label CONTAINS %@",
                                                 UndownloadedVolumeWalk.failureLine)).firstMatch
        XCTAssertTrue(failure.waitForExistence(timeout: 45), """
            The page shows no failure after the download failed with its retries spent: before L20 it \
            offered Download Volume again with no word. Elements named volume.download.failure: \
            \(named.allElementsBoundByIndex.map(\.label))
            """)
        let retry = app.buttons["volume.download.retry"].firstMatch
        XCTAssertTrue(retry.exists, "the failure is shown with no Retry")
        // Kept for a reader of the result bundle: the failure where Download Volume was.
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "download-failure-notice"
        shot.lifetime = .keepAlways
        add(shot)
        XCTAssertFalse(app.buttons["Download Volume"].firstMatch.exists,
                       "Download Volume is offered beside Retry")

        retry.tap()
        XCTAssertTrue(UndownloadedVolumeWalk.downloading(in: app).waitForExistence(timeout: 10),
                      "Retry did not queue the volume again")
        XCTAssertTrue(failure.waitForExistence(timeout: 45), "the second failure was not shown")
    }
}

// MARK: - VolumeDownloadFailureAnnouncementTests (L20, #1920, HCD-3)

/// The failure is said to VoiceOver as it arrives on the volume's page: "The download failed: no
/// connection." (L20, #1920, HCD-3).
///
/// The test walks to the page with VoiceOver off, turns it on, and has the app start the download by a
/// Darwin signal (`UITestBrowseSeams.downloadsOnSignal`), since with VoiceOver on a tap only moves its
/// cursor. It then reads VoiceOver's speech four times a second for twenty seconds, which the download's
/// three failing attempts take about five of. Before L20 nothing was said.
///
/// **Run it alone, on a simulator shut down before it**, on iPhone 17 and iPad Pro 13-inch (M5), both
/// `OS=27.0`, with 600 s a test: under Xcode 27.2, once the VoiceOver service's speech has been read,
/// `disable()` leaves VoiceOver on (`SearchResultVoiceOverTests`' entry in the runbook). It needs iOS 27's
/// VoiceOver service and skips below it.
///
/// Version history:
///   1.0 — L20 (#1920, HCD-3): initial implementation
@MainActor
final class VolumeDownloadFailureAnnouncementTests: XCTestCase {

    /// `UITestBrowseSeams.Signal.startDownload`'s name.
    private static let startDownloadSignal = "bottsywattsy.FRUS-Explorer.uitest.start-download"

    var app: XCUIApplication!

    /// Resolves tab destinations across every representation.
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    override func setUp() async throws {
        continueAfterFailure = false
        // A run that ended inside a test could have left VoiceOver on.
        turnVoiceOverOff()
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_DOWNLOADS"] = "fail"
        app.launchEnvironment["FRUS_UI_TEST_DOWNLOAD_ON_SIGNAL"] = UndownloadedVolumeWalk.volumeId
        app.launchEnvironment["FRUS_UI_TEST_DISABLE_ANIMATIONS"] = "1"
        app.launchArguments = UITestLaunch.arguments() + ["-frus.filterDownloadedOnly", "NO"]
    }

    override func tearDown() async throws {
        turnVoiceOverOff()
        UITestPresentation.dismissAnyPresentation(in: app)
        app?.terminate()
        app = nil
    }

    func testAFailedDownloadIsSaidToVoiceOver() throws {
        guard #available(iOS 27.0, *) else { throw XCTSkip("Listens through iOS 27's VoiceOver service") }
        app.launch()
        UndownloadedVolumeWalk.open(in: app, navigator: navigator)
        XCTAssertTrue(app.buttons["Download Volume"].firstMatch.waitForExistence(timeout: 15), """
            The volume's page offers no Download Volume: is \(UndownloadedVolumeWalk.volumeId) on this simulator?
            """)

        let voiceOver = XCUIDevice.shared.voiceOverService
        try voiceOver.enable()
        RunLoop.current.run(until: Date().addingTimeInterval(2))
        XCTAssertEqual(notify_post(Self.startDownloadSignal), UInt32(NOTIFY_STATUS_OK),
                       "The system refused to post \(Self.startDownloadSignal), so no download will start")
        var heard: [String] = []
        for _ in 1...80 where !heard.contains(where: { $0.contains(UndownloadedVolumeWalk.failureLine) }) {
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
            let spoken = try voiceOver.currentSpeech().utterance
            if heard.last != spoken { heard.append(spoken) }
        }
        try voiceOver.disable()
        XCTAssertTrue(heard.contains { $0.contains(UndownloadedVolumeWalk.failureLine) }, """
            VoiceOver did not say "\(UndownloadedVolumeWalk.failureLine)" within twenty seconds of the \
            download's start. It said: \(heard)
            """)
    }

    /// Turns VoiceOver off if a test left it on.
    private func turnVoiceOverOff() {
        guard #available(iOS 27.0, *) else { return }
        let voiceOver = XCUIDevice.shared.voiceOverService
        if voiceOver.isEnabled { try? voiceOver.disable() }
    }
}

// MARK: - The walk to a volume that is not on the device

/// Browse ▸ the Subseries tile ▸ 1961–63 ▸ *Soviet Union*, the page `VolumeDownloadFailureTests` and
/// `VolumeDownloadFailureAnnouncementTests` stand on, with every volume listed
/// (`-frus.filterDownloadedOnly NO`).
@MainActor
enum UndownloadedVolumeWalk {

    /// *Foreign Relations of the United States, 1961–1963, Volume V, Soviet Union*: no suite downloads it,
    /// and it is the subseries' one title that names the Soviet Union.
    static let volumeId = "frus1961-63v05"

    /// What the page says when its download failed as with no connection: Keeping Current's words.
    static let failureLine = "The download failed: no connection."

    /// The page's "Downloading…" line.
    static func downloading(in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Downloading")).firstMatch
    }

    /// Opens the volume's page, failing with a distinct message at each step.
    ///
    /// - Parameters:
    ///   - app: The running app.
    ///   - navigator: The suite's tab navigator.
    static func open(in app: XCUIApplication, navigator: TabBarNavigator) {
        _ = navigator.select(.browse).tapped
        let tile = app.buttons["browse.root.subseriesTile"].firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 20), "The Browse root's Subseries tile did not appear.")
        let subseries = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Subseries 1961-63")).firstMatch
        for _ in 0..<3 {
            scrollUntilHittable(tile, in: app, attempts: 4)
            if tile.exists && tile.isHittable { tile.tap() }
            if subseries.waitForExistence(timeout: 5) { break }
        }
        scrollUntilHittable(subseries, in: app, attempts: 12)
        XCTAssertTrue(subseries.exists, "No 1961–63 subseries row after three taps on the Subseries tile.")
        subseries.tap()
        Thread.sleep(forTimeInterval: 0.8)

        let volume = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Soviet Union'")).firstMatch
        if !volume.waitForExistence(timeout: 10) { scrollUntilHittable(volume, in: app, attempts: 8) }
        XCTAssertTrue(volume.exists, "The Soviet Union volume's row did not appear in the subseries list.")
        scrollUntilHittable(volume, in: app, attempts: 8)
        volume.tap()
        Thread.sleep(forTimeInterval: 0.8)

        // On an iPhone the page's details, tags and subjects come first, and its Download Required
        // section is below the fold, out of a lazy list's tree until it is scrolled to (the suite's
        // first run, iPhone 17, iOS 27.0).
        let download = app.buttons["Download Volume"].firstMatch
        if !download.waitForExistence(timeout: 5) { scrollUntilHittable(download, in: app, attempts: 10) }
    }

    /// Swipes up until `element` is present and hittable: a SwiftUI `List` is lazy.
    private static func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication, attempts: Int) {
        for _ in 0..<attempts {
            if element.exists && element.isHittable { return }
            app.swipeUp(velocity: .slow)
        }
    }
}
