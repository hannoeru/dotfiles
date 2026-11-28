#!/usr/bin/env python3

import atexit
import base64
import json
import os
from pathlib import Path
import shutil
import socket
import struct
import subprocess
import sys
import tempfile
import threading


def frame(payload):
    return struct.pack(">I", len(payload)) + payload


def broken_agent(path, public_key):
    # Lists the signing key, like the 1Password agent, then drops the sign request.
    blob = base64.b64decode(public_key.split()[1])
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(path)
    server.listen()

    def answer(connection):
        with connection:
            while (head := connection.recv(4)) and len(head) == 4:
                request = connection.recv(struct.unpack(">I", head)[0])
                if request[:1] != b"\x0b":
                    return
                connection.sendall(frame(b"\x0c" + struct.pack(">I", 1) + frame(blob) + frame(b"git-signing")))

    def serve():
        while True:
            answer(server.accept()[0])

    threading.Thread(target=serve, daemon=True).start()


def main():
    if len(sys.argv) != 2:
        sys.exit(f"Usage: {sys.argv[0]} EVALUATED_SIGNING_KEY_SCRIPT")
    activation = Path(sys.argv[1]).resolve(strict=True)
    bash = shutil.which("bash")
    git = shutil.which("git")
    ssh_keygen = shutil.which("ssh-keygen")
    if not bash or not git or not ssh_keygen:
        sys.exit("bash (4.2 or later), git, and ssh-keygen must be on PATH")

    with tempfile.TemporaryDirectory(prefix="signing-key-test-") as directory:
        root = Path(directory)
        bin_dir = root / "bin"
        bin_dir.mkdir()
        for name in ("cut", "mkdir", "mktemp", "mv", "rm"):
            command = shutil.which(name)
            if not command:
                sys.exit(f"{name} must be on PATH")
            (bin_dir / name).symlink_to(command)

        keys = root / "keys"
        keys.mkdir()
        for name in ("signing", "other"):
            subprocess.run(
                [ssh_keygen, "-q", "-t", "ed25519", "-N", "", "-C", name, "-f", str(keys / name)],
                check=True,
            )
        private = (keys / "signing").read_text()
        public = (keys / "signing.pub").read_text().strip()

        op = bin_dir / "op"
        op.write_text(
            f"#!{sys.executable}\n"
            "import json, os, sys\n"
            "args = sys.argv[1:]\n"
            "with open(os.environ['TEST_OP_LOG'], 'a') as log:\n"
            "    log.write(json.dumps(args) + '\\n')\n"
            "if args == ['account', 'get']:\n"
            "    sys.exit(1 if os.environ['TEST_MODE'] == 'no-account' else 0)\n"
            "if args[:2] == ['item', 'get'] and args[3:] == ['--reveal', '--format', 'json']:\n"
            "    if os.environ['TEST_MODE'] == 'fetch-failure':\n"
            "        sys.exit(1)\n"
            "    field = {'id': 'private_key', 'label': '秘密鍵', 'value': '-----BEGIN PRIVATE KEY-----'}\n"
            "    if os.environ['TEST_MODE'] != 'no-openssh-format':\n"
            "        field['ssh_formats'] = {'openssh': {'value': open(os.environ['TEST_PRIVATE']).read()}}\n"
            "    print(json.dumps({'fields': [\n"
            "        {'id': 'public_key', 'label': '公開鍵', 'value': os.environ['TEST_PUBLIC']}, field,\n"
            "    ]}))\n"
            "else:\n"
            "    sys.exit('Unexpected fake op arguments')\n",
            encoding="utf-8",
        )
        op.chmod(0o700)

        def run(name, mode="success", existing=False, dry_run=False):
            home = root / name
            ssh_dir = home / ".ssh"
            ssh_dir.mkdir(parents=True)
            temporary = home / "tmp"
            temporary.mkdir()
            target = home / ".config/git/signing.gitconfig"
            key_file = ssh_dir / "git-signing"
            previous = b"[user]\n\tsigningkey = previous-key\n"
            if existing:
                target.parent.mkdir(parents=True)
                target.write_bytes(previous)
            log = home / "op.log"
            served = keys / ("other" if mode == "mismatch" else "signing")
            env = {
                "HOME": str(home),
                "PATH": str(bin_dir),
                "TMPDIR": str(temporary),
                "GIT_CONFIG_NOSYSTEM": "1",
                "GIT_CONFIG_GLOBAL": os.devnull,
                "TEST_OP_LOG": str(log),
                "TEST_MODE": mode,
                "TEST_PUBLIC": public,
                "TEST_PRIVATE": str(served),
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
            assert private not in result.stdout + result.stderr, f"{name}: private key printed"

            if dry_run or mode != "success":
                if existing:
                    assert target.read_bytes() == previous, name
                else:
                    assert not target.exists(), name
                assert not list(ssh_dir.iterdir()), f"{name}: {list(ssh_dir.iterdir())}"
                if not dry_run:
                    assert "warning:" in result.stderr, result
            else:
                assert key_file.read_text().strip() == private.strip(), name
                assert key_file.stat().st_mode & 0o777 == 0o600, oct(key_file.stat().st_mode)
                assert (ssh_dir / "git-signing.pub").read_text().strip() == public, name
                assert sorted(p.name for p in ssh_dir.iterdir()) == ["git-signing", "git-signing.pub"], name

                def config(*args):
                    return subprocess.check_output(
                        [git, "config", "--file", str(target), *args], env=env,
                    )

                names = config("--name-only", "--list").decode().splitlines()
                assert sorted(names) == sorted([
                    "user.signingkey", "commit.gpgsign", "gpg.format", "gpg.ssh.program",
                ]), f"{name}: unexpected config keys: {names}"
                assert config("--get", "user.signingkey") == f"{key_file}\n".encode(), name
                assert config("--get", "commit.gpgsign") == b"true\n", name
                assert config("--get", "gpg.format") == b"ssh\n", name

                repo = home / "repo"
                agent = Path(tempfile.mkdtemp(prefix="agent-", dir="/tmp")) / "sock"
                atexit.register(shutil.rmtree, agent.parent, True)
                broken_agent(str(agent), public)
                git_env = {
                    "HOME": str(home),
                    "PATH": os.environ["PATH"],
                    "GIT_CONFIG_NOSYSTEM": "1",
                    "GIT_CONFIG_GLOBAL": str(target),
                    "SSH_AUTH_SOCK": str(agent),
                }
                allowed = home / "allowed_signers"
                allowed.write_text(f"t@example.invalid {public}\n")

                def repo_git(*args):
                    return subprocess.run(
                        [git, "-C", str(repo), "-c", "user.name=t", "-c", "user.email=t@example.invalid", *args],
                        env=git_env, capture_output=True, text=True, check=True,
                    ).stdout

                subprocess.run([git, "init", "-q", "-b", "main", str(repo)], env=git_env, check=True)
                repo_git("commit", "-q", "--allow-empty", "-m", "signed")
                status = repo_git("-c", f"gpg.ssh.allowedSignersFile={allowed}", "log", "-1", "--format=%G?")
                assert status.strip() == "G", f"{name}: signature status {status!r}"
            assert not list(temporary.iterdir()), name
            print(f"PASS {name}")

        run("fresh")
        run("replace-existing", existing=True)
        run("mismatch", mode="mismatch", existing=True)
        run("no-openssh-format", mode="no-openssh-format", existing=True)
        run("no-account", mode="no-account", existing=True)
        run("fetch-failure", mode="fetch-failure", existing=True)
        run("dry-run-existing", existing=True, dry_run=True)
        run("dry-run-absent", dry_run=True)


if __name__ == "__main__":
    main()
