/**
 * Installation Operations
 *
 * Handles reinstall, auto-install, and custom install flows.
 */

import inquirer from 'inquirer';
import chalk from 'chalk';
import ora from 'ora';
import boxen from 'boxen';
import { existsSync, mkdirSync, rmSync, copyFileSync } from 'fs';
import { join } from 'path';

import { runInit } from '../../init.js';
import {
  copyDirRecursive,
  showRestartReminder,
  launchClaudeCLI,
  getTemplateCounts,
} from '../helpers.js';

import {
  getAllFeatures,
  mapFeaturesToInit,
  getDefaultFeatures,
  getAllInitFeatures,
} from '../prompts.js';
import { claudeAbsolutePath } from '../../../utils/paths.js';

/**
 * Run reinstall - backup, remove, and fresh install
 * Useful for cleaning up corrupted installations or resetting to defaults
 * @returns {boolean} True if reinstall succeeded
 */
export async function runReinstall() {
  console.log(
    boxen(
      chalk.bold.cyan('CCASP Reinstall (Clean)\n\n') +
        chalk.white('This will:\n') +
        chalk.dim('  1. Create a full backup of your .claude folder\n') +
        chalk.dim('  2. Remove all CCASP files\n') +
        chalk.dim('  3. Run a fresh auto-install'),
      {
        padding: 1,
        borderStyle: 'round',
        borderColor: 'cyan',
      }
    )
  );

  // Confirm with user
  const { confirmReinstall } = await inquirer.prompt([
    {
      type: 'confirm',
      name: 'confirmReinstall',
      message: chalk.yellow('Proceed with reinstall? (backup will be created)'),
      default: false,
    },
  ]);

  if (!confirmReinstall) {
    console.log(chalk.dim('\nReinstall cancelled. No changes made.\n'));
    return false;
  }

  const claudeDir = claudeAbsolutePath(process.cwd());
  const claudeMdPath = join(process.cwd(), 'CLAUDE.md');
  const hasClaudeDir = existsSync(claudeDir);
  const hasClaudeMd = existsSync(claudeMdPath);

  // Step 1: Create backup
  if (hasClaudeDir || hasClaudeMd) {
    const spinner = ora('Creating backup...').start();

    try {
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
      const backupDir = join(process.cwd(), '.claude-backup', `reinstall-${timestamp}`);
      mkdirSync(backupDir, { recursive: true });

      if (hasClaudeDir) {
        const backupClaudeDir = join(backupDir, '.claude');
        copyDirRecursive(claudeDir, backupClaudeDir);
      }

      if (hasClaudeMd) {
        copyFileSync(claudeMdPath, join(backupDir, 'CLAUDE.md'));
      }

      spinner.succeed(`Backed up to ${chalk.cyan(backupDir)}`);
    } catch (error) {
      spinner.fail('Backup failed');
      console.error(chalk.red(error.message));
      return false;
    }

    // Step 2: Remove existing files
    const removeSpinner = ora('Removing existing files...').start();

    try {
      if (hasClaudeDir) {
        rmSync(claudeDir, { recursive: true, force: true });
      }
      if (hasClaudeMd) {
        rmSync(claudeMdPath, { force: true });
      }
      removeSpinner.succeed('Removed existing CCASP files');
    } catch (error) {
      removeSpinner.fail('Removal failed');
      console.error(chalk.red(error.message));
      return false;
    }
  }

  // Step 3: Fresh install
  console.log(chalk.cyan('\nRunning fresh install...\n'));
  return await runAutoInstall();
}

/**
 * Run auto-install - installs ALL features without any prompts
 * This is the recommended path for most users
 * @returns {boolean} True if installation succeeded
 */
export async function runAutoInstall() {
  // Display header
  console.log(
    boxen(
      chalk.bold.cyan('CCASP Auto-Install\n\n') +
        chalk.white('Installing ALL features automatically.\n') +
        chalk.dim('No prompts - full feature set'),
      {
        padding: 1,
        borderStyle: 'round',
        borderColor: 'cyan',
      }
    )
  );

  // Get all default features (all features are checked by default)
  const allFeatures = getDefaultFeatures();

  // Map to init.js features - use ALL optional features
  const initFeatures = getAllInitFeatures();

  console.log(chalk.dim(`\nInstalling: ${allFeatures.length} features (all categories)`));

  // Check if .claude folder exists and handle backup
  const claudeDir = join(process.cwd(), '.claude');
  const claudeMdPath = join(process.cwd(), 'CLAUDE.md');
  const hasExisting = existsSync(claudeDir) || existsSync(claudeMdPath);

  let installStrategy = 'backup'; // Default: backup then overwrite

  if (hasExisting) {
    const existing = [];
    if (existsSync(claudeDir)) existing.push('.claude/');
    if (existsSync(claudeMdPath)) existing.push('CLAUDE.md');

    console.log(chalk.yellow(`\nExisting files found: ${existing.join(', ')}`));
    console.log(chalk.dim('Creating backup before overwriting...\n'));
    installStrategy = 'backup';
  }

  // Run init with ALL features
  const spinner = ora('Installing ALL CCASP features...').start();

  try {
    await runInit({
      features: initFeatures,
      skipPrompts: true,
      preset: 'full',
      backup: installStrategy === 'backup',
      force: false,
      skipExisting: false,
    });

    spinner.succeed('CCASP fully installed!');

    // Get dynamic template counts
    const counts = getTemplateCounts();

    // Show summary
    console.log(
      boxen(
        `${chalk.bold.green('Auto-Install Complete\n\n') +
          chalk.white('All features installed:\n\n') 
          }Commands:  ${chalk.cyan(counts.commands)} ${chalk.dim('(GitHub, planning, testing, deploy, refactor...)')}\n` +
          `Hooks:     ${chalk.cyan(counts.hooks)} ${chalk.dim('(token, happy, advanced suite, orchestration...)')}\n` +
          `Skills:    ${chalk.cyan(counts.skills)} ${chalk.dim('(agent-creator, hook-creator, rag-agent...)')}\n` +
          `Docs:      ${chalk.cyan('4')} ${chalk.dim('(INDEX, README, gotchas, constitution)')}\n\n${ 
          chalk.bold('Next Steps:\n') 
          }${chalk.dim('1. Launch Claude Code CLI\n') 
          }${chalk.dim('2. Run ')  }${chalk.yellow('/project-implementation-for-ccasp')  }${chalk.dim(' for full setup\n')
          }${chalk.dim('3. Codex prompts are synced to ') }${chalk.yellow('.codex/prompts')}`,
        {
          padding: 1,
          borderStyle: 'round',
          borderColor: 'green',
        }
      )
    );

    // Show autonomous decision logger info
    console.log(
      boxen(
        chalk.cyan.bold('Audit Hook Installed\n\n') +
          chalk.white('Autonomous Decision Logger creates JSONL audit trail:\n') +
          chalk.dim('  - Tracks Edit, Write, Bash, Task tool calls\n') +
          chalk.dim('  - Log: .claude/logs/decisions.jsonl\n') +
          chalk.dim('  - 10MB rotation, 30-day retention\n\n') +
          chalk.dim('Configure in .claude/config/hooks-config.json'),
        {
          padding: 1,
          borderStyle: 'round',
          borderColor: 'cyan',
        }
      )
    );

    // Offer to launch Claude CLI
    const { launchClaude } = await inquirer.prompt([
      {
        type: 'confirm',
        name: 'launchClaude',
        message: 'Launch Claude Code CLI now?',
        default: true,
      },
    ]);

    if (launchClaude) {
      await launchClaudeCLI();
    } else {
      showRestartReminder();
    }

    return true;
  } catch (error) {
    spinner.fail('Installation failed');
    console.error(chalk.red(error.message));
    return false;
  }
}

/**
 * Run custom install with organized checkbox deselection
 * Shows checkbox UI for users who want to customize feature selection
 * @returns {boolean} True if installation succeeded
 */
export async function runCustomInstall() {
  // Display header
  console.log(
    boxen(
      chalk.bold.cyan('CCASP Custom Install\n\n') +
        chalk.white('All features selected by default.\n') +
        chalk.dim('Space to toggle - Enter to install'),
      {
        padding: 1,
        borderStyle: 'round',
        borderColor: 'cyan',
      }
    )
  );

  // Get feature selection with organized categories
  const { selectedFeatures } = await inquirer.prompt([
    {
      type: 'checkbox',
      name: 'selectedFeatures',
      message: 'Select features to install:',
      choices: getAllFeatures(),
      pageSize: 25, // Show all without scrolling
      loop: false,
    },
  ]);

  // Map to init.js features
  const initFeatures = mapFeaturesToInit(selectedFeatures);

  // Count selections by category for summary
  const summary = {
    commands: selectedFeatures.filter((f) => ['githubIntegration', 'phasedDevelopment', 'testing', 'deploymentAutomation', 'refactoring', 'mcpExplorer', 'analysis'].includes(f)).length,
    agents: selectedFeatures.filter((f) => ['exampleAgent', 'createAgent'].includes(f)).length,
    hooks: selectedFeatures.filter((f) => ['updateChecker', 'advancedHooks'].includes(f)).length,
    skills: selectedFeatures.filter((f) => ['exampleSkill', 'skillTemplates'].includes(f)).length,
    extras: selectedFeatures.filter((f) => ['tokenManagement', 'tunnelServices', 'happyMode'].includes(f)).length,
    docs: selectedFeatures.filter((f) => ['indexMd', 'readmeMd'].includes(f)).length,
  };

  console.log(chalk.dim(`\nSelected: ${Object.values(summary).reduce((a, b) => a + b, 0)} features`));

  // Check if .claude folder exists and ask about backup/overwrite strategy
  const claudeDir = join(process.cwd(), '.claude');
  const claudeMdPath = join(process.cwd(), 'CLAUDE.md');
  const hasExisting = existsSync(claudeDir) || existsSync(claudeMdPath);

  let installStrategy = 'backup'; // Default: backup then overwrite

  if (hasExisting) {
    const existing = [];
    if (existsSync(claudeDir)) existing.push('.claude/');
    if (existsSync(claudeMdPath)) existing.push('CLAUDE.md');

    console.log(chalk.yellow(`\nExisting files found: ${existing.join(', ')}`));

    const { strategy } = await inquirer.prompt([
      {
        type: 'list',
        name: 'strategy',
        message: 'How should existing files be handled?',
        choices: [
          {
            name: `${chalk.green('1.')} Backup + Overwrite ${chalk.dim('- Create backup, then replace (recommended)')}`,
            value: 'backup',
            short: 'Backup + Overwrite',
          },
          {
            name: `${chalk.yellow('2.')} Skip Existing ${chalk.dim('- Only add new files, keep existing')}`,
            value: 'skip',
            short: 'Skip Existing',
          },
          {
            name: `${chalk.red('3.')} Overwrite All ${chalk.dim('- Replace everything without backup')}`,
            value: 'force',
            short: 'Overwrite All',
          },
          {
            name: `${chalk.dim('0.')} Cancel`,
            value: 'cancel',
            short: 'Cancel',
          },
        ],
        pageSize: 5,
      },
    ]);

    if (strategy === 'cancel') {
      console.log(chalk.dim('\nInstallation cancelled. No changes made.\n'));
      return false;
    }

    installStrategy = strategy;
  }

  // Run init with selected features and strategy
  const spinner = ora('Installing CCASP features...').start();

  try {
    await runInit({
      features: initFeatures,
      skipPrompts: true,
      preset: 'full',
      backup: installStrategy === 'backup',
      force: installStrategy === 'force',
      skipExisting: installStrategy === 'skip',
    });

    spinner.succeed('CCASP features installed!');

    // Show summary
    console.log(
      boxen(
        `${chalk.bold.green('Installation Complete\n\n') 
          }Commands:  ${chalk.cyan(summary.commands)}\n` +
          `Agents:    ${chalk.cyan(summary.agents)}\n` +
          `Hooks:     ${chalk.cyan(summary.hooks)}\n` +
          `Skills:    ${chalk.cyan(summary.skills)}\n` +
          `Extras:    ${chalk.cyan(summary.extras)}\n` +
          `Docs:      ${chalk.cyan(summary.docs)}\n\n${ 
          chalk.bold('Next Steps:\n') 
          }${chalk.dim('1. Restart Claude Code CLI\n') 
          }${chalk.dim('2. Run ')  }${chalk.yellow('/project-implementation-for-ccasp')  }${chalk.dim(' for full setup')}`,
        {
          padding: 1,
          borderStyle: 'round',
          borderColor: 'green',
        }
      )
    );

    // Offer to launch Claude CLI
    const { launchClaude } = await inquirer.prompt([
      {
        type: 'confirm',
        name: 'launchClaude',
        message: 'Launch Claude Code CLI now?',
        default: true,
      },
    ]);

    if (launchClaude) {
      await launchClaudeCLI();
    } else {
      showRestartReminder();
    }

    return true;
  } catch (error) {
    spinner.fail('Installation failed');
    console.error(chalk.red(error.message));
    return false;
  }
}
