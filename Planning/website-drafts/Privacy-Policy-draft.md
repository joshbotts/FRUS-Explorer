<!--
  A plain-language draft of Docs/Privacy-Policy.md, 2026-10-27 (plan of record decision 101). It is
  not the copy of record and is not published. After review its text replaces the body of
  Docs/Privacy-Policy.md, under that file's own header, and Scripts/build_website_pages.py writes the
  HTML. Its claims are the copy of record's at v2 1c18b51, claim for claim, so the trace in
  Docs/Website/README.md holds; set the Last updated date to the day it lands.
-->

# FRUS Explorer Privacy Policy

*Last updated October 20, 2026. This policy covers FRUS Explorer for iPhone, iPad and Mac, from version 1.0.*

FRUS Explorer is made by Joshua Botts ("the developer").

## In short

FRUS Explorer collects no data. The app has no account of its own to sign in to. It has no advertising, no analytics and no tracking. The developer runs no server that the app reports to. The app's privacy label on the App Store reads **Data Not Collected**.

What you read, search and write stays with you: notes and collections sync only through your own iCloud account, and the app reaches the National Archives' catalog or your Zotero library only when you ask it to.

The rest of this page explains what the app keeps, where it keeps it, and every place it connects to.

## What stays on your device

- **Your library.** The volumes you download and the search index the app builds from them. Also their figure images, the semantic match files that let the app compare documents by meaning, and the search model, if you download it.
- **Your research.** Notes, highlights, tags, collections, projects, saved searches, working corpora (saved sets of documents), volume scopes (saved sets of volumes), archive visit plans and leads. Also AI summaries, your summary prompts, and any corrections you make to who a person is or how a document is classified.
- **Your research trail.** While **Log Research Sessions** is on, the app records the documents you open, the words of the searches you run, and the collections you export. History, a project's recent activity and the Session Log show this record. The switch is on unless you turn it off, in **Settings → Research → Research Sessions**. When you turn it off, the recording stops. **Delete Recorded Sessions…** on the same screen removes what was recorded.
- **What you ask the app.** Searches run against the index on your device. When you search by meaning, a model on your device turns your question into numbers, and the question does not leave the device. Apple Intelligence's on-device model writes document summaries, and the document's text does not leave your device.
- **Diagnostics.** The app's diagnostic records stay on your device unless you copy or export them yourself. They are the iCloud Sync Log (the kinds of events, their times and any error codes, never your content), the iCloud schema report, the language-analysis record and the index's research-state record.
- **Semantic Match Feedback.** The verdicts you record on the semantic matches in Related Documents stay on your device and are not synced (see [Sending feedback](#sending-feedback)).
- **Spotlight and Handoff.** The app adds the documents in your downloaded volumes to your device's Spotlight index, so system search can find them. That index stays on your device. While you read a document or use the semantic map, the app offers it to your other devices through Handoff. Apple carries Handoff between devices signed in to the same Apple Account. The offer names the document, or the volumes and scope the map shows.
- **Files you export.** A collection, a chart's data, the JSON export, the method appendix and, on a Mac, a copy of the search index go only where you save or send them. If you give one to another service, such as an AI tool, that service's terms apply.

## iCloud

If your device is signed in to iCloud, and iCloud is on for FRUS Explorer, the app syncs your research and your research trail through your own private iCloud database. That is how they appear on your other devices. Apple stores them under its own terms and privacy policy, and the developer cannot see them. To keep your research on one device, turn off iCloud for FRUS Explorer in your device's iCloud settings.

Downloaded volumes and the search index are not synced. Each device downloads and indexes its own.

The app's own settings stay on each device. They sync only if you turn on **Sync Settings Across Devices**, which starts off. It shares your word-cloud filters and stop lists, your citation style, your default document mode and the research-logging switch, through the same private database.

The NARA Catalog and Zotero API keys you enter are stored in your device's keychain. If you use iCloud Keychain, it carries them to your other devices.

## What the app downloads, and from where

The app downloads public files from the hosts below. Each request names a file or a folder. It carries nothing that identifies you or your device. Like any request on the internet, it shows the host your network address and ordinary technical details, such as the app's name. The host receives the request, not the developer, and the host's own privacy policy covers what it records.

- **The list of published volumes**, from GitHub (`api.github.com`), in the Office of the Historian's public `HistoryAtState/frus` repository. The app asks for it at launch while the device is online, and when you open **Settings → Volumes & Storage** or refresh its list.
- **Volumes**, from GitHub (`raw.githubusercontent.com`), in the same repository. The app gets a volume when you download or update it. At launch, or when the device reconnects, it also finishes a download you started.
- **Figure images**, from the Office of the Historian's image server (`static.history.state.gov`). The app gets them after a volume with figures downloads. At launch and when the device reconnects, it gets any images still missing from downloaded volumes. It also gets a single image when a document or an export needs it first.
- **Semantic match files**, one small file for each volume, from GitHub (`raw.githubusercontent.com`), in the developer's public `frus-semantic-vectors` repository. The app gets one with each volume you download, and when Related Documents or a search by meaning needs it. Turn off **Download With Volumes** in **Settings → Volumes & Storage** to stop both. The app gets them all at once when you choose **Download Missing Vectors** or **Download Vectors for Every Volume**. The files that a search by meaning or Related Documents asks for depend on the volumes it found. So those requests show GitHub which volumes they were, but never your question.
- **The search model**, Google's EmbeddingGemma 2 (310 MB), from GitHub (`github.com`), in a release of the same repository. The app gets it only when you choose **Download Search Model**.

## Services you connect yourself

Neither service is required. The app uses neither until you add your own key in **Settings → System → Connections**. **Remove Key** and **Disconnect** on the same screen remove them.

**The National Archives Catalog.** With a NARA Catalog API key, Source Explorer looks up the records a document's source note names. When you open Source Explorer on such a document, or run a catalog lookup yourself, the app sends the search terms and your key to the National Archives Catalog (`catalog.archives.gov`). The terms come from the note or from what you type: a record group, a lot number, a collection or keywords. Because the key is yours, the National Archives can link those lookups to it, under its own terms of use and privacy policy. Without a key, the app sends the Catalog nothing.

**Zotero.** After you connect your Zotero account with your own API key, the app sends your Zotero library (`api.zotero.org`) only what you choose to send. That is the citation details of the documents or the collection, with your tags and research notes on them. It never sends the documents' text. To connect, the app asks Zotero which account the key belongs to. It asks again on a device the key reached through iCloud Keychain. The developer never receives any of it. Zotero's own terms and privacy policy apply.

## Links you open

Links in About and in the FRUS Research Guide open in a browser built into the app. Links that lead out of a document, Source Explorer or a catalog lookup open in your default browser. The sites they lead to have their own privacy policies. Like any browser, the built-in one keeps the cookies and website data those sites set, inside the app.

## Sending feedback

**Semantic Match Feedback** (**Settings → System → Data & Recovery**) keeps the verdicts you give on the experimental semantic matches in Related Documents. Each verdict records the two documents, your judgement, the match score, which release of the match files it applies to, and when you gave it. The app sends none of it on its own. If you choose to share the file, by email to feedback@frusexplorer.app or any other way your device offers, it goes where you send it.

If you write to the developer with a question, a bug report or the feedback file, the developer receives your message, your email address and anything you attach. The developer uses them only to answer you and to improve the app. They are not sold or shared, and you can ask for them to be deleted.

## Apple's services

Apple provides the App Store, iCloud, iCloud Keychain, Handoff, Spotlight and Apple Intelligence under its own privacy policy. You may have chosen, in your device's privacy settings, to share analytics with app developers. If so, Apple may give the developer crash reports and usage statistics for the app. The app adds nothing of its own to them.

## Children

FRUS Explorer is a research tool and is not aimed at children. It collects no information from anyone, children included.

## Deleting your data

- Delete a note, highlight, tag, collection or other item in the app, and iCloud deletes it from your other devices too.
- **Settings → Research → Research Sessions → Delete Recorded Sessions…** deletes your research trail.
- **Settings → System → Data & Recovery → Erase Everything…** deletes the downloaded volumes and the search index on the device. It also deletes all of your research data, research trail included, on every device that syncs it. Your app settings are kept.
- Deleting the app deletes what it stored on that device. Your research in iCloud stays until you delete it in the app. Your API keys stay in your keychain until you remove them in **Settings → System → Connections**.

## Changes to this policy

When the app's handling of data changes, this page changes too, and the date at the top says when. The policy is published in two copies kept identical: at <https://frusexplorer.app/privacy> and in the app's public repository on GitHub, at <https://github.com/joshbotts/FRUS-Explorer/blob/HEAD/Docs/Privacy-Policy.md>, where every change to it is recorded.

## Contact

Questions about this policy: help@frusexplorer.app. For help with the app, see [FRUS Explorer Support](https://frusexplorer.app/support).
