// @vitest-environment jsdom
// 校园地图骨架：检索、按楼宇/事项浏览、详情动作（导航、纠错、定位）都要真的能点。
import { act } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { afterEach, beforeEach, expect, it, vi } from 'vitest';
import { demoPlacesSnapshot } from '../../../main/places/seed';
import type { DelaApi } from '../../../shared/api';
import { PlacesView } from './PlacesView';

const snapshot = demoPlacesSnapshot('2025-03-01T10:00:00.000Z');

let host: HTMLDivElement;
let root: Root;
let get: ReturnType<typeof vi.fn>;
let saveOffice: ReturnType<typeof vi.fn>;
let submitCorrection: ReturnType<typeof vi.fn>;
let reviewCorrection: ReturnType<typeof vi.fn>;
let openLink: ReturnType<typeof vi.fn>;

beforeEach(() => {
  vi.stubGlobal('IS_REACT_ACT_ENVIRONMENT', true);
  host = document.createElement('div');
  document.body.append(host);
  root = createRoot(host);
  get = vi.fn(async () => snapshot);
  saveOffice = vi.fn(async () => snapshot);
  submitCorrection = vi.fn(async () => snapshot);
  reviewCorrection = vi.fn(async () => snapshot);
  openLink = vi.fn(async () => {});
  window.dela = {
    places: {
      get,
      search: vi.fn(async () => []),
      saveOffice,
      submitCorrection,
      reviewCorrection,
      regenerateDemo: vi.fn(async () => snapshot),
    },
    workspace: { openLink },
  } as unknown as DelaApi;
});

afterEach(async () => {
  await act(async () => root.unmount());
  host.remove();
  delete window.dela;
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

const flush = () => act(async () => new Promise((resolve) => setTimeout(resolve, 0)));
const mount = () =>
  act(async () => {
    root.render(<PlacesView />);
    await new Promise((resolve) => setTimeout(resolve, 0));
  });

function button(label: string, scope: ParentNode = host): HTMLButtonElement {
  const element = [...scope.querySelectorAll('button')].find(
    (item) => item.textContent?.trim() === label,
  );
  if (!element) throw new Error(`缺少按钮：${label}`);
  return element;
}

function buttonContaining(text: string, scope: ParentNode = host): HTMLButtonElement {
  const element = [...scope.querySelectorAll('button')].find((item) =>
    item.textContent?.includes(text),
  );
  if (!element) throw new Error(`缺少包含「${text}」的按钮`);
  return element;
}

async function type(target: HTMLInputElement | HTMLTextAreaElement, value: string) {
  const prototype =
    target instanceof HTMLTextAreaElement
      ? HTMLTextAreaElement.prototype
      : HTMLInputElement.prototype;
  Object.getOwnPropertyDescriptor(prototype, 'value')!.set!.call(target, value);
  await act(async () => {
    target.dispatchEvent(new Event('input', { bubbles: true }));
  });
}

const results = () => host.querySelector('[aria-label="检索结果"]')!;
const detail = () => host.querySelector('[aria-label="地点详情"]')!;

it('打开就展示示例地点，并标明是模拟数据', async () => {
  await mount();
  expect(get).toHaveBeenCalledOnce();
  expect(host.textContent).toContain('校园地图与办事地点');
  expect(host.textContent).toContain('AI 模拟的示例内容');
  expect(host.textContent).toMatch(/找到 \d+ 条结果/);
  expect(Number(host.textContent!.match(/找到 (\d+) 条结果/)![1])).toBeGreaterThan(5);
  expect(detail().textContent).toContain('示例数据');
});

it('搜老师可以直接定位到他的办公室', async () => {
  await mount();
  await type(
    host.querySelector<HTMLInputElement>('[aria-label="搜索地点、老师或办事事项"]')!,
    '张伟',
  );
  expect(results().textContent).toContain('张伟');
  await act(async () => buttonContaining('张伟', results()).click());
  expect(detail().textContent).toContain('张伟教授办公室');
  expect(detail().textContent).toContain('A 区 420');
});

it('按办事事项查到窗口，并在详情里给出流程、材料与导航入口', async () => {
  await mount();
  await act(async () => button('办事事项').click());
  const services = host.querySelector('[aria-label="办事事项"]')!;
  expect(services.textContent).toContain('发票报销');
  await act(async () => buttonContaining('发票报销', services).click());
  expect(detail().textContent).toContain('整理票据并核对抬头');
  expect(detail().textContent).toContain('需要：发票原件');

  await act(async () => button('在地图中导航').click());
  expect(openLink).toHaveBeenCalledWith(expect.stringContaining('uri.amap.com/marker'));
});

it('按楼宇浏览时可以看到楼里的办公室数量', async () => {
  await mount();
  await act(async () => button('按楼宇').click());
  const section = host.querySelector('[aria-label="按楼宇浏览"]')!;
  expect(section.textContent).toContain('鼎新楼');
  expect(section.textContent).toMatch(/鼎新楼[\s\S]*\d+ 个地点/);
});

it('提交纠错会写清目标与说明，并给出可追踪的记录', async () => {
  await mount();
  await act(async () => button('报错 / 纠错').click());
  const dialog = document.body.querySelector('[role="dialog"]')!;
  expect(dialog.textContent).toContain('纠错：');
  const submit = button('提交纠错', document.body);
  expect(submit.disabled).toBe(true);

  await type(
    document.body.querySelector<HTMLTextAreaElement>('[aria-label="纠错说明"]')!,
    '搬到 A 区 418 了',
  );
  await flush();
  expect(button('提交纠错', document.body).disabled).toBe(false);
  await act(async () => button('提交纠错', document.body).click());
  expect(submitCorrection).toHaveBeenCalledWith(
    expect.objectContaining({ target: 'office', message: '搬到 A 区 418 了' }),
  );
  expect(host.querySelector('[role="status"]')?.textContent).toContain('纠错已记录');
});

it('先征得同意再定位，取不到本机定位时用示例位置并说明', async () => {
  await mount();
  await act(async () => button('开启定位').click());
  const consent = document.body.querySelector('[role="alertdialog"]')!;
  expect(consent.textContent).toContain('开启定位以显示距离');
  expect(consent.textContent).toContain('不上传位置');
  await act(async () => buttonContaining('开启定位', consent).click());
  await flush();
  expect(host.querySelector('[role="status"]')?.textContent).toContain('未取得本机定位');
  expect(detail().textContent).toContain('（示例位置）');
});
