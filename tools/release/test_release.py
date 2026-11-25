import tempfile
import unittest
import zipfile
from pathlib import Path

import release


def c(subject, body=""):
    return ("a" * 40, subject, body)


class Gate(unittest.TestCase):
    def test_accepts_conventional(self):
        for s in ["feat: add thing", "fix(ui): crash", "feat!: drop api", "docs: x", "chore(deps)!: bump"]:
            self.assertTrue(release.is_valid(s), s)

    def test_rejects_the_rest(self):
        for s in ["Add thing", "feat:no space", "feat: ", "Feat: x", "fixes: x", "feat(): x", ""]:
            self.assertFalse(release.is_valid(s), s)

    def test_merge_commits_exempt(self):
        self.assertTrue(release.is_valid("Merge pull request #1 from a/b"))


class Plan(unittest.TestCase):
    def test_levels(self):
        self.assertEqual(release.plan([c("feat: a")], (0, 1, 0))[0], (0, 2, 0))
        self.assertEqual(release.plan([c("fix: a")], (0, 1, 0))[0], (0, 1, 1))
        self.assertEqual(release.plan([c("perf: a")], (1, 2, 3))[0], (1, 2, 4))
        self.assertEqual(release.plan([c("feat!: a")], (0, 1, 0))[0], (1, 0, 0))
        self.assertEqual(release.plan([c("fix: a", "BREAKING CHANGE: x")], (1, 2, 3))[0], (2, 0, 0))

    def test_highest_level_wins(self):
        self.assertEqual(release.plan([c("fix: a"), c("feat: b"), c("docs: c")], (1, 0, 0))[0], (1, 1, 0))

    def test_nothing_releasable(self):
        self.assertEqual(release.plan([c("docs: a"), c("ci: b"), c("Add c")], (1, 0, 0)), (None, ""))
        self.assertEqual(release.plan([], None), (None, ""))
        self.assertEqual(release.plan([c("docs: a")], None), (None, ""))

    def test_first_release_publishes_the_declared_version(self):
        # No tag yet: whatever the bump level, the first release is the seed version.
        for subject in ["feat: a", "fix: a", "feat!: a"]:
            self.assertEqual(release.plan([c(subject)], None, (0, 1, 0))[0], (0, 1, 0), subject)
        self.assertEqual(release.plan([c("fix: a")], None, (2, 0, 5))[0], (2, 0, 5))

    def test_notes(self):
        _, notes = release.plan([c("feat(ui): shiny"), c("fix: bug"), c("feat!: gone")], (0, 1, 0))
        self.assertIn("## Breaking changes\n- gone (aaaaaaa)", notes)
        self.assertIn("## Features\n- **ui:** shiny (aaaaaaa)", notes)
        self.assertIn("## Fixes\n- bug (aaaaaaa)", notes)


class Monorepo(unittest.TestCase):
    def test_components(self):
        ids = [cid for cid, _, _ in release.components()]
        self.assertEqual(ids[0], "base")
        self.assertIn("7thHell", ids)
        self.assertEqual(len(ids), len(set(ids)))

    def test_seed_version(self):
        base = dict((cid, d) for cid, _, d in release.components())["base"]
        self.assertEqual(len(release.seed_version(base)), 3)

    def test_build_one_component(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = release.build("base", "1.2.3", tmp)
            hell = release.build("7thHell", "0.4.0", tmp)
            self.assertEqual(base.name, "CorpoBiz-Base-v1.2.3.zip")
            self.assertEqual(hell.name, "CorpoBiz-7th-Hell-v0.4.0.zip")
            with zipfile.ZipFile(base) as z:
                self.assertIn('"version": "1.2.3"', z.read("CorpoBiz-Base/info.json").decode())
                names = z.namelist()
                self.assertIn("CorpoBiz-Base/scripts/CorpoBiz/Registry.reds", names)
                self.assertFalse([n for n in names if "SeventhHell" in n], "module sources leaked into Base")
            with zipfile.ZipFile(hell) as z:
                self.assertIn('"version": "0.4.0"', z.read("CorpoBiz-7th-Hell/info.json").decode())
                self.assertIn("CorpoBiz-7th-Hell/scripts/CorpoBiz/SeventhHell.reds", z.namelist())
            first = base.read_bytes()
            release.build("base", "1.2.3", tmp)
            self.assertEqual(first, base.read_bytes(), "build is not deterministic")

    def test_unknown_component(self):
        with self.assertRaises(SystemExit):
            release.build("nope", "1.0.0", tempfile.gettempdir())


if __name__ == "__main__":
    unittest.main()
