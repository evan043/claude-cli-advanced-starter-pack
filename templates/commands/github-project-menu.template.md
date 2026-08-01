---
description: View and sync GitHub Project Board status
model: haiku
---

# /github-project-menu - GitHub Project Board Sync

View current status of your GitHub Project Board and sync progress.

{{#if versionControl.projectBoard.number}}

## Project Board Configuration

| Setting | Value |
|---------|-------|
| Owner | {{versionControl.owner}} |
| Repository | {{versionControl.repo}} |
| Project # | {{versionControl.projectBoard.number}} |
| URL | {{versionControl.projectBoard.url}} |

## Commands

### View Board Status

```bash
# View all items on the project board
gh project item-list {{versionControl.projectBoard.number}} --owner {{versionControl.owner}} --format json | jq '.items'

# View issues only
gh issue list --repo {{versionControl.owner}}/{{versionControl.repo}} --state open --json number,title,state,labels

# View PRs
gh pr list --repo {{versionControl.owner}}/{{versionControl.repo}} --state open --json number,title,state,headRefName
```

### Sync Tasks

1. **Pull from GitHub** - Fetch latest status from Project Board
2. **Push to GitHub** - Update Project Board with local progress
3. **Reconcile** - Two-way sync with conflict resolution

## Instructions for Claude

When this command is invoked:

1. Check gh CLI authentication: `gh auth status`
2. Fetch current board status using the commands above
3. Display a formatted summary:
   - Total items
   - Items by status (Todo, In Progress, Done)
   - Recent activity
4. Ask if user wants to sync or view details

{{else}}

## Configuration Required

GitHub Project Board is not configured. Please run `/menu` → Project Settings → GitHub Project Board to configure.

Required settings:
- GitHub owner (username or organization)
- Repository name
- Project board number (from URL)

{{/if}}

---

*Generated from tech-stack.json template*
