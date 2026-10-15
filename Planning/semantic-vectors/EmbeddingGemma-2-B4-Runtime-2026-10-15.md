# EmbeddingGemma 2, B4 part 1: the runtime rebuilt at a0e6dc73, the shipped model unchanged, and step 7's parity

**Date:** 2026-10-15 · **Status:** B4'S FIRST PULL REQUEST (plan of record §1 and §3, B4). The runtime
moves; the model, its download pin and every semantic artifact stay EmbeddingGemma 300m's until
the second pull request. · **Issue:** #1659 · **Design:** `EmbeddingGemma-2-Spike-2026-10-14.md` §2,
step 7 · **Stages:** `EmbeddingGemma-2-Stage-1-2026-10-14.md`, `EmbeddingGemma-2-Stage-2-2026-10-15.md`
· **Machine:** the M5 MacBook Air (`Mac17,4`, 32 GB), macOS 27.0.1, Xcode 27.0 · **Runtime:** llama.cpp
`a0e6dc7384edb8f5d927155e1d26c10b4a310e6d`, replacing `86632248188c106d749fad34a1dcd237c95863d4` ·
**Weights:** EmbeddingGemma 300m `embeddinggemma-300m-qat-Q4_0.gguf` (229,093,184 bytes, `5a9e0645…`) and
EmbeddingGemma 2 `embeddinggemma-2-Q8_0.gguf` (309,855,456 bytes, `2188ac1d…40b09135`), both SHA-checked
today · **Artifacts and the scripts that made them:** `eg2-b4-runtime-2026-10-15/`.

Every figure was measured on 2026-10-15 on the Air, except the owner's iPhone's, which §5 records
from the run of that day (added by B4's second pull request,
`EmbeddingGemma-2-B4-Move-2026-10-15.md`).

## 0. In short

- **The runtime is rebuilt at `a0e6dc73`** by upstream's own script, unmodified, in 2 min 43 s. The
  three slices grow by about half (the iOS device slice from 7.90 to 11.93 MB), most of it Metal
  shaders (§1).
- **The build script's dSYM zip did not fit the fetch script**, and never had: it zipped
  `build-apple/llama.xcframework/…` where the August asset and `fetch-llama-dsyms.sh` hold
  `llama.xcframework/…`. Fixed, and the committed framework and the zip come from one run of the
  fixed script; all six UUIDs verify through the fetch script, and the archive phase's script
  accepts each platform's dSYM (§1).
- **The shipped model is unchanged.** EmbeddingGemma 300m through the new runtime meets the
  committed fixture, made at `8663224`, at min cosine 0.999862 on the simulator's CPU (August's
  wrapper: 0.99986), 0.9999996 on the Mac's Metal, and 0.9999994 command line against command line.
  The parity suite's four tests pass, and the Mac check copy's Meaning search for "reparations"
  returns the 14 matches it returned on 2026-10-11 (§2).
- **EmbeddingGemma 2 passes step 7 on the simulator and the Mac**: min cosine 0.999714 on the
  simulator's CPU and 0.9999997 on the Mac's Metal, against a fixture regenerated at `a0e6dc7`
  that is vector for vector B2's (§3). The iPhone run is the owner's (§5).
- **The rebuild changes latency and memory a little, for the better.** On the Mac's Metal, through
  the app's encoder source, the 300m's warm encode falls from 6.2–6.5 ms to 4.7–5.3 ms and its peak
  footprint from 160–162 to 132–134 MB; its load is 8–15 ms slower. EmbeddingGemma 2 costs about
  70 MB more footprint than the 300m on Metal (203–205 MB) and 130–140 ms more load; on the
  simulator's CPU path the two peak alike (347–350 MB) (§4).
- **Stage 1's memory comparison set different shapes side by side**: its 507 MB for `a0e6dc7` was
  the peak over 1-prompt and 100-prompt invocations, the record's 639 MB for `8663224` one
  25-prompt invocation. Like for like, the new runtime is lower in both (§4).
- **The dSYM release is uploaded**, on the owner's word after this pull request merged, and
  verified from the release (§6). **The owner's iPhone passed step 7** for both models, at the
  Mac's figures (§5).

## 1. The rebuild

**The commit.** `a0e6dc73` (master, 2026-10-14) is past upstream PR 30054 (`4fbc76de`, 2026-10-06),
which added the `gemma-embedding2` architecture, and it is the runtime EmbeddingGemma 2's corpus
store was embedded through (the stage-2 memo's §1) and the 300m's was re-checked through (stage 1's
§4: cosine ≥ 0.999982 against the shipped store). So the app's query encoder is the same engine as
the document encoder that made the vectors it will search. Thirty commits followed it on master by
the time of the rebuild; none, by its title, touches the new architecture, so none is a reason to
move.

**The build.** `Scripts/build-llama-xcframework.sh` with `LLAMA_COMMIT` changed, which runs
upstream's `build-xcframework.sh ios-sim ios-device macos` unmodified: 2 min 47 s for the first
run and 2 min 43 s for the second, the one committed. The encoder's C API calls are unchanged
between the two commits (`llama.h` diffed for every call `SemanticQueryEncoder` makes), so no Swift
changes.

**The zip's layout.** The first run's zip held `build-apple/llama.xcframework/<slice>/dSYMs/…`, and
`fetch-llama-dsyms.sh` refused it (`cp: …/unpacked/llama.xcframework/*//dSYMs/…: No such file or
directory`). The `8663224` asset on `encoder-1`, read through its zip directory by a range request,
holds `llama.xcframework/<slice>/dSYMs/…`. It is not the zip the August script wrote, which was
`llama-xcframework-dSYMs.zip` with the `build-apple/` paths (#1125's version of the script), and #1350
wrote the fetch script against the asset, so the script's own zip and the fetch script had never
met. The build script now zips from inside `build-apple/`. The first run's framework and zip were
discarded, and the second run of the fixed script made both.

**The slices**, bytes of each framework binary:

| slice | `8663224` | `a0e6dc7` | change |
|---|---|---|---|
| `ios-arm64` (the iPhone and iPad app) | 7,899,016 | 11,931,672 | +4,032,656 (+51%) |
| `ios-arm64_x86_64-simulator` | 16,527,040 | 24,703,728 | +8,176,688 (+49%) |
| `macos-arm64_x86_64` (the Mac app) | 16,563,920 | 24,773,088 | +8,209,168 (+50%) |
| `Vendor/llama.xcframework`, `du -sk` | 40,996 KB | 60,980 KB | +19,984 KB |

In each arm64 slice the embedded Metal library (`__DATA,__ggml_metallib`) grew from 1,799,215 to
5,202,420 bytes and the code (`__TEXT,__text`) by about 0.4 MB (4,119,156 to 4,520,420 in the
device slice): upstream's kernels of the seven weeks between the commits (2026-08-28 and 10-14).
The iOS app's download grows by about the device slice's 4 MB before App Store compression.

**The dSYMs.** `llama-xcframework-dSYMs-a0e6dc7.zip`, 91,570,299 bytes, SHA-256
`35d6e829b5906d27550aa06a37e6cf2ec7617e3699b22d6fadfa5677eb59f73d`, DWARF 62,643,298 /
125,333,102 / 125,611,586 bytes for the device, simulator and Mac slices (the `8663224` asset:
126,278,686 bytes, DWARF 77.7 / 155.5 / 155.7 MB). UUIDs, the committed binaries' and the zip's
alike:

| slice | arm64 | x86_64 |
|---|---|---|
| `ios-arm64` | `4D3C4A5A-2265-3848-974A-DBEFCA8CC250` | — |
| `ios-arm64_x86_64-simulator` | `AA082396-66BA-3775-BABF-A76BA5F49BF1` | `4C3B09E7-7210-3FEC-9BDD-926F8B625EF7` |
| `macos-arm64_x86_64` | `6C58993B-32DB-3F6B-9DE0-E4B60E420D98` | `9A875EAC-4854-36F2-9432-5C7B0C95410D` |

`DSYM_ZIP=… ./Scripts/fetch-llama-dsyms.sh` installed the zip into `.cache/llama-dSYMs/` and verified
all six; a second run said there was nothing to fetch. `Scripts/embed-llama-dsyms.sh`, the
archive-only phase's script, run by hand with `ACTION=install` for `iphoneos`, `iphonesimulator` and
`macosx` into scratch folders, embedded each slice's dSYM and re-checked its UUIDs. That was outside
the script sandbox: no archive was made, and the phase's declarations are unchanged, since every
path it reads carries no commit.

## 2. The shipped model is unchanged

| check | engine | min cosine | worst query |
|---|---|---|---|
| `QueryEncoderParityTests`, iPhone 17 simulator, iOS 27.0, CPU (the encoder's simulator rule) | the wrapper, `a0e6dc7` | 0.999862 | "Deposing shah" |
| the same suite in August (V-5 s2, iPhone 16e simulator) | the wrapper, `8663224` | 0.99986 | — |
| the command line against itself, `-ngl 0` against Metal | `llama-embedding`, `a0e6dc7` | 0.999865 | the Chinese Civil War query |
| the Mac harness (§4), macOS slice, Metal, three runs | the wrapper, `a0e6dc7` | 0.9999996 | "Deposing shah" |
| the same harness on the `8663224` slice, three runs | the wrapper, `8663224` | 0.9999998 | — |
| `llama-embedding` against the committed fixture, Metal | `a0e6dc7` against `8663224` | 0.9999994 (median 0.9999999) | — |

All against the committed fixture, made at `8663224` in August, except the third row, which sets
the CPU path against the Metal path of the same build. All four tests of the suite pass with the
300m on the simulator: the parity, the funnel (the encoded query fills the rerank pool), the memory
shape, and the end-to-end test, which prints that the local shards are absent and returns, as in
any checkout without them. The simulator's 0.999862 is the backend skew the suite's bar was set
for, and it matches the command line's own CPU-against-Metal figure to five decimals.

**The Mac app itself.** The isolated check copy (`tools/mac-check-copy/`), built from this pull
request's commit in its release configuration and embedding the new slice (arm64 UUID `6C58993B…`),
ran a Meaning search for "reparations" against its 36 indexed volumes and the 300m it downloaded on
2026-10-11: 14 closest matches, the count it gave that day under the old runtime, led by
`frus1945Berlinv02` documents 894 (63%) and 900 (59%). It still read "Searching…" six seconds after
Return and had its list eight seconds later; the harness's first load of the 300m through the new
slice took 10 seconds, and later ones 0.18–0.20. The installed app was not run.

## 3. EmbeddingGemma 2's parity (design step 7)

**The fixture.** `make_query_parity_fixture.py` through `llama-embedding` at `a0e6dc7` (the Metal
build stage 1 made, `~/Development/llama.cpp-eg2`) and the Q8_0 GGUF: 25 queries, 768 dimensions.
Its vectors are B2's scratch fixture's, all 25 identical; its label now reads `llama-embedding
(llama.cpp a0e6dc7)`, because the script reads the commit from the binary's own `--version` and
stops when it cannot (both builds print `version: 0.x.0-dev (build 1, commit …)`). It is committed
as `FRUSExplorerTests/Fixtures/query-parity-fixture-embeddinggemma-2.json`, because a device reads
the fixture from the test bundle (§5), and the suite picks the fixture whose GGUF hash is the model's.

| check | min cosine | worst query |
|---|---|---|
| `parityAgainstFixture()`, iPhone 17 simulator, iOS 27.0, CPU | 0.999714 | "Diego Garcia base" |
| the command line against itself, `-ngl 0` against Metal, `a0e6dc7` | 0.999817 | "Deposing shah" |
| the Mac harness, macOS slice, Metal, three runs | 0.9999997 | "Diego Garcia base" |

Both pass the suite's 0.999 bar, and the Mac's Metal path agrees to the sixth decimal. The
simulator's margin is narrower than the 300m's (0.000714 above the bar against 0.000862), and it is
0.0001 below the command line's own CPU-against-Metal figure. Read, not measured: the xcframework's
CPU code is built with `GGML_NATIVE=OFF` and the command line natively, so the two CPU paths need
not agree. A wrapper bug lands orders of magnitude lower (the simulator's Metal fault read −0.12).

**The trained context.** The encoder passes `n_ctx = 0`, the model's own trained context: 2,048 for
the 300m, and 262,144 for EmbeddingGemma 2 (the GGUF's `n_ctx_train`; the card says 8,192). The
simulator's load logged `n_ctx = 262144` with a 228 MiB compute buffer, sized by the 2,048-token
batch, and the footprint (§4) shows no cost from it. `SemanticQueryEncoder.maxTokens`' comment
calls 2,048 "the trained context length of the pinned model": the second pull request owns that
sentence.

## 4. Latency and memory

**The command line, the step-4 spike's method** (stage 1's `latency.py`, unchanged, and
`latency_ab.py`, its copy with the batch as an argument): the 25 owner queries under the query
prompt, per-query cost from the slope between one query and a hundred, best of three, peak memory
from `/usr/bin/time -l`, Metal, the two runtimes interleaved over two rounds:

| | batch | cold ms | per query ms | peak RSS MB | peak footprint MB |
|---|---|---|---|---|---|
| 300m, `8663224` | 4096 | 378 / 372 | 2.72 / 2.83 | 2,398 | 2,187 / 2,188 |
| 300m, `a0e6dc7` | 4096 | 391 / 385 | 1.71 / 1.70 | 729 / 728 | 507 / 506 |
| EmbeddingGemma 2, `a0e6dc7` | 4096 | 693 / 772 | 2.34 / 1.81 | 859 | 499 / 500 |
| 300m, `8663224` | 2048 | 370 / 380 | 2.77 / 2.88 | 2,398 | 2,188 / 2,187 |
| 300m, `a0e6dc7` | 2048 | 387 / 393 | 1.61 / 1.75 | 729 / 727 | 506 / 505 |
| EmbeddingGemma 2, `a0e6dc7` | 2048 | 695 / 710 | 2.41 / 2.65 | 859 | 499 |

The peak is the largest over the one-prompt and hundred-prompt invocations, and at `8663224` the
hundred-prompt invocation must set it, since one invocation of 25 prompts peaks at 639 MB. In August's shape, the 25 prompts in one invocation, the old
runtime reads 859 MB resident and 639 MB footprint (the record: 861 and 639) and the new one 661 and
430, with `--no-warmup`, `-c 2048` or the 2,048 batch alike. Stage 1's table set its 729 / 507 MB
beside the record's 861 / 639 MB, two shapes; like for like, the new runtime is lower in both.

**In-app shape on the Mac** (`mac_parity_harness.swift`, compiled by `run_mac_harness.sh` from the
app's own `SemanticQueryEncoder.swift` and `SemanticQueryPrompt.swift` against a macOS slice; one
warm-up a configuration, then three interleaved rounds; footprint is `phys_footprint` at the four
points `memoryShape()` samples):

| | load ms | first encode ms | warm encode, median ms | footprint MB: before → load → first → 25 → unload |
|---|---|---|---|---|
| 300m, `8663224` slice | 180–185 | 17.9–18.4 | 6.16–6.50 | 8 → 114–116 → 147–149 → 160–162 → 86–88 |
| 300m, `a0e6dc7` slice | 188–195 | 18.1–18.4 | 4.74–5.33 | 8 → 122–124 → 130–131 → 132–134 → 95–96 |
| EmbeddingGemma 2, `a0e6dc7` slice | 318–332 | 21.9–22.5 | 7.17–8.13 | 8 → 191–193 → 200–202 → 203–205 → 49 |

The harness starts before any Metal device exists and ggml keeps its device until the process
ends, so its fifth point stays above its first; the differences between rows are the reading.
Why not the unit target on the Mac: the only way to run it there, "My Mac (Designed for iPad)",
starts the iOS app under the Mac app's bundle id, inside the owner's real Mac container.

**In-app shape on the simulator** (`memoryShape()` alone, twice a model; CPU, iPhone 17, iOS 27.0):

| | footprint MB: before → load → first → 25 → unload |
|---|---|
| 300m, `a0e6dc7` | 121–123 → 348–349 → 349–350 → 348–350 → 104–105 |
| EmbeddingGemma 2, `a0e6dc7` | 116–117 → 312–315 → 319–323 → 347 → 106 |
| *300m, `8663224`, August (V-5 s2, iPhone 16e simulator)* | *141 → 349 → — → 393 → 140* |

Both models release completely. The simulator's times are not quoted: the test host app launches
around the test, and the first encode alone ranged from 0.7 to 2.1 seconds. Run with the parity
test beside it, `memoryShape()` read 352 MB before its own load (Swift Testing runs a suite's tests
in parallel), so the suite's doc comment now says to run it alone.

**Read together.** The rebuild leaves the 300m's vectors where they were and makes it a little faster
and a little smaller on Metal, at a few milliseconds more load. EmbeddingGemma 2 under the same
runtime costs 130–140 ms more load in the app's shape (about 300 ms more cold on the command line)
and 2–3 ms more a warm query on the Mac, with about 70 MB more footprint on Metal and none more on
the CPU path; none of it reaches a typed search. A device's figures are §5's.

## 5. The iPhone run, for the owner

Design step 7 asks for the iPhone. These steps run the parity suite on "Josh" (the iPhone 17 Pro,
listed today as an `xcodebuild` destination on the Air). **What it does to the phone:** Xcode
installs a Debug build of FRUS Explorer from this branch over the TestFlight build; the app's data
stays, since the bundle id is the same. Hosting tests, the app opens an in-memory store with no
iCloud (`makeFRUSContainer`'s test-host rule), so the run touches neither your notes nor the sync.
Do not open the Debug build by hand: a Debug build syncs with CloudKit's Development environment.
Reinstall build 50 from TestFlight when done.

From a checkout of this branch on the Air, with the phone unlocked and connected:

```bash
xcodebuild build-for-testing -project FRUSExplorer.xcodeproj -scheme FRUSExplorer -destination "platform=iOS,name=Josh" -derivedDataPath ~/Library/Developer/Xcode/DerivedData/FRUS-B4-iPhone -allowProvisioningUpdates
```

```bash
xcrun devicectl device install app --device Josh ~/Library/Developer/Xcode/DerivedData/FRUS-B4-iPhone/Build/Products/Debug-iphoneos/"FRUS Explorer.app"
```

Copy EmbeddingGemma 2 into the app's `tmp` folder (310 MB), and confirm it landed:

```bash
xcrun devicectl device copy to --device Josh --domain-type appDataContainer --domain-identifier bottsywattsy.FRUS-Explorer --source ~/Development/models/embeddinggemma-2/embeddinggemma-2-Q8_0.gguf --destination tmp/embeddinggemma-2-Q8_0.gguf
```

```bash
xcrun devicectl device info files --device Josh --domain-type appDataContainer --domain-identifier bottsywattsy.FRUS-Explorer --subdirectory tmp
```

The 300m's whole suite, with the copy the app downloaded (the single quotes keep `~` for the phone,
where the suite reads it as the app's container):

```bash
TEST_RUNNER_FRUS_SEMANTIC_MODEL='~/Library/Application Support/FRUSExplorer/SemanticModel/embeddinggemma-300m-qat-Q4_0.gguf' xcodebuild test-without-building -project FRUSExplorer.xcodeproj -scheme FRUSExplorer -destination "platform=iOS,name=Josh" -derivedDataPath ~/Library/Developer/Xcode/DerivedData/FRUS-B4-iPhone -only-testing FRUSExplorerTests/QueryEncoderParityTests -collect-test-diagnostics never 2>&1 | tee ~/Desktop/b4-iphone-300m.log | grep -E "\[QueryEncoder|Test run with|✘"
```

EmbeddingGemma 2's parity, then each model's memory test alone:

```bash
TEST_RUNNER_FRUS_SEMANTIC_MODEL='~/tmp/embeddinggemma-2-Q8_0.gguf' xcodebuild test-without-building -project FRUSExplorer.xcodeproj -scheme FRUSExplorer -destination "platform=iOS,name=Josh" -derivedDataPath ~/Library/Developer/Xcode/DerivedData/FRUS-B4-iPhone -only-testing "FRUSExplorerTests/QueryEncoderParityTests/parityAgainstFixture()" -collect-test-diagnostics never 2>&1 | tee ~/Desktop/b4-iphone-eg2.log | grep -E "\[QueryEncoder|Test run with|✘"
```

```bash
TEST_RUNNER_FRUS_SEMANTIC_MODEL='~/Library/Application Support/FRUSExplorer/SemanticModel/embeddinggemma-300m-qat-Q4_0.gguf' xcodebuild test-without-building -project FRUSExplorer.xcodeproj -scheme FRUSExplorer -destination "platform=iOS,name=Josh" -derivedDataPath ~/Library/Developer/Xcode/DerivedData/FRUS-B4-iPhone -only-testing "FRUSExplorerTests/QueryEncoderParityTests/memoryShape()" -collect-test-diagnostics never 2>&1 | tee ~/Desktop/b4-iphone-300m-memory.log | grep -E "\[QueryEncoder|Test run with|✘"
```

```bash
TEST_RUNNER_FRUS_SEMANTIC_MODEL='~/tmp/embeddinggemma-2-Q8_0.gguf' xcodebuild test-without-building -project FRUSExplorer.xcodeproj -scheme FRUSExplorer -destination "platform=iOS,name=Josh" -derivedDataPath ~/Library/Developer/Xcode/DerivedData/FRUS-B4-iPhone -only-testing "FRUSExplorerTests/QueryEncoderParityTests/memoryShape()" -collect-test-diagnostics never 2>&1 | tee ~/Desktop/b4-iphone-eg2-memory.log | grep -E "\[QueryEncoder|Test run with|✘"
```

**What it measured, 2026-10-15, 12:27 to 12:34**, on "Josh" (iPhone 17 Pro, iOS 27.0.1, Metal), the
Debug build of `v2` at `28dd78a0` (device slice UUID `4D3C4A5A…`): the 300m's four tests passed,
min cosine **0.9999996142** ("Deposing shah"), the Mac harness's figure; EmbeddingGemma 2's parity
passed, min cosine **0.9999997158** ("Diego Garcia base"), the Mac's too. `memoryShape()` alone,
twice each, footprint MB before → load → 25 encodes → unload, sampled at once with no wait:
the 300m 95/90 → 185/184 → 194/192 → 138/192, load 450/465 ms, first encode 21 ms, warm median
6.4–6.5 ms; EmbeddingGemma 2 97/94 → 262/259 → 272/269 → 206/202, load 630/637 ms, first encode
28–30 ms, warm median 10.4–10.6 ms. So on the phone EmbeddingGemma 2 costs about 77 MB more while
loaded (its weights are 81 MB larger), 170 ms more load and 4 ms more a warm query.

**What to send back:** the `[QueryEncoder…]` lines of the four logs. **What passing looks like:** each
run ends `Test run with N tests … passed` (4, then 1, 1 and 1), and both parity lines read 0.999 or
more; on the phone's Metal they should read near the Mac's 0.9999996 and 0.9999997. If the 300m was
never downloaded in the app on this phone, copy it in the same way as EmbeddingGemma 2 (it is on the
Air at `~/.lmstudio/models/frus-eval/embeddinggemma-300m-qat/`) and point the 300m runs at
`'~/tmp/embeddinggemma-300m-qat-Q4_0.gguf'`.

**Afterwards:** reinstall build 50 from TestFlight. iOS clears an app's `tmp` folder on its own; leave
it to do so. **Never run `devicectl device copy to … --remove-existing-content true` against the
app's container**, which this paragraph suggested until 2026-10-15: run that day to clear `tmp`, it
errored ("Failed to retrieve the file node") and the app's whole data container on the phone was
then empty (the SwiftData store, the 3.33 GB index, the volumes, the vectors, the model and the
preferences). Recovery is a reinstall from TestFlight, iCloud's sync of the research data, and
downloading the volumes again.

## 6. The dSYM release

The fetch script names its asset by the pinned commit, so `llama-xcframework-dSYMs-a0e6dc7.zip` sits
beside `-8663224.zip` on the same release without a clash, and older checkouts keep fetching theirs.
It went on `encoder-1`, which leaves `DSYM_RELEASE` as it is, with one bullet in the release notes
worded as the `8663224` one is (that one now reads "embedded through build 50"). **Uploaded on the
owner's word, 2026-10-15 at 15:58Z, after this pull request merged**: 91,570,299 bytes, SHA-256
`35d6e829…`, downloaded back byte-identical, and `fetch-llama-dsyms.sh` with an empty cache fetched
it from the release and verified all six UUIDs. Until then an archive failed at "Embed llama dSYM"
on any Mac without the local zip, as the phase intends.

## 7. Not verified

- ~~The iPhone (§5)~~: run on 2026-10-15 after the merge, and §5 records it.
- An archive. The phase's script was run by hand outside the sandbox (§1).
- The Mac app's encoder memory and times in the app itself; the harness gives them for the app's
  encoder source outside it (§4).
- Why the simulator's EmbeddingGemma 2 margin sits 0.0001 below the command line's own CPU figure
  (§3 gives the likely reason, read rather than measured).

## 8. Files

`eg2-b4-runtime-2026-10-15/`:
- `parity-and-memory-runs.txt`: the suite's printed lines from every simulator run, the command line's
  cross-commit and CPU-against-Metal checks, and the 25-prompt peaks (§2 to §4).
- `latency-stage1-flags.jsonl`, `latency-batch-2048.jsonl`: §4's command-line table, from
  `eg2-stage1-2026-10-14/latency.py` and `latency_ab.py`.
- `mac-harness-ab.jsonl`: §4's Mac table and §2's and §3's Mac rows, one JSON object a run.
- `mac_parity_harness.swift`, `run_mac_harness.sh`, `latency_ab.py`: the scripts that took them.

Outside the repository, on the Air: the two GGUFs and both `llama-embedding` builds. The dSYM zip is
on `encoder-1` (§6).

---

Version history:
  1.0 — 2026-10-15: B4's first pull request: the runtime rebuilt at a0e6dc73 and the zip layout
  fixed, the 300m's parity under it on the simulator, the Mac and the command line, EmbeddingGemma
  2's step-7 parity on the simulator and the Mac, latency and memory for both models against the
  old runtime, and the owner's iPhone steps.
  1.1 — 2026-10-15 (B4's second pull request): the iPhone run's figures in §5 and the warning on
  `--remove-existing-content` that its cleanup earned; the dSYM upload recorded in §0 and §6; §7's
  iPhone line struck.
