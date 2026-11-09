export const courseCategories = ['必修', '选修', '限选', '专业选修'] as const;
export const courseGrades = ['大一', '大二', '大三', '大四'] as const;
export const materialTypes = ['课件', '笔记', '复习资料', '历年试题'] as const;

export type PublicCourseExample = {
  id: string;
  name: string;
  classification: readonly [
    string,
    string,
    (typeof courseGrades)[number],
    (typeof courseCategories)[number],
  ];
  description: string;
};

export type MaterialExample = {
  id: string;
  title: string;
  type: (typeof materialTypes)[number];
  contributor: string;
  uploadedAt: string;
  filename: string;
  description: string;
  preview: string;
  likes: number;
  downloads: number;
};

export const courseExamples: PublicCourseExample[] = [
  {
    id: 'data-structures',
    name: '数据结构',
    classification: ['计算机学院', '计算机科学与技术', '大二', '必修'],
    description: '从线性表、树到图，整理常见数据结构与算法的学习资料。',
  },
  {
    id: 'computer-networks',
    name: '计算机网络',
    classification: ['计算机学院', '计算机科学与技术', '大二', '必修'],
    description: '围绕网络分层、可靠传输与路由，交流课堂笔记和复习思路。',
  },
  {
    id: 'information-retrieval',
    name: '信息检索导论',
    classification: ['计算机学院', '计算机科学与技术', '大三', '专业选修'],
    description: '一起梳理检索模型、索引与检索效果评价的基础概念。',
  },
  {
    id: 'software-design',
    name: '软件设计基础',
    classification: ['计算机学院', '软件工程', '大二', '限选'],
    description: '分享软件设计方法、课堂练习与学习笔记。',
  },
  {
    id: 'linear-algebra',
    name: '线性代数',
    classification: ['数学学院', '数学与应用数学', '大一', '必修'],
    description: '整理矩阵、向量空间与线性变换的知识脉络。',
  },
  {
    id: 'mathematical-culture',
    name: '数学文化',
    classification: ['数学学院', '数学与应用数学', '大四', '选修'],
    description: '从数学史与经典问题出发，分享阅读和学习记录。',
  },
];

export const dataStructureMaterials: MaterialExample[] = [
  {
    id: 'linear-list',
    likes: 12,
    downloads: 128,
    title: '线性表与链表 · 课堂整理',
    type: '笔记',
    contributor: '小林',
    uploadedAt: '2026-10-18',
    filename: '线性表与链表.md',
    description: '整理顺序表和链表的存储特点，附插入、删除操作的复习提纲。',
    preview:
      '顺序表通过连续存储支持按下标访问；链表通过节点之间的链接组织数据。复习时可以从访问、插入和删除三个操作比较两者，再尝试画出指针变化。',
  },
  {
    id: 'tree-slides',
    likes: 8,
    downloads: 96,
    title: '树与二叉树 · 学习提纲',
    type: '课件',
    contributor: '阿禾',
    uploadedAt: '2026-10-16',
    filename: '树与二叉树.pdf',
    description: '按树的概念、二叉树遍历与应用整理的演示资料。',
    preview:
      '学习提纲：树的基本术语 → 二叉树的存储 → 前序、中序和后序遍历 → 遍历的应用。可先用同一棵树分别写出三种遍历结果。',
  },
  {
    id: 'revision',
    likes: 16,
    downloads: 245,
    title: '期末复习 · 知识清单',
    type: '复习资料',
    contributor: '小周',
    uploadedAt: '2026-10-12',
    filename: '复习知识清单.pdf',
    description: '按章节整理的自查清单，供交流复习方法。',
    preview:
      '自查清单：能否描述各种结构的存储方式？能否手写基本操作？能否分析时间复杂度？建议为每个知识点准备一个小例子。',
  },
  {
    id: 'past-paper',
    likes: 3,
    downloads: 172,
    title: '历年试题 · 资料位置示例',
    type: '历年试题',
    contributor: '小林',
    uploadedAt: '2026-10-08',
    filename: '试题示例.pdf',
    description: '用于演示试题类资料的位置，不包含学校真实试题。',
    preview: '这里将展示同学分享且允许传播的试题资料。当前没有真实试题或附件。',
  },
];
