import { useEffect, useMemo, useState } from 'react';
import { BookOpen, Bell, ExternalLink, RefreshCw, Search } from 'lucide-react';
import type { ChaoxingApi } from '../../../shared/chaoxing';
import {
  chaoxingAssignments,
  chaoxingWorkSection,
  chaoxingWorkSectionLabels,
  chaoxingWorkSections,
  chaoxingWorkSort,
  chaoxingWorkStatus,
  chaoxingWorkSummary,
  chaoxingWorkTime,
  type ChaoxingCalendar,
  type ChaoxingCalendarSync,
  type ChaoxingCalendarWork,
} from '../../../shared/chaoxing-calendar';
import type { ChaoxingReminderState, ChaoxingWorkMarks } from '../../../shared/chaoxing';
import { Button } from '../../components/ui/button';
import { Input } from '../../components/ui/input';
import { SegmentedControl } from '../../components/ui/beautifului/atoms/SegmentedControl';
import { cn } from '../../lib/utils';
import { useNavigationStore } from '../../navigation/view';
import { errorText } from '../../workspace/store';

/** 作业看板只依赖读缓存、同步与打开原网页这几项能力，网页端与桌面端可共用。 */
export type ChaoxingWorkBoardApi = Pick<ChaoxingApi, 'courses' | 'works'> &
  Partial<
    Pick<
      ChaoxingApi,
      | 'syncCourses'
      | 'syncWorks'
      | 'calendar'
      | 'syncCalendar'
      | 'openWorksPage'
      | 'markWork'
      | 'reminders'
      | 'setReminders'
    >
  >;

const filters = ['全部', '待完成', '已完成', '已忽略'] as const;
type Filter = (typeof filters)[number];

export function ChaoxingWorkBoard({
  api,
  now,
  onOpenCourse,
}: {
  api: ChaoxingWorkBoardApi;
  now: number;
  onOpenCourse: (courseId: string) => void;
}) {
  const [assignments, setAssignments] = useState<ChaoxingCalendar | null>(null);
  const [failures, setFailures] = useState<ChaoxingCalendarSync['failures']>([]);
  const [busy, setBusy] = useState(false);
  const [loaded, setLoaded] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [filter, setFilter] = useState<Filter>('待完成');
  const [courseId, setCourseId] = useState('');
  const [query, setQuery] = useState('');
  const [reminders, setReminders] = useState<ChaoxingReminderState | null>(null);

  useEffect(() => {
    if (!api.reminders) return;
    let active = true;
    void api
      .reminders()
      .then((value) => {
        if (active) setReminders(value);
      })
      .catch(() => {
        // 读不到开关时按关闭展示，不影响看板本身。
      });
    return () => {
      active = false;
    };
  }, [api]);

  async function readAssignments() {
    if (api.calendar) return api.calendar();
    const courses = await api.courses();
    const works = await Promise.all((courses?.items ?? []).map((row) => api.works(row.id)));
    return chaoxingAssignments(courses, works);
  }

  async function refresh() {
    setBusy(true);
    setError(null);
    try {
      if (api.syncCalendar) {
        const result = await api.syncCalendar();
        setAssignments(result.data);
        setFailures(result.failures);
        return;
      }
      if (!api.syncCourses || !api.syncWorks)
        throw new Error('当前环境不支持同步作业，请在本机 Dela 中操作');
      const courses = await api.syncCourses();
      if (!courses.ok) throw new Error(courses.error);
      const next: ChaoxingCalendarSync['failures'] = [];
      for (const course of courses.data.items) {
        if (courses.data.retainedCourseIds && !courses.data.retainedCourseIds.includes(course.id))
          continue;
        const result = await api.syncWorks(course.id);
        if (!result.ok)
          next.push({ courseId: course.id, error: result.error, reason: result.reason });
      }
      setFailures(next);
      setAssignments(await readAssignments());
    } catch (cause) {
      setError(errorText(cause));
    } finally {
      setBusy(false);
      setLoaded(true);
    }
  }

  async function retry(target: string | null) {
    if (target && api.syncWorks) {
      setBusy(true);
      setError(null);
      try {
        const result = await api.syncWorks(target);
        if (result.ok) {
          setAssignments(await readAssignments());
          setFailures((rows) => rows.filter((row) => row.courseId !== target));
        } else
          setFailures((rows) =>
            rows.map((row) =>
              row.courseId === target
                ? { courseId: target, error: result.error, reason: result.reason }
                : row,
            ),
          );
      } catch (cause) {
        setError(errorText(cause));
      } finally {
        setBusy(false);
      }
      return;
    }
    await refresh();
  }

  useEffect(() => {
    let active = true;
    void readAssignments()
      .then((value) => {
        if (active) setAssignments(value);
      })
      .catch((cause) => {
        if (active) setError(errorText(cause));
      })
      .finally(() => {
        if (active) setLoaded(true);
      });
    return () => {
      active = false;
    };
    // 只在 api 变化时重读缓存，同步由用户显式触发。
  }, [api]);

  const works = useMemo(() => assignments?.works ?? [], [assignments]);
  const summary = chaoxingWorkSummary(works, now);
  const syncedCourses = assignments?.courses.filter((course) => course.syncedAt).length ?? 0;
  const needle = query.trim().toLocaleLowerCase();
  const visible = works
    .filter((work) => (courseId ? work.courseId === courseId : true))
    .filter((work) =>
      needle
        ? `${work.title} ${work.courseName} ${work.courseOriginalName ?? ''}`
            .toLocaleLowerCase()
            .includes(needle)
        : true,
    )
    .sort(chaoxingWorkSort);
  const sections = chaoxingWorkSections
    .filter((section) =>
      filter === '全部'
        ? true
        : filter === '待完成'
          ? section !== 'done' && section !== 'ignored'
          : filter === '已完成'
            ? section === 'done'
            : section === 'ignored',
    )
    .map((section) => ({
      section,
      items: visible.filter((work) => chaoxingWorkSection(work, now) === section),
    }))
    .filter((group) => group.items.length);
  const canOpenInWorkbench = Boolean(window.dela?.webTabs);

  async function mark(work: ChaoxingCalendarWork, marks: ChaoxingWorkMarks) {
    if (!api.markWork) return;
    setError(null);
    try {
      await api.markWork(work.courseId, work.id, marks);
      setAssignments(await readAssignments());
    } catch (cause) {
      setError(errorText(cause));
    }
  }

  async function toggleReminders() {
    if (!api.setReminders || !reminders) return;
    setError(null);
    try {
      setReminders(await api.setReminders(!reminders.enabled));
    } catch (cause) {
      setError(errorText(cause));
    }
  }

  return (
    <div className="grid gap-4">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <p className="min-w-0 text-xs text-ink-3">
          {`${syncedCourses}/${assignments?.courses.length ?? 0} 门课程已读取作业 · 待完成 ${summary.pending} 份`}
          {summary.overdue ? ` · 已过截止 ${summary.overdue} 份` : ''}
          {summary.undated ? ` · 截止时间待确认 ${summary.undated} 份` : ''}
          {` · 已完成 ${summary.done} 份`}
          {summary.ignored ? ` · 已忽略 ${summary.ignored} 份` : ''}
        </p>
        <div className="flex flex-wrap items-center gap-2">
          {api.setReminders && reminders && (
            <Button
              size="sm"
              variant={reminders.enabled ? 'secondary' : 'ghost'}
              aria-pressed={reminders.enabled}
              title="临近截止时弹系统通知；只提醒未忽略、未完成的作业"
              onClick={() => void toggleReminders()}
            >
              <Bell className={reminders.enabled ? 'size-4' : 'size-4 text-ink-3'} />
              {reminders.enabled ? '截止提醒已开启' : '截止提醒已关闭'}
            </Button>
          )}
          <Button size="sm" disabled={busy} onClick={() => void refresh()}>
            <RefreshCw className={busy ? 'size-4 animate-spin' : 'size-4'} />
            {busy ? '正在读取…' : '同步全部作业'}
          </Button>
        </div>
      </div>
      {error && (
        <p role="alert" className="rounded-control bg-field p-3 text-13 text-ink">
          {error}
        </p>
      )}
      {failures.length > 0 && (
        <div role="alert" className="grid gap-2 rounded-control bg-field p-3 text-13 text-ink">
          <p className="font-medium">以下课程本次没有读取成功，已保留上次的作业缓存：</p>
          {failures.map((failure) => (
            <div
              key={failure.courseId ?? 'courses'}
              className="flex flex-wrap items-center justify-between gap-2"
            >
              <span className="min-w-0 break-words">
                {assignments?.courses.find((course) => course.id === failure.courseId)?.name ??
                  '课程列表'}
                ：{failure.error}
                {failure.reason === 'auth' ? '（请重新登录学习通）' : ''}
              </span>
              <Button
                size="sm"
                variant="ghost"
                disabled={busy}
                onClick={() => void retry(failure.courseId)}
              >
                重试
              </Button>
            </div>
          ))}
        </div>
      )}
      <div className="flex flex-wrap items-center gap-2">
        <SegmentedControl options={filters} value={filter} onChange={setFilter} />
        <select
          aria-label="筛选课程"
          className="min-w-0 max-w-full rounded-control bg-field px-3 py-1.5 text-13 text-ink"
          value={courseId}
          onChange={(event) => setCourseId(event.target.value)}
        >
          <option value="">全部课程</option>
          {(assignments?.courses ?? [])
            .filter((course) => works.some((work) => work.courseId === course.id))
            .map((course) => (
              <option key={course.id} value={course.id} title={course.originalName}>
                {course.name}
              </option>
            ))}
        </select>
        <div className="relative min-w-0 flex-1">
          <Search className="absolute left-3 top-1.5 size-4 text-ink-3" />
          <Input
            aria-label="搜索作业"
            placeholder="搜索作业或课程"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            className="pl-9"
          />
        </div>
      </div>
      {sections.map((group) => (
        <section
          key={group.section}
          aria-label={chaoxingWorkSectionLabels[group.section]}
          className="grid gap-2"
        >
          <h3
            className={cn(
              'text-xs font-medium',
              group.section === 'overdue' ? 'text-red' : 'text-ink-3',
            )}
          >
            {chaoxingWorkSectionLabels[group.section]} · {group.items.length}
          </h3>
          {group.items.map((work) => (
            <article
              key={`${work.courseId}:${work.id}`}
              className="grid gap-2 rounded-control bg-field p-4"
            >
              <div className="flex flex-wrap items-start justify-between gap-2">
                <h4 className="min-w-0 flex-1 break-words text-sm font-medium text-ink">
                  {!work.readAt && !work.mutedAt && (
                    <span
                      aria-label="未读"
                      className="mr-1.5 inline-block size-1.5 rounded-full bg-bui-accent align-middle"
                    />
                  )}
                  {work.title}
                </h4>
                <span className="text-xs text-ink-3" title={work.status}>
                  {chaoxingWorkStatus(work.status)}
                </span>
              </div>
              <div className="flex flex-wrap items-center gap-2 text-xs text-ink-2">
                <button
                  type="button"
                  className="inline-flex items-center gap-1 rounded-chip bg-surface px-2 py-0.5 hover:bg-hover"
                  onClick={() => onOpenCourse(work.courseId)}
                  title={work.courseOriginalName}
                >
                  <BookOpen className="size-3" />
                  {work.courseName}
                </button>
                <span>{chaoxingWorkTime(work, now)}</span>
                {work.readAt && (
                  <span className="rounded-chip bg-inset px-1.5 py-0.5 text-2xs text-ink-3">
                    已读
                  </span>
                )}
                {work.mutedAt && (
                  <span className="rounded-chip bg-inset px-1.5 py-0.5 text-2xs text-ink-3">
                    已忽略
                  </span>
                )}
              </div>
              {work.detailError && (
                <p className="text-xs text-ink-3">
                  {work.detailError}
                  {work.detailSyncedAt
                    ? `；时间保留自 ${new Date(work.detailSyncedAt).toLocaleString('zh-CN')}`
                    : ''}
                </p>
              )}
              <div className="flex flex-wrap items-center gap-2">
                {canOpenInWorkbench && (
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() => useNavigationStore.getState().openWork(work.courseId, work.id)}
                  >
                    在工作台打开作业
                  </Button>
                )}
                {api.openWorksPage && (
                  <Button
                    size="sm"
                    variant="ghost"
                    disabled={busy}
                    onClick={() =>
                      void api.openWorksPage!(work.courseId).catch((cause) =>
                        setError(cause instanceof Error ? cause.message : String(cause)),
                      )
                    }
                  >
                    <ExternalLink className="size-3.5" />
                    打开课程作业页
                  </Button>
                )}
                {api.markWork && (
                  <>
                    <Button
                      size="sm"
                      variant="ghost"
                      title={work.readAt ? '标为未读' : '标为已读'}
                      onClick={() => void mark(work, { read: !work.readAt })}
                    >
                      {work.readAt ? '标为未读' : '标为已读'}
                    </Button>
                    <Button
                      size="sm"
                      variant="ghost"
                      title={work.mutedAt ? '取消忽略' : '忽略后不计入待完成，也不提醒'}
                      onClick={() => void mark(work, { muted: !work.mutedAt })}
                    >
                      {work.mutedAt ? '取消忽略' : '忽略'}
                    </Button>
                  </>
                )}
                <span className="text-2xs text-ink-3">
                  读取于 {new Date(work.syncedAt).toLocaleString('zh-CN')}
                </span>
              </div>
            </article>
          ))}
        </section>
      ))}
      {!sections.length && (
        <p className="py-8 text-13 text-ink-3">
          {!loaded
            ? '正在读取作业…'
            : !works.length
              ? '还没有作业缓存。先在「管理课程」中选择需要的课程，再同步作业；需要验证时会显示学习通登录窗口。'
              : !visible.length
                ? '没有匹配的作业。'
                : filter === '已完成'
                  ? '还没有读到已完成的作业。'
                  : filter === '已忽略'
                    ? '还没有忽略的作业。'
                    : filter === '待完成'
                      ? '当前没有待完成的作业。'
                      : '没有匹配的作业。'}
        </p>
      )}
      <p className="text-xs leading-relaxed text-ink-3">
        同步时读取作业列表与详情时间；缺少年份时需与平台时间及倒计时核对，无法确认的时间不进入日历或提醒。状态来自上次同步，提交与作答仍在学习通原网页完成。
      </p>
    </div>
  );
}
