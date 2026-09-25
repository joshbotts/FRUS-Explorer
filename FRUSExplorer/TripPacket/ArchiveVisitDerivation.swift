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

// MARK: - ArchiveVisitOverlay

/// A plan's stored per-target state, joined onto a derived ``TripPacketModel`` at render time
/// (Archive-Visit-Plan-Design §2a): tier assignments, exclusions, notes, and the stored-row
/// accounting the coverage report owes.
///
/// A value type the exporter and the editor both read, so the artifact and the screen cannot
/// apply a plan's state differently. The model itself stays a pure derivation from the seeds —
/// state is an overlay HERE, never merged into the model, which is what lets an untouched
/// target keep deriving correctly as volumes index.
///
/// Version history:
///   1.0 — Archive Visits Phase 3: initial implementation
///   1.1 — #1421 review: ``storedKeys`` — a stored row whose key the re-index re-spelled answers
///          for the target it was minted for, and the editor writes through it
struct ArchiveVisitOverlay: Equatable, Sendable {

    /// The plan's tiers, in order. Empty for a plan that never prioritized.
    var tiers: [ArchiveVisitTier] = []
    /// `targetKey` → assigned tier id. A key absent here — or assigned a tier id no longer in
    /// ``tiers`` — is Unprioritized, which always sorts last.
    var tierAssignments: [String: UUID] = [:]
    /// Target keys the user excluded from the rendered packet.
    var excludedKeys: Set<String> = []
    /// `targetKey` → the researcher's note.
    var notes: [String: String] = [:]
    /// How many state rows the plan stores in all.
    var storedKeyCount: Int = 0
    /// Stored keys that no longer derive from the current seeds — kept with their tier and
    /// notes, disclosed by the coverage report, never deleted (the owner's orphan decision).
    var orphanKeys: [String] = []
    /// Derived target key → the key its stored row was minted under, where the two differ
    /// (#1421 review). A row minted before a re-index that only removed spaces from the note it
    /// was keyed on answers for the target it was minted for (``ArchiveVisitTargetKeys``); its own
    /// key is left exactly as it was, so a device still on the older index keeps finding it.
    var storedKeys: [String: String] = [:]

    /// The key the stored row for derived target `key` carries: its ``storedKeys`` entry, or
    /// `key` itself. What a write passes to ``ArchiveVisitPlan/targetState(forKey:resolvedBy:mintIfMissing:in:)``.
    func storedKey(for key: String) -> String {
        storedKeys[key] ?? key
    }

    /// The tier a target key resolves to, or `nil` for Unprioritized (including a dangling
    /// tier id, which reads as Unprioritized — degraded, never crashed).
    func tier(for key: String) -> ArchiveVisitTier? {
        guard let tierId = tierAssignments[key] else { return nil }
        return tiers.first { $0.id == tierId }
    }

    /// The tier's sort position for a target key — its index in ``tiers``, or `Int.max` for
    /// Unprioritized, so the implicit group always sorts last.
    func tierOrderIndex(for key: String) -> Int {
        guard let tier = tier(for: key),
              let index = tiers.firstIndex(of: tier) else { return Int.max }
        return index
    }

    /// The display name for a tier — its label, or the positional fallback the 1c artboard
    /// specifies ("An unlabeled tier reads 'Priority 1'").
    func displayName(for tier: ArchiveVisitTier) -> String {
        if let label = tier.label, !label.isEmpty { return label }
        let position = (tiers.firstIndex(of: tier) ?? 0) + 1
        return String(format: String(localized: "archiveVisit.tier.unnamed %lld",
                                     defaultValue: "Priority %lld"), Int64(position))
    }
}

// MARK: - ArchiveVisitDerivation

/// Derives the rendered state of an ``ArchiveVisitPlan``: the packet model from its seeds
/// through the §5 two-list seam, plus the state overlay and the seed-coverage numbers.
///
/// ONE derivation path — the editor's target list, the export sheet, and the list row's
/// summary all read this, so no two surfaces can disagree about what a plan's targets are.
///
/// Version history:
///   1.0 — Archive Visits Phase 3: initial implementation
///   1.1 — #1366: the always-`nil` `projectResearchQuestionSeed` is retired; the topic sentence
///         is the plan's own `inquiryText`, seeded at creation and refreshed by Re-seed from
///         Project, and nothing seeds it at render time
///   1.2 — #1366 review: Re-seed from Project against a project that no longer exists adds no
///         documents and reports `.unchanged` (the editor no longer offers it then)
///   1.3 — #1421 review: the overlay joins stored rows through `ArchiveVisitTargetKeys.resolve`,
///         so a row whose key the v59 re-index re-spelled is not an orphan; and `targetState`
///         resolves a write through the rendered overlay
///   1.4 — #1421 review, round 2: `targetState`'s `resolvedBy` has no default, so a write site
///         cannot drop it and still compile
@MainActor
enum ArchiveVisitDerivation {

    /// Everything a surface needs to render a plan.
    struct Derived {
        /// The packet model, built from the plan's seeds under its contribution flags, with
        /// the plan's edited inquiry text applied to the topic sentence.
        let model: TripPacketModel
        /// The plan's stored state, joined at render time.
        let overlay: ArchiveVisitOverlay
        /// How many documents seed the plan.
        let seededDocumentCount: Int
        /// How many of those seeds live in volumes indexed on this device — the
        /// `WorkingCorpusResolver` membership rule (by volume, one set lookup per key).
        let indexedDocumentCount: Int
    }

    /// Splits a `"volumeId/documentId"` key into the tuple every pipeline call takes.
    static func documentTuple(fromKey key: String) -> (volumeId: String, documentId: String)? {
        guard let slash = key.firstIndex(of: "/") else { return nil }
        let volumeId = String(key[..<slash])
        let documentId = String(key[key.index(after: slash)...])
        guard !volumeId.isEmpty, !documentId.isEmpty else { return nil }
        return (volumeId: volumeId, documentId: documentId)
    }

    /// Derives a plan's rendered state.
    ///
    /// - Parameters:
    ///   - plan: the plan.
    ///   - indexedVolumeIds: the device's indexed volumes, for the seed-coverage numbers.
    ///   - dataSource: the packet's pipeline seam.
    static func derive(
        plan: ArchiveVisitPlan,
        indexedVolumeIds: Set<String>,
        dataSource: some TripPacketReferenceDataSource
    ) async -> Derived {
        // The seeds, in a stable order so two devices derive identically.
        let seeds = (plan.documents ?? []).sorted { $0.documentKey < $1.documentKey }

        // The §5 projection: contribution flags become two lists AT THE SEAM, and are never
        // threaded through the build loops.
        let sourceDocuments = seeds.filter(\.includeSource)
            .compactMap { documentTuple(fromKey: $0.documentKey) }
        let referenceDocuments = seeds.filter(\.includeExternalRefs)
            .compactMap { documentTuple(fromKey: $0.documentKey) }

        // No seed: a plan's topic is its own `inquiryText`, copied from the project's research
        // question when the plan was made (`ArchiveVisitPlan.make`) and refreshed only by the
        // editor's Re-seed from Project (#1366). Seeding here too would print a question the
        // sheet's field does not show, and would follow a project edit the reader never accepted.
        var model = await TripPacketBuilder.build(
            sourceDocuments: sourceDocuments,
            referenceDocuments: referenceDocuments,
            researchQuestion: nil,
            dataSource: dataSource)
        // The plan's persistent inquiry text is the edited topic sentence — the same slot the
        // ephemeral sheet writes, so the exporter's forExport rule needs no second reader.
        if let inquiryText = plan.inquiryText,
           !inquiryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            model.topicSentence.edited = inquiryText
        }

        // The overlay: stored rows joined by key; a stored key with no derived target is an
        // orphan — kept and disclosed, never deleted. A stored key the re-index re-spelled joins
        // the target it was minted for, under the target's key (#1421 review).
        let derivedKeys = Set(model.targets.map(\.key))
        var overlay = ArchiveVisitOverlay(tiers: plan.tiers)
        let storedRows = plan.targets ?? []
        overlay.storedKeyCount = storedRows.count
        let resolution = ArchiveVisitTargetKeys.resolve(
            storedKeys: Set(storedRows.map(\.targetKey)), derivedKeys: derivedKeys)
        for row in storedRows.sorted(by: { $0.targetKey < $1.targetKey }) {
            let key = resolution[row.targetKey] ?? row.targetKey
            if let tierId = row.tierId { overlay.tierAssignments[key] = tierId }
            if !row.included { overlay.excludedKeys.insert(key) }
            if let note = row.userNote, !note.isEmpty { overlay.notes[key] = note }
            if resolution[row.targetKey] == nil {
                overlay.orphanKeys.append(row.targetKey)
            } else if key != row.targetKey {
                overlay.storedKeys[key] = row.targetKey
            }
        }

        let indexed = seeds.filter { seed in
            guard let volumeId = seed.documentKey.split(separator: "/").first else { return false }
            return indexedVolumeIds.contains(String(volumeId))
        }.count

        return Derived(model: model, overlay: overlay,
                       seededDocumentCount: seeds.count, indexedDocumentCount: indexed)
    }
}

// MARK: - ArchiveVisitTargetKeys

/// Which derived target a stored target key was minted for, when the index's text moved under the
/// key (#1421 review).
///
/// A target key is built from the stored source-note and footnote text (`TripPacketBuilder`'s
/// `targetKey(for:category:)` and `referenceKey(for:)`: `r|<raw text>`, `coll|<repository>|<series>`,
/// the rest from parsed numbers). The v59 re-index removed spaces from that text and nothing else,
/// so a row minted on v58 carries a key the re-indexed plan no longer derives. Measured over the
/// 553 manifest volumes, by replaying both builds' keys for every note the change touched: of 46,049
/// changed source notes, **5,238 move their key only by spaces** (5,014 `r|`, 224 `coll|`), 5 more
/// are foreign-archive series cut at ``IndexingPipeline/foreignArchiveSeriesLength`` characters
/// (the shorter cut is a prefix of the longer), and in the footnote channel 6 `coll|` keys move by
/// spaces alone. 40,690 keep their key.
///
/// **What does not match, on purpose.** 116 notes change target, not spelling: 108 NARA notes whose
/// series the parser can now read (`coll|National Archives|Box 720` becomes the Kissinger staff
/// meeting transcripts' own series), 7 whose subject-numeric class it can now read (`r|…` becomes
/// `class|DEF (MLF) 9-5`), and `frus1964-68v02` d268's RG 330 note. The old key named a bucket the
/// new one does not, and attaching its tier to the corrected unit would be a guess, so those rows
/// stay orphans — kept and disclosed, as a row whose target stopped deriving always has been.
///
/// Keys are never rewritten: a stored row keeps the key it was minted under, and the overlay joins
/// it to the target it names. That is what lets a device still on the older index, or one the row
/// syncs back to, keep finding it, and what keeps the row's derived id stable.
///
/// Version history:
///   1.0 — #1421 review: initial implementation
enum ArchiveVisitTargetKeys {

    /// `key` with every space removed — the form the #1421 re-join cannot change, since it
    /// removed spaces and nothing else.
    static func spacingInsensitive(_ key: String) -> String {
        String(key.unicodeScalars.filter { $0 != " " }.map(Character.init))
    }

    /// Whether the stored key `stored` names the target derived as `derived`, across a re-index
    /// that only removed spaces from the note both were built from.
    ///
    /// Equal keys, keys equal once spaces are removed, or two `coll|` keys whose series were cut
    /// at ``IndexingPipeline/foreignArchiveSeriesLength`` characters where the shorter, once spaces
    /// are removed, begins the longer: the cut takes more of the printed text once its spaces are
    /// gone, so the two agree only as far as the shorter reaches.
    static func sameTarget(stored: String, derived: String) -> Bool {
        if stored == derived { return true }
        let a = spacingInsensitive(stored), b = spacingInsensitive(derived)
        if a == b { return true }
        let (short, long) = a.count <= b.count ? (stored, b) : (derived, a)
        guard short.hasPrefix("coll|"), long.hasPrefix("coll|"),
              let series = short.split(separator: "|", maxSplits: 2,
                                       omittingEmptySubsequences: false).dropFirst(2).first,
              series.count == IndexingPipeline.foreignArchiveSeriesLength else { return false }
        return long.hasPrefix(spacingInsensitive(short))
    }

    /// Each stored key's derived target: itself when it still derives, otherwise the one derived
    /// key it ``sameTarget(stored:derived:)``s — and nothing when that is ambiguous.
    ///
    /// An exact match always wins, and a derived key another stored row matches exactly is not
    /// offered to anyone else. A stored key that matches two derived keys, or a derived key two
    /// stored keys match, resolves for none of them: which row a target's tier comes from must
    /// never be a guess, and an unresolved row is an orphan, which the plan discloses.
    ///
    /// - Parameters:
    ///   - storedKeys: The plan's stored `ArchiveVisitTarget.targetKey`s.
    ///   - derivedKeys: The keys of the targets the plan derives now.
    /// - Returns: Stored key → derived key, for every stored key that resolves.
    static func resolve(storedKeys: Set<String>, derivedKeys: Set<String>) -> [String: String] {
        var resolved: [String: String] = [:]
        for key in storedKeys where derivedKeys.contains(key) { resolved[key] = key }
        let open = derivedKeys.subtracting(resolved.keys)
        var candidate: [String: String] = [:]
        var claimants: [String: Int] = [:]
        for stored in storedKeys.sorted() where resolved[stored] == nil {
            let matches = open.filter { sameTarget(stored: stored, derived: $0) }
            guard matches.count == 1, let match = matches.first else { continue }
            candidate[stored] = match
            claimants[match, default: 0] += 1
        }
        for (stored, match) in candidate where claimants[match] == 1 { resolved[stored] = match }
        return resolved
    }
}

// MARK: - ArchiveVisitTopicReseed

/// What Re-seed from Project did, or proposes to do, to a plan's inquiry topic (#1366).
///
/// The topic is copied from the project's research question once, when the plan is created
/// (``ArchiveVisitPlan/make(name:activeProject:)``); Re-seed from Project is the one explicit way
/// to offer the project's CURRENT question again — "an explicit re-seed, never a live mirror".
/// It fills an empty topic, leaves one that already reads the question, and otherwise asks. It asks
/// even when the topic is only the question as it stood at creation: the plan keeps no record of
/// what it was seeded with, so that topic and one the reader rewrote look the same, and asking is
/// the side of the ambiguity that loses nothing.
enum ArchiveVisitTopicReseed: Equatable, Sendable {
    /// Nothing was written: the project has no research question, or the topic already reads
    /// it — or the project no longer exists, when Re-seed adds no documents either.
    case unchanged
    /// The topic was empty, and now holds the project's question.
    case filled(question: String)
    /// The topic holds other text, and nothing was written. The caller asks, and on the reader's
    /// yes calls ``ArchiveVisitPlan/replaceInquiryTopic(with:)``.
    case needsConfirmation(question: String, current: String)
}

// MARK: - Plan state mutation

extension ArchiveVisitPlan {

    /// Offers the project's current research question to this plan's topic — the decision
    /// behind Re-seed from Project's second half (#1366; the rule is ``ArchiveVisitTopicReseed``'s).
    /// Writes only into an empty topic; text of the reader's own is never replaced here.
    /// The caller saves.
    ///
    /// - Parameter question: the project's research question as it stands now.
    func reseedTopic(fromProjectQuestion question: String?) -> ArchiveVisitTopicReseed {
        guard let question = TripPacketTopicSentence.written(question) else { return .unchanged }
        guard let current = TripPacketTopicSentence.written(inquiryText) else {
            inquiryText = question
            return .filled(question: question)
        }
        if TripPacketTopicSentence.sameText(current, question) { return .unchanged }
        return .needsConfirmation(question: question, current: current)
    }

    /// Replaces the topic with the project's question — the confirmed half of
    /// ``ArchiveVisitTopicReseed/needsConfirmation(question:current:)``. The caller saves.
    func replaceInquiryTopic(with question: String) {
        inquiryText = question
    }

    /// 1e's explicit Re-seed from Project: adds the project's CURRENT leads union as new seeds
    /// (both contributions on, never removing anything — a mirror would silently erase choices),
    /// then offers the project's current research question to the topic through
    /// ``reseedTopic(fromProjectQuestion:)`` (#1366). Before #1366 it moved documents only, so a
    /// question written after the plan was made could never reach it.
    ///
    /// A project that no longer exists changes nothing and reports `.unchanged` (#1366 review): a
    /// deleted project's notes and collections keep its id — "kept but unlinked", per the delete
    /// confirmation — so gathering over that id would re-seed from records the reader was told
    /// had left the project. The editor offers no Re-seed then; this holds for a menu drawn
    /// before the delete.
    ///
    /// The caller saves, and asks the reader on
    /// ``ArchiveVisitTopicReseed/needsConfirmation(question:current:)``.
    @MainActor
    func reseed(fromProject projectId: UUID, in context: ModelContext) async
        -> ArchiveVisitTopicReseed {
        guard let project = Self.project(withId: projectId, in: context) else { return .unchanged }
        // Read before the await: the project is not touched again after it.
        let question = project.researchQuestion
        let keys = await ProjectLeadsService.gatherSeed(
            forProject: projectId, container: context.container).seedKeys
        let documents = keys.compactMap { DocumentKey(compositeString: $0)?.tuple }
        addSeeds(documents, includeSource: true, includeExternalRefs: true, in: context)
        return reseedTopic(fromProjectQuestion: question)
    }

    /// Renames the plan. `lastModified` is stamped at save time by `ModelModificationStamper`.
    func rename(to newName: String) {
        name = newName
    }

    /// The stored state row for a target key, minting one when `mint` and none exists —
    /// the §2a overlay rule: a row exists only once the user gives the target state, and
    /// its id is DERIVED so two devices minting the same row create a collapsible pair.
    ///
    /// `overlay` is the one the caller rendered from. Through its ``ArchiveVisitOverlay/storedKeys``
    /// a target whose row was minted under a key the re-index re-spelled finds that row (#1421
    /// review); without it the lookup minted a second row beside it, and the target's tier and
    /// note stayed on the first. A new row is minted under the target's current key. The parameter
    /// has no default (#1421 review, round 2): the editor's four write sites are covered by no test,
    /// so a site that dropped it would still compile and would mint the duplicate again. Pass `nil`
    /// only where nothing has been rendered yet.
    ///
    /// The caller saves the context.
    func targetState(forKey key: String, resolvedBy overlay: ArchiveVisitOverlay?,
                     mintIfMissing mint: Bool,
                     in context: ModelContext) -> ArchiveVisitTarget? {
        let storedKey = overlay?.storedKey(for: key) ?? key
        if let existing = (targets ?? []).first(where: { $0.targetKey == storedKey }) {
            return existing
        }
        guard mint else { return nil }
        let row = ArchiveVisitTarget(planId: id, targetKey: key)
        row.plan = self
        context.insert(row)
        return row
    }

    /// Adds seeds to the plan — the one write path every add flow shares.
    ///
    /// Upserts by derived id: a document already seeded gains the requested contributions
    /// (flags turn ON, never off — adding "references" from Source Explorer must not silently
    /// switch off a source contribution another surface added), and a new document mints its
    /// row with exactly the requested flags. Returns how many NEW seed rows were minted.
    /// The caller saves the context.
    @discardableResult
    func addSeeds(_ documents: [(volumeId: String, documentId: String)],
                  includeSource: Bool, includeExternalRefs: Bool,
                  in context: ModelContext) -> Int {
        guard includeSource || includeExternalRefs else { return 0 }
        var existingByKey = Dictionary((self.documents ?? []).map { ($0.documentKey, $0) },
                                       uniquingKeysWith: { first, _ in first })
        var minted = 0
        for document in documents {
            let key = "\(document.volumeId)/\(document.documentId)"
            if let existing = existingByKey[key] {
                if includeSource { existing.includeSource = true }
                if includeExternalRefs { existing.includeExternalRefs = true }
                continue
            }
            let seed = ArchiveVisitDocument(planId: id, documentKey: key)
            seed.plan = self
            seed.includeSource = includeSource
            seed.includeExternalRefs = includeExternalRefs
            context.insert(seed)
            existingByKey[key] = seed
            minted += 1
        }
        return minted
    }
}
