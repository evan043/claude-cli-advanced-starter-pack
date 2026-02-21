/**
 * Vision Mode Run Command
 *
 * Provides:
 * - visionRun: Execute vision in autonomous mode
 * - visionResume: Resume paused vision (delegates to visionRun)
 *
 * @module commands/vision-cmd/run
 */

import { createOrchestrator, loadVision } from '../../vision/index.js';

/**
 * Run vision execution
 * @param {string} projectRoot - Project root directory
 * @param {Object} options - CLI options
 */
export async function visionRun(projectRoot, options) {
  const slug = options.slug || options.args?.[0];

  if (!slug) {
    console.log('\n❌ Please provide a vision slug.');
    console.log('   Usage: ccasp vision run <slug>');
    console.log('   Run `ccasp vision list` to see available visions.');
    return;
  }

  const vision = await loadVision(projectRoot, slug);

  if (!vision) {
    console.log(`\n❌ Vision not found: ${slug}`);
    return;
  }

  console.log('\n┌─────────────────────────────────────────────────┐');
  console.log('│         VISION MODE - EXECUTING                 │');
  console.log('└─────────────────────────────────────────────────┘\n');

  console.log(`Vision: ${vision.title}`);
  console.log(`Slug: ${slug}\n`);

  const orchestrator = createOrchestrator(projectRoot, {
    autonomous: {
      enabled: !options.manual,
      maxIterations: options.maxIterations ? parseInt(options.maxIterations) : 100
    }
  });

  // Resume from saved state
  const resumeResult = await orchestrator.resume(slug);

  if (!resumeResult.success) {
    console.log(`\n❌ Failed to resume vision: ${resumeResult.error}`);
    return;
  }

  console.log(`Resuming from stage: ${resumeResult.stage}`);
  console.log(`Current status: ${resumeResult.vision.status}`);
  console.log('');

  // Execute
  console.log('Starting autonomous execution...\n');
  const execResult = await orchestrator.execute();

  if (execResult.success) {
    console.log('\n✓ Execution completed successfully');

    // Run validation
    console.log('\nRunning validation...');
    const validateResult = await orchestrator.validate();

    if (validateResult.success && validateResult.result.mvp.complete) {
      console.log('\n✓ MVP verification passed');

      // Complete the vision
      const completeResult = await orchestrator.complete();

      if (completeResult.success) {
        console.log('\n┌─────────────────────────────────────────────────┐');
        console.log('│         VISION COMPLETED SUCCESSFULLY           │');
        console.log('└─────────────────────────────────────────────────┘');
      }
    } else {
      console.log('\n⚠️  MVP not fully complete');
      if (validateResult.result?.mvp?.missing?.length > 0) {
        console.log('Missing items:');
        for (const item of validateResult.result.mvp.missing) {
          if (typeof item === 'string') {
            console.log(`  - ${item}`);
          } else {
            console.log(`  - ${item.check || 'item'}: ${item.details || item.status || 'incomplete'}`);
          }
        }
      }
    }
  } else {
    console.log(`\n⚠️  Execution stopped: ${execResult.result?.reason || execResult.error}`);

    if (execResult.result?.reason === 'escalation_required') {
      console.log('\nManual intervention required. Review failures and retry.');
    }
  }
}

/**
 * Resume a paused vision
 * @param {string} projectRoot - Project root directory
 * @param {Object} options - CLI options
 */
export async function visionResume(projectRoot, options) {
  const slug = options.slug || options.args?.[0];

  if (!slug) {
    console.log('\n❌ Please provide a vision slug to resume.');
    console.log('   Usage: ccasp vision resume <slug>');
    return;
  }

  // Delegate to run command
  await visionRun(projectRoot, { ...options, slug });
}
