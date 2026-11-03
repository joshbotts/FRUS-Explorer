# A6's spike: Spike Reader

The code behind A6's memo, `Planning/App-Intents-Siri-Assessment-2026-10-18.md`, kept for #1723 (A7, App Intents and Siri). It was untracked in the A6 session's worktree until 2026-11-03. The copy the memo's §9 names, in that session group's notes folder, could not be found then, so this is the only one.

Nothing here is built by the app, the package or any test. `project.yml` makes a project of its own.

## What is here

- **`project.yml`**, **`Sources/`** and **`UITests/`**: Spike Reader (`bottsywattsy.A6Spike`, display name "Spike Reader"), an app of its own. It donates ten fictional FRUS-shaped documents to Spotlight five ways and offers four intents: Open, Search, Summarize and a background write standing in for Add to Collection. `SpikeEntity.swift` is the entity and query A7's `FRUSDocumentEntity` is sketched from.
- **`redonation-timing.sh`**: times FRUS Explorer's own full Spotlight re-donation on a clone of a full-library simulator. It measured 318,104 items resubmitted 1 minute 54 seconds after the pipeline started (memo §2.7). Its simulators are gone; its header says what to change.
- **`results/`**: the UI runs' step logs (`outN-notes.txt`, what each Spotlight search listed and what the tap landed on), the re-donation's `searchd` and app CPU samples, and the log line that ended the timing. The screenshots and element trees were not kept.

## Running it

```bash
cd Planning/app-intents-spike
xcodegen generate --spec project.yml
```

Then open `A6Spike.xcodeproj`. Its generated project, `Generated/` and any `DerivedData/` are not to be committed.

- **On the simulator.** Launch with `--spike=inspect,donate,query`, then the other steps the memo's §9 lists; `q:<query string>` runs any query. The UI tests write a screenshot and element tree per step to `SPIKE_OUT`. A second build with `SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG SPIKE_NO_PARAM_SHORTCUTS'` drops the parameterised phrases (§2.5). Run builds and tests through `Scripts/heavy.sh`.
- **On the owner's iPhone** (the device check, memo §4). Its own bundle identifier keeps it out of FRUS Explorer's container. Signing registers the App ID `bottsywattsy.A6Spike` on team 828S8SXVLC. Never install with `devicectl … --remove-existing-content`.
