// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Fixture TEI XML strings for TEIHeaderParser and tag-extraction tests.
///
/// These fixtures represent real-world patterns observed in FRUS TEI headers.
/// Each fixture is a valid XML fragment ending in `</teiHeader></TEI>` as produced
/// by `TEIHeaderFetcher`.
enum TEIFixtures {

    /// Full-featured header: complete title, multiple editors, general editor,
    /// publication date, date range, and volume-level tags.
    static let fullHeader = """
    <?xml version="1.0" encoding="UTF-8"?>
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
    <teiHeader>
      <fileDesc>
        <titleStmt>
          <title type="complete">Foreign Relations of the United States, 1969–1976, Volume I, Foundations of Foreign Policy, 1969–1972</title>
          <editor role="primary">David C. Humphrey</editor>
          <editor role="primary">Edward C. Keefer</editor>
          <editor role="general">Edward C. Keefer</editor>
        </titleStmt>
        <publicationStmt>
          <publisher>United States Government Publishing Office</publisher>
          <date calendar="gregorian" type="publication-date">2003</date>
        </publicationStmt>
      </fileDesc>
      <profileDesc>
        <creation>
          <date from="1969-01-01" to="1972-12-31"/>
        </creation>
        <textClass>
          <keywords scheme="http://unstats.un.org/unsd/methods/m49/m49.htm">
            <term>United States</term>
          </keywords>
          <keywords scheme="https://history.state.gov/tags">
            <term>kissinger-henry-a</term>
            <term>iran</term>
            <term>arms-control-and-disarmament</term>
          </keywords>
          <keywords scheme="https://history.state.gov/historicaldocuments/administrations">
            <term>nixon</term>
          </keywords>
        </textClass>
      </profileDesc>
    </teiHeader></TEI>
    """

    /// Header with no publication date (older volumes often omit it).
    static let noPublicationDate = """
    <?xml version="1.0" encoding="UTF-8"?>
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
    <teiHeader>
      <fileDesc>
        <titleStmt>
          <title type="complete">Foreign Relations of the United States, 1861</title>
          <editor role="primary">Gaillard Hunt</editor>
        </titleStmt>
        <publicationStmt>
          <publisher>Government Printing Office</publisher>
        </publicationStmt>
      </fileDesc>
    </teiHeader></TEI>
    """

    /// Header with no tags keywords element (pre-tagging volumes).
    static let noTagsKeywords = """
    <?xml version="1.0" encoding="UTF-8"?>
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
    <teiHeader>
      <fileDesc>
        <titleStmt>
          <title type="complete">Foreign Relations of the United States, 1952–1954, Volume VI, Western Europe and Canada</title>
          <editor role="primary">John P. Glennon</editor>
          <editor role="general">William Z. Slany</editor>
        </titleStmt>
        <publicationStmt>
          <date calendar="gregorian" type="publication-date">1986</date>
        </publicationStmt>
      </fileDesc>
      <profileDesc>
        <creation>
          <date from="1952-01-01" to="1954-12-31"/>
        </creation>
      </profileDesc>
    </teiHeader></TEI>
    """

    /// Header with a wrong-scheme keywords element only (no tags-scheme keywords).
    static let wrongSchemeKeywords = """
    <?xml version="1.0" encoding="UTF-8"?>
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
    <teiHeader>
      <fileDesc>
        <titleStmt>
          <title type="complete">Test Volume</title>
        </titleStmt>
        <publicationStmt><date calendar="gregorian" type="publication-date">2010</date></publicationStmt>
      </fileDesc>
      <profileDesc>
        <textClass>
          <keywords scheme="https://history.state.gov/historicaldocuments/administrations">
            <term>obama</term>
          </keywords>
        </textClass>
      </profileDesc>
    </teiHeader></TEI>
    """

    /// Header with multiple keywords elements; only the tags-scheme one should be extracted.
    static let multipleKeywordsElements = """
    <?xml version="1.0" encoding="UTF-8"?>
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
    <teiHeader>
      <fileDesc>
        <titleStmt>
          <title type="complete">Foreign Relations of the United States, 1977–1980, Volume I, Foundations of Foreign Policy</title>
        </titleStmt>
        <publicationStmt><date calendar="gregorian" type="publication-date">2014</date></publicationStmt>
      </fileDesc>
      <profileDesc>
        <textClass>
          <keywords scheme="http://unstats.un.org/unsd/methods/m49/m49.htm">
            <term>United States</term>
          </keywords>
          <keywords scheme="https://history.state.gov/historicaldocuments/administrations">
            <term>carter</term>
          </keywords>
          <keywords scheme="https://history.state.gov/historicaldocuments/media-types">
            <term>print</term>
          </keywords>
          <keywords scheme="https://history.state.gov/tags">
            <term>brzezinski-zbigniew</term>
            <term>human-rights</term>
          </keywords>
        </textClass>
      </profileDesc>
    </teiHeader></TEI>
    """

    /// Old printed volume (frus1861 pattern): a `publication-date` element carrying the print
    /// year as text, an intervening `<idno>` sibling, and a `content-date` element carrying the
    /// coverage range on `@notBefore`/`@notAfter` (its text "1860 to 1861" is not the range).
    /// No `creation/date` — the range must come from `content-date`.
    static let oldPrintedVolume = """
    <?xml version="1.0" encoding="UTF-8"?>
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
    <teiHeader>
      <fileDesc>
        <titleStmt>
          <title type="complete">Papers Relating to Foreign Affairs, 1861</title>
          <editor role="primary">Gaillard Hunt</editor>
        </titleStmt>
        <publicationStmt>
          <publisher>United States Government Printing Office</publisher>
          <pubPlace>Washington</pubPlace>
          <date calendar="gregorian" type="publication-date">1861</date>
          <idno type="frus">frus1861</idno>
          <date calendar="gregorian" notAfter="1861-12-31T23:59:59-05:00"
              notBefore="1860-12-31T00:00:00-05:00" type="content-date">1860 to 1861</date>
        </publicationStmt>
      </fileDesc>
      <notesStmt>
        <relatedItem corresp="#frus1861" type="epub">
          <bibl>
            <date type="publication-date" when="2020-11-25T14:22:48.000Z"/>
          </bibl>
        </relatedItem>
      </notesStmt>
    </teiHeader></TEI>
    """

    /// In-progress modern volume (frus1977-80v05 pattern): a self-closing `publication-date`
    /// (no print year yet) plus a `content-date` carrying the coverage range on
    /// `@notBefore`/`@notAfter`. Expected: `publicationDate == nil`, range still populated.
    static let inProgressModernVolume = """
    <?xml version="1.0" encoding="UTF-8"?>
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
    <teiHeader>
      <fileDesc>
        <titleStmt>
          <title type="complete">Foreign Relations of the United States, 1977–1980, Volume V</title>
        </titleStmt>
        <publicationStmt>
          <publisher>Department of State</publisher>
          <pubPlace>Washington</pubPlace>
          <date calendar="gregorian" type="publication-date"/>
          <idno type="frus">frus1977-80v05</idno>
          <date calendar="gregorian" notAfter="1988-12-31T23:59:59-05:00"
              notBefore="1982-01-01T00:00:00-05:00" type="content-date">1982–1988</date>
        </publicationStmt>
      </fileDesc>
    </teiHeader></TEI>
    """

    /// Oldest-volumes legacy print-year encoding (real `frus1862` shape): the
    /// `type="publication-date"` element is an EMPTY self-closing `@when` build stamp, and the
    /// real historical print year lives on a SIBLING UNTYPED `<date calendar="gregorian">1862</date>`.
    /// A `content-date` sibling carries the coverage range on `@notBefore`/`@notAfter`. Expected:
    /// `publicationDate == "1862"` (from the untyped fallback), range from content-date attrs.
    static let untypedPrintYearVolume = """
    <?xml version="1.0" encoding="UTF-8"?>
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
    <teiHeader>
      <fileDesc>
        <titleStmt>
          <title type="complete">Papers Relating to Foreign Affairs, 1862</title>
          <editor role="primary">Gaillard Hunt</editor>
        </titleStmt>
        <publicationStmt>
          <publisher>United States Government Printing Office</publisher>
          <pubPlace>Washington</pubPlace>
          <date calendar="gregorian">1862</date>
          <idno type="frus">frus1862</idno>
          <date type="publication-date" when="2020-11-25T14:23:15.000Z"/>
          <date calendar="gregorian" notAfter="1862-12-31T23:59:59-05:00"
              notBefore="1860-08-01T00:00:00-05:00" type="content-date">1860 to 1862</date>
        </publicationStmt>
      </fileDesc>
    </teiHeader></TEI>
    """

    /// Self-closing `publication-date` carrying only a digital `@when` build timestamp — this
    /// must NOT populate `publicationDate` (the @when is a build stamp, not a print year).
    static let publicationDateWhenTimestampOnly = """
    <?xml version="1.0" encoding="UTF-8"?>
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
    <teiHeader>
      <fileDesc>
        <titleStmt>
          <title type="complete">Test Volume, In Progress</title>
        </titleStmt>
        <publicationStmt>
          <date type="publication-date" when="2021-06-14T09:00:00.000Z"/>
          <idno type="frus">frusTest</idno>
        </publicationStmt>
      </fileDesc>
    </teiHeader></TEI>
    """
}
