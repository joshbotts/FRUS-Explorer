# Session 31 — Final Integration Testing

## Goal
Conduct end-to-end integration testing across the full application, including performance testing at corpus scale and validation of all cross-session component interactions.

## Prerequisites
- All prior sessions complete

## Specification References
- All sections (integration of all components)

## Test Categories

### End-to-End Workflow Tests
- **FullOnboardingTest**: Fresh install → onboarding → select volumes → download → index → search
- **ResearchWorkflowTest**: Browse to document → generate summary → create research note → add to collection → export
- **CrossReferenceWorkflowTest**: Open document → view cross-reference graph → navigate to referenced document → return
- **ProjectContextWorkflowTest**: Create two projects → work in project A → switch to project B → verify context isolation → view global context
- **SourceExplorerWorkflowTest**: Open document with known source note → open Source Explorer → verify provenance resolution

### Performance Tests
- **LargeCorpusIndexTest**: Index 10+ volumes totaling >100MB; verify completion within acceptable time; verify search results correct
- **SearchPerformanceTest**: Full-text search across indexed corpus; verify results returned within 1 second
- **GraphRenderPerformanceTest**: Render graph with 20 nodes; verify 60fps; render with 100 nodes; verify acceptable frame rate
- **BrowserPerformanceTest**: Browse corpus-level view with all volumes loaded; verify no perceptible lag

### Regression Tests
- Run all unit tests from all prior sessions; verify 100% pass rate
- Run all UI tests; verify 100% pass rate

### Cross-Platform Verification
- Verify all major workflows on macOS (App Store config), macOS (DirectDistribution config), iPadOS, and iPhone
- Verify iCloud sync: perform action on one platform; verify data appears on a second platform

### Data Integrity Tests
- **CloudKitSyncTest**: Create research note on device A; verify appears on device B via CloudKit
- **OfflineResilienceTest**: Disable network; use app; re-enable network; verify no data loss
- **IndexConsistencyTest**: Download volume, index, delete volume, re-download, re-index; verify search results consistent

## Coding Standards Final Checklist
- [ ] Zero Swift 6 concurrency warnings across all targets
- [ ] All user-facing strings localized (no hardcoded literals)
- [ ] All public types and functions documented
- [ ] `FRUS-API.openapi.yaml` complete and validated
- [ ] All `#if DEBUG` telemetry logging in place
- [ ] Both macOS build configurations verified
- [ ] README updated with final build and contribution instructions
