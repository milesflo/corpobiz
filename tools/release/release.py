#!/usr/bin/env python3
"""Conventional-commit gate and per-component release helper (stdlib only).

One parser serves the commit gate and the release logic, so they can't drift.

  release.py check-msg FILE          commit-msg hook: fail unless the first line is a conventional commit
  release.py check-title TITLE       CI: same check for a PR title
  release.py check-range A..B        CI: every non-merge commit in a range
  release.py next [NOTES_DIR]        print `releases=<json list>` of components due a release (writes
                                     NOTES_DIR/<tag>.md for each); an empty list when nothing is due
  release.py build COMPONENT VERSION [OUT]
                                     write that component's REDmod-layout zip (default OUT: dist/)

This is a monorepo: Base and every module are versioned independently. A
component is `base` or a folder under `modules/` (e.g. `7thHell`); its tags are
`<component>-vX.Y.Z`. A commit counts toward a component only if it touches
that component's directory.

Per component, from commits since its last tag: a breaking change (`type!:` or
a `BREAKING CHANGE:` footer) bumps major, `feat` minor, `fix`/`perf`/`revert`
patch; other types never release. A component with no tag yet publishes the
version already in its info.json on its first releasable commit.
"""
import json
import re
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

TYPES = "feat|fix|perf|revert|docs|style|refactor|test|build|ci|chore"
HEADER = re.compile(rf"^(?P<type>{TYPES})(?:\((?P<scope>[^()\s][^()]*)\))?(?P<bang>!)?: (?P<desc>\S.*)$")
BREAKING = re.compile(r"^BREAKING[ -]CHANGE: ", re.M)
VERSION = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")
LEVEL = {"feat": 2, "fix": 1, "perf": 1, "revert": 1}  # 3 (major) comes from breaking changes


def parse(subject, body=""):
    m = HEADER.match(subject)
    if not m:
        return None
    return {"type": m["type"], "scope": m["scope"], "desc": m["desc"],
            "breaking": bool(m["bang"]) or bool(BREAKING.search(body))}


def is_valid(subject):
    # Git's own merge commits are exempt; release logic skips merges anyway.
    return subject.startswith("Merge ") or parse(subject) is not None


def plan(commits, last, first=(0, 1, 0)):
    """commits: [(sha, subject, body)]; last: (major, minor, patch) or None if never released;
    first: the version to publish on a first release. Returns (new_version or None, notes)."""
    level = 0
    groups = {"Breaking changes": [], "Features": [], "Fixes": []}
    for sha, subject, body in commits:
        c = parse(subject, body)
        if not c:
            continue
        lvl = 3 if c["breaking"] else LEVEL.get(c["type"], 0)
        if not lvl:
            continue
        level = max(level, lvl)
        scope = f"**{c['scope']}:** " if c["scope"] else ""
        group = "Breaking changes" if c["breaking"] else "Features" if c["type"] == "feat" else "Fixes"
        groups[group].append(f"- {scope}{c['desc']} ({sha[:7]})")
    if not level:
        return None, ""
    if last is None:
        new = first
    else:
        major, minor, patch = last
        new = {3: (major + 1, 0, 0), 2: (major, minor + 1, 0), 1: (major, minor, patch + 1)}[level]
    notes = "\n\n".join(f"## {name}\n" + "\n".join(lines) for name, lines in groups.items() if lines)
    return new, notes + "\n"


def components():
    """[(id, mod name, directory)] for Base (id `base`) and every module (id = its folder name)."""
    return [(info.parent.name, json.loads(info.read_text())["name"], info.parent)
            for info in [ROOT / "base" / "info.json", *sorted(ROOT.glob("modules/*/info.json"))]]


def seed_version(directory):
    v = json.loads((directory / "info.json").read_text())["version"]
    m = VERSION.match(v)
    if not m:
        raise SystemExit(f"{directory.name}/info.json version {v!r} is not MAJOR.MINOR.PATCH")
    return tuple(int(g) for g in m.groups())


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, check=True, capture_output=True, text=True).stdout


def last_release(cid):
    """(tag, (major, minor, patch)) of the component's latest tag, or (None, None)."""
    try:
        tag = git("describe", "--tags", "--abbrev=0", "--match", f"{cid}-v[0-9]*").strip()
    except subprocess.CalledProcessError:
        return None, None
    m = re.fullmatch(rf"{re.escape(cid)}-v(\d+)\.(\d+)\.(\d+)", tag)
    if not m:
        raise SystemExit(f"tag {tag!r} is not {cid}-vMAJOR.MINOR.PATCH")
    return tag, tuple(int(g) for g in m.groups())


def commits_in(rng, path=None):
    args = ["log", "--no-merges", "--format=%H%x1f%s%x1f%b%x1e", rng]
    out = git(*args, *(["--", path] if path else []))
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
        notes_dir = Path(args[0]) if args else None
        releases = []
        for cid, _, directory in components():
            tag, last = last_release(cid)
            commits = commits_in(f"{tag}..HEAD" if tag else "HEAD", f"{directory.relative_to(ROOT).as_posix()}/")
            new, notes = plan(commits, last, seed_version(directory))
            if new:
                version = "%d.%d.%d" % new
                releases.append({"component": cid, "version": version, "tag": f"{cid}-v{version}"})
                if notes_dir:
                    notes_dir.mkdir(parents=True, exist_ok=True)
                    (notes_dir / f"{cid}-v{version}.md").write_text(notes)
        print("releases=" + json.dumps(releases, separators=(",", ":")))
        return 0
    if cmd == "build":
        print(build(args[0], args[1], args[2] if len(args) > 2 else None))
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
