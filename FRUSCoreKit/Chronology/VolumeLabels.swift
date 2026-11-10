// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - VolumeLabelParts

/// A volume's short label as its two halves, for a surface that lays them out apart — see
/// `VolumeLabels.distilledVolumeLabelParts`.
///
/// Version history:
///   1.0 — #1388: initial implementation (the Mac hover magnifier; A2 / #1379's matrix rows next)
///   1.1 — #1379: the Cross-Reference heat matrix's row labels read it, through
///          `HeatMatrixRowAxis.label(volumeId:entry:)`
///   1.2 — 2026-11-10 (FRUS Explorer Light, S23b): moved into FRUSCoreKit with the label's grammar
///          (`VolumeLabels`), public, since the kit's cross-reference store titles a page by its volume
public struct VolumeLabelParts: Equatable, Sendable {
    /// The volume's descriptive topic, **uncut** — the joined label trims it to
    /// `VolumeLabels.volumeTopicMaxLength` characters and this does not — or `""` for a
    /// volume whose title is pure boilerplate (the early annuals).
    public let topic: String
    /// The period + volume tag (`"1961-63 v10–12 fiche"`), which tells every bundled volume apart.
    public let tag: String
}

// MARK: - VolumeLabels

/// A volume's short label, distilled from its id and its full title: the Chronology legend's, the
/// Cross-Reference heat matrix's rows', and the tag the cross-reference store titles a page by
/// (`CrossReferenceStore.volumeCitation(volumeId:subseries:)`).
///
/// The grammar was `ChronologyViewModel`'s, which keeps `distilledVolumeLabel(volumeId:subseries:title:)`,
/// `distilledVolumeLabelParts(volumeId:subseries:title:)` and `volumeTopicMaxLength` as forwarders to
/// these, so every app call site reads as it did. Pure: an id, a subseries and a title in, text out.
///
/// Version history:
///   1.0 — 2026-11-10 (FRUS Explorer Light, S23b): moved out of `ChronologyViewModel`, line for line,
///          when `CrossReferenceStore` moved into FRUSCoreKit and could no longer name the view model
public enum VolumeLabels {

    /// Maximum characters `distilledVolumeLabel` keeps from a volume's topic before eliding (the
    /// uncut topic is `distilledVolumeLabelParts`'s); the period/volume tag keeps the overall
    /// label distinct even when the topic is truncated.
    public static let volumeTopicMaxLength = 40

    /// A concise, distinct, descriptive label for a volume, distilled from its full FRUS
    /// title for the chronology chart legend and filter banner — where the raw title (e.g.
    /// "Foreign Relations of the United States, 1969–1976, Volume XX, Southeast Asia,
    /// 1969–1972") is far too long and repetitive to tell volumes apart.
    ///
    /// The result is the volume's **topic** (when the title carries one) joined to a compact
    /// **period + volume/part tag** derived from the id — e.g. "Southeast Asia · 1969-76 v20"
    /// or "Soviet Union · 1981-88 v6". The early annual "Papers Relating to Foreign Affairs"
    /// volumes have no topic, so they reduce to just the tag, e.g. "1864 pt.1".
    ///
    /// **The tag alone tells every bundled volume apart**, so labels stay distinct even after a
    /// long topic is truncated. Until #1388 this was asserted and false: 11 tags were shared by 29
    /// volumes — a microfiche supplement and the volume it supplements, the Paris and Berlin
    /// conference volumes and the annuals of their year, the parts of five E-volumes — and only
    /// the topic, which the 40-character cut can remove, kept their labels apart.
    /// `CorpusAnalyticsServiceTests.distilledLabelUniqueAcrossBundledCorpus` now pins it over the
    /// whole bundled manifest.
    ///
    /// **A unique tag protects only a surface that keeps it when it cuts.** Two do, and neither
    /// renders this joined string: the Cross-Reference heat matrix's row labels and the Mac hover
    /// magnifier each lay out `distilledVolumeLabelParts` as a tail-truncated topic beside a tag
    /// that never truncates (the matrix head-truncated this string until #1379). A
    /// surface that renders this joined string on one tail-truncated line — the Chronology legend
    /// and filter banner, the Corpus Analytics legend, the iPad compilation parent line — drops
    /// the tag FIRST when the line is too narrow. The Mac document window's centre label follows
    /// it with `" · Doc N"` and truncates in the middle, which is where the tag then sits.
    ///
    /// - Parameters:
    ///   - volumeId: The volume's stable id, e.g. `"frus1969-76v20"`.
    ///   - subseries: The volume's subseries period, e.g. `"1969-76"`.
    ///   - title: The full TEI volume title (whitespace already collapsed on manifest decode).
    public static func distilledVolumeLabel(volumeId: String, subseries: String, title: String) -> String {
        let parts = distilledVolumeLabelParts(volumeId: volumeId, subseries: subseries, title: title)
        let topic = truncateTopic(parts.topic)
        return topic.isEmpty ? parts.tag : "\(topic) · \(parts.tag)"
    }

    /// `distilledVolumeLabel`'s two halves, apart: the topic **uncut** and the tag.
    ///
    /// For a surface that has to fit the label in a fixed width and must not lose the tag doing
    /// it — it lays the halves out as two texts, truncates only the topic, and lets the tag take
    /// the width it needs. #1388 found the Mac hover magnifier cutting the joined label to
    /// "Microfiche Supplement, American… ·…", with no tag left at all; #1379 found the
    /// Cross-Reference matrix cutting its row labels at both ends, and its rows now read the split
    /// too (`HeatMatrixRowAxis.label(volumeId:entry:)`). The topic is NOT pre-cut to
    /// `volumeTopicMaxLength`: that cut exists to keep the joined string short, and a surface
    /// that truncates the topic itself can show as much of it as its width allows.
    ///
    /// - Parameters:
    ///   - volumeId: The volume's stable id, e.g. `"frus1961-63v10-12mSupp"`.
    ///   - subseries: The volume's subseries period, e.g. `"1961-63"`.
    ///   - title: The full TEI volume title.
    /// - Returns: The topic (`""` for a topic-less early annual) and the tag.
    public static func distilledVolumeLabelParts(volumeId: String, subseries: String,
                                                 title: String) -> VolumeLabelParts {
        VolumeLabelParts(topic: volumeTopic(from: title),
                         tag: volumeTag(volumeId: volumeId, subseries: subseries))
    }

    /// Compact period + volume tag, read from the **whole** id suffix after `frus<subseries>`
    /// in id order — e.g. `"1969-76 v20"`, `"1952-54 v2 pt.1"`, `"1864 pt.1"`, `"1870"`,
    /// `"1961-63 v10–12 fiche"`, `"1969-76 vE-15 pt.2 ed.2"`, `"1919 Paris v1"`.
    ///
    /// ## Why the whole suffix (#1388)
    /// This used to take the first `v<digits>` and the first `p<digits>` anywhere in the id, and
    /// kept the rest of the id only when neither matched. So whenever one did match it dropped
    /// the token that told two volumes apart: `frus1961-63v10-12mSupp` read `1961-63 v10`, Volume
    /// X's own tag; `frus1919Parisv01` read `1919 v1`, the 1919 annual's; `frus1977-80v09Ed2` lost
    /// its edition. Its `(E-)?` branch never matched the ids' lower-case `ve05`, so an E-volume
    /// part had no volume number at all, and `p<digits>` matched inside `Supp01` and `app1`, so
    /// a supplement and an appendix read as Parts (`frus1917Supp01v01` was `1917 v1 pt.1`).
    ///
    /// ## The grammar
    /// Tokens are read in the order the id spells them. That is usually the order the volume's own
    /// title prints them — "Part II, Volume I" is `pt.2 v1` — but the tag follows the id where
    /// the two differ: `frus1917-72PubDipv06`'s title prints "Volume VI, Public Diplomacy" and its
    /// tag reads `PubDip v6`.
    /// - `v07` → `v7`; `ve05` → `vE-5`; `v10-12` → `v10–12`
    /// - `p2` → `pt.2`
    /// - `mSupp` → `fiche`, a microfiche supplement (`frus1961-63v07-09mSupp`'s title never says
    ///   so, which leaves the tag as the only place that can)
    /// - `Supp` / `Supp02` → `Supp` / `Supp.2`; `app` / `app1` → `app` / `app.1`
    /// - `Ed2` → `ed.2`
    /// - a capitalised name — `Paris`, `Berlin`, `PubDip`, `CairoTehran`, `Guat` — verbatim
    ///
    /// Anything else ends the scan and is kept verbatim, so an id shape this grammar does not know
    /// still yields a tag that keeps its difference rather than one that drops it.
    /// `ChronologyVolumeLabelTests.everySuffixShapeReadsAsItsPinnedTag` pins one reading per
    /// id-suffix shape the bundled manifest uses, and fails naming any shape a new volume brings.
    private static func volumeTag(volumeId: String, subseries: String) -> String {
        var suffix = Substring(volumeId)
        let withSub = "frus" + subseries
        if suffix.hasPrefix(withSub) { suffix = suffix.dropFirst(withSub.count) }
        else if suffix.hasPrefix("frus") { suffix = suffix.dropFirst(4) }
        var tokens: [String] = []
        var rest = suffix.drop { "-_ ".contains($0) }
        var extendsName = false
        while !rest.isEmpty {
            guard let next = nextVolumeIdToken(rest) else {
                // A shape this grammar does not know: keep it verbatim rather than drop it.
                tokens.append(String(rest))
                break
            }
            if next.isName, extendsName, let name = tokens.popLast() {
                tokens.append(name + next.text)   // `Pub` + `Dip`, `Cairo` + `Tehran`
            } else {
                tokens.append(next.text)
            }
            extendsName = next.isName
            rest = rest[next.end...]
        }
        return ([subseries] + tokens).filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// Reads one token of a volume-id suffix at the start of `rest` (see `volumeTag` for the
    /// grammar), or `nil` when nothing it knows starts there.
    ///
    /// The order is load-bearing: `Ed2` and `Supp02` are tried before the capitalised-name rule,
    /// which cannot read `Ed2` at all and would read `Supp02` as the name `Sup` followed by a
    /// Part (`1918 Sup pt.2`), because a name stops before `p` + digit. A name stops before the
    /// next capital, `v`/`ve` + digit, or `p` + digit, so `Parisv01` is `Paris` then `v1` rather
    /// than one name `Parisv`, and `IranEd2` is `Iran` then `ed.2`.
    ///
    /// - Parameter rest: The unread remainder of the suffix.
    /// - Returns: The token's display text, where it ends in `rest`, and whether it is a name
    ///   (consecutive names are joined without a space, as the id writes them).
    private static func nextVolumeIdToken(_ rest: Substring)
        -> (text: String, end: Substring.Index, isName: Bool)? {
        if let m = rest.prefixMatch(of: /Ed([0-9]+)/) {
            return ("ed.\(idNumber(m.1))", m.range.upperBound, false)
        }
        if let m = rest.prefixMatch(of: /mSupp/) {
            return ("fiche", m.range.upperBound, false)
        }
        if let m = rest.prefixMatch(of: /Supp([0-9]+)?/) {
            return (m.1.map { "Supp.\(idNumber($0))" } ?? "Supp", m.range.upperBound, false)
        }
        if let m = rest.prefixMatch(of: /app([0-9]+)?/) {
            return (m.1.map { "app.\(idNumber($0))" } ?? "app", m.range.upperBound, false)
        }
        if let m = rest.prefixMatch(of: /v(e)?([0-9]+)(?:-([0-9]+))?/) {
            let volume = (m.1 == nil ? "v" : "vE-") + idNumber(m.2)
            return (m.3.map { "\(volume)–\(idNumber($0))" } ?? volume, m.range.upperBound, false)
        }
        if let m = rest.prefixMatch(of: /p([0-9]+)/) {
            return ("pt.\(idNumber(m.1))", m.range.upperBound, false)
        }
        if let m = rest.prefixMatch(of: /[A-Z][a-z]*?(?=[A-Z]|ve?[0-9]|p[0-9]|$)/) {
            return (String(m.0), m.range.upperBound, true)
        }
        return nil
    }

    /// A zero-padded id number as the volume prints it: `"07"` → `"7"`.
    ///
    /// - Parameter digits: A run of ASCII digits from a volume id.
    /// - Returns: The number without leading zeros, or the digits unchanged if they overflow.
    private static func idNumber(_ digits: Substring) -> String {
        Int(digits).map(String.init) ?? String(digits)
    }

    /// The descriptive topic distilled from a full FRUS volume title, or `""` when the title
    /// is pure boilerplate (the early annual "Papers Relating…/Message of the President…"
    /// volumes). Strips the series boilerplate, the subseries year, the "Volume N"/"Part N"
    /// tokens, and trailing date ranges. It does NOT truncate: `distilledVolumeLabel` cuts the
    /// result to `volumeTopicMaxLength`, and `distilledVolumeLabelParts` returns it whole.
    ///
    /// "Volume N" includes a 1969–76 E-volume's "Volume E–13" (#1472). Until then the removal
    /// matched only a Roman numeral, so all 22 E-volumes' topics began with their own number —
    /// "Volume E–13, Documents on China" — and every label said it twice, once there and once in
    /// the tag ("… · 1969-76 vE-13"). The topic now begins "Documents on China".
    ///
    /// A colon left at either end is trimmed with the spaces and commas (#1761): frus1961-63v23 prints
    /// "Volume XXIII: Southeast Asia", so once the number and the years were removed its topic began
    /// ": Southeast Asia". Over the bundled manifest that title is the only one the colon changes.
    private static func volumeTopic(from title: String) -> String {
        var t = title.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        let prefixes = [
            "Foreign Relations of the United States, Diplomatic Papers,",
            "Foreign Relations of the United States,",
            "Papers Relating to the Foreign Relations of the United States,",
            "Papers Relating to Foreign Affairs,"
        ]
        for p in prefixes where t.hasPrefix(p) {
            t = String(t.dropFirst(p.count)).trimmingCharacters(in: .whitespaces)
            break
        }
        for boilerplate in [
            "Accompanying the Annual Message of the President",
            "With the Annual Message of the President",
            "with the Annual Message of the President",
            "Transmitted to Congress",
            "Diplomatic Papers"
        ] {
            t = t.replacingOccurrences(of: boilerplate, with: "")
        }
        let removals = [
            ",?\\s*\\bVolumes?\\s+(?:E[–-][0-9]+|[IVXLCDM/]+(?:,\\s*[IVXLCDM/]+)*)\\b",
            ",?\\s*\\bPart\\s+([IVXLCDM]+|[0-9]+)\\b",
            "to the .*?Congress",
            "^[0-9]{4}(?:[–-][0-9]{2,4})?\\s*,?\\s*",
            ",?\\s*[A-Z][a-z]+ [0-9]{1,2},?\\s*[0-9]{4}.*$",
            ",?\\s*[A-Z][a-z]+ [0-9]{4}\\s*[–-]\\s*[A-Z][a-z]+ [0-9]{4}\\s*$",
            ",?\\s*[0-9]{4}(?:[–-][0-9]{2,4})?\\s*$"
        ]
        for pattern in removals {
            t = t.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " ,.;:"))
        let low = t.lowercased()
        if t.count < 3 || low.hasPrefix("message of the president")
            || low.contains("congress") || low.contains("session") {
            return ""
        }
        return t
    }

    /// Truncates a topic to `volumeTopicMaxLength`, preferring a trailing word boundary, and
    /// appends an ellipsis. The volume tag keeps the full label distinct after truncation.
    private static func truncateTopic(_ s: String) -> String {
        guard s.count > volumeTopicMaxLength else { return s }
        var cut = String(s.prefix(volumeTopicMaxLength))
        if let space = cut.lastIndex(of: " "),
           cut.distance(from: cut.startIndex, to: space) >= volumeTopicMaxLength - 12 {
            cut = String(cut[..<space])
        }
        return cut.trimmingCharacters(in: CharacterSet(charactersIn: " ,;:")) + "…"
    }
}
