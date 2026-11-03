import { app } from 'electron';
import { spawn, execFile, type ChildProcess } from 'node:child_process';
import { createHash } from 'node:crypto';
import { createWriteStream } from 'node:fs';
import { copyFile, mkdir, mkdtemp, readFile, readdir, writeFile } from 'node:fs/promises';
import { createServer } from 'node:net';
import { createRequire } from 'node:module';
import { tmpdir } from 'node:os';
import { dirname, join, relative, resolve } from 'node:path';
import { promisify } from 'node:util';
import extract from 'extract-zip';

async function probe() {
  const profile = await mkdtemp(join(tmpdir(), 'dela-qq-framework-probe-'));
  const bridge = join(profile, 'framework');
  const workdir = join(profile, 'data');
  const client = join(profile, 'QQ.app');
  const exec = promisify(execFile);
  const nativeFs = createRequire(join(resolve('.'), 'package.json'))(
    'original-fs',
  ) as typeof import('node:fs');
  let child: ChildProcess | undefined;
  let succeeded = false;
  try {
    let archive = process.env['DELA_QQ_FRAMEWORK_ARCHIVE'];
    if (!archive) {
      archive = join(profile, 'framework.zip');
      const response = await fetch(
        'https://github.com/NapNeko/NapCatQQ/releases/download/v4.18.42/NapCat.Framework.zip',
      );
      if (!response.ok) throw new Error(`Framework download failed: ${response.status}`);
      await writeFile(archive, new Uint8Array(await response.arrayBuffer()));
    }
    const bytes = await readFile(archive);
    if (
      createHash('sha256').update(bytes).digest('hex') !==
      '118d66bb4849b7fcec05a4cafc9e33ed44f9236d56661f7097aba2ab3081df2e'
    )
      throw new Error('Unexpected Framework archive');
    await extract(archive, { dir: bridge });
    await exec('/bin/cp', ['-cR', '/Applications/QQ.app', client]);
    const packagePath = join(client, 'Contents/Resources/app/package.json');
    const info = JSON.parse(await readFile(packagePath, 'utf8'));
    await copyFile('out/main/qq-shared-loader.cjs', join(profile, 'loader.cjs'));
    await writeFile(
      join(profile, 'bootstrap.json'),
      JSON.stringify({ originalMain: info.main, bridge, workdir }),
    );
    await writeFile(
      packagePath,
      JSON.stringify({
        ...info,
        main: relative(dirname(packagePath), join(profile, 'loader.cjs')),
      }),
    );
    const server = createServer();
    await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
    const address = server.address();
    if (!address || typeof address === 'string') throw new Error('No port');
    const port = address.port;
    await new Promise<void>((resolve) => server.close(() => resolve()));
    await mkdir(join(workdir, 'config'), { recursive: true });
    const token = 'dela-isolated-probe';
    await writeFile(
      join(workdir, 'config/webui.json'),
      JSON.stringify({ host: '127.0.0.1', port, token, loginRate: 30 }),
    );
    await mkdir(join(profile, 'home'));
    await writeFile(
      join(profile, 'probe-loader.cjs'),
      `const {app}=require('electron');
      for(const name of ['home','appData','userData','documents']) app.setPath(name,${JSON.stringify(join(profile, 'home'))});
      require(${JSON.stringify(join(profile, 'loader.cjs'))});`,
    );
    await writeFile(
      packagePath,
      JSON.stringify({
        ...info,
        main: relative(dirname(packagePath), join(profile, 'probe-loader.cjs')),
      }),
    );
    for (const name of await readdir(join(client, 'Contents/Frameworks'))) {
      if (name.startsWith('QQ Helper') && name.endsWith('.app'))
        await exec('/usr/bin/codesign', [
          '--force',
          '--sign',
          '-',
          join(client, 'Contents/Frameworks', name),
        ]);
    }
    await exec('/usr/bin/codesign', ['--force', '--sign', '-', client]);
    const env: NodeJS.ProcessEnv = {
      ...process.env,
      HOME: join(profile, 'home'),
      CFFIXED_USER_HOME: join(profile, 'home'),
    };
    delete env['ELECTRON_RUN_AS_NODE'];
    const log = createWriteStream(join(profile, 'launcher.log'));
    child = spawn(
      join(client, 'Contents/MacOS/QQ'),
      [`--user-data-dir=${join(profile, 'chromium')}`],
      { env, stdio: ['ignore', 'pipe', 'pipe'] },
    );
    child.stdout?.pipe(log, { end: false });
    child.stderr?.pipe(log, { end: false });
    console.log(`Isolated Framework probe: ${profile}; pid=${child.pid}`);
    const until = Date.now() + 25000;
    while (Date.now() < until) {
      if (child.exitCode !== null || child.signalCode !== null)
        throw new Error(`QQ exited: ${child.exitCode ?? child.signalCode}`);
      try {
        const response = await fetch(`http://127.0.0.1:${port}/api/auth/login`, {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({
            hash: createHash('sha256').update(`${token}.napcat`).digest('hex'),
          }),
          signal: AbortSignal.timeout(2000),
        });
        const result = (await response.json()) as { code: number; data: { Credential: string } };
        if (result.code === 0 && result.data.Credential) {
          const status = await fetch(`http://127.0.0.1:${port}/api/QQLogin/CheckLoginStatus`, {
            method: 'POST',
            headers: { authorization: `Bearer ${result.data.Credential}` },
          });
          const login = (await status.json()) as { data: { isLogin: boolean } };
          if (login.data.isLogin) throw new Error('Probe must not use a real account');
          succeeded = true;
          if (Date.now() > until - 3000)
            console.log(
              'Native QQ and authenticated Framework WebUI remained logged out for 22 seconds.',
            );
          if (Date.now() > until - 3000) break;
        }
      } catch (error) {
        if (error instanceof Error && error.message.includes('real account')) throw error;
      }
      await new Promise((resolve) => setTimeout(resolve, 1000));
    }
    if (!succeeded) throw new Error('Framework WebUI did not start');
    if (process.env['DELA_QQ_PROBE_INSPECT'] === '1')
      await new Promise((resolve) => setTimeout(resolve, 45000));
  } catch (error) {
    console.error(error);
    const log = await readFile(join(profile, 'launcher.log'), 'utf8').catch(() => '');
    console.error(
      log
        .split('\n')
        .filter(
          (line) => /error|failed|exception/i.test(line) && !/token|password|qrcode/i.test(line),
        )
        .slice(-12)
        .join('\n'),
    );
    succeeded = false;
  } finally {
    child?.kill('SIGTERM');
    await new Promise((resolve) => setTimeout(resolve, 1500));
    await nativeFs.promises.rm(profile, {
      recursive: true,
      force: true,
      maxRetries: 5,
      retryDelay: 1000,
    });
    app.exit(succeeded ? 0 : 1);
  }
}
void probe().catch((error) => {
  console.error(error);
  app.exit(1);
});
