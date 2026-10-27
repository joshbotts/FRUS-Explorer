// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - QueryMethodAppendix + the app

/// The method appendix as the app makes and renders it: from its stored trail, for its own host.
///
/// The appendix moved into FRUSCoreKit (`FRUSCoreKit/Export/QueryMethodAppendix.swift`) for FRUS Explorer
/// Light, which writes the same Markdown and CSV from its own store. What the appendix read from the app
/// is passed in there, and passed here: the bundle's version for the Generated line, the bundled data
/// files that name a subject, and the reader's locale, calendar and time zone. Every call site keeps
/// the names it used.
///
/// Version history:
///   1.0 — Session 2026-10-25 (FRUS Explorer Light, S17b): initial implementation, when the appendix
///          moved into the kit
extension QueryMethodAppendix.Host {

    /// The app's host: its bundle's short version string, its bundled data files
    /// (`IndexingResources.bundled`) and the reader's locale, calendar and time zone, read each time an
    /// appendix is rendered, as the appendix read them before it moved.
    static var app: QueryMethodAppendix.Host {
        QueryMethodAppendix.Host(
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            resources: .bundled)
    }
}

extension QueryMethodAppendix {

    /// Builds an appendix from the stored trail: the kit's
    /// ``make(recordedSearches:corpusNames:projectName:researchQuestion:generatedAt:corpusCoverage:)`` over
    /// each entry's values (`SearchHistoryEntry.recordedSearch`).
    ///
    /// - Parameters:
    ///   - searches: the recorded searches, in any order.
    ///   - corpusNames: working-corpus names by id, for the rows that carry one.
    ///   - projectName: the active project's name, or `nil` in global context.
    ///   - researchQuestion: that project's research question, if set.
    ///   - generatedAt: the export timestamp.
    ///   - corpusCoverage: how much of each searched corpus was examined, or `[]`.
    static func make(searches: [SearchHistoryEntry],
                     corpusNames: [UUID: String],
                     projectName: String?,
                     researchQuestion: String?,
                     generatedAt: Date,
                     corpusCoverage: [CorpusCoverage] = []) -> QueryMethodAppendix {
        make(recordedSearches: searches.map(\.recordedSearch),
             corpusNames: corpusNames,
             projectName: projectName,
             researchQuestion: researchQuestion,
             generatedAt: generatedAt,
             corpusCoverage: corpusCoverage)
    }

    /// The appendix as Markdown, for the app's host.
    var markdown: String { markdown(for: .app) }

    /// The appendix as RFC-4180 CSV, for the app's host.
    var csv: String { csv(for: .app) }

    /// The appendix as a flat list of lines, for the app's host.
    var plainTextLines: [String] { plainTextLines(for: .app) }

    /// The coverage block as plain sentences, its numbers grouped for the reader's locale.
    var coverageLines: [String] { coverageLines(locale: .autoupdatingCurrent) }
}

extension QueryMethodAppendix.Row {

    /// The scope as prose, or the raw key when it will not decode, or a stated absence: the kit's
    /// ``scopeProse(resources:locale:)`` over the bundled data files and the reader's locale.
    var scopeProse: String { scopeProse(resources: .bundled, locale: .autoupdatingCurrent) }
}

extension SearchHistoryEntry.RecordedCount {

    /// The count as a reader should see it, its number grouped for the reader's locale: the kit's
    /// ``appendixDescription(locale:)``.
    var appendixDescription: String { appendixDescription(locale: .autoupdatingCurrent) }
}
