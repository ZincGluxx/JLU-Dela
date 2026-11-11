import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const repoRoot = fileURLToPath(new URL('../../', import.meta.url));
const status = execFileSync(
  'git',
  ['status', '--porcelain', '--untracked-files=all', '--', 'contracts/generated/dart'],
  { cwd: repoRoot, encoding: 'utf8' },
);

if (status.trim()) {
  console.error('Generated Dart client is out of date. Re-run npm run generate.');
  console.error(status);
  process.exit(1);
}

console.log('Generated Dart client matches the committed OpenAPI output.');
