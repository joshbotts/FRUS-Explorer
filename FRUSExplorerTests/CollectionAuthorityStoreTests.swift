// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - CollectionAuthorityStoreTests

/// Exercises `CollectionAuthorityStore` over the **real bundled artifact**
/// (`collection-authority.json`): the decode, and the documented lookup order —
/// lot key, repository-scoped text key, unattributed bucket, unambiguous alias —
/// plus the shared `CollectionKeying` derivations the lookups ride on
/// (Source Explorer Phase 4 step 2).
///
/// Version history:
///   1.0 — Session 2026-07-03: initial implementation
///   1.1 — Session 2026-07-04 (Phase 4 verification): plural-folded segment norms;
///          spot-check pins for the fold bridge and the grain-mismatch alias bridge
///   1.2 — Session 2026-07-04 (Phase 4 adversarial review): step-3 guard pins
///          (generic leads and shadowed segments never bridge to the unattributed
///          bucket); phantom-repository pin (no Department-of-State NSF record)
@Suite("CollectionAuthorityStore — bundled artifact lookups")
struct CollectionAuthorityStoreTests {

    /// The bundled index, required by every test in the suite.
    private func index() throws -> CollectionAuthorityIndex {
        try #require(CollectionAuthorityStore.shared,
                     "collection-authority.json must decode from the app bundle")
    }

    @Test("The bundled artifact decodes with the expected shape")
    func artifactDecodes() throws {
        let index = try index()
        #expect(index.schemaVersion == 1)
        #expect(index.collections.count > 4000,
                "the Phase 4 artifact carries ~4,429 records; got \(index.collections.count)")
    }

    /// Cold-start guard: the store warm-up (read + decode + lookup-map build) happens
    /// off the main thread on first access, but it must stay cheap enough that a
    /// first per-row lookup soon after launch is not visibly delayed.
    @Test("Store warm-up (read + decode + maps) stays under one second")
    func decodeTimeBudget() throws {
        let url = try #require(Bundle.main.url(forResource: "collection-authority",
                                               withExtension: "json"))
        let start = CFAbsoluteTimeGetCurrent()
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(CollectionAuthorityIndex.self, from: data)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        #expect(decoded.collections.count > 4000)
        print("[CollectionAuthorityStoreTests] warm-up decode: \(String(format: "%.0f", elapsed * 1000)) ms for \(data.count) bytes")
        #expect(elapsed < 1.0, "warm-up took \(elapsed)s — cold-start budget exceeded")
    }

    @Test("Lot lookup (order step 1): the canonical compact key resolves the record")
    func lotLookup() throws {
        let index = try index()
        let record = try #require(index.record(forLotNorm: "64D199"),
                                  "Lot 64 D 199 (PPS-era Secretary's memoranda) is a corpus staple")
        #expect(record.id == "lot:64D199")
        #expect(record.repository == "Department of State")
        #expect(record.naId == "602231", "the offline NAID resolution ships in the artifact")
        #expect(record.url?.absoluteString.contains("catalog.archives.gov") == true)
        #expect(record.volumeIds.count > 10, "cited across dozens of volumes")
    }

    @Test("Text lookup (order step 2) bridges full library names to the keyword bucket")
    func repositoryScopedTextLookup() throws {
        let index = try index()
        // The full name canonicalizes to "Johnson Library" — the same bridging the
        // generator applied, so the lookup lands in the same bucket.
        let record = try #require(index.record(
            repository: "Lyndon B. Johnson Library",
            leadingSegment: "National Security File"))
        #expect(record.id == "txt:johnson library|national security file")
        #expect(!record.children.isEmpty, "NSF carries sub-series (Country File, …)")
    }

    @Test("Unattributed bucket (order step 3) is reached when the repo-scoped key misses")
    func unattributedFallback() throws {
        let index = try index()
        // "Administrative and Staff Files" is an unattributed doc-note series in the
        // artifact (no Department-of-State bucket exists for it); querying it WITH a
        // repository must still find it through the unattributed bucket, per the
        // documented order — and the bare query resolves the same record directly.
        let viaRepo = try #require(index.record(repository: "Department of State",
                                                leadingSegment: "Administrative and Staff Files"))
        #expect(viaRepo.id == "txt:|administrative and staff file")
        let bare = index.record(repository: nil,
                                leadingSegment: "Administrative and Staff Files")
        #expect(bare?.id == viaRepo.id)
    }

    @Test("Unattributed bucket (order step 3) is guarded: generic and shadowed segments never bridge")
    func unattributedBucketGuard() throws {
        let index = try index()
        // (a) Generic leads: the artifact ships bare generic grab-bag records
        // ("Subject File", "Country File"); an *attributed* citation whose repo-scoped
        // key misses must never resolve to one (adversarial review 2026-07-04
        // finding 4).
        for generic in ["Subject File", "Country File"] {
            let norm = CollectionKeying.segmentNorm(generic)
            guard index.record(id: "txt:|" + norm) != nil else { continue }
            let hit = index.record(repository: "Center of Military History",
                                   leadingSegment: generic)
            #expect(hit?.id != "txt:|" + norm,
                    "\(generic): a generic lead must never bridge to the unattributed grab-bag")
        }
        // (b) Sole-record rule: a segment carried by BOTH an unattributed and an
        // attributed record is shadowed — an attributed query from a third repository
        // must not silently land on the unattributed bucket. (Bare unattributed
        // queries still hit it directly through step 2.)
        var segmentIds: [String: [String]] = [:]
        for record in index.collections where record.id.hasPrefix("txt:") {
            if let bar = record.id.firstIndex(of: "|") {
                segmentIds[String(record.id[record.id.index(after: bar)...]),
                           default: []].append(record.id)
            }
        }
        let shadowed = segmentIds.filter {
            $0.value.count > 1 && $0.value.contains("txt:|" + $0.key)
                && !CollectionKeying.isGenericLead($0.key)
                && !$0.value.contains("txt:center of military history|" + $0.key)
        }
        for (segment, _) in shadowed.sorted(by: { $0.key < $1.key }).prefix(3) {
            let hit = index.record(repository: "Center of Military History",
                                   leadingSegment: segment)
            #expect(hit?.id != "txt:|" + segment,
                    "\(segment): shadowed segments must not bridge to the unattributed bucket")
            let bare = index.record(repository: nil, leadingSegment: segment)
            #expect(bare?.id == "txt:|" + segment,
                    "\(segment): a genuinely unattributed query still resolves directly")
        }
    }

    @Test("No phantom Department-of-State buckets for presidential-library collections")
    func noPhantomRepositoryBuckets() throws {
        let index = try index()
        // Adversarial review 2026-07-04 finding 1: secondary-copy citations minted
        // "Department of State" records for the NSF / Whitman File / Dulles Papers.
        // After the secondary-copy gate + regeneration these are gone, while the true
        // library buckets remain.
        for phantom in ["txt:department of state|whitman file",
                        "txt:department of state|dulles paper",
                        "txt:department of state|president's office file"] {
            #expect(index.record(id: phantom) == nil,
                    "\(phantom) is a phantom secondary-copy bucket")
        }
        // A small DoS NSF record legitimately survives: three volumes' front matter
        // flat-encodes the Johnson Library heading as a *sibling* of its collections,
        // so those rows inherit "Department of State" identically on both the
        // generator and app sides (same key by construction — a corpus-encoding
        // limitation, not the doc-note phantom, which spanned 18+ volumes).
        let dosNSF = index.record(id: "txt:department of state|national security file")
        #expect((dosNSF?.volumeIds.count ?? 0) < 6,
                "the doc-note phantom mass must not return; got \(dosNSF?.volumeIds.count ?? 0) volumes")
        let johnson = try #require(index.record(id: "txt:johnson library|national security file"))
        #expect(johnson.volumeIds.count > 40, "the true Johnson NSF bucket keeps its mass")
        #expect(index.record(id: "txt:kennedy library|national security file") != nil)
        #expect(index.record(id: "txt:eisenhower library|whitman file") != nil)
    }

    @Test("Alias lookup (order step 4): unique forms resolve, shared forms never do")
    func aliasLookup() throws {
        let index = try index()
        // A form unique to Lot 64 D 199 (an editor's typo the corpus actually prints).
        let unique = index.uniqueRecord(
            forAliasNorm: CollectionKeying.segmentNorm("Secretary’s Memoranda of Conservation, Lot 64 D 199"))
        #expect(unique?.id == "lot:64D199")
        // "PPS Files" is carried by many lot records — ambiguous, must not resolve.
        #expect(index.uniqueRecord(forAliasNorm: CollectionKeying.segmentNorm("PPS Files")) == nil,
                "a shared alias may never route to one collection")
    }

    @Test("Parsed-note lookup: a lot citation lands on its lot record")
    func parsedLotNote() throws {
        let index = try index()
        let note = "Source: Department of State, Secretary’s Memoranda of Conversation, Lot 64 D 199. Secret."
        let parsed = ParsedSourceNote.lotFile(recordGroup: "RG-59",
                                              lotNumber: "64 D 199", fileIdentifier: nil)
        let record = try #require(index.record(forParsed: parsed, note: note))
        #expect(record.id == "lot:64D199")
    }

    @Test("Parsed-note lookup: a presidential-library citation lands on its text record")
    func parsedLibraryNote() throws {
        let index = try index()
        let note = "Source: Johnson Library, National Security File, Country File, Vietnam, Box 1. Secret."
        let parsed = ParsedSourceNote.presidentialLibrary(
            library: "Johnson Library",
            collection: "National Security File, Country File, Vietnam",
            fileIdentifier: nil)
        let record = try #require(index.record(forParsed: parsed, note: note))
        #expect(record.id == "txt:johnson library|national security file",
                "the leading merge segment (not the full locator chain) is the identity")
    }

    @Test("Front-matter lookup: a class leaf under the central files takes the DoS override")
    func frontMatterCentralFilesOverride() throws {
        let index = try index()
        // Front matter nests the central files under a National Archives heading, but
        // the shared identity forces the Department of State bucket — the same
        // override the generator applied, so the row joins its doc-note siblings.
        let record = try #require(index.record(
            forFrontMatterText: "Central Files 1967–69: POL 27 ARAB–ISR",
            repository: "National Archives",
            lotFileNorm: nil,
            decimalClass: "POL 27 ARAB-ISR"))
        #expect(record.id == "txt:department of state|central files 1967-69")
        #expect(record.repository == "Department of State")
    }

    /// Phase 4 verification pin: the artifact's shape for a famous lot, the
    /// singular/plural fold bridge, and the alias bridge for a Phase-3
    /// grain-mismatch case — the three spot-check families the verification
    /// session confirmed, kept green against future regenerations.
    @Test("Verification pin: 64D199 shape, plural-fold bridge, grain-mismatch bridge")
    func verificationPins() throws {
        let index = try index()

        // (a) Known-record shape: Lot 64 D 199 spans its dash/space alias variants
        // and dozens of citing volumes across three subseries.
        let lot = try #require(index.record(forLotNorm: "64D199"))
        #expect(lot.aliases.contains("64 D 199"))
        #expect(lot.aliases.contains("Secretary’s Memoranda of Conversation"))
        #expect(lot.volumeIds.contains("frus1952-54v03"))
        #expect(lot.volumeIds.contains("frus1958-60v12"))

        // (b) Plural-fold bridge: the corpus writes the Kennedy NSF mostly in the
        // plural; both forms must land on ONE record (38 singular/plural level-1
        // splits collapsed in this verification pass — Whitman File, Kennedy and
        // Johnson NSF among them).
        let plural = try #require(index.record(repository: "Kennedy Library",
                                               leadingSegment: "National Security Files"))
        let singular = try #require(index.record(repository: "Kennedy Library",
                                                 leadingSegment: "National Security File"))
        #expect(plural.id == singular.id)
        #expect(plural.id == "txt:kennedy library|national security file")

        // (c) Grain-mismatch bridge (Phase 3 bucket): a doc note reaches the library
        // sub-collection "Confidential File" as a level-2 child of White House
        // Central Files, while the front-matter grain has it as its own level-1
        // record — both resolve, and the child name matches the level-1 record's
        // name, so the surfaces bridge the two grains.
        let whcf = try #require(index.record(repository: "Johnson Library",
                                             leadingSegment: "White House Central Files"))
        #expect(whcf.children.contains { $0.name == "Confidential File" },
                "the WHCF record must carry the Confidential File sub-series")
        let confidential = try #require(index.record(repository: "Johnson Library",
                                                     leadingSegment: "Confidential File"))
        #expect(confidential.id == "txt:johnson library|confidential file")
    }

    @Test("Front-matter lookup: a lot-keyed row resolves through its lot, not its text")
    func frontMatterLotRow() throws {
        let index = try index()
        let record = try #require(index.record(
            forFrontMatterText: "Secretary’s Memoranda of Conversation: Lot 64 D 199",
            repository: "National Archives",
            lotFileNorm: "64D199",
            decimalClass: nil))
        #expect(record.id == "lot:64D199")
    }
}
