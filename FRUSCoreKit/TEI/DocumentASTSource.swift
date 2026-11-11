// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - DocumentASTSource

/// The parsed documents a host keeps, so that a reader of one document's AST asks for it before it
/// parses the volume again.
///
/// The two calls Source Explorer's pre-1906 check makes (`CentralFilesClassifier.enclosureOpeners`), as
/// a protocol because the store is the host's: the app's is its `DocumentASTCache`, the reader's 24-slot
/// LRU, which conforms in `SourceExplorerResolution+App.swift`, and FRUS Explorer Light passes its own.
/// A source that keeps nothing is a valid one: every read then parses the volume.
///
/// Version history:
///   1.0 — 2026-11-10 (FRUS Explorer Light, S22b): initial implementation, the calls
///         `CentralFilesClassifier.enclosureOpeners` made of `DocumentASTCache` when the classifier moved
///         into FRUSCoreKit
public protocol DocumentASTSource: Sendable {

    /// The parsed document, or `nil` when the source holds none.
    func ast(volumeId: String, documentId: String) async -> FRUSDocumentAST?

    /// Keeps documents parsed from one volume.
    func store(_ documents: [FRUSDocumentAST], volumeId: String) async
}
