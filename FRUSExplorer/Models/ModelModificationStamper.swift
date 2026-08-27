// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import SwiftData

// MARK: - LastModifiedStamping

/// A synced model whose `lastModified` decides CloudKit merges.
///
/// Version history:
///   1.0 — M-1 follow-up: initial implementation
protocol LastModifiedStamping: AnyObject {
    /// When the record last changed. `nil` on rows written before the field existed.
    var lastModified: Date? { get set }
}

extension Project: LastModifiedStamping {}
extension Collection: LastModifiedStamping {}
extension ResearchNote: LastModifiedStamping {}
extension GeneratedSummary: LastModifiedStamping {}
extension WorkingCorpus: LastModifiedStamping {}
extension CustomVolumeScope: LastModifiedStamping {}
// Archive Visits Phase 2 — all three plan types merge on `lastModified`, and a frozen stamp
// would let a stale device win every merge (the exact defect this stamper exists for).
extension ArchiveVisitPlan: LastModifiedStamping {}
extension ArchiveVisitDocument: LastModifiedStamping {}
extension ArchiveVisitTarget: LastModifiedStamping {}
// W-5 (#266) — `SavedSearch` predated the stamper and carried no `lastModified` at all, so a
// CloudKit merge fell to `createdAt`: frozen at save time, letting a stale copy win. The field
// exists now (a schema deploy, R-7) and every mutation — a rename, a freshness stamp — bumps it.
extension SavedSearch: LastModifiedStamping {}

// MARK: - ModelModificationStamper

/// Keeps `lastModified` current on every synced model, at save time.
///
/// ## The defect this exists to fix
/// Four models kept `lastModified` current with `didSet` observers — 73 of them. **None of them
/// ever fired.** The `@Model` macro rewrites a stored property into a computed pair backed by the
/// managed store, and a computed property cannot carry a property observer, so the bodies are
/// silently discarded. `ModelLastModifiedTests` measures this on all four, with a control case
/// proving the harness can see a stamp when one really happens.
///
/// The consequence is not cosmetic. `lastModified` is what CloudKit's last-writer-wins resolves on.
/// Frozen at creation, an old copy on a second device wins every merge — restoring entries the
/// researcher deleted and reverting edits — with nothing on screen to say so.
///
/// ## Why a save hook rather than stamping at the call sites
/// The app has 54 save sites and far more mutation sites; `Collection` alone had 47 observers.
/// Stamping by hand at each one is the kind of discipline that holds for a month. A save hook is a
/// single choke point that no mutation can route around, and it costs no schema change — which
/// matters, because reshaping 73 properties would mean a CloudKit deploy for a bug fix.
///
/// ## Why it is safe to mutate here
/// The stamp is applied on `ModelContext.willSave`, before the save commits, and only to models the
/// context already reports as changed. Setting a scalar on an object that is *already* dirty adds
/// no new dirty objects, so it cannot cascade; `isStamping` additionally makes re-entry impossible
/// if a future SwiftData version re-posts the notification during the same save.
///
/// Version history:
///   1.0 — M-1 follow-up: initial implementation
@MainActor
final class ModelModificationStamper {

    /// Guards against re-entry, so a stamp can never trigger the handler that produced it.
    ///
    /// **Insurance, not a tested behaviour.** No test here can falsify it: SwiftData does not re-post
    /// `willSave` during a save on any version measured, so the guard never engages. It is kept
    /// because the cost is a boolean and the failure it prevents — an unbounded save loop rewriting
    /// every synced record — is one the user would experience as the app hanging on iCloud.
    private var isStamping = false
    private var observer: NSObjectProtocol?
    /// The observed context, held as main-actor state so the handler need not receive it — neither
    /// `ModelContext` nor `Notification` is `Sendable`, and capturing either in the closure is a
    /// strict-concurrency error rather than a style question.
    private var observedContext: ModelContext?

    /// Starts stamping saves on `context`.
    ///
    /// Call once, at app start, for the container's main context.
    func start(observing context: ModelContext) {
        stop()
        observedContext = context
        observer = NotificationCenter.default.addObserver(
            forName: ModelContext.willSave, object: context, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let saving = self.observedContext else { return }
                self.stamp(saving)
            }
        }
    }

    /// Stops observing. Idempotent, and the supported teardown: `deinit` is nonisolated and cannot
    /// reach main-actor state, so it cannot do this itself.
    func stop() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        observedContext = nil
    }

    /// Stamps every changed model that carries a `lastModified`.
    ///
    /// Deliberately **not** applied to inserted models: `init` already sets the field, and stamping
    /// an insert would overwrite a deliberate value — a corpus captured with an explicit
    /// `capturedAt`, for instance.
    func stamp(_ context: ModelContext) {
        guard !isStamping else { return }
        isStamping = true
        defer { isStamping = false }

        let now = Date()
        for model in context.changedModelsArray {
            guard let stamping = model as? any LastModifiedStamping else { continue }
            stamping.lastModified = now
        }
    }
}
