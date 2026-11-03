import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { join } from 'node:path';

const load = createRequire(__filename);
const config = JSON.parse(readFileSync(join(__dirname, 'bootstrap.json'), 'utf8')) as {
  originalMain: string;
  bridge: string;
  workdir: string;
};
process.env['NAPCAT_WORKDIR'] = config.workdir;
process.env['NAPCAT_DISABLE_MULTI_PROCESS'] = '1';
process.env['NAPCAT_DISABLE_PIPE'] = '1';
try {
  load(join(config.bridge, 'napcat.cjs'));
} catch (error) {
  console.error('Dela QQ bridge failed to load', error);
}
load(join(process.resourcesPath, 'app', config.originalMain));
setImmediate(() => {
  const launcher = (
    globalThis as typeof globalThis & {
      launcher?: { installPathPkgJson: { main: string } };
    }
  ).launcher;
  if (launcher) launcher.installPathPkgJson.main = config.originalMain;
});
