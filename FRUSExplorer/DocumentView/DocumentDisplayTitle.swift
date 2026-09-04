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
/// **The population is measured, not assumed.** On a full 316,839-document index, 8,474 documents
/// have no head. **8,467 of them are editorial notes and every one carries a document number** —
/// so *Editorial Note 304* is available for 99.9% of the cases where a bare id would otherwise
/// show. Zero are front matter. The remaining seven are neither, and fall through to the id.
///
/// Version history:
///   1.0 — initial implementation, after the headerless-fallback fix
enum DocumentDisplayTitle {

    /// The title to show for a document, given what the index knows about it.
    ///
    /// - Parameters:
    ///   - facts: What the store returned for this key, or `nil` when the document is not indexed.
    ///   - documentId: The last resort, and the reason this never returns an empty string.
    /// - Returns: A non-empty string, always.
    static func text(_ facts: CrossReferenceStore.DocumentTitleFacts?,
                     documentId: String) -> String {
        // A printed head wins outright: it is what the volume calls this document.
        if let header = facts?.header, !header.isEmpty { return header }

        // An editorial note has no head by design rather than by omission, so naming it as one is
        // more informative than the id. The number is what tells two of them apart in a list —
        // without it, 8,467 rows would read identically.
        if facts?.isEditorialNote == true {
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
}
