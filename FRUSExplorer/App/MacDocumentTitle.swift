// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - MacDocumentTitle

/// What the standalone reading window's toolbar centre says (UI review M-8).
///
/// ## The finding is wrong, and the correction is what makes this worth doing
/// M-8 says the document's *title* is "relegated to `.help` hover". It is not:
/// `MacDocumentView` sets `.navigationTitle` to the document's header, under a comment that says
/// so — "Window/tab title — the document's heading, falling back to its id." A reader has always
/// had the human title, in the window's own title bar.
///
/// The real defect is narrower. The `.principal` toolbar item — the centre of the window chrome,
/// the most valuable strip it has — carried `Text(currentEntry.documentId)` in monospace: a raw
/// `frus1946v06/d475` that **repeats identity the title already gives in human form**, with a
/// `.help` that repeats the title a third time. Three renderings of the same fact, one of them in
/// a form addressed to whoever maintains the app rather than whoever reads the documents.
///
/// So the fix is not "show the title". It is to make the centre say **what the title does not**:
/// which volume this is, and where in it. That is complementary rather than redundant, and it is
/// the one piece of orientation a standalone document window otherwise lacks entirely — it has no
/// breadcrumb, no back button, and no sidebar.
///
/// ## Why `distilledVolumeLabel`
/// The volume's own TEI title begins with the constant "Foreign Relations of the United States,
/// …", so printing it here would fill the strip with boilerplate — the exact problem #237 built
/// the iOS two-line title to see past. `ChronologyViewModel.distilledVolumeLabel` is the app's
/// existing short form, already rendered by Chronology, the Corpus Analytics legend and the
/// compilation parent line — and, as its two halves, by the Cross-Reference heat matrix's rows
/// (#1379) — and its tag half tells every bundled volume apart, so windows on two
/// different volumes never read alike while the label is shown whole. That was claimed here before
/// it was true: until #1388, 11 tags were shared by 29 volumes (`frus1961-63v10-12mSupp`, a
/// microfiche supplement, read `1961-63 v10`, Volume X's own tag), and only the topic half — cut
/// at 40 characters — kept those labels apart.
/// `CorpusAnalyticsServiceTests.distilledLabelUniqueAcrossBundledCorpus` now pins the tag half over
/// the whole bundled manifest.
///
/// **Until L38 a window too narrow for the whole label could still cut the tag**, which sat in the
/// middle of "Topic · tag · Doc N" in a centre item that elided the middle of the string. Since L38
/// the title takes the tag alone with the number, and the topic is not shown in the window's chrome.
///
/// ## Both document windows, since L21
/// Until L21 (UI review MAC-1, #1921) only the standalone window used this type. The main window
/// set no title, so the Window menu listed every main window as "FRUS Explorer", and its centre
/// showed the raw id this type was written to replace. Both windows now take their title from
/// ``windowTitle(for:volume:)`` and draw their centre through `MacDocumentPrincipalTitle`, so the
/// two cannot drift apart again.
///
/// ## The title is the volume and number, the centre the head, since L38 (F2, decision 219)
/// L21 titled the windows with the document's head and put the volume and number in the centre.
/// The title bar's room is what the toolbar leaves, and AppKit cut the head in almost every window
/// (R6's F2). Measured in the check copy with `frus1946v06` d475 open: at the main window's default
/// 1,200 pt the title read "The Chargé in the Soviet Union (Kenn…", and at its least width, 640 pt,
/// "The Chargé in the…", with every tool folded into ». The owner chose, from captures of three
/// layouts, the one that swaps the two: the title is the volume's tag and the number, "1946 v6 · Doc
/// 475", which fits whole where the head did not, and the centre is the head, cut at its tail where
/// its own room runs out, with the whole head and the id one hover away. The Window menu and Mission
/// Control list the windows by where their documents are, and two ⌘N windows on different
/// documents still read apart, by their numbers. The head stays whole at the top of the page.
///
/// Version history:
///   1.0 — CW-10 (UI review M-8)
///   1.1 — #1491 review round 1: a document the volume prints without a number reads "… ·
///          Unnumbered (d710a-1)", where it read "… · Doc [Unnumbered document following …]"
///   1.2 — L21 (MAC-1): the title both document windows set, the head, and
///          ``principalNumber(stored:documentId:)``, the number the centre names
///   1.3 — L38 (F2, decision 219): the title is the volume's tag and the number
///          (``windowTitle(for:volume:)``), and the centre the head (``headTitle(header:documentId:)``)
enum MacDocumentTitle {

    /// A document window's title: the volume's tag and the document's number, "1946 v6 · Doc 475"
    /// (L38, F2).
    ///
    /// The title is what the Window menu, Mission Control and the window's own title bar show. The
    /// tag tells every bundled volume apart (above), and with the number it fits whole in the room a
    /// toolbar leaves the title, where the head did not. A document with no number of its own, a
    /// volume's list of persons for one, adds its id, so two such windows on one volume still read
    /// apart; a volume the manifest does not hold leaves the id alone, as the centre did before.
    ///
    /// - Parameters:
    ///   - entry: The document the window shows.
    ///   - volume: Its volume's manifest entry, or `nil` when the manifest holds none.
    /// - Returns: The window's title.
    static func windowTitle(for entry: DocumentBrowserEntry, volume: VolumeManifestEntry?) -> String {
        let tag = volume.map {
            ChronologyViewModel.distilledVolumeLabelParts(volumeId: $0.volumeId, subseries: $0.subseries,
                                                          title: $0.title).tag
        }
        return windowTitle(volumeTag: tag,
                           documentNumber: principalNumber(stored: entry.documentNumber, documentId: entry.documentId),
                           documentId: entry.documentId)
    }

    /// ``windowTitle(for:volume:)``'s rule over its values.
    ///
    /// - Parameters:
    ///   - volumeTag: The volume's tag ("1946 v6"), or `nil` when the manifest holds no entry.
    ///   - documentNumber: The number to name (``principalNumber(stored:documentId:)``), or `nil`.
    ///   - documentId: The document's id.
    /// - Returns: "1946 v6 · Doc 475"; "1946 v6 · Unnumbered (d710a-1)"; "1946 v6 · persons" for a
    ///   document with no number; the id alone for a volume the manifest does not hold.
    static func windowTitle(volumeTag: String?, documentNumber: String?, documentId: String) -> String {
        guard let volumeTag, !volumeTag.isEmpty else { return documentId }
        guard let documentNumber, !documentNumber.isEmpty else {
            return String(format: String(localized: "macDocument.title.noNumber %@ %@",
                                         defaultValue: "%1$@ · %2$@"),
                          volumeTag, documentId)
        }
        return principalLabel(volumeLabel: volumeTag, documentNumber: documentNumber, documentId: documentId)
    }

    /// What a document window's centre says since L38 (F2): the document's printed head, or its id
    /// when it has none.
    ///
    /// - Parameters:
    ///   - header: The entry's head, as the producer that opened the document passed it.
    ///   - documentId: The document's id, the centre when the head is empty.
    /// - Returns: The head, or the id.
    static func headTitle(header: String, documentId: String) -> String {
        header.isEmpty ? documentId : header
    }

    /// The number the title names (the centre's until L38): the one the entry carries, or, when the
    /// producer that opened the document passed none, the one its id spells (`d475` → `475`).
    ///
    /// About half of the app's `DocumentBrowserEntry` constructions pass no number: Research's
    /// rows and the Corpus Browser's among them. Without the id's number, the main window's centre
    /// read the volume alone for those, so three same-headed telegrams opened from Research
    /// (Documents 474, 475 and 476 of `frus1946v06`) read alike there too. The id stands in only
    /// where it is the number (`CitableDocumentNumber.fromDocumentId(_:)`), the rule every list
    /// that names a document follows; a stored number, a bracketed one included, wins.
    ///
    /// - Parameters:
    ///   - stored: The entry's `documentNumber`, or `nil` when its producer passed none.
    ///   - documentId: The document's id.
    /// - Returns: The number to pass to ``principalLabel(volumeLabel:documentNumber:documentId:)``.
    static func principalNumber(stored: String?, documentId: String) -> String? {
        if let stored, !stored.isEmpty { return stored }
        return CitableDocumentNumber.fromDocumentId(documentId)
    }

    /// A document's place: its volume and its number. The toolbar centre's text until L38, and since
    /// then the window's title, with the volume's tag alone (``windowTitle(volumeTag:documentNumber:documentId:)``).
    ///
    /// Falls back to the document id when the volume is not in the manifest — a window restored
    /// for a volume that has since been removed still has to say something, and the id is what
    /// this strip showed before. That is a degraded state, not the normal one, so it keeps the
    /// old behaviour rather than inventing a placeholder.
    ///
    /// - Parameters:
    ///   - volumeLabel: The short volume form, or `nil` when the manifest has no entry.
    ///   - documentNumber: The document's number within its volume, if it has one. Editorial
    ///     notes and front-matter sections do not. A stored number that is the editors' bracketed
    ///     description of an unnumbered document (`frus1945Berlinv02`'s 217) names it "Unnumbered
    ///     (d710a-1)" instead (`CitableDocumentNumber.unnumberedLabel`, #1491).
    ///   - documentId: The raw id, used as the fallback and to name an unnumbered document.
    /// - Returns: The label to render.
    static func principalLabel(volumeLabel: String?,
                               documentNumber: String?,
                               documentId: String) -> String {
        guard let volumeLabel, !volumeLabel.isEmpty else { return documentId }
        guard let documentNumber, !documentNumber.isEmpty else { return volumeLabel }
        if CitableDocumentNumber.isUnnumbered(printed: documentNumber) {
            return String(format: String(localized: "macDocument.principal.unnumbered %@ %@",
                                         defaultValue: "%1$@ · %2$@"),
                          volumeLabel, CitableDocumentNumber.unnumberedLabel(documentId: documentId))
        }
        return String(format: String(localized: "macDocument.principal %@ %@",
                                     defaultValue: "%1$@ · Doc %2$@"),
                      volumeLabel, documentNumber)
    }

    /// Whether the centre shows the raw id rather than a head (since L38, F2).
    ///
    /// The view uses this to keep the monospaced face for an id and drop it for prose: a
    /// monospaced head reads as machine output, which is half of what M-8 complained about.
    ///
    /// - Parameter header: The entry's head.
    /// - Returns: `true` when the centre will be the bare document id.
    static func isFallback(header: String) -> Bool {
        header.isEmpty
    }
}
