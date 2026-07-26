# #488 — capturing the CloudKit failure, step by step

**Why this runbook exists.** The app's own sync log printed `CKErrorDomain partialFailure (2)` and
nothing else. That is not laziness on the owner's part — `cloudKitDiagnostic`
(`FRUSExplorer/App/FRUSExplorerApp.swift:2006`) looks for the per-item error dictionary at exactly
one level (`error.userInfo[CKPartialErrorsByItemIDKey]`) and, when it isn't there, falls through at
:2029-2033 to domain + code only. It discards `NSUnderlyingErrorKey`, CloudKit's server error text,
and the retry hint. Nothing else in the codebase reads those keys. So the single most useful fact —
*which record or field the server rejected* — was thrown away before it reached the log.

Until that is fixed, the detail has to come from outside the app. There are three routes below.
**Route C is the decisive one**; A and B are how you get the error text.

---

## The two hypotheses this is trying to separate

| | H1 — stale Production schema | H2 — PCS / key-hierarchy |
|---|---|---|
| What happened | Build 35 added CloudKit schema that was never deployed to Production, so the server rejects the save | The server refused the encryption key blob the client presented (iCloud Keychain state, or an Advanced Data Protection change) |
| Fits `USER_ERROR` / `BAD_REQUEST` | yes | yes |
| Fits `returnedRecordTypes: _pcs_data` | weakly — only if the request was rejected before any `CD_` record was processed | strongly — `_pcs_data` *is* the Protected Cloud Storage record |
| Fits the ABSENT per-item error dictionary | weakly — a missing field normally yields a *populated* dictionary with per-item code 12 | yes |
| Self-heals | never | usually |
| Fix | deploy schema | account-side, usually nothing to do |

Note the honest reading: the evidence currently leans **against** the simple schema story, because a
missing field normally comes back with per-item errors and code 12/15, not a bare code 2. That is
why the schema comparison (Route C) matters more than the log hunt.

---

## Route A — the client-side error, from the device (best error text)

This is the one you asked for, and it gets what the app dropped.

1. Connect the iPhone to the Mac by cable and unlock it.
2. Open **Console.app** → in the left sidebar, select the **iPhone** (under Devices), then click
   **Start** in the toolbar. (If the phone isn't listed: Console ▸ Action ▸ Include Info Messages
   and Include Debug Messages, and make sure the phone trusts this Mac.)
3. Put this in the search field and press Return:

   ```
   subsystem:com.apple.coredata
   ```

   Then add, as a second filter chip, `category:NSCloudKitMirroringDelegate`. Apple's mirroring
   delegate logs the *full* `CKError` including per-record failures — it does not go through the
   app's lossy diagnostic.
4. **Force an export** so the failure recurs: in the app, add or edit a research note, a tag, or a
   collection. Any write to a synced model dirties the store and schedules an export.
5. Watch for lines containing `Failed to` or `partialFailure`. The useful line looks roughly like:

   ```
   NSCloudKitMirroringDelegate ... Failed to modify some records: <CKError ... partialFailure ...
       "<CKRecordID: ...>" = "<CKError 0x...: \"Invalid Arguments\" (12/2006);
       server message = \"...\"; ...">
   ```

   **The part that matters is whatever follows `server message =`.** Copy that whole line.

If it names a `CD_` identifier (e.g. `CD_ProjectLeadEntry`, `CD_leadAxisWeights`,
`CD_defaultUserTagIds`, `CD_includeProjectProvenance`) → **H1**, go do Route C and deploy.
If it talks about PCS, protection, or key hierarchy → **H2**, and Route C will come back clean.

**Terminal alternative** if you'd rather not use Console.app (run while reproducing):

```bash
xcrun devicectl device info details --device <UDID>
```

…to confirm the device is visible, then capture with Console.app anyway — `log stream` against a
physical iPhone requires the device to be selected in Console, so Console is genuinely the easier
path here.

---

## Route B — the server-side entry, in CloudKit Console

This is the row you found once before (`RecordSave` / `USER_ERROR` / `BAD_REQUEST` /
`returnedRecordTypes: _pcs_data`). To find it again and open its detail:

1. Go to **https://icloud.developer.apple.com/dashboard/** and sign in.
2. Choose the container **`iCloud.bottsywattsy.FRUS-Explorer`**.
3. Open **Logs** (it sits alongside Telemetry and Schema in the container's sidebar).
4. Set, explicitly — the defaults are usually wrong for this:
   - **Environment:** `Production`
   - **Database:** `Private Database`
   - **Date range:** a window that actually contains the failure. The original was
     `2026-07-25T20:05:12Z` — that is **16:05 Eastern**, so if the picker is in local time, do not
     search 20:05 local.
5. Narrow with a filter on **Operation Type = `RecordSave`**, or on **Error = `BAD_REQUEST`**.
6. **Click the row.** The list view only shows `BAD_REQUEST`; the expanded detail carries the actual
   reason string. That detail is the thing worth pasting into the issue.

**Two caveats that probably explain why you couldn't find it:**
- **Log retention is short** (days, not weeks). A 2026-07-25 entry may simply have aged out by now.
  If so, reproduce first (Route A step 4), then look for a *fresh* row.
- Private-database logs only ever show **your own** account's activity. That's fine here — you are
  the account — but it means nothing appears unless *this* Apple ID generated the traffic.

---

## Route C — the decisive check: Production vs Development schema

This is what actually settles H1, and it needs no logs at all.

1. CloudKit Console → container `iCloud.bottsywattsy.FRUS-Explorer` → **Schema** → **Record Types**.
2. Look at **Development**, then switch to **Production**, and compare these four additions that
   landed between build 34 (`ac7abe6`) and build 35 (`377fa78`):

   | | Where |
   |---|---|
   | record type `CD_ProjectLeadEntry` | new `@Model`, added to `frusModelTypes` |
   | field `CD_Project.CD_leadAxisWeights` | new property on a shipped model |
   | field `CD_Project.CD_defaultUserTagIds` | new property on a shipped model |
   | field `CD_Collection.CD_includeProjectProvenance` | new property on a shipped model |

3. **If any is missing from Production → H1 is confirmed.**

### The trap that makes "I already deployed" and "it still fails" both true

CloudKit creates a record type in **Development** only when a record of that type is **actually
pushed**. Deploying before that has happened is a no-op for it — the deploy promotes what exists,
and a type nobody ever saved does not exist. This is documented in the repo at
`FRUSExplorer/Models/ModelContainer+FRUS.swift:100-118`.

So if `CD_ProjectLeadEntry` is missing from **Development** too, the sequence is:

1. Run a **Development-signed** build (Xcode to the device, not TestFlight).
2. Mint one record of each new shape:
   - **`CD_ProjectLeadEntry`** — open **Project Home** on a project that has leads to compute.
   - **`CD_Project.CD_leadAxisWeights`** — change the lead axis weights on a project.
   - **`CD_Project.CD_defaultUserTagIds`** — set a project's tag focus.
   - **`CD_Collection.CD_includeProjectProvenance`** — toggle "include project provenance" on a
     collection.
3. Confirm each now appears in the **Development** schema.
4. **Then** Deploy Schema Changes to Production.

> Deploying to Production is **irreversible** — CloudKit will not let you remove a field or record
> type afterwards. Check the Development schema for junk from experimentation before you deploy.

---

## What to send back

Whichever route produces something, the useful artifacts are:

1. The `server message = …` string from Route A (redact nothing; it names schema, not content).
2. Whether the four identifiers are present in Production (Route C).
3. Whether the export failure **repeats on every launch** (→ H1) or happened once and cleared (→ H2).
4. The full **Settings ▸ Sync Diagnostics** export, not just the two lines — it shows whether any
   `import` rows succeeded and whether build 34 was clean.

## The code change this justifies regardless

Even once #488 is resolved, the app should not have been this hard to diagnose. The fix is to walk
`NSUnderlyingErrorKey` / `NSMultipleUnderlyingErrorsKey` for the per-item dictionary instead of the
single-level lookup, record `hadPartialDictionary` so "we looked and found none" is distinguishable
from "we never looked", and extract **schema identifiers only** from the server text via a strict
allow-list regex (`CD_[A-Za-z0-9_]+`, `_pcs_data`) — never the raw string, which can carry record
names and field values and would break the #188-C.1 redaction contract.
