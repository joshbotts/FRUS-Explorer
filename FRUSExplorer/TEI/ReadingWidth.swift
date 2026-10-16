// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - ReadingWidth

/// Settings ▸ Display's **Reading Width** (#1665): how long a document's lines may grow.
///
/// Three steps, beside Document Text Size and device-local as it is (`SettingsKeys.readingWidth`,
/// never a stored property on a mirrored `@Model`, which would need a CloudKit deploy, #488).
/// Standard is the device's default (the owner's decision 20). Each step is a `ReaderMeasure` on a
/// ladder of four, of which a phone reads the lower three and an iPad or a Mac the upper three
/// (the owner's decision 50, 2026-10-16):
///
/// | | Narrow | Standard | Wide |
/// |---|---|---|---|
/// | iPhone | 60ch (63) | 70ch (77) | 87ch (100) |
/// | iPad, Mac | 70ch (77) | 87ch (100) | 120ch (145) |
///
/// In brackets, the mean characters a line at Medium text, measured on the Long Telegram
/// (frus1946v06/d475) in WebKit under iOS 27.0 and macOS 27.0, which agreed to the line; from
/// Small to Extra Large text each moves by at most 11.
///
/// **Why these rungs**, each measured in the app on 2026-10-16, not chosen. 70ch is the one
/// measure the page had from 2026-08-14 to #1665, which the owner found right for phones, so it
/// stays the phone's default. 87ch fills the reader exactly where the app gives it about 750 pt:
/// iPhone 17 in landscape (750 pt; 402 pt in portrait, narrower than every rung) and the 13-inch
/// iPad beside its Research rail (752 pt in portrait, 755.5 pt in landscape beside the list pane).
/// 120ch fills the 13-inch iPad's reader in landscape with the rail closed (1,035.5 pt), where
/// 70ch had left 430 pt empty. Wider than 120ch is the 150 to 300 characters a line that the
/// 2026-08-14 review (X-1) found on a wide window with no measure at all.
///
/// Version history:
///   1.0 — #1665: initial implementation
enum ReadingWidth: String, CaseIterable, Identifiable, Sendable {
    case narrow, standard, wide

    /// The step's stored value, which names it in a picker.
    var id: String { rawValue }

    /// The step's name in Settings.
    var label: String {
        switch self {
        case .narrow:   return String(localized: "settings.display.readingWidth.narrow", defaultValue: "Narrow")
        case .standard: return String(localized: "settings.display.readingWidth.standard", defaultValue: "Standard")
        case .wide:     return String(localized: "settings.display.readingWidth.wide", defaultValue: "Wide")
        }
    }

    /// Which ladder a device reads on.
    enum Ladder: Sendable {
        /// iPhone: 60ch, 70ch, 87ch.
        case phone
        /// iPad and the Mac: 70ch, 87ch, 120ch.
        case wide
    }

    /// The step's measure on `ladder`.
    func measure(on ladder: Ladder) -> ReaderMeasure {
        switch (ladder, self) {
        case (.phone, .narrow):   return ReaderMeasure(ch: 60)
        case (.phone, .standard): return .classic
        case (.phone, .wide):     return ReaderMeasure(ch: 87)
        case (.wide, .narrow):    return .classic
        case (.wide, .standard):  return ReaderMeasure(ch: 87)
        case (.wide, .wide):      return ReaderMeasure(ch: 120)
        }
    }

    /// The ladder this device reads on: by its idiom, so an iPad in a narrow window keeps its
    /// own ladder (a column narrower than the measure is simply filled).
    @MainActor
    static var currentLadder: Ladder {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone ? .phone : .wide
        #else
        .wide
        #endif
    }

    /// The step's measure on this device.
    @MainActor
    var measure: ReaderMeasure { measure(on: Self.currentLadder) }
}
