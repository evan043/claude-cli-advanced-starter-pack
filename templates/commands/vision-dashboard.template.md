---
description: Start Vision Dashboard web interface for real-time monitoring
options:
  - label: "Default"
    description: "Start on localhost:3847"
  - label: "Custom Port"
    description: "Specify custom port number"
---

# Vision Dashboard - Web Interface

Start a web-based dashboard for real-time Vision status monitoring with WebSocket updates.

**Features:**
- Real-time vision status updates
- Progress and alignment tracking
- Drift event monitoring
- Roadmap completion tracking
- Dark mode UI

---

## Execution Protocol

### Step 1: Start Dashboard Server

```javascript
import { startDashboard } from '${CWD}/node_modules/claude-cli-advanced-starter-pack/src/vision/dashboard/server.js';

const port = args[0] ? parseInt(args[0]) : 3847;
const host = 'localhost';

console.log('Starting Vision Dashboard...');

try {
  const server = await startDashboard(projectRoot, { port, host });

  console.log(`
┌─────────────────────────────────────────────────┐
│         VISION DASHBOARD RUNNING                │
├─────────────────────────────────────────────────┤
│                                                 │
│  URL: http://${host}:${port}                    │
│                                                 │
│  Features:                                      │
│  • Real-time status updates (WebSocket)         │
│  • Progress and alignment tracking              │
│  • Drift event monitoring                       │
│  • Roadmap completion tracking                  │
│                                                 │
│  Press Ctrl+C to stop                           │
│                                                 │
└─────────────────────────────────────────────────┘
  `);
} catch (error) {
  console.error('Failed to start dashboard:', error.message);
}
```

### Step 2: Display Dashboard Info

```
╔════════════════════════════════════════════════════════════════════════════╗
║                        VISION DASHBOARD                                     ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
║  Dashboard URL: http://localhost:{{port}}                                   ║
║                                                                             ║
║  API Endpoints:                                                             ║
║    GET /api/visions           - List all visions with status                ║
║    GET /api/vision/{slug}     - Get specific vision details                 ║
║                                                                             ║
║  WebSocket:                                                                 ║
║    ws://localhost:{{port}}    - Real-time updates                           ║
║                                                                             ║
║  Messages:                                                                  ║
║    { type: 'subscribe', slug: 'my-vision' }  - Subscribe to vision          ║
║    { type: 'refresh' }                       - Force refresh                ║
║                                                                             ║
╠════════════════════════════════════════════════════════════════════════════╣
║  Dashboard Features                                                         ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
║  • Summary Cards: Total, Active, Completed, Drift Events                    ║
║  • Vision List: Filterable by status                                        ║
║  • Progress Bars: Completion and alignment tracking                         ║
║  • Detail Modal: Click any vision for full details                          ║
║  • Quick Actions: Copy commands for vision operations                       ║
║                                                                             ║
╚════════════════════════════════════════════════════════════════════════════╝
```

## CLI Alternative

```bash
# Start dashboard on default port (3847)
ccasp vision dashboard

# Start on custom port
ccasp vision dashboard --port 8080

# Start on custom host
ccasp vision dashboard --host 0.0.0.0 --port 3847
```

## Argument Handling

- `/vision-dashboard` - Start on default port (3847)
- `/vision-dashboard {port}` - Start on custom port

## Dashboard UI Sections

### Summary Cards
- **Total Visions**: Count of all visions
- **In Progress**: Actively executing visions
- **Completed**: Successfully completed visions
- **Drift Events**: Total drift events across all visions

### Vision List
Each vision card displays:
- Title and slug
- Status badge (with emoji)
- Progress bar (completion %)
- Alignment bar (with warning colors)
- Roadmaps completed/total
- Drift event count
- Current orchestrator stage

### Vision Detail Modal
Click any vision to see:
- Full status overview
- Stage information
- Roadmap progress breakdown
- Observer metrics
- Quick action buttons

## WebSocket Protocol

### Connection
```javascript
const ws = new WebSocket('ws://localhost:3847');
```

### Server Messages
```json
{
  "type": "update",
  "timestamp": "2026-02-05T12:00:00Z",
  "visions": [
    {
      "slug": "my-vision",
      "title": "My Vision",
      "status": "executing",
      "completion": 45,
      "alignment": 0.95,
      "roadmaps": { "total": 5, "completed": 2 },
      "driftEvents": 1
    }
  ]
}
```

### Client Messages
```json
// Subscribe to specific vision
{ "type": "subscribe", "slug": "my-vision" }

// Force refresh
{ "type": "refresh" }
```

## Status Colors

| Status | Background | Text |
|--------|------------|------|
| executing | Blue | Light Blue |
| completed | Green | Light Green |
| paused | Yellow | Orange |
| failed | Red | Light Red |
| analyzing/architecting | Purple | Light Purple |

## Related Commands

- `/vision-init` - Initialize new Vision
- `/vision-status` - CLI status display
- `/vision-run` - Start execution
- `/vision-adjust` - Adjust Vision plan

---

*Vision Dashboard - Part of CCASP Vision Mode (Phase 9)*
