import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


MARKER = ".dotfiles-skills.json"
OWNER = "dotfiles-skills-v1"


def component(value):
    return isinstance(value, str) and re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9 &_-]*", value)


def present(path):
    return path.exists() or path.is_symlink()


def real_directory(path):
    if present(path) and (path.is_symlink() or not path.is_dir()):
        raise ValueError(f"Expected a real directory: {path}")


def categories(generation):
    marker = generation / MARKER
    if (generation.is_symlink() or not generation.is_dir()
            or marker.is_symlink() or not marker.is_file()):
        return None
    try:
        data = json.loads(marker.read_text())
        names = data["categories"]
        if (set(data) == {"owner", "categories"} and data["owner"] == OWNER
                and isinstance(names, list) and all(component(n) for n in names)
                and len(set(names)) == len(names)
                and all((generation / n).is_dir() and not (generation / n).is_symlink()
                        for n in names)):
            return names
    except (OSError, ValueError, KeyError, TypeError):
        pass
    return None


def owned(path, generations):
    if not path.is_symlink():
        return None
    target = Path(os.readlink(path))
    if not target.is_absolute():
        return None
    try:
        if target.parent.parent.resolve() != generations:
            return None
    except (OSError, RuntimeError):
        return None
    generation = generations / target.parent.name
    if (target.name == path.name
            and target.name in (categories(generation) or [])):
        return generation
    return None


def preflight(public, generations, desired):
    real_directory(public.parent)
    real_directory(public)
    for name in desired:
        path = public / name
        if present(path) and owned(path, generations) is None:
            raise ValueError(f"Manual category collision: {path}")
    old = {}
    if public.exists():
        for path in public.iterdir():
            generation = owned(path, generations)
            if generation is not None:
                old[path.name] = generation
    return old


def resolve(record, cli, workspace):
    source = record["source"]
    project = workspace / "project"
    project.mkdir()
    env = dict(os.environ, DISABLE_TELEMETRY="1")
    try:
        result = subprocess.run(
            [cli, "add", source, "--agent", "universal", "--copy", "--yes",
             *(["--skill", *record["skills"]] if record["skills"] is not None else [])],
            cwd=project, env=env, text=True, capture_output=True, timeout=300,
        )
        if result.returncode:
            raise ValueError(f"Skills CLI failed for {source}:\n{result.stdout}{result.stderr}")
        result = subprocess.run(
            [cli, "list", "--agent", "universal", "--json"],
            cwd=project, env=env, text=True, capture_output=True, timeout=300,
        )
    except subprocess.TimeoutExpired:
        raise ValueError(f"Skills CLI timed out after 300 seconds for {source}") from None
    if result.returncode:
        raise ValueError(f"Skills CLI list failed for {source}:\n{result.stdout}{result.stderr}")
    installed = (project / ".agents/skills").resolve()
    entries = json.loads(result.stdout)
    if not isinstance(entries, list) or not entries:
        raise ValueError(f"No skills installed from {source}")
    skills = {}
    for entry in entries:
        if not isinstance(entry, dict):
            raise ValueError(f"Invalid Skills CLI record for {source}")
        name, raw_path = entry.get("name"), entry.get("path")
        if not isinstance(name, str) or not name or not isinstance(raw_path, str):
            raise ValueError(f"Invalid Skills CLI record for {source}")
        path = Path(raw_path)
        if (entry.get("scope") != "project" or not path.is_absolute()
                or path.is_symlink() or path.resolve().parent != installed
                or not path.is_dir() or not (path / "SKILL.md").is_file()
                or path.name in (".", "..")
                or not re.fullmatch(r"[A-Za-z0-9._-]+", path.name) or name in skills):
            raise ValueError(f"Invalid installed skill {name!r} at {path}")
        for payload in path.rglob("*"):
            if payload.is_symlink() and (
                    not payload.exists() or not payload.resolve().is_relative_to(path.resolve())):
                raise ValueError(f"Skill payload link escapes its directory: {payload}")
        skills[name] = path
    if {p.resolve() for p in installed.iterdir()} != {p.resolve() for p in skills.values()}:
        raise ValueError(f"Skills CLI JSON does not match installed directories for {source}")
    requested = record["skills"]
    if requested is not None:
        selected = {n.lower() for n in requested}
        if not selected.issubset({n.lower() for n in skills}):
            raise ValueError(f"Incomplete selection from {source}: requested {requested}, installed {list(skills)}")
        return {name: path for name, path in skills.items() if name.lower() in selected}
    return skills


def sync(args):
    records = json.loads(args.config.read_text())
    if not isinstance(records, list):
        raise ValueError("Source configuration must be a list")
    for record in records:
        if (not isinstance(record, dict) or not component(record.get("category"))
                or not isinstance(record.get("source"), str) or not record["source"].strip()):
            raise ValueError(f"Invalid source record: {record}")
        record.setdefault("skills", None)
        if record["skills"] is not None and (
                not isinstance(record["skills"], list)
                or any(not isinstance(n, str) or not n.strip() or n == "*" or n.startswith("-")
                       for n in record["skills"])):
            raise ValueError(f"Invalid selected names: {record['skills']}")
        source = record["source"]
        local = Path(source).expanduser()
        if source.startswith(("/", "./", "../", "~/")) or (Path.cwd() / local).exists():
            record["source"] = str((Path.cwd() / local).resolve())
        if record["source"].startswith("-"):
            raise ValueError(f"Source must not start with '-': {source}")
    home = Path(os.environ["HOME"]).resolve()
    state = Path(os.environ.get("XDG_STATE_HOME", str(home / ".local/state"))).absolute() / "dotfiles-skills"
    generations = state / "generations"
    public = home / ".agents/skills"
    desired = {r["category"] for r in records if r["skills"] != []}
    real_directory(state)
    real_directory(generations)
    generations = generations.resolve()
    state = state.resolve()
    old = preflight(public, generations, desired)
    if args.dry_run or "DRY_RUN" in os.environ:
        print(f"Would resolve sources and publish categories {sorted(desired)}; remove {sorted(set(old) - desired)}")
        return
    if not desired and not old and not state.exists():
        return
    state.mkdir(parents=True, exist_ok=True)
    lock = state / "sync.lock"
    if lock.is_symlink():
        raise ValueError(f"Lock must not be a symlink: {lock}")
    with lock.open("a") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        old = preflight(public, generations, desired)
        with tempfile.TemporaryDirectory(prefix=".stage-", dir=state) as scratch:
            workspace = Path(scratch)
            names = {}
            for index, record in enumerate(records):
                if record["skills"] == []:
                    continue
                stage = workspace / str(index)
                stage.mkdir()
                for name, path in resolve(record, args.skills_cli, stage).items():
                    if name.lower() in names:
                        raise ValueError(f"Duplicate skill {name!r}: {names[name.lower()]} and {record['source']}")
                    names[name.lower()] = record["source"]
                    destination = workspace / "merged" / record["category"] / path.name
                    if destination.exists():
                        raise ValueError(f"Installed directory collision: {destination.name}")
                    shutil.copytree(path, destination)
            old = preflight(public, generations, desired)
            if desired:
                generations.mkdir(exist_ok=True)
                prepared = workspace / "merged"
                (prepared / MARKER).write_text(json.dumps({"owner": OWNER, "categories": sorted(desired)}))
                generation = generations / f"generation-{workspace.name}"
                if present(generation):
                    raise ValueError(f"Generation already exists: {generation}")
                prepared.rename(generation)
                public.mkdir(parents=True, exist_ok=True)
                for name in sorted(desired):
                    preflight(public, generations, {name})
                    with tempfile.TemporaryDirectory(prefix=".publish-", dir=state) as temporary:
                        link = Path(temporary) / "link"
                        link.symlink_to(generation / name)
                        os.replace(link, public / name)
            for name in set(old) - desired:
                if owned(public / name, generations) != old[name]:
                    raise ValueError(f"Category changed during publication: {public / name}")
                (public / name).unlink()
            preflight(public, generations, desired)
            live = set()
            if public.exists():
                for link in public.iterdir():
                    if link.is_symlink():
                        try:
                            target = link.resolve()
                        except (OSError, RuntimeError):
                            continue
                        if target.is_relative_to(generations):
                            relative = target.relative_to(generations)
                            if relative.parts:
                                live.add(generations / relative.parts[0])
            if generations.exists():
                for candidate in generations.iterdir():
                    if candidate not in live and categories(candidate) is not None:
                        shutil.rmtree(candidate)
            print(f"Published categories {sorted(desired)}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--skills-cli", required=True)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    try:
        sync(args)
    except (OSError, ValueError, TypeError, KeyError) as error:
        print(f"dotfiles-skills-sync: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
