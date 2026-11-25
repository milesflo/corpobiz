#!/usr/bin/env python3
"""Conventional-commit gate and per-component release helper (stdlib only).

  release.py check-msg FILE          commit-msg hook: fail unless the first line is a conventional commit
  release.py check-title TITLE       CI: same check for a PR title
  release.py check-range A..B        CI: every non-merge commit in a range
  release.py next [NOTES_DIR]        print `releases=<json list>` of components due a release (writes
                                     NOTES_DIR/<tag>.md for each); an empty list when nothing is due
  release.py build COMPONENT VERSION [OUT]
                                     write that component's REDmod-layout zip (default OUT: dist/)

This is a monorepo: Base and every module are versioned independently. A
component is `base` or a folder under `modules/` (e.g. `7thHell`).

**Each component's info.json "version" is the authority.** A component is due
a release when `<component>-v<that version>` doesn't exist as a tag yet. To
release, bump the version in info.json and merge. Commits never change a
version on their own; they feed the release notes (feat/fix/breaking, from
commits touching that component's directory since its last release).

Components listed in unreleased.txt are held back: they have a version but are
not published until removed from that file.
"""
import json
import re
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HELD_FILE = Path(__file__).parent / "unreleased.txt"

TYPES = "feat|fix|perf|revert|docs|style|refactor|test|build|ci|chore"
HEADER = re.compile(rf"^(?P<type>{TYPES})(?:\((?P<scope>[^()\s][^()]*)\))?(?P<bang>!)?: (?P<desc>\S.*)$")
BREAKING = re.compile(r"^BREAKING[ -]CHANGE: ", re.M)
VERSION = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")
NOTE_TYPES = {"feat": "Features", "fix": "Fixes", "perf": "Fixes", "revert": "Fixes"}


def parse(subject, body=""):
    m = HEADER.match(subject)
    if not m:
        return None
    return {"type": m["type"], "scope": m["scope"], "desc": m["desc"],
            "breaking": bool(m["bang"]) or bool(BREAKING.search(body))}


def is_valid(subject):
    # Git's own merge commits are exempt; release notes skip merges anyway.
    return subject.startswith("Merge ") or parse(subject) is not None


def notes_for(commits):
    """commits: [(sha, subject, body)]. Markdown grouped into Breaking changes / Features / Fixes,
    or "" if nothing notable."""
    groups = {"Breaking changes": [], "Features": [], "Fixes": []}
    for sha, subject, body in commits:
        c = parse(subject, body)
        if not c:
            continue
        group = "Breaking changes" if c["breaking"] else NOTE_TYPES.get(c["type"])
        if group:
            scope = f"**{c['scope']}:** " if c["scope"] else ""
            groups[group].append(f"- {scope}{c['desc']} ({sha[:7]})")
    body = "\n\n".join(f"## {name}\n" + "\n".join(lines) for name, lines in groups.items() if lines)
    return body + "\n" if body else ""


def version_tuple(version):
    m = VERSION.match(version)
    if not m:
        raise SystemExit(f"version {version!r} is not MAJOR.MINOR.PATCH")
    return tuple(int(g) for g in m.groups())


def status(cid, version, tags, held):
    """'released', 'held' or 'due' for `version` of component `cid`. `tags` maps each
    existing release's (major, minor, patch) to its tag name. A version below an
    existing release is an error, not a release."""
    vt = version_tuple(version)
    if vt in tags:
        return "released"
    if tags and vt < max(tags):
        raise SystemExit(f"{cid}: info.json says {version}, but {tags[max(tags)]} already exists. "
                         "Set the version above the latest release.")
    return "held" if cid in held else "due"


def load_held(text, ids):
    held = {l.split("#")[0].strip() for l in text.splitlines() if l.split("#")[0].strip()}
    unknown = held - set(ids)
    if unknown:
        raise SystemExit(f"{HELD_FILE.name} names unknown components: {', '.join(sorted(unknown))}")
    return held


def components():
    """[(id, mod name, directory)] for Base (id `base`) and every module (id = its folder name)."""
    return [(info.parent.name, json.loads(info.read_text())["name"], info.parent)
            for info in [ROOT / "base" / "info.json", *sorted(ROOT.glob("modules/*/info.json"))]]


def declared_version(directory):
    return json.loads((directory / "info.json").read_text())["version"]


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, check=True, capture_output=True, text=True).stdout


def release_tags(cid):
    """{(major, minor, patch): tag} for the component's existing tags."""
    found = {}
    for tag in git("tag", "--list", f"{cid}-v*").split():
        m = re.fullmatch(rf"{re.escape(cid)}-v(\d+)\.(\d+)\.(\d+)", tag)
        if m:
            found[tuple(int(g) for g in m.groups())] = tag
    return found


def commits_in(rng, path=None):
    out = git("log", "--no-merges", "--format=%H%x1f%s%x1f%b%x1e", rng, *(["--", path] if path else []))
    return [tuple(rec.strip("\n").split("\x1f", 2)) for rec in out.split("\x1e") if rec.strip()]


def fail(bad):
    print("Not conventional commit messages:", *[f"  {s!r}" for s in bad], sep="\n")
    print(f"\nExpected `type(optional-scope)!: description` with type one of: {TYPES.replace('|', ', ')}.")
    print("Breaking change: add `!` after the type, or a `BREAKING CHANGE: ...` footer.")
    return 1


def build(cid, version, out=None):
    """One component's zip in the REDmod folder layout, version stamped to `version`
    (the repo's info.json is left alone). Deterministic output."""
    comp = next((c for c in components() if c[0] == cid), None)
    if comp is None:
        raise SystemExit(f"unknown component {cid!r}; one of: {', '.join(c[0] for c in components())}")
    _, _, directory = comp
    out = Path(out) if out else ROOT / "dist"
    out.mkdir(parents=True, exist_ok=True)
    meta = json.loads((directory / "info.json").read_text())
    meta["version"] = version
    folder = re.sub(r"[^A-Za-z0-9]+", "-", meta["name"]).strip("-")
    path = out / f"{folder}-v{version}.zip"
    files = {f"{folder}/info.json": (json.dumps(meta, indent=2) + "\n").encode()}
    for src in sorted(directory.glob("*.reds")):
        files[f"{folder}/scripts/CorpoBiz/{src.name}"] = src.read_bytes()
    with zipfile.ZipFile(path, "w") as z:
        for name, data in files.items():
            entry = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.external_attr = 0o644 << 16
            z.writestr(entry, data)
    return path


def next_releases(notes_dir=None):
    held = load_held(HELD_FILE.read_text() if HELD_FILE.exists() else "", [c[0] for c in components()])
    releases = []
    for cid, _, directory in components():
        version = declared_version(directory)
        tags = release_tags(cid)
        state = status(cid, version, tags, held)
        previous = tags[max(tags)] if tags else None
        rng = f"{previous}..HEAD" if previous else "HEAD"
        commits = commits_in(rng, f"{directory.relative_to(ROOT).as_posix()}/")
        if state == "held":
            print(f"{cid}: {version} is held back (see {HELD_FILE.name})", file=sys.stderr)
        elif state == "released" and commits:
            print(f"{cid}: {len(commits)} commit(s) since {previous}, but info.json still says {version}; "
                  "bump it to release them", file=sys.stderr)
        elif state == "due":
            tag = f"{cid}-v{version}"
            releases.append({"component": cid, "version": version, "tag": tag})
            if notes_dir:
                Path(notes_dir).mkdir(parents=True, exist_ok=True)
                fallback = "Initial release.\n" if not previous else f"Release {version}.\n"
                (Path(notes_dir) / f"{tag}.md").write_text(notes_for(commits) or fallback)
    return releases


def main(argv):
    cmd, args = (argv[1], argv[2:]) if len(argv) > 1 else ("", [])
    if cmd == "check-msg":
        lines = [l for l in Path(args[0]).read_text().splitlines() if l.strip() and not l.startswith("#")]
        subject = lines[0] if lines else ""
        return 0 if is_valid(subject) else fail([subject])
    if cmd == "check-title":
        return 0 if is_valid(args[0]) else fail([args[0]])
    if cmd == "check-range":
        bad = [s for _, s, _ in commits_in(args[0]) if not is_valid(s)]
        return fail(bad) if bad else 0
    if cmd == "next":
        print("releases=" + json.dumps(next_releases(args[0] if args else None), separators=(",", ":")))
        return 0
    if cmd == "build":
        print(build(args[0], args[1], args[2] if len(args) > 2 else None))
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
