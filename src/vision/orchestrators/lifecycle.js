/**
 * Orchestrator Lifecycle Management
 * Handles initialization, stage transitions, and workflow execution
 */

import { VisionStatus, createVision, updateVisionStatus, calculateVisionCompletion } from '../schema.js';
import { loadVision, saveVision, createAndSaveVision, updateVision, createVisionCheckpoint } from '../state-manager.js';
import { parseVisionPrompt, estimateComplexity, detectIntent, extractFeatures } from '../parser.js';
import { detectAccountRequirements, generateSetupChecklist } from '../analysis/account-detector.js';
import fs from 'fs';
import path from 'path';

/**
 * Orchestration stages
 */
export const OrchestratorStage = {
  INITIALIZATION: 'initialization',
  ANALYSIS: 'analysis',
  ARCHITECTURE: 'architecture',
  DECISION: 'decision',
  PLANNING: 'planning',
  SECURITY: 'security',
  EXECUTION: 'execution',
  VALIDATION: 'validation',
  COMPLETION: 'completion',
  PAUSED: 'paused',
  FAILED: 'failed'
};

/**
 * Log a message with timestamp
 */
export function log(orchestrator, level, message, data = null) {
  const entry = {
    timestamp: new Date().toISOString(),
    level,
    stage: orchestrator.stage,
    message,
    data
  };
  orchestrator.logs.push(entry);

  const prefix = `[${level.toUpperCase()}] [${orchestrator.stage || 'init'}]`;
  if (data) {
    console.log(`${prefix} ${message}`, data);
  } else {
    console.log(`${prefix} ${message}`);
  }
}

/**
 * Transition to a new stage
 */
export function transitionStage(orchestrator, newStage) {
  const previousStage = orchestrator.stage;
  orchestrator.stage = newStage;
  orchestrator.stageHistory.push({
    from: previousStage,
    to: newStage,
    timestamp: new Date().toISOString()
  });
  log(orchestrator, 'info', `Stage transition: ${previousStage || 'null'} → ${newStage}`);
}

/**
 * Initialize a new vision from a prompt
 */
export async function initialize(orchestrator, prompt, options = {}) {
  transitionStage(orchestrator, OrchestratorStage.INITIALIZATION);

  try {
    log(orchestrator, 'info', 'Parsing vision prompt...');

    // Parse the prompt
    const parsedPrompt = parseVisionPrompt(prompt);
    const complexity = estimateComplexity(parsedPrompt);
    const intent = detectIntent(prompt);
    const features = extractFeatures(prompt);
    const normalizedFeatures = Array.isArray(parsedPrompt?.parsed?.features)
      ? parsedPrompt.parsed.features
      : features.map(f => f?.feature || f?.name || f).filter(Boolean);

    log(orchestrator, 'info', `Detected intent: ${intent}`, {
      complexity,
      featureCount: features.length
    });

    // Generate title from prompt
    const title = options.title || generateTitleFromPrompt(prompt);

    // Create and save vision
    const visionResult = await createAndSaveVision(orchestrator.projectRoot, {
      title,
      prompt,
      tags: options.tags || [],
      priority: options.priority || 'medium'
    });

    if (!visionResult.success) {
      throw new Error(`Failed to create vision: ${visionResult.error}`);
    }

    orchestrator.vision = visionResult.vision;

    // Update vision with parsed data
    await updateVision(orchestrator.projectRoot, orchestrator.vision.slug, (vision) => {
      vision.prompt = parsedPrompt;
      vision.metadata.estimated_complexity = complexity;
      vision.metadata.detected_intent = intent?.intent || intent;
      vision.metadata.features = normalizedFeatures;
      vision.metadata.feature_details = features;
      vision.orchestrator = {
        stage: orchestrator.stage,
        config: orchestrator.config,
        stage_history: orchestrator.stageHistory
      };
      return vision;
    });

    // Detect account requirements
    log(orchestrator, 'info', 'Detecting account requirements...');
    const detectedRequirements = detectAccountRequirements(parsedPrompt);
    const accountRequirements = Array.isArray(detectedRequirements)
      ? detectedRequirements
      : (Array.isArray(detectedRequirements?.accounts) ? detectedRequirements.accounts : []);

    if (accountRequirements.length > 0) {
      log(orchestrator, 'info', `Detected ${accountRequirements.length} account requirements`, accountRequirements);

      await updateVision(orchestrator.projectRoot, orchestrator.vision.slug, (vision) => {
        vision.requirements = vision.requirements || {};
        vision.requirements.accounts = accountRequirements;
        return vision;
      });
    }

    // Generate setup checklist
    const setupChecklist = generateSetupChecklist(accountRequirements);

    // Reload vision
    orchestrator.vision = await loadVision(orchestrator.projectRoot, orchestrator.vision.slug);

    return {
      success: true,
      stage: orchestrator.stage,
      vision: orchestrator.vision,
      parsed: parsedPrompt,
      complexity,
      intent,
      features,
      accountRequirements,
      setupChecklist
    };

  } catch (error) {
    log(orchestrator, 'error', `Initialization failed: ${error.message}`);
    transitionStage(orchestrator, OrchestratorStage.FAILED);
    return {
      success: false,
      error: error.message,
      stage: orchestrator.stage
    };
  }
}

/**
 * Run the full orchestration workflow
 */
export async function run(orchestrator, prompt, options = {}) {
  const { initialize } = await import('./lifecycle.js');
  const { analyze } = await import('./analysis.js');
  const { architect } = await import('./architecture.js');
  const { plan } = await import('./planning.js');
  const { scanSecurity } = await import('./security.js');
  const { createAgents } = await import('./agents.js');
  const { execute } = await import('./execution.js');
  const { validate, complete } = await import('./validation.js');

  const results = {
    stages: {},
    success: false
  };

  try {
    // Stage 1: Initialize
    results.stages.initialization = await initialize(orchestrator, prompt, options);
    if (!results.stages.initialization.success) {
      return { ...results, error: results.stages.initialization.error };
    }

    // Stage 2: Analyze
    results.stages.analysis = await analyze(orchestrator);
    if (!results.stages.analysis.success) {
      log(orchestrator, 'warn', 'Analysis had errors, continuing...');
    }

    // Stage 3: Architect
    results.stages.architecture = await architect(orchestrator);
    if (!results.stages.architecture.success) {
      log(orchestrator, 'warn', 'Architecture had errors, continuing...');
    }

    // Stage 4: Planning (NEW - creates Epic → Roadmaps → Phase-Dev-Plans)
    results.stages.planning = await plan(orchestrator);
    if (!results.stages.planning.success) {
      log(orchestrator, 'warn', 'Planning had errors, continuing...');
    }

    // Stage 5: Security scan
    results.stages.security = await scanSecurity(orchestrator);
    if (results.stages.security.results?.hasBlockedPackages && !orchestrator.config.security.allowOverride) {
      log(orchestrator, 'error', 'Blocked packages detected, stopping execution');
      return {
        ...results,
        error: 'Security vulnerabilities detected. Review and resolve before continuing.',
        blockedPackages: results.stages.security.results.blocked
      };
    }

    // Stage 6: Create agents
    results.stages.agents = await createAgents(orchestrator);

    // Stage 7: Session restart check (before execution)
    const { checkSessionRestart } = await import('./monitoring.js');
    const sessionCheck = checkSessionRestart(orchestrator);
    if (sessionCheck.needsRestart && !options.skipSessionCheck) {
      log(orchestrator, 'warn', sessionCheck.reason);
      results.sessionRestartRequired = true;
      results.sessionRestartReason = sessionCheck.reason;

      // Create marker file for session tracking
      const markerPath = path.join(orchestrator.projectRoot, '.claude', 'vision-initialized');
      if (!fs.existsSync(markerPath)) {
        fs.writeFileSync(markerPath, JSON.stringify({
          vision_slug: orchestrator.vision.slug,
          initialized_at: new Date().toISOString(),
          planning_complete: true
        }, null, 2), 'utf8');
      }

      // If not auto-executing, return here with restart warning
      if (!options.forceExecute) {
        return {
          ...results,
          success: false,
          paused: true,
          message: 'Planning complete. Please restart Claude Code session to activate hooks, then run /vision-run to continue.'
        };
      }
    }

    // Stage 8: Execute
    if (options.autoExecute !== false) {
      results.stages.execution = await execute(orchestrator, options);
    }

    // Stage 9: Validate
    if (results.stages.execution?.success) {
      results.stages.validation = await validate(orchestrator);
    }

    // Stage 10: Complete
    if (results.stages.validation?.success && results.stages.validation.result.mvp.complete) {
      results.stages.completion = await complete(orchestrator);
      results.success = true;
    }

    // Final result
    results.vision = orchestrator.vision;
    return results;

  } catch (error) {
    log(orchestrator, 'error', `Orchestration failed: ${error.message}`);
    transitionStage(orchestrator, OrchestratorStage.FAILED);

    return {
      ...results,
      success: false,
      error: error.message
    };
  }
}

/**
 * Resume from a saved vision
 */
export async function resume(orchestrator, visionSlug) {
  try {
    log(orchestrator, 'info', `Resuming vision: ${visionSlug}`);

    orchestrator.vision = await loadVision(orchestrator.projectRoot, visionSlug);

    if (!orchestrator.vision) {
      throw new Error(`Vision not found: ${visionSlug}`);
    }

    // Restore orchestrator state
    if (orchestrator.vision.orchestrator) {
      orchestrator.stage = orchestrator.vision.orchestrator.stage;
      orchestrator.stageHistory = orchestrator.vision.orchestrator.stage_history || [];
      const { DEFAULT_CONFIG } = await import('./lifecycle.js');
      orchestrator.config = { ...DEFAULT_CONFIG, ...orchestrator.vision.orchestrator.config };
    }

    // Restore analysis and architecture if available
    orchestrator.analysisResults = orchestrator.vision.analysis || null;
    orchestrator.architectureArtifacts = orchestrator.vision.architecture || null;
    orchestrator.securityResults = orchestrator.vision.security || null;

    log(orchestrator, 'info', `Resumed at stage: ${orchestrator.stage}`, {
      status: orchestrator.vision.status,
      completion: orchestrator.vision.metadata?.completion_percentage
    });

    return {
      success: true,
      vision: orchestrator.vision,
      stage: orchestrator.stage
    };

  } catch (error) {
    log(orchestrator, 'error', `Resume failed: ${error.message}`);
    return {
      success: false,
      error: error.message
    };
  }
}

/**
 * Generate title from prompt
 */
export function generateTitleFromPrompt(prompt) {
  const firstSentence = prompt.split(/[.!?]/)[0]?.trim();

  if (firstSentence && firstSentence.length <= 60) {
    return firstSentence;
  }

  const truncated = prompt.substring(0, 50).trim();
  return truncated + (prompt.length > 50 ? '...' : '');
}

/**
 * Orchestrator configuration defaults
 */
export const DEFAULT_CONFIG = {
  // Security settings
  security: {
    enabled: true,
    blockThreshold: 'high',      // Block critical and high severity
    scanOnInstall: true,
    allowOverride: false
  },

  // Analysis settings
  analysis: {
    webSearchEnabled: true,
    maxSimilarApps: 5,
    maxToolSuggestions: 10,
    mcpMatchingEnabled: true
  },

  // Autonomous execution settings
  autonomous: {
    enabled: true,
    maxIterations: 100,
    selfHealingEnabled: true,
    escalationThreshold: 3        // Retry count before escalating
  },

  // Observer settings
  observer: {
    enabled: true,
    driftCheckInterval: 5,        // Check drift every N tasks
    autoAdjust: true,
    replanThreshold: 0.60         // Trigger replan below 60% alignment
  },

  // Agent settings
  agents: {
    maxConcurrent: 3,
    defaultContextBudget: 50000,
    autoDecommission: true
  }
};
