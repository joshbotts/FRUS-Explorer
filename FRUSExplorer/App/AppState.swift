// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Observation

/// AppState is the root observable state object for FRUS Explorer.
///
/// It holds application-level state that must be accessible across the entire view hierarchy
/// and persists across launches via `UserDefaults`. Injected into SwiftUI's environment at
/// the `App` level so any view can read it without explicit parameter passing.
///
/// Project context: AppState serves as the bridge between the user's active research focus
/// (`activeProjectId`) and the SwiftData/CloudKit layer that stores all user-generated content.
/// Views observe AppState to react to project switching without requiring data migration —
/// switching projects is a state change, never a data migration.
///
/// Network monitoring and download queue management are expanded in Session 05
/// (Volume Download & Storage Manager). For now these properties are stubs with
/// sensible defaults.
@Observable
@MainActor
final class AppState {

    // MARK: - Active Project

    /// The ID of the currently active research project, or `nil` for global context.
    ///
    /// Persisted across launches via `UserDefaults`. Changing this property is instantaneous —
    /// it does not trigger data migration. All content is global; the active project is a lens
    /// that filters what the user sees.
    var activeProjectId: UUID? {
        didSet {
            UserDefaults.standard.set(activeProjectId?.uuidString, forKey: Keys.activeProjectId)
            #if DEBUG
            print("[FRUSExplorer] Active project changed to: \(activeProjectId?.uuidString ?? "nil (global context)")")
            #endif
        }
    }

    // MARK: - Network State

    /// Whether the device currently has network connectivity.
    ///
    /// Defaults to `true` (optimistic). Updated when the download manager initialises
    /// its `NWPathMonitor` in Session 05. Kept here so views can observe reachability
    /// without depending on the download manager directly.
    var isOnline: Bool = true

    // MARK: - Download Queue

    /// Volume IDs currently queued for download.
    ///
    /// Managed by the download manager (Session 05). Exposed on AppState so any view
    /// can show download progress without importing the download manager directly.
    var downloadQueue: [String] = []

    // MARK: - Initialization

    init() {
        if let raw = UserDefaults.standard.string(forKey: Keys.activeProjectId),
           let uuid = UUID(uuidString: raw) {
            activeProjectId = uuid
        }

        #if DEBUG
        print("[FRUSExplorer] AppState initialised. activeProjectId=\(activeProjectId?.uuidString ?? "nil")")
        #endif
    }

    // MARK: - Private

    private enum Keys {
        static let activeProjectId = "activeProjectId"
    }
}
