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

import Vision
import XCTest

// MARK: - YearRangeFieldWidthTests

/// The year-range popover's two fields must SHOW their whole year, and stay inside the popover,
/// from the smallest text size to the largest accessibility size.
///
/// ## Why the oracle is text recognition
/// The defect is visual and invisible to every other query. A truncated field still reports its
/// full value ("1861") to accessibility, and its frame does not say how much of that frame the
/// `.roundedBorder` style keeps for padding. Measured on iPhone 17 (iOS 26.3 and 27.0) the fields
/// were ~44 pt wide and drew "18…" / "19…"; a check like "width ≥ the digits' width plus a
/// plausible inset" PASSES that state, because 44 pt looks like room for ~30 pt of digits until
/// the style's padding is counted. So this test crops each field out of a screenshot and asks
/// Vision what it READS there, which is what the reader sees. A truncated field reads as "18…"
/// (or "18"), never as "1861".
///
/// Vision alone is not enough at the accessibility sizes: on the unfixed control at AX-XL every
/// digit read correctly while the row overflowed the popover and cut off the start field's
/// leading edge. So each size also checks that both fields and both steppers lie inside the
/// popover and the window by a real margin, and that the pair is stacked on iPhone and one row on
/// a full-screen iPad.
///
/// ## Launched with UIKit view animations OFF
/// This suite measures a popover at rest, so it launches with `FRUS_UI_TEST_DISABLE_ANIMATIONS`.
/// It was the best reproducer of the iOS 27 idle stall (`FRUSExplorerApp.configureUITestAnimations`
/// has the mechanism): XCTest's animation counter was left above zero — by the Analysis Tools
/// menu on iPhone, by a keyboard coming up or going down on either — and every later action in
/// the case waited 60 s, often past its 300 s allowance. Measured 2026-09-19 on iOS 27 simulators;
/// the CLAUDE.md note on `-test-timeouts-enabled` has the rates with animations on and off.
///
/// Version history:
///   1.0 — 2026-09-19: initial implementation, with the width fix in `AnalyticsYearRangeBar`
///   1.1 — 2026-09-19: launched with view animations off, which removes the iOS 27 idle stall
@MainActor
final class YearRangeFieldWidthTests: XCTestCase {

    var app: XCUIApplication!

    /// Read through a closure: each test mints a fresh `XCUIApplication`.
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    override func tearDown() async throws {
        // Close the year popover FIRST. `dismissAnyPresentation` taps a navigation-bar Done, and while
        // the popover is up a tap outside it only closes the popover — leaving the Corpus Analytics
        // sheet (on iPad, a window scene) open for the next launch to restore (#1279).
        if let app, app.state == .runningForeground {
            let popoverDone = app.buttons["yearRangeDone"].firstMatch
            if popoverDone.exists {
                popoverDone.tap()
                _ = app.popovers.firstMatch.waitForNonExistence(timeout: 3)
            }
        }
        UITestPresentation.dismissAnyPresentation(in: app)
        app?.terminate()
        app = nil
    }

    // MARK: - Tests

    /// The smallest text size: the worst case for 1.1's `@ScaledMetric` width, which scaled the
    /// field with the text while the style's inset stayed constant.
    func testYearFieldsFitAtExtraSmallSize() throws {
        try assertYearFieldsFit(contentSizeCategory: "UICTContentSizeCategoryXS")
    }

    /// The default text size — where the defect shipped ("18…" / "19…"). Pinned to `L` rather than
    /// left to the simulator, whose own setting is whatever the last person left it at.
    func testYearFieldsFitAtDefaultSize() throws {
        try assertYearFieldsFit(contentSizeCategory: "UICTContentSizeCategoryL")
    }

    /// The largest non-accessibility size — where the first version of this fix left the iPhone row
    /// sitting on the popover's edge, and a 393-pt iPhone's row outside it.
    func testYearFieldsFitAtExtraExtraExtraLargeSize() throws {
        try assertYearFieldsFit(contentSizeCategory: "UICTContentSizeCategoryXXXL")
    }

    /// The first accessibility size.
    func testYearFieldsFitAtAccessibilityMediumSize() throws {
        try assertYearFieldsFit(contentSizeCategory: "UICTContentSizeCategoryAccessibilityM")
    }

    /// Accessibility-XL — where the unfixed row outgrew an iPhone popover and cut off the start
    /// field's leading edge while every digit still read, so Vision alone could not see it.
    func testYearFieldsFitAtAccessibilityExtraLargeSize() throws {
        try assertYearFieldsFit(contentSizeCategory: "UICTContentSizeCategoryAccessibilityXL")
    }

    /// The largest accessibility size.
    func testYearFieldsFitAtAccessibilityExtraExtraExtraLargeSize() throws {
        try assertYearFieldsFit(contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL")
    }

    // MARK: - Helpers

    /// How far inside the popover (and the window) every field and stepper button must sit. The
    /// popover pads its content by 16 pt; the first version of this check allowed −0.5 pt and passed
    /// a row that had eaten all of it and sat ON the popover's edge.
    private static let minimumInset: CGFloat = 8

    /// Opens the popover at `contentSizeCategory` and checks: for both fields, the whole year reads
    /// at rest and the field and its stepper sit well inside the popover and the window; the pair is
    /// stacked on iPhone and one row on iPad; and the Start field still shows its whole year while
    /// being edited with the caret at its end.
    private func assertYearFieldsFit(contentSizeCategory: String) throws {
        let size = contentSizeCategory.replacingOccurrences(of: "UICTContentSizeCategory", with: "")
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        // A screen at rest needs no animation, and with them on, iOS 27 can leave XCTest's idle
        // counter above zero for the rest of the launch (see the type's doc).
        app.launchEnvironment["FRUS_UI_TEST_DISABLE_ANIMATIONS"] = "1"
        app.launchArguments = UITestLaunch.arguments(contentSizeCategory: contentSizeCategory)
        app.launch()

        try AnalysisToolsMenu.open("Corpus Analytics", in: app, through: navigator)

        // The chip rides the chart chrome, so a term has to be committed first.
        let term = app.textFields["analytics.termField"].firstMatch
        XCTAssertTrue(term.waitForExistence(timeout: 10), "The Corpus Analytics term field never appeared")
        term.tap()
        term.typeText("Berlin\n")

        let chip = app.buttons["Year range"].firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "The year-range chip never appeared")
        chip.tap()

        // Containment is measured against the popover, so it must exist or the check is vacuous.
        let popover = app.popovers.firstMatch
        XCTAssertTrue(popover.waitForExistence(timeout: 5), "The year-range popover is not in the tree")
        let window = app.windows.firstMatch.frame
        let inside = popover.frame.intersection(window).insetBy(dx: Self.minimumInset, dy: Self.minimumInset)

        let startField = app.textFields["analytics.yearRange.startField"].firstMatch
        let endField = app.textFields["analytics.yearRange.endField"].firstMatch
        XCTAssertTrue(startField.waitForExistence(timeout: 5), "No start field in the popover")
        XCTAssertTrue(endField.exists, "No end field in the popover")
        print("[YearRangeFieldWidth] \(size): window \(window), popover \(popover.frame), "
              + "start \(startField.frame), end \(endField.frame)")

        for (field, name) in [(startField, "Start year"), (endField, "End year")] {
            let value = (field.value as? String) ?? ""
            XCTAssertEqual(value.count, 4, "The \(name) field should hold a four-digit year; it holds \"\(value)\"")

            // 1. At rest, the reader sees exactly the year — not "18…", not "861".
            let read = try readField(field, attachmentName: "\(name) field at \(size)")
            XCTAssertEqual(read, value, """
                The \(name) field holds "\(value)" but a reader sees "\(read)" at \(size) — the field \
                is too narrow for its year (frame \(field.frame)).
                """)

            // 2. The field and both of its stepper buttons sit well inside the popover and the window.
            XCTAssertTrue(inside.contains(field.frame), """
                The \(name) field \(field.frame) is not \(Self.minimumInset) pt inside the popover \
                \(popover.frame) and window \(window) at \(size)
                """)
            for step in ["Decrement", "Increment"] {
                let button = app.buttons.matching(NSPredicate(format: "label == %@", "\(name), \(step)")).firstMatch
                XCTAssertTrue(button.exists, "No \"\(name), \(step)\" button at \(size)")
                XCTAssertTrue(inside.contains(button.frame), """
                    \(name)'s \(step) button \(button.frame) is not \(Self.minimumInset) pt inside the \
                    popover \(popover.frame) and window \(window) at \(size)
                    """)
            }
        }

        // 3. Stacked in order on iPhone, where whole years side by side do not fit a narrow popover;
        //    one row on a (full-screen, so regular-width) iPad, where they fit at every size.
        if UIDevice.current.userInterfaceIdiom == .phone {
            XCTAssertGreaterThanOrEqual(endField.frame.minY, startField.frame.maxY,
                                        "At \(size) on iPhone the End field should sit below the Start field")
        } else {
            XCTAssertLessThan(abs(startField.frame.midY - endField.frame.midY), 1,
                              "At \(size) on iPad the two fields should share a row")
        }

        // 4. The hidden "8888" sizer never reaches the accessibility tree.
        XCTAssertEqual(app.textFields.matching(NSPredicate(format: "value == %@", "8888")).count, 0,
                       "The hidden width sizer is visible to accessibility")

        let whole = XCTAttachment(screenshot: popover.screenshot())
        whole.name = "popover at \(size)"
        whole.lifetime = .keepAlways
        add(whole)

        // 5. While editing, with the caret after the last digit, all four digits still show — a field
        //    exactly as wide as its text can scroll a digit out of view to make room for the caret.
        //    A centre tap lands mid-"1861" and puts the caret there, where nothing scrolls, so the
        //    first version of this step could not fail; the tap goes near the trailing edge, and the
        //    attachment shows the caret after the last digit. (It is also what showed the sizer's
        //    2-pt caret allowance to be unnecessary: the step passed with it and without it.) The
        //    caret may read as an extra "1", so this read is a containment.
        let startValue = (startField.value as? String) ?? ""
        startField.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        Thread.sleep(forTimeInterval: 1.0)
        let editing = try readField(startField, attachmentName: "Start year field editing at \(size)")
        XCTAssertTrue(editing.contains(startValue), """
            While editing at \(size) the start field shows "\(editing)", not all of "\(startValue)" — \
            the text scrolled a digit out of view (frame \(startField.frame)).
            """)
    }

    /// Screenshots `field`, attaches the image, and returns what Vision reads there.
    private func readField(_ field: XCUIElement, attachmentName: String) throws -> String {
        let shot = field.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = attachmentName
        attachment.lifetime = .keepAlways
        add(attachment)
        return try recognizedText(in: shot.image)
    }

    /// What Vision reads in the image, keeping only digits: an ellipsis, a space or a stray mark is
    /// dropped, so a truncated field reads as its visible digits ("18"), never as its value.
    private func recognizedText(in image: UIImage) throws -> String {
        guard let cgImage = image.cgImage else {
            XCTFail("The field screenshot has no bitmap")
            return ""
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: cgImage).perform([request])
        return (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined()
            .filter(\.isNumber)
    }
}
