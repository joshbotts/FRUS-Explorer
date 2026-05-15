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

import SwiftUI

/// Root entry point for FRUS Explorer.
///
/// Bootstraps `AppState` and injects it into the environment so that all descendant views
/// can read application-level state without explicit prop-drilling.
/// Platform-specific Scene configuration (window sizing on macOS) lives here.
@main
struct FRUSExplorerApp: App {

    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
        #if os(macOS)
        .defaultSize(width: 1200, height: 800)
        .commands {
            // macOS-specific menu commands added in future sessions.
        }
        #endif
    }
}
