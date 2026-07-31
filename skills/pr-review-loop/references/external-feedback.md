# External PR feedback

Run after the internal reviewers finish, so bot latency overlaps with review work rather than adding to it.

## 1. Take the cutoff timestamp

Everything older than the last commit has already been answered by it.

```bash
git log --format="%cI" -1 HEAD | python3 -c "import sys, datetime; dt=datetime.datetime.fromisoformat(sys.stdin.read().strip()); print(dt.astimezone(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))"
```

## 2. Fetch feedback newer than it

```bash
gh api repos/{owner}/{repo}/pulls/{number}/comments --jq '[.[] | select(.created_at > "UTC_COMMIT_DATE")]'
gh api repos/{owner}/{repo}/pulls/{number}/reviews --jq '[.[] | select(.submitted_at > "UTC_COMMIT_DATE")]'
gh api repos/{owner}/{repo}/issues/{number}/comments --jq '[.[] | select(.created_at > "UTC_COMMIT_DATE")]'
```

## 3. Let the bots finish

Check status with `gh pr checks {number} --repo {owner}/{repo}`.

Review bots re-run on every push and take minutes. Treat a check as pending when it is `pending`/`in_progress` for the latest commit **or** has not started for the newest push yet, and poll every 60 seconds for up to ~10 minutes. Silence from a bot that is still running is not approval — that is the whole reason this step waits.

## 4. Read the results

Once every review-bot check for the latest commit has completed, fetch again (step 2). If there is still nothing, wait 60 seconds and retry up to 5 times, then continue on internal findings alone. A passing bot check with no comments counts as a completed external review for this iteration.

A **failed** review check needs its log inspected before it counts as feedback. Quota, auth, and infrastructure failures are caveats for the final summary, not code findings.
