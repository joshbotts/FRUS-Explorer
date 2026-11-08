// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - SubjectNumericLabelStore

/// The bundled subject-numeric table, decoded once on first use (#1211).
///
/// Version history:
///   1.0 — #1211: initial implementation, in this file with the table
///   1.1 — 2026-11-08 (FRUS Explorer Light, S22a): the table moved into FRUSCoreKit
///          (`SubjectNumericLabelTable.swift`), which never reads a bundle; the store stays here
enum SubjectNumericLabelStore {

    /// The table, or `nil` when the resource is absent or unreadable.
    ///
    /// Absence degrades to unlabelled keys, never to a crash — the state every build before this
    /// one shipped in.
    static let shared: SubjectNumericLabelTable? = load()

    private static func load() -> SubjectNumericLabelTable? {
        guard let url = Bundle.main.url(forResource: "subject-numeric-labels",
                                        withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            #if DEBUG
            print("[SubjectNumericLabelStore] subject-numeric-labels.json is not in the bundle; "
                + "subject-numeric keys will render unlabelled, as they did before #1211.")
            #endif
            return nil
        }
        return try? JSONDecoder().decode(SubjectNumericLabelTable.self, from: data)
    }
}
