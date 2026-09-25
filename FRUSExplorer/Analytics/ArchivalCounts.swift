// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ArchivalCounts

/// Count phrases the Archival Analytics screen and its export both print (#1374).
///
/// The sentences that carry a count live here rather than on `ArchivalAnalyticsView`, because a
/// view's statics are main-actor isolated and a `private func` on it has no caller a test can
/// reach: the ranking caption and the umbrella caveat were each left printing an ungrouped number
/// once while their neighbours were fixed, and nothing could see it.
///
/// Version history:
///   1.0 — 2026-09-25: #1374
///   1.1 — 2026-09-25: #1374 review, round 1 — the ranking caption, its VoiceOver value, the
///         umbrella caveat on screen and the gloss's "and N others", moved here from the views
enum ArchivalCounts {

    /// "1 source note" / "59,973 source notes" — an era's denominator.
    ///
    /// It went through a `%lld`, so every band printed ungrouped: #1374 measured 150,764 / 59,973 /
    /// 22,737 / 18,381 / 12,697 notes across the five.
    ///
    /// - Parameter count: How many source notes.
    /// - Returns: The phrase.
    static func sourceNotes(_ count: Int) -> String {
        CountCopy.phrase(count,
                         one: String(localized: "archival.count.sourceNotes.one",
                                     defaultValue: "%@ source note"),
                         many: String(localized: "archival.count.sourceNotes.many",
                                      defaultValue: "%@ source notes"))
    }

    /// "1 collection" / "5,893 classes" — how many units an era's ranking reaches, in the unit
    /// lens's own noun.
    ///
    /// - Parameters:
    ///   - count: How many units carry a non-zero value in the band, before the row cap.
    ///   - lens: Named collections or central-file classes.
    /// - Returns: The phrase.
    static func units(_ count: Int, lens: ArchivalUnitLens) -> String {
        switch lens {
        case .namedCollections:
            return CountCopy.phrase(count,
                                    one: String(localized: "archival.ranking.caption.units.collections.one",
                                                defaultValue: "%@ collection"),
                                    many: String(localized: "archival.ranking.caption.units.collections.many",
                                                 defaultValue: "%@ collections"))
        case .centralFileClasses:
            return CountCopy.phrase(count,
                                    one: String(localized: "archival.ranking.caption.units.classes.one",
                                                defaultValue: "%@ class"),
                                    many: String(localized: "archival.ranking.caption.units.classes.many",
                                                 defaultValue: "%@ classes"))
        }
    }

    /// The ranking card's caption: which volumes the era holds and how many units they reach.
    ///
    /// It set both counts in `%lld`s and the units' noun in a separate `%@`, so the classes lens
    /// read "draw on 5893 classes" three bands out of five — directly above the denominator this
    /// lane had already grouped — and a lens reaching one unit read "1 collections".
    ///
    /// **"Draw on" is false above a pointers chart.** The other two weights rank where documents
    /// came from; the pointers weight ranks what footnotes pointed at and FRUS did not print, so the
    /// sentence branches rather than being reused with a different number in it.
    ///
    /// - Parameters:
    ///   - bandTitle: The era band's title — "1948–1960".
    ///   - bandVolumeCount: Volumes whose coverage falls in the band.
    ///   - unitsReached: Units with a non-zero value in the band, before the row cap.
    ///   - lens: Named collections or central-file classes.
    ///   - measuresPrintedMaterial: `false` for the unprinted-pointers weight.
    /// - Returns: The caption.
    static func rankingCaption(bandTitle: String, bandVolumeCount: Int, unitsReached: Int,
                               lens: ArchivalUnitLens, measuresPrintedMaterial: Bool) -> String {
        let units = units(unitsReached, lens: lens)
        guard measuresPrintedMaterial else {
            return String(format: String(
                localized: "archival.ranking.caption.pointers %@ %@ %@",
                defaultValue: "Footnotes in the volumes covering %1$@ — %2$@ of them — point at unprinted material in %3$@. Bars are colored by who holds the records."),
                bandTitle, bandVolumeCount.formatted(), units)
        }
        return String(format: String(
            localized: "archival.ranking.caption %@ %@ %@",
            defaultValue: "Volumes covering %1$@ — %2$@ of them — draw on %3$@. Bars are colored by who holds the records."),
            bandTitle, bandVolumeCount.formatted(), units)
    }

    /// A ranking bar's VoiceOver value: "12,067 documents, Presidential library".
    ///
    /// It read the value through a `%lld` before the weight's lower-cased title, which VoiceOver
    /// spoke as "12067 documents" and, at one, "1 volumes".
    ///
    /// - Parameters:
    ///   - value: The bar's value under the weight.
    ///   - weight: The Count-by weight.
    ///   - custodian: Who holds the records, as the legend names them.
    /// - Returns: The value.
    static func rankingAccessibilityValue(_ value: Int, weight: ArchivalWeight,
                                          custodian: String) -> String {
        String(format: String(localized: "archival.ranking.a11y %@ %@",
                              defaultValue: "%1$@, %2$@"),
               weight.countPhrase(value), custodian)
    }

    /// The umbrella caveat under the ranking: what the Central Files umbrella filter withheld in
    /// this era, in the Count-by weight's own words.
    ///
    /// It read "accounts for 12067 documents in the 1948–1960 volumes" (#1374), and the weight's
    /// title being plural, a count of one could not be said at all. The export's twin is
    /// `ArchivalAnalyticsExport.ranking`'s `archival.export.caveat.umbrella %@`.
    ///
    /// - Parameters:
    ///   - weight: The Count-by weight.
    ///   - hidden: The umbrella record's value in the band.
    ///   - bandTitle: The era band's title.
    /// - Returns: The caveat.
    static func umbrellaCaveat(weight: ArchivalWeight, hidden: Int, bandTitle: String) -> String {
        String(format: String(
            localized: "archival.caveats.umbrella %@ %@",
            defaultValue: "The Central Files umbrella record is hidden here. On its own it accounts for %1$@ in the %2$@ volumes, and its bar would flatten the scale. The era-specific Central Files records are still shown."),
            weight.countPhrase(hidden), bandTitle)
    }

    // MARK: Shared class codes (#1257)

    /// "and 1 other" / "and 21 others" — the link after a gloss whose class code names other
    /// places too.
    ///
    /// It read "and 1 others" for every code with exactly two claimants: 48, 44 and 39 codes in
    /// the three schedules' `countryAlternates`, each a row on Archives ▸ Classes and in the
    /// Archival ranking.
    ///
    /// - Parameter count: How many other places the code names.
    /// - Returns: The phrase.
    static func andOthers(_ count: Int) -> String {
        CountCopy.phrase(count,
                         one: String(localized: "archival.gloss.andOthers.one", defaultValue: "and %@ other"),
                         many: String(localized: "archival.gloss.andOthers.many", defaultValue: "and %@ others"))
    }

    /// The link's VoiceOver label: "11f also names 1 other place".
    ///
    /// - Parameters:
    ///   - key: The class key the gloss belongs to.
    ///   - count: How many other places the code names.
    /// - Returns: The label.
    static func andOthersAccessibilityLabel(key: String, count: Int) -> String {
        String(format: String(localized: "archival.gloss.andOthers.a11y %@ %@",
                              defaultValue: "%1$@ also names %2$@"),
               key,
               CountCopy.phrase(count,
                                one: String(localized: "archival.gloss.andOthers.a11y.places.one",
                                            defaultValue: "%@ other place"),
                                many: String(localized: "archival.gloss.andOthers.a11y.places.many",
                                             defaultValue: "%@ other places")))
    }

    /// A gloss as the ranking's CSV writes it: the name alone, or "Panama Canal Zone (and 1
    /// other)" when the code names other places too — a spreadsheet cannot pop over, so the COUNT
    /// travels instead of the list.
    ///
    /// - Parameters:
    ///   - gloss: The vended name.
    ///   - alternates: How many other places the code names.
    /// - Returns: The cell's reading.
    static func exportReading(gloss: String, alternates: Int) -> String {
        guard alternates > 0 else { return gloss }
        return String(format: String(localized: "archival.export.andOthers %@ %@",
                                     defaultValue: "%1$@ (%2$@)"),
                      gloss, andOthers(alternates))
    }
}

// MARK: - ArchivalWeight count phrases

extension ArchivalWeight {

    /// `count` of this weight as a phrase — "12,067 documents", "1 volume" — in the segment's own
    /// words, for the umbrella caveat on screen and in the export (#1374).
    ///
    /// Those sentences set a `%lld` beside the lower-cased segment title, which printed "accounts
    /// for 12067 documents in the 1948–1960 volumes"; and since the title is plural, a count of one
    /// could not be said at all.
    ///
    /// - Parameter count: How many.
    /// - Returns: The phrase, grouped and singular at one.
    func countPhrase(_ count: Int) -> String {
        switch self {
        case .documents:
            return CountCopy.documents(count)
        case .volumes:
            return CountCopy.volumes(count)
        case .unprintedPointers:
            return CountCopy.phrase(count,
                                    one: String(localized: "archival.weight.count.unprintedPointers.one",
                                                defaultValue: "%@ unprinted pointer"),
                                    many: String(localized: "archival.weight.count.unprintedPointers.many",
                                                 defaultValue: "%@ unprinted pointers"))
        }
    }
}
