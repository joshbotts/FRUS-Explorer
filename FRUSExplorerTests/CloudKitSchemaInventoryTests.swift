// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData
import Testing
@testable import FRUSExplorer

// MARK: - CloudKitSchemaInventoryTests

/// The schema-deploy release gate (Wave R-7).
///
/// ## Why this suite exists
/// `Planning/Completed/188-189-Tester-Feedback-Build28-Plan.md:158` specified a startup warning "if the
/// installed model set is newer than a known-deployed marker, so a future undeployed-schema
/// regression is caught before shipping". It was never built, and #488 is that regression: build
/// 35 added four CloudKit identifiers with no gate, the Production schema was never promoted, and
/// CloudKit export failed for every user on that build.
///
/// ## What it can and cannot prove
/// It **can** prove that the checked-in inventory matches the model set this build actually
/// mirrors — it rebuilds the inventory from `ModelContainer.frusModelTypes` through a live
/// `Schema` and compares. Adding or removing a `@Model`, or a stored property on one, fails here.
///
/// It **cannot** see the Production CloudKit schema; no code in this process can. So the deploy
/// marker is an owner-attested claim, and what these tests do instead is make that claim
/// impossible to skip: the deployed baseline is pinned by count *and* digest, so a schema change
/// must be answered either by listing the new identifiers as awaiting deploy or by restating the
/// baseline. Both are explicit, both are visible in the diff.
///
/// ## The failure messages are the deliverable
/// A gate nobody is forced to act on is theatre. Every `#expect` here fails with the deploy
/// checklist and, where it can, the exact text to paste — so the developer who trips it does not
/// have to go and find out what the gate wanted.
///
/// Version history:
///   1.0 — Wave R-7: initial implementation
struct CloudKitSchemaInventoryTests {

    // MARK: - Fixtures

    /// The repository root, located the same way `CodingStandardsAuditTests` does.
    private static let projectRoot: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    /// The identifiers the *live* schema mirrors, rebuilt from `frusModelTypes`.
    ///
    /// A bare `Schema` — no `ModelContainer`, no store, no CloudKit — so this is fast and has no
    /// account or entitlement requirement.
    private static func liveIdentifiers() -> [String] {
        CloudKitSchemaInventory.mirroredIdentifiers(
            of: Schema(ModelContainer.frusModelTypes))
    }

    /// Renders an identifier list as the Swift literal to paste into
    /// `CloudKitSchemaInventory.installedIdentifiers`.
    private static func literal(for identifiers: [String]) -> String {
        identifiers.map { "        \"\($0)\"," }.joined(separator: "\n")
    }

    // MARK: - The inventory

    /// **The test R-7 exists to make fail.** The checked-in inventory must be exactly what
    /// `frusModelTypes` mirrors into CloudKit.
    ///
    /// Trips on: a new `@Model`, a removed one, a new stored property, a removed property, a
    /// rename. Each of those is a CloudKit schema change that needs a Production deploy before
    /// the build ships — which is what the failure message says, in order.
    @Test("The checked-in inventory matches the model set this build mirrors")
    func installedInventoryMatchesTheLiveSchema() {
        let live = Self.liveIdentifiers()
        let pinned = CloudKitSchemaInventory.installedIdentifiers
        guard live != pinned else { return }

        let added = live.filter { !pinned.contains($0) }
        let removed = pinned.filter { !live.contains($0) }

        Issue.record("""
        The CloudKit-mirrored model set has changed. This is a schema change and needs a \
        Production deploy before the build ships — #488 is what happens when it does not.

        Added   (\(added.count)): \(added.isEmpty ? "none" : added.joined(separator: ", "))
        Removed (\(removed.count)): \(removed.isEmpty ? "none" : removed.joined(separator: ", "))

        DEPLOY CHECKLIST
        1. Paste the list below over CloudKitSchemaInventory.installedIdentifiers.
        2. Add the ADDED identifiers to CloudKitSchemaInventory.identifiersAwaitingDeploy. \
        The app will then say so at launch and in Settings > Data & Recovery > iCloud Schema.
        3. Run a Development build signed into a real iCloud account and exercise the new \
        type/field once, so NSPersistentCloudKitContainer creates it in the Development schema.
        4. CloudKit Dashboard > Schema > Deploy Schema Changes to Production, for container \
        iCloud.bottsywattsy.FRUS-Explorer.
        5. Only then: clear identifiersAwaitingDeploy, set deployedThroughBuild / deployedOn, \
        and re-run this suite — deployedBaselineIsPinned prints the count and digest to paste.

        static let installedIdentifiers: [String] = [
        \(Self.literal(for: live))
        ]
        """)
    }

    /// The record-type count is derived, and the prose that used to carry it by hand is checked
    /// against the derived number.
    ///
    /// `ModelContainer+FRUS.swift` claimed "16 record types" while the list held 18 — it went
    /// stale across `CustomVolumeScope` (#258) and `ProjectLeadEntry` (#377 Phase 3) without
    /// anything noticing. Any `N record types` phrase in that file must now agree with the
    /// inventory.
    @Test("No stale record-type count survives in ModelContainer+FRUS.swift")
    func documentedRecordTypeCountIsCurrent() throws {
        let url = Self.projectRoot
            .appendingPathComponent("FRUSExplorer/Models/ModelContainer+FRUS.swift")
        let source = try String(contentsOf: url, encoding: .utf8)

        let expected = CloudKitSchemaInventory.recordTypeCount
        #expect(expected == ModelContainer.frusModelTypes.count,
                "recordTypeCount is derived from the inventory and must equal the model count")

        let pattern = try NSRegularExpression(pattern: #"(\d+)\s+record types"#)
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        var claimed: [Int] = []
        pattern.enumerateMatches(in: source, range: range) { match, _, _ in
            guard let match, let r = Range(match.range(at: 1), in: source) else { return }
            claimed.append(Int(source[r]) ?? -1)
        }

        #expect(claimed.allSatisfy { $0 == expected }, """
        ModelContainer+FRUS.swift claims \(claimed.map(String.init).joined(separator: ", ")) \
        record types; the model set holds \(expected). Either update the prose or — better — \
        stop restating the count and refer to CloudKitSchemaInventory.recordTypeCount, which \
        cannot drift.
        """)
    }

    // MARK: - The deploy marker

    /// The deployed baseline is pinned to `installed − awaiting`, by count and by digest.
    ///
    /// This is the tie that makes the marker more than a comment. Adding an identifier without
    /// listing it as awaiting-deploy breaks the digest, and the only way to mend it is to restate
    /// the baseline — which *is* the claim "I deployed this to Production". The digest catches
    /// what a count cannot: a rename, or an add and a removal in the same change.
    @Test("The deployed baseline is pinned by count and digest")
    func deployedBaselineIsPinned() {
        let baseline = CloudKitSchemaInventory.deployedBaseline
        let digest = CloudKitSchemaInventory.digest(of: baseline)

        let advice = """

        If you changed the schema: list the new identifiers in \
        CloudKitSchemaInventory.identifiersAwaitingDeploy — do NOT restate the baseline, because \
        that claims a Production deploy that has not happened.

        If you HAVE deployed to Production (CloudKit Dashboard > Schema > Deploy Schema Changes \
        to Production): clear identifiersAwaitingDeploy, set deployedThroughBuild to the current \
        CURRENT_PROJECT_VERSION and deployedOn to today, then paste:

            static let deployedIdentifierCount = \(baseline.count)
            static let deployedIdentifierDigest = "\(digest)"
        """

        #expect(baseline.count == CloudKitSchemaInventory.deployedIdentifierCount, """
        The deployed baseline holds \(baseline.count) identifiers; the marker claims \
        \(CloudKitSchemaInventory.deployedIdentifierCount).\(advice)
        """)

        #expect(digest == CloudKitSchemaInventory.deployedIdentifierDigest, """
        The deployed baseline's digest is \(digest); the marker claims \
        "\(CloudKitSchemaInventory.deployedIdentifierDigest)".\(advice)
        """)
    }

    /// You cannot claim to be awaiting a deploy for something this build does not mirror.
    ///
    /// Catches the copy-paste failure the checklist invites — pasting an identifier from an issue
    /// or a `git diff` with a typo, which would leave the gate warning about a phantom for ever.
    @Test("Every identifier awaiting deploy is one this build actually mirrors")
    func awaitingIdentifiersAreRealMembersOfTheInventory() {
        let installed = Set(CloudKitSchemaInventory.installedIdentifiers)
        let phantom = CloudKitSchemaInventory.identifiersAwaitingDeploy
            .filter { !installed.contains($0) }

        #expect(phantom.isEmpty, """
        identifiersAwaitingDeploy names identifiers this build does not mirror: \
        \(phantom.joined(separator: ", ")). They are typos or leftovers — an identifier can only \
        await deployment if installedIdentifiers carries it.
        """)
    }

    /// The inventory is sorted and free of duplicates, so the diff of a schema change reads as
    /// the change itself rather than as a reshuffle.
    @Test("The inventory is sorted and duplicate-free")
    func inventoryIsSortedAndUnique() {
        let identifiers = CloudKitSchemaInventory.installedIdentifiers
        #expect(identifiers == identifiers.sorted(),
                "installedIdentifiers must stay sorted — paste the literal the inventory test prints")
        #expect(Set(identifiers).count == identifiers.count,
                "installedIdentifiers contains duplicates")
    }

    /// Every identifier is in CloudKit's own vocabulary: `CD_Type` or `CD_Type.CD_field`.
    ///
    /// Pins the shape the deploy checklist and the Settings screen both assume, and the shape
    /// #488 was finally described in.
    @Test("Every identifier is a CD_-prefixed CloudKit name")
    func identifiersUseCloudKitNaming() {
        let malformed = CloudKitSchemaInventory.installedIdentifiers.filter { identifier in
            let parts = identifier.split(separator: ".", omittingEmptySubsequences: false)
            guard parts.count <= 2 else { return true }
            return !parts.allSatisfy { $0.hasPrefix("CD_") && $0.count > 3 }
        }

        #expect(malformed.isEmpty,
                "Not CloudKit identifiers: \(malformed.joined(separator: ", "))")
    }

    // MARK: - The runtime signal

    /// The launch-time check reads one array literal and nothing else.
    ///
    /// The gate has to survive being on the launch path, so this pins the cheap contract rather
    /// than measuring a duration (which would be a flaky assertion on shared CI hardware): the
    /// answer comes from `identifiersAwaitingDeploy`, never from walking a `Schema`.
    @Test("The launch-time check agrees with the awaiting list")
    func launchCheckIsTheAwaitingList() {
        #expect(CloudKitSchemaInventory.isProductionSchemaCurrent
                == CloudKitSchemaInventory.identifiersAwaitingDeploy.isEmpty)
    }

    /// `mirroredIdentifiers` is deterministic — the same schema yields the same list twice.
    /// `Schema.Entity.properties` is not order-guaranteed, so the sort in the reader is what makes
    /// the checked-in literal stable; without it this suite would fail at random.
    @Test("Reading a schema twice yields the same identifiers")
    func schemaReadIsDeterministic() {
        #expect(Self.liveIdentifiers() == Self.liveIdentifiers())
    }

    /// The digest is a function of content and order, not of identity.
    @Test("The digest distinguishes a changed list from an unchanged one")
    func digestIsContentAddressed() {
        let base = ["CD_Project", "CD_Project.CD_name"]
        #expect(CloudKitSchemaInventory.digest(of: base)
                == CloudKitSchemaInventory.digest(of: ["CD_Project", "CD_Project.CD_name"]))
        #expect(CloudKitSchemaInventory.digest(of: base)
                != CloudKitSchemaInventory.digest(of: base + ["CD_Project.CD_question"]))
        #expect(CloudKitSchemaInventory.digest(of: base).count == 64,
                "SHA-256 hex is 64 characters")
    }
}
