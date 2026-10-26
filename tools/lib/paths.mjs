import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { createHash } from 'node:crypto';
export const ROOT = fileURLToPath(new URL('../../', import.meta.url));
export const at = (...parts) => path.join(ROOT, ...parts);
export const hash = bytes => createHash('sha256').update(bytes).digest('hex');
export function inside(base, relative) {
  if (path.isAbsolute(relative) || relative.split(/[\\/]/).includes('..')) throw Error(`Unsafe relative path: ${relative}`);
  const result = path.resolve(base, relative);
  if (!result.startsWith(path.resolve(base) + path.sep)) throw Error('Path escapes source');
  return result;
}
