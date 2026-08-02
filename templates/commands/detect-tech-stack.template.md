---
description: Re-run tech stack detection and update configuration
---

# /detect-tech-stack - Tech Stack Analysis

Re-analyze the project's tech stack and update `.claude/config/tech-stack.json`.

## Purpose

Issue #8: Tech stack detection previously only ran during terminal phase (ccasp init).
This command allows re-running detection from within Claude CLI to:
- Detect new dependencies added since initial setup
- Update framework versions
- Refresh configuration for agents, skills, and hooks

## Execution Steps

### Step 1: Read Current Tech Stack

```bash
cat .claude/config/tech-stack.json 2>/dev/null || echo "{}"
```

Save as `previousStack` for comparison.

### Step 2: Detect Current Stack

Analyze the following files to build the new tech stack:

**Package Managers:**
- `package.json` → Node.js/npm project
- `pyproject.toml` or `requirements.txt` → Python project
- `Cargo.toml` → Rust project
- `go.mod` → Go project
- `pom.xml` or `build.gradle` → Java project

**Frontend Frameworks (from package.json):**
- `react` → React
- `vue` → Vue.js
- `@angular/core` → Angular
- `svelte` → Svelte
- `next` → Next.js
- `nuxt` → Nuxt.js
- `vite` → Vite bundler

**Backend Frameworks:**
- `express` → Express.js
- `fastify` → Fastify
- `@nestjs/core` → NestJS
- `fastapi` (Python) → FastAPI
- `django` (Python) → Django
- `flask` (Python) → Flask

**Testing Frameworks:**
- `jest` → Jest
- `vitest` → Vitest
- `playwright` → Playwright
- `cypress` → Cypress
- `pytest` (Python) → Pytest

**Database:**
- `prisma` → Prisma ORM
- `drizzle-orm` → Drizzle
- `mongoose` → MongoDB
- `pg` or `postgres` → PostgreSQL
- `mysql2` → MySQL

**Deployment:**
Check for config files:
- `wrangler.toml` → Cloudflare
- `railway.json` or `railway.toml` → Railway
- `vercel.json` → Vercel
- `netlify.toml` → Netlify
- `Dockerfile` → Docker

### Step 3: Compare and Report Changes

Compare `previousStack` with newly detected stack:

```
╔═══════════════════════════════════════════════════════════════╗
║  📊 Tech Stack Analysis                                       ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Language: {{language}}                                       ║
║  Frontend: {{frontend.framework}} + {{frontend.bundler}}      ║
║  Backend:  {{backend.framework}}                              ║
║  Database: {{database.type}}                                  ║
║  Testing:  {{testing.frameworks}}                             ║
║  Deploy:   {{deployment.platform}}                            ║
║                                                               ║
╠═══════════════════════════════════════════════════════════════╣
║  Changes Detected:                                            ║
║  [+] Added: (list new dependencies)                           ║
║  [-] Removed: (list removed dependencies)                     ║
║  [~] Updated: (list version changes)                          ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

### Step 4: Update tech-stack.json

Write the updated configuration:

```bash
# Backup current config
cp .claude/config/tech-stack.json .claude/config/tech-stack.json.bak

# Write new config (use actual detected values)
```

### Step 5: Suggest Agent/Skill Updates

Based on detected changes, recommend:

| Change | Recommendation |
|--------|----------------|
| Added Playwright | Enable E2E testing skill |
| Added Prisma | Enable database agent |
| Added React 19 | Update component patterns |
| New test framework | Configure test runner |

## Output

After completion, display:

1. **Summary** of detected tech stack
2. **Diff** showing what changed since last detection
3. **Recommendations** for updating CCASP configuration
4. **Restart reminder** if significant changes detected

## Related Commands

- `/claude-audit` - Audit CLAUDE.md configuration
- `/update-smart` - Smart update manager
- `/project-impl` - Project implementation agent
