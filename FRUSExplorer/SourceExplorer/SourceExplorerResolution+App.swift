// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// The app's half of `SourceExplorerResolution` (FRUS Explorer Light, S22b): what the sequence both Source
// Explorer views run reads in the app, its bundled files through their stores and the reader's parsed
// documents. The value and the sequence are FRUSCoreKit's (`FRUSCoreKit/SourceExplorer/SourceExplorerResolution.swift`).

// MARK: - DocumentASTCache

extension DocumentASTCache: DocumentASTSource {}

// MARK: - SourceExplorerResolution.Dependencies.app

extension SourceExplorerResolution.Dependencies {

    /// The app's: each bundled file through its store, read where the step that needs it reads it, off the
    /// main actor and the presidential-library catalogue only for a library citation, as both views read
    /// them; the register, `ChiefsOfMissionRoster.bundled`, only once both of the country series' gates
    /// have passed; the reader's AST cache; and the volume's downloaded file. `AppState` is read here, on
    /// the main actor, as the views read it before they called `CentralFilesClassifier.evaluate`.
    ///
    /// - Parameters:
    ///   - appState: The app's state, for the AST cache and the volume's file.
    ///   - volumeId: The document's volume, or `nil` when the host passed none.
    @MainActor
    static func app(_ appState: AppState, volumeId: String?) -> Self {
        Self(collectionAuthority: CollectionAuthorityStore.shared,
             centralFiles: CentralFilesIndexStore.shared,
             chiefsOfMission: .bundled,
             presidentialLibraries: PresidentialLibraryIndexStore.shared,
             curatedLibraries: CuratedLibraryResolutionsStore.shared,
             parsedDocuments: appState.documentASTCache,
             volumeURL: volumeId.flatMap { appState.downloadManager?.volumeURL(for: $0) })
    }
}
