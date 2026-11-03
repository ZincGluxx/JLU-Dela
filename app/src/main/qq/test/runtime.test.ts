import { EventEmitter } from 'node:events';
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readlinkSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

const state = vi.hoisted(() => ({ root: '' }));
vi.mock('electron', () => ({
  app: { getPath: () => state.root, getAppPath: () => state.root },
  net: { fetch: vi.fn() },
  dialog: { showOpenDialog: vi.fn() },
}));
vi.mock('node:fs', async (original) => {
  const fs = await original<typeof import('node:fs')>();
  return {
    ...fs,
    existsSync: (path: string) => (path === '/Applications/QQ.app' ? false : fs.existsSync(path)),
  };
});
vi.mock('node:module', async (original) => {
  const fs = await vi.importActual<typeof import('node:fs')>('node:fs');
  return { ...(await original<typeof import('node:module')>()), createRequire: () => () => fs };
});
vi.mock('node:child_process', () => ({
  execFile: vi.fn((...args: unknown[]) => {
    const callback = args.at(-1) as (error: null, stdout: string, stderr: string) => void;
    callback(null, '', '');
  }),
  spawn: vi.fn(() => Object.assign(new EventEmitter(), { exitCode: null, pid: undefined })),
}));
import { execFile, spawn } from 'node:child_process';
import { net } from 'electron';
import { launchQqRuntime, prepareQqRuntime, qqRuntimeVersion, verifyQqRuntime } from '../runtime';

beforeEach(() => {
  vi.clearAllMocks();
  state.root = mkdtempSync(join(tmpdir(), 'dela-qq-runtime-test-'));
});
afterEach(() => rmSync(state.root, { recursive: true, force: true }));

describe.skipIf(process.platform !== 'darwin')('QQ 运行目录', () => {
  it('仅修改运行副本，保留框架内的相对链接，并单独重签 helper', async () => {
    const source = join(state.root, 'Applications/QQ.app');
    const resources = join(source, 'Contents/Resources/app');
    const framework = join(source, 'Contents/Frameworks/QQNT.framework');
    mkdirSync(resources, { recursive: true });
    mkdirSync(join(source, 'Contents/MacOS'), { recursive: true });
    mkdirSync(join(source, 'Contents/Frameworks/QQ Helper.app'), { recursive: true });
    mkdirSync(join(framework, 'Versions/A'), { recursive: true });
    writeFileSync(join(framework, 'Versions/A/QQNT'), 'framework');
    symlinkSync('A', join(framework, 'Versions/Current'));
    symlinkSync('Versions/Current/QQNT', join(framework, 'QQNT'));
    const original = JSON.stringify({
      version: 'fixture-1',
      buildVersion: '1',
      main: './application.asar/entry.js',
    });
    writeFileSync(join(resources, 'package.json'), original);
    writeFileSync(join(source, 'Contents/MacOS/QQ'), 'fixture');
    const bridge = join(state.root, `qq/napcat-${qqRuntimeVersion}`);
    mkdirSync(bridge, { recursive: true });
    writeFileSync(join(bridge, 'napcat.mjs'), Buffer.alloc(0));
    writeFileSync(join(bridge, 'loadNapCat.js'), 'fixture loader bytes');
    const prepared = await prepareQqRuntime(new AbortController().signal, () => {});
    const copied = join(state.root, 'qq/client/QQ.app');
    expect(prepared.executable).toBe(join(copied, 'Contents/MacOS/QQ'));
    expect(readFileSync(join(resources, 'package.json'), 'utf8')).toBe(original);
    expect(readlinkSync(join(copied, 'Contents/Frameworks/QQNT.framework/QQNT'))).toBe(
      'Versions/Current/QQNT',
    );
    expect(readFileSync(join(state.root, 'qq/load-dela-qq.cjs'), 'utf8')).toBe(
      'fixture loader bytes',
    );
    expect(
      JSON.parse(readFileSync(join(copied, 'Contents/Resources/app/package.json'), 'utf8')).main,
    ).toContain('load-dela-qq.cjs');
    expect(vi.mocked(execFile).mock.calls.map((call) => call[1])).toEqual([
      ['--force', '--sign', '-', join(copied, 'Contents/Frameworks/QQ Helper.app')],
      ['--force', '--sign', '-', copied],
    ]);
    expect(net.fetch).not.toHaveBeenCalled();
  });

  it('为桥接服务配置本机端口和随机令牌，将 QQ 数据与 Chromium 目录隔离', async () => {
    const runtime = await launchQqRuntime({
      executable: '/fixture/QQ.app/Contents/MacOS/QQ',
      sourceVersion: 'fixture',
    });
    const config = JSON.parse(readFileSync(join(runtime.workdir, 'config/onebot11.json'), 'utf8'));
    expect(config.network.httpServers[0]).toMatchObject({
      host: '127.0.0.1',
      token: runtime.token,
      enableCors: false,
    });
    expect(config.network.websocketServers[0]).toMatchObject({
      host: '127.0.0.1',
      token: runtime.token,
    });
    expect(new Set([runtime.apiPort, runtime.wsPort, runtime.webPort]).size).toBe(3);
    expect(runtime.token).toHaveLength(64);
    const options = vi.mocked(spawn).mock.calls[0]![2]!;
    expect(options.env).toMatchObject({
      NAPCAT_QQ_DATA_DIR: join(state.root, 'qq/profile'),
      CFFIXED_USER_HOME: join(state.root, 'qq/mac-home'),
      NAPCAT_DISABLE_PIPE: '1',
    });
    expect(vi.mocked(spawn).mock.calls[0]![1]).toContain(
      `--user-data-dir=${join(state.root, 'qq/chromium')}`,
    );
    runtime.child.emit('close', 0);
    await new Promise((resolve) => setTimeout(resolve, 20));
  });
});

it('拒绝被替换或损坏的运行组件', () => {
  expect(() => verifyQqRuntime(new TextEncoder().encode('corrupt archive'))).toThrow('校验失败');
});
