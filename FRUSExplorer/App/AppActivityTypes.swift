// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

/// Handoff / NSUserActivity type identifiers.
///
/// The activity type strings must be registered in each target's `Info.plist`
/// under `NSUserActivityTypes` for Handoff to route activities to this app.
enum AppActivityTypes {
    /// A user is viewing a FRUS document. Carries `volumeId` and `documentId`
    /// in `userInfo` so the receiving device can navigate directly to it.
    static let document = "com.joshbotts.frus-explorer.document"
}
