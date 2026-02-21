/**
 * OpenClaw Bot Management
 *
 * Plugin registry + lifecycle control + governance primitives.
 */

const DEFAULT_PERMISSIONS = {
  admin: new Set([
    'plugin:create',
    'plugin:read',
    'plugin:update',
    'plugin:delete',
    'bot:create',
    'bot:read',
    'bot:manage',
    'bot:deploy',
    'bot:rollback',
    'report:read'
  ]),
  operator: new Set([
    'plugin:read',
    'bot:create',
    'bot:read',
    'bot:manage',
    'bot:deploy',
    'bot:rollback',
    'report:read'
  ]),
  viewer: new Set(['plugin:read', 'bot:read', 'report:read'])
};

const BOT_STATES = new Set(['created', 'running', 'stopped', 'suspended', 'failed']);

function nowIso() {
  return new Date().toISOString();
}

function parseVersion(value) {
  return String(value || '0.0.0')
    .split('.')
    .map((v) => Number.parseInt(v, 10) || 0)
    .slice(0, 3);
}

function compareVersions(a, b) {
  const pa = parseVersion(a);
  const pb = parseVersion(b);
  for (let i = 0; i < 3; i++) {
    if (pa[i] > pb[i]) return 1;
    if (pa[i] < pb[i]) return -1;
  }
  return 0;
}

function isVersionInRange(coreVersion, minCoreVersion, maxCoreVersion) {
  if (minCoreVersion && compareVersions(coreVersion, minCoreVersion) < 0) return false;
  if (maxCoreVersion && compareVersions(coreVersion, maxCoreVersion) > 0) return false;
  return true;
}

export class OpenClawBotManager {
  constructor(options = {}) {
    this.coreVersion = options.coreVersion || '1.0.0';
    this.plugins = new Map();
    this.bots = new Map();
    this.auditEvents = [];
    this.policyHooks = [];
    this.failedRollouts = 0;
    this.permissions = options.permissions || DEFAULT_PERMISSIONS;
  }

  registerPolicyHook(hook) {
    if (typeof hook !== 'function') {
      throw new Error('Policy hook must be a function');
    }
    this.policyHooks.push(hook);
  }

  // API: plugin CRUD
  createPlugin(manifest, context = {}) {
    this.assertPermission(context, 'plugin:create');
    const parsed = this.validatePluginManifest(manifest);
    if (!this.checkPluginCompatibility(parsed).compatible) {
      this.emitAudit(context, 'plugin.create', 'plugin', parsed.id, 'denied', {
        reason: 'incompatible',
        coreVersion: this.coreVersion
      });
      throw new Error(`Plugin ${parsed.id} is incompatible with core ${this.coreVersion}`);
    }
    if (this.plugins.has(parsed.id)) {
      throw new Error(`Plugin ${parsed.id} already exists`);
    }

    const record = { ...parsed, enabled: true, createdAt: nowIso(), updatedAt: nowIso() };
    this.plugins.set(record.id, record);
    this.emitAudit(context, 'plugin.create', 'plugin', record.id, 'success', { version: record.version });
    return record;
  }

  listPlugins(context = {}) {
    this.assertPermission(context, 'plugin:read');
    return Array.from(this.plugins.values());
  }

  getPlugin(pluginId, context = {}) {
    this.assertPermission(context, 'plugin:read');
    const plugin = this.plugins.get(pluginId);
    if (!plugin) throw new Error(`Plugin ${pluginId} not found`);
    return plugin;
  }

  updatePlugin(pluginId, patch, context = {}) {
    this.assertPermission(context, 'plugin:update');
    const current = this.getPlugin(pluginId, { ...context, role: context.role || 'admin' });
    const next = this.validatePluginManifest({ ...current, ...patch, id: pluginId });
    const compat = this.checkPluginCompatibility(next);
    if (!compat.compatible) {
      throw new Error(`Updated plugin ${pluginId} incompatible with core ${this.coreVersion}`);
    }
    const updated = { ...current, ...next, updatedAt: nowIso() };
    this.plugins.set(pluginId, updated);
    this.emitAudit(context, 'plugin.update', 'plugin', pluginId, 'success', { patch: Object.keys(patch || {}) });
    return updated;
  }

  deletePlugin(pluginId, context = {}) {
    this.assertPermission(context, 'plugin:delete');
    if (!this.plugins.has(pluginId)) throw new Error(`Plugin ${pluginId} not found`);
    for (const bot of this.bots.values()) {
      if (bot.pluginId === pluginId) {
        throw new Error(`Plugin ${pluginId} is in use by bot ${bot.id}`);
      }
    }
    this.plugins.delete(pluginId);
    this.emitAudit(context, 'plugin.delete', 'plugin', pluginId, 'success');
    return { deleted: true };
  }

  validatePluginManifest(manifest) {
    const normalized = { ...(manifest || {}) };
    const required = ['id', 'name', 'version'];
    for (const field of required) {
      if (!normalized[field] || String(normalized[field]).trim().length === 0) {
        throw new Error(`Plugin manifest missing required field: ${field}`);
      }
    }
    if (!/^[a-z0-9-]+$/.test(normalized.id)) {
      throw new Error('Plugin id must be kebab-case');
    }
    return {
      id: String(normalized.id),
      name: String(normalized.name),
      version: String(normalized.version),
      minCoreVersion: normalized.minCoreVersion ? String(normalized.minCoreVersion) : undefined,
      maxCoreVersion: normalized.maxCoreVersion ? String(normalized.maxCoreVersion) : undefined,
      capabilities: Array.isArray(normalized.capabilities) ? normalized.capabilities : []
    };
  }

  checkPluginCompatibility(manifest) {
    const compatible = isVersionInRange(
      this.coreVersion,
      manifest.minCoreVersion,
      manifest.maxCoreVersion
    );
    return {
      compatible,
      coreVersion: this.coreVersion,
      minCoreVersion: manifest.minCoreVersion || null,
      maxCoreVersion: manifest.maxCoreVersion || null
    };
  }

  // API: bot lifecycle
  createBot(payload, context = {}) {
    this.assertPermission(context, 'bot:create');
    const id = String(payload?.id || '').trim();
    if (!id) throw new Error('Bot id is required');
    if (this.bots.has(id)) throw new Error(`Bot ${id} already exists`);
    const plugin = this.getPlugin(String(payload?.pluginId || ''), { ...context, role: context.role || 'operator' });
    const bot = {
      id,
      name: String(payload?.name || id),
      pluginId: plugin.id,
      pluginVersion: plugin.version,
      status: 'created',
      config: payload?.config || {},
      rollbackStack: [],
      updatedAt: nowIso(),
      createdAt: nowIso()
    };
    this.bots.set(id, bot);
    this.emitAudit(context, 'bot.create', 'bot', id, 'success', { pluginId: plugin.id });
    return bot;
  }

  getBot(botId, context = {}) {
    this.assertPermission(context, 'bot:read');
    const bot = this.bots.get(botId);
    if (!bot) throw new Error(`Bot ${botId} not found`);
    return bot;
  }

  commandBot(botId, command, context = {}) {
    this.assertPermission(context, 'bot:manage');
    const bot = this.getBot(botId, { ...context, role: context.role || 'operator' });
    const next = this.transitionState(bot.status, command);
    if (next === bot.status) {
      this.emitAudit(context, 'bot.command', 'bot', botId, 'noop', { command, status: bot.status });
      return { changed: false, status: bot.status };
    }
    bot.status = next;
    bot.updatedAt = nowIso();
    this.emitAudit(context, 'bot.command', 'bot', botId, 'success', { command, status: next });
    return { changed: true, status: next };
  }

  deployBotPlugin(botId, pluginId, context = {}) {
    this.assertPermission(context, 'bot:deploy');
    const bot = this.getBot(botId, { ...context, role: context.role || 'operator' });
    const plugin = this.getPlugin(pluginId, { ...context, role: context.role || 'operator' });

    const policyResult = this.evaluatePolicies({
      action: 'bot.deploy',
      bot,
      plugin,
      actor: context
    });
    if (!policyResult.allowed) {
      this.failedRollouts++;
      this.emitAudit(context, 'bot.deploy', 'bot', botId, 'denied', { reason: policyResult.reason });
      throw new Error(`Policy blocked deployment: ${policyResult.reason}`);
    }

    bot.rollbackStack.push({
      pluginId: bot.pluginId,
      pluginVersion: bot.pluginVersion,
      status: bot.status,
      timestamp: nowIso()
    });

    bot.pluginId = plugin.id;
    bot.pluginVersion = plugin.version;
    bot.updatedAt = nowIso();
    this.emitAudit(context, 'bot.deploy', 'bot', botId, 'success', { pluginId: plugin.id, pluginVersion: plugin.version });
    return { deployed: true, pluginId: plugin.id, pluginVersion: plugin.version };
  }

  rollbackBot(botId, context = {}) {
    this.assertPermission(context, 'bot:rollback');
    const bot = this.getBot(botId, { ...context, role: context.role || 'operator' });
    const previous = bot.rollbackStack.pop();
    if (!previous) {
      this.emitAudit(context, 'bot.rollback', 'bot', botId, 'noop', { reason: 'empty rollback stack' });
      return { rolledBack: false };
    }
    bot.pluginId = previous.pluginId;
    bot.pluginVersion = previous.pluginVersion;
    bot.status = previous.status;
    bot.updatedAt = nowIso();
    this.emitAudit(context, 'bot.rollback', 'bot', botId, 'success', { toPlugin: previous.pluginId });
    return { rolledBack: true, pluginId: bot.pluginId, pluginVersion: bot.pluginVersion };
  }

  // API: governance + operations
  getAuditEvents(context = {}) {
    this.assertPermission(context, 'report:read');
    return [...this.auditEvents];
  }

  getHealthReport(context = {}) {
    this.assertPermission(context, 'report:read');
    const bots = Array.from(this.bots.values());
    const counts = {};
    for (const state of BOT_STATES) counts[state] = 0;
    for (const bot of bots) {
      if (!counts[bot.status]) counts[bot.status] = 0;
      counts[bot.status] += 1;
    }

    const drift = [];
    for (const bot of bots) {
      const plugin = this.plugins.get(bot.pluginId);
      if (plugin && plugin.version !== bot.pluginVersion) {
        drift.push({
          botId: bot.id,
          pluginId: bot.pluginId,
          deployedVersion: bot.pluginVersion,
          latestVersion: plugin.version
        });
      }
    }

    return {
      generatedAt: nowIso(),
      coreVersion: this.coreVersion,
      botCount: bots.length,
      botStatus: counts,
      failedRollouts: this.failedRollouts,
      pluginDrift: drift
    };
  }

  transitionState(current, command) {
    const state = String(current || '').toLowerCase();
    const cmd = String(command || '').toLowerCase();
    const map = {
      created: { start: 'running', stop: 'stopped' },
      running: { stop: 'stopped', restart: 'running', suspend: 'suspended' },
      stopped: { start: 'running', restart: 'running' },
      suspended: { resume: 'running', stop: 'stopped' },
      failed: { restart: 'running', stop: 'stopped' }
    };
    const next = map[state]?.[cmd];
    if (!next) return state;
    return next;
  }

  evaluatePolicies(payload) {
    for (const hook of this.policyHooks) {
      const result = hook(payload);
      if (result && result.allowed === false) {
        return { allowed: false, reason: result.reason || 'policy denied' };
      }
    }
    return { allowed: true };
  }

  assertPermission(context, permission) {
    const role = context?.role || 'viewer';
    const roleSet = this.permissions[role];
    if (!roleSet || !roleSet.has(permission)) {
      this.emitAudit(context, 'rbac.denied', 'permission', permission, 'denied', { role });
      throw new Error(`Role ${role} missing permission ${permission}`);
    }
  }

  emitAudit(context, action, resourceType, resourceId, outcome, details = {}) {
    this.auditEvents.push({
      at: nowIso(),
      actor: context?.actor || 'system',
      role: context?.role || 'unknown',
      action,
      resourceType,
      resourceId,
      outcome,
      details
    });
  }
}

export default {
  OpenClawBotManager
};
