#!/usr/bin/env python3
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
"""The repository's rules that no test checks: CI's job A (`.github/workflows/ci.yml`).

Run it before a pull request as well; it takes seconds and needs only Python 3:

    python3 Scripts/check_repo_hygiene.py

Each check prints PASS or FAIL with what it found, and the exit status is 1 when any failed:

1. The website's pages are what their Markdown makes (`Scripts/build_website_pages.py --check`).
2. The paste kit, its guide and its review sheet are in step
   (`Planning/website-drafts/build_paste.py --check`).
3. Every JSON file under `FRUSExplorer/Resources/` parses.
4. Each TestFlight note is at most 4,000 characters, counted as CLAUDE.md's build-bump list says,
   with Python's len(): App Store Connect's limit, which only counting by hand held until now.
5. Each workflow script under `.claude/workflows/` parses as the Workflow runtime runs it, its
   body inside an async function (a top-level `return` is legal there and nowhere else). Node
   checks it where there is one, as on CI; a Mac without Node uses JavaScriptCore's `jsc`.
6. No tracked text file holds a merge-conflict marker at the start of a line.

Written 2026-11-26 with the CI it serves, on the owner's word ("Yes, all three"). Each of these
had a gate only in a session's memory or a runbook's checklist; the rules a test can hold (the
CLAUDE.md budget, the license headers, the plan of record) stay in `CodingStandardsAuditTests`.
"""

import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
TESTFLIGHT_NOTES = ["Docs/TestFlight-Instructions-ios.md", "Docs/TestFlight-Instructions-mac.md"]
TESTFLIGHT_LIMIT = 4000
JSC = pathlib.Path("/System/Library/Frameworks/JavaScriptCore.framework/Versions/A/Helpers/jsc")


def run(args):
    """Runs a command at the repository's root and returns its exit status and output."""
    done = subprocess.run(args, cwd=ROOT, capture_output=True, text=True)
    return done.returncode, (done.stdout + done.stderr).strip()


def check_script(relative):
    """A Python script's own `--check` mode, run with this interpreter."""
    status, output = run([sys.executable, relative, "--check"])
    return status == 0, output.splitlines()[-1] if output else "(no output)"


def check_json():
    files = sorted((ROOT / "FRUSExplorer" / "Resources").glob("*.json"))
    bad = []
    for path in files:
        try:
            json.loads(path.read_bytes())
        except ValueError as error:
            bad.append("{}: {}".format(path.name, error))
    if not files:
        return False, "found no JSON file under FRUSExplorer/Resources/: the folder moved"
    if bad:
        return False, "; ".join(bad)
    return True, "{} files parse".format(len(files))


def check_testflight_notes():
    found, over = [], []
    for relative in TESTFLIGHT_NOTES:
        length = len((ROOT / relative).read_text(encoding="utf-8"))
        found.append("{} {:,}".format(pathlib.Path(relative).name, length))
        if length > TESTFLIGHT_LIMIT:
            over.append("{} is {:,} characters, over App Store Connect's {:,}".format(
                relative, length, TESTFLIGHT_LIMIT))
    if over:
        return False, "; ".join(over)
    return True, ", ".join(found)


def check_workflow_scripts():
    scripts = sorted((ROOT / ".claude" / "workflows").glob("*.js"))
    if not scripts:
        return False, "found no workflow script under .claude/workflows/: the folder moved"
    node = shutil.which("node")
    if node is None and os.environ.get("CI"):
        return False, "CI has no node, so the workflow scripts were not parsed"
    if node is None and not JSC.exists():
        return False, "neither node nor JavaScriptCore's jsc is here to parse the workflow scripts"
    failures = []
    with tempfile.TemporaryDirectory() as scratch:
        for script in scripts:
            body = re.sub(r"^export const meta", "const meta", script.read_text(encoding="utf-8"),
                          count=1, flags=re.M)
            wrapped = pathlib.Path(scratch) / (script.stem + ".wrapped.js")
            wrapped.write_text("(async function () {\n" + body + "\n})\n", encoding="utf-8")
            if node is not None:
                status, output = run([node, "--check", str(wrapped)])
                if status != 0:
                    failures.append("{}: {}".format(script.name, output.splitlines()[-1]))
            else:
                program = ("try {{ checkModuleSyntax(readFile({!r})); print('ok') }} "
                           "catch (e) {{ print('error ' + e) }}").format(str(wrapped))
                status, output = run([str(JSC), "-e", program])
                if output != "ok":
                    failures.append("{}: {}".format(script.name, output))
    if failures:
        return False, "; ".join(failures)
    return True, "{} scripts parse ({})".format(len(scripts), "node" if node else "jsc")


def check_conflict_markers():
    status, output = run(["git", "grep", "-I", "-n", "-E", r"^(<<<<<<<|>>>>>>>|\|\|\|\|\|\|\|) "])
    if status == 0:
        return False, "conflict markers: " + "; ".join(output.splitlines()[:10])
    if status == 1:
        return True, "none"
    return False, "git grep failed: " + output


CHECKS = [
    ("the website's pages", lambda: check_script("Scripts/build_website_pages.py")),
    ("the paste kit", lambda: check_script("Planning/website-drafts/build_paste.py")),
    ("bundled JSON", check_json),
    ("TestFlight notes", check_testflight_notes),
    ("workflow scripts", check_workflow_scripts),
    ("conflict markers", check_conflict_markers),
]


def main():
    failed = 0
    for name, check in CHECKS:
        passed, detail = check()
        failed += 0 if passed else 1
        print("{} {}: {}".format("PASS" if passed else "FAIL", name, detail))
    print("{} of {} checks failed".format(failed, len(CHECKS)) if failed else
          "all {} checks passed".format(len(CHECKS)))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
