/**
 * Init Command - Refactored Orchestrator
 *
 * Deploy Claude CLI Advanced Starter Pack to a project's .claude/ folder
 * Creates complete folder structure with commands, skills, agents, hooks
 * Generates a sophisticated /menu command for project navigation
 *
 * This file is a thin orchestrator that delegates to submodules.
 */

import chalk from 'chalk';
import { join } from 'path';
import { showHeader, showWarning } from '../cli/menu.js';
import { existsSync, readdirSync } from 'fs';

// Import from extracted modules
import {
  OPTIONAL_FEATURES,
  AVAILABLE_COMMANDS,
  getDefaultFeatures,
} from './init/features.js';
import { COMMAND_TEMPLATES } from './init/command-templates.js';
import {
  generateMenuCommand,
  generateStarterAgent,
  generateStarterSkill,
  generateStarterHook,
  generateUpdateCheckHook,
  generateSettingsJson,
  generateSettingsLocalJson,
  generateIndexFile,
  generateReadmeFile,
} from './init/generators.js';
import { runDevMode } from './init/dev-mode.js';
import { verifyLegacyInstallation } from './init/legacy-verify.js';
import { deployCommands, deployHooks, deploySkills, deployBinaries } from './init/deploy-assets.js';
import { createBackup } from './setup-wizard.js';

// Import new submodules
import { setupCIMode, getProjectMetadata, getDirectoryPaths } from './init/environment.js';
import { handleExistingInstallation } from './init/existing-detection.js';
import { createFolderStructure } from './init/folder-structure.js';
import { manageSettings } from './init/settings-manager.js';
import { createStarterFiles } from './init/starter-files.js';
import { selectFeatures } from './init/feature-selection.js';
import { selectCommands } from './init/command-selection.js';
import { handleSmartMerge, createMergeHelpers } from './init/smart-merge.js';
import { setupCodexSupport } from './init/codex-setup.js';
import {
  generateDocumentation,
  generateTechStack,
  updateCcaspState,
  registerInGlobalRegistry,
  generateStackAgents,
} from './init/post-deployment.js';
import {
  displayInstallationSummary,
  displayFailures,
  displayNextSteps,
} from './init/summary-display.js';

// Re-export for backwards compatibility
export { verifyLegacyInstallation };

/**
 * Run dev mode - rapid template testing workflow
 * (Delegated to init/dev-mode.js)
 */
async function runDevModeWrapper(options = {}) {
  return runDevMode(options);
}

/**
 * Run the init wizard
 */
export async function runInit(options = {}) {
  // CI MODE: Auto-detect and skip prompts in CI environments
  setupCIMode(options, getDefaultFeatures);

  // DEV MODE: Fast path for template testing
  if (options.dev) {
    showHeader('Claude CLI Advanced Starter Pack - DEV MODE');
    return runDevModeWrapper(options);
  }

  showHeader('Claude CLI Advanced Starter Pack - Project Setup');

  const cwd = process.cwd();
  const { projectName } = getProjectMetadata(cwd);
  const claudeDir = join(cwd, '.claude');
  const paths = getDirectoryPaths(claudeDir);

  console.log(chalk.cyan(`  Project: ${chalk.bold(projectName)}`));
  console.log(chalk.cyan(`  Location: ${cwd}`));
  console.log('');

  // Check for existing .claude folder
  const existingResult = await handleExistingInstallation(claudeDir, paths, options);
  if (!existingResult.shouldProceed) {
    return;
  }
  const hasExistingClaudeDir = existingResult.exists;

  // Step 1: Create folder structure
  createFolderStructure(paths);

  // Step 2: Configure settings
  manageSettings(paths, projectName, generateSettingsJson, generateSettingsLocalJson);

  // Step 3: Create starter files
  const generators = {
    generateStarterAgent,
    generateStarterSkill,
    generateStarterHook,
    generateUpdateCheckHook,
  };
  createStarterFiles(paths, generators);

  // Step 4: Select features
  const featureResult = await selectFeatures(OPTIONAL_FEATURES, options, getDefaultFeatures);
  const {
    selectedFeatures,
    enabledFeatures,
    featuresRequiringConfig,
    featureCommands,
    featureHooks,
    featureSkills,
    featureBinaries,
  } = featureResult;

  // Step 5: Select commands
  const commandResult = await selectCommands(AVAILABLE_COMMANDS, paths.commandsDir, options, featureCommands);
  if (!commandResult) {
    showWarning('No commands selected. Nothing to install.');
    return;
  }

  let { finalCommands, existingCmdNames, requiredCommands } = commandResult;

  // Step 6: Handle smart merge for existing commands
  try {
    const mergeResult = await handleSmartMerge(finalCommands, existingCmdNames, requiredCommands, options, cwd);
    finalCommands = mergeResult.finalCommands;
    const { smartMergeDecisions, overwrite } = mergeResult;

    // Create helper functions for backup/skip checks
    const commandsToOverwrite = finalCommands.filter(cmd => existingCmdNames.includes(cmd));
    const createBackups = options.backup || (typeof overwrite !== 'undefined' && commandsToOverwrite.length > 0 && !options.force);
    const { shouldBackupCommand, shouldSkipCommand } = createMergeHelpers(smartMergeDecisions, createBackups);

    // Get installed assets for menu generation
    const installedAgents = existsSync(paths.agentsDir)
      ? readdirSync(paths.agentsDir).filter(f => f.endsWith('.md')).map(f => f.replace('.md', ''))
      : [];
    const installedSkills = existsSync(paths.skillsDir)
      ? readdirSync(paths.skillsDir).filter(f => !f.startsWith('.'))
      : [];
    const installedHooks = existsSync(paths.hooksDir)
      ? readdirSync(paths.hooksDir).filter(f => f.endsWith('.js')).map(f => f.replace('.js', ''))
      : [];

    // Critical commands that should ALWAYS be updated (never skipped)
    const alwaysUpdateCommands = ['update-check', '__ccasp-sync-marker'];

    // Step 6a: Deploy commands
    const deployCommandsResult = await deployCommands({
      commandsDir: paths.commandsDir,
      finalCommands,
      projectName,
      installedAgents,
      installedSkills,
      installedHooks,
      alwaysUpdateCommands,
      shouldBackupCommand,
      shouldSkipCommand,
      COMMAND_TEMPLATES,
      generateMenuCommand,
      createBackup,
    });

    const installed = deployCommandsResult.installed;
    const failed = deployCommandsResult.failed;
    const backedUpFiles = [...deployCommandsResult.backedUpFiles];

    // Step 6b: Deploy hooks
    const hooksResult = await deployHooks({
      hooksDir: paths.hooksDir,
      featureHooks,
      overwrite,
      createBackup,
    });
    backedUpFiles.push(...hooksResult.backedUpFiles);

    // Step 6c: Deploy skills
    const skillsResult = await deploySkills({
      skillsDir: paths.skillsDir,
      featureSkills,
      overwrite,
      createBackup,
    });
    backedUpFiles.push(...skillsResult.backedUpFiles);

    // Step 6d: Deploy binaries
    const binariesResult = await deployBinaries({
      cwd,
      featureBinaries,
      overwrite,
      createBackup,
    });
    backedUpFiles.push(...binariesResult.backedUpFiles);

    // Step 7: Generate documentation
    generateDocumentation(paths.commandsDir, installed, projectName, generateIndexFile, generateReadmeFile);

    // Step 8: Generate tech-stack.json
    const deployment = {
      commands: installed,
      featureCommands: featureCommands.filter(c => installed.includes(c)),
      hooks: hooksResult.deployed,
      featureHooks: featureHooks,
      skills: skillsResult.deployed,
      featureSkills: featureSkills,
      enabledFeatures: selectedFeatures,
      timestamp: new Date().toISOString(),
    };
    generateTechStack(claudeDir, projectName, selectedFeatures, featuresRequiringConfig, deployment);

    // Step 9: Update ccasp-state.json
    updateCcaspState(claudeDir);

    // Step 10: Setup Codex prompt routing/support
    const codexSetup = setupCodexSupport(cwd);

    // Step 11: Register in global registry
    registerInGlobalRegistry(cwd, projectName, selectedFeatures, options);

    // Step 12: Auto-generate stack-specific agents
    await generateStackAgents(selectedFeatures, cwd);

    // Display summary
    displayInstallationSummary(projectName, installed, existingCmdNames, hasExistingClaudeDir, overwrite, codexSetup);
    displayFailures(failed);
    displayNextSteps(featuresRequiringConfig);

  } catch (error) {
    if (error.message === 'Installation cancelled by user') {
      console.log(chalk.dim('\nCancelled. No changes made.'));
      return;
    }
    throw error;
  }
}
