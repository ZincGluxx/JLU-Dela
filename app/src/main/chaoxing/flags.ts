import { getDatabase } from '../database';
import type { ChaoxingWorkMarks } from '../../shared/chaoxing';

/** 本地作业标记（已读 / 忽略 / 已提醒的截止时间），与学校缓存分开存放。 */
export interface ChaoxingWorkFlag {
  readAt: string | null;
  mutedAt: string | null;
  reminderKey: string | null;
}

type FlagRow = {
  course_id: string;
  work_id: string;
  read_at: string | null;
  muted_at: string | null;
  reminder_key: string | null;
};

export const chaoxingWorkFlagKey = (courseId: string, workId: string) => `${courseId}:${workId}`;

export function chaoxingWorkFlags(): Map<string, ChaoxingWorkFlag> {
  const rows = getDatabase()
    .prepare('SELECT course_id,work_id,read_at,muted_at,reminder_key FROM chaoxing_work_flags')
    .all() as FlagRow[];
  return new Map(
    rows.map((row) => [
      chaoxingWorkFlagKey(row.course_id, row.work_id),
      { readAt: row.read_at, mutedAt: row.muted_at, reminderKey: row.reminder_key },
    ]),
  );
}

function flag(courseId: string, workId: string): ChaoxingWorkFlag | null {
  const row = getDatabase()
    .prepare(
      'SELECT course_id,work_id,read_at,muted_at,reminder_key FROM chaoxing_work_flags WHERE course_id=? AND work_id=?',
    )
    .get(courseId, workId) as FlagRow | undefined;
  return row ? { readAt: row.read_at, mutedAt: row.muted_at, reminderKey: row.reminder_key } : null;
}

/** 写入已读 / 忽略标记；省略的字段保持不变，false 表示清除该标记。 */
export function markChaoxingWork(
  courseId: string,
  workId: string,
  marks: ChaoxingWorkMarks,
): ChaoxingWorkFlag {
  const current = flag(courseId, workId) ?? { readAt: null, mutedAt: null, reminderKey: null };
  const now = new Date().toISOString();
  const next: ChaoxingWorkFlag = {
    readAt: marks.read === undefined ? current.readAt : marks.read ? (current.readAt ?? now) : null,
    mutedAt:
      marks.muted === undefined ? current.mutedAt : marks.muted ? (current.mutedAt ?? now) : null,
    reminderKey: current.reminderKey,
  };
  getDatabase()
    .prepare(
      `INSERT INTO chaoxing_work_flags(course_id,work_id,read_at,muted_at,reminder_key)
       VALUES(?,?,?,?,?)
       ON CONFLICT(course_id,work_id) DO UPDATE SET
         read_at=excluded.read_at, muted_at=excluded.muted_at, reminder_key=excluded.reminder_key`,
    )
    .run(courseId, workId, next.readAt, next.mutedAt, next.reminderKey);
  return next;
}

/** 记下已经提醒过的截止阶段，避免同一份作业反复弹窗。 */
export function saveChaoxingWorkReminder(courseId: string, workId: string, key: string): void {
  getDatabase()
    .prepare(
      `INSERT INTO chaoxing_work_flags(course_id,work_id,reminder_key) VALUES(?,?,?)
       ON CONFLICT(course_id,work_id) DO UPDATE SET reminder_key=excluded.reminder_key`,
    )
    .run(courseId, workId, key);
}
