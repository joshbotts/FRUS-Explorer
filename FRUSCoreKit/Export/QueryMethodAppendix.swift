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

// MARK: - QueryMethodAppendix

/// The recorded query log, rendered as a methods statement a reader can check (M-2).
///
/// ## What this is for
/// Wave R's decision **D5** declines to auto-prune the research trail *because* the query log is
/// exported as a method appendix: a recorded query with its real hit count — **including the
/// zeros** — is what makes a claim of absence checkable. "I searched for X and found nothing" is
/// an assertion; "I searched for X on this date, over these 553 volumes, with these fields, and it
/// returned 0" is evidence. This type is the second half of that promise. The trail has been in
/// the JSON export since Wave R-5; JSON is not a methods section.
///
/// ## The one thing it must not do
/// **Never print a floor as if it were a count.** A macOS search that loaded 7,500 rows against a
/// 7,500-row ceiling did not find 7,500 documents; it found *at least* 7,500. Every count here is
/// routed through ``RecordedSearch/RecordedCount`` (the app's `SearchHistoryEntry.RecordedCount`),
/// which distinguishes the four cases the trail can actually be in, and each renders differently. The `count_basis` CSV column exists so
/// that distinction survives a spreadsheet, where a reader will otherwise sum the column.
///
/// Rows written before M-2 recorded only a headline number and no capture detail. They are printed
/// — dropping them would silently shorten the log — but marked, so a reader is never invited to
/// treat them as equivalent to the rows that carry their own provenance.
///
/// ## Two formats, one preamble
/// Markdown for reading and pasting into a paper; CSV for a spreadsheet. Both open with the same
/// `#`-prefixed preamble, following `AnalyticsProvenance`: the method travels *with* the numbers
/// rather than in a sidecar that gets separated from them.
///
/// ## What a rendering reads from its host
/// Each format is rendered for a ``Host``: the app's version for the Generated line, the data files
/// that name a subject in a scope, and the locale, calendar and time zone its dates and numbers are
/// written in. The app renders for its own (`markdown`, `csv` and `plainTextLines`, in its
/// `QueryMethodAppendix+App.swift`): its bundle's version, its bundled data files and the reader's
/// locale, as it always has. A host that fixes all three writes the same file on any platform.
///
/// Version history:
///   1.0 — M-2 commit 3: initial implementation
///   1.1 — PV-1 (the 2026-09-28 audit): the sources block (`sourceLines`) reaches the Markdown and the plain-text
///          lines, not only the CSV
///   1.2 — Session 2026-10-25 (FRUS Explorer Light, S17b): moved into FRUSCoreKit, public, for the web
///          edition's method appendix. A row's count is `RecordedSearch.RecordedCount`, and the appendix is
///          made from recorded searches as values (``make(recordedSearches:corpusNames:projectName:researchQuestion:generatedAt:corpusCoverage:)``).
///          What it read from the app's bundle and the reader's locale is passed in, as a ``Host``
///          (``markdown(for:)``, ``csv(for:)``, ``plainTextLines(for:)``); the app's renderings pass its own
public struct QueryMethodAppendix: Sendable, Equatable {

    /// One recorded search, already resolved against the models it points at.
    public struct Row: Sendable, Equatable {

        /// When the search ran. `nil` on rows migrated from the retired `SessionEvent`.
        public var executedAt: Date?

        /// The submitted query, trimmed.
        public var queryText: String

        /// How the count should be read. The honesty of the whole document rests here.
        public var count: RecordedSearch.RecordedCount

        /// The canonical scope key as recorded, printed verbatim in the CSV.
        public var scopeSignature: String?

        /// How many volumes the device had indexed — the denominator. `nil` on pre-M-2 rows.
        public var indexedVolumeCount: Int?

        /// The name of the working corpus the search ran inside, resolved at export time. `nil`
        /// when no corpus was applied *or* the corpus has since been deleted; the appendix cannot
        /// tell those apart and does not claim to.
        public var workingCorpusName: String?

        /// The id of that corpus. Stored beside the name because the coverage block narrows on it:
        /// a name is what a reader sees, an id is what a join needs, and two corpora may share a
        /// name. `nil` on the same terms as ``workingCorpusName``.
        public var workingCorpusId: UUID?

        /// The FTS5 expression the query compiled to. Printed in the CSV only — it is the answer
        /// to "what did the app actually search for", which prose cannot give.
        public var renderedExpression: String?

        /// The id of the project active at execution, if any.
        public var projectId: UUID?

        /// Creates a row.
        public init(executedAt: Date? = nil, queryText: String, count: RecordedSearch.RecordedCount,
                    scopeSignature: String? = nil, indexedVolumeCount: Int? = nil,
                    workingCorpusName: String? = nil, workingCorpusId: UUID? = nil,
                    renderedExpression: String? = nil, projectId: UUID? = nil) {
            self.executedAt = executedAt
            self.queryText = queryText
            self.count = count
            self.scopeSignature = scopeSignature
            self.indexedVolumeCount = indexedVolumeCount
            self.workingCorpusName = workingCorpusName
            self.workingCorpusId = workingCorpusId
            self.renderedExpression = renderedExpression
            self.projectId = projectId
        }
    }

    /// One corpus and how much of it was examined.
    ///
    /// Version history:
    ///   1.0 — W-13 session 2: initial implementation
    public struct CorpusCoverage: Sendable, Equatable {

        /// The corpus, for the join against ``Row/workingCorpusId``.
        public var corpusId: UUID

        /// Its name at export time.
        public var corpusName: String

        /// Opened / annotated / collected against the corpus's own document count.
        public var coverage: EngagementCoverage

        /// Whether the capture that built the corpus was complete.
        ///
        /// **The denominator can itself be a floor**, and this appendix's one non-negotiable
        /// property is that a floor never renders as a total. A corpus saved at the row ceiling
        /// holds 7,500 of 40,000 matches, so "43 of 7,500 worked on" is a true sentence about a
        /// set that is not the one the query described — and a reader has no way to tell without
        /// being told.
        public var truncation: CorpusCaptureTruncation = .unrecorded

        /// Whether the corpus is a Meaning search's closest matches (`WorkingCorpus.isMeaningCapture`), which its
        /// completeness line names rather than calling it a capture that stopped short (#1688).
        public var isMeaningCapture = false

        /// Creates a coverage row.
        public init(corpusId: UUID, corpusName: String, coverage: EngagementCoverage,
                    truncation: CorpusCaptureTruncation = .unrecorded, isMeaningCapture: Bool = false) {
            self.corpusId = corpusId
            self.corpusName = corpusName
            self.coverage = coverage
            self.truncation = truncation
            self.isMeaningCapture = isMeaningCapture
        }
    }

    /// The active project's name at export time, heading the appendix exactly as it heads a
    /// collection export (#454/#455, Q&CA §I-2).
    public var projectName: String?

    /// That project's research question, if set.
    public var researchQuestion: String?

    /// When this appendix was generated.
    public var generatedAt: Date

    /// Every recorded search, oldest first.
    public var rows: [Row]

    /// How much of each searched corpus was actually examined (W-13 session 2).
    ///
    /// **Every corpus here was searched inside by one of `rows`.** That is the whole answer to the
    /// question of what a coverage statement in a query log is entitled to describe: a
    /// `WorkingCorpus` carries no project identifier, so there is no such thing as "this project's
    /// corpora" to report on — but "the corpora this project searched inside" is derivable from
    /// the log itself, through `SearchHistoryEntry.appliedCorpusId`. Read
    /// ``applicableCoverage`` rather than this, which narrows with the rows.
    public var corpusCoverage: [CorpusCoverage] = []

    /// Creates an appendix from rows already resolved and ordered, as
    /// ``make(recordedSearches:corpusNames:projectName:researchQuestion:generatedAt:corpusCoverage:)`` makes one.
    public init(projectName: String? = nil, researchQuestion: String? = nil, generatedAt: Date,
                rows: [Row], corpusCoverage: [CorpusCoverage] = []) {
        self.projectName = projectName
        self.researchQuestion = researchQuestion
        self.generatedAt = generatedAt
        self.rows = rows
        self.corpusCoverage = corpusCoverage
    }

    // MARK: - Construction

    /// Builds an appendix from the stored trail, as values (the app's `SearchHistoryEntry.recordedSearch`).
    ///
    /// - Parameters:
    ///   - recordedSearches: the recorded searches, in any order — this sorts them oldest first, putting
    ///     undated rows (migrated `SessionEvent`s) at the end rather than at an invented time.
    ///   - corpusNames: working-corpus names by id, for the rows that carry one.
    ///   - projectName: the active project's name, or `nil` in global context.
    ///   - researchQuestion: that project's research question, if set.
    ///   - generatedAt: the export timestamp.
    ///   - corpusCoverage: how much of each searched corpus was examined, or `[]`. Defaulted so
    ///     every existing caller and test keeps compiling and keeps meaning what it meant — an
    ///     appendix with no coverage table renders exactly as it did before W-13 session 2.
    public static func make(recordedSearches searches: [RecordedSearch],
                            corpusNames: [UUID: String],
                            projectName: String?,
                            researchQuestion: String?,
                            generatedAt: Date,
                            corpusCoverage: [CorpusCoverage] = []) -> QueryMethodAppendix {
        let sorted = searches.sorted { lhs, rhs in
            switch (lhs.executedAt, rhs.executedAt) {
            case let (left?, right?): return left < right
            case (nil, _?): return false
            case (_?, nil): return true
            case (nil, nil): return lhs.id.uuidString < rhs.id.uuidString
            }
        }
        return QueryMethodAppendix(
            projectName: projectName,
            researchQuestion: researchQuestion,
            generatedAt: generatedAt,
            rows: sorted.map { entry in
                Row(executedAt: entry.executedAt,
                    queryText: entry.queryText,
                    count: entry.recordedCount,
                    scopeSignature: entry.scopeSignature,
                    indexedVolumeCount: entry.indexedVolumeCount,
                    workingCorpusName: entry.appliedCorpusId.flatMap { corpusNames[$0] },
                    workingCorpusId: entry.appliedCorpusId,
                    renderedExpression: entry.renderedExpression,
                    projectId: entry.projectId)
            },
            corpusCoverage: corpusCoverage.sorted { $0.corpusName < $1.corpusName })
    }

    /// The same appendix, narrowed to the searches run under one project.
    ///
    /// A collection export is a shareable artifact, and the whole trail is not. `includeColophon`'s
    /// sibling `includeProjectProvenance` is off by default so a research question is never
    /// disclosed on a published PDF unless the researcher opts in; the query log is the same
    /// argument with more surface, so the collection route both opts in *and* narrows to the
    /// project the export was generated under.
    ///
    /// The counts in the caveats are recomputed from the narrowed rows, because they are derived —
    /// an appendix claiming "3 searches returned nothing" about rows it is not showing would be
    /// describing a different document.
    ///
    /// - Parameter projectId: the project to keep. `nil` keeps nothing: in global context there is
    ///   no project whose method this would be stating, so an export cannot silently fall back to
    ///   the whole trail.
    public func scoped(toProject projectId: UUID?) -> QueryMethodAppendix {
        var scoped = self
        scoped.rows = projectId.map { id in rows.filter { $0.projectId == id } } ?? []
        // The coverage table is narrowed with the rows, on the same argument. `coverageLines`
        // already renders only ``applicableCoverage``, so this is belt as well as braces — but a
        // scoped appendix is the one handed to a *collection export*, a shareable artifact, and a
        // stored table naming corpora from another line of work is exactly the disclosure the
        // narrowing exists to prevent. Anything reading `corpusCoverage` directly is safe too.
        let searched = Set(scoped.rows.compactMap(\.workingCorpusId))
        scoped.corpusCoverage = corpusCoverage.filter { searched.contains($0.corpusId) }
        return scoped
    }

    // MARK: - Derived facts

    /// Rows written before M-2, which carry a headline number and no capture detail.
    public var unrecordedRowCount: Int {
        rows.filter { if case .unrecorded = $0.count { return true } else { return false } }.count
    }

    /// Rows whose count is a floor rather than a total — the ones a reader must not sum.
    public var floorRowCount: Int {
        rows.filter { if case .floor = $0.count { return true } else { return false } }.count
    }

    /// Rows that returned nothing. Named in the preamble because a zero is the appendix's whole
    /// reason for existing and a reader scanning a long table will not count them.
    public var zeroResultRowCount: Int {
        rows.filter { $0.count.displayedTotal == 0 }.count
    }

    /// Whether a row records a Meaning-route search (V-5 hybrid page), by its signature.
    public static func isSemanticRow(_ row: Row) -> Bool {
        SearchScopeSignature.isMeaningRoute(row.scopeSignature)
    }

    /// Zero-result rows on the KEYWORD route only — the term-absence caveat's honest scope: a
    /// semantic zero says nothing about term absence, so counting it there would put a false
    /// sentence in a method appendix.
    public var keywordZeroResultRowCount: Int {
        rows.filter { $0.count.displayedTotal == 0 && !Self.isSemanticRow($0) }.count
    }

    /// The coverage rows that describe corpora **these** rows actually searched inside.
    ///
    /// Derived rather than stored, for the reason ``scoped(toProject:)`` gives about the caveat
    /// counts: a narrowed appendix that kept reporting coverage of a corpus it no longer shows a
    /// search for would be describing a different document. Narrowing the rows narrows this.
    public var applicableCoverage: [CorpusCoverage] {
        let searched = Set(rows.compactMap(\.workingCorpusId))
        return corpusCoverage.filter { searched.contains($0.corpusId) }
    }

    /// The heading over the coverage block, in every format.
    public static var coverageHeading: String {
        String(localized: "appendix.coverage.heading",
               defaultValue: "How much of each searched corpus was examined")
    }

    /// The coverage block as plain sentences — **one definition, rendered by all three formats.**
    ///
    /// The three renderers decorate it differently (a Markdown bullet, a bare line, a `#` comment)
    /// and none of them composes the sentence. That is deliberate and is the failure this block was
    /// written to avoid: the appendix already had three renderers, and a fact added to one of them
    /// appears in the exported Markdown and is silently missing from the collection PDF that the
    /// same research is published from.
    ///
    /// Empty when no row searched inside a corpus, which is the honest outcome rather than a
    /// degenerate one: with no corpus there is no denominator, and a coverage statement without a
    /// denominator is the thing this feature exists to replace.
    ///
    /// - Parameter locale: The locale that groups the numbers (the app's `coverageLines` passes the
    ///   reader's).
    /// - Returns: The block's lines.
    public func coverageLines(locale: Locale) -> [String] {
        let applicable = applicableCoverage
        guard !applicable.isEmpty else { return [] }
        // Whose engagement, said plainly. A project-scoped count attributes a note or a highlight
        // through the project that owns it, so a highlight made with no note attached to no project
        // is not counted — and a reader recomputing these numbers by hand needs to know which
        // population they describe before the difference looks like an error.
        var lines = [projectName == nil
            ? String(localized: "appendix.coverage.preamble.device",
                     defaultValue: "Coverage counts what has been done on this device with the documents each corpus holds — opened, annotated, or placed in a collection. It is not what the searches returned.")
            : String(localized: "appendix.coverage.preamble.project",
                     defaultValue: "Coverage counts what this project has done with the documents each corpus holds — opened, annotated, or placed in a collection. It is not what the searches returned.")]
        for entry in applicable {
            var sentence = "\(entry.corpusName): \(entry.coverage.coverageDescription(locale: locale))"
            if let breakdown = entry.coverage.breakdownDescription(locale: locale) {
                sentence += " · \(breakdown)"
            }
            sentence += " · \(entry.coverage.untouchedDescription(locale: locale))"
            lines.append(sentence)
            // The denominator's own completeness, in the corpus browser's exact words, prefixed
            // with the name so a multi-corpus block stays attributable line by line.
            if let note = entry.truncation.line(documentCount: entry.coverage.totalCount,
                                                isMeaningCapture: entry.isMeaningCapture,
                                                locale: locale) {
                lines.append("\(entry.corpusName): \(note)")
            }
        }
        // Once for the block, not once per corpus: the gate is a device setting, so a log with
        // four corpora would otherwise print the same sentence four times. Taken from the first
        // coverage that HAS one rather than from the first coverage — `first?.loggingCaveat` is
        // nil whenever the alphabetically-first corpus happens to be the complete one.
        if let caveat = applicable.compactMap({ $0.coverage.loggingCaveat }).first {
            lines.append(caveat)
        }
        return lines
    }

    /// Rows recorded from the Meaning route, so the appendix can say what those counts mean.
    public var semanticRowCount: Int {
        rows.filter { Self.isSemanticRow($0) }.count
    }

    // MARK: - The host

    /// What a rendering of the appendix reads from its host (S17b, FRUS Explorer Light).
    ///
    /// The app's renderings pass its own (`QueryMethodAppendix.Host.app`): its bundle's version, its
    /// bundled data files and the reader's locale, calendar and time zone, which is what the appendix
    /// read itself before it moved into the kit. A host that fixes the locale, calendar and time zone
    /// writes the same file on any platform: the kit's suite holds a fixture trail's to the byte.
    public struct Host: Sendable {
        /// The app's version, for the Generated line ("FRUS Explorer 1.0"), or `nil` to print the
        /// name alone.
        public var appVersion: String?
        /// The data files whose subject vocabulary names a scope's subject; with none, the scope
        /// prints the subject as recorded.
        public var resources: IndexingResources
        /// The locale the dates, the numbers and the lists are written in.
        public var locale: Locale
        /// The calendar the dates are written in.
        public var calendar: Calendar
        /// The time zone the dates are written in. The CSV's `executed_at` column is ISO 8601 in UTC
        /// whatever this is.
        public var timeZone: TimeZone

        /// Creates a host.
        public init(appVersion: String?, resources: IndexingResources = .none,
                    locale: Locale = .autoupdatingCurrent, calendar: Calendar = .autoupdatingCurrent,
                    timeZone: TimeZone = .autoupdatingCurrent) {
            self.appVersion = appVersion
            self.resources = resources
            self.locale = locale
            self.calendar = calendar
            self.timeZone = timeZone
        }
    }

    // MARK: - Markdown

    /// The appendix as Markdown — a preamble, a table, and the caveats that apply to *this* log.
    ///
    /// - Parameter host: What the rendering reads from its host; the app's `markdown` passes its own.
    /// - Returns: The Markdown file.
    public func markdown(for host: Host) -> String {
        var lines: [String] = []
        lines.append("# " + String(localized: "appendix.title",
                                   defaultValue: "Query log — method appendix"))
        lines.append("")
        if let projectName {
            lines.append("**" + String(localized: "appendix.field.project", defaultValue: "Project")
                         + ":** \(projectName)")
        }
        if let researchQuestion {
            lines.append("**" + String(localized: "appendix.field.question",
                                       defaultValue: "Research question")
                         + ":** \(researchQuestion)")
        }
        lines.append("**" + String(localized: "appendix.field.generated", defaultValue: "Generated")
                     + ":** \(Self.appCredit(version: host.appVersion)), \(formattedGeneratedAt(for: host))")
        lines.append("**" + String(localized: "appendix.field.searches", defaultValue: "Searches")
                     + ":** \(rows.count.formatted(.number.locale(host.locale)))")
        lines.append("")

        lines.append("| " + [
            String(localized: "appendix.column.executed", defaultValue: "Executed"),
            String(localized: "appendix.column.query", defaultValue: "Query"),
            String(localized: "appendix.column.results", defaultValue: "Results"),
            String(localized: "appendix.column.indexed", defaultValue: "Volumes indexed"),
            String(localized: "appendix.column.scope", defaultValue: "Scope")
        ].joined(separator: " | ") + " |")
        lines.append("| --- | --- | ---: | ---: | --- |")
        for row in rows {
            lines.append("| " + [
                row.executedAt.map { Self.tableDate($0, for: host) } ?? "—",
                Self.escapeMarkdownCell(row.queryText),
                Self.escapeMarkdownCell(row.count.appendixDescription(locale: host.locale)),
                row.indexedVolumeCount?.formatted(.number.locale(host.locale)) ?? "—",
                Self.escapeMarkdownCell(row.scopeProse(resources: host.resources, locale: host.locale))
            ].joined(separator: " | ") + " |")
        }
        let coverage = coverageLines(locale: host.locale)
        if !coverage.isEmpty {
            lines.append("")
            lines.append("## " + Self.coverageHeading)
            for line in coverage { lines.append("- \(line)") }
        }
        lines.append("")
        lines.append("## " + String(localized: "appendix.method.heading",
                                    defaultValue: "How to read this table"))
        for caveat in caveats(locale: host.locale) { lines.append("- \(caveat)") }
        // PV-1: the same sources block the CSV carries, as a section of its own.
        if let heading = sourceLines.first {
            lines.append("")
            lines.append("## " + heading)
            for line in sourceLines.dropFirst() { lines.append("- \(line)") }
        }
        lines.append("")
        lines.append(Self.corpusAttribution)
        return lines.joined(separator: "\n").appending("\n")
    }

    // MARK: - Plain text

    /// The appendix as a flat list of lines, for renderers that cannot lay out a table.
    ///
    /// The collection exporters draw into PDF pages, Word paragraphs and HTML sections. Giving each
    /// of them a table to lay out would mean three implementations of column widths that could
    /// disagree, in three formats, over a document whose entire point is that it can be checked. A
    /// line per search says the same things — the date, the query, how the count must be read, the
    /// denominator, the scope — and every renderer can already draw a paragraph.
    ///
    /// Prefixes distinguish structure without any renderer needing to know the schema: a heading
    /// stands alone, caveats start with `—`, and search lines start with a date.
    ///
    /// - Parameter host: What the rendering reads from its host; the app's `plainTextLines` passes its
    ///   own.
    /// - Returns: The lines.
    public func plainTextLines(for host: Host) -> [String] {
        var lines = [String(localized: "appendix.title", defaultValue: "Query log — method appendix")]
        for caveat in caveats(locale: host.locale) { lines.append("— \(caveat)") }
        let coverage = coverageLines(locale: host.locale)
        if !coverage.isEmpty {
            lines.append("")
            lines.append(Self.coverageHeading)
            for line in coverage { lines.append(line) }
        }
        // PV-1: the sources block, a heading standing alone and its sentences after it — the lines a collection's
        // PDF, HTML and Word exports print, where the colophon's own block names only the collection's items.
        let sources = sourceLines
        if !sources.isEmpty {
            lines.append("")
            lines.append(contentsOf: sources)
        }
        lines.append("")
        for row in rows {
            var parts = [row.executedAt.map { Self.tableDate($0, for: host) } ?? "—", "“\(row.queryText)”"]
            parts.append(String(localized: "appendix.line.results %@",
                                defaultValue: "\(row.count.appendixDescription(locale: host.locale)) results"))
            if let indexed = row.indexedVolumeCount {
                parts.append(String(localized: "appendix.line.indexed %lld",
                                    defaultValue: "\(indexed) volumes indexed", locale: host.locale))
            }
            parts.append(row.scopeProse(resources: host.resources, locale: host.locale))
            lines.append(parts.joined(separator: " · "))
        }
        return lines
    }

    // MARK: - CSV

    /// The appendix as RFC-4180 CSV, preceded by the same preamble as `#` comment lines.
    ///
    /// Carries four columns the Markdown table does not — the raw scope key, the compiled FTS5
    /// expression, the separate loaded/limit numbers, and `count_basis`. The Markdown is for a
    /// reader; this is for anyone re-deriving the numbers, who needs the parts a sentence folds
    /// together.
    ///
    /// - Parameter host: What the rendering reads from its host; the app's `csv` passes its own.
    /// - Returns: The CSV file.
    public func csv(for host: Host) -> String {
        var lines = preambleLines(for: host).map { $0.isEmpty ? "#" : "# \($0)" }
        lines.append([
            "executed_at", "query", "count_basis", "match_count", "loaded_count", "fetch_limit",
            "reported_count", "indexed_volume_count", "working_corpus", "project_id",
            "scope_signature", "rendered_expression"
        ].joined(separator: ","))
        for row in rows {
            let numbers = row.count.csvNumbers
            lines.append([
                row.executedAt.map(Self.iso) ?? "",
                Self.escapeCSV(row.queryText),
                row.count.basisToken,
                numbers.match, numbers.loaded, numbers.limit, numbers.reported,
                row.indexedVolumeCount.map(String.init) ?? "",
                Self.escapeCSV(row.workingCorpusName ?? ""),
                row.projectId?.uuidString ?? "",
                Self.escapeCSV(row.scopeSignature ?? ""),
                Self.escapeCSV(row.renderedExpression ?? "")
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n").appending("\n")
    }

    // MARK: - Shared prose

    /// The CSV's header facts, written as its `#` comment lines. (Markdown and plain text build their own headers,
    /// and share only `sourceLines` and the caveats with it.)
    private func preambleLines(for host: Host) -> [String] {
        var lines: [String] = []
        lines.append(String(localized: "appendix.title", defaultValue: "Query log — method appendix"))
        lines.append("")
        if let projectName {
            lines.append("\(String(localized: "appendix.field.project", defaultValue: "Project")): \(projectName)")
        }
        if let researchQuestion {
            lines.append("\(String(localized: "appendix.field.question", defaultValue: "Research question")): \(researchQuestion)")
        }
        lines.append("\(String(localized: "appendix.field.generated", defaultValue: "Generated")): \(Self.appCredit(version: host.appVersion)), \(formattedGeneratedAt(for: host))")
        lines.append("\(String(localized: "appendix.field.searches", defaultValue: "Searches")): \(rows.count.formatted(.number.locale(host.locale)))")
        let coverage = coverageLines(locale: host.locale)
        if !coverage.isEmpty {
            lines.append("")
            lines.append(Self.coverageHeading)
            for line in coverage { lines.append(line) }
        }
        lines.append("")
        lines.append(String(localized: "appendix.method.heading", defaultValue: "How to read this table"))
        for caveat in caveats(locale: host.locale) { lines.append(caveat) }
        let sourceBlock = sourceLines
        if !sourceBlock.isEmpty {
            lines.append("")
            lines.append(contentsOf: sourceBlock)
        }
        lines.append("")
        lines.append(Self.corpusAttribution)
        return lines
    }

    /// What these counts were drawn from (PV-1): the sources block, its heading first, shared by all three formats.
    ///
    /// A keyword search is the FTS5 index over FRUS's own text; a Meaning search additionally ran the on-device
    /// encoder, which is a different claim and is the reason the set is derived from the rows rather than fixed. Only
    /// the CSV carried it until the 2026-09-28 audit: the Markdown query log (`frus-query-log.md`) and the plain-text
    /// lines a collection export embeds stated no sources at all, the W-13 trap the provenance plan named.
    public var sourceLines: [String] {
        var sources: Set<ProvenanceSource> = [.frusText]
        if semanticRowCount > 0 { sources.insert(.appModel) }
        return ProvenanceStatement.block(for: sources)
    }

    /// The caveats that apply to *this* log. Conditional on purpose: an appendix that recited every
    /// possible hazard would train a reader to skip them, so each of the last three appears only
    /// when a row of that kind is actually present. Only the first — that a count is a snapshot —
    /// is unconditional, because it is true of every row.
    ///
    /// Singular and plural are spelled out as separate strings rather than dropping a count into
    /// one. There is no String Catalog in this app, so `inflect:` markup would ship literally, and
    /// "1 searches hit the app's row ceiling" in a methods section undercuts the care the rest of
    /// the document is making a case for.
    private func caveats(locale: Locale) -> [String] {
        var caveats: [String] = [
            String(localized: "appendix.caveat.snapshot",
                   defaultValue: "Each count is what the search returned when it ran, over the volumes downloaded to that device at that moment. It is not re-run, and it will not match a search run today against a larger index.")
        ]
        if keywordZeroResultRowCount > 0 {
            caveats.append(keywordZeroResultRowCount == 1
                ? String(localized: "appendix.caveat.zero.one",
                         defaultValue: "One of these searches returned nothing. A zero is a finding: it means the term is absent from the volumes indexed at the time, not that it is absent from the FRUS series.")
                : String(localized: "appendix.caveat.zero.many %lld",
                         defaultValue: "\(keywordZeroResultRowCount) of these searches returned nothing. A zero is a finding: it means the term is absent from the volumes indexed at the time, not that it is absent from the FRUS series.",
                         locale: locale))
        }
        if semanticRowCount > 0 {
            // The Meaning route's own caveat: its counts are a ranked top-K, not a match total,
            // and its zeros are not term absence — different claims than the keyword rows make.
            caveats.append(semanticRowCount == 1
                ? String(localized: "appendix.caveat.semantic.one",
                         defaultValue: "One search ran by meaning (on-device model) rather than by keywords. Its count is the size of a ranked list, not a match total, and a zero there does not mean any term is absent.")
                : String(localized: "appendix.caveat.semantic.many %lld",
                         defaultValue: "\(semanticRowCount) searches ran by meaning (on-device model) rather than by keywords. Their counts are sizes of ranked lists, not match totals, and zeros there do not mean any term is absent.",
                         locale: locale))
        }
        if floorRowCount > 0 {
            caveats.append(floorRowCount == 1
                ? String(localized: "appendix.caveat.floor.one",
                         defaultValue: "One search hit the app’s row ceiling. Its count is shown as “at least N” and is a floor, not a total — do not sum it with the others.")
                : String(localized: "appendix.caveat.floor.many %lld",
                         defaultValue: "\(floorRowCount) searches hit the app’s row ceiling. Those counts are shown as “at least N” and are floors, not totals — do not sum them.",
                         locale: locale))
        }
        if unrecordedRowCount > 0 {
            caveats.append(unrecordedRowCount == 1
                ? String(localized: "appendix.caveat.unrecorded.one",
                         defaultValue: "One search predates this app version. It saved only a result count — not the scope, the row ceiling, or how many volumes were indexed. It is marked “as reported” and cannot be checked against the others.")
                : String(localized: "appendix.caveat.unrecorded.many %lld",
                         defaultValue: "\(unrecordedRowCount) searches predate this app version. They saved only a result count — not the scope, the row ceiling, or how many volumes were indexed. They are marked “as reported” and cannot be checked against the others.",
                         locale: locale))
        }
        return caveats
    }

    /// The generation date, spelled out, in the host's locale, calendar and time zone.
    private func formattedGeneratedAt(for host: Host) -> String {
        Date.FormatStyle(date: .long, time: .shortened, locale: host.locale, calendar: host.calendar,
                         timeZone: host.timeZone).format(generatedAt)
    }

    // MARK: - Constants and escaping

    /// The wordmark + version, matching `AnalyticsProvenance.appCredit`. The version is the host's
    /// (``Host/appVersion``): the app reads its bundle's short version string, as this read before S17b.
    private static func appCredit(version: String?) -> String {
        "FRUS Explorer \(version ?? "")".trimmingCharacters(in: .whitespaces)
    }

    /// The source attribution every export carries.
    private static var corpusAttribution: String {
        String(localized: "appendix.attribution",
               defaultValue: "Text from Foreign Relations of the United States, Office of the Historian, U.S. Department of State (public domain).")
    }

    /// Locale-free, for the machine-readable column. A format *style* rather than a shared
    /// `ISO8601DateFormatter`, which is not `Sendable` and would need isolating to be a `static
    /// let` — and a per-call formatter allocation in a loop over an unbounded trail is worse.
    private static func iso(_ date: Date) -> String {
        date.formatted(.iso8601)
    }

    /// Localized, for the human-readable table, in the host's locale, calendar and time zone.
    private static func tableDate(_ date: Date, for host: Host) -> String {
        Date.FormatStyle(date: .numeric, time: .shortened, locale: host.locale, calendar: host.calendar,
                         timeZone: host.timeZone).format(date)
    }

    /// A pipe or a newline inside a query would break the table row it sits in — and a query
    /// containing a pipe is entirely legal FTS5 input.
    private static func escapeMarkdownCell(_ text: String) -> String {
        text.replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }

    /// RFC-4180: always quote, and double any embedded quote. Unconditional quoting because query
    /// text is arbitrary and a conditional rule is one missed character from a shifted column.
    private static func escapeCSV(_ text: String) -> String {
        "\"\(text.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}

// MARK: - QueryMethodAppendix.Row + scope

extension QueryMethodAppendix.Row {

    /// The scope as prose, or the raw key when it will not decode, or a stated absence.
    ///
    /// Three outcomes, never a fourth: this must not invent a scope for a row that recorded none.
    /// A pre-M-2 row has no signature at all, and saying "whole corpus" for it would assert
    /// something nobody recorded.
    ///
    /// - Parameters:
    ///   - resources: The host's data files, which name a subject (`SearchScopeSignature.describe(_:resources:locale:)`).
    ///   - locale: The locale that formats the scope's counts and lists.
    /// - Returns: The scope as prose.
    public func scopeProse(resources: IndexingResources, locale: Locale) -> String {
        guard let scopeSignature else {
            return String(localized: "appendix.scope.unrecorded", defaultValue: "not recorded")
        }
        var phrases = SearchScopeSignature.describe(scopeSignature, resources: resources, locale: locale)
            ?? [scopeSignature]
        if let workingCorpusName {
            phrases.insert(String(localized: "appendix.scope.corpus %@",
                                  defaultValue: "inside “\(workingCorpusName)”"), at: 0)
        }
        return phrases.joined(separator: "; ")
    }
}

// MARK: - RecordedCount + appendix rendering

extension RecordedSearch.RecordedCount {

    /// The count as a reader should see it — the one place a floor is stopped from passing as a
    /// total.
    ///
    /// - Parameter locale: The locale that groups the number (the app's `appendixDescription` passes
    ///   the reader's).
    /// - Returns: The count, in words where it is not a plain total.
    public func appendixDescription(locale: Locale) -> String {
        switch self {
        case let .exact(match, _):
            return match.formatted(.number.locale(locale))
        case let .floor(loaded, _):
            return String(localized: "appendix.count.floor %@",
                          defaultValue: "at least \(loaded.formatted(.number.locale(locale)))")
        case let .completeWithoutTotal(loaded):
            return loaded.formatted(.number.locale(locale))
        case let .unrecorded(reported):
            return String(localized: "appendix.count.unrecorded %@",
                          defaultValue: "\(reported.formatted(.number.locale(locale))) (as reported)")
        }
    }

    /// A stable, non-localized token for the CSV's `count_basis` column, so the distinction the
    /// prose makes survives into a spreadsheet where a reader will otherwise sum the column.
    public var basisToken: String {
        switch self {
        case .exact: "exact"
        case .floor: "floor"
        case .completeWithoutTotal: "complete"
        case .unrecorded: "unrecorded"
        }
    }

    /// The numeric columns, each empty where the case genuinely has no value — never zero, which a
    /// spreadsheet would treat as a measurement.
    public var csvNumbers: (match: String, loaded: String, limit: String, reported: String) {
        switch self {
        case let .exact(match, loaded): (String(match), String(loaded), "", "")
        case let .floor(loaded, limit): ("", String(loaded), String(limit), "")
        case let .completeWithoutTotal(loaded): (String(loaded), String(loaded), "", "")
        case let .unrecorded(reported): ("", "", "", String(reported))
        }
    }

    /// The number shown to a reader, for counting the zeros. A floor of zero is impossible, so
    /// every case has one.
    public var displayedTotal: Int {
        switch self {
        case let .exact(match, _): match
        case let .floor(loaded, _): loaded
        case let .completeWithoutTotal(loaded): loaded
        case let .unrecorded(reported): reported
        }
    }
}
