// 校园社区的 AI 模拟内容。真实服务接入后由服务端下发，本文件仅用于骨架演示与联调。
import type { CommunityPost, CommunitySnapshot } from '../../shared/community';
import { reviewCommunityPost, statusForReview } from '../../shared/community';

const DAY = 86_400_000;

type Seed = Omit<
  CommunityPost,
  | 'status'
  | 'review'
  | 'tags'
  | 'likes'
  | 'liked'
  | 'replies'
  | 'reports'
  | 'updatedAt'
  | 'createdAt'
> & {
  tags?: string[];
  likes?: number;
  sinceHours: number;
  replies?: { author: string; body: string; hoursAgo: number }[];
};

const seeds: Seed[] = [
  {
    id: 'demo-talk-1',
    board: 'talk',
    title: '期末周图书馆座位怎么找？整理了几条经验',
    body: '早上 8 点前到四楼基本还有位置，中午 12 点到 13 点会有一波空位；带插座的座位集中在靠窗一侧。\n\n另外建议先在预约系统里锁座，现场再找容易白跑。',
    author: '示例同学 · 计算机 22 级',
    tags: ['图书馆', '期末'],
    likes: 24,
    sinceHours: 5,
    replies: [
      {
        author: '示例同学 · 软件 21 级',
        body: '补充：五楼安静区不能用键盘声太大的设备。',
        hoursAgo: 3,
      },
      { author: '示例同学 · 机械 23 级', body: '预约系统早上 7 点开放，记得定闹钟。', hoursAgo: 1 },
    ],
  },
  {
    id: 'demo-talk-2',
    board: 'talk',
    title: '转专业材料准备清单（计算机方向）',
    body: '成绩单、排名证明、个人陈述和两封推荐信是常见材料。个人陈述建议写清楚为什么转、做过什么、之后想做什么，别只写兴趣。',
    author: '示例同学 · 计算机 21 级',
    tags: ['转专业'],
    likes: 41,
    sinceHours: 26,
  },
  {
    id: 'demo-market-1',
    board: 'market',
    title: '出 24 寸显示器，九成新，宿舍自提',
    body: '用了半年，无坏点，带 HDMI 线和电源。毕业清仓，价格可小刀。',
    author: '示例同学 · 电子 21 级',
    tags: ['显示器', '闲置'],
    likes: 6,
    sinceHours: 9,
    price: 350,
    condition: '九成新',
    dealStatus: '在售',
    contact: '站内留言（示例）',
  },
  {
    id: 'demo-market-2',
    board: 'market',
    title: '求购二手自行车，能骑就行',
    body: '预算 200 以内，最好南岭校区附近，周末可以自提。',
    author: '示例同学 · 机械 23 级',
    tags: ['自行车'],
    likes: 2,
    sinceHours: 30,
    price: 200,
    condition: '正常使用',
    contact: '站内留言（示例）',
  },
  {
    id: 'demo-research-1',
    board: 'research',
    title: '模式识别实验室招本科科研助理（大二以上）',
    body: '方向是视觉检索与多模态学习，每周投入 8 小时左右，先做数据与复现，后续可参与论文。要求会 Python，有 PyTorch 经验优先。\n\n有意向请附成绩单与一段自我介绍。',
    author: '示例同学 · 计算机 20 级',
    tags: ['科研招募', '计算机视觉'],
    likes: 18,
    sinceHours: 12,
    lab: '模式识别实验室',
    sourceUrl: 'https://cs.jlu.edu.cn/',
  },
  {
    id: 'demo-research-2',
    board: 'research',
    title: '关于某课题组招募的转述（缺来源）',
    body: '听说有课题组在招人，方向是遥感，具体要求和联系方式暂不清楚。',
    author: '示例同学 · 地球探测 22 级',
    tags: ['科研招募'],
    likes: 1,
    sinceHours: 20,
  },
  {
    id: 'demo-contest-1',
    board: 'contest',
    title: '蓝桥杯省赛组队，缺一名算法方向',
    body: '已有两人，一人负责实现、一人负责工程，想找一位刷题量在 300 题以上的同学。可以一起做往年真题。',
    author: '示例同学 · 软件 22 级',
    tags: ['蓝桥杯', '组队'],
    likes: 9,
    sinceHours: 15,
    competition: '蓝桥杯',
    deadline: '2026-12-20',
  },
  {
    id: 'demo-contest-2',
    board: 'contest',
    title: '数学建模国赛经验：三天怎么分工',
    body: '前一天定题后立刻分工：建模、编程、写作各一人，每 6 小时合稿一次。摘要在最后半天单独打磨，比多加一个模型更值。',
    author: '示例同学 · 数学 21 级',
    tags: ['数学建模', '经验'],
    likes: 33,
    sinceHours: 48,
    competition: '全国大学生数学建模竞赛',
  },
  {
    id: 'demo-food-1',
    board: 'food',
    title: '南门小吃街这家麻辣烫值得排队',
    body: '荤素同价，汤底可以选番茄。晚高峰要等 20 分钟左右，建议错峰。',
    author: '示例同学 · 化学 23 级',
    tags: ['南门', '麻辣烫'],
    likes: 27,
    sinceHours: 8,
    shop: '南门小吃街 · 示例麻辣烫',
    rating: 4.5,
    pricePerPerson: 18,
  },
  {
    id: 'demo-food-2',
    board: 'food',
    title: '食堂二楼新窗口测评：分量足但偏咸',
    body: '一荤两素 12 元，米饭可以续。口味偏咸，建议让师傅少放酱。',
    author: '示例同学 · 物理 22 级',
    tags: ['食堂'],
    likes: 11,
    sinceHours: 40,
    shop: '中心校区 · 示例食堂二楼',
    rating: 3.5,
    pricePerPerson: 12,
  },
];

export const communityViewer = '我（本机）';

/** 生成示例帖子：审核结论也走真实规则，便于演示「待复核 / 来源待核实 / 未通过」。 */
export function demoCommunitySnapshot(now = Date.now()): CommunitySnapshot {
  const posts: CommunityPost[] = seeds.map((seed) => {
    const createdAt = new Date(now - seed.sinceHours * 3_600_000).toISOString();
    const input = {
      board: seed.board,
      title: seed.title,
      body: seed.body,
      author: seed.author,
      tags: seed.tags ?? [],
      ...(seed.price === undefined ? {} : { price: seed.price }),
      ...(seed.condition ? { condition: seed.condition } : {}),
      ...(seed.contact ? { contact: seed.contact } : {}),
      ...(seed.lab ? { lab: seed.lab } : {}),
      ...(seed.sourceUrl ? { sourceUrl: seed.sourceUrl } : {}),
      ...(seed.competition ? { competition: seed.competition } : {}),
      ...(seed.deadline ? { deadline: seed.deadline } : {}),
      ...(seed.shop ? { shop: seed.shop } : {}),
      ...(seed.rating === undefined ? {} : { rating: seed.rating }),
    };
    const review = reviewCommunityPost(input, createdAt);
    return {
      ...input,
      id: seed.id,
      author: seed.author,
      createdAt,
      updatedAt: createdAt,
      status: statusForReview(seed.board, review),
      review,
      tags: seed.tags ?? [],
      likes: seed.likes ?? 0,
      liked: false,
      replies: (seed.replies ?? []).map((reply, index) => ({
        id: `${seed.id}-r${index + 1}`,
        author: reply.author,
        body: reply.body,
        createdAt: new Date(now - reply.hoursAgo * 3_600_000).toISOString(),
      })),
      reports: 0,
      ...(seed.dealStatus ? { dealStatus: seed.dealStatus } : {}),
    } satisfies CommunityPost;
  });
  return {
    version: 1,
    generatedAt: new Date(now).toISOString(),
    posts,
    viewer: communityViewer,
  };
}

/** 示例内容的时间跨度：用于「重新生成」时保持帖子看起来是最近发布的。 */
export const demoCommunityWindowMs = 7 * DAY;
