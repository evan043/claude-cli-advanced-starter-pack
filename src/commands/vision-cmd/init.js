/**
 * Vision Mode Init Command
 *
 * Handles vision initialization from natural language prompts.
 * Includes multi-instance awareness and decision engine display.
 *
 * @module commands/vision-cmd/init
 */

import { createOrchestrator, getActiveVisions, describePlanType } from '../../vision/index.js';
import readline from 'readline';

/**
 * Initialize a new vision from a prompt
 * @param {string} projectRoot - Project root directory
 * @param {Object} options - CLI options
 */
export async function visionInit(projectRoot, options) {
  const prompt = options.prompt || options.args?.join(' ');

  if (!prompt) {
    console.log('\n┌─────────────────────────────────────────────────┐');
    console.log('│         VISION MODE - INITIALIZATION            │');
    console.log('└─────────────────────────────────────────────────┘\n');

    // Show existing active visions if any
    const activeVisions = getActiveVisions(projectRoot);
    if (activeVisions.length > 0) {
      console.log(`  Active visions (${activeVisions.length}):`);
      for (const v of activeVisions) {
        const pct = v.completion_percentage || 0;
        console.log(`    - ${v.slug} [${v.status}] ${pct}% complete`);
      }
      console.log('');
    }

    // Interactive prompt entry
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });

    const userPrompt = await new Promise((resolve) => {
      rl.question('Enter your vision (describe what you want to build):\n> ', (answer) => {
        rl.close();
        resolve(answer);
      });
    });

    if (!userPrompt?.trim()) {
      console.log('\n❌ No prompt provided. Vision initialization cancelled.');
      return;
    }

    return visionInit(projectRoot, { ...options, prompt: userPrompt.trim() });
  }

  console.log('\n┌─────────────────────────────────────────────────┐');
  console.log('│         VISION MODE - INITIALIZING              │');
  console.log('└─────────────────────────────────────────────────┘\n');

  console.log(`Prompt: "${prompt.substring(0, 60)}${prompt.length > 60 ? '...' : ''}"\n`);

  // Show active visions warning
  const activeVisions = getActiveVisions(projectRoot);
  if (activeVisions.length > 0) {
    console.log(`  Note: ${activeVisions.length} active vision(s) exist. Use 'ccasp vision list' to see them.\n`);
  }

  const orchestrator = createOrchestrator(projectRoot, {
    security: {
      enabled: !options.noSecurity,
      blockThreshold: options.securityThreshold || 'high'
    },
    autonomous: {
      enabled: !options.manual
    },
    planTypeOverride: options.planType || null
  });

  // Initialize vision
  console.log('Parsing prompt and detecting requirements...');
  const initResult = await orchestrator.initialize(prompt, {
    title: options.title,
    tags: options.tags?.split(',') || [],
    priority: options.priority || 'medium'
  });

  if (!initResult.success) {
    console.log(`\n❌ Initialization failed: ${initResult.error}`);
    return;
  }

  console.log(`\n✓ Vision created: ${initResult.vision.slug}`);
  console.log(`  Title: ${initResult.vision.title}`);
  console.log(`  Intent: ${initResult.intent?.intent || initResult.intent || 'build'}`);
  console.log(`  Complexity: ${initResult.complexity?.scale || initResult.complexity}`);
  console.log(`  Features: ${initResult.features.length}`);

  const accountRequirements = Array.isArray(initResult.accountRequirements)
    ? initResult.accountRequirements
    : (initResult.accountRequirements?.accounts || []);

  if (accountRequirements.length > 0) {
    console.log('\n📋 Account Requirements Detected:');
    for (const account of accountRequirements) {
      console.log(`  - ${account.service}: ${account.accountType || 'account required'}`);
    }
  }

  // Run analysis if not skipped
  if (!options.skipAnalysis) {
    console.log('\n📊 Running analysis...');
    const analysisResult = await orchestrator.analyze();

    if (analysisResult.success) {
      const r = analysisResult.results;
      const similarAppsCount = Array.isArray(r.similarApps)
        ? r.similarApps.length
        : (r.similarApps?.results?.length || 0);
      console.log(`  Similar apps found: ${similarAppsCount}`);
      console.log(`  NPM packages suggested: ${r.npmPackages?.length || 0}`);
      console.log(`  MCP servers matched: ${r.mcpServers?.length || 0}`);
    }
  }

  // Run architecture if not skipped
  if (!options.skipArchitecture) {
    console.log('\n🏗️  Generating architecture...');
    const archResult = await orchestrator.architect();

    if (archResult.success) {
      const a = archResult.artifacts;
      console.log(`  Diagrams generated: ${Object.keys(a.diagrams).length}`);
      console.log(`  Components identified: ${a.componentList?.length || 0}`);
      console.log(`  API contracts: ${a.apiContracts ? 'Yes' : 'No'}`);
    }
  }

  // Run security scan
  if (!options.noSecurity) {
    console.log('\n🔒 Running security scan...');
    const securityResult = await orchestrator.scanSecurity();

    if (securityResult.results?.hasBlockedPackages) {
      console.log(`\n⚠️  ${securityResult.results.blocked.length} package(s) blocked due to vulnerabilities`);
      console.log('  Run `ccasp vision scan` for details.');
    } else {
      console.log('  ✓ No critical vulnerabilities found');
    }
  }

  // Run planning to generate executable hierarchy/tasks by default
  console.log('\n📋 Creating planning hierarchy...');
  const planningResult = await orchestrator.plan();

  if (planningResult.success) {
    const p = planningResult.result || {};
    const planType = p.decision?.planType || orchestrator.vision?.plan_type || 'unknown';
    console.log(`  Plan type: ${planType}`);
    console.log(`  Epic created: ${p.epic?.slug ? 'Yes' : 'No'}`);
    console.log(`  Roadmaps: ${p.roadmaps?.length || 0}`);
    console.log(`  Phase plans: ${p.phaseDevPlans?.length || 0}`);
  } else {
    console.log(`  ⚠️ Planning failed: ${planningResult.error}`);
  }

  // Create agents after planning
  console.log('\n🤖 Creating agents...');
  const agentsResult = await orchestrator.createAgents();
  if (agentsResult.success) {
    console.log(`  Agents created: ${agentsResult.agents?.length || 0}`);
  } else {
    console.log(`  ⚠️ Agent creation failed: ${agentsResult.error}`);
  }

  // Display decision engine result if planning was run
  const vision = orchestrator.vision;
  if (vision?.decision) {
    const desc = describePlanType(vision.decision.planType);
    console.log('\n┌─────────────────────────────────────────────────┐');
    console.log('│         PLAN TYPE DECISION                      │');
    console.log('└─────────────────────────────────────────────────┘');
    console.log(`  Type: ${desc.label} (${vision.decision.planType})`);
    console.log(`  Confidence: ${Math.round(vision.decision.confidence * 100)}%`);
    console.log(`  Reasoning: ${vision.decision.reasoning}`);
    if (!vision.decision.overridden) {
      console.log(`  Override: use --plan-type=<type> to change`);
    }
  }

  console.log('\n┌─────────────────────────────────────────────────┐');
  console.log('│         VISION INITIALIZED SUCCESSFULLY         │');
  console.log('└─────────────────────────────────────────────────┘');
  console.log(`\nSlug: ${initResult.vision.slug}`);
  console.log(`\nNext steps:`);
  console.log(`  ccasp vision status ${initResult.vision.slug}  # View status`);
  console.log(`  ccasp vision run ${initResult.vision.slug}     # Start execution`);
  console.log(`  ccasp vision list                              # List all visions`);
  console.log(`  /vision-status                                 # Claude Code slash command`);
}
