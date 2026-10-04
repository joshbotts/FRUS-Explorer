// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CitationStyle, the user's preference

/// The app's half of `CitationStyle` (FRUSCoreKit's `CitationFormatter.swift`): the preference is a
/// setting of the app's, which the kit cannot read.
///
/// Version history:
///   1.0 — FRUSCoreKit, part 1: moved from `CitationFormatter.swift`
extension CitationStyle {

    /// The user's persisted citation style preference
    /// (`SettingsKeys.citationStyle`), defaulting to `.historyAtState`
    /// when unset or unrecognized. Drives `DocumentViewModel.formattedCitation`
    /// and friends, the iOS `CitationSheetView`, and the macOS citation
    /// popover's initial selection.
    public static var current: CitationStyle {
        get {
            guard let raw = UserDefaults.standard.string(forKey: SettingsKeys.citationStyle),
                  let style = CitationStyle(rawValue: raw) else { return .historyAtState }
            return style
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: SettingsKeys.citationStyle)
        }
    }
}
