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

/// What to call a document in a list, when its printed head is not the answer.
///
/// **One rule, in one place, because the alternative already went wrong twice.** Seven expressions
/// across `ResearchView`, `CorpusBrowseView` and `ClustersBrowseView` each spelled the fallback
/// themselves as `headers[key] ?? documentId`. That idiom was silently broken for years — a
/// headerless document came back as `""` rather than absent, so the fallback never fired and the
/// row rendered blank (fixed in the preceding change) — and then it was accurate but unhelpful,
/// naming the record `d304` rather than describing it. A rule spelled seven times is a rule that
/// drifts; this type is the single place it lives.
///
/// **The population is measured, not assumed — and the first measurement measured a bug.** On a
/// full 316,839-document index built before v55, 8,474 documents had no stored head, 8,467 of them
/// editorial notes, each carrying a document number, so *Editorial Note 304* covered 99.9% of the
/// cases. But the TEI gives **every one of those notes a `<head>`**: the parser wraps a note in one
/// `.editorialNote` node and `IndexingPipeline.extractHeader` did not read through it (#1372). From
/// index v55 it does, and the corpus's remaining **seven** headerless documents are not notes, and
/// fall through to the id.
///
/// **A stored head is not always a name, though.** Measured over the corpus, about 2,676 notes print
/// a head that says only what they are — *Editorial Note* (2,560), *Editor's Note* (97, all in
/// `frus1945Berlinv02`), *Editorial Notes*, *[Editorial Note]*, *[Untitled]*, *Note* — and one
/// volume holds up to 99 of them, so a list of those heads reads identically. Such a head is treated
/// as no head (`isGenericNoteHead`) and the note is named with its number, as before. A numbered
/// head (*245. Editorial Note*, 5,114) and a real title (*Memorandum by Prime Minister Churchill*)
/// are names and win outright.
///
/// Version history:
///   1.0 — initial implementation, after the headerless-fallback fix
///   1.1 — #1372: the population corrected — the 8,467 notes were headerless only in the index
///   1.2 — #1372: a note's generic printed head (*Editorial Note*) names it with its number
enum DocumentDisplayTitle {

    /// The title to show for a document, given what the index knows about it.
    ///
    /// - Parameters:
    ///   - facts: What the store returned for this key, or `nil` when the document is not indexed.
    ///   - documentId: The last resort, and the reason this never returns an empty string.
    /// - Returns: A non-empty string, always.
    static func text(_ facts: CrossReferenceStore.DocumentTitleFacts?,
                     documentId: String) -> String {
        let isNote = facts?.isEditorialNote == true

        // A printed head wins outright: it is what the volume calls this document — unless it is
        // an editorial note's generic head, which names the kind and not the note.
        if let header = facts?.header, !header.isEmpty,
           !(isNote && Self.isGenericNoteHead(header)) {
            return header
        }

        // An editorial note with no head that names it: an index built before v55, which dropped
        // every note's head (#1372), or a note whose printed head only says *Editorial Note*.
        // Naming it as a note is more informative than the id, and the number is what tells two of
        // them apart in a list — without it, a volume's notes would read identically.
        if isNote {
            if let number = facts?.documentNumber, !number.isEmpty {
                return String(format: String(localized: "document.title.editorialNote %@",
                                             defaultValue: "Editorial Note %@"), number)
            }
            return String(localized: "document.title.editorialNote.unnumbered",
                          defaultValue: "Editorial Note")
        }

        // Not indexed, or indexed with neither a head nor a note flag — seven documents in the
        // corpus. The id at least names the record unambiguously.
        return documentId
    }

    /// Whether an editorial note's printed head says only what the document is, rather than
    /// naming it: *Editorial Note*, *Editorial Notes*, *Editor's Note*, *Note*, *Untitled*, in
    /// any case, with or without surrounding brackets or a trailing full stop.
    ///
    /// The list is the corpus's own, measured over every editorial note's head; it is deliberately
    /// exact rather than a pattern, so *The World War: Editorial note* and *Editorial Note on a
    /// Meeting at the White House, December 18, 1941* — real titles that contain the words — stay
    /// names.
    static func isGenericNoteHead(_ head: String) -> Bool {
        var text = head.trimmingCharacters(in: .whitespacesAndNewlines)
        while let last = text.last, last == "." || last == ":" { text.removeLast() }
        if text.hasPrefix("["), text.hasSuffix("]") { text = String(text.dropFirst().dropLast()) }
        let folded = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .lowercased()
        return genericNoteHeads.contains(folded)
    }

    /// The generic heads, folded: lower case, ASCII apostrophe, no brackets or final stop.
    private static let genericNoteHeads: Set<String> = [
        "editorial note", "editorial notes", "editor's note", "note", "untitled",
    ]
}
