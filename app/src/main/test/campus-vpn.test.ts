import Database from 'better-sqlite3';
import { beforeEach, afterEach, describe, expect, it, vi } from 'vitest';
let db: Database.Database;
vi.mock('../database', () => ({ getDatabase: () => db }));
import {
  campusRealUrl,
  campusUrl,
  campusVpnConfig,
  decodeVpnHost,
  encodeVpnHost,
  fromVpnUrl,
  isVpnLoginUrl,
  rewriteCampusHeaders,
  setCampusVpnConfig,
  toVpnUrl,
} from '../campus-vpn';
import { JLU_WEBVPN_BASE, WEBVPN_KEY } from '../../shared/campus-vpn';

beforeEach(() => {
  db = new Database(':memory:');
  db.exec('CREATE TABLE workspace_settings(key TEXT PRIMARY KEY,value TEXT NOT NULL)');
});
afterEach(() => db.close());

const on = { mode: 'webvpn' as const, baseUrl: JLU_WEBVPN_BASE };

describe('WebVPN 地址包装', () => {
  it('matches a real JLU gateway address', () => {
    // 取自学校真实入口：https://webvpn.jlu.edu.cn/https/<这段>/defaultroot/...
    expect(encodeVpnHost('oa.jlu.edu.cn')).toBe(
      '77726476706e69737468656265737421fff60f962b2526557a1dc7af96',
    );
    expect(encodeVpnHost('oa.jlu.edu.cn').slice(0, 32)).toBe(
      Buffer.from(WEBVPN_KEY, 'utf8').toString('hex'),
    );
  });
  it('round-trips hosts of any length', () => {
    for (const host of [
      'iedu.jlu.edu.cn',
      'oa.jlu.edu.cn',
      'ilearntec.jlu.edu.cn',
      'mails.jlu.edu.cn',
      'a.b.c.d.e.f.g.h.jlu.edu.cn',
    ]) {
      expect(decodeVpnHost(encodeVpnHost(host))).toBe(host);
    }
    expect(decodeVpnHost('00ff')).toBeNull();
  });
  it('wraps campus addresses and leaves everything else alone', () => {
    expect(toVpnUrl('https://iedu.jlu.edu.cn/jwapp/sys/wdkb/x.do?a=1#top', on)).toBe(
      `${JLU_WEBVPN_BASE}/https/${encodeVpnHost('iedu.jlu.edu.cn')}/jwapp/sys/wdkb/x.do?a=1#top`,
    );
    // 非校园域、入口自身、未启用都不改写。
    expect(toVpnUrl('https://i.chaoxing.com/base', on)).toBe('https://i.chaoxing.com/base');
    expect(toVpnUrl(`${JLU_WEBVPN_BASE}/login`, on)).toBe(`${JLU_WEBVPN_BASE}/login`);
    expect(toVpnUrl('https://iedu.jlu.edu.cn/x', { ...on, mode: 'off' })).toBe(
      'https://iedu.jlu.edu.cn/x',
    );
  });
  it('keeps the port when the target is not on the default one', () => {
    const wrapped = toVpnUrl('http://jwgl.jlu.edu.cn:8080/a/b', on);
    expect(wrapped).toContain('/http-8080/');
    expect(fromVpnUrl(wrapped, on)).toBe('http://jwgl.jlu.edu.cn:8080/a/b');
  });
  it('unwraps back to the campus address and ignores foreign hosts', () => {
    const target = 'https://iedu.jlu.edu.cn/jwapp/sys/wdkb/*default/index.do?x=1';
    expect(fromVpnUrl(toVpnUrl(target, on), on)).toBe(target);
    expect(fromVpnUrl('https://iedu.jlu.edu.cn/x', on)).toBeNull();
    expect(fromVpnUrl(`${JLU_WEBVPN_BASE}/login`, on)).toBeNull();
  });
});

describe('VPN 设置', () => {
  it('defaults to direct access and persists the chosen gateway', () => {
    expect(campusVpnConfig()).toEqual({ mode: 'off', baseUrl: JLU_WEBVPN_BASE });
    expect(setCampusVpnConfig({ mode: 'webvpn' })).toEqual({
      mode: 'webvpn',
      baseUrl: JLU_WEBVPN_BASE,
    });
    expect(campusVpnConfig()).toEqual({ mode: 'webvpn', baseUrl: JLU_WEBVPN_BASE });
    expect(setCampusVpnConfig({ baseUrl: 'https://vpn.example.edu.cn/' })).toEqual({
      mode: 'webvpn',
      baseUrl: 'https://vpn.example.edu.cn',
    });
    expect(setCampusVpnConfig({ mode: 'off' })).toEqual({
      mode: 'off',
      baseUrl: 'https://vpn.example.edu.cn',
    });
  });
  it('rejects a gateway that is not an http(s) address', () => {
    expect(() => setCampusVpnConfig({ baseUrl: 'ftp://vpn.jlu.edu.cn' })).toThrow('http');
    expect(() =>
      setCampusVpnConfig({ baseUrl: 'https://vpn.jlu.edu.cn', mode: 'webvpn' }),
    ).not.toThrow();
  });
  it('falls back to direct access when the stored value is corrupt', () => {
    db.prepare('INSERT OR REPLACE INTO workspace_settings VALUES (?,?)').run(
      'campus-vpn',
      '{not json',
    );
    expect(campusVpnConfig()).toEqual({ mode: 'off', baseUrl: JLU_WEBVPN_BASE });
  });
  it('drives the shared helpers from the stored setting', () => {
    expect(campusUrl('https://iedu.jlu.edu.cn/x')).toBe('https://iedu.jlu.edu.cn/x');
    setCampusVpnConfig({ mode: 'webvpn' });
    const wrapped = campusUrl('https://iedu.jlu.edu.cn/x');
    expect(wrapped.startsWith(`${JLU_WEBVPN_BASE}/https/`)).toBe(true);
    expect(campusRealUrl(wrapped)).toBe('https://iedu.jlu.edu.cn/x');
    expect(campusRealUrl('https://iedu.jlu.edu.cn/x')).toBe('https://iedu.jlu.edu.cn/x');
  });
});

describe('VPN 请求头与登录页识别', () => {
  it('rewrites Origin and Referer to the gateway form', () => {
    const headers = {
      Origin: 'https://iedu.jlu.edu.cn',
      Referer: 'https://iedu.jlu.edu.cn/jwapp/sys/wdkb/index.do',
      Accept: 'application/json',
    };
    expect(rewriteCampusHeaders(headers)).toBe(headers);
    setCampusVpnConfig({ mode: 'webvpn' });
    const rewritten = rewriteCampusHeaders(headers)!;
    expect(rewritten.Accept).toBe('application/json');
    expect(rewritten.Origin?.startsWith(`${JLU_WEBVPN_BASE}/https/`)).toBe(true);
    expect(rewritten.Referer?.endsWith('/jwapp/sys/wdkb/index.do')).toBe(true);
  });
  it('recognises the gateway login page only while VPN is on', () => {
    expect(isVpnLoginUrl(`${JLU_WEBVPN_BASE}/login`)).toBe(false);
    setCampusVpnConfig({ mode: 'webvpn' });
    expect(isVpnLoginUrl(`${JLU_WEBVPN_BASE}/login`)).toBe(true);
    expect(isVpnLoginUrl(`${JLU_WEBVPN_BASE}/login?next=%2F`)).toBe(true);
    expect(isVpnLoginUrl(`${JLU_WEBVPN_BASE}/https/abcdef/path`)).toBe(false);
    expect(isVpnLoginUrl('https://iedu.jlu.edu.cn/login')).toBe(false);
  });
});
