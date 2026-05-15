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
final class FRUSExplorerUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
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
