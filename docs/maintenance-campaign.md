# Personal maintenance campaign

This repository participates in Pavan's explicitly authorized 90-day documentation campaign, alongside `tpavan03/lakshya-ap-si-prep` and `tpavan03/pavan-portfolio`.

- Campaign starts **3 November 2026** in **Asia/Kolkata**.
- One repository takes a turn every two days: Saapadu, Exam Prep King, then the portfolio.
- There are **45 planned publications**, fifteen per repository. The last planned publication is **30 January 2027**.
- The campaign expires **1 February 2027**. Each workflow then disables itself using its temporary repository token.
- The workflow wakes at **08:47 and 20:47 IST** daily. The second wake retries a failed eligible day; an already completed slot produces no duplicate commit. Other days do not write files. GitHub can delay scheduled jobs.

## What gets published

The reviewed queue is `.github/maintenance/backlog.json`. Each entry contains a focused handbook guide, its destination and explicit source-code anchors. The first pending guide is checked against the current checkout before publication. Missing or renamed evidence stops the run for review. Existing guides are never overwritten.

Only a new `docs/handbook/*.md` guide, the handbook index and the campaign completion ledger may change. The pipeline does not modify application behavior, dependencies, database schemas, versions, APKs or release tags. Existing Vercel integrations may still build documentation commits to `main`.

This is a deterministic publisher for a Codex-prepared documentation backlog. It does not call a paid AI model or independently invent production code changes. Completion records and commit trailers identify the automation. Commits use the real execution time in Asia/Kolkata, Pavan's GitHub-linked author address and the GitHub Actions bot as committer. No timestamps are backdated or future-dated.

## Operate it

Open **Actions → Personal maintenance (90 days)**:

- **Run workflow**, with `dry_run` checked: validate all guide evidence and display today's eligibility without publishing anything.
- **Run workflow**, with `dry_run` unchecked: publish only if this repository's turn is due today and has not already completed. This does not advance future slots.
- **Disable workflow**: pause the campaign immediately. Re-enabling does not extend the fixed end date or replay missed days.
- Read the job summary and logs to see the local date, due status, completion count and any source changes needing review.

For local checks, run these commands sequentially from the repository root:

```bash
python3 -B -m unittest discover -s .github/maintenance -p 'test_*.py' -v
python3 -B .github/maintenance/runner.py validate --all-evidence
python3 -B .github/maintenance/runner.py plan
```

Use Python 3.11 or newer. Local publication is disabled; live writes require the scheduled or manually dispatched default-branch workflow in the authorized repository. No personal access token, SSH deployment key, AI credential or server is needed. Checkout is pinned to a full action commit. The temporary `GITHUB_TOKEN` has `contents:write` for publishing and `actions:write` only for campaign shutdown.

## Failure behavior

Failed source/link checks leave the repository untouched. Push conflicts fail without force-pushing or rewriting another change; the later same-day run starts from the new default branch. There are no empty commits or daily status-only updates. A failed day can therefore mean fewer than 45 publications; inspect failed runs rather than manufacturing a replacement contribution. There is no catch-up burst after downtime.

Future feature work should use normal review and application checks. These publication checks verify the scheduling, source references and allowed documentation changes; they do not replace application tests or establish current external exam rules, hosting prices or medical advice.
