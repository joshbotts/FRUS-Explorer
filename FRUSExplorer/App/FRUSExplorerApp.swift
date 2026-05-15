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
import SwiftData

/// Root entry point for FRUS Explorer.
///
/// Bootstraps `AppState` and the SwiftData `ModelContainer` and injects both into
/// the SwiftUI environment. All descendant views can access persistent models via
/// `@Environment(\.modelContext)` and application state via `@Environment(AppState.self)`.
///
/// ## ModelContainer
/// Created once via `ModelContainer.makeFRUSContainer()` which configures CloudKit
/// private-database sync. On failure (e.g., no iCloud account in simulator) the
/// factory falls back to a local-only store so the app remains functional.
///
/// Version history:
///   1.0 — Session 01: initial implementation
///   1.1 — Session 04: inject SwiftData ModelContainer
@main
struct FRUSExplorerApp: App {

    @State private var appState = AppState()

    private let modelContainer: ModelContainer = ModelContainer.makeFRUSContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .modelContainer(modelContainer)
        }
        #if os(macOS)
        .defaultSize(width: 1200, height: 800)
        .commands {
            // macOS-specific menu commands added in future sessions.
        }
        #endif
    }
}
