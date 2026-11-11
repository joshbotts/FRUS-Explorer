// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// The app's half of `NARACatalogClient` (FRUS Explorer Light, S22c): the key from the Keychain and the
// 30-day count of answered calls, which the client read and wrote itself before it moved into
// FRUSCoreKit (`FRUSCoreKit/SourceExplorer/NARACatalogClient.swift`), where it asks a
// `NARACatalogKeyProvider` for both. `KeychainStore` is the app's provider, and the initializer the
// app's call sites use passes it, so each of them is unchanged.

extension KeychainStore: NARACatalogKeyProvider {

    /// The user's NARA Catalog API key, read from the keychain on each call, as the client read it.
    public func naraCatalogAPIKey() throws -> String? {
        try getNARACatalogAPIKey()
    }

    /// Records a successful API hit for the 30-day usage tracking displayed in Settings, on the main
    /// actor, as the client recorded it.
    public nonisolated func recordNARACatalogAPICall() async {
        await MainActor.run { NARAAPIKeyStore.shared.recordAPICall() }
    }
}

extension NARACatalogClient {

    /// The app's client: the key from `keychainStore`, the app's shared Keychain store unless a test
    /// passes one of its own.
    public init(
        keychainStore: KeychainStore = .shared,
        urlSession: URLSession = .shared
    ) {
        self.init(keyProvider: keychainStore, urlSession: urlSession)
    }
}
