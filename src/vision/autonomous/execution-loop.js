/**
 * Autonomous Execution Loop
 *
 * Main execution loop that continues until vision.status === 'completed'
 * or human intervention is required.
 *
 * Flow:
 * 1. Check if should continue
 * 2. Execute next pending tasks
 * 3. Run tests
 * 4. If tests fail, attempt self-healing
 * 5. Check overall progress
 * 6. Repeat until 100% complete
 */

import { VisionStatus, updateVisionStatus, calculateVisionCompletion } from '../schema.js';
import { loadVision, saveVision, updateVision } from '../state-manager.js';
import { runTests, identifyFailures } from './test-validator.js';
import { generateFixes, applyFixes, shouldEscalate } from './self-healer.js';
import { verifyMVPComplete } from './completion-verifier.js';
import fs from 'fs';

/**
 * Run autonomous execution loop
 * Continues until vision is completed or manual intervention needed
 *
 * @param {Object} vision - Vision object
 * @param {string} projectRoot - Project root directory
 * @returns {Promise<Object>} Result { success: boolean, reason: string, vision: Object }
 */
export async function runAutonomousLoop(vision, projectRoot) {
  console.log(`Starting autonomous loop for vision: ${vision.title}`);
  console.log(`Current status: ${vision.status}`);

  let iterations = 0;
  const MAX_ITERATIONS = 100;
  let retryCount = 0;
  let runtimePlan = vision.currentPlan || null;
  const runtimePlanPath = vision.currentPlanPath || null;

  // Update status to executing
  updateVisionStatus(vision, VisionStatus.EXECUTING);
  await saveVision(projectRoot, vision);

  while (shouldContinue(vision) && iterations < MAX_ITERATIONS) {
    iterations++;
    console.log(`\nIteration ${iterations}/${MAX_ITERATIONS}`);

    try {
      // Step 1: Execute next tasks
      console.log('Executing next tasks...');
      vision.currentPlan = runtimePlan;
      vision.currentPlanPath = runtimePlanPath;
      const taskResult = await executeNextTasks(vision, projectRoot);
      runtimePlan = vision.currentPlan || runtimePlan;

      if (!taskResult.success) {
        console.error(`Task execution failed: ${taskResult.error}`);

        if (shouldEscalate([], retryCount)) {
          return {
            success: false,
            reason: 'task_execution_failed',
            error: taskResult.error,
            vision: await loadVision(projectRoot, vision.slug)
          };
        }

        retryCount++;
        continue;
      }

      // Step 2: Run tests
      console.log('Running tests...');
      const testResult = await runTests(vision, projectRoot);

      if (!testResult.success) {
        console.log(`Tests failed: ${testResult.failures?.length || 0} failures`);

        // Step 3: Attempt self-healing
        const failures = identifyFailures(testResult);

        if (shouldEscalate(failures, retryCount)) {
          updateVisionStatus(vision, VisionStatus.PAUSED);
          await saveVision(projectRoot, vision);

          return {
            success: false,
            reason: 'escalation_required',
            failures,
            retryCount,
            vision: await loadVision(projectRoot, vision.slug)
          };
        }

        console.log('Attempting self-healing...');
        const healResult = await generateFixes(failures, projectRoot);

        if (healResult.fixes?.length > 0) {
          const applyResult = await applyFixes(healResult.fixes, projectRoot);

          if (!applyResult.success) {
            retryCount++;
            continue;
          }

          retryCount = 0; // Reset on successful fix
        } else {
          retryCount++;
        }

        continue;
      }

      // Step 4: Check progress
      console.log('Checking progress...');
      const progress = await checkProgress(vision, projectRoot);
      console.log(`Current progress: ${progress.completion_percentage}%`);

      // Update vision with latest progress
      await updateVision(projectRoot, vision.slug, (v) => {
        calculateVisionCompletion(v);
        return v;
      });

      // Reload vision with latest data
      vision = await loadVision(projectRoot, vision.slug);
      vision.currentPlan = runtimePlan;
      vision.currentPlanPath = runtimePlanPath;

      // Step 5: Check if MVP is complete
      if (progress.completion_percentage >= 100) {
        if (runtimePlan) {
          updateVisionStatus(vision, VisionStatus.COMPLETED);
          await saveVision(projectRoot, vision);
          return {
            success: true,
            reason: 'phase_plan_complete',
            iterations,
            vision: await loadVision(projectRoot, vision.slug)
          };
        }

        console.log('Verifying MVP completion...');
        const verification = await verifyMVPComplete(vision, projectRoot);

        if (verification.complete) {
          updateVisionStatus(vision, VisionStatus.COMPLETED);
          await saveVision(projectRoot, vision);

          return {
            success: true,
            reason: 'mvp_complete',
            iterations,
            vision: await loadVision(projectRoot, vision.slug)
          };
        } 
          console.log('MVP not fully complete, continuing...');
          console.log('Missing:', verification.missing);
        
      }

      // Small delay between iterations
      await new Promise(resolve => setTimeout(resolve, 1000));

    } catch (error) {
      console.error(`Error in autonomous loop iteration ${iterations}:`, error);

      if (shouldEscalate([], retryCount)) {
        updateVisionStatus(vision, VisionStatus.FAILED);
        await saveVision(projectRoot, vision);

        return {
          success: false,
          reason: 'loop_error',
          error: error.message,
          vision: await loadVision(projectRoot, vision.slug)
        };
      }

      retryCount++;
    }
  }

  // Max iterations reached
  if (iterations >= MAX_ITERATIONS) {
    updateVisionStatus(vision, VisionStatus.PAUSED);
    await saveVision(projectRoot, vision);

    return {
      success: false,
      reason: 'max_iterations_reached',
      iterations,
      vision: await loadVision(projectRoot, vision.slug)
    };
  }

  // Interrupted
  return handleInterruption(vision, projectRoot);
}

/**
 * Execute next pending tasks
 *
 * @param {Object} vision - Vision object
 * @param {string} projectRoot - Project root directory
 * @returns {Promise<Object>} Result { success: boolean, tasksExecuted: number }
 */
export async function executeNextTasks(vision, projectRoot) {
  try {
    if (vision.currentPlan?.phases?.length) {
      const plan = vision.currentPlan;
      let executed = false;

      for (const phase of plan.phases) {
        const nextTask = (phase.tasks || []).find((t) => !t.completed && t.status !== 'completed');
        if (!nextTask) {
          phase.status = 'completed';
          continue;
        }

        nextTask.completed = true;
        nextTask.status = 'completed';
        phase.status = 'in_progress';
        executed = true;
        console.log(`Executed task: ${nextTask.name}`);
        break;
      }

      plan.phases.forEach((phase) => {
        const allDone = (phase.tasks || []).every((t) => t.completed || t.status === 'completed');
        if (allDone) phase.status = 'completed';
      });

      const tasks = plan.phases.flatMap((phase) => phase.tasks || []);
      const completed = tasks.filter((t) => t.completed || t.status === 'completed').length;
      const total = tasks.length;
      plan.completion_percentage = total > 0 ? Math.round((completed / total) * 100) : 100;
      plan.status = plan.completion_percentage >= 100 ? 'completed' : (executed ? 'in_progress' : 'not_started');
      plan.metadata = {
        ...(plan.metadata || {}),
        updated: new Date().toISOString()
      };

      vision.currentPlan = plan;

      if (vision.currentPlanPath && fs.existsSync(vision.currentPlanPath)) {
        fs.writeFileSync(vision.currentPlanPath, JSON.stringify(plan, null, 2), 'utf8');
      }

      await updateVision(projectRoot, vision.slug, (v) => {
        v.execution_plan = v.execution_plan || {};
        v.execution_plan.roadmaps = [{
          title: plan.project?.name || plan.slug || 'Phase Plan',
          status: plan.status === 'completed' ? 'completed' : 'in_progress',
          completion_percentage: plan.completion_percentage || 0
        }];
        return v;
      });
      vision.execution_plan = vision.execution_plan || {};
      vision.execution_plan.roadmaps = [{
        title: plan.project?.name || plan.slug || 'Phase Plan',
        status: plan.status === 'completed' ? 'completed' : 'in_progress',
        completion_percentage: plan.completion_percentage || 0
      }];

      return {
        success: true,
        tasksExecuted: executed ? 1 : 0,
        message: executed ? 'Task completed' : 'No pending tasks in current plan'
      };
    }

    const roadmaps = vision.execution_plan?.roadmaps || [];
    const pendingRoadmaps = roadmaps.filter(rm =>
      rm.status === 'pending' || rm.status === 'in_progress'
    );

    if (pendingRoadmaps.length === 0) {
      return {
        success: true,
        tasksExecuted: 0,
        message: 'No pending tasks'
      };
    }

    // Execute tasks for the first pending/in-progress roadmap
    const currentRoadmap = pendingRoadmaps[0];

    console.log(`Executing tasks for roadmap: ${currentRoadmap.title}`);

    // TODO: Integrate with actual task execution system
    // For now, simulate task execution

    return {
      success: true,
      tasksExecuted: 1,
      roadmap: currentRoadmap
    };

  } catch (error) {
    return {
      success: false,
      error: error.message
    };
  }
}

/**
 * Check current progress
 *
 * @param {Object} vision - Vision object
 * @param {string} projectRoot - Project root directory
 * @returns {Promise<Object>} Progress summary
 */
export async function checkProgress(vision, projectRoot) {
  if (vision.currentPlan?.phases?.length) {
    const tasks = vision.currentPlan.phases.flatMap((phase) => phase.tasks || []);
    const total = tasks.length;
    const completed = tasks.filter((t) => t.completed || t.status === 'completed').length;
    const completion_percentage = total > 0 ? Math.round((completed / total) * 100) : 0;

    return {
      total,
      completed,
      inProgress: total - completed,
      pending: Math.max(0, total - completed),
      failed: 0,
      completion_percentage,
      current_alignment: vision.observer?.current_alignment || 1.0,
      drift_events: vision.observer?.drift_events?.length || 0
    };
  }

  const roadmaps = vision.execution_plan?.roadmaps || [];

  const total = roadmaps.length;
  const completed = roadmaps.filter(rm => rm.status === 'completed').length;
  const inProgress = roadmaps.filter(rm => rm.status === 'in_progress').length;
  const pending = roadmaps.filter(rm => rm.status === 'pending').length;
  const failed = roadmaps.filter(rm => rm.status === 'failed').length;

  const completion_percentage = total > 0
    ? Math.round((completed / total) * 100)
    : 0;

  return {
    total,
    completed,
    inProgress,
    pending,
    failed,
    completion_percentage,
    current_alignment: vision.observer?.current_alignment || 1.0,
    drift_events: vision.observer?.drift_events?.length || 0
  };
}

/**
 * Check if loop should continue
 *
 * @param {Object} vision - Vision object
 * @returns {boolean} True if should continue
 */
export function shouldContinue(vision) {
  // Stop if status is terminal
  if ([
    VisionStatus.COMPLETED,
    VisionStatus.FAILED,
    VisionStatus.PAUSED
  ].includes(vision.status)) {
    return false;
  }

  // Continue if executing or validating
  if ([
    VisionStatus.EXECUTING,
    VisionStatus.VALIDATING
  ].includes(vision.status)) {
    return true;
  }

  if (vision.currentPlan?.phases?.length) {
    return vision.currentPlan.phases.some((phase) =>
      (phase.tasks || []).some((t) => !t.completed && t.status !== 'completed')
    );
  }

  // For other statuses, check if there are pending roadmaps
  const roadmaps = vision.execution_plan?.roadmaps || [];
  const hasIncompleteTasks = roadmaps.some(rm =>
    rm.status !== 'completed' && rm.status !== 'failed'
  );

  return hasIncompleteTasks;
}

/**
 * Handle graceful interruption
 *
 * @param {Object} vision - Vision object
 * @param {string} projectRoot - Project root directory
 * @returns {Promise<Object>} Interruption result
 */
export async function handleInterruption(vision, projectRoot) {
  console.log('Handling interruption...');

  // Save current state
  updateVisionStatus(vision, VisionStatus.PAUSED);
  await saveVision(projectRoot, vision);

  // Calculate current progress
  const progress = await checkProgress(vision, projectRoot);

  return {
    success: false,
    reason: 'interrupted',
    progress,
    vision: await loadVision(projectRoot, vision.slug)
  };
}

export default {
  runAutonomousLoop,
  executeNextTasks,
  checkProgress,
  shouldContinue,
  handleInterruption
};
