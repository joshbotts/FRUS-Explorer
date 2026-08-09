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
/// an assertion; "I searched for X on this date, over these 552 volumes, with these fields, and it
/// returned 0" is evidence. This type is the second half of that promise. The trail has been in
/// the JSON export since Wave R-5; JSON is not a methods section.
///
/// ## The one thing it must not do
/// **Never print a floor as if it were a count.** A macOS search that loaded 7,500 rows against a
/// 7,500-row ceiling did not find 7,500 documents; it found *at least* 7,500. Every count here is
/// routed through ``SearchHistoryEntry/RecordedCount``, which distinguishes the four cases the
/// trail can actually be in, and each renders differently. The `count_basis` CSV column exists so
/// that distinction survives a spreadsheet, where a reader will otherwise sum the column.
///
/// Rows written before M-2 recorded only a headline number and no capture detail. They are printed
/// — dropping them would silently shorten the log — but marked, so a reader is never invited to
/// treat them as equivalent to the rows that carry their own provenance.
///
/// ## Two formats, one preamble
/// Markdown for reading and pasting into a paper; CSV for a spreadsheet. Both open with the same
/// `#`-prefixed preamble, following ``AnalyticsProvenance``: the method travels *with* the numbers
/// rather than in a sidecar that gets separated from them.
///
/// Version history:
///   1.0 — M-2 commit 3: initial implementation
struct QueryMethodAppendix: Sendable, Equatable {

    /// One recorded search, already resolved against the models it points at.
    struct Row: Sendable, Equatable {

        /// When the search ran. `nil` on rows migrated from the retired `SessionEvent`.
        var executedAt: Date?

        /// The submitted query, trimmed.
        var queryText: String

        /// How the count should be read. The honesty of the whole document rests here.
        var count: SearchHistoryEntry.RecordedCount

        /// The canonical scope key as recorded, printed verbatim in the CSV.
        var scopeSignature: String?

        /// How many volumes the device had indexed — the denominator. `nil` on pre-M-2 rows.
        var indexedVolumeCount: Int?

        /// The name of the working corpus the search ran inside, resolved at export time. `nil`
        /// when no corpus was applied *or* the corpus has since been deleted; the appendix cannot
        /// tell those apart and does not claim to.
        var workingCorpusName: String?

        /// The FTS5 expression the query compiled to. Printed in the CSV only — it is the answer
        /// to "what did the app actually search for", which prose cannot give.
        var renderedExpression: String?

        /// The id of the project active at execution, if any.
        var projectId: UUID?
    }

    /// The active project's name at export time, heading the appendix exactly as it heads a
    /// collection export (#454/#455, Q&CA §I-2).
    var projectName: String?

    /// That project's research question, if set.
    var researchQuestion: String?

    /// When this appendix was generated.
    var generatedAt: Date

    /// Every recorded search, oldest first.
    var rows: [Row]

    // MARK: - Construction

    /// Builds an appendix from the stored trail.
    ///
    /// - Parameters:
    ///   - searches: the recorded searches, in any order — this sorts them oldest first, putting
    ///     undated rows (migrated `SessionEvent`s) at the end rather than at an invented time.
    ///   - corpusNames: working-corpus names by id, for the rows that carry one.
    ///   - projectName: the active project's name, or `nil` in global context.
    ///   - researchQuestion: that project's research question, if set.
    ///   - generatedAt: the export timestamp.
    static func make(searches: [SearchHistoryEntry],
                     corpusNames: [UUID: String],
                     projectName: String?,
                     researchQuestion: String?,
                     generatedAt: Date) -> QueryMethodAppendix {
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
                    renderedExpression: entry.renderedExpression,
                    projectId: entry.projectId)
            })
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
    func scoped(toProject projectId: UUID?) -> QueryMethodAppendix {
        var scoped = self
        scoped.rows = projectId.map { id in rows.filter { $0.projectId == id } } ?? []
        return scoped
    }

    // MARK: - Derived facts

    /// Rows written before M-2, which carry a headline number and no capture detail.
    var unrecordedRowCount: Int {
        rows.filter { if case .unrecorded = $0.count { return true } else { return false } }.count
    }

    /// Rows whose count is a floor rather than a total — the ones a reader must not sum.
    var floorRowCount: Int {
        rows.filter { if case .floor = $0.count { return true } else { return false } }.count
    }

    /// Rows that returned nothing. Named in the preamble because a zero is the appendix's whole
    /// reason for existing and a reader scanning a long table will not count them.
    var zeroResultRowCount: Int {
        rows.filter { $0.count.displayedTotal == 0 }.count
    }

    // MARK: - Markdown

    /// The appendix as Markdown — a preamble, a table, and the caveats that apply to *this* log.
    var markdown: String {
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
                     + ":** \(Self.appCredit), \(formattedGeneratedAt)")
        lines.append("**" + String(localized: "appendix.field.searches", defaultValue: "Searches")
                     + ":** \(rows.count.formatted())")
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
                row.executedAt.map(Self.tableDate) ?? "—",
                Self.escapeMarkdownCell(row.queryText),
                Self.escapeMarkdownCell(row.count.appendixDescription),
                row.indexedVolumeCount?.formatted() ?? "—",
                Self.escapeMarkdownCell(row.scopeProse)
            ].joined(separator: " | ") + " |")
        }
        lines.append("")
        lines.append("## " + String(localized: "appendix.method.heading",
                                    defaultValue: "How to read this table"))
        for caveat in caveats { lines.append("- \(caveat)") }
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
    var plainTextLines: [String] {
        var lines = [String(localized: "appendix.title", defaultValue: "Query log — method appendix")]
        for caveat in caveats { lines.append("— \(caveat)") }
        lines.append("")
        for row in rows {
            var parts = [row.executedAt.map(Self.tableDate) ?? "—", "“\(row.queryText)”"]
            parts.append(String(localized: "appendix.line.results %@",
                                defaultValue: "\(row.count.appendixDescription) results"))
            if let indexed = row.indexedVolumeCount {
                parts.append(String(localized: "appendix.line.indexed %lld",
                                    defaultValue: "\(indexed) volumes indexed"))
            }
            parts.append(row.scopeProse)
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
    var csv: String {
        var lines = preambleLines.map { $0.isEmpty ? "#" : "# \($0)" }
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

    /// The header facts, shared by both formats.
    private var preambleLines: [String] {
        var lines: [String] = []
        lines.append(String(localized: "appendix.title", defaultValue: "Query log — method appendix"))
        lines.append("")
        if let projectName {
            lines.append("\(String(localized: "appendix.field.project", defaultValue: "Project")): \(projectName)")
        }
        if let researchQuestion {
            lines.append("\(String(localized: "appendix.field.question", defaultValue: "Research question")): \(researchQuestion)")
        }
        lines.append("\(String(localized: "appendix.field.generated", defaultValue: "Generated")): \(Self.appCredit), \(formattedGeneratedAt)")
        lines.append("\(String(localized: "appendix.field.searches", defaultValue: "Searches")): \(rows.count.formatted())")
        lines.append("")
        lines.append(String(localized: "appendix.method.heading", defaultValue: "How to read this table"))
        for caveat in caveats { lines.append(caveat) }
        lines.append("")
        lines.append(Self.corpusAttribution)
        return lines
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
    private var caveats: [String] {
        var caveats: [String] = [
            String(localized: "appendix.caveat.snapshot",
                   defaultValue: "Each count is what the search returned when it ran, over the volumes downloaded to that device at that moment. It is not re-run, and it will not match a search run today against a larger index.")
        ]
        if zeroResultRowCount > 0 {
            caveats.append(zeroResultRowCount == 1
                ? String(localized: "appendix.caveat.zero.one",
                         defaultValue: "One of these searches returned nothing. A zero is a finding: it means the term is absent from the volumes indexed at the time, not that it is absent from the FRUS series.")
                : String(localized: "appendix.caveat.zero.many %lld",
                         defaultValue: "\(zeroResultRowCount) of these searches returned nothing. A zero is a finding: it means the term is absent from the volumes indexed at the time, not that it is absent from the FRUS series."))
        }
        if floorRowCount > 0 {
            caveats.append(floorRowCount == 1
                ? String(localized: "appendix.caveat.floor.one",
                         defaultValue: "One search hit the app's row ceiling. Its count is shown as \"at least N\" and is a floor, not a total — do not sum it with the others.")
                : String(localized: "appendix.caveat.floor.many %lld",
                         defaultValue: "\(floorRowCount) searches hit the app's row ceiling. Those counts are shown as \"at least N\" and are floors, not totals — do not sum them."))
        }
        if unrecordedRowCount > 0 {
            caveats.append(unrecordedRowCount == 1
                ? String(localized: "appendix.caveat.unrecorded.one",
                         defaultValue: "One search predates this app version. It saved only a result count — not the scope, the row ceiling, or how many volumes were indexed. It is marked \"as reported\" and cannot be checked against the others.")
                : String(localized: "appendix.caveat.unrecorded.many %lld",
                         defaultValue: "\(unrecordedRowCount) searches predate this app version. They saved only a result count — not the scope, the row ceiling, or how many volumes were indexed. They are marked \"as reported\" and cannot be checked against the others."))
        }
        return caveats
    }

    /// The generation date, spelled out.
    private var formattedGeneratedAt: String {
        generatedAt.formatted(date: .long, time: .shortened)
    }

    // MARK: - Constants and escaping

    /// The wordmark + version, matching `AnalyticsProvenance.appCredit`.
    private static var appCredit: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return "FRUS Explorer \(version ?? "")".trimmingCharacters(in: .whitespaces)
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

    /// Localized, for the human-readable table.
    private static func tableDate(_ date: Date) -> String {
        date.formatted(date: .numeric, time: .shortened)
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
    var scopeProse: String {
        guard let scopeSignature else {
            return String(localized: "appendix.scope.unrecorded", defaultValue: "not recorded")
        }
        var phrases = SearchScopeSignature.describe(scopeSignature) ?? [scopeSignature]
        if let workingCorpusName {
            phrases.insert(String(localized: "appendix.scope.corpus %@",
                                  defaultValue: "inside “\(workingCorpusName)”"), at: 0)
        }
        return phrases.joined(separator: "; ")
    }
}

// MARK: - RecordedCount + appendix rendering

extension SearchHistoryEntry.RecordedCount {

    /// The count as a reader should see it — the one place a floor is stopped from passing as a
    /// total.
    var appendixDescription: String {
        switch self {
        case let .exact(match, _):
            return match.formatted()
        case let .floor(loaded, _):
            return String(localized: "appendix.count.floor %@",
                          defaultValue: "at least \(loaded.formatted())")
        case let .completeWithoutTotal(loaded):
            return loaded.formatted()
        case let .unrecorded(reported):
            return String(localized: "appendix.count.unrecorded %@",
                          defaultValue: "\(reported.formatted()) (as reported)")
        }
    }

    /// A stable, non-localized token for the CSV's `count_basis` column, so the distinction the
    /// prose makes survives into a spreadsheet where a reader will otherwise sum the column.
    var basisToken: String {
        switch self {
        case .exact: "exact"
        case .floor: "floor"
        case .completeWithoutTotal: "complete"
        case .unrecorded: "unrecorded"
        }
    }

    /// The numeric columns, each empty where the case genuinely has no value — never zero, which a
    /// spreadsheet would treat as a measurement.
    var csvNumbers: (match: String, loaded: String, limit: String, reported: String) {
        switch self {
        case let .exact(match, loaded): (String(match), String(loaded), "", "")
        case let .floor(loaded, limit): ("", String(loaded), String(limit), "")
        case let .completeWithoutTotal(loaded): (String(loaded), String(loaded), "", "")
        case let .unrecorded(reported): ("", "", "", String(reported))
        }
    }

    /// The number shown to a reader, for counting the zeros. A floor of zero is impossible, so
    /// every case has one.
    var displayedTotal: Int {
        switch self {
        case let .exact(match, _): match
        case let .floor(loaded, _): loaded
        case let .completeWithoutTotal(loaded): loaded
        case let .unrecorded(reported): reported
        }
    }
}
