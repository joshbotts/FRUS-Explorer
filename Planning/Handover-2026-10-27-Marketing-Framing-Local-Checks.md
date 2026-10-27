# Hand-over: local checks for the marketing-framing pass of 2026-10-27

**Status:** OPEN until a local session has run the checks below. Delete this file, or move it to
`Planning/Completed/`, in the pull request that records the run.

**What this pass changed, and why.** The owner revised the internal briefing deck on 2026-10-26
(`Docs/Briefing/`, deliberately uncommitted) and chose, on 2026-10-27, to carry its framing into
every other surface but the app's About screen. The branch `claude/powerpoint-app-briefing-0a7ec8-c41qsy`
holds the pass, written on a Linux container with no Xcode and no simulator: nothing below could be
run there. The commit touches prose only: no Swift, no test file, no resource.

| Surface | File | What changed |
|---|---|---|
| Launch kit | `Planning/Launch-Marketing-Kit-2026-10-13.md` | header note; §1's line, pitch, two table cells and *What it is not*; §1a's right column; §5.1, §5.2, §5.3's first post, §5.4, §5.5's first answer; two §6 rows |
| Store draft | `Planning/Store-Listing-Draft.md` | header note; §2's disclaimer and BUILT ON THE EDITORS' WORK section, recounted at 3,423 / 4,000; a note under the editors' theme |
| Support page | `Docs/Support.md`, `Docs/Website/support.html` (rebuilt), `Docs/Website/README.md` | the opening sentence credits the Office's open TEI editions; the disclaimer; two rows of the claim table |
| README | `README.md`, `Docs/EditableContent/03-Repository-README.md`, `Docs/EditableContent/Amendment-Log.md` | the two opening paragraphs; the `Current build:` line is untouched |
| Manuals | `Docs/iOS-User-Manual.md`, `Docs/macOS-User-Manual.md` | the closing disclaimer, now the same sentence in both (they disagreed with each other before) |
| Not changed | `FRUSExplorer/Settings/AboutView.swift`, `Docs/EditableContent/01-About-and-Onboarding.md`, `Docs/Privacy-Policy.md`, `Planning/Visual-Marketing-Plan.md` | the owner keeps the About screen's wording; the policy makes no official-status claim; the plan's §7 is read by a test and was left alone |

## 1. The checks to run

One job at a time, through `Scripts/heavy.sh` (`CLAUDE.md`, *Build & Test Commands*).

```bash
Scripts/heavy.sh xcodebuild test \
  -project FRUSExplorer.xcodeproj \
  -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=27.0" \
  -only-testing FRUSExplorerTests/CodingStandardsAuditTests \
  -only-testing FRUSExplorerTests/EditableContentKeyTests \
  -only-testing FRUSExplorerTests/ResearchGuideCoverageTests
```

Read the test count back: an `-only-testing` name that matches nothing runs zero tests and reports
green.

| Suite | Why it is owed | Expected |
|---|---|---|
| `CodingStandardsAuditTests` | `readmeStatesCurrentBuild` reads `README.md`'s `Current build:` line, which moved from the end of one paragraph to the end of a longer one; `planOfRecordMatchesTheVisualMarketingPlan` reads a file this pass did not touch | pass, no pin to re-take |
| `EditableContentKeyTests` | `03-Repository-README.md` changed (a whole-file block with no `lines:` range) and `Amendment-Log.md` gained a bullet; `01-About-and-Onboarding.md`'s ranged block for `about.dos.disclaimer` was not touched and `AboutView.swift` did not move | pass, no range to re-point |
| `ResearchGuideCoverageTests` | `manualsCoverTheLateAdditions` reads both manuals for three phrases (`method appendix`, `count_basis` or `at least 7,500`, `paraphrase does not pass`), none of which this pass touched | pass |

Also, from the repository root, with no Xcode needed (already run on the container, exit 0, and
owed again only if the Support page is edited further):

```bash
python3 Scripts/build_website_pages.py --check
```

## 2. If a check fails

- **`readmeStatesCurrentBuild`**: the README's line must read `Current build: **1776** (version 1.0)`
  and match `project.yml`. If `project.yml` has moved on since (a TestFlight upload between 1776 and
  1861, or the restore to 1861 for R3), the README line and its mirror in
  `Docs/EditableContent/03-Repository-README.md` follow the bump procedure in `CLAUDE.md`; this pass
  is not the cause.
- **`EditableContentKeyTests`**: the failure names the key and its real line. The only block this
  pass changed is `repo.readme`, which has no range. A failure on `about.dos.disclaimer` means
  `AboutView.swift` moved under it in a merge since; re-point the range to start on the key's line
  and keep its length, and log the re-point in `Amendment-Log.md`.
- **`manualsCoverTheLateAdditions`**: cannot fail from this pass; if it does, the merge brought a
  manual edit with it.

## 3. The steps outside the repository, the owner's

1. **The Support page on frusexplorer.app.** Paste the body of the rebuilt
   `Docs/Website/support.html` (everything between `<body>` and `</body>`) into the Code Block of
   the page whose slug is `support`, as `Docs/Website/README.md` describes. The published page is a
   third copy the repository cannot see, and it is in step only after the paste. The privacy page
   did not change.
2. **App Store Connect.** The description in `Planning/Store-Listing-Draft.md` §2 is the copy of
   record for the field; paste it when the listing is next edited, and run the draft's §6 counter
   first. The promotional text, subtitle and keywords did not change.
3. **The manuals** are read from GitHub by the app's About links, so they are live once the branch
   merges to `v2`; nothing to paste.
