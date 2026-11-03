import { getDatabase } from '../database';
import { systemNotifyWorkReminder, workspaceMainWindow } from '../notifications/system';
import {
  chaoxingReminderKey,
  chaoxingReminderStage,
  chaoxingWorkTime,
} from '../../shared/chaoxing-calendar';
import type { ChaoxingReminderCheck, ChaoxingReminderState } from '../../shared/chaoxing';
import { getChaoxingCalendar } from './api';
import { chaoxingWorkFlagKey, chaoxingWorkFlags, saveChaoxingWorkReminder } from './flags';

const REMINDER_ENABLED_KEY = 'chaoxing-work-reminders';
const REMINDER_INTERVAL_MS = 5 * 60_000;

export function workRemindersEnabled(): boolean {
  const row = getDatabase()
    .prepare('SELECT value FROM workspace_settings WHERE key=?')
    .get(REMINDER_ENABLED_KEY) as { value?: string } | undefined;
  return row?.value !== '0';
}

export function setWorkRemindersEnabled(enabled: boolean): ChaoxingReminderState {
  getDatabase()
    .prepare('INSERT OR REPLACE INTO workspace_settings(key,value) VALUES(?,?)')
    .run(REMINDER_ENABLED_KEY, enabled ? '1' : '0');
  return { enabled };
}

export function workReminderState(): ChaoxingReminderState {
  return { enabled: workRemindersEnabled() };
}

/**
 * 检查临近截止的作业并弹一次系统提醒。
 * 同一份作业同一截止时刻的同一阶段只提醒一次；窗口聚焦或通知被暂停时不弹，
 * 也不记为已提醒，等下次检查再试。
 */
export function checkWorkReminders(now = Date.now()): ChaoxingReminderCheck {
  if (!workRemindersEnabled()) return { due: 0, sent: 0 };
  const flags = chaoxingWorkFlags();
  let due = 0,
    sent = 0;
  for (const work of getChaoxingCalendar().works) {
    const flag = flags.get(chaoxingWorkFlagKey(work.courseId, work.id));
    if (flag?.mutedAt) continue;
    const target = chaoxingReminderStage(work, now);
    if (!target) continue;
    const key = chaoxingReminderKey(work, target.stage);
    if (flag?.reminderKey === key) continue;
    due += 1;
    const title =
      target.stage === 'overdue'
        ? `作业已过截止：${work.title}`
        : target.stage === 'urgent'
          ? `1 小时内截止：${work.title}`
          : `24 小时内截止：${work.title}`;
    const body = `${work.courseName} · ${chaoxingWorkTime(work, now)}`;
    if (
      systemNotifyWorkReminder(title, body, () => {
        // 点击后由渲染层打开对应的作业标签。
        workspaceMainWindow()?.webContents.send('chaoxing:open-work', {
          courseId: work.courseId,
          workId: work.id,
        });
      })
    ) {
      saveChaoxingWorkReminder(work.courseId, work.id, key);
      sent += 1;
    }
  }
  return { due, sent };
}

let timer: ReturnType<typeof setInterval> | undefined;

export function startWorkReminders(): () => void {
  timer ??= setInterval(() => {
    try {
      checkWorkReminders();
    } catch (error) {
      console.error('Work reminder check failed', error);
    }
  }, REMINDER_INTERVAL_MS);
  timer.unref?.();
  return () => {
    if (timer) clearInterval(timer);
    timer = undefined;
  };
}
