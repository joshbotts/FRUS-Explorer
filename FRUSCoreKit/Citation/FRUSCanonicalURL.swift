// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - FRUSCanonicalURL

/// The one spelling of a document's public `history.state.gov` address.
///
/// It was already spelled in `DocumentExportSupport.canonicalURL`, but that lives in
/// `SupportingViews.swift`, which is entirely `#if os(macOS)` — so the iOS share menu could not
/// reach it and would have had to spell the URL a second time. That matters more than tidiness
/// here: on iOS this URL **is** the Zotero integration for anyone without an API key (#358), since
/// Zotero's share extension ingests `public.url` through its web translators and cannot read an
/// RIS at all. A second spelling that drifted would break the fallback on one platform only.
///
/// Version history:
///   1.0 — Session 2026-08-10: #358 (F-8)
enum FRUSCanonicalURL {

    /// The document's public page, e.g.
    /// `https://history.state.gov/historicaldocuments/frus1969-76v01/d1`.
    static func string(volumeId: String, documentId: String) -> String {
        "https://history.state.gov/historicaldocuments/\(volumeId)/\(documentId)"
    }

    /// The same address as a `URL`, or `nil` if either identifier is unusable.
    ///
    /// Percent-encoding is deliberate rather than assumed-unnecessary: FRUS volume and document
    /// ids are ASCII today, and a `URL(string:)` that silently returned nil on some future id
    /// would remove the share entry with no other symptom.
    static func url(volumeId: String, documentId: String) -> URL? {
        guard !volumeId.isEmpty, !documentId.isEmpty else { return nil }
        return URL(string: string(volumeId: volumeId, documentId: documentId))
    }
}
