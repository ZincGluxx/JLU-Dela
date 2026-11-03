import { useActionState, useEffect, useLayoutEffect, useRef, useState } from 'react';
import { Dialog } from 'radix-ui';
import { QRCodeSVG } from 'qrcode.react';
import {
  ArrowLeft,
  Download,
  MessageCircle,
  PanelsTopLeft,
  RefreshCw,
  Reply,
  Send,
  Sparkles,
  SquareCheckBig,
  X,
} from 'lucide-react';
import type { QqMessage } from '../../../shared/qq';
import { qqSummaryPrompt } from '../../../shared/qq';
import { Button } from '../../components/ui/button';
import { Input } from '../../components/ui/input';
import { Textarea } from '../../components/ui/textarea';
import { dialogOverlay, dialogPanel } from '../../components/ui/motion';
import { useNavigationStore } from '../../navigation/view';
import { useChatDrafts } from '../../content/chat/drafts';
import { useSessions } from '../../sessions/store';
import { errorText } from '../../workspace/store';
import { showToast } from '../../app/toasts';
import { cn } from '../../lib/utils';
import { attachQq, useQq } from './store';

const emptyMessages: QqMessage[] = [];
const emptyDraft = { text: '', replyTo: undefined };
const phaseLabels = {
  idle: '尚未连接',
  preparing: '正在准备',
  setup: '等待安装共享组件',
  starting: '正在启动',
  login: '等待登录',
  online: '已连接',
  stopped: '已断开',
  error: '连接异常',
};

export function QqView() {
  const state = useQq((store) => store.state);
  const [selected, setSelected] = useState<string | null>(null);
  const [mode, setMode] = useState<'groups' | 'chat'>('chat');
  const [showGroupList, setShowGroupList] = useState(false);
  const [search, setSearch] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  useEffect(attachQq, []);
  const api = window.dela?.qq;
  const online = state.phase === 'online';
  const active = ['preparing', 'starting', 'login', 'online'].includes(state.phase);
  const connectedGroups = state.groups.filter((group) => group.selected);
  const managing = mode === 'groups' || connectedGroups.length === 0;
  const current = connectedGroups.find((group) => group.id === selected) ?? connectedGroups[0];
  const groups = state.groups.filter(
    (group) =>
      (managing || group.selected) &&
      `${group.name} ${group.id}`.toLowerCase().includes(search.toLowerCase()),
  );
  async function perform(task: () => Promise<unknown>) {
    setBusy(true);
    setError(null);
    try {
      await task();
    } catch (cause) {
      setError(errorText(cause));
    } finally {
      setBusy(false);
    }
  }
  return (
    <section className="flex min-h-0 min-w-0 flex-1 flex-col" aria-label="QQ 群聊">
      <header className="flex flex-wrap items-center justify-between gap-3 px-5 py-4">
        <div className="min-w-0">
          <h1 className="text-base font-semibold">QQ 群聊</h1>
          <p className="mt-1 text-xs text-ink-3" role="status">
            {phaseLabels[state.phase]}
            {state.account ? ` · ${state.account.name}（${state.account.id}）` : ''}
          </p>
        </div>
        <div className="flex items-center gap-2">
          {online && (
            <Button
              variant="ghost"
              size="icon"
              aria-label="刷新群列表"
              disabled={busy}
              onClick={() => void perform(() => api!.refreshGroups())}
            >
              <RefreshCw />
            </Button>
          )}
          {active || state.phase === 'error' ? (
            <Button
              variant="outline"
              disabled={!api}
              onClick={() => void perform(() => api!.stop())}
            >
              断开
            </Button>
          ) : (
            <Button disabled={busy || !api} onClick={() => void perform(() => api!.start())}>
              连接 QQ
            </Button>
          )}
        </div>
      </header>
      {(error || state.error) && (
        <p className="mx-5 mb-3 break-words text-13 text-red" role="alert">
          {error || state.error}
        </p>
      )}
      {!api ? (
        <p className="p-5 text-13 text-ink-3">请在 Dela 桌面版中连接 QQ。</p>
      ) : !state.account ? (
        <div className="flex min-h-0 flex-1 flex-col items-center justify-center gap-5 overflow-y-auto p-6 text-center">
          {state.qrCode ? (
            <div className="rounded-card bg-white p-4">
              <QRCodeSVG value={state.qrCode} size={192} title="QQ 登录二维码" />
            </div>
          ) : (
            <MessageCircle className="size-10 text-ink-3" />
          )}
          <div className="max-w-md space-y-2">
            <h2 className="text-base font-medium">{state.progress || '把课程群消息带进工作台'}</h2>
            <p className="text-13 leading-relaxed text-ink-3">
              {state.phase === 'setup'
                ? '完全退出 QQ 后，安装共享桥接，再点击“连接 QQ”。安装需要管理员授权，会替换 QQ 的启动入口和本机签名，并保留完整原版备份。'
                : '复用本机 QQ 的原生会话。登录后选择要接入的群，QQ 原生窗口可继续使用。'}
            </p>
            <p className="text-xs leading-relaxed text-ink-3">
              实验功能 · 消息以你的 QQ 身份发送。断开 Dela 不会退出 QQ。
            </p>
          </div>
          {state.phase === 'setup' && (
            <Button disabled={busy} onClick={() => void perform(() => api.openInstaller())}>
              安装共享桥接
            </Button>
          )}
          {state.phase === 'login' && (
            <Button
              variant="outline"
              disabled={busy}
              onClick={() => void perform(() => api.refreshLogin())}
            >
              <RefreshCw />
              刷新二维码
            </Button>
          )}
          {state.phase === 'error' && (
            <Button
              disabled={busy}
              onClick={() =>
                void perform(async () => {
                  await api.stop();
                  await api.start();
                })
              }
            >
              重新连接
            </Button>
          )}
        </div>
      ) : (
        <div className="flex min-h-0 min-w-0 flex-1">
          <aside
            className={cn(
              'flex w-64 shrink-0 flex-col gap-3 bg-page p-3 max-md:w-full',
              !managing && current && !showGroupList && 'max-md:hidden',
            )}
            aria-label="选择接入群"
          >
            <Input
              aria-label="搜索 QQ 群"
              placeholder="搜索群名或群号"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
            />
            <div className="flex items-center justify-between gap-2 px-2">
              <p className="text-xs text-ink-3">
                {managing ? '勾选要接入的群' : '已接入的群'} · {connectedGroups.length} 个
              </p>
              {!managing && (
                <Button variant="ghost" size="sm" onClick={() => setMode('groups')}>
                  管理群聊
                </Button>
              )}
            </div>
            <div className="min-h-0 flex-1 space-y-1 overflow-y-auto">
              {groups.map((group) => (
                <div
                  key={group.id}
                  className={cn(
                    'flex items-center gap-2 rounded-control px-2 py-1',
                    current?.id === group.id && 'bg-hover-2',
                  )}
                >
                  {managing && (
                    <input
                      type="checkbox"
                      aria-label={`接入 ${group.name}`}
                      checked={group.selected}
                      disabled={busy || !online}
                      onChange={(event) => {
                        const checked = event.target.checked;
                        setMode('groups');
                        const ids = state.groups
                          .filter((item) => (item.id === group.id ? checked : item.selected))
                          .map((item) => item.id);
                        void perform(async () => {
                          await api.selectGroups(ids);
                          if (checked) setSelected(group.id);
                        });
                      }}
                    />
                  )}
                  <button
                    aria-label={`打开群聊 ${group.name}`}
                    className="min-w-0 flex-1 rounded-control py-2 text-left disabled:opacity-50"
                    disabled={!group.selected}
                    onClick={() => {
                      setSelected(group.id);
                      setMode('chat');
                      setShowGroupList(false);
                    }}
                  >
                    <span className="block truncate text-13 font-medium">{group.name}</span>
                    <span className="text-xs text-ink-3">{group.id}</span>
                  </button>
                </div>
              ))}
              {!groups.length && (
                <p className="p-2 text-13 text-ink-3">
                  {search ? '没有匹配的群' : '尚未获取到群，请刷新群列表。'}
                </p>
              )}
            </div>
            {managing && (
              <Button
                disabled={busy || !connectedGroups.length}
                onClick={() => {
                  setMode('chat');
                  setShowGroupList(false);
                  setSearch('');
                }}
              >
                完成并进入聊天
              </Button>
            )}
          </aside>
          {!managing && current && state.account ? (
            <div className={cn('flex min-h-0 min-w-0 flex-1', showGroupList && 'max-md:hidden')}>
              <QqConversation
                key={`${state.account.id}/${current.id}`}
                accountId={state.account.id}
                groupId={current.id}
                onBack={() => setShowGroupList(true)}
              />
            </div>
          ) : (
            <div className="hidden flex-1 items-center justify-center p-6 text-13 text-ink-3 md:flex">
              {connectedGroups.length
                ? '选好群后，点击“完成并进入聊天”'
                : '勾选要接入的群，然后进入聊天'}
            </div>
          )}
        </div>
      )}
    </section>
  );
}

export function QqConversation({
  accountId,
  groupId,
  onBack,
}: {
  accountId: string;
  groupId: string;
  onBack?: () => void;
}) {
  const state = useQq((store) => store.state);
  const key = `${accountId}/${groupId}`;
  const messages = useQq((store) => store.messages[key] ?? emptyMessages);
  const draft = useQq((store) => store.drafts[key] ?? emptyDraft);
  const [selected, setSelected] = useState<string[]>([]);
  const [todoMessage, setTodoMessage] = useState<QqMessage | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const group = state.groups.find((item) => item.id === groupId && item.selected);
  const messageList = useRef<HTMLDivElement>(null);
  const following = useRef(true);
  const selectedMessages = messages.filter((message) => selected.includes(message.id));
  const available = state.account?.id === accountId && Boolean(group);
  const online = available && state.phase === 'online';
  useLayoutEffect(() => {
    if (following.current && messageList.current)
      messageList.current.scrollTop = messageList.current.scrollHeight;
  }, [messages]);
  useEffect(() => {
    if (!available) return;
    let active = true;
    void useQq
      .getState()
      .loadMessages(accountId, groupId, online)
      .catch((cause) => {
        if (active) setError(errorText(cause));
      });
    return () => {
      active = false;
    };
  }, [accountId, groupId, available, online]);
  async function perform(task: () => Promise<unknown>) {
    setBusy(true);
    setError(null);
    try {
      await task();
    } catch (cause) {
      setError(errorText(cause));
    } finally {
      setBusy(false);
    }
  }
  const [sendError, sendAction, sending] = useActionState(
    async () => {
      try {
        if (!window.dela) throw new Error('请在桌面版中连接 QQ');
        await window.dela.qq.send({ groupId, text: draft.text, replyTo: draft.replyTo });
        useQq.getState().draft(key, { text: '' });
        return null;
      } catch (cause) {
        return errorText(cause);
      }
    },
    null as string | null,
  );
  async function summarize() {
    const api = window.dela;
    if (!group || !api) return;
    const chosen = selectedMessages.length ? selectedMessages : messages.slice(-100);
    if (!chosen.length) throw new Error('请先读取群消息');
    const prompt = qqSummaryPrompt(group, chosen);
    if (prompt.length > 100_000) throw new Error('所选消息过长，请减少选择后再总结');
    const chat = await api.session.create(null, 'chat');
    if (!chat.sessionId) throw new Error('未能创建 AI 会话，请重试');
    useSessions.getState().putChat(chat.sessionId, chat);
    useChatDrafts.getState().update(chat.sessionId, { prompt });
    useNavigationStore.getState().openChat(chat.sessionId, null);
    showToast({
      variant: 'neutral',
      title: '已准备总结草稿',
      description: '检查后发送给你选择的 AI。',
    });
  }
  if (!available)
    return (
      <div className="flex min-w-0 flex-1 items-center justify-center p-5 text-13 text-ink-3">
        请连接对应 QQ 账号，并重新选择这个群。
      </div>
    );
  return (
    <section className="flex min-h-0 min-w-0 flex-1 flex-col" aria-label={`群聊 ${group!.name}`}>
      <header className="flex flex-wrap items-center justify-between gap-2 px-4 py-3">
        <div className="flex min-w-0 items-center gap-2">
          {onBack && (
            <Button
              className="md:hidden"
              variant="ghost"
              size="icon"
              aria-label="返回群列表"
              onClick={onBack}
            >
              <ArrowLeft />
            </Button>
          )}
          <div className="min-w-0">
            <h2 className="truncate text-sm font-semibold">{group!.name}</h2>
            <p className="text-xs text-ink-3">显示最近 200 条缓存 · 刷新读取最多 100 条可用记录</p>
          </div>
        </div>
        <div className="flex items-center gap-1">
          <Button
            size="sm"
            variant="ghost"
            disabled={busy || !messages.length}
            onClick={() => void perform(summarize)}
          >
            <Sparkles />
            {selectedMessages.length ? `总结所选 ${selectedMessages.length} 条` : 'AI 总结'}
          </Button>
          <Button
            size="icon-sm"
            variant="ghost"
            aria-label="刷新群消息"
            disabled={busy || !online}
            onClick={() =>
              void perform(() => useQq.getState().loadMessages(accountId, groupId, true))
            }
          >
            <RefreshCw />
          </Button>
          {onBack && (
            <Button
              size="icon-sm"
              variant="ghost"
              aria-label="在工作台打开群聊"
              onClick={() => useNavigationStore.getState().openQqGroup(accountId, groupId)}
            >
              <PanelsTopLeft />
            </Button>
          )}
        </div>
      </header>
      {(error || sendError) && (
        <p role="alert" className="px-4 pb-2 text-13 text-red">
          {error || sendError}
        </p>
      )}
      {!online && (
        <p role="status" className="px-4 pb-2 text-xs text-ink-3">
          QQ 已断开，当前显示本机缓存。
        </p>
      )}
      <div
        ref={messageList}
        onScroll={(event) => {
          const node = event.currentTarget;
          following.current = node.scrollHeight - node.clientHeight - node.scrollTop <= 1;
        }}
        className="min-h-0 flex-1 space-y-4 overflow-y-auto px-4 py-3"
        aria-label="群消息记录"
        aria-busy={busy}
      >
        {!messages.length && (
          <p className="py-8 text-center text-13 text-ink-3">
            尚无消息。点击刷新读取近期可用记录。
          </p>
        )}
        {messages.map((message) => (
          <article
            key={message.id}
            className="group/message flex min-w-0 gap-2"
            data-message-id={message.id}
          >
            <input
              type="checkbox"
              className="mt-1 shrink-0 self-start"
              aria-label={`选择 ${message.senderName} 的消息 ${message.id}`}
              checked={selected.includes(message.id)}
              onChange={(event) =>
                setSelected((ids) =>
                  event.target.checked
                    ? [...ids, message.id]
                    : ids.filter((id) => id !== message.id),
                )
              }
            />
            <div className="min-w-0 flex-1">
              <p className="flex flex-wrap items-baseline gap-x-2 text-xs text-ink-3">
                <span className="font-medium text-ink-2">
                  {message.senderName}
                  {message.own ? '（我）' : ''}
                </span>
                <time dateTime={message.sentAt}>
                  {new Date(message.sentAt).toLocaleString('zh-CN')}
                </time>
              </p>
              {message.replyTo && (
                <p className="mt-1 text-xs text-ink-3">引用消息 {message.replyTo}</p>
              )}
              <p className="mt-1 whitespace-pre-wrap break-words text-13 leading-relaxed [overflow-wrap:anywhere]">
                {message.text}
              </p>
              {message.files.map((file) => (
                <Button
                  key={file.id}
                  className="mt-2 max-w-full"
                  variant="outline"
                  size="sm"
                  disabled={busy || !online}
                  onClick={() =>
                    void perform(async () => {
                      const path = await window.dela!.qq.download(groupId, message.id, file.id);
                      if (path)
                        showToast({ variant: 'success', title: '文件已保存', description: path });
                    })
                  }
                >
                  <Download />
                  <span className="truncate">{file.name}</span>
                </Button>
              ))}
              <div className="mt-1 flex gap-1">
                <Button
                  size="sm"
                  variant="ghost"
                  disabled={!online || sending}
                  aria-label={`回复消息 ${message.id}`}
                  onClick={() => useQq.getState().draft(key, { ...draft, replyTo: message.id })}
                >
                  <Reply />
                  回复
                </Button>
                <Button
                  size="sm"
                  variant="ghost"
                  onClick={() => setTodoMessage(message)}
                  aria-label={`将消息 ${message.id} 设为待办`}
                >
                  <SquareCheckBig />
                  设为待办
                </Button>
              </div>
            </div>
          </article>
        ))}
      </div>
      <form className="space-y-2 p-4" action={sendAction}>
        {draft.replyTo && (
          <div className="flex items-center justify-between gap-2 rounded-control bg-field px-3 py-2 text-xs text-ink-3">
            <span className="truncate">
              回复：
              {messages.find((message) => message.id === draft.replyTo)?.text ?? draft.replyTo}
            </span>
            <Button
              variant="ghost"
              size="icon-xs"
              aria-label="取消引用"
              disabled={sending}
              onClick={() => useQq.getState().draft(key, { text: draft.text })}
            >
              <X />
            </Button>
          </div>
        )}
        <Textarea
          aria-label="QQ 消息内容"
          placeholder="输入消息"
          maxLength={4500}
          value={draft.text}
          disabled={!online || sending}
          onChange={(event) => useQq.getState().draft(key, { ...draft, text: event.target.value })}
        />
        <div className="flex justify-end">
          <Button type="submit" disabled={!online || sending || !draft.text.trim()}>
            <Send />
            {sending ? '发送中…' : '发送'}
          </Button>
        </div>
      </form>
      {todoMessage && (
        <QqTodoDialog
          key={todoMessage.id}
          groupId={groupId}
          message={todoMessage}
          onClose={() => setTodoMessage(null)}
        />
      )}
    </section>
  );
}

function QqTodoDialog({
  groupId,
  message,
  onClose,
}: {
  groupId: string;
  message: QqMessage;
  onClose: () => void;
}) {
  const [title, setTitle] = useState(message.text.slice(0, 200));
  const [dueAt, setDueAt] = useState('');
  const [error, action, pending] = useActionState(
    async () => {
      try {
        if (!window.dela) throw new Error('请在桌面版中连接 QQ');
        const id = await window.dela.qq.createTodo({
          groupId,
          messageId: message.id,
          title,
          dueAt: dueAt ? new Date(dueAt).toISOString() : null,
        });
        onClose();
        useNavigationStore.getState().openTodo(id);
        return null;
      } catch (cause) {
        return errorText(cause);
      }
    },
    null as string | null,
  );
  return (
    <Dialog.Root
      open
      onOpenChange={(open) => {
        if (!open && !pending) onClose();
      }}
    >
      <Dialog.Portal>
        <Dialog.Overlay className={dialogOverlay} />
        <Dialog.Content className={cn(dialogPanel, 'max-w-md')}>
          <Dialog.Title className="text-base font-semibold">设为待办</Dialog.Title>
          <Dialog.Description className="mt-2 text-13 text-ink-3">
            原消息和来源信息会保存在备注中。
          </Dialog.Description>
          <form action={action} className="mt-4 space-y-4">
            <label className="block space-y-2 text-13">
              <span>待办内容</span>
              <Input
                autoFocus
                required
                maxLength={200}
                value={title}
                disabled={pending}
                onChange={(event) => setTitle(event.target.value)}
              />
            </label>
            <label className="block space-y-2 text-13">
              <span>截止时间（可选）</span>
              <Input
                type="datetime-local"
                value={dueAt}
                disabled={pending}
                onChange={(event) => setDueAt(event.target.value)}
              />
            </label>
            {error && (
              <p role="alert" className="text-13 text-red">
                {error}
              </p>
            )}
            <div className="flex justify-end gap-2">
              <Button variant="ghost" disabled={pending} onClick={onClose}>
                取消
              </Button>
              <Button type="submit" disabled={pending || !title.trim()}>
                {pending ? '保存中…' : '保存待办'}
              </Button>
            </div>
          </form>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  );
}
