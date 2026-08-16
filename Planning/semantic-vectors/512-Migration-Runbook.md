# Moving the corpus to 512 dimensions — runbook

**Status:** COMPLETE. Shards published and bundle swapped 2026-08-16.

Owner decision (2026-08-16): ship 512 for everyone rather than as a user option, and clear the old
shards automatically. The cost was measured in `Dimension-Ladder-Spike.md`: **+86.5 MB on device,
+9.76 MB in the app bundle, ~+0.6 ms a query, for +0.115 recall@10.**

---

## The ordering constraint, which is the whole risk

**Publish the shards BEFORE swapping the bundle.** The bundled manifest records each shard's exact
byte length and SHA-256, so a 512 bundle against a host still serving 256 files fails every fetch:

```
integrityMismatch(volumeID: "frus1861", expected: "161056 bytes", found: "81184 bytes")
```

That is not a guess — `VectorGenerationMigrationTests.prematureSwapIsRefused` produces it on demand,
so the symptom is recognisable if it ever appears. Nothing is corrupted by getting the order wrong;
Tier 2 simply stops working until the shards catch up, and every failure is reported on the storage
screen rather than being silent.

---

## Step 1 — regenerate (anyone, ~2 minutes)

```bash
STORE=~/frus-semantic-raw \
OUTPUT_DIR=/tmp/vectors512 SHARDS_DIR=/tmp/vectors512-shards \
DIMS=512 GENERATED_DATE=$(date +%F) \
swift run -c release SemanticVectorsGenerator
```

**The output is byte-reproducible.** Two independent runs produced identical SHA-256 for all three
bundled artifacts and all 552 shards, so this can be re-run at any time and the result will match
whatever was published. That is what makes the 175 MB safe to keep out of the repo.

Expect: `semantic-vectors-binary.bin` 19.52 MB, `semantic-vectors-index.json` ~73 KB,
`semantic-shards-manifest.json` ~66 KB, and 552 `.vec` files totalling 154.79 MB.

## Step 2 — publish (OWNER ONLY)

Push the 552 `.vec` files to `joshbotts/frus-semantic-vectors` under `shards/`, replacing the 256
set. The fetcher reads `https://raw.githubusercontent.com/joshbotts/frus-semantic-vectors/main/shards/<volumeId>.vec`
— no API, no credentials, no directory listing; the bundled manifest is what says which shards exist.

Verify one before continuing:

```bash
curl -sI https://raw.githubusercontent.com/joshbotts/frus-semantic-vectors/main/shards/frus1861.vec \
  | grep -i content-length      # expect 161056, not 81184
```

## Step 3 — swap the bundle

Copy **all five** regenerated files over `FRUSExplorer/Resources/`. A same-name refresh needs **no**
`xcodegen`.

> **Correction, made while executing this step.** An earlier draft said the map artifacts
> (`semantic-map.bin`, `semantic-map-index.json`) were "Tier 0 and unaffected by width — do not swap
> them". That is true of their *placements* and false of their *header*: `BundledSemanticMap`
> validates the map's provenance digest against the loaded vectors and returns
> `.provenanceMismatch` when they disagree, so leaving the old map behind takes the entire map
> surface dark — silently, with nothing in the diff to show for it. Measured after the swap: the
> repacked 512 map is byte-identical from offset 64 onward (same 179 clusters, same 314,483
> placements) and differs **only** in the 32-byte digest at offset 20. Swap it.
>
> `VectorGenerationMigrationTests.bundledArtifactsAgree` now pins all five against one digest, so
> this cannot recur quietly.

Then bump the build number (see CLAUDE.md — never `xcodegen` for that).

## Step 4 — what happens on every existing device, automatically

1. `BundledSemanticVectors.prepare()` loads the new index, whose provenance digest has changed
   because `shippingDims` is part of it.
2. `SemanticShardStore.purgeIfGenerationChanged()` sees a `.generation` marker that no longer
   matches and **discards every old shard** before any surface can read one. Rehearsed:
   `upgradeFrom256To512` discards the 256 file and adopts the 512 one, which then maps at 512 dims
   and scores 1.0 against itself.
3. Shards re-download under the rules #926 established — with the volume if "Download With Volumes"
   is on, on demand when a semantic surface asks, or in bulk from **Download Missing Vectors**.

**No user action is required, and no user data is at risk**: shards are a derived cache, and the
storage screen reports what is missing while it refills.

## Step 5 — verify

```bash
xcodebuild test -project FRUSExplorer.xcodeproj -scheme FRUSExplorer \
  -destination "id=<simulator udid>" \
  -only-testing FRUSExplorerTests/VectorGenerationMigrationTests
```

**No environment is needed any more.** The suite used to point at an out-of-repo 512 build through
`TEST_RUNNER_`-prefixed variables and skip itself without them — which, once 512 shipped, would have
left it passing while testing nothing. It now derives the "previous" generation from whatever is
bundled, so it runs in every ordinary pass and survives the next width change unedited.

Also verify the published host, which is what a device actually reads:

```bash
curl -s -o /dev/null -w '%{http_code} %{size_download}\n' -L \
  https://raw.githubusercontent.com/joshbotts/frus-semantic-vectors/main/shards/frus1861.vec
```

(`curl -sI … | grep content-length` also works, but the header is last in a long HTTP/2 response and
is easy to lose; the write-out form prints only the two numbers that matter.)

---

## What does NOT change

- **Tier 0, the map.** It reads the bundled corpus block, not shards, and its layout is independent
  of width.
- **Recall figures on screen.** Nothing in the app quotes them; they live in the design and the
  spike.
- **CloudKit.** No `@Model` changes, so no schema deploy.
