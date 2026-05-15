// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation

/// Tests that the macOS entitlement files contain all required keys.
///
/// Both `.entitlements` files are added to the test target's Copy Bundle Resources
/// phase so they can be loaded via `Bundle.testBundle`. The tests parse each file as
/// a property list and assert the presence and value of every required entitlement key.
///
/// These tests serve as a living specification of required entitlements — if a key is
/// added or removed from the spec, update these tests first, then the `.entitlements` files.
struct EntitlementsTests {

    // MARK: - Helpers

    private func loadEntitlements(named name: String) throws -> [String: Any] {
        guard let url = Bundle.testBundle.url(forResource: name, withExtension: "entitlements") else {
            Issue.record("Entitlements file '\(name).entitlements' not found in test bundle. " +
                         "Ensure it is added to FRUSExplorerTests Copy Bundle Resources phase.")
            return [:]
        }
        let data = try Data(contentsOf: url)
        guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            Issue.record("Failed to deserialise '\(name).entitlements' as [String: Any]")
            return [:]
        }
        return plist
    }

    // MARK: - App Store Entitlements

    @Test("AppStore entitlements: app-sandbox is true")
    func appStoreHasAppSandbox() throws {
        let plist = try loadEntitlements(named: "FRUSExplorer-AppStore")
        #expect(plist["com.apple.security.app-sandbox"] as? Bool == true)
    }

    @Test("AppStore entitlements: network.client is true")
    func appStoreHasNetworkClient() throws {
        let plist = try loadEntitlements(named: "FRUSExplorer-AppStore")
        #expect(plist["com.apple.security.network.client"] as? Bool == true)
    }

    @Test("AppStore entitlements: icloud-container-identifiers references correct container")
    func appStoreHasCorrectICloudContainer() throws {
        let plist = try loadEntitlements(named: "FRUSExplorer-AppStore")
        let containers = plist["com.apple.developer.icloud-container-identifiers"] as? [String]
        #expect(containers?.contains("iCloud.bottsywattsy.FRUS-Explorer") == true)
    }

    @Test("AppStore entitlements: icloud-services includes CloudKit")
    func appStoreHasCloudKitService() throws {
        let plist = try loadEntitlements(named: "FRUSExplorer-AppStore")
        let services = plist["com.apple.developer.icloud-services"] as? [String]
        #expect(services?.contains("CloudKit") == true)
    }

    @Test("AppStore entitlements: ubiquity-kvstore-identifier is present")
    func appStoreHasKVStoreIdentifier() throws {
        let plist = try loadEntitlements(named: "FRUSExplorer-AppStore")
        let kvStore = plist["com.apple.developer.ubiquity-kvstore-identifier"] as? String
        #expect(kvStore?.isEmpty == false)
    }

    @Test("AppStore entitlements: keychain-access-groups is present and non-empty")
    func appStoreHasKeychainAccessGroups() throws {
        let plist = try loadEntitlements(named: "FRUSExplorer-AppStore")
        let groups = plist["keychain-access-groups"] as? [String]
        #expect(groups?.isEmpty == false)
    }

    // MARK: - Direct Distribution Entitlements

    @Test("DirectDistribution entitlements: app-sandbox is true")
    func directDistributionHasAppSandbox() throws {
        let plist = try loadEntitlements(named: "FRUSExplorer-DirectDistribution")
        #expect(plist["com.apple.security.app-sandbox"] as? Bool == true)
    }

    @Test("DirectDistribution entitlements: network.client is true")
    func directDistributionHasNetworkClient() throws {
        let plist = try loadEntitlements(named: "FRUSExplorer-DirectDistribution")
        #expect(plist["com.apple.security.network.client"] as? Bool == true)
    }

    @Test("DirectDistribution entitlements: icloud-container-identifiers references correct container")
    func directDistributionHasCorrectICloudContainer() throws {
        let plist = try loadEntitlements(named: "FRUSExplorer-DirectDistribution")
        let containers = plist["com.apple.developer.icloud-container-identifiers"] as? [String]
        #expect(containers?.contains("iCloud.bottsywattsy.FRUS-Explorer") == true)
    }

    @Test("DirectDistribution entitlements: icloud-services includes CloudKit")
    func directDistributionHasCloudKitService() throws {
        let plist = try loadEntitlements(named: "FRUSExplorer-DirectDistribution")
        let services = plist["com.apple.developer.icloud-services"] as? [String]
        #expect(services?.contains("CloudKit") == true)
    }

    @Test("DirectDistribution entitlements: ubiquity-kvstore-identifier is present")
    func directDistributionHasKVStoreIdentifier() throws {
        let plist = try loadEntitlements(named: "FRUSExplorer-DirectDistribution")
        let kvStore = plist["com.apple.developer.ubiquity-kvstore-identifier"] as? String
        #expect(kvStore?.isEmpty == false)
    }

    @Test("DirectDistribution entitlements: keychain-access-groups is present and non-empty")
    func directDistributionHasKeychainAccessGroups() throws {
        let plist = try loadEntitlements(named: "FRUSExplorer-DirectDistribution")
        let groups = plist["keychain-access-groups"] as? [String]
        #expect(groups?.isEmpty == false)
    }

    // MARK: - Parity

    @Test("Both entitlement files have identical sandbox posture")
    func entitlementFilesHaveIdenticalSandboxPosture() throws {
        let appStore = try loadEntitlements(named: "FRUSExplorer-AppStore")
        let direct = try loadEntitlements(named: "FRUSExplorer-DirectDistribution")
        #expect(appStore["com.apple.security.app-sandbox"] as? Bool ==
                direct["com.apple.security.app-sandbox"] as? Bool)
        #expect(appStore["com.apple.security.network.client"] as? Bool ==
                direct["com.apple.security.network.client"] as? Bool)
        #expect(appStore["com.apple.developer.icloud-container-identifiers"] as? [String] ==
                direct["com.apple.developer.icloud-container-identifiers"] as? [String])
        #expect(appStore["com.apple.developer.icloud-services"] as? [String] ==
                direct["com.apple.developer.icloud-services"] as? [String])
    }
}
