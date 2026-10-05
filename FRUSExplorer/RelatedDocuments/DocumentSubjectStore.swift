// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - DocumentSubjectStore

/// The document-grain subject seam (design §5.2): the single access point every document-level
/// subject consumer reads — the on-document subject hierarchy, the subject drill-down, and the
/// find-related shared-subjects axis.
///
/// Loaded lazily on first access rather than at `AppState` init, mirroring
/// `VolumeSubjectProfilesStore`. `nil` when the resource is missing or unreadable, and every
/// consumer degrades to "no subjects" — a section that does not appear, and a scorer that returns
/// nothing — never a crash and never an inversion.
///
/// Version history:
///   1.0 — #308 Phase 2: the seam, deliberately empty
///   2.0 — Session 2026-08-21: #308 Phase 3 — the bundle is real
///   2.1 — FRUSCoreKit, part 2: moved from `DocumentSubjectStore.swift`, now the kit's
///          `DocumentSubjectIndex.swift`; the kit is given the index (`IndexingResources`) and never
///          reads a bundle
enum DocumentSubjectStore {

    /// The document-grain subject index, or `nil` when it isn't bundled or won't decode.
    static let shared: DocumentSubjectIndex? = load()

    private static func load() -> DocumentSubjectIndex? {
        guard let url = Bundle.main.url(forResource: "document-subject-index",
                                        withExtension: "json") else {
            #if DEBUG
            print("[DocumentSubjectStore] document-subject-index.json not found in bundle; "
                + "document subjects unavailable, as they were before #308 Phase 3.")
            #endif
            return nil
        }
        do {
            return try JSONDecoder().decode(DocumentSubjectIndex.self,
                                            from: try Data(contentsOf: url))
        } catch {
            #if DEBUG
            print("[DocumentSubjectStore] document-subject-index.json failed to decode: \(error)")
            #endif
            return nil
        }
    }
}
