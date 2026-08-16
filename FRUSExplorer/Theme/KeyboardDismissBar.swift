// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - Keyboard dismissal

/// A **Done** bar above the on-screen keyboard, and the way to put the keyboard away (#861).
///
/// ## Why this had to be introduced rather than copied
/// Audited across the whole app: `ToolbarItemGroup(placement: .keyboard)` appears **zero** times,
/// and the only dismissal affordance of any kind anywhere is a single
/// `.scrollDismissesKeyboard(.interactively)` in `AnalyticsView`. There was no house pattern, so
/// this is the first one; every stuck field should adopt *this* rather than a sixth variation.
///
/// ## The three shapes that are provably stuck without it
/// A field is not merely awkward but **impossible to leave** when the keyboard has no Return key
/// to resign on:
///
/// 1. **`.keyboardType(.numberPad)` / `.decimalPad`** — those keyboards have no return key at all.
///    `.submitLabel(.search)` on such a field is inert, which the Citation Lookup fields showed.
/// 2. **Multi-line `TextEditor` / `TextField(axis: .vertical)`** — Return inserts a newline, which
///    is the point of the control, so it can never double as dismissal.
/// 3. **A field the keyboard physically covers.** Measured on the reported screen (iPhone,
///    402×874): the scope editor's volume filter renders at y 803–841 while the keyboard occupies
///    y 583–816, so with the name field's keyboard up the filter is *under* it and reports
///    `isHittable == false`. No gesture on that screen dismisses the keyboard, so the task cannot
///    be completed at all — which is why #862 ("custom volume scopes do not save on iOS") is the
///    same defect seen from the other end.
///
/// ## Why it resigns through UIKit rather than a `FocusState`
/// `FocusState` is the sanctioned route and is better *when a screen already has one* — it is
/// typed, and it says which field. But this modifier is applied at ~a dozen sites across six
/// features, and threading a new `@FocusState` through each would change focus semantics on
/// screens that never asked for it (an initial-focus surprise is its own bug). Resigning the
/// first responder dismisses whatever is focused without claiming to know what that is, which is
/// exactly the scope of a Done button.
///
/// The call is main-actor and iOS-only; on macOS the whole modifier compiles away, because a Mac
/// has a hardware keyboard and none of this applies.
///
/// Version history:
///   1.0 — #861
struct KeyboardDismissBar: ViewModifier {

    func body(content: Content) -> some View {
        #if os(iOS)
        content.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    KeyboardDismissBar.dismiss()
                } label: {
                    Text(String(localized: "common.keyboard.done", defaultValue: "Done"))
                        .fontWeight(.semibold)
                }
                // **No `accessibilityLabel` override.** An earlier draft set one to "Dismiss
                // keyboard", which *renames* the button — VoiceOver and any UI query then see a
                // control whose name is not the word on screen, and the visible/spoken names stop
                // agreeing. "Done" is the platform's own word for this bar and needs no gloss.
            }
        }
        #else
        content
        #endif
    }

    /// Resigns the first responder, dismissing the on-screen keyboard.
    ///
    /// Also usable directly — a screen that wants to dismiss on submit or on a row tap can call
    /// this without adopting the bar.
    @MainActor
    static func dismiss() {
        #if os(iOS)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}

extension View {

    /// Adds a **Done** bar above the on-screen keyboard (iOS), so the reader can always put it
    /// away — see ``KeyboardDismissBar`` for which fields are stuck without it.
    ///
    /// Apply it to the screen (or the smallest container holding the fields), not to each field:
    /// the keyboard toolbar is per-responder, so one bar serves every field beneath it.
    func keyboardDismissBar() -> some View {
        modifier(KeyboardDismissBar())
    }
}
