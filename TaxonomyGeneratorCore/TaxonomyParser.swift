// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Parses the `history.state.gov/tags/all` HTML page into a flat array of `RawTaxonomyEntry`.
///
/// ## Actual Page Structure
///
/// The page renders tags as a recursively nested `<ul class="hsg-tag-list">` tree:
///
/// ```html
/// <ul class="hsg-tag-list">
///   <li><a href="/tags/people">People</a>            ← depth 1 (category, skipped as entry)
///     <ul class="hsg-tag-list">
///       <li><a href="/tags/presidents">Presidents</a> ← depth 2 (subcategory)
///         <ul class="hsg-tag-list">
///           <li><a href="/tags/reagan-ronald">Reagan, Ronald</a></li>  ← depth 3 (leaf)
///         </ul>
///       </li>
///     </ul>
///   </li>
///   <li><a href="/tags/places">Places</a>            ← depth 1 (category)
///     <ul class="hsg-tag-list">
///       <li><a href="/tags/sovereign-territories">…</a>  ← depth 2 (structural, not a real tag)
///         <ul class="hsg-tag-list">
///           <li><a href="/tags/sub-saharan-africa">…</a>  ← depth 3 (subcategory for places)
///             <ul class="hsg-tag-list">
///               <li><a href="/tags/angola">Angola</a></li>  ← depth 4 (leaf)
///             </ul>
///           </li>
///         </ul>
///       </li>
///     </ul>
///   </li>
/// </ul>
/// ```
///
/// Subcategory assignment rules:
/// - depth-2 entries (presidents, sovereign-territories, arms-control-and-disarmament):
///   subcategory = own slug; parentSlug = nil
/// - depth-3 entries whose parent is a structural node (sovereign-territories,
///   dependencies-and-areas-of-special-sovereignty): subcategory = own slug; parentSlug = parent
/// - depth-3 entries otherwise (individual people, individual topics): subcategory = parent slug
/// - depth-4 entries (individual countries): subcategory = parent slug (the regional grouping)
///
/// Version history:
///   1.0 — Session 02: initial implementation (h2/h3 approach)
///   1.1 — Session 02: rewritten for actual nested ul.hsg-tag-list structure
public struct TaxonomyParser {

    private init() {}

    // Slugs used only for structural grouping in Places — not real content tags.
    // Entries whose parent is one of these are treated as subcategory roots, not leaves.
    private static let structuralSlugs = Set([
        "sovereign-territories",
        "dependencies-and-areas-of-special-sovereignty",
    ])

    // Top-level category slugs. Entries at this depth are skipped as tag records but
    // set the `currentCategory` context for all descendants.
    private static let categorySlugs = Set(["people", "places", "topics"])

    /// Parses the tags/all HTML page into a flat list of taxonomy entries.
    ///
    /// - Parameter html: The full HTML content of `history.state.gov/tags/all`.
    /// - Returns: All individual and subcategory tags, preserving hierarchy via
    ///   `category`, `subcategory`, and `parentSlug` fields.
    public static func parse(html: String) -> [RawTaxonomyEntry] {
        var entries: [RawTaxonomyEntry] = []

        // parentSlugStack[i] = the slug of the tag entry that opened the UL at depth i+1.
        // Empty string means this UL was opened by a category node (people/places/topics).
        var parentSlugStack: [String] = []
        var depth = 0
        var lastSlug = ""         // most recently seen /tags/ slug at any depth
        var currentCategory = ""

        struct Pending {
            var slug: String
            var displayName: String
            var description: String?
        }
        var pending: Pending?

        // Flush pending entry into `entries` using the current depth and parent stack.
        func flush(depth currentDepth: Int) {
            guard let p = pending else { return }
            pending = nil

            if currentDepth <= 1 {
                // Category node — update context but don't record as a tag entry.
                if categorySlugs.contains(p.slug) {
                    currentCategory = p.slug
                }
                return
            }

            let parentSlug: String? = parentSlugStack.last.map { $0.isEmpty ? nil : $0 } ?? nil
            let isParentCategory = parentSlug == nil || parentSlug.map { categorySlugs.contains($0) } == true
            let isParentStructural = parentSlug.map { structuralSlugs.contains($0) } ?? false

            let subcategory: String
            if isParentCategory || isParentStructural {
                // This entry IS the subcategory (or is directly below a structural intermediate).
                subcategory = p.slug
            } else {
                // This entry is a leaf under a real subcategory.
                subcategory = parentSlug ?? p.slug
            }

            entries.append(RawTaxonomyEntry(
                slug: p.slug,
                displayName: p.displayName,
                category: currentCategory,
                subcategory: subcategory,
                // Don't record the category node as parentSlug — it isn't a tag itself.
                parentSlug: isParentCategory ? nil : parentSlug,
                description: p.description
            ))
        }

        // Token-based scan. We look for four token types:
        //   <ul class="hsg-tag-list">   — UL open
        //   </ul>                       — UL close
        //   href="/tags/SLUG">NAME</a>  — tag entry
        //   <span class="hsg-font-italic">DESC</span>  — optional description for previous entry
        var i = html.startIndex

        while i < html.endIndex {
            let rest = html[i...]

            if rest.hasPrefix("<ul class=\"hsg-tag-list\">") {
                flush(depth: depth)
                depth += 1
                // The most recently seen slug becomes the parent for entries at this new depth.
                parentSlugStack.append(lastSlug)
                i = html.index(i, offsetBy: 25)

            } else if rest.hasPrefix("</ul>") {
                // Only decrement depth for ULs we actually opened. Navigation HTML
                // contains </ul> closers for non-hsg-tag-list lists that appear
                // before the taxonomy section; clamping prevents depth going negative.
                if depth > 0 {
                    flush(depth: depth)
                    if !parentSlugStack.isEmpty { parentSlugStack.removeLast() }
                    depth -= 1
                }
                i = html.index(i, offsetBy: 5)

            } else if rest.hasPrefix("href=\"/tags/") {
                flush(depth: depth)
                // Extract slug: href="/tags/SLUG"
                let slugStart = html.index(i, offsetBy: 12)
                guard let quoteIdx = html[slugStart...].firstIndex(of: "\"") else {
                    i = html.index(after: i); continue
                }
                let slug = String(html[slugStart..<quoteIdx])

                // Advance past the closing `>` of the `<a>` tag.
                guard let closeAngle = html[quoteIdx...].firstIndex(of: ">") else {
                    i = html.index(after: i); continue
                }
                let nameStart = html.index(after: closeAngle)

                // Extract display name: text before the next `<`
                guard let nameEndIdx = html[nameStart...].firstIndex(of: "<") else {
                    i = html.index(after: i); continue
                }
                let displayName = String(html[nameStart..<nameEndIdx])
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                lastSlug = slug
                pending = Pending(slug: slug, displayName: displayName, description: nil)
                i = nameEndIdx

            } else if rest.hasPrefix("<span class=\"hsg-font-italic\">") {
                // Optional description immediately following a tag entry's </a>.
                let spanOpen = "<span class=\"hsg-font-italic\">"
                let spanClose = "</span>"
                let contentStart = html.index(i, offsetBy: spanOpen.count)
                if let endIdx = html[contentStart...].range(of: spanClose) {
                    let raw = String(html[contentStart..<endIdx.lowerBound])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !raw.isEmpty {
                        pending?.description = raw
                    }
                    i = endIdx.upperBound
                } else {
                    i = html.index(after: i)
                }

            } else {
                i = html.index(after: i)
            }
        }

        flush(depth: depth)
        return entries
    }

    /// Converts a display string to a URL-style slug: lowercase, non-alphanumeric → hyphens.
    static func slugify(_ string: String) -> String {
        string
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }
}
