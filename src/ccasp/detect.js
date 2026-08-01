import fs from 'fs';
import os from 'os';
import path from 'path';

export function detectOS() {
  const platform = os.platform();
  const isWindows = platform === 'win32';
  const isMac = platform === 'darwin';
  const isLinux = platform === 'linux';
  let isWSL = false;

  if (isLinux) {
    const env = process.env.WSL_DISTRO_NAME || process.env.WSL_INTEROP;
    let version = '';
    try {
      version = fs.readFileSync('/proc/version', 'utf8').toLowerCase();
    } catch {
      version = '';
    }
    if (env || version.includes('microsoft')) {
      isWSL = true;
    }
  }

  return { platform, isWindows, isMac, isLinux, isWSL };
}

function isExecutable(filePath) {
  try {
    fs.accessSync(filePath, fs.constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

export function findExecutable(name) {
  const pathEnv = process.env.PATH || '';
  const segments = pathEnv.split(path.delimiter);
  const extensions = process.platform === 'win32' ? ['.exe', '.cmd', '.bat', ''] : [''];

  for (const dir of segments) {
    for (const ext of extensions) {
      const full = path.join(dir, `${name}${ext}`);
      if (fs.existsSync(full) && isExecutable(full)) {
        return full;
      }
    }
  }
  return undefined;
}

export function detectRuntimes() {
  const claudePath = findExecutable('claude');
  const codexPath = findExecutable('codex');
  return {
    claude: Boolean(claudePath),
    codex: Boolean(codexPath),
    claudePath,
    codexPath,
  };
}
