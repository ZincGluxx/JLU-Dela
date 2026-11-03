import Database from 'better-sqlite3';
import { beforeEach, afterEach, expect, it, vi } from 'vitest';
import type { ChaoxingCalendar } from '../../../shared/chaoxing-calendar';
let db: Database.Database;
let calendar: ChaoxingCalendar;
const mocks = vi.hoisted(() => {
  const state = {
    shown: [] as { title: string; body: string; click: (() => void) | null }[],
    focus: vi.fn(),
    send: vi.fn(),
  };
  class FakeNotification {
    private readonly record: { title: string; body: string; click: (() => void) | null };
    constructor(options: { title: string; body: string }) {
      this.record = { ...options, click: null };
      state.shown.push(this.record);
    }
    static isSupported() {
      return true;
    }
    on(event: string, listener: () => void) {
      if (event === 'click') this.record.click = listener;
    }
    show() {}
  }
  return { state, FakeNotification };
});
vi.mock('electron', () => ({
  Notification: mocks.FakeNotification,
  BrowserWindow: {
    getAllWindows: () => [
      {
        isDestroyed: () => false,
        isFocused: () => false,
        isMinimized: () => false,
        show: () => {},
        focus: mocks.state.focus,
        webContents: {
          getURL: () => 'file:///app/out/renderer/index.html?smoke-test=1',
          send: mocks.state.send,
        },
      },
    ],
  },
}));
vi.mock('../../database', () => ({ getDatabase: () => db }));
vi.mock('../api', () => ({ getChaoxingCalendar: () => calendar }));
import { checkWorkReminders } from '../reminders';
beforeEach(() => {
  vi.clearAllMocks();
  mocks.state.shown.length = 0;
  db = new Database(':memory:');
  db.exec(`CREATE TABLE chaoxing_work_flags(course_id TEXT NOT NULL,work_id TEXT NOT NULL,read_at TEXT,muted_at TEXT,reminder_key TEXT,PRIMARY KEY(course_id,work_id));
    CREATE TABLE workspace_settings(key TEXT PRIMARY KEY,value TEXT NOT NULL)`);
  calendar = {
    coursesSyncedAt: '2026-11-03T00:00:00Z',
    courses: [{ id: '1:2', name: '示例课程', syncedAt: '2026-11-03T00:00:00Z' }],
    works: [
      {
        id: 'w1',
        courseId: '1:2',
        courseName: '示例课程',
        title: '课程报告',
        status: '未交',
        timing: '剩余2天',
        detailTiming: '截止时间：2026-11-04 08:00',
        syncedAt: '2026-11-03T00:00:00Z',
        deadline: { date: '2026-11-04', time: '08:00' },
      },
    ],
  };
});
afterEach(() => db.close());

it('shows one desktop toast per deadline stage without waiting for the notification baseline', () => {
  const now = new Date('2026-11-03T12:00:00+08:00').getTime();
  expect(checkWorkReminders(now)).toEqual({ due: 1, sent: 1 });
  expect(mocks.state.shown).toHaveLength(1);
  expect(mocks.state.shown[0]?.title).toBe('24 小时内截止：课程报告');
  expect(mocks.state.shown[0]?.body).toContain('示例课程');
  mocks.state.shown[0]?.click?.();
  expect(mocks.state.focus).toHaveBeenCalled();
  expect(mocks.state.send).toHaveBeenCalledWith('chaoxing:open-work', {
    courseId: '1:2',
    workId: 'w1',
  });
  // 同一阶段不重复弹。
  expect(checkWorkReminders(now)).toEqual({ due: 0, sent: 0 });
  expect(mocks.state.shown).toHaveLength(1);
});
