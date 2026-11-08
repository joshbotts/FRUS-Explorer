// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - AnnotationLayer

/// One layer of a volume's editorial annotation, as the app shows it: a row of a volume page's
/// "Editors’ Annotations" and a category of the Browse axis of the same name
/// (`Planning/Editors-Annotations-Design-2026-11-06.md`, §5 and §6). Fifteen, in the page's order.
///
/// The one table both read, so that a volume's page and the axis cannot disagree on what a layer is
/// called, how it is drawn, or which volumes carry it. A layer is one of FRUSCoreKit's
/// `AnnotationCategory` counts, or several taken together: the two source-note forms, the three
/// kinds of reference, and the printed aids, which are sections, not counts.
///
/// Version history:
///   1.0 — 2026-11-06: the editors' annotations design, lane C
enum AnnotationLayer: String, CaseIterable, Identifiable, Sendable {
    /// Names linked to the volume's List of Persons.
    case people
    /// Abbreviations linked to the volume's List of Abbreviations.
    case abbreviations
    /// The sender or the recipient marked in a document's heading.
    case correspondents
    /// A memorandum's Subject line.
    case subjects
    /// A meeting's participants, listed.
    case participants
    /// Source notes, of either form.
    case sourceNotes
    /// Classification markings.
    case classification
    /// Text marked as not declassified.
    case excisions
    /// The posts' despatch numbers.
    case despatch
    /// Documents numbered in print.
    case numbered
    /// References to the volume's documents, to other volumes and to printed pages.
    case crossReferences
    /// Editorial notes.
    case editorialNotes
    /// Footnotes.
    case footnotes
    /// Marginal notes.
    case marginalNotes
    /// The front and back matter: a preface, the lists, an index.
    case printedAids

    /// The layer's stable name: a volume page's row ids and the axis's levels read it.
    var id: String { rawValue }

    /// The group the layer is shown in.
    var family: AnnotationCategory.Family {
        switch self {
        case .people, .abbreviations, .correspondents, .subjects, .participants:
            return .named
        case .sourceNotes, .classification, .excisions, .despatch:
            return .provenance
        case .numbered, .crossReferences, .editorialNotes, .footnotes, .marginalNotes, .printedAids:
            return .connects
        }
    }

    /// The SF Symbol drawn beside the layer: the design's §5.2 proposals, kept.
    var symbol: String {
        switch self {
        case .people: return "person.2"
        case .abbreviations: return "character.book.closed"
        case .correspondents: return "arrow.left.arrow.right"
        case .subjects: return "text.alignleft"
        case .participants: return "person.3"
        case .sourceNotes: return "archivebox"
        case .classification: return "lock"
        case .excisions: return "eye.slash"
        case .despatch: return "number.circle"
        case .numbered: return "number"
        case .crossReferences: return "arrow.triangle.branch"
        case .editorialNotes: return "text.bubble"
        case .footnotes: return "note.text"
        case .marginalNotes: return "text.append"
        case .printedAids: return "books.vertical"
        }
    }

    /// The layer's name: a volume page's row, and the axis's row and page title.
    var label: String {
        typealias Labels = VolumeAnnotationsPresentation.Labels
        switch self {
        case .people: return Labels.people
        case .abbreviations: return Labels.abbreviations
        case .correspondents: return Labels.correspondents
        case .subjects: return Labels.subjects
        case .participants: return Labels.participants
        case .sourceNotes: return Labels.sourceNotes
        case .classification: return Labels.classification
        case .excisions: return Labels.excisions
        case .despatch: return Labels.despatch
        case .numbered: return Labels.numbered
        case .crossReferences: return Labels.crossReferences
        case .editorialNotes: return Labels.editorialNotes
        case .footnotes: return Labels.footnotes
        case .marginalNotes: return Labels.marginalNotes
        case .printedAids: return Labels.printedAids
        }
    }

    /// The kit category whose count the layer is, or `nil` for a layer made of several (source
    /// notes, references) or of sections (printed aids).
    var category: AnnotationCategory? {
        switch self {
        case .people: return .people
        case .abbreviations: return .abbreviations
        case .correspondents: return .correspondents
        case .subjects: return .subjects
        case .participants: return .participants
        case .classification: return .classification
        case .excisions: return .excisions
        case .despatch: return .despatch
        case .numbered: return .numbered
        case .editorialNotes: return .editorialNotes
        case .footnotes: return .footnotes
        case .marginalNotes: return .marginalNotes
        case .sourceNotes, .crossReferences, .printedAids: return nil
        }
    }

    /// `true` when `annotations` carries the layer: a category by the kit's threshold; source notes
    /// when half the documents have one of either form; references when any of the three kinds is
    /// there; the printed aids when the volume prints one the page names.
    func isCarried(by annotations: VolumeAnnotations) -> Bool {
        switch self {
        case .sourceNotes:
            return annotations.carriesSourceNotes
        case .crossReferences:
            return annotations.carries(.xrefDocuments) || annotations.carries(.xrefVolumes)
                || annotations.carries(.xrefPages)
        case .printedAids:
            return !VolumeAnnotationsPresentation.printedAids(in: annotations.sections).isEmpty
        default:
            return category.map(annotations.carries) ?? false
        }
    }

    /// The count a drill's row shows for the layer, or `nil` where no one count says it.
    func count(in annotations: VolumeAnnotations) -> Int? {
        switch self {
        case .sourceNotes: return annotations.sourceNotes
        case .crossReferences, .printedAids: return nil
        default: return category.map(annotations.count)
        }
    }
}

// MARK: - What each layer's page says

extension AnnotationLayer {

    /// A screen of the app that reads the layer, which its page links to.
    enum AppLink: String, Sendable {
        /// The People browser.
        case people
        /// The Archives axis.
        case archives

        /// The link's title.
        var title: String {
            switch self {
            case .people:
                return String(localized: "browser.annotations.link.people", defaultValue: "Open People")
            case .archives:
                return String(localized: "browser.annotations.link.archives", defaultValue: "Open Archives")
            }
        }
    }

    /// The screen the layer's page links to, or `nil`.
    var appLink: AppLink? {
        switch self {
        case .people: return .people
        case .sourceNotes: return .archives
        default: return nil
        }
    }

    /// When a volume counts as carrying the layer: the rule its threshold states.
    var rule: String {
        switch self {
        case .people:
            return String(localized: "browser.annotations.rule.people",
                          defaultValue: "A volume counts when at least half its documents link a name to its List of Persons.")
        case .abbreviations:
            return String(localized: "browser.annotations.rule.abbreviations",
                          defaultValue: "A volume counts when at least half its documents link a term to its List of Abbreviations.")
        case .correspondents:
            return String(localized: "browser.annotations.rule.correspondents",
                          defaultValue: "A volume counts when at least half its documents mark a sender or a recipient in the heading.")
        case .subjects:
            return String(localized: "browser.annotations.rule.subjects",
                          defaultValue: "A volume counts when one of its documents prints a Subject line.")
        case .participants:
            return String(localized: "browser.annotations.rule.participants",
                          defaultValue: "A volume counts when one of its documents lists who attended a meeting.")
        case .sourceNotes:
            return String(localized: "browser.annotations.rule.sourceNotes",
                          defaultValue: "A volume counts when at least half its documents carry a source note, of either form.")
        case .classification:
            return String(localized: "browser.annotations.rule.classification",
                          defaultValue: "A volume counts when at least half its documents carry a classification marking, as the app reads them.")
        case .excisions:
            return String(localized: "browser.annotations.rule.excisions",
                          defaultValue: "A volume counts when one of its documents marks a redaction as not declassified: text in it, or the whole document.")
        case .despatch:
            return String(localized: "browser.annotations.rule.despatch",
                          defaultValue: "A volume counts when at least a tenth of its documents carry a despatch number.")
        case .numbered:
            return String(localized: "browser.annotations.rule.numbered",
                          defaultValue: "A volume counts when at least half its documents print a document number.")
        case .crossReferences:
            return String(localized: "browser.annotations.rule.crossReferences",
                          defaultValue: "A volume counts when one of its documents cites another of its documents, another volume or a printed page.")
        case .editorialNotes:
            return String(localized: "browser.annotations.rule.editorialNotes",
                          defaultValue: "A volume counts when it prints an editorial note.")
        case .footnotes:
            return String(localized: "browser.annotations.rule.footnotes",
                          defaultValue: "A volume counts when at least half its documents carry a footnote.")
        case .marginalNotes:
            return String(localized: "browser.annotations.rule.marginalNotes",
                          defaultValue: "A volume counts when one of its documents prints a marginal note.")
        case .printedAids:
            return String(localized: "browser.annotations.rule.printedAids",
                          defaultValue: "A volume counts when it prints one of the sections listed below.")
        }
    }

    /// What the editors did: the practice, in a paragraph the owner edits.
    var practice: String {
        switch self {
        case .people:
            return String(localized: "browser.annotations.practice.people",
                          defaultValue: "The editors linked each person a document names to the volume's List of Persons, where the person is identified.")
        case .abbreviations:
            return String(localized: "browser.annotations.practice.abbreviations",
                          defaultValue: "The editors linked each abbreviation in a document to the volume's List of Abbreviations, where it is spelled out.")
        case .correspondents:
            return String(localized: "browser.annotations.practice.correspondents",
                          defaultValue: "The editors marked who sent each document, and to whom, in its heading.")
        case .subjects:
            return String(localized: "browser.annotations.practice.subjects",
                          defaultValue: "Where a memorandum carried a Subject line, the editors printed it with the memorandum.")
        case .participants:
            return String(localized: "browser.annotations.practice.participants",
                          defaultValue: "Where a memorandum of conversation lists who took part, the editors marked the list.")
        case .sourceNotes:
            return String(localized: "browser.annotations.practice.sourceNotes",
                          defaultValue: "A source note says where the editors found a document. It was printed first as a file number above the heading, and later as a note that begins “Source:” with the full archival citation. The earliest volumes print none: a despatch there carries the post's own number instead.")
        case .classification:
            return String(localized: "browser.annotations.practice.classification",
                          defaultValue: "The editors printed each document's security classification, first above the dateline and later in the source note.")
        case .excisions:
            return String(localized: "browser.annotations.practice.excisions",
                          defaultValue: "The editors mark what declassification review redacted: a gap in the printed text, “[… not declassified]”, or a whole document withheld, listed in its place with its heading, its source note and the number of pages not declassified. Before the 1991 statute, volumes marked every omission with an ellipsis, whether the editors left the text out or it was not cleared for publication, so their redactions cannot be told from the editors’ omissions and are not counted here.")
        case .despatch:
            return String(localized: "browser.annotations.practice.despatch",
                          defaultValue: "Older volumes print the number a diplomatic post gave each despatch it sent, “No. 74.”, by which the despatch is found in the archives.")
        case .numbered:
            return String(localized: "browser.annotations.practice.numbered",
                          defaultValue: "The editors numbered the documents in print, so that each heading opens with its number: “12. Telegram From …”.")
        case .crossReferences:
            return String(localized: "browser.annotations.practice.crossReferences",
                          defaultValue: "The editors' notes point to other documents in the volume, to other volumes and to printed pages: “See Document 12”, “see p. 123”.")
        case .editorialNotes:
            return String(localized: "browser.annotations.practice.editorialNotes",
                          defaultValue: "Where no single document tells the story, the editors wrote a note of their own, set between the documents.")
        case .footnotes:
            return String(localized: "browser.annotations.practice.footnotes",
                          defaultValue: "The editors' footnotes explain a document: who it names, what it answered, what became of it.")
        case .marginalNotes:
            return String(localized: "browser.annotations.practice.marginalNotes",
                          defaultValue: "A few volumes print the notes written in a document's margin, set off from its text.")
        case .printedAids:
            return String(localized: "browser.annotations.practice.printedAids",
                          defaultValue: "Besides its documents, a volume prints front and back matter to help readers use it: a preface, lists of sources, abbreviations and persons, an index.")
        }
    }

    /// What the app does with the layer. A layer nothing in the app reads says so plainly.
    var appUse: String {
        switch self {
        case .people:
            return String(localized: "browser.annotations.app.people",
                          defaultValue: "The People browser and Person analytics read these links. Where a volume does not link its names, search for them instead.")
        case .abbreviations:
            return String(localized: "browser.annotations.app.abbreviations",
                          defaultValue: "The reader opens a linked abbreviation's meaning.")
        case .sourceNotes:
            return String(localized: "browser.annotations.app.sourceNotes",
                          defaultValue: "Source Explorer and the Archives axis read them, and a chapter's list of documents shows the first line of each note.")
        case .classification:
            return String(localized: "browser.annotations.app.classification",
                          defaultValue: "Search's results and Source Explorer show a document's marking.")
        case .despatch:
            return String(localized: "browser.annotations.app.despatch",
                          defaultValue: "Source Explorer shows a document's despatch number with its archival series.")
        case .numbered:
            return String(localized: "browser.annotations.app.numbered",
                          defaultValue: "Document titles and citations give the number the volume prints.")
        case .crossReferences:
            return String(localized: "browser.annotations.app.crossReferences",
                          defaultValue: "The reader follows each one, and the Cross-Reference graph and Cross-Volume Connections draw them.")
        case .editorialNotes:
            return String(localized: "browser.annotations.app.editorialNotes",
                          defaultValue: "Search can limit its results to editorial notes.")
        case .footnotes:
            return String(localized: "browser.annotations.app.footnotes",
                          defaultValue: "The reader shows each footnote with its document.")
        case .printedAids:
            return String(localized: "browser.annotations.app.printedAids",
                          defaultValue: "A volume's page lists them under Front Matter and Back Matter, and the reader opens each one.")
        case .correspondents, .subjects, .participants, .excisions, .marginalNotes:
            return String(localized: "browser.annotations.app.none",
                          defaultValue: "The reader shows these as printed. Nothing else in the app reads them yet.")
        }
    }
}

// MARK: - AnnotationsAxis

/// The Editors’ Annotations browse axis's pure logic (`Planning/Editors-Annotations-Design-2026-11-06.md`,
/// §6; #1051's axis pattern): each layer's reach across the corpus and its eras, the sentence that
/// says when it became standard, and the R-1 drill specs, split from the views for testability.
///
/// Every figure comes from the bundled `volume-annotations-index.json`; no count or year is written
/// into the copy. A drill's volumes are in volume-id order, which runs by the years each covers, so a
/// list shows a practice arriving; only the volume whose page opened the layer's comes first.
///
/// Version history:
///   1.0 — 2026-11-06: the editors' annotations design, lane C
enum AnnotationsAxis {

    /// One era's share of a layer: how many of its volumes carry it.
    struct Band: Identifiable, Equatable, Sendable {
        /// The era.
        let era: AnnotationEra
        /// Its volumes that carry the layer.
        let carrying: Int
        /// Its volumes.
        let total: Int

        /// The era, as the band's identity.
        var id: AnnotationEra { era }

        /// The share of the era's volumes that carry the layer, 0 to 1.
        var share: Double { total == 0 ? 0 : Double(carrying) / Double(total) }
    }

    /// A layer's reach across the corpus.
    struct Reach: Equatable, Sendable {
        /// The layer.
        let layer: AnnotationLayer
        /// The volumes that carry it, in drill order.
        let carrying: [String]
        /// The volumes the file holds.
        let total: Int
        /// The eras, earliest first, with the late retrospectives last.
        let bands: [Band]
        /// The first era from which the series made it standard, or `nil`.
        let onset: AnnotationEra?
    }

    /// One way into a layer's volumes from its page: with it, without it, by form or by aid.
    struct Drill: Identifiable {
        /// The drill's stable id, also the tail of its row's accessibility identifier.
        let id: String
        /// The row's title.
        let title: String
        /// How many volumes the drill lists.
        let count: Int
        /// The list it opens.
        let spec: VolumeListSpec
    }

    /// The eras in strip order: earliest first, the late retrospectives last.
    static var stripEras: [AnnotationEra] { AnnotationEra.chronological + [.retrospective] }

    /// A layer's reach in `index`.
    static func reach(of layer: AnnotationLayer, in index: VolumeAnnotationsIndex) -> Reach {
        var carrying: [String] = []
        var perEra: [AnnotationEra: (carrying: Int, total: Int)] = [:]
        for (volumeId, annotations) in index.volumes {
            let carries = layer.isCarried(by: annotations)
            if carries { carrying.append(volumeId) }
            var tally = perEra[annotations.era] ?? (0, 0)
            tally.total += 1
            if carries { tally.carrying += 1 }
            perEra[annotations.era] = tally
        }
        let bands = stripEras.map { era in
            Band(era: era, carrying: perEra[era]?.carrying ?? 0, total: perEra[era]?.total ?? 0)
        }
        return Reach(layer: layer, carrying: order(carrying), total: index.volumes.count, bands: bands,
                     onset: index.onset(where: layer.isCarried(by:)))
    }

    /// Volume ids in drill order: by id, numbers compared as numbers, which runs by the years each
    /// volume covers ("frus1969-76v2" before "frus1969-76v17").
    static func order(_ volumeIds: [String]) -> [String] {
        volumeIds.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    // MARK: Copy

    /// "288 of 553 volumes".
    static func volumesLine(_ count: Int, of total: Int, locale: Locale = .autoupdatingCurrent) -> String {
        CountCopy.phrase(total,
                         one: String(localized: "browser.annotations.ofVolumes.one",
                                     defaultValue: "%2$@ of %1$@ volume"),
                         many: String(localized: "browser.annotations.ofVolumes.many",
                                      defaultValue: "%2$@ of %1$@ volumes"),
                         then: [count.formatted(.number.locale(locale))], locale: locale)
    }

    /// An era's name in a sentence: "1955–1968", "1981 on", or the late retrospectives'. Each year
    /// goes in through `String(_:)`: a year is not a count.
    static func eraName(_ era: AnnotationEra) -> String {
        guard let first = era.firstYear else {
            return String(localized: "browser.annotations.era.retrospective", defaultValue: "the late retrospectives")
        }
        let parts = era.rawValue.split(separator: "-", omittingEmptySubsequences: false)
        if parts.count == 2, let last = Int(parts[1]) {
            return String(format: String(localized: "browser.annotations.era.span", defaultValue: "%1$@–%2$@"),
                          String(first), String(last))
        }
        return String(format: String(localized: "browser.annotations.era.from", defaultValue: "%@ on"),
                      String(first))
    }

    /// An era's label under its cell in the full strip: its first year, or the retrospectives' short name.
    static func shortEraName(_ era: AnnotationEra) -> String {
        guard let first = era.firstYear else {
            return String(localized: "browser.annotations.era.retrospective.short", defaultValue: "Retro.")
        }
        return String(first)
    }

    /// When the layer became standard: "Standard in the volumes covering 1955 on.", or, for a practice
    /// no era made standard, the era where it is most common. Empty when no volume carries it.
    ///
    /// Redactions say instead when the series began to mark them. That follows the year a volume was
    /// published, not the years it covers, so the era strip's onset would put it in the wrong place.
    static func standardLine(for reach: Reach) -> String {
        if reach.layer == .excisions { return redactionsStandardLine }
        if reach.onset != nil { return VolumeAnnotationsPresentation.standardFrom(reach.onset) }
        // Ties go to the earlier band: the strip's order.
        guard let peak = reach.bands.filter({ $0.carrying > 0 }).max(by: { $0.share < $1.share }) else {
            return ""
        }
        if peak.era == .retrospective {
            return String(localized: "browser.annotations.standard.none.retrospective",
                          defaultValue: "No era made it standard. It is most common in the late retrospective volumes.")
        }
        return String(format: String(localized: "browser.annotations.standard.none",
                                     defaultValue: "No era made it standard. It is most common in the volumes covering %@."),
                      eraName(peak.era))
    }

    /// The Redactions layer's sentence in place of an era's: the practice began with the 1991
    /// statute, which dates a volume's publication, not the years it covers.
    static var redactionsStandardLine: String {
        String(localized: "browser.annotations.standard.redactions",
               defaultValue: "Volumes produced after the passage of the 1991 statute include explicit editorial annotation of redactions made during the declassification process.")
    }

    /// What VoiceOver reads for a layer's row on the axis: "People tagged: 288 of 553 volumes.
    /// Standard in the volumes covering 1955 on."
    static func spokenRow(for reach: Reach, locale: Locale = .autoupdatingCurrent) -> String {
        let lead = String(format: String(localized: "browser.annotations.row.spoken", defaultValue: "%1$@: %2$@."),
                          reach.layer.label, volumesLine(reach.carrying.count, of: reach.total, locale: locale))
        let standard = standardLine(for: reach)
        return standard.isEmpty ? lead : lead + " " + standard
    }

    /// What VoiceOver reads for one cell of the full strip: "1955–1968: 58 of 60 volumes".
    static func spokenBand(_ band: Band, locale: Locale = .autoupdatingCurrent) -> String {
        let name = band.era == .retrospective
            ? String(localized: "browser.annotations.era.retrospective.title", defaultValue: "Late retrospectives")
            : eraName(band.era)
        return String(format: String(localized: "browser.annotations.band.spoken", defaultValue: "%1$@: %2$@"),
                      name, volumesLine(band.carrying, of: band.total, locale: locale))
    }

    /// The axis's honesty caption: what a row counts, and what a strip shades.
    static func indexCaption(total: Int, locale: Locale = .autoupdatingCurrent) -> String {
        String(format: String(localized: "browser.annotations.index.caption",
                              defaultValue: "What the editors of %@ annotated, layer by layer. A layer that runs through a volume, such as people tagged, counts when it reaches at least half the volume's documents; one found here and there, such as an editorial note, when one document carries it. Each strip shades the eras, earliest first and the late retrospectives last, by the share of their volumes that carry the layer."),
               CountCopy.volumes(total, locale: locale))
    }

    /// The group headings, as a volume's page names them.
    static func familyTitle(_ family: AnnotationCategory.Family) -> String {
        switch family {
        case .named: return VolumeAnnotationsPresentation.Labels.named
        case .provenance: return VolumeAnnotationsPresentation.Labels.provenance
        case .connects: return VolumeAnnotationsPresentation.Labels.connects
        }
    }

    // MARK: Drills

    /// A layer's drills: the volumes with it and without it, and for source notes one per form; the
    /// printed aids have one per aid instead, since nearly every volume prints one.
    ///
    /// - Parameters:
    ///   - layer: The layer.
    ///   - index: The bundled file.
    ///   - fromVolumeId: The volume whose page opened the layer's, marked in each list it is in.
    ///   - locale: The locale that groups the counts.
    static func drills(for layer: AnnotationLayer, in index: VolumeAnnotationsIndex, from fromVolumeId: String? = nil,
                       locale: Locale = .autoupdatingCurrent) -> [Drill] {
        if layer == .printedAids { return aidDrills(in: index, from: fromVolumeId, locale: locale) }
        let reach = reach(of: layer, in: index)
        let with = Set(reach.carrying)
        let without = order(index.volumes.keys.filter { !with.contains($0) })
        var drills = [
            Drill(id: "with",
                  title: String(localized: "browser.annotations.drill.with", defaultValue: "Volumes with it"),
                  count: reach.carrying.count,
                  spec: spec(axisKey: "annotation:\(layer.rawValue):with",
                             title: String(format: String(localized: "browser.annotations.drill.with.title",
                                                          defaultValue: "With: %@"), layer.label),
                             volumeIds: reach.carrying, rule: layer.rule, layer: layer, index: index,
                             from: fromVolumeId, locale: locale)),
            Drill(id: "without",
                  title: String(localized: "browser.annotations.drill.without", defaultValue: "Volumes without it"),
                  count: without.count,
                  spec: spec(axisKey: "annotation:\(layer.rawValue):without",
                             title: String(format: String(localized: "browser.annotations.drill.without.title",
                                                          defaultValue: "Without: %@"), layer.label),
                             volumeIds: without, rule: layer.rule, layer: layer, index: index,
                             from: fromVolumeId, locale: locale)),
        ]
        if layer == .sourceNotes {
            let forms: [(id: String, category: AnnotationCategory, title: String)] = [
                ("citation", .sourceCitation,
                 String(localized: "browser.annotations.drill.sourceCitation",
                        defaultValue: "Archival citations (“Source: …”)")),
                ("fileNumber", .sourceFileNumber,
                 String(localized: "browser.annotations.drill.sourceFileNumber",
                        defaultValue: "File numbers above the heading")),
            ]
            for form in forms {
                let ids = order(index.volumeIds { $0.carries(form.category) })
                let rule = String(localized: "browser.annotations.rule.sourceForm",
                                  defaultValue: "A volume counts when at least half its documents carry a source note of this form.")
                drills.append(Drill(id: form.id, title: form.title, count: ids.count,
                                    spec: spec(axisKey: "annotation:sourceNotes:\(form.id)", title: form.title,
                                               volumeIds: ids, rule: rule, layer: layer, index: index,
                                               from: fromVolumeId, locale: locale,
                                               accessoryCategory: form.category)))
            }
        }
        return drills
    }

    /// The drill of one cell of the regular-width matrix: the era's volumes that carry the layer, the
    /// era named in its title and caption ("1955–1968: 114 of 114 volumes." and the rule).
    ///
    /// - Parameters:
    ///   - layer: The layer, the cell's row.
    ///   - era: The era, the cell's column.
    ///   - index: The bundled file.
    ///   - locale: The locale that groups the counts.
    static func eraDrill(for layer: AnnotationLayer, era: AnnotationEra, in index: VolumeAnnotationsIndex,
                         locale: Locale = .autoupdatingCurrent) -> Drill {
        let members = index.volumes.filter { $0.value.era == era }
        let ids = order(members.filter { layer.isCarried(by: $0.value) }.map(\.key))
        let band = Band(era: era, carrying: ids.count, total: members.count)
        let title = String(format: String(localized: "browser.annotations.era.drill.title", defaultValue: "%1$@, %2$@"),
                           layer.label, eraName(era))
        let caption = String(format: String(localized: "browser.annotations.drill.caption", defaultValue: "%1$@. %2$@"),
                             spokenBand(band, locale: locale), layer.rule)
        return Drill(id: "era.\(era.rawValue)", title: title, count: ids.count,
                     spec: spec(axisKey: "annotation:\(layer.rawValue):era:\(era.rawValue)", title: title,
                                volumeIds: ids, rule: layer.rule, layer: layer, index: index, from: nil,
                                locale: locale, caption: caption))
    }

    /// What VoiceOver reads for a cell of the matrix, and its help: "People tagged, 1955–1968: 114 of
    /// 114 volumes".
    static func spokenCell(_ layer: AnnotationLayer, _ band: Band, locale: Locale = .autoupdatingCurrent) -> String {
        String(format: String(localized: "browser.annotations.cell.spoken", defaultValue: "%1$@, %2$@"),
               layer.label, spokenBand(band, locale: locale))
    }

    /// One drill per printed aid any volume prints, in the order a volume's page names them; the
    /// section kinds that share a name ("intro" and "introduction") are one aid.
    private static func aidDrills(in index: VolumeAnnotationsIndex, from fromVolumeId: String?,
                                  locale: Locale) -> [Drill] {
        var kindsByName: [(name: String, kinds: [String])] = []
        for (kind, name) in VolumeAnnotationsPresentation.printedAidNames {
            if let at = kindsByName.firstIndex(where: { $0.name == name }) {
                kindsByName[at].kinds.append(kind)
            } else {
                kindsByName.append((name, [kind]))
            }
        }
        let rule = String(localized: "browser.annotations.rule.aid", defaultValue: "A volume counts when it prints this section.")
        return kindsByName.compactMap { aid in
            let ids = order(index.volumeIds { annotations in aid.kinds.contains { annotations.prints(section: $0) } })
            guard !ids.isEmpty, let first = aid.kinds.first else { return nil }
            return Drill(id: first, title: aid.name, count: ids.count,
                         spec: spec(axisKey: "annotation:printedAids:\(first)", title: aid.name, volumeIds: ids,
                                    rule: rule, layer: .printedAids, index: index, from: fromVolumeId,
                                    locale: locale))
        }
    }

    /// A drill's R-1 spec: its volumes, the caption ("288 of 553 volumes." and the rule), each
    /// volume's count where the layer has one, and the notes.
    ///
    /// The volume whose page opened the layer's comes first, with its note, and the rest keep their
    /// order: in the 288 volumes that tag people, `frus1961-63v06` would otherwise be the 126th row,
    /// a mark no one scrolls to.
    private static func spec(axisKey: String, title: String, volumeIds: [String], rule: String,
                             layer: AnnotationLayer, index: VolumeAnnotationsIndex, from fromVolumeId: String?,
                             locale: Locale, accessoryCategory: AnnotationCategory? = nil,
                             caption: String? = nil) -> VolumeListSpec {
        var volumeIds = volumeIds
        if let fromVolumeId, let at = volumeIds.firstIndex(of: fromVolumeId) {
            volumeIds.insert(volumeIds.remove(at: at), at: 0)
        }
        var accessories: [String: String] = [:]
        var notes: [String: String] = [:]
        for volumeId in volumeIds {
            guard let annotations = index[volumeId] else { continue }
            if let accessory = accessory(for: layer, annotations, category: accessoryCategory, locale: locale) {
                accessories[volumeId] = accessory
            }
            var lines: [String] = []
            if let unlinked = unlinkedList(for: layer, annotations) { lines.append(unlinked) }
            if volumeId == fromVolumeId {
                lines.append(String(localized: "browser.annotations.note.from",
                                    defaultValue: "You came here from this volume."))
            }
            if !lines.isEmpty { notes[volumeId] = lines.joined(separator: " ") }
        }
        let stated = caption ?? String(
            format: String(localized: "browser.annotations.drill.caption", defaultValue: "%1$@. %2$@"),
            volumesLine(volumeIds.count, of: index.volumes.count, locale: locale), rule)
        return VolumeListSpec(axisKey: axisKey, title: title, volumeIds: volumeIds, caption: stated,
                              accessories: accessories, notes: notes)
    }

    /// A volume's count in a drill: "279/280" for a layer that runs through a volume, "37 docs" for
    /// one found here and there, "12 notes" for editorial notes; `nil` at zero, and for references and
    /// the printed aids, which no one count says.
    static func accessory(for layer: AnnotationLayer, _ annotations: VolumeAnnotations,
                          category: AnnotationCategory? = nil, locale: Locale = .autoupdatingCurrent) -> String? {
        let count = category.map(annotations.count) ?? layer.count(in: annotations)
        guard let count, count > 0 else { return nil }
        switch layer {
        case .people, .abbreviations, .correspondents, .sourceNotes, .classification, .despatch, .numbered,
             .footnotes:
            return count.formatted(.number.locale(locale)) + "/" + annotations.documents.formatted(.number.locale(locale))
        case .editorialNotes:
            return CountCopy.phrase(count,
                                    one: String(localized: "browser.annotations.accessory.notes.one", defaultValue: "%@ note"),
                                    many: String(localized: "browser.annotations.accessory.notes.many", defaultValue: "%@ notes"),
                                    locale: locale)
        case .subjects, .participants, .excisions, .marginalNotes:
            return CountCopy.docs(count, locale: locale)
        case .crossReferences, .printedAids:
            return nil
        }
    }

    /// The amber line for a volume that prints the list a layer links to and links none of its
    /// documents to it (`frus1977-80v27`'s List of Persons); `nil` otherwise.
    static func unlinkedList(for layer: AnnotationLayer, _ annotations: VolumeAnnotations) -> String? {
        switch layer {
        case .people where annotations.count(.people) == 0 && annotations.personsListed > 0:
            return String(localized: "browser.annotations.note.people.unlinked",
                          defaultValue: "Prints a List of Persons, but none of its documents links a name to it.")
        case .abbreviations where annotations.count(.abbreviations) == 0 && annotations.termsListed > 0:
            return String(localized: "browser.annotations.note.abbreviations.unlinked",
                          defaultValue: "Prints a List of Abbreviations, but none of its documents links a term to it.")
        default:
            return nil
        }
    }
}
