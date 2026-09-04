// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - Store-schema mismatch alert (debug builds)

extension View {

    /// Presents a launch alert, **on debug builds only**, when this build cannot open the store on
    /// disk because their record types disagree.
    ///
    /// ## Why an alert, and why only here
    /// The app already reports a failed container init: `AppState.cloudKitInitError`, an orange
    /// "Local Only" chip in the macOS status bar, and a row in Settings. All three are correct, and
    /// all three were on screen for four days in July 2026 while the owner's Mac ran on an empty
    /// fallback store, never synced, and never received a bulk summarization run started on another
    /// machine. On a computer that rebuilds this app every few minutes, a small orange chip is
    /// launch noise. Nothing distinguished "sync is briefly unhappy" from "your data is not the
    /// data you are looking at".
    ///
    /// So this one failure — the store and the build declaring different record types, which is the
    /// one a developer causes routinely and no user can — gets a modal that must be dismissed.
    ///
    /// Release builds get the modifier as a pass-through. A researcher cannot cause this, cannot
    /// act on the record-type names, and the honest recovery for them is the same Fix iCloud Sync
    /// row this alert points at, which is already reachable. Blocking their first frame with entity
    /// names would be alarming and useless. `AppState.cloudKitInitError` carries the summary into
    /// the status bar and Settings on every build, which is where a tester's screenshot will find
    /// it.
    ///
    /// ## Not a substitute for the schema-deploy gate
    /// A different failure with a similar name: `CloudKitSchemaInventory` covers the *CloudKit*
    /// schema not being promoted to Production. This covers the *local* store disagreeing with the
    /// running model. They are separate layers and separate fixes, and the sync log records them
    /// under separate phases for that reason.
    func storeSchemaMismatchAlert(_ appState: AppState) -> some View {
        modifier(StoreSchemaMismatchAlert(appState: appState))
    }
}

/// Implementation of ``SwiftUI/View/storeSchemaMismatchAlert(_:)``.
///
/// Version history:
///   1.0 — the guard, after the 2026-07-25 four-day silent fallback
private struct StoreSchemaMismatchAlert: ViewModifier {

    /// Publishes the diagnosis. Read in `body` so the alert appears whenever `bootApp()` sets it,
    /// with no assumption about whether that happens before or after this view's first render — an
    /// ordering the previous draft of this modifier got wrong by latching the value in a `.task`.
    let appState: AppState

    /// Set once the alert has been dismissed, so it does not immediately return.
    @State private var isDismissed = false

    func body(content: Content) -> some View {
        #if DEBUG
        content
            .alert(
                String(localized: "storeSchema.alert.title",
                       defaultValue: "This Build Cannot Open Your Data"),
                isPresented: Binding(
                    get: { !isDismissed && appState.storeSchemaMismatch?.isMismatch == true },
                    set: { if !$0 { isDismissed = true } }
                )
            ) {
                Button(String(localized: "storeSchema.alert.dismiss",
                              defaultValue: "Continue Local-Only"), role: .cancel) {
                    isDismissed = true
                }
            } message: {
                Text(message)
            }
        #else
        content
        #endif
    }

    #if DEBUG
    /// The diagnosis, then the one action that resolves it.
    private var message: String {
        guard let diagnostic = appState.storeSchemaMismatch else { return "" }
        return diagnostic.summary + "\n\n" + String(
            localized: "storeSchema.alert.recovery",
            defaultValue: "To rebuild this device’s copy from iCloud, use Settings ▸ Data & Recovery ▸ Fix iCloud Sync, then quit and reopen the app."
        )
    }
    #endif
}
