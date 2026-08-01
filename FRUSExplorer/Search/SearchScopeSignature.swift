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

import CryptoKit
import Foundation

// MARK: - SearchScopeSignature

/// A canonical, locale-free key for the scope a search ran under.
///
/// ## Why a key and not a sentence
/// M-2 needs the scope for two jobs that pull in opposite directions. The appendix must *show* it,
/// which argues for prose; the trail must *compare* it, which prose cannot do — a sentence drifts
/// with locale, so a French iPad and an English Mac would disagree about whether two searches had
/// the same scope, in one synced trail.
///
/// So this emits a key. The appendix renders it through a decoder, and prints it verbatim if
/// decoding ever fails — failing closed to showing exactly what was recorded rather than to a
/// confident mis-description.
///
/// ## Three properties it must have
/// - **Deterministic.** Fixed key order, sorted id lists, no dictionary iteration.
/// - **Locale-free.** No `String(localized:)`, no `.formatted()`, no date formatter honouring a
///   calendar. ISO dates and raw integers only.
/// - **Injective on the volume list.** The list is recorded as a stable hash, never as a count:
///   two different twelve-volume scopes must not collapse into the same signature, or the trail
///   would treat a re-run under a *different* scope as a duplicate — which is precisely the hole
///   M-2 exists to close.
///
/// The hash is truncated SHA-256 over the sorted, newline-joined ids. Truncation is safe here
/// because the consequence of a collision is one de-duplicated trail row, not a wrong answer.
///
/// Version history:
///   1.0 — M-2: initial implementation
enum SearchScopeSignature {

    /// The signature for `parameters`.
    ///
    /// - Parameter parameters: the executed search's parameters — not the live filter state, which
    ///   may have moved since.
    /// - Returns: a key such as
    ///   `"dates=1949-01-01..1952-12-31;docs=none;front=1;mode=and;notes=1;…"`.
    static func signature(for parameters: SearchParameters) -> String {
        // Fixed order, written out rather than derived, so a reordering is a visible diff.
        var parts: [String] = []
        parts.append("mode=\(parameters.booleanMode == .or ? "or" : "and")")
        parts.append("dates=\(dateComponent(parameters.dateRange))")
        parts.append("vols=\(idComponent(parameters.volumeIds))")
        parts.append("docs=\(idComponent(parameters.documentIds))")
        parts.append("exdocs=\(idComponent(parameters.excludeDocumentIds))")
        parts.append("stags=\(idComponent(parameters.subjectTagIds))")
        parts.append("utags=\(idComponent(parameters.userTagIds))")
        parts.append("type=\(parameters.documentTypeFilter.signatureToken)")
        parts.append("person=\(personComponent(parameters))")
        parts.append("phrase=\(parameters.phrase?.isEmpty == false ? "1" : "0")")
        parts.append("prefix=\(parameters.prefixWildcard?.isEmpty == false ? "1" : "0")")
        parts.append("excl=\(parameters.excludedTerms.isEmpty ? "0" : "1")")
        parts.append("text=\(parameters.includeDocumentText ? "1" : "0")")
        parts.append("summ=\(parameters.includeSummaries ? "1" : "0")")
        parts.append("notes=\(parameters.includeNotes ? "1" : "0")")
        parts.append("front=\(parameters.includeFrontMatter ? "1" : "0")")
        parts.append("proj=\(parameters.projectId?.uuidString ?? "none")")
        return parts.joined(separator: ";")
    }

    // MARK: - Components

    /// `nil` and `[]` are DIFFERENT scopes and must not share a token: `IndexingPipeline` reads an
    /// empty `documentIds` as "match nothing" and `nil` as "no constraint".
    private static func idComponent(_ ids: [String]?) -> String {
        guard let ids else { return "none" }
        if ids.isEmpty { return "empty" }
        return "\(ids.count)/\(digest(of: ids))"
    }

    private static func idComponent(_ ids: [String]) -> String {
        ids.isEmpty ? "empty" : "\(ids.count)/\(digest(of: ids))"
    }

    /// ISO strings straight from the model — never a `DateFormatter`, which honours the locale's
    /// calendar and would give two devices different keys for one range.
    private static func dateComponent(_ range: DateRange?) -> String {
        guard let range else { return "none" }
        return "\(range.earliest ?? "")..\(range.latest ?? "")"
    }

    /// A person filter has two forms and they are not interchangeable — a rollup spans the corpus,
    /// a raw ref is one volume's spelling.
    private static func personComponent(_ parameters: SearchParameters) -> String {
        if let rollup = parameters.personRollupId { return "rollup:\(rollup)" }
        if let ref = parameters.personRef, !ref.isEmpty { return "ref:\(digest(of: [ref]))" }
        return "none"
    }

    /// Truncated SHA-256 over the sorted, newline-joined ids. Sorted so that member ORDER — which
    /// carries no scope meaning — cannot change the key.
    private static func digest(of ids: [String]) -> String {
        let joined = ids.sorted().joined(separator: "\n")
        let hash = SHA256.hash(data: Data(joined.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined().prefix(12).description
    }
}

// MARK: - DocumentTypeFilter + signature

extension DocumentTypeFilter {

    /// A stable, non-localized token. The raw value is not used directly so that renaming a case
    /// for display cannot silently change every recorded signature.
    var signatureToken: String {
        switch self {
        case .all: "all"
        case .documentsOnly: "documents"
        case .editorialNotesOnly: "editorial"
        }
    }
}
