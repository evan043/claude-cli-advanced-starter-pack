/**
 * Summary Display
 * Displays installation summary and next steps
 */

import chalk from 'chalk';
import { showSuccess, showError } from '../../cli/menu.js';

/**
 * Display installation summary
 * @param {string} projectName - Project name
 * @param {Array} installed - Installed commands
 * @param {Array} existingCmdNames - Existing command names
 * @param {boolean} hasExistingClaudeDir - Had existing .claude dir
 * @param {boolean} overwrite - Overwrite mode enabled
 * @param {Object} codexSetup - Codex setup result
 */
export function displayInstallationSummary(projectName, installed, existingCmdNames, hasExistingClaudeDir, overwrite, codexSetup = null) {
  console.log('');

  // Count what was preserved
  const preservedCommands = existingCmdNames.filter(c => !installed.includes(c) || !overwrite);
  const newCommands = installed.filter(c => !existingCmdNames.includes(c));
  const updatedCommands = installed.filter(c => existingCmdNames.includes(c) && overwrite);

  if (installed.length > 0) {
    const summaryLines = [
      '',
      `Project: ${projectName}`,
      '',
    ];

    // Show what happened
    if (hasExistingClaudeDir) {
      summaryLines.push('Integration Summary:');
      if (newCommands.length > 0) {
        summaryLines.push(`  ✓ ${newCommands.length} new command(s) added`);
      }
      if (updatedCommands.length > 0) {
        summaryLines.push(`  ↻ ${updatedCommands.length} command(s) updated`);
      }
      if (preservedCommands.length > 0) {
        summaryLines.push(`  ○ ${preservedCommands.length} existing command(s) preserved`);
      }
      summaryLines.push('');
    }

    summaryLines.push('Folder Structure:');
    summaryLines.push('  .claude/');
    summaryLines.push('  ├── commands/     (slash commands)');
    summaryLines.push('  ├── agents/       (custom agents)');
    summaryLines.push('  ├── skills/       (skill packages)');
    summaryLines.push('  ├── hooks/        (enforcement hooks)');
    summaryLines.push('  ├── docs/         (documentation)');
    summaryLines.push('  ├── settings.json');
    summaryLines.push('  └── settings.local.json');
    summaryLines.push('');
    summaryLines.push('Codex Integration:');
    summaryLines.push(`  .codex/prompts synced: ${codexSetup?.promptsSynced || 0}`);
    if ((codexSetup?.promptsSkipped || 0) > 0) {
      summaryLines.push(`  .codex/prompts skipped: ${codexSetup.promptsSkipped}`);
    }
    if (codexSetup?.routerCreated) {
      summaryLines.push('  AGENTS.md router block: created');
    } else if (codexSetup?.routerUpdated) {
      summaryLines.push('  AGENTS.md router block: updated');
    } else {
      summaryLines.push('  AGENTS.md router block: already present');
    }
    summaryLines.push('');
    summaryLines.push(`Commands Available: ${installed.length + preservedCommands.length}`);
    summaryLines.push(...installed.slice(0, 6).map((c) => `  /${c}${newCommands.includes(c) ? ' (new)' : ''}`));
    if (installed.length > 6) {
      summaryLines.push(`  ... and ${installed.length - 6} more`);
    }

    showSuccess('Claude CLI Advanced Starter Pack Deployed!', summaryLines);
  }
}

/**
 * Display failed installations
 * @param {Array} failed - Failed command installations
 */
export function displayFailures(failed) {
  if (failed.length === 0) {
    return;
  }

  showError('Some commands failed to install:');
  for (const f of failed) {
    console.log(chalk.red(`  /${f.name}: ${f.error}`));
  }
}

/**
 * Display next steps
 * @param {Array} featuresRequiringConfig - Features needing configuration
 */
export function displayNextSteps(featuresRequiringConfig) {
  console.log(chalk.bold('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'));
  console.log(chalk.bold('Next Steps:\n'));
  console.log(`${chalk.cyan('  1.')  } Launch Claude Code CLI in this project`);
  console.log(`${chalk.cyan('  2.')  } Type ${chalk.bold('/menu')} to see the interactive project menu`);
  console.log(`${chalk.cyan('  3.')  } In Codex, use slash commands via ${chalk.bold('.codex/prompts')} (router in AGENTS.md)`);

  // Show post-config reminder if features need it
  if (featuresRequiringConfig.length > 0) {
    console.log(chalk.cyan('  4.') + chalk.yellow(' Configure enabled features via /menu → Project Settings'));
    console.log(chalk.dim(`       Features pending configuration: ${featuresRequiringConfig.map((f) => f.label).join(', ')}`));
    console.log(`${chalk.cyan('  5.')  } Use any installed command by typing its name (e.g., /e2e-test)`);
  } else {
    console.log(`${chalk.cyan('  4.')  } Use any installed command by typing its name (e.g., /e2e-test)`);
  }

  console.log('');
  console.log(chalk.dim('  Customize your setup:'));
  console.log(chalk.dim('    • Edit agents in .claude/agents/'));
  console.log(chalk.dim('    • Create skills in .claude/skills/'));
  console.log(chalk.dim('    • Add hooks in .claude/hooks/'));
  console.log(chalk.dim('    • Configure tech stack in .claude/config/tech-stack.json'));
  console.log('');
  console.log(chalk.dim(`  To update: ${chalk.bold('npx claude-cli-advanced-starter-pack init --force')}`));
  console.log('');
}
