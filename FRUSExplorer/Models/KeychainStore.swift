// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Security

// MARK: - KeychainError

/// Errors thrown by `KeychainStore` operations.
///
/// Version history:
///   1.0 — Session 04: initial implementation
public enum KeychainError: Error, Sendable {
    /// The keychain item was not found. Returned by `get` when the key is absent.
    case notFound
    /// A Security framework operation returned a non-zero status code.
    case securityError(OSStatus)
    /// The stored data could not be decoded as a UTF-8 string.
    case decodingError
}

// MARK: - KeychainStore

/// Manages encrypted credential storage in the device keychain.
///
/// ## Stored Keys
/// - **NARA Catalog API key**: the user's personal API key for the National Archives
///   Catalog API (Session 23). Stored under `kSecAttrAccount = "NARACatalogAPIKey"`.
///
/// ## iCloud Keychain Sharing
/// The `accessGroup` property controls whether stored items are shared across the
/// user's devices via iCloud Keychain. The access group must match the
/// `com.apple.developer.icloud-keychain-sharing` entitlement value:
///   `<TeamIdentifierPrefix>bottsywattsy.FRUS-Explorer.shared`
///
/// The team identifier prefix is not known at compile time. It is read at runtime
/// from the app's signed bundle via `Bundle.main.infoDictionary["AppIdentifierPrefix"]`.
/// During development and unit testing, `accessGroup` defaults to `nil` (items stay
/// in the app's own keychain partition, which is sufficient for testing).
///
/// ## Actor Isolation
/// All keychain operations run on the actor's executor, ensuring serial access and
/// preventing concurrent Security framework calls from the same process.
///
/// Version history:
///   1.0 — Session 04: initial implementation
public actor KeychainStore {

    // MARK: - Singleton

    /// Shared instance for production use. The iCloud Keychain access group is resolved
    /// from the signed bundle (auto-detected from `AppIdentifierPrefix` in Info.plist).
    public static let shared: KeychainStore = KeychainStore.makeProduction()

    // MARK: - Configuration

    private let service: String
    private let accessGroup: String?

    // MARK: - Init

    /// Creates a `KeychainStore`.
    ///
    /// - Parameters:
    ///   - service: The `kSecAttrService` value identifying this app's keychain items.
    ///     Defaults to the bundle ID `"bottsywattsy.FRUS-Explorer"`.
    ///   - accessGroup: The iCloud Keychain sharing access group. Pass `nil` to restrict
    ///     items to the app's own keychain partition (suitable for tests and development).
    /// Creates a `KeychainStore`.
    ///
    /// - Parameters:
    ///   - service: The `kSecAttrService` value identifying this app's keychain items.
    ///     Defaults to the bundle ID `"bottsywattsy.FRUS-Explorer"`.
    ///   - accessGroup: The iCloud Keychain sharing access group. Pass `nil` to restrict
    ///     items to the app's own keychain partition (suitable for tests and development).
    ///     Pass `.useBundle` to derive the group from the signed bundle automatically.
    public init(
        service: String = "bottsywattsy.FRUS-Explorer",
        accessGroup: String? = nil
    ) {
        self.service = service
        self.accessGroup = accessGroup
    }

    /// Creates the shared production store, auto-deriving the iCloud Keychain access group
    /// from the signed bundle when available.
    nonisolated static func makeProduction() -> KeychainStore {
        KeychainStore(
            service: "bottsywattsy.FRUS-Explorer",
            accessGroup: KeychainStore.resolveAccessGroup()
        )
    }

    // MARK: - NARA Catalog API Key

    /// Stores (or replaces) the NARA Catalog API key in the keychain.
    ///
    /// If a key already exists it is updated in-place; otherwise a new item is created.
    public func setNARACatalogAPIKey(_ key: String) throws {
        guard let data = key.data(using: .utf8) else {
            throw KeychainError.decodingError
        }
        // Try to update an existing item first.
        let query = baseQuery(account: Keys.naraCatalogAPIKey)
        let update: [CFString: Any] = [kSecValueData: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)

        if updateStatus == errSecItemNotFound {
            // Item doesn't exist yet — add it.
            var addQuery = baseQuery(account: Keys.naraCatalogAPIKey)
            addQuery[kSecValueData] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.securityError(addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw KeychainError.securityError(updateStatus)
        }

        #if DEBUG
        print("[KeychainStore] NARA API key stored")
        #endif
    }

    /// Retrieves the stored NARA Catalog API key.
    ///
    /// Returns `nil` if no key has been stored yet.
    public func getNARACatalogAPIKey() throws -> String? {
        var query = baseQuery(account: Keys.naraCatalogAPIKey)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let string = String(data: data, encoding: .utf8) else {
                throw KeychainError.decodingError
            }
            return string
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.securityError(status)
        }
    }

    /// Returns `true` when a NARA Catalog API key is present in the keychain.
    public func hasAPIKey() -> Bool {
        (try? getNARACatalogAPIKey()) != nil
    }

    /// Removes the stored NARA Catalog API key.
    ///
    /// Succeeds silently if the key does not exist.
    public func deleteNARACatalogAPIKey() throws {
        let query = baseQuery(account: Keys.naraCatalogAPIKey)
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.securityError(status)
        }

        #if DEBUG
        print("[KeychainStore] NARA API key deleted")
        #endif
    }

    // MARK: - Private Helpers

    private func baseQuery(account: String) -> [CFString: Any] {
        var query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        if let group = accessGroup {
            query[kSecAttrAccessGroup] = group
        }
        return query
    }

    // MARK: - Account Constants

    private enum Keys {
        static let naraCatalogAPIKey = "NARACatalogAPIKey"
    }

    // MARK: - Access Group Resolution

    /// Derives the iCloud Keychain access group from the app's signed bundle.
    ///
    /// The group identifier is `<TeamIDPrefix>bottsywattsy.FRUS-Explorer.shared`.
    /// Returns `nil` in environments where the bundle prefix is unavailable
    /// (unit tests, command-line tools), falling back to the app's own keychain partition.
    private static func resolveAccessGroup() -> String? {
        guard let prefix = Bundle.main.infoDictionary?["AppIdentifierPrefix"] as? String,
              !prefix.isEmpty else {
            return nil
        }
        // Strip trailing '.' if present (the value from Info.plist includes it).
        let cleanPrefix = prefix.hasSuffix(".") ? String(prefix.dropLast()) : prefix
        return "\(cleanPrefix).bottsywattsy.FRUS-Explorer.shared"
    }
}
