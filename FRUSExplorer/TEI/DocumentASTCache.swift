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

// MARK: - DocumentASTCache

/// In-memory LRU cache of parsed document ASTs, keyed by `"volumeId/documentId"`.
///
/// ## Why
/// SAX parsing must start at the beginning of a volume file, so opening a document
/// costs a parse of everything before it. The parse that finds document *N* has
/// necessarily already produced documents 1…N (and `parseDocumentWindow` adds N+1),
/// so caching a window around the target makes the adjacent-document page-turn and
/// any re-open instant — without persisting anything to disk.
///
/// ## Memory
/// Capacity-bounded LRU (default 24 entries — a handful of reading windows). On
/// iOS the cache empties itself on a memory warning. Holding the trailing window
/// is strictly cheaper than the parse itself, which already accumulated the whole
/// prefix in memory before this cache existed.
///
/// Version history:
///   1.0 — Session 2026-06-09: initial implementation (Phase 3a fast document opens)
public actor DocumentASTCache {

    /// Cached ASTs keyed by `"volumeId/documentId"`.
    private var storage: [String: FRUSDocumentAST] = [:]

    /// LRU order — least-recently-used first, most-recently-used last.
    private var order: [String] = []

    /// Maximum number of cached documents.
    private let capacity: Int

    /// Creates a cache holding up to `capacity` document ASTs.
    ///
    /// - Parameter capacity: LRU bound. Default 24.
    public init(capacity: Int = 24) {
        self.capacity = capacity

        // Empty the cache when the system is under memory pressure. The observer
        // fires on the main thread; hop onto the actor via an unstructured Task.
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { await self.removeAll() }
        }
        #endif
    }

    /// Returns the cached AST for a document, refreshing its LRU position.
    public func ast(volumeId: String, documentId: String) -> FRUSDocumentAST? {
        let key = "\(volumeId)/\(documentId)"
        guard let hit = storage[key] else { return nil }
        touch(key)
        return hit
    }

    /// Inserts a window of parsed documents from one volume, evicting the
    /// least-recently-used entries beyond capacity.
    ///
    /// Callers should pass a bounded slice (e.g. the last few documents of a parse
    /// window), not an entire volume.
    public func store(_ documents: [FRUSDocumentAST], volumeId: String) {
        for doc in documents {
            let key = "\(volumeId)/\(doc.documentId)"
            storage[key] = doc
            touch(key)
        }
        while order.count > capacity, let evict = order.first {
            order.removeFirst()
            storage.removeValue(forKey: evict)
        }
    }

    /// Removes every cached AST (memory-warning response and volume deletion).
    public func removeAll() {
        storage.removeAll()
        order.removeAll()
    }

    /// Removes cached ASTs belonging to one volume (called when a volume file is
    /// deleted or re-indexed so stale content is never served).
    public func removeVolume(_ volumeId: String) {
        let prefix = "\(volumeId)/"
        let stale = order.filter { $0.hasPrefix(prefix) }
        for key in stale {
            storage.removeValue(forKey: key)
        }
        order.removeAll { $0.hasPrefix(prefix) }
    }

    /// Moves `key` to the most-recently-used position.
    private func touch(_ key: String) {
        if let idx = order.firstIndex(of: key) {
            order.remove(at: idx)
        }
        order.append(key)
    }
}
