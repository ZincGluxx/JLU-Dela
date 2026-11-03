// @vitest-environment jsdom
import { act } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { ChaoxingCalendar } from '../../../shared/chaoxing-calendar';
import { ChaoxingWorkBoard, type ChaoxingWorkBoardApi } from './ChaoxingWorkBoard';

const now = new Date('2026-11-03T02:00:00Z').getTime();
const assignments: ChaoxingCalendar = {
  coursesSyncedAt: '2026-11-03T00:00:00Z',
  courses: [
    { id: 'a', name: '软件工程', syncedAt: '2026-11-03T00:00:00Z' },
    { id: 'b', name: '计算机网络', syncedAt: '2026-11-03T00:00:00Z' },
    { id: 'c', name: '数据库', syncedAt: null },
  ],
  works: [
    {
      id: '1',
      courseId: 'a',
      courseName: '软件工程',
      title: '逾期报告',
      status: '未交',
      timing: '截止时间：2026-11-01 23:59',
      syncedAt: '2026-11-03T00:00:00Z',
      deadline: { date: '2026-11-01', time: '23:59' },
    },
    {
      id: '2',
      courseId: 'b',
      courseName: '计算机网络',
      title: '本周实验',
      status: '未交',
      timing: '截止时间：2026-11-05 23:59',
      syncedAt: '2026-11-03T00:00:00Z',
      deadline: { date: '2026-11-05', time: '23:59' },
    },
    {
      id: '3',
      courseId: 'a',
      courseName: '软件工程',
      title: '期末大作业',
      status: '未交',
      timing: '截止时间：2026-12-20 23:59',
      syncedAt: '2026-11-03T00:00:00Z',
      deadline: { date: '2026-12-20', time: '23:59' },
    },
    {
      id: '4',
      courseId: 'b',
      courseName: '计算机网络',
      title: '时段待确认的作业',
      status: '未交',
      timing: '剩余2天',
      syncedAt: '2026-11-03T00:00:00Z',
      deadline: null,
    },
    {
      id: '5',
      courseId: 'a',
      courseName: '软件工程',
      title: '已交报告',
      status: '已提交',
      timing: '截止日期：2026-10-28',
      syncedAt: '2026-11-03T00:00:00Z',
      deadline: { date: '2026-10-28', time: null },
    },
  ],
};
let host: HTMLDivElement, root: Root, api: ChaoxingWorkBoardApi;
beforeEach(() => {
  vi.stubGlobal('IS_REACT_ACT_ENVIRONMENT', true);
  host = document.createElement('div');
  document.body.appendChild(host);
  root = createRoot(host);
  api = {
    courses: vi.fn(async () => null),
    works: vi.fn(async () => null),
    calendar: vi.fn(async () => assignments),
    syncCalendar: vi.fn(async () => ({ data: assignments, failures: [] })),
    syncWorks: vi.fn(async () => ({ ok: true as const, data: null as never })),
    openWorksPage: vi.fn(async () => {}),
  };
});
afterEach(() => {
  act(() => root.unmount());
  host.remove();
  vi.restoreAllMocks();
});
const button = (label: string) =>
  [...host.querySelectorAll('button')].find((b) => b.textContent?.trim() === label)!;
const mount = () =>
  act(async () => {
    root.render(<ChaoxingWorkBoard api={api} now={now} onOpenCourse={() => {}} />);
    await new Promise((resolve) => setTimeout(resolve, 0));
  });

describe('学习通作业看板', () => {
  it('groups pending works by deadline and keeps completed works behind the filter', async () => {
    await mount();
    expect(host.querySelector('[aria-label="已过截止时间"]')?.textContent).toContain('逾期报告');
    expect(host.querySelector('[aria-label="7 天内截止"]')?.textContent).toContain('本周实验');
    expect(host.querySelector('[aria-label="之后截止"]')?.textContent).toContain('期末大作业');
    expect(host.querySelector('[aria-label="截止时间待确认"]')?.textContent).toContain(
      '时段待确认的作业',
    );
    expect(host.textContent).not.toContain('已交报告');
    expect(host.textContent).toContain('待完成 4 份');
    await act(async () => button('全部').click());
    expect(host.querySelector('[aria-label="已完成 / 已批阅"]')?.textContent).toContain('已交报告');
    await act(async () => button('已完成').click());
    expect(host.textContent).not.toContain('逾期报告');
    expect(host.textContent).toContain('已交报告');
  });

  it('filters by course and keyword without losing the summary', async () => {
    await mount();
    const select = host.querySelector<HTMLSelectElement>('[aria-label="筛选课程"]')!;
    expect([...select.options].map((option) => option.textContent)).toEqual([
      '全部课程',
      '软件工程',
      '计算机网络',
    ]);
    await act(async () => {
      select.value = 'b';
      select.dispatchEvent(new Event('change', { bubbles: true }));
    });
    expect(host.textContent).toContain('本周实验');
    expect(host.textContent).not.toContain('逾期报告');
    await act(async () => {
      const input = host.querySelector<HTMLInputElement>('[aria-label="搜索作业"]')!;
      Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value')!.set!.call(
        input,
        '不存在的作业',
      );
      input.dispatchEvent(new Event('input', { bubbles: true }));
    });
    expect(host.textContent).toContain('没有匹配的作业。');
  });

  it('syncs all courses on demand, surfaces failures and retries a single course', async () => {
    (api.syncCalendar as unknown as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
      data: assignments,
      failures: [{ courseId: 'b', error: '网络超时' }],
    });
    await mount();
    expect(api.syncCalendar).not.toHaveBeenCalled();
    await act(async () => button('同步全部作业').click());
    expect(api.syncCalendar).toHaveBeenCalledTimes(1);
    expect(host.textContent).toContain('网络超时');
    expect(host.textContent).toContain('计算机网络');
    (api.syncWorks as unknown as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
      ok: true,
      data: null,
    });
    await act(async () => button('重试').click());
    expect(api.syncWorks).toHaveBeenCalledWith('b');
    expect(host.textContent).not.toContain('网络超时');
  });

  it('opens the platform homework page for the same course', async () => {
    await mount();
    const row = host.querySelector('[aria-label="7 天内截止"]')!;
    const open = [...row.querySelectorAll('button')].find(
      (item) => item.textContent?.trim() === '打开课程作业页',
    )!;
    await act(async () => open.click());
    expect(api.openWorksPage).toHaveBeenCalledWith('b');
  });
});
