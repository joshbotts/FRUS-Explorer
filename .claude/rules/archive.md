---
paths:
  - "Scripts/**"
  - "Vendor/**"
---

# Before any archive: the query encoder's debug symbols

Claude Code loads this file when a session reads or edits a file its `paths` name. A session that
archives without opening one reads it first (`CLAUDE.md`, *Before ANY archive*). Everything below
this paragraph was moved here from `CLAUDE.md`'s *Build & Test Commands* word for word on 2026-11-26.
The rest of a build bump's list is in `CLAUDE.md`'s *Project Overview*.

**Before ANY archive — TestFlight, App Store, or the notarized DMG — cache the query encoder's
debug symbols once:**
```bash
./Scripts/fetch-llama-dsyms.sh
```
`Vendor/llama.xcframework` (the on-device query encoder's llama.cpp runtime) is committed WITHOUT
its dSYMs — 63–126 MB per slice since the B4 rebuild, two of the three past GitHub's 100 MB
limit — so every TestFlight upload used to warn that the archive "did not include a dSYM for
llama.framework", and a crash inside the encoder could not be symbolicated. The dSYMs live as a release asset on `frus-semantic-vectors`
(`llama-xcframework-dSYMs-<commit7>.zip`, on `encoder-1`); the fetch script downloads them into
the gitignored `.cache/llama-dSYMs/`, verifies every slice's UUIDs against the committed
binary, and is a no-op once the cache verifies. An archive-only build phase on both app targets
("Embed llama dSYM", `Scripts/embed-llama-dsyms.sh`) then copies the embedded slice's dSYM into
the archive after re-checking the UUIDs — and **FAILS the archive** when the cache is missing or
stale, because shipping unsymbolicated is the state it exists to end. It never runs on a plain
build or test. **Test a change to that phase with `-derivedDataPath` on a real path, never under
`/tmp`**: xcodebuild spells a `/tmp` build directory as `/tmp/…` in the script sandbox's rules while
the kernel checks the resolved `/private/tmp/…`, so no deny rule matches and the phase runs
unsandboxed — measured, the `rm -rf` that failed the build-48 archive passes a `/tmp` archive and
fails one under `~/Library`. After `Scripts/build-llama-xcframework.sh` rebuilds the framework, upload the zip
it writes to that release AND commit the new xcframework together, then re-run the fetch;
`notarize.sh` runs the fetch itself before archiving.
