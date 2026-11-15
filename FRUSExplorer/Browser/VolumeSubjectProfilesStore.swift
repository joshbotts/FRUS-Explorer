// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - VolumeSubjectProfilesStore

/// Loads and caches the bundled `volume-subject-profiles-index.json`.
///
/// Decoded once, **lazily**, on first access — deliberately NOT at `AppState` init, unlike
/// the removed synchronous `SubjectTagStore`. `shared` is `nil` only when the resource is
/// missing or malformed (logged in DEBUG); the volume-detail "Top subjects" section then
/// simply does not appear. Mirrors ``VolumeSourcesIndexStore``.
///
/// Version history:
///   1.0 — Session 9: initial implementation
///   1.1 — FRUSCoreKit, part 2: moved from `VolumeSubjectProfiles.swift`, which the kit compiles;
///          the kit never reads a bundle
///   1.2 — #1905 (L15): ``SubjectDataCaption`` beside it, the one account of where the data
///          comes from
enum VolumeSubjectProfilesStore {

    /// The bundled volume-subject profiles, or `nil` if unavailable. Loaded once.
    static let shared: VolumeSubjectProfiles? = load()

    private static func load() -> VolumeSubjectProfiles? {
        guard let url = Bundle.main.url(forResource: "volume-subject-profiles-index", withExtension: "json") else {
            #if DEBUG
            print("[VolumeSubjectProfilesStore] volume-subject-profiles-index.json not found in bundle.")
            #endif
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(VolumeSubjectProfiles.self, from: data)
        } catch {
            #if DEBUG
            print("[VolumeSubjectProfilesStore] failed to decode volume-subject-profiles-index.json — \(error)")
            #endif
            return nil
        }
    }
}

// MARK: - SubjectDataCaption

/// The one account of where the subject data comes from, which every surface that explains it
/// carries (#1905; the plan of record's decision 135).
///
/// The data is the Office of the Historian's subject export, matched to documents by name before
/// the app reads it (`document-subject-index.json`, `volume-subject-profiles-index.json`). Until
/// #1905 the surfaces gave five accounts of it — "detected automatically", "inferred from the
/// text", "experimental enrichment data", "assigned", "detected topics … matched by name" — and
/// the word *detected* said the app does the detecting. The owner set this text on 2026-11-15,
/// on the terms that it credit the Office and not imply that the Office has reviewed the data or
/// approved its editorial accuracy, so it names no reviewer and claims no review either way.
///
/// The text lives here once, under one key, so that it reads the same everywhere and changes in
/// one place. A surface keeps its own practical sentence under its own key and joins the caption
/// to it where its old account stood: ``leading(_:)`` where the account came first (the rail,
/// Search's two footers), ``trailing(_:)`` where it came last (the Subject index's header, a
/// subject's sheet, the archival footer). The facet panel shows ``text`` alone. The two surfaces
/// that showed subjects with no account carry it too, on the owner's word of 2026-11-15: a
/// volume's Top subjects shows ``text`` under its chips (on the Mac, below the block's capped
/// scroll view), and the person sheet's Subjects joins it after its volume-level note.
///
/// Version history:
///   1.0 — 2026-11-15: #1905 (L15)
enum SubjectDataCaption {

    /// The caption, word for word as the owner set it.
    static var text: String {
        String(localized: "subjects.caption",
               defaultValue: "Experimental subject data from the Office of the Historian, not published on history.state.gov. Subjects are matched to documents by name in the text; they are not editorial headings from the FRUS publication process, so some are wrong.")
    }

    /// The caption, then a surface's own sentence.
    ///
    /// - Parameter sentence: The surface's practical sentence, already localized.
    /// - Returns: One paragraph: the caption, a space, the sentence.
    static func leading(_ sentence: String) -> String {
        "\(text) \(sentence)"
    }

    /// A surface's own sentence, then the caption.
    ///
    /// - Parameter sentence: The surface's practical sentence, already localized.
    /// - Returns: One paragraph: the sentence, a space, the caption.
    static func trailing(_ sentence: String) -> String {
        "\(sentence) \(text)"
    }
}
