import { app, net } from 'electron';
import { readFile, realpath, stat } from 'node:fs/promises';
import { isAbsolute, join, sep } from 'node:path';
import { fileTypeFromBuffer } from 'file-type';

const maxImageBytes = 20 * 1024 * 1024;

export async function readQqImage(source: string): Promise<string> {
  let bytes: Buffer;
  if (/^https?:\/\//i.test(source)) {
    const response = await net.fetch(source, {
      credentials: 'omit',
      signal: AbortSignal.timeout(20000),
    });
    if (!response.ok || !response.body) throw new Error('图片地址已失效');
    if (Number(response.headers.get('content-length')) > maxImageBytes)
      throw new Error('图片超过 20 MB，请在 QQ 中查看');
    const chunks: Uint8Array[] = [];
    let size = 0;
    for await (const chunk of response.body) {
      size += chunk.byteLength;
      if (size > maxImageBytes) throw new Error('图片超过 20 MB，请在 QQ 中查看');
      chunks.push(chunk);
    }
    bytes = Buffer.concat(chunks);
  } else {
    if (!isAbsolute(source)) throw new Error('QQ 未提供有效图片地址');
    const root = await realpath(
      join(app.getPath('home'), 'Library/Containers/com.tencent.qq/Data'),
    );
    const path = await realpath(source);
    if (!path.startsWith(`${root}${sep}`)) throw new Error('图片不在 QQ 数据目录中');
    if ((await stat(path)).size > maxImageBytes) throw new Error('图片超过 20 MB，请在 QQ 中查看');
    bytes = await readFile(path);
  }
  const type = await fileTypeFromBuffer(bytes);
  if (
    !type ||
    !['image/png', 'image/jpeg', 'image/gif', 'image/webp', 'image/avif', 'image/apng'].includes(
      type.mime,
    )
  )
    throw new Error('QQ 返回的内容不是受支持的图片');
  return `data:${type.mime};base64,${bytes.toString('base64')}`;
}
