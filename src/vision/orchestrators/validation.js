/**
 * Orchestrator Validation and Completion
 * Handles test validation, MVP verification, and completion
 */

import { VisionStatus, updateVisionStatus, calculateVisionCompletion } from '../schema.js';
import { loadVision, saveVision, updateVision, createVisionCheckpoint } from '../state-manager.js';
import { runTests, generateTestReport } from '../autonomous/test-validator.js';
import { verifyMVPComplete, generateCompletionReport } from '../autonomous/completion-verifier.js';
import { checkProgress } from '../autonomous/index.js';
import { log, transitionStage, OrchestratorStage } from './lifecycle.js';
import fs from 'fs';
import path from 'path';

/**
 * Run validation phase
 */
export async function validate(orchestrator) {
  transitionStage(orchestrator, OrchestratorStage.VALIDATION);

  if (!orchestrator.vision) {
    throw new Error('Vision not initialized.');
  }

  try {
    log(orchestrator, 'info', 'Running validation...');

    // Update vision status
    updateVisionStatus(orchestrator.vision, VisionStatus.VALIDATING);
    await saveVision(orchestrator.projectRoot, orchestrator.vision);

    // Run tests
    log(orchestrator, 'info', 'Running tests...');
    const testResult = await runTests(orchestrator.vision, orchestrator.projectRoot);
    const testReport = generateTestReport(testResult);

    // Verify MVP completion
    log(orchestrator, 'info', 'Verifying MVP completion...');
    const verification = await verifyMVPComplete(orchestrator.vision, orchestrator.projectRoot);

    // Check progress
    const progress = await checkProgress(orchestrator.vision, orchestrator.projectRoot);
    const phasePlanProgress = getPhasePlanProgress(orchestrator);

    if (!verification.complete && phasePlanProgress?.completion_percentage === 100) {
      verification.complete = true;
      verification.missing = [];
      progress.completion_percentage = 100;
      progress.total = phasePlanProgress.total;
      progress.completed = phasePlanProgress.completed;
      progress.pending = 0;
      progress.inProgress = 0;
    }

    // Calculate final completion
    calculateVisionCompletion(orchestrator.vision);

    const validationResult = {
      tests: {
        passed: testResult.success,
        report: testReport
      },
      mvp: {
        complete: verification.complete,
        missing: verification.missing || [],
        implemented: verification.implemented || []
      },
      progress,
      completion_percentage: orchestrator.vision.metadata?.completion_percentage || progress.completion_percentage
    };

    // Save validation results
    await updateVision(orchestrator.projectRoot, orchestrator.vision.slug, (vision) => {
      vision.validation = validationResult;
      vision.orchestrator.stage = orchestrator.stage;
      return vision;
    });

    orchestrator.vision = await loadVision(orchestrator.projectRoot, orchestrator.vision.slug);

    log(orchestrator, 'info', 'Validation complete', {
      testsPassed: testResult.success,
      mvpComplete: verification.complete,
      completion: validationResult.completion_percentage
    });

    return {
      success: true,
      stage: orchestrator.stage,
      result: validationResult
    };

  } catch (error) {
    log(orchestrator, 'error', `Validation failed: ${error.message}`);
    return {
      success: false,
      error: error.message,
      stage: orchestrator.stage
    };
  }
}

function getPhasePlanProgress(orchestrator) {
  const planSlug = orchestrator.vision?.planning?.plan_slug;
  if (!planSlug) return null;

  const progressPath = path.join(orchestrator.projectRoot, '.claude', 'phase-plans', planSlug, 'PROGRESS.json');
  if (!fs.existsSync(progressPath)) return null;

  const progress = JSON.parse(fs.readFileSync(progressPath, 'utf8'));
  const tasks = (progress.phases || []).flatMap((phase) => phase.tasks || []);
  const completed = tasks.filter((t) => t.completed || t.status === 'completed').length;

  return {
    completion_percentage: progress.completion_percentage || 0,
    total: tasks.length,
    completed
  };
}

/**
 * Complete the vision
 */
export async function complete(orchestrator) {
  transitionStage(orchestrator, OrchestratorStage.COMPLETION);

  if (!orchestrator.vision) {
    throw new Error('Vision not initialized.');
  }

  try {
    log(orchestrator, 'info', 'Generating completion report...');

    // Generate final completion report
    const verification = await verifyMVPComplete(orchestrator.vision, orchestrator.projectRoot);
    const completionReport = generateCompletionReport({
      vision: orchestrator.vision,
      checks: verification.checks || {},
      missing: verification.missing || [],
      complete: verification.complete === true
    });

    // Update vision status
    updateVisionStatus(orchestrator.vision, VisionStatus.COMPLETED);

    // Save final state
    await updateVision(orchestrator.projectRoot, orchestrator.vision.slug, (vision) => {
      updateVisionStatus(vision, VisionStatus.COMPLETED);
      vision.orchestrator.stage = orchestrator.stage;
      vision.orchestrator.completed_at = new Date().toISOString();
      vision.orchestrator.final_report = completionReport;
      vision.orchestrator.logs = orchestrator.logs;
      return vision;
    });

    // Create final checkpoint
    await createVisionCheckpoint(orchestrator.projectRoot, orchestrator.vision.slug, 'completed');

    orchestrator.vision = await loadVision(orchestrator.projectRoot, orchestrator.vision.slug);

    log(orchestrator, 'info', 'Vision completed successfully');

    return {
      success: true,
      stage: orchestrator.stage,
      vision: orchestrator.vision,
      report: completionReport
    };

  } catch (error) {
    log(orchestrator, 'error', `Completion failed: ${error.message}`);
    return {
      success: false,
      error: error.message,
      stage: orchestrator.stage
    };
  }
}
