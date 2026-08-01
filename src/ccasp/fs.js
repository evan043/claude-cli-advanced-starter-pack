import fs from 'fs';
import path from 'path';

export function exists(p) {
  try {
    fs.accessSync(p);
    return true;
  } catch {
    return false;
  }
}

export function ensureDir(p) {
  fs.mkdirSync(p, { recursive: true });
}

export function readFile(p) {
  return fs.readFileSync(p, 'utf8');
}

export function writeFile(p, content) {
  ensureDir(path.dirname(p));
  fs.writeFileSync(p, content, 'utf8');
}

export function copyRecursive(src, dest) {
  if (!fs.existsSync(src)) return;
  const stat = fs.statSync(src);
  if (stat.isDirectory()) {
    fs.mkdirSync(dest, { recursive: true });
    for (const entry of fs.readdirSync(src)) {
      copyRecursive(path.join(src, entry), path.join(dest, entry));
    }
  } else {
    ensureDir(path.dirname(dest));
    fs.copyFileSync(src, dest);
  }
}

export function movePath(src, dest) {
  ensureDir(path.dirname(dest));
  fs.renameSync(src, dest);
}

export function removePath(p) {
  if (!exists(p)) return;
  const stat = fs.lstatSync(p);
  if (stat.isSymbolicLink() || stat.isFile()) {
    fs.unlinkSync(p);
    return;
  }
  if (stat.isDirectory()) {
    fs.rmSync(p, { recursive: true, force: true });
  }
}

export function isBrokenLink(p) {
  if (!exists(p)) return false;
  const stat = fs.lstatSync(p);
  if (!stat.isSymbolicLink()) return false;
  try {
    fs.statSync(p);
    return false;
  } catch {
    return true;
  }
}
