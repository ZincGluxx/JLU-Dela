// 校园社区：板块、内容模型、基础审核规则与筛选的单一真源。
// 本版为骨架：内容由 AI 模拟填充并只保存在本机；接入真实服务（账号、审核、举报处置）由后续实现。

export const communityBoards = ['talk', 'market', 'research', 'contest', 'food'] as const;
export type CommunityBoard = (typeof communityBoards)[number];

export const communityBoardLabels: Record<CommunityBoard, string> = {
  talk: '普通交流',
  market: '二手信息',
  research: '科研信息',
  contest: '竞赛交流',
  food: '美食评分',
};

export const communityBoardDescriptions: Record<CommunityBoard, string> = {
  talk: '校园话题、经验分享与问题讨论',
  market: '闲置物品与转让需求',
  research: '课题组招募、科研动态（来源需核实）',
  contest: '比赛信息、往届经验与组队',
  food: '校园周边美食与店铺评价',
};

/**
 * published      正常展示
 * pending        基础审核判定需要人工复核
 * rejected       基础审核拦截，仅作者可见
 * unverified     科研信息缺少可追溯来源，展示时标注「来源待核实」
 */
export type CommunityPostStatus = 'published' | 'pending' | 'rejected' | 'unverified';

export const communityStatusLabels: Record<CommunityPostStatus, string> = {
  published: '已发布',
  pending: '待复核',
  rejected: '未通过审核',
  unverified: '来源待核实',
};

export type CommunityCondition = '全新' | '九成新' | '正常使用' | '有瑕疵';
export type CommunityDealStatus = '在售' | '已出';

export interface CommunityReply {
  id: string;
  author: string;
  body: string;
  createdAt: string;
}

export interface CommunityPostInput {
  board: CommunityBoard;
  title: string;
  body: string;
  author?: string;
  tags?: string[];
  contact?: string;
  /** 二手 */
  price?: number | null;
  condition?: CommunityCondition;
  /** 科研 */
  sourceUrl?: string;
  lab?: string;
  /** 竞赛 */
  competition?: string;
  deadline?: string | null;
  /** 美食 */
  shop?: string;
  rating?: number | null;
  pricePerPerson?: number | null;
}

export interface CommunityPost extends CommunityPostInput {
  id: string;
  author: string;
  createdAt: string;
  updatedAt: string;
  status: CommunityPostStatus;
  review: CommunityReview;
  tags: string[];
  likes: number;
  liked: boolean;
  replies: CommunityReply[];
  dealStatus?: CommunityDealStatus;
  /** 举报次数（本机演示：只累计不外发）。 */
  reports: number;
}

/** 基础审核结论；level=block 时不予发布。 */
export interface CommunityReview {
  level: 'ok' | 'warn' | 'block';
  reasons: string[];
  needsVerification: boolean;
  reviewedAt: string;
}

/** 明显违规的词，命中即拦截；真实服务应替换为可配置词库与模型审核。 */
const blockedKeywords = ['代写', '代考', '刷单', '贷款', '博彩', '办证', '出售答案'];

const contactLike = /(?:微信|vx|v信|qq|电话|手机号)\s*[:：]?\s*[a-z0-9_+-]{5,}/i;

/**
 * 基础审核占位实现：规则固定、可单测，便于后续替换成模型或服务端审核。
 * 科研信息更严格：必须有可追溯的 https 来源，缺失时仅展示为「来源待核实」。
 */
export function reviewCommunityPost(
  input: CommunityPostInput,
  now = new Date().toISOString(),
): CommunityReview {
  const reasons: string[] = [];
  let level: CommunityReview['level'] = 'ok';
  const text = `${input.title} ${input.body}`;
  const blocked = blockedKeywords.find((word) => text.includes(word));
  if (blocked)
    return {
      level: 'block',
      reasons: [`包含禁止发布的内容：${blocked}`],
      needsVerification: false,
      reviewedAt: now,
    };
  if (input.title.trim().length < 4) {
    level = 'warn';
    reasons.push('标题过短，补充科目或地点更容易被找到');
  }
  if (input.body.trim().length < 10) {
    level = 'warn';
    reasons.push('正文过短，建议补充具体信息');
  }
  if (blockedKeywords.some((word) => (input.tags ?? []).join(' ').includes(word)))
    return {
      level: 'block',
      reasons: ['标签包含禁止发布的内容'],
      needsVerification: false,
      reviewedAt: now,
    };

  if (input.board === 'market') {
    if (typeof input.price !== 'number' || input.price < 0) {
      level = 'warn';
      reasons.push('二手信息需要写明价格（可写 0 表示赠送）');
    }
    if (!input.contact?.trim() && !contactLike.test(text)) {
      level = 'warn';
      reasons.push('建议留下联系方式，方便对方联系');
    }
  }
  if (input.board === 'research') {
    const source = input.sourceUrl?.trim() ?? '';
    const traceable = /^https?:\/\//i.test(source);
    if (!traceable)
      return {
        level: 'warn',
        reasons: ['科研信息必须提供可追溯的来源链接，当前缺失'],
        needsVerification: true,
        reviewedAt: now,
      };
    reasons.push('来源链接已附上，仍需人工核实真实性');
    return { level: 'warn', reasons, needsVerification: true, reviewedAt: now };
  }
  if (input.board === 'contest' && !input.competition?.trim()) {
    level = 'warn';
    reasons.push('建议补上比赛名称，方便同学检索');
  }
  if (input.board === 'food') {
    if (typeof input.rating !== 'number' || input.rating < 1 || input.rating > 5) {
      level = 'warn';
      reasons.push('评分需在 1 到 5 之间');
    }
    if (!input.shop?.trim()) {
      level = 'warn';
      reasons.push('建议填写店铺名称');
    }
  }
  return { level, reasons, needsVerification: false, reviewedAt: now };
}

/** 审核结论 → 发布状态：拦截不进列表，科研一律先标来源待核实。 */
export function statusForReview(
  board: CommunityBoard,
  review: CommunityReview,
): CommunityPostStatus {
  if (review.level === 'block') return 'rejected';
  if (review.needsVerification) return 'unverified';
  if (review.level === 'warn') return 'pending';
  return 'published';
}

export type CommunitySort = 'latest' | 'hot';

export interface CommunityFilter {
  board?: CommunityBoard | '';
  text?: string;
  /** 只看自己的帖子（演示：作者名匹配）。 */
  mine?: string;
}

export function communityPostMatches(post: CommunityPost, filter: CommunityFilter): boolean {
  if (filter.board && post.board !== filter.board) return false;
  if (filter.mine && post.author !== filter.mine) return false;
  const needle = filter.text?.trim().toLocaleLowerCase();
  if (!needle) return true;
  return `${post.title} ${post.body} ${post.tags.join(' ')} ${post.author}`
    .toLocaleLowerCase()
    .includes(needle);
}

/** 热度 = 点赞 + 回复 × 2；同分按时间倒序。 */
export function communityHeat(post: CommunityPost): number {
  return post.likes + post.replies.length * 2;
}

export function sortCommunityPosts(
  posts: readonly CommunityPost[],
  sort: CommunitySort,
): CommunityPost[] {
  return [...posts].sort((left, right) =>
    sort === 'hot'
      ? communityHeat(right) - communityHeat(left) || right.createdAt.localeCompare(left.createdAt)
      : right.createdAt.localeCompare(left.createdAt),
  );
}

/** 板块计数只统计可展示内容（审核未通过的不计入）。 */
export function communityBoardCounts(
  posts: readonly CommunityPost[],
): Record<CommunityBoard, number> {
  const counts = { talk: 0, market: 0, research: 0, contest: 0, food: 0 } as Record<
    CommunityBoard,
    number
  >;
  for (const post of posts) if (post.status !== 'rejected') counts[post.board] += 1;
  return counts;
}

/** 帖子的关键信息行：按板块给出价格、比赛、评分等摘要。 */
export function communityPostSummary(post: CommunityPost): string {
  const parts: string[] = [];
  if (post.board === 'market') {
    if (typeof post.price === 'number') parts.push(`¥${post.price}`);
    if (post.condition) parts.push(post.condition);
    if (post.dealStatus) parts.push(post.dealStatus);
  }
  if (post.board === 'research' && post.lab) parts.push(post.lab);
  if (post.board === 'contest') {
    if (post.competition) parts.push(post.competition);
    if (post.deadline) parts.push(`截止 ${post.deadline}`);
  }
  if (post.board === 'food') {
    if (post.shop) parts.push(post.shop);
    if (typeof post.rating === 'number') parts.push(`${post.rating} 分`);
    if (typeof post.pricePerPerson === 'number') parts.push(`人均 ¥${post.pricePerPerson}`);
  }
  return parts.join(' · ');
}

export interface CommunitySnapshot {
  version: number;
  generatedAt: string;
  posts: CommunityPost[];
  /** 本机演示身份：发帖与「只看我的」按它匹配。 */
  viewer: string;
}

export type CommunityModerationDecision = 'publish' | 'reject';

export interface CommunityApi {
  get(): Promise<CommunitySnapshot>;
  create(input: CommunityPostInput): Promise<CommunitySnapshot>;
  like(id: string): Promise<CommunitySnapshot>;
  reply(id: string, body: string): Promise<CommunitySnapshot>;
  /** 人工复核：通过或驳回待复核内容。 */
  moderate(id: string, decision: CommunityModerationDecision): Promise<CommunitySnapshot>;
  setDealStatus(id: string, status: CommunityDealStatus): Promise<CommunitySnapshot>;
  report(id: string): Promise<CommunitySnapshot>;
  remove(id: string): Promise<CommunitySnapshot>;
  /** 重新生成示例内容：保留自己发布的帖子。 */
  regenerateDemo(): Promise<CommunitySnapshot>;
}
