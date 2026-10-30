# tools/person-authority-facts — the person authority's Wikidata snapshot (#1767)

`PersonAuthorityIndexGenerator` stamps an overlay entry's Wikidata and VIAF ids on a registry record only
where the identifier rule takes them (`PersonIdentifierRule`, the identifier assessment's rule (b4)): the
item must be a person whose names and life years fit the record, and the registry's years, the record's
VIAF id or a word of its registry remarks must agree. The rule reads its items from
`PersonAuthorityIndexGenerator/wikidata-snapshot.json`, committed beside the tool, so a run goes to no
network and reproduces. `refresh_wikidata_snapshot.py` writes that file. Standard library only, macOS's
bundled `python3`; its docstring says what each field of the file holds.

## Run it

```bash
PERSONS_COMPLETE=~/Development/frus-name-authority/4_Outputs/persons-complete.xml \
PEOPLE_DATA_DIR=~/Development/people/data \
  python3 -I tools/person-authority-facts/refresh_wikidata_snapshot.py
```

About ten minutes, measured 2026-10-30: three SPARQL queries a minute apart for the VIAF ids' holders
(query.wikidata.org rate-limits this client to one request a minute), then 109 `wbgetentities` calls for
4,331 items and 127 for the 6,331 labels their claims point to, a second apart. Answers are cached under
`.cache/wikidata-snapshot/` (gitignored); a run that stops resumes where it stopped, and removing the
cache fetches afresh. Do not add `maxlag` to the reads: the API then refuses while the query service lags.

## When to run it

- **When the generator refuses** with *overlay identifiers the run would test have no facts in the Wikidata
  snapshot*: the overlay or the registry has moved since the snapshot was fetched, and the new ids would
  otherwise be withheld unread.
- **When the overlay or the registry is updated**, before regenerating `person-authority-index.json`.

The tool refuses to write (`NOT WRITTEN`, exit 1) when an id it collected is left without facts.

## After a refresh

A refreshed snapshot moves the bundle wherever an item changed on Wikidata. Run the generator's control
first (the `PersonAuthorityIndexGenerator` entry of `Planning/Generators-Runbook.md`), then regenerate,
and read the diff record for record: every id the rule withholds is printed with why. The corpus's own
cases are pinned in `PersonIdentifierRuleCorpusTests` (the Kennedys, McKee and Denton, Brezhnev and the
carrier, the Castros, the Einaudis, Truman's nephew); one that moves is read on wikidata.org before its
expectation changes. A changed VIAF id reaches a library only at its next person-rollup rebuild, since the
rollup stores `viaf_id`.

## Licence

Wikidata's data is CC0. The snapshot holds no VIAF data (ODC-By): the VIAF ids in it are Wikidata's own
claims (P214), and the rule reads no VIAF cluster.
