// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - Reader rendering
//
// How the reader turns a parsed document into its page: the lookups `DocumentViewModel.load` builds
// for the converter, and the serializer settings `HTMLTemplate.build` writes the page with. Both
// lived in those two files, which import SwiftData and SwiftUI. They live here so FRUS Explorer
// Light, the web edition, renders a document through the same code instead of a copy of it: what
// the app chooses — where persons and terms come from, the classification override, the bundled
// broken-refs index — stays the caller's, and is passed in.

/// The persons and glossary terms a document's links are resolved against, keyed as the reader
/// looks them up.
///
/// Version history:
///   1.0 — FRUSCoreKit, part 1: moved from `DocumentViewModel.load`
public struct ReaderLookups: Sendable {

    /// Persons by their `xml:id` ref. A ref listed twice keeps its last entry.
    public let personsByRef: [String: PersonEntry]

    /// Glossary terms by their `xml:id` ref. A ref listed twice keeps its last entry.
    public let termsByRef: [String: GlossEntry]

    /// Glossary terms by their term text, lowercased, so an `<abbr>` with no `@ref` still renders
    /// as a link when its text names a term. A term listed twice keeps its last entry.
    public let termsByText: [String: GlossEntry]

    /// Keys `persons` and `terms` for the reader, in the order given.
    public init(persons: [PersonEntry], terms: [GlossEntry]) {
        var pByRef: [String: PersonEntry] = [:]
        for p in persons { pByRef[p.ref] = p }
        var tByRef:  [String: GlossEntry] = [:]
        var tByText: [String: GlossEntry] = [:]
        for t in terms {
            tByRef[t.ref]              = t
            tByText[t.term.lowercased()] = t
        }
        personsByRef = pByRef
        termsByRef   = tByRef
        termsByText  = tByText
    }
}

extension ASTToRenderNodeConverter {

    /// The converter the reader renders a document of `volumeId` with.
    ///
    /// Persons and glossary terms resolve by ref through `lookups`, and `abbrLookup` matches
    /// `<abbr>` element text against the glossary by term name (case-insensitive), so
    /// abbreviations without an explicit `@ref` still render as tappable dotted-underline links.
    /// Dead cross-references are degraded through `brokenRefs` (issue #240). That lookup is
    /// volume-scoped: brokenness is independent of the source document, so front- and
    /// back-matter refs resolve too. A `nil` index degrades nothing.
    ///
    /// - Parameters:
    ///   - volumeId: The volume the document belongs to.
    ///   - lookups: The volume's persons and glossary terms.
    ///   - brokenRefs: The broken-refs index; the app passes its bundled copy.
    public init(readerOf volumeId: String, lookups: ReaderLookups, brokenRefs: BrokenRefsIndex?) {
        self.init(
            volumeId: volumeId,
            personLookup: { [pByRef = lookups.personsByRef] ref in pByRef[ref] },
            glossLookup:  { [tByRef = lookups.termsByRef] ref in tByRef[ref] },
            abbrLookup:   { [tByText = lookups.termsByText] text in tByText[text.lowercased()] },
            brokenRefLookup: { [brokenRefs] target in
                brokenRefs?.degradableInfo(sourceVolume: volumeId, rawTarget: target)
            }
        )
    }
}

extension FRUSRenderNodeHTMLSerializer {

    /// The serializer the reader's page is written with.
    ///
    /// Reading views opt into classification chips on source footnotes (Source Explorer Phase 5);
    /// exports construct their own serializer with the default (off), so exported output is
    /// unchanged. The reader names each figure's image by a `frusexplorer://figure/` URL (#1516),
    /// which the app's `FRUSURLSchemeHandler` answers from the device's figure store.
    public static var reader: FRUSRenderNodeHTMLSerializer {
        FRUSRenderNodeHTMLSerializer(annotateSourceClassification: true, figureImages: .reader)
    }

    /// The reader's serializer for a host outside the app, which names each figure's image by
    /// `figureURL`, the address it serves the image at, in place of the app's `frusexplorer://figure/`
    /// URL. Everything else is ``reader``'s, so with `FRUSURLScheme.figureURL(for:)` it writes
    /// ``reader``'s bytes.
    public static func reader(
        figureURL: @escaping @Sendable (FigureImageName) -> URL?
    ) -> FRUSRenderNodeHTMLSerializer {
        FRUSRenderNodeHTMLSerializer(annotateSourceClassification: true, figureImages: .linked(url: figureURL))
    }
}
