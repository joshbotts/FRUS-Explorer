// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - RollScan

/// One digitised microfilm roll, keyed by the NARA identifier the app already stores (#663).
///
/// The app-side mirror of `DigitizedRangeIndexGeneratorCore.RollScan`; the JSON is the contract.
struct RollScan: Codable, Sendable, Equatable {
    let naId: String
    let objectCount: Int
    let objectUrl: String?
    let objectFilename: String?

    /// The direct scan link, **only when it is a whole-roll PDF** — the same rule
    /// `DigitizedRange` applies, for the same reason: a `.tif` object URL is the *first image*
    /// of the unit, and one frame of a thousand is worse than the viewer holding all of them.
    /// Measured, 1,235 of the 1,238 M862 rolls are PDFs, so this withholds almost nothing.
    var rollPDFURL: URL? {
        guard let objectUrl, let objectFilename,
              objectFilename.lowercased().hasSuffix(".pdf") else { return nil }
        return URL(string: objectUrl)
    }
}

// MARK: - RollScansIndex

/// Scan data for the M862 Numerical File rolls `central-files-index.json` already names (#663).
///
/// ## Why this is a second artifact rather than four more fields on the central-files index
/// `central-files-index.json` is rebuilt **wholesale** by the owner-keyed
/// `CentralFilesIndexGenerator` harvest. Any field added to its roll records by a different pass
/// would be dropped by the next routine regeneration, silently — the same reasoning that made
/// `lot-claimants-index.json` its own file rather than a column on that index. Keyed by NAID,
/// this survives a re-harvest of either side.
///
/// ## What it buys
/// The pre-1910 route already resolves a `File No.` to its roll(s); what it could not do was
/// open one. Measured over the shipped bundles and the owner's index:
///
/// | | |
/// |---|---|
/// | bundled M862 rolls | 1,261 |
/// | of those, joined to a digitised record by NAID | **1,218 (96.6%)** |
/// | 1906–1910 documents resolving to at least one roll | **2,449** |
/// | of those, every roll digitised | 2,425 |
/// | roll references digitised / not | 5,094 / 72 |
///
/// The join needs no parsing at all, which is why it reaches 96.6% where the decimal-range work
/// (#663's first half) had to parse titles and reached 14.7% of its candidate units.
///
/// The 43 unjoined rolls are not an error to hide: those rows keep their catalog link and get no
/// PDF button, exactly as a `.tif`-only unit does.
///
/// Version history:
///   1.0 — Session 2026-08-07: #663 follow-up
struct RollScansIndex: Codable, Sendable {
    let schemaVersion: Int
    let generated: String
    let seriesNaId: String
    let scans: [RollScan]

    /// `scans` keyed by NAID, built once at decode — the pre-1910 section asks once per roll.
    private let byNaId: [String: RollScan]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, generated, seriesNaId, scans
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        generated = try c.decodeIfPresent(String.self, forKey: .generated) ?? ""
        seriesNaId = try c.decodeIfPresent(String.self, forKey: .seriesNaId) ?? ""
        scans = try c.decodeIfPresent([RollScan].self, forKey: .scans) ?? []
        byNaId = Dictionary(scans.map { ($0.naId, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// The scan for a roll, or `nil` when the harvest has none for it.
    func scan(forNaId naId: String) -> RollScan? { byNaId[naId] }
}

// MARK: - RollScansIndexStore

/// Loads the bundled `roll-scans-index.json` once. `nil` when the resource is absent or
/// malformed — in which case the pre-1910 section renders exactly as it did before, with the
/// catalog links and no PDF buttons.
enum RollScansIndexStore {
    static let shared: RollScansIndex? = load()

    private static func load() -> RollScansIndex? {
        guard let url = Bundle.main.url(forResource: "roll-scans-index",
                                        withExtension: "json") else {
            #if DEBUG
            print("[SourceExplorer] RollScansIndexStore: resource not found in bundle.")
            #endif
            return nil
        }
        do {
            return try JSONDecoder().decode(RollScansIndex.self, from: Data(contentsOf: url))
        } catch {
            #if DEBUG
            print("[SourceExplorer] RollScansIndexStore: decode failed — \(error)")
            #endif
            return nil
        }
    }
}

// MARK: - DigitizedScanPresentation

/// What both platforms say about one digitised scan (#663).
///
/// ## Why a presentation type rather than a shared row view
/// The two Source Explorer views style their controls differently — macOS uses
/// `.buttonStyle(.link)`, iOS a plain `Label` — so a single shared `View` would have to carry a
/// platform switch inside it. What actually needs to be identical is **what the row says**: the
/// title, the image count, the roll's filename, and which links exist. That lives here, so the
/// two rows cannot drift on the wording or on whether a PDF button appears, while each keeps its
/// own chrome. Same shape as `ParisPeaceRecords` and `ManuscriptRepositoryGuidance`.
///
/// ## Why the caveat is a parameter and not a constant
/// The decimal route and the numerical route need **different sentences**, and using one for
/// both would make one of them wrong:
///
/// - decimal: the scan covers the *file range* the citation falls in, and the document is
///   somewhere inside it;
/// - numerical: the roll genuinely holds the case — what it does not do is point at the page.
///
/// Collapsing those into one line was the temptation this type exists to resist.
struct DigitizedScanPresentation: Equatable {
    /// NARA's own title for the scanned unit, shown verbatim.
    let title: String
    /// The scan's image count.
    let objectCount: Int
    /// The whole-roll PDF, when the unit publishes one.
    let pdfURL: URL?
    /// The PDF's filename, which names the microfilm publication and roll.
    let pdfFilename: String?
    /// The unit's catalog record — always present; it is the page with the viewer on it.
    let catalogURL: URL?

    /// "1,172 scanned images".
    var imageCountLabel: String {
        String(localized: "source.explorer.scans.count",
               defaultValue: "\(objectCount) scanned images")
    }

    /// "Open M862_Roll1.pdf".
    var pdfLabel: String? {
        pdfFilename.map {
            String(localized: "source.explorer.scans.openRoll", defaultValue: "Open \($0)")
        }
    }

    /// The presentation for a decimal-range scan (#663's first half).
    init(_ range: DigitizedRange) {
        title = range.title
        objectCount = range.objectCount
        pdfURL = range.rollPDFURL
        pdfFilename = range.rollPDFURL == nil ? nil : range.objectFilename
        catalogURL = range.catalogURL
    }

    /// The presentation for a Numerical File roll, whose scan data is looked up by NAID.
    ///
    /// `scan` is `nil` for the 43 bundled rolls the harvest has no digitised record for; the row
    /// then shows the title and the catalog link and no PDF button, which is the honest state
    /// rather than a missing one.
    init(roll: NumericalFileRoll, scan: RollScan?) {
        title = roll.title
        objectCount = scan?.objectCount ?? 0
        pdfURL = scan?.rollPDFURL
        pdfFilename = scan?.rollPDFURL == nil ? nil : scan?.objectFilename
        catalogURL = URL(string: roll.catalogURL)
    }
}
