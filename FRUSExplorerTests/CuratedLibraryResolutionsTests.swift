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

// MARK: - CuratedLibraryResolutionsTests

/// Pins the curated library resolutions (#355 / N-4) — the first archival destinations Source
/// Explorer has ever had for a presidential-library citation.
///
/// Every library cluster in `collection-authority.json` carries `naId: nil`, and that is
/// structural rather than an oversight: presidential libraries sit outside every NARA record
/// group, so the record-group-filtered catalogue harvest cannot reach them. The destination is
/// therefore the repository's own finding aid.
///
/// ## The sub-collection level, and why it is optional
/// Measured over the corpus, two rows are containers rather than collections:
/// - **Carter / National Security Affairs**, 3,591 documents: `Brzezinski Material` 2,065
///   (57.5%) and `Staff Material` 1,444 (40.2%) — 97.7% in two branches the library describes
///   separately. One link for the row is right for at most 57% of it.
/// - **Library of Congress / Manuscript Division**, 958 documents naming **12** personal-papers
///   collections (Kissinger 745, Harriman 54, Harold Brown 30 …). The row is the division that
///   holds them, not a collection.
///
/// Everywhere else level 1 *is* the collection, so the sub-collection stays optional.
///
/// Version history:
///   1.0 — Session 2026-08-06: #355 / N-4, Carter + Library of Congress
@Suite("Curated library resolutions")
struct CuratedLibraryResolutionsTests {

    private func bundled() throws -> CuratedLibraryResolutions {
        try #require(CuratedLibraryResolutionsStore.shared,
                     "curated-library-resolutions.json must decode from the app bundle")
    }

    // MARK: - Sub-collection extraction

    /// The level-2 segment has to come back out of the note: the per-document parse keeps only
    /// the level-1 collection, and the authority artifact's `children` are volume-grain
    /// vocabulary with no document linkage.
    @Test("The sub-collection is recovered from the citation")
    func subCollectionIsExtracted() {
        let carter = "Source: Carter Library, National Security Affairs, Brzezinski Material, "
            + "Subject File, Box 55, SALT , Chronology, 1/24/77–3/24/77. Secret."
        #expect(CuratedLibraryResolutions.subCollection(
            inNote: carter, afterCollection: "National Security Affairs") == "Brzezinski Material")

        let staff = "Source: Carter Library, National Security Affairs, Staff Material, Office, "
            + "Box 69, USSR : Brezhnev - Carter Correspondence, 1–2/77. No classification marking."
        #expect(CuratedLibraryResolutions.subCollection(
            inNote: staff, afterCollection: "National Security Affairs") == "Staff Material")

        let loc = "Source: Library of Congress, Manuscript Division, Kissinger Papers, "
            + "Box TS 82, NSC Meetings, Jan–Mar 1969. Top Secret."
        #expect(CuratedLibraryResolutions.subCollection(
            inNote: loc, afterCollection: "Manuscript Division") == "Kissinger Papers")
    }

    /// A box or folder is a locator, not a sub-collection. Treating `Box 17` as one would key
    /// every document separately and resolve none of them.
    @Test("A locator is never mistaken for a sub-collection")
    func locatorsAreRefused() {
        for note in ["Source: Carter Library, Plains File, Box 17, Nodis.",
                     "Source: Carter Library, Plains File, Folder 3.",
                     "Source: Kennedy Library, National Security Files, Reel 12."] {
            let collection = note.contains("Plains") ? "Plains File" : "National Security Files"
            #expect(CuratedLibraryResolutions.subCollection(
                inNote: note, afterCollection: collection) == nil, "leaked a locator from: \(note)")
        }
        // A citation that stops at the collection has no sub-collection either.
        #expect(CuratedLibraryResolutions.subCollection(
            inNote: "Source: Carter Library, Plains File.", afterCollection: "Plains File") == nil)
    }

    // MARK: - Lookup

    @Test("A sub-collection resolves to its own finding aid")
    func subCollectionResolves() throws {
        let curated = try bundled()
        let brzezinski = curated.resolution(repository: "Carter Library",
                                            collection: "National Security Affairs",
                                            subCollection: "Brzezinski Material")
        let staff = curated.resolution(repository: "Carter Library",
                                       collection: "National Security Affairs",
                                       subCollection: "Staff Material")
        #expect(brzezinski != nil, "Brzezinski Material (2,065 documents) must resolve")
        #expect(staff != nil, "Staff Material (1,444 documents) must resolve")
        #expect(brzezinski?.findingAid != nil)
        #expect(staff?.findingAid != nil)
    }

    /// The corpus misspells the name three ways, and those are real documents.
    @Test("Sub-collection aliases and misspellings resolve to the same aid")
    func aliasesResolve() throws {
        let curated = try bundled()
        let canonical = curated.resolution(repository: "Carter Library",
                                           collection: "National Security Affairs",
                                           subCollection: "Brzezinski Material")
        // Compared on the whole resolution, not the URL. Carter's collection-wide entry shares
        // the container aid's URL, so a URL-only assertion passes even with alias matching
        // removed — the misspelling simply falls through to the collection-wide answer. The
        // rationale differs, so equality distinguishes "matched the alias" from "fell through".
        let collectionWide = curated.resolution(repository: "Carter Library",
                                                collection: "National Security Affairs",
                                                subCollection: nil)
        #expect(canonical?.url == collectionWide?.url, "fixture guard: the URLs really are shared")
        #expect(canonical != collectionWide, "fixture guard: …but the entries are distinguishable")
        for spelling in ["Brzezinski Materials", "Brzezinksi Material", "Brzezinsky Material"] {
            #expect(curated.resolution(repository: "Carter Library",
                                       collection: "National Security Affairs",
                                       subCollection: spelling) == canonical,
                    "\(spelling) must match the alias, not fall through to the collection-wide entry")
        }
    }

    /// The Reagan citations write one series both ways — `NSC Country File` and
    /// `NSC : Country File` — 76 documents turning on a punctuation mark. The fold is local to
    /// this artifact so it cannot leak into the authority keying, where a colon IS meaningful.
    @Test("A colon is a separator when matching a sub-collection")
    func colonIsASeparator() throws {
        let curated = try bundled()
        let plain = curated.resolution(repository: "Reagan Library",
                                       collection: "Executive Secretariat",
                                       subCollection: "NSC Country File")
        #expect(plain != nil, "the Reagan Country File must resolve")
        for variant in ["NSC : Country File", "NSC:Country File", "NSC Country Files"] {
            #expect(curated.resolution(repository: "Reagan Library",
                                       collection: "Executive Secretariat",
                                       subCollection: variant) == plain,
                    "\(variant) must reach the same aid")
        }
        // …and the fold must not merge genuinely different series.
        #expect(curated.resolution(repository: "Reagan Library",
                                   collection: "Executive Secretariat",
                                   subCollection: "NSC Head of State File") != plain)
    }

    /// Nixon writes the same level with `and` and with `&`.
    @Test("Ampersand and 'and' reach the same Nixon sub-series")
    func ampersandFolds() throws {
        let curated = try bundled()
        let spelled = curated.resolution(repository: "Nixon", collection: "White House Special Files",
                                         subCollection: "Staff Member and Office Files")
        let amp = curated.resolution(repository: "Nixon", collection: "White House Special Files",
                                     subCollection: "Staff Member & Office Files")
        #expect(spelled != nil || amp == nil,
                "if the spelled form is curated the ampersand must reach it too")
        if spelled != nil { #expect(amp == spelled) }
    }

    /// The Library of Congress row has no honest whole-row answer — it is a division, not a
    /// collection — so an unrecognized sub-collection must resolve to **nothing** rather than
    /// falling back to a repository-level link. That fallback is the defect this work removes.
    @Test("A container row never answers for an unrecognized sub-collection")
    func containerRowDoesNotFallBack() throws {
        let curated = try bundled()
        #expect(curated.resolution(repository: "Library of Congress",
                                   collection: "Manuscript Division",
                                   subCollection: "Some Unlisted Papers") == nil)
        #expect(curated.resolution(repository: "Library of Congress",
                                   collection: "Manuscript Division",
                                   subCollection: nil) == nil,
                "there is no collection-wide answer for a division")
    }

    @Test("The lookup normalizes repository and collection like the authority keying")
    func lookupUsesSharedNormalizers() throws {
        let curated = try bundled()
        let canonical = curated.resolution(repository: "Carter Library",
                                           collection: "National Security Affairs",
                                           subCollection: "Brzezinski Material")
        #expect(canonical != nil)
        // Full library name, and the plural-folded collection spelling.
        #expect(curated.resolution(repository: "Jimmy Carter Library",
                                   collection: "National Security Affair",
                                   subCollection: "Brzezinski Material")?.url == canonical?.url)
    }

    @Test("An uncurated repository resolves to nothing")
    func uncuratedResolvesToNil() throws {
        let curated = try bundled()
        #expect(curated.resolution(repository: "Reagan Library", collection: "Matlock Files",
                                   subCollection: nil) == nil)
    }

    // MARK: - Artifact integrity

    /// A curated entry whose URL does not parse is worse than no entry: the row would render a
    /// title with nothing behind it.
    @Test("Every curated entry carries a parseable finding aid")
    func everyEntryHasAUsableURL() throws {
        let curated = try bundled()
        #expect(!curated.entries.isEmpty)
        for entry in curated.entries {
            #expect(entry.resolution.findingAid != nil,
                    "\(entry.collection)/\(entry.subCollection ?? "—") has an unparseable URL")
            #expect(!entry.resolution.title.isEmpty)
            #expect(entry.resolution.url.hasPrefix("https://"),
                    "\(entry.resolution.url) is not https")
        }
    }

    /// Two entries answering the same key would make the resolution order-dependent.
    @Test("No two entries share a key")
    func keysAreUnique() throws {
        var seen = Set<String>()
        for entry in try bundled().entries {
            let key = CuratedLibraryResolutions.collectionKey(entry.repository, entry.collection)
                + "|" + (entry.subCollection.map { CuratedLibraryResolutions.subCollectionKey($0) } ?? "")
            #expect(seen.insert(key).inserted, "duplicate curated key: \(key)")
        }
    }

    /// Both platforms must consult the store. This is a **deletion** guard: a source scan
    /// cannot tell a live call from one behind `if false`, and does not try. The realistic
    /// regression it exists for is a call site that never gets written, not one disabled on
    /// purpose.
    ///
    /// Both platforms must consult the store. This codebase has shipped a Source Explorer
    /// affordance to iOS only before (#617 did it in Collections), and the macOS panel is a
    /// separate hand-written view rather than a shared one.
    @Test("Both Source Explorer views consult the curated store")
    func bothPlatformsWired() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        for path in ["FRUSExplorer/SourceExplorer/SourceExplorerView.swift",
                     "FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift"] {
            let text = try String(contentsOf: root.appending(path: path), encoding: .utf8)
            let code = text.split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
            #expect(code.contains("CuratedLibraryResolutionsStore.shared?.resolution("),
                    "\(path) does not consult the curated library store")
            #expect(code.contains("CuratedLibraryResolutions.subCollection("),
                    "\(path) resolves without the sub-collection — the container rows would be wrong")
        }
    }
}
