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
/// here is a manifest type. It is also not a loss: `TEIHeaderParser` never set `status` — the TEI
/// header does not carry publication status — so the field was only ever the `.published` default,
/// supplied now by whichever consumer needs it.
///
/// Version history:
///   1.0 — Session 2026-08-09 (#777): extracted from `ManifestGeneratorCore/ManifestModels.swift`
///         so the app can read a side-loaded volume's header with the generator's own grammar
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

    /// Creates an empty header, which is what the parser fills in place.
    public init() {}
}

// MARK: - Errors

/// Why a header could not be parsed.
public enum TEIHeaderParserError: Error, Sendable, Equatable {
    /// `XMLParser` refused the bytes.
    case xmlParseError(String)
}
