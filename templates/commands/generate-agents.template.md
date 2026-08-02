
<!-- CODEX-OVERRIDE:START -->
# generate-agents — Codex Runtime

This command generates agent configuration files. In Codex, the `Task()` multi-agent spawner is unavailable. This command will run sequentially instead.

## What I'll Do

1. Read your existing project structure (`package.json`, tech stack files)
2. Analyze what kinds of tasks you have (frontend, backend, testing, deployment)
3. Generate `.ccasp/agents/` configuration YAML files for each agent type
4. Create a summary of what agents were generated

## Run

Tell me which agent types to generate (or say "auto-detect") and I'll create the configuration files. I'll work through each agent type one at a time.

**For parallel multi-agent generation, use Claude Code CLI: `/generate-agents`**
<!-- CODEX-OVERRIDE:END -->
---
description: Generate stack-specific agents
model: sonnet
---

# /generate-agents - Stack-Specific Agent Generator

Generate tech stack-specific specialist agents based on your project's detected technologies.

## What This Command Does

1. **Detects your tech stack** from package.json, config files, and project structure
2. **Generates specialist agents** for each detected technology (React, FastAPI, Prisma, etc.)
3. **Creates routing configuration** for automatic task delegation
4. **Sets up delegation hooks** for agent-only mode enforcement

## Usage

```
/generate-agents
```

### Options

- **Auto mode**: Generates without confirmation prompts
- **Verbose**: Shows detailed output of all generated files
- **List**: Shows existing agents instead of generating

## Generated Files

### Agent Registry (`.claude/config/agents.json`)
Central registry of all specialist agents with:
- Agent metadata (name, level, domain, framework)
- Tool assignments per agent
- Model assignments (sonnet, haiku, opus)
- Trigger keywords and file patterns

### Delegation Config (`.claude/config/delegation.json`)
Routing rules for task classification:
- Domain keywords (component → frontend, api → backend)
- File pattern matching (src/components/** → frontend specialist)
- Agent-only mode settings
- Delegation modes (suggest, auto, enforce)

### Agent Definitions (`.claude/agents/*.md`)
Markdown files for each specialist agent containing:
- Framework-specific expertise
- Code standards and patterns
- Common workflows
- Tool access and delegation rules

## Supported Frameworks

### Frontend
- React, Vue, Angular, Svelte
- Next.js, Nuxt, Astro

### Backend
- FastAPI, Express, NestJS, Django
- Flask, Rails, Gin

### State Management
- Zustand, Redux, Pinia
- Vuex, MobX, Jotai

### Database/ORM
- PostgreSQL, MySQL, MongoDB
- Prisma, SQLAlchemy, TypeORM

### Testing
- Playwright, Cypress
- Vitest, Jest, pytest

### Deployment
- Railway, Cloudflare, Vercel
- Docker

## After Generation

1. **Restart Claude Code CLI** to load new agents
2. **Use `/menu`** to see agent status and quick access
3. **Tasks are auto-routed** to appropriate specialists based on keywords and file patterns

## Agent-Only Mode

Enable agent-only mode for strict delegation:

```json
// .claude/config/delegation.json
{
  "agentOnlyMode": {
    "enabled": true,
    "restrictedTools": ["Edit", "Write", "Bash"]
  }
}
```

When enabled:
- Direct Edit/Write/Bash calls are blocked
- All modifications must go through specialist agents
- Git and test commands remain allowed

## Example Workflow

1. User asks: "Add a new React component for user profiles"
2. Task classifier detects: `component` keyword → frontend domain
3. Agent delegator suggests: `react-frontend-specialist`
4. Task is delegated to the React specialist with full context

## Regenerating Agents

Run `/generate-agents` again to:
- Update agents after tech stack changes
- Add agents for newly detected technologies
- Refresh routing configuration
