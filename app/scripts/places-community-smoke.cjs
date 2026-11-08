// 校园地图与校园社区的端到端冒烟：走真实 IPC + SQLite + 界面，确认骨架功能真的可用。
const { app } = require('electron');
const { dirname, join, resolve } = require('node:path');
const { mkdtempSync } = require('node:fs');
const { tmpdir } = require('node:os');
const assert = require('node:assert/strict');

const root = resolve(process.argv[2] || '.');
app.setAppPath(root);
if (root.endsWith('.asar')) {
  Object.defineProperty(app, 'isPackaged', { value: true });
  process.resourcesPath = dirname(root);
}
const profile = mkdtempSync(join(tmpdir(), 'places-community-smoke-'));
for (const name of ['userData', 'documents', 'home']) app.setPath(name, profile);
process.argv.push('--terminal-smoke-test');
app.once('browser-window-created', (_event, window) => {
  window.webContents.setBackgroundThrottling(false);
  window.webContents.once('did-finish-load', () => {
    void run(window).then(
      () => app.exit(0),
      (error) => {
        console.error(error);
        app.exit(1);
      },
    );
  });
});
require(join(root, 'out/main/index.cjs'));

async function run(window) {
  const js = (source) => window.webContents.executeJavaScript(`(async () => { ${source} })()`);
  const wait = async (source, label) => {
    const deadline = Date.now() + 20000;
    while (Date.now() < deadline) {
      if (await js(source)) return;
      await new Promise((done) => setTimeout(done, 50));
    }
    throw new Error(`Timed out: ${label}`);
  };
  const fails = async (source, label) => {
    try {
      await js(source);
    } catch {
      return;
    }
    throw new Error(`Expected failure: ${label}`);
  };

  await wait('return !!window.dela && !!document.querySelector("#main-nav")', 'workspace ready');
  assert.equal(await js('return typeof window.dela.places'), 'object');
  assert.equal(await js('return typeof window.dela.places.get'), 'function');
  assert.equal(await js('return typeof window.dela.community.get'), 'function');

  // ---------- 校园地图：数据与检索 ----------
  const places = await js('return await window.dela.places.get()');
  assert.ok(places.campuses.length >= 3, '示例校区');
  assert.ok(places.buildings.length >= 5, '示例楼宇');
  assert.ok(places.offices.length >= 10, '示例办公室');
  assert.ok(
    places.offices.every((office) => office.source === 'demo' && office.verifiedAt === null),
    '示例地点必须标注来源且未核实',
  );
  assert.ok(
    places.services.every((service) => places.offices.some((row) => row.id === service.officeId)),
    '办事事项必须挂在真实办公室上',
  );
  assert.ok(
    places.teachers.every((teacher) => places.offices.some((row) => row.id === teacher.officeId)),
    '老师必须挂在真实办公室上',
  );

  const teacherHits = await js("return await window.dela.places.search({ text: '张伟' })");
  assert.ok(
    teacherHits.some((hit) => hit.kind === 'teacher' && hit.officeId),
    '按老师姓名检索要能落到办公室',
  );
  const serviceHits = await js("return await window.dela.places.search({ text: '发票报销' })");
  assert.ok(
    serviceHits.some((hit) => hit.kind === 'service'),
    '按事项检索要能命中事项',
  );
  const nanling = await js("return await window.dela.places.search({ campusId: 'nanling' })");
  assert.ok(nanling.length > 0, '按校区筛选应有结果');
  const nanlingBuildings = new Set(
    places.buildings.filter((row) => row.campusId === 'nanling').map((row) => row.id),
  );
  const officesById = new Map(places.offices.map((row) => [row.id, row]));
  assert.ok(
    nanling.every((hit) => nanlingBuildings.has(officesById.get(hit.officeId).buildingId)),
    '校区筛选不能返回其他校区的地点',
  );

  // ---------- 校园地图：上报、纠错与重新生成 ----------
  const officeName = '冒烟测试办事窗口';
  const saved = await js(
    `return await window.dela.places.saveOffice({ buildingId: 'dx', floor: '6 层', room: 'C 区 601', name: '${officeName}', kind: 'service', departmentIds: ['cs'] })`,
  );
  const savedOffice = saved.offices.find((row) => row.name === officeName);
  assert.ok(savedOffice, '新增地点应出现在快照里');
  assert.equal(savedOffice.source, 'user', '同学上报的地点标记为 user');
  const reread = await js('return await window.dela.places.get()');
  assert.ok(
    reread.offices.some((row) => row.id === savedOffice.id),
    '新增地点应持久化到本机数据库',
  );
  await fails(
    "return await window.dela.places.saveOffice({ buildingId: 'missing', floor: '', room: '', name: '无主地点', kind: 'office' })",
    '不存在的楼宇',
  );

  const corrected = await js(
    `return await window.dela.places.submitCorrection({ target: 'office', targetId: '${savedOffice.id}', targetName: '${officeName}', message: '房间号已变更为 C 区 602' })`,
  );
  const correction = corrected.corrections[0];
  assert.equal(correction.status, 'pending', '新纠错待处理');
  const reviewed = await js(
    `return await window.dela.places.reviewCorrection('${correction.id}', 'accepted')`,
  );
  assert.equal(
    reviewed.corrections.find((row) => row.id === correction.id).status,
    'accepted',
    '纠错可以标记采纳',
  );

  const regenerated = await js('return await window.dela.places.regenerateDemo()');
  assert.ok(
    regenerated.offices.some((row) => row.id === savedOffice.id),
    '重新生成示例内容要保留同学上报的地点',
  );
  assert.ok(
    regenerated.corrections.some((row) => row.id === correction.id),
    '重新生成示例内容要保留纠错记录',
  );
  assert.ok(regenerated.offices.length >= places.offices.length, '重新生成后仍有完整示例数据');

  // ---------- 校园社区：发帖与审核 ----------
  const community = await js('return await window.dela.community.get()');
  assert.ok(community.posts.length >= 10, '示例帖子');
  assert.ok(community.viewer, '本机演示身份');
  assert.ok(
    community.posts.some((post) => post.status === 'unverified'),
    '示例里应包含来源待核实的科研信息',
  );

  const researchTitle = '冒烟测试科研信息';
  const research = await js(
    `return await window.dela.community.create({ board: 'research', title: '${researchTitle}', body: '这是一条用于冒烟测试的科研招募信息，请忽略。' })`,
  );
  const researchPost = research.posts.find((post) => post.title === researchTitle);
  assert.equal(researchPost.status, 'unverified', '科研信息缺来源要标为待核实');
  assert.equal(researchPost.author, community.viewer);

  const blockedTitle = '冒烟测试违规内容';
  const blocked = await js(
    `return await window.dela.community.create({ board: 'talk', title: '${blockedTitle}', body: '这里可以代写课程论文，价格优惠，欢迎咨询。' })`,
  );
  const blockedPost = blocked.posts.find((post) => post.title === blockedTitle);
  assert.equal(blockedPost.status, 'rejected', '命中禁止词要拦截');
  await fails(
    `return await window.dela.community.like('${blockedPost.id}')`,
    '未通过审核的帖子点赞',
  );

  const liked = await js("return await window.dela.community.like('demo-talk-1')");
  assert.equal(liked.posts.find((post) => post.id === 'demo-talk-1').liked, true, '点赞');
  const replied = await js(
    "return await window.dela.community.reply('demo-talk-1', '冒烟测试回复')",
  );
  assert.equal(
    replied.posts.find((post) => post.id === 'demo-talk-1').replies.length,
    3,
    '回复应追加到列表',
  );
  const reported = await js("return await window.dela.community.report('demo-food-1')");
  assert.equal(reported.posts.find((post) => post.id === 'demo-food-1').reports, 1, '举报计数');
  const moderated = await js(
    `return await window.dela.community.moderate('${researchPost.id}', 'publish')`,
  );
  assert.equal(
    moderated.posts.find((post) => post.id === researchPost.id).status,
    'published',
    '人工复核通过后发布',
  );
  const removed = await js(`return await window.dela.community.remove('${blockedPost.id}')`);
  assert.ok(!removed.posts.some((post) => post.id === blockedPost.id), '自己的帖子可以删除');
  await fails("return await window.dela.community.remove('demo-talk-2')", '删除他人帖子');

  const keepTitle = '冒烟测试保留帖子';
  await js(
    `return await window.dela.community.create({ board: 'talk', title: '${keepTitle}', body: '用于验证重新生成示例内容后自己的帖子仍然存在。' })`,
  );
  const fresh = await js('return await window.dela.community.regenerateDemo()');
  assert.ok(
    fresh.posts.some((post) => post.title === keepTitle),
    '重新生成示例要保留自己发布的帖子',
  );
  assert.ok(fresh.posts.length >= community.posts.length, '重新生成后仍有完整示例内容');

  // ---------- 界面：两个新页面都能打开并渲染 ----------
  await js(
    `Array.from(document.querySelectorAll('button')).find((item) => item.textContent.trim() === '校园地图').click()`,
  );
  await wait(
    'return document.querySelector("h1")?.textContent === "校园地图与办事地点"',
    '校园地图页面',
  );
  await wait('return !!document.querySelector("[aria-label=\'检索结果\']")', '检索结果列表');
  assert.ok(
    (
      await js('return document.querySelector("[aria-label=\'地点详情\']")?.textContent ?? ""')
    ).includes('示例数据'),
    '地点详情要标明示例来源',
  );

  await js(
    `Array.from(document.querySelectorAll('button')).find((item) => item.textContent.trim() === '校园社区').click()`,
  );
  await wait('return document.querySelector("h1")?.textContent === "校园社区"', '校园社区页面');
  await wait('return !!document.querySelector("[aria-label=\'帖子列表\']")', '帖子列表');
  assert.ok(
    (await js('return document.querySelector("[aria-label=\'帖子详情\']")?.textContent ?? ""'))
      .length > 0,
    '社区详情要能渲染',
  );
}
