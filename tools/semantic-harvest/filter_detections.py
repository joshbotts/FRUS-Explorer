#!/usr/bin/env python3
"""A rule-based post-filter for a detector store — a scoring ARM, not a product (#234 R-1).

    SOURCE=<detector store> OUT_DIR=<new store> python3 filter_detections.py
    SOURCE=<detector store> OUT_DIR=<new store> RULES=boundary python3 filter_detections.py
    SELFTEST=1 python3 filter_detections.py

WHY IT EXISTS. The qwen3-14b sweep stored 3,656,238 candidate mentions, and the commonest surfaces
are exactly what its own system prompt excludes — `Secretary of State` alone 61,842 times, then
`United States`, `Department`, `Japan`, `he`. A verdict that credits the model with those, or that
condemns the whole LLM route for them, is a verdict about one prompt. So the scorer should see the
raw store AND the same store after mechanical cleanup, side by side — and the NLTagger control after
the SAME cleanup, or the filter is a thumb on one scale.

THE RULES ARE FROZEN BEFORE ANY GROUND TRUTH EXISTS. They were written on 2026-09-12 while the M2a
sample was still un-keyed, from the detector prompt's own exclusion sentence and from ungraded surface
counts. Nothing here has seen a gold span, and every output store records this file's SHA-256, so a
later edit cannot be passed off as the filter that was scored.

The prompt's rule, verbatim (run-manifest.json `system_prompt`): "Exclude countries, cities, ships,
treaties, conferences, legations, departments, companies, and every other non-person name. Exclude a
title with no name attached ("the Secretary of State")."

Rules, applied in this order; the first to match claims the row:

  boundary     the span starts or ends inside a longer word of the R-0 text. harvest_ner's locate()
               grounds with an unbounded substring search, so `he` lands inside `the` and `Japan`
               inside `Japanese`. That is a grounding bug rather than a judgement, which is why
               RULES=boundary exists on its own.
  pronoun      the whole surface is a pronoun (a closed class).
  title        every word is a title, honorific, office or function word — "the Secretary of State",
               "His Majesty", "Sir", "Mr.". One name-bearing word saves the span, and so does a title
               noun used AS a surname right after a rank or honorific: `Admiral King`, `General Pope`,
               `Mr. Lord`, `Prime Minister King` are people, while `the King` and `Mr. Secretary` are
               not.
  institution  every word is a title/office/function word or an institution word, and at least one is
               an institution word — "Department of State", "His Majesty's Government", "United
               States".
  place        the whole surface is a country or territory from the app's own bundled artifacts:
               volume-tag-taxonomy.json places and every decimal-class-labels.json country with its
               historical spellings and alternates.
  curated      the whole surface is on a short explicit list (abbreviations, nationality words, the
               commonest cities, document furniture) drawn from the 300 commonest surfaces of BOTH
               arms, or is a bare Roman numeral. Called curation because it is: this list is the one
               place to look for bias, so it is short, dated and hashed.

WHAT IT DOES NOT DO: ships, treaties and conferences (no closed vocabulary exists in the repo), cities
beyond the curated few, and anything that needs context — a BARE `King` that is Mackenzie King, a bare
`Washington` that is a person, a bare `Victoria` that is the Queen (the gazetteer's `Victoria`,
`Marion`, `Salvador`, `Jordan`, `Israel`, `Georgia` and `Chad` are literal entries in the bundled
artifacts, kept as they are rather than edited to suit this filter). Those costs are MEASURED rather than guessed: every removal is checked
against the editors' own <persName> layer, and each store reports, per rule, how many removed spans the
editors marked as a person. That count needs no ground truth and is a LOWER bound on the rule's damage,
since the editors mark only some persons.

Stdlib only. Store shapes and code-point offsets per NER-RUNBOOK.md §8; reads through ner_store.py.

Version history:
  1.0 — 2026-09-12: initial implementation, frozen before the M2a sitting
  1.1 — 2026-09-12, still before any ground truth: the first full run's own example output showed the
        title rule removing `General Pope`. A census of every title-claimed span ending in <rank>
        <title noun> found the same class at scale — `Mr. King` 548, `Admiral King` 402, `President
        King` 216, `Dr. Lord` 158, `General Sultan` 16 in the sweep — beside the correct removals it
        sits among (`Mr. Secretary` 3,750, `Consul General` 875, `Lord Chancellor`). The rule now
        spares a surname-capable title noun after a rank or honorific. Revised by reading the tool's
        output against its stated intent, NOT against the editors' person layer, which is a scored
        arm and must not shape the filter.
"""

import datetime
import gzip
import hashlib
import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ner_store as store  # noqa: E402

REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
ALL_RULES = ("boundary", "pronoun", "title", "institution", "place", "curated")

PRONOUNS = frozenset("""
he him his himself she her hers herself you your yours yourself yourselves i me my mine myself
we us our ours ourselves they them their theirs themselves it its itself who whom
""".split())

# Words that are a title, honorific or office — never a name on their own. Deliberately absent, each
# because it is also a surname a bare mention can mean: `house` (Colonel House), `dean`, `bishop`,
# `judge`, `marshall` (only `marshal` is here). `king` and `pope` ARE here and are a known cost.
TITLE_WORDS = frozenset("""
mr mrs miss ms messrs dr sir lord lady hon honorable honourable esq excellency excellencies majesty
highness monsieur messieurs m mme madame senor señor sr don herr count baron marquis duke earl
viscount prince princess king queen emperor empress sultan shah pope president vice secretary
secretaries state ambassador ambassadors minister ministers chargé charge d'affaires affaires consul
consuls envoy extraordinary plenipotentiary governor premier prime chancellor chairman generalissimo
marshal general admiral commander chief representative delegate counselor counsellor attaché attache
commissioner senator mayor viceroy acting under assistant deputy foreign affairs finance war navy
""".split())

# A title noun that is also a surname, and the ranks and honorifics that turn it into one. `lord` and
# `chief` are deliberately NOT ranks here: after them a title noun is an office (`Lord Chancellor`,
# `the lord chief baron`), not a person.
SURNAME_TITLE_NOUNS = frozenset("king lord pope duke earl baron sultan shah marquis prince marshal".split())
RANKS_BEFORE_A_NAME = frozenset("""
mr mrs miss ms messrs dr m monsieur messieurs mme madame herr senor señor sr don hon honorable honourable
general admiral commander senator president minister governor
""".split())

FUNCTION_WORDS = frozenset("""
the a an of for and to in his her their its my your our this that these those de du des la le el del
""".split())

INSTITUTION_WORDS = frozenset("""
department departments dept office embassy embassies legation legations consulate consulates
government governments congress commission council assembly committee ministry bureau staff joint
chiefs security united nations states senate cabinet court treasury board mission conference league
parliament administration agency headquarters
""".split())

# Drawn 2026-09-12 from the 300 commonest surfaces of BOTH the qwen3-14b sweep and the NLTagger
# control, before any ground truth existed. Phrases compare casefolded with a leading "the" removed;
# abbreviations compare with dots and spaces removed, so "U. S. S. R." and "USSR" are one entry.
CURATED_PHRASES = frozenset([
    # nationality and group words
    "american", "americans", "british", "briton", "britons", "english", "french", "frenchman",
    "german", "germans", "japanese", "chinese", "russian", "russians", "soviet", "soviets",
    "italian", "italians", "dutch", "spanish", "turkish", "greek", "greeks", "polish", "arab",
    "arabs", "yugoslav", "yugoslavs", "communist", "communists", "allied", "allies",
    # the commonest cities in either arm
    "washington", "london", "paris", "berlin", "rome", "madrid", "moscow", "tokyo", "peking",
    "peiping", "nanking", "shanghai", "chungking", "canton", "tientsin", "hankow", "mukden",
    "new york", "petersburg", "st. petersburg", "vera cruz", "vichy", "formosa", "buenos ayres",
    "buenos aires",
    # document furniture
    "telegram", "telegram the chargé", "ante", "supra", "ibid",
])
CURATED_ABBREVIATIONS = frozenset([
    "us", "usa", "uk", "un", "ussr", "sc", "ga", "eca", "scap", "goi", "goc", "fonoff", "emb",
    "brit", "fr", "indo", "neth", "yugo", "gatt", "dc", "ad", "q",
])
ROMAN = re.compile(r"[IVX]{2,}\.?")

APOSTROPHES = str.maketrans({"’": "'", "‘": "'"})
EDGE = ".,;:!?\"'()[]{}“”"


def words(surface):
    """The surface's words, casefolded, with edge punctuation and a possessive 's removed."""
    out = []
    for raw in surface.translate(APOSTROPHES).split():
        token = raw.casefold().strip(EDGE)
        if token.endswith("'s"):
            token = token[:-2].strip(EDGE)
        if token:
            out.append(token)
    return out


def phrase(surface):
    """Casefolded, apostrophes folded, whitespace collapsed, edge commas trimmed, leading "the" dropped."""
    text = " ".join(surface.translate(APOSTROPHES).casefold().split()).strip(",;: ")
    if text.startswith("the "):
        text = text[4:]
    return text


def compact(surface):
    """The phrase with every dot and space removed — how abbreviations are compared."""
    return re.sub(r"[.\s]", "", phrase(surface))


def place_variants(name):
    """Every surface a gazetteer name can appear as: slash alternates, parenthetical qualifiers
    removed, dotted sub-areas cut at the dot, and "Congo, Republic of" read both ways."""
    variants = set()
    for part in name.split("/"):
        part = part.strip()
        base = re.sub(r"\s*\([^)]*\)", "", part).strip()
        for candidate in {part, base}:
            if not candidate:
                continue
            variants.add(candidate)
            if ". " in candidate:
                variants.add(candidate.split(". ", 1)[0])
            if ", " in candidate:
                head, tail = candidate.split(", ", 1)
                variants.add(head)
                variants.add(tail + " " + head)
    return {phrase(v) for v in variants if len(phrase(v)) >= 4 and not re.search(r"\d", v)}


def load_gazetteer(taxonomy_path, decimal_labels_path):
    """{phrase} of country and territory names from the two bundled artifacts."""
    names = set()
    for entry in json.load(open(taxonomy_path)):
        if entry.get("category") == "places":
            names.add(entry["displayName"])
    for schedule in json.load(open(decimal_labels_path)).get("schedules", []):
        names.update(v for v in schedule.get("countries", {}).values() if isinstance(v, str))
        for alternates in (schedule.get("countryAlternates") or {}).values():
            for alternate in (alternates if isinstance(alternates, list) else [alternates]):
                if isinstance(alternate, str):
                    names.add(alternate)
    gazetteer = set()
    for name in names:
        gazetteer |= place_variants(name)
    gazetteer.discard("other")
    return gazetteer


def names_by_title_noun(tokens):
    """True when the last word is a title noun serving as a surname: `Admiral King`, `Mr. Lord`."""
    return len(tokens) >= 2 and tokens[-1] in SURNAME_TITLE_NOUNS and tokens[-2] in RANKS_BEFORE_A_NAME


def rule_for(surface, text, start, end, rules, gazetteer):
    """The first rule that removes this span, or None to keep it."""
    if "boundary" in rules:
        before = text[start - 1] if start > 0 else ""
        after = text[end] if end < len(text) else ""
        if before.isalnum() or after.isalnum():
            return "boundary"
    tokens = words(surface)
    if "pronoun" in rules and len(tokens) == 1 and tokens[0] in PRONOUNS:
        return "pronoun"
    if "title" in rules and tokens and any(t in TITLE_WORDS for t in tokens) \
            and all(t in TITLE_WORDS or t in FUNCTION_WORDS for t in tokens) \
            and not names_by_title_noun(tokens):
        return "title"
    if "institution" in rules and tokens and any(t in INSTITUTION_WORDS for t in tokens) \
            and all(t in TITLE_WORDS or t in FUNCTION_WORDS or t in INSTITUTION_WORDS for t in tokens):
        return "institution"
    if "place" in rules and phrase(surface).rstrip(".") in gazetteer:
        return "place"
    if "curated" in rules and (phrase(surface).rstrip(".") in CURATED_PHRASES
                               or compact(surface) in CURATED_ABBREVIATIONS
                               or ROMAN.fullmatch(surface.strip())):
        return "curated"
    return None


def sha256_bytes(data):
    return hashlib.sha256(data).hexdigest()


def sha256_file(path):
    return sha256_bytes(open(path, "rb").read())


def write_rows(path, rows, gz):
    """JSON lines, gzipped with mtime=0 when the source was, so a re-run is byte-identical."""
    data = "".join(json.dumps(row, ensure_ascii=False) + "\n" for row in rows).encode("utf-8")
    if gz:
        buffer = io.BytesIO()
        with gzip.GzipFile(fileobj=buffer, mode="wb", mtime=0, filename="") as zipped:
            zipped.write(data)
        data = buffer.getvalue()
    temporary = path + ".tmp"
    with open(temporary, "wb") as handle:
        handle.write(data)
    os.replace(temporary, path)


def vocabulary_digest():
    """One hash over every closed list, so a changed word is a changed filter."""
    parts = [sorted(PRONOUNS), sorted(TITLE_WORDS), sorted(SURNAME_TITLE_NOUNS), sorted(RANKS_BEFORE_A_NAME),
             sorted(FUNCTION_WORDS), sorted(INSTITUTION_WORDS),
             sorted(CURATED_PHRASES), sorted(CURATED_ABBREVIATIONS), ROMAN.pattern]
    return sha256_bytes(json.dumps(parts, ensure_ascii=False).encode("utf-8"))


def run(source, out, text_dir, marked_store, rules, taxonomy, decimal_labels,
        force=False, generated=None, quiet=False):
    """Filter every volume of `source`'s detected layer into a new store at `out`."""
    if not source or not out:
        raise SystemExit("SOURCE and OUT_DIR are both required.")
    source = os.path.abspath(os.path.expanduser(source))
    out = os.path.abspath(os.path.expanduser(out))
    if os.path.realpath(source) == os.path.realpath(out):
        raise SystemExit("OUT_DIR is SOURCE. A filter writes a new store beside the one it read, "
                         "never over it — the raw store is the other half of the comparison.")
    unknown = [rule for rule in rules if rule not in ALL_RULES]
    if unknown or not rules:
        raise SystemExit("unknown RULES %s; choose from %s or 'all'" % (unknown, ", ".join(ALL_RULES)))
    source_detected = os.path.join(source, "detected")
    if not os.path.isdir(source_detected):
        raise SystemExit("%s has no detected/ layer." % source)
    out_detected = os.path.join(out, "detected")
    if os.path.isdir(out_detected) and not force \
            and any(name.endswith(".head.json") for name in os.listdir(out_detected)):
        raise SystemExit("%s already holds filtered volumes. Set FORCE=1 to rebuild it." % out)
    os.makedirs(out_detected, exist_ok=True)

    names = os.listdir(source_detected)
    heads = sorted(name[:-len(".head.json")] for name in names if name.endswith(".head.json"))
    bodies = {name.split(".jsonl")[0] for name in names if ".jsonl" in name and not name.endswith(".tmp")}
    headless = sorted(bodies - set(heads))
    if headless:
        raise SystemExit("body with no head in %s (a killed run, which the scorer refuses too): %s"
                         % (source_detected, ", ".join(headless)))

    gazetteer = load_gazetteer(taxonomy, decimal_labels) if "place" in rules else set()
    marked_available = os.path.isdir(os.path.join(marked_store, "marked"))
    removed = {rule: 0 for rule in rules}
    editor_marked = {rule: 0 for rule in rules}
    examples = {rule: [] for rule in rules}
    source_total = kept_total = 0

    for index, volume in enumerate(heads, 1):
        head = store.layer_head(source, "detected", volume)
        body_path = store.layer_path(source, "detected", volume)
        rows = store.read_jsonl_gz(body_path) if body_path else []
        texts = store.volume_text(text_dir, volume) if rows else {}
        marked = (store.spans_by_document(store.volume_layer(marked_store, "marked", volume))
                  if marked_available else {})
        kept, volume_removed = [], {rule: 0 for rule in rules}
        volume_editor, volume_examples = {rule: 0 for rule in rules}, {rule: [] for rule in rules}
        for row in rows:
            text = texts.get(row["d"])
            if text is None:
                raise SystemExit("%s/%s is in the detected layer but not in the R-0 text at %s"
                                 % (volume, row["d"], text_dir))
            if text[row["s"]:row["e"]] != row["n"]:
                raise SystemExit("span does not match its text in %s %s/%s: [%d,%d) is %r, row says %r"
                                 % (source, volume, row["d"], row["s"], row["e"],
                                    text[row["s"]:row["e"]], row["n"]))
            rule = rule_for(row["n"], text, row["s"], row["e"], rules, gazetteer)
            if rule is None:
                kept.append(row)
                continue
            volume_removed[rule] += 1
            if any(ms < row["e"] and row["s"] < me for ms, me, _ in marked.get(row["d"], [])):
                volume_editor[rule] += 1
            if len(volume_examples[rule]) < 8 and row["n"] not in volume_examples[rule]:
                volume_examples[rule].append(row["n"])

        if body_path:
            gz = body_path.endswith(".gz")
            write_rows(os.path.join(out_detected, volume + (".jsonl.gz" if gz else ".jsonl")), kept, gz)
        new_head = {key: head[key] for key in ("volume", "sampled", "sampled_doc_ids", "docs_in_volume",
                                               "docs_scanned", "chars_scanned", "model",
                                               "marked_in_scanned_docs") if key in head}
        new_head["mentions"] = len(kept)
        new_head["filter"] = {
            "script_sha256": SCRIPT_SHA256, "vocabulary_sha256": vocabulary_digest(),
            "rules": list(rules), "source_store": source, "source_mentions": len(rows),
            "removed_by_rule": volume_removed,
            "removed_spans_editors_marked_as_person_by_rule": volume_editor if marked_available else None,
            "examples_by_rule": volume_examples,
        }
        with open(os.path.join(out_detected, volume + ".head.json"), "w") as handle:
            json.dump(new_head, handle, indent=1, sort_keys=True, ensure_ascii=False)

        source_total += len(rows)
        kept_total += len(kept)
        for rule in rules:
            removed[rule] += volume_removed[rule]
            editor_marked[rule] += volume_editor[rule]
            for surface in volume_examples[rule]:
                if len(examples[rule]) < 20 and surface not in examples[rule]:
                    examples[rule].append(surface)
        if not quiet:
            print("[%d/%d] %-22s %7d -> %7d  %s" % (
                index, len(heads), volume, len(rows), len(kept),
                "  ".join("%s %d" % (rule, volume_removed[rule]) for rule in rules)))
            sys.stdout.flush()

    source_manifest = os.path.join(source, "run-manifest.json")
    manifest = {
        "generated": generated or datetime.date.today().isoformat(),
        "tool": "filter_detections.py", "script_sha256": SCRIPT_SHA256,
        "vocabulary_sha256": vocabulary_digest(), "rules": list(rules),
        "frozen_before_ground_truth": "2026-09-12, with the M2a sample un-keyed",
        "source_store": source,
        "source_run_manifest_sha256": sha256_file(source_manifest) if os.path.exists(source_manifest) else None,
        "text_dir": text_dir, "marked_store": marked_store if marked_available else None,
        "gazetteer": {"entries": len(gazetteer), "sources": [
            {"path": taxonomy, "sha256": sha256_file(taxonomy)},
            {"path": decimal_labels, "sha256": sha256_file(decimal_labels)}]} if "place" in rules else None,
        "totals": {
            "volumes": len(heads), "source_mentions": source_total, "kept": kept_total,
            "removed": source_total - kept_total, "removed_by_rule": removed,
            "removed_spans_editors_marked_as_person_by_rule": editor_marked if marked_available else None,
            "examples_by_rule": examples,
        },
    }
    with open(os.path.join(out, "run-manifest.json"), "w") as handle:
        json.dump(manifest, handle, indent=2, sort_keys=True, ensure_ascii=False)
    if not quiet:
        print("\n%d volumes: %d -> %d mentions (removed %d)" % (len(heads), source_total, kept_total,
                                                               source_total - kept_total))
        for rule in rules:
            print("  %-12s %9d removed   %7s of them marked as a person by the editors"
                  % (rule, removed[rule], editor_marked[rule] if marked_available else "n/a"))
    return manifest


SCRIPT_SHA256 = sha256_file(os.path.abspath(__file__))


# --------------------------------------------------------------------------------------------------
# Self-test

CHECKS = []


def check(label, condition, detail=""):
    CHECKS.append((label, bool(condition), detail))
    print(("  ok   " if condition else "  FAIL ") + label + ("" if condition else "  -- %s" % (detail,)))


def _raises(thunk):
    """True when `thunk` refuses with SystemExit — and ONLY SystemExit, so a NameError is a failure."""
    try:
        thunk()
    except SystemExit:
        return True
    return False


def selftest():
    import shutil
    import tempfile

    root = tempfile.mkdtemp(prefix="filter-detections-")
    text = ("Mr. Bevin told the Secretary of State that he saw Japanese ships near France and "
            "Washington; the Department of State agreed. General Marshall met Colonel House in VIII.")

    def span(needle, after=0):
        start = text.index(needle, after)
        return start, start + len(needle)

    text_dir = os.path.join(root, "text")
    os.makedirs(text_dir)
    write_rows(os.path.join(text_dir, "volA.jsonl.gz"), [{"d": "d1", "t": text}], gz=True)

    marked_store = os.path.join(root, "marked-store")
    os.makedirs(os.path.join(marked_store, "marked"))
    bevin = span("Bevin")
    washington = span("Washington")
    write_rows(os.path.join(marked_store, "marked", "volA.jsonl.gz"),
               [{"d": "d1", "o": 0, "s": bevin[0], "e": bevin[1], "n": "Bevin"},
                {"d": "d1", "o": 0, "s": washington[0], "e": washington[1], "n": "Washington"}], gz=True)

    taxonomy = os.path.join(root, "taxonomy.json")
    json.dump([{"category": "places", "displayName": "France", "slug": "france"}], open(taxonomy, "w"))
    decimal = os.path.join(root, "decimal.json")
    json.dump({"schedules": [{"countries": {"27": "Congo, Republic of"},
                              "countryAlternates": {"27": ["Belgian Congo", {"odd": "shape"}]}}]},
              open(decimal, "w"))

    the = text.index("the Secretary")
    he_inside_the = (the + 1, the + 3)
    japan = span("Japan")
    pronoun_he = (text.index(" he ") + 1, text.index(" he ") + 3)

    def row(bounds, ci=True):
        entry = {"d": "d1", "o": 0, "s": bounds[0], "e": bounds[1], "n": text[bounds[0]:bounds[1]]}
        if ci:
            entry["ci"] = 0
        return entry

    # `and` is a bare function word: no rule's category covers it, so it is KEPT. It is here to prove
    # the institution rule needs an institution word — without that conjunct it would claim `and`.
    bare_and = (text.index(" and ") + 1, text.index(" and ") + 4)
    fixture = [span("Mr. Bevin"), span("General Marshall"), span("Colonel House"),
               span("Marshall"), bare_and, he_inside_the, japan, pronoun_he,
               span("the Secretary of State"), span("the Department of State"), span("France"),
               washington, span("VIII")]

    def detector(name, rows, head, gz=True):
        directory = os.path.join(root, name, "detected")
        os.makedirs(directory)
        if rows is not None:
            write_rows(os.path.join(directory, "volA" + (".jsonl.gz" if gz else ".jsonl")), rows, gz)
        if head is not None:
            json.dump(head, open(os.path.join(directory, "volA.head.json"), "w"))
        return os.path.join(root, name)

    llm = detector("llm", [row(b) for b in fixture], {"volume": "volA", "sampled": False, "mentions": 13})

    def filtered(out, rules=ALL_RULES, source=llm, force=False):
        return run(source, os.path.join(root, out), text_dir, marked_store, rules, taxonomy, decimal,
                   force=force, generated="2026-09-12", quiet=True)

    manifest = filtered("out")
    out_rows = store.read_jsonl_gz(os.path.join(root, "out", "detected", "volA.jsonl.gz"))
    check("keeps the four person spans, and a bare function word no rule's category covers",
          sorted(r["n"] for r in out_rows)
          == sorted(["Mr. Bevin", "General Marshall", "Colonel House", "Marshall", "and"]),
          sorted(r["n"] for r in out_rows))
    expected = {"boundary": 2, "pronoun": 1, "title": 1, "institution": 1, "place": 1, "curated": 2}
    check("attributes every removal to the first rule that claims it",
          manifest["totals"]["removed_by_rule"] == expected, manifest["totals"]["removed_by_rule"])
    check("`he` inside `the` and `Japan` inside `Japanese` are boundary removals, not pronoun or place",
          manifest["totals"]["removed_by_rule"]["boundary"] == 2)
    check("counts a removal the editors had marked as a person, against the rule that made it",
          manifest["totals"]["removed_spans_editors_marked_as_person_by_rule"]["curated"] == 1
          and sum(manifest["totals"]["removed_spans_editors_marked_as_person_by_rule"].values()) == 1,
          manifest["totals"]["removed_spans_editors_marked_as_person_by_rule"])
    head = json.load(open(os.path.join(root, "out", "detected", "volA.head.json")))
    check("preserves `sampled` so the scorer accepts the store", head.get("sampled") is False, head)
    check("records the script and vocabulary hashes in every head",
          head["filter"]["script_sha256"] == SCRIPT_SHA256 and len(head["filter"]["vocabulary_sha256"]) == 64)

    first = sha256_file(os.path.join(root, "out", "detected", "volA.jsonl.gz"))
    filtered("out", force=True)
    check("a re-run is byte-identical (gzip mtime=0)",
          sha256_file(os.path.join(root, "out", "detected", "volA.jsonl.gz")) == first)

    boundary_only = filtered("out-boundary", rules=("boundary",))
    check("RULES=boundary removes only the two in-word spans",
          boundary_only["totals"]["removed"] == 2 and boundary_only["totals"]["kept"] == 11,
          boundary_only["totals"])

    control = detector("control", [row(span("Mr. Bevin"), ci=False), row(span("France"), ci=False)],
                       {"volume": "volA", "sampled": False, "mentions": 2}, gz=False)
    filtered("out-control", source=control)
    check("a plain .jsonl source stays plain — the Swift control never reads gzip",
          os.path.exists(os.path.join(root, "out-control", "detected", "volA.jsonl"))
          and not os.path.exists(os.path.join(root, "out-control", "detected", "volA.jsonl.gz")))

    sampled = detector("sampled", [row(span("Mr. Bevin"))],
                       {"volume": "volA", "sampled": True, "sampled_doc_ids": ["d1"]})
    filtered("out-sampled", source=sampled)
    sampled_head = json.load(open(os.path.join(root, "out-sampled", "detected", "volA.head.json")))
    check("preserves sampled_doc_ids — a sample without them is refused by the scorer",
          sampled_head.get("sampled") is True and sampled_head.get("sampled_doc_ids") == ["d1"], sampled_head)

    def claimed(surface):
        return rule_for(surface, surface, 0, len(surface), ALL_RULES, set())
    people = ["Admiral King", "General Pope", "Prime Minister King", "Mr. Lord", "General Sultan", "M. Baron"]
    check("spares a title noun used as a surname after a rank or honorific",
          all(claimed(p) is None for p in people), {p: claimed(p) for p in people})
    # `my Lord Duke` is a form of address, and the only fixture that proves `lord` is not a rank: after
    # `Lord Chancellor` the noun is not surname-capable, so that one cannot tell.
    offices = ["the King", "his Majesty the King", "Mr. Secretary", "Lord Chancellor", "Consul General",
               "the lord chief baron", "Honorable Sir", "King", "my Lord Duke"]
    check("still removes the same nouns as titles: after an article, after `lord`/`chief`, or alone",
          all(claimed(o) == "title" for o in offices), {o: claimed(o) for o in offices})

    gazetteer = load_gazetteer(taxonomy, decimal)
    check("gazetteer reads an inverted name both ways, keeps its head, and takes string alternates",
          {"congo, republic of", "republic of congo", "congo", "belgian congo", "france"} <= gazetteer,
          sorted(gazetteer))

    # With FORCE, on a store of its own: without FORCE the "already holds volumes" guard refuses too,
    # which is how this check first passed with the same-path guard deleted.
    selfsame = detector("selfsame", [row(span("Mr. Bevin"))], {"volume": "volA", "sampled": False})
    check("refuses to write over its own source even with FORCE", _raises(lambda: run(
        selfsame, selfsame, text_dir, marked_store, ALL_RULES, taxonomy, decimal, force=True, quiet=True)))
    check("refuses an output that already holds volumes without FORCE", _raises(lambda: filtered("out")))
    check("refuses an unknown rule", _raises(lambda: filtered("out-bad", rules=("nonsense",))))
    headless = detector("headless", [row(span("Mr. Bevin"))], None)
    check("refuses a body with no head (a killed run)", _raises(lambda: filtered("out-headless", source=headless)))
    corrupt = [row(span("Mr. Bevin"))]
    corrupt[0]["n"] = "Mr. Bevan"
    moved = detector("moved", corrupt, {"volume": "volA", "sampled": False})
    check("refuses a span that no longer slices its own surface out of the R-0 text",
          _raises(lambda: filtered("out-moved", source=moved)))

    saved = os.environ.pop("SELFTEST", None)
    try:
        import score_detections
    finally:
        if saved is not None:
            os.environ["SELFTEST"] = saved
    out_store = os.path.join(root, "out")
    check("the real scorer reads the filtered head as a full, unsampled pass",
          score_detections.scanned_documents(out_store, "volA", {"d1"}) == {"d1"})
    predictions, refused = score_detections.collect_predictions(
        out_store, "detected", {("volA", "d1"): [(0, 1, "x")]}, False)
    check("the real scorer collects the filtered spans with no refusal",
          refused == [] and len(predictions.get(("volA", "d1"), [])) == 5, (refused, predictions))

    shutil.rmtree(root, ignore_errors=True)
    failed = [label for label, ok, _ in CHECKS if not ok]
    print("\n%d checks, %d failed" % (len(CHECKS), len(failed)))
    if failed:
        print("FAILED: " + "; ".join(failed))
        sys.exit(1)
    print("SELFTEST PASSED")


def main():
    if os.environ.get("SELFTEST"):
        selftest()
        return
    requested = os.environ.get("RULES", "all").strip()
    rules = ALL_RULES if requested == "all" else tuple(r.strip() for r in requested.split(",") if r.strip())
    run(os.environ.get("SOURCE", ""), os.environ.get("OUT_DIR", ""),
        os.path.expanduser(os.environ.get("TEXT_DIR", "~/frus-semantic-raw/text")),
        os.path.expanduser(os.environ.get("MARKED_STORE", "~/frus-ner-raw")), rules,
        os.environ.get("TAXONOMY", os.path.join(REPO, "FRUSExplorer/Resources/volume-tag-taxonomy.json")),
        os.environ.get("DECIMAL_LABELS", os.path.join(REPO, "FRUSExplorer/Resources/decimal-class-labels.json")),
        force=bool(os.environ.get("FORCE")), generated=os.environ.get("GENERATED_DATE"))


if __name__ == "__main__":
    main()
