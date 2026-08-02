---
description: Natural language command discovery
model: haiku
---

# Ask Claude

Find the right command, skill, or workflow using natural language. Smart command discovery for CCASP.

## Usage

Describe what you want to do:

```
/ask-claude how do I deploy to production?
/ask-claude create a new API endpoint
/ask-claude fix the failing tests
/ask-claude analyze code quality
```

## How It Works

1. **Parse Intent** - Understand what you're trying to accomplish
2. **Match Commands** - Find relevant slash commands and skills
3. **Suggest Workflow** - Recommend the best approach
4. **Execute or Guide** - Run the command or explain how to use it

## Command Categories

### Development
| Intent | Command |
|--------|---------|
| "create agent" | `/create-agent` |
| "create hook" | `/create-hook` |
| "create skill" | `/create-skill` |
| "create command" | `/create-command` |

### Testing
| Intent | Command |
|--------|---------|
| "run tests" | `/e2e-test` |
| "create test" | `/create-smoke-test` |
| "fix failing tests" | `/e2e-test --ralph` |

### GitHub
| Intent | Command |
|--------|---------|
| "create issue" | `/github-task` |
| "start task" | `/github-task-start` |
| "check status" | `/github-update` |

### Refactoring
| Intent | Command |
|--------|---------|
| "check quality" | `/refactor-check` |
| "cleanup code" | `/refactor-cleanup` |
| "analyze code" | `/refactor-analyze` |

### Deployment
| Intent | Command |
|--------|---------|
| "deploy" | `/deploy-full` |
| "start tunnel" | `/tunnel-start` |

### Setup
| Intent | Command |
|--------|---------|
| "configure project" | `/ccasp-setup` |
| "audit setup" | `/claude-audit` |
| "explore MCP" | `/explore-mcp` |

## Response Format

```
You asked: "how do I deploy to production?"

Recommended: /deploy-full

This command:
- Builds the frontend
- Deploys backend to Railway (or configured platform)
- Deploys frontend to Cloudflare (or configured platform)
- Runs smoke tests to verify deployment

Would you like me to run /deploy-full now?
[Y] Yes, deploy now
[C] Configure deployment platforms first
[H] Show detailed help for this command
```

## Smart Matching

The command uses fuzzy matching to understand:

- **Synonyms**: "deploy", "publish", "release" → `/deploy-full`
- **Actions**: "create", "make", "add" → context-dependent
- **Targets**: "test", "agent", "hook" → specific command
- **Modifiers**: "quick", "full", "all" → command options

## Fallback Behavior

If no exact match is found:

1. Show top 3 most likely commands
2. Ask clarifying questions
3. Suggest reading `/menu` for full command list

## Configuration

Commands are discovered from:
- `.claude/commands/INDEX.md`
- Built-in CCASP commands
- Tech-stack specific commands

## Related Commands

- `/menu` - Interactive command browser
- `/help-examples` - Detailed usage examples
- `/ccasp-setup` - Project configuration wizard
