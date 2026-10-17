// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - PersonsCompleteCorrections

/// The `persons-complete.xml` entries this repository holds apart: entries that merge two people, and
/// what of each belongs to the person the entry is not keyed to (#1657).
///
/// ## Why there is one
/// The overlay's crosswalk expansion adds an entry's `frus-ref` anchors to its `people-id`, and its
/// enrichment stamps the entry's Wikidata and VIAF ids on that id's registry record. The merge audit
/// guard skips an entry a human review flagged, and two wrong merges are in no row of the audit:
///
/// - `FRUS-14666` carries people-id `107235`, *Kirkpatrick, Helen P.* (Public Affairs Adviser,
///   1952–1954 vol. XI), and ten anchors of *Kirkpatrick, Jeane J.* from 1981–1988 volumes, with
///   Jeane Kirkpatrick's Wikidata and VIAF ids. The registry gives `107235` Helen P.'s two anchors
///   and no identifier, and gives Jeane Kirkpatrick `107237`.
/// - `FRUS-14463` carries `107120`, *Khomeini, Ruhollah*, with 1977–1980 vol. XI Part 1's
///   *Khomeini, Ahmad* among its anchors and Ahmad Khomeini's Wikidata id, `Q400619`. Its VIAF id,
///   `88036173`, is Ruhollah Khomeini's.
///
/// So People filed Jeane Kirkpatrick's mentions in eight volumes under Helen P. Kirkpatrick, with
/// Jeane's identifiers on both records, and Ahmad Khomeini's entry under his father.
///
/// ## Why not the audit's guard
/// The guard skips an entry whole, and both entries are mostly right: skipping them would also take
/// Ruhollah Khomeini's VIAF id, his role text and four of his anchors from the bundle, and Helen P.
/// Kirkpatrick's role text. A correction holds apart only what belongs to the other person.
///
/// ## What a correction does
/// For an overlay entry that carries ``HeldApart/peopleId``, its listed anchors join none of the
/// entry's people-ids, and an identifier equal to ``HeldApart/wikidata`` or ``HeldApart/viaf`` is
/// stamped on none of them. Nothing else of the entry changes. A held-apart anchor joins no person
/// unless another source names it: the registry, or another overlay entry (`FRUS-14668`, Jeane
/// Kirkpatrick's own, names 1981–1988 vol. I's). The app's clusterer then places the rest by name and
/// era, as it does any entry the crosswalk does not cover.
///
/// ## When a run refuses
/// A correction is checked against the registry and the overlay it is applied to, and a run that
/// finds one stale writes nothing: the registry's name for ``HeldApart/peopleId`` must be
/// ``HeldApart/registryName``, an overlay entry must carry the people-id, and each anchor and
/// identifier must be that entry's. A correction that matches nothing does nothing, and it would
/// do nothing silently after a re-mint or an upstream fix; a typo would leave the merge in place.
///
/// ## The file
/// `PersonAuthorityIndexGenerator/persons-complete-corrections.json` (``defaultPath``), committed
/// beside the tool: an object whose `heldApart` lists the corrections. Any other key, such as the
/// file's `about`, is for its readers.
///
/// Version history:
///   1.0 — #1657: initial implementation
public enum PersonsCompleteCorrections {

    /// Where a run reads the corrections, relative to the project root, as the runner's default
    /// `OUTPUT_PATH` is.
    public static let defaultPath = "PersonAuthorityIndexGenerator/persons-complete-corrections.json"

    /// One overlay entry that merges two people, and what of it belongs to the other one.
    public struct HeldApart: Codable, Sendable, Equatable {
        /// The registry person the entry is keyed to, by `people-id`: the joining key, never the
        /// `FRUS-NNNNN` xml:id, which upstream re-mints.
        public let peopleId: String
        /// The registry's preferred name for ``peopleId``. Checked at build time, so a mistyped id
        /// cannot hold apart another person's anchors.
        public let registryName: String
        /// Who the held-apart anchors and identifiers belong to.
        public let otherPerson: String
        /// The entry's anchors that belong to ``otherPerson``, as the overlay writes them
        /// (`volume/persons#ref`).
        public let anchors: [String]
        /// The entry's Wikidata id when it is ``otherPerson``'s, else `nil`.
        public let wikidata: String?
        /// The entry's VIAF id when it is ``otherPerson``'s, else `nil`.
        public let viaf: String?
        /// Why the correction is here: the issue, and what the sources say.
        public let reason: String

        /// Creates a correction.
        public init(peopleId: String, registryName: String, otherPerson: String, anchors: [String],
                    wikidata: String?, viaf: String?, reason: String) {
            self.peopleId = peopleId
            self.registryName = registryName
            self.otherPerson = otherPerson
            self.anchors = anchors
            self.wikidata = wikidata
            self.viaf = viaf
            self.reason = reason
        }

        /// ``anchors`` parsed, in the file's order. An anchor that does not parse is left out, and
        /// ``PersonsCompleteCorrections/load(path:)`` refuses a file that holds one.
        var parsedAnchors: [FRUSAnchor] {
            anchors.compactMap(PersonsCompleteOverlay.parseFRUSRef)
        }
    }

    /// The file's shape.
    private struct File: Decodable {
        let heldApart: [HeldApart]
    }

    /// Why the corrections were not read, or do not fit the registry and overlay they were applied
    /// to. Either way the run writes nothing.
    public enum Problem: Error, Equatable, Sendable, CustomStringConvertible {
        /// The file could not be read.
        case unreadable(path: String, reason: String)
        /// The file is not a list of corrections: not JSON, or no `heldApart` of the right shape.
        case malformed(path: String, reason: String)
        /// A correction lacks a people-id, a name, the other person, the reason, or anything to
        /// hold apart.
        case incomplete(peopleId: String)
        /// An anchor is not of the `volume/persons#ref` form.
        case badAnchor(peopleId: String, anchor: String)
        /// Two corrections name one people-id.
        case duplicatePeopleId(String)
        /// The registry has no record for the people-id, or names it otherwise.
        case registryNameDiffers(peopleId: String, expected: String, found: String?)
        /// No overlay entry carries the people-id.
        case noOverlayEntry(peopleId: String)
        /// An anchor is not among the anchors of the entries that carry the people-id.
        case anchorNotInEntry(peopleId: String, anchor: String)
        /// No entry that carries the people-id has this identifier.
        case identifierNotInEntry(peopleId: String, identifier: String)

        /// What the run prints.
        public var description: String {
            switch self {
            case .unreadable(let path, let reason):
                return "the corrections \(path) could not be read (\(reason))."
            case .malformed(let path, let reason):
                return "the corrections \(path) are not a list of held-apart entries (\(reason))."
            case .incomplete(let peopleId):
                return "the correction for \"\(peopleId)\" lacks a people-id, a name, the other person, its reason, or anything to hold apart."
            case .badAnchor(let peopleId, let anchor):
                return "the correction for \(peopleId) lists \"\(anchor)\", which is not volume/persons#ref."
            case .duplicatePeopleId(let peopleId):
                return "two corrections name people-id \(peopleId)."
            case .registryNameDiffers(let peopleId, let expected, let found):
                return "the correction for \(peopleId) expects the registry to name it \"\(expected)\"; "
                    + "the registry names it \(found.map { "\"\($0)\"" } ?? "nothing")."
            case .noOverlayEntry(let peopleId):
                return "the correction for \(peopleId) matches no overlay entry: upstream may have fixed it, "
                    + "or re-minted it. Read the entry and remove or update the correction."
            case .anchorNotInEntry(let peopleId, let anchor):
                return "the correction for \(peopleId) holds apart \(anchor), which no overlay entry carrying "
                    + "\(peopleId) lists."
            case .identifierNotInEntry(let peopleId, let identifier):
                return "the correction for \(peopleId) withholds \(identifier), which no overlay entry carrying "
                    + "\(peopleId) has."
            }
        }
    }

    /// Reads and checks the file at `path`.
    ///
    /// - Parameter path: The corrections file, ``defaultPath`` for a run from the project root.
    /// - Returns: The corrections, in the file's order.
    /// - Throws: ``Problem`` when the file cannot be read, is not a list of corrections, or holds
    ///   one that is incomplete, has an anchor of the wrong form, or repeats a people-id.
    public static func load(path: String) throws -> [HeldApart] {
        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: path))
        } catch {
            throw Problem.unreadable(path: path, reason: error.localizedDescription)
        }
        let corrections: [HeldApart]
        do {
            corrections = try JSONDecoder().decode(File.self, from: data).heldApart
        } catch {
            throw Problem.malformed(path: path, reason: String(describing: error))
        }
        var seen = Set<String>()
        for correction in corrections {
            let blank = [correction.peopleId, correction.registryName, correction.otherPerson,
                         correction.reason].contains { $0.trimmingCharacters(in: .whitespaces).isEmpty }
            let nothingHeld = correction.anchors.isEmpty && correction.wikidata == nil
                && correction.viaf == nil
            if blank || nothingHeld { throw Problem.incomplete(peopleId: correction.peopleId) }
            for anchor in correction.anchors where PersonsCompleteOverlay.parseFRUSRef(anchor) == nil {
                throw Problem.badAnchor(peopleId: correction.peopleId, anchor: anchor)
            }
            guard seen.insert(correction.peopleId).inserted else {
                throw Problem.duplicatePeopleId(correction.peopleId)
            }
        }
        return corrections
    }

    /// The first way `corrections` do not fit the registry and overlay they are applied to, or
    /// `nil` when every one does.
    ///
    /// - Parameters:
    ///   - corrections: The corrections the run applies.
    ///   - entries: The overlay's entries.
    ///   - registryName: The registry's preferred name for a people-id, or `nil` when it has none.
    public static func misfit(of corrections: [HeldApart], entries: [PersonsCompleteOverlay.Entry],
                              registryName: (String) -> String?) -> Problem? {
        for correction in corrections {
            let found = registryName(correction.peopleId)
            guard found == correction.registryName else {
                return .registryNameDiffers(peopleId: correction.peopleId,
                                            expected: correction.registryName, found: found)
            }
            let carrying = entries.filter { $0.peopleIds.contains(correction.peopleId) }
            guard !carrying.isEmpty else { return .noOverlayEntry(peopleId: correction.peopleId) }
            let anchors = Set(carrying.flatMap(\.anchors))
            for (raw, anchor) in zip(correction.anchors, correction.parsedAnchors)
            where !anchors.contains(anchor) {
                return .anchorNotInEntry(peopleId: correction.peopleId, anchor: raw)
            }
            if let wikidata = correction.wikidata, !carrying.contains(where: { $0.wikidata == wikidata }) {
                return .identifierNotInEntry(peopleId: correction.peopleId, identifier: wikidata)
            }
            if let viaf = correction.viaf, !carrying.contains(where: { $0.viaf == viaf }) {
                return .identifierNotInEntry(peopleId: correction.peopleId, identifier: viaf)
            }
        }
        return nil
    }
}
