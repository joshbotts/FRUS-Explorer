# FRUS Explorer for iOS and iPadOS — Supplement for macOS Users

> This guide is for researchers who already know FRUS Explorer on Mac and want to use it on iPhone or iPad. It does not repeat every feature from scratch; instead it maps what you know to where things are on iOS and explains what is different, better, or touch-specific.

---

## Table of Contents

1. [The Big Picture: Windows Become Tabs](#1-the-big-picture-windows-become-tabs)
2. [Tab-by-Tab Walkthrough](#2-tab-by-tab-walkthrough)
3. [Reading and Annotating Documents](#3-reading-and-annotating-documents)
4. [Indexing Banners (New on iOS)](#4-indexing-banners-new-on-ios)
5. [iPad-Specific Features](#5-ipad-specific-features)
6. [Touch Gestures Reference](#6-touch-gestures-reference)
7. [Feature Differences at a Glance](#7-feature-differences-at-a-glance)

---

## 1. The Big Picture: Windows Become Tabs

On macOS, FRUS Explorer keeps every major tool in a separate, resizable window: the corpus browser, search, research notes, and collections each live in their own space. On iOS a tab bar at the bottom of the screen takes over that role. The five tabs correspond to the windows you know:

| macOS Window | iOS Tab |
|---|---|
| Corpus Browser (⇧⌘B) | **Browse** (leftmost tab) |
| Search (⌘F) | **Search** |
| Research window (⌘⌥R) | **Research** |
| Collections (⇧⌘K) | **Collections** |
| Settings (⌘,) | **Settings** |

The **main document window** on macOS — the large central reading area — has no direct tab equivalent. Instead, tapping any document in Browse, Search, or Research pushes it onto that tab's navigation stack, covering the list view. The Back button (top-left) returns you to the list, just as ⌘[ does on the Mac.

`[SCREENSHOT: iPhone bottom tab bar showing all five tabs with icons and labels]`

---

## 2. Tab-by-Tab Walkthrough

### 2.1 Browse Tab

This is the Corpus Browser. The hierarchy — Corpus → Subseries → Volume → Chapter → Document — is identical to the macOS version.

`[SCREENSHOT: Browse tab on iPhone showing the top-level subseries list]`

**What's the same:** All navigation levels, download buttons, date-range and subject-tag filters.

**What's different:**

- The browser occupies the full tab rather than a separate window. Breadcrumbs along the top of the navigation stack let you jump back multiple levels at once.
- **Analytics** is accessed from a toolbar button (chart icon) at the top right of the Browse tab. On macOS this opens a separate Analytics window; on iOS it slides up as a sheet. All chart features (dimension, date range, chart vs. table) are identical.

`[SCREENSHOT: Analytics sheet on iPhone showing bar chart with dimension and date controls]`

### 2.2 Search Tab

`[SCREENSHOT: Search tab on iPhone with the keyword field, active filters, and results list]`

**What's the same:** Query syntax (phrase, boolean, prefix wildcard), advanced filters, timeline toggle, saved searches, result tapping to open a document.

**What's different:**

- On the Mac, Search lives in a persistent window alongside your document. On iPhone, opening a search result navigates into the document within the Search tab. Tap **Back** to return to results without losing them.
- **Citation Lookup** (⌘⇧F on Mac) is accessed by tapping the **magnifying glass + quote** button in the Search tab toolbar. It opens as a sheet over the tab.

`[SCREENSHOT: Citation Lookup sheet on iPhone showing the Paste Citation and Structured Entry tabs]`

### 2.3 Research Tab

`[SCREENSHOT: Research tab on iPhone showing a two-column split: tag sidebar on the left, document list on the right]`

This is the Research window from macOS, adapted for touch.

**What's the same:** Browsing all annotated documents, filtering by project or user tag, opening documents.

**What's different:**

- On iPhone, the tag sidebar and document list stack vertically; swipe right from the left edge to reveal the tag sidebar.
- On iPad, both columns are always visible side by side (see Section 5).
- **Long-press** any document row to open a context menu with options: *Open*, *Edit Note*, *Add to Collection*, *Remove Tag*.

### 2.4 Collections Tab

`[SCREENSHOT: Collections tab on iPhone showing collection list with a "+" button in the navigation bar]`

**What's the same:** Creating collections, adding documents (individually or by tag), smart collection linking, export formats (PDF and HTML).

**What's different:**

- **Reordering** uses the standard iOS edit mode. Tap **Edit** (top-right), then drag the reorder handles that appear on each row.
- **Export** uses the iOS share sheet (UIActivityViewController), giving you options to save to Files, share via AirDrop, send by email, print directly, and more.

`[SCREENSHOT: Export share sheet on iPhone showing Files, Mail, AirDrop, and Print options]`

### 2.5 Settings Tab

`[SCREENSHOT: Settings tab on iPhone showing a grouped list layout]`

**What's the same:** All panes — General, Research, Corpus, Advanced (NARA API + Summarization), Reset — are present with identical functionality.

**What's different:**

- Settings is a tab rather than a system Settings scene, so you reach it from within the app rather than from the iOS Settings app.
- The layout is a flat grouped list rather than the macOS sidebar. Tap any row to drill into its pane.
- **Volume management** (download queue, storage breakdown, Check for Updates, Sideload XML) is under **Settings → Corpus → Add Volumes** — same path as macOS.

---

## 3. Reading and Annotating Documents

### 3.1 Document Toolbar

When you open a document on iPhone, a toolbar appears below the navigation bar. It provides the same tools as the macOS research strip but organized for touch:

`[SCREENSHOT: Document view on iPhone with the document toolbar labeled, showing Note, Tags, Collection, Citation, Graph, and More buttons]`

| Button | Mac equivalent |
|--------|---------------|
| **Note** | Research strip → Add / Edit Note |
| **Tags** | Research strip → Tags |
| **Collection** | Research strip → Collections |
| **Citation** | Research strip → Citation |
| **Graph** | Toolbar → Graph |
| **More (…)** | Reveals: Source Explorer, Summarize, Share |

### 3.2 Text Highlighting

Highlighting is a fully touch-native feature on iOS. To highlight and annotate a passage:

1. **Long-press** a word to begin a text selection.
2. Drag the selection handles to cover the passage you want.
3. In the context menu that appears, tap **Highlight**.
4. An optional note field appears — add a note or leave it blank and tap **Save**.

`[SCREENSHOT: Text selection on iPhone with the "Highlight" option visible in the context menu]`

Highlights appear in the document as colored underlines. Tap any highlight to view or edit its note.

> **Mac note:** Text highlighting in the same form is not available on macOS. On the Mac, you select text and click Highlight in the research strip; this anchors the selection and links it to a note, but the visual highlight overlay in the document is an iOS-only feature.

### 3.3 Summary Strip

Generated summaries appear in a strip between the toolbar and the document body, the same as on macOS. Tap **View Others** to see all summaries for this document. Tap **Use as Draft** to promote a summary into a research note.

`[SCREENSHOT: Summary strip on iPhone with a one-paragraph summary visible and "View Others" button]`

### 3.4 Interactive Document Elements

Person references, glossary terms, and cross-references all work with a tap rather than a click:

- **Tap persName** → Person Index entry slides up as a sheet.
- **Tap gloss** → Terms & Abbreviations entry slides up as a sheet.
- **Tap cross-reference** → The referenced document opens in the current navigation stack. Use Back to return.

### 3.5 Cross-Reference Graph

Tap **Graph** in the document toolbar to open the cross-reference graph as a full-screen push (or sheet on iPad). All graph features are identical to macOS: three-column layout, force-directed physics for large networks, degree filter, cluster collapsing.

`[SCREENSHOT: Cross-reference graph full-screen on iPhone with a three-column layout]`

**Touch interactions in the graph:**

| Gesture | Effect |
|---------|--------|
| Tap node | Select; shows full title below the graph |
| Long-press node | Context menu: *Re-centre*, *Open Document* |
| Pinch | Zoom |
| Two-finger drag | Pan |

---

## 4. Indexing Banners (New on iOS)

On macOS, indexing progress is shown quietly in the status bar at the bottom of the main window. On iOS, an animated banner appears above the tab bar during indexing — more prominent because iOS has no always-visible status bar equivalent.

`[SCREENSHOT: iPhone with an indexing banner above the tab bar showing a progress bar and percentage]`

**Single volume being indexed:** Progress bar + percentage complete + volume name.

**Multiple volumes in queue:** Current position in queue, e.g., *Indexing 2 of 5 — 1969–1976, Vol. XI*, plus an estimated time remaining.

`[SCREENSHOT: Multi-volume indexing banner showing queue position and ETA]`

**Indexing complete:** A summary card slides up briefly showing total documents indexed and a **Search Now** shortcut button. Tap it to jump directly to the Search tab.

`[SCREENSHOT: Indexing-complete card with document count and "Search Now" button]`

The banners dismiss automatically when their state changes. You do not need to interact with them — all other tabs remain fully usable while indexing runs.

---

## 5. iPad-Specific Features

iPad gives you more screen room, and FRUS Explorer uses it in two important ways.

### 5.1 Inspector Panels

On iPad in landscape orientation, most tabs add a persistent side panel on the right (an iOS `inspector`) instead of relying on sheets and navigation pushes.

`[SCREENSHOT: iPad landscape view of the Browse tab with the document list on the left and a document open in the right inspector panel]`

| Tab | Inspector contents |
|-----|--------------------|
| **Browse** | Open document with full research note panel below |
| **Search** | Open document (same) |
| **Research** | Full research note editor for the selected document |
| **Collections** | Collection detail with document list |

The inspector means you can read a document and edit its note without ever leaving the Browse or Search results list — the same mental model as the macOS two-window layout.

### 5.2 Multi-Window (Stage Manager)

On iPad with Stage Manager enabled, you can open multiple documents in separate windows simultaneously. Long-press a document in any list and choose **Open in New Window** from the context menu.

`[SCREENSHOT: iPad Stage Manager showing two FRUS Explorer windows side by side, each showing a different document]`

Each window maintains its own navigation history and research strip state. Notes and tags saved in either window sync immediately.

### 5.3 Keyboard and Trackpad Support

With an external keyboard or the Magic Keyboard folio, most macOS keyboard shortcuts work identically on iPad:

| Action | Shortcut |
|--------|----------|
| Jump to Search tab | ⌘F |
| Jump to Browse tab | ⇧⌘B |
| Back in navigation | ⌘[ |
| Forward in navigation | ⌘] |
| Add / edit note | ⌘⌥N |
| Copy citation | ⌘⌥C |

---

## 6. Touch Gestures Reference

| Gesture | Where | Effect |
|---------|-------|--------|
| Tap | Document list row | Open document |
| Long-press | Document list row | Context menu (Open, Edit Note, Add to Collection, etc.) |
| Swipe left | Document list row | Quick-delete user tag or remove from collection |
| Long-press | Document body text | Begin text selection (then drag handles to extend) |
| Tap highlighted text | Document body | View / edit highlight note |
| Tap persName / gloss / ref | Document body | Open linked entry as sheet |
| Swipe right from left edge | Research tab | Reveal tag sidebar |
| Tap node | Cross-reference graph | Select node |
| Long-press node | Cross-reference graph | Context menu (Re-centre, Open Document) |
| Pinch | Cross-reference graph | Zoom |
| Two-finger drag | Cross-reference graph | Pan |
| Pinch | Timeline in Search | Zoom timeline axis |
| Drag | Timeline in Search | Pan timeline |

---

## 7. Feature Differences at a Glance

This table summarizes every significant difference between the macOS and iOS versions. Where iOS is *different* does not mean it is *lesser* — many touch interactions are more direct than their Mac counterparts.

| Feature | macOS | iOS / iPadOS |
|---------|-------|--------------|
| **Navigation structure** | Multiple windows | Tab bar; each tab has its own navigation stack |
| **Document reading area** | Dedicated main window | Pushes into the active tab's stack |
| **Text highlights** | Research strip button; no visual overlay | Long-press → select → Highlight; colored underline overlay in document |
| **Analytics** | Separate persistent window | Sheet from Browse tab toolbar |
| **Citation Lookup** | Separate window (⌘⇧F) | Sheet from Search tab toolbar |
| **Research notes panel** | Always-visible research strip + note editor | Toolbar button; inline editor on iPhone, inspector panel on iPad |
| **Source Explorer** | Sheet in main window | Sheet over current tab |
| **Reorder collection items** | Drag-and-drop directly | Tap Edit first, then drag reorder handles |
| **Export share target** | NSSharingServicePicker + Reveal in Finder | iOS share sheet (Files, AirDrop, Print, Mail, etc.) |
| **Indexing progress** | Quiet status bar indicator | Animated banner above tab bar |
| **Settings access** | System Settings scene (⌘,) | Settings tab within the app |
| **Inspector panel** | N/A | iPad landscape: right-side persistent panel |
| **Multi-window documents** | Standard macOS multi-window | iPad Stage Manager: long-press → Open in New Window |
| **Keyboard shortcuts** | Full macOS shortcut set | Subset available with external keyboard on iPad |
| **AI Summarization** | Apple Silicon Mac required | iPhone 16 Pro / iPad with Apple Intelligence required |
| **iCloud sync** | Automatic | Automatic — same iCloud account shares all data |

---

*Your notes, tags, collections, highlights, and summaries are stored in iCloud and appear automatically on every device signed into the same Apple ID. Changes made on your iPhone are visible on your Mac within seconds, and vice versa.*
