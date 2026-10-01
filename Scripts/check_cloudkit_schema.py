#!/usr/bin/env python3
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
"""The CloudKit Production schema gate (#1531): every archive needs it to have passed.

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
It reads the schema only; it never imports, resets or writes anything in CloudKit.

EVERY ARCHIVE CHECKS IT, NOT ONLY THE DMG. A live read of Production writes what Production holds
to STAMP (`.cache/cloudkit-schema-gate/production-schema.txt`, gitignored, per checkout). The
archive-only build phase "Check CloudKit schema", first on both app targets in project.yml, runs
this script with `--archive-phase`, which compares the inventory being archived with that file and
FAILS THE ARCHIVE when it is missing or does not hold every required identifier. So a TestFlight or
App Store archive made in Xcode is gated as `notarize.sh`'s DMG is (it runs the live check first),
and an identifier added to the inventory since the last read fails the archive until this script
is run again. The phase knows Production only through that file: it runs under
ENABLE_USER_SCRIPT_SANDBOXING, which grants the three files it declares (this script, the inventory
and STAMP) and nothing else, so it cannot reach the keychain token or the network.
The file cannot go stale in the direction that matters, because Production's schema is
append-only: whatever it held when the file was written, it holds still.

USAGE
    Scripts/check_cloudkit_schema.py                      export Production, compare, write STAMP
    Scripts/check_cloudkit_schema.py --schema-file F      compare an already-exported schema
                                                          (writes no STAMP: a file proves nothing
                                                          about where it came from)
    Scripts/check_cloudkit_schema.py --archive-phase      the build phase: compare with STAMP
    Scripts/check_cloudkit_schema.py --self-test          the parser and rules, no network

    Env: TEAM_ID (default: DEVELOPMENT_TEAM in project.yml), CONTAINER_ID (default
    iCloud.bottsywattsy.FRUS-Explorer), ENVIRONMENT (default production). A read of any other
    container or environment writes no STAMP.

EXIT STATUS
    0  Production holds every required identifier. (--archive-phase: STAMP shows it does, or this
       is not an archive.)
    1  It does not; the missing ones are listed. (--archive-phase: also when STAMP is missing or
       unreadable — the archive fails either way.)
    2  The check could not run: no management token, cktool failed, or the inventory or schema
       could not be read. A gate that could not look is not a pass.

Stdlib only, for macOS's bundled python3.
"""

import contextlib
import datetime
import io
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INVENTORY = os.path.join(ROOT, "FRUSExplorer", "Models", "CloudKitSchemaInventory.swift")
PROJECT_YML = os.path.join(ROOT, "project.yml")
DEFAULT_CONTAINER = "iCloud.bottsywattsy.FRUS-Explorer"
# What the last live read of Production held — see "EVERY ARCHIVE CHECKS IT" above. The archive
# phase declares this exact path as an input in project.yml; move it in both places or neither.
STAMP = os.path.join(ROOT, ".cache", "cloudkit-schema-gate", "production-schema.txt")

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
# The stamp: what the last live read of Production held, for the archive phase
# --------------------------------------------------------------------------------------------

def write_stamp(identifiers, container, environment, path=STAMP, now=None):
    """Writes what a live read of `container`'s `environment` held. Only Production of the app's
    own container is written: any other read says nothing about what an archive will meet."""
    if environment != "production" or container != DEFAULT_CONTAINER:
        return False
    read_at = (now or datetime.datetime.now(datetime.timezone.utc)).strftime("%Y-%m-%dT%H:%M:%SZ")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    lines = [
        "# CloudKit Production schema identifiers, written by Scripts/check_cloudkit_schema.py.",
        "# Every archive checks the inventory it builds against this file. Do not edit it: run",
        "# the script again.",
        f"# container: {container}",
        f"# environment: {environment}",
        f"# read: {read_at}",
    ] + sorted(identifiers)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines) + "\n")
    return True


def read_stamp(path=STAMP):
    """(identifiers, read-at) from the stamp. Raises GateError when it is missing, unreadable or
    not a read of the app's Production container."""
    if not os.path.exists(path):
        raise GateError(f"no live read of Production has been recorded on this Mac ({path} is "
                        "missing)")
    try:
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
    except OSError as error:
        raise GateError(f"cannot read {path} ({error}). It exists, so this is the script "
                        "sandbox: declare it under the phase's inputFiles in project.yml")
    header, identifiers = {}, set()
    for line in text.split("\n"):
        line = line.strip()
        if line.startswith("#"):
            key, sep, value = line[1:].partition(":")
            if sep:
                header[key.strip()] = value.strip()
        elif line:
            identifiers.add(line)
    if header.get("container") != DEFAULT_CONTAINER or header.get("environment") != "production":
        raise GateError(f"{path} is not a read of {DEFAULT_CONTAINER}'s Production schema")
    if not identifiers:
        raise GateError(f"{path} names no identifier")
    return identifiers, header.get("read", "an unrecorded time")


def archive_verdict(lists, stamp_path=STAMP):
    """The archive phase's verdict as data: (passed, lines). Every failing line is an Xcode
    `error:` line, so the archive's issue list names the cause and the command that clears it."""
    remedy = ("error: Run  ./Scripts/check_cloudkit_schema.py  (it needs a CloudKit management "
              "token), deploy anything it lists, then archive again.")
    try:
        held, read_at = read_stamp(stamp_path)
    except GateError as error:
        # A sandbox refusal is fixed in project.yml, not by reading Production again.
        sandboxed = "script sandbox" in str(error)
        return False, [f"error: CloudKit schema gate: {error}."] + ([] if sandboxed else [remedy])
    passed, report = compare(lists, held)
    if passed:
        return True, [f"CloudKit schema gate: Production, as read {read_at}, holds every "
                      "identifier this build can write."]
    missing = [line.strip() for line in report if line.startswith("  CD_")]
    return False, ([f"error: CloudKit schema gate: Production, as read {read_at}, does not hold "
                    f"{len(missing)} identifier(s) this build can write (#1531):"]
                   + [f"error:   {name}" for name in missing] + [remedy])


def archive_phase(stamp_path=STAMP):
    """The archive-only build phase: compare the inventory with STAMP. Not an archive: exit 0."""
    if os.environ.get("ACTION", "build") != "install":
        return 0
    try:
        with open(INVENTORY, encoding="utf-8") as handle:
            lists = read_inventory(handle.read())
    except (GateError, OSError) as error:
        print(f"error: CloudKit schema gate: {error}", file=sys.stderr)
        return 1
    passed, lines = archive_verdict(lists, stamp_path)
    print("\n".join(lines), file=sys.stdout if passed else sys.stderr)
    return 0 if passed else 1


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

    with tempfile.TemporaryDirectory() as scratch:
        stamp = os.path.join(scratch, "gate", "production-schema.txt")
        passed, lines = archive_verdict(lists, stamp)
        check("an archive with no recorded read of Production fails",
              not passed and any("is missing" in line for line in lines))
        check("and says how to record one", any("check_cloudkit_schema.py" in line
                                                for line in lines))
        check("a Development read writes no stamp",
              not write_stamp(production, DEFAULT_CONTAINER, "development", stamp)
              and not os.path.exists(stamp))
        check("another container's read writes no stamp",
              not write_stamp(production, "iCloud.example.other", "production", stamp)
              and not os.path.exists(stamp))
        check("a Production read writes the stamp",
              write_stamp(production, DEFAULT_CONTAINER, "production", stamp))
        held, _ = read_stamp(stamp)
        check("the stamp reads back exactly what Production held", held == production)
        passed, lines = archive_verdict(lists, stamp)
        check("an archive whose identifiers the stamp holds passes", passed)
        check("and no line of a pass is an Xcode error", not any(line.startswith("error:")
                                                                  for line in lines))

        write_stamp(parse_schema(without), DEFAULT_CONTAINER, "production", stamp)
        passed, lines = archive_verdict(lists, stamp)
        check("#1531's archive — the field missing from the stamp — fails", not passed)
        check("its failure names the field as an Xcode error",
              "error:   CD_GeneratedSummary.CD_sourceContentHash" in lines)

        added = dict(lists)
        added["installedIdentifiers"] = lists["installedIdentifiers"] + ["CD_Ghost.CD_field"]
        write_stamp(production, DEFAULT_CONTAINER, "production", stamp)
        passed, lines = archive_verdict(added, stamp)
        check("an identifier added since the last read fails the archive",
              not passed and "error:   CD_Ghost.CD_field" in lines)

        # Every identifier Production holds, but read from Development: refused for its header.
        with open(stamp, "w", encoding="utf-8") as handle:
            handle.write(f"# container: {DEFAULT_CONTAINER}\n# environment: development\n"
                         + "\n".join(sorted(production)) + "\n")
        passed, lines = archive_verdict(lists, stamp)
        check("a stamp that is not a Production read fails, whatever it holds", not passed)

        absent = os.path.join(scratch, "absent.txt")
        saved = os.environ.get("ACTION")
        try:
            os.environ["ACTION"] = "install"
            with contextlib.redirect_stderr(io.StringIO()) as said:
                status = archive_phase(absent)
            check("the phase fails an archive with no recorded read",
                  status == 1 and "error: CloudKit schema gate" in said.getvalue())
            os.environ["ACTION"] = "build"
            check("the phase does nothing outside an archive", archive_phase(absent) == 0)
        finally:
            if saved is None:
                os.environ.pop("ACTION", None)
            else:
                os.environ["ACTION"] = saved

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
    if "--archive-phase" in argv:
        return archive_phase()
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
        if "--schema-file" not in argv and write_stamp(
                production, os.environ.get("CONTAINER_ID", DEFAULT_CONTAINER),
                os.environ.get("ENVIRONMENT", "production")):
            source += f"; recorded for the archive phase in {STAMP}"
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
