// @vitest-environment jsdom
import { afterEach, expect, it, vi } from 'vitest';
import {
  chaoxingCoursesScript,
  chaoxingFilesScript,
  chaoxingWorksScript,
} from '../../../shared/chaoxing-collectors';
Object.defineProperty(HTMLElement.prototype, 'innerText', {
  configurable: true,
  get() {
    return (this as HTMLElement).textContent;
  },
});
afterEach(() => vi.unstubAllGlobals());
it('extracts visible course metadata and retains the official route only for main', () => {
  document.body.innerHTML = `<div class="course learnCourse"><div class="course-info"><h3><a href="https://mooc1.chaoxing.com/visit/stucoursemiddle?courseid=1&clazzid=2&enc=private"><span class="course-name" title="示例课程">示例课程</span></a></h3><p class="color3">示例教师</p></div></div>`;
  expect(window.eval(chaoxingCoursesScript)).toMatchObject({
    ready: true,
    data: [{ id: '1:2', name: '示例课程', teacher: '示例教师', ended: false }],
  });
});
it('distinguishes folders, downloadable documents and special teacher courseware', () => {
  document.body.innerHTML = `<input id="downloadDomain" value="https://mooc1.chaoxing.com"><input id="cpi" value="3"><input id="classId" value="2"><input id="courseId" value="1"><div class="dataBody"><ul class="dataBody_td" id="f1" type="afolder" dataname="课件"></ul><ul class="dataBody_td" id="d1" type="pdf" dataname="示例.pdf" isdown="1"><li class="dataBody_size_stu">12KB</li></ul><ul class="dataBody_td" type="tch-courseware"><li class="dataBody_name_stu">教师课件</li></ul></div>`;
  const result = window.eval(chaoxingFilesScript);
  expect(result.data).toMatchObject([
    { id: 'f1', type: 'afolder', downloadable: false },
    { id: 'd1', type: 'pdf', downloadable: true },
    { id: 'teacher-courseware', type: 'tch-courseware', downloadable: false },
  ]);
  expect(result.data[1].downloadUrl).toContain('/coursedata/downloadData?');
});
it('reads assignment metadata with GET without executing the answer page scripts', async () => {
  const fetch = vi.fn().mockResolvedValue({
    ok: true,
    url: 'https://mooc1.chaoxing.com/mooc-ans/mooc2/work/dowork?workId=w1',
    text: async () =>
      '<div class="infoHead"><p>作答时间：<em>2026-10-22 18:20</em>至<em>2026-11-30 18:22</em></p></div><script>fetch("/submit", {method:"POST"})</script><div class="mark_table"><p>截止时间：2020-01-01 私密作答</p><textarea>答案</textarea></div>',
  });
  vi.stubGlobal('fetch', fetch);
  document.body.innerHTML = `<div class="bottomList"><li role="link" data="https://mooc1.chaoxing.com/mooc-ans/mooc2/work/task?workId=w1&answerId=private&enc=secret"><div class="right-content"><p class="overHidden2 fl">示例作业</p><p class="status fl">未交</p></div><div class="time">剩余2天</div></li></div>`;
  const result = await window.eval(chaoxingWorksScript);
  expect(result).toEqual({
    ready: true,
    data: [
      {
        id: 'w1',
        title: '示例作业',
        status: '未交',
        timing: '剩余2天',
        url: 'https://mooc1.chaoxing.com/mooc-ans/mooc2/work/task?workId=w1&answerId=private&enc=secret',
        detailTiming: '截止时间：2026-11-30 18:22',
      },
    ],
  });
  expect(result.data[0].url).toContain('enc=secret');
  expect(fetch).toHaveBeenCalledExactlyOnceWith(
    result.data[0].url,
    expect.objectContaining({ credentials: 'include' }),
  );
  document.body.innerHTML = '<div class="bottomList">服务维护</div>';
  await expect(window.eval(chaoxingWorksScript)).rejects.toThrow('Unknown empty');
  document.body.innerHTML = '<div class="bottomList">暂无作业</div>';
  expect(await window.eval(chaoxingWorksScript)).toMatchObject({ ready: true, data: [] });
});

it('reads explicit deadline labels without collecting answer controls or hidden text', async () => {
  const { chaoxingDetailTimingScript } = await import('../../../shared/chaoxing-collectors');
  document.body.innerHTML = `<div><span>截止时间：</span><span>2026-11-02 20:00</span></div><textarea>截止时间：2020-01-01 私密作答</textarea><div contenteditable>截止时间：2020-01-01 私密编辑</div><p>Deadline: 2026-11-03 20:00</p><div hidden><p>截止时间：2020-01-01 隐藏</p></div><div style="display:none"><p>截止时间：2020-01-01 隐藏</p></div>`;
  const result = window.eval(chaoxingDetailTimingScript);
  expect(result).toContain('2026-11-02 20:00');
  expect(result).toContain('截止时间：2026-11-03 20:00');
  expect(result).not.toMatch(/2020|私密|隐藏/);
});

it.each([
  ['2026-11-07T18:00:30+08:00', '557hour20minutes left', '11-30 23:20', '2026-11-30 23:20'],
  ['2026-12-31T23:30:00+08:00', '剩余1小时29分钟', '01-01 01:00', '2027-01-01 01:00'],
])(
  'confirms the year using both platform time and remaining duration',
  async (server, timing, end, expected) => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        url: 'https://mooc1.chaoxing.com/mooc2/work/dowork?workId=w1',
        text: async () =>
          '<script>window["currentTime"] = "' +
          Date.parse(server) +
          '"</script><div class="infoHead"><p>作答时间：<em>10-22 18:20</em>至<em>' +
          end +
          '</em></p></div>',
      }),
    );
    document.body.innerHTML =
      '<div class="bottomList"><li role="link" data="https://mooc1.chaoxing.com/mooc2/work/task?workId=w1&answerId=123"><div class="right-content"><p class="overHidden2">作业</p><p class="status">To be Submitted</p></div><div class="time">' +
      timing +
      '</div></li></div>';
    expect((await window.eval(chaoxingWorksScript)).data[0]).toMatchObject({
      status: 'To be Submitted',
      detailTiming: '截止时间：' + expected,
    });
  },
);

it('keeps a yearless deadline unresolved when the platform evidence does not match', async () => {
  vi.stubGlobal(
    'fetch',
    vi.fn().mockResolvedValue({
      ok: true,
      url: 'https://mooc1.chaoxing.com/mooc2/work/dowork?workId=w1',
      text: async () =>
        '<script>window["currentTime"] = "' +
        Date.parse('2026-11-07T18:00:00+08:00') +
        '"</script><div class="infoHead"><p>作答时间：10-22 18:20至11-30 18:22</p></div>',
    }),
  );
  document.body.innerHTML =
    '<div class="bottomList"><li role="link" data="https://mooc1.chaoxing.com/mooc2/work/task?workId=w1"><div class="right-content"><p class="overHidden2">作业</p><p class="status">待批阅</p></div><div class="time">剩余2小时0分钟</div></li></div>';
  expect((await window.eval(chaoxingWorksScript)).data[0].detailTiming).toBe(
    '截止时间：11-30 18:22（年份待确认）',
  );
});

it('reads the two date elements in the official header regardless of page language', async () => {
  const { chaoxingDetailTimingScript } = await import('../../../shared/chaoxing-collectors');
  document.body.innerHTML =
    '<div class="infoHead"><span>题量: 1</span><span>满分: 100</span><p>Time range: <em>2026-10-22 18:20</em> to <em>2026-11-30 18:22</em></p></div>';
  expect(window.eval(chaoxingDetailTimingScript)).toBe('截止时间：2026-11-30 18:22');
});

it('keeps list status and timing when detail requests fail', async () => {
  vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new Error('offline')));
  document.body.innerHTML =
    '<div class="bottomList"><li role="link" data="https://mooc1.chaoxing.com/mooc2/work/task?workId=w1"><div class="right-content"><p class="overHidden2">作业</p><p class="status">To be marked</p></div><div class="time">剩余2小时0分钟</div></li></div>';
  expect((await window.eval(chaoxingWorksScript)).data[0]).toMatchObject({
    status: 'To be marked',
    timing: '剩余2小时0分钟',
    detailError: '作业详情暂时无法读取，请稍后刷新',
  });
});

it('uses a full deadline tooltip without fetching an answer page', async () => {
  const fetch = vi.fn();
  vi.stubGlobal('fetch', fetch);
  document.body.innerHTML =
    '<div class="bottomList"><li role="link" data="https://mooc1.chaoxing.com/mooc2/work/task?workId=w1"><div class="right-content"><p class="overHidden2">作业</p><p class="status">Completed</p></div><div class="time" title="2026-11-30 18:22">剩余2天</div></li></div>';
  expect((await window.eval(chaoxingWorksScript)).data[0].detailTiming).toBe(
    '截止时间：2026-11-30 18:22',
  );
  expect(fetch).not.toHaveBeenCalled();
});
