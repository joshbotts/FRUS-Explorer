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
- **A `frusexplorer://` link opened from the shell goes to the INSTALLED app.** Never run
  `open "frusexplorer://document/…"` on the Mac to reach a document in the copy. Launch Services
  hands the scheme to `/Applications/FRUS Explorer.app`: on 2026-10-11 that launched the installed
  build 49 against the owner's real library and opened a document in it, and the copy showed
  nothing. Reach a document through the copy's own windows (Corpus Browser, Search, Citation
  Lookup). `xcrun simctl openurl <udid> "frusexplorer://document/<volume>/<document>"` is the
  simulator's own and is safe.

## Driving and reading the copy, measured on 2026-10-10

Found while walking #1576 lane 4's list in the copy.

- **Type with real keystrokes.** Text set through the background accessibility route did not
  reach the Search field as typing does: Return was written into the field as a line break, and
  the search that followed listed nothing. The same query typed through the full-screen tools
  listed 5,079 results.
- **Resize a window with System Events, not by dragging.** A drag that would end over the desktop
  is refused. This sets a width, and the window keeps its own minimum:
  ```bash
  osascript -e 'tell application "System Events" to tell (first process whose bundle identifier is "bottsywattsy.FRUS-Explorer.maccheck") to set size of window "Search" to {640, 680}'
  ```
  `description of every UI element of toolbar 1 of window "Search"`, asked the same way, lists the
  items a toolbar is showing. Stepping the width and asking again gives the widths at which a
  titlebar folds each item into its » menu.
- **Read accessibility names with `axread.swift`, not with System Events.** A SwiftUI control in
  a window's content gives its name as an attributed string (`AXAttributedDescription`), which
  AppleScript cannot read: a named checkbox looks nameless there. `axread.swift` reads the
  accessibility API itself and prints the name, value, help, identifier and enabled state of
  every element of one role in one window:
  ```bash
  MCS=${MAC_CHECK_SCRATCH:-$HOME/Library/Caches/frus-mac-check}
  swiftc -O -o "$MCS/axread" tools/mac-check-copy/axread.swift
  "$MCS/axread" Search AXCheckBox 5
  ```
  A toolbar item is AppKit's and gives a plain `AXDescription`, which is its title: an
  `.accessibilityLabel` on a toolbar button does not replace it, and `.accessibilityValue` does
  come through.
- **A toolbar button's `.help` did show** under a pointer moved by computer use: the main
  window's Search button, and the Search window's Reading picker and Select button. The note
  above found the opposite on the Collections toolbar, so a tooltip that does not appear is no
  proof that it is missing, and one that does appear can be read.

## Preferences and recordings, measured on 2026-10-21

Found in the build-51 sitting S4, which took the Mac's captures and recordings in the copy
(`Docs/screenshots/README.md`, *Found by S4*, item 9; #1763).

- **Put the copy's preferences back with `prefs-restore.swift`, not `defaults import`.** The
  copy's preferences live in the real `~/Library/Preferences` (see *Limits* above), so a sitting
  that changes them exports the domain first and puts the export back at the end. S4 exported the
  domain's 96 keys and set 15 others for the sitting with `defaults import`, which took. At the
  end, `defaults import` of the export exited 0 and changed nothing, twice. Setting the keys one
  by one through CFPreferences put all 96 back, identical to the export. `prefs-restore.swift`
  does that, removes the keys the export lacks, then reads the domain back through `defaults
  export` and names any key that differs. Run it with the copy quit:
  ```bash
  MCS=${MAC_CHECK_SCRATCH:-$HOME/Library/Caches/frus-mac-check}
  defaults export bottsywattsy.FRUS-Explorer.maccheck "$MCS/prefs-before.plist"   # before the sitting
  swiftc -O -o "$MCS/prefs-restore" tools/mac-check-copy/prefs-restore.swift
  "$MCS/prefs-restore" "$MCS/prefs-before.plist"                                  # after it
  ```
  It exits 1 when a key reads back different. Read an export back from a file, as it does:
  `defaults export` writes a binary property list to a file, and XML to standard output (`-`),
  which keeps a date only to the second.
- **Record the copy with `apprec.swift`, not `screencapture -v` or QuickTime.** While computer
  use drives the copy, the Claude app draws its own windows on the screen, and a recording of the
  screen takes them in: a `screencapture -v` test showed the Claude app's panel over the copy.
  QuickTime's screen recording takes in whatever is on the screen in the same way. `apprec.swift`
  records a part of the display through ScreenCaptureKit, leaving out the Claude app's windows
  (bundle id `com.anthropic.claudefordesktop`), so the copy is recorded and the panel is not. S4
  made recording A and the Mac App Preview's pass B with it, at 60 frames a second:
  ```bash
  MCS=${MAC_CHECK_SCRATCH:-$HOME/Library/Caches/frus-mac-check}
  swiftc -O -o "$MCS/apprec" tools/mac-check-copy/apprec.swift
  "$MCS/apprec" 20 "$MCS/take.mov" 100,80,1440,900   # seconds, the file, x,y,w,h in display points
  ```
  The rectangle is in points from the screen's top left; `get {position, size} of window 1`,
  asked of the copy's process through System Events as above, gives a window's. Like
  `screencapture`, it needs the Screen Recording permission.

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
