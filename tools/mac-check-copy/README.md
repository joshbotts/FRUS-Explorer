# The isolated Mac check copy

A separate macOS copy of FRUS Explorer for by-eye checks and screenshots. It never touches the
installed app's library, index, SwiftData store or iCloud. It was first used for build 48's Mac
checks (2026-09-25), when 12 merged PRs' Mac lists were walked in one sitting on a 32-volume
library.

```bash
tools/mac-check-copy/setup.sh                    # extract origin/v2, seed the frus1961-63 volumes
tools/mac-check-copy/build.sh                    # build, then launch against the fake home
```

`setup.sh --ref HEAD` extracts this checkout's last commit instead. Uncommitted edits are never
extracted. `--prefix frus1961-63,frus1913` seeds more than one run of volumes. The corpus comes
from `FRUS_VOLUMES_DIR` (default `~/Development/frus/volumes`). `build.sh --wait-for-lanes 3`
waits until fewer than three `xcodebuild` processes are running before it starts, so its own build
is at most the third: pass the machine's cap, counting this build. `--no-launch` builds without
launching.

## What makes it separate

| | the installed app | the check copy |
|---|---|---|
| bundle id | `bottsywattsy.FRUS-Explorer` | `bottsywattsy.FRUS-Explorer.maccheck` |
| signing | team, sandboxed, iCloud entitlement | ad hoc (`CODE_SIGN_IDENTITY=-`), `ENABLE_APP_SANDBOX=NO`, no entitlements file |
| Application Support | its sandbox container, `~/Library/Containers/bottsywattsy.FRUS-Explorer/` | `$MAC_CHECK_SCRATCH/home/Library/Application Support/FRUSExplorer/` (`CFFIXED_USER_HOME`) |
| SwiftData store | CloudKit-mirrored | the local-only store, compiled in by `FRUS_MAC_CHECK` |
| source | the build you installed | a `git archive` of one ref in `$MAC_CHECK_SCRATCH/src` |

The scratch directory defaults to `~/Library/Caches/frus-mac-check`. Set `MAC_CHECK_SCRATCH` or
pass `--scratch DIR` to both scripts to use another one. It holds `src/` (replaced on every
setup), `dd/` (derived data, kept so a rebuild is incremental), `home/` (the fake home, kept so
its index survives a rebuild), `build.log`, `ref.txt` and `app-path.txt`. The commands below find
it the way the scripts do, through `MAC_CHECK_SCRATCH`; if you passed `--scratch`, set
`MAC_CHECK_SCRATCH` to the same directory before running them.

**The local store is a compile-time switch, not a patch.** Without the iCloud entitlement,
CloudKit's setup traps at launch. So `ModelContainer.makeFRUSContainer()` returns the local-only
store under `#if FRUS_MAC_CHECK`. Only `build.sh` defines that condition, passing
`SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) FRUS_MAC_CHECK'` on its xcodebuild command
line. `CodingStandardsAuditTests.macCheckStoreSwitchNeverShips` fails if the branch leaves its
`#if`, if `project.yml`, the Xcode project or a script in `Scripts/` names the condition
(`notarize.sh` passes its archive's settings on xcodebuild's command line, as `build.sh` does), or
if `build.sh` stops passing it. So no shipped configuration or release script can compile the
branch. The build log reports one expected
warning site, in `ModelContainer+FRUS.swift`: the CloudKit attempt after that `return` "will
never be executed". In this build, it never is. Until #1512 the session scripts patched the
extracted source instead. `setup.sh` refuses a ref that predates the switch.

Measured on 2026-09-27 with the app sources that added the switch: `** BUILD SUCCEEDED **`, bundle
id `bottsywattsy.FRUS-Explorer.maccheck`, and `com.apple.security.get-task-allow` as the only
entitlement. The copy's binary holds the branch's log line, "Mac check copy (FRUS_MAC_CHECK)". A
plain Debug build of `FRUSExplorerMac` from the same commit does not.

## After launch

The copy indexes its seeded volumes on first launch. On 2026-09-25 the session's copy took 27
volumes to 10,543 documents, 3,948 persons and 7,778 cross-references. Wait for the index to
settle before you check anything that reads it:

```bash
MCS=${MAC_CHECK_SCRATCH:-$HOME/Library/Caches/frus-mac-check}
sqlite3 "$MCS/home/Library/Application Support/FRUSExplorer/frus.db" 'SELECT COUNT(*) FROM document_cache'
```

To relaunch without rebuilding:

```bash
MCS=${MAC_CHECK_SCRATCH:-$HOME/Library/Caches/frus-mac-check}
open -n -a "$(cat "$MCS/app-path.txt")" --env CFFIXED_USER_HOME="$MCS/home" --args -hasCompletedOnboarding 1
```

Launch it with `open -n --env`. Do not exec the binary directly: macOS App Nap throttles an app
launched from a shell. To drive the copy with computer use, grant access to its bundle id,
`bottsywattsy.FRUS-Explorer.maccheck`, and never to the installed app.

## Limits, measured on 2026-09-25

- **Preferences escape the fake home.** `CFFIXED_USER_HOME` moves Application Support. It does
  not move preferences: `cfprefsd` ignores the variable. The copy's defaults land in the REAL
  `~/Library/Preferences/bottsywattsy.FRUS-Explorer.maccheck.plist`, under the copy's own bundle
  id, so they never mix with the installed app's. They do outlive the scratch directory, though,
  and a later copy reads them back, including saved window frames.
- **Synthetic hover misses most hover effects.** A pointer moved by computer use does not
  trigger SwiftUI `.onHover`: a hovered disc does not grow and a dock does not preview. It does
  not show a toolbar button's `.help` tooltip either; the Collections toolbar was the control. AppKit
  tooltips over content do fire, such as a heat-matrix cell's. So did one toolbar *menu*'s
  tooltip. Leave every hover step to a person.
- **Dark mode must be checked by hand.** `-AppleInterfaceStyle Dark` as a launch argument does not
  take. Switch the system appearance instead.
- **No iCloud, by construction.** Nothing a check does in the copy syncs. Check sync on a signed,
  entitled build.

## Cleanup

Once the checks are done:

```bash
MCS=${MAC_CHECK_SCRATCH:-$HOME/Library/Caches/frus-mac-check}
osascript -e 'quit app id "bottsywattsy.FRUS-Explorer.maccheck"'
defaults delete bottsywattsy.FRUS-Explorer.maccheck          # the plist that escaped the fake home
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -u "$(cat "$MCS/app-path.txt")"                            # forget the copy's registration
rm -rf "$MCS"
```

`defaults delete` reports that the domain was not found when the copy never ran. That is fine.
Run `lsregister -u` even then: the build itself registers the app with LaunchServices (its log's
`RegisterWithLaunchServices` step), whether or not the app ever launches.
