// @vitest-environment jsdom
import { act } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { afterEach, beforeEach, expect, it, vi } from 'vitest';
import type {
  JluNoticePage,
  JluNoticeSearch,
  JluPlatformResult,
} from '../../../shared/jlu-platforms';
import { SchoolNoticesView, type NoticesPageApi } from './SchoolNoticesView';

const original: JluNoticePage = {
  channel: '179577',
  page: 1,
  totalPages: 2500,
  syncedAt: '2026-11-08T00:00:00.000Z',
  items: [
    {
      id: '1',
      channel: '179577',
      title: '本页通知',
      department: '本科生院',
      published: '2026-11-08',
      pinned: false,
      url: 'https://oa.jlu.edu.cn/?id=1',
    },
  ],
};
const result = (page: number, search: JluNoticeSearch): JluNoticePage => ({
  ...original,
  page,
  totalPages: 3,
  search,
  items: [
    { ...original.items[0]!, id: String(page + 10), title: `${search.query} · 第 ${page} 页结果` },
  ],
});
let host: HTMLDivElement;
let root: Root;
let api: NoticesPageApi;
const sync = vi.fn<NoticesPageApi['syncNotices']>();

beforeEach(async () => {
  vi.stubGlobal('IS_REACT_ACT_ENVIRONMENT', true);
  sync.mockReset().mockImplementation(async (_channel, page, search) => ({
    ok: true,
    data: search ? result(page, search) : original,
  }));
  api = {
    getNotices: vi.fn(async (_channel, _page, search) => (search ? null : original)),
    syncNotices: sync,
    getNotice: vi.fn(async () => null),
    readNotice: vi.fn(),
  };
  host = document.createElement('div');
  document.body.append(host);
  root = createRoot(host);
  await act(async () => root.render(<SchoolNoticesView api={api} />));
});
afterEach(async () => {
  await act(async () => root.unmount());
  host.remove();
  vi.unstubAllGlobals();
});
async function type(query: string, label?: string) {
  await act(async () => {
    const input = host.querySelector<HTMLInputElement>(
      label ? `input[aria-label="${label}"]` : 'form input',
    )!;
    Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value')!.set!.call(input, query);
    input.dispatchEvent(new Event('input', { bubbles: true }));
  });
}
async function select(label: string, value: string) {
  await act(async () => {
    const node = host.querySelector<HTMLSelectElement>(`select[aria-label="${label}"]`)!;
    node.value = value;
    node.dispatchEvent(new Event('change', { bubbles: true }));
  });
}
async function submit() {
  await act(async () => {
    host
      .querySelector('form')!
      .dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));
  });
}

it('searches across all pages and preserves the applied query while paging and opening a new search', async () => {
  await type(' 奖学金 ');
  await submit();
  expect(sync).toHaveBeenLastCalledWith('179577', 1, { query: '奖学金', field: 'title' });
  expect(host.textContent).toContain('奖学金 · 第 1 页结果');
  expect(host.textContent).toContain('全部时间');
  await act(async () =>
    host.querySelector<HTMLButtonElement>('[aria-label="下一页通知"]')!.click(),
  );
  expect(sync).toHaveBeenLastCalledWith('179577', 2, { query: '奖学金', field: 'title' });
  expect(host.textContent).toContain('奖学金 · 第 2 页结果');
  await select('搜索字段', 'department');
  await type('本科生院');
  await submit();
  expect(sync).toHaveBeenLastCalledWith('179577', 1, { query: '本科生院', field: 'department' });
  await act(async () =>
    host.querySelector<HTMLButtonElement>('[aria-label="清除通知筛选"]')!.click(),
  );
  expect(sync).toHaveBeenLastCalledWith('179577', 1, undefined);
  expect(host.textContent).toContain('本页通知');
  expect(host.textContent).not.toContain('全部时间');
});

it('keeps current-page filtering instant and offline', async () => {
  await select('筛选范围', 'page');
  await type(' 本科生院 ');
  expect(host.textContent).toContain('本页通知');
  expect(sync).not.toHaveBeenCalled();
  await type('没有这个关键词');
  expect(host.textContent).toContain('本页没有匹配的通知');
  expect(sync).not.toHaveBeenCalled();
});
it('removes subscription controls even when the desktop API still exposes subscriptions', async () => {
  const getNoticeSubscriptions = vi.fn();
  const desktopApi = { ...api, getNoticeSubscriptions };
  await act(async () => root.render(<SchoolNoticesView api={desktopApi} />));
  expect(host.textContent).not.toContain('订阅');
  expect(getNoticeSubscriptions).not.toHaveBeenCalled();
});

it('supports body keywords through quick search', async () => {
  await select('搜索字段', 'body');
  await type('申请材料');
  await submit();
  expect(sync).toHaveBeenLastCalledWith('179577', 1, { query: '申请材料', field: 'body' });
  expect(host.textContent).toContain('正文：申请材料');
});

it('combines all three conditions, paginates the intersection locally and preserves it after reading', async () => {
  sync.mockImplementation(async (_channel, page, search) => ({
    ok: true,
    data: {
      ...original,
      page,
      totalPages: 3,
      search,
      items: Array.from({ length: page === 3 ? 5 : 30 }, (_, index) => ({
        ...original.items[0]!,
        id: String((page - 1) * 30 + index + 1),
        title: `组合通知 ${(page - 1) * 30 + index + 1}`,
      })),
    },
  }));
  await act(async () =>
    [...host.querySelectorAll<HTMLButtonElement>('button')]
      .find((button) => button.textContent === '组合筛选')!
      .click(),
  );
  await type('本科生院', '筛选组织');
  await type('奖学金', '筛选标题');
  await type('申请材料', '筛选正文');
  await submit();
  expect(sync).toHaveBeenCalledTimes(6);
  expect(sync.mock.calls.every((call) => call[2]?.organization === '本科生院')).toBe(true);
  expect(host.textContent).toContain('组织：本科生院 · 标题：奖学金 · 正文：申请材料 · 65 条结果');
  await act(async () =>
    host.querySelector<HTMLButtonElement>('[aria-label="下一页通知"]')!.click(),
  );
  expect(host.textContent).toContain('组合通知 31');
  expect(sync).toHaveBeenCalledTimes(6);
  const detail = {
    id: '31',
    channel: '179577',
    title: '组合通知 31',
    metadata: '本科生院',
    text: '正文包含申请材料',
    url: 'https://oa.jlu.edu.cn/?id=31',
    syncedAt: original.syncedAt,
    attachments: [],
  };
  vi.mocked(api.getNotice).mockResolvedValueOnce(detail);
  vi.mocked(api.readNotice).mockResolvedValueOnce({ ok: true, data: detail });
  await act(async () =>
    [...host.querySelectorAll<HTMLButtonElement>('button')]
      .find((button) => button.textContent?.includes('组合通知 31'))!
      .click(),
  );
  expect(host.querySelector('h2')?.textContent).toBe('组合通知 31');
  await act(async () =>
    [...host.querySelectorAll<HTMLButtonElement>('button')]
      .find((button) => button.textContent?.includes('返回列表'))!
      .click(),
  );
  expect(host.textContent).toContain('组合通知 31');
  expect(host.textContent).toContain('第 2 / 3 页');
  expect(host.querySelector<HTMLInputElement>('[aria-label="筛选正文"]')?.value).toBe('申请材料');
});

it('allows organization plus body without scanning unrelated title pages', async () => {
  await act(async () =>
    [...host.querySelectorAll<HTMLButtonElement>('button')]
      .find((button) => button.textContent === '组合筛选')!
      .click(),
  );
  await type('本科生院', '筛选组织');
  await type('申请材料', '筛选正文');
  await submit();
  expect(sync).toHaveBeenCalledOnce();
  expect(sync).toHaveBeenLastCalledWith('179577', 1, {
    query: '申请材料',
    field: 'body',
    organization: '本科生院',
  });
});

it('stops a combined query without replacing previous results', async () => {
  let finish!: (value: JluPlatformResult<JluNoticePage>) => void;
  sync.mockImplementationOnce(
    () =>
      new Promise((resolve) => {
        finish = resolve;
      }),
  );
  await act(async () =>
    [...host.querySelectorAll<HTMLButtonElement>('button')]
      .find((button) => button.textContent === '组合筛选')!
      .click(),
  );
  await type('奖学金', '筛选标题');
  await type('申请材料', '筛选正文');
  await submit();
  await act(async () =>
    [...host.querySelectorAll<HTMLButtonElement>('button')]
      .find((button) => button.textContent === '停止筛选')!
      .click(),
  );
  await act(async () => {
    finish({ ok: true, data: result(1, { query: '奖学金', field: 'title' }) });
  });
  expect(sync).toHaveBeenCalledOnce();
  expect(host.textContent).toContain('本页通知');
  expect(host.textContent).not.toContain('奖学金 · 第 1 页结果');
});
it('shows an empty search result and disables paging without reporting a read error', async () => {
  sync.mockImplementationOnce(async (_channel, _page, search) => ({
    ok: true,
    data: { ...result(1, search!), items: [], totalPages: 1 },
  }));
  await type('无匹配');
  await submit();
  expect(host.textContent).toContain('没有找到匹配的通知');
  expect(host.querySelector('[role="alert"]')).toBeNull();
  expect(host.querySelector<HTMLButtonElement>('[aria-label="下一页通知"]')?.disabled).toBe(true);
});

it('keeps the previous results and their search label when a new search fails', async () => {
  await type('奖学金');
  await submit();
  sync.mockResolvedValueOnce({ ok: false, error: '无法连接学校平台' });
  await type('转专业');
  await submit();
  expect(host.querySelector('[role="alert"]')?.textContent).toBe('无法连接学校平台');
  expect(host.textContent).toContain('标题：奖学金');
  expect(host.textContent).toContain('奖学金 · 第 1 页结果');
});

it('does not bring back an in-progress query after the filter is cleared', async () => {
  let finish!: (value: JluPlatformResult<JluNoticePage>) => void;
  sync.mockImplementationOnce(
    () =>
      new Promise((resolve) => {
        finish = resolve;
      }),
  );
  await type('奖学金');
  await submit();
  await act(async () =>
    host.querySelector<HTMLButtonElement>('[aria-label="清除通知筛选"]')!.click(),
  );
  await act(async () => {
    finish({ ok: true, data: result(1, { query: '奖学金', field: 'title' }) });
  });
  expect(host.textContent).toContain('本页通知');
  expect(host.textContent).not.toContain('奖学金 · 第 1 页结果');
});
