import { describe, it, expect } from 'vitest';
import {
  chaoxingAssignments,
  chaoxingDeadline,
  chaoxingWorkCompleted,
  chaoxingWorkDueAt,
  chaoxingWorkSection,
  chaoxingWorkSort,
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
});

describe('assignment board grouping', () => {
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
