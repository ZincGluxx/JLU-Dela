import { useEffect, useState } from 'react';
import { Dialog } from 'radix-ui';
import { ArrowLeft, BookOpen, Download, FileText, Folder, RefreshCw, Search } from 'lucide-react';
import type {
  ChaoxingCourse,
  ChaoxingCourses,
  ChaoxingFolder,
  ChaoxingWorks,
  ChaoxingApi,
} from '../../../shared/chaoxing';
import type { KnowledgeState } from '../../../shared/knowledge';
import { chaoxingCourseLabel } from '../../../shared/chaoxing';
import {
  chaoxingWorkSort,
  chaoxingWorkStatus,
  chaoxingWorkSummary,
  chaoxingWorkTime,
} from '../../../shared/chaoxing-calendar';
import { Button } from '../../components/ui/button';
import { Input } from '../../components/ui/input';
import { dialogOverlay, dialogPanel } from '../../components/ui/motion';
import { cn } from '../../lib/utils';
import { SegmentedControl } from '../../components/ui/beautifului/atoms/SegmentedControl';
import { DesktopOnlyNotice } from '../../components/ui/desktop-only-notice';
import { useNavigationStore } from '../../navigation/view';
import { errorText } from '../../workspace/store';
import { ChaoxingWorkBoard } from './ChaoxingWorkBoard';

export type ChaoxingPageApi = Omit<
  ChaoxingApi,
  | 'importFile'
  | 'calendar'
  | 'syncCalendar'
  | 'bindCourse'
  | 'linkFile'
  | 'openFilesPage'
  | 'openWorksPage'
  | 'markWork'
  | 'reminders'
  | 'setReminders'
  | 'checkReminders'
  | 'onOpenWork'
  | 'setRetainedCourses'
  | 'setCourseRemark'
> &
  Partial<
    Pick<
      ChaoxingApi,
      | 'importFile'
      | 'calendar'
      | 'syncCalendar'
      | 'bindCourse'
      | 'linkFile'
      | 'openFilesPage'
      | 'openWorksPage'
      | 'markWork'
      | 'reminders'
      | 'setReminders'
      | 'checkReminders'
      | 'onOpenWork'
      | 'setRetainedCourses'
      | 'setCourseRemark'
    >
  >;
export function ChaoxingView({ api = window.dela?.chaoxing }: { api?: ChaoxingPageApi } = {}) {
  return api ? (
    <ChaoxingPage api={api} />
  ) : (
    <DesktopOnlyNotice title="学习通" description="请在桌面应用中登录并同步课程资料与作业。" />
  );
}
function ChaoxingPage({ api }: { api: ChaoxingPageApi }) {
  const [now, setNow] = useState(Date.now);
  useEffect(() => {
    const timer = window.setInterval(() => setNow(Date.now()), 60_000);
    return () => window.clearInterval(timer);
  }, []);
  const [data, setData] = useState<ChaoxingCourses | null>(null);
  const [course, setCourse] = useState<ChaoxingCourse | null>(null);
  const [files, setFiles] = useState<ChaoxingFolder | null>(null);
  const [works, setWorks] = useState<ChaoxingWorks | null>(null);
  const [tab, setTab] = useState<'资料' | '作业'>('资料');
  const [mode, setMode] = useState<'课程' | '作业'>('课程');
  const [path, setPath] = useState<{ id: string; name: string }[]>([]);
  const [query, setQuery] = useState('');
  const [managingCourses, setManagingCourses] = useState(false);
  const [selectedCourses, setSelectedCourses] = useState<string[]>([]);
  const [remarkCourse, setRemarkCourse] = useState<ChaoxingCourse | null>(null);
  const [remark, setRemark] = useState('');
  const [remarkError, setRemarkError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [knowledge, setKnowledge] = useState<KnowledgeState>({ roots: [], courses: [] });
  useEffect(() => {
    let active = true;
    if (course && api.bindCourse && window.dela?.knowledge)
      void window.dela.knowledge
        .state()
        .then((value) => {
          if (active) setKnowledge(value);
        })
        .catch(() => {
          if (active) setError('无法读取本地课程，请稍后重试');
        });
    return () => {
      active = false;
    };
  }, [course?.id, api]);
  useEffect(() => {
    let active = true;
    void api
      .courses()
      .then((value) => {
        if (active) setData(value);
      })
      .catch((cause) => {
        if (active) setError(errorText(cause));
      });
    return () => {
      active = false;
    };
  }, [api]);
  async function syncCourses() {
    setBusy(true);
    setError(null);
    try {
      const result = await api.syncCourses();
      if (result.ok) {
        setData(result.data);
        if (api.setRetainedCourses && !result.data.retainedCourseIds?.length) {
          setSelectedCourses([]);
          setManagingCourses(true);
        }
      } else setError(result.error);
    } catch (cause) {
      setError(errorText(cause));
    } finally {
      setBusy(false);
    }
  }
  async function manageCourses() {
    setBusy(true);
    setError(null);
    try {
      const latest = await api.courses();
      setData(latest);
      setSelectedCourses(
        latest?.items
          .filter((row) => !latest.retainedCourseIds || latest.retainedCourseIds.includes(row.id))
          .map((row) => row.id) ?? [],
      );
      setQuery('');
      setManagingCourses(true);
    } catch (cause) {
      setError(errorText(cause));
    } finally {
      setBusy(false);
    }
  }
  async function saveCourses() {
    if (!api.setRetainedCourses) return;
    setBusy(true);
    setError(null);
    try {
      setData(await api.setRetainedCourses(selectedCourses));
      setManagingCourses(false);
      setQuery('');
    } catch (cause) {
      setError(errorText(cause));
    } finally {
      setBusy(false);
    }
  }
  function editRemark(next: ChaoxingCourse) {
    setRemarkCourse(next);
    setRemark(next.remark ?? '');
    setRemarkError(null);
  }
  async function saveRemark() {
    if (!remarkCourse || !api.setCourseRemark || busy) return;
    setBusy(true);
    setRemarkError(null);
    try {
      const next = await api.setCourseRemark(remarkCourse.id, remark);
      setData(next);
      if (course?.id === remarkCourse.id)
        setCourse(next.items.find((row) => row.id === course.id) ?? course);
      setRemarkCourse(null);
    } catch (cause) {
      setRemarkError(errorText(cause));
    } finally {
      setBusy(false);
    }
  }
  async function loadFiles(next: ChaoxingCourse, nextPath: { id: string; name: string }[]) {
    setBusy(true);
    setError(null);
    setPath(nextPath);
    const folderId = nextPath.at(-1)?.id;
    try {
      setFiles(await api.files(next.id, folderId));
      const result = await api.syncFiles(next.id, folderId);
      if (result.ok) setFiles(result.data);
      else setError(result.error);
    } catch (cause) {
      setError(errorText(cause));
    } finally {
      setBusy(false);
    }
  }
  async function loadWorks(next: ChaoxingCourse) {
    setBusy(true);
    setError(null);
    try {
      setWorks(await api.works(next.id));
      const result = await api.syncWorks(next.id);
      if (result.ok) setWorks(result.data);
      else setError(result.error);
    } catch (cause) {
      setError(errorText(cause));
    } finally {
      setBusy(false);
    }
  }
  async function importFile(fileId: string) {
    if (!course || !api.importFile) return;
    setBusy(true);
    setError(null);
    try {
      const file = await api.importFile(course.id, path.at(-1)?.id ?? '', fileId);
      setFiles(await api.files(course.id, path.at(-1)?.id));
      useNavigationStore.getState().openDocument(file.id);
    } catch (cause) {
      setError(errorText(cause));
    } finally {
      setBusy(false);
    }
  }
  async function bindCourse(value: string) {
    if (!course || !api.bindCourse) return;
    setBusy(true);
    setError(null);
    try {
      await api.bindCourse(course.id, value || null);
      setFiles(await api.files(course.id, path.at(-1)?.id));
    } catch (cause) {
      setError(errorText(cause));
    } finally {
      setBusy(false);
    }
  }
  async function linkFile(fileId: string) {
    if (!course || !api.linkFile) return;
    setBusy(true);
    setError(null);
    try {
      await api.linkFile(course.id, path.at(-1)?.id ?? '', fileId);
      setFiles(await api.files(course.id, path.at(-1)?.id));
    } catch (cause) {
      setError(errorText(cause));
    } finally {
      setBusy(false);
    }
  }
  async function openFilesPage() {
    if (!course || !api.openFilesPage) return;
    try {
      await api.openFilesPage(course.id, path.at(-1)?.id);
    } catch (cause) {
      setError(errorText(cause));
    }
  }
  const retained =
    data?.items.filter(
      (row) => !data.retainedCourseIds || data.retainedCourseIds.includes(row.id),
    ) ?? [];
  const filtered = (managingCourses ? (data?.items ?? []) : retained).filter((row) =>
    `${row.name} ${row.remark ?? ''} ${row.teacher}`
      .toLocaleLowerCase()
      .includes(query.trim().toLocaleLowerCase()),
  );
  const snapshot = course ? (tab === '资料' ? files : works) : data;
  const board = !course && mode === '作业';
  return (
    <div className="min-h-0 flex-1 overflow-y-auto bg-surface">
      <div className="mx-auto grid w-full max-w-5xl gap-6 px-6 py-8 md:px-10">
        <header className="flex flex-wrap items-center justify-between gap-3">
          <div className="min-w-0">
            <div className="flex items-center gap-2">
              <BookOpen className="size-5 text-ink-3" />
              <h1 className="text-xl font-semibold text-ink">学习通</h1>
            </div>
            <p className="mt-1 text-xs text-ink-3">
              {board
                ? '汇总已保留课程的作业与截止时间'
                : snapshot
                  ? `更新于 ${new Date(snapshot.syncedAt).toLocaleString('zh-CN')}`
                  : '尚未同步'}
            </p>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            {!course && data && api.setRetainedCourses && (
              <Button
                size="sm"
                variant="outline"
                disabled={busy || managingCourses}
                onClick={() => void manageCourses()}
              >
                管理课程
              </Button>
            )}
            {!board && !managingCourses && (
              <Button
                size="sm"
                disabled={busy}
                onClick={() =>
                  void (course
                    ? tab === '资料'
                      ? loadFiles(course, path)
                      : loadWorks(course)
                    : syncCourses())
                }
              >
                <RefreshCw className={busy ? 'size-4 animate-spin' : 'size-4'} />
                {busy ? '正在读取…' : data ? '刷新' : '登录并同步'}
              </Button>
            )}
          </div>
        </header>
        {error && (
          <p role="alert" className="rounded-control bg-field p-3 text-13 text-ink">
            {error}
          </p>
        )}
        <Dialog.Root
          open={remarkCourse !== null}
          onOpenChange={(open) => {
            if (!open && !busy) setRemarkCourse(null);
          }}
        >
          <Dialog.Portal>
            <Dialog.Overlay className={dialogOverlay} />
            <Dialog.Content className={cn(dialogPanel, 'max-w-md')}>
              <Dialog.Title className="text-base font-semibold">设置课程备注</Dialog.Title>
              <Dialog.Description className="mt-2 break-words text-xs leading-relaxed text-ink-3">
                原课程名：{remarkCourse?.name}
              </Dialog.Description>
              <form
                className="mt-4 grid gap-4"
                onSubmit={(event) => {
                  event.preventDefault();
                  void saveRemark();
                }}
              >
                <label className="grid gap-2 text-13 text-ink">
                  备注名
                  <Input
                    aria-label="课程备注名"
                    autoFocus
                    maxLength={80}
                    value={remark}
                    disabled={busy}
                    placeholder="例如：安卓课"
                    onChange={(event) => setRemark(event.target.value)}
                  />
                </label>
                <p className="text-xs text-ink-3">仅保存在本机；留空保存可恢复原名。</p>
                {remarkError && (
                  <p role="alert" className="text-13 text-red">
                    {remarkError}
                  </p>
                )}
                <div className="flex justify-end gap-2">
                  <Button
                    type="button"
                    size="sm"
                    variant="ghost"
                    disabled={busy}
                    onClick={() => setRemarkCourse(null)}
                  >
                    取消
                  </Button>
                  <Button type="submit" size="sm" disabled={busy}>
                    {busy ? '正在保存…' : '保存备注'}
                  </Button>
                </div>
              </form>
            </Dialog.Content>
          </Dialog.Portal>
        </Dialog.Root>
        {!course ? (
          <>
            {managingCourses ? (
              <section aria-label="选择保留的课程" className="grid gap-4">
                <div className="grid gap-1">
                  <h2 className="text-base font-semibold text-ink">选择保留的课程</h2>
                  <p className="text-xs leading-relaxed text-ink-3">
                    仅将所选课程的作业纳入同步、日历与提醒。取消保留不删除已下载的资料，可随时重新选择。
                  </p>
                </div>
                <Input
                  aria-label="搜索可保留课程"
                  placeholder="搜索课程或教师"
                  value={query}
                  onChange={(event) => setQuery(event.target.value)}
                  disabled={busy}
                />
                <fieldset disabled={busy} className="grid gap-3 md:grid-cols-2">
                  {filtered.map((row) => (
                    <div key={row.id} className="grid min-w-0 gap-2 rounded-control bg-field p-4">
                      <label className="flex min-w-0 cursor-pointer items-start gap-3">
                        <input
                          type="checkbox"
                          className="mt-1 size-4 shrink-0 accent-ink"
                          aria-label={`保留 ${row.name}`}
                          checked={selectedCourses.includes(row.id)}
                          onChange={(event) =>
                            setSelectedCourses(
                              event.target.checked
                                ? [...selectedCourses, row.id]
                                : selectedCourses.filter((id) => id !== row.id),
                            )
                          }
                        />
                        <span className="grid min-w-0 gap-1">
                          <span className="break-words text-sm font-medium text-ink">
                            {chaoxingCourseLabel(row)}
                          </span>
                          {row.remark && (
                            <span className="break-words text-xs text-ink-3">原名：{row.name}</span>
                          )}
                          <span className="break-words text-xs text-ink-3">{row.teacher}</span>
                          <span className="text-xs text-ink-3">
                            {row.ended ? '已结束课程' : '未结束课程'}
                          </span>
                        </span>
                      </label>
                      {api.setCourseRemark && (
                        <Button
                          size="sm"
                          variant="ghost"
                          className="justify-self-end"
                          disabled={busy}
                          aria-label={`备注 ${row.name}`}
                          onClick={() => editRemark(row)}
                        >
                          备注
                        </Button>
                      )}
                    </div>
                  ))}
                </fieldset>
                {!filtered.length && <p className="text-sm text-ink-3">没有匹配的课程。</p>}
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <p className="text-xs text-ink-3">已选择 {selectedCourses.length} 门课程</p>
                  <div className="flex items-center gap-2">
                    <Button
                      size="sm"
                      variant="ghost"
                      disabled={busy}
                      onClick={() => {
                        setManagingCourses(false);
                        setQuery('');
                      }}
                    >
                      取消
                    </Button>
                    <Button size="sm" disabled={busy} onClick={() => void saveCourses()}>
                      {busy ? '正在保存…' : '保存课程选择'}
                    </Button>
                  </div>
                </div>
              </section>
            ) : (
              <>
                <fieldset disabled={busy}>
                  <SegmentedControl
                    options={['课程', '作业'] as const}
                    value={mode}
                    onChange={setMode}
                  />
                </fieldset>
                {mode === '作业' ? (
                  <ChaoxingWorkBoard
                    api={api}
                    now={now}
                    onOpenCourse={(courseId) => {
                      const row = data?.items.find((item) => item.id === courseId);
                      if (!row) return;
                      setCourse(row);
                      setFiles(null);
                      setWorks(null);
                      setTab('作业');
                      void loadWorks(row);
                    }}
                  />
                ) : (
                  <>
                    <div className="relative">
                      <Search className="absolute left-3 top-2 size-4 text-ink-3" />
                      <Input
                        aria-label="筛选学习通课程"
                        placeholder="搜索课程或教师"
                        value={query}
                        onChange={(event) => setQuery(event.target.value)}
                        className="pl-9"
                      />
                    </div>
                    {!data && (
                      <p className="py-12 text-center text-sm text-ink-3">
                        登录学习通，读取课程中的资料和作业。需要验证时会显示学习通登录窗口。
                      </p>
                    )}
                    {data && (
                      <>
                        <p className="text-xs text-ink-3">已保留课程 · {retained.length} 门</p>
                        <div className="grid gap-3 md:grid-cols-2">
                          {filtered.map((row) => (
                            <article
                              key={row.id}
                              className="grid min-w-0 gap-2 rounded-xl bg-field p-5 text-left hover:bg-hover disabled:opacity-50"
                            >
                              <button
                                disabled={busy}
                                className="grid min-w-0 gap-2 text-left disabled:opacity-50"
                                onClick={() => {
                                  setCourse(row);
                                  setFiles(null);
                                  setWorks(null);
                                  setTab('资料');
                                  void loadFiles(row, []);
                                }}
                              >
                                <h2 className="break-words text-base font-semibold text-ink">
                                  {chaoxingCourseLabel(row)}
                                </h2>
                                {row.remark && (
                                  <p className="break-words text-xs text-ink-3">原名：{row.name}</p>
                                )}
                                <p className="break-words text-13 text-ink-3">{row.teacher}</p>
                                <span className="text-xs text-ink-3">
                                  {row.ended ? '已结束课程' : '查看资料与作业'}
                                </span>
                              </button>
                              {api.setCourseRemark && (
                                <Button
                                  size="sm"
                                  variant="ghost"
                                  className="justify-self-end"
                                  disabled={busy}
                                  aria-label={`备注 ${row.name}`}
                                  onClick={() => editRemark(row)}
                                >
                                  备注
                                </Button>
                              )}
                            </article>
                          ))}
                        </div>
                        {!filtered.length && (
                          <p className="text-13 text-ink-3">
                            {data.retainedCourseIds?.length === 0 && data.items.length
                              ? '尚未保留课程，请在「管理课程」中选择需要的课程。'
                              : data.items.length
                                ? '没有匹配的课程。'
                                : '学校当前列表未返回课程。'}
                          </p>
                        )}
                      </>
                    )}
                  </>
                )}
              </>
            )}
          </>
        ) : (
          <>
            <div>
              <Button
                size="sm"
                variant="ghost"
                disabled={busy}
                onClick={() => {
                  setCourse(null);
                  setPath([]);
                  setError(null);
                }}
              >
                <ArrowLeft className="size-4" />
                返回课程
              </Button>
            </div>
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div className="min-w-0">
                <h2 className="break-words text-lg font-semibold text-ink">
                  {chaoxingCourseLabel(course)}
                </h2>
                {course.remark && (
                  <p className="mt-1 break-words text-xs text-ink-3">原名：{course.name}</p>
                )}
                <p className="mt-1 text-xs text-ink-3">{course.teacher}</p>
                {api.setCourseRemark && (
                  <Button
                    size="sm"
                    variant="ghost"
                    disabled={busy}
                    onClick={() => editRemark(course)}
                  >
                    修改备注
                  </Button>
                )}
              </div>
              <fieldset disabled={busy}>
                <SegmentedControl
                  options={['资料', '作业'] as const}
                  value={tab}
                  onChange={(value) => {
                    setTab(value);
                    void (value === '资料' ? loadFiles(course, []) : loadWorks(course));
                  }}
                />
              </fieldset>
            </div>
            {tab === '资料' ? (
              <>
                {api.bindCourse && (
                  <section
                    aria-label="学习通关联本地课程"
                    className="grid gap-2 rounded-control bg-field p-3"
                  >
                    <label className="grid gap-2 text-13 text-ink-2">
                      关联本地课程
                      <select
                        aria-label="关联本地课程"
                        className="min-w-0 max-w-full rounded-control bg-surface px-3 py-2 text-13 text-ink"
                        disabled={busy}
                        value={files?.localCourse?.knowledgeCourseId ?? ''}
                        onChange={(event) => void bindCourse(event.target.value)}
                      >
                        <option value="">未关联 · 导入到学习通资料</option>
                        {knowledge.courses.map((row) => (
                          <option key={row.id} value={row.id}>
                            {row.name} · {row.relativePath || '根目录'}
                          </option>
                        ))}
                      </select>
                    </label>
                    <p className="break-all text-xs text-ink-3">
                      {files?.localCourse
                        ? `导入位置：${files.localCourse.path}，保留线上子目录。已有文件不会自动移动或覆盖。`
                        : '在知识库把本地文件夹设为课程后，可在这里关联；已下载的资料可以逐项选择本地文件建立对应。'}
                    </p>
                  </section>
                )}
                <div className="flex flex-wrap items-center gap-2 text-xs text-ink-3">
                  <span>
                    当前目录{' '}
                    {files?.items.filter((row) => row.type !== 'tch-courseware').length ?? 0} 项 ·
                    按需读取子目录
                  </span>
                  {api.openFilesPage && (
                    <Button
                      size="sm"
                      variant="ghost"
                      disabled={busy}
                      onClick={() => void openFilesPage()}
                    >
                      打开平台资料页
                    </Button>
                  )}
                </div>
                <nav
                  aria-label="学习通资料目录"
                  className="flex flex-wrap items-center gap-1 text-xs text-ink-3"
                >
                  <button
                    disabled={busy}
                    className="rounded-control px-2 py-1 hover:bg-hover"
                    onClick={() => void loadFiles(course, [])}
                  >
                    课程资料
                  </button>
                  {path.map((part, index) => (
                    <span key={part.id}>
                      /{' '}
                      <button
                        disabled={busy}
                        className="rounded-control px-2 py-1 hover:bg-hover"
                        onClick={() => void loadFiles(course, path.slice(0, index + 1))}
                      >
                        {part.name}
                      </button>
                    </span>
                  ))}
                </nav>
                {files?.items.map((row) => (
                  <div
                    key={row.id}
                    className="flex min-w-0 flex-wrap items-center gap-3 rounded-control bg-field p-4"
                  >
                    {row.type === 'afolder' ? (
                      <Folder className="size-5 shrink-0 text-ink-3" />
                    ) : (
                      <FileText className="size-5 shrink-0 text-ink-3" />
                    )}
                    <div className="min-w-0 flex-1">
                      {row.type === 'afolder' ? (
                        <button
                          className="break-words text-left text-sm font-medium text-ink hover:underline"
                          disabled={busy}
                          onClick={() =>
                            void loadFiles(course, [...path, { id: row.id, name: row.name }])
                          }
                        >
                          {row.name}
                        </button>
                      ) : (
                        <h3 className="break-words text-sm font-medium text-ink">{row.name}</h3>
                      )}
                      <p className="mt-1 text-xs text-ink-3">
                        {row.type === 'tch-courseware'
                          ? '特殊教师课件入口，暂未适配'
                          : [row.size, row.creator, row.date].filter(Boolean).join(' · ')}
                      </p>
                    </div>
                    {row.type === 'tch-courseware' && api.openFilesPage && (
                      <Button
                        size="sm"
                        variant="ghost"
                        disabled={busy}
                        onClick={() => void openFilesPage()}
                      >
                        在平台查看
                      </Button>
                    )}
                    {row.type !== 'afolder' && row.type !== 'tch-courseware' && (
                      <div className="flex flex-wrap items-center gap-2">
                        {row.local && (
                          <div className="grid gap-1 text-xs text-ink-3">
                            <span>
                              {row.local.status === 'missing'
                                ? '本地文件已移动或删除'
                                : row.local.status === 'remote-changed'
                                  ? '线上资料信息已更新'
                                  : row.local.status === 'local-changed'
                                    ? '本地文件已修改'
                                    : row.local.origin === 'linked'
                                      ? '已关联本地文件（未比对正文）'
                                      : '已导入本机'}
                            </span>
                            <span className="max-w-xs break-all">{row.local.path}</span>
                          </div>
                        )}
                        {row.local && row.local.status !== 'missing' && api.importFile && (
                          <Button
                            size="sm"
                            variant="outline"
                            disabled={busy}
                            onClick={() =>
                              useNavigationStore.getState().openDocument(row.local!.path)
                            }
                          >
                            打开本地文件
                          </Button>
                        )}
                        {api.linkFile && (
                          <Button
                            size="sm"
                            variant="ghost"
                            disabled={busy || !files?.localCourse}
                            onClick={() => void linkFile(row.id)}
                          >
                            关联本地文件
                          </Button>
                        )}
                        {(!row.local || row.local.status !== 'ready' || !api.importFile) && (
                          <Button
                            size="sm"
                            variant="ghost"
                            disabled={busy || !row.downloadable || !api.importFile}
                            onClick={() => void importFile(row.id)}
                          >
                            <Download className="size-3.5" />
                            {!api.importFile
                              ? '在桌面端导入'
                              : row.downloadable
                                ? row.local?.status === 'remote-changed' ||
                                  row.local?.status === 'local-changed'
                                  ? '导入新版'
                                  : '导入并打开'
                                : '未开放下载'}
                          </Button>
                        )}
                      </div>
                    )}
                  </div>
                ))}
                {files && !files.items.length && (
                  <p className="py-8 text-13 text-ink-3">当前目录暂无资料。</p>
                )}
                <p className="text-xs leading-relaxed text-ink-3">
                  {api.importFile
                    ? '目录来自本次读取的页面；资料不全时可打开平台资料页核对。导入位置以课程关联设置为准，重复导入会打开已关联文件。'
                    : '资料下载与导入请使用本机 Dela。'}
                </p>
              </>
            ) : (
              <>
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <p className="text-xs text-ink-3">
                    {works
                      ? `待完成 ${chaoxingWorkSummary(works.items, now).pending} 份 · 已完成 ${chaoxingWorkSummary(works.items, now).done} 份`
                      : '尚未读取作业'}
                  </p>
                  <div className="flex flex-wrap items-center gap-2">
                    {api.openWorksPage && (
                      <Button
                        size="sm"
                        variant="ghost"
                        disabled={busy}
                        onClick={() =>
                          void api.openWorksPage!(course.id).catch((cause) =>
                            setError(errorText(cause)),
                          )
                        }
                      >
                        打开课程作业页
                      </Button>
                    )}
                    <Button
                      size="sm"
                      variant="ghost"
                      disabled={busy}
                      onClick={() => {
                        setCourse(null);
                        setMode('作业');
                        setError(null);
                      }}
                    >
                      查看全部课程作业
                    </Button>
                  </div>
                </div>
                {[...(works?.items ?? [])].sort(chaoxingWorkSort).map((row) => (
                  <article key={row.id} className="grid gap-2 rounded-control bg-field p-4">
                    <div className="flex flex-wrap items-start justify-between gap-2">
                      <h3 className="min-w-0 flex-1 break-words text-sm font-medium text-ink">
                        {row.title}
                      </h3>
                      <span className="text-xs text-ink-3" title={row.status}>
                        {chaoxingWorkStatus(row.status)}
                      </span>
                    </div>
                    <p className="text-xs text-ink-2">{chaoxingWorkTime(row, now)}</p>
                    {row.detailError && <p className="text-xs text-ink-3">{row.detailError}</p>}
                    <p className="text-2xs text-ink-3">
                      更新于{' '}
                      {new Date(row.detailSyncedAt ?? works!.syncedAt).toLocaleString('zh-CN')}
                    </p>
                    {window.dela?.webTabs ? (
                      <Button
                        size="sm"
                        variant="outline"
                        className="justify-self-start"
                        onClick={() => useNavigationStore.getState().openWork(course.id, row.id)}
                      >
                        在工作台打开作业
                      </Button>
                    ) : (
                      <p className="text-xs text-ink-3">请在桌面 App 中打开作业原网页。</p>
                    )}
                  </article>
                ))}
                {works && !works.items.length && (
                  <p className="py-8 text-13 text-ink-3">当前列表暂无作业。</p>
                )}
                <p className="text-xs leading-relaxed text-ink-3">
                  作业状态来自上次同步。可在工作台打开学习通原网页，查看详情、作答和提交。
                </p>
              </>
            )}
          </>
        )}
      </div>
    </div>
  );
}
