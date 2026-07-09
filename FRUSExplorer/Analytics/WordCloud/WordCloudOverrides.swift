// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Per-scope user stopword overrides — words a researcher has chosen to hide from
/// a particular word cloud.
///
/// Stored in `UserDefaults` as a `[scopeSignature: [word]]` map so each scope's
/// hidden words persist independently across launches. These are unioned with the
/// bundled stopword layers when a cloud is computed.
///
/// Version history:
///   1.0 — Word Cloud feature: Phase 4 per-scope overrides
enum WordCloudOverrides {

    /// UserDefaults key for the persisted overrides map.
    private static let storageKey = "frus.wordcloud.overrides"

    /// Decodes the full `[signature: [word]]` map.
    private static func load() -> [String: [String]] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let map = try? JSONDecoder().decode([String: [String]].self, from: data)
        else { return [:] }
        return map
    }

    /// Persists the full map.
    private static func save(_ map: [String: [String]]) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    /// The set of words hidden for the given scope.
    static func hidden(for signature: String) -> Set<String> {
        Set(load()[signature] ?? [])
    }

    // (A per-scope `hide(_:for:)` writer previously lived here but had no callers — hides
    // are written through `WordCloudSettings` (global / per-lens) and, non-persistently,
    // through `WordCloudView.sessionHiddenWords` (#233). The reader + reset remain so any
    // legacy persisted per-scope hides still load and can be cleared.)

    /// Clears all hidden words for the given scope.
    static func reset(for signature: String) {
        var map = load()
        map[signature] = nil
        save(map)
    }
}
