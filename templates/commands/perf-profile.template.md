---
description: Performance profiling and optimization analysis
type: project
complexity: medium
allowed-tools: Bash, Read, Grep, Glob
category: performance
---

# /perf-profile

Analyze application performance and identify optimization opportunities.

## Usage

```
/perf-profile
/perf-profile --web
/perf-profile --bundle
/perf-profile --runtime
```

## What It Does

1. **Web Performance** - Lighthouse audit for web apps
2. **Bundle Analysis** - Identify large dependencies
3. **Core Web Vitals** - Check LCP, FID, CLS
4. **Memory Profiling** - Memory leak detection
5. **Import Cost** - Analyze dependency sizes

---

## Step 1: Lighthouse Audit (Web Projects)

{{#if frontend.framework}}

Run Lighthouse on your application:

```bash
# Install Lighthouse CLI
npm install -g lighthouse

# Run audit (dev server must be running)
lighthouse http://localhost:{{frontend.devServerPort || 5173}} \
  --output=json \
  --output-path=./lighthouse-report.json \
  --only-categories=performance,accessibility,best-practices

# Parse results
cat lighthouse-report.json | jq '.categories.performance.score * 100'
```

### Key Metrics

- **Performance Score**: Target 90+
- **First Contentful Paint (FCP)**: Target < 1.8s
- **Largest Contentful Paint (LCP)**: Target < 2.5s
- **Total Blocking Time (TBT)**: Target < 200ms
- **Cumulative Layout Shift (CLS)**: Target < 0.1
- **Speed Index**: Target < 3.4s

### Report Format

```markdown
## Lighthouse Performance Report

**Overall Score:** 87/100

### Metrics
- FCP: 1.2s ✓
- LCP: 3.1s ✗ (Target: < 2.5s)
- TBT: 180ms ✓
- CLS: 0.05 ✓
- Speed Index: 2.8s ✓

### Opportunities
1. **Eliminate render-blocking resources** (-1.2s)
   - Move CSS critical path inline
   - Defer non-critical CSS

2. **Reduce unused JavaScript** (-0.8s)
   - Remove lodash (use native methods)
   - Tree-shake moment.js (use date-fns)

3. **Enable text compression** (-0.4s)
   - Enable Brotli/gzip on server
```

{{/if}}

---

## Step 2: Bundle Size Analysis

{{#if frontend.bundler}}

Analyze JavaScript bundle sizes:

### Vite Projects

```bash
# Build with bundle analysis
npm run build -- --mode production

# Install visualizer
npm install --save-dev rollup-plugin-visualizer

# Generate report
npx vite-bundle-visualizer
```

### Webpack Projects

```bash
# Install analyzer
npm install --save-dev webpack-bundle-analyzer

# Add to webpack.config.js
const BundleAnalyzerPlugin = require('webpack-bundle-analyzer').BundleAnalyzerPlugin;

module.exports = {
  plugins: [
    new BundleAnalyzerPlugin({
      analyzerMode: 'static',
      reportFilename: 'bundle-report.html'
    })
  ]
};

# Run build
npm run build
```

### Analysis Report

```markdown
## Bundle Size Report

**Total Size:** 1.2 MB (gzipped: 380 KB)

### Top 10 Dependencies by Size

| Package | Size | Gzipped | % of Total |
|---------|------|---------|-----------|
| lodash | 72 KB | 24 KB | 6.0% |
| moment | 67 KB | 18 KB | 5.6% |
| chart.js | 55 KB | 15 KB | 4.6% |
| react-icons | 48 KB | 12 KB | 4.0% |

### Optimization Opportunities

1. **Replace lodash with lodash-es** (-40 KB)
   ```bash
   npm uninstall lodash
   npm install lodash-es
   ```
   ```javascript
   // Before
   import _ from 'lodash';

   // After
   import { debounce, throttle } from 'lodash-es';
   ```

2. **Replace moment with date-fns** (-50 KB)
   ```bash
   npm uninstall moment
   npm install date-fns
   ```

3. **Code split routes** (-200 KB initial)
   ```javascript
   // Before
   import Dashboard from './pages/Dashboard';

   // After
   const Dashboard = lazy(() => import('./pages/Dashboard'));
   ```

4. **Tree-shake react-icons** (-30 KB)
   ```javascript
   // Before
   import { FaUser, FaHome } from 'react-icons/fa';

   // After
   import FaUser from 'react-icons/fa/FaUser';
   import FaHome from 'react-icons/fa/FaHome';
   ```
```

{{/if}}

---

## Step 3: Core Web Vitals Check

Monitor real-user metrics:

```javascript
// Add to your app
import { getCLS, getFID, getFCP, getLCP, getTTFB } from 'web-vitals';

function sendToAnalytics(metric) {
  console.log(metric);
  // Send to your analytics endpoint
  fetch('/api/vitals', {
    method: 'POST',
    body: JSON.stringify(metric)
  });
}

getCLS(sendToAnalytics);
getFID(sendToAnalytics);
getFCP(sendToAnalytics);
getLCP(sendToAnalytics);
getTTFB(sendToAnalytics);
```

### Thresholds

| Metric | Good | Needs Improvement | Poor |
|--------|------|-------------------|------|
| LCP | ≤ 2.5s | 2.5s - 4.0s | > 4.0s |
| FID | ≤ 100ms | 100ms - 300ms | > 300ms |
| CLS | ≤ 0.1 | 0.1 - 0.25 | > 0.25 |

---

## Step 4: Memory Profiling

{{#if backend.runtime}}

### Node.js Memory Profiling

```bash
# Run with memory profiling
node --inspect --expose-gc backend/main.js

# Generate heap snapshot
node --heap-prof backend/main.js

# Analyze with Chrome DevTools
# 1. Open chrome://inspect
# 2. Click "Open dedicated DevTools for Node"
# 3. Go to Memory tab
# 4. Take heap snapshot
```

### Memory Leak Detection

```javascript
// Add to your server
const heapdump = require('heapdump');

// Trigger snapshot
app.get('/heapdump', (req, res) => {
  heapdump.writeSnapshot((err, filename) => {
    res.send(`Snapshot written to ${filename}`);
  });
});
```

### Common Memory Leaks

1. **Unclosed database connections**
2. **Event listener accumulation**
3. **Global variable retention**
4. **Closure memory retention**
5. **Caching without bounds**

{{/if}}

---

## Step 5: Import Cost Analysis

Calculate the size cost of imports:

```bash
# Install import-cost CLI
npm install -g import-cost

# Analyze file
import-cost src/App.tsx
```

### VS Code Extension

Install `Import Cost` extension to see inline size indicators:

```typescript
import React from 'react';              // 2.5 KB (gzipped: 1.2 KB)
import _ from 'lodash';                 // 72 KB (gzipped: 24 KB) ⚠️
import moment from 'moment';            // 67 KB (gzipped: 18 KB) ⚠️
import { format } from 'date-fns';      // 5 KB (gzipped: 2 KB) ✓
```

---

## Step 6: Runtime Performance

### React Profiler

```javascript
import { Profiler } from 'react';

function onRenderCallback(
  id, // the "id" prop of the Profiler tree
  phase, // "mount" or "update"
  actualDuration, // time spent rendering
  baseDuration, // estimated time without memoization
  startTime, // when React began rendering
  commitTime, // when React committed the update
  interactions // Set of interactions for this update
) {
  console.log(`${id} took ${actualDuration}ms to render`);
}

<Profiler id="Dashboard" onRender={onRenderCallback}>
  <Dashboard />
</Profiler>
```

### Database Query Profiling

{{#if backend.database}}

```javascript
// Enable query logging
// PostgreSQL
SET log_statement = 'all';

// MySQL
SET GLOBAL general_log = 'ON';

// MongoDB
db.setProfilingLevel(2);

// Check slow queries
SELECT * FROM pg_stat_statements ORDER BY total_time DESC LIMIT 10;
```

{{/if}}

---

## Performance Report

```markdown
# Performance Profile Report

**Date:** [timestamp]
**Environment:** Production

## Summary

- **Overall Score:** B (82/100)
- **Load Time:** 2.8s (Target: < 2.0s)
- **Bundle Size:** 1.2 MB (Target: < 500 KB)
- **Memory Usage:** 45 MB (Acceptable)

## Critical Issues

### 1. Large Bundle Size (1.2 MB)
**Impact:** Slow initial load on 3G networks
**Optimization:**
- Code split routes (-400 KB)
- Replace moment with date-fns (-50 KB)
- Tree-shake lodash (-40 KB)
**Estimated Improvement:** 2.8s → 1.9s load time

### 2. Largest Contentful Paint (3.1s)
**Impact:** Poor perceived performance
**Optimization:**
- Lazy load images below fold
- Preload critical assets
- Optimize hero image (WebP)
**Estimated Improvement:** 3.1s → 2.2s LCP

## Recommendations

### Immediate (High Impact)
- [ ] Enable code splitting for routes
- [ ] Add image lazy loading
- [ ] Replace heavy dependencies

### Short Term (Medium Impact)
- [ ] Add CDN for static assets
- [ ] Enable Brotli compression
- [ ] Implement service worker caching

### Long Term (Low Impact)
- [ ] Migrate to SSR/SSG
- [ ] Add resource hints (prefetch/preconnect)
- [ ] Implement skeleton screens
```

---

## Configuration

Add to `package.json`:

```json
{
  "scripts": {
    "analyze": "vite-bundle-visualizer",
    "lighthouse": "lighthouse http://localhost:5173 --view",
    "perf": "node --prof server.js"
  }
}
```

---

## Continuous Monitoring

### Lighthouse CI

```yaml
# .github/workflows/lighthouse.yml
name: Lighthouse CI

on: [pull_request]

jobs:
  lighthouse:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: npm ci
      - run: npm run build
      - run: npm install -g @lhci/cli
      - run: lhci autorun
```

### Budget Configuration

```json
// lighthouserc.json
{
  "ci": {
    "assert": {
      "assertions": {
        "categories:performance": ["error", {"minScore": 0.9}],
        "first-contentful-paint": ["error", {"maxNumericValue": 2000}],
        "largest-contentful-paint": ["error", {"maxNumericValue": 2500}]
      }
    }
  }
}
```

---

## Related Commands

- `/security-scan` - Performance + security audit
- `/deploy-full` - Pre-deployment perf check
- `/create-smoke-test` - Add performance tests

---

*Performance profiling powered by CCASP*
