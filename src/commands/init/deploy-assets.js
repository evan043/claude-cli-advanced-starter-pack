/**
 * Asset Deployment Module
 *
 * Handles deployment of commands, hooks, skills, and binaries during init.
 * Extracted from init.js for maintainability.
 */

import chalk from 'chalk';
import ora from 'ora';
import { existsSync, mkdirSync, writeFileSync, readdirSync, readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { createLogger } from '../../utils/logger.js';
import { injectRuntimeCompatibilityShim } from './runtime-compat.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const log = createLogger('init:deploy-assets');

/**
 * Deploy slash commands from templates
 *
 * @param {Object} config - Deployment configuration
 * @returns {Object} Deployment result { installed: [], failed: [], backedUpFiles: [] }
 */
export async function deployCommands(config) {
  const {
    commandsDir,
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
  } = config;

  console.log(chalk.bold('Step 6: Installing slash commands\n'));

  const spinner = ora('Installing commands...').start();
  const installed = [];
  const failed = [];
  const backedUpFiles = [];

  for (const cmdName of finalCommands) {
    try {
      // Skip commands that were marked to skip in smart merge
      // EXCEPT for critical commands that must always be updated
      if (shouldSkipCommand(cmdName) && !alwaysUpdateCommands.includes(cmdName)) {
        continue;
      }

      const cmdPath = join(commandsDir, `${cmdName}.md`);

      let content;
      if (cmdName === 'menu') {
        // Generate dynamic menu command
        content = generateMenuCommand(projectName, finalCommands, installedAgents, installedSkills, installedHooks);
      } else {
        const template = COMMAND_TEMPLATES[cmdName];
        if (template) {
          content = template();
        } else {
          // Try to load from templates/commands/ folder
          const templatePath = join(__dirname, '..', '..', '..', 'templates', 'commands', `${cmdName}.template.md`);
          if (existsSync(templatePath)) {
            content = readFileSync(templatePath, 'utf8');
          } else {
            failed.push({ name: cmdName, error: 'No template found' });
            continue;
          }
        }
      }

      // Create backup if overwriting existing file (respects smart merge decisions)
      if (existsSync(cmdPath) && shouldBackupCommand(cmdName)) {
        const backupPath = createBackup(cmdPath);
        if (backupPath) {
          backedUpFiles.push({ original: cmdPath, backup: backupPath });
        }
      }

      writeFileSync(cmdPath, injectRuntimeCompatibilityShim(content), 'utf8');
      installed.push(cmdName);
    } catch (error) {
      failed.push({ name: cmdName, error: error.message });
    }
  }

  spinner.stop();

  // Show backup summary if any files were backed up
  if (backedUpFiles.length > 0) {
    console.log(chalk.cyan(`\n  📁 Backed up ${backedUpFiles.length} file(s) to .claude/backups/`));
  }

  return { installed, failed, backedUpFiles };
}

/**
 * Deploy feature-specific hooks
 *
 * @param {Object} config - Deployment configuration
 * @returns {Object} Deployment result { deployed: [], failed: [], backedUpFiles: [] }
 */
export async function deployHooks(config) {
  const {
    hooksDir,
    featureHooks,
    overwrite,
    createBackup,
  } = config;

  const deployedHooks = [];
  const failedHooks = [];
  const backedUpFiles = [];

  if (featureHooks.length === 0) {
    return { deployed: deployedHooks, failed: failedHooks, backedUpFiles };
  }

  console.log(chalk.bold('\nStep 6b: Deploying feature hooks\n'));

  for (const hookName of featureHooks) {
    try {
      const hookPath = join(hooksDir, `${hookName}.js`);
      const hookExists = existsSync(hookPath);

      // Respect overwrite setting for hooks (like commands)
      if (hookExists && !overwrite) {
        console.log(chalk.blue(`  ○ hooks/${hookName}.js exists (preserved)`));
        continue;
      }

      // Try to load from templates/hooks/ folder (support both .js and .cjs extensions)
      const templatePathJs = join(__dirname, '..', '..', '..', 'templates', 'hooks', `${hookName}.template.js`);
      const templatePathCjs = join(__dirname, '..', '..', '..', 'templates', 'hooks', `${hookName}.template.cjs`);
      const templatePath = existsSync(templatePathCjs) ? templatePathCjs : templatePathJs;
      const outputExt = existsSync(templatePathCjs) ? '.cjs' : '.js';
      const outputPath = join(hooksDir, `${hookName}${outputExt}`);

      if (existsSync(templatePath)) {
        // Check if output already exists (could be .js or .cjs)
        const hookExistsJs = existsSync(join(hooksDir, `${hookName}.js`));
        const hookExistsCjs = existsSync(join(hooksDir, `${hookName}.cjs`));
        const hookExistsAny = hookExistsJs || hookExistsCjs;

        // Create backup if overwriting existing hook
        if (hookExistsAny && overwrite) {
          const existingPath = hookExistsCjs ? join(hooksDir, `${hookName}.cjs`) : join(hooksDir, `${hookName}.js`);
          const backupPath = createBackup(existingPath);
          if (backupPath) {
            backedUpFiles.push({ original: existingPath, backup: backupPath });
          }
        }

        // Skip if exists and not overwriting
        if (hookExistsAny && !overwrite) {
          console.log(chalk.blue(`  ○ hooks/${hookName}${outputExt} exists (preserved)`));
        } else {
          const hookContent = readFileSync(templatePath, 'utf8');
          writeFileSync(outputPath, hookContent, 'utf8');
          deployedHooks.push(hookName);
          const action = hookExistsAny ? 'Updated' : 'Created';
          console.log(chalk.green(`  ✓ ${action} hooks/${hookName}${outputExt}`));
        }
      } else {
        failedHooks.push({ name: hookName, error: 'No template found' });
        console.log(chalk.yellow(`  ⚠ Skipped hooks/${hookName}${outputExt} (no template)`));
      }
    } catch (error) {
      failedHooks.push({ name: hookName, error: error.message });
      console.log(chalk.red(`  ✗ Failed: hooks/${hookName}.js - ${error.message}`));
    }
  }

  if (deployedHooks.length > 0) {
    console.log(chalk.green(`\n  ✓ Deployed ${deployedHooks.length} feature hook(s)`));
  }

  return { deployed: deployedHooks, failed: failedHooks, backedUpFiles };
}

/**
 * Deploy feature skills
 *
 * @param {Object} config - Deployment configuration
 * @returns {Object} Deployment result { deployed: [], failed: [], backedUpFiles: [] }
 */
export async function deploySkills(config) {
  const {
    skillsDir,
    featureSkills,
    overwrite,
    createBackup,
  } = config;

  const deployedSkills = [];
  const failedSkills = [];
  const backedUpFiles = [];

  if (featureSkills.length === 0) {
    return { deployed: deployedSkills, failed: failedSkills, backedUpFiles };
  }

  console.log(chalk.bold('\nStep 6c: Deploying feature skills\n'));

  for (const skillName of featureSkills) {
    try {
      const skillPath = join(skillsDir, skillName);
      const skillExists = existsSync(skillPath);

      // Respect overwrite setting for skills (like commands)
      if (skillExists && !overwrite) {
        console.log(chalk.blue(`  ○ skills/${skillName}/ exists (preserved)`));
        continue;
      }

      // Try to load from templates/skills/ folder
      const templatePath = join(__dirname, '..', '..', '..', 'templates', 'skills', skillName);
      if (existsSync(templatePath)) {
        // Create backup if overwriting existing skill
        if (skillExists && overwrite) {
          const backupPath = createBackup(skillPath);
          if (backupPath) {
            backedUpFiles.push({ original: skillPath, backup: backupPath });
          }
        }
        // Create skill directory and copy recursively
        mkdirSync(skillPath, { recursive: true });
        const { cpSync } = await import('fs');
        cpSync(templatePath, skillPath, { recursive: true });
        deployedSkills.push(skillName);
        const action = skillExists ? 'Updated' : 'Created';
        console.log(chalk.green(`  ✓ ${action} skills/${skillName}/`));
      } else {
        failedSkills.push({ name: skillName, error: 'No template found' });
        console.log(chalk.yellow(`  ⚠ Skipped skills/${skillName}/ (no template)`));
      }
    } catch (error) {
      failedSkills.push({ name: skillName, error: error.message });
      console.log(chalk.red(`  ✗ Failed: skills/${skillName}/ - ${error.message}`));
    }
  }

  if (deployedSkills.length > 0) {
    console.log(chalk.green(`\n  ✓ Deployed ${deployedSkills.length} feature skill(s)`));
  }

  return { deployed: deployedSkills, failed: failedSkills, backedUpFiles };
}

/**
 * Deploy feature binaries (helper scripts)
 *
 * @param {Object} config - Deployment configuration
 * @returns {Object} Deployment result { deployed: [], failed: [], backedUpFiles: [] }
 */
export async function deployBinaries(config) {
  const {
    cwd,
    featureBinaries,
    overwrite,
    createBackup,
  } = config;

  const deployedBinaries = [];
  const failedBinaries = [];
  const backedUpFiles = [];

  if (featureBinaries.length === 0) {
    return { deployed: deployedBinaries, failed: failedBinaries, backedUpFiles };
  }

  console.log(chalk.bold('\nStep 6d: Deploying helper scripts\n'));

  // Create bin directory in project root (alongside .claude)
  const binDir = join(cwd, 'bin');
  if (!existsSync(binDir)) {
    mkdirSync(binDir, { recursive: true });
  }

  for (const binaryName of featureBinaries) {
    try {
      const binaryPath = join(binDir, binaryName);
      const binaryExists = existsSync(binaryPath);

      // Respect overwrite setting
      if (binaryExists && !overwrite) {
        console.log(chalk.blue(`  ○ bin/${binaryName} exists (preserved)`));
        continue;
      }

      // Try to load from templates/bin/ folder (remove .template suffix if present)
      const templateName = binaryName.includes('.template.') ? binaryName : binaryName.replace(/(\.[^.]+)$/, '.template$1');
      const templatePath = join(__dirname, '..', '..', '..', 'templates', 'bin', templateName);
      if (existsSync(templatePath)) {
        // Create backup if overwriting
        if (binaryExists && overwrite) {
          const backupPath = createBackup(binaryPath);
          if (backupPath) {
            backedUpFiles.push({ original: binaryPath, backup: backupPath });
          }
        }
        const binaryContent = readFileSync(templatePath, 'utf8');
        writeFileSync(binaryPath, binaryContent, 'utf8');
        deployedBinaries.push(binaryName);
        const action = binaryExists ? 'Updated' : 'Created';
        console.log(chalk.green(`  ✓ ${action} bin/${binaryName}`));
      } else {
        failedBinaries.push({ name: binaryName, error: 'No template found' });
        console.log(chalk.yellow(`  ⚠ Skipped bin/${binaryName} (no template)`));
      }
    } catch (error) {
      failedBinaries.push({ name: binaryName, error: error.message });
      console.log(chalk.red(`  ✗ Failed: bin/${binaryName} - ${error.message}`));
    }
  }

  if (deployedBinaries.length > 0) {
    console.log(chalk.green(`\n  ✓ Deployed ${deployedBinaries.length} helper script(s)`));
  }

  return { deployed: deployedBinaries, failed: failedBinaries, backedUpFiles };
}
