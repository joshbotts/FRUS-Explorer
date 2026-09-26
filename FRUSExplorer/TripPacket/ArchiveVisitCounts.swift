// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ArchiveVisitCounts

/// A plan's two summary counts, worded once for the plan editor and the plans list (#1374), and
/// the repository sections the editor draws them over (#1458).
///
/// The list row read "8 targets · 1 repositories" and the editor "8 targets across
/// 1 repositories." while the trip packet built from the same plan said "1 repository"
/// (`TripPacketExporter` branches on the count itself). Both screens now take these, which group
/// and singularise through `CountCopy`.
///
/// Version history:
///   1.0 — 2026-09-25: #1374
///   1.1 — 2026-09-25: #1458 — the editor's sections, its summary line and the list row's summary
///          move here and count repositories by one rule, presidential libraries included
enum ArchiveVisitCounts {

    /// "1 target" / "N targets".
    ///
    /// - Parameter count: How many research targets the plan derives.
    /// - Returns: The phrase.
    static func targets(_ count: Int) -> String {
        CountCopy.phrase(count,
                         one: String(localized: "archiveVisit.count.targets.one", defaultValue: "%@ target"),
                         many: String(localized: "archiveVisit.count.targets.many", defaultValue: "%@ targets"))
    }

    /// "1 repository" / "N repositories".
    ///
    /// - Parameter count: How many distinct repositories hold those targets.
    /// - Returns: The phrase.
    static func repositories(_ count: Int) -> String {
        CountCopy.phrase(count,
                         one: String(localized: "archiveVisit.count.repositories.one",
                                     defaultValue: "%@ repository"),
                         many: String(localized: "archiveVisit.count.repositories.many",
                                      defaultValue: "%@ repositories"))
    }

    // MARK: - Repository sections (#1458)
    //
    // The editor's sections, its summary and the list row used to read two rules: the sections
    // fell back to a target's curated row (`facts?.displayName`) while both counts read
    // `facility.chapterHeading`, which was nil for every presidential library — so a plan read
    // "6 targets across 1 repository." above three repository sections. The fallback now lives in
    // `ResearchFacilityResolver`, and everything here reads `chapterHeading` alone, through
    // `TripPacketModel.repositoryNames(of:)`, the function the packet's header counts with too.

    /// The heading of the Targets list's group for targets no repository can serve. It is a
    /// section, never a repository: nothing here counts it.
    static var unplacedSectionHeading: String {
        String(localized: "archiveVisit.section.unplaced", defaultValue: "Confirm before you travel")
    }

    /// The Targets-list section a target is drawn under: its repository, or the unplaced group.
    ///
    /// - Parameter target: A derived research target.
    /// - Returns: The section heading.
    static func sectionHeading(for target: TripPacketModel.Target) -> String {
        target.facility.chapterHeading ?? unplacedSectionHeading
    }

    /// The Targets list's sections, in drawing order: every repository once, in the model's
    /// facility order, then the unplaced group when any target falls in it.
    ///
    /// - Parameter targets: The plan's derived targets.
    /// - Returns: The section headings.
    static func sectionHeadings(of targets: [TripPacketModel.Target]) -> [String] {
        let repositories = TripPacketModel.repositoryNames(of: targets)
        guard targets.contains(where: { $0.facility.chapterHeading == nil }) else {
            return repositories
        }
        return repositories + [unplacedSectionHeading]
    }

    /// How many repositories hold a plan's targets — the repository sections the editor draws,
    /// excluded targets included. The packet's header counts the same rule over the targets the
    /// export includes (`TripPacketExporter.includedRepositories`), so the two differ only by a
    /// repository whose every target is excluded — see `TripPacketModel.repositoryNames(of:)`.
    ///
    /// - Parameter model: The derived plan.
    /// - Returns: The count.
    static func repositoryCount(of model: TripPacketModel) -> Int {
        model.repositoryNames.count
    }

    /// The plan editor's summary line: "6 targets across 3 repositories."
    ///
    /// - Parameter model: The derived plan.
    /// - Returns: The line.
    static func editorSummary(of model: TripPacketModel) -> String {
        let targets = model.targets.count
        let repositories = repositoryCount(of: model)
        return String(localized: "archiveVisit.editor.summary.v3",
                      defaultValue: "\(ArchiveVisitCounts.targets(targets)) across \(ArchiveVisitCounts.repositories(repositories)).")
    }

    /// The Archives Visits list row's summary: "6 targets · 3 repositories".
    ///
    /// - Parameter model: The derived plan.
    /// - Returns: The phrase.
    static func listSummary(of model: TripPacketModel) -> String {
        let targets = model.targets.count
        let repositories = repositoryCount(of: model)
        return String(format: String(
            localized: "archiveVisit.list.summary %@ %@",
            defaultValue: "%1$@ · %2$@"),
            ArchiveVisitCounts.targets(targets), ArchiveVisitCounts.repositories(repositories))
    }
}
