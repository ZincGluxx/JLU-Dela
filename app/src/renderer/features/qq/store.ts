import { create } from 'zustand';
import type { QqMessage, QqState } from '../../../shared/qq';

export const useQq = create<{
  state: QqState;
  messages: Record<string, QqMessage[]>;
  drafts: Record<string, { text: string; replyTo?: string }>;
  setState(state: QqState): void;
  loadMessages(accountId: string, groupId: string, refresh?: boolean): Promise<void>;
  draft(key: string, value: { text: string; replyTo?: string }): void;
}>((set, get) => ({
  state: { phase: 'idle', progress: '', qrCode: null, account: null, groups: [], error: null },
  messages: {},
  drafts: {},
  setState: (state) => set({ state }),
  loadMessages: async (accountId, groupId, refresh = false) => {
    const api = window.dela?.qq;
    if (!api) throw new Error('请在桌面版中连接 QQ');
    const messages = await (refresh ? api.refreshMessages(groupId) : api.messages(groupId));
    if (get().state.account?.id !== accountId) return;
    set((state) => ({ messages: { ...state.messages, [`${accountId}/${groupId}`]: messages } }));
  },
  draft: (key, value) => set((state) => ({ drafts: { ...state.drafts, [key]: value } })),
}));

let attached = false;
export function attachQq(): void {
  if (attached || !window.dela?.qq) return;
  attached = true;
  window.dela.qq.onUpdate(useQq.getState().setState);
  window.dela.qq.onMessages((groupId) => {
    const account = useQq.getState().state.account;
    if (account) void useQq.getState().loadMessages(account.id, groupId).catch(console.error);
  });
  void window.dela.qq.getState().then(useQq.getState().setState).catch(console.error);
}
