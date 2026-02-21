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
# monitoring-setup — Codex Runtime

This command configures monitoring for your deployed services. Railway MCP is unavailable in Codex.

## What I Can Do

1. Generate monitoring configuration files (uptime checks, alert rules)
2. Show you the Railway CLI commands to set up monitoring
3. Provide curl commands to manually test health endpoints

## Manual Railway Monitoring Setup

```bash
# Install Railway CLI if needed
npm install -g @railway/cli
railway login

# List your services
railway status

# Set up environment variables for monitoring
railway variables set MONITORING_ENABLED=true
```

## Alternative: Uptime Monitors

I can generate configuration for third-party monitors (UptimeRobot, BetterUptime, etc.) that work without Railway MCP. Just tell me your service URLs.

**For full Railway MCP monitoring setup, use Claude Code CLI: `/monitoring-setup`**
<!-- CODEX-OVERRIDE:END -->
---
description: Set up monitoring and observability for your application
type: project
complexity: medium
allowed-tools: Bash, Read, Write, Grep, Glob
category: devops
---

# /monitoring-setup

Set up comprehensive monitoring, error tracking, and observability for your application.

## Usage

```
/monitoring-setup
/monitoring-setup --error-tracking
/monitoring-setup --apm
/monitoring-setup --logs
```

## What It Does

1. **Error Tracking** - Set up Sentry or similar
2. **Application Performance Monitoring** - APM integration
3. **Log Aggregation** - Structured logging setup
4. **Health Checks** - Endpoint creation
5. **Alerting** - Configure notifications
6. **Dashboards** - Monitoring dashboard setup

---

## Step 1: Detect Project Type

Analyze tech stack to recommend appropriate monitoring tools:

{{#if frontend.framework}}
**Frontend Framework:** {{frontend.framework}}
{{/if}}

{{#if backend.framework}}
**Backend Framework:** {{backend.framework}}
{{/if}}

{{#if backend.database}}
**Database:** {{backend.database}}
{{/if}}

### Recommended Stack

| Component | Tool | Free Tier |
|-----------|------|-----------|
| Error Tracking | Sentry | 5K errors/month |
| APM | New Relic / DataDog | Limited |
| Logs | Better Stack / Logtail | 1GB/month |
| Uptime | UptimeRobot | 50 monitors |
| Analytics | PostHog | 1M events/month |

---

## Step 2: Error Tracking Setup (Sentry)

### Installation

```bash
# Frontend
npm install @sentry/react

# Backend (Node.js)
npm install @sentry/node @sentry/tracing

# Backend (Python)
pip install sentry-sdk[fastapi]
```

### Frontend Configuration (React)

{{#if (eq frontend.framework "react")}}

Create `src/utils/sentry.ts`:

```typescript
import * as Sentry from '@sentry/react';
import { BrowserTracing } from '@sentry/tracing';

export function initSentry() {
  if (import.meta.env.PROD) {
    Sentry.init({
      dsn: import.meta.env.VITE_SENTRY_DSN,
      integrations: [
        new BrowserTracing(),
        new Sentry.Replay({
          maskAllText: false,
          blockAllMedia: false,
        }),
      ],
      tracesSampleRate: 0.1, // 10% of transactions
      replaysSessionSampleRate: 0.1,
      replaysOnErrorSampleRate: 1.0, // 100% on errors
      environment: import.meta.env.MODE,
    });
  }
}
```

Update `src/main.tsx`:

```typescript
import { initSentry } from './utils/sentry';

initSentry();

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
```

Add error boundary:

```typescript
import { ErrorBoundary } from '@sentry/react';

function App() {
  return (
    <ErrorBoundary fallback={<ErrorFallback />}>
      <YourApp />
    </ErrorBoundary>
  );
}
```

{{/if}}

### Backend Configuration (Node.js)

{{#if (eq backend.runtime "node")}}

Update backend entry point:

```javascript
const Sentry = require('@sentry/node');
const { ProfilingIntegration } = require('@sentry/profiling-node');

// Initialize Sentry FIRST
Sentry.init({
  dsn: process.env.SENTRY_DSN,
  integrations: [
    new Sentry.Integrations.Http({ tracing: true }),
    new Sentry.Integrations.Express({ app }),
    new ProfilingIntegration(),
  ],
  tracesSampleRate: 0.1,
  profilesSampleRate: 0.1,
  environment: process.env.NODE_ENV,
});

// Add request handler (BEFORE routes)
app.use(Sentry.Handlers.requestHandler());
app.use(Sentry.Handlers.tracingHandler());

// Add routes here
app.use('/api', routes);

// Add error handler (AFTER routes)
app.use(Sentry.Handlers.errorHandler());

// Optional: custom error handler
app.use((err, req, res, next) => {
  res.status(500).json({ error: 'Internal Server Error' });
});
```

{{/if}}

### Backend Configuration (Python/FastAPI)

{{#if (eq backend.framework "fastapi")}}

Update `backend/main.py`:

```python
import sentry_sdk
from sentry_sdk.integrations.fastapi import FastApiIntegration
from sentry_sdk.integrations.sqlalchemy import SqlalchemyIntegration

sentry_sdk.init(
    dsn=os.getenv("SENTRY_DSN"),
    integrations=[
        FastApiIntegration(),
        SqlalchemyIntegration(),
    ],
    traces_sample_rate=0.1,
    profiles_sample_rate=0.1,
    environment=os.getenv("ENVIRONMENT", "production"),
)

app = FastAPI()
```

{{/if}}

### Environment Variables

Add to `.env`:

```bash
SENTRY_DSN=https://your-sentry-dsn@sentry.io/project-id
SENTRY_ORG=your-org
SENTRY_PROJECT=your-project
```

---

## Step 3: Application Performance Monitoring

### Option A: New Relic

```bash
# Install agent
npm install newrelic

# Generate config
npx newrelic install
```

Create `newrelic.js`:

```javascript
exports.config = {
  app_name: ['{{projectName}}'],
  license_key: process.env.NEW_RELIC_LICENSE_KEY,
  logging: {
    level: 'info',
  },
  distributed_tracing: {
    enabled: true,
  },
  application_logging: {
    forwarding: {
      enabled: true,
    },
  },
};
```

Require at app entry:

```javascript
require('newrelic');
const express = require('express');
// ... rest of your app
```

### Option B: DataDog (Node.js)

```bash
npm install dd-trace --save
```

Create `dd-trace.js`:

```javascript
const tracer = require('dd-trace').init({
  service: '{{projectName}}',
  env: process.env.NODE_ENV,
  logInjection: true,
  profiling: true,
  runtimeMetrics: true,
});

module.exports = tracer;
```

Require first:

```javascript
require('./dd-trace');
const express = require('express');
// ... rest of your app
```

### Custom Transaction Tracking

```javascript
// Track custom transactions
const Sentry = require('@sentry/node');

app.get('/api/expensive-operation', async (req, res) => {
  const transaction = Sentry.startTransaction({
    op: 'expensive-operation',
    name: 'Process Large Dataset',
  });

  try {
    const span = transaction.startChild({ op: 'db.query' });
    const data = await processData();
    span.finish();

    res.json(data);
  } catch (err) {
    transaction.setStatus('internal_error');
    throw err;
  } finally {
    transaction.finish();
  }
});
```

---

## Step 4: Structured Logging

### Winston (Node.js)

```bash
npm install winston
```

Create `src/utils/logger.js`:

```javascript
const winston = require('winston');

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: {
    service: '{{projectName}}',
    environment: process.env.NODE_ENV,
  },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      ),
    }),
    new winston.transports.File({
      filename: 'logs/error.log',
      level: 'error',
    }),
    new winston.transports.File({
      filename: 'logs/combined.log',
    }),
  ],
});

module.exports = logger;
```

Usage:

```javascript
const logger = require('./utils/logger');

logger.info('User logged in', { userId: user.id });
logger.error('Database connection failed', { error: err.message });
logger.warn('Rate limit approaching', { userId, requestCount });
```

### Python Logging (FastAPI)

```python
import logging
from logging.handlers import RotatingFileHandler
import json

class JsonFormatter(logging.Formatter):
    def format(self, record):
        log_data = {
            'timestamp': self.formatTime(record),
            'level': record.levelname,
            'message': record.getMessage(),
            'service': '{{projectName}}',
        }
        if record.exc_info:
            log_data['exception'] = self.formatException(record.exc_info)
        return json.dumps(log_data)

logger = logging.getLogger('{{projectName}}')
logger.setLevel(logging.INFO)

handler = RotatingFileHandler('logs/app.log', maxBytes=10485760, backupCount=5)
handler.setFormatter(JsonFormatter())
logger.addHandler(handler)
```

---

## Step 5: Health Check Endpoints

### Backend Health Check

{{#if backend.framework}}

Create `backend/routers/health.py` or `routes/health.js`:

**Node.js/Express:**

```javascript
const express = require('express');
const router = express.Router();

router.get('/health', async (req, res) => {
  const health = {
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    checks: {
      database: await checkDatabase(),
      redis: await checkRedis(),
      external_api: await checkExternalAPI(),
    },
  };

  const isHealthy = Object.values(health.checks).every(check => check.status === 'ok');

  res.status(isHealthy ? 200 : 503).json(health);
});

async function checkDatabase() {
  try {
    await db.query('SELECT 1');
    return { status: 'ok', latency: '5ms' };
  } catch (err) {
    return { status: 'error', message: err.message };
  }
}

async function checkRedis() {
  try {
    await redis.ping();
    return { status: 'ok' };
  } catch (err) {
    return { status: 'error', message: err.message };
  }
}

async function checkExternalAPI() {
  try {
    const start = Date.now();
    await fetch('https://api.example.com/health');
    const latency = Date.now() - start;
    return { status: 'ok', latency: `${latency}ms` };
  } catch (err) {
    return { status: 'degraded', message: err.message };
  }
}

module.exports = router;
```

**Python/FastAPI:**

```python
from fastapi import APIRouter, Response
from datetime import datetime
import time

router = APIRouter()

@router.get("/health")
async def health_check(response: Response):
    health = {
        "status": "ok",
        "timestamp": datetime.utcnow().isoformat(),
        "checks": {
            "database": await check_database(),
            "redis": await check_redis(),
        }
    }

    is_healthy = all(
        check["status"] == "ok"
        for check in health["checks"].values()
    )

    response.status_code = 200 if is_healthy else 503
    return health

async def check_database():
    try:
        await db.execute("SELECT 1")
        return {"status": "ok"}
    except Exception as e:
        return {"status": "error", "message": str(e)}
```

{{/if}}

### Readiness vs Liveness

```javascript
// Liveness: Is the service running?
app.get('/healthz', (req, res) => {
  res.status(200).send('OK');
});

// Readiness: Is the service ready to accept traffic?
app.get('/ready', async (req, res) => {
  const ready = await checkDependencies();
  res.status(ready ? 200 : 503).json({ ready });
});
```

---

## Step 6: Alerting Configuration

### Sentry Alerts

Configure in Sentry dashboard:

1. **High Error Rate**: Alert when error rate > 10/minute
2. **New Issue**: Alert on first occurrence of new error
3. **Regression**: Alert when resolved issue reappears
4. **Performance Degradation**: Alert when p95 latency > 2s

### Uptime Monitoring (UptimeRobot)

```bash
# Health check URLs to monitor
{{deployment.backend.productionUrl}}/health
{{deployment.frontend.productionUrl}}
```

Configuration:
- Monitor Type: HTTP(s)
- Interval: 5 minutes
- Alert Contacts: Email, Slack, SMS

### Custom Alerts

```javascript
// Alert on high memory usage
const os = require('os');

setInterval(() => {
  const freeMem = os.freemem();
  const totalMem = os.totalmem();
  const usedPercent = ((totalMem - freeMem) / totalMem) * 100;

  if (usedPercent > 90) {
    logger.error('High memory usage', { usedPercent });
    Sentry.captureMessage('High memory usage', {
      level: 'warning',
      extra: { usedPercent },
    });
  }
}, 60000); // Check every minute
```

---

## Step 7: Dashboard Setup

### Grafana Dashboard (if using Prometheus)

```yaml
# docker-compose.yml
version: '3'
services:
  prometheus:
    image: prom/prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml

  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
```

### Custom Monitoring Dashboard

Create `.claude/monitoring/dashboard.html`:

```html
<!DOCTYPE html>
<html>
<head>
  <title>{{projectName}} Monitoring</title>
</head>
<body>
  <h1>System Health</h1>
  <iframe src="{{deployment.backend.productionUrl}}/health" width="100%" height="400"></iframe>

  <h1>Sentry Errors</h1>
  <iframe src="https://sentry.io/..." width="100%" height="600"></iframe>

  <h1>Uptime Status</h1>
  <iframe src="https://stats.uptimerobot.com/..." width="100%" height="400"></iframe>
</body>
</html>
```

---

## Configuration Summary

### Environment Variables

Add to `.env`:

```bash
# Sentry
SENTRY_DSN=https://...@sentry.io/...
SENTRY_ORG=your-org
SENTRY_PROJECT=your-project

# New Relic (optional)
NEW_RELIC_LICENSE_KEY=...
NEW_RELIC_APP_NAME={{projectName}}

# DataDog (optional)
DD_API_KEY=...
DD_SITE=datadoghq.com

# Logging
LOG_LEVEL=info
```

### Package.json Scripts

```json
{
  "scripts": {
    "logs": "tail -f logs/combined.log",
    "logs:error": "tail -f logs/error.log",
    "monitor": "open http://localhost:3000/health"
  }
}
```

---

## Related Commands

- `/security-scan` - Security monitoring setup
- `/deploy-full` - Add monitoring to deployment
- `/perf-profile` - Performance monitoring

---

*Monitoring setup powered by CCASP*
