// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ParsedTEIHeader

/// What `TEIHeaderParser` reads out of a FRUS volume's `<teiHeader>`.
///
/// ## Why this lives in a kit rather than in either consumer
/// Two places need to read a volume's own header, and they must read it the same way: the
/// `ManifestGenerator`, which built the bundled `manifest.json` from GitHub's copies, and the app,
/// which since #777 parses a **side-loaded** volume's header to give it a title and a coverage
/// range the catalogue cannot supply. A second parser would drift, and the drift would surface as
/// a side-loaded volume whose metadata disagreed with the same volume downloaded — the worst kind
/// of difference, because nothing would report it.
///
/// ## Why it carries no `VolumeStatus`
/// The obvious extraction — move `ParsedTEIHeader` and the `VolumeStatus`/`DateRange` types it
/// referenced — collides head-on: `ManifestGeneratorCore/ManifestModels.swift` and
/// `FRUSExplorer/Models/Manifest/ManifestModels.swift` each declare their own `VolumeManifestEntry`,
/// `VolumeStatus` and `DateRange`, and the app cannot see the generator's.
///
/// The resolution is that **the kit owns the grammar and each consumer owns its model.** Nothing
/// here is a manifest type. When that was written the parser never set `status` and the note said
/// the TEI header does not carry publication status; **that was wrong**, or has since become so —
/// `revisionDesc/@status` carries it, and 3 of the 553 shipped volumes say `partially-published`
/// there while the manifest recorded them as published. The header's own words are now read into
/// ``publicationStatus`` and mapped to a manifest status by whoever builds a manifest, which keeps
/// this type a faithful report of the document.
///
/// Version history:
///   1.0 — Session 2026-08-09 (#777): extracted from `ManifestGeneratorCore/ManifestModels.swift`
///         so the app can read a side-loaded volume's header with the generator's own grammar
///   1.1 — Session 2026-09-09: `publicationStatus` and `publishedWhen`, read from `revisionDesc`.
///         OH's release of `frus1981-88v16` arrived with an empty `publicationStmt` print year and
///         both facts stated in `revisionDesc` instead.
public struct ParsedTEIHeader: Sendable, Equatable {

    /// The volume's full title, e.g. *Foreign Relations of the United States, 1969–1976, Volume I*.
    public var title: String = ""

    /// The volume's editors, in the order the header lists them.
    public var editors: [String] = []

    /// The series' general editor, when the header names one.
    public var generalEditor: String? = nil

    /// The print year, as the text of `publicationStmt/date[@type="publication-date"]`.
    ///
    /// Never `@when` and never a content date — the distinction matters, and the 1.2 fallback
    /// below is why: the ten oldest 1860s volumes use an untyped `publicationStmt/date`.
    public var publicationDate: String? = nil

    /// Earliest document date in the volume's declared coverage range.
    public var earliestDate: String? = nil

    /// Latest document date in the volume's declared coverage range.
    public var latestDate: String? = nil

    /// How many `<div type="document">` elements the header's own counting reports.
    public var documentCount: Int = 0

    /// The volume's subject tags.
    public var tags: [String] = []

    /// `revisionDesc/@status` verbatim — `published`, `partially-published`, `being-cleared`,
    /// `planned`, `being-researched`, `being-digitized` — or nil when the header has no
    /// `revisionDesc` at all.
    ///
    /// Reported, never interpreted: mapping these six words onto a manifest's three-case status is
    /// the manifest builder's policy, not the document's meaning. Measured over all 694 corpus
    /// files, reading each header WHOLE: published 551, being-cleared 51, planned 42,
    /// being-researched 37, being-digitized 10, partially-published 3 — and **every file has one**,
    /// so nil is a guard rather than a case. Among the 553 shipped volumes only two of the six
    /// occur (published 550, partially-published 3), because the in-progress states belong to
    /// volumes the app does not carry.
    ///
    /// A first pass at these numbers read only each file's first 20 KB and reported 20 files with
    /// no `revisionDesc` and 2 partially-published. Both were artefacts of the truncation — the
    /// element sits at the END of the header, past 20 KB in the longer volumes — and the third
    /// partially-published volume, `frus1969-76ve10`, was hidden by it.
    public var publicationStatus: String? = nil

    /// The `@when` of the `<change>` that marks THIS volume published, or nil when there is none.
    ///
    /// The entry is identified by `corresp="#<the volume's own frus idno>"`, never by position: a
    /// partially-published volume lists a `<change>` per chapter, and `frus1981-88v16` states four
    /// published chapters among eleven, the other seven `being-cleared`. Measured: 553 of the 694
    /// corpus files carry such an entry, and **not one** file carries a published `@when` without a
    /// matching self-corresp — so the rule never has to guess between siblings.
    ///
    /// This is a *digital publication* date and ``publicationDate`` is the *print* year. They are
    /// not the same fact and must not be merged: over the shipped volumes where both exist the
    /// years agree in 525 and **differ in 26** (`frus1950v01` prints 1977 and was published
    /// digitally in 1998).
    public var publishedWhen: String? = nil

    /// Creates an empty header, which is what the parser fills in place.
    public init() {}
}

// MARK: - Errors

/// Why a header could not be parsed.
public enum TEIHeaderParserError: Error, Sendable, Equatable {
    /// `XMLParser` refused the bytes.
    case xmlParseError(String)
}
