// 校园社区的审核规则与列表规则：关键词拦截、科研来源核实、排序与计数。
import { describe, expect, it } from 'vitest';
import {
  communityBoardCounts,
  communityHeat,
  communityPostMatches,
  communityPostSummary,
  reviewCommunityPost,
  sortCommunityPosts,
  statusForReview,
  type CommunityPost,
  type CommunityPostInput,
} from './community';

const now = '2025-03-01T10:00:00.000Z';

function input(overrides: Partial<CommunityPostInput> = {}): CommunityPostInput {
  return {
    board: 'talk',
    title: '期末周图书馆座位怎么找',
    body: '早上八点前到四楼基本还有位置，中午会空出一波。',
    tags: ['图书馆'],
    ...overrides,
  };
}

let seq = 0;

function post(overrides: Partial<CommunityPost> = {}): CommunityPost {
  seq += 1;
  const base = input(overrides.board ? { board: overrides.board } : {});
  const review = reviewCommunityPost(base, now);
  return {
    ...base,
    id: `p${seq}`,
    author: '示例同学',
    createdAt: now,
    updatedAt: now,
    status: statusForReview(base.board, review),
    review,
    tags: base.tags ?? [],
    likes: 0,
    liked: false,
    replies: [],
    reports: 0,
    ...overrides,
  };
}

describe('基础审核', () => {
  it('正常帖子可以直接发布', () => {
    const review = reviewCommunityPost(input(), now);
    expect(review).toMatchObject({ level: 'ok', needsVerification: false });
    expect(statusForReview('talk', review)).toBe('published');
  });

  it('命中禁止词直接拦截，标题和标签都查', () => {
    const inBody = reviewCommunityPost(input({ body: '需要代写课程论文，价格好说。' }), now);
    expect(inBody.level).toBe('block');
    expect(inBody.reasons[0]).toContain('代写');
    expect(statusForReview('talk', inBody)).toBe('rejected');

    const inTags = reviewCommunityPost(input({ tags: ['刷单'] }), now);
    expect(inTags).toMatchObject({ level: 'block' });
  });

  it('标题或正文过短只提示，进入人工复核而不是直接拦下', () => {
    const review = reviewCommunityPost(input({ title: '求问', body: '怎么弄' }), now);
    expect(review.level).toBe('warn');
    expect(review.reasons).toHaveLength(2);
    expect(statusForReview('talk', review)).toBe('pending');
  });

  it('科研信息没有来源时标为待核实，不允许直接发布', () => {
    const review = reviewCommunityPost(input({ board: 'research', tags: [] }), now);
    expect(review.needsVerification).toBe(true);
    expect(review.reasons.join()).toContain('来源链接');
    expect(statusForReview('research', review)).toBe('unverified');
  });

  it('科研信息附上 https 来源也只是待核实，仍需人工核实', () => {
    const review = reviewCommunityPost(
      input({ board: 'research', sourceUrl: 'https://cs.jlu.edu.cn/', lab: '模式识别实验室' }),
      now,
    );
    expect(review.level).toBe('warn');
    expect(review.needsVerification).toBe(true);
    expect(review.reasons.join()).toContain('人工核实');
    expect(statusForReview('research', review)).toBe('unverified');
  });

  it('二手信息缺价格时要求补齐（0 元赠送算填了）', () => {
    expect(
      reviewCommunityPost(input({ board: 'market', contact: '站内留言' }), now).reasons,
    ).toContain('二手信息需要写明价格（可写 0 表示赠送）');
    const free = reviewCommunityPost(
      input({ board: 'market', price: 0, condition: '正常使用', contact: '站内留言' }),
      now,
    );
    expect(free.level).toBe('ok');
  });

  it('二手信息没留联系方式时给出提示', () => {
    const review = reviewCommunityPost(input({ board: 'market', price: 100 }), now);
    expect(review.reasons.join()).toContain('联系方式');
  });

  it('美食评分超出 1–5 会被要求修正，店铺也要写清', () => {
    const review = reviewCommunityPost(input({ board: 'food', rating: 9 }), now);
    expect(review.reasons.join()).toContain('评分需在 1 到 5 之间');
    expect(review.reasons.join()).toContain('店铺名称');
    expect(
      reviewCommunityPost(input({ board: 'food', rating: 4.5, shop: '南门麻辣烫' }), now).level,
    ).toBe('ok');
  });

  it('竞赛信息建议补比赛名称', () => {
    expect(reviewCommunityPost(input({ board: 'contest' }), now).reasons.join()).toContain(
      '比赛名称',
    );
  });
});

describe('列表规则', () => {
  it('按板块、关键词和作者过滤', () => {
    const talk = post({ title: '图书馆占座经验', tags: ['占座'] });
    const market = post({ board: 'market', title: '出显示器', tags: ['闲置'], price: 350 });
    expect(communityPostMatches(talk, { board: 'talk' })).toBe(true);
    expect(communityPostMatches(market, { board: 'talk' })).toBe(false);
    expect(communityPostMatches(market, { text: '闲置' })).toBe(true);
    expect(communityPostMatches(market, { text: '图书馆' })).toBe(false);
    expect(communityPostMatches(talk, { mine: '别人' })).toBe(false);
    expect(communityPostMatches(talk, { mine: '示例同学' })).toBe(true);
  });

  it('热度把回复算得比点赞重', () => {
    const replies = [0, 1, 2].map((index) => ({
      id: `r${index}`,
      author: '同学',
      body: '内容',
      createdAt: now,
    }));
    expect(communityHeat(post({ likes: 5, replies }))).toBe(11);
  });

  it('最新按时间倒序，热门按热度倒序', () => {
    const olderHot = post({ createdAt: '2025-02-20T10:00:00.000Z', likes: 50 });
    const newerCold = post({ createdAt: '2025-02-28T10:00:00.000Z' });
    expect(sortCommunityPosts([olderHot, newerCold], 'latest').map((row) => row.id)).toEqual([
      newerCold.id,
      olderHot.id,
    ]);
    expect(sortCommunityPosts([newerCold, olderHot], 'hot').map((row) => row.id)).toEqual([
      olderHot.id,
      newerCold.id,
    ]);
  });

  it('板块计数不把审核未通过的算进去', () => {
    const counts = communityBoardCounts([
      post({ board: 'talk' }),
      post({ board: 'talk', status: 'rejected' }),
      post({ board: 'market', price: 10 }),
    ]);
    expect(counts).toMatchObject({ talk: 1, market: 1, research: 0, contest: 0, food: 0 });
  });

  it('摘要只展示当前板块关心的字段', () => {
    expect(
      communityPostSummary(
        post({ board: 'market', price: 350, condition: '九成新', dealStatus: '在售' }),
      ),
    ).toBe('¥350 · 九成新 · 在售');
    expect(
      communityPostSummary(
        post({ board: 'food', shop: '南门麻辣烫', rating: 4.5, pricePerPerson: 18 }),
      ),
    ).toBe('南门麻辣烫 · 4.5 分 · 人均 ¥18');
    expect(
      communityPostSummary(
        post({ board: 'contest', competition: '蓝桥杯', deadline: '2026-12-20' }),
      ),
    ).toBe('蓝桥杯 · 截止 2026-12-20');
    expect(communityPostSummary(post({ board: 'research', lab: '模式识别实验室' }))).toBe(
      '模式识别实验室',
    );
    expect(communityPostSummary(post())).toBe('');
  });
});
