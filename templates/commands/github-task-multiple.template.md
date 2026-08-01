---
description: Batch GitHub task operations
model: sonnet
---

# /github-task-multiple

Create multiple GitHub issues from a complex prompt by intelligently breaking it into distinct tasks and creating issues in parallel.

## Usage

```
/github-task-multiple <description>
/github-task-multiple "Add auth with OAuth, JWT tokens, password reset, and 2FA"
```

## Features

- Intelligent prompt analysis and task decomposition
- Parallel agent execution using Sonnet 4.5
- Post-creation integration with Phase Dev, Roadmaps, Epics
- User confirmation before issue creation

## Instructions

<instructions>

### Step 1: Analyze the Prompt

Parse the user's description to identify distinct tasks:

**Detection Signals:**
- Conjunctions: "and", "plus", "also", "additionally", "as well as"
- Comma-separated lists: "X, Y, and Z"
- Numbered items: "1. First 2. Second"
- Multiple action verbs: "add", "create", "implement", "fix", "update"
- Multiple feature keywords: "feature", "component", "system", "service"

**Analysis Algorithm:**
```javascript
function analyzePrompt(prompt) {
  const indicators = {
    conjunctions: (prompt.match(/\b(and|plus|also|additionally|as well as)\b/gi) || []).length,
    listItems: (prompt.match(/,\s*(?:and\s+)?[a-z]/gi) || []).length,
    numbered: (prompt.match(/\d+\.\s+\w/g) || []).length,
    actions: (prompt.match(/\b(add|create|build|implement|fix|refactor|update|integrate)\b/gi) || []).length,
    features: (prompt.match(/\b(feature|component|system|service|module|endpoint|api)\b/gi) || []).length
  };

  const score = indicators.conjunctions * 2 +
                indicators.listItems * 1.5 +
                indicators.numbered * 3 +
                indicators.actions * 1 +
                indicators.features * 0.5;

  return {
    shouldSplit: score >= 4,
    estimatedTasks: Math.max(2, Math.min(8, Math.ceil(score / 2)))
  };
}
```

### Step 2: Extract and Display Tasks

Break the prompt into distinct tasks and display for confirmation:

```
╔═══════════════════════════════════════════════════════════════════════╗
║  /github-task-multiple                                                ║
╠═══════════════════════════════════════════════════════════════════════╣
║                                                                       ║
║  Analyzing prompt...                                                  ║
║                                                                       ║
║  Identified N distinct tasks:                                         ║
║                                                                       ║
║  1. [Task Title]                                                      ║
║     └─ [Brief description of scope]                                   ║
║                                                                       ║
║  2. [Task Title]                                                      ║
║     └─ [Brief description of scope]                                   ║
║                                                                       ║
║  ... more tasks ...                                                   ║
║                                                                       ║
╠═══════════════════════════════════════════════════════════════════════╣
║  [C] Create all N issues (parallel agents)                            ║
║  [E] Edit task breakdown                                              ║
║  [M] Merge some tasks                                                 ║
║  [X] Cancel                                                           ║
╚═══════════════════════════════════════════════════════════════════════╝
```

### Step 3: Create Issues in Parallel

Launch parallel agents to create each issue:

**CRITICAL: Use Sonnet 4.5 (model: 'sonnet') for thorough analysis**

For each task, spawn an agent:
```
Task tool call:
  subagent_type: "general-purpose"
  model: "sonnet"
  prompt: |
    Create a GitHub issue for this task:

    Title: [Task Title]

    Context from original request:
    [Task description and scope]

    Instructions:
    1. Analyze what files/components would be affected
    2. Search codebase for relevant existing code
    3. Generate comprehensive issue body with:
       - Problem/feature description
       - Relevant code snippets (if applicable)
       - Implementation approach
       - Acceptance criteria
    4. Create the issue using: gh issue create --title "..." --body "..."
    5. Return the issue URL and number
```

**Execute ALL agents in a SINGLE message for true parallel execution.**

### Step 4: Collect Results

After all agents complete, collect the created issues:

```
╔═══════════════════════════════════════════════════════════════════════╗
║  ✓ Created N issues                                                   ║
╠═══════════════════════════════════════════════════════════════════════╣
║                                                                       ║
║  #101 - OAuth Login Integration                                       ║
║  #102 - JWT Refresh Token System                                      ║
║  #103 - Password Reset Flow                                           ║
║  #104 - Two-Factor Authentication                                     ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝
```

### Step 5: Post-Creation Integration

{{#if (eq githubTask.defaultPostAction "ask")}}
Present options for organizing the created issues:

```
╔═══════════════════════════════════════════════════════════════════════╗
║  Add to project structure?                                            ║
╠═══════════════════════════════════════════════════════════════════════╣
║                                                                       ║
║  [P] Create new Phase Development Plan                                ║
║      └─ /phase-dev-plan with these issues as phases                   ║
║                                                                       ║
║  [R] Add to existing Roadmap                                          ║
║      └─ Select roadmap → assign to phases                             ║
║                                                                       ║
║  [E] Create new Epic                                                  ║
║      └─ /create-github-epic with these as child issues                ║
║                                                                       ║
║  [B] Add to Project Board only                                        ║
║      └─ Add all to current sprint/backlog                             ║
║                                                                       ║
║  [N] No grouping (keep as standalone issues)                          ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝
```
{{else}}
Default action: {{githubTask.defaultPostAction}}

{{#if (eq githubTask.defaultPostAction "phase-dev")}}
Automatically invoke /phase-dev-plan with created issues.
{{/if}}
{{#if (eq githubTask.defaultPostAction "epic")}}
Automatically invoke /create-github-epic with created issues as children.
{{/if}}
{{#if (eq githubTask.defaultPostAction "board")}}
Add all issues to Project Board.
{{/if}}
{{/if}}

### Step 6: Add to Project Board

{{#if githubTask.autoAddToProjectBoard}}
Automatically add all created issues to the configured Project Board:

```bash
{{#each createdIssues}}
gh project item-add {{../versionControl.projectBoard.number}} --owner {{../versionControl.owner}} --url {{this.url}}
{{/each}}
```
{{/if}}

</instructions>

## Configuration

Settings from `/menu` → Settings → GitHub Task:

| Setting | Value |
|---------|-------|
| Auto-split mode | {{githubTask.autoSplitMode}} |
| Default post-action | {{githubTask.defaultPostAction}} |
| Parallel agent model | {{githubTask.parallelAgentModel}} |
| Max parallel issues | {{githubTask.maxParallelIssues}} |
| Auto-add to board | {{githubTask.autoAddToProjectBoard}} |

## Examples

```bash
# Feature with multiple components
/github-task-multiple "Build user dashboard with profile settings, activity feed, and notification preferences"

# Refactoring tasks
/github-task-multiple "Refactor auth module: extract JWT logic, add refresh tokens, improve error handling"

# Bug fixes across areas
/github-task-multiple "Fix login timeout, broken password reset email, and session persistence issues"
```

## Related Commands

- `/github-task` - Create single issue with codebase analysis
- `/phase-dev-plan` - Create phased development plan
- `/create-github-epic` - Create epic with child issues
- `/github-update` - View Project Board status
