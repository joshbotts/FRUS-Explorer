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

import XCTest

/// Project Home's Plan a Visit enables as soon as a collection with documents is attached through
/// Manage, without Project Home being closed and reopened (#1457).
///
/// ## The defect
/// Plan a Visit is enabled by the project's engaged content, which Project Home read once, when it
/// opened. Attaching a collection through Manage changed what the screen's own seed signature reads,
/// but that signature only rescheduled the leads, so the button stayed disabled with nothing on
/// screen to say why. The read also ran on a fresh context that sees only saved data, and Manage does
/// not save; `ProjectHomeEngagedSetTests` pins that half without a UI.
///
/// ## The fixture
/// `UITestProjectSeeder` (`FRUS_UI_TEST_SEED_PROJECT`) seeds a project with a fixed id, which the launch
/// makes active, and one collection holding one document that is NOT in the project. So the button
/// starts disabled for the right reason, which the test asserts before it attaches anything.
///
/// ## Where it can fail
/// On iPhone and on iPad: Project Home is a sheet from the Research tab on both, and the gate is one
/// shared body. It needs no volume and no index. Measured on iOS 26.4 (the Session 2026-09-25 entry
/// in `Planning/DEVELOPMENT-PLAN.md` has the runs): on iPhone 17 it failed on the final assertion
/// against the code before the fix; on iPad Pro 11-inch (M5) it failed on the same assertion with
/// only the re-read on the seed signature taken out, the save kept; both pass with the fix. Whether
/// it would catch the save alone going was not measured — the main context may autosave first — so
/// `ProjectHomeEngagedSetTests` pins the save, with autosave off.
///
/// Version history:
///   1.0 — #1457: initial implementation
@MainActor
final class ProjectHomePlanVisitGateTests: XCTestCase {

    /// The seeded project's id — `UITestProjectSeeder.projectIdString`, repeated because a UI-test
    /// target cannot import the app.
    private static let projectId = "14570000-B4B4-4B4B-8B4B-000000001457"
    /// The seeded project's name, which titles the Manage sheet.
    private static let projectName = "UI Test Project"
    /// The seeded collection's name — `UITestProjectSeeder.collectionName`.
    private static let collectionName = "UI Test Unattached Collection"

    /// Resolves the Research tab across every tab-bar representation.
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    /// The application under test.
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_PROJECT"] = "1"
        app.launchArguments = UITestLaunch.arguments(startingOn: .research, activeProjectId: Self.projectId)
        app.launch()
    }

    override func tearDown() async throws {
        // Project Home is a sheet; close it rather than leave it to the next launch.
        UITestPresentation.dismissAnyPresentation(in: app)
        app = nil
    }

    func testPlanAVisitEnablesOnceManageAttachesACollection() throws {
        XCTAssertTrue(navigator.select(.research).tapped, "no Research tab")

        let home = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Project Home")).firstMatch
        XCTAssertTrue(home.waitForExistence(timeout: 20), """
            Research shows no Project Home row, so the seeded project is not active — the seeder did \
            not run, or the launch did not set activeProjectId
            """)
        home.tap()

        let planVisit = app.buttons["project.home.planVisit"]
        XCTAssertTrue(planVisit.waitForExistence(timeout: 10), "Project Home shows no Plan a Visit button")
        // Nothing is engaged yet, and the project has no plan: disabled, for the right reason. Given a
        // moment first, since the open-time read is asynchronous and could only enable it.
        Thread.sleep(forTimeInterval: 1)
        XCTAssertFalse(planVisit.isEnabled, "fixture: Plan a Visit is enabled before anything is attached")

        let manage = app.buttons["project.home.collections.manage"]
        XCTAssertTrue(manage.waitForExistence(timeout: 5), "Project Home shows no Manage button")
        manage.tap()

        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", Self.collectionName)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Manage does not list the seeded collection")
        row.tap()

        let manageBar = app.navigationBars["Collections · \(Self.projectName)"]
        XCTAssertTrue(manageBar.waitForExistence(timeout: 5), "the Manage sheet's navigation bar is not on screen")
        // The attach moves the collection into the sheet's "In this project" section, which the sheet
        // draws only while the project holds a collection — so its header is what says the tap landed.
        // Not the row's disappearance: the member row, with its remove button, still carries the name.
        XCTAssertTrue(app.staticTexts["In this project"].waitForExistence(timeout: 5),
                      "tapping the collection did not attach it")
        manageBar.buttons["Done"].tap()
        XCTAssertTrue(waitUntil(timeout: 5) { !manageBar.exists }, "Manage did not close")

        XCTAssertTrue(waitUntil(timeout: 10) { planVisit.isEnabled }, """
            Plan a Visit is still disabled after Manage attached a collection holding a document. Project \
            Home must re-read its engaged set when its seed changes, saving first (#1457).
            """)
    }

    /// Polls `condition` until it holds or `timeout` passes.
    private func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return condition()
    }
}
