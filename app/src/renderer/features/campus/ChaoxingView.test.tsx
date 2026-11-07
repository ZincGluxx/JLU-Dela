// @vitest-environment jsdom
import { act } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { afterEach, beforeEach, expect, it, vi } from 'vitest';
import type { ChaoxingCourses } from '../../../shared/chaoxing';
import { ChaoxingView, type ChaoxingPageApi } from './ChaoxingView';

let host: HTMLDivElement, root: Root, api: ChaoxingPageApi, catalog: ChaoxingCourses;
beforeEach(() => {
  vi.stubGlobal('IS_REACT_ACT_ENVIRONMENT', true);
  host = document.createElement('div');
  document.body.appendChild(host);
  root = createRoot(host);
  catalog = {
    items: [
      { id: 'a', name: '本学期课程', teacher: '教师甲', ended: false },
      { id: 'b', name: '已结课课程', teacher: '教师乙', ended: true },
    ],
    syncedAt: '2026-11-07T00:00:00Z',
    retainedCourseIds: ['a'],
  };
  api = {
    courses: vi.fn(async () => catalog),
    syncCourses: vi.fn(async () => ({ ok: true as const, data: catalog })),
    setRetainedCourses: vi.fn(async (ids) => {
      catalog = { ...catalog, retainedCourseIds: ids };
      return catalog;
    }),
    setCourseRemark: vi.fn(async (id, remark) => {
      catalog = {
        ...catalog,
        items: catalog.items.map((row) =>
          row.id === id ? { ...row, remark: remark.trim() || undefined } : row,
        ),
      };
      return catalog;
    }),
    files: vi.fn(async () => null),
    works: vi.fn(async () => null),
    syncFiles: vi.fn(async () => ({ ok: false as const, error: '未同步' })),
    syncWorks: vi.fn(async () => ({ ok: false as const, error: '未同步' })),
  };
});
afterEach(() => {
  act(() => root.unmount());
  host.remove();
  vi.unstubAllGlobals();
});
const button = (label: string) =>
  [...host.querySelectorAll('button')].find((item) => item.textContent?.trim() === label)!;
const checkbox = (name: string) =>
  host.querySelector<HTMLInputElement>(`input[aria-label="保留 ${name}"]`)!;
const mount = () =>
  act(async () => {
    root.render(<ChaoxingView api={api} />);
  });

it('keeps only selected course cards and lets users retain an ended course instead', async () => {
  await mount();
  expect(host.textContent).toContain('本学期课程');
  expect(host.textContent).not.toContain('已结课课程');
  await act(async () => button('管理课程').click());
  expect(checkbox('本学期课程').checked).toBe(true);
  expect(checkbox('已结课课程').checked).toBe(false);
  await act(async () => {
    checkbox('本学期课程').click();
    checkbox('已结课课程').click();
  });
  await act(async () => button('保存课程选择').click());
  expect(api.setRetainedCourses).toHaveBeenCalledWith(['b']);
  expect(host.textContent).toContain('已保留课程 · 1 门');
  expect(host.textContent).toContain('已结课课程');
  expect(host.textContent).not.toContain('本学期课程');
  expect(api.syncWorks).not.toHaveBeenCalled();
  expect(api.syncFiles).not.toHaveBeenCalled();
  await act(async () => button('管理课程').click());
  expect(checkbox('本学期课程').checked).toBe(false);
  expect(checkbox('已结课课程').checked).toBe(true);
});

it('cancels draft changes and supports retaining no courses', async () => {
  await mount();
  await act(async () => button('管理课程').click());
  await act(async () => checkbox('本学期课程').click());
  await act(async () => button('取消').click());
  expect(api.setRetainedCourses).not.toHaveBeenCalled();
  expect(host.textContent).toContain('本学期课程');
  await act(async () => button('管理课程').click());
  expect(checkbox('本学期课程').checked).toBe(true);
  await act(async () => checkbox('本学期课程').click());
  await act(async () => button('保存课程选择').click());
  expect(api.setRetainedCourses).toHaveBeenCalledWith([]);
  expect(host.textContent).toContain('尚未保留课程');
  expect(host.textContent).not.toContain('已结课课程');
});

it('offers course selection after the first sync without importing every course', async () => {
  catalog.retainedCourseIds = [];
  vi.mocked(api.courses).mockResolvedValueOnce(null);
  await mount();
  await act(async () => button('登录并同步').click());
  expect(host.querySelector('[aria-label="选择保留的课程"]')).not.toBeNull();
  expect(checkbox('本学期课程').checked).toBe(false);
  expect(checkbox('已结课课程').checked).toBe(false);
  expect(api.setRetainedCourses).not.toHaveBeenCalled();
  expect(api.syncWorks).not.toHaveBeenCalled();
});

it('keeps selections when filtering and leaves failed saves editable', async () => {
  await mount();
  await act(async () => button('管理课程').click());
  await act(async () => {
    const input = host.querySelector<HTMLInputElement>('[aria-label="搜索可保留课程"]')!;
    Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value')!.set!.call(
      input,
      '教师乙',
    );
    input.dispatchEvent(new Event('input', { bubbles: true }));
  });
  expect(checkbox('本学期课程')).toBeNull();
  await act(async () => checkbox('已结课课程').click());
  vi.mocked(api.setRetainedCourses!).mockRejectedValueOnce(new Error('保存失败'));
  await act(async () => button('保存课程选择').click());
  expect(api.setRetainedCourses).toHaveBeenCalledWith(['a', 'b']);
  expect(host.querySelector('[role="alert"]')!.textContent).toBe('保存失败');
  expect(checkbox('已结课课程').checked).toBe(true);
  await act(async () => button('保存课程选择').click());
  expect(host.textContent).toContain('已保留课程 · 2 门');
});

const remarkInput = () => document.querySelector<HTMLInputElement>('[aria-label="课程备注名"]')!;
const saveRemark = () =>
  [...document.querySelectorAll<HTMLButtonElement>('[role="dialog"] button')].find(
    (item) => item.textContent === '保存备注',
  )!;
const enterRemark = (value: string) =>
  act(async () => {
    Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value')!.set!.call(
      remarkInput(),
      value,
    );
    remarkInput().dispatchEvent(new Event('input', { bubbles: true }));
  });

it('edits a local remark, keeps the original name visible and finds both names in search', async () => {
  await mount();
  await act(async () =>
    host.querySelector<HTMLButtonElement>('[aria-label="备注 本学期课程"]')!.click(),
  );
  await enterRemark('安卓课');
  await act(async () => saveRemark().click());
  expect(api.setCourseRemark).toHaveBeenCalledWith('a', '安卓课');
  expect(host.querySelector('h2')!.textContent).toBe('安卓课');
  expect(host.textContent).toContain('原名：本学期课程');
  expect(document.querySelector('[role="dialog"]')).toBeNull();
  for (const query of ['安卓课', '本学期课程']) {
    await act(async () => {
      const input = host.querySelector<HTMLInputElement>('[aria-label="筛选学习通课程"]')!;
      Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value')!.set!.call(input, query);
      input.dispatchEvent(new Event('input', { bubbles: true }));
    });
    expect(host.querySelector('h2')!.textContent).toBe('安卓课');
  }
  await act(async () => button('管理课程').click());
  await act(async () =>
    host.querySelector<HTMLButtonElement>('[aria-label="备注 本学期课程"]')!.click(),
  );
  expect(remarkInput().value).toBe('安卓课');
  await enterRemark('');
  await act(async () => saveRemark().click());
  expect(checkbox('本学期课程').checked).toBe(true);
  expect(host.textContent).not.toContain('安卓课');
  expect(host.textContent).toContain('本学期课程');
});

it('keeps failed remark edits open and cancels without changing the course', async () => {
  await mount();
  await act(async () =>
    host.querySelector<HTMLButtonElement>('[aria-label="备注 本学期课程"]')!.click(),
  );
  await enterRemark('安卓课');
  vi.mocked(api.setCourseRemark!).mockRejectedValueOnce(new Error('备注保存失败'));
  await act(async () => saveRemark().click());
  expect(document.querySelector('[role="dialog"] [role="alert"]')!.textContent).toBe(
    '备注保存失败',
  );
  expect(remarkInput().value).toBe('安卓课');
  await act(async () =>
    [...document.querySelectorAll<HTMLButtonElement>('[role="dialog"] button')]
      .find((item) => item.textContent === '取消')!
      .click(),
  );
  expect(document.querySelector('[role="dialog"]')).toBeNull();
  expect(host.querySelector('h2')!.textContent).toBe('本学期课程');
});
