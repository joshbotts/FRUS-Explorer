// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// `StructuredSummarySchema` and `ResponseFormat` moved to FRUSCoreKit
// (`FRUSCoreKit/Models/SummaryTypes.swift`) under their names, since the research data export,
// now kit code, names them.

// `TextSizePreference` moved to FRUSCoreKit (`FRUSCoreKit/TEI/TextSizePreference.swift`) under its
// name, since the reader's page, `ReaderPage`, now kit code, reads it.

// MARK: - DefaultDocumentMode

/// User preference for which mode a document opens in (Session 154).
///
/// Stored via `AppStorage(SettingsKeys.defaultDocumentMode)`. `.rememberLast`
/// preserves the original behaviour: `frus.document.researchPanel.visible`
/// persists the last Read/Research choice across documents and is left alone
/// on open. `.read`/`.research` force that panel-visibility flag to a fixed
/// value each time a document opens; the in-document Read/Research rail toggle
/// can still switch modes live for that document.
public enum DefaultDocumentMode: String, CaseIterable, Identifiable, Sendable {
    case read
    case research
    case rememberLast

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .read:         return "Read"
        case .research:     return "Research"
        case .rememberLast: return "Remember Last"
        }
    }
}
