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

/// The one rule that turns a stored archival reference into a collection-authority record.
///
/// ## Why this exists as its own type (#837)
/// It shipped twice, independently and identically: `SourceExplorerView.resolve(_:authority:)`
/// for a document's unprinted pointers, and `ArchivalLibraryProfile.resolve(_:authority:)` for the
/// library profile's citation groups. The two take different inputs and are otherwise the same
/// four steps in the same order, including the guard. #837 would have added a third copy for the
/// graph's unit nodes.
///
/// Three copies of a matching rule is three places for a resolution to drift, and a drift here is
/// invisible: each surface would simply resolve a slightly different set, and no test compares
/// them. The rule is small enough that duplication looked harmless — which is exactly the shape
/// this codebase has been bitten by before.
///
/// ## The rule, in order
/// 1. **A lot number wins outright.** `lot_file_norm` is the canonical compact key both sides of
///    the corpus write, so an exact hit needs no disambiguation.
/// 2. Otherwise the **leading comma segment** of the collection/series name is the level-1 key the
///    authority clusters on (`Conference Files, Lot 60 D 627` → `Conference Files`).
/// 3. The match is looked up **scoped by repository**, so two archives' identically-named series
///    do not collapse.
/// 4. **The #351 library-over-lot guard**: a library-held citation that matched a `lot:` record is
///    refused. A presidential library's series and a State lot file can carry the same words, and
///    answering a library citation with a State lot file is the confidently-wrong archival link
///    this workstream exists to remove.
///
/// `nonisolated` throughout: both callers run it inside a detached task because the authority is a
/// ~2 MB decode, and the inputs are all `Sendable` value types, which is what makes the annotation
/// honest rather than a silencer.
enum ExternalCitationAuthorityJoin {

    /// Resolves a citation described by its three keying fields.
    ///
    /// Takes the fields rather than a row type so both callers can use it: they hold different
    /// structs (`ExternalCitation` and `ArchivalLibraryCollectionGroup`) carrying the same three
    /// facts under different names.
    ///
    /// - Parameters:
    ///   - lotFileNorm: The canonical compact lot key, when the citation named a lot.
    ///   - collectionName: The collection or series name as stored.
    ///   - repository: The holding repository, when the citation named one.
    ///   - authority: The bundled collection authority.
    /// - Returns: The record, or `nil` when nothing matches under the guard.
    nonisolated static func record(
        lotFileNorm: String?,
        collectionName: String?,
        repository: String?,
        authority: CollectionAuthorityIndex
    ) -> AuthorityCollectionRecord? {
        if let lot = lotFileNorm, !lot.isEmpty {
            return authority.record(forLotNorm: lot)
        }
        guard let name = collectionName, let segment = leadingSegment(of: name) else { return nil }
        let match = authority.record(repository: repository, leadingSegment: segment)
        if match?.id.hasPrefix("lot:") == true, let repository,
           CollectionKeying.isLibraryRepositoryName(repository) {
            return nil
        }
        return match
    }

    /// The first comma-separated segment of a stored name — the level-1 key the authority
    /// clusters on.
    nonisolated static func leadingSegment(of name: String) -> String? {
        let head = name.split(separator: ",", maxSplits: 1).first.map(String.init) ?? name
        let trimmed = head.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
