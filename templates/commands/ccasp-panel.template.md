---
description: CCASP Control Panel dashboard
model: sonnet
---

# CCASP Control Panel

Launch the CCASP Control Panel in a separate terminal window.

## Instructions for Claude

**IMPORTANT**: Execute the appropriate Bash command below to launch the panel in a new terminal window.

### Step 1: Launch Panel in New Window

Use the Bash tool to run ONE of these commands based on the platform:

**Windows (default):**
```bash
start powershell -NoExit -Command "ccasp panel"
```

**macOS:**
```bash
osascript -e 'tell application "Terminal" to do script "ccasp panel"'
```

**Linux (gnome-terminal):**
```bash
gnome-terminal -- ccasp panel &
```

### Step 2: Confirm Launch

After running the command, tell the user:

```
✅ CCASP Panel launched in a new terminal window!

How to use:
1. Switch to the new terminal window
2. Press a key to select a command (e.g., 'A' for Create Agent)
3. Come back here and press Enter to execute

Panel Controls:
  [A] Create Agent     [H] Create Hook      [S] Create Skill
  [M] Explore MCP      [C] Claude Audit     [E] Explore Codebase
  [P] Phase Dev Plan   [G] GitHub Task      [T] Run E2E Tests
  [Q] Quit             [R] Refresh          [X] Clear Queue
```

### First-Time Setup (if hook not installed)

If the user hasn't set up the panel hook yet, run:

```bash
ccasp install-panel-hook --global
```

Then tell them to restart Claude Code for the hook to take effect.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ CCASP Control Panel (NEW terminal window)                       │
│                                                                 │
│   Press key → Command queued to ~/.claude/ccasp-panel/          │
└─────────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────┐
│ Claude Code CLI (THIS terminal)                                  │
│                                                                 │
│   Press Enter → Hook reads queue → Executes command             │
└─────────────────────────────────────────────────────────────────┘
```
