---
description: Merge PR with interactive blocker resolution, safety checkpoints, and contributor messaging
allowed-tools:
  - Bash
  - Read
  - AskUserQuestion
---

# /pr-merge - Interactive PR Merge

An intelligent merge assistant that handles all PR scenarios safely, with clear communication to contributors.

{{#if versionControl.owner}}

## Usage

```
/pr-merge                    # Show menu of all open PRs
/pr-merge 42                 # Merge PR #42 directly
/pr-merge 42 --worktree      # Test PR #42 in isolated worktree first
/pr-merge --dry-run          # Preview only, no changes
```

### Worktree Test Mode

Use `--worktree` or select **[W]** during merge to:
- Run security scan on PR changes
- Create isolated worktree for testing
- Resolve conflicts safely before merging
- Test features without affecting your main repo

---

## PHASE 0: OPEN PR MENU (Default when no args)

**When `/pr-merge` is called without arguments or a PR number, show an interactive menu of all open PRs.**

**Step 0.1: Fetch all open PRs with details**

```bash
gh pr list --repo {{versionControl.owner}}/{{versionControl.repo}} --state open --json number,title,body,createdAt,author,isDraft,mergeable,mergeStateStatus,reviewDecision,statusCheckRollup,additions,deletions,changedFiles --limit 20
```

**Step 0.2: Display the PR selection menu**

Format each PR as a stacked card (mobile-friendly, no word wrapping):

| Field | Content |
|-------|---------|
| **Header** | Selection #, PR number, Date (MM/DD) |
| **Author** | @username |
| **Description** | 15-20 word summary (multi-line ok) |
| **Status** | Ready/Draft/Conflicts/Behind |
| **Issues** | 3-5 word bullet points per issue |

**Card format (stacked rows, max 40 chars wide):**

```
📋 Open Pull Requests

┌────────────────────────────────────┐
│ [1] #42                     01/15  │
│ @johndoe                           │
├────────────────────────────────────┤
│ Add JWT auth flow with             │
│ refresh tokens for secure          │
│ API access and session mgmt        │
├────────────────────────────────────┤
│ Status: Ready                      │
│ • CI passing                       │
│ • 2 approvals                      │
│ • Ready to merge                   │
└────────────────────────────────────┘

┌────────────────────────────────────┐
│ [2] #38                     01/12  │
│ @janesmith                         │
├────────────────────────────────────┤
│ Fix memory leak in cache           │
│ manager causing high CPU           │
│ usage on large datasets            │
├────────────────────────────────────┤
│ Status: Behind                     │
│ • Update branch                    │
│ • Pending review                   │
└────────────────────────────────────┘

┌────────────────────────────────────┐
│ [3] #35                     01/08  │
│ @contributor42                     │
├────────────────────────────────────┤
│ Refactor database queries          │
│ for better performance on          │
│ large result sets                  │
├────────────────────────────────────┤
│ Status: Conflicts                  │
│ • Resolve conflicts                │
│ • CI failing                       │
└────────────────────────────────────┘

Enter number (or q to quit):

───────────────────────────────────
Options:
───────────────────────────────────
[W] Test in Worktree First
    Security scan + isolated testing
```

**Issues/Recommendations column - status indicators:**

| Indicator | When to show |
|-----------|--------------|
| `• CI passing` | All checks green |
| `• CI failing` | Any check failed |
| `• CI pending` | Checks still running |
| `• Update branch` | Behind base branch |
| `• Resolve conflicts` | Has merge conflicts |
| `• Pending review` | Awaiting review |
| `• Changes requested` | Reviewer requested changes |
| `• N approvals` | Has N approved reviews |
| `• Draft PR` | PR is in draft mode |
| `• Ready to merge` | No blockers found |

**Step 0.3: Wait for user selection**

Use AskUserQuestion with options for each PR:

| Option | Label |
|--------|-------|
| 1 | PR #42 - Add JWT auth flow |
| 2 | PR #38 - Fix memory leak |
| 3 | PR #35 - Refactor queries |
| W | 🧪 Test in Worktree (security scan + isolated testing) |
| Q | Quit |

**After selection:**
- **If W selected:** Ask which PR to test, then jump to PHASE 3.5 (Worktree Test)
- **Otherwise:** Continue to PHASE 1 with the selected PR number

---

## PHASE 1: IDENTIFY THE PR

**Step 1.1: Determine which PR to merge**

```bash
# If PR number provided as argument, use it
# Otherwise, find PR for current branch:
CURRENT_BRANCH=$(git branch --show-current)
gh pr list --repo {{versionControl.owner}}/{{versionControl.repo}} --head "$CURRENT_BRANCH" --json number,title,headRefName --jq '.[0]'
```

**If no PR found:**
- Tell user: "I couldn't find an open PR for this branch."
- Offer: "Would you like me to create one with `/github-task-start --complete`?"

**Step 1.2: Fetch complete PR details**

```bash
gh pr view <PR_NUMBER> --repo {{versionControl.owner}}/{{versionControl.repo}} --json number,title,body,state,author,mergeable,mergeStateStatus,headRefName,baseRefName,isDraft,reviewDecision,statusCheckRollup,commits,additions,deletions,changedFiles,url
```

**Display a friendly summary:**

```
📋 PR #<number>: <title>
   Author: @<username>
   Branch: <head> → <base>
   Changes: +<additions> -<deletions> across <files> files
   Status: <current state>
```

---

## PHASE 2: CREATE SAFETY CHECKPOINT

**Before ANY changes, create a safety net.**

**Step 2.1: Verify clean working tree**

```bash
git status --porcelain
```

If there are uncommitted changes:
- Tell user: "You have uncommitted changes. I need a clean working tree before we start."
- Ask: "Should I stash them temporarily, or would you like to commit/discard first?"

Options:
| Option | Action |
|--------|--------|
| **A** | Stash changes (I'll restore them after) |
| **B** | Let me commit first (abort merge) |
| **C** | Discard changes (WARNING: loses work) |

**Step 2.2: Record current state**

```bash
# Save current branch and commit
SAFETY_BRANCH=$(git branch --show-current)
SAFETY_COMMIT=$(git rev-parse HEAD)
SAFETY_BASE_COMMIT=$(git rev-parse origin/{{versionControl.defaultBranch}})

# Fetch latest from remote
git fetch origin
```

**Tell user:**
> "✅ Safety checkpoint created. If anything goes wrong, I can restore you to exactly where you started."

---

## PHASE 3: DETECT ALL BLOCKERS

Check for every possible merge blocker and collect them into a list.

**Blocker Detection:**

| Blocker | How to Detect | Severity |
|---------|---------------|----------|
| Draft PR | `isDraft: true` | 🟡 Warning |
| Out of date | `mergeStateStatus: BEHIND` | 🟠 Fixable |
| Merge conflicts | `mergeable: CONFLICTING` | 🔴 Blocking |
| Failing checks | `statusCheckRollup` has failures | 🔴 Blocking |
| Pending reviews | `reviewDecision: REVIEW_REQUIRED` | 🟠 Depends on settings |
| Changes requested | `reviewDecision: CHANGES_REQUESTED` | 🔴 Blocking |

**Display blockers clearly:**

```
🔍 Pre-merge check complete.

Found <N> issue(s) to resolve:

1. 🔴 Merge conflicts in 2 files
2. 🟠 Branch is 3 commits behind {{versionControl.defaultBranch}}
3. 🟡 PR is still in draft mode

───────────────────────────────────
Options:
───────────────────────────────────
[W] 🧪 Test in Worktree First
    Security scan + resolve in isolation

[C] Continue with blocker resolution
```

**Always offer worktree option** - even with blockers, user may want to test in isolation first.

If user selects **W**: Jump to PHASE 3.5 (Worktree Test Option)
If user selects **C**: Continue to PHASE 4 (Resolve Each Blocker)

If NO blockers:
```
✅ All checks passed! This PR is ready to merge.

───────────────────────────────────
Options:
───────────────────────────────────
[W] 🧪 Test in Worktree First
    Security scan + test features

[M] Proceed to Merge
```

If user selects **W**: Jump to PHASE 3.5
If user selects **M**: Skip to Phase 5

---

## PHASE 3.5: WORKTREE TEST OPTION (Security Scan + Feature Testing)

**After detecting blockers, offer the option to test the PR in an isolated worktree.**

This is useful when:
- You want to test new features before merging
- The PR has conflicts that need resolution
- You want to review changes in a sandboxed environment
- Security scan is needed before running untrusted code

**Ask user:**

```
╔═══════════════════════════════════════════════════════════════╗
║  🧪 Test PR in Worktree?                                      ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Create an isolated worktree to:                              ║
║  • Run security scan on PR changes                            ║
║  • Test new features before merging                           ║
║  • Resolve conflicts in isolation                             ║
║  • Build and verify the code works                            ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

| Option | What happens |
|--------|--------------|
| **W** | Create worktree, run security scan, test features |
| **S** | Skip - proceed directly to blocker resolution |

---

### 3.5.1 Security Scan (If W selected)

**Before creating the worktree, scan the PR for security concerns:**

```bash
# Get list of changed files
gh pr view <PR_NUMBER> --repo {{versionControl.owner}}/{{versionControl.repo}} --json files --jq '.files[].path'
```

**Security checks to perform:**

| Check | What to look for |
|-------|------------------|
| **Sensitive files** | `.env`, `credentials`, `secrets`, `*.pem`, `*.key` |
| **Script changes** | Modified `.sh`, `.bat`, `.ps1`, `postinstall.js` |
| **Config changes** | `package.json` scripts, CI/CD workflows, `.github/` |
| **Dependency changes** | New packages in `package.json`, `requirements.txt` |
| **Hook changes** | Files in `.claude/hooks/` that execute on tool use |

**Display security report:**

```
╔═══════════════════════════════════════════════════════════════╗
║  🔒 Security Scan Results                                     ║
╠═══════════════════════════════════════════════════════════════╣
{{#if securityIssues}}
║  ⚠️  Found {{securityIssueCount}} item(s) to review:          ║
║                                                               ║
{{#each securityIssues}}
║  • {{this.type}}: {{this.file}}                               ║
{{/each}}
{{else}}
║  ✅ No obvious security concerns detected                     ║
{{/if}}
║                                                               ║
║  Changed files: {{changedFilesCount}}                         ║
║  Scripts modified: {{scriptsModified}}                        ║
║  Dependencies added: {{newDependencies}}                      ║
╚═══════════════════════════════════════════════════════════════╝
```

**If security concerns found, ask:**

| Option | Action |
|--------|--------|
| **C** | Continue anyway - I trust this contributor |
| **R** | Review flagged files before proceeding |
| **A** | Abort - I need to investigate further |

---

### 3.5.2 Create Test Worktree

**Create worktree adjacent to main repo:**

```bash
# Determine worktree path
PROJECT_ROOT=$(git rev-parse --show-toplevel)
PROJECT_NAME=$(basename "$PROJECT_ROOT")
WORKTREE_PATH="../${PROJECT_NAME}-pr-${PR_NUMBER}"

# Create worktree with PR branch
git fetch origin pull/<PR_NUMBER>/head:pr-<PR_NUMBER>
git worktree add "$WORKTREE_PATH" pr-<PR_NUMBER>
```

**Display worktree info:**

```
╔═══════════════════════════════════════════════════════════════╗
║  ✅ Test Worktree Created                                     ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Location: {{worktreePath}}                                   ║
║  Branch: pr-{{prNumber}}                                      ║
║  PR: #{{prNumber}} - {{prTitle}}                              ║
║                                                               ║
║  To work in worktree:                                         ║
║    cd {{worktreePath}}                                        ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

---

### 3.5.3 Conflict Resolution in Worktree (If conflicts exist)

**If the PR has merge conflicts, resolve them in the worktree:**

```bash
cd "$WORKTREE_PATH"

# Attempt to merge base branch
git merge origin/{{versionControl.defaultBranch}}
```

**If conflicts occur:**

```
╔═══════════════════════════════════════════════════════════════╗
║  ⚠️  Merge Conflicts Detected                                 ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Conflicting files:                                           ║
{{#each conflictFiles}}
║  • {{this}}                                                   ║
{{/each}}
║                                                               ║
║  Resolving in isolated worktree (safe to experiment)          ║
╚═══════════════════════════════════════════════════════════════╝
```

**Walk through each conflicting file:**

1. Show the conflict markers
2. Explain what each side changed
3. Ask user which version to keep (or manual edit)
4. Stage the resolved file

```bash
# After all conflicts resolved
git add .
git commit -m "Resolve merge conflicts with {{versionControl.defaultBranch}}"
```

---

### 3.5.4 Test the PR Features

**After worktree is set up (and conflicts resolved if any):**

```
╔═══════════════════════════════════════════════════════════════╗
║  🧪 Ready to Test PR Features                                 ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  You're now in an isolated worktree.                          ║
║  Test the PR's changes without affecting your main repo.      ║
║                                                               ║
║  Worktree: {{worktreePath}}                                   ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

**Ask what to do:**

| Option | Action |
|--------|--------|
| **B** | Run build/tests (`npm install && npm test` or detected build command) |
| **I** | Install dependencies only |
| **M** | Manual testing - I'll explore on my own |
| **P** | PR looks good - proceed to merge from worktree |
| **X** | Abort - delete worktree and cancel merge |

**For B (Build and test):**

```bash
cd "$WORKTREE_PATH"

# Detect package manager and run tests
{{#if (eq packageManager "npm")}}
npm install && npm test
{{else if (eq packageManager "yarn")}}
yarn install && yarn test
{{else if (eq packageManager "pnpm")}}
pnpm install && pnpm test
{{else}}
# Python project
pip install -r requirements.txt && pytest
{{/if}}
```

**Display test results:**

```
╔═══════════════════════════════════════════════════════════════╗
{{#if testsPassed}}
║  ✅ All Tests Passed                                          ║
{{else}}
║  ❌ Tests Failed                                              ║
{{/if}}
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Tests run: {{testsRun}}                                      ║
║  Passed: {{testsPassed}}                                      ║
║  Failed: {{testsFailed}}                                      ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

---

### 3.5.5 Merge from Worktree or Return to Main

**After testing, ask user:**

| Option | Action |
|--------|--------|
| **P** | Proceed with merge (push conflict resolution if any, then merge) |
| **K** | Keep worktree, return to main repo (merge later) |
| **D** | Delete worktree, return to main repo (don't merge yet) |
| **X** | Delete worktree, abort merge entirely |

**For P (Proceed with merge):**

If conflicts were resolved in worktree:
```bash
# Push resolved conflicts back to PR branch
cd "$WORKTREE_PATH"
git push origin pr-<PR_NUMBER>:<head-branch>
```

Then return to main repo and continue to Phase 4.

**For K (Keep worktree):**
```
╔═══════════════════════════════════════════════════════════════╗
║  📁 Worktree Preserved                                        ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Location: {{worktreePath}}                                   ║
║                                                               ║
║  To return later:                                             ║
║    cd {{worktreePath}}                                        ║
║                                                               ║
║  To cleanup when done:                                        ║
║    git worktree remove {{worktreePath}}                       ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

**For D or X (Delete worktree):**
```bash
cd "$PROJECT_ROOT"
git worktree remove "$WORKTREE_PATH" --force
git branch -D pr-<PR_NUMBER> 2>/dev/null || true
```

---

## PHASE 4: RESOLVE EACH BLOCKER

Handle blockers **one at a time**, in order of severity.

### 4.1 Draft PR

**Explain:**
> "This PR is marked as a draft, which usually means the author isn't ready for review yet."

**Ask:**

| Option | What happens |
|--------|--------------|
| **A** | Mark as ready for review, then continue |
| **B** | Merge anyway (author may have forgotten to un-draft) |
| **C** | Abort - let me check with the author first |

For A:
```bash
gh pr ready <PR_NUMBER> --repo {{versionControl.owner}}/{{versionControl.repo}}
```

---

### 4.2 Out-of-Date Branch

**Explain:**
> "The PR branch is behind {{versionControl.defaultBranch}}. This means new commits were merged since this PR was created."

**Ask:**

| Option | What happens |
|--------|--------------|
| **A** | Update by merging {{versionControl.defaultBranch}} into PR branch (recommended - preserves history) |
| **B** | Update by rebasing onto {{versionControl.defaultBranch}} (cleaner history, rewrites commits) |
| **C** | Skip - merge anyway if branch protection allows |
| **D** | Abort - I want to review the new commits first |

For A (merge update):
```bash
git fetch origin
git checkout <head-branch>
git merge origin/{{versionControl.defaultBranch}} --no-edit
git push origin <head-branch>
```

For B (rebase):
```bash
git fetch origin
git checkout <head-branch>
git rebase origin/{{versionControl.defaultBranch}}
git push origin <head-branch> --force-with-lease
```

**After update:**
> "✅ Branch updated. Waiting for CI checks to restart..."

```bash
gh pr checks <PR_NUMBER> --repo {{versionControl.owner}}/{{versionControl.repo}} --watch
```

---

### 4.3 Merge Conflicts

**Explain:**
> "There are merge conflicts between this PR and {{versionControl.defaultBranch}}. The same files were changed in both branches."

**Show conflicting files:**
```bash
gh pr view <PR_NUMBER> --repo {{versionControl.owner}}/{{versionControl.repo}} --json files --jq '.files[] | select(.conflictStatus == "CONFLICTING") | .path'
```

**Ask:**

| Option | What happens |
|--------|--------------|
| **A** | I'll help you resolve conflicts locally (recommended) |
| **B** | Open GitHub's web conflict resolver |
| **C** | Abort and notify the contributor to fix conflicts |

For A:
```bash
git fetch origin
git checkout <head-branch>
git merge origin/{{versionControl.defaultBranch}}
# Conflicts will appear - guide user through resolution
```

Then walk through each conflicting file, explaining what changed and asking which version to keep.

For C (notify contributor):
Post comment to PR (see Phase 6 for template).

---

### 4.4 Failing CI Checks

**Explain:**
> "Some automated checks are failing. This usually means tests aren't passing or there's a build error."

**Show failing checks:**
```bash
gh pr checks <PR_NUMBER> --repo {{versionControl.owner}}/{{versionControl.repo}}
```

**Ask:**

| Option | What happens |
|--------|--------------|
| **A** | Wait for checks to complete (they might still be running) |
| **B** | View the failing check logs |
| **C** | Abort and notify contributor about failures |
| **D** | Force merge anyway (admin bypass - use carefully!) |

For A:
```bash
gh pr checks <PR_NUMBER> --repo {{versionControl.owner}}/{{versionControl.repo}} --watch
```

For B:
```bash
gh pr checks <PR_NUMBER> --repo {{versionControl.owner}}/{{versionControl.repo}} --json name,state,conclusion,detailsUrl --jq '.[] | select(.conclusion == "FAILURE")'
```

For C:
Post comment with failure details (see Phase 6).

---

### 4.5 Pending Reviews

**Explain:**
> "This repository requires reviews before merging. No approved reviews yet."

**Ask:**

| Option | What happens |
|--------|--------------|
| **A** | Request a review from a team member |
| **B** | I'll review and approve it myself |
| **C** | Admin merge (bypass review requirement) |
| **D** | Abort - reviews are required for a reason |

For A:
```bash
# Show collaborators
gh api repos/{{versionControl.owner}}/{{versionControl.repo}}/collaborators --jq '.[].login'
# Request review
gh pr edit <PR_NUMBER> --add-reviewer <username>
```

---

### 4.6 Changes Requested

**Explain:**
> "A reviewer requested changes on this PR. The feedback should be addressed before merging."

**Show the requested changes:**
```bash
gh pr view <PR_NUMBER> --repo {{versionControl.owner}}/{{versionControl.repo}} --json reviews --jq '.reviews[] | select(.state == "CHANGES_REQUESTED") | {author: .author.login, body: .body}'
```

**Ask:**

| Option | What happens |
|--------|--------------|
| **A** | View the review comments in detail |
| **B** | Dismiss the review (requires justification) |
| **C** | Abort - changes need to be addressed first |

---

## PHASE 5: CONTRIBUTOR MESSAGING (Pre-Merge)

**Before merging, offer to thank the contributor.**

**Ask:**
> "Would you like to post a friendly comment thanking the contributor before I merge?"

| Option | Action |
|--------|--------|
| **A** | Yes, post a thank-you message (recommended for external contributors) |
| **B** | No, just merge silently |

For A, post this comment:
```bash
gh pr comment <PR_NUMBER> --repo {{versionControl.owner}}/{{versionControl.repo}} --body "Thanks for the contribution! 🎉 Reviewing and merging now."
```

---

## PHASE 6: SELECT MERGE METHOD

**Explain the options:**

| Method | Best for | What happens |
|--------|----------|--------------|
| **A** Squash (recommended) | Most PRs | All commits become one clean commit |
| **B** Merge commit | Preserving history | Creates a merge commit, keeps all PR commits |
| **C** Rebase | Linear history | Replays commits on top of base branch |

**Ask:**
> "How would you like to merge this PR?"

---

## PHASE 7: EXECUTE MERGE

**Confirm before proceeding:**

> "Ready to merge PR #<number> using <method>."
> "This will:"
> "  • Merge <N> commits into {{versionControl.defaultBranch}}"
> "  • Delete the <branch-name> branch"
> "  • Close any linked issues"
>
> "Proceed?"

**Execute:**

```bash
# Squash merge
gh pr merge <PR_NUMBER> --repo {{versionControl.owner}}/{{versionControl.repo}} --squash --delete-branch

# OR Merge commit
gh pr merge <PR_NUMBER> --repo {{versionControl.owner}}/{{versionControl.repo}} --merge --delete-branch

# OR Rebase
gh pr merge <PR_NUMBER> --repo {{versionControl.owner}}/{{versionControl.repo}} --rebase --delete-branch
```

---

## PHASE 8: POST-MERGE CLEANUP

**After successful merge:**

```bash
# Return to base branch
git checkout {{versionControl.defaultBranch}}

# Pull the merged changes
git pull origin {{versionControl.defaultBranch}}

# Delete local PR branch
git branch -d <head-branch> 2>/dev/null || true

# Clean up remote tracking
git fetch --prune
```

**If worktree was created in Phase 3.5:**
```bash
# Remove the test worktree
git worktree remove "$WORKTREE_PATH" --force 2>/dev/null || true

# Delete the temporary PR branch
git branch -D pr-<PR_NUMBER> 2>/dev/null || true
```

**If we stashed changes earlier:**
```bash
git stash pop
```

---

## PHASE 9: SUCCESS SUMMARY

**Display final summary:**

```
✅ PR #<number> merged successfully!

📋 Summary:
   Title: <PR title>
   Author: @<username>
   Method: Squash and merge
   Commits: <N> → 1
   Branch: <head-branch> (deleted)

🔗 Links:
   Merged PR: <pr-url>
   Commit: https://github.com/{{versionControl.owner}}/{{versionControl.repo}}/commit/<sha>

📌 What's next?
   • Deploy changes: /deploy-full
   • Start next task: /github-task-start
   • View project board: /github-update
```

---

## ERROR HANDLING & ROLLBACK

**If ANY step fails:**

1. **Stop immediately** - no partial merges
2. **Restore safety checkpoint:**
   ```bash
   git checkout $SAFETY_BRANCH
   git reset --hard $SAFETY_COMMIT
   git stash pop 2>/dev/null || true
   ```
3. **Explain what happened:**
   > "❌ The merge couldn't be completed. Don't worry - I've restored everything to exactly how it was before we started."
   > "What went wrong: <specific error>"

4. **Post failure comment to PR** (if contributor is external):

```bash
gh pr comment <PR_NUMBER> --repo {{versionControl.owner}}/{{versionControl.repo}} --body "$(cat <<'COMMENT'
Thanks so much for the contribution! 🙏

I wasn't able to merge this yet due to:

<BLOCKER_LIST>

**What needs to happen:**
<ACTION_ITEMS>

Once these are resolved, I'll be happy to try again. Let me know if you have any questions!
COMMENT
)"
```

---

## FAILURE COMMENT TEMPLATES

### CI Failures
```
- ❌ Failing CI checks
  - <check-name>: [View logs](<url>)
  - <check-name>: [View logs](<url>)

**To fix:** Please check the failing tests and push a fix.
```

### Merge Conflicts
```
- ❌ Merge conflicts in:
  - `<file1>`
  - `<file2>`

**To fix:** Please merge or rebase with `{{versionControl.defaultBranch}}` and resolve conflicts.
```

### Outdated Branch
```
- ⚠️ Branch is behind `{{versionControl.defaultBranch}}`

**To fix:** Please update your branch:
\`\`\`bash
git fetch origin
git merge origin/{{versionControl.defaultBranch}}
git push
\`\`\`
```

---

## AGENT-ONLY MODE COMPATIBILITY

This command is **fully compatible** with Agent-Only Mode:

- `git` and `gh` commands are in the exempt patterns list
- All PR operations bypass agent delegation requirements
- No Edit/Write tools are used by this command

**For existing projects:** Ensure `^gh ` is in your `delegation.json` exemptPatterns.

---

## DRY RUN MODE

When `--dry-run` is specified:

1. Run all detection and analysis phases
2. Show what blockers exist and what actions would be taken
3. **DO NOT** execute any merge, update, or comment operations
4. Display: "This was a dry run. No changes were made."

---

## INSTRUCTIONS FOR CLAUDE

**Mindset:** Act as a helpful senior engineer sitting next to the user, making sure they don't break their repo and helping them communicate clearly with contributors.

**Execution flow:**

1. Parse arguments (PR number, --dry-run flag, --worktree flag)
2. **If NO PR number provided:** PHASE 0 - Show Open PR Menu
   - Fetch all open PRs with full details
   - Display formatted table with #, PR, Description (15-20 words), Date (MM/DD), Status, Issues
   - Wait for user selection, then continue with selected PR
3. PHASE 1: Identify the PR (with selected or provided number)
4. PHASE 2: Create safety checkpoint (CRITICAL - always do this)
5. PHASE 3: Detect all blockers
6. **PHASE 3.5: Worktree Test Option** (if --worktree flag OR user selects [W])
   - Run security scan on changed files
   - Create isolated worktree with PR branch
   - Resolve conflicts in worktree if any
   - Run build/tests in isolated environment
   - Ask user to proceed, keep worktree, or abort
7. PHASE 4: Resolve blockers one by one (ask user for each)
8. PHASE 5: Offer contributor thank-you message
9. PHASE 6: Ask for merge method
10. PHASE 7: Execute merge (with confirmation)
11. PHASE 8: Cleanup local environment (including worktree if created)
12. PHASE 9: Display success summary

**On any error:** Immediately rollback and explain clearly.

**Communication style:**
- No jargon - explain git concepts simply
- Always explain what's happening and why
- Always ask before any destructive action
- Never silently automate - transparency first
- Be encouraging, especially about contributor PRs

{{else}}

## Configuration Required

GitHub repository is not configured. Run:

```bash
ccasp init
```

Then restart Claude Code for commands to appear.

{{/if}}

---

*Part of CCASP - Claude CLI Advanced Starter Pack*
