// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation

// MARK: - DistributionTests

/// Structural tests for the Direct Distribution build configuration.
///
/// These tests verify:
/// - Entitlement files for AppStore and DirectDistribution are present and parseable
/// - Both entitlement files define an identical sandbox security posture (SandboxParityTest)
/// - `project.yml` declares Sparkle as a package dependency for the macOS target (SparkleIntegrationTest)
/// - `Scripts/notarize.sh` exists and contains the expected notarization workflow steps (NotarizationWorkflowTest)
struct DistributionTests {

    // MARK: - File URL Helpers

    private static let projectRoot: URL = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // FRUSExplorerTests/
            .deletingLastPathComponent()   // project root
    }()

    private static let appStoreEntitlementsURL: URL =
        projectRoot.appendingPathComponent("FRUSExplorer/FRUSExplorer-AppStore.entitlements")

    private static let directDistEntitlementsURL: URL =
        projectRoot.appendingPathComponent("FRUSExplorer/FRUSExplorer-DirectDistribution.entitlements")

    private static let projectYMLURL: URL =
        projectRoot.appendingPathComponent("project.yml")

    private static let notarizeScriptURL: URL =
        projectRoot.appendingPathComponent("Scripts/notarize.sh")

    // MARK: - SandboxParityTests

    @Test("SandboxParityTest: both entitlement files exist and are non-empty")
    func entitlementFilesExist() throws {
        let appStore = try String(contentsOf: Self.appStoreEntitlementsURL, encoding: .utf8)
        let direct   = try String(contentsOf: Self.directDistEntitlementsURL, encoding: .utf8)
        #expect(!appStore.isEmpty)
        #expect(!direct.isEmpty)
    }

    @Test("SandboxParityTest: both entitlement files enable the app sandbox")
    func bothEntitlementsEnableSandbox() throws {
        let appStore = try String(contentsOf: Self.appStoreEntitlementsURL, encoding: .utf8)
        let direct   = try String(contentsOf: Self.directDistEntitlementsURL, encoding: .utf8)
        #expect(appStore.contains("com.apple.security.app-sandbox"),
                "AppStore entitlements missing sandbox key")
        #expect(direct.contains("com.apple.security.app-sandbox"),
                "DirectDistribution entitlements missing sandbox key")
    }

    @Test("SandboxParityTest: both entitlement files grant outbound network access")
    func bothEntitlementsGrantNetworkClient() throws {
        let appStore = try String(contentsOf: Self.appStoreEntitlementsURL, encoding: .utf8)
        let direct   = try String(contentsOf: Self.directDistEntitlementsURL, encoding: .utf8)
        #expect(appStore.contains("com.apple.security.network.client"),
                "AppStore entitlements missing network.client")
        #expect(direct.contains("com.apple.security.network.client"),
                "DirectDistribution entitlements missing network.client")
    }

    @Test("SandboxParityTest: DirectDistribution entitlements do not add extra capabilities beyond AppStore")
    func directDistributionHasNoExtraCapabilities() throws {
        let appStore = try String(contentsOf: Self.appStoreEntitlementsURL, encoding: .utf8)
        let direct   = try String(contentsOf: Self.directDistEntitlementsURL, encoding: .utf8)

        // Extract boolean keys from a plist-like entitlement document
        func extractKeys(_ content: String) -> Set<String> {
            let pattern = #"<key>(com\.[a-z.]+)</key>"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
            let range = NSRange(content.startIndex..., in: content)
            let matches = regex.matches(in: content, range: range)
            return Set(matches.compactMap { match -> String? in
                guard let r = Range(match.range(at: 1), in: content) else { return nil }
                return String(content[r])
            })
        }

        let appStoreKeys = extractKeys(appStore)
        let directKeys   = extractKeys(direct)
        let extraKeys    = directKeys.subtracting(appStoreKeys)
        #expect(extraKeys.isEmpty,
                "DirectDistribution entitlements have extra keys not in AppStore: \(extraKeys.sorted())")
    }

    @Test("SandboxParityTest: entitlement files are valid UTF-8 plists (contain xml declaration)")
    func entitlementFilesAreValidPlists() throws {
        let appStore = try String(contentsOf: Self.appStoreEntitlementsURL, encoding: .utf8)
        let direct   = try String(contentsOf: Self.directDistEntitlementsURL, encoding: .utf8)
        #expect(appStore.contains("<?xml"))
        #expect(direct.contains("<?xml"))
        #expect(appStore.contains("<!DOCTYPE plist"))
        #expect(direct.contains("<!DOCTYPE plist"))
    }

    // MARK: - SparkleIntegrationTests

    @Test("SparkleIntegrationTest: project.yml exists and declares Sparkle package")
    func projectYMLDeclaresSparkle() throws {
        let content = try String(contentsOf: Self.projectYMLURL, encoding: .utf8)
        #expect(content.contains("Sparkle"),
                "project.yml does not reference Sparkle package")
        #expect(content.contains("sparkle-project/Sparkle"),
                "project.yml does not reference Sparkle repository URL")
    }

    @Test("SparkleIntegrationTest: Sparkle is linked to FRUSExplorerMac target")
    func sparkleLinkedToMacTarget() throws {
        let content = try String(contentsOf: Self.projectYMLURL, encoding: .utf8)
        // Verify Sparkle appears under the FRUSExplorerMac target's dependencies
        // by checking proximity of "FRUSExplorerMac:" and "Sparkle" within 50 lines.
        let lines = content.components(separatedBy: .newlines)
        guard let macTargetLine = lines.firstIndex(where: { $0.contains("FRUSExplorerMac:") }) else {
            Issue.record("FRUSExplorerMac target not found in project.yml")
            return
        }
        let window = lines[macTargetLine..<min(macTargetLine + 50, lines.count)]
        #expect(window.contains(where: { $0.contains("package: Sparkle") }),
                "Sparkle is not listed as a dependency of FRUSExplorerMac in project.yml")
    }

    @Test("SparkleIntegrationTest: DirectDistribution config sets DIRECT_DISTRIBUTION compiler flag")
    func directDistributionFlagDefined() throws {
        let content = try String(contentsOf: Self.projectYMLURL, encoding: .utf8)
        #expect(content.contains("DIRECT_DISTRIBUTION"),
                "project.yml DirectDistribution config missing -DDIRECT_DISTRIBUTION flag")
    }

    @Test("SparkleIntegrationTest: DirectDistribution config uses Manual code signing")
    func directDistributionUsesManualSigning() throws {
        let content = try String(contentsOf: Self.projectYMLURL, encoding: .utf8)
        // Find DirectDistribution block and check CODE_SIGN_STYLE: Manual
        let lines = content.components(separatedBy: .newlines)
        // Look for the per-target settings block: `DirectDistribution:` with nothing
        // after the colon (not the top-level `DirectDistribution: release` configs entry).
        guard let ddLine = lines.firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == "DirectDistribution:"
        }) else {
            Issue.record("DirectDistribution per-target config block not found in project.yml")
            return
        }
        let window = lines[ddLine..<min(ddLine + 20, lines.count)]
        #expect(window.contains(where: { $0.contains("CODE_SIGN_STYLE: Manual") }),
                "DirectDistribution config should use CODE_SIGN_STYLE: Manual")
    }

    @Test("SparkleIntegrationTest: DirectDistribution config sets SUFeedURL")
    func directDistributionSetsSUFeedURL() throws {
        let content = try String(contentsOf: Self.projectYMLURL, encoding: .utf8)
        #expect(content.contains("SUFeedURL"),
                "project.yml DirectDistribution config missing SUFeedURL / INFOPLIST_KEY_SUFeedURL")
        #expect(content.contains("appcast.xml"),
                "SUFeedURL should reference an appcast.xml feed")
    }

    // MARK: - NotarizationWorkflowTests

    @Test("NotarizationWorkflowTest: notarize.sh exists and is non-empty")
    func notarizeScriptExists() throws {
        let content = try String(contentsOf: Self.notarizeScriptURL, encoding: .utf8)
        #expect(!content.isEmpty)
        #expect(content.count > 500, "Expected a substantive script, got \(content.count) bytes")
    }

    @Test("NotarizationWorkflowTest: notarize.sh contains required workflow steps")
    func notarizeScriptContainsRequiredSteps() throws {
        let content = try String(contentsOf: Self.notarizeScriptURL, encoding: .utf8)
        let requiredPhrases = [
            "xcodebuild archive",
            "xcodebuild -exportArchive",
            "notarytool submit",
            "stapler staple",
            "hdiutil create",
        ]
        for phrase in requiredPhrases {
            #expect(content.contains(phrase),
                    "notarize.sh is missing required step: '\(phrase)'")
        }
    }

    @Test("NotarizationWorkflowTest: notarize.sh references DirectDistribution configuration")
    func notarizeScriptUsesDirectDistributionConfig() throws {
        let content = try String(contentsOf: Self.notarizeScriptURL, encoding: .utf8)
        #expect(content.contains("DirectDistribution"),
                "notarize.sh should use the DirectDistribution build configuration")
    }

    @Test("NotarizationWorkflowTest: notarize.sh has a TEAM_ID guard")
    func notarizeScriptGuardsTeamId() throws {
        let content = try String(contentsOf: Self.notarizeScriptURL, encoding: .utf8)
        #expect(content.contains("TEAM_ID"),
                "notarize.sh must require a TEAM_ID to avoid unsigned builds")
    }

    @Test("NotarizationWorkflowTest: notarize.sh starts with a bash shebang")
    func notarizeScriptHasBashShebang() throws {
        let content = try String(contentsOf: Self.notarizeScriptURL, encoding: .utf8)
        #expect(content.hasPrefix("#!/usr/bin/env bash") || content.hasPrefix("#!/bin/bash"),
                "notarize.sh should start with a bash shebang")
    }
}
