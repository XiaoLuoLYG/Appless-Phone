import { hapTasks } from '@ohos/hvigor-ohos-plugin';
import { execFileSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { dirname, join } from 'node:path';

function projectRoot(startDir: string): string {
  let current = startDir;
  for (let index = 0; index < 6; index++) {
    if (existsSync(join(current, 'scripts', 'sync-provider-config.mjs'))) {
      return current;
    }
    const parent = dirname(current);
    if (parent === current) {
      break;
    }
    current = parent;
  }
  return startDir;
}

function syncLocalProviderConfig(): void {
  const rootDir = projectRoot(process.cwd());
  const envPath = join(rootDir, 'tool-gateway', '.env.local');
  const scriptPath = join(rootDir, 'scripts', 'sync-provider-config.mjs');
  if (!existsSync(envPath) || !existsSync(scriptPath)) {
    console.warn('[AIPhone] Skipping local provider config sync: missing tool-gateway/.env.local');
    return;
  }
  execFileSync(process.execPath, [scriptPath], { cwd: rootDir, stdio: 'inherit' });
}

syncLocalProviderConfig();

export default {
  system: hapTasks, /* Built-in plugin of Hvigor. It cannot be modified. */
  plugins: []       /* Custom plugin to extend the functionality of Hvigor. */
}
