import { BrowserWindow, dialog, ipcMain, net, app } from 'electron';
import { createWriteStream } from 'node:fs';
import { rename, rm } from 'node:fs/promises';
import { basename, join } from 'node:path';
import { randomUUID } from 'node:crypto';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import { z } from 'zod';
import { checkWorkspaceSender } from '../ipc';
import { QqService } from './service';
import { openQqInstaller } from './runtime';

const id = z.string().min(1).max(512);
const groupId = z.string().regex(/^\d+$/);
let service: QqService | undefined;

export function registerQqIpc(): void {
  const broadcast = (channel: string, payload: unknown) => {
    for (const window of BrowserWindow.getAllWindows()) {
      if (window.isDestroyed()) continue;
      const url = window.webContents.getURL();
      if (
        !url.startsWith('http://127.0.0.1:5173/') &&
        !(url.startsWith('file:') && /\/renderer\/index\.html(?:\?|$)/.test(url))
      )
        continue;
      window.webContents.send(channel, payload);
    }
  };
  const qq = new QqService(
    (state) => broadcast('qq:state', state),
    (groupId) => broadcast('qq:messages', groupId),
  );
  service = qq;
  const handlers: Record<string, (input: unknown) => unknown> = {
    'get-state': () => qq.getState(),
    start: () => qq.start(),
    'open-installer': () => openQqInstaller(),
    stop: () => qq.stop(),
    'refresh-login': () => qq.refreshLogin(),
    'refresh-groups': () => qq.refreshGroups(),
    'select-groups': (input) => qq.selectGroups(z.array(groupId).max(500).parse(input)),
    messages: (input) => qq.messages(groupId.parse(input)),
    'refresh-messages': (input) => qq.refreshMessages(groupId.parse(input)),
    send: (input) =>
      qq.send(
        z
          .object({ groupId, text: z.string().trim().min(1).max(4500), replyTo: id.optional() })
          .strict()
          .parse(input),
      ),
    'create-todo': (input) =>
      qq.createTodo(
        z
          .object({
            groupId,
            messageId: id,
            title: z.string().trim().min(1).max(200),
            dueAt: z.iso.datetime().nullable(),
          })
          .strict()
          .parse(input),
      ),
    download: async (input) => {
      const value = z.object({ groupId, messageId: id, fileId: id }).strict().parse(input);
      const file = await qq.file(value.groupId, value.messageId, value.fileId);
      const choice = await dialog.showSaveDialog({
        title: '保存 QQ 群文件',
        defaultPath: join(app.getPath('downloads'), basename(file.name.replaceAll('\\', '/'))),
      });
      if (choice.canceled || !choice.filePath) return null;
      const temporary = `${choice.filePath}.${randomUUID()}.part`;
      try {
        const response = await net.fetch(file.url, { signal: AbortSignal.timeout(5 * 60_000) });
        if (!response.ok || !response.body) throw new Error('文件下载失败，请刷新群消息后重试');
        await pipeline(
          Readable.fromWeb(response.body),
          createWriteStream(temporary, { flags: 'wx' }),
        );
        await rename(temporary, choice.filePath);
        return choice.filePath;
      } finally {
        await rm(temporary, { force: true });
      }
    },
  };
  for (const [name, handler] of Object.entries(handlers))
    ipcMain.handle(`qq:${name}`, (event, input: unknown) => {
      checkWorkspaceSender(event);
      return handler(input);
    });
}

export function closeQq(): void {
  service?.stop();
}
