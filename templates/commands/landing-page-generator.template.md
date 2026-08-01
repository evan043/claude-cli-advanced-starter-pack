---
description: Landing Page Generator - Create marketing assets with screenshots, device frames, and GIFs
model: sonnet
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Task
  - AskUserQuestion
  - Glob
  - Grep
  - ToolSearch
options:
  - label: "Configure"
    description: "Set up screenshot routes, viewports, device frames, output paths"
  - label: "Capture"
    description: "Run Playwright screenshot pipeline"
  - label: "Frame"
    description: "Apply device bezels to screenshots"
  - label: "Generate GIFs"
    description: "Stitch framed screenshots into animated GIFs"
  - label: "Preview"
    description: "Open landing page in browser via Playwright"
  - label: "Build Components"
    description: "Generate React landing page components"
  - label: "Full Pipeline"
    description: "Run all steps in sequence"
  - label: "Deploy"
    description: "Build and deploy landing page"
---

# Landing Page Generator

{{#if panel_config}}
**Panel config gate:** If `panel_config.features.landing_page_generator === false`, skip this entire command.
Display: "Landing page generator skipped (disabled in panel config)."
{{/if}}

Automated marketing asset generation system. Captures screenshots of your app with Playwright, composites them into device frames (MacBook Pro, iPhone, etc.), generates animated GIFs, and builds professional landing page components.

## Arguments

- `/landing-page-generator` — Show menu of actions
- `/landing-page-generator configure` — Interactive configuration setup
- `/landing-page-generator capture [route-name]` — Capture screenshots
- `/landing-page-generator frame [device]` — Apply device frames
- `/landing-page-generator generate-gifs` — Create animated GIFs
- `/landing-page-generator preview` — Open landing page in browser
- `/landing-page-generator build` — Generate React components
- `/landing-page-generator pipeline` — Run full pipeline
- `/landing-page-generator deploy` — Build and deploy landing page

## Configuration

The landing page generator requires a configuration file at:
```
{{landingPage.configPath}}
```

If this file doesn't exist, the "Configure" action will create it with defaults.

### Config Structure

```json
{
  "enabled": true,
  "routes": [
    {
      "path": "/dashboard",
      "name": "Dashboard",
      "waitFor": "[data-testid='dashboard-loaded']"
    }
  ],
  "viewports": [
    { "name": "desktop", "width": 1440, "height": 900 },
    { "name": "mobile", "width": 390, "height": 844 }
  ],
  "devices": [
    {
      "name": "macbook-pro",
      "bezelPath": "assets/device-frames/macbook-pro-16.png",
      "screenRegion": { "x": 112, "y": 80, "width": 1920, "height": 1200 }
    }
  ],
  "gif": {
    "frameDelay": 2000,
    "quality": 10,
    "maxSize": 5242880
  },
  "outputDir": "{{landingPage.outputDir}}",
  "baseUrl": "{{deployment.frontend.url}}"
}
```

## Instructions

### Action: Configure

When the user requests configuration (or selects "Configure"):

1. Check if config file exists at `{{landingPage.configPath}}`
2. If not exists:
   - Use `AskUserQuestion` to gather:
     - Output directory (default: `public/landing-assets`)
     - Routes to capture (comma-separated paths)
     - Base URL for local dev (default: `http://localhost:{{deployment.frontend.port}}`)
   - Create config file with defaults
3. If exists:
   - Read current config
   - Use `AskUserQuestion` to offer modification options:
     - Add new route
     - Edit viewport settings
     - Change device frame settings
     - Update GIF quality settings
   - Apply changes and save

### Action: Capture

When the user requests screenshot capture:

1. Verify config file exists (if not, run Configure first)
2. Read config from `{{landingPage.configPath}}`
3. Load the Playwright MCP tool:
   ```
   Use ToolSearch to load: "playwright navigate screenshot"
   ```
4. For each route in config:
   - For each viewport in config:
     - Navigate to `{baseUrl}{route.path}`
     - If `waitFor` specified, wait for selector
     - Resize to viewport dimensions
     - Capture screenshot to `{outputDir}/screenshots/{route.name}-{viewport.name}.png`
5. Display summary:
   ```
   ╔══════════════════════════════════════════════════════╗
   ║  SCREENSHOT CAPTURE COMPLETE                         ║
   ╠══════════════════════════════════════════════════════╣
   ║  Routes Captured: {routeCount}                       ║
   ║  Viewports: {viewportCount}                          ║
   ║  Total Screenshots: {total}                          ║
   ║  Output Directory: {outputDir}/screenshots/          ║
   ╚══════════════════════════════════════════════════════╝
   ```

### Action: Frame

When the user requests device framing:

1. Verify screenshots exist in `{outputDir}/screenshots/`
2. Read config from `{{landingPage.configPath}}`
3. Check if `sharp` NPM package is installed:
   ```bash
   npm list sharp || npm install sharp
   ```
4. For each screenshot:
   - Match to appropriate device frame based on viewport dimensions
   - Use Sharp to composite screenshot into device bezel
   - Output to `{outputDir}/framed/{basename}-framed.png`
5. Display summary with frame count

**Sharp composite pattern:**
```typescript
import sharp from 'sharp';

await sharp(bezelPath)
  .composite([{
    input: screenshotPath,
    top: screenRegion.y,
    left: screenRegion.x,
    blend: 'over'
  }])
  .resize(outputSize.width, outputSize.height)
  .toFile(outputPath);
```

### Action: Generate GIFs

When the user requests GIF generation:

1. Verify framed screenshots exist in `{outputDir}/framed/`
2. Read config from `{{landingPage.configPath}}`
3. Check NPM packages:
   ```bash
   npm list gifencoder canvas || npm install gifencoder canvas
   ```
4. Group framed screenshots by device type
5. For each device group:
   - Use gifencoder + canvas to stitch frames
   - Apply frameDelay and quality from config
   - Output to `{outputDir}/gifs/{device}-demo.gif`
6. Verify file sizes (warn if > maxSize from config)
7. Display summary with file sizes

**GIF encoder pattern:**
```typescript
import GIFEncoder from 'gifencoder';
import { createCanvas, loadImage } from 'canvas';
import fs from 'fs';

const encoder = new GIFEncoder(width, height);
encoder.createReadStream().pipe(fs.createWriteStream(outputPath));
encoder.start();
encoder.setRepeat(0);
encoder.setDelay(frameDelay);
encoder.setQuality(quality);

for (const framePath of framePaths) {
  const image = await loadImage(framePath);
  const canvas = createCanvas(width, height);
  const ctx = canvas.getContext('2d');
  ctx.drawImage(image, 0, 0, width, height);
  encoder.addFrame(ctx);
}

encoder.finish();
```

### Action: Preview

When the user requests preview:

1. Verify landing page route exists (typically `/landing`)
2. Load Playwright MCP tool
3. Navigate to landing page URL
4. Take screenshot for visual confirmation
5. Keep browser open for manual inspection
6. Display: "Landing page opened in browser. Use Ctrl+C to close when done."

### Action: Build Components

When the user requests component generation:

1. Read config from `{{landingPage.configPath}}`
2. Generate React component files:
   - `{{frontend.componentPath}}/landing/HeroGIF.tsx` — Animated GIF hero section
   - `{{frontend.componentPath}}/landing/FeatureGallery.tsx` — Grid of feature cards
   - `{{frontend.componentPath}}/landing/StoreBadges.tsx` — App store download badges
3. Generate route file:
   - `{{frontend.pagesPath}}/LandingPage.tsx`
4. Update router configuration (if needed)
5. Display file paths created

**HeroGIF component pattern:**
```tsx
export function HeroGIF() {
  return (
    <div className="hero-section">
      <img
        src="/landing-assets/gifs/macbook-demo.gif"
        alt="App Demo"
        className="hero-gif"
      />
    </div>
  );
}
```

### Action: Full Pipeline

When the user requests full pipeline:

1. Run Configure (if config doesn't exist)
2. Run Capture
3. Run Frame
4. Run Generate GIFs
5. Run Build Components
6. Display complete summary with all artifacts

### Action: Deploy

When the user requests deployment:

1. Verify all assets exist in `{outputDir}/`
2. Run build command:
   ```bash
   {{#if (eq frontend.framework "vite")}}
   npm run build
   {{else if (eq frontend.framework "next")}}
   npm run build
   {{/if}}
   ```
3. Deploy based on platform:
   ```
   {{#if (eq deployment.frontend.platform "cloudflare")}}
   npx wrangler pages deploy dist --project-name={{deployment.frontend.projectName}}
   {{else if (eq deployment.frontend.platform "vercel")}}
   vercel --prod
   {{else if (eq deployment.frontend.platform "netlify")}}
   netlify deploy --prod
   {{/if}}
   ```
4. Display deployment URL

## Skill Integration

This command works with the `/screenshot-pipeline` skill package. For detailed documentation on:
- Device frame catalog
- Viewport presets
- Pipeline configuration options

Use: `/help screenshot-pipeline` or check `.claude/skills/screenshot-pipeline/`

## Required NPM Packages

- `playwright` (usually already installed)
- `sharp` (image compositing)
- `gifencoder` (GIF creation)
- `canvas` (Node canvas for gifencoder)

The command will check for these and prompt to install if missing.

## MCP Tools Required

- `playwright-ext` MCP server for browser automation

Use `/explore-mcp playwright` if not configured.

---

*Part of Claude CLI Advanced Starter Pack*
