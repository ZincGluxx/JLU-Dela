import { describe, it, expect } from 'vitest';
import {
  chaoxingAssignments,
  chaoxingDeadline,
  chaoxingReminderKey,
  chaoxingReminderStage,
  chaoxingWorkCompleted,
  chaoxingWorkDueAt,
  chaoxingWorkSection,
  chaoxingWorkSort,
  chaoxingWorkStatus,
  chaoxingWorkSummary,
} from './chaoxing-calendar';

describe('learning deadlines', () => {
  it('uses an explicitly labelled end date rather than the publication date', () => {
    expect(chaoxingDeadline('开始时间：2026-10-01 08:00 截止时间：2026-11-02 23:59')).toEqual({
      date: '2026-11-02',
      time: '23:59',
    });
    expect(chaoxingDeadline('截止时间：2026年11月2日23:59:12')).toEqual({
      date: '2026-11-02',
      time: '23:59:12',
    });
    expect(chaoxingDeadline('截止日期：2026年11月2日')).toEqual({ date: '2026-11-02', time: null });
  });
  it('does not invent deadlines from relative, unlabeled, or invalid dates', () => {
    for (const value of [
      '剩余2天',
      '2026-11-02 23:59',
      '发布时间：2026-11-02',
      '截止时间：2026-02-30 12:00',
      '截止：2026-11-02 24:00',
      '截止：2026-11-123',
      '截止：2026-11-02 23:5',
      '截止：2026-11-02 23:59:99',
    ])
      expect(chaoxingDeadline(value)).toBeNull();
  });
  it('requires an explicit completion status', () => {
    expect(chaoxingWorkCompleted('已提交')).toBe(true);
    for (const value of ['未提交', '未完成', '已截止', '', '未知'])
      expect(chaoxingWorkCompleted(value)).toBe(false);
  });
  it.each(['待批阅', '待批改', 'To be marked', 'reviewd', 'Reviewed', 'Completed'])(
    'counts the platform status %s as submitted',
    (status) => {
      expect(chaoxingWorkCompleted(status)).toBe(true);
      expect(chaoxingWorkSection({ id: 'w', title: '作业', status, timing: '' }, Date.now())).toBe(
        'done',
      );
    },
  );
  it('shows readable submission labels while keeping unknown states unresolved', () => {
    expect(chaoxingWorkStatus('To be Submitted')).toBe('未提交');
    expect(chaoxingWorkStatus('To be marked')).toBe('已提交 · 待批阅');
    expect(chaoxingWorkStatus('reviewd')).toBe('已批阅');
    for (const value of ['To be Submitted', '未交', '已退回', 'Uncompleted', 'Not submitted'])
      expect(chaoxingWorkCompleted(value)).toBe(false);
    expect(chaoxingWorkStatus('')).toBe('状态待确认');
  });
});

describe('assignment board grouping', () => {
  it('uses the remark in calendar and work labels while retaining the original course name', () => {
    const courses = {
      items: [{ id: 'a', name: 'Android软件开发', remark: '安卓课', teacher: '', ended: false }],
      syncedAt: '2026-11-07T00:00:00Z',
      retainedCourseIds: ['a'],
    };
    const works = [
      {
        courseId: 'a',
        syncedAt: courses.syncedAt,
        items: [{ id: 'w', title: '报告', status: '未交', timing: '' }],
      },
    ];
    expect(chaoxingAssignments(courses, works)).toMatchObject({
      courses: [{ id: 'a', name: '安卓课', originalName: 'Android软件开发' }],
      works: [{ courseName: '安卓课', courseOriginalName: 'Android软件开发' }],
    });
    expect(courses.items[0]!.name).toBe('Android软件开发');
  });

  it('filters unretained courses without shifting the work snapshots between courses', () => {
    const courses = {
      items: [
        { id: 'a', name: '未保留课程', teacher: '', ended: false },
        { id: 'b', name: '已保留课程', teacher: '', ended: true },
      ],
      syncedAt: '2026-11-07T00:00:00Z',
      retainedCourseIds: ['b'],
    };
    const works = courses.items.map((course) => ({
      courseId: course.id,
      syncedAt: courses.syncedAt,
      items: [{ id: course.id, title: course.name + '作业', status: '未交', timing: '' }],
    }));
    expect(chaoxingAssignments(courses, works)).toMatchObject({
      courses: [{ id: 'b', name: '已保留课程' }],
      works: [{ courseId: 'b', title: '已保留课程作业' }],
    });
    expect(chaoxingAssignments({ ...courses, retainedCourseIds: [] }, works)).toMatchObject({
      courses: [],
      works: [],
    });
  });

  const now = new Date('2026-11-03T02:00:00Z').getTime();
  const work = (
    overrides: Partial<Parameters<typeof chaoxingWorkDueAt>[0]> & {
      status?: string;
      title?: string;
    },
  ) => ({
    id: overrides.title ?? 'w',
    title: overrides.title ?? '作业',
    status: overrides.status ?? '未交',
    timing: overrides.timing ?? '',
    detailTiming: overrides.detailTiming,
  });
  it('treats a date-only deadline as the end of that day in Beijing time', () => {
    expect(chaoxingWorkDueAt(work({ timing: '截止日期：2026-11-03' }))).toBe(
      new Date('2026-11-03T23:59:00+08:00').getTime(),
    );
    expect(chaoxingWorkDueAt(work({ timing: '剩余2天' }))).toBeNull();
  });
  it('separates overdue, soon, later, undated and completed works', () => {
    expect(chaoxingWorkSection(work({ timing: '截止时间：2026-11-01 23:59' }), now)).toBe(
      'overdue',
    );
    expect(chaoxingWorkSection(work({ timing: '截止时间：2026-11-05 23:59' }), now)).toBe('soon');
    expect(chaoxingWorkSection(work({ timing: '截止时间：2026-12-20 23:59' }), now)).toBe('later');
    expect(chaoxingWorkSection(work({ timing: '剩余2天' }), now)).toBe('undated');
    expect(
      chaoxingWorkSection(work({ status: '已提交', timing: '截止时间：2026-11-01 23:59' }), now),
    ).toBe('done');
  });
  it('summarises pending work and sorts by the nearest deadline with undated works last', () => {
    const items = [
      work({ title: '无时间', timing: '剩余2天' }),
      work({ title: '之后', timing: '截止时间：2026-12-20 23:59' }),
      work({ title: '逾期', timing: '截止时间：2026-11-01 23:59' }),
      work({ title: '已完成', status: '已提交', timing: '截止时间：2026-11-02 23:59' }),
    ];
    expect(chaoxingWorkSummary(items, now)).toEqual({
      total: 4,
      pending: 3,
      done: 1,
      overdue: 1,
      undated: 1,
      ignored: 0,
    });
    expect([...items].sort(chaoxingWorkSort).map((item) => item.title)).toEqual([
      '逾期',
      '已完成',
      '之后',
      '无时间',
    ]);
  });
  it('assembles cached works with course names without inventing deadlines', () => {
    const calendar = chaoxingAssignments(
      {
        syncedAt: '2026-11-03T00:00:00Z',
        items: [{ id: '1:2', name: '示例课程', teacher: '', ended: false }],
      },
      [
        {
          courseId: '1:2',
          syncedAt: '2026-11-03T01:00:00Z',
          items: [
            { id: 'w1', title: '报告', status: '未交', timing: '剩余2天' },
            {
              id: 'w2',
              title: '实验',
              status: '未交',
              timing: '剩余1天',
              detailTiming: '截止时间：2026-11-04 20:00',
            },
          ],
        },
      ],
    );
    expect(calendar.coursesSyncedAt).toBe('2026-11-03T00:00:00Z');
    expect(calendar.courses).toEqual([
      { id: '1:2', name: '示例课程', syncedAt: '2026-11-03T01:00:00Z' },
    ]);
    expect(calendar.works.map((row) => [row.courseName, row.deadline])).toEqual([
      ['示例课程', null],
      ['示例课程', { date: '2026-11-04', time: '20:00' }],
    ]);
  });
});

describe('assignment marks and reminders', () => {
  const now = new Date('2026-11-03T12:00:00+08:00').getTime();
  const work = (overrides: Record<string, unknown> = {}) => ({
    id: 'w',
    title: '作业',
    status: '未交',
    timing: '',
    detailTiming: '截止时间：2026-11-04 08:00',
    ...overrides,
  });
  it('moves ignored works into their own section and out of the pending counts', () => {
    const items = [work({ id: '1' }), work({ id: '2', mutedAt: '2026-11-03T00:00:00Z' })];
    expect(chaoxingWorkSection(items[1]!, now)).toBe('ignored');
    expect(chaoxingWorkSummary(items, now)).toEqual({
      total: 2,
      pending: 1,
      done: 0,
      overdue: 0,
      undated: 0,
      ignored: 1,
    });
  });
  it('only reminds for dated, unfinished, unignored work within 24 hours', () => {
    expect(chaoxingReminderStage(work(), now)).toEqual({
      stage: 'soon',
      dueAt: new Date('2026-11-04T08:00:00+08:00').getTime(),
    });
    expect(chaoxingReminderStage(work(), now + 19 * 3_600_000)).toMatchObject({ stage: 'urgent' });
    expect(chaoxingReminderStage(work(), now + 21 * 3_600_000)).toMatchObject({
      stage: 'overdue',
    });
    for (const value of [
      work({ detailTiming: undefined, timing: '剩余2天' }),
      work({ status: '已提交' }),
      work({ status: 'To be marked' }),
      work({ status: 'reviewd' }),
      work({ mutedAt: '2026-11-03T00:00:00Z' }),
      work({ detailTiming: '截止时间：2026-11-10 08:00' }),
      work({ detailTiming: '截止时间：2026-10-01 08:00' }),
      work({ detailTiming: '截止日期：2026-11-04' }),
    ])
      expect(chaoxingReminderStage(value, now)).toBeNull();
    expect(chaoxingReminderKey(work(), 'soon')).toBe('2026-11-04T08:00|soon');
    expect(chaoxingReminderKey(work(), 'urgent')).not.toBe(chaoxingReminderKey(work(), 'soon'));
    expect(chaoxingReminderKey(work(), 'overdue')).not.toBe(chaoxingReminderKey(work(), 'urgent'));
  });
  it('also reminds when the full deadline is supplied by the list itself', () => {
    const listed = work({ detailTiming: undefined, timing: '截止时间：2026-11-04 08:00' });
    expect(chaoxingReminderStage(listed, now)?.stage).toBe('soon');
    expect(chaoxingReminderKey(listed, 'soon')).toBe('2026-11-04T08:00|soon');
    expect(
      chaoxingReminderKey({ ...listed, timing: '截止时间：2026-11-04 09:00' }, 'soon'),
    ).not.toBe(chaoxingReminderKey(listed, 'soon'));
  });
});
