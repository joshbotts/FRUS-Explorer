# FRUS Explorer

A macOS, iPadOS, and iOS application providing tools to help researchers use the
[Foreign Relations of the United States (FRUS)](https://history.state.gov/historicaldocuments)
series more effectively.

## Features

- Full-text search and filtering across the FRUS corpus (FTS5, English stemming)
- TEI-rendered document view faithful to history.state.gov content and annotation
- Document-level research notes and user tagging
- Cross-reference visualization showing linkages between documents
- AI summarization via Apple Intelligence (FoundationModels framework)
- User-configurable summarization prompts with structured output support
- Citation formatter (history.state.gov recommended style)
- Citation lookup: resolve citations encountered in publications to FRUS documents
- NARA Source Explorer: link document source notes to NARA Catalog records
- Composable document collections with PDF and HTML export
- CloudKit-synced user data (notes, tags, collections, projects)
- Offline functionality with download queue management

## Requirements

- **Xcode 26.0+** (macOS 26 SDK required)
- **macOS 26.0+** (development machine)
- **Swift 6.0+** with strict concurrency enabled
- Apple Developer account with the following capabilities:
  - iCloud (CloudKit + iCloud Documents)
  - iCloud Keychain Sharing
  - App Sandbox

## Project Structure

```
FRUSExplorer/
├── FRUSExplorer.xcodeproj        Xcode project (iOS/iPadOS + macOS app targets)
├── project.yml                   XcodeGen spec — edit this, not the .xcodeproj directly
├── FRUSExplorer/                 Main app source
│   ├── App/                      Entry point, AppState, root views
│   ├── Resources/                Bundled data (manifest, taxonomy, subject tags)
│   └── Localizable.strings       English base localisation
├── FRUSExplorerTests/            Unit tests
├── FRUSExplorerUITests/          UI tests
├── ManifestGenerator/            SPM tool: generates manifest.json from FRUS GitHub
├── TaxonomyGenerator/            SPM tool: generates volume-tag-taxonomy.json
├── Package.swift                 SPM manifest for command-line tools
├── FRUS-API.openapi.yaml         Living OpenAPI spec (future FRUS API)
└── Planning/                     Specification and development plan documents
```

## Building

### iOS / iPadOS

Select the **FRUSExplorer** scheme in Xcode. Build for any iOS/iPadOS simulator or device.

### macOS — App Store

Select the **FRUSExplorerMac** scheme with the **AppStore** build configuration.

### macOS — Direct Distribution

Select the **FRUSExplorerMac** scheme with the **DirectDistribution** build configuration.
This configuration links Sparkle for automatic updates. Before release, notarize the
built app via `notarytool`:

```sh
xcrun notarytool submit FRUSExplorer.dmg \
  --apple-id YOUR_APPLE_ID \
  --team-id YOUR_TEAM_ID \
  --password APP_SPECIFIC_PASSWORD \
  --wait
```

### Regenerating the Xcode Project

If `project.yml` is modified, regenerate the `.xcodeproj` using XcodeGen:

```sh
xcodegen generate --spec project.yml
```

### Command-Line Tools

```sh
# Regenerate manifest.json before each app release:
swift run ManifestGenerator

# Regenerate volume-tag-taxonomy.json when the taxonomy changes:
swift run TaxonomyGenerator
```

## Coding Standards

All code must comply with the following standards (see `Planning/FRUS-Explorer-Specification.md` §22):

- **Swift 6 strict concurrency** — zero warnings under `SWIFT_STRICT_CONCURRENCY=complete`
- **Localization** — all user-facing strings use `String(localized:)`; no hardcoded literals
- **Documentation** — every new type, function, and significant property carries a doc comment
- **Telemetry** — `#if DEBUG` print statements for all significant operations
- **Testing** — each development session produces unit tests; all prior tests must continue passing
- **OpenAPI** — `FRUS-API.openapi.yaml` updated in any session touching GitHub API or volume XML

## Architecture

```
┌─────────────────────────────────────────────┐
│                  SwiftUI Views               │
├─────────────────────────────────────────────┤
│              Service Layer                   │
│  (Summarization, Search, Export, Citation,  │
│   NARA Resolution, Download, Indexing)       │
├──────────────────┬──────────────────────────┤
│   SwiftData      │   SQLite FTS5 + Edge DB  │
│  (User Data +    │   (Search Index +        │
│   CloudKit Sync) │    Cross-References)     │
├──────────────────┴──────────────────────────┤
│           TEI Rendering Pipeline             │
│    (XML Parser → Swift AST → SwiftUI)        │
├─────────────────────────────────────────────┤
│           Network & Storage Layer            │
│  (GitHub API, NARA API, Volume Files,        │
│   Manifest, iCloud Keychain)                 │
└─────────────────────────────────────────────┘
```

## Bundle Identifiers

| Target | Bundle ID |
|--------|-----------|
| iOS/iPadOS app | `bottsywattsy.FRUS-Explorer` |
| macOS app | `bottsywattsy.FRUS-Explorer` |
| CloudKit container | `iCloud.bottsywattsy.FRUS-Explorer` |

The bundle identifier is registered in App Store Connect. Do not change it.

## License

Apache 2.0. See [LICENSE](LICENSE) for the full license text.

All source files carry the Apache 2.0 license header.

## Contributing

1. Read `Planning/FRUS-Explorer-Specification.md` to understand the full application design
2. Read `Planning/DEVELOPMENT-PLAN.md` for the session sequence and dependency graph
3. Each session's task file (e.g. `Planning/03-FTS5-Wrapper.md`) describes prerequisites,
   outputs, and tests for that unit of work
4. Ensure all existing tests pass before committing session output
5. Update `FRUS-API.openapi.yaml` if your session touches GitHub API or volume XML
