import { z } from 'zod';
import type { QqMessage } from '../../shared/qq';

export const qqId = z.union([z.string().min(1), z.number().int()]).transform(String);
const segment = z.object({
  type: z.string(),
  data: z
    .object({
      text: z.string().optional(),
      id: qqId.optional(),
      qq: qqId.optional(),
      name: z.string().optional(),
      file: z.string().optional(),
      file_id: qqId.optional(),
      file_name: z.string().optional(),
    })
    .passthrough(),
});

export const qqMessageSchema = z.object({
  message_id: qqId,
  group_id: qqId,
  user_id: qqId,
  time: z.number().nonnegative().max(8_640_000_000_000),
  message: z.union([z.string(), z.array(segment)]),
  sender: z.object({ nickname: z.string().optional(), card: z.string().optional() }).default({}),
});

export function parseQqMessage(input: unknown, accountId: string): QqMessage {
  const raw = qqMessageSchema.parse(input);
  const message: QqMessage = {
    id: raw.message_id,
    groupId: raw.group_id,
    senderId: raw.user_id,
    senderName: raw.sender.card || raw.sender.nickname || raw.user_id,
    sentAt: new Date(raw.time * 1000).toISOString(),
    text: '',
    files: [],
    own: raw.user_id === accountId,
  };
  if (typeof raw.message === 'string') {
    message.text = raw.message;
    return message;
  }
  const parts: string[] = [];
  for (const item of raw.message) {
    if (item.type === 'text') parts.push(item.data.text ?? '');
    else if (item.type === 'at')
      parts.push(
        item.data.qq === 'all' ? '@全体成员' : `@${item.data.name || item.data.qq || '群成员'}`,
      );
    else if (item.type === 'reply') message.replyTo = item.data.id;
    else if (item.type === 'file') {
      const id = item.data.file_id || item.data.id || item.data.file;
      const name = item.data.name || item.data.file_name || item.data.file || '群文件';
      if (id) message.files.push({ id, name });
      parts.push(`[文件] ${name}`);
    } else {
      const labels: Record<string, string> = {
        image: '图片',
        record: '语音',
        video: '视频',
        forward: '合并转发',
        face: '表情',
      };
      parts.push(`[${labels[item.type] ?? '暂不支持的消息'}]`);
    }
  }
  message.text = parts.join('');
  return message;
}
