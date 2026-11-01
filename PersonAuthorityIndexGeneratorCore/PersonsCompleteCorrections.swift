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
/// Eighty more were read in A4c (plan of record §6g). Seventy-three are entries keyed to one person
/// that carry another's anchors, found from the anchors the overlay adds whose own persons-list name is
/// not their record's: `FRUS-00645`, keyed to Richard F. Allen of the 1951 aid mission to Yugoslavia,
/// carries thirteen of Richard V. Allen's anchors, his identifiers and his role text; others file
/// Romulo Betancourt under Ernesto Betancourt, Orville Freeman under a Navy commander of 1945, and eight
/// of the Tehran hostages under older namesakes. Seven are entries carrying several people-ids, whose
/// anchors go to the first the registry knows: 1977–1980 vol. XXIV's Raul H. Castro, U.S. Ambassador to
/// Argentina, went to Raul Castro of Cuba.
///
/// ## Why not the audit's guard
/// The guard skips an entry whole, and both entries are mostly right: skipping them would also take
/// Ruhollah Khomeini's VIAF id, his role text and four of his anchors from the bundle, and Helen P.
/// Kirkpatrick's role text. A correction holds apart only what belongs to the other person.
///
/// ## What a correction does
/// For an overlay entry that carries ``HeldApart/peopleId``, its listed anchors join none of the
/// entry's people-ids, and an identifier equal to ``HeldApart/wikidata`` or ``HeldApart/viaf``, or a
/// role text equal to ``HeldApart/role``, is stamped on none of them. Nothing else of the entry
/// changes. A held-apart anchor joins no person unless another source names it (the registry, or
/// another overlay entry: `FRUS-14668`, Jeane Kirkpatrick's own, names 1981–1988 vol. I's) or the
/// correction names the record it joins (below). The app's clusterer places the rest by name and era,
/// as it does any entry the crosswalk does not cover.
/// A withheld role text leaves the record with none unless another entry carrying the people-id
/// gives one: the person sheet then shows the volume's own description alone.
///
/// ## Where a held-apart anchor goes
/// Where the other person has a record in the registry, the correction can name it
/// (``HeldApart/joins``), and the held-apart anchors join it wherever no source answers for them.
/// Without it, an anchor held apart can be merged back by name: Richard V. Allen's 1981–1988 entries,
/// once held apart from Richard F. Allen, rejoined him in the app's rollup through 1952–1954 vol.
/// VIII's plain "Allen, Richard", which is Richard F. Allen's and fits either name. A join never
/// overrides the registry, and is checked as the people-id is: its registry name must be the one
/// the correction gives.
///
/// An identifier or role text is listed when it is not the keyed person's: the other person's, or,
/// as on most of A4c's entries, someone's the reconciliation matched by name alone (Alfred Rosenberg's
/// entry carries the Wikidata id of a Czech film actor born in 1975). Each was read on wikidata.org or
/// viaf.org before it was listed; one that could not be shown to be someone else's stays.
///
/// ## Entries carrying several people-ids
/// A correction holds apart from every people-id of the entry, so on an entry that carries two
/// people's ids it cannot keep the first's role text and identifiers off the second: A4c's seven such
/// corrections list anchors alone, held apart from both ids, and where the right one is in the
/// bundle they join it.
///
/// ## When a run refuses
/// A correction is checked against the registry and the overlay it is applied to, and a run that
/// finds one stale writes nothing: the registry's name for ``HeldApart/peopleId`` must be
/// ``HeldApart/registryName``, an overlay entry must carry the people-id, each anchor, identifier
/// and role text must be that entry's, and the registry's name for a join's people-id must be the
/// join's. A correction that matches nothing does nothing, and it would do nothing silently after a
/// re-mint or an upstream fix; a typo would leave the merge in place.
///
/// ## A record with no anchor of its own
/// A join may name a registry record that has no anchor in a volume the run keeps, which the builder
/// otherwise leaves out of the bundle; the record is then kept for the anchor the join places (#1767).
/// `106238`, *Hughes, (Robert) John*, Assistant Secretary for Public Affairs from 1982 to 1985, is
/// known to the registry only from his POCOM page, and 1981–1988 vol. X's "Hughes, John" joins him.
///
/// ## Anchors no source answers: assignments
/// ``Assigned`` is not a correction of an overlay entry. It names an anchor that neither the registry
/// nor the overlay gives to anyone, and the registry record it belongs to (#1767). Left uncovered, such
/// an anchor is placed by the app's clusterer by name, and where its name fits two reconciled people
/// the order of the clusterer's input chooses between them: 1981–1988 vol. XLIV Part 1's and vol. I's
/// entries for Sir Oliver Wright, British Ambassador to the United States from 1982 to 1986, sit in the
/// name block of Admiral Jerauld Wright, whose 1951–1968 entries sort first, and went to him. The
/// registry has Sir Oliver as `114825`, with his vol. XIII entry. An anchor a correction holds apart
/// can be assigned as well, when the correction joins none: one correction's anchors can belong to two
/// people, as `108262`'s two Donald MacDonalds do. An assignment's anchor is written to the record
/// wherever no source answers for it, and a run refuses to write when the registry names the record
/// otherwise than ``Assigned/registryName``, when the registry answers for the anchor (with the
/// record, once upstream has taken it, or with another), or when an overlay entry gives it to another
/// record.
///
/// ## Anchors that stand apart
/// A held-apart anchor that no source answers and no join or assignment places belongs to no person
/// a correction could name a record for, and the bundle lists it as `apart`: the app never joins it
/// to a reconciled person by name (#1767). So a correction joins its anchors wherever the other
/// person has a record, even one with no FRUS anchor of its own; held apart and listed, an anchor
/// whose person does have a record would stand apart from it.
///
/// ## Anchors that stand apart by name alone
/// ``StandsApart`` names an anchor that no source gives to anyone and that no overlay entry carrying a
/// people-id lists, so no correction can name it, and whose person has no registry record: Public
/// Diplomacy vol. VI's "Wheeler, E. Romney", Director of the Television Service at USIA, whose overlay
/// entry carries no people-id, and whom the app's rollup joined by name to General Earle G. Wheeler
/// (#1767). The bundle lists it as `apart` with the held-apart anchors. A run refuses to write when a
/// source answers for it: the registry, once upstream has a record for the person, or an overlay entry,
/// which a correction holds apart from instead.
///
/// ## An identifier kept off one record of an entry
/// ``Withheld`` names an identifier that an entry carrying several people offers, and the one record of
/// the entry it is not the person of. A correction withholds from every people-id of the entry, so it
/// cannot divide such an entry: `FRUS-28039` carries President Truman (113770) and his nephew (116214)
/// with the President's item, which the identifier rule gives the nephew too, on the word *President*
/// in his remark, "nephew of the President" (#1767). The identifier is not stamped on that record, and
/// is not compared with the items offered to it. A run refuses to write when the registry names the
/// record otherwise, when no entry carrying it offers the identifier, or when every entry that does
/// carries no one else, which a correction is for.
///
/// ## The file
/// `PersonAuthorityIndexGenerator/persons-complete-corrections.json` (``defaultPath``), committed
/// beside the tool: an object whose `heldApart` lists the corrections and whose `assigned`,
/// `standsApart` and `withheld`, when present, list the assignments, the anchors that stand apart and
/// the identifiers kept off one record. Any other key, such as the file's `about`, is for its readers.
///
/// Version history:
///   1.0 — #1657: initial implementation
///   1.1 — A4c (plan of record §6g): a correction can withhold the entry's role text and name the
///         registry record its anchors join; eighty more corrections
///   1.2 — #1767: assignments (``Assigned``), and a join may name a record with no anchor of its own
///   1.3 — #1767's follow-up: anchors that stand apart by name alone (``StandsApart``), and an
///         identifier kept off one record of an entry carrying several people (``Withheld``)
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
        /// Who the held-apart anchors belong to, and the identifiers and role text when they are that
        /// person's.
        public let otherPerson: String
        /// The entry's anchors that belong to ``otherPerson``, as the overlay writes them
        /// (`volume/persons#ref`).
        public let anchors: [String]
        /// The registry record ``anchors`` belong to, when the bundle has one, else `nil`. Absent from
        /// a file entry, it is `nil`.
        public let joins: Joins?
        /// The entry's Wikidata id when it is not the keyed person's (``otherPerson``'s, or another
        /// namesake's), else `nil`.
        public let wikidata: String?
        /// The entry's VIAF id when it is not the keyed person's, else `nil`.
        public let viaf: String?
        /// The entry's role text when it is not the keyed person's, else `nil`: exactly as
        /// ``PersonsCompleteOverlay/roleText(from:)`` takes it (the first occupation, else the bio,
        /// whitespace collapsed), before the bundle's length limit cuts it. Absent from a file entry,
        /// it is `nil`.
        public let role: String?
        /// Why the correction is here: the issue, and what the sources say.
        public let reason: String

        /// Creates a correction.
        public init(peopleId: String, registryName: String, otherPerson: String, anchors: [String],
                    joins: Joins? = nil, wikidata: String?, viaf: String?, role: String? = nil,
                    reason: String) {
            self.peopleId = peopleId
            self.registryName = registryName
            self.otherPerson = otherPerson
            self.anchors = anchors
            self.joins = joins
            self.wikidata = wikidata
            self.viaf = viaf
            self.role = role
            self.reason = reason
        }

        /// The registry record a correction's held-apart anchors join.
        public struct Joins: Codable, Sendable, Equatable {
            /// The record's `people-id`.
            public let peopleId: String
            /// The registry's preferred name for ``peopleId``, checked at build time as
            /// ``HeldApart/registryName`` is.
            public let registryName: String

            /// Creates a join.
            public init(peopleId: String, registryName: String) {
                self.peopleId = peopleId
                self.registryName = registryName
            }
        }

        /// ``anchors`` parsed, in the file's order. An anchor that does not parse is left out, and
        /// ``PersonsCompleteCorrections/load(path:)`` refuses a file that holds one.
        var parsedAnchors: [FRUSAnchor] {
            anchors.compactMap(PersonsCompleteOverlay.parseFRUSRef)
        }
    }

    /// An anchor no source gives to anyone, and the registry record it belongs to (#1767).
    public struct Assigned: Codable, Sendable, Equatable {
        /// The anchor, as the overlay writes one (`volume/persons#ref`).
        public let anchor: String
        /// The registry record the anchor belongs to, by `people-id`.
        public let peopleId: String
        /// The registry's preferred name for ``peopleId``, checked at build time as
        /// ``HeldApart/registryName`` is.
        public let registryName: String
        /// Why: the volume's entry for the anchor, and the record's own entries in the registry.
        public let reason: String

        /// Creates an assignment.
        public init(anchor: String, peopleId: String, registryName: String, reason: String) {
            self.anchor = anchor
            self.peopleId = peopleId
            self.registryName = registryName
            self.reason = reason
        }

        /// ``anchor`` parsed, or `nil` when it is not of the `volume/persons#ref` form, which
        /// ``PersonsCompleteCorrections/loadAssignments(path:)`` refuses.
        var parsedAnchor: FRUSAnchor? {
            PersonsCompleteOverlay.parseFRUSRef(anchor)
        }
    }

    /// An anchor no source gives to anyone and no registry record is the person of, which no correction
    /// can name: no overlay entry carrying a people-id lists it (#1767's follow-up).
    public struct StandsApart: Codable, Sendable, Equatable {
        /// The anchor, as the overlay writes one (`volume/persons#ref`).
        public let anchor: String
        /// The person, as the volume prints the name.
        public let name: String
        /// Why: the volume's entry for the anchor, the person the app joined it to by name, and what the
        /// registry holds under the name.
        public let reason: String

        /// Creates an anchor that stands apart.
        public init(anchor: String, name: String, reason: String) {
            self.anchor = anchor
            self.name = name
            self.reason = reason
        }

        /// ``anchor`` parsed, or `nil` when it is not of the `volume/persons#ref` form, which
        /// ``PersonsCompleteCorrections/loadStandingApart(path:)`` refuses.
        var parsedAnchor: FRUSAnchor? {
            PersonsCompleteOverlay.parseFRUSRef(anchor)
        }
    }

    /// An identifier an entry carrying several people offers, kept off the one of them it is not the
    /// person of (#1767's follow-up).
    public struct Withheld: Codable, Sendable, Equatable {
        /// The record the identifier is kept off, by `people-id`.
        public let peopleId: String
        /// The registry's preferred name for ``peopleId``, checked at build time as
        /// ``HeldApart/registryName`` is.
        public let registryName: String
        /// The entry's Wikidata id to keep off the record, or `nil`.
        public let wikidata: String?
        /// The entry's VIAF id to keep off the record, or `nil`.
        public let viaf: String?
        /// Why: whose the identifier is, and why the rule cannot see it.
        public let reason: String

        /// Creates an identifier kept off one record.
        public init(peopleId: String, registryName: String, wikidata: String?, viaf: String?, reason: String) {
            self.peopleId = peopleId
            self.registryName = registryName
            self.wikidata = wikidata
            self.viaf = viaf
            self.reason = reason
        }
    }

    /// The file's shape.
    private struct File: Decodable {
        let heldApart: [HeldApart]
        /// Absent from a file written before #1767.
        let assigned: [Assigned]?
        /// Absent from a file written before #1767's follow-up.
        let standsApart: [StandsApart]?
        /// Absent from a file written before #1767's follow-up.
        let withheld: [Withheld]?
    }

    /// Why the corrections were not read, or do not fit the registry and overlay they were applied
    /// to. Either way the run writes nothing.
    public enum Problem: Error, Equatable, Sendable, CustomStringConvertible {
        /// The file could not be read.
        case unreadable(path: String, reason: String)
        /// The file is not a list of corrections: not JSON, or no `heldApart` of the right shape.
        case malformed(path: String, reason: String)
        /// A correction lacks a people-id, a name, the other person, the reason, or anything to
        /// hold apart or withhold.
        case incomplete(peopleId: String)
        /// An anchor is not of the `volume/persons#ref` form.
        case badAnchor(peopleId: String, anchor: String)
        /// Two corrections name one people-id.
        case duplicatePeopleId(String)
        /// A correction's join names no anchor to join, or the people-id it holds apart from.
        case joinMisplaced(peopleId: String)
        /// The registry has no record for the people-id, or names it otherwise.
        case registryNameDiffers(peopleId: String, expected: String, found: String?)
        /// The registry has no record for the join's people-id, or names it otherwise.
        case joinNameDiffers(peopleId: String, joins: String, expected: String, found: String?)
        /// No overlay entry carries the people-id.
        case noOverlayEntry(peopleId: String)
        /// An anchor is not among the anchors of the entries that carry the people-id.
        case anchorNotInEntry(peopleId: String, anchor: String)
        /// No entry that carries the people-id has this identifier.
        case identifierNotInEntry(peopleId: String, identifier: String)
        /// No entry that carries the people-id has this role text.
        case roleNotInEntry(peopleId: String, role: String)
        /// An assignment lacks its people-id, the registry's name for it, or its reason.
        case assignmentIncomplete(anchor: String)
        /// An assignment's anchor is not of the `volume/persons#ref` form.
        case badAssignedAnchor(anchor: String)
        /// Two assignments name one anchor.
        case duplicateAssignment(anchor: String)
        /// An assignment names an anchor a correction holds apart and joins to a record.
        case assignmentAlsoJoined(anchor: String)
        /// The registry has no record for an assignment's people-id, or names it otherwise.
        case assignedNameDiffers(anchor: String, peopleId: String, expected: String, found: String?)
        /// The registry answers for an assignment's anchor, with the assigned record or another.
        case assignmentAnsweredByRegistry(anchor: String, peopleId: String, registry: Int)
        /// An overlay entry gives an assignment's anchor to another record.
        case assignmentAnsweredByOverlay(anchor: String, peopleId: String, overlay: Int)
        /// An anchor that stands apart lacks the name or its reason.
        case standsApartIncomplete(anchor: String)
        /// An anchor that stands apart is not of the `volume/persons#ref` form.
        case badStandsApartAnchor(anchor: String)
        /// Two entries name one anchor that stands apart.
        case duplicateStandsApart(anchor: String)
        /// An anchor that stands apart is also a correction's or an assignment's.
        case standsApartAlsoListed(anchor: String)
        /// The registry answers for an anchor that stands apart.
        case standsApartAnsweredByRegistry(anchor: String, registry: Int)
        /// An overlay entry gives an anchor that stands apart to a record.
        case standsApartAnsweredByOverlay(anchor: String, overlay: Int)
        /// An identifier kept off one record lacks its people-id, the registry's name, the reason, or an
        /// identifier.
        case withheldIncomplete(peopleId: String)
        /// Two entries keep identifiers off one people-id.
        case duplicateWithheld(peopleId: String)
        /// The registry has no record for the people-id an identifier is kept off, or names it otherwise.
        case withheldNameDiffers(peopleId: String, expected: String, found: String?)
        /// No overlay entry carrying the people-id offers the identifier.
        case withheldNotOffered(peopleId: String, identifier: String)
        /// Every entry that offers the identifier to the people-id carries no one else the registry knows.
        case withheldNotShared(peopleId: String, identifier: String)

        /// What the run prints.
        public var description: String {
            switch self {
            case .unreadable(let path, let reason):
                return "the corrections \(path) could not be read (\(reason))."
            case .malformed(let path, let reason):
                return "the corrections \(path) are not a list of held-apart entries (\(reason))."
            case .incomplete(let peopleId):
                return "the correction for \"\(peopleId)\" lacks a people-id, a name, the other person, its reason, or anything to hold apart or withhold."
            case .badAnchor(let peopleId, let anchor):
                return "the correction for \(peopleId) lists \"\(anchor)\", which is not volume/persons#ref."
            case .joinMisplaced(let peopleId):
                return "the correction for \(peopleId) joins its anchors to \(peopleId) itself, or has none to join."
            case .duplicatePeopleId(let peopleId):
                return "two corrections name people-id \(peopleId)."
            case .registryNameDiffers(let peopleId, let expected, let found):
                return "the correction for \(peopleId) expects the registry to name it \"\(expected)\"; "
                    + "the registry names it \(found.map { "\"\($0)\"" } ?? "nothing")."
            case .joinNameDiffers(let peopleId, let joins, let expected, let found):
                return "the correction for \(peopleId) joins its anchors to \(joins), expecting the registry to name it "
                    + "\"\(expected)\"; the registry names it \(found.map { "\"\($0)\"" } ?? "nothing")."
            case .noOverlayEntry(let peopleId):
                return "the correction for \(peopleId) matches no overlay entry: upstream may have fixed it, "
                    + "or re-minted it. Read the entry and remove or update the correction."
            case .anchorNotInEntry(let peopleId, let anchor):
                return "the correction for \(peopleId) holds apart \(anchor), which no overlay entry carrying "
                    + "\(peopleId) lists."
            case .identifierNotInEntry(let peopleId, let identifier):
                return "the correction for \(peopleId) withholds \(identifier), which no overlay entry carrying "
                    + "\(peopleId) has."
            case .roleNotInEntry(let peopleId, let role):
                return "the correction for \(peopleId) withholds the role text \"\(role)\", which no overlay entry "
                    + "carrying \(peopleId) has."
            case .assignmentIncomplete(let anchor):
                return "the assignment of \"\(anchor)\" lacks a people-id, the registry's name for it, or its reason."
            case .badAssignedAnchor(let anchor):
                return "an assignment names \"\(anchor)\", which is not volume/persons#ref."
            case .duplicateAssignment(let anchor):
                return "two assignments name \(anchor)."
            case .assignmentAlsoJoined(let anchor):
                return "\(anchor) is assigned, and its correction also joins it to a record: keep one of the two."
            case .assignedNameDiffers(let anchor, let peopleId, let expected, let found):
                return "the assignment of \(anchor) to \(peopleId) expects the registry to name it \"\(expected)\"; "
                    + "the registry names it \(found.map { "\"\($0)\"" } ?? "nothing")."
            case .assignmentAnsweredByRegistry(let anchor, let peopleId, let registry):
                if String(registry) == peopleId {
                    return "the registry now gives \(anchor) to \(peopleId), as its assignment does: remove the assignment."
                }
                return "the registry gives \(anchor) to \(registry), and an assignment to \(peopleId): read the "
                    + "anchor's entry, and correct or remove the assignment."
            case .assignmentAnsweredByOverlay(let anchor, let peopleId, let overlay):
                return "an overlay entry gives \(anchor) to \(overlay), and an assignment to \(peopleId): read the "
                    + "entry, and hold the anchor apart from it with a correction that joins \(peopleId), or "
                    + "remove the assignment."
            case .standsApartIncomplete(let anchor):
                return "\"\(anchor)\" stands apart without the name the volume prints, or its reason."
            case .badStandsApartAnchor(let anchor):
                return "an anchor that stands apart is \"\(anchor)\", which is not volume/persons#ref."
            case .duplicateStandsApart(let anchor):
                return "\(anchor) stands apart twice."
            case .standsApartAlsoListed(let anchor):
                return "\(anchor) stands apart, and a correction or an assignment also lists it: keep one of the two."
            case .standsApartAnsweredByRegistry(let anchor, let registry):
                return "the registry gives \(anchor), which stands apart, to \(registry): read the record, and "
                    + "remove the anchor from standsApart, or assign it."
            case .standsApartAnsweredByOverlay(let anchor, let overlay):
                return "an overlay entry gives \(anchor), which stands apart, to \(overlay): hold it apart from "
                    + "that entry with a correction instead."
            case .withheldIncomplete(let peopleId):
                return "the identifier kept off \"\(peopleId)\" lacks a people-id, a name, its reason or an identifier."
            case .duplicateWithheld(let peopleId):
                return "two entries keep identifiers off people-id \(peopleId)."
            case .withheldNameDiffers(let peopleId, let expected, let found):
                return "an identifier kept off \(peopleId) expects the registry to name it \"\(expected)\"; "
                    + "the registry names it \(found.map { "\"\($0)\"" } ?? "nothing")."
            case .withheldNotOffered(let peopleId, let identifier):
                return "\(identifier) is kept off \(peopleId), and no overlay entry carrying \(peopleId) offers it: "
                    + "upstream may have changed the entry. Read it, and update or remove the entry."
            case .withheldNotShared(let peopleId, let identifier):
                return "\(identifier) is kept off \(peopleId), and the entries that offer it carry no one else: "
                    + "withhold it with a correction instead."
            }
        }
    }

    /// Reads and checks the file at `path`.
    ///
    /// - Parameter path: The corrections file, ``defaultPath`` for a run from the project root.
    /// - Returns: The corrections, in the file's order.
    /// - Throws: ``Problem`` when the file cannot be read, is not a list of corrections, or holds
    ///   one that is incomplete, has an anchor of the wrong form, repeats a people-id, or joins its
    ///   anchors to nothing or to the people-id it holds them apart from. A file entry with no `role`
    ///   key withholds no role text, and one with no `joins` key names no record.
    public static func load(path: String) throws -> [HeldApart] {
        let corrections = try read(path: path).heldApart
        var seen = Set<String>()
        for correction in corrections {
            let blank = [correction.peopleId, correction.registryName, correction.otherPerson,
                         correction.reason].contains { $0.trimmingCharacters(in: .whitespaces).isEmpty }
            let nothingHeld = correction.anchors.isEmpty && correction.wikidata == nil
                && correction.viaf == nil && correction.role == nil
            if blank || nothingHeld { throw Problem.incomplete(peopleId: correction.peopleId) }
            for anchor in correction.anchors where PersonsCompleteOverlay.parseFRUSRef(anchor) == nil {
                throw Problem.badAnchor(peopleId: correction.peopleId, anchor: anchor)
            }
            if let joins = correction.joins,
               correction.anchors.isEmpty || joins.peopleId == correction.peopleId {
                throw Problem.joinMisplaced(peopleId: correction.peopleId)
            }
            guard seen.insert(correction.peopleId).inserted else {
                throw Problem.duplicatePeopleId(correction.peopleId)
            }
        }
        return corrections
    }

    /// Reads and checks the assignments in the file at `path` (#1767).
    ///
    /// - Parameter path: The corrections file, ``defaultPath`` for a run from the project root.
    /// - Returns: The assignments, in the file's order; none for a file without an `assigned` key.
    /// An anchor a correction holds apart may be assigned when its correction joins none: the anchors
    /// of one correction can belong to two people, whom one join cannot name.
    ///
    /// - Throws: ``Problem`` when the file cannot be read or is not a list of corrections, or when an
    ///   assignment is incomplete, names an anchor of the wrong form, repeats an anchor, or names one
    ///   that a correction in the same file holds apart and joins to a record.
    public static func loadAssignments(path: String) throws -> [Assigned] {
        let file = try read(path: path)
        let joined = Set(file.heldApart.filter { $0.joins != nil }.flatMap(\.parsedAnchors))
        var seen = Set<FRUSAnchor>()
        for assignment in file.assigned ?? [] {
            let blank = [assignment.peopleId, assignment.registryName, assignment.reason]
                .contains { $0.trimmingCharacters(in: .whitespaces).isEmpty }
            if blank { throw Problem.assignmentIncomplete(anchor: assignment.anchor) }
            guard let anchor = assignment.parsedAnchor else {
                throw Problem.badAssignedAnchor(anchor: assignment.anchor)
            }
            if joined.contains(anchor) { throw Problem.assignmentAlsoJoined(anchor: assignment.anchor) }
            guard seen.insert(anchor).inserted else {
                throw Problem.duplicateAssignment(anchor: assignment.anchor)
            }
        }
        return file.assigned ?? []
    }

    /// Reads and checks the anchors that stand apart in the file at `path` (#1767's follow-up).
    ///
    /// - Parameter path: The corrections file, ``defaultPath`` for a run from the project root.
    /// - Returns: The anchors, in the file's order; none for a file without a `standsApart` key.
    /// - Throws: ``Problem`` when the file cannot be read or is not a list of corrections, or when an
    ///   entry lacks its name or reason, names an anchor of the wrong form, repeats an anchor, or names
    ///   one that a correction holds apart or an assignment places.
    public static func loadStandingApart(path: String) throws -> [StandsApart] {
        let file = try read(path: path)
        let listed = Set(file.heldApart.flatMap(\.parsedAnchors))
            .union((file.assigned ?? []).compactMap(\.parsedAnchor))
        var seen = Set<FRUSAnchor>()
        for entry in file.standsApart ?? [] {
            let blank = [entry.name, entry.reason].contains { $0.trimmingCharacters(in: .whitespaces).isEmpty }
            if blank { throw Problem.standsApartIncomplete(anchor: entry.anchor) }
            guard let anchor = entry.parsedAnchor else { throw Problem.badStandsApartAnchor(anchor: entry.anchor) }
            if listed.contains(anchor) { throw Problem.standsApartAlsoListed(anchor: entry.anchor) }
            guard seen.insert(anchor).inserted else { throw Problem.duplicateStandsApart(anchor: entry.anchor) }
        }
        return file.standsApart ?? []
    }

    /// Reads and checks the identifiers kept off one record in the file at `path` (#1767's follow-up).
    ///
    /// - Parameter path: The corrections file, ``defaultPath`` for a run from the project root.
    /// - Returns: The entries, in the file's order; none for a file without a `withheld` key.
    /// - Throws: ``Problem`` when the file cannot be read or is not a list of corrections, or when an
    ///   entry lacks its people-id, name, reason or an identifier, or repeats a people-id.
    public static func loadWithheld(path: String) throws -> [Withheld] {
        let file = try read(path: path)
        var seen = Set<String>()
        for entry in file.withheld ?? [] {
            let blank = [entry.peopleId, entry.registryName, entry.reason]
                .contains { $0.trimmingCharacters(in: .whitespaces).isEmpty }
            if blank || (entry.wikidata == nil && entry.viaf == nil) {
                throw Problem.withheldIncomplete(peopleId: entry.peopleId)
            }
            guard seen.insert(entry.peopleId).inserted else { throw Problem.duplicateWithheld(peopleId: entry.peopleId) }
        }
        return file.withheld ?? []
    }

    /// The first way the identifiers kept off one record do not fit the registry and overlay they are
    /// applied to, or `nil` when every one does (#1767's follow-up).
    ///
    /// - Parameters:
    ///   - withheld: The identifiers the run keeps off one record.
    ///   - entries: The overlay's entries.
    ///   - registryName: The registry's preferred name for a people-id, or `nil` when it has none.
    ///   - isKnown: Whether the bundle has a record for a people-id, as an entry's other people are counted.
    public static func misfit(ofWithheld withheld: [Withheld], entries: [PersonsCompleteOverlay.Entry],
                              registryName: (String) -> String?, isKnown: (String) -> Bool) -> Problem? {
        for entry in withheld {
            let found = registryName(entry.peopleId)
            guard found == entry.registryName else {
                return .withheldNameDiffers(peopleId: entry.peopleId, expected: entry.registryName, found: found)
            }
            let carrying = entries.filter { $0.peopleIds.contains(entry.peopleId) }
            for (identifier, offers) in [(entry.wikidata, { (e: PersonsCompleteOverlay.Entry) in e.wikidata == entry.wikidata }),
                                         (entry.viaf, { (e: PersonsCompleteOverlay.Entry) in e.viaf == entry.viaf })] {
                guard let identifier else { continue }
                let offering = carrying.filter(offers)
                guard !offering.isEmpty else { return .withheldNotOffered(peopleId: entry.peopleId, identifier: identifier) }
                let shared = offering.contains { $0.peopleIds.contains { $0 != entry.peopleId && isKnown($0) } }
                guard shared else { return .withheldNotShared(peopleId: entry.peopleId, identifier: identifier) }
            }
        }
        return nil
    }

    /// The file at `path`, decoded and not yet checked.
    private static func read(path: String) throws -> File {
        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: path))
        } catch {
            throw Problem.unreadable(path: path, reason: error.localizedDescription)
        }
        do {
            return try JSONDecoder().decode(File.self, from: data)
        } catch {
            throw Problem.malformed(path: path, reason: String(describing: error))
        }
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
            if let joins = correction.joins {
                let joined = registryName(joins.peopleId)
                guard joined == joins.registryName else {
                    return .joinNameDiffers(peopleId: correction.peopleId, joins: joins.peopleId,
                                            expected: joins.registryName, found: joined)
                }
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
            if let role = correction.role, !carrying.contains(where: { $0.role == role }) {
                return .roleNotInEntry(peopleId: correction.peopleId, role: role)
            }
        }
        return nil
    }
}
