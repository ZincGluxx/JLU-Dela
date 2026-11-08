import type { JluNotice, JluPlatformsApi } from '../../../shared/jlu-platforms';

export interface NoticeFilters {
  organization: string;
  title: string;
  body: string;
}

export async function intersectNoticeSearch(
  api: Pick<JluPlatformsApi, 'syncNotices'>,
  filters: NoticeFilters,
  onProgress: (progress: { completed: number; total: number }) => void,
  active: () => boolean,
): Promise<JluNotice[] | null> {
  const searches = (['title', 'body'] as const).map((field) => ({
    query: filters[field],
    field,
    ...(filters.organization ? { organization: filters.organization } : {}),
  }));
  const sources = [];
  let completed = 0;
  let total = 0;
  for (const search of searches) {
    if (!active()) return null;
    const result = await api.syncNotices('179577', 1, search);
    if (!active()) return null;
    if (!result.ok) throw new Error(result.error);
    if (!result.data.items.length) return [];
    if (result.data.totalPages === null)
      throw new Error('学校未返回搜索页数，无法完成组合筛选，请使用快速搜索');
    sources.push({ search, first: result.data, pages: result.data.totalPages });
    total += result.data.totalPages;
    completed += 1;
  }
  onProgress({ completed, total });
  sources.sort((a, b) => a.pages - b.pages);
  const smaller = sources[0]!;
  const larger = sources[1]!;
  const candidates = new Map(
    smaller.first.items.map((item) => [`${item.channel}:${item.id}`, item]),
  );
  for (let page = 2; page <= smaller.pages; page++) {
    if (!active()) return null;
    const result = await api.syncNotices('179577', page, smaller.search);
    if (!active()) return null;
    if (!result.ok) throw new Error(result.error);
    for (const item of result.data.items) candidates.set(`${item.channel}:${item.id}`, item);
    onProgress({ completed: ++completed, total });
  }
  const matched = new Set(
    larger.first.items
      .map((item) => `${item.channel}:${item.id}`)
      .filter((key) => candidates.has(key)),
  );
  for (let page = 2; page <= larger.pages && matched.size < candidates.size; page++) {
    if (!active()) return null;
    const result = await api.syncNotices('179577', page, larger.search);
    if (!active()) return null;
    if (!result.ok) throw new Error(result.error);
    for (const item of result.data.items) {
      const key = `${item.channel}:${item.id}`;
      if (candidates.has(key)) matched.add(key);
    }
    onProgress({ completed: ++completed, total });
  }
  return [...candidates].filter(([key]) => matched.has(key)).map(([, item]) => item);
}
