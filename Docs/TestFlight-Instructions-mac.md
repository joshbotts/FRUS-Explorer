# What's New Since Build 44 (Mac)

The headline: **what the app does when the Office of the Historian corrects a volume you already hold**.

**Build 44's two one-time costs are gone.** No index change shipped this time, so there is no re-index and no Spotlight re-donation on first launch.

## When a volume is corrected

FRUS volumes are corrected after publication, and until now that landed silently under your notes, highlights and quotations. The app now records each document's change set as it indexes, and says so.

- A **banner** on a changed document states whether its **text moved** or only its **notes and heading** changed — only the first can strand a highlight. A document an update *removed* still opens; its review sheet is the only route left to it.
- The **review sheet** (the banner's Review…, or Review Changes… in the Research window) walks your work on it: **Confirm**, **Remove** or **Move Here** each highlight; every quotation frozen from it is re-checked against the new text; notes, tags and archive-visit plans open from it; **Summarize Again**; **Mark Reviewed**.
- The **Research window** (⌘⌥R) gains a **Changed by an update** filter across six kinds of annotation, and **Settings ▸ Volumes & Storage** an **After an Update** summary per volume.
- Review state **syncs** — mark a document reviewed here and your iPhone stops listing it.

**Expect silence, and check that you get it.** The change set is written at index time, and a document's *first* indexing records a baseline and reports nothing. So on a library you already hold these surfaces stay quiet in build 45 by design; they light up from the next correction onward. The bug worth reporting is the opposite one — a document claiming an update changed it when none did. To see the whole flow you need a volume corrected since you downloaded it: **Volumes & Storage ▸ Check for Corrections** will say.

## Also

**Project coverage**: how much of a working corpus a project has actually engaged — a badge on each row (Untouched / Opened / In a collection / Annotated), a coverage line above the list, a Project Home tile, and a coverage statement in all three exports. **Enclosures**: Source Explorer gives a 19th-century document's enclosures their own archival home — each was filmed in its own originating series, not with the despatch that carried it. **Getting data out**: Export Research Database… (Settings ▸ Data & Recovery), and Copy Research-State Record (Volumes & Storage ▸ Advanced), and `frusexplorer://` document links. Exported figures now carry their caveats and credit the Office of the Historian. The splash drifts.

## What to test

1. Open documents you have annotated. Nothing should claim an update changed them. Anything that does is a bug — report the document id.
2. Volumes & Storage ▸ **Check for Corrections**. If one comes back for a volume you have worked in, take it and open a changed document: is the text-vs-notes claim right? Does the sheet find your highlights in the new text?
3. Mark one document reviewed; confirm it leaves **Changed by an update** on another device.
4. **Corpus Browser ▸ Clusters — the verdict we still owe.** Open several and read what is in them. Coherent research leads, or arbitrary piles? "Piles" is the most useful answer you can give: it means we remove the feature in one commit.
5. Meaning search, if you took the model: do the top matches deserve opening? Still unanswered from build 44.
6. A project with real work in it: does the coverage line match what you remember doing, and does the exported statement agree?
7. Source Explorer on a 19th-century document with enclosures — right archival home for the enclosure?

Include macOS version, clicks, expected vs. actual. Thanks!
