import { net } from 'electron';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { z } from 'zod';
import type { QqMessage, QqSendInput, QqState, QqTodoInput } from '../../shared/qq';
import { getDatabase } from '../database';
import { getTodoState, saveTodo } from '../todo';
import { parseQqMessage, qqId } from './protocol';
import { readQqImage } from './media';
import { launchQqRuntime, prepareQqRuntime, type ManagedQqRuntime } from './runtime';

const onebotResponse = z.object({
  status: z.string(),
  retcode: z.number(),
  data: z.unknown(),
  message: z.string().optional(),
  wording: z.string().optional(),
});
const webResponse = z.object({
  code: z.number(),
  message: z.string().optional(),
  data: z.unknown().optional(),
});
const loginSchema = z.object({
  isLogin: z.boolean(),
  isOffline: z.boolean().optional(),
  qrcodeurl: z.string().optional(),
  loginError: z.string().nullable().optional(),
  loginPhase: z.string().optional(),
});

export class QqService {
  private state: QqState = {
    phase: 'idle',
    progress: '',
    qrCode: null,
    account: null,
    groups: [],
    error: null,
  };
  private controller: AbortController | null = null;
  private runtime: ManagedQqRuntime | null = null;
  private socket: WebSocket | null = null;
  private pollTimer: ReturnType<typeof setTimeout> | undefined;
  private reconnectTimer: ReturnType<typeof setTimeout> | undefined;
  private credential = '';
  private credentialAt = 0;
  private startedAt = 0;
  private startPending = false;

  constructor(
    private readonly publish: (state: QqState) => void,
    private readonly messagesChanged: (groupId: string) => void,
  ) {}

  getState(): QqState {
    return this.state;
  }

  private update(patch: Partial<QqState>): QqState {
    this.state = { ...this.state, ...patch };
    this.publish(this.state);
    return this.state;
  }

  async start(): Promise<QqState> {
    if (this.controller) return this.state;
    if (this.startPending) throw new Error('正在结束上次准备，请稍后连接 QQ');
    this.startPending = true;
    const controller = new AbortController();
    this.controller = controller;
    this.update({
      phase: 'preparing',
      progress: '正在查找 QQ…',
      account: null,
      groups: [],
      qrCode: null,
      error: null,
    });
    try {
      const prepared = await prepareQqRuntime(controller.signal, (progress) => {
        if (!controller.signal.aborted) this.update({ progress });
      });
      controller.signal.throwIfAborted();
      if (!prepared.installed) {
        this.controller = null;
        return this.update({ phase: 'setup', progress: 'QQ 共享组件已准备好' });
      }
      this.update({ phase: 'starting', progress: '正在启动 QQ…' });
      const runtime = await launchQqRuntime(prepared);
      if (controller.signal.aborted) {
        return this.state;
      }
      this.runtime = runtime;
      this.startedAt = Date.now();
      void this.poll(controller);
    } catch (error) {
      if (!controller.signal.aborted) {
        this.stop();
        this.update({
          phase: 'error',
          error: error instanceof Error ? error.message : String(error),
          progress: '',
        });
      }
    } finally {
      this.startPending = false;
    }
    return this.state;
  }

  stop(): QqState {
    this.controller?.abort();
    this.controller = null;
    clearTimeout(this.pollTimer);
    clearTimeout(this.reconnectTimer);
    this.socket?.close();
    this.socket = null;
    this.runtime = null;
    this.credential = '';
    this.credentialAt = 0;
    return this.update({ phase: 'stopped', progress: '', qrCode: null, error: null });
  }

  private async web(path: string, body: object = {}): Promise<unknown> {
    const runtime = this.runtime;
    const controller = this.controller;
    if (!runtime || !controller) throw new Error('QQ 尚未启动');
    const request = async (route: string, input: object, credential = '') => {
      const response = await net.fetch(`http://127.0.0.1:${runtime.webPort}/api/${route}`, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          ...(credential ? { authorization: `Bearer ${credential}` } : {}),
        },
        body: JSON.stringify(input),
        signal: AbortSignal.any([controller.signal, AbortSignal.timeout(10_000)]),
      });
      if (!response.ok) throw new Error(`QQ 登录服务暂不可用（${response.status}）`);
      const parsed = webResponse.parse(await response.json());
      if (parsed.code !== 0) throw new Error(parsed.message || 'QQ 登录请求失败');
      return parsed.data;
    };
    if (!this.credential || Date.now() - this.credentialAt > 50 * 60_000) {
      const config = z
        .object({ token: z.string() })
        .parse(JSON.parse(await readFile(join(runtime.workdir, 'config/webui.json'), 'utf8')));
      const hash = createHash('sha256').update(`${config.token}.napcat`).digest('hex');
      const auth = z
        .object({ Credential: z.string() })
        .parse(await request('auth/login', { hash }));
      controller.signal.throwIfAborted();
      this.credential = auth.Credential;
      this.credentialAt = Date.now();
    }
    return request(path, body, this.credential);
  }

  private async poll(controller: AbortController): Promise<void> {
    try {
      const login = loginSchema.parse(await this.web('QQLogin/CheckLoginStatus'));
      controller.signal.throwIfAborted();
      if (login.isLogin) {
        if (this.state.phase !== 'online') {
          const account = z
            .object({ user_id: qqId, nickname: z.string() })
            .parse(await this.call('get_login_info'));
          controller.signal.throwIfAborted();
          this.update({
            phase: 'online',
            progress: '',
            qrCode: null,
            account: { id: account.user_id, name: account.nickname },
            groups: this.state.account?.id === account.user_id ? this.state.groups : [],
            error: null,
          });
          await this.refreshGroups();
          controller.signal.throwIfAborted();
          this.connectEvents(controller);
        }
      } else {
        if (this.state.account) {
          this.update({
            phase: 'reconnecting',
            progress: 'QQ 状态暂时不可用，正在等待原生会话恢复。聊天记录已保留。',
            qrCode: null,
            error: login.loginError?.includes('SelfOffline') ? null : login.loginError || null,
          });
        } else {
          const qrCode = login.qrcodeurl || null;
          const confirming = ['qrcode_scanned', 'initializing'].includes(login.loginPhase ?? '');
          this.update({
            phase: 'login',
            progress: confirming
              ? '已扫码，等待手机确认并连接 QQ…'
              : login.isOffline
                ? 'QQ 已离线，请重新扫码登录'
                : qrCode
                  ? '用手机 QQ 扫码，并在手机上确认登录'
                  : '请在 QQ 原生窗口完成登录',
            qrCode,
            account: null,
            groups: [],
            error: login.loginError || null,
          });
        }
      }
    } catch (error) {
      if (controller.signal.aborted) return;
      this.credential = '';
      if (this.state.account) {
        this.update({
          phase: 'reconnecting',
          progress: '暂时无法连接 QQ 桥接服务，正在重试。聊天记录已保留。',
          error: null,
        });
      } else if (Date.now() - this.startedAt > 90_000) {
        this.update({
          phase: 'error',
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }
    if (!controller.signal.aborted)
      this.pollTimer = setTimeout(
        () => void this.poll(controller),
        this.state.phase === 'online' ? 10_000 : this.state.phase === 'reconnecting' ? 5000 : 2000,
      );
  }

  async refreshLogin(): Promise<QqState> {
    await this.web('QQLogin/RefreshQRcode');
    this.update({ qrCode: null, progress: '正在刷新二维码…' });
    return this.state;
  }

  private connectEvents(controller: AbortController): void {
    const runtime = this.runtime;
    if (!runtime || controller.signal.aborted || this.socket) return;
    const socket = new WebSocket(`ws://127.0.0.1:${runtime.wsPort}/?access_token=${runtime.token}`);
    this.socket = socket;
    socket.addEventListener('open', () => {
      if (!controller.signal.aborted) this.update({ error: null });
    });
    socket.addEventListener('message', (event) => {
      if (controller.signal.aborted || !['online', 'reconnecting'].includes(this.state.phase))
        return;
      try {
        const envelope = z
          .object({
            post_type: z.string(),
            message_type: z.string().optional(),
            group_id: qqId.optional(),
            self_id: qqId.optional(),
          })
          .parse(JSON.parse(String(event.data)));
        if (
          !['message', 'message_sent'].includes(envelope.post_type) ||
          envelope.message_type !== 'group'
        )
          return;
        if (envelope.self_id && envelope.self_id !== this.accountId()) return;
        if (!this.state.groups.some((group) => group.id === envelope.group_id && group.selected))
          return;
        const message = parseQqMessage(JSON.parse(String(event.data)), this.accountId());
        this.storeMessages(message.groupId, [message]);
      } catch {
        this.update({ error: '有一条消息未能读取，请刷新群消息重试' });
      }
    });
    socket.addEventListener('error', () => {
      if (!controller.signal.aborted)
        this.update({ error: '实时消息连接中断，正在重连；可手动刷新群消息' });
    });
    socket.addEventListener('close', () => {
      if (this.socket === socket) this.socket = null;
      if (!controller.signal.aborted && ['online', 'reconnecting'].includes(this.state.phase))
        this.reconnectTimer = setTimeout(() => this.connectEvents(controller), 2000);
    });
  }

  private async call(action: string, body: object = {}): Promise<unknown> {
    const runtime = this.runtime;
    const controller = this.controller;
    if (!runtime || !controller) throw new Error('QQ 尚未连接');
    let response: Response;
    try {
      response = await net.fetch(`http://127.0.0.1:${runtime.apiPort}/${action}`, {
        method: 'POST',
        headers: { 'content-type': 'application/json', authorization: `Bearer ${runtime.token}` },
        body: JSON.stringify(body),
        signal: AbortSignal.any([controller.signal, AbortSignal.timeout(20_000)]),
      });
    } catch {
      throw new Error(
        action === 'send_group_msg'
          ? '发送结果未确认，请先刷新群消息再决定是否重发'
          : 'QQ 连接失败，请检查登录状态后重试',
      );
    }
    if (!response.ok)
      throw new Error(
        action === 'send_group_msg' && response.status >= 500
          ? '发送结果未确认，请先刷新群消息再决定是否重发'
          : `QQ 请求失败（${response.status}）`,
      );
    const result = onebotResponse.parse(await response.json());
    if (result.status !== 'ok' || result.retcode !== 0)
      throw new Error(result.wording || result.message || 'QQ 未能完成操作');
    controller.signal.throwIfAborted();
    return result.data;
  }

  private accountId(): string {
    if (!this.state.account) throw new Error('请先登录 QQ');
    return this.state.account.id;
  }

  private group(groupId: string, online = false) {
    this.accountId();
    if (online && this.state.phase !== 'online') throw new Error('QQ 已断开，请重新连接');
    const group = this.state.groups.find((item) => item.id === groupId && item.selected);
    if (!group) throw new Error('请先选择接入这个群');
    return group;
  }

  async refreshGroups(): Promise<QqState> {
    const accountId = this.accountId();
    const rows = z
      .array(z.object({ group_id: qqId, group_name: z.string() }))
      .parse(await this.call('get_group_list'));
    const selected = new Set(
      (
        getDatabase()
          .prepare('SELECT group_id FROM qq_groups WHERE account_id=?')
          .all(accountId) as { group_id: string }[]
      ).map((row) => row.group_id),
    );
    return this.update({
      groups: rows.map((row) => ({
        id: row.group_id,
        name: row.group_name,
        selected: selected.has(row.group_id),
      })),
    });
  }

  selectGroups(ids: string[]): QqState {
    const accountId = this.accountId();
    if (ids.some((id) => !this.state.groups.some((group) => group.id === id)))
      throw new Error('群列表已变化，请刷新后重新选择');
    const selected = new Set(ids);
    const db = getDatabase();
    db.transaction(() => {
      db.prepare('DELETE FROM qq_groups WHERE account_id=?').run(accountId);
      for (const group of this.state.groups.filter((item) => selected.has(item.id)))
        db.prepare('INSERT INTO qq_groups(account_id,group_id,name) VALUES (?,?,?)').run(
          accountId,
          group.id,
          group.name,
        );
    })();
    return this.update({
      groups: this.state.groups.map((group) => ({ ...group, selected: selected.has(group.id) })),
    });
  }

  messages(groupId: string): QqMessage[] {
    this.group(groupId);
    const rows = getDatabase()
      .prepare(
        'SELECT data FROM qq_messages WHERE account_id=? AND group_id=? ORDER BY sent_at DESC,id DESC LIMIT 200',
      )
      .all(this.accountId(), groupId) as { data: string }[];
    return rows.reverse().map((row) => JSON.parse(row.data) as QqMessage);
  }

  private storeMessages(groupId: string, messages: QqMessage[]): void {
    const accountId = this.accountId();
    const db = getDatabase();
    db.transaction(() => {
      for (const message of messages) {
        if (message.groupId !== groupId) throw new Error('QQ 返回了其他群的消息');
        db.prepare(
          'INSERT INTO qq_messages(account_id,group_id,id,sent_at,data) VALUES (?,?,?,?,?) ON CONFLICT(account_id,group_id,id) DO UPDATE SET sent_at=excluded.sent_at,data=excluded.data',
        ).run(accountId, groupId, message.id, message.sentAt, JSON.stringify(message));
      }
    })();
    this.messagesChanged(groupId);
  }

  async refreshMessages(groupId: string): Promise<QqMessage[]> {
    this.group(groupId, true);
    const accountId = this.accountId();
    const result = z.object({ messages: z.array(z.unknown()) }).parse(
      await this.call('get_group_msg_history', {
        group_id: groupId,
        count: 100,
        reverseOrder: false,
      }),
    );
    if (accountId !== this.accountId()) throw new Error('QQ 账号已变化，请重新打开群聊');
    const messages = result.messages.map((message) => parseQqMessage(message, accountId));
    this.storeMessages(groupId, messages);
    return this.messages(groupId);
  }

  async send(input: QqSendInput): Promise<void> {
    this.group(input.groupId, true);
    const account = this.state.account!;
    if (
      input.replyTo &&
      !this.messages(input.groupId).some((message) => message.id === input.replyTo)
    )
      throw new Error('引用的消息不在当前记录中，请刷新后重试');
    const segments = [
      ...(input.replyTo ? [{ type: 'reply', data: { id: input.replyTo } }] : []),
      { type: 'text', data: { text: input.text } },
    ];
    const sent = z
      .object({ message_id: qqId })
      .parse(await this.call('send_group_msg', { group_id: input.groupId, message: segments }));
    this.storeMessages(input.groupId, [
      {
        id: sent.message_id,
        groupId: input.groupId,
        senderId: account.id,
        senderName: account.name,
        sentAt: new Date().toISOString(),
        text: input.text,
        files: [],
        own: true,
        ...(input.replyTo ? { replyTo: input.replyTo } : {}),
      },
    ]);
  }

  async image(groupId: string, messageId: string, imageId: string): Promise<string> {
    this.group(groupId);
    const image = this.messages(groupId)
      .find((message) => message.id === messageId)
      ?.images?.find((item) => item.id === imageId);
    if (!image) throw new Error('图片不在当前群消息中，请刷新后重试');
    if (image.url) {
      try {
        return await readQqImage(image.url);
      } catch (error) {
        if (!image.file) throw error;
      }
    }
    if (!image.file) throw new Error('QQ 未提供图片标识，请刷新群消息后重试');
    const result = z
      .object({ url: z.string().optional(), file: z.string().optional() })
      .parse(await this.call('get_image', { file: image.file }));
    const source = result.url || result.file;
    if (!source) throw new Error('QQ 未能提供这张图片');
    return readQqImage(source);
  }

  async file(
    groupId: string,
    messageId: string,
    fileId: string,
  ): Promise<{ url: string; name: string }> {
    this.group(groupId, true);
    const message = this.messages(groupId).find((item) => item.id === messageId);
    const file = message?.files.find((item) => item.id === fileId);
    if (!file) throw new Error('文件不在当前群消息中，请刷新后重试');
    const result = z
      .object({ url: z.url() })
      .parse(await this.call('get_group_file_url', { group_id: groupId, file_id: fileId }));
    if (!['http:', 'https:'].includes(new URL(result.url).protocol))
      throw new Error('QQ 返回的文件地址不可下载');
    return { url: result.url, name: file.name };
  }

  createTodo(input: QqTodoInput): string {
    const group = this.group(input.groupId);
    const accountId = this.accountId();
    const message = this.messages(input.groupId).find((item) => item.id === input.messageId);
    if (!message) throw new Error('消息不在当前记录中，请刷新后重试');
    const db = getDatabase();
    const linked = db
      .prepare(
        'SELECT todo_id FROM qq_message_todos WHERE account_id=? AND group_id=? AND message_id=?',
      )
      .get(accountId, input.groupId, input.messageId) as { todo_id: string } | undefined;
    if (linked) return linked.todo_id;
    return db.transaction(() => {
      const previous = new Set(getTodoState().items.map((item) => item.id));
      const notes = `QQ 群：${group.name}（${group.id}）\n发送者：${message.senderName}\n发送时间：${message.sentAt}\n消息 ID：${message.id}\n\n${message.text}`;
      const result = saveTodo({
        title: input.title,
        notes:
          notes.length > 10000 ? `${notes.slice(0, 9950)}\n\n（原文过长，部分内容已省略）` : notes,
        dueAt: input.dueAt,
        calendar: Boolean(input.dueAt),
      });
      const item = result.items.find((item) => !previous.has(item.id))!;
      db.prepare(
        'INSERT INTO qq_message_todos(account_id,group_id,message_id,todo_id) VALUES (?,?,?,?)',
      ).run(accountId, input.groupId, input.messageId, item.id);
      return item.id;
    })();
  }
}
