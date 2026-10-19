<!--
  One of two copies kept in step (plan of record decision 36). Its twin is
  Docs/Website/privacy.html, published at https://frusexplorer.app/privacy, the address App Store
  Connect names. This copy is the one edited: run Scripts/build_website_pages.py after any change,
  and commit both. Docs/Website/README.md traces every factual sentence here to the code it
  describes; a change to what the app sends, keeps or syncs owes this page an edit.
-->

# FRUS Explorer Privacy Policy

*Last updated October 15, 2026. This policy covers FRUS Explorer for iPhone, iPad and Mac, from version 1.0.*

FRUS Explorer is made by Joshua Botts ("the developer").

## In short

FRUS Explorer collects no data. The app has no account of its own to sign in to, no advertising, no analytics and no tracking, and the developer runs no server that the app reports to. Its App Store privacy label reads **Data Not Collected**.

What you read, search and write stays with you: notes and collections sync only through your own iCloud account, and the app reaches the National Archives' catalog or your Zotero library only when you ask it to.

The rest of this page says what the app keeps, where it keeps it, and every place it connects to.

## What stays on your device

- **Your library.** The volumes you download, the search index the app builds from them, their figure images, the semantic match files and, if you download it, the search model.
- **Your research.** Notes, highlights, tags, collections, projects, saved searches, working corpora, volume scopes, archive visit plans and leads, AI summaries and your summarization prompts, and the corrections you make to person identities and document classifications.
- **Your research trail.** While **Log Research Sessions** is on, the app records the documents you open, the text of the searches you run and the collections you export, so that History, a project's recent activity and the Session Log can show them. The switch is on unless you turn it off, in **Settings → Research → Research Sessions**; turn it off and the recording stops, and **Delete Recorded Sessions…** on the same screen removes what was recorded.
- **What you ask the app.** Searches run against the index on your device. A question you type into a search by meaning is turned into numbers by a model that runs on your device, and the question does not leave it. Document summaries are written by Apple Intelligence's on-device model, and the document's text does not leave your device.
- **Diagnostics.** The app's diagnostic records stay on your device unless you copy or export them yourself: the iCloud Sync Log (event types, timing and error codes, never your content), the iCloud schema report, the language-analysis record and the index's research-state record.
- **Semantic Match Feedback.** The verdicts you record on Related Documents' semantic matches are stored on your device and are not synced (see [Sending feedback](#sending-feedback)).
- **Spotlight and Handoff.** The app adds the documents of the volumes you have downloaded to your device's Spotlight index, so that system search can find them; that index is kept on your device. While you read a document or use the semantic map, the app offers it to your other devices through Handoff, which Apple carries between devices signed in to the same Apple Account; the offer names the document, or the volumes and scope the map shows.

## iCloud

If your device is signed in to iCloud and iCloud is on for FRUS Explorer, the app syncs your research and your research trail through your own private iCloud database, so they appear on your other devices. Apple stores them under its own terms and privacy policy, and the developer cannot see them. To keep your research on one device, turn iCloud off for FRUS Explorer in your device's iCloud settings.

Downloaded volumes and the search index are not synced: each device downloads and indexes its own.

The app's own settings stay on each device unless you turn on **Sync Settings Across Devices** (off unless you turn it on), which shares your word-cloud filters and stop lists, citation style, default document mode and the research-logging switch through the same private database.

The NARA Catalog and Zotero API keys you enter are stored in your device's keychain, and iCloud Keychain carries them to your other devices if you use it.

## What the app downloads, and from where

The app downloads public files from the hosts below. Each request names a file or a folder and carries no identifier of you or your device. Like any request on the internet, it shows the host your network address and ordinary technical details, such as the app's name; the host, not the developer, receives it, and the host's own privacy policy governs what it records.

- **The list of published volumes**, from GitHub (`api.github.com`), the Office of the Historian's public `HistoryAtState/frus` repository: at launch while the device is online, and when you open **Settings → Volumes & Storage** or refresh its list.
- **Volumes**, from GitHub (`raw.githubusercontent.com`), the same repository: when you download or update a volume, and at launch or when the device reconnects, to finish a download you started.
- **Figure images**, from the Office of the Historian's image server (`static.history.state.gov`): after a volume with figures downloads; at launch and when the device reconnects, for downloaded volumes still missing images; and for a single image when a document or an export needs it first.
- **Semantic match files**, a small file for each volume, from GitHub (`raw.githubusercontent.com`), the developer's public `frus-semantic-vectors` repository: with each volume you download, and when Related Documents or a search by meaning needs a volume's file, unless you turn off **Download With Volumes** in **Settings → Volumes & Storage**; and all at once when you choose **Download Missing Vectors** or **Download Vectors for Every Volume**. Which files a search by meaning or Related Documents asks for depends on the volumes it found, so those requests show GitHub which volumes they were, though never your question.
- **The search model**, Google's EmbeddingGemma 2 (310 MB), from GitHub (`github.com`), a release of the same repository: only when you choose **Download Search Model**.

## Services you connect yourself

Neither service is required, and the app uses neither until you add your own key in **Settings → System → Connections**. **Remove Key** and **Disconnect** on the same screen remove them.

**The National Archives Catalog.** With a NARA Catalog API key, Source Explorer looks up the records a document's source note cites. When you open Source Explorer on such a document, or run a catalog lookup yourself, the app sends the National Archives Catalog (`catalog.archives.gov`) the search terms drawn from the note or typed by you (a record group, a lot number, a collection or keywords) with your key. Because the key is yours, the National Archives can associate those lookups with it, under its own terms of use and privacy policy. Without a key, the app sends the Catalog nothing.

**Zotero.** After you connect your Zotero account with your own API key, the app sends your Zotero library (`api.zotero.org`) what you choose to send: the citation details of the documents or the collection, with your tags and research notes on them, never the documents' text. To connect, the app asks Zotero which account the key belongs to, and it asks again on a device the key reached through iCloud Keychain. The developer never receives any of it. Zotero's own terms and privacy policy apply.

## Links you open

Links in About and the FRUS Research Guide open in a built-in browser inside the app; links that lead out of a document, Source Explorer or a catalog lookup open in your default browser. The sites they lead to have their own privacy policies. Like any browser, the built-in one keeps the cookies and website data those sites set, inside the app.

## Sending feedback

**Semantic Match Feedback** (**Settings → System → Data & Recovery**) keeps the verdicts you give Related Documents' experimental semantic matches. Each verdict records the two documents, your judgement, the match score, which release of the vectors it applies to, and when you gave it. The app sends none of it on its own. If you choose to share the file, by email to feedback@frusexplorer.app or any other way your device offers, it goes where you send it.

If you write to the developer, with a question, a bug report or the feedback file, the developer receives your message, your email address and anything you attach, and uses them only to answer you and to improve the app. They are not sold or shared, and you can ask for them to be deleted.

## Apple's services

Apple provides the App Store, iCloud, iCloud Keychain, Handoff, Spotlight and Apple Intelligence under its own privacy policy. If you have chosen in your device's privacy settings to share analytics with app developers, Apple may give the developer crash reports and usage statistics for the app; the app adds nothing of its own to them.

## Children

FRUS Explorer is a research tool and is not directed at children. It collects no information from anyone, children included.

## Deleting your data

- Delete a note, highlight, tag, collection or other item in the app, and it is deleted from your other devices through iCloud.
- **Settings → Research → Research Sessions → Delete Recorded Sessions…** deletes your research trail.
- **Settings → System → Data & Recovery → Erase Everything…** deletes the downloaded volumes and the search index on the device, and all of your research data, research trail included, on every device that syncs it. Your app settings are kept.
- Deleting the app deletes what it stored on that device. Your research in iCloud stays until you delete it in the app, and your API keys stay in your keychain until you remove them in **Settings → System → Connections**.

## Changes to this policy

When the app's handling of data changes, this page changes with it, and the date at the top says when. The policy is published in two copies kept identical: at <https://frusexplorer.app/privacy> and in the app's public repository on GitHub, at <https://github.com/joshbotts/FRUS-Explorer/blob/HEAD/Docs/Privacy-Policy.md>, where every change to it is recorded.

## Contact

Questions about this policy: help@frusexplorer.app. For help with the app, see [FRUS Explorer Support](https://frusexplorer.app/support).
