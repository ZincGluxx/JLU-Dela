import { app, dialog, net } from 'electron';
import { spawn, execFile, type ChildProcess } from 'node:child_process';
import { createHash, randomBytes } from 'node:crypto';
import { constants, createWriteStream, existsSync } from 'node:fs';
import { copyFile, mkdir, readFile, readdir, rename, rm, writeFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { createServer } from 'node:net';
import { dirname, join, relative } from 'node:path';
import { promisify } from 'node:util';
import extract from 'extract-zip';
import { z } from 'zod';
import runtimeLicenses from './runtime-licenses.txt?raw';

export const qqRuntimeVersion = '4.18.42';
export const qqRuntimeSha256 = '02e5ff0f79916c1e04c81c1b4590056406fb4293f1f1300c955e71fd08b2829d';
const exec = promisify(execFile);
const nativeFs = createRequire(join(app.getAppPath(), 'package.json'))(
  'original-fs',
) as typeof import('node:fs');
const preparedSchema = z.object({ executable: z.string(), sourceVersion: z.string() });
export type PreparedQqRuntime = z.infer<typeof preparedSchema>;

export interface ManagedQqRuntime {
  child: ChildProcess;
  apiPort: number;
  wsPort: number;
  webPort: number;
  token: string;
  workdir: string;
}

function runtimeRoot(): string {
  return join(app.getPath('userData'), 'qq');
}

export function verifyQqRuntime(bytes: Uint8Array): void {
  if (createHash('sha256').update(bytes).digest('hex') !== qqRuntimeSha256)
    throw new Error('QQ 组件校验失败，请重试下载');
}

export async function prepareQqRuntime(
  signal: AbortSignal,
  progress: (message: string) => void,
): Promise<PreparedQqRuntime> {
  if (!['darwin', 'win32'].includes(process.platform))
    throw new Error('QQ 接入目前仅支持 macOS 和 Windows');
  const root = runtimeRoot();
  const bridge = join(root, `napcat-${qqRuntimeVersion}`);
  const marker = join(root, `ready-${qqRuntimeVersion}.json`);
  if (existsSync(marker) && existsSync(join(bridge, 'napcat.mjs'))) {
    const prepared = preparedSchema.parse(JSON.parse(await readFile(marker, 'utf8')));
    if (existsSync(prepared.executable)) return prepared;
  }
  const candidates =
    process.platform === 'darwin'
      ? ['/Applications/QQ.app', join(app.getPath('home'), 'Applications/QQ.app')]
      : [
          join(process.env['ProgramFiles'] ?? 'C:\\Program Files', 'Tencent/QQNT/QQ.exe'),
          join(
            process.env['ProgramFiles(x86)'] ?? 'C:\\Program Files (x86)',
            'Tencent/QQNT/QQ.exe',
          ),
          join(process.env['LOCALAPPDATA'] ?? app.getPath('home'), 'Programs/Tencent/QQNT/QQ.exe'),
        ];
  if (process.platform === 'win32') {
    try {
      const { stdout } = await exec('reg.exe', [
        'query',
        'HKLM\\SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\QQ',
        '/v',
        'UninstallString',
      ]);
      const uninstall = stdout.match(/REG_SZ\s+"?([^"\r\n]+?\.exe)/i)?.[1];
      if (uninstall) candidates.unshift(join(dirname(uninstall), 'QQ.exe'));
    } catch {
      /* 非系统安装的位置通过文件选择器定位。 */
    }
  }
  let source = candidates.find((candidate) => existsSync(candidate));
  if (!source) {
    const choice = await dialog.showOpenDialog({
      title: '选择本机 QQ',
      message: 'Dela 将复制 QQ 的运行文件到自己的数据目录，不会修改原 QQ。',
      properties: ['openFile'],
      filters: process.platform === 'win32' ? [{ name: 'QQ', extensions: ['exe'] }] : undefined,
    });
    source = choice.filePaths[0];
    if (!source || choice.canceled) throw new Error('未找到本机 QQ，请选择已安装的 QQ 后重试');
  }
  signal.throwIfAborted();
  await mkdir(root, { recursive: true, mode: 0o700 });
  if (!existsSync(join(bridge, 'napcat.mjs'))) {
    progress('正在下载 QQ 组件（约 35 MB）…');
    const response = await net.fetch(
      `https://github.com/NapNeko/NapCatQQ/releases/download/v${qqRuntimeVersion}/NapCat.Shell.zip`,
      { signal },
    );
    if (!response.ok) throw new Error(`QQ 组件下载失败（${response.status}），请检查网络后重试`);
    const bytes = new Uint8Array(await response.arrayBuffer());
    verifyQqRuntime(bytes);
    const archive = join(root, 'napcat.zip');
    const staging = join(root, 'napcat-extract');
    await writeFile(archive, bytes);
    await rm(staging, { recursive: true, force: true });
    try {
      await extract(archive, { dir: staging });
      signal.throwIfAborted();
      await rm(bridge, { recursive: true, force: true });
      await rename(staging, bridge);
      await writeFile(join(bridge, 'DELA-LICENSES.txt'), runtimeLicenses);
    } finally {
      await rm(archive, { force: true });
      await rm(staging, { recursive: true, force: true });
    }
  }
  progress('正在准备独立的 QQ 运行文件…');
  const copyRoot = join(root, 'client');
  await rm(copyRoot, { recursive: true, force: true });
  await mkdir(copyRoot, { recursive: true });
  let executable: string;
  let sourceVersion: string;
  if (process.platform === 'darwin') {
    const appDir = join(copyRoot, 'QQ.app');
    await nativeFs.promises.cp(source, appDir, {
      recursive: true,
      verbatimSymlinks: true,
      mode: constants.COPYFILE_FICLONE,
    });
    const packagePath = join(appDir, 'Contents/Resources/app/package.json');
    const info = z
      .object({ version: z.string(), buildVersion: z.string() })
      .passthrough()
      .parse(JSON.parse(await readFile(packagePath, 'utf8')));
    sourceVersion = info.version;
    const loader = join(root, 'load-dela-qq.cjs');
    await copyFile(join(bridge, 'loadNapCat.js'), loader);
    await writeFile(
      packagePath,
      JSON.stringify({
        ...info,
        main: relative(dirname(packagePath), loader),
      }),
    );
    executable = join(appDir, 'Contents/MacOS/QQ');
    // 只修改 Dela 的副本；原 QQ 及其登录目录不参与运行。
    const frameworks = join(appDir, 'Contents/Frameworks');
    for (const name of await readdir(frameworks)) {
      if (name.startsWith('QQ Helper') && name.endsWith('.app'))
        await exec('/usr/bin/codesign', ['--force', '--sign', '-', join(frameworks, name)], {
          signal,
        });
    }
    await exec('/usr/bin/codesign', ['--force', '--sign', '-', appDir], { signal });
  } else {
    await nativeFs.promises.cp(dirname(source), copyRoot, {
      recursive: true,
      verbatimSymlinks: true,
      mode: constants.COPYFILE_FICLONE,
    });
    const config = z
      .object({ curVersion: z.string() })
      .parse(JSON.parse(await readFile(join(copyRoot, 'versions/config.json'), 'utf8')));
    sourceVersion = config.curVersion;
    executable = join(copyRoot, 'QQ.exe');
  }
  signal.throwIfAborted();
  const prepared = { executable, sourceVersion };
  await writeFile(marker, JSON.stringify(prepared));
  return prepared;
}

export async function launchQqRuntime(prepared: PreparedQqRuntime): Promise<ManagedQqRuntime> {
  const root = runtimeRoot();
  const workdir = join(root, 'bridge-data');
  const bridge = join(root, `napcat-${qqRuntimeVersion}`);
  const ports: number[] = [];
  const reservations = [];
  try {
    for (let index = 0; index < 3; index++) {
      const server = createServer();
      reservations.push(server);
      await new Promise<void>((resolve, reject) => {
        server.once('error', reject);
        server.listen(0, '127.0.0.1', () => resolve());
      });
      const address = server.address();
      if (!address || typeof address === 'string') throw new Error('无法分配 QQ 连接端口');
      ports.push(address.port);
    }
  } finally {
    await Promise.all(
      reservations.map((server) => new Promise<void>((resolve) => server.close(() => resolve()))),
    );
  }
  const [apiPort, wsPort, webPort] = ports as [number, number, number];
  const token = randomBytes(32).toString('hex');
  await mkdir(join(workdir, 'config'), { recursive: true, mode: 0o700 });
  await writeFile(
    join(workdir, 'config/webui.json'),
    JSON.stringify({
      host: '127.0.0.1',
      port: webPort,
      token,
      loginRate: 30,
    }),
    { mode: 0o600 },
  );
  await writeFile(
    join(workdir, 'config/onebot11.json'),
    JSON.stringify({
      network: {
        httpServers: [
          {
            name: 'dela-http',
            enable: true,
            host: '127.0.0.1',
            port: apiPort,
            token,
            enableCors: false,
          },
        ],
        websocketServers: [
          {
            name: 'dela-ws',
            enable: true,
            host: '127.0.0.1',
            port: wsPort,
            token,
            reportSelfMessage: true,
            messagePostFormat: 'array',
          },
        ],
        httpClients: [],
        websocketClients: [],
      },
      musicSignUrl: '',
      enableLocalFile2Url: false,
      parseMultMsg: false,
    }),
    { mode: 0o600 },
  );
  const env: NodeJS.ProcessEnv = {
    ...process.env,
    NAPCAT_WORKDIR: workdir,
    NAPCAT_QQ_DATA_DIR: join(root, 'profile'),
    NAPCAT_DISABLE_MULTI_PROCESS: '1',
    NAPCAT_DISABLE_PIPE: '1',
    NAPCAT_WEBUI_SECRET_KEY: token,
    NAPCAT_MAIN_PATH: join(bridge, 'napcat.mjs'),
  };
  delete env['ELECTRON_RUN_AS_NODE'];
  let command = prepared.executable;
  let args = ['--no-sandbox', `--user-data-dir=${join(root, 'chromium')}`];
  if (process.platform === 'darwin') {
    const macHome = join(root, 'mac-home');
    await mkdir(macHome, { recursive: true, mode: 0o700 });
    env['CFFIXED_USER_HOME'] = macHome;
    const appPath = join(dirname(prepared.executable), '../Resources/app');
    env['NAPCAT_QQ_PACKAGE_INFO_PATH'] = join(appPath, 'package.json');
    const versionPath = join(root, 'version.json');
    await writeFile(
      versionPath,
      JSON.stringify({ curVersion: prepared.sourceVersion, baseVersion: prepared.sourceVersion }),
    );
    env['NAPCAT_QQ_VERSION_CONFIG_PATH'] = versionPath;
  } else {
    command = join(bridge, 'NapCatWinBootMain.exe');
    args = [
      prepared.executable,
      join(bridge, 'NapCatWinBootHook.dll'),
      `--user-data-dir=${join(root, 'chromium')}`,
    ];
    env['NAPCAT_PATCH_PACKAGE'] = join(bridge, 'qqnt.json');
    env['NAPCAT_LOAD_PATH'] = join(bridge, 'loadNapCat.js');
    env['NAPCAT_MAIN_PATH'] = join(bridge, 'napcat.mjs');
  }
  const log = createWriteStream(join(root, 'launcher.log'), { mode: 0o600 });
  const child = spawn(command, args, {
    cwd: bridge,
    env,
    windowsHide: true,
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  log.on('error', (error) => {
    console.error('QQ 运行日志写入失败', error);
    child.kill('SIGTERM');
  });
  child.stdout?.pipe(log, { end: false });
  child.stderr?.pipe(log, { end: false });
  child.once('close', () => log.end());
  return { child, apiPort, wsPort, webPort, token, workdir };
}

export function stopQqRuntime(runtime: ManagedQqRuntime): void {
  if (runtime.child.exitCode !== null || !runtime.child.pid) return;
  if (process.platform === 'win32') {
    execFile('taskkill.exe', ['/pid', String(runtime.child.pid), '/t', '/f'], () => {});
  } else runtime.child.kill('SIGTERM');
}
