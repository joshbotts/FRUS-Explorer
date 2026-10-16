// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - TaxonomyOverlay

/// The tags this repository adds to the Office of the Historian's taxonomy, read after the Office's
/// own (decision 39 of the 2026-10-14 plan of record, #1622).
///
/// ## Why there is one
/// Volumes carry tags by slug in their TEI, and the app names a tag from the bundled taxonomy
/// (`VolumeLevelTagStore`). Four volumes carry `lgbtq-rights`, which neither of the Office's sources
/// gives: its taxonomy file holds the tag only inside a comment, and the page draws the file. So the
/// four volumes' tag had no name, and they were missing from a filter no control could reach. The
/// owner decided on 2026-10-15 that the tag joins the bundled taxonomy as "LGBTQ Rights" under
/// Topics, from a local overlay the generator reads after the Office's file.
///
/// ## What it may do
/// It **adds** a tag the source does not give, and nothing else. A slug the source gives is left as
/// the source gives it, and the run says that the overlay's entry for it is no longer needed. It
/// never stands for a taxonomy: a source with no tags is refused as before, whatever the overlay
/// holds. Each tag states why it is there (`Tag.reason`), and its parent must be a tag the written
/// file holds: a source that lacks it is passed over, as a source the gate refuses is, once the gate
/// has judged it (`TaxonomyGeneratorRunner`), so the next source is read.
///
/// ## The file
/// `TaxonomyGenerator/volume-tag-taxonomy-overlay.json` (``defaultPath``), committed beside the tool:
/// an object whose `tags` are the entries to add, each with the fields of `TagTaxonomyFileEntry` but
/// its description, and a `reason`. Any other key, such as the file's `about`, is for its readers.
///
/// Version history:
///   1.0 — #1622, decision 39: initial implementation
public enum TaxonomyOverlay {

    /// Where a run reads the overlay, relative to the project root, as
    /// `TaxonomyGeneratorRunner.defaultOutputPath` is.
    public static let defaultPath = "TaxonomyGenerator/volume-tag-taxonomy-overlay.json"

    /// One tag the overlay adds.
    public struct Tag: Codable, Sendable, Equatable {
        /// The tag's slug, as the volumes' TEI carry it.
        public let slug: String
        /// The name the app shows.
        public let displayName: String
        /// `people`, `places` or `topics`.
        public let category: String
        /// Its second-level grouping, as `TagTaxonomyFileEntry.subcategory`.
        public let subcategory: String
        /// The slug of its parent tag, which the written taxonomy must hold, or `nil` for none.
        public let parentSlug: String?
        /// Why the tag is added: whose decision, and what the Office's sources give for it.
        public let reason: String

        /// Creates a tag.
        public init(slug: String, displayName: String, category: String, subcategory: String,
                    parentSlug: String?, reason: String) {
            self.slug = slug
            self.displayName = displayName
            self.category = category
            self.subcategory = subcategory
            self.parentSlug = parentSlug
            self.reason = reason
        }

        /// The entry the taxonomy file holds for it. The overlay gives no description: the app
        /// shows none, and the one the Office's comment holds is not the Office's published text.
        public var fileEntry: TagTaxonomyFileEntry {
            TagTaxonomyFileEntry(slug: slug, displayName: displayName, category: category,
                                 subcategory: subcategory, parentSlug: parentSlug, description: nil)
        }
    }

    /// The overlay file's shape.
    private struct File: Decodable {
        let tags: [Tag]
    }

    /// Why an overlay was not read, or does not fit the taxonomy it is laid over. An overlay that cannot
    /// be read stops the run before any source is fetched; one that does not fit a source passes that
    /// source over. Nothing is written in either case.
    public enum Problem: Error, Equatable, Sendable, CustomStringConvertible {
        /// The file could not be read.
        case unreadable(path: String, reason: String)
        /// The file is not an overlay: not JSON, or no `tags` of the right shape.
        case malformed(path: String, reason: String)
        /// A tag has an empty slug, name, subcategory or reason.
        case incomplete(slug: String)
        /// A tag sits outside people, places and topics.
        case unknownCategory(slug: String, category: String)
        /// Two tags have one slug.
        case duplicateSlug(String)
        /// A tag's parent is a slug the written taxonomy would not hold. The run passes over the source
        /// that gave that taxonomy, as it does one the gate refuses.
        case missingParent(slug: String, parentSlug: String)

        /// What the run prints.
        public var description: String {
            switch self {
            case .unreadable(let path, let reason):
                return "the overlay \(path) could not be read (\(reason))."
            case .malformed(let path, let reason):
                return "the overlay \(path) is not a list of tags (\(reason))."
            case .incomplete(let slug):
                return "the overlay's tag \"\(slug)\" lacks a slug, a name, a subcategory or the reason it is there."
            case .unknownCategory(let slug, let category):
                return "the overlay's tag \"\(slug)\" is under \"\(category)\", which is not people, places or topics."
            case .duplicateSlug(let slug):
                return "the overlay names \"\(slug)\" twice."
            case .missingParent(let slug, let parentSlug):
                return "the overlay's tag \"\(slug)\" has the parent \"\(parentSlug)\", which the taxonomy does not hold."
            }
        }
    }

    /// What laying the overlay over a source's entries gave.
    public struct Applied: Sendable, Equatable {
        /// The source's entries, in its order, then each tag the overlay added, in the overlay's order.
        public let entries: [TagTaxonomyFileEntry]
        /// The slugs the overlay added.
        public let added: [String]
        /// The overlay's slugs the source already gives, so their entries were not used.
        public let alreadyInSource: [String]
    }

    /// Reads and checks the overlay at `path`.
    ///
    /// - Throws: ``Problem`` when the file cannot be read, is not an overlay, or holds a tag that is
    ///   incomplete, outside the three categories, or named twice.
    public static func load(from path: String) throws -> [Tag] {
        guard let data = FileManager.default.contents(atPath: path) else {
            throw Problem.unreadable(path: path, reason: "no file there")
        }
        return try decode(data, path: path)
    }

    /// Checks an overlay's bytes; `path` names it in a problem.
    ///
    /// - Throws: ``Problem``, as ``load(from:)``.
    public static func decode(_ data: Data, path: String) throws -> [Tag] {
        let tags: [Tag]
        do {
            tags = try JSONDecoder().decode(File.self, from: data).tags
        } catch {
            throw Problem.malformed(path: path, reason: "\(error)")
        }
        var seen: Set<String> = []
        for tag in tags {
            let required = [tag.slug, tag.displayName, tag.subcategory, tag.reason]
            guard required.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                throw Problem.incomplete(slug: tag.slug)
            }
            guard TaxonomyGate.categories.contains(tag.category) else {
                throw Problem.unknownCategory(slug: tag.slug, category: tag.category)
            }
            guard seen.insert(tag.slug).inserted else { throw Problem.duplicateSlug(tag.slug) }
        }
        return tags
    }

    /// Lays `overlay` over a source's `entries`: each tag whose slug the source does not give is
    /// added after them; one it gives is left as the source gives it. Pure. Whether each added tag's
    /// parent is held is ``misfit(of:from:)``'s to say, after the gate has judged the result.
    public static func apply(_ overlay: [Tag], to entries: [TagTaxonomyFileEntry]) -> Applied {
        let given = Set(entries.map(\.slug))
        let adding = overlay.filter { !given.contains($0.slug) }
        return Applied(entries: entries + adding.map(\.fileEntry),
                       added: adding.map(\.slug),
                       alreadyInSource: overlay.map(\.slug).filter { given.contains($0) })
    }

    /// Why `applied` does not fit, or `nil` when it does: the first tag the overlay added whose parent
    /// the result does not hold. Pure.
    ///
    /// - Parameters:
    ///   - applied: What ``apply(_:to:)`` gave.
    ///   - overlay: The overlay it was given.
    public static func misfit(of applied: Applied, from overlay: [Tag]) -> Problem? {
        let held = Set(applied.entries.map(\.slug))
        let added = Set(applied.added)
        for tag in overlay where added.contains(tag.slug) {
            if let parent = tag.parentSlug, !held.contains(parent) {
                return .missingParent(slug: tag.slug, parentSlug: parent)
            }
        }
        return nil
    }
}
