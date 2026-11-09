// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import FRUSCoreKit
import SourceNoteKit

// MARK: - VolumeAnnotationsAssembly

/// Counts one volume's ``VolumeAnnotations`` from its TEI scan and what its index holds.
///
/// The documents are the scan's: the TEI's `div[@type="document"]` inside `<body>`. Each category
/// is counted over them by the app's own rule wherever the app has one, read from the index:
/// - **people:** a person mention that resolves to the volume's `persons` rows (the People
///   browser's rule, borrowed split-set lists and the document-level `@ana` included);
/// - **source notes:** the stored note (`IndexingPipeline.extractSourceNote`), unless it is a
///   despatch number (``isDespatchNumber(_:)``), which keeps out `frus1870`'s "No. 3." notes. Its
///   form is where the TEI prints it: a `note[@rend="inline"]` is the file number printed above
///   the heading, any other note the citation form. The text alone cannot tell them apart: the
///   microfiche supplements' summary notes open with neither "Source:" nor a file number;
/// - **classification:** a stored marking, the note's or the opener's (index versions 72 and 73);
/// - **despatch numbers:** a stored serial (#965);
/// - **numbered:** the stored heading opens with its printed number ("12. Telegram From …");
/// - **abbreviations:** a `gloss` pointer, or one of the document div's own `@ana`, that names one
///   of the volume's `terms` rows: the terms the reader links in the text, or lists below the
///   document (#1599), which is how `frus1981-88v16` names them.
///
/// The other layers the app does not read, and the scan's TEI rule counts them. Among them, since
/// Lane 1 of the follow-ups plan, the editors' bracketed omissions (`EditorialOmissionMarkers`),
/// counted for every volume and stored with the volume's publication year, on which the kit gates
/// the layer (`VolumeAnnotations.editorialOmissionsFromYear`).
///
/// Version history:
///   1.0 — 2026-11-06: the editors' annotations design, lane A
///   1.1 — 2026-11-06: abbreviations count a document's `@ana` pointers to a term, as people did
///   1.2 — 2026-11-08: `.editorialOmissions`, and the volume's publication year
enum VolumeAnnotationsAssembly {

    /// One volume's counts, with what the run reports about them.
    struct Counted: Sendable {
        /// The volume's annotations.
        let annotations: VolumeAnnotations
        /// Its documents the index holds no row for, which count by the TEI rule alone.
        let unindexed: Int
        /// Its stored source notes that the despatch grammar reads as a despatch number.
        let despatchNotes: Int
    }

    /// One volume's annotations, counted from its scan and its index facts.
    static func annotations(scan: TEIVolumeScan, facts: IndexVolumeFacts, era: AnnotationEra) -> Counted {
        var counts: [AnnotationCategory: Int] = [:]
        func add(_ category: AnnotationCategory, _ carried: Bool) {
            if carried { counts[category, default: 0] += 1 }
        }
        var unindexed = 0
        var despatchNotes = 0
        for id in scan.documentIds {
            let features = scan.features[id] ?? TEIDocumentFeatures()
            if !facts.rowIds.contains(id) { unindexed += 1 }
            add(.people, facts.peopleDocuments.contains(id))
            add(.abbreviations, !features.glossTargets.isDisjoint(with: facts.termRefs)
                    || !features.annotatedIds.isDisjoint(with: facts.termRefs))
            add(.correspondents, features.correspondents)
            add(.subjects, features.subjects)
            add(.participants, features.participants)
            if let note = facts.sourceNotes[id] {
                if let form = sourceNoteForm(note, inline: features.inlineSourceNote) {
                    add(form, true)
                } else {
                    despatchNotes += 1
                }
            }
            add(.classification, facts.classified.contains(id))
            add(.excisions, features.excisions)
            add(.editorialOmissions, features.editorialOmissions)
            add(.despatch, facts.despatch.contains(id))
            add(.numbered, facts.headers[id].map(opensWithPrintedNumber) ?? false)
            add(.xrefDocuments, features.xrefDocuments)
            add(.xrefFootnotes, features.xrefFootnotes)
            add(.xrefVolumes, features.xrefVolumes)
            add(.xrefPages, features.xrefPages)
            add(.editorialNotes, features.isEditorialNote)
            add(.footnotes, features.footnotes)
            add(.marginalNotes, features.marginalNotes)
            add(.figures, features.figures)
        }
        let documents = scan.documentIds.count
        let annotations = VolumeAnnotations(
            documents: documents,
            historicalDocuments: documents - (counts[.editorialNotes] ?? 0),
            personsListed: facts.personsListed,
            termsListed: facts.termRefs.count,
            era: era, counts: counts, sections: facts.sections, publicationYear: scan.publicationYear)
        return Counted(annotations: annotations, unindexed: unindexed, despatchNotes: despatchNotes)
    }

    /// The form of a stored source note, or `nil` for none and for a despatch number stored as one.
    ///
    /// - Parameters:
    ///   - note: The document's stored source note.
    ///   - inline: Whether the TEI prints the document's source note above the heading
    ///     (`note[@rend="inline"]`).
    static func sourceNoteForm(_ note: String?, inline: Bool) -> AnnotationCategory? {
        guard let note else { return nil }
        let text = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isDespatchNumber(text) else { return nil }
        return inline ? .sourceFileNumber : .sourceCitation
    }

    /// `true` when a stored source note is a despatch number, not a citation: `DespatchSerialGrammar`
    /// reads its whole text as one ("No. 3.", "No. 1315.]"), and it holds no `/`. A file number always
    /// holds one, and the grammar would otherwise take "No. 8130/11." (the Numerical File) and
    /// "No. 711.1215/448a." (the decimal file) for serials.
    static func isDespatchNumber(_ text: String) -> Bool {
        !text.contains("/") && DespatchSerialGrammar.serial(inSegment: text) != nil
    }

    /// `true` when a stored heading opens with a printed document number: optional whitespace,
    /// digits, an optional letter, a stop and whitespace ("12. ", "12A. "), the test
    /// `Planning/editors-annotations/index_extract.py` applied.
    static func opensWithPrintedNumber(_ header: String) -> Bool {
        let scalars = Array(header.unicodeScalars.prefix(64))
        var position = 0
        func at(_ test: (Unicode.Scalar) -> Bool) -> Bool {
            position < scalars.count && test(scalars[position])
        }
        while at({ CharacterSet.whitespacesAndNewlines.contains($0) }) { position += 1 }
        let digits = position
        while at({ ("0"..."9").contains($0) }) { position += 1 }
        guard position > digits else { return false }
        if at({ ("A"..."Z").contains($0) || ("a"..."z").contains($0) }) { position += 1 }
        guard at({ $0 == "." }) else { return false }
        position += 1
        return at { CharacterSet.whitespacesAndNewlines.contains($0) }
    }
}
