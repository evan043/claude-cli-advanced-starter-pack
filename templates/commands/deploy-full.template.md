<!-- CCASP-CODEX-COMPAT:START -->
# Codex Runtime Compatibility

This prompt was authored for Claude-style slash workflows. In Codex runtime, adapt tool calls as follows:
- `AskUserQuestion` => ask the user directly in chat.
- `WebSearch`/`WebFetch` => use available web tools (`search_query`, `open`, `find`) and cite links.
- `Read`/`Write` => use shell/filesystem tools in this workspace.
- Claude-only MCP calls (for example Playwright MCP names) => use available equivalents or clearly state fallback.
- Keep intent and output format identical; only adapt execution mechanics.
<!-- CCASP-CODEX-COMPAT:END -->
<!-- CODEX-OVERRIDE:START -->
# deploy-full — Codex Runtime

This command deploys your full-stack app. In Codex, Railway MCP and the `Task()` agent spawner are unavailable. Use the manual steps below.

## Pre-deployment

```bash
git status       # confirm clean working tree
git branch --show-current   # confirm on correct branch
npm test         # run tests before deploying
```

## Backend Deployment (Railway)

Railway auto-deploy is disabled. Trigger a deploy via Railway dashboard or Railway CLI:

```bash
# Option 1: Railway CLI (if installed)
railway up

# Option 2: Push to trigger CI (if Railway is linked to git)
git push origin main

# Option 3: Railway Dashboard
# Go to https://railway.app → your project → Deploy
```

## Frontend Deployment (Cloudflare Pages)

```bash
npm run build
npx wrangler pages deploy dist --project-name=<your-project-name>
```

## Verification

After deployment, verify by running:
```bash
curl https://<your-backend-url>/health
```
And opening your frontend URL in a browser.

**For full automated parallel deployment with Railway MCP, use Claude Code CLI: `/deploy-full`**
<!-- CODEX-OVERRIDE:END -->
---
description: Parallel full-stack deployment (backend + frontend)
model: haiku
---

# /deploy-full - Full-Stack Deployment

Deploy all services in parallel for fastest deployment.

{{#if deployment.backend.platform}}
{{#if deployment.frontend.platform}}

## Deployment Targets

| Component | Platform | Service | URL |
|-----------|----------|---------|-----|
| Backend (Primary) | {{deployment.backend.platform}} | {{deployment.backend.serviceName}} | {{deployment.backend.productionUrl}} |
{{#if deployment.backendSecondary.platform}}
| Backend (Secondary) | {{deployment.backendSecondary.platform}} | {{deployment.backendSecondary.serviceName}} | {{deployment.backendSecondary.productionUrl}} |
{{/if}}
| Frontend | {{deployment.frontend.platform}} | {{deployment.frontend.project}} | {{deployment.frontend.productionUrl}} |

## Pre-deployment Checklist

```bash
# 1. Verify clean working directory
git status

# 2. Ensure on correct branch
git branch --show-current

# 3. Run tests
{{#if testing.unit.testCommand}}
{{testing.unit.testCommand}}
{{else}}
npm test
{{/if}}
```

---

## Backend Deployment (Primary: {{deployment.backend.serviceName}})

{{#if (eq deployment.backend.platform "railway")}}
### Railway ({{deployment.backend.serviceName}})

Using Railway MCP server for deployment:

```javascript
// Trigger deployment via Railway MCP
mcp__railway-mcp-server__deployment_trigger({
  projectId: "{{deployment.backend.projectId}}",
  serviceId: "{{deployment.backend.serviceId}}",
  environmentId: "{{deployment.backend.environmentId}}"
})
```

Monitor deployment:
```javascript
mcp__railway-mcp-server__deployment_logs({
  projectId: "{{deployment.backend.projectId}}",
  serviceId: "{{deployment.backend.serviceId}}"
})
```
{{/if}}

{{#if (eq deployment.backend.platform "heroku")}}
### Heroku

```bash
# Push to Heroku
git push heroku {{versionControl.defaultBranch}}

# Check logs
heroku logs --tail
```
{{/if}}

{{#if (eq deployment.backend.platform "render")}}
### Render

```bash
# Render auto-deploys from git push
git push origin {{versionControl.defaultBranch}}

# Or trigger manual deploy via API
curl -X POST "https://api.render.com/v1/services/{{deployment.backend.serviceId}}/deploys" \
  -H "Authorization: Bearer $RENDER_API_KEY"
```
{{/if}}

{{#if (eq deployment.backend.platform "fly")}}
### Fly.io

```bash
# Deploy to Fly
fly deploy

# Check status
fly status
```
{{/if}}

{{#if (eq deployment.backend.platform "vercel")}}
### Vercel (Serverless)

```bash
vercel --prod
```
{{/if}}

{{#if (eq deployment.backend.platform "self-hosted")}}
### Self-Hosted

```bash
# SSH deploy
ssh {{deployment.backend.selfHostedConfig.sshUser}}@{{deployment.backend.selfHostedConfig.sshHost}} -p {{deployment.backend.selfHostedConfig.sshPort}} \
  'cd {{deployment.backend.selfHostedConfig.appPath}} && git pull && {{deployment.backend.selfHostedConfig.deployScript}}'
```
{{/if}}

---

{{#if deployment.backendSecondary.platform}}
## Backend Deployment (Secondary: {{deployment.backendSecondary.serviceName}})

{{#if (eq deployment.backendSecondary.platform "railway")}}
### Railway ({{deployment.backendSecondary.serviceName}})

Using Railway MCP server for deployment:

```javascript
// Trigger deployment via Railway MCP
mcp__railway-mcp-server__deployment_trigger({
  projectId: "{{deployment.backendSecondary.projectId}}",
  serviceId: "{{deployment.backendSecondary.serviceId}}",
  environmentId: "{{deployment.backendSecondary.environmentId}}"
})
```

Monitor deployment:
```javascript
mcp__railway-mcp-server__deployment_logs({
  projectId: "{{deployment.backendSecondary.projectId}}",
  serviceId: "{{deployment.backendSecondary.serviceId}}"
})
```
{{/if}}

{{#if (eq deployment.backendSecondary.platform "heroku")}}
### Heroku (Secondary)

```bash
# Push to Heroku secondary app
git push heroku-secondary {{versionControl.defaultBranch}}

# Check logs
heroku logs --tail --app {{deployment.backendSecondary.appName}}
```
{{/if}}

{{#if (eq deployment.backendSecondary.platform "render")}}
### Render (Secondary)

```bash
curl -X POST "https://api.render.com/v1/services/{{deployment.backendSecondary.serviceId}}/deploys" \
  -H "Authorization: Bearer $RENDER_API_KEY"
```
{{/if}}

{{#if (eq deployment.backendSecondary.platform "fly")}}
### Fly.io (Secondary)

```bash
fly deploy --config {{deployment.backendSecondary.configFile}}
```
{{/if}}

{{#if (eq deployment.backendSecondary.platform "vercel")}}
### Vercel (Secondary)

```bash
vercel --prod --cwd {{deployment.backendSecondary.directory}}
```
{{/if}}

{{#if (eq deployment.backendSecondary.platform "self-hosted")}}
### Self-Hosted (Secondary)

```bash
ssh {{deployment.backendSecondary.selfHostedConfig.sshUser}}@{{deployment.backendSecondary.selfHostedConfig.sshHost}} -p {{deployment.backendSecondary.selfHostedConfig.sshPort}} \
  'cd {{deployment.backendSecondary.selfHostedConfig.appPath}} && git pull && {{deployment.backendSecondary.selfHostedConfig.deployScript}}'
```
{{/if}}

{{#if (eq deployment.backendSecondary.platform "docker")}}
### Docker (Secondary)

```bash
# Build and push image
docker build -t {{deployment.backendSecondary.imageName}}:latest {{deployment.backendSecondary.directory}}
docker push {{deployment.backendSecondary.imageName}}:latest

# Deploy (platform-specific)
{{#if deployment.backendSecondary.dockerCompose}}
docker-compose -f {{deployment.backendSecondary.dockerCompose}} up -d
{{/if}}
```
{{/if}}

---
{{/if}}

---

## Frontend Deployment

{{#if (eq deployment.frontend.platform "cloudflare")}}
### Cloudflare Pages

```bash
# Clean and build
rm -rf {{deployment.frontend.outputDir}}
{{deployment.frontend.buildCommand}}

# Deploy
npx wrangler pages deploy {{deployment.frontend.outputDir}} --project-name={{deployment.frontend.project}}
```
{{/if}}

{{#if (eq deployment.frontend.platform "vercel")}}
### Vercel

```bash
vercel --prod
```
{{/if}}

{{#if (eq deployment.frontend.platform "netlify")}}
### Netlify

```bash
# Build
{{deployment.frontend.buildCommand}}

# Deploy
netlify deploy --prod --dir={{deployment.frontend.outputDir}}
```
{{/if}}

{{#if (eq deployment.frontend.platform "github-pages")}}
### GitHub Pages

```bash
# Build and deploy (assumes gh-pages package)
{{deployment.frontend.buildCommand}}
npm run deploy
```
{{/if}}

{{#if (eq deployment.frontend.platform "railway")}}
### Railway (Static)

```bash
# Push triggers auto-deploy
git push origin {{versionControl.defaultBranch}}
```
{{/if}}

---

## Verification

### Backend Health Check (Primary)

```bash
curl {{deployment.backend.productionUrl}}{{deployment.backend.healthEndpoint}}
```

{{#if deployment.backendSecondary.platform}}
### Backend Health Check (Secondary)

```bash
curl {{deployment.backendSecondary.productionUrl}}{{deployment.backendSecondary.healthEndpoint}}
```
{{/if}}

### Frontend Verification

1. Open {{deployment.frontend.productionUrl}}
2. Verify page loads correctly
3. Check browser console for errors
4. Test critical user flows

### E2E Smoke Test (Optional)

```bash
npx playwright test --grep "smoke"
```

---

## Rollback Procedures

### Backend Rollback (Primary)

{{#if (eq deployment.backend.platform "railway")}}
```javascript
// List recent deployments
mcp__railway-mcp-server__deployment_list({
  projectId: "{{deployment.backend.projectId}}",
  serviceId: "{{deployment.backend.serviceId}}"
})

// Redeploy previous version
mcp__railway-mcp-server__deployment_rollback({
  projectId: "{{deployment.backend.projectId}}",
  serviceId: "{{deployment.backend.serviceId}}",
  deploymentId: "<previous-deployment-id>"
})
```
{{else}}
```bash
# Revert commit and redeploy
git revert HEAD
git push origin {{versionControl.defaultBranch}}
```
{{/if}}

{{#if deployment.backendSecondary.platform}}
### Backend Rollback (Secondary)

{{#if (eq deployment.backendSecondary.platform "railway")}}
```javascript
mcp__railway-mcp-server__deployment_list({
  projectId: "{{deployment.backendSecondary.projectId}}",
  serviceId: "{{deployment.backendSecondary.serviceId}}"
})

mcp__railway-mcp-server__deployment_rollback({
  projectId: "{{deployment.backendSecondary.projectId}}",
  serviceId: "{{deployment.backendSecondary.serviceId}}",
  deploymentId: "<previous-deployment-id>"
})
```
{{else}}
```bash
git revert HEAD
git push origin {{versionControl.defaultBranch}}
```
{{/if}}
{{/if}}

### Frontend Rollback

```bash
# Revert to previous build
git revert HEAD
{{deployment.frontend.buildCommand}}
npx wrangler pages deploy {{deployment.frontend.outputDir}} --project-name={{deployment.frontend.project}}
```

---

## Parallel Deployment Command

To deploy all services in parallel, use:

```bash
# Deploy all backends and frontend simultaneously
# Backend Primary (Railway MCP)
# Backend Secondary (if configured)
# Frontend (Cloudflare)
```

**Recommended approach:** Use the Task tool to spawn parallel deployment agents:

```javascript
// Deploy backend primary
Task({ subagent_type: "l2-deployment-specialist", prompt: "Deploy backend primary to Railway" })

{{#if deployment.backendSecondary.platform}}
// Deploy backend secondary (in parallel)
Task({ subagent_type: "l2-deployment-specialist", prompt: "Deploy backend secondary" })
{{/if}}

// Deploy frontend (in parallel)
Task({ subagent_type: "l2-deployment-specialist", prompt: "Deploy frontend to Cloudflare" })
```

{{else}}

## Frontend Deployment Not Configured

Frontend deployment platform is not configured.

Run `/ccasp-setup` → Deployment Configuration to configure.

{{/if}}
{{else}}

## Backend Deployment Not Configured

Backend deployment platform is not configured.

Run `/ccasp-setup` → Deployment Configuration to configure.

{{/if}}

---

*Generated from tech-stack.json - CCASP v2.0*
