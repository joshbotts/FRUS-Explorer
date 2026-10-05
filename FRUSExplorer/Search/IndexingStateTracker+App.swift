// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - IndexingStateTracker + the app

extension IndexingStateTracker {

    /// A tracker that keeps its sentinel in `userDefaults`: `.standard` in the app, a suite of its
    /// own in a test, so tests never pollute the app's settings.
    ///
    /// Version history:
    ///   1.0 — Session 2026-10-04 (FRUSCoreKit, part 2): the tracker's initialiser before it moved
    ///          into the kit, delegating to `init(store:)`
    init(userDefaults: UserDefaults = .standard) {
        self.init(store: userDefaults)
    }
}
