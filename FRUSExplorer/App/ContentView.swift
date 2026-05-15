// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

/// Placeholder root view.
///
/// Replaced by the Onboarding → Browser → Document navigation hierarchy starting in Session 10.
/// This stub exists solely so the app target compiles and launches during early sessions.
struct ContentView: View {

    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .imageScale(.large)
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text(String(localized: "app.placeholder.title", defaultValue: "FRUS Explorer"))
                .font(.largeTitle.bold())
            Text(String(localized: "app.placeholder.subtitle", defaultValue: "Setup in progress"))
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
