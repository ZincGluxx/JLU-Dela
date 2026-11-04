import { ipcMain, net, type WebContents } from 'electron';
import { z } from 'zod';
import type { CampusVpnLoginResult, CampusVpnStatus } from '../shared/campus-vpn';
import { createCampusLoginWindow, getCampusSession } from './campus';
import { campusVpnConfig, isVpnLoginUrl, setCampusVpnConfig } from './campus-vpn';
import { checkWorkspaceSender } from './ipc';

/**
 * 探测入口是否可访问、是否已登录：在校园会话分区里读入口首页，
 * 未登录时入口会跳到登录页，据此区分「连不上」和「还没登录」。
 */
export async function campusVpnStatus(): Promise<CampusVpnStatus> {
  const config = campusVpnConfig();
  if (config.mode !== 'webvpn') return { config, reachable: true, authenticated: false };
  const campus = await getCampusSession();
  const result = await new Promise<{ reachable: boolean; authenticated: boolean }>((resolve) => {
    const request = net.request({
      url: `${config.baseUrl}/`,
      method: 'GET',
      session: campus,
      useSessionCookies: true,
      redirect: 'manual',
    });
    let settled = false;
    const finish = (reachable: boolean, authenticated: boolean) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      request.abort();
      resolve({ reachable, authenticated });
    };
    const timer = setTimeout(() => finish(false, false), 10000);
    request.on('error', () => finish(false, false));
    request.on('redirect', (_status, _method, target: string) => {
      let authenticated = false;
      try {
        const url = new URL(target, `${config.baseUrl}/`);
        const base = new URL(config.baseUrl);
        authenticated = !(url.host === base.host && /login/i.test(url.pathname));
      } catch {
        authenticated = false;
      }
      finish(true, authenticated);
    });
    request.on('response', (response) => {
      const status = response.statusCode ?? 0;
      response.on('error', () => finish(false, false));
      response.on('end', () => finish(status >= 200 && status < 500, false));
      response.on('data', () => {});
    });
    request.end();
  });
  return {
    config,
    ...result,
    ...(result.reachable ? {} : { error: 'VPN 入口无法连接，请检查网络或入口地址' }),
  };
}

/** 打开 VPN 登录窗口：登录状态落在校园会话分区，之后的校园请求会自动带上。 */
export async function openVpnLogin(sender: WebContents): Promise<CampusVpnLoginResult> {
  const config = campusVpnConfig();
  if (config.mode !== 'webvpn') return { ok: false, error: '尚未启用校外 VPN' };
  await getCampusSession();
  const window = createCampusLoginWindow(sender, '登录吉林大学 VPN');
  return new Promise<CampusVpnLoginResult>((resolve) => {
    let settled = false;
    const finish = (result: CampusVpnLoginResult) => {
      if (settled) return;
      settled = true;
      resolve(result);
      if (!window.isDestroyed()) window.close();
    };
    const check = async () => {
      if (settled || window.isDestroyed()) return;
      const current = window.webContents.getURL();
      if (!current.startsWith('https://') || window.webContents.isLoadingMainFrame()) return;
      // 仍在入口登录页时继续等；离开登录页且没有密码框即视为登录完成。
      if (isVpnLoginUrl(current)) return;
      try {
        const hasPassword: boolean = await window.webContents.executeJavaScript(
          `Boolean(document.querySelector('input[type="password"]'))`,
        );
        if (!hasPassword) finish({ ok: true });
      } catch {
        // 页面跳转中取不到 DOM 属正常，等下一次检查。
      }
    };
    const timer = setInterval(() => void check(), 1000);
    window.on('closed', () => {
      clearInterval(timer);
      if (!settled) {
        settled = true;
        resolve({ ok: false, error: '未完成 VPN 登录' });
      }
    });
    void window.loadURL(`${config.baseUrl}/`).catch((error: unknown) => {
      clearInterval(timer);
      finish({
        ok: false,
        error:
          error instanceof Error && error.message.includes('ERR_ABORTED')
            ? 'VPN 登录窗口已关闭'
            : `无法打开 VPN 入口：${error instanceof Error ? error.message : String(error)}`,
      });
    });
  });
}

export function registerCampusVpnIpc(): void {
  ipcMain.handle('campus:vpn:get', (event) => {
    checkWorkspaceSender(event);
    return campusVpnConfig();
  });
  ipcMain.handle('campus:vpn:set', (event, patch: unknown) => {
    checkWorkspaceSender(event);
    const input = z
      .object({
        mode: z.enum(['off', 'webvpn']).optional(),
        baseUrl: z.string().min(1).max(200).optional(),
      })
      .parse(patch ?? {});
    return setCampusVpnConfig(input);
  });
  ipcMain.handle('campus:vpn:status', async (event) => {
    checkWorkspaceSender(event);
    return campusVpnStatus();
  });
  ipcMain.handle('campus:vpn:login', (event) => {
    checkWorkspaceSender(event);
    return openVpnLogin(event.sender);
  });
}
