// @vitest-environment jsdom
// 校园社区骨架：板块切换、发布（含基础审核预览）、互动与人工复核。
import { act } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { afterEach, beforeEach, expect, it, vi } from 'vitest';
import { demoCommunitySnapshot } from '../../../main/community/seed';
import type { DelaApi } from '../../../shared/api';
import { CommunityView } from './CommunityView';

const now = Date.UTC(2025, 2, 1, 10);
const snapshot = demoCommunitySnapshot(now);

let host: HTMLDivElement;
let root: Root;
let get: ReturnType<typeof vi.fn>;
let create: ReturnType<typeof vi.fn>;
let like: ReturnType<typeof vi.fn>;
let moderate: ReturnType<typeof vi.fn>;

beforeEach(() => {
  vi.stubGlobal('IS_REACT_ACT_ENVIRONMENT', true);
  host = document.createElement('div');
  document.body.append(host);
  root = createRoot(host);
  get = vi.fn(async () => snapshot);
  create = vi.fn(async () => snapshot);
  like = vi.fn(async () => snapshot);
  moderate = vi.fn(async () => snapshot);
  window.dela = {
    community: {
      get,
      create,
      like,
      reply: vi.fn(async () => snapshot),
      moderate,
      setDealStatus: vi.fn(async () => snapshot),
      report: vi.fn(async () => snapshot),
      remove: vi.fn(async () => snapshot),
      regenerateDemo: vi.fn(async () => snapshot),
    },
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
    root.render(<CommunityView />);
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

async function choose(target: HTMLSelectElement, value: string) {
  target.value = value;
  await act(async () => {
    target.dispatchEvent(new Event('change', { bubbles: true }));
  });
}

const list = () => host.querySelector('[aria-label="帖子列表"]')!;
const detail = () => host.querySelector('[aria-label="帖子详情"]')!;

it('默认落在普通交流，并展示示例帖子的审核状态', async () => {
  await mount();
  expect(get).toHaveBeenCalledOnce();
  expect(host.textContent).toContain('校园社区');
  expect(host.textContent).toContain('内容由 AI 模拟');
  expect(list().textContent).toContain('期末周图书馆座位怎么找');
  expect(detail().textContent).toContain('已发布');
  expect(detail().textContent).toContain('回复 2');
});

it('切到二手板块可以看到价格与成色，点赞会落到后端', async () => {
  await mount();
  await act(async () => buttonContaining('二手信息').click());
  expect(list().textContent).toContain('出 24 寸显示器');
  expect(detail().textContent).toContain('¥350 · 九成新 · 在售');

  const likeButton = [...detail().querySelectorAll('button')].find(
    (item) => item.getAttribute('aria-pressed') === 'false',
  )!;
  await act(async () => likeButton.click());
  expect(like).toHaveBeenCalledWith('demo-market-1');
});

it('发科研信息时先给审核预览，缺来源会标注待核实', async () => {
  await mount();
  await act(async () => button('发布').click());
  const dialog = document.body.querySelector('[role="dialog"]')!;
  expect(dialog.textContent).toContain('发布到校园社区');

  await choose(dialog.querySelector<HTMLSelectElement>('[aria-label="选择板块"]')!, 'research');
  await type(
    dialog.querySelector<HTMLInputElement>('[aria-label="帖子标题"]')!,
    '实验室招本科科研助理',
  );
  await type(
    dialog.querySelector<HTMLTextAreaElement>('[aria-label="帖子正文"]')!,
    '方向是视觉检索，每周投入八小时左右，欢迎大二以上同学。',
  );
  await flush();
  const preview = dialog.querySelector('[role="status"]')!;
  expect(preview.textContent).toContain('需复核');
  expect(preview.textContent).toContain('来源链接');
  expect(preview.textContent).toContain('科研信息一律标注来源并等待人工核实');

  await act(async () => button('提交', document.body).click());
  expect(create).toHaveBeenCalledWith(
    expect.objectContaining({ board: 'research', title: '实验室招本科科研助理' }),
  );
  expect(host.querySelector('[role="status"]')?.textContent).toContain(
    '审核结论见帖子上的状态标签',
  );
});

it('待复核列表可以逐条通过', async () => {
  await mount();
  await act(async () => buttonContaining('全部').click());
  await act(async () => buttonContaining('待复核').click());
  expect(list().textContent).toContain('关于某课题组招募的转述');
  expect(detail().textContent).toContain('来源待核实');

  await act(async () => button('通过').click());
  expect(moderate).toHaveBeenCalledWith(expect.any(String), 'publish');
});
