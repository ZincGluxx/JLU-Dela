import type { ChaoxingCalendar, ChaoxingCalendarSync } from './chaoxing-calendar';
export interface ChaoxingCourse {
  id: string;
  name: string;
  teacher: string;
  ended: boolean;
  remark?: string;
}
export function chaoxingCourseLabel(course: Pick<ChaoxingCourse, 'name' | 'remark'>): string {
  return course.remark || course.name;
}
export interface ChaoxingCourses {
  items: ChaoxingCourse[];
  syncedAt: string;
  retainedCourseIds?: string[];
}
export interface ChaoxingLocalCourse {
  knowledgeCourseId: string;
  name: string;
  path: string;
}
export interface ChaoxingLocalFile {
  path: string;
  origin: 'linked' | 'downloaded';
  status: 'ready' | 'missing' | 'local-changed' | 'remote-changed';
}
export interface ChaoxingFile {
  id: string;
  name: string;
  type: string;
  size: string;
  creator: string;
  date: string;
  downloadable: boolean;
  local?: ChaoxingLocalFile;
}
export interface ChaoxingFolder {
  courseId: string;
  folderId: string;
  relativePath?: string[];
  localCourse?: ChaoxingLocalCourse;
  name: string;
  items: ChaoxingFile[];
  syncedAt: string;
}
export interface ChaoxingWork {
  id: string;
  title: string;
  status: string;
  timing: string;
  detailTiming?: string;
  detailSyncedAt?: string;
  detailError?: string;
  /** 本地标记：手动标为已读的时间（与学校状态无关）。 */
  readAt?: string;
  /** 本地标记：被忽略的时间；忽略的作业不计入待完成，也不参与截止提醒。 */
  mutedAt?: string;
}
export interface ChaoxingWorks {
  courseId: string;
  items: ChaoxingWork[];
  syncedAt: string;
}
export type ChaoxingResult<T> =
  { ok: true; data: T } | { ok: false; error: string; reason?: 'auth' };
/** 作业的本地标记；省略的字段保持不变，传 false 表示清除。 */
export interface ChaoxingWorkMarks {
  read?: boolean;
  muted?: boolean;
}
export interface ChaoxingReminderState {
  enabled: boolean;
}
export interface ChaoxingReminderCheck {
  /** 处于提醒窗口内、本次尚未提醒过的作业数。 */
  due: number;
  /** 实际弹出的系统通知数（窗口聚焦、未武装或暂停时为 0）。 */
  sent: number;
}
export interface ChaoxingApi {
  calendar(): Promise<ChaoxingCalendar>;
  syncCalendar(): Promise<ChaoxingCalendarSync>;
  courses(): Promise<ChaoxingCourses | null>;
  syncCourses(): Promise<ChaoxingResult<ChaoxingCourses>>;
  setRetainedCourses(courseIds: string[]): Promise<ChaoxingCourses>;
  setCourseRemark(courseId: string, remark: string): Promise<ChaoxingCourses>;
  files(courseId: string, folderId?: string): Promise<ChaoxingFolder | null>;
  syncFiles(courseId: string, folderId?: string): Promise<ChaoxingResult<ChaoxingFolder>>;
  works(courseId: string): Promise<ChaoxingWorks | null>;
  syncWorks(courseId: string): Promise<ChaoxingResult<ChaoxingWorks>>;
  openWorksPage(courseId: string): Promise<void>;
  markWork(courseId: string, workId: string, marks: ChaoxingWorkMarks): Promise<void>;
  reminders(): Promise<ChaoxingReminderState>;
  setReminders(enabled: boolean): Promise<ChaoxingReminderState>;
  checkReminders(): Promise<ChaoxingReminderCheck>;
  /** 主进程在截止提醒被点击时推送；返回退订函数。 */
  onOpenWork(listener: (payload: { courseId: string; workId: string }) => void): () => void;
  bindCourse(
    courseId: string,
    knowledgeCourseId: string | null,
  ): Promise<ChaoxingLocalCourse | null>;
  linkFile(courseId: string, folderId: string, fileId: string): Promise<{ id: string } | null>;
  openFilesPage(courseId: string, folderId?: string): Promise<void>;
  importFile(courseId: string, folderId: string, fileId: string): Promise<{ id: string }>;
}
