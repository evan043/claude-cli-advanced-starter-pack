---
description: Site Intelligence Dashboard - view health scores, route analysis, and scan diffs
---

# Site Intelligence Dashboard

Opens the Site Intelligence web dashboard showing last-known state without running a new scan. Provides visual exploration of route scores, health grades, diffs, and trend sparklines.

## Instructions

### Default Flow

1. First, check if dev scan state exists using `site_intel_dev_state` MCP tool
2. If state exists, display a quick summary:

```
╔══════════════════════════════════════════════════╗
║  DEV SCAN STATE                                   ║
╠══════════════════════════════════════════════════╣
║  Health: {score}/100 ({grade})                    ║
║  Routes: {totalRoutes}                            ║
║  TestID Coverage: {coverage}%                     ║
║  Last Scan: {lastScanTime} ({scanType})           ║
║  Latest Diffs: {improvements} up, {regressions} down
╚══════════════════════════════════════════════════╝
```

3. Start the dashboard server:

```bash
node -e "import('./src/site-intel/dashboard/server.js').then(m => m.startDashboard())"
```

4. Report: "Dashboard running at http://localhost:3847 - click the **Dev Scan** tab to see route scores and diffs."

5. Ask user if they want to:
   - **Run a dev scan** (full or incremental) to update the data
   - **Run a quick check** for fast testid coverage
   - **Just browse** the dashboard with existing data

### If No State Exists

1. Report that no dev scan has been run yet
2. Offer to run one:
   - **Quick Check** (fast, no Playwright, testid coverage only)
   - **Full Dev Scan** (Playwright-based, all metrics)
3. After running, start the dashboard

## Dashboard Features

The Dev Scan tab in the dashboard shows:

- **Health metrics**: Overall score, total routes, testid coverage, last scan time
- **Route score table**: Sortable by path, testid coverage, a11y violations, performance, health grade
- **Health grades**: Color-coded A (green) through F (red)
- **Diff section**: Improvements (green) and regressions (red) from latest scan
- **Trend sparklines**: Inline SVG showing health history
- **Filters**: All routes, failing only (<70% health), regressions only

## MCP Tools Used

| Tool | Purpose |
|------|---------|
| `site_intel_dev_state` | Read current state without scanning |
| `site_intel_dev_scan` | Run a new dev scan (full/incremental) |
| `site_intel_quick_check` | Run fast static testid check |
