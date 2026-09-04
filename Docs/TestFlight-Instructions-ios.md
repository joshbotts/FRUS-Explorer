# What's New Since Build 44 (iOS)

The headline: **what happens when the Office of the Historian corrects a volume**. Also a per-project coverage map.

**No one-time costs this time.** Build 44 needed a full re-index and a Spotlight re-donation. Build 45 changes no index, so it opens straight into a working library.

## When a volume is corrected

FRUS volumes get corrected after publication — a transcription fixed, a footnote rewritten, occasionally a document withdrawn. The app used to absorb that silently while your highlights moved. It now records each document's change set as it indexes, and says what moved.

- A **banner** on a changed document says whether its **text** moved — highlight positions may have shifted — or whether only footnotes, the source note or the heading changed and the text did not.
- **Review…** opens a sheet over your own work on that document: **Confirm**, **Remove** or **Move Here** each highlight (offered only where the passage is found exactly once, and it shows you the passage in context first), re-checks every quotation you froze against the new text, opens the notes, tags and archive-visit plans attached to it, offers **Summarize Again**, and ends in **Mark Reviewed**.
- The **Research tab** gains a **Changed by an update** filter; **Settings ▸ Volumes & Storage ▸ After an Update** summarises it per volume.
- A document an update **removed still opens** — that sheet is the only route left to it.
- Review state **syncs across your devices**.

**Expect silence, and check that it is silent.** The comparison needs a previously indexed copy, so the first time a document is indexed the app records a baseline and reports nothing. On a library you already hold, these surfaces stay quiet in build 45 by design and light up from the next correction onward. The bug worth reporting is the opposite one — anything claiming an update changed it when none did. To see the whole flow you need a volume corrected since you downloaded it: **Volumes & Storage ▸ Check for Corrections** will say.

## Also

**Coverage**: with a project active, a working corpus's document list badges each row Untouched / Opened / In a collection / Annotated and totals it, with a Project Home tile and a coverage statement in the exported method appendix. **Enclosures** get their own archival home in Source Explorer. Exported figures carry their caveats and credit the Office of the Historian. The search field's prompt follows the engine you picked. `frusexplorer://` links open a document; **Copy Research-State Record** and **Download Vectors for Every Volume** are under Volumes & Storage ▸ Advanced. The splash drifts.

## What to test

1. Launch on your existing library: no re-index, and **nothing claims to have changed**. Report anything that does.
2. **Check for Corrections**. If it finds one, update it, then take a document you had highlighted through the review sheet: does the banner name the right kind of change, and does Move Here land on the right words?
3. Mark a document reviewed; check it clears on a second device.
4. Queue two or three volumes, force-quit before indexing starts, relaunch — **"N downloads queued"** should sit above the tab bar. It showed nothing at all before.
5. Coverage on a corpus you have worked in: does the figure match what you believe you read? Export and read the statement back.
6. **Browse ▸ Clusters — coherent research leads, or arbitrary piles?** Open several and say which. "Piles" is the most useful answer: it means we remove the feature.
7. Meaning search: do the top matches deserve opening? Still unanswered from build 44.

Include device + iOS version, taps, expected, actual — and for anything about corrections, the volume id. Thanks!
