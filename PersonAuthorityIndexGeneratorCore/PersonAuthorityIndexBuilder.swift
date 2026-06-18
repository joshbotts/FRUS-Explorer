// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - PersonAuthorityIndexBuilder

/// Parses `HistoryAtState/people` record XML into the bundled `PersonAuthorityIndex`.
///
/// Each record aggregates the per-volume FRUS `persName` anchors (`<source-url>` of the form
/// `…/historicaldocuments/{volume}/persons#{ref}`) that refer to one human, under one canonical
/// `<id>`. The builder keeps only the FRUS anchors (the app's corpus) and the canonical metadata
/// (preferred name, birth/death years, VIAF). Pure and file-system-light: `parseRecord(xml:)` works
/// on a string for testability; `build(dataDirectory:…)` walks a checkout.
public enum PersonAuthorityIndexBuilder {

    /// Matches a FRUS persons-page anchor and captures `(volume, ref)`.
    /// e.g. `https://history.state.gov/historicaldocuments/frus1961-63v14/persons#p_KHA1`.
    private static let frusAnchor = try! NSRegularExpression(
        pattern: #"historicaldocuments/(frus[^/]+)/persons#(.+)$"#)

    // MARK: - Single record

    /// Parses one record's XML. Returns `nil` when the record has no numeric id or no FRUS anchor
    /// (e.g. a person known only from Visits/Principals, outside the app's corpus).
    public static func parseRecord(xml: String) throws -> PersonAuthorityRecord? {
        let doc = try XMLDocument(xmlString: xml, options: [])
        guard let root = doc.rootElement() else { return nil }

        guard let idText = root.firstChildText("id"), let canonicalId = Int(idText) else { return nil }

        let anchors = root.descendantTexts("source-url").compactMap(parseAnchor(_:))
        guard !anchors.isEmpty else { return nil }

        let name = root.elements(forName: "names").first?
            .elements(forName: "preferred").first?
            .firstChildText("name")?.trimmed ?? ""

        let birth = root.firstChildText("birth-year").flatMap { Int($0.trimmed) }
        let death = root.firstChildText("death-year").flatMap { Int($0.trimmed) }

        var viaf: String?
        if let authorities = root.elements(forName: "authorities").first {
            for a in authorities.elements(forName: "authority") where a.attribute(forName: "service")?.stringValue == "viaf" {
                if let v = a.stringValue?.trimmed, !v.isEmpty { viaf = v }
            }
        }

        return PersonAuthorityRecord(canonicalId: canonicalId, name: name,
                                     birthYear: birth, deathYear: death, viaf: viaf,
                                     frusAnchors: anchors)
    }

    /// Decodes a single `source-url` into a FRUS `(volume, ref)` anchor, or `nil` if it isn't one.
    public static func parseAnchor(_ url: String) -> FRUSAnchor? {
        let s = url.trimmed
        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        guard let m = frusAnchor.firstMatch(in: s, range: range),
              let volRange = Range(m.range(at: 1), in: s),
              let refRange = Range(m.range(at: 2), in: s) else { return nil }
        let ref = String(s[refRange]).trimmed
        guard !ref.isEmpty else { return nil }
        return FRUSAnchor(volumeId: String(s[volRange]), ref: ref)
    }

    // MARK: - Full build

    /// Builds the index from a directory of record XML files (recursively).
    ///
    /// `keepVolume` lets the caller restrict the crosswalk to known volumes (e.g. those in the app
    /// manifest); pass `nil` to keep all FRUS volumes.
    public static func build(dataDirectory: URL, version: Int, generated: String,
                             source: String, keepVolume: ((String) -> Bool)? = nil)
    throws -> (index: PersonAuthorityIndex, stats: BuildStats) {
        var stats = BuildStats()
        var crosswalk: [String: [String: Int]] = [:]
        var authority: [String: AuthorityEntry] = [:]

        let fm = FileManager.default
        let enumerator = fm.enumerator(at: dataDirectory, includingPropertiesForKeys: nil)
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "xml" else { continue }
            guard let data = try? Data(contentsOf: url),
                  let xml = String(data: data, encoding: .utf8) else { continue }
            stats.recordsParsed += 1
            guard let record = try? parseRecord(xml: xml) else { continue }

            let kept = record.frusAnchors.filter { keepVolume?($0.volumeId) ?? true }
            guard !kept.isEmpty else { continue }
            stats.recordsWithFRUSAnchors += 1

            for anchor in kept {
                crosswalk[anchor.volumeId, default: [:]][anchor.ref] = record.canonicalId
            }
            authority[String(record.canonicalId)] = AuthorityEntry(
                n: record.name, b: record.birthYear, d: record.deathYear, v: record.viaf)
        }

        stats.crosswalkEntries = crosswalk.values.reduce(0) { $0 + $1.count }
        stats.distinctVolumes = crosswalk.count
        stats.withViaf = authority.values.reduce(0) { $0 + (($1.v?.isEmpty == false) ? 1 : 0) }

        let index = PersonAuthorityIndex(version: version, generated: generated, source: source,
                                         crosswalk: crosswalk, authority: authority)
        return (index, stats)
    }
}

// MARK: - XML helpers

private extension XMLElement {
    /// Text of the first direct child element with `name`.
    func firstChildText(_ name: String) -> String? {
        elements(forName: name).first?.stringValue
    }
    /// Text of every descendant element with `name`, at any depth.
    func descendantTexts(_ name: String) -> [String] {
        (try? nodes(forXPath: ".//\(name)"))?.compactMap { $0.stringValue } ?? []
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
