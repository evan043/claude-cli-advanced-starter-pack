import fs from 'fs';
import path from 'path';
import { exists, isBrokenLink, removePath } from './fs.js';

export function isLinkTo(linkPath, target) {
  if (!exists(linkPath)) return false;
  try {
    const real = fs.realpathSync(linkPath);
    return path.resolve(real) === path.resolve(target);
  } catch {
    return false;
  }
}

export function linkDir(linkPath, target, isWindows, dryRun, repair) {
  if (isLinkTo(linkPath, target)) {
    return { created: false, repaired: false, skipped: true, message: `Link ok: ${linkPath} -> ${target}` };
  }

  if (exists(linkPath)) {
    if (!repair) {
      return { created: false, repaired: false, skipped: true, message: `Exists (repair disabled): ${linkPath}` };
    }
    if (dryRun) {
      return { created: false, repaired: true, skipped: false, message: `Would repair link: ${linkPath} -> ${target}` };
    }
    removePath(linkPath);
  } else if (isBrokenLink(linkPath)) {
    if (!repair) {
      return { created: false, repaired: false, skipped: true, message: `Broken link (repair disabled): ${linkPath}` };
    }
    if (dryRun) {
      return { created: false, repaired: true, skipped: false, message: `Would repair link: ${linkPath} -> ${target}` };
    }
    removePath(linkPath);
  }

  if (dryRun) {
    return { created: true, repaired: false, skipped: false, message: `Would create link: ${linkPath} -> ${target}` };
  }

  fs.mkdirSync(path.dirname(linkPath), { recursive: true });
  try {
    fs.symlinkSync(target, linkPath, isWindows ? 'junction' : 'dir');
    return { created: true, repaired: false, skipped: false, message: `Link created: ${linkPath} -> ${target}` };
  } catch (err) {
    return { created: false, repaired: false, skipped: false, message: `Failed to create link: ${String(err)}` };
  }
}
