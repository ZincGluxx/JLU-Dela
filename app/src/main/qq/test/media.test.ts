import { mkdir, mkdtemp, rm, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { afterEach, beforeEach, expect, it, vi } from 'vitest';
const state = vi.hoisted(() => ({ home: '' }));
vi.mock('electron', () => ({ app: { getPath: () => state.home }, net: { fetch: vi.fn() } }));
import { net } from 'electron';
import { readQqImage } from '../media';
const png = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aNuoAAAAASUVORK5CYII=',
  'base64',
);
const gif = Buffer.from('R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7', 'base64');
beforeEach(async () => {
  vi.clearAllMocks();
  state.home = await mkdtemp(join(tmpdir(), 'dela-qq-media-'));
});
afterEach(async () => {
  await rm(state.home, { recursive: true, force: true });
});

it('按内容识别 PNG 和 GIF，保留动图原始字节，不信任远程 Content-Type', async () => {
  for (const [bytes, mime] of [
    [png, 'image/png'],
    [gif, 'image/gif'],
  ] as const) {
    vi.mocked(net.fetch).mockResolvedValueOnce(new Response(bytes));
    expect(await readQqImage('https://example.com/picture')).toBe(
      `data:${mime};base64,${bytes.toString('base64')}`,
    );
  }
});
it('读取 QQ 下载的本地图片，拒绝任意本机文件及非图片响应', async () => {
  const root = join(state.home, 'Library/Containers/com.tencent.qq/Data');
  await mkdir(root, { recursive: true });
  const local = join(root, 'screenshot.png');
  await writeFile(local, png);
  expect(await readQqImage(local)).toBe(`data:image/png;base64,${png.toString('base64')}`);
  const unrelated = join(state.home, 'private.png');
  await writeFile(unrelated, png);
  await expect(readQqImage(unrelated)).rejects.toThrow('不在 QQ 数据目录');
  await expect(readQqImage('file:///etc/passwd')).rejects.toThrow('有效图片地址');
  vi.mocked(net.fetch).mockResolvedValueOnce(Response.json({ secret: 'not-an-image' }));
  await expect(readQqImage('https://example.com/picture')).rejects.toThrow('不是受支持的图片');
});
it('对过期链接和超过显示上限的图片给出可重试结果', async () => {
  vi.mocked(net.fetch).mockResolvedValueOnce(new Response(null, { status: 403 }));
  await expect(readQqImage('https://example.com/expired')).rejects.toThrow('地址已失效');
  vi.mocked(net.fetch).mockResolvedValueOnce(
    new Response(png, { headers: { 'content-length': String(21 * 1024 * 1024) } }),
  );
  await expect(readQqImage('https://example.com/large')).rejects.toThrow('超过 20 MB');
});
