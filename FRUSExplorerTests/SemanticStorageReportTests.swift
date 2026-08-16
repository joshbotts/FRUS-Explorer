// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import FRUSExplorer

/// What the storage screens may claim about semantic vectors (#900).
///
/// ## What is worth testing
/// Not the arithmetic — two counts and a sum. What matters is the **honesty boundary**: two of this
/// report's four inputs are complete and two are structurally partial, and a screen that presented
/// the partial ones as total would be quietly wrong in the direction users cannot detect.
///
/// - `failures` comes from `SemanticShardFetcher.failed`, in-memory and empty at every launch.
/// - `refusals` comes from `SemanticShardStore.refused`, populated only by `shard(for:)` — i.e.
///   only for volumes some surface has already asked about.
///
/// So "no problems found" is a sentence this app cannot support, and the tests below say so.
///
/// Version history:
///   1.0 — #900
@Suite("Semantic storage report")
struct SemanticStorageReportTests {

    /// A repo source file, for the two structural checks below.
    private static func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appending(path: relativePath), encoding: .utf8)
        #expect(text.count > 1_000, "\(relativePath) is implausibly small — did it move?")
        return text
    }

    private func report(
        onDisk: Int = 8, bytes: Int = 1_200_000,
        published: Int = 552, publishedBytes: Int = 82_000_000,
        failures: [String: String] = [:], refusals: [String: String] = [:]
    ) -> SemanticStorageReport {
        SemanticStorageReport(
            volumesOnDisk: onDisk, bytesOnDisk: bytes,
            volumesPublished: published, bytesPublished: publishedBytes,
            failures: failures, refusals: refusals)
    }

    // MARK: - The honesty boundary

    @Test("an empty problem list never claims there are no problems")
    func emptyProblemsIsNotACleanBillOfHealth() {
        let caption = report().problemsCaption
        #expect(!caption.isEmpty)
        #expect(caption.lowercased().contains("not a clean bill of health")
                || caption.lowercased().contains("only recorded"), """
            With nothing recorded the screen said something that reads as "everything is fine". \
            It cannot know that: a fetch failure is forgotten at every launch, and a damaged shard \
            is only noticed once some surface asks for that volume. The caption has to disclose \
            what it did NOT look at.
            """)
    }

    @Test("a non-empty problem list still says others may exist")
    func someProblemsStillDisclosesThePartialScan() {
        let caption = report(failures: ["frus1861": "The download did not complete."]).problemsCaption
        #expect(caption.contains("1"))
        #expect(caption.lowercased().contains("may exist"),
                "reporting a count without saying the scan was partial reads as a total")
    }

    // MARK: - Deduplication

    @Test("a volume that both failed and was refused is one problem, not two")
    func problemsAreDeduplicated() {
        let both = report(
            failures: ["frus1861": "The download did not complete."],
            refusals: ["frus1861": "The file on disk is damaged."])
        #expect(both.problemVolumeIDs == ["frus1861"],
                "one volume was counted twice — the screen would report two problems where there is one")
    }

    @Test("the refusal wins, because the file is on disk and unusable")
    func refusalIsTheMoreActionableDescription() {
        let both = report(
            failures: ["frus1861": "download failed"],
            refusals: ["frus1861": "damaged on disk"])
        #expect(both.problemDescription(for: "frus1861") == "damaged on disk")
        #expect(both.problemDescription(for: "frus1862") == nil)
    }

    @Test("problem ids are sorted, so the list does not reshuffle between reads")
    func problemsAreOrdered() {
        let many = report(failures: ["frus1970": "a", "frus1861": "b"],
                          refusals: ["frus1905": "c"])
        #expect(many.problemVolumeIDs == ["frus1861", "frus1905", "frus1970"])
    }

    // MARK: - Which refusals are faults at all

    @Test("the two ordinary states are not reported as problems")
    func ordinaryStatesAreNotFaults() {
        // `noArtifact` is the condition of every volume in a library that has fetched nothing, and
        // `documentNotVectorised` is a fact about one document rather than about this volume's
        // storage. Describing either would fill the problems list with the normal state of the app.
        #expect(SemanticStorageReport.describe(SemanticUnavailable.noArtifact) == nil,
                "an un-fetched volume would be listed as a problem on every fresh install")
        #expect(SemanticStorageReport.describe(SemanticUnavailable.documentNotVectorised) == nil)
    }

    @Test("every real fault gets a sentence a reader can act on")
    func realFaultsAreDescribed() {
        for reason in [SemanticUnavailable.pending,
                       .provenanceMismatch(expected: "a", found: "b"),
                       .shardMissing(volumeID: "frus1861"),
                       .malformedArtifact("bad header")] {
            let sentence = SemanticStorageReport.describe(reason)
            #expect(sentence != nil, "\(reason) has no user-facing sentence")
            #expect(sentence?.isEmpty == false)
        }
    }

    @Test("every fetch failure gets a sentence, and the HTTP code survives into it")
    func fetchFailuresAreDescribed() {
        #expect(SemanticStorageReport.describe(.httpStatus(404)).contains("404"),
                "the status code is the one actionable detail in an HTTP failure and it was dropped")
        for error in [SemanticShardFetcher.FetchError.notInManifest("frus1861"),
                      .integrityMismatch(volumeID: "frus1861", expected: "a", found: "b"),
                      .transport("offline")] {
            #expect(!SemanticStorageReport.describe(error).isEmpty)
        }
    }

    // MARK: - Availability

    @Test("an unbooted semantic stack is distinguishable from an empty library")
    func unavailableIsNotTheSameAsEmpty() {
        // The screens say different things for these two, so the report has to tell them apart:
        // one is "this build cannot do semantic search at all", the other is "nothing downloaded
        // yet". Both have zero shards on disk.
        #expect(!SemanticStorageReport.unavailable.isAvailable)
        #expect(report(onDisk: 0, bytes: 0).isAvailable,
                "a booted stack with nothing downloaded read as unavailable")
    }

    @Test("vectors on disk are always reportable, even with no publishable denominator")
    func orphanedBytesStillGetASection() {
        // The build this exists for: the bundled shard manifest is missing or from another
        // generation, so `SemanticShardFetcher` is nil and nothing is publishable — while the
        // user still has megabytes of now-unusable vectors on disk. Gating the section on the
        // denominator would hide the Remove button in the one state where removal is the point.
        let orphaned = report(onDisk: 40, bytes: 6_000_000, published: 0, publishedBytes: 0)
        #expect(orphaned.isAvailable, """
            A device holding 40 shards showed the "not available" row and no Remove button, because \
            this build cannot publish any. Those bytes are exactly the ones a reader would want to \
            reclaim.
            """)
    }

    @Test("the report's byte figures come from the same directory reader that removal uses")
    func diskFiguresAndRemovalAgree() throws {
        // A source check, because the alternative is a live store. `diskUsage()` must be built on
        // `volumeIDsOnDisk()` — the reader `removeAllShards()` iterates — or a screen can show a
        // count and a size for a set of files the Remove button would not delete. The first draft
        // walked the directory a second time with `.skipsHiddenFiles` and had exactly that gap.
        let source = try Self.source("FRUSExplorer/Semantic/SemanticShardStore.swift")
        let body = try #require(source.range(of: "public func diskUsage()"))
        let tail = String(source[body.upperBound...].prefix(700))
        #expect(tail.contains("volumeIDsOnDisk()"), """
            diskUsage() walks the directory itself instead of reusing volumeIDsOnDisk(). Two \
            readers with different filters can disagree about what counts as a shard, so the size \
            shown and the files removed would be different sets.
            """)
    }

    // MARK: - #926 · the download controls

    @Test("the per-volume figure is a mean, derived from the authoritative totals")
    func perVolumeIsDerived() {
        let r = report(published: 552, publishedBytes: 81_800_908)
        #expect(r.perVolumeEstimate == 81_800_908 / 552)
        // Never a stored second copy: if it were, it could disagree with the totals beside it.
        #expect(report(published: 0, publishedBytes: 0).perVolumeEstimate == 0,
                "a device with nothing publishable divided by zero")
    }

    @Test("the off-switch default preserves today's behaviour")
    func autoDownloadDefaultsOn() {
        // The switch is device-local (`SettingsKeys.autoDownloadSemanticShards`, never on
        // `SyncedPreferences`, so no CloudKit deploy) and defaults ON — a preference whose
        // INTRODUCTION stopped filling libraries that are being filled today would change behaviour
        // for people who never touched it.
        let key = SettingsKeys.autoDownloadSemanticShards
        let saved = UserDefaults.standard.object(forKey: key)
        defer {
            if let saved { UserDefaults.standard.set(saved, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }

        UserDefaults.standard.removeObject(forKey: key)
        #expect(AppState.automaticSemanticShardDownloads,
                "an app that has never seen the toggle stopped downloading shards")

        UserDefaults.standard.set(false, forKey: key)
        #expect(!AppState.automaticSemanticShardDownloads)
        UserDefaults.standard.set(true, forKey: key)
        #expect(AppState.automaticSemanticShardDownloads)
    }

    @Test("bulk progress is a count, and reports its own fraction safely")
    func downloadProgressIsCounted() {
        var p = AppState.SemanticShardDownloadProgress(completed: 0, total: 340, failed: 0)
        #expect(p.fraction == 0)
        p.completed = 170
        #expect(abs(p.fraction - 0.5) < 0.0001)
        // A run that found nothing to do must not divide by zero on its way to a progress view.
        let empty = AppState.SemanticShardDownloadProgress(completed: 0, total: 0, failed: 0)
        #expect(empty.fraction == 0)
    }

    @Test("a shard the store rejects is a reportable failure, not a silence")
    func storeRejectionIsDescribed() {
        // Before #900 this case was rethrown WITHOUT being recorded, so it appeared in no list and
        // — because the same dictionary is the do-not-retry gate — it re-downloaded on every
        // launch. The generation-skew case the digest check exists to catch was the one failure
        // nothing could report.
        let sentence = SemanticStorageReport.describe(
            .rejectedByStore(volumeID: "frus1861", reason: "provenanceMismatch"))
        #expect(!sentence.isEmpty)
        #expect(!sentence.lowercased().contains("provenancemismatch"),
                "the raw enum description reached the user instead of a sentence")
    }
}

// MARK: - SemanticStorageSectionParityTests

/// Both storage hubs offer the semantic-vectors surface (#900).
///
/// ## Why this test exists at all
/// `VolumesStorageHubView` and `MacVolumesStorageHub` are ~1,850 and ~1,960 lines of hand-maintained
/// twins, and **nothing mechanically pins them together**. The repo's recorded consequence is a
/// Settings toggle that shipped on one platform and was invisible to every user of the other until
/// the owner went looking. A storage figure and a Remove button are exactly the shape of thing that
/// happens to.
///
/// The primary defence is the design — one `SemanticStorageSection` mounted by both, rather than a
/// section written twice — and this pins that arrangement rather than re-checking the copy: if a
/// later edit inlines the rows into one hub, the shared view stops being shared and this fails.
///
/// Version history:
///   1.0 — #900
@Suite("Semantic storage section parity")
struct SemanticStorageSectionParityTests {

    private static func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appending(path: relativePath), encoding: .utf8)
        #expect(text.count > 1_000, "\(relativePath) is implausibly small — did it move?")
        return text
    }

    @Test("both hubs mount the shared section")
    func bothHubsMountIt() throws {
        for hub in ["FRUSExplorer/Settings/VolumesStorageHubView.swift",
                    "FRUSExplorer/Settings/MacVolumesStorageHub.swift"] {
            let text = try Self.source(hub)
            #expect(text.contains("SemanticStorageSection()"), """
                \(hub) does not mount SemanticStorageSection. These two files are hand-maintained \
                twins with no other mechanism keeping them in step, and a storage figure plus a \
                Remove button visible on one platform and absent on the other is the defect this \
                repo has already shipped once.
                """)
        }
    }

    @Test("the section's copy lives in one place, not in either hub")
    func hubsDoNotSpellTheCopyThemselves() throws {
        // The anti-drift property. If a hub starts writing its own vector strings, the two
        // platforms can describe the same bytes differently — which is the failure the shared view
        // exists to make impossible.
        for hub in ["FRUSExplorer/Settings/VolumesStorageHubView.swift",
                    "FRUSExplorer/Settings/MacVolumesStorageHub.swift"] {
            let text = try Self.source(hub)
            #expect(!text.contains("settings.vectors."), """
                \(hub) spells a semantic-vectors string itself. Every one of them belongs to \
                SemanticStorageSection or SemanticStorageReport, so the two hubs cannot word the \
                same fact differently.
                """)
        }
    }
}
