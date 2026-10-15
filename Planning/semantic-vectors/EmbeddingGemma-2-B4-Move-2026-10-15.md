# EmbeddingGemma 2, B4 part 2: the move

**Date:** 2026-10-15 · **Status:** DRAFT — the owner's two decisions (§1) are open. · **Issue:** #1659
· **Plan of record:** decisions 15 to 17, §1's and §3's B4 bullets · **Inherits:** the stage-2 memo's
§11 and the runtime memo (`EmbeddingGemma-2-B4-Runtime-2026-10-15.md`, #1673) · **Machine:** the M5
MacBook Air (`Mac17,4`, 32 GB), macOS 27.0.1, Xcode 27.0 · **Artifacts and the scripts that made
them:** `eg2-b4-move-2026-10-15/`.

## 1. The owner's two decisions

Each was measured on 2026-10-15 on the Air, and each is proposed, not decided.

### 1a. How the encoder reaches a device

Under Apache 2.0 neither way needs an agreement: the consent sheet, the Terms screen and the
flow-down retire either way (the spike design's §1).

| | EmbeddingGemma 300m (builds 42–50) | EmbeddingGemma 2 |
|---|---|---|
| the file | 229,093,184 B | 309,855,456 B (+80,762,272) |
| deflate -9 | 218,780,346 B (95.5%) | 282,739,162 B (91.2%) |

Build 50's archives (2026-10-13): the iOS app is 86.2 MB installed and 43.1 MB as a deflate-9 zip,
of which the executable is 23.9 MB raw and 10.0 MB compressed. The App Store encrypts the
executable, which then does not compress, so its download is about 57 MB (an estimate: App Store
Connect has the figure). The Mac app is 120.3 MB. Build 51 adds about 4 MB either way (the rebuilt
`llama.framework`).

- **Inside the binary:** about 400 MB installed and 340 MB to download on iOS, past the default that
  asks before a cellular App Store download over 200 MB, on every fresh install; an update that
  leaves the file alone should not resend it. Every reader carries it, Meaning search or not. The
  Mac app and its DMG grow by the same 310 MB. The repository cannot hold the file (GitHub's 100 MB
  limit, the dSYMs' reason), so the build would fetch it the way the archive fetches the dSYMs: a
  fetch script, a verified cache, a copy phase on both app targets, and the file hosted publicly
  anyway. The download code, its verification and its storage rows would go, and Meaning search
  would work at first launch.
- **An opt-in download, no agreement step:** the app stays about 61 MB to download. The button
  downloads at once (no sheet), with the size and "runs on this device" where they are now. The
  fetcher, its length-then-SHA-256 check, its progress, the app's cellular switch and the Remove
  row are built and tested, and change in four constants (URL, file name, length, and the pin,
  which is the bundled index's). 310 MB is about 50 seconds at 50 Mb/s. A reader who downloaded the
  300m finds it purged at the first launch of build 51 (the pin moves) and the offer back, once.

The encoder's memory and time do not depend on the delivery: on the owner's iPhone 17 Pro it loads
in 630 ms and adds about 170 MB while a Meaning search runs (the runtime memo's hand-over).

**Proposed: the opt-in download.** Most readers keep a small app, nothing is added to the build,
and the path is the one already measured. The GGUF goes to a new release, `encoder-2`, so
`encoder-1` stays what builds 42 to 50 fetch, after the artifact repository's Model weights section
is rewritten (the upload is the owner's yes).

### 1b. Whether the Meaning chip's percentage is recalibrated

The chip shows the raw cosine (`SemanticScoreCopy.percent`), and so does Related Documents'
semantic chip, whose cosine also enters Related's weighted sum (the axis is self-normalising,
#643). EmbeddingGemma 2's cosines sit higher everywhere: an on-topic question's mean cosine over
the whole corpus is 0.62 against the 300m's 0.28 to 0.31, and two documents' 0.71 against 0.49.

Measured over 90 typed queries through both models at `a0e6dc7` (the owner's 25, of which "Space
aliens" is the null control; 45 on-topic questions and 20 off-topic ones written for this
measurement, `eg2-b4-move-2026-10-15/`), each scored against all 314,616 documents' int8-512 rows as
the app scores them, and 600 seeded anchor documents against all others for Related:

| median score | 300m, as shown | EmbeddingGemma 2, raw | EmbeddingGemma 2, recalibrated |
|---|---|---|---|
| owner's queries, best match | 61% | 80% | 62% |
| owner's queries, tenth | 57% | 77% | 57% |
| on-topic queries, best match | 65% | 81% | 65% |
| off-topic queries, best match | 32% | 64% | 32% |
| "Space aliens", best match | 60% | 74% | 52% |
| Related, closest neighbour | 87% | 92% | 86% |
| Related, tenth neighbour | 79% | 88% | 79% |

Raw, an off-topic question's best match reads 64%, the 300m's figure for an on-topic one: the
off-topic best matches span 58–70% and the on-topic ones 72–86%. EmbeddingGemma 2 separates the two
better than the 300m did (on-topic against off-topic best match, AUC 0.997 against 0.988); its raw
numbers hide it in a band twenty points wide.

**Proposed: recalibrate.** One rule, `shown = (cosine − c) / (1 − c)`, clamped to 0–100%, with `c`
measured for the model: 0.47 for a question against a document (the Meaning chip, the fallback
card, the rows of undownloaded volumes, VoiceOver's value) and 0.40 for a document against a
document (Related's chip and its share of Related's sum). The fitted figures are the table's last
column, within two points of the 300m's on every row but "Space aliens". 100% still means
identical. The constants are pinned to the model's SHA-256, so a later model shows its raw cosine
until it is measured. Related's sum keeps the balance the owner set on 2026-09-10 (the semantic axis
at 0.5), which was tuned on the 300m's scale. The alternatives: keep the raw cosine (no code
change; every figure about twenty points higher on a typed query and five to nine on Related), or
drop the number for the rank alone (every surface, both manuals and the EditableContent blocks).

---

Version history:
  0.1 — 2026-10-15: draft; §1 the two decisions, measured, for the owner.
