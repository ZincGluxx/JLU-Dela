// @vitest-environment jsdom
import { act } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { afterEach, beforeEach, expect, it, vi } from 'vitest';
import { PublicCourseLibrary } from './PublicCourseLibrary';

let host: HTMLDivElement;
let root: Root;

beforeEach(async () => {
  vi.stubGlobal('IS_REACT_ACT_ENVIRONMENT', true);
  host = document.createElement('div');
  document.body.append(host);
  root = createRoot(host);
  await act(async () => root.render(<PublicCourseLibrary />));
});

afterEach(async () => {
  await act(async () => root.unmount());
  host.remove();
  vi.unstubAllGlobals();
});

async function click(label: string, scope: ParentNode = document) {
  const button = [...scope.querySelectorAll('button')].find(
    (item) => item.textContent?.trim() === label || item.getAttribute('aria-label') === label,
  );
  expect(button, label).toBeTruthy();
  await act(async () => button!.click());
}

async function type(element: HTMLInputElement | HTMLTextAreaElement, value: string) {
  const prototype =
    element instanceof HTMLInputElement
      ? HTMLInputElement.prototype
      : HTMLTextAreaElement.prototype;
  await act(async () => {
    Object.getOwnPropertyDescriptor(prototype, 'value')!.set!.call(element, value);
    element.dispatchEvent(new Event('input', { bubbles: true }));
  });
}

async function openDataStructures() {
  for (const label of ['计算机学院', '计算机科学与技术', '大二', '必修']) await click(label);
  const course = [...host.querySelectorAll('button')].find((item) =>
    item.textContent?.startsWith('数据结构'),
  )!;
  await act(async () => course.click());
}

it('逐层浏览、按当前分类查找，并通过面包屑和返回按钮回退', async () => {
  await click('计算机学院');
  await click('计算机科学与技术');
  for (const grade of ['大一', '大二', '大三', '大四']) {
    expect(host.querySelector('[aria-label="选择年级"]')?.textContent).toContain(grade);
  }
  expect(host.textContent).not.toMatch(/202[0-9]级|年级口径待确定/);
  await click('大一');
  await click('必修');
  expect(host.textContent).toContain('此分类暂无示例课程');
  await click('返回上一级');
  await click('返回上一级');
  await click('大二');
  for (const category of ['必修', '选修', '限选', '专业选修']) {
    expect(host.querySelector(`[aria-label="选择课程类别"]`)?.textContent).toContain(category);
  }
  await click('必修');
  const search = host.querySelector<HTMLInputElement>('[aria-label="按课程名称查找"]')!;
  await type(search, '网络');
  const list = host.querySelector('[aria-label="当前分类课程"]')!;
  expect(list.textContent).toContain('计算机网络');
  expect(list.textContent).not.toContain('数据结构');
  await type(search, '不存在的课程');
  expect(list.textContent).toContain('没有找到匹配的课程');
  await click('清空搜索');
  const course = [...list.querySelectorAll('button')].find((item) =>
    item.textContent?.startsWith('数据结构'),
  )!;
  await act(async () => course.click());
  expect(host.querySelector('[aria-label="课程帖子"]')?.textContent).toContain('线性表与链表');
  await click('返回上一级');
  expect(host.querySelector('[aria-label="当前分类课程"]')).toBeTruthy();
  await click('返回上一级');
  expect(host.querySelector('[aria-label="选择课程类别"]')).toBeTruthy();
  await click('全部学院');
  expect(host.querySelector('[aria-label="选择学院"]')).toBeTruthy();
});

it('资料下载和两类评论只反馈待接入，不伪造文件或新增评论', async () => {
  await openDataStructures();
  await click('下载 线性表与链表 · 课堂整理（待接入）');
  expect(host.querySelector('[role="status"]')?.textContent).toContain('下载待接入');
  await click('查看 线性表与链表 · 课堂整理');
  const dialog = document.querySelector('[role="dialog"]')!;
  expect(dialog.textContent).toContain('非真实文件正文');
  await type(dialog.querySelector('textarea')!, '这是一条未发布评论');
  await click('提交评论（待接入）', dialog);
  expect(dialog.querySelector('[role="status"]')?.textContent).toContain('内容未发布或保存');
  expect(dialog.querySelectorAll('ol li')).toHaveLength(2);
  expect(dialog.querySelector('textarea')!.value).toBe('这是一条未发布评论');
  await click('关闭帖子详情');
  await click('课程讨论');
  await type(host.querySelector('textarea')!, '这是一条未发布讨论');
  await click('提交评论（待接入）');
  expect(host.querySelector('[role="status"]')?.textContent).toContain('评论发布待接入');
  expect(host.querySelectorAll('ol li')).toHaveLength(2);
});

it('贡献表单明确课程，选择文件后可填写，提交不新增资料', async () => {
  await openDataStructures();
  await click('发布资料帖');
  const dialog = document.querySelector('[role="dialog"]')!;
  expect(dialog.textContent).toContain('发布到「数据结构」');
  const submit = [...dialog.querySelectorAll('button')].find((item) => item.type === 'submit')!;
  expect(submit.disabled).toBe(true);
  const input = dialog.querySelector<HTMLInputElement>('input[type="file"]')!;
  await act(async () => {
    Object.defineProperty(input, 'files', {
      value: [new File(['example'], '我的笔记.md')],
      configurable: true,
    });
    input.dispatchEvent(new Event('change', { bubbles: true }));
  });
  expect(
    dialog.querySelector<HTMLInputElement>('input[type="text"], input:not([type])')!.value,
  ).toBe('我的笔记');
  expect(dialog.textContent).toContain('已选择：我的笔记.md');
  expect(submit.disabled).toBe(true);
  await type(dialog.querySelector('textarea')!, '整理第三章的课堂重点和复习建议。');
  expect(submit.disabled).toBe(false);
  await act(async () =>
    dialog
      .querySelector('form')!
      .dispatchEvent(new Event('submit', { bubbles: true, cancelable: true })),
  );
  expect(dialog.querySelector('[role="status"]')?.textContent).toContain(
    '文件未上传，帖子未发布或保存',
  );
  await click('关闭上传窗口');
  expect(host.querySelectorAll('[aria-label="课程帖子"] li')).toHaveLength(4);
  await click('发布资料帖');
  expect(document.querySelector<HTMLInputElement>('input[type="file"]')!.value).toBe('');
});

it('帖子展示简介与附件，点赞可取消，收藏筛选与详情状态同步，离开课程后重置', async () => {
  await openDataStructures();
  const post = host.querySelector<HTMLElement>('article[aria-label="线性表与链表 · 课堂整理"]')!;
  expect(post.textContent).toContain('整理顺序表和链表的存储特点');
  expect(post.textContent).toContain('线性表与链表.md');
  expect(post.textContent).toContain('赞 12');
  await click('点赞 线性表与链表 · 课堂整理', post);
  expect(post.textContent).toContain('赞 13');
  expect(
    post
      .querySelector('[aria-label="取消点赞 线性表与链表 · 课堂整理"]')
      ?.getAttribute('aria-pressed'),
  ).toBe('true');
  await click('取消点赞 线性表与链表 · 课堂整理', post);
  expect(post.textContent).toContain('赞 12');
  await click('收藏 线性表与链表 · 课堂整理', post);
  await click('本页收藏 · 1');
  expect(host.querySelectorAll('article')).toHaveLength(1);
  await click('评价 线性表与链表 · 课堂整理');
  const dialog = document.querySelector('[role="dialog"]')!;
  expect(dialog.textContent).toContain('帖子评价');
  expect(
    dialog
      .querySelector('[aria-label="取消收藏 线性表与链表 · 课堂整理"]')
      ?.getAttribute('aria-pressed'),
  ).toBe('true');
  await click('点赞 线性表与链表 · 课堂整理', dialog);
  expect(post.textContent).toContain('赞 13');
  await click('取消收藏 线性表与链表 · 课堂整理', dialog);
  await click('关闭帖子详情');
  expect(host.textContent).toContain('本页还没有收藏的帖子');
  await click('查看全部帖子');
  expect(host.querySelectorAll('article')).toHaveLength(4);
  expect(host.textContent).toContain('离开课程后重置');
  await click('全部学院');
  await openDataStructures();
  expect(host.querySelector('article')!.textContent).toContain('赞 12');
  await click('本页收藏 · 0');
  expect(host.querySelectorAll('article')).toHaveLength(0);
});

it('帖子支持时间与点赞量排序，并与收藏筛选一起生效', async () => {
  await openDataStructures();
  expect([...host.querySelectorAll('article h3')].map((item) => item.textContent)).toEqual([
    '线性表与链表 · 课堂整理',
    '树与二叉树 · 学习提纲',
    '期末复习 · 知识清单',
    '历年试题 · 资料位置示例',
  ]);
  await click('最多点赞');
  expect([...host.querySelectorAll('article h3')].map((item) => item.textContent)).toEqual([
    '期末复习 · 知识清单',
    '线性表与链表 · 课堂整理',
    '树与二叉树 · 学习提纲',
    '历年试题 · 资料位置示例',
  ]);
  await click('收藏 线性表与链表 · 课堂整理');
  await click('收藏 期末复习 · 知识清单');
  await click('本页收藏 · 2');
  expect([...host.querySelectorAll('article h3')].map((item) => item.textContent)).toEqual([
    '期末复习 · 知识清单',
    '线性表与链表 · 课堂整理',
  ]);
  await click('最新发布');
  expect([...host.querySelectorAll('article h3')].map((item) => item.textContent)).toEqual([
    '线性表与链表 · 课堂整理',
    '期末复习 · 知识清单',
  ]);
  await click('资料 · 4');
  expect(host.querySelectorAll('[aria-label="资料下载排行"] > li')).toHaveLength(4);
  await click('帖子 · 4');
  expect(host.querySelectorAll('article')).toHaveLength(2);
  expect(host.querySelector('[aria-label="帖子排序"] [aria-pressed="true"]')?.textContent).toBe(
    '最新发布',
  );
});

it('资料按示例下载量排列，点击不增加计数，查看原帖和发布共用同一入口', async () => {
  await openDataStructures();
  await click('资料 · 4');
  const rows = [...host.querySelectorAll('[aria-label="资料下载排行"] > li')];
  expect(
    rows.map((item) =>
      item.querySelector('[aria-label^="示例下载量"]')?.getAttribute('aria-label'),
    ),
  ).toEqual(['示例下载量 245', '示例下载量 172', '示例下载量 128', '示例下载量 96']);
  expect(rows[0]?.textContent).toContain('复习知识清单.pdf');
  expect(rows[0]?.textContent).toContain('来自帖子：期末复习 · 知识清单');
  await click('下载 期末复习 · 知识清单（待接入）');
  expect(host.querySelector('[role="status"]')?.textContent).toContain('下载量未改变');
  expect(rows[0]?.querySelector('[aria-label="示例下载量 245"]')).toBeTruthy();
  await click('查看原帖', rows[0]!);
  const dialog = document.querySelector('[role="dialog"]')!;
  expect(dialog.textContent).toContain('期末复习 · 知识清单');
  expect(dialog.textContent).toContain('帖子评价');
  await click('收藏 期末复习 · 知识清单', dialog);
  await click('关闭帖子详情');
  await click('发布资料帖');
  expect(document.querySelector('[role="dialog"]')?.textContent).toContain('帖子和资料一并发布');
  expect(document.querySelectorAll('input[type="file"]')).toHaveLength(1);
  await click('关闭上传窗口');
  await click('帖子 · 4');
  await click('本页收藏 · 1');
  expect(host.querySelector('article h3')?.textContent).toBe('期末复习 · 知识清单');
});
