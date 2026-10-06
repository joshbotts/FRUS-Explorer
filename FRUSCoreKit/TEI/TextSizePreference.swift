// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - TextSizePreference

/// User preference for document body text size.
///
/// Stored in `UserDefaults` via `AppStorage("frus.display.textSize")` and applied
/// by `FRUSDocumentRenderer` to all paragraph-level text. `Double` body font sizes
/// avoid a CoreGraphics import in this Foundation-only file.
public enum TextSizePreference: String, CaseIterable, Identifiable, Sendable {
    case small, medium, large, extraLarge

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .small:      return "Small"
        case .medium:     return "Medium"
        case .large:      return "Large"
        case .extraLarge: return "Extra Large"
        }
    }

    /// Point size for body text (paragraphs, salutations, inline defaults).
    public var bodyFontSize: Double {
        switch self {
        case .small:      return 12
        case .medium:     return 14
        case .large:      return 16
        case .extraLarge: return 19
        }
    }
}
