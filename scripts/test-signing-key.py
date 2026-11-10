#!/usr/bin/env python3

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def main():
    if len(sys.argv) != 2:
        sys.exit(f"Usage: {sys.argv[0]} EVALUATED_SIGNING_KEY_SCRIPT")
    activation = Path(sys.argv[1]).resolve(strict=True)
    bash = shutil.which("bash")
    git = shutil.which("git")
    if not bash or not git:
        sys.exit("bash (4.2 or later) and git must be on PATH")

    with tempfile.TemporaryDirectory(prefix="signing-key-test-") as directory:
        root = Path(directory)
        bin_dir = root / "bin"
        bin_dir.mkdir()
        for name in ("mkdir", "mktemp", "mv"):
            command = shutil.which(name)
            if not command:
                sys.exit(f"{name} must be on PATH")
            (bin_dir / name).symlink_to(command)
        op = bin_dir / "op"
        op.write_text(
            f"#!{sys.executable}\n"
            "import json, os, sys\n"
            "args = sys.argv[1:]\n"
            "with open(os.environ['TEST_OP_LOG'], 'a') as log:\n"
            "    log.write(json.dumps(args) + '\\n')\n"
            "if args == ['account', 'get']:\n"
            "    sys.exit(1 if os.environ['TEST_MODE'] == 'no-account' else 0)\n"
            "if args[:2] == ['item', 'get'] and args[3:] == ['--format', 'json']:\n"
            "    if os.environ['TEST_MODE'] == 'fetch-failure':\n"
            "        sys.exit(1)\n"
            "    print(json.dumps({'fields': [{'label': 'public key',\n"
            "                                 'value': os.environ['TEST_KEY']}]}))\n"
            "else:\n"
            "    sys.exit('Unexpected fake op arguments')\n"
        )
        op.chmod(0o700)

        def run(name, key="", mode="success", existing=False, dry_run=False):
            home = root / name
            home.mkdir()
            temporary = home / "tmp"
            temporary.mkdir()
            target = home / ".config/git/signing.gitconfig"
            previous = b"[user]\n\tsigningkey = previous-key\n"
            if existing:
                target.parent.mkdir(parents=True)
                target.write_bytes(previous)
            log = home / "op.log"
            env = {
                "HOME": str(home),
                "PATH": str(bin_dir),
                "TMPDIR": str(temporary),
                "GIT_CONFIG_NOSYSTEM": "1",
                "GIT_CONFIG_GLOBAL": os.devnull,
                "TEST_OP_LOG": str(log),
                "TEST_MODE": mode,
                "TEST_KEY": key,
            }
            if dry_run:
                env["DRY_RUN"] = "1"
            result = subprocess.run(
                [bash, "--noprofile", "--norc", "-euo", "pipefail", str(activation)],
                env=env, capture_output=True, text=True, check=True,
            )
            calls = [json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []
            if dry_run:
                assert not calls, calls
                assert "Would update" in result.stdout, result
            else:
                assert calls[0] == ["account", "get"], calls
                assert len(calls) == (1 if mode == "no-account" else 2), calls
            if dry_run or mode != "success" or not key:
                if existing:
                    assert target.read_bytes() == previous, name
                else:
                    assert not target.parent.exists(), name
                if not dry_run:
                    assert "warning:" in result.stderr, result
            else:
                def config(*args):
                    return subprocess.check_output(
                        [git, "config", "--file", str(target), *args], env=env,
                    )

                names = config("--name-only", "--list").decode().splitlines()
                assert sorted(names) == sorted([
                    "user.signingkey", "commit.gpgsign", "gpg.format", "gpg.ssh.program",
                ]), f"{name}: unexpected config keys: {names}"
                assert config("--null", "--get", "user.signingkey") == key.encode() + b"\0", name
                assert config("--get", "commit.gpgsign") == b"true\n", name
                assert config("--get", "gpg.format") == b"ssh\n", name
                assert config("--get", "gpg.ssh.program").strip().endswith(b"op-ssh-sign"), name
            assert not list(temporary.iterdir()), name
            print(f"PASS {name}")

        run("ordinary", "ssh-ed25519 AAAAtest test@example.invalid")
        run("multiline", "ssh-ed25519 AAAAtest\n[core]\n  hooksPath = /tmp/unwanted")
        run("quoted", '  ssh-ed25519 AAAAtest "quoted" \\backslash\t#; comment')
        run("no-account", mode="no-account", existing=True)
        run("fetch-failure", mode="fetch-failure", existing=True)
        run("empty-key", existing=True)
        run("dry-run-existing", "ssh-ed25519 AAAAtest", existing=True, dry_run=True)
        run("dry-run-absent", "ssh-ed25519 AAAAtest", dry_run=True)


if __name__ == "__main__":
    main()
