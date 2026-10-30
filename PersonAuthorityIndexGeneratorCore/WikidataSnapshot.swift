// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - WikidataSnapshot

/// The Wikidata facts the identifier rule reads (#1767): `PersonAuthorityIndexGenerator/wikidata-snapshot.json`,
/// committed beside the tool and written only by `tools/person-authority-facts/refresh_wikidata_snapshot.py`.
///
/// It holds every item an overlay entry names that can reach a registry record, and every item that holds
/// one of the VIAF ids those entries or records carry, each reduced to what ``PersonIdentifierRule`` tests:
/// whether it is a person, its names, its life years, its own VIAF ids, its description and the labels of
/// its positions, occupations and employers. For every such VIAF id it lists the items that hold it, an
/// empty list when none does, so that a VIAF id no query answered for is told from one nobody holds.
/// Wikidata is CC0. The generator reads the file by path from the project root, as it reads the
/// corrections, and never goes to the network, so a run is reproducible.
///
/// Version history:
///   1.0 — #1767 lane B: initial implementation
public struct WikidataSnapshot: Decodable, Sendable, Equatable {

    /// Where a run reads the snapshot, relative to the project root.
    public static let defaultPath = "PersonAuthorityIndexGenerator/wikidata-snapshot.json"

    /// The day the facts were fetched (yyyy-MM-dd), which the bundle's provenance names.
    public let fetched: String
    /// `QID → facts`, keyed by the id the overlay or a holder query gave, through any redirect.
    public let items: [String: Item]
    /// `VIAF id → [QID]`: the items holding it at a rank other than deprecated, an empty list when none.
    public let viafHolders: [String: [String]]
    /// `VIAF id → [QID]`: the items whose every statement of it is deprecated. Absent from the file when none.
    public let viafDeprecatedHolders: [String: [String]]

    /// Creates a snapshot, for a test.
    public init(fetched: String, items: [String: Item], viafHolders: [String: [String]],
                viafDeprecatedHolders: [String: [String]] = [:]) {
        self.fetched = fetched
        self.items = items
        self.viafHolders = viafHolders
        self.viafDeprecatedHolders = viafDeprecatedHolders
    }

    private enum CodingKeys: String, CodingKey {
        case fetched, items, viafHolders, viafDeprecatedHolders
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fetched = try container.decode(String.self, forKey: .fetched)
        items = try container.decode([String: Item].self, forKey: .items)
        viafHolders = try container.decode([String: [String]].self, forKey: .viafHolders)
        viafDeprecatedHolders = try container.decodeIfPresent([String: [String]].self,
                                                              forKey: .viafDeprecatedHolders) ?? [:]
    }

    // MARK: - Item

    /// One item's facts, as the refresh tool derives them. A key absent from the file is empty.
    public struct Item: Decodable, Sendable, Equatable {
        /// An instance of human (P31 Q5), at any rank.
        public let human: Bool
        /// Every name the item offers: labels and aliases (en, mul), its English Wikipedia title, its
        /// name claims (P1477, P1559, P742, P1449) and its family names' labels (P734).
        public let names: [String]
        /// Years of birth (P569) given to a year or finer, preferred rank first.
        public let born: [Int]
        /// Years of death (P570), as ``born``.
        public let died: [Int]
        /// The item's own VIAF ids (P214), at any rank.
        public let viaf: [String]
        /// The English description.
        public let description: String?
        /// Labels of its positions held, occupations and employers (P39, P106, P108).
        public let roles: [String]
        /// The item the id redirects to, whose facts these are; `nil` when the id is the item's own.
        public let redirect: String?
        /// The id names no item: deleted.
        public let missing: Bool

        /// Creates an item, for a test.
        public init(human: Bool, names: [String], born: [Int] = [], died: [Int] = [], viaf: [String] = [],
                    description: String? = nil, roles: [String] = [], redirect: String? = nil,
                    missing: Bool = false) {
            self.human = human
            self.names = names
            self.born = born
            self.died = died
            self.viaf = viaf
            self.description = description
            self.roles = roles
            self.redirect = redirect
            self.missing = missing
        }

        private enum CodingKeys: String, CodingKey {
            case human, names, born, died, viaf, description, roles, redirect, missing
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            human = try c.decodeIfPresent(Bool.self, forKey: .human) ?? false
            names = try c.decodeIfPresent([String].self, forKey: .names) ?? []
            born = try c.decodeIfPresent([Int].self, forKey: .born) ?? []
            died = try c.decodeIfPresent([Int].self, forKey: .died) ?? []
            viaf = try c.decodeIfPresent([String].self, forKey: .viaf) ?? []
            description = try c.decodeIfPresent(String.self, forKey: .description)
            roles = try c.decodeIfPresent([String].self, forKey: .roles) ?? []
            redirect = try c.decodeIfPresent(String.self, forKey: .redirect)
            missing = try c.decodeIfPresent(Bool.self, forKey: .missing) ?? false
        }
    }

    // MARK: - Reading

    /// Why the snapshot was not read, or does not cover what a run would stamp. Either way the run
    /// writes nothing.
    public enum Problem: Error, Equatable, Sendable, CustomStringConvertible {
        /// The file could not be read.
        case unreadable(path: String, reason: String)
        /// The file is not a snapshot.
        case malformed(path: String, reason: String)
        /// A VIAF id is listed as held by an item the file has no facts for.
        case holderWithoutFacts(viaf: String, item: String)
        /// Overlay identifiers the run would test have no facts: the overlay or the registry has moved
        /// since the snapshot was fetched. `ids` is the first few of `count`.
        case identifiersWithoutFacts(count: Int, ids: [String])

        /// What the run prints.
        public var description: String {
            switch self {
            case .unreadable(let path, let reason):
                return "the Wikidata snapshot \(path) could not be read (\(reason))."
            case .malformed(let path, let reason):
                return "the Wikidata snapshot \(path) is not a snapshot (\(reason))."
            case .holderWithoutFacts(let viaf, let item):
                return "the Wikidata snapshot lists \(item) as holding VIAF \(viaf) and has no facts for it: refresh it."
            case .identifiersWithoutFacts(let count, let ids):
                return "\(count) overlay identifiers the run would test have no facts in the Wikidata snapshot "
                    + "(\(ids.joined(separator: ", "))\(count > ids.count ? ", …" : "")): the overlay or the registry "
                    + "has moved since it was fetched. Refresh it with tools/person-authority-facts/refresh_wikidata_snapshot.py."
            }
        }
    }

    /// Reads and checks the snapshot at `path`.
    ///
    /// - Parameter path: The snapshot, ``defaultPath`` for a run from the project root.
    /// - Throws: ``Problem`` when the file cannot be read, is not a snapshot, or names a holder of a
    ///   VIAF id it has no facts for.
    public static func load(path: String) throws -> WikidataSnapshot {
        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: path))
        } catch {
            throw Problem.unreadable(path: path, reason: error.localizedDescription)
        }
        let snapshot: WikidataSnapshot
        do {
            snapshot = try JSONDecoder().decode(WikidataSnapshot.self, from: data)
        } catch {
            throw Problem.malformed(path: path, reason: String(describing: error))
        }
        if let problem = snapshot.inconsistency { throw problem }
        return snapshot
    }

    /// The first VIAF id listed as held by an item the snapshot has no facts for, or `nil`.
    var inconsistency: Problem? {
        for (viaf, holders) in viafHolders.sorted(by: { $0.key < $1.key }) {
            if let item = holders.first(where: { items[$0] == nil }) {
                return .holderWithoutFacts(viaf: viaf, item: item)
            }
        }
        return nil
    }

    /// The items holding `viaf` at a rank other than deprecated.
    func holders(of viaf: String) -> [String] {
        viafHolders[viaf] ?? []
    }

    /// Every item holding `viaf`, deprecated statements included.
    func allHolders(of viaf: String) -> Set<String> {
        Set(holders(of: viaf)).union(viafDeprecatedHolders[viaf] ?? [])
    }
}
