export const chaoxingEntryScript = `(() => {
  const heading=document.getElementById('first21583') || [...document.querySelectorAll('h3')].find(el=>/^(课程|courses)$/i.test(el.textContent.trim()));
  if(!heading) return {ready:false};
  if(!document.documentElement.dataset.delaCourses) {document.documentElement.dataset.delaCourses='1';heading.click();}
  const frame=document.querySelector('iframe#frame_content');
  const url=frame?.src && new URL(frame.src);
  return url?.hostname==='mooc2-ans.chaoxing.com' && url.pathname==='/visit/interaction' ? {ready:true,data:{url:url.href}} : {ready:false};
})()`;
export const chaoxingCoursesScript = `(() => {
  const cards=[...document.querySelectorAll('.course.learnCourse')];
  if(!cards.length) {
    if(/暂无课程|还没有课程/.test(document.body.innerText)) return {ready:true,data:[]};
    return {ready:false};
  }
  return {ready:true,data:cards.map(row=>{
    const link=row.querySelector('h3 a[href]'), name=row.querySelector('.course-name');
    const url=link && new URL(link.href), courseId=url?.searchParams.get('courseid'),classId=url?.searchParams.get('clazzid');
    return {id:courseId+':'+classId,name:name?.getAttribute('title')||name?.textContent.trim(),teacher:row.querySelector('.course-info .color3')?.textContent.trim()||'',ended:!!row.querySelector('.not-open-tip'),url:url?.href};
  })};
})()`;
export function chaoxingFrameScript(kind: 'files' | 'works'): string {
  return `(() => {
    const frame=document.querySelector(${JSON.stringify(kind === 'files' ? 'iframe#frame_content-zl' : 'iframe#frame_content-zy')});
    return frame?.src ? {ready:true,data:{url:frame.src}} : {ready:false};
  })()`;
}
export const chaoxingFilesScript = `(() => {
  const body=document.querySelector('.dataBody');
  if(!body) return {ready:false};
  const rows=[...body.querySelectorAll('.dataBody_td')];
  if(!rows.length && !/暂无|没有|无资料|无文件/.test(body.innerText)) throw new Error('Unknown empty resources');
  const field=id=>document.getElementById(id)?.value || '';
  const items=rows.map(row=>{
    const type=row.getAttribute('type')||'', id=row.id || 'teacher-courseware';
    const name=row.getAttribute('dataname') || row.querySelector('.dataBody_name_stu')?.textContent.trim();
    let folderUrl=null,downloadUrl=null;
    if(type==='afolder') {
      const url=new URL(location.href);
      for(const [key,value] of Object.entries({dataId:id,dataName:name,type:'1',parent:[...document.querySelectorAll('.subtitleId')].map(e=>e.id).join(','),flag:'0',enc:field('enc'),cpi:field('cpi'),ut:field('ut')||'s',microTopicId:field('microTopicId')})) url.searchParams.set(key,value);
      folderUrl=url.href;
    } else if(row.getAttribute('isdown')==='1' && field('downloadDomain')) {
      const url=new URL(field('downloadDomain')+'/coursedata/downloadData');
      for(const [key,value] of Object.entries({dataId:id,classId:field('classId'),cpi:field('cpi'),courseId:field('courseId'),ut:'s'})) url.searchParams.set(key,value);
      downloadUrl=url.href;
    }
    return {id,name,type,size:row.querySelector('.dataBody_size_stu')?.textContent.trim()||'',creator:row.querySelector('.dataBody_creater_stu')?.textContent.trim()||'',date:row.querySelector('.dataBody_time_stu')?.textContent.trim()||'',downloadable:!!downloadUrl,folderUrl,downloadUrl};
  });
  return {ready:true,data:items};
})()`;
const workTimingReader = String.raw`(root, context = {}) => {
  const clean = value => (value ?? '').replace(/\s+/g, ' ').trim();
  const excluded = 'script, style, textarea, input, [contenteditable], [hidden], [aria-hidden="true"], .mark_table, .ans-cc, .workTextWrap, .question';
  const lines = [];
  const visible = element => {
    if (element.closest(excluded) || element.querySelector(excluded)) return false;
    for (let parent = element; parent; parent = parent.parentElement) {
      const style = parent.style;
      if (style.display === 'none' || style.visibility === 'hidden') return false;
      if (root === document) {
        const computed = getComputedStyle(parent);
        if (computed.display === 'none' || computed.visibility === 'hidden') return false;
      }
    }
    return true;
  };
  for (const element of root.querySelectorAll('.infoHead p, .infoHead span, p, li, label, dd, dt, td, th, span, div')) {
    if (lines.length >= 10) break;
    if (!visible(element)) continue;
    const text = clean(element.innerText ?? element.textContent);
    if (!text || text.length > 180) continue;
    const rangeTimes = element.matches('.infoHead p') ? element.querySelectorAll('em') : [];
    const range = /(?:作答时间|起止时间|answering time|answer time)\s*[:：]?\s*(.+?)\s*(?:至|~|～|—|\bto\b)\s*(.+)/i.exec(text);
    const labelled = /(?:截止时间|截止日期|截止|deadline|due(?:\s+date)?|end\s*(?:time|date))\s*[:：]?\s*((?:20\d{2}[-/.年])?\d{1,2}[-/.月]\d{1,2}日?(?:\s*\d{1,2}:\d{2}(?::\d{2})?)?)/i.exec(text);
    let deadline = clean(rangeTimes.length === 2 ? rangeTimes[1].textContent : range?.[2] ?? labelled?.[1]);
    if (!deadline) continue;
    const partial = /^(\d{1,2})[-/.月](\d{1,2})日?\s+(\d{1,2}):(\d{2})(?::(\d{2}))?$/.exec(deadline);
    if (partial) {
      const [, month, day, hour, minute, second] = partial;
      const serverTime = [...root.querySelectorAll('script')].map(script => script.textContent ?? '').join('\n')
        .match(/window\s*\[\s*["']currentTime["']\s*\]\s*=\s*["'](\d{13})["']/);
      const remaining = /^(?:剩余\s*(\d+)\s*小时\s*(\d+)\s*分钟|(\d+)\s*hours?\s*(\d+)\s*minutes?\s+left)$/i.exec(clean(context.timing));
      let year;
      if (serverTime && remaining) {
        const duration = (Number(remaining[1] ?? remaining[3]) * 60 + Number(remaining[2] ?? remaining[4])) * 60000;
        const expected = Number(serverTime[1]) + duration;
        const candidateYear = new Intl.DateTimeFormat('sv-SE', { timeZone: 'Asia/Shanghai' }).format(new Date(expected)).slice(0, 4);
        const candidate = new Date(candidateYear + '-' + month.padStart(2, '0') + '-' + day.padStart(2, '0') + 'T' + hour.padStart(2, '0') + ':' + minute + ':' + (second ?? '00') + '+08:00');
        if (Math.abs(candidate.getTime() - expected) <= 120000 + (context.elapsedMs ?? 0)) year = candidateYear;
      }
      const valid = new Date('2000-' + month.padStart(2, '0') + '-' + day.padStart(2, '0') + 'T' + hour.padStart(2, '0') + ':' + minute + ':' + (second ?? '00') + 'Z');
      if (!Number.isFinite(valid.getTime()) || valid.toISOString().slice(5, 10) !== month.padStart(2, '0') + '-' + day.padStart(2, '0')) continue;
      deadline = (year ? year + '-' : '') + month.padStart(2, '0') + '-' + day.padStart(2, '0') + ' ' + hour.padStart(2, '0') + ':' + minute + (second ? ':' + second : '') + (year ? '' : '（年份待确认）');
    } else if (!/^20\d{2}[-/.年]/.test(deadline)) continue;
    const line = '截止时间：' + deadline;
    if (!lines.includes(line)) lines.push(line);
  }
  return lines.join('\n');
}`;

export const chaoxingWorksScript = String.raw`(async () => {
  const container=document.querySelector('.bottomList');
  if(!container) return {ready:false};
  const rows=[...container.querySelectorAll('li[data][role="link"]')];
  if(!rows.length && !/暂无作业|没有作业|未发布作业/.test(document.body.innerText)) throw new Error('Unknown empty work list');
  const readTiming = ${workTimingReader};
  const listReadAt = Date.now();
  const items = await Promise.all(rows.map(async row => {
    const url = new URL(row.getAttribute('data'), location.href);
    const time = row.querySelector('.time');
    const item = {
      id:url.searchParams.get('workId'),
      title:row.querySelector('.right-content .overHidden2')?.textContent.trim(),
      status:row.querySelector('.status')?.textContent.trim()||'',
      timing:time?.textContent.trim()||'',
      url:url.href,
      detailTiming:time?.getAttribute('title')?.trim()||undefined,
    };
    if (item.detailTiming && /^20\d{2}[-/.年]/.test(item.detailTiming)) item.detailTiming = '截止时间：' + item.detailTiming;
    if (/(?:截止时间|截止日期|截止|deadline|due(?:\s+date)?|end\s*(?:time|date))\s*[:：]?\s*20\d{2}[-/.年]/i.test(item.detailTiming || item.timing)) return item;
    try {
      if (url.protocol !== 'https:' || !url.hostname.endsWith('.chaoxing.com')) throw new Error('Unsupported work route');
      const response = await fetch(url.href, {credentials:'include', signal:AbortSignal.timeout(8000)});
      if (!response.ok || new URL(response.url).hostname === 'passport2.chaoxing.com') throw new Error('Work detail unavailable');
      const root = new DOMParser().parseFromString(await response.text(), 'text/html');
      item.detailTiming = readTiming(root, {timing:item.timing, elapsedMs:Date.now()-listReadAt}) || undefined;
      if (!item.detailTiming) item.detailError = '详情页未提供可识别的截止时间';
    } catch {
      item.detailTiming = undefined;
      item.detailError = '作业详情暂时无法读取，请稍后刷新';
    }
    return item;
  }));
  return {ready:true,data:items};
})()`;

export const chaoxingDetailTimingScript = `(${workTimingReader})(document)`;
