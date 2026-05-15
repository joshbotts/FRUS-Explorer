// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - KeychainStoreTests

/// Tests for `KeychainStore` NARA API key storage.
///
/// These tests use a test-specific keychain service identifier ("frus-test-keychain")
/// to avoid contaminating production keychain items. All items are deleted after
/// each test.
///
/// ## Running Environment
/// Keychain operations require a signed host process. These tests pass when run on
/// a physical device or iOS/macOS simulator with a valid signing identity. They may
/// fail in unsigned CI environments — in that case the tests are expected to throw
/// `KeychainError.securityError(-34018)` (errSecMissingEntitlement).
struct KeychainStoreTests {

    // Use a distinct service name to isolate test items from production.
    private func makeStore() -> KeychainStore {
        KeychainStore(service: "frus-test-keychain", accessGroup: nil)
    }

    @Test("Set and get NARA API key returns stored value")
    func setAndGet() async throws {
        let store = makeStore()
        // Clean up any leftover item from a prior run.
        try? await store.deleteNARACatalogAPIKey()

        try await store.setNARACatalogAPIKey("test-key-abc123")
        let retrieved = try await store.getNARACatalogAPIKey()

        #expect(retrieved == "test-key-abc123")

        // Cleanup.
        try? await store.deleteNARACatalogAPIKey()
    }

    @Test("Get before set returns nil")
    func getBeforeSet() async throws {
        let store = makeStore()
        try? await store.deleteNARACatalogAPIKey()

        let result = try await store.getNARACatalogAPIKey()
        #expect(result == nil)
    }

    @Test("Updating the key replaces the previous value")
    func updateKey() async throws {
        let store = makeStore()
        try? await store.deleteNARACatalogAPIKey()

        try await store.setNARACatalogAPIKey("first-key")
        try await store.setNARACatalogAPIKey("second-key")
        let result = try await store.getNARACatalogAPIKey()

        #expect(result == "second-key")

        try? await store.deleteNARACatalogAPIKey()
    }

    @Test("Deleting the key results in nil on subsequent get")
    func deleteKey() async throws {
        let store = makeStore()
        try? await store.deleteNARACatalogAPIKey()

        try await store.setNARACatalogAPIKey("ephemeral-key")
        try await store.deleteNARACatalogAPIKey()
        let result = try await store.getNARACatalogAPIKey()

        #expect(result == nil)
    }

    @Test("Deleting a non-existent key does not throw")
    func deleteNonExistent() async throws {
        let store = makeStore()
        try? await store.deleteNARACatalogAPIKey()

        // Should succeed silently when there is nothing to delete.
        try await store.deleteNARACatalogAPIKey()
    }
}
