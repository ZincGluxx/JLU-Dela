import { expect, it, vi } from 'vitest';
import type {
  JluNoticePage,
  JluNoticeSearch,
  JluPlatformsApi,
  JluPlatformResult,
} from '../../../shared/jlu-platforms';
import { intersectNoticeSearch } from './notice-search';

const filters = { organization: '本科生院', title: '奖学金', body: '申请材料' };
function page(
  ids: string[],
  current: number,
  totalPages: number | null,
  search?: JluNoticeSearch,
): JluNoticePage {
  return {
    channel: '179577',
    page: current,
    totalPages,
    syncedAt: '2026-11-08T00:00:00.000Z',
    search,
    items: ids.map((id) => ({
      id,
      channel: '179577',
      title: `通知${id}`,
      department: '本科生院',
      published: '2026-11-08',
      pinned: false,
      url: `https://oa.jlu.edu.cn/?id=${id}`,
    })),
  };
}

it('intersects title and body across every result page while retaining the organization condition', async () => {
  const syncNotices = vi.fn<JluPlatformsApi['syncNotices']>(async (_channel, current, search) => ({
    ok: true,
    data:
      search?.field === 'title'
        ? page(current === 1 ? ['1', '2'] : ['2', '3'], current, 2, search)
        : page(current === 1 ? ['9', '3'] : current === 2 ? ['1'] : ['8'], current, 3, search),
  }));
  const progress = vi.fn();
  const result = await intersectNoticeSearch({ syncNotices }, filters, progress, () => true);
  expect(result?.map((item) => item.id)).toEqual(['1', '3']);
  expect(syncNotices).toHaveBeenCalledTimes(5);
  expect(syncNotices.mock.calls.every((call) => call[2]?.organization === '本科生院')).toBe(true);
  expect(progress).toHaveBeenLastCalledWith({ completed: 5, total: 5 });
});

it('finishes early once every candidate from the smaller result set is confirmed', async () => {
  const syncNotices = vi.fn<JluPlatformsApi['syncNotices']>(async (_channel, current, search) => ({
    ok: true,
    data:
      search?.field === 'body'
        ? page(['1', '2'], current, 1, search)
        : page(current === 1 ? ['1'] : ['2'], current, 7, search),
  }));
  expect(
    (await intersectNoticeSearch({ syncNotices }, filters, vi.fn(), () => true))?.map(
      (item) => item.id,
    ),
  ).toEqual(['1', '2']);
  expect(syncNotices).toHaveBeenCalledTimes(3);
});

it('stops fetching after cancellation and does not return partial results as complete', async () => {
  let active = true;
  let resolve!: (result: JluPlatformResult<JluNoticePage>) => void;
  const syncNotices = vi.fn<JluPlatformsApi['syncNotices']>(
    () =>
      new Promise((done) => {
        resolve = done;
      }),
  );
  const result = intersectNoticeSearch({ syncNotices }, filters, vi.fn(), () => active);
  active = false;
  resolve({ ok: true, data: page(['1'], 1, 2) });
  expect(await result).toBeNull();
  expect(syncNotices).toHaveBeenCalledTimes(1);
});

it('reports a failed page and missing page counts instead of returning an incomplete intersection', async () => {
  const syncNotices = vi
    .fn<JluPlatformsApi['syncNotices']>()
    .mockResolvedValueOnce({ ok: true, data: page(['1'], 1, 2) })
    .mockResolvedValueOnce({ ok: true, data: page(['2'], 1, 3) })
    .mockResolvedValueOnce({ ok: false, error: '网络不可用' });
  await expect(
    intersectNoticeSearch({ syncNotices }, filters, vi.fn(), () => true),
  ).rejects.toThrow('网络不可用');
  syncNotices.mockResolvedValueOnce({ ok: true, data: page(['1'], 1, null) });
  await expect(
    intersectNoticeSearch({ syncNotices }, filters, vi.fn(), () => true),
  ).rejects.toThrow('未返回搜索页数');
});

it('returns an empty intersection as soon as one complete condition has no results', async () => {
  const syncNotices = vi
    .fn<JluPlatformsApi['syncNotices']>()
    .mockResolvedValue({ ok: true, data: page([], 1, 1) });
  expect(await intersectNoticeSearch({ syncNotices }, filters, vi.fn(), () => true)).toEqual([]);
  expect(syncNotices).toHaveBeenCalledTimes(1);
});
