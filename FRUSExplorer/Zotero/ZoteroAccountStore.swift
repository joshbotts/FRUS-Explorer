// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Security

/// Stores the user's Zotero Web API credentials.
///
/// The **API key** is a secret and lives in the Keychain (synchronizable across the
/// user's devices via iCloud Keychain, never in SwiftData/CloudKit). The resolved
/// numeric **userID** and **username** are non-secret and live in `UserDefaults`.
///
/// Mirrors `NARAAPIKeyStore`: a synchronous `@MainActor` facade over the Security
/// framework, callable from Settings UI without `await`.
///
/// Version history:
///   1.0 — Zotero Web API integration (Phase 2)
@MainActor
public final class ZoteroAccountStore {

    /// Shared instance.
    public static let shared = ZoteroAccountStore()

    private let service = "bottsywattsy.FRUS-Explorer"
    private let account = "ZoteroAPIKey"
    private let userIDKey = "ZoteroUserID"
    private let usernameKey = "ZoteroUsername"

    private init() {}

    // MARK: - API Key (Keychain)

    /// The stored Zotero API key, or `nil` if none has been saved.
    public func retrieveKey() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = kCFBooleanTrue as Any
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else { return nil }
        return string
    }

    /// Stores (or replaces) the Zotero API key in the Keychain.
    public func storeKey(_ key: String) {
        guard let data = key.data(using: .utf8) else { return }
        let query = baseQuery()
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrSynchronizable as String: kCFBooleanTrue as Any,
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = baseQuery()
            addQuery[kSecAttrSynchronizable as String] = kCFBooleanTrue as Any
            addQuery[kSecValueData as String] = data
            _ = SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    /// Removes the Zotero API key from the Keychain.
    public func deleteKey() {
        _ = SecItemDelete(baseQuery() as CFDictionary)
    }

    /// `true` when an API key is present.
    public var hasKey: Bool { retrieveKey() != nil }

    // MARK: - Account (UserDefaults, non-secret)

    /// The resolved Zotero numeric user ID, or `nil` if not connected.
    public var userID: Int? {
        let value = UserDefaults.standard.integer(forKey: userIDKey)
        return value == 0 ? nil : value
    }

    /// The resolved Zotero username, if known.
    public var username: String? { UserDefaults.standard.string(forKey: usernameKey) }

    /// Records the resolved account identity alongside the stored key.
    public func setAccount(userID: Int, username: String?) {
        UserDefaults.standard.set(userID, forKey: userIDKey)
        UserDefaults.standard.set(username, forKey: usernameKey)
    }

    /// `true` when both a key and a resolved user ID are present.
    public var isConnected: Bool { hasKey && userID != nil }

    /// Clears all stored Zotero credentials.
    public func disconnect() {
        deleteKey()
        UserDefaults.standard.removeObject(forKey: userIDKey)
        UserDefaults.standard.removeObject(forKey: usernameKey)
    }

    // MARK: - Private

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
        ]
    }
}
