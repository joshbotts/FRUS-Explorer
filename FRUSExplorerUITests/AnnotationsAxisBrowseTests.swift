// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import XCTest

/// The Editors’ Annotations axis on a real Browse (the editors' annotations design, lane C,
/// `Planning/Editors-Annotations-Design-2026-11-06.md` §5.4 and §6):
/// - the root's door opens the axis, which lists each layer with how many volumes carry it, read by
///   VoiceOver as one sentence with the bundled file's counts; a layer opens its page, and the page's
///   drill opens the R-1 volume list with its caption;
/// - a row of a volume page's section opens its layer's page, whose drill lists that volume first,
///   with the note that says the reader came from it.
///
/// The counts are the shipped file's, which `AnnotationsAxisTests.theShippedFile` pins as well. Each
/// test keeps a screenshot of the list it reaches.
///
/// Devices: an iPhone 17 and an iPad Pro 13-inch (M5), both under iOS 27.0
/// (`Planning/UI-Test-Destinations-Runbook.md`, `AnnotationsAxisBrowseTests`). Neither test skips.
///
/// Version history:
///   1.0 — 2026-11-06: the editors' annotations design, lane C
//
// Note: the XCUI APIs are main-actor isolated, so the class is `@MainActor` and overrides the ASYNC
// `setUp`/`tearDown` (see the note at the head of `UIObstructionTests`).
@MainActor
final class AnnotationsAxisBrowseTests: XCTestCase {

    /// The volume `BrowseNestedSectionTests` and `VolumeAnnotationsSectionTests` seed, which tags its
    /// people (120 of 120 documents).
    private static let seededVolumeId = "frus1961-63v06"

    /// Its subseries row's label, matched by name: the launch shows downloaded volumes only.
    private static let seededSubseriesLabel = "Subseries 1961-63"

    /// What VoiceOver reads for the axis's People tagged row, from the shipped file.
    private static let peopleRowSpoken =
        "People tagged: 288 of 553 volumes. Standard in the volumes covering 1955 on."

    var app: XCUIApplication!

    /// Resolves tab destinations across every representation. Shared with every other suite.
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_VOLUME"] = Self.seededVolumeId
        app.launchArguments = UITestLaunch.arguments(contentSizeCategory: nil)
            + ["-frus.filterDownloadedOnly", "YES"]
    }

    override func tearDown() async throws {
        app = nil
    }

    /// The element with `identifier`, of any type.
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// Swipes up until `element` is present and hittable. A SwiftUI `List` is lazy, so a row below
    /// the fold is absent from the accessibility tree, not merely invisible.
    private func scrollUntilHittable(_ element: XCUIElement, attempts: Int) {
        for _ in 0..<attempts {
            if element.exists && element.isHittable { return }
            app.swipeUp(velocity: .slow)
        }
    }

    /// Keeps a screenshot in the result bundle, for a reader to check the list by eye.
    private func keepScreenshot(named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Browse → the Subseries tile → 1961–63 → the seeded volume's page, as
    /// `VolumeAnnotationsSectionTests.openSeededVolume()` walks it (its doc has why each try waits
    /// for the subseries row).
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
        XCTAssertTrue(subseries.exists, "No 1961–63 subseries row after three taps on the Subseries tile.")
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

    func testTheAxisOpensALayersPageAndItsVolumes() throws {
        app.launch()
        _ = navigator.select(.browse).tapped
        let door = element("browse.root.annotationsTile")
        XCTAssertTrue(door.waitForExistence(timeout: 15), "The Browse root has no Editors’ Annotations door.")
        scrollUntilHittable(door, attempts: 6)
        door.tap()

        let people = element("annotations.layer.people")
        XCTAssertTrue(people.waitForExistence(timeout: 10), "The axis lists no People tagged row.")
        XCTAssertEqual(people.label, Self.peopleRowSpoken,
                       "VoiceOver must read the axis's row as one sentence with the shipped file's counts.")
        people.tap()

        let reach = element("annotations.category.reach")
        XCTAssertTrue(reach.waitForExistence(timeout: 10), "People tagged's page did not open.")
        XCTAssertTrue(reach.label.hasPrefix("288 of 553 volumes"), "The page's reach reads \(reach.label)")

        let without = element("annotations.drill.without")
        scrollUntilHittable(without, attempts: 8)
        XCTAssertEqual(without.label, "Volumes without it: 265 volumes")
        without.tap()

        let caption = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "265 of 553 volumes. A volume counts when")).firstMatch
        XCTAssertTrue(caption.waitForExistence(timeout: 10),
                      "The drill's list does not say how many volumes it holds and by what rule.")
        keepScreenshot(named: "Without: People tagged")
    }

    func testAVolumeRowOpensItsLayerWithTheVolumeFirst() throws {
        app.launch()
        openSeededVolume()
        let people = element("volume.annotations.people")
        scrollUntilHittable(people, attempts: 8)
        XCTAssertTrue(people.exists && people.isHittable, "The volume's page has no People row to open.")
        people.tap()

        let reach = element("annotations.category.reach")
        XCTAssertTrue(reach.waitForExistence(timeout: 10), "The People row did not open People tagged's page.")
        let with = element("annotations.drill.with")
        scrollUntilHittable(with, attempts: 8)
        XCTAssertEqual(with.label, "Volumes with it: 288 volumes")
        with.tap()

        let marked = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "You came here from this volume.")).firstMatch
        XCTAssertTrue(marked.waitForExistence(timeout: 10),
                      "The drill does not mark the volume its page was opened from.")
        XCTAssertTrue(marked.label.contains("Kennedy-Khrushchev"),
                      "The marked row is not the seeded volume's: \(marked.label)")
        keepScreenshot(named: "With: People tagged, opened from Kennedy-Khrushchev")
    }
}
