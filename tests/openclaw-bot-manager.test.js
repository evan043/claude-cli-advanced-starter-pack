import test from 'node:test';
import assert from 'node:assert/strict';
import { OpenClawBotManager } from '../src/openclaw/bot-manager.js';

function admin(actor = 'admin-user') {
  return { role: 'admin', actor };
}

function operator(actor = 'ops-user') {
  return { role: 'operator', actor };
}

function viewer(actor = 'viewer-user') {
  return { role: 'viewer', actor };
}

test('plugin manifest validation rejects invalid schema', () => {
  const m = new OpenClawBotManager({ coreVersion: '1.2.0' });
  assert.throws(() => m.createPlugin({ name: 'No ID', version: '1.0.0' }, admin()), /required field: id/);
  assert.throws(() => m.createPlugin({ id: 'Bad ID', name: 'Bad', version: '1.0.0' }, admin()), /kebab-case/);
});

test('plugin CRUD and compatibility checks work', () => {
  const m = new OpenClawBotManager({ coreVersion: '1.2.0' });
  const p1 = m.createPlugin(
    { id: 'metrics-plugin', name: 'Metrics', version: '1.0.0', minCoreVersion: '1.1.0', maxCoreVersion: '1.3.0' },
    admin()
  );
  assert.equal(p1.id, 'metrics-plugin');
  assert.equal(m.listPlugins(admin()).length, 1);

  const updated = m.updatePlugin('metrics-plugin', { version: '1.1.0' }, admin());
  assert.equal(updated.version, '1.1.0');
  assert.equal(m.getPlugin('metrics-plugin', admin()).version, '1.1.0');

  assert.throws(
    () => m.updatePlugin('metrics-plugin', { minCoreVersion: '2.0.0' }, admin()),
    /incompatible/
  );

  const deleted = m.deletePlugin('metrics-plugin', admin());
  assert.equal(deleted.deleted, true);
  assert.equal(m.listPlugins(admin()).length, 0);
});

test('lifecycle commands enforce state machine and idempotency', () => {
  const m = new OpenClawBotManager({ coreVersion: '1.0.0' });
  m.createPlugin({ id: 'core-plugin', name: 'Core', version: '1.0.0' }, admin());
  m.createBot({ id: 'bot-1', name: 'Bot 1', pluginId: 'core-plugin' }, operator());

  let r = m.commandBot('bot-1', 'start', operator());
  assert.equal(r.changed, true);
  assert.equal(r.status, 'running');

  r = m.commandBot('bot-1', 'start', operator());
  assert.equal(r.changed, false);
  assert.equal(r.status, 'running');

  r = m.commandBot('bot-1', 'suspend', operator());
  assert.equal(r.status, 'suspended');

  r = m.commandBot('bot-1', 'resume', operator());
  assert.equal(r.status, 'running');

  r = m.commandBot('bot-1', 'stop', operator());
  assert.equal(r.status, 'stopped');
});

test('rollout and rollback orchestration restores last known good plugin', () => {
  const m = new OpenClawBotManager({ coreVersion: '1.0.0' });
  m.createPlugin({ id: 'plugin-a', name: 'Plugin A', version: '1.0.0' }, admin());
  m.createPlugin({ id: 'plugin-b', name: 'Plugin B', version: '2.0.0' }, admin());
  m.createBot({ id: 'bot-2', name: 'Bot 2', pluginId: 'plugin-a' }, operator());

  const deploy = m.deployBotPlugin('bot-2', 'plugin-b', operator());
  assert.equal(deploy.deployed, true);
  assert.equal(m.getBot('bot-2', operator()).pluginId, 'plugin-b');

  const rollback = m.rollbackBot('bot-2', operator());
  assert.equal(rollback.rolledBack, true);
  assert.equal(m.getBot('bot-2', operator()).pluginId, 'plugin-a');
});

test('RBAC guards block unauthorized management operations', () => {
  const m = new OpenClawBotManager({ coreVersion: '1.0.0' });
  m.createPlugin({ id: 'p', name: 'P', version: '1.0.0' }, admin());
  assert.throws(
    () => m.createBot({ id: 'b', name: 'B', pluginId: 'p' }, viewer()),
    /missing permission/
  );
});

test('audit event pipeline records lifecycle and permission events', () => {
  const m = new OpenClawBotManager({ coreVersion: '1.0.0' });
  m.createPlugin({ id: 'audit-plugin', name: 'Audit Plugin', version: '1.0.0' }, admin());
  m.createBot({ id: 'audit-bot', name: 'Audit Bot', pluginId: 'audit-plugin' }, operator());
  m.commandBot('audit-bot', 'start', operator());
  assert.throws(() => m.deletePlugin('audit-plugin', viewer()), /missing permission/);

  const events = m.getAuditEvents(admin());
  assert.ok(events.length >= 3);
  const denied = events.find((e) => e.action === 'rbac.denied');
  assert.ok(denied);
});

test('policy hooks can block deployment and failed rollout is tracked', () => {
  const m = new OpenClawBotManager({ coreVersion: '1.0.0' });
  m.createPlugin({ id: 'plugin-safe', name: 'Safe', version: '1.0.0' }, admin());
  m.createPlugin({ id: 'plugin-risky', name: 'Risky', version: '2.0.0' }, admin());
  m.createBot({ id: 'bot-3', name: 'Bot 3', pluginId: 'plugin-safe' }, operator());

  m.registerPolicyHook(({ plugin }) => {
    if (plugin.id === 'plugin-risky') {
      return { allowed: false, reason: 'blocked by trust policy' };
    }
    return { allowed: true };
  });

  assert.throws(
    () => m.deployBotPlugin('bot-3', 'plugin-risky', operator()),
    /Policy blocked deployment/
  );
  const report = m.getHealthReport(operator());
  assert.equal(report.failedRollouts, 1);
});

test('health report includes drift detection', () => {
  const m = new OpenClawBotManager({ coreVersion: '1.0.0' });
  m.createPlugin({ id: 'plugin-drift', name: 'Drift', version: '1.0.0' }, admin());
  m.createBot({ id: 'bot-4', name: 'Bot 4', pluginId: 'plugin-drift' }, operator());

  m.updatePlugin('plugin-drift', { version: '1.1.0' }, admin());
  const report = m.getHealthReport(operator());
  assert.equal(report.botCount, 1);
  assert.equal(report.pluginDrift.length, 1);
  assert.equal(report.pluginDrift[0].botId, 'bot-4');
});
