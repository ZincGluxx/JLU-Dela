import Database from 'better-sqlite3';
import { beforeEach, afterEach, expect, it, vi } from 'vitest';
import type { ChaoxingCalendar, ChaoxingCalendarWork } from '../../../shared/chaoxing-calendar';
let db: Database.Database;
let calendar: ChaoxingCalendar;
const mocks = vi.hoisted(() => ({
  notify: vi.fn(() => true),
  click: vi.fn(),
}));
vi.mock('../../database', () => ({ getDatabase: () => db }));
vi.mock('../api', () => ({ getChaoxingCalendar: () => calendar }));
vi.mock('../../notifications/system', () => ({
  systemNotifyWorkReminder: (_title: string, _body: string, onClick: () => void) => {
    mocks.click.mockImplementation(onClick);
    return mocks.notify();
  },
  workspaceMainWindow: () => null,
}));
import {
  checkWorkReminders,
  setWorkRemindersEnabled,
  workReminderState,
  workRemindersEnabled,
} from '../reminders';
import { markChaoxingWork } from '../flags';

const now = new Date('2026-11-03T12:00:00+08:00').getTime();
const work = (overrides: Partial<ChaoxingCalendarWork> = {}): ChaoxingCalendarWork => ({
  id: 'w1',
  courseId: '1:2',
  courseName: '示例课程',
  title: '课程报告',
  status: '未交',
  timing: '剩余2天',
  detailTiming: '截止时间：2026-11-04 08:00',
  syncedAt: '2026-11-03T00:00:00Z',
  deadline: { date: '2026-11-04', time: '08:00' },
  ...overrides,
});
beforeEach(() => {
  vi.clearAllMocks();
  mocks.notify.mockReturnValue(true);
  db = new Database(':memory:');
  db.exec(`CREATE TABLE chaoxing_work_flags(course_id TEXT NOT NULL,work_id TEXT NOT NULL,read_at TEXT,muted_at TEXT,reminder_key TEXT,PRIMARY KEY(course_id,work_id));
    CREATE TABLE workspace_settings(key TEXT PRIMARY KEY,value TEXT NOT NULL)`);
  calendar = {
    coursesSyncedAt: '2026-11-03T00:00:00Z',
    courses: [{ id: '1:2', name: '示例课程', syncedAt: '2026-11-03T00:00:00Z' }],
    works: [work()],
  };
});
afterEach(() => db.close());

it('reminds once per deadline stage and again when the deadline moves', () => {
  expect(workRemindersEnabled()).toBe(true);
  expect(checkWorkReminders(now)).toEqual({ due: 1, sent: 1 });
  expect(mocks.notify).toHaveBeenCalledTimes(1);
  // 同一截止时刻同一阶段不重复提醒。
  expect(checkWorkReminders(now)).toEqual({ due: 0, sent: 0 });
  // 进入 1 小时内是新的阶段。
  const urgent = now + 21 * 3_600_000;
  expect(checkWorkReminders(urgent)).toEqual({ due: 1, sent: 1 });
  expect(mocks.notify).toHaveBeenCalledTimes(2);
  // 截止时间被学校改动后重新提醒。
  calendar = { ...calendar, works: [work({ detailTiming: '截止时间：2026-11-03 23:00' })] };
  expect(checkWorkReminders(now)).toEqual({ due: 1, sent: 1 });
  expect(mocks.notify).toHaveBeenCalledTimes(3);
});

it('skips ignored, completed, undated and long-past work, and does not mark what was not shown', () => {
  calendar = {
    ...calendar,
    works: [
      work({ id: 'muted' }),
      work({ id: 'done', status: '已提交' }),
      work({ id: 'undated', detailTiming: undefined, timing: '剩余2天' }),
      work({ id: 'old', detailTiming: '截止时间：2026-10-01 08:00' }),
      work({ id: 'later', detailTiming: '截止时间：2026-11-20 08:00' }),
    ],
  };
  markChaoxingWork('1:2', 'muted', { muted: true });
  expect(checkWorkReminders(now)).toEqual({ due: 0, sent: 0 });
  mocks.notify.mockReturnValue(false);
  calendar = { ...calendar, works: [work()] };
  expect(checkWorkReminders(now)).toEqual({ due: 1, sent: 0 });
  mocks.notify.mockReturnValue(true);
  expect(checkWorkReminders(now)).toEqual({ due: 1, sent: 1 });
});

it('honours the reminder switch and exposes the click target', () => {
  expect(workReminderState()).toEqual({ enabled: true });
  expect(setWorkRemindersEnabled(false)).toEqual({ enabled: false });
  expect(checkWorkReminders(now)).toEqual({ due: 0, sent: 0 });
  expect(mocks.notify).not.toHaveBeenCalled();
  setWorkRemindersEnabled(true);
  checkWorkReminders(now);
  mocks.click();
  expect(mocks.click).toHaveBeenCalledTimes(1);
});
