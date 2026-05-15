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
          <date>2003</date>
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
          <date>1986</date>
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
        <publicationStmt><date>2010</date></publicationStmt>
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
        <publicationStmt><date>2014</date></publicationStmt>
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
}
