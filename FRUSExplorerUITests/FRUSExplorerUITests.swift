// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import XCTest

/// UI test suite for FRUS Explorer.
///
/// Session 01 establishes the test target. Substantive UI tests are added
/// starting in Session 10 (Onboarding) and later sessions as views are built.
/// This placeholder ensures the UI test target compiles and the scheme is
/// configured correctly.
///
/// ## Launch configuration
/// Every test injects two values before launch:
///   - `FRUS_UI_TEST_MODE = "1"` — tells `ModelContainer.makeFRUSContainer()` to use
///     a local SQLite store instead of CloudKit. Without this, CloudKit's background
///     sync setup fires a SIGTRAP ~30 s after launch when the entitlement is absent,
///     crashing the app under test before most tests can run.
///   - `-hasCompletedOnboarding 1` — populates `NSArgumentDomain` so
///     `UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")` returns `true`,
///     bypassing `OnboardingView` and landing directly in `MainTabView`.
///
/// Version history:
///   1.0 — Session 01: initial placeholder
///   1.1 — Session 52: inject FRUS_UI_TEST_MODE + hasCompletedOnboarding bypass
final class FRUSExplorerUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Bypass CloudKit (avoids the 30-second SIGTRAP in unsigned UI test builds).
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        // Bypass OnboardingView so tests start in the main tab UI.
        app.launchArguments = ["-hasCompletedOnboarding", "1"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// Placeholder test: verifies the app launches without crashing.
    /// Replaced by a meaningful launch test in Session 10.
    func testAppLaunches() throws {
        XCTAssertTrue(app.state == .runningForeground, "App should be running in the foreground after launch")
    }
}
