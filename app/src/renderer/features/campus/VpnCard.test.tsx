// @vitest-environment jsdom
import { act } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { afterEach, beforeEach, expect, it, vi } from 'vitest';
import { JLU_WEBVPN_BASE, type CampusVpnConfig } from '../../../shared/campus-vpn';
import { VpnCard } from './VpnCard';

let host: HTMLDivElement, root: Root, config: CampusVpnConfig;
beforeEach(() => {
  vi.stubGlobal('IS_REACT_ACT_ENVIRONMENT', true);
  host = document.createElement('div');
  document.body.append(host);
  root = createRoot(host);
  config = { mode: 'off', baseUrl: JLU_WEBVPN_BASE };
  window.dela = {
    campusVpn: {
      get: vi.fn(async () => config),
      set: vi.fn(async (patch: Partial<CampusVpnConfig>) => {
        config = { ...config, ...patch };
        return config;
      }),
      status: vi.fn(async () => ({
        config,
        reachable: true,
        authenticated: false,
      })),
      login: vi.fn(async () => ({ ok: true })),
    },
  } as unknown as NonNullable<typeof window.dela>;
});
afterEach(() => {
  act(() => root.unmount());
  host.remove();
  delete window.dela;
  vi.restoreAllMocks();
});
const button = (label: string) =>
  [...host.querySelectorAll('button')].find((item) => item.textContent?.trim() === label)!;
const mount = () =>
  act(async () => {
    root.render(<VpnCard />);
    await new Promise((resolve) => setTimeout(resolve, 0));
  });

it('starts on direct access and explains both options', async () => {
  await mount();
  expect(host.textContent).toContain('直连');
  expect(host.textContent).toContain('学校 VPN');
  expect(button('直连 / 系统 VPN').getAttribute('aria-pressed')).toBe('true');
  expect(host.querySelector('[aria-label="VPN 入口地址"]')).toBeNull();
  expect(window.dela!.campusVpn.get).toHaveBeenCalledOnce();
});

it('switches to the gateway, keeps the address and reports its state', async () => {
  await mount();
  await act(async () => button('学校 WebVPN').click());
  expect(window.dela!.campusVpn.set).toHaveBeenCalledWith({ mode: 'webvpn' });
  expect(host.textContent).toContain('学校 WebVPN');
  const input = host.querySelector<HTMLInputElement>('[aria-label="VPN 入口地址"]')!;
  expect(input.value).toBe(JLU_WEBVPN_BASE);

  await act(async () => button('保存入口').click());
  expect(window.dela!.campusVpn.set).toHaveBeenLastCalledWith({ baseUrl: JLU_WEBVPN_BASE });

  await act(async () => button('检测 VPN 状态').click());
  expect(host.textContent).toContain('还没有登录');

  await act(async () => button('打开 VPN 登录').click());
  expect(window.dela!.campusVpn.login).toHaveBeenCalledOnce();
  expect(host.textContent).toContain('VPN 登录已完成');
});

it('shows why the gateway is unusable instead of pretending it works', async () => {
  window.dela!.campusVpn.status = vi.fn(async () => ({
    config,
    reachable: false,
    authenticated: false,
    error: 'VPN 入口无法连接，请检查网络或入口地址',
  }));
  await mount();
  await act(async () => button('学校 WebVPN').click());
  await act(async () => button('检测 VPN 状态').click());
  expect(host.textContent).toContain('VPN 入口无法连接');
});

it('surfaces a failed gateway login', async () => {
  window.dela!.campusVpn.login = vi.fn(async () => ({ ok: false, error: '未完成 VPN 登录' }));
  await mount();
  await act(async () => button('学校 WebVPN').click());
  await act(async () => button('打开 VPN 登录').click());
  expect(host.querySelector('[role="alert"]')?.textContent).toContain('未完成 VPN 登录');
});
