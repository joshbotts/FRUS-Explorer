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

import Testing
import Foundation
@testable import FRUSExplorer

/// A person filter must survive a rollup rebuild (#747).
///
/// ## The defect these pin
/// `IndexingPipeline.consolidatePersonRollup` does `DELETE FROM person_rollup` and then writes one
/// row per cluster at `rollup_id = clusterIndex + 1`. Clusters are ordered by canonical name, so
/// **merging two identities shifts every id after the merge point down by one**. Anything holding a
/// bare `rollup_id` across that rebuild — an open filter chip, a saved search, an analytics series,
/// a trail signature — is holding a slot number, and after the rebuild that slot is someone else.
///
/// The fix is a durable anchor: `person_rollup_member`'s primary key is `(volume_id, ref)`, both
/// taken from the TEI, so it does not move when the table is renumbered. These tests exercise the
/// rebind rule directly, with the two store lookups injected as closures.
///
/// Version history:
///   1.0 — Session 2026-08-08: #747
@Suite("Person rollup identity")
struct PersonRollupIdentityTests {

    // MARK: - Fixtures

    private static let anchor = PersonRollupAnchor(volumeId: "frus1961-63v14", ref: "p_RK")

    /// Builds the entry shape the store returns for a rollup lookup — note `entry.ref` is **empty**,
    /// which is the real store's behaviour and the whole reason capture cannot happen at the sites
    /// that set a rollup id.
    private static func entry(rollupId: Int, name: String) -> PersonIndexEntry {
        PersonIndexEntry(entry: PersonEntry(ref: "", name: name, description: nil,
                                            role: nil, startYear: nil, endYear: nil),
                         mentionCount: 42,
                         rollupId: rollupId)
    }

    private func rebind(_ binding: PersonFilterBinding,
                        anchorFor: @escaping (Int) -> PersonRollupAnchor? = { _ in nil },
                        entryFor: @escaping (PersonRollupAnchor) -> PersonIndexEntry? = { _ in nil })
        -> (binding: PersonFilterBinding, droppedPersonFilter: Bool) {
        PersonRollupRefresh.rebind(binding, anchorFor: anchorFor, entryFor: entryFor)
    }

    // MARK: - Capture

    @Test("A filter with no anchor yet captures one from the rollup's representative member")
    func capturesAnchorOnFirstRebind() {
        let (after, dropped) = rebind(PersonFilterBinding(rollupId: 12, label: "Rusk"),
                                      anchorFor: { _ in Self.anchor })
        #expect(after.anchor == Self.anchor)
        // Capture is not a change to the filter: the same person, now identified durably.
        #expect(after.rollupId == 12)
        #expect(after.label == "Rusk")
        #expect(dropped == false)
    }

    @Test("Capture asks for the anchor of the id actually being held")
    func captureUsesTheHeldId() {
        var asked: [Int] = []
        _ = rebind(PersonFilterBinding(rollupId: 77),
                   anchorFor: { id in asked.append(id); return Self.anchor })
        #expect(asked == [77], "capture must look up the held id, not a constant")
    }

    @Test("A capture that fails leaves the filter intact rather than dropping it")
    func failedCaptureIsNotADrop() {
        // The store can be mid-rebuild. "I could not look this up" is not "this person is gone".
        let (after, dropped) = rebind(PersonFilterBinding(rollupId: 12, label: "Rusk"),
                                      anchorFor: { _ in nil })
        #expect(after.rollupId == 12)
        #expect(after.label == "Rusk")
        #expect(dropped == false)
    }

    // MARK: - Re-resolution — the H-1 defect

    @Test("A renumbered rollup re-points the filter at the same person, not the same slot")
    func followsThePersonThroughRenumbering() {
        // Before a merge the filter was on rollup 12. The merge shifts everything down; the anchor
        // now resolves to 11. Without this, the chip would keep filtering to slot 12 — a different
        // human — while still displaying the old name.
        let (after, dropped) = rebind(
            PersonFilterBinding(rollupId: 12, label: "Rusk", anchor: Self.anchor),
            entryFor: { _ in Self.entry(rollupId: 11, name: "Rusk, Dean") })
        #expect(after.rollupId == 11, "the filter must follow the anchor, not keep the slot")
        #expect(dropped == false)
    }

    @Test("The chip label adopts the merged identity's canonical name")
    func labelFollowsTheMerge() {
        // A merge adopts the authority's preferred spelling. Keeping the pre-merge label would
        // leave the chip describing a filter it is no longer applying.
        let (after, _) = rebind(
            PersonFilterBinding(rollupId: 12, label: "Rusk", anchor: Self.anchor),
            entryFor: { _ in Self.entry(rollupId: 11, name: "Rusk, Dean") })
        #expect(after.label == "Rusk, Dean")
    }

    @Test("Re-resolution looks the anchor up, and does not re-capture")
    func reresolutionUsesTheAnchor() {
        var capturedCalls = 0
        var resolved: [PersonRollupAnchor] = []
        _ = rebind(PersonFilterBinding(rollupId: 12, anchor: Self.anchor),
                   anchorFor: { _ in capturedCalls += 1; return nil },
                   entryFor: { a in resolved.append(a); return Self.entry(rollupId: 11, name: "X") })
        #expect(capturedCalls == 0, "an anchored filter must not re-capture — that would relabel it")
        #expect(resolved == [Self.anchor])
    }

    @Test("An unchanged rollup leaves the binding byte-identical")
    func stableRollupIsANoOp() {
        let before = PersonFilterBinding(rollupId: 12, label: "Rusk, Dean", anchor: Self.anchor)
        let (after, dropped) = rebind(before,
                                      entryFor: { _ in Self.entry(rollupId: 12, name: "Rusk, Dean") })
        #expect(after == before, "a no-op rebind must not churn the filter or force a re-run")
        #expect(dropped == false)
    }

    // MARK: - Dropping

    @Test("An anchor whose volume left the index drops the filter instead of guessing")
    func dropsWhenTheAnchorIsGone() {
        let (after, dropped) = rebind(
            PersonFilterBinding(rollupId: 12, label: "Rusk", anchor: Self.anchor),
            entryFor: { _ in nil })
        #expect(dropped)
        #expect(after.rollupId == nil, "keeping the id would filter to whoever now holds slot 12")
        #expect(after.label == nil)
        #expect(after.anchor == nil, "a dead anchor must not linger and re-resolve later")
    }

    @Test("An entry with no rollup id is a drop, not a silent keep")
    func entryWithoutRollupIdDrops() {
        // The store returns the member row's person even when the rollup was not rebuilt for it.
        let orphan = PersonIndexEntry(
            entry: PersonEntry(ref: "", name: "Rusk", description: nil,
                               role: nil, startYear: nil, endYear: nil),
            mentionCount: 0, rollupId: nil)
        let (after, dropped) = rebind(
            PersonFilterBinding(rollupId: 12, label: "Rusk", anchor: Self.anchor),
            entryFor: { _ in orphan })
        #expect(dropped)
        #expect(after.rollupId == nil)
    }

    // MARK: - No filter

    @Test("No person filter is left alone, and a stale anchor is cleared")
    func noFilterClearsAnyStaleAnchor() {
        let (after, dropped) = rebind(PersonFilterBinding(rollupId: nil, anchor: Self.anchor),
                                      anchorFor: { _ in Self.anchor },
                                      entryFor: { _ in Self.entry(rollupId: 1, name: "X") })
        #expect(after.rollupId == nil)
        #expect(after.anchor == nil,
                "an anchor with no filter would silently resurrect the filter on the next rebind")
        #expect(dropped == false)
    }

    // MARK: - SearchParameters round trip

    @Test("A stored query re-resolves its person filter through the same rule")
    func storedQueryReresolves() {
        var params = SearchParameters(keywords: "berlin")
        params.personRollupId = 12
        params.personLabel = "Rusk"
        params.personAnchor = Self.anchor

        let (updated, dropped) = params.reresolvedPerson(
            using: { _ in Self.entry(rollupId: 11, name: "Rusk, Dean") })
        #expect(updated.personRollupId == 11)
        #expect(updated.personLabel == "Rusk, Dean")
        #expect(updated.personAnchor == Self.anchor)
        #expect(dropped == false)
        #expect(updated.keywords == "berlin", "re-resolution must touch only the person filter")
    }

    @Test("A stored query with no anchor is left alone — it cannot capture one")
    func storedQueryWithoutAnchorIsUnchanged() {
        var params = SearchParameters(keywords: "berlin")
        params.personRollupId = 12
        let (updated, dropped) = params.reresolvedPerson(using: { _ in Self.entry(rollupId: 11, name: "X") })
        #expect(updated.personRollupId == 12)
        #expect(dropped == false)
    }

    @Test("A dropped stored-query filter clears all three fields")
    func storedQueryDropClearsEverything() {
        var params = SearchParameters(keywords: "berlin")
        params.personRollupId = 12
        params.personLabel = "Rusk"
        params.personAnchor = Self.anchor
        let (updated, dropped) = params.reresolvedPerson(using: { _ in nil })
        #expect(dropped)
        #expect(updated.personRollupId == nil)
        #expect(updated.personLabel == nil)
        #expect(updated.personAnchor == nil)
    }


    // MARK: - The trail signature (L-38)

    @Test("Two different people who occupied the same slot sign differently")
    func signatureDistinguishesPeopleSharingASlot() {
        // The exact false match L-38 describes: a scope recorded before a merge and one recorded
        // after can both say "rollup 12" while naming different people. Keyed on the slot they
        // collide, and one result set is silently reused for the other.
        var before = SearchParameters(keywords: "berlin")
        before.personRollupId = 12
        before.personAnchor = PersonRollupAnchor(volumeId: "frus1961-63v14", ref: "p_RK")

        var after = SearchParameters(keywords: "berlin")
        after.personRollupId = 12
        after.personAnchor = PersonRollupAnchor(volumeId: "frus1961-63v14", ref: "p_BUNDY")

        #expect(SearchScopeSignature.signature(for: before) != SearchScopeSignature.signature(for: after))
    }

    @Test("One person keeps one signature across a renumbering")
    func signatureIsStableAcrossRenumbering() {
        var before = SearchParameters(keywords: "berlin")
        before.personRollupId = 12
        before.personAnchor = Self.anchor

        var after = before
        after.personRollupId = 11   // the same person, renumbered by a merge

        #expect(SearchScopeSignature.signature(for: before) == SearchScopeSignature.signature(for: after),
                "an unchanged scope must not look like a new scope just because ids shifted")
    }

    @Test("A rollup filter with no anchor still signs, distinctly from an anchored one")
    func unanchoredRollupStillSigns() {
        var unanchored = SearchParameters(keywords: "berlin")
        unanchored.personRollupId = 12

        var none = SearchParameters(keywords: "berlin")
        none.personRollupId = nil

        var anchored = unanchored
        anchored.personAnchor = Self.anchor

        #expect(SearchScopeSignature.signature(for: unanchored) != SearchScopeSignature.signature(for: none),
                "an unanchored person filter must still be part of the scope")
        #expect(SearchScopeSignature.signature(for: unanchored) != SearchScopeSignature.signature(for: anchored),
                "the fallback form must not collide with the durable form")
    }

    // MARK: - The anchor itself

    @Test("The signature key is the composite, so two volumes' identical refs stay distinct")
    func anchorKeyIsComposite() {
        let a = PersonRollupAnchor(volumeId: "frus1961-63v14", ref: "p_RK")
        let b = PersonRollupAnchor(volumeId: "frus1964-68v11", ref: "p_RK")
        #expect(a.signatureKey != b.signatureKey)
        #expect(a != b)
        #expect(a.signatureKey.contains("frus1961-63v14"))
        #expect(a.signatureKey.contains("p_RK"))
    }
}

// MARK: - Wiring

/// The rebind rule has to be *reached*, on both platforms (#747).
///
/// Every test above proves the rule is correct. None would notice if a view stopped observing
/// `personRollupGeneration`, or if one platform's search surface was fixed and the other left
/// holding stale ids — which is this codebase's documented recurring failure (`Dual Settings Views`,
/// `macOS Search is Separate`: a toggle hidden from every Mac user for a whole release). So these
/// read the source, in the style of `CodingStandardsAuditTests` and `ResetInventoryTests`.
@Suite("Person rollup wiring")
struct PersonRollupWiringTests {

    private func source(_ relativePath: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test("Both search surfaces re-resolve on a rollup rebuild")
    func bothSearchSurfacesObserveTheGeneration() throws {
        for path in ["FRUSExplorer/Search/SearchView.swift",      // iOS + iPadOS
                     "FRUSExplorer/App/SearchSheet.swift"] {      // the separate macOS window
            let text = try source(path)
            #expect(text.contains("appState.personRollupGeneration"),
                    "\(path) must observe personRollupGeneration (#747)")
            #expect(text.contains("refreshPersonRollupBinding"),
                    "\(path) must re-resolve through the durable anchor, not merely reload")
        }
    }

    @Test("The anchor rides the whole parameter round trip in both view models")
    func viewModelsCarryTheAnchor() throws {
        // `SearchParameters` is not Codable — `SavedSearch` flattens it into scalar columns, and
        // that flattening persists neither `personRollupId` nor `personLabel`, so a saved search
        // has never carried a rollup filter at all (that gap is #756, not this issue). What does
        // carry it is the in-memory hand-off, and it only survives if BOTH directions are wired:
        // parameters → view model on apply, and view model → parameters on emit. Miss the emit and
        // the anchor is re-captured from scratch on every round trip, quietly restoring the
        // slot-number behaviour this issue removes.
        let ios = try source("FRUSExplorer/Search/SearchViewModel.swift")
        #expect(ios.contains("personAnchor      = params.personAnchor"),
                "SearchViewModel.applyParameters must read params.personAnchor")
        #expect(ios.contains("personAnchor: personAnchor"),
                "SearchViewModel must emit personAnchor in its parameters")

        let mac = try source("FRUSExplorer/App/MacSearchViewModel.swift")
        #expect(mac.contains("filterVM.personAnchor       = parameters.personAnchor"),
                "MacSearchViewModel must push personAnchor into the shared filter view model")
        #expect(mac.contains("parameters.personAnchor     = filterVM.personAnchor"),
                "MacSearchViewModel must pull personAnchor back out again")
    }

    @Test("Person Analytics reloads on a rollup rebuild, not only on a store reopen")
    func analyticsObservesTheGeneration() throws {
        // M-27: a correction rebuilds the rollup *without* reopening the read-only stores, so
        // `readOnlyStoresGeneration` never moves and every charted series stayed attributed to a
        // rollup id that had since become someone else.
        let text = try source("FRUSExplorer/Analytics/PersonAnalyticsView.swift")
        #expect(text.contains("appState.personRollupGeneration"),
                "PersonAnalyticsView must observe personRollupGeneration (#747 / M-27)")
    }

    @Test("Both volume hubs reconsolidate the rollup after a corpus change")
    func bothHubsReconsolidate() throws {
        // M-14: adding or removing volumes changed `persons` but left the rollup standing, so the
        // People browser listed people from removed volumes — with their old counts — until the
        // next launch. Reopening connections is not recomputing derived data.
        for path in ["FRUSExplorer/Settings/MacVolumesStorageHub.swift",
                     "FRUSExplorer/Settings/VolumesStorageHubView.swift"] {
            let text = try source(path)
            #expect(text.contains("refreshAfterCorpusChange"),
                    "\(path) must route corpus changes through refreshAfterCorpusChange (#747)")
            #expect(!text.contains("appState.refreshReadOnlyStores()"), """
                \(path) still calls refreshReadOnlyStores() directly. That reopens connections \
                without recomputing person_rollup, which is the M-14 defect — use \
                appState.refreshAfterCorpusChange(context:) instead.
                """)
        }
    }

    @Test("refreshAfterCorpusChange reopens the stores before it does anything else")
    func corpusChangeStillSatisfiesTheReindexContract() throws {
        // #275's contract — VACUUM and reindex swap the database file under the boot-once
        // read-only connections, so they must be recreated or every dashboard reads empty for the
        // rest of the session. Both storage hubs now reach that through
        // `refreshAfterCorpusChange`, so `IndexCompactionTests` accepts the delegating call; this
        // is the assertion that makes that acceptance safe. If the delegation is ever removed,
        // #275 regresses silently on every hub action at once.
        let text = try source("FRUSExplorer/App/AppState.swift")
        let start = try #require(text.range(of: "func refreshAfterCorpusChange(context:"))
        let body = String(text[start.lowerBound...].prefix(600))
        #expect(body.contains("refreshReadOnlyStores()"),
                "refreshAfterCorpusChange must reopen the read-only stores (#275)")

        // And it must do so BEFORE the async rollup work, not after: the whole point is that the
        // connections are usable the moment the hub action returns.
        let reopen = try #require(body.range(of: "refreshReadOnlyStores()"))
        if let asyncWork = body.range(of: "Task {") {
            #expect(reopen.lowerBound < asyncWork.lowerBound,
                    "the stores must be reopened synchronously, before the rollup task is spawned")
        }
    }

    @Test("Corrections raise the signal through the choke point, not by hand")
    func correctionSitesUseTheChokePoint() throws {
        for path in ["FRUSExplorer/Browser/PersonIndexView.swift",
                     "FRUSExplorer/Browser/PersonCorrectionsView.swift"] {
            let text = try source(path)
            #expect(text.contains("PersonRollupRefresh.afterCorrection"),
                    "\(path) must rebuild through PersonRollupRefresh (#747)")
            let handRolled = text
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map(String.init)
                .filter { line in
                    let t = line.trimmingCharacters(in: .whitespaces)
                    return !t.hasPrefix("//") && t.contains("personRollupGeneration += 1")
                }
            #expect(handRolled.isEmpty, """
                \(path) bumps personRollupGeneration by hand: \(handRolled.joined(separator: " | ")). \
                That is how the third correction site came to raise no signal at all — route the \
                rebuild through PersonRollupRefresh, which raises it as part of rebuilding.
                """)
        }
    }
}
