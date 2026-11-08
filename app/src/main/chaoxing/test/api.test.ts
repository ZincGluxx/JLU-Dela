import Database from 'better-sqlite3';
import {
  mkdtempSync,
  readFileSync,
  writeFileSync,
  mkdirSync,
  rmSync,
  unlinkSync,
  symlinkSync,
  realpathSync,
} from 'node:fs';
import { EventEmitter } from 'node:events';
import { Readable } from 'node:stream';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { beforeEach, afterEach, expect, it, vi } from 'vitest';
let db: Database.Database, directory: string;
const mocks = vi.hoisted(() => ({ request: vi.fn() }));
vi.mock('electron', () => ({
  net: { request: mocks.request },
  safeStorage: {
    isEncryptionAvailable: () => true,
    encryptString: (value: string) => Buffer.from('sealed:' + value),
    decryptString: (value: Buffer) => value.toString().slice(7),
  },
}));
vi.mock('../../database', () => ({ getDatabase: () => db }));
vi.mock('../../jlu/reader', () => ({ readSchoolPage: vi.fn() }));
vi.mock('../../jlu/api', () => ({
  platformResult: async (work: () => Promise<unknown>) => {
    try {
      return { ok: true, data: await work() };
    } catch (error) {
      return {
        ok: false,
        error: (error as Error).message,
        ...((error as Error).cause === 'auth' ? { reason: 'auth' } : {}),
      };
    }
  },
}));
vi.mock('../session', () => ({
  chaoxingSession: {
    partition: 'persist:chaoxing',
    get: async () => ({}),
    flush: async () => {},
  },
  isChaoxingLoginUrl: () => false,
}));
vi.mock('../../workspace/api', () => ({ getWorkspaceState: () => ({ directory }) }));
vi.mock('../../storage', async (importOriginal) => {
  const actual = await importOriginal<typeof import('../../storage')>();
  return { ...actual, availablePath: vi.fn(actual.availablePath) };
});
import { availablePath } from '../../storage';
import { readSchoolPage } from '../../jlu/reader';
import {
  cachedWorkEntry,
  saveWorkTiming,
  getChaoxingCourses,
  getChaoxingCalendar,
  syncChaoxingCalendar,
  getChaoxingFiles,
  getChaoxingWorks,
  syncChaoxingCourses,
  setRetainedChaoxingCourses,
  setChaoxingCourseRemark,
  syncChaoxingFiles,
  syncChaoxingWorks,
  importChaoxingFile,
  bindChaoxingCourse,
  linkChaoxingFile,
  chaoxingResult,
} from '../api';
import { markChaoxingWork } from '../flags';
const reader = vi.mocked(readSchoolPage);
beforeEach(() => {
  vi.clearAllMocks();
  db = new Database(':memory:');
  db.exec(
    'CREATE TABLE jlu_platform_cache(key TEXT PRIMARY KEY,data TEXT NOT NULL); CREATE TABLE chaoxing_work_flags(course_id TEXT NOT NULL,work_id TEXT NOT NULL,read_at TEXT,muted_at TEXT,reminder_key TEXT,PRIMARY KEY(course_id,work_id))',
  );
  directory = realpathSync(mkdtempSync(join(tmpdir(), 'dela-cx-api-')));
});
afterEach(() => {
  db.close();
  rmSync(directory, { recursive: true, force: true });
});
async function seedCourse() {
  reader
    .mockResolvedValueOnce({ url: 'https://mooc2-ans.chaoxing.com/visit/interaction?s=private' })
    .mockResolvedValueOnce([
      {
        id: '1:2',
        name: '示例课程',
        teacher: '示例教师',
        ended: false,
        url: 'https://mooc1.chaoxing.com/visit/stucoursemiddle?courseid=1&clazzid=2&enc=private',
      },
    ]);
  await syncChaoxingCourses();
  return setRetainedChaoxingCourses(['1:2']);
}
async function seedFile() {
  await seedCourse();
  reader
    .mockResolvedValueOnce({
      url: 'https://mooc2-ans.chaoxing.com/mooc2-ans/mycourse/stu?courseid=1&clazzid=2&enc=private',
    })
    .mockResolvedValueOnce({
      url: 'https://mooc2-ans.chaoxing.com/mooc2-ans/coursedata/stu-datalist?enc=private',
    })
    .mockResolvedValueOnce([
      {
        id: 'd1',
        name: '示例.pdf',
        type: 'pdf',
        size: '5KB',
        creator: '教师',
        date: '10-31',
        downloadable: true,
        folderUrl: null,
        downloadUrl: 'https://mooc1.chaoxing.com/coursedata/downloadData?dataId=d1&enc=private',
      },
    ]);
  return syncChaoxingFiles('1:2');
}
it('keeps signed course routes outside renderer and plaintext caches, and preserves data on failed refresh', async () => {
  const data = await seedCourse();
  expect(JSON.stringify(data)).not.toMatch(/private|url|enc/);
  const routes = db.prepare("SELECT data FROM jlu_platform_cache WHERE key='cx:routes'").get() as {
    data: string;
  };
  expect(routes.data).not.toContain('enc=private');
  expect(getChaoxingCourses()).toEqual(data);
  reader.mockRejectedValueOnce(new Error('network unavailable'));
  expect(await chaoxingResult(() => syncChaoxingCourses())).toEqual({
    ok: false,
    error: 'network unavailable',
  });
  expect(getChaoxingCourses()).toEqual(data);
});
it('resolves the course landing page before reading metadata and retains assignments on invalid responses', async () => {
  await seedFile();
  expect(JSON.stringify(getChaoxingFiles('1:2'))).not.toContain('private');
  expect(
    reader.mock.calls.some(([options]) =>
      options.accepts(new URL('https://mooc2-ans.chaoxing.com/mooc2-ans/mycourse/stu')),
    ),
  ).toBe(true);
  reader
    .mockResolvedValueOnce({ url: 'https://mooc1.chaoxing.com/mooc2/work/list?enc=private' })
    .mockResolvedValueOnce([
      {
        id: 'w1',
        title: '示例作业',
        status: '未交',
        timing: '剩余2天',
        url: 'https://mooc1.chaoxing.com/mooc-ans/mooc2/work/task?workId=w1&enc=private',
      },
    ]);
  const works = await syncChaoxingWorks('1:2');
  expect(getChaoxingWorks('1:2')).toEqual(works);
  expect(JSON.stringify(works)).not.toContain('private');
  expect(cachedWorkEntry('1:2', 'w1')).toMatchObject({
    exact: true,
    url: expect.stringContaining('enc=private'),
  });
  const plaintext = db
    .prepare("SELECT data FROM jlu_platform_cache WHERE key='cx:works:1:2'")
    .get() as { data: string };
  expect(plaintext.data).not.toMatch(/enc=|https:/);
  expect(saveWorkTiming('1:2', 'w1', '剩余2天')).toBe(false);
  expect(saveWorkTiming('1:2', 'missing', '截止时间：2026-11-02 20:00')).toBe(false);

  reader
    .mockResolvedValueOnce({ url: 'https://mooc1.chaoxing.com/mooc2/work/list' })
    .mockResolvedValueOnce({ maintenance: true });
  expect(await chaoxingResult(() => syncChaoxingWorks('1:2'))).toMatchObject({
    ok: false,
    error: expect.stringContaining('结构'),
  });
  expect(getChaoxingWorks('1:2')).toEqual(works);
});
function downloadRequest(target = 'https://download.chaoxing.com/fixture.pdf', statusCode = 200) {
  const request = Object.assign(new EventEmitter(), {
    setHeader: vi.fn(),
    end: () => queueMicrotask(() => request.emit('redirect', 302, 'GET', target)),
    followRedirect: vi.fn(() => {
      const response = Object.assign(Readable.from([Buffer.from('%PDF-fixture')]), {
        statusCode,
        headers: { 'content-type': 'application/pdf' },
      });
      request.emit('response', response);
    }),
    abort: () => request.emit('abort'),
  });
  mocks.request.mockReturnValueOnce(request);
  return request;
}
it.each(['https://download.chaoxing.com/fixture.pdf', 'https://d0.cldisk.com/fixture.pdf'])(
  'follows the allowed native download redirect %s and imports inside the workspace',
  async (target) => {
    await seedFile();
    const request = downloadRequest(target);
    const result = await importChaoxingFile('1:2', '', 'd1');
    expect(request.followRedirect).toHaveBeenCalledOnce();
    expect(request.setHeader).toHaveBeenCalledWith('Referer', 'https://mooc2-ans.chaoxing.com/');
    expect(mocks.request).toHaveBeenCalledWith(
      expect.objectContaining({ useSessionCookies: true, redirect: 'manual' }),
    );
    expect(result.id.startsWith(join(directory, 'workspace'))).toBe(true);
    expect(readFileSync(result.id, 'utf8')).toBe('%PDF-fixture');
  },
);
it('keeps local read and ignore marks across work refreshes without touching school data', async () => {
  await seedCourse();
  const insert = db.prepare('INSERT INTO jlu_platform_cache VALUES (?, ?)');
  insert.run(
    'cx:works:1:2',
    JSON.stringify({
      courseId: '1:2',
      syncedAt: '2026-11-03T00:00:00Z',
      items: [{ id: 'w1', title: '报告', status: '未交', timing: '剩余2天' }],
    }),
  );
  expect(getChaoxingWorks('1:2')?.items[0]?.readAt).toBeUndefined();
  markChaoxingWork('1:2', 'w1', { read: true, muted: true });
  const marked = getChaoxingWorks('1:2')!.items[0]!;
  expect(marked).toMatchObject({ title: '报告', mutedAt: expect.any(String) });
  expect(marked.readAt).toBeTruthy();
  // 学校缓存本身不写标记，读取时再叠加。
  const cached = db
    .prepare("SELECT data FROM jlu_platform_cache WHERE key='cx:works:1:2'")
    .get() as {
    data: string;
  };
  expect(cached.data).not.toContain('mutedAt');
  expect(getChaoxingCalendar().works[0]).toMatchObject({ mutedAt: expect.any(String) });
  markChaoxingWork('1:2', 'w1', { read: false, muted: false });
  expect(getChaoxingWorks('1:2')?.items[0]?.mutedAt).toBeUndefined();
  expect(getChaoxingWorks('1:2')?.items[0]?.readAt).toBeUndefined();
});
it('refuses non-school native redirect destinations', async () => {
  await seedFile();
  const request = downloadRequest('https://example.com/private');
  await expect(importChaoxingFile('1:2', '', 'd1')).rejects.toThrow('下载地址暂不支持');
  expect(request.followRedirect).not.toHaveBeenCalled();
});
it('reports a refused file download as a download failure and retains the directory cache', async () => {
  const files = await seedFile();
  downloadRequest('https://d0.cldisk.com/fixture.pdf', 403);
  await expect(importChaoxingFile('1:2', '', 'd1')).rejects.toThrow('下载失败（403）');
  expect(getChaoxingFiles('1:2')).toEqual(files);
});
it('does not replace or remove an existing note when file creation is refused', async () => {
  await seedFile();
  const folder = join(directory, 'workspace', '学习通资料', '示例课程 (1_2)');
  mkdirSync(folder, { recursive: true });
  const file = join(folder, '示例.pdf');
  writeFileSync(file, 'original');
  vi.mocked(availablePath).mockReturnValueOnce(file);
  downloadRequest();
  await expect(importChaoxingFile('1:2', '', 'd1')).rejects.toThrow();
  expect(readFileSync(file, 'utf8')).toBe('original');
});

it('aggregates only cached course works, without reading a school page or exposing signed routes', async () => {
  await seedCourse();
  db.prepare('INSERT INTO jlu_platform_cache VALUES (?, ?)').run(
    'cx:works:1:2',
    JSON.stringify({
      courseId: '1:2',
      syncedAt: '2026-10-31T00:00:00Z',
      items: [{ id: 'w', title: '报告', status: '未交', timing: '截止时间：2026-11-02 23:59' }],
    }),
  );
  reader.mockClear();
  expect(getChaoxingCalendar().works[0]).toMatchObject({
    courseId: '1:2',
    deadline: { date: '2026-11-02', time: '23:59' },
  });
  expect(JSON.stringify(getChaoxingCalendar())).not.toContain('private');
  expect(reader).not.toHaveBeenCalled();
});

it('requires a course selection and hides unretained works without deleting their cache', async () => {
  await seedCourse();
  db.prepare('DELETE FROM jlu_platform_cache WHERE key=?').run('cx:retained-courses');
  expect(getChaoxingCourses()!.retainedCourseIds).toEqual([]);
  db.prepare('INSERT INTO jlu_platform_cache VALUES (?, ?)').run(
    'cx:works:1:2',
    JSON.stringify({
      courseId: '1:2',
      syncedAt: '2026-11-07T00:00:00Z',
      items: [{ id: 'w', title: '课程作业', status: '未交', timing: '截止时间：2026-11-08 23:59' }],
    }),
  );
  expect(getChaoxingCalendar().works).toEqual([]);
  setRetainedChaoxingCourses(['1:2']);
  expect(getChaoxingCalendar().works).toHaveLength(1);
  setRetainedChaoxingCourses([]);
  expect(getChaoxingCalendar()).toMatchObject({ courses: [], works: [] });
  expect(getChaoxingWorks('1:2')!.items[0]!.title).toBe('课程作业');
  expect(() => setRetainedChaoxingCourses(['unknown'])).toThrow('列表已变化');
  expect(getChaoxingCourses()!.retainedCourseIds).toEqual([]);
  setRetainedChaoxingCourses(['1:2']);
  expect(getChaoxingCalendar().works).toHaveLength(1);
});

it('stores course remarks separately, preserves them across sync and allows restoring the school name', async () => {
  await seedCourse();
  const renamed = setChaoxingCourseRemark('1:2', '  安卓课  ');
  expect(renamed.items[0]).toMatchObject({ id: '1:2', name: '示例课程', remark: '安卓课' });
  expect(renamed.retainedCourseIds).toEqual(['1:2']);
  const schoolCache = db
    .prepare("SELECT data FROM jlu_platform_cache WHERE key='cx:courses'")
    .get() as { data: string };
  expect(schoolCache.data).not.toContain('安卓课');
  setRetainedChaoxingCourses([]);
  expect(getChaoxingCourses()!.items[0]!.remark).toBe('安卓课');
  reader
    .mockResolvedValueOnce({ url: 'https://mooc2-ans.chaoxing.com/visit/interaction' })
    .mockResolvedValueOnce([
      {
        id: '1:2',
        name: '学校更新后的课程名',
        teacher: '',
        ended: true,
        url: 'https://mooc1.chaoxing.com/mycourse/stu?courseid=1&clazzid=2',
      },
    ]);
  const refreshed = await syncChaoxingCourses();
  expect(refreshed.items[0]).toMatchObject({
    name: '学校更新后的课程名',
    remark: '安卓课',
    ended: true,
  });
  expect(() => setChaoxingCourseRemark('unknown', '备注')).toThrow('自己的学习通课程');
  expect(() => setChaoxingCourseRemark('1:2', '课'.repeat(81))).toThrow('80');
  expect(getChaoxingCourses()!.items[0]!.remark).toBe('安卓课');
  expect(setChaoxingCourseRemark('1:2', '   ').items[0]!.remark).toBeUndefined();
  expect(getChaoxingCourses()!.items[0]!.name).toBe('学校更新后的课程名');
});

it('sorts courses by remark or original name after edits, clearing and catalog refresh', async () => {
  const rows = [
    { id: 'network', name: '计算机网络' },
    { id: 'android', name: 'Android软件开发' },
    { id: 'compiler', name: '编译原理' },
    { id: 'math10', name: '微积分10' },
    { id: 'math2', name: '微积分2' },
  ].map((course) => ({
    ...course,
    teacher: '',
    ended: false,
    url: 'https://mooc2-ans.chaoxing.com/mooc2-ans/mycourse/stu?courseid=' + course.id,
  }));
  const refresh = () => {
    reader
      .mockResolvedValueOnce({ url: 'https://mooc2-ans.chaoxing.com/visit/interaction' })
      .mockResolvedValueOnce(rows);
    return syncChaoxingCourses();
  };
  const originalOrder = ['compiler', 'network', 'math2', 'math10', 'android'];
  expect((await refresh()).items.map((course) => course.id)).toEqual(originalOrder);
  setRetainedChaoxingCourses(rows.map((course) => course.id));
  const remarkedOrder = ['android', 'compiler', 'network', 'math2', 'math10'];
  expect(setChaoxingCourseRemark('android', '安卓课').items.map((course) => course.id)).toEqual(
    remarkedOrder,
  );
  expect(getChaoxingCalendar().courses.map((course) => course.id)).toEqual(remarkedOrder);
  expect((await refresh()).items.map((course) => course.id)).toEqual(remarkedOrder);
  expect(setChaoxingCourseRemark('android', '').items.map((course) => course.id)).toEqual(
    originalOrder,
  );
  expect(getChaoxingCalendar().courses.map((course) => course.id)).toEqual(originalOrder);
  const schoolCache = db
    .prepare("SELECT data FROM jlu_platform_cache WHERE key='cx:courses'")
    .get() as { data: string };
  expect(JSON.parse(schoolCache.data).items.map((course: { id: string }) => course.id)).toEqual(
    rows.map((course) => course.id),
  );
});

it('keeps the user selection after catalog refresh and syncs only retained courses', async () => {
  await seedCourse();
  const catalog = [
    {
      id: '1:2',
      name: '示例课程',
      teacher: '',
      ended: false,
      url: 'https://mooc2-ans.chaoxing.com/mooc2-ans/mycourse/stu?courseid=1&clazzid=2',
    },
    {
      id: 'old',
      name: '已结课课程',
      teacher: '',
      ended: true,
      url: 'https://mooc2-ans.chaoxing.com/mooc2-ans/mycourse/stu?courseid=3',
    },
    {
      id: 'new',
      name: '新发现课程',
      teacher: '',
      ended: false,
      url: 'https://mooc2-ans.chaoxing.com/mooc2-ans/mycourse/stu?courseid=4',
    },
  ];
  reader.mockClear();
  reader
    .mockResolvedValueOnce({ url: 'https://mooc2-ans.chaoxing.com/visit/interaction' })
    .mockResolvedValueOnce(catalog)
    .mockResolvedValueOnce({ url: 'https://mooc1.chaoxing.com/list' })
    .mockResolvedValueOnce([
      {
        id: 'w',
        title: '本学期作业',
        status: '未交',
        timing: '',
        url: 'https://mooc1.chaoxing.com/task?workId=w',
      },
    ]);
  const result = await syncChaoxingCalendar();
  expect(result.failures).toEqual([]);
  expect(getChaoxingCourses()!.retainedCourseIds).toEqual(['1:2']);
  expect(getChaoxingCourses()!.items).toHaveLength(3);
  expect(result.data.courses.map((course) => course.id)).toEqual(['1:2']);
  expect(result.data.works.map((work) => work.title)).toEqual(['本学期作业']);
  expect(reader).toHaveBeenCalledTimes(4);
  setRetainedChaoxingCourses(['old']);
  expect(getChaoxingCourses()!.retainedCourseIds).toEqual(['old']);
});

it('continues after a course network failure, stops on authentication, and preserves previous snapshots', async () => {
  const courses = ['1', '2', '3'].map((key) => ({
    id: key,
    name: '课程' + key,
    teacher: '',
    ended: false,
    url: 'https://mooc1.chaoxing.com/mycourse/stu?courseid=' + key,
  }));
  db.prepare('INSERT INTO jlu_platform_cache VALUES (?, ?)').run(
    'cx:retained-courses',
    JSON.stringify(['1', '2', '3']),
  );
  db.prepare('INSERT INTO jlu_platform_cache VALUES (?, ?)').run(
    'cx:works:1',
    JSON.stringify({
      courseId: '1',
      syncedAt: '2026-10-30T00:00:00Z',
      items: [{ id: 'w', title: '旧作业', status: '未交', timing: '剩余2天' }],
    }),
  );
  reader
    .mockResolvedValueOnce({ url: 'https://mooc2-ans.chaoxing.com/visit/interaction' })
    .mockResolvedValueOnce(courses)
    .mockRejectedValueOnce(new Error('网络超时'))
    .mockRejectedValueOnce(new Error('需要登录', { cause: 'auth' }));
  const result = await syncChaoxingCalendar();
  expect(result.failures).toEqual([
    { courseId: '1', error: '网络超时', reason: undefined },
    { courseId: '2', error: '需要登录', reason: 'auth' },
  ]);
  expect(result.data.works).toEqual([expect.objectContaining({ title: '旧作业' })]);
  expect(reader).toHaveBeenCalledTimes(4);
});

it('retains a detail deadline across relative list refreshes, but lets newer explicit list dates replace it', async () => {
  await seedCourse();
  let first = true;
  const refresh = async (timing: string) => {
    if (first) reader.mockResolvedValueOnce({ url: 'https://mooc1.chaoxing.com/course' });
    first = false;
    reader.mockResolvedValueOnce({ url: 'https://mooc1.chaoxing.com/list' }).mockResolvedValueOnce([
      {
        id: 'w1',
        title: '报告',
        status: '未交',
        timing,
        url: 'https://mooc1.chaoxing.com/task?workId=w1&enc=private',
      },
    ]);
    return syncChaoxingWorks('1:2');
  };
  await refresh('剩余2天');
  expect(saveWorkTiming('1:2', 'w1', '截止时间：2026-11-02 20:00')).toBe(true);
  await refresh('剩余1天');
  expect(getChaoxingCalendar().works[0]?.deadline).toEqual({ date: '2026-11-02', time: '20:00' });
  expect(getChaoxingWorks('1:2')?.items[0]?.detailSyncedAt).toBeTruthy();
  await refresh('截止时间：2026-11-04 21:00');
  expect(getChaoxingCalendar().works[0]?.deadline).toEqual({ date: '2026-11-04', time: '21:00' });
  expect(getChaoxingWorks('1:2')?.items[0]?.detailSyncedAt).toBeUndefined();
});

it('refreshes status and deadlines automatically and retains earlier detail times on partial failure', async () => {
  await seedCourse();
  reader
    .mockResolvedValueOnce({ url: 'https://mooc1.chaoxing.com/course' })
    .mockResolvedValueOnce({ url: 'https://mooc1.chaoxing.com/list' })
    .mockResolvedValueOnce([
      {
        id: 'w1',
        title: '报告',
        status: 'To be marked',
        timing: '剩余2小时0分钟',
        detailTiming: '截止时间：2026-11-07 20:00',
        url: 'https://mooc1.chaoxing.com/task?workId=w1&enc=private',
      },
    ]);
  const initial = await syncChaoxingWorks('1:2');
  expect(initial.items[0]).toMatchObject({
    status: 'To be marked',
    detailTiming: '截止时间：2026-11-07 20:00',
    detailSyncedAt: expect.any(String),
  });
  expect(saveWorkTiming('1:2', 'w1', '截止时间：11-07 20:00（年份待确认）')).toBe(true);
  const saved = getChaoxingWorks('1:2')!.items[0]!;
  expect(saved.detailTiming).toBe(initial.items[0]!.detailTiming);
  reader.mockResolvedValueOnce({ url: 'https://mooc1.chaoxing.com/list' }).mockResolvedValueOnce([
    {
      id: 'w1',
      title: '报告',
      status: 'reviewd',
      timing: '',
      detailError: '作业详情暂时无法读取，请稍后刷新',
      url: 'https://mooc1.chaoxing.com/task?workId=w1&enc=private',
    },
  ]);
  const refreshed = await syncChaoxingWorks('1:2');
  expect(refreshed.items[0]).toMatchObject({
    status: 'reviewd',
    detailTiming: initial.items[0]!.detailTiming,
    detailSyncedAt: saved.detailSyncedAt,
    detailError: '作业详情暂时无法读取，请稍后刷新',
  });
  expect(getChaoxingCalendar().works[0]?.deadline).toEqual({ date: '2026-11-07', time: '20:00' });
  reader.mockResolvedValueOnce({ url: 'https://mooc1.chaoxing.com/list' }).mockResolvedValueOnce([
    {
      id: 'w1',
      title: '报告',
      status: 'To be Submitted',
      timing: '剩余20000小时0分钟',
      detailTiming: '截止时间：11-07 20:00（年份待确认）',
      url: 'https://mooc1.chaoxing.com/task?workId=w1&enc=private',
    },
  ]);
  await syncChaoxingWorks('1:2');
  expect(getChaoxingCalendar().works[0]?.deadline).toBeNull();
});

function localCourse() {
  db.exec(
    'CREATE TABLE knowledge_roots(id TEXT PRIMARY KEY,path TEXT); CREATE TABLE knowledge_courses(id TEXT PRIMARY KEY,root_id TEXT,name TEXT,relative_path TEXT)',
  );
  const id = crypto.randomUUID(),
    rootId = crypto.randomUUID();
  const root = join(directory, '本地知识库'),
    path = join(root, '计算机网络');
  mkdirSync(path, { recursive: true });
  db.prepare('INSERT INTO knowledge_roots VALUES (?,?)').run(rootId, root);
  db.prepare('INSERT INTO knowledge_courses VALUES (?,?,?,?)').run(
    id,
    rootId,
    '计算机网络',
    '计算机网络',
  );
  return { id, path };
}
it('binds courses explicitly and opens an associated file without downloading it again', async () => {
  await seedFile();
  const course = localCourse();
  const file = join(course.path, '已有课件.pdf');
  writeFileSync(file, 'existing local notes');
  expect(bindChaoxingCourse('1:2', course.id)).toMatchObject({ knowledgeCourseId: course.id });
  linkChaoxingFile('1:2', '', 'd1', file);
  expect(getChaoxingFiles('1:2')?.items[0]?.local).toMatchObject({
    origin: 'linked',
    status: 'ready',
  });
  expect(await importChaoxingFile('1:2', '', 'd1')).toEqual({
    id: expect.stringContaining('已有课件.pdf'),
  });
  expect(mocks.request).not.toHaveBeenCalled();
  writeFileSync(file, 'edited locally');
  expect(getChaoxingFiles('1:2')?.items[0]?.local?.status).toBe('local-changed');
  expect(bindChaoxingCourse('1:2', null)).toBeNull();
  expect(readFileSync(file, 'utf8')).toBe('edited locally');
  unlinkSync(file);
  expect(getChaoxingFiles('1:2')?.items[0]?.local?.status).toBe('missing');
});
it('preserves the remote folder hierarchy when importing into a linked course', async () => {
  await seedFile();
  const course = localCourse();
  bindChaoxingCourse('1:2', course.id);
  const root = getChaoxingFiles('1:2')!;
  db.prepare('UPDATE jlu_platform_cache SET data=? WHERE key=?').run(
    JSON.stringify({
      ...root,
      items: [
        {
          id: 'folder1',
          name: '课件PPT',
          type: 'afolder',
          size: '',
          creator: '',
          date: '',
          downloadable: false,
        },
      ],
    }),
    'cx:files:1:2:',
  );
  const routes = JSON.parse(
    Buffer.from(
      JSON.parse(
        (
          db.prepare("SELECT data FROM jlu_platform_cache WHERE key='cx:routes'").get() as {
            data: string;
          }
        ).data,
      ),
      'base64',
    )
      .toString()
      .slice(7),
  );
  routes['folder:1:2:folder1'] =
    'https://mooc2-ans.chaoxing.com/mooc2-ans/coursedata/stu-datalist?folder=1';
  db.prepare('UPDATE jlu_platform_cache SET data=? WHERE key=?').run(
    JSON.stringify(Buffer.from('sealed:' + JSON.stringify(routes)).toString('base64')),
    'cx:routes',
  );
  reader.mockResolvedValueOnce([
    {
      ...root.items[0],
      folderUrl: null,
      downloadUrl: 'https://mooc1.chaoxing.com/coursedata/downloadData?dataId=d1',
    },
  ]);
  expect((await syncChaoxingFiles('1:2', 'folder1')).relativePath).toEqual(['课件PPT']);
  downloadRequest();
  const result = await importChaoxingFile('1:2', 'folder1', 'd1');
  expect(result.id).toBe(join(course.path, '课件PPT', '示例.pdf'));
  expect((await importChaoxingFile('1:2', 'folder1', 'd1')).id).toBe(result.id);
  expect(mocks.request).toHaveBeenCalledOnce();
  const snapshot = getChaoxingFiles('1:2', 'folder1')!;
  db.prepare('UPDATE jlu_platform_cache SET data=? WHERE key=?').run(
    JSON.stringify({
      ...snapshot,
      items: snapshot.items.map((file) => ({ ...file, date: '11-02' })),
    }),
    'cx:files:1:2:folder1',
  );
  expect(getChaoxingFiles('1:2', 'folder1')?.items[0]?.local?.status).toBe('remote-changed');
  downloadRequest();
  const updated = await importChaoxingFile('1:2', 'folder1', 'd1');
  expect(updated.id).not.toBe(result.id);
  expect(readFileSync(updated.id, 'utf8')).toBe('%PDF-fixture');
  expect(readFileSync(result.id, 'utf8')).toBe('%PDF-fixture');
});
it('refuses linking files outside the bound course, including symlink targets', async () => {
  await seedFile();
  const course = localCourse();
  bindChaoxingCourse('1:2', course.id);
  const outside = join(directory, 'outside.pdf');
  writeFileSync(outside, 'private');
  expect(() => linkChaoxingFile('1:2', '', 'd1', outside)).toThrow('课程目录');
  if (process.platform !== 'win32') {
    const linked = join(course.path, 'linked.pdf');
    symlinkSync(outside, linked);
    expect(() => linkChaoxingFile('1:2', '', 'd1', linked)).toThrow('课程目录');
  }
});
