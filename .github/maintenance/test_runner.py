from copy import deepcopy
from datetime import date, datetime, timedelta, timezone
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch, MagicMock

spec = importlib.util.spec_from_file_location("maintenance_runner", Path(__file__).with_name("runner.py"))
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class CampaignTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / ".github/maintenance").mkdir(parents=True)
        (self.root / "docs/handbook").mkdir(parents=True)
        (self.root / "src").mkdir()
        (self.root / "src/app.py").write_text("def save_record():\n    return True\n")
        (self.root / runner.INDEX).write_text("# Handbook\n\nHuman notes stay.\n" + runner.BEGIN + "\n" + runner.END + "\n")
        body = ("# Save a record\n\n" +
                "Read the current source before changing the persistence path. " * 12 +
                "\n\n[Source](../../src/app.py)\n")
        self.config = {"schema": 1, "repository": "tpavan03/saapadu-tracker",
                       "timezone": "Asia/Kolkata", "start_date": "2026-11-03",
                       "days": 90, "interval_days": 2, "daily_from": "2026-11-24",
                       "rotation_size": 3,
                       "rotation_index": 0, "tasks": [
                           {"id": f"guide-{i:02d}", "title": f"Guide {i}",
                            "path": f"docs/handbook/guide-{i:02d}.md", "body": body,
                            "evidence": [{"path": "src/app.py", "contains": ["def save_record"]}]}
                           for i in range(30)]}
        self.state = {"schema": 1, "completed": []}
        self.save()

    def save(self):
        (self.root / ".github/maintenance/backlog.json").write_text(json.dumps(self.config))
        (self.root / runner.STATE).write_text(json.dumps(self.state))

    def test_exactly_80_slots_alternate_then_daily_rotation(self):
        slots = []
        start = date(2026, 11, 3)
        for day in range(90):
            due = []
            for repo in range(3):
                config = {**self.config, "rotation_index": repo}
                plan = runner.calendar(config, start + timedelta(days=day))
                if plan["due"]:
                    due.append(repo)
                    slots.append(plan["slot"])
            if day < 21:
                # Alternate-day schedule before 24 November stays unchanged.
                self.assertEqual(len(due), 1 if day % 2 == 0 else 0)
                if due:
                    self.assertEqual(due[0], (day // 2) % 3)
            else:
                self.assertEqual(len(due), 1)
                self.assertEqual(due[0], (11 + day - 21) % 3)
        self.assertEqual(slots, list(range(runner.TOTAL_SLOTS)))
        self.assertEqual(runner.TOTAL_SLOTS, 80)

    def test_no_slot_is_assigned_twice_across_repositories(self):
        per_repo = [runner.repository_slots({**self.config, "rotation_index": repo}) for repo in range(3)]
        combined = [slot for slots in per_repo for slot in slots]
        self.assertEqual(sorted(combined), list(range(80)))
        self.assertEqual(len(combined), len(set(combined)))
        daily = [[slot for slot in slots if slot >= 11] for slots in per_repo]
        self.assertEqual([len(slots) for slots in daily], [23, 23, 23])

    def test_completed_alternate_day_slots_remain_valid(self):
        history = {0: [(0, "2026-11-03"), (3, "2026-11-09"), (6, "2026-11-15"), (9, "2026-11-21")],
                   1: [(1, "2026-11-05"), (4, "2026-11-11"), (7, "2026-11-17"), (10, "2026-11-23")],
                   2: [(5, "2026-11-13"), (8, "2026-11-19")]}
        for repo, records in history.items():
            config = {**self.config, "rotation_index": repo}
            for slot, day in records:
                plan = runner.calendar(config, date.fromisoformat(day))
                self.assertTrue(plan["due"])
                self.assertEqual(plan["slot"], slot)
        # The missed portfolio slot is never offered again.
        portfolio = {**self.config, "rotation_index": 2}
        self.assertEqual(runner.calendar(portfolio, date(2026, 11, 7))["slot"], 2)
        for day in range(21, 90):
            plan = runner.calendar(portfolio, date(2026, 11, 3) + timedelta(days=day))
            self.assertNotEqual(plan["slot"], 2)
        self.config["rotation_index"] = 0
        self.state["completed"] = [{"id": f"guide-{i:02d}", "slot": slot}
                                   for i, (slot, _) in enumerate(history[0])]
        self.save()
        runner.load(self.root)

    def test_daily_switch_starts_today_with_the_portfolio(self):
        self.assertFalse(runner.calendar({**self.config, "rotation_index": 1}, date(2026, 11, 22))["due"])
        for repo, expected in ((0, False), (1, False), (2, True)):
            plan = runner.calendar({**self.config, "rotation_index": repo}, date(2026, 11, 24))
            self.assertEqual(plan["due"], expected)
        self.assertEqual(runner.calendar({**self.config, "rotation_index": 2}, date(2026, 11, 24))["slot"], 11)
        self.assertEqual(runner.calendar({**self.config, "rotation_index": 0}, date(2026, 11, 25))["slot"], 12)
        self.assertEqual(runner.calendar({**self.config, "rotation_index": 1}, date(2026, 11, 26))["slot"], 13)
        now = datetime(2026, 11, 23, 21, 47, tzinfo=timezone.utc)
        self.assertEqual(now.astimezone(runner.ZoneInfo("Asia/Kolkata")).date(), date(2026, 11, 24))

    def test_last_slot_is_79_on_31_january_then_expires(self):
        plan = runner.calendar({**self.config, "rotation_index": 1}, date(2027, 1, 31))
        self.assertTrue(plan["due"])
        self.assertEqual(plan["slot"], 79)
        for repo in range(3):
            config = {**self.config, "rotation_index": repo}
            for day in (date(2027, 2, 1), date(2027, 2, 2)):
                self.assertTrue(runner.calendar(config, day)["expired"])
                self.assertFalse(runner.calendar(config, day)["due"])
            self.assertFalse(runner.calendar(config, date(2027, 1, 31))["expired"])

    def test_too_few_tasks_for_remaining_slots_are_rejected(self):
        self.config["tasks"] = self.config["tasks"][:22]
        self.save()
        with self.assertRaisesRegex(runner.MaintenanceError, "Too few reviewed tasks"):
            runner.load(self.root)
        self.config["tasks"] = self.config["tasks"][:23] + [deepcopy(self.config["tasks"][0])]
        self.config["tasks"][-1].update(id="guide-extra", path="docs/handbook/guide-extra.md")
        self.save()
        runner.load(self.root)

    def test_cadence_date_and_slot_bound_cannot_change(self):
        for value in ("2026-11-25", "2026-11-01", None):
            with self.subTest(value=value):
                self.config["daily_from"] = value
                self.save()
                with self.assertRaisesRegex(runner.MaintenanceError, "daily cadence"):
                    runner.load(self.root)
        self.config["daily_from"] = "2026-11-24"
        self.state["completed"] = [{"id": "guide-00", "slot": 81}]
        self.save()
        with self.assertRaisesRegex(runner.MaintenanceError, "outside"):
            runner.load(self.root)

    def test_this_repository_has_a_task_for_every_remaining_slot(self):
        config, state = runner.load(runner.ROOT)
        done = {record["id"] for record in state["completed"]}
        used = {record["slot"] for record in state["completed"]}
        pending = [task for task in config["tasks"] if task["id"] not in done]
        remaining = [slot for slot in runner.repository_slots(config) if slot >= 11 and slot not in used]
        self.assertGreaterEqual(len(pending), len(remaining))
        self.assertEqual(len(remaining), 23 - sum(slot >= 11 for slot in used))

    def test_window_crosses_month_and_year_and_stops_at_day_90(self):
        self.assertFalse(runner.calendar(self.config, date(2026, 11, 2))["due"])
        for index in range(3):
            config = {**self.config, "rotation_index": index}
            self.assertEqual(runner.calendar(config, date(2027, 1, 31))["due"], index == 1)
            for end in (date(2027, 2, 1), date(2030, 1, 1)):
                plan = runner.calendar(config, end)
                self.assertTrue(plan["expired"])
                self.assertFalse(plan["due"])
        self.assertEqual(runner.calendar(self.config, date(2026, 11, 3))["ends_exclusive"], "2027-02-01")

    def test_india_calendar_handles_utc_previous_day(self):
        now = datetime(2026, 11, 2, 19, 0, tzinfo=timezone.utc)
        local_day = now.astimezone(runner.ZoneInfo("Asia/Kolkata")).date()
        self.assertEqual(local_day, date(2026, 11, 3))
        self.assertTrue(runner.calendar(self.config, local_day)["due"])

    def test_valid_manifest_and_all_source_links(self):
        config, _ = runner.load(self.root)
        for task in config["tasks"]:
            runner.check_task(self.root, task)

    def test_source_drift_stops_before_any_write(self):
        (self.root / "src/app.py").write_text("renamed and changed\n")
        with self.assertRaisesRegex(runner.MaintenanceError, "anchors changed"):
            runner.choose(self.root, self.config, self.state, 0)
        self.assertEqual(list((self.root / "docs/handbook").glob("guide*")), [])

    def test_broken_links_require_review(self):
        task = deepcopy(self.config["tasks"][0])
        task["body"] += "\n[Missing](../../missing.py)"
        with self.assertRaisesRegex(runner.MaintenanceError, "broken local"):
            runner.check_task(self.root, task)

    def test_path_traversal_and_symlinks_are_rejected(self):
        for value in ("../outside", "/tmp/outside", "docs/../../outside", "docs\\outside"):
            with self.subTest(value=value), self.assertRaises(runner.MaintenanceError):
                runner.safe_file(self.root, value)
        (self.root / "docs/handbook/link.md").symlink_to(self.root / "src/app.py")
        with self.assertRaisesRegex(runner.MaintenanceError, "Symlink"):
            runner.safe_file(self.root, "docs/handbook/link.md")

    def test_manifest_cannot_change_code_or_extend_campaign(self):
        for key, value in (("days", 91), ("start_date", "2027-01-01"), ("repository", "someone/other")):
            with self.subTest(key=key):
                original = self.config[key]
                self.config[key] = value
                self.save()
                with self.assertRaises(runner.MaintenanceError):
                    runner.load(self.root)
                self.config[key] = original
        for target in ("src/app.py", ".github/workflows/unsafe.yml", runner.INDEX):
            self.config["tasks"][0]["path"] = target
            self.save()
            with self.assertRaises(runner.MaintenanceError):
                runner.load(self.root)

    def test_publish_changes_only_guide_index_and_ledger(self):
        plan = runner.calendar(self.config, date(2026, 11, 3))
        task = runner.choose(self.root, self.config, self.state, plan["slot"])
        now = datetime(2026, 11, 2, 19, 0, tzinfo=timezone.utc)
        changed = runner.apply_task(self.root, self.config, self.state, task, plan, now, "a" * 40)
        self.assertEqual(set(changed), {task["path"], runner.INDEX, runner.STATE})
        config, state = runner.load(self.root)
        self.assertIsNone(runner.choose(self.root, config, state, 0))
        self.assertEqual(state["completed"][0]["published_at"], now.isoformat())
        index = (self.root / runner.INDEX).read_text()
        self.assertIn("Human notes stay.", index)
        self.assertIn("[Guide 0](guide-00.md)", index)
        self.assertNotIn("[Guide 1]", index)
        self.assertEqual((self.root / "src/app.py").read_text(), "def save_record():\n    return True\n")

    def test_existing_guide_is_never_overwritten(self):
        target = self.root / self.config["tasks"][0]["path"]
        target.write_text("Owner's new guide")
        with self.assertRaisesRegex(runner.MaintenanceError, "already exists"):
            runner.choose(self.root, self.config, self.state, 0)
        self.assertEqual(target.read_text(), "Owner's new guide")

    def test_duplicate_completed_slots_are_rejected(self):
        self.state["completed"] = [{"id": "guide-00", "slot": 0}, {"id": "guide-01", "slot": 0}]
        self.save()
        with self.assertRaisesRegex(runner.MaintenanceError, "at most once"):
            runner.load(self.root)

    def test_unscheduled_apply_cannot_write(self):
        plan = runner.calendar(self.config, date(2026, 11, 4))
        with self.assertRaisesRegex(runner.MaintenanceError, "unscheduled"):
            runner.apply_task(self.root, self.config, self.state, self.config["tasks"][0], plan,
                              datetime.now(timezone.utc), "a" * 40)

    def test_forks_wrong_branches_and_pull_requests_cannot_publish(self):
        base = {"GITHUB_ACTIONS": "true", "GITHUB_REPOSITORY": self.config["repository"],
                "GITHUB_EVENT_NAME": "schedule", "GITHUB_REF": "refs/heads/main"}
        for key, value in (("GITHUB_ACTIONS", "false"), ("GITHUB_REPOSITORY", "fork/saapadu"),
                           ("GITHUB_EVENT_NAME", "pull_request"), ("GITHUB_REF", "refs/heads/other")):
            with self.subTest(key=key), patch.dict(os.environ, {**base, key: value}, clear=True):
                with self.assertRaises(runner.MaintenanceError):
                    runner.authorized_checkout(self.root, self.config)

    def test_git_removes_inherited_fake_dates_and_never_uses_shell(self):
        result = MagicMock(returncode=0, stdout="ok")
        with patch.dict(os.environ, {"GIT_AUTHOR_DATE": "old", "GIT_COMMITTER_DATE": "old"}), \
                patch.object(runner.subprocess, "run", return_value=result) as command:
            runner.git(self.root, "rev-parse", "HEAD")
        self.assertNotIn("GIT_AUTHOR_DATE", command.call_args.kwargs["env"])
        self.assertNotIn("GIT_COMMITTER_DATE", command.call_args.kwargs["env"])
        self.assertEqual(command.call_args.kwargs["env"]["TZ"], "Asia/Kolkata")
        self.assertIsInstance(command.call_args.args[0], list)
        self.assertNotIn("shell", command.call_args.kwargs)

    def test_push_conflict_fails_without_force_or_retrying_over_owner_changes(self):
        calls = []
        def fake_git(root, *args):
            calls.append(args)
            if args[:2] == ("rev-parse", "HEAD"):
                return "a" * 40
            if args[:2] == ("diff", "--name-only"):
                return runner.INDEX + "\n" + runner.STATE
            if args[:2] == ("ls-files", "--others"):
                return self.config["tasks"][0]["path"]
            if args[0] == "push":
                raise runner.MaintenanceError("git push failed; no force push attempted.")
            return ""
        with patch.object(runner, "authorized_checkout"), patch.object(runner, "git", side_effect=fake_git):
            with self.assertRaisesRegex(runner.MaintenanceError, "push failed"):
                runner.publish(self.root, self.config, self.state, datetime(2026, 11, 3, 4, tzinfo=timezone.utc))
        self.assertEqual(sum(args[0] == "push" for args in calls), 1)
        self.assertFalse(any("--force" in args or "--force-with-lease" in args for args in calls))
        commit = next(args for args in calls if "commit" in args)
        self.assertIn(runner.AUTHOR, commit)
        self.assertIn("Maintenance-Slot: 1/80", commit[-1])
        self.assertIn("user.name=github-actions[bot]", commit)

    def test_campaign_cannot_disable_early_and_disables_only_its_workflow(self):
        with self.assertRaisesRegex(runner.MaintenanceError, "before its end"):
            runner.disable_expired(self.config, datetime(2027, 1, 31, tzinfo=timezone.utc))
        response = MagicMock()
        response.__enter__.return_value.status = 204
        with patch.dict(os.environ, {"GITHUB_REPOSITORY": self.config["repository"], "GITHUB_TOKEN": "fixture-only"}), \
                patch.object(runner.urllib.request, "urlopen", return_value=response) as request:
            message = runner.disable_expired(self.config, datetime(2027, 2, 1, tzinfo=timezone.utc))
        self.assertIn("disabled", message)
        sent = request.call_args.args[0]
        self.assertTrue(sent.full_url.endswith("/actions/workflows/personal-maintenance.yml/disable"))
        self.assertEqual(sent.method, "PUT")


if __name__ == "__main__":
    unittest.main()
