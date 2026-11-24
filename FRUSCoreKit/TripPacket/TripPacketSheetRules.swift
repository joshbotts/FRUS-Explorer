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

// The two rules of the packet's sheet that a host needs without the sheet: a static collection's seeds,
// and the PDF's file name. The sheet, its smart collection's resolution and its drawing of the PDF stay
// the app's (`FRUSExplorer/TripPacket/TripPacketSheet.swift`).

// MARK: - TripPacketSeed

/// How a collection becomes a reading list — the one membership rule the add-to-plan flows share.
///
/// A namespace, with no cases. Through Phase 3 it was the packet sheet's seed, with three:
/// `.documents` (an explicit reading list), `.collection` (resolved inside the sheet) and `.plan`.
/// The first two were constructed nowhere once the Archives Visit editor became the sheet's only
/// presenter, and on those paths the project's research question still seeded the inquiry's topic
/// without the topic field showing it — the mismatch #1366 fixed on the plan path. #1423 deleted
/// them, and the sheet now takes its ``ArchiveVisitPlan`` directly (`TripPacketSheet.plan`). A new
/// entry point makes a plan (`ArchiveVisitPlan.make`) and presents that, so it follows the same
/// seed-at-creation rule; it does not get a second way into the sheet.
///
/// What is left is what the collection surfaces call before they make a plan: a smart
/// collection's membership comes from its saved search (matching export behavior — the editor
/// itself tells the user "static entries are ignored"), and a static collection contributes its
/// document entries AND its excerpts, whose `volumeId`/`documentId` provenance is a real
/// document reference the old filter dropped.
///
/// Version history:
///   1.0 — 2026-11-23 (FRUS Explorer Light, S30a): declared in FRUSCoreKit, out of
///          `TripPacketSheet.swift`, with the static collection's rule over its entries as values;
///          a smart collection's resolution, which runs the app's saved search, stays there
public enum TripPacketSeed {

    /// The static-collection seed rule, separated so it is testable: document and excerpt
    /// entries with non-empty ids, in `sortOrder`, de-duplicated first-occurrence-wins.
    ///
    /// Over a collection's entries as values, each with its kind, its document's ids and its place, so
    /// that a host reads a collection the app stores as the app does; the app passes its `CollectionEntry`
    /// rows through its overload (`TripPacket+App.swift`).
    public static func staticSeedDocuments(
        from entries: [(kind: CollectionEntryKind, volumeId: String, documentId: String, sortOrder: Int)]
    ) -> [(volumeId: String, documentId: String)] {
        var seen = Set<String>()
        var out: [(volumeId: String, documentId: String)] = []
        for entry in entries.sorted(by: { $0.sortOrder < $1.sortOrder })
        where (entry.kind == .document || entry.kind == .excerpt)
            && !entry.volumeId.isEmpty && !entry.documentId.isEmpty {
            let key = "\(entry.volumeId)/\(entry.documentId)"
            if seen.insert(key).inserted {
                out.append((volumeId: entry.volumeId, documentId: entry.documentId))
            }
        }
        return out
    }
}

// MARK: - TripPacketPDFRenderer

/// Paginates the packet string into a US-Letter PDF (#830).
///
/// ## The same string, never a second composition
/// The exporter's one-format rule stands: this renders the EXACT plain text the reader
/// reviewed, in a monospaced face, flowed across pages by CoreText. A structured PDF
/// (styled headings, laid-out tables) would be a second composition of the packet — a
/// second place for its honesty rules to be applied differently — which is the exact
/// failure #960 measured across the collection exporters. The technique is
/// `PDFCollectionExporter`'s (CoreText framesetter into a `CGContext` PDF); the ambition
/// deliberately is not.
///
/// Version history:
///   1.0 — Session 2026-08-23: #830
///   1.1 — Lane EXPORT review round 1: `fileName(title:)` cuts the title to fit (`ExportFileName`), so a long
///          project name no longer leaves the sheet with no PDF to share
///   1.2 — 2026-11-23 (FRUS Explorer Light, S30a): declared in FRUSCoreKit with `fileName(title:)`, out of
///          `TripPacketSheet.swift`, so a host names its PDF by the same rule; the drawing, through CoreText,
///          stays the app's (`render(packet:title:)`, in that file)
public enum TripPacketPDFRenderer {

    /// The PDF's file name: "Archives Visit — " and `title`, its path separators written as `-`, cut on a whole
    /// character so the name fits the file system (`ExportFileName`, #1498's rule).
    ///
    /// Uncut, a project name past about 230 characters made a name the file system refuses, `CGDataConsumer(url:)`
    /// failed, `render` returned `nil`, and the sheet's Share PDF control disappeared without a word (review round 1).
    ///
    /// - Parameter title: The packet's title — the project's name.
    /// - Returns: The file name, ending in `.pdf`.
    public static func fileName(title: String) -> String {
        let prefix = "Archives Visit — "
        let safeName = title.components(separatedBy: CharacterSet(charactersIn: "/\\:"))
            .joined(separator: "-")
        let stem = ExportFileName.fitting(safeName,
                                          reserving: ExportFileName.length(of: prefix) + ExportFileName.length(of: ".pdf"))
        return prefix + stem + ".pdf"
    }
}
