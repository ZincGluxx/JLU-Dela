import { DatabaseSync } from 'node:sqlite';
import { EventEmitter } from 'node:events';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import type { ChildProcess } from 'node:child_process';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('electron', () => ({
  net: { fetch: vi.fn() },
  BrowserWindow: { getAllWindows: () => [] },
  ipcMain: { handle: vi.fn() },
}));
vi.mock('../../database', () => ({ getDatabase: vi.fn() }));
vi.mock('../../ipc', () => ({ checkWorkspaceSender: vi.fn() }));
vi.mock('../runtime', () => ({
  prepareQqRuntime: vi.fn(),
  launchQqRuntime: vi.fn(),
  stopQqRuntime: vi.fn(),
}));
import { net } from 'electron';
import { getDatabase } from '../../database';
import { getTodoState, removeTodo, saveTodo } from '../../todo';
import { prepareQqRuntime, launchQqRuntime, stopQqRuntime } from '../runtime';
import { QqService } from '../service';

class Socket extends EventTarget {
  static instances: Socket[] = [];
  constructor() {
    super();
    Socket.instances.push(this);
  }
  close() {
    this.dispatchEvent(new Event('close'));
  }
}

let db: DatabaseSync;
let root: string;
let service: QqService;
let account: string;
let loggedIn: boolean;
let failSend: boolean;
const events = vi.fn();
const fixture = {
  message_id: '1',
  group_id: '100',
  user_id: '9',
  time: 1793671200,
  sender: { card: '老师' },
  message: [
    { type: 'text', data: { text: '周五交报告' } },
    { type: 'file', data: { file_id: 'f1', name: '报告.pdf' } },
  ],
};

beforeEach(async () => {
  vi.useFakeTimers();
  vi.clearAllMocks();
  vi.stubGlobal('WebSocket', Socket);
  Socket.instances = [];
  db = new DatabaseSync(':memory:');
  db.exec(`PRAGMA foreign_keys=ON;
    CREATE TABLE qq_groups (account_id TEXT, group_id TEXT, name TEXT, PRIMARY KEY(account_id,group_id));
    CREATE TABLE qq_messages (account_id TEXT, group_id TEXT, id TEXT, sent_at TEXT, data TEXT, PRIMARY KEY(account_id,group_id,id));
    CREATE TABLE todo_items (id TEXT PRIMARY KEY, owner TEXT, data TEXT, read_at TEXT, notice_at TEXT);
    CREATE TABLE qq_message_todos (account_id TEXT, group_id TEXT, message_id TEXT, todo_id TEXT REFERENCES todo_items(id) ON DELETE CASCADE, PRIMARY KEY(account_id,group_id,message_id));`);
  vi.mocked(getDatabase).mockReturnValue({
    prepare: (sql: string) => db.prepare(sql),
    transaction:
      <T>(fn: () => T) =>
      () => {
        db.exec('BEGIN');
        try {
          const result = fn();
          db.exec('COMMIT');
          return result;
        } catch (error) {
          db.exec('ROLLBACK');
          throw error;
        }
      },
  } as unknown as ReturnType<typeof getDatabase>);
  root = mkdtempSync(join(tmpdir(), 'dela-qq-test-'));
  mkdirSync(join(root, 'config'));
  writeFileSync(join(root, 'config/webui.json'), JSON.stringify({ token: 'fixture-token' }));
  account = '7';
  loggedIn = true;
  failSend = false;
  vi.mocked(prepareQqRuntime).mockResolvedValue({
    executable: '/fixture/QQ',
    sourceVersion: 'fixture',
  });
  vi.mocked(launchQqRuntime).mockImplementation(async () => ({
    child: Object.assign(new EventEmitter(), { pid: 123, exitCode: null }) as ChildProcess,
    apiPort: 3000,
    wsPort: 3001,
    webPort: 6099,
    token: 'fixture-token',
    workdir: root,
  }));
  vi.mocked(net.fetch).mockImplementation(async (input, options) => {
    const path = new URL(String(input)).pathname;
    let data: unknown;
    if (path === '/api/auth/login') data = { Credential: 'fixture-credential' };
    else if (path === '/api/QQLogin/CheckLoginStatus')
      data = { isLogin: loggedIn, qrcodeurl: 'https://qq.com/fixture-qr', loginError: null };
    else if (path === '/get_login_info') data = { user_id: account, nickname: `用户${account}` };
    else if (path === '/get_group_list')
      data = [
        { group_id: 100, group_name: '课程群' },
        { group_id: 200, group_name: '未订阅群' },
      ];
    else if (path === '/get_group_msg_history') data = { messages: [fixture, fixture] };
    else if (path === '/send_group_msg') {
      if (failSend) throw new Error('timeout');
      data = { message_id: 'sent-1' };
    } else if (path === '/get_group_file_url') {
      expect(JSON.parse(String(options?.body))).toEqual({ group_id: '100', file_id: 'f1' });
      data = { url: 'https://example.com/report.pdf' };
    } else throw new Error(`Unexpected endpoint ${path}`);
    return Response.json(
      path.startsWith('/api/') ? { code: 0, data } : { status: 'ok', retcode: 0, data },
    );
  });
  service = new QqService(() => {}, events);
});

async function connect() {
  await service.start();
  await vi.waitFor(() => expect(service.getState().phase).toBe(loggedIn ? 'online' : 'login'));
  expect(service.getState().phase).toBe('online');
  service.selectGroups(['100']);
}

afterEach(() => {
  service.stop();
  db.close();
  rmSync(root, { recursive: true, force: true });
  vi.useRealTimers();
  vi.unstubAllGlobals();
});

describe('QQ 群聊服务', () => {
  it('仅保存订阅群的实时消息，并按消息 ID 合并历史与重复推送', async () => {
    await connect();
    expect(await service.refreshMessages('100')).toHaveLength(1);
    const socket = Socket.instances[0]!;
    socket.dispatchEvent(
      new MessageEvent('message', {
        data: JSON.stringify({ ...fixture, post_type: 'message', message_type: 'group' }),
      }),
    );
    socket.dispatchEvent(
      new MessageEvent('message', {
        data: JSON.stringify({
          ...fixture,
          message_id: 'other',
          group_id: '200',
          post_type: 'message',
          message_type: 'group',
        }),
      }),
    );
    expect(service.messages('100')).toHaveLength(1);
    expect(db.prepare('SELECT COUNT(*) AS count FROM qq_messages').get()).toMatchObject({
      count: 1,
    });
    expect(() => service.messages('200')).toThrow('请先选择');
  });

  it('引用回复使用消息段，正文中的 CQ 字符串保持普通文本', async () => {
    await connect();
    await service.refreshMessages('100');
    await service.send({ groupId: '100', text: '[CQ:at,qq=all] 已收到', replyTo: '1' });
    const call = vi
      .mocked(net.fetch)
      .mock.calls.find(([url]) => String(url).endsWith('/send_group_msg'))!;
    expect(JSON.parse(String(call[1]?.body))).toEqual({
      group_id: '100',
      message: [
        { type: 'reply', data: { id: '1' } },
        { type: 'text', data: { text: '[CQ:at,qq=all] 已收到' } },
      ],
    });
    expect(service.messages('100').find((message) => message.id === 'sent-1')?.own).toBe(true);
  });

  it('发送超时不自动重试，不插入假成功消息', async () => {
    await connect();
    failSend = true;
    await expect(service.send({ groupId: '100', text: '你好' })).rejects.toThrow('发送结果未确认');
    expect(
      vi.mocked(net.fetch).mock.calls.filter(([url]) => String(url).endsWith('/send_group_msg')),
    ).toHaveLength(1);
    expect(service.messages('100')).toEqual([]);
  });

  it('重复转待办返回同一条，保留用户编辑；删除后可以重新创建', async () => {
    await connect();
    await service.refreshMessages('100');
    const input = {
      groupId: '100',
      messageId: '1',
      title: '交报告',
      dueAt: '2026-11-06T10:00:00.000Z',
    };
    const id = service.createTodo(input);
    expect(getTodoState().items[0]).toMatchObject({ id, title: '交报告', calendar: true });
    expect(getTodoState().items[0]!.notes).toContain('课程群（100）');
    saveTodo({ id, title: '我编辑的标题', completed: true });
    expect(service.createTodo(input)).toBe(id);
    expect(getTodoState().items[0]).toMatchObject({ title: '我编辑的标题', status: 'completed' });
    expect(getTodoState().items).toHaveLength(1);
    removeTodo(id);
    expect(service.createTodo(input)).not.toBe(id);
  });

  it('切换账号不会继承上一个账号的订阅或缓存', async () => {
    await connect();
    await service.refreshMessages('100');
    service.stop();
    account = '8';
    await service.start();
    await vi.waitFor(() => expect(service.getState().phase).toBe(loggedIn ? 'online' : 'login'));
    expect(service.getState().groups.every((group) => !group.selected)).toBe(true);
    service.selectGroups(['100']);
    expect(service.messages('100')).toEqual([]);
    service.stop();
    account = '7';
    await service.start();
    await vi.waitFor(() => expect(service.getState().phase).toBe(loggedIn ? 'online' : 'login'));
    expect(service.messages('100')).toHaveLength(1);
  });

  it('只为当前群消息中的文件申请下载地址', async () => {
    await connect();
    await service.refreshMessages('100');
    await expect(service.file('100', '1', 'not-a-file')).rejects.toThrow('文件不在');
    expect(await service.file('100', '1', 'f1')).toEqual({
      name: '报告.pdf',
      url: 'https://example.com/report.pdf',
    });
  });

  it('登录二维码保留实际 URL；准备过程中断开不会继续启动组件', async () => {
    loggedIn = false;
    await service.start();
    await vi.waitFor(() => expect(service.getState().phase).toBe(loggedIn ? 'online' : 'login'));
    expect(service.getState()).toMatchObject({
      phase: 'login',
      qrCode: 'https://qq.com/fixture-qr',
      account: null,
    });
    service.stop();
    let finish!: (value: { executable: string; sourceVersion: string }) => void;
    vi.mocked(prepareQqRuntime).mockReturnValueOnce(
      new Promise((resolve) => {
        finish = resolve;
      }),
    );
    const starting = service.start();
    service.stop();
    const launches = vi.mocked(launchQqRuntime).mock.calls.length;
    finish({ executable: '/fixture/QQ', sourceVersion: 'fixture' });
    await starting;
    expect(launchQqRuntime).toHaveBeenCalledTimes(launches);
    expect(service.getState().phase).toBe('stopped');
    expect(stopQqRuntime).toHaveBeenCalled();
  });
});
