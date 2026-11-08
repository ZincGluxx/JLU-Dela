import { ipcMain } from 'electron';
import { randomUUID } from 'node:crypto';
import { z } from 'zod';
import { getDatabase } from '../database';
import { checkWorkspaceSender } from '../ipc';
import {
  communityBoards,
  reviewCommunityPost,
  statusForReview,
  type CommunityBoard,
  type CommunityPost,
  type CommunityPostInput,
  type CommunitySnapshot,
  type CommunityDealStatus,
} from '../../shared/community';
import { communityViewer, demoCommunitySnapshot } from './seed';

const DOC_KIND = 'community';

type DocRow = { version: number; data: string };

function readDoc(): CommunitySnapshot | null {
  const row = getDatabase()
    .prepare('SELECT version,data FROM campus_docs WHERE kind=?')
    .get(DOC_KIND) as DocRow | undefined;
  if (!row) return null;
  try {
    return JSON.parse(row.data) as CommunitySnapshot;
  } catch {
    return null;
  }
}

function writeDoc(snapshot: CommunitySnapshot): CommunitySnapshot {
  getDatabase()
    .prepare(
      `INSERT INTO campus_docs(kind,version,data,updated_at) VALUES(?,?,?,?)
       ON CONFLICT(kind) DO UPDATE SET version=excluded.version, data=excluded.data,
       updated_at=excluded.updated_at`,
    )
    .run(DOC_KIND, snapshot.version, JSON.stringify(snapshot), new Date().toISOString());
  return snapshot;
}

export function getCommunity(): CommunitySnapshot {
  return readDoc() ?? writeDoc(demoCommunitySnapshot());
}

const boardTuple = [...communityBoards] as [CommunityBoard, ...CommunityBoard[]];

export const communityInputSchema = z
  .object({
    board: z.enum(boardTuple),
    title: z.string().trim().min(2).max(120),
    body: z.string().trim().min(1).max(8000),
    tags: z.array(z.string().trim().min(1).max(20)).max(6).optional(),
    contact: z.string().trim().max(120).optional(),
    price: z.number().min(0).max(1_000_000).nullish(),
    condition: z.enum(['全新', '九成新', '正常使用', '有瑕疵']).optional(),
    sourceUrl: z.string().trim().max(500).optional(),
    lab: z.string().trim().max(80).optional(),
    competition: z.string().trim().max(80).optional(),
    deadline: z
      .string()
      .regex(/^\d{4}-\d{2}-\d{2}$/)
      .optional(),
    shop: z.string().trim().max(80).optional(),
    rating: z.number().min(1).max(5).nullish(),
    pricePerPerson: z.number().min(0).max(10_000).nullish(),
  })
  .strict();

function ownPost(snapshot: CommunitySnapshot, id: string): CommunityPost {
  const post = snapshot.posts.find((row) => row.id === id);
  if (!post) throw new Error('帖子不存在或已被删除');
  return post;
}

/** 发帖：基础审核直接给出发布状态，拦截的内容仍保留在「我的」里供作者查看原因。 */
export function createCommunityPost(input: unknown): CommunitySnapshot {
  const value = communityInputSchema.parse(input);
  const snapshot = getCommunity();
  const now = new Date().toISOString();
  const normalized: CommunityPostInput = {
    ...value,
    author: communityViewer,
    tags: value.tags ?? [],
    price: value.price ?? null,
    rating: value.rating ?? null,
    pricePerPerson: value.pricePerPerson ?? null,
  };
  const review = reviewCommunityPost(normalized, now);
  const post: CommunityPost = {
    ...normalized,
    tags: value.tags ?? [],
    id: randomUUID(),
    author: communityViewer,
    createdAt: now,
    updatedAt: now,
    status: statusForReview(value.board, review),
    review,
    likes: 0,
    liked: false,
    replies: [],
    reports: 0,
    ...(value.board === 'market' ? { dealStatus: '在售' as CommunityDealStatus } : {}),
  };
  return writeDoc({ ...snapshot, generatedAt: now, posts: [post, ...snapshot.posts] });
}

export function likeCommunityPost(id: string): CommunitySnapshot {
  const snapshot = getCommunity();
  const post = ownPost(snapshot, id);
  if (post.status === 'rejected') throw new Error('未通过审核的帖子不能点赞');
  return writeDoc({
    ...snapshot,
    posts: snapshot.posts.map((row) =>
      row.id === id
        ? { ...row, liked: !row.liked, likes: Math.max(0, row.likes + (row.liked ? -1 : 1)) }
        : row,
    ),
  });
}

export function replyCommunityPost(id: string, body: unknown): CommunitySnapshot {
  const text = z.string().trim().min(1).max(1000).parse(body);
  const snapshot = getCommunity();
  const post = ownPost(snapshot, id);
  if (post.status === 'rejected') throw new Error('未通过审核的帖子不能回复');
  return writeDoc({
    ...snapshot,
    posts: snapshot.posts.map((row) =>
      row.id === id
        ? {
            ...row,
            replies: [
              ...row.replies,
              {
                id: randomUUID(),
                author: communityViewer,
                body: text,
                createdAt: new Date().toISOString(),
              },
            ],
          }
        : row,
    ),
  });
}

/** 人工复核：把待复核/来源待核实的内容定为已发布或驳回。 */
export function moderateCommunityPost(id: string, decision: unknown): CommunitySnapshot {
  const value = z.enum(['publish', 'reject']).parse(decision);
  const snapshot = getCommunity();
  const post = ownPost(snapshot, id);
  if (post.status === 'published' || post.status === 'rejected')
    throw new Error('该内容已经处理过了');
  return writeDoc({
    ...snapshot,
    posts: snapshot.posts.map((row) =>
      row.id === id
        ? {
            ...row,
            status: value === 'publish' ? 'published' : 'rejected',
            updatedAt: new Date().toISOString(),
          }
        : row,
    ),
  });
}

export function setCommunityDealStatus(id: string, status: unknown): CommunitySnapshot {
  const value = z.enum(['在售', '已出']).parse(status);
  const snapshot = getCommunity();
  const post = ownPost(snapshot, id);
  if (post.board !== 'market') throw new Error('只有二手信息可以标记成交状态');
  return writeDoc({
    ...snapshot,
    posts: snapshot.posts.map((row) => (row.id === id ? { ...row, dealStatus: value } : row)),
  });
}

export function reportCommunityPost(id: string): CommunitySnapshot {
  const snapshot = getCommunity();
  ownPost(snapshot, id);
  return writeDoc({
    ...snapshot,
    posts: snapshot.posts.map((row) =>
      row.id === id ? { ...row, reports: row.reports + 1 } : row,
    ),
  });
}

/** 删除只允许自己的帖子；示例内容不能删，重新生成即可。 */
export function removeCommunityPost(id: string): CommunitySnapshot {
  const snapshot = getCommunity();
  const post = ownPost(snapshot, id);
  if (post.author !== snapshot.viewer) throw new Error('只能删除自己发布的帖子');
  return writeDoc({ ...snapshot, posts: snapshot.posts.filter((row) => row.id !== id) });
}

/** 重新生成示例内容：保留自己发布的帖子与互动。 */
export function regenerateDemoCommunity(): CommunitySnapshot {
  const current = getCommunity();
  const demo = demoCommunitySnapshot();
  const mine = current.posts.filter((row) => row.author === current.viewer);
  const kept = new Set(demo.posts.map((row) => row.id));
  return writeDoc({
    ...demo,
    viewer: current.viewer,
    posts: [...mine.filter((row) => !kept.has(row.id)), ...demo.posts],
  });
}

export function registerCommunityIpc(): void {
  ipcMain.handle('community:get', (event) => {
    checkWorkspaceSender(event);
    return getCommunity();
  });
  ipcMain.handle('community:create', (event, input: unknown) => {
    checkWorkspaceSender(event);
    return createCommunityPost(input);
  });
  ipcMain.handle('community:like', (event, id: string) => {
    checkWorkspaceSender(event);
    return likeCommunityPost(id);
  });
  ipcMain.handle('community:reply', (event, id: string, body: unknown) => {
    checkWorkspaceSender(event);
    return replyCommunityPost(id, body);
  });
  ipcMain.handle('community:moderate', (event, id: string, decision: unknown) => {
    checkWorkspaceSender(event);
    return moderateCommunityPost(id, decision);
  });
  ipcMain.handle('community:deal-status', (event, id: string, status: unknown) => {
    checkWorkspaceSender(event);
    return setCommunityDealStatus(id, status);
  });
  ipcMain.handle('community:report', (event, id: string) => {
    checkWorkspaceSender(event);
    return reportCommunityPost(id);
  });
  ipcMain.handle('community:remove', (event, id: string) => {
    checkWorkspaceSender(event);
    return removeCommunityPost(id);
  });
  ipcMain.handle('community:regenerate-demo', (event) => {
    checkWorkspaceSender(event);
    return regenerateDemoCommunity();
  });
}
