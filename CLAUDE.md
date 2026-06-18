# Project Instructions

## Git Commits

- **Do not commit directly to the `main` branch.** The `main` branch is treated as unstable and must not receive direct commits.
- Before committing, always create a new branch. The branch name **must** start with `CAP-{NUMBER}-` (where `{NUMBER}` is the task/ticket number), followed by a short description of the task (for example, `CAP-123-fix-login-bug` or `CAP-456-export-csv`).
- Commit your changes to that new branch, then push the branch to the remote repository.

## Commit Message Format

- The commit message **must** start with `CAP-{NUMBER}:`, followed by the message.
  - `CAP-{NUMBER}` references the related task/ticket number.
  - `<message>` is a concise, imperative description of the change (for example, "add ngrok tunnel to launcher").
- Format: `CAP-{NUMBER}: <message>`
- Example: `CAP-123: add ngrok tunnel to launcher`
- Keep the summary line under ~72 characters. Add a blank line and a longer body only if more detail is needed.

## CAP Number Sequence

- The `{NUMBER}` used in branch names and commit messages is a sequential counter, maintained separately for each repository.
- **Before committing, determine the next number from git history:** scan the repository's existing commit messages (and branch names) for the highest `CAP-{NUMBER}` already used, then add `1`.
- If the repository has no `CAP-{NUMBER}` yet, start at `1`.
- The number always **increments by `1`** for each new commit (`CAP-1`, `CAP-2`, `CAP-3`, …).
