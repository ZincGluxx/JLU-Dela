import { ipcMain, dialog, BrowserWindow } from 'electron';
import { z } from 'zod';
import { checkWorkspaceSender } from '../ipc';
import {
  chaoxingResult,
  getChaoxingCalendar,
  syncChaoxingCalendar,
  getChaoxingCourses,
  syncChaoxingCourses,
  setRetainedChaoxingCourses,
  setChaoxingCourseRemark,
  getChaoxingFiles,
  syncChaoxingFiles,
  getChaoxingWorks,
  syncChaoxingWorks,
  importChaoxingFile,
  bindChaoxingCourse,
  linkChaoxingFile,
  openChaoxingFilesPage,
  openChaoxingWorksPage,
} from './api';
import { markChaoxingWork } from './flags';
import { checkWorkReminders, setWorkRemindersEnabled, workReminderState } from './reminders';

const workIds = z.string().regex(/^[A-Za-z0-9:_-]{1,180}$/);
const workMarks = z.object({ read: z.boolean().optional(), muted: z.boolean().optional() });

export function registerChaoxingIpc() {
  ipcMain.handle('cx:calendar:get', (event) => {
    checkWorkspaceSender(event);
    return getChaoxingCalendar();
  });
  ipcMain.handle('cx:calendar:sync', (event) => {
    checkWorkspaceSender(event);
    return syncChaoxingCalendar(event.sender);
  });
  ipcMain.handle('cx:courses:get', (event) => {
    checkWorkspaceSender(event);
    return getChaoxingCourses();
  });
  ipcMain.handle('cx:courses:sync', (event) => {
    checkWorkspaceSender(event);
    return chaoxingResult(() => syncChaoxingCourses(event.sender));
  });
  ipcMain.handle('cx:courses:retain', (event, courseIds: unknown) => {
    checkWorkspaceSender(event);
    return setRetainedChaoxingCourses(courseIds);
  });
  ipcMain.handle('cx:course:remark', (event, courseId: string, remark: unknown) => {
    checkWorkspaceSender(event);
    return setChaoxingCourseRemark(courseId, remark);
  });
  ipcMain.handle('cx:files:get', (event, courseId: string, folderId?: string) => {
    checkWorkspaceSender(event);
    return getChaoxingFiles(courseId, folderId);
  });
  ipcMain.handle('cx:files:sync', (event, courseId: string, folderId?: string) => {
    checkWorkspaceSender(event);
    return chaoxingResult(() => syncChaoxingFiles(courseId, folderId, event.sender));
  });
  ipcMain.handle('cx:works:get', (event, courseId: string) => {
    checkWorkspaceSender(event);
    return getChaoxingWorks(courseId);
  });
  ipcMain.handle('cx:works:sync', (event, courseId: string) => {
    checkWorkspaceSender(event);
    return chaoxingResult(() => syncChaoxingWorks(courseId, event.sender));
  });
  ipcMain.handle('cx:works:open', (event, courseId: string) => {
    checkWorkspaceSender(event);
    return openChaoxingWorksPage(courseId, event.sender);
  });
  ipcMain.handle('cx:works:mark', (event, courseId: string, workId: string, marks: unknown) => {
    checkWorkspaceSender(event);
    return markChaoxingWork(
      workIds.parse(courseId),
      workIds.parse(workId),
      workMarks.parse(marks ?? {}),
    );
  });
  ipcMain.handle('cx:reminders:get', (event) => {
    checkWorkspaceSender(event);
    return workReminderState();
  });
  ipcMain.handle('cx:reminders:set', (event, enabled: unknown) => {
    checkWorkspaceSender(event);
    return setWorkRemindersEnabled(z.boolean().parse(enabled));
  });
  ipcMain.handle('cx:reminders:check', (event) => {
    checkWorkspaceSender(event);
    return checkWorkReminders();
  });
  ipcMain.handle('cx:course:bind', (event, courseId: string, knowledgeCourseId: unknown) => {
    checkWorkspaceSender(event);
    return bindChaoxingCourse(courseId, knowledgeCourseId);
  });
  ipcMain.handle('cx:files:open', (event, courseId: string, folderId = '') => {
    checkWorkspaceSender(event);
    return openChaoxingFilesPage(courseId, folderId, event.sender);
  });
  ipcMain.handle(
    'cx:file:link',
    async (event, courseId: string, folderId: string, fileId: string) => {
      checkWorkspaceSender(event);
      const parent = BrowserWindow.fromWebContents(event.sender);
      const options = {
        defaultPath: getChaoxingFiles(courseId, folderId)?.localCourse?.path,
        title: '关联已下载的本地资料',
        properties: ['openFile'] as ['openFile'],
      };
      const selected = await (parent
        ? dialog.showOpenDialog(parent, options)
        : dialog.showOpenDialog(options));
      return selected.canceled
        ? null
        : linkChaoxingFile(courseId, folderId, fileId, selected.filePaths[0]!);
    },
  );
  ipcMain.handle('cx:file:import', (event, courseId: string, folderId: string, fileId: string) => {
    checkWorkspaceSender(event);
    return importChaoxingFile(courseId, folderId, fileId);
  });
}
