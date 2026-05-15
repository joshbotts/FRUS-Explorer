// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

/// Root routing view for FRUS Explorer.
///
/// Routes to `OnboardingView` when no volumes have been downloaded, or to
/// `BrowserView` when at least one .xml file exists in the volumes directory.
/// The routing trigger is purely filesystem-based — no persistent flag is stored.
///
/// Version history:
///   1.0 — Session 01: initial placeholder implementation
///   1.1 — Session 10: replaced with onboarding / main-app routing
///   1.2 — Session 11: replaced placeholder with BrowserView
struct ContentView: View {

    @Environment(AppState.self) private var appState

    var body: some View {
        if OnboardingViewModel.hasDownloadedVolumes(in: appState.downloadManager?.volumesDirectory) {
            BrowserView()
        } else {
            OnboardingView()
        }
    }
}
