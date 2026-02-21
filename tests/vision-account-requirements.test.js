import test from 'node:test';
import assert from 'node:assert/strict';

import { detectAccountRequirements } from '../src/vision/analysis/account/requirements.js';

test('detectAccountRequirements accepts wrapped tools and mcpServers objects', () => {
  const requirements = detectAccountRequirements(
    { tools: [{ name: 'stripe' }] },
    { mcpServers: [{ server: 'github-mcp-server' }] }
  );

  const services = requirements.map(req => req.service);
  assert.ok(services.includes('GitHub'));
  assert.ok(services.includes('Stripe'));
});
