import { createCipheriv, createDecipheriv } from 'node:crypto';
import { z } from 'zod';
import { JLU_WEBVPN_BASE, WEBVPN_KEY, type CampusVpnConfig } from '../shared/campus-vpn';
import { getDatabase } from './database';

const SETTING_KEY = 'campus-vpn';

/**
 * 学校 WebVPN（网瑞达）把内网地址包成 `<入口>/<协议>/<加密主机><路径>`：
 * 主机名补 0 到 16 的倍数，用 wrdvpnisthebest! 同时作 key 与 IV 做 AES-128-CFB 加密，
 * 输出 IV 的十六进制前缀加截断到原长度的密文。各校部署规则一致，
 * 已用吉林大学真实入口地址（oa.jlu.edu.cn）校验。
 */
export function encodeVpnHost(host: string, key: string = WEBVPN_KEY): string {
  const length = host.length;
  const remainder = length % 16;
  const padded = remainder ? host + '0'.repeat(16 - remainder) : host;
  const cipher = createCipheriv('aes-128-cfb', Buffer.from(key, 'utf8'), Buffer.from(key, 'utf8'));
  const encrypted = Buffer.concat([
    cipher.update(Buffer.from(padded, 'utf8')),
    cipher.final(),
  ]).toString('hex');
  return Buffer.from(key, 'utf8').toString('hex') + encrypted.slice(0, length * 2);
}

/**
 * 反向解析加密主机；结构不对时返回 null，不抛错。
 * CFB 是流模式，密文按原长度截断后直接解密即可，不需要补块或去填充。
 */
export function decodeVpnHost(encoded: string, key: string = WEBVPN_KEY): string | null {
  const prefix = Buffer.from(key, 'utf8').toString('hex');
  if (!encoded.startsWith(prefix)) return null;
  const body = encoded.slice(prefix.length);
  if (!body.length || body.length % 2) return null;
  try {
    const decipher = createDecipheriv(
      'aes-128-cfb',
      Buffer.from(key, 'utf8'),
      Buffer.from(key, 'utf8'),
    );
    const plain = Buffer.concat([
      decipher.update(Buffer.from(body, 'hex')),
      decipher.final(),
    ]).toString('utf8');
    return /^[a-z0-9.-]+$/i.test(plain) ? plain : null;
  } catch {
    return null;
  }
}

function normalizeBase(value: string): string {
  const url = new URL(value.trim());
  if (url.protocol !== 'https:' && url.protocol !== 'http:')
    throw new Error('VPN 入口需要以 http:// 或 https:// 开头');
  if (url.username || url.password) throw new Error('VPN 入口不能包含账号密码');
  return `${url.origin}${url.pathname.replace(/\/+$/, '')}`;
}

export const DEFAULT_VPN_CONFIG: CampusVpnConfig = { mode: 'off', baseUrl: JLU_WEBVPN_BASE };

export function campusVpnConfig(): CampusVpnConfig {
  try {
    const row = getDatabase()
      .prepare('SELECT value FROM workspace_settings WHERE key=?')
      .get(SETTING_KEY) as { value?: string } | undefined;
    if (!row?.value) return DEFAULT_VPN_CONFIG;
    const parsed = z
      .object({ mode: z.enum(['off', 'webvpn']), baseUrl: z.string() })
      .safeParse(JSON.parse(row.value));
    if (!parsed.success) return DEFAULT_VPN_CONFIG;
    return {
      mode: parsed.data.mode,
      baseUrl: normalizeBase(parsed.data.baseUrl || JLU_WEBVPN_BASE),
    };
  } catch {
    // 设置表尚未建立或内容损坏时按直连处理，不影响其他功能。
    return DEFAULT_VPN_CONFIG;
  }
}

export function setCampusVpnConfig(patch: Partial<CampusVpnConfig>): CampusVpnConfig {
  const current = campusVpnConfig();
  const next: CampusVpnConfig = {
    mode: patch.mode ?? current.mode,
    baseUrl: normalizeBase(patch.baseUrl ?? current.baseUrl),
  };
  getDatabase()
    .prepare('INSERT OR REPLACE INTO workspace_settings(key,value) VALUES(?,?)')
    .run(SETTING_KEY, JSON.stringify(next));
  return next;
}

const isCampusHost = (host: string) => host === 'jlu.edu.cn' || host.endsWith('.jlu.edu.cn');

/** 入口可能部署在子路径下，拼地址时统一去掉末尾斜杠。 */
const basePrefix = (base: URL) => base.pathname.replace(/\/+$/, '');

/** 把校园内网地址换成 VPN 入口地址；入口本身、非校园域或未启用时原样返回。 */
export function toVpnUrl(
  target: string,
  config: CampusVpnConfig = campusVpnConfig(),
  key: string = WEBVPN_KEY,
): string {
  if (config.mode !== 'webvpn') return target;
  let url: URL;
  let base: URL;
  try {
    url = new URL(target);
    base = new URL(config.baseUrl);
  } catch {
    return target;
  }
  if (url.host === base.host || !isCampusHost(url.hostname)) return target;
  const defaultPort = url.protocol === 'https:' ? '443' : '80';
  const suffix = url.port && url.port !== defaultPort ? `-${url.port}` : '';
  return `${base.origin}${basePrefix(base)}/${url.protocol.replace(':', '')}${suffix}/${encodeVpnHost(url.hostname, key)}${url.pathname}${url.search}${url.hash}`;
}

/** 从 VPN 地址还原真实内网地址；不是 VPN 地址时返回 null。 */
export function fromVpnUrl(
  value: string,
  config: CampusVpnConfig = campusVpnConfig(),
  key: string = WEBVPN_KEY,
): string | null {
  let url: URL;
  let base: URL;
  try {
    url = new URL(value);
    base = new URL(config.baseUrl);
  } catch {
    return null;
  }
  if (url.host !== base.host) return null;
  const prefix = basePrefix(base);
  if (!url.pathname.startsWith(`${prefix}/`)) return null;
  const rest = url.pathname.slice(prefix.length + 1);
  const [scheme, encoded, ...tail] = rest.split('/');
  if (!scheme || !encoded) return null;
  const match = /^(https?)(?:-(\d+))?$/.exec(scheme);
  if (!match) return null;
  const host = decodeVpnHost(encoded, key);
  if (!host) return null;
  return `${match[1]}://${host}${match[2] ? `:${match[2]}` : ''}/${tail.join('/')}${url.search}${url.hash}`;
}

/** 校园内网地址在启用 VPN 时换成入口地址，供会话请求与登录窗共用。 */
export function campusUrl(target: string): string {
  return toVpnUrl(target, campusVpnConfig());
}

/** 主体报告的地址可能是 VPN 地址；还原成校园地址再判断登录域。 */
export function campusRealUrl(value: string): string {
  return fromVpnUrl(value, campusVpnConfig()) ?? value;
}

/** 该地址是否是 VPN 入口的登录页（未登录时入口会跳到这里）。 */
export function isVpnLoginUrl(value: string): boolean {
  const config = campusVpnConfig();
  if (config.mode !== 'webvpn') return false;
  try {
    const url = new URL(value);
    const base = new URL(config.baseUrl);
    if (url.host !== base.host) return false;
    const prefix = basePrefix(base);
    if (!url.pathname.startsWith(`${prefix}/`)) return false;
    return /^\/(?:login|auth|sso|cas)(?:\/|$)/i.test(url.pathname.slice(prefix.length));
  } catch {
    return false;
  }
}

/** 请求头里的 Origin/Referer 也换成 VPN 地址，避免入口拒绝同源校验。 */
export function rewriteCampusHeaders(
  headers: Record<string, string> | undefined,
): Record<string, string> | undefined {
  if (!headers) return headers;
  const config = campusVpnConfig();
  if (config.mode !== 'webvpn') return headers;
  const next: Record<string, string> = {};
  for (const [name, value] of Object.entries(headers))
    next[name] = /^(origin|referer)$/i.test(name) ? toVpnUrl(value, config) : value;
  return next;
}
