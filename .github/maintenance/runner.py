#!/usr/bin/env python3
"""Publish one source-checked handbook task when its real calendar slot is due.

Only documentation, its index and this campaign's state may be written.
This is an approved queue runner, not an unrestricted AI coding agent.
"""

from __future__ import annotations

import argparse
from datetime import date, datetime, timedelta, timezone
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import urllib.request
from zoneinfo import ZoneInfo

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
INDEX = "docs/handbook/README.md"
STATE = ".github/maintenance/state.json"
BEGIN = "<!-- maintenance:begin -->"
END = "<!-- maintenance:end -->"
AUTHOR = "Pavan <132299814+tpavan03@users.noreply.github.com>"


class MaintenanceError(Exception):
    """A condition requiring review rather than an automatic write."""


def git(root: Path, *args: str) -> str:
    # No shell, inherited date overrides, force pushes or arbitrary commands.
    env = {k: v for k, v in os.environ.items()
           if k not in ("GIT_AUTHOR_DATE", "GIT_COMMITTER_DATE")}
    env["TZ"] = "Asia/Kolkata"
    result = subprocess.run(["git", *args], cwd=root, env=env,
                            text=True, capture_output=True, check=False)
    if result.returncode:
        raise MaintenanceError(f"git {args[0]} failed; no force push attempted.")
    return result.stdout.strip()


def safe_file(root: Path, relative: str) -> Path:
    path = PurePosixPath(relative)
    if path.is_absolute() or ".." in path.parts or "\\" in relative:
        raise MaintenanceError("Unsafe repository path.")
    candidate = root.joinpath(*path.parts)
    if not candidate.resolve().is_relative_to(root.resolve()):
        raise MaintenanceError("Repository path leaves the checkout.")
    current = candidate
    while current != root:
        if current.is_symlink():
            raise MaintenanceError("Symlink paths require manual review.")
        current = current.parent
    return candidate


def read_json(path: Path) -> dict:
    try:
        value = json.loads(path.read_text())
    except (OSError, ValueError) as error:
        raise MaintenanceError(f"Cannot read {path.name}.") from error
    if not isinstance(value, dict):
        raise MaintenanceError("Expected a JSON object.")
    return value


def load(root: Path = ROOT) -> tuple[dict, dict]:
    config = read_json(root / ".github/maintenance/backlog.json")
    state = read_json(root / STATE)
    if config.get("schema") != 1 or state.get("schema") != 1:
        raise MaintenanceError("Unsupported campaign schema.")
    if config.get("repository") not in (
        "tpavan03/saapadu-tracker", "tpavan03/lakshya-ap-si-prep",
        "tpavan03/pavan-portfolio",
    ):
        raise MaintenanceError("Only the three authorized personal repos may run.")
    if config.get("timezone") != "Asia/Kolkata":
        raise MaintenanceError("Unexpected campaign timezone.")
    if config.get("start_date") != "2026-11-03":
        raise MaintenanceError("Changing the campaign window requires review.")
    if config.get("days") != 90 or config.get("interval_days") != 2:
        raise MaintenanceError("Campaign must stop after its approved 90-day window.")
    if config.get("rotation_size") != 3 or config.get("rotation_index") not in range(3):
        raise MaintenanceError("Invalid repository rotation.")
    expected_index = {"tpavan03/saapadu-tracker": 0,
                      "tpavan03/lakshya-ap-si-prep": 1,
                      "tpavan03/pavan-portfolio": 2}[config["repository"]]
    if config["rotation_index"] != expected_index:
        raise MaintenanceError("Repository has an unexpected rotation slot.")
    tasks = config.get("tasks")
    if not isinstance(tasks, list) or len(tasks) != 15:
        raise MaintenanceError("Each repository must have fifteen reviewed tasks.")
    ids, paths = set(), set()
    for task in tasks:
        if not re.fullmatch(r"[a-z][a-z0-9-]{2,70}", task.get("id", "")):
            raise MaintenanceError("Invalid task ID.")
        if not re.fullmatch(r"docs/handbook/[a-z][a-z0-9-]+\.md", task.get("path", "")):
            raise MaintenanceError("A task may only add a handbook page.")
        if task["path"] == INDEX or task["id"] in ids or task["path"] in paths:
            raise MaintenanceError("Duplicate task or protected index destination.")
        ids.add(task["id"])
        paths.add(task["path"])
        safe_file(root, task["path"])
        title, body = task.get("title", ""), task.get("body", "")
        if not title or "\n" in title or len(title) > 140:
            raise MaintenanceError("Invalid task title.")
        if not body.startswith("# ") or len(body.split()) < 75:
            raise MaintenanceError("Task must contain a useful reviewed guide.")
        if re.search(r"(?:gh[pousr]_[A-Za-z0-9]{20,}|-----BEGIN .*PRIVATE KEY-----)", body):
            raise MaintenanceError("Sensitive-looking content cannot be published.")
        evidence = task.get("evidence")
        if not isinstance(evidence, list) or not evidence:
            raise MaintenanceError("Every guide needs source evidence.")
        for source in evidence:
            relative = source.get("path", "")
            if not relative or any(part.startswith(".") for part in PurePosixPath(relative).parts):
                raise MaintenanceError("Evidence must use non-secret source paths.")
            safe_file(root, relative)
            if not isinstance(source.get("contains"), list) or not source["contains"]:
                raise MaintenanceError("Evidence needs explicit source anchors.")
    records = state.get("completed")
    if not isinstance(records, list):
        raise MaintenanceError("Invalid completion ledger.")
    completed_ids = [record.get("id") for record in records]
    completed_slots = [record.get("slot") for record in records]
    if len(completed_ids) != len(set(completed_ids)) or not set(completed_ids) <= ids:
        raise MaintenanceError("Invalid or duplicate completed task.")
    if len(completed_slots) != len(set(completed_slots)):
        raise MaintenanceError("A slot may publish at most once.")
    for record in records:
        slot = record.get("slot")
        if not isinstance(slot, int) or not 0 <= slot < 45 or slot % 3 != config["rotation_index"]:
            raise MaintenanceError("Completion outside this repository's slots.")
    index = safe_file(root, INDEX).read_text()
    if index.count(BEGIN) != 1 or index.count(END) != 1 or index.index(BEGIN) > index.index(END):
        raise MaintenanceError("Handbook index markers are missing or ambiguous.")
    return config, state


def calendar(config: dict, today: date) -> dict:
    start = date.fromisoformat(config["start_date"])
    offset = (today - start).days
    expired = offset >= config["days"]
    slot = offset // config["interval_days"]
    due = (0 <= offset < config["days"] and offset % 2 == 0
           and slot % 3 == config["rotation_index"])
    return {"date": today.isoformat(), "due": due, "expired": expired,
            "slot": slot if due else None,
            "ends_exclusive": (start + timedelta(days=90)).isoformat()}


def check_task(root: Path, task: dict) -> None:
    for source in task["evidence"]:
        path = safe_file(root, source["path"])
        if not path.is_file():
            raise MaintenanceError(f"{task['id']}: source file was moved or removed.")
        text = path.read_text()
        if not all(isinstance(anchor, str) and anchor in text for anchor in source["contains"]):
            raise MaintenanceError(f"{task['id']}: source anchors changed; review the guide.")
    # Check local Markdown links without touching the network or any secrets.
    destination = safe_file(root, task["path"])
    for link in re.findall(r"\[[^\]]+\]\(([^\s)]+)\)", task["body"]):
        if re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", link) or link.startswith("#"):
            continue
        target = (destination.parent / link.split("#", 1)[0]).resolve()
        if not target.is_relative_to(root.resolve()) or not target.is_file():
            raise MaintenanceError(f"{task['id']}: broken local documentation link.")


def choose(root: Path, config: dict, state: dict, slot: int) -> dict | None:
    if any(record["slot"] == slot for record in state["completed"]):
        return None
    done = {record["id"] for record in state["completed"]}
    for task in config["tasks"]:
        if task["id"] not in done:
            # A source change must be reviewed, never silently published.
            check_task(root, task)
            if safe_file(root, task["path"]).exists():
                raise MaintenanceError("The next guide already exists; preserve it and review the queue.")
            return task
    return None


def index_text(existing: str, config: dict, state: dict) -> str:
    done = {record["id"]: record for record in state["completed"]}
    lines = ["", f"Published guides: **{len(done)} / 15**.", "",
             "| Guide | Status |", "| --- | --- |"]
    for task in config["tasks"]:
        title = task["title"].replace("|", "\\|")
        if task["id"] in done:
            record = done[task["id"]]
            lines.append(f"| [{title}]({Path(task['path']).name}) | Published {record['published_date']} |")
        else:
            lines.append(f"| {title} | Queued |")
    lines += ["", "Source anchors and local links are checked before each publication.", ""]
    before, remainder = existing.split(BEGIN)
    _, after = remainder.split(END)
    return before + BEGIN + "\n".join(lines) + END + after


def apply_task(root: Path, config: dict, state: dict, task: dict,
               plan: dict, now: datetime, source_commit: str) -> list[str]:
    if not plan["due"] or any(r["slot"] == plan["slot"] for r in state["completed"]):
        raise MaintenanceError("An unscheduled or repeated slot cannot write.")
    check_task(root, task)
    path = safe_file(root, task["path"])
    if path.exists():
        raise MaintenanceError("Refusing to overwrite an existing guide.")
    record = {"id": task["id"], "slot": plan["slot"],
              "published_date": plan["date"], "published_at": now.isoformat(),
              "source_commit": source_commit}
    next_state = {"schema": 1, "completed": [*state["completed"], record]}
    current_index = safe_file(root, INDEX).read_text()
    updated_index = index_text(current_index, config, next_state)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(task["body"].rstrip() + "\n")
    safe_file(root, STATE).write_text(json.dumps(next_state, indent=2) + "\n")
    safe_file(root, INDEX).write_text(updated_index)
    return [task["path"], INDEX, STATE]


def authorized_checkout(root: Path, config: dict) -> None:
    if os.environ.get("GITHUB_ACTIONS") != "true":
        raise MaintenanceError("Publishing is restricted to the hosted workflow. Use validate locally.")
    if os.environ.get("GITHUB_REPOSITORY") != config["repository"]:
        raise MaintenanceError("Repository identity mismatch; forks cannot publish.")
    if os.environ.get("GITHUB_EVENT_NAME") not in ("schedule", "workflow_dispatch"):
        raise MaintenanceError("Only scheduled or explicit manual runs may publish.")
    if os.environ.get("GITHUB_REF") != "refs/heads/main":
        raise MaintenanceError("Publishing is restricted to the default main branch.")
    if git(root, "status", "--porcelain"):
        raise MaintenanceError("Checkout is not clean; no edits will be overwritten.")
    remote = git(root, "remote", "get-url", "origin").removesuffix(".git")
    if remote not in ("https://github.com/" + config["repository"],
                       "git@github.com:" + config["repository"]):
        raise MaintenanceError("Unexpected git remote.")


def publish(root: Path, config: dict, state: dict, now: datetime) -> str:
    authorized_checkout(root, config)
    plan = calendar(config, now.astimezone(ZoneInfo(config["timezone"])).date())
    if not plan["due"]:
        return "No publication due today."
    task = choose(root, config, state, plan["slot"])
    if task is None:
        return "This slot is already complete; no duplicate commit."
    before = git(root, "rev-parse", "HEAD")
    paths = apply_task(root, config, state, task, plan, now, before)
    dirty = set(git(root, "diff", "--name-only").splitlines())
    untracked = set(git(root, "ls-files", "--others", "--exclude-standard").splitlines())
    if dirty | untracked != set(paths):
        raise MaintenanceError("Unexpected file changes; refusing to commit.")
    git(root, "diff", "--check")
    git(root, "add", "--", *paths)
    message = (f"docs: {task['title']}\n\n"
               f"Maintenance-Task: {task['id']}\n"
               f"Maintenance-Slot: {plan['slot'] + 1}/45\n"
               "Automated-By: personal-maintenance GitHub Actions workflow")
    git(root, "-c", "user.name=github-actions[bot]", "-c",
        "user.email=41898282+github-actions[bot]@users.noreply.github.com",
        "commit", "--author", AUTHOR, "-m", message)
    # A competing push is a safe failure, never a rebase or history rewrite.
    git(root, "push", "origin", "HEAD:main")
    return f"Published {task['id']} in slot {plan['slot'] + 1}/45: {git(root, 'rev-parse', 'HEAD')}"


def disable_expired(config: dict, now: datetime) -> str:
    plan = calendar(config, now.astimezone(ZoneInfo(config["timezone"])).date())
    if not plan["expired"]:
        raise MaintenanceError("Cannot disable a campaign before its end date.")
    if os.environ.get("GITHUB_REPOSITORY") != config["repository"]:
        raise MaintenanceError("Repository identity mismatch.")
    token = os.environ.get("GITHUB_TOKEN")
    if not token:
        raise MaintenanceError("Missing ephemeral workflow token.")
    request = urllib.request.Request(
        f"https://api.github.com/repos/{config['repository']}/actions/workflows/personal-maintenance.yml/disable",
        method="PUT", headers={"Authorization": "Bearer " + token,
                               "Accept": "application/vnd.github+json",
                               "X-GitHub-Api-Version": "2022-11-28"})
    with urllib.request.urlopen(request, timeout=20) as response:
        if response.status != 204:
            raise MaintenanceError("Workflow disable request did not succeed.")
    return "90-day window ended; this scheduled workflow is now disabled."


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("validate", "plan", "publish", "disable-expired"))
    parser.add_argument("--all-evidence", action="store_true")
    args = parser.parse_args()
    config, state = load()
    now = datetime.now(timezone.utc)
    plan = calendar(config, now.astimezone(ZoneInfo(config["timezone"])).date())
    if args.command == "validate":
        if args.all_evidence:
            for task in config["tasks"]:
                check_task(ROOT, task)
        print(f"Validated 15 reviewed tasks for {config['repository']}.")
    elif args.command == "plan":
        plan["already_published"] = any(r["slot"] == plan["slot"] for r in state["completed"])
        if os.environ.get("GITHUB_OUTPUT"):
            with open(os.environ["GITHUB_OUTPUT"], "a") as output:
                for key in ("due", "expired"):
                    output.write(f"{key}={str(plan[key]).lower()}\n")
        print(json.dumps(plan, indent=2))
        if os.environ.get("GITHUB_STEP_SUMMARY"):
            with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as summary:
                summary.write(f"## Personal maintenance\n\nRepository: `{config['repository']}`\n\n"
                              f"Local date: {plan['date']} (Asia/Kolkata)\n\n"
                              f"Due: {plan['due']}; expired: {plan['expired']}; already published: {plan['already_published']}\n\n"
                              f"Completed guides: {len(state['completed'])}/15. Campaign stops 1 February 2027.\n")
    elif args.command == "publish":
        print(publish(ROOT, config, state, now))
    else:
        print(disable_expired(config, now))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (MaintenanceError, OSError, ValueError) as error:
        print(f"Maintenance stopped: {error}", file=sys.stderr)
        sys.exit(1)
