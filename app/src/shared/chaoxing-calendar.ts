import type { ChaoxingCourses, ChaoxingWork, ChaoxingWorks } from './chaoxing';

export interface ChaoxingCalendarWork extends ChaoxingWork {
  courseId: string;
  courseName: string;
  syncedAt: string;
  deadline: { date: string; time: string | null } | null;
}
export interface ChaoxingCalendar {
  courses: { id: string; name: string; syncedAt: string | null }[];
  works: ChaoxingCalendarWork[];
  coursesSyncedAt: string | null;
}
export interface ChaoxingCalendarSync {
  data: ChaoxingCalendar;
  failures: { courseId: string | null; error: string; reason?: 'auth' }[];
}

/** 把各课程的作业快照汇总成一份带课程名的列表；主进程与网页端共用同一份拼装规则。 */
export function chaoxingAssignments(
  courses: ChaoxingCourses | null,
  works: (ChaoxingWorks | null)[],
): ChaoxingCalendar {
  const items = courses?.items ?? [];
  return {
    coursesSyncedAt: courses?.syncedAt ?? null,
    courses: items.map((course, index) => ({
      id: course.id,
      name: course.name,
      syncedAt: works[index]?.syncedAt ?? null,
    })),
    works: items.flatMap((course, index) =>
      (works[index]?.items ?? []).map((work) => ({
        ...work,
        courseId: course.id,
        courseName: course.name,
        syncedAt: works[index]!.syncedAt,
        deadline: chaoxingDeadline(work.detailTiming ?? '') ?? chaoxingDeadline(work.timing),
      })),
    ),
  };
}

export function chaoxingDeadline(timing: string): ChaoxingCalendarWork['deadline'] {
  const match = timing.match(
    /(?:截止时间|截止日期|截止|deadline|due(?:\s+date)?|end\s*(?:time|date))\s*[:：]?\s*(\d{4})[-/.年](\d{1,2})[-/.月](\d{1,2})日?(?:[ T]*(\d{1,2}):(\d{2})(?::(\d{2}))?)?/i,
  );
  if (!match) return null;
  const [, year, month, day, hour, minute, second] = match;
  const remainder = timing.slice(match.index! + match[0].length);
  if (/^[\d:]/.test(remainder) || (hour === undefined && /^\s*[T\d]/.test(remainder))) return null;
  const date = `${year}-${month!.padStart(2, '0')}-${day!.padStart(2, '0')}`;
  const value = new Date(`${date}T00:00:00Z`);
  if (!Number.isFinite(value.getTime()) || value.toISOString().slice(0, 10) !== date) return null;
  if (
    hour !== undefined &&
    (Number(hour) > 23 || Number(minute) > 59 || (second !== undefined && Number(second) > 59))
  )
    return null;
  return {
    date,
    time:
      hour === undefined
        ? null
        : `${hour.padStart(2, '0')}:${minute}${second === undefined ? '' : `:${second}`}`,
  };
}

export function chaoxingWorkCompleted(status: string): boolean {
  return /^(已完成|已提交|已批阅|已批改|已评分|已交|completed|submitted|graded|marked)(?:\s|$)/i.test(
    status.trim(),
  );
}

export function chaoxingWorkTime(work: ChaoxingWork, now: number): string {
  const deadline = chaoxingDeadline(work.detailTiming ?? '') ?? chaoxingDeadline(work.timing);
  const snapshot = work.timing || (/left|remaining|剩余/i.test(work.status) ? work.status : '');
  if (!deadline)
    return snapshot ? `上次同步显示：${snapshot}` : '尚未读到截止时间，请打开原网页查看';
  const label = `截止 ${deadline.date}${deadline.time ? ` ${deadline.time}` : '（具体时刻待确认）'}`;
  if (!deadline.time || chaoxingWorkCompleted(work.status)) return label;
  const remaining =
    new Date(
      `${deadline.date}T${deadline.time.length === 5 ? deadline.time + ':00' : deadline.time}+08:00`,
    ).getTime() - now;
  if (remaining <= 0) return `${label} · 已过截止时间`;
  const minutes = Math.ceil(remaining / 60_000);
  const days = Math.floor(minutes / 1440);
  const hours = Math.floor((minutes % 1440) / 60);
  return `${label} · 剩余${days ? `${days}天` : ''}${hours ? `${hours}小时` : ''}${!days && (minutes % 60 || !hours) ? `${minutes % 60}分钟` : ''}`;
}

const DAY = 86_400_000;

/** 作业看板的分组：逾期、7 天内截止、之后截止、时间段待确认、已完成。 */
export type ChaoxingWorkSection = 'overdue' | 'soon' | 'later' | 'undated' | 'done';
export const chaoxingWorkSections: readonly ChaoxingWorkSection[] = [
  'overdue',
  'soon',
  'later',
  'undated',
  'done',
];
export const chaoxingWorkSectionLabels = {
  overdue: '已过截止时间',
  soon: '7 天内截止',
  later: '之后截止',
  undated: '截止时间待确认',
  done: '已完成 / 已批阅',
} as const satisfies Record<ChaoxingWorkSection, string>;

/** 截止时刻（毫秒）。只读到日期时按当天 23:59（北京时间）算，当天不会被误判为逾期。 */
export function chaoxingWorkDueAt(work: Pick<ChaoxingWork, 'timing' | 'detailTiming'>) {
  const deadline = chaoxingDeadline(work.detailTiming ?? '') ?? chaoxingDeadline(work.timing);
  if (!deadline) return null;
  const time = deadline.time ?? '23:59';
  const value = new Date(
    `${deadline.date}T${time.length === 5 ? time + ':00' : time}+08:00`,
  ).getTime();
  return Number.isFinite(value) ? value : null;
}

export function chaoxingWorkSection(
  work: ChaoxingWork,
  now: number,
  soonDays = 7,
): ChaoxingWorkSection {
  if (chaoxingWorkCompleted(work.status)) return 'done';
  const due = chaoxingWorkDueAt(work);
  if (due === null) return 'undated';
  if (due < now) return 'overdue';
  return due - now <= soonDays * DAY ? 'soon' : 'later';
}

export function chaoxingWorkSummary(works: readonly ChaoxingWork[], now: number) {
  let pending = 0,
    done = 0,
    overdue = 0,
    undated = 0;
  for (const work of works) {
    const section = chaoxingWorkSection(work, now);
    if (section === 'done') {
      done += 1;
      continue;
    }
    pending += 1;
    if (section === 'overdue') overdue += 1;
    else if (section === 'undated') undated += 1;
  }
  return { total: works.length, pending, done, overdue, undated };
}

/** 待完成按截止时间由近到远，没有截止时间的排最后；同一时间按标题排序。 */
export function chaoxingWorkSort(a: ChaoxingWork, b: ChaoxingWork) {
  const left = chaoxingWorkDueAt(a) ?? Number.MAX_SAFE_INTEGER;
  const right = chaoxingWorkDueAt(b) ?? Number.MAX_SAFE_INTEGER;
  return left - right || a.title.localeCompare(b.title, 'zh-CN');
}
