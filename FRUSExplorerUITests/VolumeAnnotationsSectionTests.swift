// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import XCTest

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
