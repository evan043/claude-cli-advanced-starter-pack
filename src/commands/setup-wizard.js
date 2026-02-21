/**
 * CCASP Setup Wizard
 *
 * Vibe-code friendly setup wizard with minimal typing.
 * Designed for mobile/remote use with numbered options.
 */

import inquirer from 'inquirer';
import chalk from 'chalk';
import boxen from 'boxen';
import { existsSync } from 'fs';
import { join } from 'path';
import { claudeAbsolutePath } from '../utils/paths.js';

import { runSetup as runGitHubSetup } from './setup.js';
import { promptForIntegrations } from '../pm-hierarchy/integration-wizard.js';
import {
  performVersionCheck,
  formatUpdateBanner,
} from '../utils/version-check.js';
import { pickDirectory, changeDirectory } from '../utils/directory-picker.js';

// Import from wizard modules
import {
  // Helpers
  createBackup,
  showSetupHeader,
  showRestartReminder,
  // Prompts
  SETUP_OPTIONS,
  ADVANCED_OPTIONS,
  // Actions
  runRemove,
  runReinstall,
  runAutoInstall,
  runCustomInstall,
  showTemplates,
  showPriorReleases,
  installHappyEngineering,
} from './wizard/index.js';
import { installFont } from './install-font.js';

/**
 * Check for updates and show banner if available
 * @returns {Object|null} Check result or null on error
 */
async function checkAndShowUpdateBanner() {
  try {
    const checkResult = await performVersionCheck(process.cwd(), false);

    if (checkResult.updateAvailable && checkResult.shouldNotify) {
      const banner = formatUpdateBanner(checkResult);
      if (banner) {
        console.log(chalk.yellow(banner));
      }
    }

    return checkResult;
  } catch {
    // Silently fail - network might be unavailable
    return null;
  }
}

/**
 * Advanced options submenu - Issue #14: Removed custom (Full Install has customization)
 */
async function showAdvancedOptions() {
  let inSubmenu = true;

  while (inSubmenu) {
    const { action } = await inquirer.prompt([
      {
        type: 'list',
        name: 'action',
        message: 'Advanced Options:',
        choices: ADVANCED_OPTIONS,
        pageSize: 4,
      },
    ]);

    switch (action) {
      case 'templates':
        await showTemplates();
        break;

      case 'releases':
        await showPriorReleases();
        break;

      case 'back':
        inSubmenu = false;
        break;
    }
  }
}

/**
 * Main setup wizard - entry point
 * @param {Object} options - Configuration options
 * @param {boolean} options.fromPostinstall - Whether launched from postinstall (enables directory selection)
 */
export async function runSetupWizard(options = {}) {
  showSetupHeader();

  // If launched from postinstall, offer directory selection first (Issue #15)
  if (options.fromPostinstall) {
    const dirResult = await pickDirectory({
      currentDir: process.cwd(),
      showCurrent: true,
    });

    if (!dirResult) {
      console.log(chalk.dim('\nSetup cancelled. Run "ccasp wizard" anytime to continue.\n'));
      return;
    }

    // Change to selected directory if different
    if (dirResult.changed) {
      const success = changeDirectory(dirResult.path);
      if (!success) {
        console.log(chalk.red('\nFailed to change directory. Exiting setup.\n'));
        return;
      }
    } else {
      console.log(chalk.green(`\nUsing current directory: ${chalk.cyan(dirResult.path)}\n`));
    }
  }

  // Check for updates in background (non-blocking display)
  await checkAndShowUpdateBanner();

  // Check if .claude already exists
  const claudeDir = claudeAbsolutePath(process.cwd());
  const claudeMd = join(process.cwd(), 'CLAUDE.md');

  if (existsSync(claudeDir)) {
    console.log(chalk.yellow('\n.claude folder exists in this project.\n'));
  }
  if (existsSync(claudeMd)) {
    console.log(chalk.green('CLAUDE.md exists\n'));
  }

  // Main menu loop - streamlined 3-path flow (Issue #8)
  let running = true;
  while (running) {
    const { action } = await inquirer.prompt([
      {
        type: 'list',
        name: 'action',
        message: 'What would you like to do?',
        choices: SETUP_OPTIONS,
        pageSize: 6, // All options visible without scrolling
      },
    ]);

    switch (action) {
      case 'auto':
        // Auto-Install: ALL features, no prompts
        await runAutoInstall();
        running = false;
        break;

      case 'custom':
        // Custom Install: checkbox UI for feature selection
        await runCustomInstall();
        running = false;
        break;

      case 'reinstall':
        // Reinstall: backup, remove, fresh install
        await runReinstall();
        running = false;
        break;

      case 'github':
        await runGitHubSetup({});
        // Offer additional PM integrations (Jira, Linear, ClickUp)
        await promptForIntegrations({ skipIfConfigured: false });
        showRestartReminder();
        break;

      case 'more':
        // Advanced options submenu
        await showAdvancedOptions();
        break;

      case 'uninstall': {
        // Uninstall: remove CCASP from project
        const removed = await runRemove();
        if (removed) {
          running = false;
        }
        break;
      }

      case 'happy':
        // Install Happy.engineering integration
        await installHappyEngineering();
        break;

      case 'install-font':
        // Install JetBrainsMono Nerd Font for icon rail
        await installFont();
        break;

      case 'exit':
        running = false;
        console.log(chalk.dim('\nRun `ccasp wizard` anytime to return.\n'));
        break;
    }
  }
}

/**
 * Generate slash command content for /ccasp-setup
 * @returns {string} Slash command markdown content
 */
export function generateSlashCommand() {
  return `# CCASP Setup

Run the Claude CLI Advanced Starter Pack setup wizard.

## Usage

This command launches the interactive setup wizard for configuring:
- .claude folder structure
- .codex prompt sync + slash router in AGENTS.md
- GitHub project integration
- Agents, hooks, and skills

## Quick Options

Reply with a number to jump to that option:
1. Quick Start - Auto-detect and initialize
2. Full Setup - All features with customization
3. GitHub Setup - Connect to project board
4. View Templates - Browse available templates
5. Prior Releases - Review & add features from past versions
6. Remove CCASP - Uninstall from this project

## Related Commands

- \`/project-impl\` - Agent-powered project implementation (audit, enhance, detect, configure)
- \`/update-check\` - Check for updates and add new features

## From Terminal

\`\`\`bash
npx ccasp wizard
\`\`\`
`;
}

// Re-export createBackup for backwards compatibility
export { createBackup };

export default runSetupWizard;
