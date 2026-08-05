# Session 01 — Project Setup & Build Configuration

## Goal
Create the Xcode project with all targets, build configurations, SPM dependencies, entitlements, and signing configurations required for the full FRUS Explorer development lifecycle. All subsequent sessions build on this foundation without revisiting these choices.

## Prerequisites
- Xcode supporting macOS 26, iPadOS 26, iOS 26 SDKs
- Apple Developer account with iCloud, CloudKit, and iCloud Keychain Sharing capabilities enabled
- Access to the HistoryAtState GitHub repository (for later sessions; confirmed accessible now)

## Given Inputs (do not change these)

**Bundle identifier**: `bottsywattsy.FRUS-Explorer`
This identifier is already registered in App Store Connect from a prior TestFlight submission. Use it exactly as written in all three platform targets. Do not create a new identifier.

**App Store Connect record**: the existing "FRUS Explorer" record linked to the above bundle identifier. Do not delete or create a new record. The new project connects to it automatically once the bundle identifier and signing certificate match.

**CloudKit container**: `iCloud.bottsywattsy.FRUS-Explorer`
Verify this container exists in App Store Connect (Certificates, Identifiers & Profiles → Identifiers → iCloud Containers) before configuring entitlements. Create it if it does not exist from the prior project.

**Note on bundle identifier format**: the hyphen in `FRUS-Explorer` is non-standard but accepted by Apple. If any entitlement or CloudKit configuration rejects the hyphen, substitute `FRUS-Explorer` with `FRUSExplorer` in that specific context only and document the discrepancy clearly in a code comment.

## Specification References
- Section 3: Platform & Toolchain
- Section 5: Data Architecture (entitlements)
- Section 17: App Identity & Distribution
- Section 22: Coding Standards

## Inputs
None. This is the root session.

## Outputs

### Xcode Project Structure
```
FRUSExplorer/
├── FRUSExplorer.xcodeproj
├── FRUSExplorer/                    # Main app source
│   ├── App/
│   │   ├── FRUSExplorerApp.swift
│   │   └── AppState.swift
│   ├── Resources/
│   │   ├── manifest.json                # Placeholder; populated in Session 02
│   │   ├── volume-tag-taxonomy.json     # Placeholder; populated in Session 02
│   │   ├── taxonomy.json                # Placeholder; populated in Session 08
│   │   └── subject-appearances.json     # Placeholder; populated in Session 08
│   └── Localizable.strings
├── FRUSExplorerTests/               # Unit test target
├── FRUSExplorerUITests/             # UI test target
├── ManifestGenerator/               # SPM executable target (Session 02)
├── TaxonomyGenerator/               # SPM executable target (Session 02)
├── Package.swift                    # SPM manifest
├── FRUS-API.openapi.yaml            # Living OpenAPI document
└── README.md
```

### Build Configurations
Two build configurations for the macOS target:

**AppStore**
- Provisioning: App Store profile
- Entitlements: `FRUSExplorer-AppStore.entitlements`
- Signing: Automatic (App Store)

**DirectDistribution**  
- Provisioning: Developer ID profile
- Entitlements: `FRUSExplorer-DirectDistribution.entitlements`
- Signing: Developer ID Application certificate
- Includes Sparkle SPM dependency (update framework)

iOS and iPadOS targets have a single App Store configuration.

Both macOS configurations maintain identical sandbox posture. The entitlement files differ only where App Store and Developer ID requirements diverge.

### Required Entitlements (both macOS configurations)
```xml
com.apple.security.app-sandbox = true
com.apple.security.network.client = true
com.apple.developer.icloud-containers = [iCloud.bottsywattsy.FRUS-Explorer]
com.apple.developer.ubiquity-kvstore-identifier = $(TeamIdentifierPrefix)bottsywattsy.FRUS-Explorer
com.apple.developer.icloud-keychain-sharing = [bottsywattsy.FRUS-Explorer.shared]
com.apple.developer.cloudkit = true
```

Note: if the hyphen in `FRUS-Explorer` causes a rejection in any entitlement value, substitute `FRUSExplorer` in that value only and add a comment explaining the discrepancy.

### SPM Dependencies (`Package.swift`)
```swift
// Sparkle — direct distribution macOS update delivery
// Only linked in DirectDistribution build configuration
.package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0")
```
No other external SPM dependencies. All other functionality uses native frameworks or project-written components.

### `AppState.swift`
The central observable application state object. At this session, implement:
```swift
/// AppState is the root observable state object for FRUS Explorer.
/// It holds application-level state that must be accessible across
/// the entire view hierarchy and persists across launches via UserDefaults.
///
/// Project context: AppState serves as the bridge between the user's
/// active research focus (activeProjectId) and the SwiftData/CloudKit
/// layer that stores all user-generated content. Views observe AppState
/// to react to project switching without requiring data migration.
@Observable
final class AppState {
    var activeProjectId: UUID?       // nil = no active project (global context)
    var isOnline: Bool               // network reachability
    var downloadQueue: [String]      // volumeIds queued for download
}
```

### Initial OpenAPI Document
Create `FRUS-API.openapi.yaml` with:
- OpenAPI 3.1 header
- Info block (title: "FRUS API", version: "0.1.0-draft")
- A comment block explaining the document's purpose as a living specification
- Empty `paths:` block (populated in subsequent sessions)

## Tasks

1. Create the Xcode project with the structure above
2. Configure three targets: iOS/iPadOS app, macOS app, unit tests, UI tests
3. Create both macOS build configurations with correct entitlement files
4. Add Sparkle as a conditional SPM dependency for DirectDistribution only
5. Create `AppState.swift` with documentation and `#if DEBUG` logging for state changes
6. Create placeholder resource files (`manifest.json`, `volume-tag-taxonomy.json`, `taxonomy.json`, `subject-appearances.json`) with empty but valid JSON structures (empty arrays `[]` for all)
7. Create `Localizable.strings` with a comment explaining the localization requirement
8. Create the initial `FRUS-API.openapi.yaml`
9. Create `README.md` with project overview, build instructions for both macOS configurations, and contributor guidance
10. Verify the project builds successfully for all three platforms with zero warnings under Swift 6 strict concurrency checking

## Tests

### Session 01 Tests
- **BuildTest**: Project compiles for macOS (AppStore config), macOS (DirectDistribution config), iPadOS, and iOS with zero errors and zero concurrency warnings
- **AppStateTest**: `AppState` initializes correctly; `activeProjectId` defaults to nil; state changes trigger `@Observable` notifications
- **EntitlementsTest**: Verify both macOS entitlement files contain the required keys (parse as plist and check)

## Coding Standards Checklist
- [ ] All types have documentation comments
- [ ] `AppState` changes logged with `#if DEBUG`
- [ ] `Localizable.strings` created; no hardcoded UI strings
- [ ] `FRUS-API.openapi.yaml` created
- [ ] Swift 6 strict concurrency: zero warnings
