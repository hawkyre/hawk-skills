---
name: cap
description: Stage all changes, commit with a short message that matches the repo's existing commit style, and push. Use when the user wants to ship the current diff with no fuss.
---

# Cap

Commit and push the current working tree in one shot.

## Process

1. **Read the state** — run in parallel:
   - `git status` to see what's changed and untracked
   - `git diff` (and `git diff --staged`) to see the full diff
   - `git log -10 --oneline` to learn the repo's commit message style

2. **Match the repo's voice**:
   - Mirror tense, casing, length, and prefix conventions from recent commits
   - If recent commits are lowercase imperative ("fix banner alignment"), do that
   - If they use Conventional Commits ("feat: ..."), do that
   - If they're terse one-liners, stay terse — do not pad

3. **Draft a commit message**: one short line, summarizes the *why* of the change. No body unless the diff genuinely needs one.

   **Never include AI attribution.** No "Generated with Claude", no "🤖", no `Co-Authored-By: Claude ...` trailer, no mention of Anthropic, AI, or any model — not in the subject, not in the body, not in a trailer. Even if the repo's history contains such trailers, do not add them. The commit must read as if a human wrote it.

4. **Stage explicitly**: add the specific files you intend to commit by name. Never `git add -A` or `git add .` — that risks sweeping in `.env`, credentials, or other untracked files the user did not mean to commit.

5. **Sanity check before committing**:
   - If staged files include anything that smells like a secret (`.env*`, `*.pem`, `credentials*`, `*.key`), stop and ask
   - If the working tree is clean, say so and exit — do not create empty commits

6. **Commit and push**:
   - Commit with the drafted message
   - If the branch has no upstream, push with `-u origin <branch>`; otherwise plain `git push`
   - If pre-commit hooks fail, fix the issue and create a new commit (never `--amend`, never `--no-verify`)

7. **Handle non-fast-forward rejections** — if push is rejected because the remote moved ahead:
   - Run `git pull --rebase` to replay your local commits on top of the remote tip. This is safe — you're only rebasing **your unpushed commits**, which no one else has.
   - If the rebase hits conflicts: stop, surface the conflicting paths, and let the user resolve. Do not auto-resolve.
   - After a clean rebase, retry `git push`.
   - Do **not** fall back to a merge pull (`git pull` without `--rebase`) — that creates noisy `Merge branch 'main' of origin/...` commits, which is exactly what we're avoiding.
   - Do **not** force-push to recover from a rejection.

8. **Report**: the short SHA, the message, and the push destination. One line.

## Rules

- Never push to `main`/`master` with `--force` or `--force-with-lease`
- Never skip hooks (`--no-verify`, `--no-gpg-sign`)
- Never amend a commit that's already been pushed
- If the user is mid-rebase, mid-merge, or has conflicts, stop and surface the state instead of committing through it
