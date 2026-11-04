const { app, BrowserWindow, net } = require('electron');
const { EventEmitter } = require('node:events');
const { mkdtempSync, mkdirSync, writeFileSync } = require('node:fs');
const { tmpdir } = require('node:os');
const { dirname, join, resolve } = require('node:path');
const assert = require('node:assert/strict');

const root = resolve(process.argv[2] || '.');
app.setAppPath(root);
if (root.endsWith('.asar')) {
  Object.defineProperty(app, 'isPackaged', { value: true });
  process.resourcesPath = dirname(root);
}
const profile = mkdtempSync(join(tmpdir(), 'jlu-timetable-smoke-'));
for (const name of ['userData', 'home', 'documents']) app.setPath(name, profile);
process.argv.push('--terminal-smoke-test');
const schoolUrl = 'https://iedu.jlu.edu.cn/jwapp/sys/wdkb/*default/index.do';
// 校外 VPN：学校 WebVPN 入口与 iedu 的加密主机（AES-128-CFB，key=IV=wrdvpnisthebest!）。
const vpnRoot = 'https://webvpn.jlu.edu.cn';
const encodedIedu = (() => {
  const key = Buffer.from('wrdvpnisthebest!', 'utf8');
  const host = 'iedu.jlu.edu.cn';
  const padded = host + '0'.repeat((16 - (host.length % 16)) % 16);
  const cipher = require('node:crypto').createCipheriv('aes-128-cfb', key, key);
  const encrypted = Buffer.concat([cipher.update(Buffer.from(padded, 'utf8')), cipher.final()]);
  return key.toString('hex') + encrypted.toString('hex').slice(0, host.length * 2);
})();
let vpnExpired = false;
let failure = 'none';
let recovery = 'automatic';
const schoolWindows = [];
let loginPreferences;
const requests = [];
const fixture = {
  dqxnxq: [{ DM: '2026-2027-1' }],
  cxxszhxqkb: [
    {
      KBID: 'synthetic',
      KCM: '测试课程',
      KCH: 'DEMO',
      SKJS: '测试教师/fixture',
      JASMC: '测试教室',
      SKXQ: '1',
      KSJC: '1',
      JSJC: '2',
      SKZC: '1111111111111111',
    },
  ],
  jc: [
    { DM: '1', KSSJ: '09:10', JSSJ: '09:55', SFSY: '1' },
    { DM: '2', KSSJ: '10:05', JSSJ: '10:50', SFSY: '1' },
  ],
  cxxljc: [{ XQKSRQ: '2026-09-14', ZZC: '20' }],
  xsdkkc: [],
  xswpkc: [],
};
net.request = (options) => {
  const target = new URL(options.url);
  assert.ok(
    target.hostname === 'iedu.jlu.edu.cn' || target.hostname === 'webvpn.jlu.edu.cn',
    `unexpected host: ${target.hostname}`,
  );
  assert.equal(options.useSessionCookies, true);
  const request = new EventEmitter();
  let body = '';
  request.setHeader = () => {};
  request.write = (value) => {
    body += value;
  };
  request.abort = () => {};
  request.end = (value) => {
    body += value ?? '';
    requests.push({ url: options.url, body });
    setImmediate(() => {
      // VPN 入口本身：未登录时跳登录页，用来说明「能连上但还没登录」。
      if (target.hostname === 'webvpn.jlu.edu.cn' && target.pathname === '/') {
        request.emit('redirect', 302, 'GET', `${vpnRoot}/login`, {});
        return;
      }
      if (vpnExpired && target.hostname === 'webvpn.jlu.edu.cn') {
        request.emit('redirect', 302, 'GET', `${vpnRoot}/login?next=%2F`, {});
        return;
      }
      if (failure === 'offline') return request.emit('error', new Error('fixture offline'));
      if (failure === 'expired' || failure === 'redirect') {
        request.emit(
          'redirect',
          302,
          'GET',
          failure === 'expired'
            ? 'https://cas.jlu.edu.cn/tpass/login?service=iedu'
            : 'https://iedu.jlu.edu.cn/maintenance',
          {},
        );
        return;
      }
      const key = new URL(options.url).pathname.split('/').pop().replace('.do', '');
      assert.ok(Object.hasOwn(fixture, key), `unexpected fixture: ${key}`);
      const response = new EventEmitter();
      response.statusCode = failure === 'forbidden' ? 403 : failure === 'server' ? 500 : 200;
      request.emit('response', response);
      response.emit(
        'data',
        Buffer.from(
          JSON.stringify(
            failure === 'schema'
              ? { code: '0', datas: {} }
              : {
                  code: '0',
                  datas: {
                    [key]: {
                      rows: fixture[key],
                      totalSize: ['jc', 'cxxszhxqkb'].includes(key) ? -1 : fixture[key].length,
                      ...(key === 'cxxszhxqkb' ? { pageSize: 0, pageNumber: 0 } : {}),
                    },
                  },
                },
          ),
        ),
      );
      response.emit('end');
    });
  };
  return request;
};
const originalLoad = BrowserWindow.prototype.loadURL;
BrowserWindow.prototype.loadURL = function (url, options) {
  if (url !== schoolUrl) return originalLoad.call(this, url, options);
  loginPreferences = this.webContents.getLastWebPreferences();
  const hidden = !this.isVisible();
  schoolWindows.push({ window: this, hidden, preferences: loginPreferences });
  if (hidden && recovery === 'network') return Promise.reject(new Error('fixture offline'));
  if (hidden && recovery === 'schema') failure = 'schema';
  else if (!hidden || recovery === 'automatic') failure = 'none';
  const target =
    hidden && recovery === 'manual' ? 'https://cas.jlu.edu.cn/tpass/login?service=iedu' : schoolUrl;
  this.webContents.getURL = () => target;
  this.hide();
  this.webContents.once('did-finish-load', () => this.webContents.emit('did-navigate', {}, target));
  return originalLoad.call(
    this,
    'data:text/html,<title>School login fixture</title>' +
      (target === schoolUrl
        ? '<p>Test fixture</p>'
        : '<form id="loginForm"><input type="password"></form>'),
    options,
  );
};
app.once('browser-window-created', (_event, window) => {
  window.webContents.setBackgroundThrottling(false);
  window.webContents.once(
    'did-finish-load',
    () =>
      void run(window).then(
        () => app.exit(0),
        (error) => {
          console.error(error);
          app.exit(1);
        },
      ),
  );
});
require(join(root, 'out/main/index.cjs'));

async function run(window) {
  const js = (source) => window.webContents.executeJavaScript(source);
  const wait = async (source) => {
    const deadline = Date.now() + 15000;
    while (Date.now() < deadline) {
      if (await js(source)) return;
      await new Promise((resolve) => setTimeout(resolve, 50));
    }
    throw new Error(`Timed out: ${source}`);
  };
  await wait('!!window.dela && !!document.querySelector("#main-nav")');
  await js(
    `Array.from(document.querySelectorAll('#main-nav button')).find((button) => button.textContent.trim() === '课表').click()`,
  );
  await wait('document.body.textContent.includes("打开教务认证")');
  await js(
    `Array.from(document.querySelectorAll('button')).find((button) => button.textContent.trim() === '打开教务认证').click()`,
  );
  await wait('window.dela.timetable.getState().then((state) => !!state.lastSyncedAt)');
  assert.equal(loginPreferences.sandbox, true);
  assert.equal(loginPreferences.contextIsolation, true);
  assert.ok(!loginPreferences.preload);
  let state = await js('window.dela.timetable.getState()');
  let lessons = await js('window.dela.timetable.listLessons()');
  assert.equal(state.semesterStart, '2026-09-14');
  assert.equal(state.totalWeeks, 20);
  assert.equal(lessons[0].startMinute, 550);
  assert.equal(lessons[0].endMinute, 650);
  await js(
    `Array.from(document.querySelectorAll('#main-nav button')).find((button) => button.textContent.trim() === '课表').click()`,
  );
  await wait('document.body.textContent.includes("测试课程")');
  window.setMinimumSize(360, 500);
  for (const width of [600, 900, 1280, 1800]) {
    window.setSize(width, 850);
    await js(
      'new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)))',
    );
    assert.equal(
      await js('document.documentElement.scrollWidth <= document.documentElement.clientWidth'),
      true,
      `overflow at ${width}`,
    );
    if (width === 1280 && !root.endsWith('.asar')) {
      await js(
        'Promise.all(document.getAnimations().filter((animation) => animation.effect?.getComputedTiming().iterations !== Infinity).map((animation) => animation.finished.catch(() => {})))',
      );
      mkdirSync('.build', { recursive: true });
      writeFileSync(
        '.build/jlu-timetable-fixture.png',
        (await window.webContents.capturePage()).toPNG(),
      );
    }
  }
  let count = schoolWindows.length;
  failure = 'expired';
  assert.equal((await js('window.dela.timetable.syncNow("2026-2027-1")')).ok, true);
  assert.equal(schoolWindows.length, count + 1);
  assert.equal(schoolWindows.at(-1).hidden, true);
  assert.equal(schoolWindows.at(-1).window.isDestroyed(), true);
  state = await js('window.dela.timetable.getState()');
  lessons = await js('window.dela.timetable.listLessons()');
  for (const mode of ['offline', 'forbidden', 'server', 'redirect', 'schema']) {
    failure = mode;
    count = schoolWindows.length;
    const result = await js('window.dela.timetable.syncNow("2026-2027-1")');
    assert.equal(result.ok, false, mode);
    assert.equal(result.reason, undefined, mode);
    assert.equal(schoolWindows.length, count, mode);
    assert.deepEqual(await js('window.dela.timetable.getState()'), state);
    assert.deepEqual(await js('window.dela.timetable.listLessons()'), lessons);
  }
  for (const mode of ['manual', 'network', 'schema']) {
    recovery = mode;
    failure = 'expired';
    const result = await js('window.dela.timetable.syncNow("2026-2027-1")');
    assert.equal(result.ok, false, mode);
    assert.equal(result.reason, mode === 'manual' ? 'auth' : undefined, mode);
    assert.equal(schoolWindows.at(-1).hidden, true);
    assert.equal(schoolWindows.at(-1).window.isDestroyed(), true);
    assert.deepEqual(await js('window.dela.timetable.getState()'), state);
    assert.deepEqual(await js('window.dela.timetable.listLessons()'), lessons);
  }
  recovery = 'manual';
  failure = 'expired';
  count = schoolWindows.length;
  await js(`document.querySelector('button[aria-label="同步课表"]').click()`);
  await wait(
    `window.dela.timetable.getState().then((value) => value.lastSyncedAt !== ${JSON.stringify(state.lastSyncedAt)})`,
  );
  assert.equal(schoolWindows.length, count + 2);
  assert.equal(schoolWindows.at(-2).hidden, true);
  assert.equal(schoolWindows.at(-1).hidden, false);
  assert.ok(schoolWindows.slice(count).every((item) => item.window.isDestroyed()));

  failure = 'forbidden';
  count = schoolWindows.length;
  await wait(`!document.querySelector('button[aria-label="同步课表"]').disabled`);
  await js(`document.querySelector('button[aria-label="同步课表"]').click()`);
  await wait('document.body.textContent.includes("403")');
  assert.equal(schoolWindows.length, count);
  assert.ok(
    requests.some((request) => new URLSearchParams(request.body).get('XNXQDM') === '2026-2027-1'),
  );

  // 校外 VPN：启用后所有校园请求改走入口地址，入口登录失效时给出明确提示。
  failure = 'none';
  assert.equal((await js('window.dela.campusVpn.get()')).mode, 'off');
  await js('window.dela.campusVpn.set({ mode: "webvpn" })');
  assert.equal((await js('window.dela.campusVpn.get()')).mode, 'webvpn');
  const status = await js('window.dela.campusVpn.status()');
  assert.equal(status.reachable, true, 'gateway reachable');
  assert.equal(status.authenticated, false, 'gateway login not yet done');

  let mark = requests.length;
  const wrapped = await js('window.dela.timetable.syncNow("2026-2027-1")');
  assert.equal(wrapped.ok, true);
  const wrappedUrls = requests.slice(mark).map((request) => request.url);
  assert.ok(wrappedUrls.length > 0, 'requests issued through the gateway');
  assert.ok(
    wrappedUrls.every((url) => url.startsWith(`${vpnRoot}/https/`)),
    'every campus request goes through the gateway',
  );
  assert.ok(
    wrappedUrls.every((url) => url.includes(`/https/${encodedIedu}/`)),
    'gateway address carries the encrypted campus host',
  );

  vpnExpired = true;
  const expired = await js('window.dela.timetable.syncNow("2026-2027-1")');
  assert.equal(expired.ok, false);
  assert.equal(expired.reason, 'auth');
  assert.ok(expired.error.includes('VPN'), 'VPN expiry is explained');

  vpnExpired = false;
  await js('window.dela.campusVpn.set({ mode: "off" })');
  mark = requests.length;
  const direct = await js('window.dela.timetable.syncNow("2026-2027-1")');
  assert.equal(direct.ok, true);
  assert.ok(
    requests.slice(mark).every((request) => new URL(request.url).hostname === 'iedu.jlu.edu.cn'),
    'turning VPN off goes back to direct requests',
  );

  console.log(
    'Timetable smoke passed with synthetic fixtures: login, SSO recovery, manual-only authentication, error classification, VPN gateway wrapping and expiry guidance, cache preservation, clock times, and four viewport widths. No school account or live school request was used.',
  );
}
