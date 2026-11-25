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


class Status(unittest.TestCase):
    TAGS = {(0, 1, 0): "base-v0.1.0", (0, 2, 0): "base-v0.2.0"}

    def test_untagged_version_is_due(self):
        self.assertEqual(release.status("base", "0.1.0", {}, set()), "due")
        self.assertEqual(release.status("base", "0.3.0", self.TAGS, set()), "due")
        self.assertEqual(release.status("base", "1.0.0", self.TAGS, set()), "due")

    def test_already_tagged_is_released(self):
        self.assertEqual(release.status("base", "0.2.0", self.TAGS, set()), "released")
        self.assertEqual(release.status("base", "0.1.0", self.TAGS, {"base"}), "released")

    def test_held_component_is_not_published(self):
        self.assertEqual(release.status("7thHell", "0.1.0", {}, {"7thHell"}), "held")

    def test_version_below_an_existing_release_is_an_error(self):
        with self.assertRaises(SystemExit):
            release.status("base", "0.1.5", self.TAGS, set())

    def test_malformed_version_is_an_error(self):
        for v in ["0.1", "v0.1.0", "0.1.0-dev", ""]:
            with self.assertRaises(SystemExit, msg=v):
                release.status("base", v, {}, set())

    def test_load_held(self):
        self.assertEqual(release.load_held("# c\nbase  # why\n\n7thHell\n", ["base", "7thHell", "x"]), {"base", "7thHell"})
        with self.assertRaises(SystemExit):
            release.load_held("typo\n", ["base"])

    def test_the_real_hold_file_names_real_components(self):
        ids = [cid for cid, _, _ in release.components()]
        held = release.load_held(release.HELD_FILE.read_text(), ids)
        self.assertNotIn("base", held, "base must be releasable")


class Notes(unittest.TestCase):
    def test_grouping(self):
        notes = release.notes_for([c("feat(ui): shiny"), c("fix: bug"), c("feat!: gone"), c("perf: fast"), c("docs: x")])
        self.assertIn("## Breaking changes\n- gone (aaaaaaa)", notes)
        self.assertIn("## Features\n- **ui:** shiny (aaaaaaa)", notes)
        self.assertIn("## Fixes\n- bug (aaaaaaa)\n- fast (aaaaaaa)", notes)
        self.assertNotIn("docs", notes)

    def test_footer_marks_breaking(self):
        self.assertIn("## Breaking changes", release.notes_for([c("fix: a", "BREAKING CHANGE: x")]))

    def test_nothing_notable(self):
        self.assertEqual(release.notes_for([c("docs: a"), c("chore: b"), c("Add c")]), "")
        self.assertEqual(release.notes_for([]), "")


class Monorepo(unittest.TestCase):
    def test_components(self):
        ids = [cid for cid, _, _ in release.components()]
        self.assertEqual(ids[0], "base")
        self.assertIn("7thHell", ids)
        self.assertEqual(len(ids), len(set(ids)))

    def test_declared_versions_are_valid(self):
        for _, _, directory in release.components():
            release.version_tuple(release.declared_version(directory))

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
