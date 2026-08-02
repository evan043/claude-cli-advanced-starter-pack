---
description: Toggle landing page on/off in production
model: haiku
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
---

# Toggle Landing Page

{{#if panel_config}}
**Panel config gate:** If `panel_config.features.landing_page_generator === false`, skip this entire command.
Display: "Landing page toggle skipped (disabled in panel config)."
{{/if}}

Toggle the landing page on or off. When enabled, the root route shows the marketing landing page. When disabled, the root route goes directly to the main application.

## What This Command Does

1. Updates `{{landingPage.configPath}}` to set `enabled: true` or `false` based on argument
2. Updates timestamp and modifier
3. Rebuilds the frontend
4. Deploys to production

## Usage

```bash
/landing-page-toggle enable   # Enable landing page
/landing-page-toggle disable  # Disable landing page
/landing-page-toggle          # Toggle current state (enable if disabled, disable if enabled)
```

## Effect

### When Enabled
- **Result**: Root URL ({{deployment.frontend.url}}) → Landing Page (with "Get Started" or "Sign In" button)

### When Disabled
- **Result**: Root URL ({{deployment.frontend.url}}) → Main App (direct authentication or dashboard)

## Implementation

You should:

1. **Read the current config** at `{{landingPage.configPath}}`
   - If file doesn't exist, create it with default structure:
     ```json
     {
       "enabled": false,
       "routes": [],
       "viewports": [],
       "devices": [],
       "gif": {
         "frameDelay": 2000,
         "quality": 10,
         "maxSize": 5242880
       },
       "outputDir": "{{landingPage.outputDir}}",
       "baseUrl": "{{deployment.frontend.url}}",
       "lastModified": "",
       "modifiedBy": ""
     }
     ```

2. **Determine the desired state:**
   - If argument is "enable": set `enabled: true`
   - If argument is "disable": set `enabled: false`
   - If no argument: toggle current state (flip the boolean)

3. **Update metadata:**
   - Set `lastModified` to current ISO timestamp
   - Set `modifiedBy: "Claude Code CLI"`

4. **Save the updated config**

5. **Rebuild the frontend:**
   ```bash
   {{#if (eq frontend.framework "vite")}}
   npm run build
   {{else if (eq frontend.framework "next")}}
   npm run build
   {{else if (eq frontend.framework "nuxt")}}
   npm run build
   {{/if}}
   ```

6. **Deploy to production:**
   ```bash
   {{#if (eq deployment.frontend.platform "cloudflare")}}
   npx wrangler pages deploy dist --project-name={{deployment.frontend.projectName}}
   {{else if (eq deployment.frontend.platform "vercel")}}
   vercel --prod
   {{else if (eq deployment.frontend.platform "netlify")}}
   netlify deploy --prod
   {{else if (eq deployment.frontend.platform "railway")}}
   # Use Railway MCP tool
   mcp__railway-mcp-server__deployment_trigger
   {{/if}}
   ```

7. **Display result:**
   ```
   ╔═══════════════════════════════════════════════════════╗
   ║  LANDING PAGE TOGGLE                                  ║
   ╠═══════════════════════════════════════════════════════╣
   ║  Status: {enabled ? "ENABLED" : "DISABLED"}           ║
   ║  Modified: {timestamp}                                ║
   ║  Modified By: Claude Code CLI                         ║
   ╠═══════════════════════════════════════════════════════╣
   ║  Effect                                               ║
   ╠═══════════════════════════════════════════════════════╣
   {#if enabled}
   ║  {{deployment.frontend.url}} → Landing Page           ║
   {else}
   ║  {{deployment.frontend.url}} → Main App               ║
   {/if}
   ╠═══════════════════════════════════════════════════════╣
   ║  Deployment                                           ║
   ╠═══════════════════════════════════════════════════════╣
   ║  Platform: {{deployment.frontend.platform}}           ║
   ║  Build: ✓ Completed                                   ║
   ║  Deploy: ✓ Success                                    ║
   ║  URL: {{deployment.frontend.url}}                     ║
   ╚═══════════════════════════════════════════════════════╝
   ```

## Router Integration

This toggle works by modifying the config file that your router reads. Ensure your router setup includes:

**React Router example:**
```tsx
// src/routes.tsx (or similar)
import landingPageConfig from './config/landingPage.json';

export const routes = landingPageConfig.enabled
  ? [
      { path: '/', element: <LandingPage /> },
      { path: '/app/*', element: <AppRoutes /> },
    ]
  : [
      { path: '/*', element: <AppRoutes /> },
    ];
```

**Next.js example:**
```tsx
// middleware.ts
import landingPageConfig from './config/landingPage.json';

export function middleware(request: NextRequest) {
  if (request.nextUrl.pathname === '/' && landingPageConfig.enabled) {
    return NextResponse.rewrite(new URL('/landing', request.url));
  }
}
```

---

## Notes

- **Requires**: Landing page assets to be generated first (use `/landing-page-generator pipeline`)
- **Category**: Deployment
- **Affects**: Production routing behavior
- **Safe**: Non-destructive (toggle is reversible)

---

*Part of Claude CLI Advanced Starter Pack*
