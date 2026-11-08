// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// The app's half of `ArchivalResolver` (FRUS Explorer Light, S18b and S22a): the overloads that read the
// app's bundled indexes through their stores. The document and front-matter resolutions, the library route,
// the divided-lot claimants, the indexes and `ArchivalIndexes` are FRUSCoreKit's
// (`FRUSCoreKit/SourceExplorer/ArchivalResolver.swift`), each given the index it reads.

extension ArchivalResolver {

    /// ``frontMatterResolution(recordGroup:lotFile:entryText:repository:centralFiles:volumeSources:claimants:presidentialLibrary:)``
    /// with the app's bundled presidential-library catalogue.
    static func frontMatterResolution(recordGroup: String?,
                                      lotFile: String?,
                                      entryText: String,
                                      repository: String? = nil,
                                      centralFiles: CentralFilesIndex?,
                                      volumeSources: VolumeSourcesIndex?,
                                      claimants: LotClaimantsIndex? = nil) -> ArchivalResolution? {
        frontMatterResolution(recordGroup: recordGroup, lotFile: lotFile, entryText: entryText,
                              repository: repository, centralFiles: centralFiles,
                              volumeSources: volumeSources, claimants: claimants,
                              presidentialLibrary: PresidentialLibraryIndexStore.shared)
    }

    /// ``libraryResolution(repository:entryText:index:)`` against the app's bundled catalogue.
    static func libraryResolution(repository: String?, entryText: String) -> ArchivalResolution? {
        libraryResolution(repository: repository, entryText: entryText,
                          index: PresidentialLibraryIndexStore.shared)
    }

    /// ``dividedLotClaimants(lotFile:claimants:)`` against the app's bundled claimants index.
    static func dividedLotClaimants(lotFile: String?) -> [LotClaimant]? {
        dividedLotClaimants(lotFile: lotFile, claimants: LotClaimantsIndexStore.shared)
    }

    /// ``frontMatterResolution(recordGroup:lotFile:centralFiles:volumeSources:)`` against the
    /// app's bundled indexes.
    static func frontMatterResolution(recordGroup: String?, lotFile: String?,
                                      entryText: String,
                                      repository: String? = nil) -> ArchivalResolution? {
        frontMatterResolution(recordGroup: recordGroup, lotFile: lotFile, entryText: entryText,
                              repository: repository,
                              centralFiles: CentralFilesIndexStore.shared,
                              volumeSources: VolumeSourcesIndexStore.shared,
                              claimants: LotClaimantsIndexStore.shared)
    }

    /// ``documentResolution(lotFile:centralFiles:volumeSources:)`` against the app's bundled
    /// indexes.
    static func documentResolution(lotFile: String?) -> ArchivalResolution? {
        documentResolution(lotFile: lotFile,
                           centralFiles: CentralFilesIndexStore.shared,
                           volumeSources: VolumeSourcesIndexStore.shared,
                           claimants: LotClaimantsIndexStore.shared)
    }
}

// MARK: - ArchivalIndexes.bundled

extension ArchivalIndexes {

    /// The app's bundled indexes, from their three stores: what the app's Sources & Archives block and its
    /// document resolution read.
    static var bundled: ArchivalIndexes {
        ArchivalIndexes(centralFiles: CentralFilesIndexStore.shared,
                        volumeSources: VolumeSourcesIndexStore.shared,
                        claimants: LotClaimantsIndexStore.shared)
    }
}
