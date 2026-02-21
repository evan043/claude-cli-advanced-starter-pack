/**
 * Orchestrator Execution Phase
 * Handles hierarchical execution through Epic → Roadmap → Phase-Dev-Plan → Tasks
 */

import { VisionStatus, updateVisionStatus } from '../schema.js';
import { loadVision, saveVision, createVisionCheckpoint, updateVision } from '../state-manager.js';
import { runAutonomousLoop } from '../autonomous/index.js';
import { log, transitionStage, OrchestratorStage } from './lifecycle.js';
import fs from 'fs';
import path from 'path';

/**
 * Run the execution phase with proper agent delegation
 */
export async function execute(orchestrator, options = {}) {
  transitionStage(orchestrator, OrchestratorStage.EXECUTION);

  if (!orchestrator.vision) {
    throw new Error('Vision not initialized. Call initialize() first.');
  }

  if (!orchestrator.config.autonomous.enabled) {
    log(orchestrator, 'info', 'Autonomous execution disabled');
    return {
      success: true,
      stage: orchestrator.stage,
      skipped: true,
      message: 'Manual execution required'
    };
  }

  try {
    log(orchestrator, 'info', 'Starting hierarchical execution...');

    // Update vision status
    updateVisionStatus(orchestrator.vision, VisionStatus.EXECUTING);
    await saveVision(orchestrator.projectRoot, orchestrator.vision);

    // Create checkpoint before execution
    await createVisionCheckpoint(orchestrator.projectRoot, orchestrator.vision.slug, 'pre_execution');

    const executionResult = {
      success: true,
      roadmapsCompleted: 0,
      plansCompleted: 0,
      tasksCompleted: 0,
      iterations: 0
    };

    // Load planning data
    if (!orchestrator.vision.planning?.epic_path) {
      const planSlug = orchestrator.vision.planning?.plan_slug;
      const phasePlanPath = planSlug
        ? path.join(orchestrator.projectRoot, '.claude', 'phase-plans', planSlug, 'PROGRESS.json')
        : null;

      if (phasePlanPath && fs.existsSync(phasePlanPath)) {
        log(orchestrator, 'info', `No epic hierarchy found; executing phase-dev-plan: ${planSlug}`);
        const currentPlan = JSON.parse(fs.readFileSync(phasePlanPath, 'utf8'));
        const result = await runAutonomousLoop(
          { ...orchestrator.vision, currentPlan, currentPlanPath: phasePlanPath },
          orchestrator.projectRoot
        );
        return {
          success: result.success,
          stage: orchestrator.stage,
          result
        };
      }

      log(orchestrator, 'warn', 'No planning data found, falling back to autonomous loop');
      const result = await runAutonomousLoop(orchestrator.vision, orchestrator.projectRoot);
      return {
        success: result.success,
        stage: orchestrator.stage,
        result
      };
    }

    // Load Epic
    const epicPath = path.join(orchestrator.projectRoot, orchestrator.vision.planning.epic_path);
    if (!fs.existsSync(epicPath)) {
      throw new Error(`Epic not found at: ${  orchestrator.vision.planning.epic_path}`);
    }

    const epic = JSON.parse(fs.readFileSync(epicPath, 'utf8'));
    log(orchestrator, 'info', `Executing Epic: ${epic.title} with ${epic.roadmaps?.length || 0} roadmap(s)`);

    // Execute each Roadmap sequentially (respecting dependencies)
    for (let rmIndex = 0; rmIndex < (epic.roadmaps?.length || 0); rmIndex++) {
      const roadmapRef = epic.roadmaps[rmIndex];
      if (!roadmapRef.path) continue;

      const roadmapPath = path.join(orchestrator.projectRoot, roadmapRef.path);
      if (!fs.existsSync(roadmapPath)) {
        log(orchestrator, 'warn', `Roadmap not found: ${roadmapRef.path}`);
        continue;
      }

      const roadmap = JSON.parse(fs.readFileSync(roadmapPath, 'utf8'));
      log(orchestrator, 'info', `Executing Roadmap ${rmIndex + 1}/${epic.roadmaps.length}: ${roadmap.title}`);

      // Update roadmap status
      roadmap.status = 'in_progress';
      roadmap.metadata = roadmap.metadata || {};
      roadmap.metadata.updated = new Date().toISOString();
      fs.writeFileSync(roadmapPath, JSON.stringify(roadmap, null, 2), 'utf8');

      // Execute each Phase-Dev-Plan
      for (const planRef of (roadmap.phase_dev_plan_refs || [])) {
        const planPath = path.join(orchestrator.projectRoot, planRef.progress_file);
        if (!fs.existsSync(planPath)) {
          log(orchestrator, 'warn', `Plan not found: ${planRef.progress_file}`);
          continue;
        }

        const progress = JSON.parse(fs.readFileSync(planPath, 'utf8'));
        log(orchestrator, 'info', `Executing Plan: ${progress.project?.name || planRef.slug}`);

        // Update plan status
        progress.status = 'in_progress';
        progress.metadata = progress.metadata || {};
        progress.metadata.updated = new Date().toISOString();
        fs.writeFileSync(planPath, JSON.stringify(progress, null, 2), 'utf8');

        // Delegate to appropriate agent based on domain
        const agent = selectAgentForPlan(orchestrator, progress);
        if (agent) {
          log(orchestrator, 'info', `Delegating to ${agent.domain} agent`);
        }

        // Execute tasks within the plan (via autonomous loop or agent)
        const planResult = await runAutonomousLoop(
          { ...orchestrator.vision, currentPlan: progress },
          orchestrator.projectRoot
        );

        executionResult.iterations += planResult.iterations || 0;

        // Import and call syncProgressHierarchy
        const { syncProgressHierarchy } = await import('../state-manager.js');

        // Sync progress up the hierarchy after plan execution
        const syncResult = await syncProgressHierarchy(orchestrator.projectRoot, planRef.slug);
        if (syncResult.success) {
          log(orchestrator, 'info', `Progress synced: Plan ${syncResult.updates.plan?.completion}% → Roadmap ${syncResult.updates.roadmap?.completion}%`);
        }

        if (planResult.success) {
          executionResult.plansCompleted++;
        }
      }

      // Check if roadmap is complete
      const updatedRoadmap = JSON.parse(fs.readFileSync(roadmapPath, 'utf8'));
      if (updatedRoadmap.completion_percentage === 100) {
        executionResult.roadmapsCompleted++;
        log(orchestrator, 'info', `Roadmap completed: ${roadmap.title}`);
      }
    }

    // Reload vision after execution
    orchestrator.vision = await loadVision(orchestrator.projectRoot, orchestrator.vision.slug);

    // Update orchestrator stage in vision
    await updateVision(orchestrator.projectRoot, orchestrator.vision.slug, (vision) => {
      vision.orchestrator.stage = orchestrator.stage;
      vision.orchestrator.execution_result = executionResult;
      return vision;
    });

    log(orchestrator, 'info', 'Hierarchical execution completed', {
      roadmapsCompleted: executionResult.roadmapsCompleted,
      plansCompleted: executionResult.plansCompleted,
      iterations: executionResult.iterations
    });

    return {
      success: executionResult.success,
      stage: orchestrator.stage,
      result: executionResult
    };

  } catch (error) {
    log(orchestrator, 'error', `Execution failed: ${error.message}`);

    // Update vision status
    updateVisionStatus(orchestrator.vision, VisionStatus.FAILED);
    await saveVision(orchestrator.projectRoot, orchestrator.vision);

    return {
      success: false,
      error: error.message,
      stage: orchestrator.stage
    };
  }
}

/**
 * Select the appropriate agent for a phase-dev-plan based on its content
 */
export function selectAgentForPlan(orchestrator, progress) {
  const planName = (progress.project?.name || progress.slug || '').toLowerCase();

  // Check agent registry for matching domain
  for (const [domain, agent] of orchestrator.agents) {
    if (domain === 'frontend' && (planName.includes('frontend') || planName.includes('ui') || planName.includes('component'))) {
      return agent;
    }
    if (domain === 'backend' && (planName.includes('backend') || planName.includes('api') || planName.includes('service'))) {
      return agent;
    }
    if (domain === 'testing' && (planName.includes('test') || planName.includes('e2e'))) {
      return agent;
    }
  }

  // Default to orchestrator agent
  return orchestrator.agents.get('orchestrator') || null;
}
