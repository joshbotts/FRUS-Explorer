// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CoreData
import Foundation
import SwiftData

// MARK: - StoreSchemaDiagnostic

/// Names the difference between the record types an on-disk SwiftData store was created with and
/// the ones this build declares in ``ModelContainer/frusModelTypes``.
///
/// ## Why this exists
/// On 2026-07-25 the dev Mac's `default.store` stopped opening. `ModelContainer` init threw
/// `SwiftDataError.internalError`, the app fell back to `FRUSExplorerLocal.store` — which was
/// empty — and ran that way for **31 consecutive launches over four days**. Nothing was lost, but
/// nothing synced either, a bulk summarization run started on another Mac never arrived, and the
/// only signal anywhere was a small orange "Local Only" chip in the status bar. That chip is
/// correct and completely insufficient: on a machine that rebuilds the app every few minutes it
/// reads as ordinary launch noise.
///
/// The eventual diagnosis took a `sqlite3` session against `Z_METADATA` and a hand comparison of
/// its `NSStoreModelVersionHashes` keys against `frusModelTypes`: the store had been created by a
/// build with **12** record types and this one declared **19**. That comparison is two sets and a
/// subtraction, so the app can do it itself, at the moment of failure, and say the words.
///
/// ## What it can and cannot conclude
/// It reports *evidence*, not a verdict. A store whose record types differ from the running
/// build's is the ordinary cause of an init failure on a developer machine that runs many
/// different builds against one store, and ``summary`` says so in those terms. It does not claim
/// to be the cause: an init failure with a *matching* record-type list is a different problem
/// (entitlement, account, a genuinely corrupt file), and in that case ``isMismatch`` is `false`
/// and the diagnostic says only that the lists agree — which is itself the useful finding,
/// because it rules this class out.
///
/// ## Reading the store without opening it
/// `NSPersistentStoreCoordinator.metadataForPersistentStore(type:at:)` reads the metadata table
/// only. It does not open the store for use, does not migrate it, and does not care that the
/// running model disagrees with it — which is the entire point, since the disagreement is what we
/// are trying to measure. It is also safe on the failure path specifically because the failure
/// means nothing holds the file.
///
/// Version history:
///   1.0 — the guard, after the 2026-07-25 four-day silent fallback
struct StoreSchemaDiagnostic: Sendable, Equatable {

    /// File name of the store inspected, e.g. `"default.store"` — the store's identity in every
    /// place an owner would look for it (Finder, a `sqlite3` invocation, this app's log).
    let storeName: String

    /// Record types the store was created with, sorted. Read from the store's
    /// `NSStoreModelVersionHashes` metadata.
    let storeEntityNames: [String]

    /// Record types this build declares, sorted. Derived from a `Schema` over
    /// ``ModelContainer/frusModelTypes``, so it cannot drift from what the app actually asks for.
    let modelEntityNames: [String]

    /// Record types this build declares that the store has never held.
    ///
    /// A non-empty list means the store predates this build. This is the direction that fails: the
    /// store must be migrated forward, and under CloudKit mirroring not every migration is legal.
    var missingFromStore: [String] {
        let known = Set(storeEntityNames)
        return modelEntityNames.filter { !known.contains($0) }
    }

    /// Record types the store holds that this build no longer declares.
    ///
    /// A non-empty list means the store was written by a *newer* build than this one — the shape
    /// of running an older branch after a newer one, where the risk is the reverse (this build
    /// cannot see data that is really there).
    var absentFromModel: [String] {
        let declared = Set(modelEntityNames)
        return storeEntityNames.filter { !declared.contains($0) }
    }

    /// `true` when the two lists differ in either direction.
    var isMismatch: Bool { !missingFromStore.isEmpty || !absentFromModel.isEmpty }

    /// One paragraph naming the difference, for the status-bar tooltip, the Settings row, and the
    /// debug alert.
    ///
    /// Written to be pasteable into a bug report: it carries the counts, the direction, and the
    /// actual record-type names, because the names are what turn "sync is broken" into a
    /// one-line diagnosis.
    var summary: String {
        guard isMismatch else {
            return String(
                localized: "storeSchema.summary.match",
                defaultValue: "\(storeName) holds the same \(storeEntityNames.count) record types this build declares, so a stale store is not the cause of this failure."
            )
        }
        var parts: [String] = [
            String(
                localized: "storeSchema.summary.counts",
                defaultValue: "\(storeName) was created with \(storeEntityNames.count) record types; this build declares \(modelEntityNames.count)."
            )
        ]
        if !missingFromStore.isEmpty {
            parts.append(String(
                localized: "storeSchema.summary.missing",
                defaultValue: "Not in the store: \(missingFromStore.joined(separator: ", "))."
            ))
        }
        if !absentFromModel.isEmpty {
            parts.append(String(
                localized: "storeSchema.summary.extra",
                defaultValue: "In the store but not in this build: \(absentFromModel.joined(separator: ", ")). This store was written by a newer build."
            ))
        }
        parts.append(String(
            localized: "storeSchema.summary.consequence",
            defaultValue: "This usually happens when your stored data does not match the build you are running. The data is safe, and iCloud still has its copy. This build cannot open it, so it is using a separate local store. Nothing you do here will sync."
        ))
        return parts.joined(separator: " ")
    }

    // MARK: - Diagnosis

    /// Compares the record types in the store at `storeURL` against `modelEntityNames`.
    ///
    /// Returns `nil` when there is nothing to compare — the file does not exist (a first launch,
    /// or a store that was just reset), or its metadata carries no version hashes. `nil` means
    /// "no finding", never "no mismatch"; the two are different answers and the caller must not
    /// conflate them.
    ///
    /// - Parameters:
    ///   - storeURL: the store to inspect. Not opened — only its metadata table is read.
    ///   - modelEntityNames: the record types the running build declares. Pass
    ///     `Schema(ModelContainer.frusModelTypes).entities.map(\.name)`.
    static func diagnose(storeURL: URL, modelEntityNames: [String]) -> StoreSchemaDiagnostic? {
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return nil }
        let metadata: [String: Any]
        do {
            metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                type: .sqlite, at: storeURL
            )
        } catch {
            // A store too damaged to yield metadata is a different failure, and one this type
            // has nothing to say about. Report no finding rather than an empty entity list,
            // which would read as "the store declares nothing" — a claim we cannot make.
            print("[StoreSchema] Could not read metadata for \(storeURL.lastPathComponent): \(error)")
            return nil
        }
        guard let hashes = metadata[NSStoreModelVersionHashesKey] as? [String: Any],
              !hashes.isEmpty else { return nil }
        return StoreSchemaDiagnostic(
            storeName: storeURL.lastPathComponent,
            storeEntityNames: hashes.keys.sorted(),
            modelEntityNames: modelEntityNames.sorted()
        )
    }
}
