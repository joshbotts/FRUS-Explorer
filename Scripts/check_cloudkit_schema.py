#!/usr/bin/env python3
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
"""The CloudKit Production schema gate (#1531): run it before every archive.

WHAT IT CHECKS. Every identifier this build mirrors into CloudKit is listed, by
`CloudKitSchemaInventoryTests`'s own derivation, in
`FRUSExplorer/Models/CloudKitSchemaInventory.swift` (`installedIdentifiers`). This script exports
the CloudKit container's PRODUCTION schema with `xcrun cktool export-schema` and fails when
Production lacks any of them that a record can carry. That is the one step of the schema-deploy
checklist that used to be an attestation nobody could check: in #1531 the inventory recorded
`CD_GeneratedSummary.CD_sourceContentHash` as deployed on 2026-09-03, Production did not have it,
and from build 45 every summary of an indexed document stopped sync on the device that made it —
in both directions, on every launch — until the owner deployed it on 2026-09-28.

WHAT IT DOES NOT REQUIRE of Production:
  - `identifiersAwaitingWriter`: nothing in the build writes them, so CloudKit cannot have them
    and no record can carry one.
  - `identifiersNotStoredAsFields`: the to-many side of a relationship, which CloudKit stores on
    the to-one side only.
`identifiersAwaitingDeploy` IS required: an archive must not ship while one is missing. When every
one of them is in Production, the script says so, and the list can be cleared.
Identifiers Production holds that the inventory does not (retired record types, which Production
keeps forever because its schema is append-only, CloudKit's system fields, `CD_entityName`) are
counted, never failed.

IT NEEDS A CLOUDKIT MANAGEMENT TOKEN saved on this Mac. Without one it fails, saying so:
    1. CloudKit Console (icloud.developer.apple.com) > Settings > Tokens > Management Tokens:
       create one.
    2. xcrun cktool save-token --type management    (paste the token at the prompt)
It reads the schema only; it never imports, resets or writes anything.

USAGE
    Scripts/check_cloudkit_schema.py                      export Production and compare
    Scripts/check_cloudkit_schema.py --schema-file F      compare an already-exported schema
    Scripts/check_cloudkit_schema.py --self-test          the parser and rules, no network

    Env: TEAM_ID (default: DEVELOPMENT_TEAM in project.yml), CONTAINER_ID (default
    iCloud.bottsywattsy.FRUS-Explorer), ENVIRONMENT (default production).

EXIT STATUS
    0  Production holds every required identifier.
    1  It does not; the missing ones are listed.
    2  The check could not run: no management token, cktool failed, or the inventory or schema
       could not be read. A gate that could not look is not a pass.

Stdlib only, for macOS's bundled python3.
"""

import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INVENTORY = os.path.join(ROOT, "FRUSExplorer", "Models", "CloudKitSchemaInventory.swift")
PROJECT_YML = os.path.join(ROOT, "project.yml")
DEFAULT_CONTAINER = "iCloud.bottsywattsy.FRUS-Explorer"

# The lists read out of the inventory. Each is a `static let <name>: [String] = [ ... ]`.
LISTS = (
    "installedIdentifiers",
    "identifiersAwaitingDeploy",
    "identifiersAwaitingWriter",
    "identifiersNotStoredAsFields",
)

# What cktool prints when no management token is saved (measured 2026-10-01, Xcode 27.0):
# "Error: No management token found in arguments, CLOUDKIT_MANAGEMENT_TOKEN environment variable,
# or built-in methods. (See: save-token)", with exit status 64.
NO_TOKEN_CUE = "No management token found"


class GateError(Exception):
    """The check could not run (exit 2)."""


# --------------------------------------------------------------------------------------------
# Reading the inventory
# --------------------------------------------------------------------------------------------

def strip_swift_comments(text):
    """Drops `//` line comments that are not inside a string literal on that line."""
    out = []
    for line in text.split("\n"):
        in_string = False
        cut = len(line)
        i = 0
        while i < len(line):
            ch = line[i]
            if ch == "\\" and in_string:
                i += 2
                continue
            if ch == '"':
                in_string = not in_string
            elif not in_string and line.startswith("//", i):
                cut = i
                break
            i += 1
        out.append(line[:cut])
    return "\n".join(out)


def read_inventory(text):
    """The four identifier lists, by name, from the inventory's Swift source."""
    code = strip_swift_comments(text)
    lists = {}
    for name in LISTS:
        match = re.search(r"static\s+let\s+" + name + r"\s*:\s*\[String\]\s*=\s*\[(.*?)\]", code,
                          re.S)
        if not match:
            raise GateError(f"{INVENTORY}: no `static let {name}: [String] = [...]` found")
        lists[name] = re.findall(r'"([^"\\]*)"', match.group(1))
    if len(lists["installedIdentifiers"]) < 100:
        raise GateError(f"{INVENTORY}: installedIdentifiers read as "
                        f"{len(lists['installedIdentifiers'])} entries; the parse is broken")
    return lists


def required_identifiers(lists):
    """What Production must hold: installed, less the writer-less and the to-many sides."""
    exempt = set(lists["identifiersAwaitingWriter"]) | set(lists["identifiersNotStoredAsFields"])
    return [i for i in lists["installedIdentifiers"] if i not in exempt]


# --------------------------------------------------------------------------------------------
# Reading an exported schema (CloudKit's text schema language, .ckdb)
# --------------------------------------------------------------------------------------------

def strip_ckdb_comments(text):
    """Drops `//` and `--` comments outside double quotes."""
    out = []
    for line in text.split("\n"):
        in_string = False
        cut = len(line)
        for i, ch in enumerate(line):
            if ch == '"':
                in_string = not in_string
            elif not in_string and (line.startswith("//", i) or line.startswith("--", i)):
                cut = i
                break
        out.append(line[:cut])
    return "\n".join(out)


def split_top_level(body):
    """Splits a record type's body on commas outside quotes and angle brackets."""
    parts, depth, in_string, current = [], 0, False, []
    for ch in body:
        if ch == '"':
            in_string = not in_string
        elif not in_string and ch == "<":
            depth += 1
        elif not in_string and ch == ">":
            depth -= 1
        elif not in_string and depth == 0 and ch == ",":
            parts.append("".join(current))
            current = []
            continue
        current.append(ch)
    parts.append("".join(current))
    return [p.strip() for p in parts if p.strip()]


def parse_schema(text):
    """The identifiers an exported schema holds: `CD_X` per record type, `CD_X.f` per field.

    System fields (`___createTime`, …) and GRANT clauses are not fields of the app's schema and
    are skipped. Raises GateError when the text names no record type at all, because a gate that
    read an empty or unrecognised file must not report that everything is missing — or present.
    """
    code = strip_ckdb_comments(text)
    identifiers = set()
    types = 0
    for match in re.finditer(r'RECORD\s+TYPE\s+"?([A-Za-z0-9_]+)"?\s*\(', code):
        record_type = match.group(1)
        types += 1
        identifiers.add(record_type)
        # The body runs to the parenthesis that closes this one.
        depth, i = 1, match.end()
        in_string = False
        while i < len(code) and depth:
            ch = code[i]
            if ch == '"':
                in_string = not in_string
            elif not in_string and ch == "(":
                depth += 1
            elif not in_string and ch == ")":
                depth -= 1
            i += 1
        body = code[match.end():i - 1]
        for element in split_top_level(body):
            if re.match(r"GRANT\b", element, re.I):
                continue
            name_match = re.match(r'"?([A-Za-z0-9_]+)"?', element)
            if not name_match:
                continue
            name = name_match.group(1)
            if name.startswith("___"):
                continue
            identifiers.add(f"{record_type}.{name}")
    if types == 0:
        raise GateError("the exported schema names no RECORD TYPE; is it a CloudKit schema file?")
    return identifiers


# --------------------------------------------------------------------------------------------
# The comparison
# --------------------------------------------------------------------------------------------

def compare(lists, production):
    """The verdict as data: (passed, report lines)."""
    required = required_identifiers(lists)
    awaiting = set(lists["identifiersAwaitingDeploy"])
    missing = [i for i in required if i not in production]
    missing_attested = [i for i in missing if i not in awaiting]
    missing_awaiting = [i for i in missing if i in awaiting]
    awaiting_present = sorted(i for i in awaiting if i in production)
    inventory = set(lists["installedIdentifiers"])
    extra = sorted(i for i in production if i not in inventory)
    lines = [
        f"inventory: {len(lists['installedIdentifiers'])} identifiers; "
        f"{len(required)} required of Production "
        f"({len(lists['identifiersAwaitingWriter'])} awaiting a writer and "
        f"{len(lists['identifiersNotStoredAsFields'])} to-many relationship sides not required)",
        f"production: {len(production)} identifiers; {len(extra)} not in the inventory "
        "(retired types, system and bookkeeping fields: reported, never failed)",
    ]
    for name in lists["identifiersNotStoredAsFields"]:
        state = "present" if name in production else "absent, as expected"
        lines.append(f"  to-many side {name}: {state}")
    if missing_attested:
        lines.append("")
        lines.append(f"FAIL: {len(missing_attested)} identifier(s) the inventory attests as "
                     "deployed are NOT in Production (#1531's shape; a record carrying one "
                     "stops sync on the device that wrote it):")
        lines += [f"  {i}" for i in missing_attested]
    if missing_awaiting:
        lines.append("")
        lines.append(f"FAIL: {len(missing_awaiting)} identifier(s) awaiting deploy are not in "
                     "Production yet. Exercise each on a Development build, then CloudKit "
                     "Console > Schema > Deploy Schema Changes to Production:")
        lines += [f"  {i}" for i in missing_awaiting]
    if awaiting_present and not missing_awaiting:
        lines.append("")
        lines.append("Every identifier in identifiersAwaitingDeploy is in Production: clear the "
                     "list and follow CloudKitSchemaInventoryTests' checklist.")
    passed = not missing
    lines.append("")
    lines.append("PASS: Production holds every identifier this build can write."
                 if passed else "The archive must not ship until Production holds them.")
    return passed, lines


# --------------------------------------------------------------------------------------------
# Talking to cktool
# --------------------------------------------------------------------------------------------

def team_id():
    """TEAM_ID from the environment, else DEVELOPMENT_TEAM from project.yml."""
    if os.environ.get("TEAM_ID"):
        return os.environ["TEAM_ID"]
    with open(PROJECT_YML, encoding="utf-8") as handle:
        match = re.search(r"^\s*DEVELOPMENT_TEAM:\s*([A-Z0-9]{10})\s*$", handle.read(), re.M)
    if not match:
        raise GateError("no TEAM_ID in the environment and no DEVELOPMENT_TEAM in project.yml")
    return match.group(1)


def classify_cktool_failure(status, stderr):
    """The message for a failed cktool run."""
    if NO_TOKEN_CUE in stderr:
        return ("no CloudKit management token is saved on this Mac, so Production's schema "
                "cannot be read.\n"
                "  1. CloudKit Console (icloud.developer.apple.com) > Settings > Tokens > "
                "Management Tokens: create one.\n"
                "  2. xcrun cktool save-token --type management   (paste it at the prompt)\n"
                "Then run this again. Do not archive until it passes.")
    return f"xcrun cktool export-schema failed (exit {status}):\n{stderr.strip()}"


def export_production_schema():
    """Production's schema text, from cktool."""
    environment = os.environ.get("ENVIRONMENT", "production")
    container = os.environ.get("CONTAINER_ID", DEFAULT_CONTAINER)
    with tempfile.TemporaryDirectory() as scratch:
        out = os.path.join(scratch, "schema.ckdb")
        command = ["xcrun", "cktool", "export-schema", "--team-id", team_id(),
                   "--container-id", container, "--environment", environment,
                   "--output-file", out]
        try:
            result = subprocess.run(command, stdin=subprocess.DEVNULL, capture_output=True,
                                    text=True, timeout=180)
        except (OSError, subprocess.TimeoutExpired) as error:
            raise GateError(f"could not run xcrun cktool: {error}")
        if result.returncode != 0:
            raise GateError(classify_cktool_failure(result.returncode,
                                                    result.stderr + result.stdout))
        if not os.path.exists(out):
            raise GateError("cktool exited 0 but wrote no schema file")
        with open(out, encoding="utf-8") as handle:
            return handle.read()


# --------------------------------------------------------------------------------------------
# Self-test
# --------------------------------------------------------------------------------------------

def self_test():
    """The rules against the repository's real inventory and synthesised schemas."""
    failures = []

    def check(name, condition):
        print(("ok   " if condition else "FAIL ") + name)
        if not condition:
            failures.append(name)

    with open(INVENTORY, encoding="utf-8") as handle:
        source_text = handle.read()
    lists = read_inventory(source_text)
    installed = lists["installedIdentifiers"]
    check("the inventory reads more than 200 identifiers", len(installed) > 200)
    check("the inventory holds #1531's field",
          "CD_GeneratedSummary.CD_sourceContentHash" in installed)
    check("the to-many list is read", len(lists["identifiersNotStoredAsFields"]) >= 1)
    commented = read_inventory(text_with_commented_entry(source_text))
    check("a commented-out entry is not read", commented["installedIdentifiers"] == installed)

    required = required_identifiers(lists)
    check("writer-less and to-many identifiers are not required",
          not (set(lists["identifiersAwaitingWriter"])
               | set(lists["identifiersNotStoredAsFields"])) & set(required))

    full = render_schema(required + ["CD_ResearchSession", "CD_ResearchSession.CD_title"])
    production = parse_schema(full)
    check("a rendered schema parses back to every required identifier",
          set(required) <= production)
    check("system fields are not identifiers",
          not any(i.split(".")[-1].startswith("___") for i in production))
    passed, _ = compare(lists, production)
    check("a Production schema holding every required identifier passes", passed)

    without = render_schema([i for i in required
                             if i != "CD_GeneratedSummary.CD_sourceContentHash"])
    passed, report = compare(lists, parse_schema(without))
    check("#1531's schema — the field missing — fails", not passed)
    check("the failure names the field",
          any("CD_GeneratedSummary.CD_sourceContentHash" in line for line in report))
    check("the failure calls it attested, not awaiting",
          any("attests as deployed" in line for line in report))

    awaiting_lists = dict(lists)
    awaiting_lists["identifiersAwaitingDeploy"] = ["CD_GeneratedSummary.CD_sourceContentHash"]
    passed, report = compare(awaiting_lists, parse_schema(without))
    check("a missing identifier awaiting deploy fails too", not passed)
    check("and is reported as awaiting deploy",
          any("awaiting deploy are not in Production" in line for line in report))

    missing_type = render_schema([i for i in required if not i.startswith("CD_WorkingCorpus")])
    passed, report = compare(lists, parse_schema(missing_type))
    check("a missing record type fails", not passed and any("  CD_WorkingCorpus" == line
                                                            for line in report))

    try:
        parse_schema("DEFINE SCHEMA\n")
        check("a schema naming no record type is refused", False)
    except GateError:
        check("a schema naming no record type is refused", True)

    commented = "DEFINE SCHEMA\n// RECORD TYPE CD_Ghost ( CD_x STRING );\n" + full
    check("a commented-out record type is not read",
          "CD_Ghost" not in parse_schema(commented))

    message = classify_cktool_failure(
        64, "Error: No management token found in arguments, CLOUDKIT_MANAGEMENT_TOKEN environment "
            "variable, or built-in methods. (See: save-token)")
    check("no saved token is named as such, with the fix", "save-token --type management" in message)
    check("any other cktool failure carries cktool's own words",
          "boom" in classify_cktool_failure(1, "boom"))

    print()
    print("self-test: " + ("PASS" if not failures else f"{len(failures)} FAILED"))
    return 0 if not failures else 1


def text_with_commented_entry(source_text):
    """The inventory source with a commented-out extra entry inside installedIdentifiers."""
    return source_text.replace(
        "static let installedIdentifiers: [String] = [",
        'static let installedIdentifiers: [String] = [\n        // "CD_Ghost.CD_field",', 1)


def render_schema(identifiers):
    """A .ckdb text holding exactly `identifiers`, shaped as cktool writes one."""
    types = {}
    for identifier in identifiers:
        record_type, _, field = identifier.partition(".")
        types.setdefault(record_type, [])
        if field:
            types[record_type].append(field)
    blocks = []
    for record_type in sorted(types):
        lines = ['        "___createTime" TIMESTAMP', '        "___recordID" REFERENCE QUERYABLE']
        lines += [f"        {field} STRING QUERYABLE" for field in sorted(types[record_type])]
        lines += ['        GRANT WRITE TO "_creator"', '        GRANT READ TO "_world"']
        blocks.append(f"    RECORD TYPE {record_type} (\n" + ",\n".join(lines) + "\n    );")
    return "DEFINE SCHEMA\n\n" + "\n\n".join(blocks) + "\n"


# --------------------------------------------------------------------------------------------

def main(argv):
    if "--self-test" in argv:
        return self_test()
    try:
        with open(INVENTORY, encoding="utf-8") as handle:
            lists = read_inventory(handle.read())
        if "--schema-file" in argv:
            index = argv.index("--schema-file")
            if index + 1 >= len(argv):
                raise GateError("--schema-file needs a path")
            with open(argv[index + 1], encoding="utf-8") as handle:
                schema_text = handle.read()
            source = argv[index + 1]
        else:
            schema_text = export_production_schema()
            source = "cktool export-schema (" + os.environ.get("ENVIRONMENT", "production") + ")"
        production = parse_schema(schema_text)
    except GateError as error:
        print(f"check_cloudkit_schema: CANNOT CHECK — {error}", file=sys.stderr)
        return 2
    except OSError as error:
        print(f"check_cloudkit_schema: CANNOT CHECK — {error}", file=sys.stderr)
        return 2
    print(f"CloudKit schema gate — {source}")
    passed, lines = compare(lists, production)
    print("\n".join(lines))
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
