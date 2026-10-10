from contextlib import redirect_stderr
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import io
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys
import tempfile
import threading
import unittest
from unittest.mock import patch


ENGINE = Path(__file__).resolve().parents[1] / "modules/home/programs/skills-sync.py"
CLI = os.environ["SKILLS_BIN"]


class SkillsSyncTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.home.mkdir()
        self.state = self.home / ".local/state/dotfiles-skills"
        self.public = self.home / ".agents/skills"
        self.source = self.root / "source"
        self.skill(self.source, "alpha")
        self.skill(self.source, "beta")
        self.env = dict(os.environ, HOME=str(self.home))
        for key in ("XDG_STATE_HOME", "XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME", "DRY_RUN"):
            self.env.pop(key, None)

    def skill(self, source, name, body="original"):
        directory = source / name
        directory.mkdir(parents=True, exist_ok=True)
        (directory / "SKILL.md").write_text(
            f"---\nname: {name}\ndescription: A local test skill\n---\n\n{body}\n"
        )
        (directory / "scripts").mkdir(exist_ok=True)
        (directory / "scripts/run.sh").write_text("printf 'payload'\n")
        (directory / "reference.txt").write_text("reference payload\n")
        return directory

    def record(self, category="work", **fields):
        return dict(source=str(self.source), category=category, **fields)

    def sync(self, records, *args, success=True, cli=CLI, cwd=None, env=None):
        config = self.root / "config.json"
        config.write_text(json.dumps(records))
        result = subprocess.run(
            [sys.executable, str(ENGINE), "--skills-cli", cli,
             "--config", str(config), *args],
            cwd=cwd or self.root, env=env or self.env,
            text=True, capture_output=True, timeout=60,
        )
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def test_cli_option_arguments_fail_before_any_home_write(self):
        for option in ("--global", "-g", "--yes", "--agent", "--skill", "-x"):
            with self.subTest(option=option, field="skills"):
                result = self.sync([self.record(skills=[option, "alpha"])], success=False)
                self.assertIn("Invalid selected names", result.stderr)
                self.assertEqual(list(self.home.iterdir()), [])
            with self.subTest(option=option, field="source"):
                result = self.sync([dict(source=option, category="work")], success=False)
                self.assertIn("Source must not start with '-'", result.stderr)
                self.assertEqual(list(self.home.iterdir()), [])
        self.sync([self.record(skills=["alpha"])])
        self.assertTrue((self.public / "work/alpha/SKILL.md").is_file())
        self.assertEqual({p.name for p in (self.home / ".agents").iterdir()}, {"skills"})
        self.assertFalse((self.home / ".pi").exists())
        local = self.root / "-g"
        self.skill(local, "gamma")
        self.sync([dict(source="./-g", category="local", skills=["gamma"])])
        self.assertTrue((self.public / "local/gamma/SKILL.md").is_file())

    def test_cli_timeouts_report_source_and_preserve_all_categories(self):
        self.sync([self.record(skills=["beta"]),
                   self.record(category="old", skills=["alpha"])])
        previous = {name: os.readlink(self.public / name) for name in ("work", "old")}
        config = self.root / "timeout.json"
        config.write_text(json.dumps([self.record(skills=["alpha"])]))
        main = runpy.run_path(str(ENGINE))["main"]
        native_run = subprocess.run
        for command in ("add", "list"):
            with self.subTest(command=command):
                def run(argv, **kwargs):
                    self.assertEqual(kwargs.get("timeout"), 300)
                    if argv[1] == command:
                        raise subprocess.TimeoutExpired(argv, 300)
                    return native_run(argv, **kwargs)

                stderr = io.StringIO()
                with patch.dict(os.environ, self.env, clear=True), patch.object(
                    sys, "argv", [str(ENGINE), "--skills-cli", CLI, "--config", str(config)]
                ), patch("subprocess.run", side_effect=run), redirect_stderr(stderr):
                    self.assertEqual(main(), 1)
                self.assertEqual(stderr.getvalue(),
                                 f"dotfiles-skills-sync: Skills CLI timed out after 300 seconds for {self.source.resolve()}\n")
                self.assertEqual({name: os.readlink(self.public / name) for name in previous},
                                 previous)
                self.assertIn("name: beta", (self.public / "work/beta/SKILL.md").read_text())
                self.assertIn("name: alpha", (self.public / "old/alpha/SKILL.md").read_text())

    def test_optional_project_lock_does_not_block_selected_publication(self):
        config = self.root / "optional-lock.json"
        config.write_text(json.dumps([self.record(skills=["ALPHA"])]))
        main = runpy.run_path(str(ENGINE))["main"]
        native_run = subprocess.run
        locks = {
            "malformed": "{",
            "future-version": json.dumps({"version": 2, "skills": {"alpha": {}}}),
            "mismatched-names": json.dumps({"version": 1, "skills": {"beta": {}}}),
        }
        for case, contents in locks.items():
            with self.subTest(lock=case):
                commands = []

                def run(argv, **kwargs):
                    result = native_run(argv, **kwargs)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    commands.append(argv[1])
                    if argv[1] == "add":
                        (Path(kwargs["cwd"]) / "skills-lock.json").write_text(contents)
                    return result

                stderr = io.StringIO()
                with patch.dict(os.environ, self.env, clear=True), patch.object(
                    sys, "argv", [str(ENGINE), "--skills-cli", CLI, "--config", str(config)]
                ), patch("subprocess.run", side_effect=run), redirect_stderr(stderr):
                    result = main()
                self.assertEqual(commands, ["add", "list"])
                self.assertEqual(result, 0, stderr.getvalue())
                self.assertTrue((self.public / "work").is_symlink())
                self.assertEqual({p.name for p in (self.public / "work").iterdir()}, {"alpha"})
                self.assertIn("name: alpha", (self.public / "work/alpha/SKILL.md").read_text())
                self.assertEqual((self.public / "work/alpha/reference.txt").read_text(),
                                 "reference payload\n")

    def test_all_skills_and_payload(self):
        self.sync([self.record()])
        self.assertTrue((self.public / "work").is_symlink())
        self.assertIn("name: alpha", (self.public / "work/alpha/SKILL.md").read_text())
        self.assertIn("name: beta", (self.public / "work/beta/SKILL.md").read_text())
        self.assertEqual((self.public / "work/alpha/scripts/run.sh").read_text(),
                         "printf 'payload'\n")
        self.assertEqual((self.public / "work/alpha/reference.txt").read_text(),
                         "reference payload\n")

    def test_category_with_spaces_and_ampersand(self):
        self.sync([self.record(category="Vue & Nuxt", skills=["alpha"])])
        category = self.public / "Vue & Nuxt"
        self.assertTrue(category.is_symlink())
        self.assertIn("name: alpha", (category / "alpha/SKILL.md").read_text())
        self.assertEqual((category / "alpha/reference.txt").read_text(),
                         "reference payload\n")
        self.assertEqual((category / "alpha/scripts/run.sh").read_text(),
                         "printf 'payload'\n")
        self.sync([])
        self.assertFalse(category.is_symlink())
        self.assertFalse(category.exists())

    def test_subset_repeat_update_and_empty_cleanup(self):
        manual = self.public / "manual"
        manual.mkdir(parents=True)
        (manual / "SKILL.md").write_text("manual skill\n")
        self.sync([self.record(skills=["ALPHA"])])
        self.assertFalse((self.public / "work/beta").exists())
        first = (self.public / "work").resolve()
        self.skill(self.source, "alpha", "updated source")
        self.sync([self.record(skills=["alpha"])])
        self.assertIn("updated source", (self.public / "work/alpha/SKILL.md").read_text())
        self.assertFalse(first.exists())
        self.sync([self.record(skills=[])], cli="/no-such-skills")
        self.assertFalse((self.public / "work").exists())
        self.assertEqual((manual / "SKILL.md").read_text(), "manual skill\n")
        self.sync([], cli="/no-such-skills")

    def test_repeated_categories_merge_and_rename(self):
        other = self.root / "other"
        self.skill(other, "gamma")
        self.sync([self.record(skills=["alpha"]),
                   dict(source=str(other), category="work")])
        self.assertTrue((self.public / "work/alpha/SKILL.md").is_file())
        self.assertTrue((self.public / "work/gamma/SKILL.md").is_file())
        self.sync([dict(source=str(other), category="new")])
        self.assertFalse((self.public / "work").exists())
        self.assertTrue((self.public / "new/gamma/SKILL.md").is_file())
        self.sync([])
        self.assertFalse((self.public / "new").exists())

    def test_missing_cli_and_incomplete_selection_preserve_previous(self):
        self.sync([self.record(skills=["beta"])])
        previous = os.readlink(self.public / "work")
        for selection in (["missing"], ["alpha", "missing"]):
            self.sync([self.record(skills=selection)], success=False)
            self.assertEqual(os.readlink(self.public / "work"), previous)
            self.assertTrue((self.public / "work/beta/SKILL.md").is_file())
        self.sync([self.record()], cli="/no-such-skills", success=False)
        self.assertEqual(os.readlink(self.public / "work"), previous)

    def test_duplicate_names_in_any_category_preserve_previous(self):
        self.sync([self.record(skills=["beta"])])
        previous = os.readlink(self.public / "work")
        other = self.root / "other"
        self.skill(other, "alpha")
        for category in ("work", "other"):
            result = self.sync([self.record(skills=["alpha"]),
                                dict(source=str(other), category=category)], success=False)
            self.assertIn("Duplicate skill", result.stderr)
            self.assertEqual(os.readlink(self.public / "work"), previous)
            self.assertFalse((self.public / "other").exists())

    def test_manual_collisions_fail_including_dry_run(self):
        self.sync([self.record(category="old", skills=["beta"])])
        previous = os.readlink(self.public / "old")
        manual = self.public / "work"
        manual.mkdir()
        (manual / "keep").write_text("manual\n")
        for args in ((), ("--dry-run",)):
            result = self.sync([self.record()], *args, success=False)
            self.assertIn("Manual category collision", result.stderr)
            self.assertEqual((manual / "keep").read_text(), "manual\n")
            self.assertEqual(os.readlink(self.public / "old"), previous)
        (manual / "keep").unlink()
        manual.rmdir()
        manual.symlink_to(self.root / "missing")
        result = self.sync([self.record()], success=False)
        self.assertIn("Manual category collision", result.stderr)
        self.assertEqual(os.readlink(manual), str(self.root / "missing"))

    def test_indirect_category_link_is_not_adopted(self):
        self.sync([self.record()])
        target = (self.public / "work").resolve()
        indirect = self.root / "indirect"
        indirect.symlink_to(target)
        (self.public / "work").unlink()
        (self.public / "work").symlink_to(indirect)
        result = self.sync([self.record()], success=False)
        self.assertIn("Manual category collision", result.stderr)
        self.assertEqual(os.readlink(self.public / "work"), str(indirect))

    def test_parent_symlinks_fail(self):
        target = self.root / "manual-agents"
        target.mkdir()
        (self.home / ".agents").symlink_to(target)
        self.sync([self.record()], success=False)
        self.assertEqual(list(target.iterdir()), [])

    def test_dry_run_and_empty_untouched_home_write_nothing(self):
        self.sync([], cli="/no-such-skills")
        self.assertEqual(list(self.home.iterdir()), [])
        self.sync([self.record()], "--dry-run", cli="/no-such-skills")
        self.assertEqual(list(self.home.iterdir()), [])
        env = dict(self.env, DRY_RUN="1")
        self.sync([self.record()], cli="/no-such-skills", env=env)
        self.assertEqual(list(self.home.iterdir()), [])

    def test_relative_source_and_original_names(self):
        self.skill(self.source, "Alpha_With_Underscores")
        self.sync([dict(source="./source", category="local",
                        skills=["Alpha_With_Underscores"])])
        self.assertIn("name: Alpha_With_Underscores",
                      (self.public / "local/alpha_with_underscores/SKILL.md").read_text())

    def test_original_names_with_spaces_and_dots(self):
        self.skill(self.source, "Alpha Test")
        self.skill(self.source, "alpha.dot")
        self.sync([self.record(skills=["ALPHA TEST", "alpha.dot"])])
        self.assertIn("name: Alpha Test", (self.public / "work/alpha-test/SKILL.md").read_text())
        self.assertIn("name: alpha.dot", (self.public / "work/alpha.dot/SKILL.md").read_text())
        self.assertFalse((self.public / "work/beta").exists())

    def test_installed_directory_collision_preserves_previous(self):
        other = self.root / "other"
        self.skill(self.source, "Alpha Test")
        self.skill(other, "alpha-test")
        self.sync([self.record(skills=["beta"])])
        previous = os.readlink(self.public / "work")
        result = self.sync([self.record(skills=["Alpha Test"]),
                            dict(source=str(other), category="work")], success=False)
        self.assertIn("Installed directory collision", result.stderr)
        self.assertEqual(os.readlink(self.public / "work"), previous)

    def test_concurrent_runs_publish_complete_categories(self):
        config = self.root / "concurrent.json"
        config.write_text(json.dumps([self.record()]))
        processes = [subprocess.Popen(
            [sys.executable, str(ENGINE), "--skills-cli", CLI, "--config", str(config)],
            env=self.env, cwd=self.root, text=True,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        ) for _ in range(2)]
        try:
            for process in processes:
                stdout, stderr = process.communicate(timeout=60)
                self.assertEqual(process.returncode, 0, stdout + stderr)
        finally:
            for process in processes:
                if process.poll() is None:
                    process.kill()
                    process.wait()
        self.assertTrue((self.public / "work/alpha/SKILL.md").is_file())
        self.assertTrue((self.public / "work/beta/SKILL.md").is_file())

    def test_well_known_http_source(self):
        site = self.root / "site"
        pack = site / ".well-known/skills"
        self.skill(pack, "network-skill")
        (pack / "index.json").write_text(json.dumps({"skills": [{
            "name": "network-skill", "description": "Local HTTP fixture",
            "files": ["SKILL.md", "reference.txt", "scripts/run.sh"],
        }]}))

        class QuietHandler(SimpleHTTPRequestHandler):
            def log_message(self, *args):
                pass

        server = ThreadingHTTPServer(("127.0.0.1", 0),
                                     partial(QuietHandler, directory=str(site)))
        thread = threading.Thread(target=server.serve_forever)
        thread.start()
        try:
            source = f"http://127.0.0.1:{server.server_port}"
            self.sync([dict(source=source, category="web")])
            self.assertIn("name: network-skill",
                          (self.public / "web/network-skill/SKILL.md").read_text())
            self.assertEqual((self.public / "web/network-skill/reference.txt").read_text(),
                             "reference payload\n")
        finally:
            server.shutdown()
            thread.join()
            server.server_close()

    def test_partial_publication_recovery_and_alias_gc(self):
        self.sync([self.record(category="one", skills=["alpha"]),
                   self.record(category="two", skills=["beta"])])
        first = (self.public / "one").resolve().parent
        alias = self.public / "manual-alias"
        alias.symlink_to(first / "one")
        self.skill(self.source, "alpha", "second version")
        self.sync([self.record(category="one", skills=["alpha"]),
                   self.record(category="two", skills=["beta"])])
        self.assertTrue(first.exists())
        second = (self.public / "one").resolve().parent
        (self.public / "one").unlink()
        (self.public / "one").symlink_to(first / "one")
        unknown = self.state / "generations/manual-directory"
        unknown.mkdir()
        (unknown / "keep").write_text("not marked\n")
        self.sync([self.record(category="one", skills=["alpha"])])
        self.assertIn("second version", (self.public / "one/alpha/SKILL.md").read_text())
        self.assertFalse((self.public / "two").exists())
        self.assertFalse(second.exists())
        self.assertTrue(first.exists())
        self.assertEqual((unknown / "keep").read_text(), "not marked\n")
        self.sync([])
        self.assertTrue(alias.is_symlink())
        self.assertTrue((alias / "alpha/SKILL.md").is_file())
        alias.unlink()
        self.sync([])
        self.assertFalse(first.exists())
        self.assertTrue(unknown.is_dir())


if __name__ == "__main__":
    unittest.main()
