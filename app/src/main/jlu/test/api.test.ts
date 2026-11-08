import Database from 'better-sqlite3';
import { beforeEach, afterEach, it, expect, vi } from 'vitest';
let db: Database.Database;
vi.mock('../../database', () => ({ getDatabase: () => db }));
vi.mock('../reader', () => ({ readSchoolPage: vi.fn() }));
vi.mock('../../campus', () => ({
  CampusAuthError: class extends Error {},
  createCampusLoginWindow: vi.fn(),
  getCampusSession: vi.fn(),
}));
import { readSchoolPage } from '../reader';
import {
  getLearning,
  getNotices,
  getNotice,
  getRecordings,
  platformResult,
  syncNotices,
  readNotice,
  syncLearning,
  syncRecordings,
} from '../api';
const reader = vi.mocked(readSchoolPage);
beforeEach(() => {
  vi.resetAllMocks();
  db = new Database(':memory:');
  db.exec('CREATE TABLE jlu_platform_cache(key TEXT PRIMARY KEY,data TEXT NOT NULL)');
});
afterEach(() => db.close());
it('stores relative notice dates as absolute Shanghai dates', async () => {
  vi.useFakeTimers();
  vi.setSystemTime(new Date('2026-10-30T17:00:00Z'));
  try {
    reader.mockResolvedValueOnce({
      items: [
        {
          id: '1',
          channel: '179577',
          title: 'Example',
          department: '',
          published: '今天 09:30',
          pinned: false,
          url: 'https://oa.jlu.edu.cn/defaultroot/PortalInformation!getInformation.action?id=1',
        },
      ],
      totalPages: 1,
    });
    expect((await syncNotices('179577', 1)).items[0]?.published).toBe('2026-10-31 09:30');
  } finally {
    vi.useRealTimers();
  }
});
it('stores a requested notice page and preserves it on malformed or failed refresh', async () => {
  reader.mockResolvedValueOnce({
    items: [
      {
        id: '1',
        channel: '179577',
        title: '示例通知',
        department: '示例单位',
        published: '今天',
        pinned: false,
        url: 'https://oa.jlu.edu.cn/defaultroot/PortalInformation!getInformation.action?id=1',
      },
    ],
    totalPages: 2,
  });
  const first = await syncNotices('179577', 1);
  expect(getNotices('179577', 1)).toEqual(first);
  reader.mockResolvedValueOnce({ items: null });
  expect((await platformResult(() => syncNotices('179577', 1))).ok).toBe(false);
  expect(getNotices('179577', 1)).toEqual(first);
  reader.mockRejectedValueOnce(new Error('offline'));
  expect(await platformResult(() => syncNotices('179577', 1))).toEqual({
    ok: false,
    error: 'offline',
  });
  expect(getNotices('179577', 1)).toEqual(first);
});
it('stores notice text and validates attachment destinations', async () => {
  reader.mockResolvedValueOnce({
    title: '示例通知',
    metadata: '示例单位',
    text: '正文',
    attachments: [
      {
        name: '示例.pdf',
        url: 'https://oa.jlu.edu.cn/defaultroot/PortalInformation!getInformation.action?id=1',
        elementId: 'test.pdf',
      },
    ],
  });
  await readNotice('1', '179577');
  expect(getNotice('1', '179577')?.text).toBe('正文');
  reader.mockResolvedValueOnce({
    title: '示例',
    metadata: '',
    text: '',
    attachments: [{ name: 'bad', url: 'javascript:alert(1)' }],
  });
  await expect(readNotice('1', '179577')).rejects.toThrow('结构');
  expect(getNotice('1', '179577')?.text).toBe('正文');
});
it('queries all dates and keeps search pages separate by field, keyword and page', async () => {
  reader.mockImplementation(async ({ url }) => {
    const params = new URL(url).searchParams;
    return {
      items: [
        {
          id: '1',
          channel: '179577',
          title: params.get('searchnr') || '原列表',
          department: '本科生院',
          published: '2020-01-01',
          pinned: false,
          url: 'https://oa.jlu.edu.cn/defaultroot/PortalInformation!getInformation.action?id=1',
        },
      ],
      totalPages: 97,
    };
  });
  const title = { query: '奖学金 & 交流', field: 'title' as const };
  const department = { query: title.query, field: 'department' as const };
  const original = await syncNotices('179577', 1);
  const first = await syncNotices('179577', 1, undefined, title);
  const url = new URL(reader.mock.calls.at(-1)![0].url);
  expect(url.searchParams.get('searchnr')).toBe(title.query);
  expect(url.searchParams.get('searchlx')).toBe('0');
  expect(url.searchParams.has('searchDate')).toBe(true);
  expect(url.searchParams.get('searchDate')).toBe('');
  expect(first).toMatchObject({
    search: title,
    totalPages: 97,
    items: [{ published: '2020-01-01' }],
  });
  expect(getNotices('179577', 1)).toEqual(original);
  expect(getNotices('179577', 1, title)).toEqual(first);
  expect(getNotices('179577', 2, title)).toBeNull();
  expect(getNotices('179577', 1, department)).toBeNull();
  expect(getNotices('179577', 1, { ...title, query: '其他' })).toBeNull();
  await syncNotices('179577', 2, undefined, title);
  expect(new URL(reader.mock.calls.at(-1)![0].url).searchParams.get('startPage')).toBe('2');
  expect(getNotices('179577', 2, title)?.page).toBe(2);
  await syncNotices('179577', 1, undefined, department);
  expect(new URL(reader.mock.calls.at(-1)![0].url).searchParams.get('searchlx')).toBe('1');
  expect(getNotices('179577', 1, department)?.search).toEqual(department);
  const body = { query: '奖学金', field: 'body' as const, organization: '本科生院' };
  await syncNotices('179577', 1, undefined, body);
  const bodyUrl = new URL(reader.mock.calls.at(-1)![0].url);
  expect(bodyUrl.searchParams.get('searchlx')).toBe('2');
  expect(bodyUrl.searchParams.get('orgname')).toBe('本科生院');
  expect(bodyUrl.searchParams.get('searchDate')).toBe('');
  expect(getNotices('179577', 1, body)?.search).toEqual(body);
  expect(getNotices('179577', 1, { ...body, organization: '研究生院' })).toBeNull();
  expect(getNotices('179577', 1, { query: body.query, field: body.field })).toBeNull();
  reader.mockRejectedValueOnce(new Error('offline'));
  await expect(syncNotices('179577', 1, undefined, title)).rejects.toThrow('offline');
  expect(getNotices('179577', 1, title)).toEqual(first);
  expect(getNotices('179577', 1)).toEqual(original);
});
it('keeps semester-specific courses and permits recordings only for a synced own course', async () => {
  reader.mockResolvedValueOnce([
    { id: 'term-1', year: '2026', num: '1', name: '秋', selected: '1' },
  ]);
  reader.mockResolvedValueOnce([
    {
      id: 'course-1',
      name: '示例教学班',
      courseName: '示例课程',
      teacherName: '示例教师',
      statusName: '进行中',
      studentId: 'private',
    },
  ]);
  await syncLearning();
  expect(getLearning()).toMatchObject({
    termId: 'term-1',
    courses: [{ id: 'course-1', teacher: '示例教师' }],
  });
  expect(JSON.stringify(getLearning())).not.toContain('private');
  await expect(syncRecordings('not-my-course')).rejects.toThrow('自己的课程');
  reader.mockResolvedValueOnce([
    {
      id: 'record-1',
      liveRecordName: '第一讲',
      currentDate: '2026-10-30',
      timeRange: '08:00-09:40',
      roomName: '示例教室',
      liveStatus: '2',
    },
  ]);
  await syncRecordings('course-1');
  expect(getRecordings('course-1')?.items[0]?.name).toBe('第一讲');
  const before = getLearning();
  reader.mockResolvedValueOnce({ invalid: true });
  await expect(syncLearning()).rejects.toThrow('学期');
  expect(getLearning()).toEqual(before);
});
