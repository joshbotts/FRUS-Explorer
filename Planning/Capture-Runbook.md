# Capture runbook — filming what already ships

**Status:** 2026-08-31. Visual-marketing plan §7 step 4, *"film what already exists — one
afternoon, zero code"*. The frame sequence half is **run and measured** below. The rest is an
afternoon at a device, and it is the owner's: §2(b) establishes that the splash and onboarding
frames are manual on an erased device, in a window that occurs once per install.

---

## 1. The frame sequence — RUN 2026-08-31, and it holds

```bash
TEST_RUNNER_RENDER_MAP_FRAMES_DIR=/tmp/map-frames xcodebuild test \
  -project FRUSExplorer.xcodeproj -scheme FRUSExplorer \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -only-testing FRUSExplorerTests/SemanticMapFrameSequenceTests
```

**Copy that as it stands — it is the whole command.** `name=` is the house idiom (`CLAUDE.md` uses
it for every documented test run) and it resolves even with several iOS runtimes installed, so
there is nothing to substitute. An earlier draft wrote `id=<UDID>`, which is not a command but a
fill-in-the-blank: pasted verbatim it fails with *"Unable to find a device matching the provided
destination specifier"* and forty lines of devices. Where a UDID is genuinely needed — `simctl`,
below — this document resolves it for you.

Two things about that command are load-bearing and both are in the harness's own doc comment: the
env var **must** wear xcodebuild's `TEST_RUNNER_` prefix (a trailing `KEY=VALUE` is a build setting
and never reaches the test process), and the filter **must** stop at the suite (a function-level
`-only-testing` matches zero tests here and reports "passed").

| | Measured 2026-08-31 | Recorded 2026-08-27 |
|---|---|---|
| Frames | **553** | 553 |
| Mean per frame | **100.8 ms** | 103.8 ms |
| Worst | **122.8 ms** | 123.9 ms |
| Wall clock | ~56 s | 57.6 s |
| Output | **392 MB**, 1920×1080 PNG | — |

Re-run 2026-08-31 on **iPhone 17**, the device this runbook now names: 553 frames, mean 104.9 ms,
worst 201.6 ms, same 553 files. The worst-frame figure is well above the 16e's 122.8 ms while the
mean barely moves — the shape of a warm-up outlier, not a slower device. The output is identical
either way: the sequence is deterministic in the artifact, not in the host.

Files `frame-0000.png` … `frame-0552.png`, **no gaps**, plus `frames.csv` (554 lines: header + 553)
and `provenance.txt`. Assemble with:

```bash
ffmpeg -framerate 12 -i frame-%04d.png -pix_fmt yuv420p map.mp4
```

### What running it found that reading it did not

**The sequence opens in 1620, and its first six frames are a lie about chronology.**

| Frame | coverage_start | Volume |
|---|---|---|
| 0 | 1620-11-03 | `frus1872p2v5` |
| 1 | 1697-01-01 | `frus1902app2` |
| 2 | 1793-08-23 | `frus1873p2v3` |
| 3 | 1802-04-14 | `frus1873p1v2` |
| 4 | 1803-05-04 | `frus1872p2v2` |
| 5 | 1811-07-18 | `frus1872p2v1` |

The ordering is by `dateRange.earliest`, and FRUS prints historical enclosures in arbitration
papers — so three volumes published in the 1870s–1900s carry documents from before 1800. **A viewer
watching "the published record accumulate chronologically" reads the opening as *the record begins
in 1620*.** It does not; the series begins in 1861.

This is a §5-class problem — a caption that a promotional clip would make false — and it is **not**
a defect in the harness: ordering by earliest coverage is the honest thing for the harness to do.
It is a captioning obligation for anything assembled from these frames. Three options, none of
them requiring code:

1. **Caption it.** *"Ordered by each volume's earliest document; three early volumes print
   historical enclosures, so the sequence opens before 1800."* Truthful, and mildly interesting.
2. **Start at frame 6.** The clip then opens in 1811 and no caption is owed. Cheapest.
3. **Say nothing and open on 1620.** Not available — it is the failure §5 exists to prevent.

**The `provenance.txt` defects are confirmed, and both are literals in the test target.** The
sidecar as written today says *"Only the **0** volume(s) indexed on this device can be opened from
it"* (`indexedVolumeCount: 0`), and hard-codes `lens: .cluster` regardless of what was rendered.
The first is visibly wrong in a file meant to be published beside the frames; the second is latent,
and only correct today because the harness happens to render on the default lens. Plan step 11
already schedules both.

**The nil-frame hazard is real, was fixed in this pass, and did not fire in this run.** All 553
frames rendered, so the pre-flight would have passed — which is exactly why it was the wrong guard.
See §4.

---

## 2. What to film, and what each shot is for

`§3.1` is the inventory. **The Renderer column decides what you are looking at**: the splash and
the onboarding cloud have never run the particle canvas, so their words are static and only the
splash's shimmer moves.

| Shot | Device state | Notes |
|---|---|---|
| Launch splash + shimmer | **Erased** | Lives exactly 1.6 s. One take per install — see §3. Now opens on a **fixed lens** (M-5), so takes are comparable. |
| Onboarding scope-tracking cloud | **Erased** | *"The best 8-second demo in the app."* Hold for the LensChip — see §3. |
| Indexing drift cloud | Downloading | The app's **only** continuous particle animation. |
| Lens picker (semantic map) | Full corpus | Now carries the **dip** (M-3); film the swap, not a still. |
| Camera transit on region focus | Full corpus | See §5 — the "before" shot needs Reduce Motion. |
| Live Activity / Dynamic Island | **Physical iPhone** | No simulator route exists. Discover that now, not in submission week. |

---

## 3. The two traps that make a plausible-looking take wrong

**`prepareVolumes` — the most valuable operational line in §4.1.** Switching to Volume scope fires
`BundledCloudVectors.prepareVolumes()`; until it resolves, a volume scope falls back to the
**subseries** list. An early frame therefore shows the *era's* vocabulary and looks entirely
plausible. **Hold for the LensChip before recording.**

**The splash is unrepeatable within an install.** `CloudSurfaceArbiter.resolve` is one `switch`:
any pending corpus work returns `.indexingBackdrop`, and only then is the fresh-install splash
reachable. **One queued download permanently replaces it.** So the splash and a corpus-bearing
device are mutually exclusive by construction, which is why the App Preview is cut from two passes
and why every splash take costs an erase.

---

## 4. One thing that was code, and why it was worth breaking "zero code"

The harness skipped a failed frame with `continue`. The consequence was not a missing frame but a
**corrupted sequence that looks complete**: `writeFrame` takes the loop index while the closing
frame takes `records.count`, so one skip leaves a hole *and* makes the closing frame overwrite a
real one — `ffmpeg` stops at the hole, and a frame is silently replaced.

Plan step 11's remedy was a manual pre-flight (`ls | wc -l` against `records.count`) before
assembling. It now **throws** instead. A ritual that guards a silent corruption is the weakest
possible guard, and this repo refuses rather than checklists everywhere else a generator can produce
a plausible wrong artifact.

---

## 5. The "before" shot for M-1 — recoverable, but not the way step 4 assumed

Step 4 says *"the teleport recording is the 'before' shot that justifies M-1"*, and the plan
expected step 4 to run before steps 7–9. It ran after, so **the teleport no longer exists to
film.**

It is still recordable, exactly: **turn on Reduce Motion.** M-2's contract makes the Reduce Motion
path the behaviour that shipped for the map's whole life — the camera lands instantly. So the
before/after pair is one setting toggle on one device, which is a better comparison than two builds
would have been. Film both takes back to back.

---

## 8. Which device class to shoot on

§6 flags this and could not settle it: *"Device classes are asserted, not verified. The documented
capture program is iPhone 17 + iPad Pro 11″; store requirements (6.9″, 13″) are external facts."*
Still true — App Store Connect is the authority and it is outside this repo. But the two required
classes map onto simulators already installed here, and they are **not** the two the capture
program names:

| Purpose | Class | Simulator |
|---|---|---|
| Store screenshots — iPhone | 6.9″ | **iPhone 17 Pro Max** |
| Store screenshots — iPad | 13″ | **iPad Pro 13-inch (M5)** |
| Figures, film, frame sequence | any | iPhone 17 — what this runbook's commands name |

So do not shoot store assets on the device you render figures on without checking: `iPhone 17` is
the 6.3″ class, and the plan's `iPad Pro 11″` is not the 13″ one. **Confirm against App Store
Connect before a submission pass** — that instruction stands unchanged. What is new is that the
substitute devices are named and present.

---

## 7. The three device states (step 6)

| State | What it is | How to reach it |
|---|---|---|
| **A** | Corpus-empty, fresh install | Erase the simulator. The splash is reachable **only** here. |
| **B** | Corpus-full | Already satisfied — 552 volumes, 316,839 documents on the author's Mac. |
| **C** | A library that has been *worked in* | State B **plus** `FRUS_CAPTURE_SEED=1` on one launch. |

**Why C exists.** §6 records that A and B are incomplete: a project header, a collection with
entries, tagged documents and saved searches are none of them downloaded and none of them bundled,
so on a corpus-full device every one of those screens is still an empty state — and they are the
screens a research app most needs to show.

`CaptureStateSeeder` builds C. It is `#if DEBUG`, inert unless `FRUS_CAPTURE_SEED=1`, and
idempotent by project name, mirroring the two seeders already on that boot path.

```bash
# Resolve the capture device once — newest installed runtime that has it.
UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
match = ""
for runtime in sorted(devices):
    for device in devices[runtime]:
        if device["name"] == "iPhone 17":
            match = device["udid"]
print(match)')
echo "$UDID"

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl launch "$UDID" bottsywattsy.FRUS-Explorer --setenv FRUS_CAPTURE_SEED 1
```

Change the device name in that snippet to whichever class you are shooting — see §8.

Three things that will otherwise cost you an afternoon:

- **The app must already be installed on that simulator.** `simctl launch` does not build. Run the
  app to the device once from Xcode (or `simctl install`) first; otherwise this returns
  *"Unable to find application"*.
- **Do not add `--console`.** It attaches to the process and does not return until the app exits, so
  the terminal appears to hang. Add it only when you want to read the seeder's confirmation line,
  and expect to quit the app to get your prompt back.
- **Shut the simulator down when you are finished.** A simulator left booted competes with the test
  suite for the machine and is a known source of wall-clock flakes.

**It seeds the structure and not the words.** Every body reads *"Replace before capture."* Edit
`CaptureStateSeeder.Content` — one enum of plain data, no code — and re-run. That division is
deliberate: the prose in a store screenshot of a research tool is a historian's to write, and a
note that reads plausibly while saying something slightly wrong about the record would be wrong in
the one place nobody re-reads. A test fails if the placeholder ever stops saying "replace".

**§6 said State C "must wait for person-rollup consolidation".** Nothing in the seeded structure
touches person rollups — no `PersonClusterOverride`, no rollup read — so that dependency does not
bind here. If it was meant to gate a *person-profile* screenshot, that is a separate shot and still
waits.

### Confirming State A still shows the splash

Step 6 says to confirm this before shooting, and it cannot be automated: the UI-test guard returns
`.none` unconditionally, so the XCUITest harness can never see the splash (§2(b)).

What **is** checkable, and is pinned by `CloudSurfaceArbiterTests`, is the arbiter's verdict for
State A's inputs. What is not checkable is that the verdict reaches the screen — and there is a
known window where it does not: with a download **queued but no batch started**, `resolve` returns
`.indexingBackdrop`, `ContentView` withholds the splash, and `MainTabView` never mounts the strip,
so nothing renders. So the confirmation is: **erase, launch with no download queued, watch for the
splash.** If it is missing, check whether anything is queued before assuming a regression.

---

## 6. What this settles

Step 4 exists to answer *does the material justify engineering before a line is written*. Read
against what has since shipped:

- **The frame sequence is publishable today** — 553 frames, deterministic, with its grain sentence
  in `provenance.txt` — subject to §1's captioning obligation and step 11's two literals.
- **The lens dip and the camera transit are worth filming** and were worth building; both are
  visible in a way a still cannot show, which is the argument §3.2 made and could not demonstrate.
- **The splash is the weakest of the four.** Its words are static, its only motion is a 140×3 pt
  shimmer, and it lives 1.6 s. M-4 would change that by enabling a renderer on a first-run
  composition — priced `S in code, M in risk` — and nothing here argues for pulling it forward.
