# App Store Custom EULA — paste-ready text (V-5, Gemma flow-down)

**Status:** prepared 2026-08-28, adversarially reviewed (four-reviewer panel; every finding
addressed — the findings and their dispositions are in the PR that landed this file), then
re-verified against the revised text. The owner enters it in App Store Connect. **This file is
the canonical text the compliance runbook §5 points at.**

## Instructions (do not paste this section)

1. The body contains **FOUR bracketed placeholders**. Three are in section 15 (Developer
   Contact) — your mailing address (a P.O. box is fine), a telephone number, and the support
   email; Apple's minimum terms (instruction 8) require all three stated in the EULA, so the
   text does NOT satisfy Apple until they are filled. The fourth is in section 17 (Governing
   Law) — fill it with your state, or delete that section entirely (default conflict-of-law
   rules then apply); **if you delete section 17, also delete "and 17" from section 13's
   survival list.** Never paste a literal bracket into App Store Connect.
2. App Store Connect → My Apps → FRUS Explorer → **App Information** → **License Agreement**
   → Edit → paste everything below the cut line → apply to all territories → Save.
3. Do this **before submitting the build that carries the encoder** (any build cut at or after
   the s2 merge) for review. TestFlight is not gated — the in-app consent sheet is the
   operative agreement there — but staging this first costs nothing.
4. Provenance: the structure and every required provision follow Apple's "Instructions for
   Minimum Terms of Developer's End-User License Agreement"
   (apple.com/legal/internet-services/itunes/appstore/dev/minterms/, all ten instructions);
   the substantive sections adapt Apple's Standard EULA
   (apple.com/legal/internet-services/itunes/dev/stdeula/) into developer voice; section 3 is
   the Gemma flow-down clause from `Gemma-Compliance-Runbook.md` §5. **Three recorded
   deviations from Apple's exact instruction text**: instruction 5's HealthKit/HomeKit example
   clause is omitted because the app uses neither framework; the Standard EULA's
   consent-to-data-collection section is replaced by section 9's stronger factual statements,
   because this app collects nothing; and the Standard's open-source-components carve-out on
   the reverse-engineering ban is omitted because it could be read to swallow the ban whole
   for an app that is itself open-source — section 11's licenses-govern-those-components
   sentence covers bundled components instead. All three deliberate; none weakens a required
   provision.
   Engineering-side drafting, not legal advice — read it once before pasting; it is written
   to be readable.

---- PASTE EVERYTHING BELOW THIS LINE ----

END-USER LICENSE AGREEMENT — FRUS EXPLORER

This End-User License Agreement ("Agreement") governs your use of the FRUS Explorer
application ("Application") published by Josh Botts ("Developer"). By downloading or using
the Application you agree to this Agreement.

1. Acknowledgement. You and the Developer acknowledge that this Agreement is concluded
between you and the Developer only, and not with Apple Inc. ("Apple"), and that the
Developer, not Apple, is solely responsible for the Application and its content. This
Agreement does not provide usage rules for the Application that conflict with the Apple
Media Services Terms and Conditions, and to the extent any term of this Agreement is found
to conflict with the Usage Rules set forth there, the Apple Media Services Terms and
Conditions control.

2. Scope of License. The Developer grants you a non-transferable license to use the
Application on any Apple-branded products that you own or control, as permitted by the Usage
Rules set forth in the Apple Media Services Terms and Conditions, except that the
Application may be accessed and used by other accounts associated with the purchaser via
Family Sharing or volume purchasing. The terms of this Agreement govern any content or
services accessible from within the Application, and any upgrades provided by the Developer
that replace or supplement the original Application, unless a separate license accompanies
them. Except as provided in the Usage Rules, you may not distribute or make the Application
available over a network where it could be used by multiple devices at the same time, and
you may not transfer, redistribute or sublicense the Application and, if you sell your
Apple Device to a third party, you must remove the Application from the Apple Device before
doing so. You may not copy (except as permitted by this license and the Usage Rules), reverse-engineer, disassemble, attempt to
derive the source code of, modify, or create derivative works of the Application, any
updates, or any part thereof, except to the extent any such restriction is prohibited by
applicable law. The Developer reserves all rights in and to the Application not expressly
granted to you under this Agreement. Separately from the copy of the Application delivered
through the App Store — which this section governs — the Application's source code is
published under the Apache License, Version 2.0, and nothing in this Agreement restricts the
rights that license grants you in that separately distributed source code as obtained from
its source repository. The optional on-device model described in section 3 is governed as
stated there.

3. Optional On-Device Search Model. The Application can, at your request, download Google's
EmbeddingGemma model for on-device search. The model is provided under and subject to the
Gemma Terms of Use (ai.google.dev/gemma/terms), including the Gemma Prohibited Use Policy
(ai.google.dev/gemma/prohibited_use_policy), which are incorporated into this Agreement with
respect to your use of the model. You may use the model only in compliance with those terms,
and your rights to use the model terminate automatically if you breach them. The model is
optional: it is downloaded only when you choose, it runs entirely on your device, and
declining or removing it leaves every other feature of the Application unaffected. Google is
not a party to this Agreement and provides the model "as is," without warranties or
conditions of any kind except as required by applicable law. A copy of the Gemma Terms of
Use is included in the Application (About > Legal > Full Notices).

4. Maintenance and Support. The Developer is solely responsible for providing any
maintenance and support services with respect to the Application, as required under
applicable law. You and the Developer acknowledge that Apple has no obligation whatsoever to
furnish any maintenance and support services with respect to the Application.

5. Warranty. To the maximum extent permitted by applicable law, the Application and any
services performed or provided by it are provided "AS IS" and "AS AVAILABLE," with all
faults and without warranty of any kind, and the Developer disclaims all warranties and
conditions with respect to the Application, whether express, implied, or statutory,
including implied warranties or conditions of merchantability, satisfactory quality, fitness
for a particular purpose, accuracy, quiet enjoyment, and non-infringement of third-party
rights. The Developer is solely responsible for any product warranties, whether express or
implied by law, to the extent not effectively disclaimed. In the event of any failure of the
Application to conform to any applicable warranty, you may notify Apple, and Apple will
refund the purchase price for the Application to you; to the maximum extent permitted by
applicable law, Apple will have no other warranty obligation whatsoever with respect to the
Application, and any other claims, losses, liabilities, damages, costs or expenses
attributable to any failure to conform to any warranty will be the Developer's sole
responsibility. Some jurisdictions do not allow the exclusion of implied warranties or
limitations on applicable statutory rights of a consumer, so the above exclusions and
limitations may not apply to you.

6. Historical Content. The Application presents the Foreign Relations of the United States
series and related archival reference data for research purposes. The Developer does not
warrant the completeness or accuracy of historical documents, third-party catalog data, or
experimental features, and none of it constitutes legal, governmental, or professional
advice.

7. Product Claims. You and the Developer acknowledge that the Developer, not Apple, is
responsible for addressing any claims by you or any third party relating to the Application
or your possession and/or use of the Application, including, but not limited to: (i) product
liability claims; (ii) any claim that the Application fails to conform to any applicable
legal or regulatory requirement; and (iii) claims arising under consumer protection,
privacy, or similar legislation. This Agreement does not limit the Developer's liability to
you beyond what is permitted by applicable law.

8. Intellectual Property Rights. You and the Developer acknowledge that, in the event of any
third-party claim that the Application or your possession and use of the Application
infringes that third party's intellectual property rights, the Developer, not Apple, will be
solely responsible for the investigation, defense, settlement and discharge of any such
intellectual property infringement claim.

9. Data. The Application does not collect your personal data or research content for the
Developer, and contains no analytics or tracking. Your notes, highlights, tags, collections,
and other research data are stored on your device and synced through your own iCloud account
when iCloud is available, under Apple's terms, unless you disable iCloud for the Application
in system settings. Diagnostic logs remain on your device unless you choose to export them.
At your request, the Application can send your notes, tags, and citations to your own Zotero
account, using an API key you supply; the Developer never receives them. The Application
retrieves publicly available content — document volumes, vector files, the optional search
model, and archival catalog data — from public repositories maintained by the Developer and
by the Office of the Historian, and from third-party services such as the U.S. National
Archives; those requests carry no personal information beyond what any network request
necessarily includes and, where a service requires it, credentials you have supplied for
that service.

10. External Services. The Application enables access to third-party services and websites,
including the U.S. National Archives Catalog, the Office of the Historian's document
repositories, Zotero, and the archival and reference websites the Application links to
(collectively, "External Services"). You use External Services at your sole risk. The
Developer is not responsible for examining or evaluating the content or accuracy of any
third-party External Services, and shall not be liable for any such third-party External
Services. You agree to use External Services in compliance with applicable law and their own
terms, and you acknowledge that External Services may change or become unavailable at any
time.

11. Third-Party Terms of Agreement. You must comply with applicable third-party terms of
agreement when using the Application — including the Gemma Terms of Use described in
section 3 if you download the optional search model, Apple's iCloud terms if you use sync,
Zotero's terms if you connect a Zotero account, and the National Archives Catalog's terms of
use for catalog data. The Application also includes open-source components licensed under
their own terms, listed in the Application (About > Legal > Full Notices); those licenses
govern those components.

12. Legal Compliance. You represent and warrant that (i) you are not located in a country
that is subject to a U.S. Government embargo, or that has been designated by the U.S.
Government as a "terrorist supporting" country, and (ii) you are not listed on any U.S.
Government list of prohibited or restricted parties. You may not use or otherwise export or
re-export the Application except as authorized by United States law and the laws of the
jurisdiction in which the Application was obtained.

13. Termination. This Agreement is effective until terminated by you or the Developer. Your
rights under this Agreement terminate automatically if you fail to comply with any of its
terms. Sections 3 (as to the model's own terms), 5, 6, 7, 8, 12, 14, 15, 16, and 17 survive
termination.

14. Limitation of Liability. To the extent not prohibited by law, in no event shall the
Developer be liable for personal injury or any incidental, special, indirect, or
consequential damages whatsoever, including, without limitation, damages for loss of
profits, loss of data, business interruption, or any other commercial damages or losses,
arising out of or related to your use of or inability to use the Application, however
caused, regardless of the theory of liability (contract, tort, or otherwise) and even if the
Developer has been advised of the possibility of such damages. In no event shall the
Developer's total liability to you for all damages (other than as may be required by
applicable law in cases involving personal injury) exceed the greater of the amount you paid
for the Application and fifty dollars ($50.00). The foregoing limitations will apply even if
the above stated remedy fails of its essential purpose. Some jurisdictions do not allow the
limitation of liability for personal injury, or of incidental or consequential damages, so
this limitation may not apply to you.

15. Developer Contact. Questions, complaints or claims with respect to the Application
should be directed to:

Josh Botts
[MAILING ADDRESS]
[TELEPHONE NUMBER]
[SUPPORT EMAIL ADDRESS]

16. Third-Party Beneficiary. You and the Developer acknowledge and agree that Apple, and
Apple's subsidiaries, are third-party beneficiaries of this Agreement, and that, upon your
acceptance of the terms and conditions of this Agreement, Apple will have the right (and
will be deemed to have accepted the right) to enforce this Agreement against you as a
third-party beneficiary thereof.

17. Governing Law. This Agreement is governed by the laws of [YOUR STATE / COUNTRY], without
regard to conflict of law principles, to the extent permitted by the mandatory consumer law
of your place of residence.
