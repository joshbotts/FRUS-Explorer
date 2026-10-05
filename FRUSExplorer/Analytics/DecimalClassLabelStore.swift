// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - DecimalClassLabelStore

/// The bundled label table, decoded once on first use (#828).
///
/// A lazy `static let`, like its sibling stores — but every caller reaches it from a background
/// context, because the first touch pays the decode on whichever thread arrives first.
///
/// Version history:
///   1.0 — FRUSCoreKit, part 2: moved from `DecimalClassLabelStore.swift`, now the kit's
///          `DecimalClassLabelTable.swift`; the kit is given the table (`IndexingResources`) and
///          never reads a bundle
enum DecimalClassLabelStore {

    /// The table, or `nil` when the resource is absent or unreadable.
    ///
    /// Absence degrades to unlabelled keys, never to a crash: the app rendered bare numbers for
    /// its whole life before this artifact existed, and that remains a working state.
    static let shared: DecimalClassLabelTable? = load()

    private static func load() -> DecimalClassLabelTable? {
        guard let url = Bundle.main.url(forResource: "decimal-class-labels", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            #if DEBUG
            print("[DecimalClassLabelStore] decimal-class-labels.json is not in the bundle; "
                + "class keys will render unlabelled, as they did before #828.")
            #endif
            return nil
        }
        return try? JSONDecoder().decode(DecimalClassLabelTable.self, from: data)
    }
}
