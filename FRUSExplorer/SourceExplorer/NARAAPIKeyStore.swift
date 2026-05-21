// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Security

/// Manages the NARA Catalog API key in the macOS/iOS Keychain and tracks API call usage.
///
/// ## Interface
/// `NARAAPIKeyStore` is a synchronous facade over the Security framework, designed for use
/// on the main thread from Settings UI without `await`. It complements the existing
/// `KeychainStore` actor (which is async) by providing a dedicated, simpler interface for
/// the NARA key specifically.
///
/// ## Call-count tracking
/// Each time `NARACatalogClient` makes a successful API call it should call
/// `recordAPICall()`. Timestamps are persisted in `UserDefaults` and pruned to the
/// trailing 30-day window on each read. This is a best-effort count — it resets if the
/// user reinstalls the app or clears `UserDefaults`.
///
/// ## Thread safety
/// Isolated to the `@MainActor`. The Security framework calls are inherently
/// serialised per-process for the same keychain item.
///
/// Version history:
///   1.0 — New UI scaffolding (stub for `SettingsNARAPane`)
@MainActor
public final class NARAAPIKeyStore {

    // MARK: - Singleton

    public static let shared = NARAAPIKeyStore()

    // MARK: - Constants

    private let service       = "bottsywattsy.FRUS-Explorer"
    private let account       = "NARACatalogAPIKey"
    private let timestampsKey = "NARAAPICallTimestamps"

    // MARK: - Init

    private init() {}

    // MARK: - Key Management

    /// Returns the stored NARA Catalog API key, or `nil` if none has been saved.
    public func retrieveKey() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = kCFBooleanTrue as Any
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    /// Stores (or replaces) the NARA Catalog API key in the keychain.
    ///
    /// New items are created with `kSecAttrSynchronizable = true` so they sync across the
    /// user's devices via iCloud Keychain. Existing items (stored before this fix) are
    /// updated in-place with the same synchronizable flag to migrate them on the next save.
    ///
    /// Silently ignores the call if `key` cannot be encoded as UTF-8.
    public func storeKey(_ key: String) {
        guard let data = key.data(using: .utf8) else { return }
        // kSecAttrSynchronizableAny in the query matches both sync and non-sync items so
        // any previously stored key is found and updated regardless of its sync state.
        let query = baseQuery()
        let updateAttributes: [String: Any] = [
            kSecValueData as String:         data,
            kSecAttrSynchronizable as String: kCFBooleanTrue as Any,
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = baseQuery()
            addQuery[kSecAttrSynchronizable as String] = kCFBooleanTrue as Any
            addQuery[kSecValueData as String] = data
            _ = SecItemAdd(addQuery as CFDictionary, nil)
        }
        #if DEBUG
        print("[NARAAPIKeyStore] Key stored (synchronizable).")
        #endif
    }

    /// Removes the NARA Catalog API key from the keychain.
    ///
    /// Succeeds silently if the key is not present.
    public func deleteKey() {
        _ = SecItemDelete(baseQuery() as CFDictionary)
        #if DEBUG
        print("[NARAAPIKeyStore] Key deleted.")
        #endif
    }

    /// Returns `true` when a NARA Catalog API key is present in the keychain.
    public var hasKey: Bool {
        retrieveKey() != nil
    }

    // MARK: - Call Count

    /// The number of NARA Catalog API calls recorded in the last 30 days.
    ///
    /// Stale entries (older than 30 days) are pruned from `UserDefaults` on each read.
    public var callCountLast30Days: Int {
        pruneAndLoad().count
    }

    /// Records a single NARA Catalog API call.
    ///
    /// Call this from `NARACatalogClient` after each successful request so the Settings
    /// usage counter stays accurate.
    public func recordAPICall() {
        var timestamps = pruneAndLoad()
        timestamps.append(Date())
        UserDefaults.standard.set(
            timestamps.map { $0.timeIntervalSince1970 },
            forKey: timestampsKey
        )
    }

    // MARK: - Private Helpers

    private func baseQuery() -> [String: Any] {
        // kSecAttrSynchronizableAny matches both synchronizable and non-synchronizable items
        // in queries (lookup, update, delete). New items override this to kCFBooleanTrue.
        [
            kSecClass as String:              kSecClassGenericPassword,
            kSecAttrService as String:        service,
            kSecAttrAccount as String:        account,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
        ]
    }

    /// Loads call timestamps, drops those older than 30 days, and writes the pruned list
    /// back to `UserDefaults`. Returns the remaining (recent) dates.
    @discardableResult
    private func pruneAndLoad() -> [Date] {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        let stored = UserDefaults.standard.array(forKey: timestampsKey) as? [Double] ?? []
        let recent = stored
            .map { Date(timeIntervalSince1970: $0) }
            .filter { $0 >= cutoff }
        UserDefaults.standard.set(
            recent.map { $0.timeIntervalSince1970 },
            forKey: timestampsKey
        )
        return recent
    }
}
