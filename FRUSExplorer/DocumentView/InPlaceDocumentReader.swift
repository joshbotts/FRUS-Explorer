// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - InPlaceReading

/// The rules an in-place reader follows, stated over the READING CHAIN its host owns.
///
/// A host that reads documents in place keeps one array: the document opened from its list, then each
/// document a cross-reference pushed on top of it. Every reader in the chain edits that array rather than
/// state of its own, and that is what lets a reading position outlive the views showing it. On iPad,
/// Research swaps a stack for a two-pane layout as its width crosses 820 pt, which rebuilds every view
/// pushed on it; a position held in those views — this reader's first version — was lost with them.
///
/// Version history:
///   1.0 — 2026-09-11: initial implementation
///   1.1 — 2026-09-11: the chain moved out of each reader into its host, after review found the iPad
///          layout swap discarding it
enum InPlaceReading {

    /// Applies a jump taken by the reader at `level` to the chain.
    ///
    /// It is ``DocumentJump/apply(to:appending:)`` — the rule Browse, Search and the reader sheets route
    /// through — over the part of the chain the reader stands on: its own level and everything beneath.
    /// A cross-reference (`.push`) keeps the document and pushes its target, so Back returns to the
    /// document the link was in; a page-turn (`.replace`) swaps the document at this level, so however far
    /// the reader pages, one Back still leaves. Levels above `level` are dropped first: only the top reader
    /// can take a jump, and a chain that disagreed would push onto a level nobody can see.
    ///
    /// - Parameters:
    ///   - jump: What the reader did — followed a reference, or turned the page.
    ///   - chain: The host's reading chain.
    ///   - level: The position in `chain` of the reader that jumped.
    ///   - target: The document the jump leads to.
    static func apply(_ jump: DocumentJump, to chain: inout [DocumentBrowserEntry],
                      at level: Int, target: DocumentBrowserEntry) {
        var visible = Array(chain.prefix(level + 1))
        jump.apply(to: &visible, appending: target)
        chain = visible
    }

    /// Whether a reader stands above `level` — pass `-1` for the host's own view.
    ///
    /// - Parameters:
    ///   - level: A position in the chain, or `-1` for the host.
    ///   - chain: The host's reading chain.
    /// - Returns: `true` while the chain reaches past `level`.
    static func isPresenting(above level: Int, in chain: [DocumentBrowserEntry]) -> Bool {
        chain.count > level + 1
    }

    /// Drops every level above `level` — what Back, or a swipe back, does to the chain.
    ///
    /// - Parameters:
    ///   - level: The level that stays on top, or `-1` to close the reader entirely.
    ///   - chain: The host's reading chain.
    static func dismiss(above level: Int, in chain: inout [DocumentBrowserEntry]) {
        guard chain.count > level + 1 else { return }
        chain.removeSubrange((level + 1)...)
    }
}

#if os(iOS)

extension InPlaceReading {

    /// The presentation of the reader above `level`: shown while the chain reaches it, and setting it
    /// false — Back — drops that reader and every one above it.
    ///
    /// - Parameters:
    ///   - level: The level presenting, or `-1` for the host.
    ///   - chain: The host's reading chain.
    /// - Returns: A binding for `navigationDestination(isPresented:)`.
    static func presentation(above level: Int,
                             in chain: Binding<[DocumentBrowserEntry]>) -> Binding<Bool> {
        Binding(get: { isPresenting(above: level, in: chain.wrappedValue) },
                set: { if !$0 { dismiss(above: level, in: &chain.wrappedValue) } })
    }
}

// MARK: - InPlaceDocumentReader

/// A document reader that reads INSIDE whatever navigation stack pushed it, so a reader stays in the
/// tab they are working in and Back returns to the place they opened the document from.
///
/// Used where a document is opened from a tab that has no document case on its path: Research and
/// its History, a collection in the Collections tab, Project Home reached through Settings, and the
/// Archives Visit editor's sheets. Before this, every one of them handed the document to the Browse
/// tab, and Back then unwound Browse's history rather than returning to the list the reader had come
/// from (audit M-16; the owner reopened O-3 on 2026-09-11 with exactly that report).
///
/// ## Why a self-contained reader rather than a document case on each stack's path
/// Browse and Search push documents onto a typed path, and that is the better shape where it exists.
/// It does not exist in the places this serves. Research's path is a one-deep projection of its
/// selection — the iPadOS `.sidebarAdaptable` workaround of #238 and #272, whose regression history is
/// what O-3 cited when it first declined this change — and the iPad two-pane Research has no path at
/// all (#915). Collections and Settings navigate with state-driven destinations on path-less stacks,
/// where a path element appended beneath a state-driven push would land underneath it, out of sight.
///
/// This reader needs none of those paths. Each level is pushed by a state-driven destination — the
/// first declared on the view the reader is looking at (``SwiftUICore/View/inPlaceReader(_:)``), each
/// later one by the reader beneath it — and the documents themselves live in an array the host owns, so
/// the stack is never asked to hold a type it was not built for.
///
/// ## Jumps
/// A reader shows one level of its host's chain and edits the chain rather than itself:
/// ``InPlaceReading/apply(_:to:at:target:)`` decides, so a cross-reference presents the next level and a
/// page-turn replaces this one. `.id(entry)` gives each document a fresh `DocumentView`, the way a new
/// path element would.
///
/// Version history:
///   1.0 — 2026-09-11: initial implementation
///   1.1 — 2026-09-11: reads one level of the host's chain (see `InPlaceReading`), and keeps the
///          "Working on:" subtitle Browse's and Search's readers show on regular-width iPad
struct InPlaceDocumentReader: View {

    /// The host's reading chain.
    @Binding private var chain: [DocumentBrowserEntry]
    /// This reader's position in `chain`.
    private let level: Int
    /// The document this level last showed, kept for the moment after Back has shortened the chain and
    /// before the pop has finished sliding this reader away — without it the page goes blank as it leaves.
    @State private var retained: DocumentBrowserEntry?

    /// Creates the reader for one level of a host's chain.
    ///
    /// - Parameters:
    ///   - chain: The host's reading chain.
    ///   - level: The position in `chain` this reader shows.
    init(chain: Binding<[DocumentBrowserEntry]>, level: Int) {
        _chain = chain
        self.level = level
    }

    /// The document to show: this level's, or the one retained while the reader is being popped.
    private var shown: DocumentBrowserEntry? {
        chain.indices.contains(level) ? chain[level] : retained
    }

    var body: some View {
        Group {
            if let entry = shown {
                DocumentView(entry: entry, onNavigateToDocument: { target, jump in
                    InPlaceReading.apply(jump, to: &chain, at: level, target: target)
                })
                .id(entry)
            }
        }
        .onChange(of: shown, initial: true) { _, entry in retained = entry }
        // Browse and Search keep the research question in the title area on regular-width iPad, where
        // the top-inset banner is suppressed; a document read in place keeps it too.
        .workingOnSubtitle()
        .navigationDestination(isPresented: InPlaceReading.presentation(above: level, in: $chain)) {
            InPlaceDocumentReader(chain: $chain, level: level + 1)
        }
    }
}

extension View {

    /// Reads the host's `chain` in place: pushes an ``InPlaceDocumentReader`` over this view while the
    /// chain holds a document, and Back empties it.
    ///
    /// Declare it on the view the reader is looking at when they open a document, and keep the chain on
    /// a view that outlives any layout change beneath it — see ``InPlaceReading``.
    ///
    /// - Parameter chain: The host's reading chain; set it to `[entry]` to open a document.
    /// - Returns: The view, with the reader's destination declared.
    func inPlaceReader(_ chain: Binding<[DocumentBrowserEntry]>) -> some View {
        navigationDestination(isPresented: InPlaceReading.presentation(above: -1, in: chain)) {
            InPlaceDocumentReader(chain: chain, level: 0)
        }
    }
}

#endif
