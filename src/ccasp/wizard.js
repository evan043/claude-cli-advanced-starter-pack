import inquirer from 'inquirer';
import { detectOS, detectRuntimes } from './detect.js';
import { runInit, scanProject } from './init.js';

export async function runWizard(options = {}) {
  const root = process.cwd();
  const osInfo = detectOS();
  const runtimeInfo = detectRuntimes();
  const status = scanProject(root);

  console.log('Status Summary\n=');
  console.log(`Project: ${status.root}`);
  console.log(`.ccasp/ present: ${status.hasCcasp ? 'yes' : 'no'}`);
  console.log(`.claude present: ${status.hasClaude ? 'yes' : 'no'}`);
  console.log(`.codex present: ${status.hasCodex ? 'yes' : 'no'}`);
  console.log(`CLAUDE.md present: ${status.hasClaudeMd ? 'yes' : 'no'}`);
  console.log(`Legacy commands: ${status.hasLegacyCommands ? 'yes' : 'no'}`);
  console.log(`Legacy hooks: ${status.hasLegacyHooks ? 'yes' : 'no'}`);
  if (status.brokenClaude) console.log('Broken .claude link detected');
  if (status.brokenCodex) console.log('Broken .codex link detected');
  console.log('');

  console.log(`OS: ${osInfo.platform}${osInfo.isWSL ? ' (WSL)' : ''}`);
  console.log(`Claude CLI: ${runtimeInfo.claude ? 'yes' : 'no'}`);
  console.log(`Codex CLI: ${runtimeInfo.codex ? 'yes' : 'no'}`);
  console.log('');

  const { pathChoice } = await inquirer.prompt([
    {
      type: 'list',
      name: 'pathChoice',
      message: 'Choose a setup path:',
      choices: [
        { name: 'Fresh setup', value: 'fresh' },
        { name: 'Convert legacy Claude project', value: 'legacy_claude' },
        { name: 'Convert legacy Codex project', value: 'legacy_codex' },
        { name: 'Merge dual runtime', value: 'merge' },
        { name: 'Repair broken symlinks', value: 'repair' },
      ],
    },
  ]);

  const { enableClaude, enableCodex } = await inquirer.prompt([
    { type: 'confirm', name: 'enableClaude', message: 'Enable Claude runtime?', default: true },
    { type: 'confirm', name: 'enableCodex', message: 'Enable Codex runtime?', default: runtimeInfo.codex },
  ]);

  const dualDefault = Boolean(enableClaude && enableCodex);
  const advanced = await inquirer.prompt([
    { type: 'confirm', name: 'dualRuntime', message: 'Enable dual runtime mode?', default: dualDefault },
    { type: 'confirm', name: 'hooksEnabled', message: 'Enable hooks?', default: true },
    {
      type: 'list',
      name: 'governance',
      message: 'Governance mode:',
      choices: [
        { name: 'Standard', value: 'standard' },
        { name: 'Strict enforcement', value: 'strict' },
        { name: 'Off', value: 'off' },
      ],
      default: 'standard',
    },
  ]);

  let defaultRuntime = enableClaude ? 'claude' : 'codex';
  if (enableClaude && enableCodex && advanced.dualRuntime) {
    const runtimeChoice = await inquirer.prompt([
      {
        type: 'list',
        name: 'defaultRuntime',
        message: 'Default runtime:',
        choices: [
          { name: 'Claude', value: 'claude' },
          { name: 'Codex', value: 'codex' },
        ],
        default: 'claude',
      },
    ]);
    defaultRuntime = runtimeChoice.defaultRuntime;
  }

  const convertLegacy = pathChoice === 'legacy_claude' || pathChoice === 'legacy_codex' || pathChoice === 'merge';
  const repair = pathChoice === 'repair' || options.repairLinks;

  console.log('Summary\n=');
  console.log(`Convert legacy: ${convertLegacy ? 'yes' : 'no'}`);
  console.log(`Repair links: ${repair ? 'yes' : 'no'}`);
  console.log(`Enable Claude: ${enableClaude ? 'yes' : 'no'}`);
  console.log(`Enable Codex: ${enableCodex ? 'yes' : 'no'}`);
  console.log(`Dual runtime: ${advanced.dualRuntime ? 'yes' : 'no'}`);
  console.log(`Hooks: ${advanced.hooksEnabled ? 'yes' : 'no'}`);
  console.log(`Governance: ${advanced.governance}`);
  console.log(`Default runtime: ${defaultRuntime}`);
  console.log('');

  const { confirm } = await inquirer.prompt([
    { type: 'confirm', name: 'confirm', message: 'Apply changes?', default: true },
  ]);

  if (!confirm) {
    console.log('No changes applied');
    return 0;
  }

  return runInit({
    dryRun: options.dryRun,
    repairLinks: repair,
    enableClaude,
    enableCodex,
    convertLegacy,
    configUpdates: {
      default_runtime: defaultRuntime,
      dual_runtime: advanced.dualRuntime,
      hooks_enabled: advanced.hooksEnabled,
      governance_mode: advanced.governance,
    },
  });
}
