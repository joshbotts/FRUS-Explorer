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

#if os(iOS) && DEBUG
import Testing
@testable import FRUSExplorer

/// The iOS background task's launch handler holds the AppState the launch boots (plan of record
/// L11, decision 121).
///
/// ## The defect
/// The handler `FRUSExplorerApp.init()` registers for `bottsywattsy.FRUS-Explorer.indexing` indexes
/// and summarizes through `state.indexingPipeline`, which only the launch's boot sets, and only on
/// the AppState SwiftUI installed. Builds 47 to 1787 gave the handler an AppState of its own. Since
/// Xcode 27.0, `@State` is a macro over `LazyState`, which holds a property's initial value as a
/// closure until SwiftUI installs the property: the `init()`'s read of `appState` ran that closure,
/// and installation ran it again. No line of the app changed; the toolchain did. Every background wake then
/// ended at the handler's first guard with `setTaskCompleted(success: false)`.
///
/// ## Why the instances, and not the source
/// A scan for a `@State` read in an `init` would not have caught this: the read was correct under
/// Xcode 26, whose property wrapper kept the instance the `init()` saw. What the handler depends on
/// is that its AppState IS the booted one, so that is what this compares, in the app this target
/// runs in: whatever separates the two, an edit or the next toolchain, fails it.
///
/// The unit tests run inside the app, so its `init()` has run and its first scene boots on its own.
/// `init()` records the instance it gave the handler (`debugBackgroundTaskAppState`), and the first
/// `bootSearchInfrastructureOnce()` the instance it ran on (`debugBootedAppState`), both DEBUG only.
/// A recorded verdict and a failing test, rather than an `assert` in the app: a trap at launch
/// would kill the host and every test in it.
///
/// Measured on 2026-11-09 against the unfixed `init()` (`7f24463e` with this suite and the two
/// records): it failed at the identity check, both records set and the host booted 4.9 s in.
///
/// Version history:
///   1.0 — L11: the handler's AppState is the booted one
@MainActor
struct BackgroundTaskAppStateTests {

    /// How long the host's first boot may take to reach `bootSearchInfrastructureOnce()`, the main
    /// scene's first `.task`. It has normally run before the first test starts.
    private static let bootWait: Duration = .seconds(60)

    @Test("The background task's launch handler holds the AppState the launch boots")
    func handlerHoldsTheBootedAppState() async throws {
        let deadline = ContinuousClock.now + Self.bootWait
        while FRUSExplorerApp.debugBootedAppState == nil, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }
        let handlerState = try #require(FRUSExplorerApp.debugBackgroundTaskAppState,
                                        "FRUSExplorerApp.init() recorded no AppState for the background task's handler")
        let bootedState = try #require(FRUSExplorerApp.debugBootedAppState,
                                       "The host app's first boot did not reach bootSearchInfrastructureOnce() within \(Self.bootWait)")
        #expect(handlerState === bootedState,
                "The background task's handler holds an AppState the launch never boots, so every background wake ends at its first guard. Never read a @State in an init: make the instance there and hand it to _appState (L11).")
    }
}
#endif
