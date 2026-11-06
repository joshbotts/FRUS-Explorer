// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - VolumeAnnotationsPresentation

/// What a volume page's "Editors’ Annotations" section says: the layers of editorial annotation the
/// volume carries, in three groups, and the standard ones it lacks, each with the era from which the
/// series made it standard (`Planning/Editors-Annotations-Design-2026-11-06.md`, §5).
///
/// Built from the bundled `volume-annotations-index.json` (``VolumeAnnotationsStore``), so a page
/// says the same before and after its volume is downloaded. A layer is in the volume or not, by
/// FRUSCoreKit's `VolumeAnnotations.carries(_:)`; there is no partial state, and the counts carry the
/// coverage (§5.2). Every count goes through `CountCopy`, and no count or year is written into the
/// copy: each comes from the file.
///
/// Version history:
///   1.0 — 2026-11-06: the editors' annotations design, lane B
struct VolumeAnnotationsPresentation: Equatable {

    /// One layer the volume carries.
    struct Row: Identifiable, Equatable {
        /// The layer's stable id, also the tail of the row's accessibility identifier.
        let id: String
        /// The row's SF Symbol.
        let symbol: String
        /// The layer's name.
        let label: String
        /// Its counts, in one line, the parts joined by ``VolumeAnnotationsPresentation/separator``.
        let detail: String

        /// What VoiceOver reads: the name and the counts as one sentence, the parts joined by
        /// semicolons ("People tagged: 279 of 280 documents; 325 people listed.").
        var accessibilityLabel: String {
            String(format: String(localized: "browser.volume.annotations.row.spoken",
                                  defaultValue: "%1$@: %2$@."),
                   label, detail.replacingOccurrences(of: VolumeAnnotationsPresentation.separator, with: "; "))
        }
    }

    /// One of the three groups: who is named, where it came from, how it connects.
    struct Group: Identifiable, Equatable {
        /// The group's family.
        let id: AnnotationCategory.Family
        /// Its heading.
        let title: String
        /// Its rows, in the order the page shows them.
        let rows: [Row]
    }

    /// A layer the series made standard that this volume lacks.
    struct AbsentRow: Identifiable, Equatable {
        /// The layer's stable id.
        let id: String
        /// The layer's name.
        let label: String
        /// From which era the series made it standard, with, for people, where to look instead.
        /// Empty when the layer has no onset.
        let note: String

        /// What VoiceOver reads ("Not in this volume: People tagged. Standard in the volumes covering
        /// 1955 on. Search the names instead.").
        var accessibilityLabel: String {
            let lead = String(format: String(localized: "browser.volume.annotations.absent.spoken",
                                             defaultValue: "Not in this volume: %@."), label)
            return note.isEmpty ? lead : lead + " " + note
        }
    }

    /// The groups that hold a row, in order.
    let groups: [Group]
    /// The standard layers the volume lacks, in order.
    let absent: [AbsentRow]

    /// What joins the parts of a row's counts.
    static let separator = " · "

    /// The section's heading.
    static var title: String {
        String(localized: "browser.volume.annotations.header", defaultValue: "Editors’ Annotations")
    }

    /// The disclosure's title, with how many standard layers the volume lacks.
    var absentTitle: String {
        String(format: String(localized: "browser.volume.annotations.absent.header",
                              defaultValue: "Not in this volume (%@)"),
               absent.count.formatted())
    }

    /// `true` when the bundled file holds `volumeId`, so its page shows the section.
    static func hasContent(forVolumeId volumeId: String) -> Bool {
        VolumeAnnotationsStore.shared?[volumeId] != nil
    }

    /// The section for `volumeId`, or `nil` when the file does not hold it.
    init?(volumeId: String, index: VolumeAnnotationsIndex? = VolumeAnnotationsStore.shared,
          locale: Locale = .autoupdatingCurrent) {
        guard let index, let annotations = index[volumeId] else { return nil }
        self.init(annotations: annotations, index: index, locale: locale)
    }

    /// The section for one volume's `annotations`, its absent layers' onsets read from `index`.
    init(annotations: VolumeAnnotations, index: VolumeAnnotationsIndex, locale: Locale = .autoupdatingCurrent) {
        let copy = Copy(annotations: annotations, locale: locale)
        var named: [Row] = []
        var provenance: [Row] = []
        var connects: [Row] = []

        if annotations.carries(.people) {
            named.append(Row(id: "people", symbol: "person.2", label: Labels.people,
                             detail: copy.coverage(.people, listed: copy.personsListed)))
        }
        if annotations.carries(.abbreviations) {
            named.append(Row(id: "abbreviations", symbol: "character.book.closed", label: Labels.abbreviations,
                             detail: copy.coverage(.abbreviations, listed: copy.termsListed)))
        }
        if annotations.carries(.correspondents) {
            named.append(Row(id: "correspondents", symbol: "arrow.left.arrow.right",
                             label: Labels.correspondents, detail: copy.documents(.correspondents)))
        }
        if annotations.carries(.subjects) {
            named.append(Row(id: "subjects", symbol: "text.alignleft", label: Labels.subjects,
                             detail: copy.documents(.subjects)))
        }
        if annotations.carries(.participants) {
            named.append(Row(id: "participants", symbol: "person.3", label: Labels.participants,
                             detail: copy.documents(.participants)))
        }

        if annotations.carriesSourceNotes {
            provenance.append(Row(id: "sourceNotes", symbol: "archivebox", label: Labels.sourceNotes,
                                  detail: copy.sourceNotes))
        }
        if annotations.carries(.classification) {
            provenance.append(Row(id: "classification", symbol: "lock", label: Labels.classification,
                                  detail: copy.coverage(.classification)))
        }
        if annotations.carries(.excisions) {
            provenance.append(Row(id: "excisions", symbol: "eye.slash", label: Labels.excisions,
                                  detail: copy.excisions))
        }
        if annotations.carries(.despatch) {
            provenance.append(Row(id: "despatch", symbol: "number.circle", label: Labels.despatch,
                                  detail: copy.documents(.despatch)))
        }

        if annotations.carries(.numbered) {
            connects.append(Row(id: "numbered", symbol: "number", label: Labels.numbered,
                                detail: copy.coverage(.numbered)))
        }
        if let references = copy.crossReferences {
            connects.append(Row(id: "crossReferences", symbol: "arrow.triangle.branch",
                                label: Labels.crossReferences, detail: references))
        }
        if annotations.carries(.editorialNotes) {
            connects.append(Row(id: "editorialNotes", symbol: "text.bubble", label: Labels.editorialNotes,
                                detail: copy.editorialNotes))
        }
        if annotations.carries(.footnotes) {
            connects.append(Row(id: "footnotes", symbol: "note.text", label: Labels.footnotes,
                                detail: copy.coverage(.footnotes)))
        }
        if annotations.carries(.marginalNotes) {
            connects.append(Row(id: "marginalNotes", symbol: "text.append", label: Labels.marginalNotes,
                                detail: copy.documents(.marginalNotes)))
        }
        let aids = Self.printedAids(in: annotations.sections)
        if !aids.isEmpty {
            connects.append(Row(id: "printedAids", symbol: "books.vertical", label: Labels.printedAids,
                                detail: aids.joined(separator: Self.separator)))
        }

        groups = [
            Group(id: .named, title: Labels.named, rows: named),
            Group(id: .provenance, title: Labels.provenance, rows: provenance),
            Group(id: .connects, title: Labels.connects, rows: connects),
        ].filter { !$0.rows.isEmpty }

        // The standard layers, in the order the groups show them (§5.2); an era-bound practice is
        // never listed as missing.
        let standard: [(id: String, label: String, carried: Bool, onset: () -> AnnotationEra?)] = [
            ("people", Labels.people, annotations.carries(.people), { index.onset(of: .people) }),
            ("abbreviations", Labels.abbreviations, annotations.carries(.abbreviations),
             { index.onset(of: .abbreviations) }),
            ("sourceNotes", Labels.sourceNotes, annotations.carriesSourceNotes,
             { index.onset(where: \.carriesSourceNotes) }),
            ("classification", Labels.classification, annotations.carries(.classification),
             { index.onset(of: .classification) }),
            ("numbered", Labels.numbered, annotations.carries(.numbered), { index.onset(of: .numbered) }),
            ("referencesToDocuments", Labels.referencesToDocuments, annotations.carries(.xrefDocuments),
             { index.onset(of: .xrefDocuments) }),
            ("editorialNotes", Labels.editorialNotes, annotations.carries(.editorialNotes),
             { index.onset(of: .editorialNotes) }),
            ("noteOnSources", Labels.noteOnSources, annotations.prints(section: "sources"),
             { index.onset { $0.prints(section: "sources") } }),
        ]
        absent = standard.filter { !$0.carried }.map { layer in
            var note = Self.standardFrom(layer.onset())
            if layer.id == "people" {
                let hint = String(localized: "browser.volume.annotations.absent.people.hint",
                                  defaultValue: "Search the names instead.")
                note = note.isEmpty ? hint : note + " " + hint
            }
            return AbsentRow(id: layer.id, label: layer.label, note: note)
        }
    }

    /// "Standard in the volumes covering 1955 on.", or empty for no onset. The year is the era's
    /// first, from the file's own onset rule, and goes in through `String(_:)`: a year is not a count.
    static func standardFrom(_ era: AnnotationEra?) -> String {
        guard let year = era?.firstYear else { return "" }
        return String(format: String(localized: "browser.volume.annotations.absent.onset",
                                     defaultValue: "Standard in the volumes covering %@ on."),
                      String(year))
    }

    /// The names of the printed aids among `sections`, in the order the page names them. A section
    /// kind not listed here (the front and back containers, the table of contents, a chapter) is not
    /// an aid the page names.
    static func printedAids(in sections: [String]) -> [String] {
        var names: [String] = []
        for (kind, name) in printedAidNames where sections.contains(kind) && !names.contains(name) {
            names.append(name)
        }
        return names
    }

    /// The printed aids the page names: a section kind, as the parser names it, and its name.
    static var printedAidNames: [(kind: String, name: String)] {
        [
            ("preface", String(localized: "browser.volume.annotations.aid.preface", defaultValue: "Preface")),
            ("foreword", String(localized: "browser.volume.annotations.aid.foreword", defaultValue: "Foreword")),
            ("intro", String(localized: "browser.volume.annotations.aid.introduction", defaultValue: "Introduction")),
            ("introduction", String(localized: "browser.volume.annotations.aid.introduction",
                                    defaultValue: "Introduction")),
            ("sources", String(localized: "browser.volume.annotations.aid.sources", defaultValue: "Sources")),
            ("terms", String(localized: "browser.volume.annotations.aid.terms", defaultValue: "Abbreviations")),
            ("persons", String(localized: "browser.volume.annotations.aid.persons", defaultValue: "Persons")),
            ("list-of-papers", String(localized: "browser.volume.annotations.aid.listOfPapers",
                                      defaultValue: "List of Papers")),
            ("note-on-covert-actions", String(localized: "browser.volume.annotations.aid.covertActions",
                                              defaultValue: "Note on U.S. Covert Actions")),
            ("press-release", String(localized: "browser.volume.annotations.aid.pressRelease",
                                     defaultValue: "Press Release")),
            ("volume-summary", String(localized: "browser.volume.annotations.aid.volumeSummary",
                                      defaultValue: "Volume Summary")),
            ("index", String(localized: "browser.volume.annotations.aid.index", defaultValue: "Index")),
            ("errata", String(localized: "browser.volume.annotations.aid.errata", defaultValue: "Errata")),
        ]
    }

    // MARK: Copy

    /// The layers' and groups' names.
    enum Labels {
        /// The first group's heading.
        static var named: String {
            String(localized: "browser.volume.annotations.group.named", defaultValue: "Who is named")
        }
        /// The second group's heading.
        static var provenance: String {
            String(localized: "browser.volume.annotations.group.provenance", defaultValue: "Where it came from")
        }
        /// The third group's heading.
        static var connects: String {
            String(localized: "browser.volume.annotations.group.connects", defaultValue: "How it connects")
        }
        /// People linked to the volume's List of Persons.
        static var people: String {
            String(localized: "browser.volume.annotations.people", defaultValue: "People tagged")
        }
        /// Terms linked to the volume's List of Abbreviations.
        static var abbreviations: String {
            String(localized: "browser.volume.annotations.abbreviations", defaultValue: "Abbreviations explained")
        }
        /// Senders and recipients marked in the heading.
        static var correspondents: String {
            String(localized: "browser.volume.annotations.correspondents", defaultValue: "Senders and recipients")
        }
        /// Subject lines.
        static var subjects: String {
            String(localized: "browser.volume.annotations.subjects", defaultValue: "Subject lines")
        }
        /// Lists of who attended.
        static var participants: String {
            String(localized: "browser.volume.annotations.participants", defaultValue: "Meeting participants")
        }
        /// Source notes of either form.
        static var sourceNotes: String {
            String(localized: "browser.volume.annotations.sourceNotes", defaultValue: "Source notes")
        }
        /// Classification markings.
        static var classification: String {
            String(localized: "browser.volume.annotations.classification", defaultValue: "Classification markings")
        }
        /// Excisions marked in the text.
        static var excisions: String {
            String(localized: "browser.volume.annotations.excisions", defaultValue: "Excisions marked")
        }
        /// The sending post's own serials.
        static var despatch: String {
            String(localized: "browser.volume.annotations.despatch", defaultValue: "Despatch numbers")
        }
        /// Documents numbered in print.
        static var numbered: String {
            String(localized: "browser.volume.annotations.numbered", defaultValue: "Numbered documents")
        }
        /// References to documents, footnotes, volumes and pages.
        static var crossReferences: String {
            String(localized: "browser.volume.annotations.crossReferences", defaultValue: "Cross-references")
        }
        /// References to the volume's own documents, the standard part of the cross-references.
        static var referencesToDocuments: String {
            String(localized: "browser.volume.annotations.referencesToDocuments",
                   defaultValue: "References to documents")
        }
        /// Editorial notes.
        static var editorialNotes: String {
            String(localized: "browser.volume.annotations.editorialNotes", defaultValue: "Editorial notes")
        }
        /// Footnotes in most documents.
        static var footnotes: String {
            String(localized: "browser.volume.annotations.footnotes", defaultValue: "Footnotes")
        }
        /// Marginal notes.
        static var marginalNotes: String {
            String(localized: "browser.volume.annotations.marginalNotes", defaultValue: "Marginal notes")
        }
        /// The volume's printed aids: its preface, lists and index.
        static var printedAids: String {
            String(localized: "browser.volume.annotations.printedAids", defaultValue: "Printed aids")
        }
        /// The Note on Sources, a standard section.
        static var noteOnSources: String {
            String(localized: "browser.volume.annotations.noteOnSources", defaultValue: "Note on Sources")
        }
    }

    /// The rows' counts as words, for one volume and one locale.
    private struct Copy {
        let annotations: VolumeAnnotations
        let locale: Locale

        /// "279 of 280 documents", with what the volume lists after it when there is any.
        func coverage(_ category: AnnotationCategory, listed: String? = nil) -> String {
            let line = of(annotations.count(category))
            guard let listed else { return line }
            return line + VolumeAnnotationsPresentation.separator + listed
        }

        /// "N of M documents", M the volume's documents.
        func of(_ count: Int) -> String {
            CountCopy.phrase(annotations.documents,
                             one: String(localized: "browser.volume.annotations.ofDocuments.one",
                                         defaultValue: "%2$@ of %1$@ document"),
                             many: String(localized: "browser.volume.annotations.ofDocuments.many",
                                          defaultValue: "%2$@ of %1$@ documents"),
                             then: [count.formatted(.number.locale(locale))], locale: locale)
        }

        /// "N documents".
        func documents(_ category: AnnotationCategory) -> String {
            CountCopy.documents(annotations.count(category), locale: locale)
        }

        /// "325 people listed", or `nil` when the volume prints no List of Persons the index read.
        var personsListed: String? {
            guard annotations.personsListed > 0 else { return nil }
            return CountCopy.phrase(annotations.personsListed,
                                    one: String(localized: "browser.volume.annotations.people.listed.one",
                                                defaultValue: "%@ person listed"),
                                    many: String(localized: "browser.volume.annotations.people.listed.many",
                                                 defaultValue: "%@ people listed"),
                                    locale: locale)
        }

        /// "470 terms listed", or `nil` when the volume prints no List of Abbreviations the index read.
        var termsListed: String? {
            guard annotations.termsListed > 0 else { return nil }
            return CountCopy.phrase(annotations.termsListed,
                                    one: String(localized: "browser.volume.annotations.terms.listed.one",
                                                defaultValue: "%@ term listed"),
                                    many: String(localized: "browser.volume.annotations.terms.listed.many",
                                                 defaultValue: "%@ terms listed"),
                                    locale: locale)
        }

        /// "268 of 280 documents · archival citations (“Source: …”)": the coverage, then the form.
        var sourceNotes: String {
            let citations = annotations.count(.sourceCitation) > 0
            let fileNumbers = annotations.count(.sourceFileNumber) > 0
            let form: String
            switch (citations, fileNumbers) {
            case (true, false):
                form = String(localized: "browser.volume.annotations.sourceNotes.citations",
                              defaultValue: "archival citations (“Source: …”)")
            case (false, true):
                form = String(localized: "browser.volume.annotations.sourceNotes.fileNumbers",
                              defaultValue: "file numbers above the heading")
            default:
                form = String(localized: "browser.volume.annotations.sourceNotes.both",
                              defaultValue: "archival citations and file numbers")
            }
            return of(annotations.sourceNotes) + VolumeAnnotationsPresentation.separator + form
        }

        /// "31 documents with text not declassified".
        var excisions: String {
            CountCopy.phrase(annotations.count(.excisions),
                             one: String(localized: "browser.volume.annotations.excisions.one",
                                         defaultValue: "%@ document with text not declassified"),
                             many: String(localized: "browser.volume.annotations.excisions.many",
                                          defaultValue: "%@ documents with text not declassified"),
                             locale: locale)
        }

        /// "12 editorial notes".
        var editorialNotes: String {
            CountCopy.phrase(annotations.count(.editorialNotes),
                             one: String(localized: "browser.volume.annotations.editorialNotes.one",
                                         defaultValue: "%@ editorial note"),
                             many: String(localized: "browser.volume.annotations.editorialNotes.many",
                                          defaultValue: "%@ editorial notes"),
                             locale: locale)
        }

        /// The documents that cite the volume's own documents, other volumes and printed pages, the
        /// parts present joined; `nil` when none does.
        var crossReferences: String? {
            var parts: [String] = []
            if annotations.carries(.xrefDocuments) {
                parts.append(CountCopy.phrase(annotations.count(.xrefDocuments),
                    one: String(localized: "browser.volume.annotations.xrefs.documents.one",
                                defaultValue: "%@ document cites another in this volume"),
                    many: String(localized: "browser.volume.annotations.xrefs.documents.many",
                                 defaultValue: "%@ documents cite others in this volume"),
                    locale: locale))
            }
            if annotations.carries(.xrefVolumes) {
                parts.append(CountCopy.phrase(annotations.count(.xrefVolumes),
                    one: String(localized: "browser.volume.annotations.xrefs.volumes.one",
                                defaultValue: "%@ document cites other volumes"),
                    many: String(localized: "browser.volume.annotations.xrefs.volumes.many",
                                 defaultValue: "%@ documents cite other volumes"),
                    locale: locale))
            }
            if annotations.carries(.xrefPages) {
                parts.append(CountCopy.phrase(annotations.count(.xrefPages),
                    one: String(localized: "browser.volume.annotations.xrefs.pages.one",
                                defaultValue: "%@ document cites printed pages"),
                    many: String(localized: "browser.volume.annotations.xrefs.pages.many",
                                 defaultValue: "%@ documents cite printed pages"),
                    locale: locale))
            }
            return parts.isEmpty ? nil : parts.joined(separator: VolumeAnnotationsPresentation.separator)
        }
    }
}
