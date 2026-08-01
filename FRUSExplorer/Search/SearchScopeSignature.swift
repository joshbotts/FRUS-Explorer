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
///   1.1 — M-2 commit 3: `describe(_:)` — the decoder this type's overview promised, so the
///          method appendix can print a scope as prose without the trail comparing prose
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

    // MARK: - Decoding

    /// Renders a recorded signature as readable prose for the method appendix.
    ///
    /// The inverse direction of the trade-off in this type's overview: the key exists so the trail
    /// can *compare* scopes, and this exists so the appendix can *show* one. It is deliberately
    /// lossy — the volume digest names a count, never the twelve volume ids — because the appendix
    /// states the method, and the signature itself is printed beside it for anyone who needs to
    /// check that two rows really did run under the same scope.
    ///
    /// - Parameter signature: a string produced by ``signature(for:)``.
    /// - Returns: the phrases describing the scope, or `nil` if `signature` does not parse. `nil`
    ///   is the caller's cue to print the raw key: an appendix that guessed would be describing a
    ///   scope the search did not run under, which is worse than an ugly line.
    static func describe(_ signature: String) -> [String]? {
        var pairs: [String: String] = [:]
        for part in signature.split(separator: ";") {
            guard let split = part.firstIndex(of: "=") else { return nil }
            pairs[String(part[part.startIndex..<split])] = String(part[part.index(after: split)...])
        }
        // Every signature this type writes carries `mode`. Its absence means the string came from
        // somewhere else — or from a future version — and must not be paraphrased.
        guard pairs["mode"] != nil else { return nil }

        var phrases: [String] = []

        // Fields searched: stated always, because *which* text was searched is method, not a
        // narrowing. A reader cannot infer it from the query.
        let fields = [
            (pairs["text"], String(localized: "appendix.scope.field.text", defaultValue: "document text")),
            (pairs["summ"], String(localized: "appendix.scope.field.summaries", defaultValue: "summaries")),
            (pairs["notes"], String(localized: "appendix.scope.field.notes", defaultValue: "notes")),
            (pairs["front"], String(localized: "appendix.scope.field.frontMatter", defaultValue: "front matter"))
        ].compactMap { $0.0 == "1" ? $0.1 : nil }
        if fields.isEmpty {
            phrases.append(String(localized: "appendix.scope.fields.none",
                                  defaultValue: "no fields searched"))
        } else {
            phrases.append(String(localized: "appendix.scope.fields %@",
                                  defaultValue: "searched \(fields.formatted(.list(type: .and)))"))
        }

        if pairs["mode"] == "or" {
            phrases.append(String(localized: "appendix.scope.mode.or", defaultValue: "any term matches"))
        }
        if let dates = pairs["dates"], dates != "none" {
            phrases.append(String(localized: "appendix.scope.dates %@", defaultValue: "dated \(dates)"))
        }
        phrases += countPhrase(pairs["vols"],
                               some: { String(localized: "appendix.scope.volumes %lld",
                                              defaultValue: "\($0) volumes") },
                               empty: String(localized: "appendix.scope.volumes.empty",
                                             defaultValue: "no volumes selected"))
        phrases += countPhrase(pairs["docs"],
                               some: { String(localized: "appendix.scope.documents %lld",
                                              defaultValue: "\($0) documents") },
                               empty: String(localized: "appendix.scope.documents.empty",
                                             defaultValue: "no documents selected"))
        phrases += countPhrase(pairs["exdocs"],
                               some: { String(localized: "appendix.scope.excludedDocuments %lld",
                                              defaultValue: "\($0) documents excluded") },
                               empty: nil)
        phrases += countPhrase(pairs["stags"],
                               some: { String(localized: "appendix.scope.subjectTags %lld",
                                              defaultValue: "\($0) subject tags") },
                               empty: nil)
        phrases += countPhrase(pairs["utags"],
                               some: { String(localized: "appendix.scope.userTags %lld",
                                              defaultValue: "\($0) of your tags") },
                               empty: nil)

        switch pairs["type"] {
        case "documents":
            phrases.append(String(localized: "appendix.scope.type.documents", defaultValue: "documents only"))
        case "editorial":
            phrases.append(String(localized: "appendix.scope.type.editorial",
                                  defaultValue: "editorial notes only"))
        default: break
        }
        if let person = pairs["person"], person != "none" {
            phrases.append(person.hasPrefix("rollup:")
                           ? String(localized: "appendix.scope.person.rollup",
                                    defaultValue: "filtered to one person")
                           : String(localized: "appendix.scope.person.ref",
                                    defaultValue: "filtered to one person, by a single volume's spelling"))
        }
        if pairs["phrase"] == "1" {
            phrases.append(String(localized: "appendix.scope.phrase", defaultValue: "phrase search"))
        }
        if pairs["prefix"] == "1" {
            phrases.append(String(localized: "appendix.scope.prefix", defaultValue: "prefix wildcard"))
        }
        if pairs["excl"] == "1" {
            phrases.append(String(localized: "appendix.scope.excluded", defaultValue: "with excluded terms"))
        }
        if pairs["proj"] != nil, pairs["proj"] != "none" {
            phrases.append(String(localized: "appendix.scope.project", defaultValue: "gated to a project"))
        }
        return phrases
    }

    /// Renders a `count/digest`, `empty` or `none` component. `none` is no constraint and yields
    /// nothing; `empty` is a real — and pathological — scope, so it gets a phrase where one is
    /// supplied. A malformed count yields nothing rather than a `0`, which would read as a fact.
    private static func countPhrase(_ component: String?,
                                    some: (Int) -> String,
                                    empty: String?) -> [String] {
        guard let component, component != "none" else { return [] }
        if component == "empty" { return empty.map { [$0] } ?? [] }
        guard let slash = component.firstIndex(of: "/"),
              let count = Int(component[component.startIndex..<slash]) else { return [] }
        return [some(count)]
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
