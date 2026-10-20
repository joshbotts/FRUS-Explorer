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
///   1.2 — decision 62 (A15): ``superseded`` — a stored row that answers for a target another
///          stored row is shown on, kept and listed with its own tier, note and exclusion
struct ArchiveVisitOverlay: Equatable, Sendable {

    /// A stored row that answers for a derived target another stored row is shown on (decision
    /// 62): two targets the reader had set became one, or a row re-spelled beside one minted on the
    /// new spelling. Its tier and note are kept under its own key, in ``tierAssignments`` and
    /// ``notes``, and none of its state is applied to the target.
    struct Superseded: Equatable, Sendable {
        /// The derived target it answers for.
        let targetKey: String
        /// Whether the row excludes its target from the packet — not applied, since the target
        /// follows the row it shows.
        let excluded: Bool
    }

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
    /// The stored rows that answer for a target another stored row is shown on, by their own
    /// stored key (decision 62): kept, listed under Stored targets with the orphans, never deleted,
    /// and written there by their own key. Which row a target shows is
    /// ``ArchiveVisitTargetKeys/shownRow(among:answeringFor:)``'s rule.
    var superseded: [String: Superseded] = [:]

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
///   1.5 — #1456: ``inputSignature(plan:indexedVolumeIds:)``, what ``derive(plan:indexedVolumeIds:dataSource:)``
///         reads from the plan and which of its seeds' volumes are indexed, as one value, so the editor
///         re-derives when a write from anywhere else changes it
///   1.6 — #1456 review, round 1: the signature's doc names what it does not carry (the index's
///         content, so a re-index of a volume already indexed does not move it) and what it costs; the
///         Archives Visits list's row keys its summary on it too; and Re-seed from Project saves before
///         it gathers, as Project Home's engaged set does (#1457)
///   1.7 — decision 62 (A15): the overlay joins a key on a note's text to the target the note sits
///         in now, and a target several stored rows answer for shows one of them and keeps the rest
///         as `superseded`; the signature carries each row's creation date and id, which that choice
///         reads
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

    /// What ``derive(plan:indexedVolumeIds:dataSource:)`` reads from the plan, and which of the plan's
    /// seed volumes are indexed on this device, as one value (#1456).
    ///
    /// The editor keys its derivation on this, and the Archives Visits list's row its summary, so a
    /// write they did not make re-derives them: seeds added from another window through
    /// `PlanPickerSheet.add(to:)`, a seed's flag turned off, and a seed's volume that finishes
    /// indexing while the screen is open. The editor's own counter moved only on its own writes, so
    /// its list stayed on the derivation of the plan as it was — reading "No targets derive from
    /// these documents" over a plan with six. A write that arrives through iCloud moves the signature
    /// too, but a screen reads it only if SwiftData's model observation reports the merged rows to the
    /// view's body, and nothing here has checked that it does.
    ///
    /// **Everything the derivation reads from the plan, and nothing it does not.** A field left out
    /// is a write that leaves the screen stale; a field put in re-derives for nothing. The plan's name
    /// is not here because the derivation never reads it, and neither is an indexed volume no seed is
    /// in, because a volume only changes what derives when a seed lives in it. Change the two
    /// together: a new read of the plan in `derive` belongs here in the same commit.
    ///
    /// **What it does not carry is the index's content.** `derive` also reads each seed's source
    /// note and footnotes through its data source, and the caller's data source reads the manifest.
    /// The one index change the signature sees is a seed's volume joining or leaving the indexed set.
    /// A volume indexed AGAIN while it is already in the set — a volume update, say — leaves the set
    /// as it was (`AppState` inserts an id already present), so the signature does not move, and a
    /// screen open across that re-index keeps the derivation it had until it is reopened or the plan
    /// changes.
    struct InputSignature: Hashable, Sendable {

        /// One seed as the derivation reads it: its key and its two contribution flags.
        struct Seed: Hashable, Sendable {
            /// The seed's `"volumeId/documentId"` key.
            let documentKey: String
            /// Whether its own source note contributes (the drawn-from channel).
            let includeSource: Bool
            /// Whether its footnotes' citations contribute (the pointed-at channel).
            let includeExternalRefs: Bool
        }

        /// One stored state row as the overlay reads it.
        struct StoredTarget: Hashable, Sendable {
            /// The key the row was minted under.
            let targetKey: String
            /// The tier it is assigned to, or `nil`.
            let tierId: UUID?
            /// Whether the target stays in the packet.
            let included: Bool
            /// The researcher's note.
            let userNote: String?
            /// When the row was created, and its id: which of several rows answering for one
            /// target the target shows (`ArchiveVisitTargetKeys.shownRow`, decision 62).
            let createdAt: Date?
            let id: UUID
        }

        /// The plan's seed rows, each with how many rows carry it. Counted rather than a set, since
        /// the derivation counts rows (`seededDocumentCount`) and two devices minting one seed leave
        /// two until the pair collapses; unordered, since the derivation sorts them itself.
        let seeds: [Seed: Int]
        /// The plan's inquiry text, as stored.
        let inquiryText: String?
        /// The plan's tiers, in order: the overlay takes the list whole.
        let tiers: [ArchiveVisitTier]
        /// The plan's stored state rows, counted for the same reason as ``seeds``: the overlay
        /// reports how many rows the plan stores (`storedKeyCount`).
        let targets: [StoredTarget: Int]
        /// The volumes the seeds live in that are indexed on this device — the indexed set
        /// intersected with the seeds' own volumes, never the whole set.
        let indexedSeedVolumes: Set<String>
    }

    /// The ``InputSignature`` of `plan` on a device whose indexed volumes are `indexedVolumeIds`.
    ///
    /// Computed in a view body, on every pass of it: the editor's and each Archives Visits list
    /// row's. Linear in the plan's rows — one pass reading three attributes of every seed row and
    /// six of every state row (four when the timings below were taken; A15 added the row's
    /// creation date and id), one decode of the tier list, and two dictionaries, which SwiftUI
    /// then compares with the previous key's. On the Targets tab this is more than the body read
    /// before: it walked the seeds only when no target derived. Measured on the iPhone 17 simulator
    /// (iOS 26.4) over an in-memory store, the median of ten passes after the first: 1.6 ms for 500
    /// seeds and 50 state rows, 11.9 ms for 5,000 and 200, and 45 ms for 20,000 and 500 — the size a
    /// unit-grain seed can reach — plus 0.06, 0.41 and 2.2 ms for the comparison. So a plan of a few
    /// hundred seeds costs a millisecond or two a pass, and one of 20,000 costs about three frames at
    /// 60 Hz on every pass, which on iOS includes each keystroke in the editor's name field. A device
    /// and an on-disk store were not measured.
    ///
    /// - Parameters:
    ///   - plan: the plan.
    ///   - indexedVolumeIds: the device's indexed volumes — the set ``derive(plan:indexedVolumeIds:dataSource:)`` is passed.
    static func inputSignature(plan: ArchiveVisitPlan, indexedVolumeIds: Set<String>) -> InputSignature {
        let seedRows = plan.documents ?? []
        var seeds: [InputSignature.Seed: Int] = [:]
        var seedVolumes = Set<String>()
        for row in seedRows {
            seeds[InputSignature.Seed(documentKey: row.documentKey, includeSource: row.includeSource,
                                      includeExternalRefs: row.includeExternalRefs), default: 0] += 1
            if let volumeId = volumeId(ofSeedKey: row.documentKey) { seedVolumes.insert(volumeId) }
        }
        var targets: [InputSignature.StoredTarget: Int] = [:]
        for row in plan.targets ?? [] {
            targets[InputSignature.StoredTarget(targetKey: row.targetKey, tierId: row.tierId,
                                                included: row.included, userNote: row.userNote,
                                                createdAt: row.createdAt, id: row.id), default: 0] += 1
        }
        return InputSignature(seeds: seeds, inquiryText: plan.inquiryText, tiers: plan.tiers,
                              targets: targets, indexedSeedVolumes: seedVolumes.intersection(indexedVolumeIds))
    }

    /// The volume a seed's `"volumeId/documentId"` key lives in — the one rule both the derivation's
    /// seed coverage and ``inputSignature(plan:indexedVolumeIds:)`` read a seed's volume by, so the
    /// two cannot disagree about which indexed volumes a plan depends on.
    static func volumeId(ofSeedKey key: String) -> String? {
        key.split(separator: "/").first.map(String.init)
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
    /// Everything this reads from the plan, and which seed volumes are indexed, is in
    /// ``InputSignature``, which the editor and the list's row key their derivation on (#1456); a new
    /// read of the plan here belongs there too. What it reads from the index through `dataSource` is
    /// not in it (see there).
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
        // packet sheet's field writes, so the exporter's forExport rule needs no second reader.
        if let inquiryText = plan.inquiryText,
           !inquiryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            model.topicSentence.edited = inquiryText
        }

        // The overlay: stored rows joined by key; a stored key with no derived target is an
        // orphan — kept and disclosed, never deleted. A stored key the re-index re-spelled joins
        // the target it was minted for, under the target's key (#1421 review), and a key on a
        // note's text joins the target the note sits in now (decision 62). A target several rows
        // answer for shows one (`ArchiveVisitTargetKeys.shownRow`); the others are kept, listed
        // and written by their own keys (`ArchiveVisitOverlay.superseded`).
        let derivedKeys = Set(model.targets.map(\.key))
        var overlay = ArchiveVisitOverlay(tiers: plan.tiers)
        let storedRows = (plan.targets ?? []).sorted(by: { $0.targetKey < $1.targetKey })
        overlay.storedKeyCount = storedRows.count
        let resolution = ArchiveVisitTargetKeys.resolve(
            storedKeys: Set(storedRows.map(\.targetKey)), derivedKeys: derivedKeys,
            textKeys: ArchiveVisitTargetKeys.textKeys(of: model.targets))
        func apply(_ row: ArchiveVisitTarget, under key: String, excluding: Bool) {
            if let tierId = row.tierId { overlay.tierAssignments[key] = tierId }
            if excluding, !row.included { overlay.excludedKeys.insert(key) }
            if let note = row.userNote, !note.isEmpty { overlay.notes[key] = note }
        }
        var answering: [String: [ArchiveVisitTarget]] = [:]
        for row in storedRows {
            guard let key = resolution[row.targetKey] else {
                apply(row, under: row.targetKey, excluding: true)
                overlay.orphanKeys.append(row.targetKey)
                continue
            }
            answering[key, default: []].append(row)
        }
        for (key, rows) in answering {
            guard let shown = ArchiveVisitTargetKeys.shownRow(among: rows, answeringFor: key)
            else { continue }
            apply(shown, under: key, excluding: true)
            if shown.targetKey != key { overlay.storedKeys[key] = shown.targetKey }
            // A copy of the shown row's own key (two devices' rows, before the duplicate cleanup
            // collapses them) is the same row, and is neither applied nor listed.
            for row in rows where row.targetKey != shown.targetKey {
                apply(row, under: row.targetKey, excluding: false)
                overlay.superseded[row.targetKey] = .init(targetKey: key, excluded: !row.included)
            }
        }

        let indexed = seeds.filter { seed in
            guard let volumeId = volumeId(ofSeedKey: seed.documentKey) else { return false }
            return indexedVolumeIds.contains(volumeId)
        }.count

        return Derived(model: model, overlay: overlay,
                       seededDocumentCount: seeds.count, indexedDocumentCount: indexed)
    }
}

// MARK: - ArchiveVisitTargetKeys

/// Which derived target a stored target key was minted for, when the index's text or the rule that
/// keys a note moved under the key (#1421 review, index version 69, decision 62).
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
/// `class|DEF (MLF) 9-5`), and `frus1964-68v02` d268's RG 330 note, a central-files note the
/// index keyed `330` (its record group's number) until the parser read the records centre's
/// citation. A `coll|` or `class|` key names a bucket of notes, and where the new key names another
/// bucket, attaching the old one's tier to it would be a guess, so the 108 rows and d268's stay
/// orphans — kept and disclosed, as a row whose target stopped deriving always has been. The 7
/// were orphans by the same rule until decision 62 (below), and join.
///
/// Keys are never rewritten: a stored row keeps the key it was minted under, and the overlay joins
/// it to the target it names. That is what lets a device still on the older index, or one the row
/// syncs back to, keep finding it, and what keeps the row's derived id stable.
///
/// **Index version 69 moved 437 more keys**, by a change of grammar and not of text (measured over
/// the 198,347 stored notes this builder keys as a central file, each read by the kit before the
/// change and after it; no key went from `class|` to `r|`):
/// - **27 are the same file with its dash back** (`class|POL 1 US USSR` is `class|POL 1 US-USSR`;
///   13 files). The class grammar had dropped a dash that a space followed. They join, by
///   ``sameTarget(stored:derived:)``'s third rule.
/// - **410 gain a class** (`r|Source: Department of State, Central Files, PR 11 Saigon. …` becomes
///   `class|PR 11 SAIGON`; 151 files in 33 volumes). They were orphans until decision 62, and join
///   by their notes' text.
///
/// **A key on a note's text follows the note (decision 62, A15).** An `r|` key names one source
/// note or footnote citation by its text, so where that text sits in a target keyed otherwise now
/// — the note gives a class the packet once could not read, or a lot or a place — the row answers
/// for that target (``textKeys(of:)``), read exactly and then once spaces are removed, as the first
/// rule reads keys. A15 keys a Department-worded central file by the class the index stores for it,
/// which moves the keys of 688 notes the citation scan reads no class from, in 39 volumes (files
/// with no subject number, and classifications run on; measured over a full v69 index, 2026-10-20,
/// where no other key moved); a later index version that stores a class for more notes moves their
/// keys the same way. What the rule cannot follow is a class whose own spelling changes: no note's
/// text names the old class, and only the dash rule joins two classes.
///
/// **Several rows can answer for one target** since decision 62: a target that had a row of its
/// own and a note whose row now follows it there, two notes of one file that each had a row, or a
/// re-spelled row beside one minted on the new spelling. The target shows one of them
/// (``shownRow(among:answeringFor:)``), and the others are kept with their tier, note and exclusion,
/// unapplied, listed under Stored targets (``ArchiveVisitOverlay/superseded``), never deleted.
///
/// Version history:
///   1.0 — #1421 review: initial implementation
///   1.1 — index version 69: a class key that got its dash back joins the key that had lost it
///   1.2 — decision 62 (A15): a key on a note's text joins the target the note sits in now
///          (``textKeys(of:)``), several stored keys may resolve to one derived key, and the target
///          shows one row of them (``shownRow(among:answeringFor:)``)
enum ArchiveVisitTargetKeys {

    /// `key` with every space removed — the form the #1421 re-join cannot change, since it
    /// removed spaces and nothing else.
    static func spacingInsensitive(_ key: String) -> String {
        String(key.unicodeScalars.filter { $0 != " " }.map(Character.init))
    }

    /// Whether the stored key `stored` names the target derived as `derived`, across a re-index
    /// that only removed spaces from the note both were built from.
    ///
    /// Equal keys, keys equal once spaces are removed, two `class|` keys that differ only where
    /// one has a hyphen and the other a space, or two `coll|` keys whose series were cut
    /// at ``IndexingPipeline/foreignArchiveSeriesLength`` characters where the shorter, once spaces
    /// are removed, begins the longer: the cut takes more of the printed text once its spaces are
    /// gone, so the two agree only as far as the shorter reaches.
    ///
    /// The `class|` rule is index version 69's: `POL 1 US - USSR` was stored as `POL 1 US USSR`
    /// and is `POL 1 US-USSR`. It is read character for character, so two keys of different
    /// lengths never join by it (`DEF 1-1 US` is not `DEF 11 US`), and either way round, for a row
    /// minted on version 69 and read by a device still on 68.
    static func sameTarget(stored: String, derived: String) -> Bool {
        if stored == derived { return true }
        let a = spacingInsensitive(stored), b = spacingInsensitive(derived)
        if a == b { return true }
        // One prefix test covers both keys: the rule reads character for character and `class|`
        // holds neither mark, so a key that passes against a class key begins as it does.
        if stored.hasPrefix("class|"), stored.count == derived.count,
           zip(stored, derived).allSatisfy({ one, other in
               one == other || (one == " " && other == "-") || (one == "-" && other == " ")
           }) {
            return true
        }
        let (short, long) = a.count <= b.count ? (stored, b) : (derived, a)
        guard short.hasPrefix("coll|"), long.hasPrefix("coll|"),
              let series = short.split(separator: "|", maxSplits: 2,
                                       omittingEmptySubsequences: false).dropFirst(2).first,
              series.count == IndexingPipeline.foreignArchiveSeriesLength else { return false }
        return long.hasPrefix(spacingInsensitive(short))
    }

    /// Each key a target's seedings would carry were they keyed on their text — `r|` and a
    /// drawn-from document's source note, or a footnote citation's text — to the derived targets
    /// holding such a seeding (decision 62). What ``resolve(storedKeys:derivedKeys:textKeys:)``
    /// reads a stored `r|` key's note by.
    static func textKeys(of targets: [TripPacketModel.Target]) -> [String: Set<String>] {
        var keys: [String: Set<String>] = [:]
        for target in targets {
            for document in target.drawnFrom {
                keys["r|" + document.sourceNote, default: []].insert(target.key)
            }
            for seeding in target.pointedAt {
                keys["r|" + seeding.rawText, default: []].insert(target.key)
            }
        }
        return keys
    }

    /// Each stored key's derived target: itself when it still derives; else, for a key on a note's
    /// text, the one target that text sits in now; else the one derived key it
    /// ``sameTarget(stored:derived:)``s or whose seedings' text it equals once spaces are removed —
    /// and nothing when that is ambiguous.
    ///
    /// A stored key that names two derived keys resolves to neither: which target a row's state
    /// lands on must never be a guess, and an unresolved row is an orphan, which the plan
    /// discloses. Several stored keys may resolve to one derived key (decision 62): which of their
    /// rows the target shows is ``shownRow(among:answeringFor:)``'s rule, and the others are kept and
    /// listed. Until A15 a derived key two stored keys matched resolved for neither, and an exact
    /// match took its derived key from every other stored key, so a row re-spelled beside one
    /// minted on the new spelling was an orphan.
    ///
    /// - Parameters:
    ///   - storedKeys: The plan's stored `ArchiveVisitTarget.targetKey`s.
    ///   - derivedKeys: The keys of the targets the plan derives now.
    ///   - textKeys: ``textKeys(of:)`` over those targets.
    /// - Returns: Stored key → derived key, for every stored key that resolves.
    static func resolve(storedKeys: Set<String>, derivedKeys: Set<String>,
                        textKeys: [String: Set<String>] = [:]) -> [String: String] {
        let textKeysWithoutSpaces = textKeys.reduce(into: [String: Set<String>]()) { keys, entry in
            keys[spacingInsensitive(entry.key), default: []].formUnion(entry.value)
        }
        var resolved: [String: String] = [:]
        for stored in storedKeys {
            if derivedKeys.contains(stored) {
                resolved[stored] = stored
                continue
            }
            let isTextKey = stored.hasPrefix("r|")
            // The note the key names, read exactly: where it sits now (decision 62).
            if isTextKey, let holders = textKeys[stored], holders.count == 1, let holder = holders.first {
                resolved[stored] = holder
                continue
            }
            var matches = derivedKeys.filter { sameTarget(stored: stored, derived: $0) }
            if isTextKey {
                matches.formUnion(textKeysWithoutSpaces[spacingInsensitive(stored)] ?? [])
            }
            if matches.count == 1, let match = matches.first { resolved[stored] = match }
        }
        return resolved
    }

    /// The stored row a derived target shows, of the rows that answer for it (decision 62): the
    /// one minted under the target's own key, when there is one, so a target the reader had set
    /// shows what it showed; otherwise the earliest created, the order `DuplicateRecordCleanup`
    /// keeps one of two copies by, so every device shows the same row. `nil` only for no rows.
    ///
    /// The rule was chosen in A15, where several rows can first answer for one target: a note
    /// keyed on its text since its row was set now sits in its file's target, beside that
    /// target's own row or another note's. It applies equally to a row re-spelled beside one
    /// minted on the new spelling. The rows it does not show keep their tier, note and exclusion,
    /// unapplied (``ArchiveVisitOverlay/superseded``).
    static func shownRow(among rows: [ArchiveVisitTarget],
                         answeringFor key: String) -> ArchiveVisitTarget? {
        let own = rows.filter { $0.targetKey == key }
        return (own.isEmpty ? rows : own).min {
            DuplicateRecordCleanup.isKept(($0.createdAt, $0.id), over: ($1.createdAt, $1.id))
        }
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
    /// Saves `context` before it gathers (#1457 review): the project's seed is gathered on a fresh
    /// context, which reads only saved data, and a note, a focus tag or an attach made moments
    /// earlier may not be saved yet — `ProjectLeadsService.recompute` and Project Home's engaged set
    /// save first for the same reason. The caller saves what this writes, and asks the reader on
    /// ``ArchiveVisitTopicReseed/needsConfirmation(question:current:)``.
    @MainActor
    func reseed(fromProject projectId: UUID, in context: ModelContext) async
        -> ArchiveVisitTopicReseed {
        guard let project = Self.project(withId: projectId, in: context) else { return .unchanged }
        // Read before the await: the project is not touched again after it.
        let question = project.researchQuestion
        try? context.save()
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
