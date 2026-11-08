import { useEffect, useRef, useState } from 'react';
import { ArrowLeft, ChevronLeft, ChevronRight, RefreshCw, Search, X } from 'lucide-react';
import type {
  JluNoticeDetail,
  JluNoticePage,
  JluPlatformsApi,
  JluNoticeSearch,
  JluNotice,
} from '../../../shared/jlu-platforms';
import { Button } from '../../components/ui/button';
import { Input } from '../../components/ui/input';
import { DesktopOnlyNotice } from '../../components/ui/desktop-only-notice';
import { errorText } from '../../workspace/store';
import { intersectNoticeSearch, type NoticeFilters } from './notice-search';

const searchLabels = { department: '组织', title: '标题', body: '正文' };
const filterLabels = { organization: '组织', title: '标题', body: '正文' };

export type NoticesPageApi = Pick<
  JluPlatformsApi,
  'getNotices' | 'syncNotices' | 'getNotice' | 'readNotice'
> &
  Partial<Pick<JluPlatformsApi, 'openNotice' | 'openAttachment'>>;
export function SchoolNoticesView({
  api = window.dela?.jluPlatforms,
}: { api?: NoticesPageApi } = {}) {
  if (!api)
    return <DesktopOnlyNotice title="学校通知" description="请在桌面应用中同步和保存学校通知。" />;
  return <NoticesPage api={api} />;
}
function NoticesPage({ api }: { api: NoticesPageApi }) {
  const [data, setData] = useState<JluNoticePage | null>(null);
  const [detail, setDetail] = useState<JluNoticeDetail | null>(null);
  const [page, setPage] = useState(1);
  const [query, setQuery] = useState('');
  const [scope, setScope] = useState<'page' | 'all'>('all');
  const [field, setField] = useState<JluNoticeSearch['field']>('title');
  const [mode, setMode] = useState<'quick' | 'combined'>('quick');
  const [filters, setFilters] = useState<NoticeFilters>({ organization: '', title: '', body: '' });
  const [combined, setCombined] = useState<{
    filters: NoticeFilters;
    items: JluNotice[];
    syncedAt: string;
  } | null>(null);
  const [progress, setProgress] = useState<{ completed: number; total: number } | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const request = useRef(0);
  useEffect(() => {
    let active = true;
    void api
      .getNotices('179577', 1)
      .then((value) => {
        if (active) setData(value);
      })
      .catch((reason) => {
        if (active) setError(errorText(reason));
      });
    return () => {
      active = false;
      request.current += 1;
    };
  }, [api]);
  async function sync(next = page, search: JluNoticeSearch | null = data?.search ?? null) {
    const id = ++request.current;
    setBusy(true);
    setError(null);
    setProgress(null);
    try {
      if (
        next !== page ||
        search?.query !== data?.search?.query ||
        search?.field !== data?.search?.field ||
        search?.organization !== data?.search?.organization ||
        combined !== null
      ) {
        const cached = await api.getNotices('179577', next, search ?? undefined);
        if (id !== request.current) return;
        if (cached) {
          setData(cached);
          setPage(next);
          setDetail(null);
          setCombined(null);
        }
      }
      const result = await api.syncNotices('179577', next, search ?? undefined);
      if (id !== request.current) return;
      if (result.ok) {
        setData(result.data);
        setPage(next);
        setDetail(null);
        setCombined(null);
      } else setError(result.error);
    } catch (reason) {
      if (id === request.current) setError(errorText(reason));
    } finally {
      if (id === request.current) setBusy(false);
    }
  }
  async function applyFilters(input: NoticeFilters) {
    const applied = {
      organization: input.organization.trim(),
      title: input.title.trim(),
      body: input.body.trim(),
    };
    if (!applied.title || !applied.body) {
      const query = applied.title || applied.body || applied.organization;
      void sync(
        1,
        query
          ? {
              query,
              field: applied.title ? 'title' : applied.body ? 'body' : 'department',
              ...(applied.organization ? { organization: applied.organization } : {}),
            }
          : null,
      );
      return;
    }
    const id = ++request.current;
    setBusy(true);
    setError(null);
    setProgress({ completed: 0, total: 0 });
    try {
      const items = await intersectNoticeSearch(
        api,
        applied,
        setProgress,
        () => id === request.current,
      );
      if (id !== request.current || items === null) return;
      setCombined({ filters: applied, items, syncedAt: new Date().toISOString() });
      setPage(1);
      setDetail(null);
    } catch (reason) {
      if (id === request.current) setError(errorText(reason));
    } finally {
      if (id === request.current) {
        setBusy(false);
        setProgress(null);
      }
    }
  }
  function clearFilters() {
    setQuery('');
    setFilters({ organization: '', title: '', body: '' });
    if (data?.search || combined || busy) void sync(1, null);
  }
  async function read(id: string, channel: string) {
    const revision = ++request.current;
    setBusy(true);
    setError(null);
    try {
      const cached = await api.getNotice(id, channel);
      if (revision !== request.current) return;
      setDetail(cached);
      const result = await api.readNotice(id, channel);
      if (revision !== request.current) return;
      if (result.ok) setDetail(result.data);
      else setError(result.error);
    } catch (reason) {
      setError(errorText(reason));
    } finally {
      if (revision === request.current) setBusy(false);
    }
  }
  const notices = (
    combined ? combined.items.slice((page - 1) * 30, page * 30) : (data?.items ?? [])
  ).filter(
    (item) =>
      mode === 'combined' ||
      scope === 'all' ||
      `${item.title} ${item.department}`.toLowerCase().includes(query.trim().toLowerCase()),
  );
  const totalPages = combined
    ? Math.max(1, Math.ceil(combined.items.length / 30))
    : (data?.totalPages ?? null);
  const appliedLabels = combined
    ? (['organization', 'title', 'body'] as const)
        .filter((key) => combined.filters[key])
        .map((key) => `${filterLabels[key]}：${combined.filters[key]}`)
    : data?.search
      ? [
          ...(data.search.organization ? [`组织：${data.search.organization}`] : []),
          ...(data.search.field === 'department' && data.search.query === data.search.organization
            ? []
            : [`${searchLabels[data.search.field]}：${data.search.query}`]),
        ]
      : [];
  return (
    <div className="min-h-0 flex-1 overflow-y-auto bg-surface">
      <div className="mx-auto grid w-full max-w-4xl gap-6 px-6 py-8 md:px-10">
        <header className="flex flex-wrap items-center justify-between gap-3">
          <div className="min-w-0">
            <h1 className="text-xl font-semibold text-ink">学校通知</h1>
            <p className="mt-1 text-xs text-ink-2">
              电子校务 · 校内通知
              {combined || data
                ? ` · 更新于 ${new Date((combined ?? data)!.syncedAt).toLocaleString('zh-CN')}`
                : ' · 尚未同步'}
            </p>
          </div>
          <Button
            disabled={busy}
            size="sm"
            onClick={() => (combined ? void applyFilters(combined.filters) : void sync())}
          >
            <RefreshCw className={busy ? 'size-4 animate-spin' : 'size-4'} />
            {busy ? '正在读取…' : '刷新通知'}
          </Button>
        </header>
        {error && (
          <p role="alert" className="rounded-control bg-field p-3 text-13 text-ink">
            {error}
          </p>
        )}
        {detail ? (
          <article className="grid min-w-0 gap-4">
            <div className="flex flex-wrap gap-2">
              <Button size="sm" variant="ghost" disabled={busy} onClick={() => setDetail(null)}>
                <ArrowLeft className="size-4" />
                返回列表
              </Button>
              {api.openNotice && (
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() =>
                    void api.openNotice!(detail.id, detail.channel).catch((reason) =>
                      setError(errorText(reason)),
                    )
                  }
                >
                  学校原文
                </Button>
              )}
            </div>
            <h2 className="break-words text-lg font-semibold text-ink">{detail.title}</h2>
            <p className="whitespace-pre-wrap text-xs text-ink-2">{detail.metadata}</p>
            <div className="whitespace-pre-wrap break-words text-sm leading-relaxed text-ink">
              {detail.text}
            </div>
            {detail.attachments.length > 0 && (
              <section className="grid gap-2">
                <h3 className="text-sm font-semibold">附件</h3>
                {detail.attachments.map((attachment, index) => (
                  <Button
                    disabled={!api.openAttachment}
                    className="h-auto justify-start whitespace-normal break-all text-left"
                    key={`${attachment.url}:${index}`}
                    variant="outline"
                    onClick={() =>
                      void api.openAttachment!(detail.id, detail.channel, index).catch((reason) =>
                        setError(errorText(reason)),
                      )
                    }
                  >
                    {attachment.name}
                  </Button>
                ))}
              </section>
            )}
            {!api.openAttachment && (
              <p className="text-xs text-ink-2">学校原文与附件请在本机 Dela 中打开。</p>
            )}
            <p className="text-xs text-ink-2">
              正文缓存于 {new Date(detail.syncedAt).toLocaleString('zh-CN')}
            </p>
          </article>
        ) : (
          <>
            <form
              className="grid min-w-0 gap-3"
              aria-label="通知筛选"
              onSubmit={(event) => {
                event.preventDefault();
                if (mode === 'combined') void applyFilters(filters);
                else if (scope === 'all')
                  void sync(1, query.trim() ? { query: query.trim(), field } : null);
              }}
            >
              <div role="group" aria-label="筛选方式" className="flex flex-wrap gap-1">
                <Button
                  size="sm"
                  variant={mode === 'quick' ? 'secondary' : 'ghost'}
                  aria-pressed={mode === 'quick'}
                  onClick={() => setMode('quick')}
                >
                  快速搜索
                </Button>
                <Button
                  size="sm"
                  variant={mode === 'combined' ? 'secondary' : 'ghost'}
                  aria-pressed={mode === 'combined'}
                  onClick={() => {
                    setMode('combined');
                    setScope('all');
                  }}
                >
                  组合筛选
                </Button>
              </div>
              {mode === 'quick' ? (
                <div className="flex min-w-0 flex-wrap items-center gap-2">
                  <select
                    aria-label="筛选范围"
                    className="h-8 min-w-0 rounded-control bg-field px-2 text-13 text-ink"
                    value={scope}
                    onChange={(event) => {
                      setScope(event.target.value as 'all' | 'page');
                      if (data?.search || combined || busy) void sync(1, null);
                    }}
                  >
                    <option value="all">全部通知</option>
                    <option value="page">当前页</option>
                  </select>
                  {scope === 'all' && (
                    <select
                      aria-label="搜索字段"
                      className="h-8 min-w-0 rounded-control bg-field px-2 text-13 text-ink"
                      value={field}
                      onChange={(event) => setField(event.target.value as JluNoticeSearch['field'])}
                    >
                      <option value="department">组织</option>
                      <option value="title">标题</option>
                      <option value="body">正文</option>
                    </select>
                  )}
                  <div className="flex min-w-0 basis-full items-center gap-2 md:basis-auto md:flex-1">
                    <Input
                      className="min-w-0 flex-1"
                      aria-label={scope === 'all' ? '搜索全部通知' : '筛选本页通知'}
                      value={query}
                      maxLength={200}
                      onChange={(event) => setQuery(event.target.value)}
                      placeholder={
                        scope === 'page' ? '筛选本页标题或组织' : `输入${searchLabels[field]}关键词`
                      }
                    />
                    {scope === 'all' && (
                      <Button type="submit" disabled={busy}>
                        <Search className="size-4" />
                        搜索
                      </Button>
                    )}
                    {(query || data?.search || combined) && (
                      <Button
                        size="icon"
                        variant="ghost"
                        aria-label="清除通知筛选"
                        title="清除筛选"
                        onClick={clearFilters}
                      >
                        <X className="size-4" />
                      </Button>
                    )}
                  </div>
                </div>
              ) : (
                <>
                  <div className="grid min-w-0 gap-3 md:grid-cols-3">
                    {(['organization', 'title', 'body'] as const).map((key) => (
                      <label key={key} className="grid min-w-0 gap-2 text-xs text-ink-2">
                        {filterLabels[key]}
                        <Input
                          aria-label={`筛选${filterLabels[key]}`}
                          value={filters[key]}
                          maxLength={200}
                          list={key === 'organization' ? 'notice-organizations' : undefined}
                          placeholder={
                            key === 'organization'
                              ? '完整组织名称，可留空'
                              : `${filterLabels[key]}关键词，可留空`
                          }
                          onChange={(event) =>
                            setFilters({ ...filters, [key]: event.target.value })
                          }
                        />
                      </label>
                    ))}
                    <datalist id="notice-organizations">
                      {[...new Set(data?.items.map((item) => item.department).filter(Boolean))].map(
                        (organization) => (
                          <option key={organization} value={organization} />
                        ),
                      )}
                    </datalist>
                  </div>
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <p className="text-xs text-ink-2">
                      全部通知 · 全部时间 · 已填写的条件需全部满足
                    </p>
                    <div className="flex gap-2">
                      <Button variant="ghost" onClick={clearFilters}>
                        清除
                      </Button>
                      <Button
                        type="submit"
                        disabled={busy || !Object.values(filters).some((value) => value.trim())}
                      >
                        <Search className="size-4" />
                        筛选
                      </Button>
                    </div>
                  </div>
                </>
              )}
            </form>
            {busy && (
              <div className="flex flex-wrap items-center gap-2 text-xs text-ink-2" role="status">
                <span>
                  {progress
                    ? progress.total
                      ? `正在组合筛选 · 已检查 ${progress.completed} / ${progress.total} 页`
                      : '正在读取筛选范围…'
                    : '正在读取通知…'}
                </span>
                {progress && (
                  <Button
                    size="sm"
                    variant="ghost"
                    onClick={() => {
                      request.current += 1;
                      setBusy(false);
                      setProgress(null);
                    }}
                  >
                    停止筛选
                  </Button>
                )}
              </div>
            )}
            {appliedLabels.length > 0 && (
              <p className="break-words text-xs text-ink-2">
                全部通知 · 全部时间 · {appliedLabels.join(' · ')}
                {combined ? ` · ${combined.items.length} 条结果` : ''}
              </p>
            )}
            {!data && !combined && (
              <p className="py-8 text-13 text-ink-2">
                点击「刷新通知」读取学校列表，已读取的通知会保存在本机。
              </p>
            )}
            {(data || combined) && (
              <div className="grid gap-1">
                {notices.map((item) => (
                  <button
                    key={item.id}
                    className="grid min-w-0 gap-2 rounded-control p-3 text-left hover:bg-hover disabled:opacity-50"
                    disabled={busy}
                    onClick={() => void read(item.id, item.channel)}
                  >
                    <span className="break-words text-sm text-ink">
                      {item.pinned && <span className="mr-2 text-xs text-ink-2">置顶</span>}
                      {item.title}
                    </span>
                    <span className="flex flex-wrap gap-x-3 text-xs text-ink-2">
                      <span>{item.department}</span>
                      <span>{item.published}</span>
                    </span>
                  </button>
                ))}
                {!busy && !notices.length && (
                  <p className="py-6 text-13 text-ink-2">
                    {data?.search || combined ? '没有找到匹配的通知。' : '本页没有匹配的通知。'}
                  </p>
                )}
              </div>
            )}
            {(data || combined) && (
              <footer className="flex flex-wrap items-center justify-between gap-3 text-xs text-ink-2">
                <span>
                  第 {page}
                  {totalPages ? ` / ${totalPages}` : ''} 页 ·{' '}
                  {combined || data?.search
                    ? '搜索结果'
                    : scope === 'page'
                      ? '仅筛选当前页'
                      : '通知列表'}
                </span>
                <div className="flex gap-2">
                  <Button
                    aria-label="上一页通知"
                    size="icon-sm"
                    variant="outline"
                    disabled={busy || page === 1}
                    onClick={() => (combined ? setPage(page - 1) : void sync(page - 1))}
                  >
                    <ChevronLeft />
                  </Button>
                  <Button
                    aria-label="下一页通知"
                    size="icon-sm"
                    variant="outline"
                    disabled={busy || (totalPages !== null && page >= totalPages)}
                    onClick={() => (combined ? setPage(page + 1) : void sync(page + 1))}
                  >
                    <ChevronRight />
                  </Button>
                </div>
              </footer>
            )}
          </>
        )}
      </div>
    </div>
  );
}
