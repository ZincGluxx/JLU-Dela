import type { QqApi, QqSendInput, QqState, QqTodoInput } from '../shared/qq';
import { invoke, on } from './lib';

export const qq = {
  getState: () => invoke('qq:get-state'),
  start: () => invoke('qq:start'),
  openInstaller: () => invoke('qq:open-installer'),
  stop: () => invoke('qq:stop'),
  refreshLogin: () => invoke('qq:refresh-login'),
  refreshGroups: () => invoke('qq:refresh-groups'),
  selectGroups: (ids: string[]) => invoke('qq:select-groups', ids),
  messages: (groupId: string) => invoke('qq:messages', groupId),
  image: (groupId: string, messageId: string, imageId: string) =>
    invoke('qq:image', { groupId, messageId, imageId }),
  refreshMessages: (groupId: string) => invoke('qq:refresh-messages', groupId),
  send: (input: QqSendInput) => invoke('qq:send', input),
  download: (groupId: string, messageId: string, fileId: string) =>
    invoke('qq:download', { groupId, messageId, fileId }),
  createTodo: (input: QqTodoInput) => invoke('qq:create-todo', input),
  onUpdate: (listener: (state: QqState) => void) => on('qq:state', listener),
  onMessages: (listener: (groupId: string) => void) => on('qq:messages', listener),
} satisfies QqApi;
