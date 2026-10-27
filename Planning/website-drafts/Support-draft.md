<!--
  A plain-language draft of Docs/Support.md, 2026-10-27 (plan of record decision 101). It is not the
  copy of record and is not published. After review its text replaces the body of Docs/Support.md,
  under that file's own header, and Scripts/build_website_pages.py writes the HTML. Its claims are
  the copy of record's at v2 1c18b51, with two additions: the coming-soon line, which comes out on
  release day, and the sentence saying what TEI is, which needs a row in Docs/Website/README.md.
-->

# FRUS Explorer Support

FRUS Explorer is a research app for iPhone, iPad and Mac. It helps you read and search the Foreign Relations of the United States series: the official documentary record of U.S. foreign policy, published since 1861 by the Office of the Historian. The app builds on the Office's open TEI editions.

**Coming soon.** FRUS Explorer has been submitted to the App Store and is not there yet. Until it is, this page is here for the people testing it.

> FRUS Explorer is an independent, private-capacity research tool. It is not an official product of the Office of the Historian or the U.S. Department of State. Any commentary, advice, or guidance about the FRUS series in this app reflects personal views about historical research methodology and makes no interpretive claims about the history of U.S. foreign policy. Those views are not necessarily those of the Department of State or the U.S. Government. The FRUS series itself is in the public domain.

For help with the app, write to its developer, not to the Office of the Historian.

## Manuals and guides

- [FRUS Explorer for iPad and iPhone — User Manual](https://github.com/joshbotts/FRUS-Explorer/blob/HEAD/Docs/iOS-User-Manual.md)
- [FRUS Explorer for macOS — User Manual](https://github.com/joshbotts/FRUS-Explorer/blob/HEAD/Docs/macOS-User-Manual.md)

The app links to both manuals from **Settings → System → About**. It also has a **FRUS Research Guide**, which introduces the series itself. On iPhone and iPad, find it on the Research tab, or in **Settings → System → About → FRUS Research Guide**. On a Mac, choose **Help → FRUS Research Guide**.

## Contact

Email **help@frusexplorer.app**. It helps to include:

- your device and its system version;
- the app's version and build, from **Settings → System → About** (for example, *Version 1.0 (1861)*);
- what you did, what you expected, and what happened instead;
- for a problem with iCloud sync, the Sync Log, from **Settings → System → Data & Recovery → Sync Log → Export…**. The log holds the kinds of events, their times and any error codes. It never holds your content.

The [privacy policy](https://frusexplorer.app/privacy) says what happens to an email you send.

## Common questions

**What does the app need?** An iPhone or iPad with iOS or iPadOS 26 or later, or a Mac with macOS 26 or later. Document summaries also need Apple Intelligence. On a Mac, that means a Mac with Apple silicon.

**Where do the documents come from?** From the Office of the Historian's public TEI editions of the series. TEI is a standard way to mark up a text. The app reads those marks to tell a heading from a footnote, or a person's name from the words around it. The app downloads the volumes you choose from the Office's collection on GitHub. Then it builds a search index on your device. After that, reading and searching work offline.

**Do I need an account?** No. If your device is signed in to iCloud, your notes, collections and other research sync through your own iCloud account. Two services are optional. Each needs a free key of your own, which you add in **Settings → System → Connections**:

- the National Archives Catalog, which lets Source Explorer look up the records a document's source note names (the card links to where you get a key);
- Zotero, which lets you send documents, with your tags and notes, to your Zotero library.

**What is natural-language search?** A way to search by meaning instead of by matching words. It is still experimental. It needs a model, Google's EmbeddingGemma 2, which is an optional 310 MB download (**Settings → Volumes & Storage → Download Search Model**). The model runs only on your device, so nothing you search leaves it.

**Can I use the search index with my own tools?** Yes, on a Mac. **Settings → System → Data & Recovery → Export Research Database…** saves a checked copy of the index as a SQLite file. Your notes, summaries and tag names are left out unless you turn on **Include My Notes, Summaries, and Tags**. The [Agentic Analysis Guide](https://github.com/joshbotts/FRUS-Explorer/blob/HEAD/Docs/Agentic-Analysis-Guide.md) explains the database, and how to check what an AI tool tells you about it. If you give a copy to an online service, that service's terms apply.

**My notes are not reaching my other devices.** First, check the app's iCloud status. On iPhone and iPad, it is at the top of Settings. On a Mac, it is at the right end of the main window's status bar. If something is wrong, the status says what. Then read the manual's section on Data & Recovery. It lists the recovery steps in order and says what each one deletes.

## Privacy

FRUS Explorer collects no data. What you read, search and write stays with you: notes and collections sync only through your own iCloud account, and the app reaches the National Archives' catalog or your Zotero library only when you ask it to. The [privacy policy](https://frusexplorer.app/privacy) has the details.

## Source code

FRUS Explorer's source code is public, under the Apache License 2.0, at <https://github.com/joshbotts/FRUS-Explorer>.

---

This page is published in two copies kept identical: at <https://frusexplorer.app/support> and at <https://github.com/joshbotts/FRUS-Explorer/blob/HEAD/Docs/Support.md>.
