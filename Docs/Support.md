<!--
  One of two copies kept in step (plan of record decision 36). Its twin is
  Docs/Website/support.html, published at https://frusexplorer.app/support, the address App Store
  Connect names. This copy is the one edited: run Scripts/build_website_pages.py after any change,
  and commit both. Docs/Website/README.md traces its factual sentences to the code.
-->

# FRUS Explorer Support

FRUS Explorer is a research app for iPhone, iPad and Mac for the Foreign Relations of the United States series: the official documentary record of U.S. foreign policy, published since 1861.

> FRUS Explorer is an independent research tool. It is not an official product of the Office of the Historian or the U.S. Department of State. Any commentary, advice, or guidance about the FRUS series in this app reflects personal views. Those views are not necessarily those of the Department of State or the U.S. Government. The FRUS series itself is in the public domain.

For help with the app, write to its developer, not to the Office of the Historian.

## Manuals and guides

- [FRUS Explorer for iPad and iPhone — User Manual](https://github.com/joshbotts/FRUS-Explorer/blob/HEAD/Docs/iOS-User-Manual.md)
- [FRUS Explorer for macOS — User Manual](https://github.com/joshbotts/FRUS-Explorer/blob/HEAD/Docs/macOS-User-Manual.md)

The app links to both from **Settings → System → About**. Its **FRUS Research Guide**, an introduction to the series itself, is in the app: on iPhone and iPad, a row on the Research tab or **Settings → System → About → FRUS Research Guide**; on a Mac, **Help → FRUS Research Guide**.

## Contact

Email **[ADDRESS]@frusexplorer.app**. It helps to include:

- your device and its system version;
- the app's version and build, from **Settings → System → About** (for example, *Version 1.0 (1861)*);
- what you did, what you expected, and what happened instead;
- for an iCloud sync problem, the Sync Log, from **Settings → System → Data & Recovery → Sync Log → Export…**. It holds event types, timing and error codes, never your content.

The [privacy policy](https://frusexplorer.app/privacy) says what happens to an email you send.

## Common questions

**What does the app need?** An iPhone or iPad with iOS or iPadOS 26 or later, or a Mac with macOS 26 or later. Document summaries also need Apple Intelligence, which on a Mac means Apple silicon.

**Where do the documents come from?** From the Office of the Historian's public TEI editions of the series. The app downloads the volumes you choose from the Office's repository on GitHub and indexes them on your device; from then on, reading and searching work offline.

**Do I need an account?** No. If your device is signed in to iCloud, your notes, collections and other research sync through your own iCloud account. Two services are optional, each with a free key of your own, in **Settings → System → Connections**: the National Archives Catalog, which lets Source Explorer look up the records a document's source note cites (the card links to where you get a key), and Zotero, which lets you send documents with your tags and notes to your Zotero library.

**What is natural-language search?** An experimental way to search by meaning rather than by matching words. It needs a model, Google's EmbeddingGemma 2, which is an optional 310 MB download (**Settings → Volumes & Storage → Download Search Model**) and runs on your device only: nothing you search leaves it.

**My notes are not reaching my other devices.** Start with the app's iCloud status, at the top of Settings on iPhone and iPad and at the right of the main window's status bar on a Mac, which names the problem when there is one. Then read the manual's section on Data & Recovery, which lists the recovery steps in order and what each one deletes.

## Privacy

FRUS Explorer collects no data. What you read, search and write stays with you: notes and collections sync only through your own iCloud account, and the app reaches the National Archives' catalog or your Zotero library only when you ask it to. The [privacy policy](https://frusexplorer.app/privacy) has the details.

## Source code

FRUS Explorer's source code is public, under the Apache License 2.0, at <https://github.com/joshbotts/FRUS-Explorer>.

---

This page is published in two copies kept identical: at <https://frusexplorer.app/support> and at <https://github.com/joshbotts/FRUS-Explorer/blob/HEAD/Docs/Support.md>.
