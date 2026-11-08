import { useEffect, useMemo, useState } from 'react';
import { Dialog } from 'radix-ui';
import {
  Flag,
  Heart,
  MessageSquare,
  Plus,
  RefreshCw,
  Search,
  ShieldCheck,
  Trash2,
} from 'lucide-react';
import {
  communityBoardCounts,
  communityBoardDescriptions,
  communityBoardLabels,
  communityBoards,
  communityPostMatches,
  communityPostSummary,
  communityStatusLabels,
  reviewCommunityPost,
  sortCommunityPosts,
  type CommunityBoard,
  type CommunityCondition,
  type CommunityPost,
  type CommunityPostInput,
  type CommunitySnapshot,
  type CommunitySort,
} from '../../../shared/community';
import { Button } from '../../components/ui/button';
import { Input } from '../../components/ui/input';
import { Textarea } from '../../components/ui/textarea';
import { SegmentedControl } from '../../components/ui/beautifului/atoms/SegmentedControl';
import { dialogOverlay, dialogPanel } from '../../components/ui/motion';
import { cn } from '../../lib/utils';
import { errorText } from '../../workspace/store';

const sorts: readonly { id: CommunitySort; label: string }[] = [
  { id: 'latest', label: '最新' },
  { id: 'hot', label: '热门' },
];

export function CommunityView({
  api = window.dela?.community,
}: {
  api?: NonNullable<typeof window.dela>['community'];
}) {
  const [snapshot, setSnapshot] = useState<CommunitySnapshot | null>(null);
  const [board, setBoard] = useState<CommunityBoard | ''>('talk');
  const [text, setText] = useState('');
  const [sort, setSort] = useState<CommunitySort>('latest');
  const [mineOnly, setMineOnly] = useState(false);
  const [pendingOnly, setPendingOnly] = useState(false);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [composerOpen, setComposerOpen] = useState(false);
  const [reply, setReply] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  useEffect(() => {
    if (!api) return;
    let active = true;
    void api
      .get()
      .then((value) => {
        if (active) setSnapshot(value);
      })
      .catch((cause) => {
        if (active) setError(errorText(cause));
      });
    return () => {
      active = false;
    };
  }, [api]);

  const viewer = snapshot?.viewer ?? '';
  const counts = useMemo(
    () => (snapshot ? communityBoardCounts(snapshot.posts) : null),
    [snapshot],
  );
  const pendingCount =
    snapshot?.posts.filter((row) => row.status === 'pending' || row.status === 'unverified')
      .length ?? 0;
  const visible = useMemo(() => {
    if (!snapshot) return [];
    const filtered = snapshot.posts.filter(
      (post) =>
        communityPostMatches(post, { board, text, mine: mineOnly ? viewer : undefined }) &&
        (pendingOnly
          ? post.status === 'pending' || post.status === 'unverified'
          : post.status !== 'rejected' || post.author === viewer),
    );
    return sortCommunityPosts(filtered, sort);
  }, [snapshot, board, text, mineOnly, viewer, pendingOnly, sort]);
  const selected = visible.find((row) => row.id === selectedId) ?? visible[0] ?? null;

  async function apply(next: Promise<CommunitySnapshot>, message: string) {
    setBusy(true);
    setError(null);
    setNotice(null);
    try {
      setSnapshot(await next);
      setNotice(message);
    } catch (cause) {
      setError(errorText(cause));
    } finally {
      setBusy(false);
    }
  }

  if (!api)
    return (
      <div className="min-h-0 flex-1 overflow-y-auto bg-surface p-10">
        <p className="text-13 text-ink-3">校园社区只在桌面应用中可用。</p>
      </div>
    );

  return (
    <div className="min-h-0 flex-1 overflow-y-auto bg-surface">
      <div className="mx-auto grid w-full max-w-6xl gap-5 px-6 py-8 md:px-10">
        <header className="flex flex-wrap items-start justify-between gap-3">
          <div className="min-w-0">
            <h1 className="text-xl font-semibold text-ink">校园社区</h1>
            <p className="mt-1 text-xs leading-relaxed text-ink-3">
              交流、二手、科研、竞赛与美食，一个入口看完。当前为骨架版本：内容由 AI
              模拟，发布、点赞、回复与审核都只保存在本机。
            </p>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <Button
              size="sm"
              variant="ghost"
              disabled={busy}
              onClick={() =>
                void apply(api.regenerateDemo(), '已重新生成示例内容，自己发布的帖子已保留。')
              }
            >
              <RefreshCw className={busy ? 'size-4 animate-spin' : 'size-4'} />
              重新生成示例
            </Button>
            <Button size="sm" onClick={() => setComposerOpen(true)}>
              <Plus className="size-4" />
              发布
            </Button>
          </div>
        </header>

        {error && (
          <p role="alert" className="rounded-control bg-field p-3 text-13 text-ink">
            {error}
          </p>
        )}
        {notice && (
          <p role="status" className="rounded-control bg-field p-3 text-13 text-ink-2">
            {notice}
          </p>
        )}

        <nav aria-label="社区板块" className="flex flex-wrap gap-2">
          <BoardButton
            active={board === ''}
            label="全部"
            count={counts ? Object.values(counts).reduce((sum, value) => sum + value, 0) : 0}
            onClick={() => setBoard('')}
          />
          {communityBoards.map((id) => (
            <BoardButton
              key={id}
              active={board === id}
              label={communityBoardLabels[id]}
              description={communityBoardDescriptions[id]}
              count={counts?.[id] ?? 0}
              onClick={() => setBoard(id)}
            />
          ))}
        </nav>

        <div className="flex flex-wrap items-center gap-2">
          <SegmentedControl
            options={sorts.map((item) => item.id)}
            labels={
              Object.fromEntries(sorts.map((item) => [item.id, item.label])) as Record<
                CommunitySort,
                string
              >
            }
            value={sort}
            onChange={setSort}
          />
          <div className="relative min-w-0 flex-1">
            <Search className="absolute left-3 top-2 size-4 text-ink-3" />
            <Input
              aria-label="搜索帖子"
              placeholder="搜索标题、正文或标签"
              value={text}
              onChange={(event) => setText(event.target.value)}
              className="pl-9"
            />
          </div>
          <Button
            size="sm"
            variant={mineOnly ? 'secondary' : 'ghost'}
            aria-pressed={mineOnly}
            onClick={() => setMineOnly((value) => !value)}
          >
            只看我的
          </Button>
          <Button
            size="sm"
            variant={pendingOnly ? 'secondary' : 'ghost'}
            aria-pressed={pendingOnly}
            onClick={() => setPendingOnly((value) => !value)}
          >
            <ShieldCheck className="size-4" />
            待复核 {pendingCount}
          </Button>
        </div>

        <div className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.1fr)]">
          <section aria-label="帖子列表" className="grid content-start gap-2">
            {!snapshot && <p className="py-10 text-center text-13 text-ink-3">正在读取内容…</p>}
            {snapshot && !visible.length && (
              <p className="py-10 text-center text-13 text-ink-3">
                {pendingOnly ? '没有待复核的内容。' : '这个板块还没有内容，点右上角「发布」试试。'}
              </p>
            )}
            {visible.map((post) => (
              <button
                key={post.id}
                type="button"
                onClick={() => setSelectedId(post.id)}
                className={cn(
                  'grid gap-1.5 rounded-control bg-field p-3 text-left hover:bg-hover',
                  selected?.id === post.id && 'ring-1 ring-bui-accent',
                )}
              >
                <span className="flex flex-wrap items-center gap-2">
                  <span className="rounded-chip bg-inset px-1.5 py-0.5 text-2xs text-ink-3">
                    {communityBoardLabels[post.board]}
                  </span>
                  <span className="text-sm font-medium text-ink">{post.title}</span>
                  {post.status !== 'published' && (
                    <span
                      className={cn(
                        'rounded-chip px-1.5 py-0.5 text-2xs',
                        post.status === 'rejected'
                          ? 'bg-red-tint text-red'
                          : 'bg-orange-tint text-orange',
                      )}
                    >
                      {communityStatusLabels[post.status]}
                    </span>
                  )}
                </span>
                <span className="text-xs text-ink-2">{post.body.slice(0, 60)}</span>
                <span className="flex flex-wrap items-center gap-2 text-2xs text-ink-3">
                  <span>{post.author}</span>
                  <span>{new Date(post.createdAt).toLocaleDateString('zh-CN')}</span>
                  <span>赞 {post.likes}</span>
                  <span>回复 {post.replies.length}</span>
                  {communityPostSummary(post) && <span>{communityPostSummary(post)}</span>}
                </span>
              </button>
            ))}
          </section>

          <section aria-label="帖子详情" className="grid content-start gap-3">
            {selected ? (
              <PostDetail
                post={selected}
                viewer={viewer}
                busy={busy}
                reply={reply}
                onReplyChange={setReply}
                onLike={() => void apply(api.like(selected.id), '已更新点赞。')}
                onReply={() => {
                  const value = reply.trim();
                  if (!value) return;
                  setReply('');
                  void apply(api.reply(selected.id, value), '回复已保存在本机。');
                }}
                onReport={() =>
                  void apply(api.report(selected.id), '已记录举报；接入服务后会进入审核队列。')
                }
                onRemove={() => void apply(api.remove(selected.id), '帖子已删除。')}
                onModerate={(decision) =>
                  void apply(
                    api.moderate(selected.id, decision),
                    decision === 'publish' ? '已通过并发布。' : '已驳回，仅作者可见。',
                  )
                }
                onDealStatus={(status) =>
                  void apply(api.setDealStatus(selected.id, status), `已标记为${status}。`)
                }
              />
            ) : (
              <p className="rounded-control bg-field p-6 text-13 text-ink-3">
                左侧选择一条内容查看详情。
              </p>
            )}
          </section>
        </div>
      </div>

      <Composer
        open={composerOpen}
        onOpenChange={setComposerOpen}
        busy={busy}
        initialBoard={board || 'talk'}
        onSubmit={(input) =>
          void apply(api.create(input), '已提交；审核结论见帖子上的状态标签。').then(() =>
            setComposerOpen(false),
          )
        }
      />
    </div>
  );
}

function BoardButton({
  active,
  label,
  count,
  description,
  onClick,
}: {
  active: boolean;
  label: string;
  count: number;
  description?: string;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-pressed={active}
      title={description}
      className={cn(
        'flex items-center gap-1.5 rounded-control px-2.5 py-1.5 text-13 transition-colors',
        active ? 'bg-ink text-surface' : 'bg-field text-ink-2 hover:bg-hover',
      )}
    >
      {label}
      <span className={cn('text-2xs', active ? 'text-surface/70' : 'text-ink-3')}>{count}</span>
    </button>
  );
}

function PostDetail({
  post,
  viewer,
  busy,
  reply,
  onReplyChange,
  onLike,
  onReply,
  onReport,
  onRemove,
  onModerate,
  onDealStatus,
}: {
  post: CommunityPost;
  viewer: string;
  busy: boolean;
  reply: string;
  onReplyChange: (value: string) => void;
  onLike: () => void;
  onReply: () => void;
  onReport: () => void;
  onRemove: () => void;
  onModerate: (decision: 'publish' | 'reject') => void;
  onDealStatus: (status: '在售' | '已出') => void;
}) {
  const mine = post.author === viewer;
  const summary = communityPostSummary(post);
  return (
    <article className="grid gap-3 rounded-card bg-field p-4">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div className="min-w-0">
          <h2 className="break-words text-base font-semibold text-ink">{post.title}</h2>
          <p className="mt-1 text-xs text-ink-3">
            {communityBoardLabels[post.board]} · {post.author} ·{' '}
            {new Date(post.createdAt).toLocaleString('zh-CN')}
          </p>
        </div>
        <span
          className={cn(
            'rounded-chip px-2 py-0.5 text-2xs',
            post.status === 'published'
              ? 'bg-green-tint text-green'
              : post.status === 'rejected'
                ? 'bg-red-tint text-red'
                : 'bg-orange-tint text-orange',
          )}
        >
          {communityStatusLabels[post.status]}
        </span>
      </div>
      {summary && <p className="text-13 text-ink-2">{summary}</p>}
      <p className="whitespace-pre-wrap break-words text-13 leading-relaxed text-ink">
        {post.body}
      </p>
      {post.tags.length > 0 && (
        <div className="flex flex-wrap gap-1.5">
          {post.tags.map((tag) => (
            <span key={tag} className="rounded-chip bg-surface px-2 py-0.5 text-2xs text-ink-3">
              #{tag}
            </span>
          ))}
        </div>
      )}
      {post.review.reasons.length > 0 && (
        <div className="grid gap-1 rounded-control bg-surface p-3">
          <p className="flex items-center gap-1 text-xs font-medium text-ink-2">
            <ShieldCheck className="size-3.5" />
            基础审核提示
          </p>
          <ul className="grid list-disc gap-0.5 pl-4 text-xs text-ink-3">
            {post.review.reasons.map((reason) => (
              <li key={reason}>{reason}</li>
            ))}
          </ul>
          {post.review.needsVerification && (
            <p className="text-2xs text-orange">
              科研类内容需要人工核实来源；接入真实服务前请勿据此做出决定。
            </p>
          )}
        </div>
      )}
      {post.sourceUrl && <p className="break-all text-xs text-ink-3">来源：{post.sourceUrl}</p>}
      <div className="flex flex-wrap items-center gap-2">
        <Button
          size="sm"
          variant={post.liked ? 'secondary' : 'ghost'}
          disabled={busy || post.status === 'rejected'}
          aria-pressed={post.liked}
          onClick={onLike}
        >
          <Heart className={post.liked ? 'size-4 text-red' : 'size-4'} />
          {post.likes}
        </Button>
        <Button size="sm" variant="ghost" disabled={busy} onClick={onReport}>
          <Flag className="size-4" />
          举报 {post.reports > 0 ? `(${post.reports})` : ''}
        </Button>
        {post.board === 'market' && mine && (
          <Button
            size="sm"
            variant="ghost"
            disabled={busy}
            onClick={() => onDealStatus(post.dealStatus === '已出' ? '在售' : '已出')}
          >
            {post.dealStatus === '已出' ? '重新上架' : '标记已出'}
          </Button>
        )}
        {mine && (
          <Button size="sm" variant="ghost" disabled={busy} onClick={onRemove}>
            <Trash2 className="size-4" />
            删除
          </Button>
        )}
        {(post.status === 'pending' || post.status === 'unverified') && (
          <>
            <Button
              size="sm"
              variant="outline"
              disabled={busy}
              onClick={() => onModerate('publish')}
            >
              通过
            </Button>
            <Button size="sm" variant="ghost" disabled={busy} onClick={() => onModerate('reject')}>
              驳回
            </Button>
          </>
        )}
      </div>
      <div className="grid gap-2">
        <h3 className="flex items-center gap-1 text-xs font-medium text-ink-2">
          <MessageSquare className="size-3.5" />
          回复 {post.replies.length}
        </h3>
        {post.replies.map((item) => (
          <div key={item.id} className="rounded-control bg-surface p-2.5">
            <p className="text-2xs text-ink-3">
              {item.author} · {new Date(item.createdAt).toLocaleString('zh-CN')}
            </p>
            <p className="mt-1 whitespace-pre-wrap break-words text-13 text-ink-2">{item.body}</p>
          </div>
        ))}
        <div className="flex flex-wrap gap-2">
          <Input
            aria-label="写下回复"
            placeholder="写下你的回复"
            value={reply}
            onChange={(event) => onReplyChange(event.target.value)}
          />
          <Button size="sm" disabled={busy || !reply.trim()} onClick={onReply}>
            回复
          </Button>
        </div>
      </div>
    </article>
  );
}

const conditions: CommunityCondition[] = ['全新', '九成新', '正常使用', '有瑕疵'];

function Composer({
  open,
  onOpenChange,
  busy,
  initialBoard,
  onSubmit,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  busy: boolean;
  initialBoard: CommunityBoard;
  onSubmit: (input: CommunityPostInput) => void;
}) {
  const [board, setBoard] = useState<CommunityBoard>(initialBoard);
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [tags, setTags] = useState('');
  const [contact, setContact] = useState('');
  const [price, setPrice] = useState('');
  const [condition, setCondition] = useState<CommunityCondition>('九成新');
  const [sourceUrl, setSourceUrl] = useState('');
  const [lab, setLab] = useState('');
  const [competition, setCompetition] = useState('');
  const [deadline, setDeadline] = useState('');
  const [shop, setShop] = useState('');
  const [rating, setRating] = useState('4');
  const [pricePerPerson, setPricePerPerson] = useState('');

  useEffect(() => {
    if (!open) return;
    setBoard(initialBoard);
    setTitle('');
    setBody('');
    setTags('');
    setContact('');
    setPrice('');
    setCondition('九成新');
    setSourceUrl('');
    setLab('');
    setCompetition('');
    setDeadline('');
    setShop('');
    setRating('4');
    setPricePerPerson('');
  }, [open, initialBoard]);

  const input: CommunityPostInput = {
    board,
    title,
    body,
    tags: tags
      .split(/[,，\s]+/)
      .map((tag) => tag.trim())
      .filter(Boolean),
    ...(contact.trim() ? { contact: contact.trim() } : {}),
    ...(board === 'market' ? { price: price ? Number(price) : null, condition } : {}),
    ...(board === 'research'
      ? {
          ...(sourceUrl.trim() ? { sourceUrl: sourceUrl.trim() } : {}),
          ...(lab.trim() ? { lab } : {}),
        }
      : {}),
    ...(board === 'contest'
      ? {
          ...(competition.trim() ? { competition } : {}),
          ...(deadline ? { deadline } : {}),
        }
      : {}),
    ...(board === 'food'
      ? {
          ...(shop.trim() ? { shop } : {}),
          rating: rating ? Number(rating) : null,
          pricePerPerson: pricePerPerson ? Number(pricePerPerson) : null,
        }
      : {}),
  };
  const preview = reviewCommunityPost(input);

  return (
    <Dialog.Root open={open} onOpenChange={onOpenChange}>
      <Dialog.Portal>
        <Dialog.Overlay className={dialogOverlay} />
        <Dialog.Content className={cn(dialogPanel, 'max-h-[88vh] max-w-xl overflow-y-auto')}>
          <Dialog.Title className="text-base font-semibold">发布到校园社区</Dialog.Title>
          <Dialog.Description className="mt-1 text-xs text-ink-3">
            当前保存在本机；下方是「基础审核」的即时预览，正式版会接入服务端审核。
          </Dialog.Description>
          <div className="mt-4 grid gap-3">
            <label className="grid gap-1 text-13 text-ink-2">
              板块
              <select
                aria-label="选择板块"
                className="rounded-control bg-field px-3 py-2 text-13 text-ink"
                value={board}
                onChange={(event) => setBoard(event.target.value as CommunityBoard)}
              >
                {communityBoards.map((id) => (
                  <option key={id} value={id}>
                    {communityBoardLabels[id]}
                  </option>
                ))}
              </select>
            </label>
            <label className="grid gap-1 text-13 text-ink-2">
              标题
              <Input
                aria-label="帖子标题"
                placeholder="一句话说清楚"
                value={title}
                onChange={(event) => setTitle(event.target.value)}
              />
            </label>
            <label className="grid gap-1 text-13 text-ink-2">
              正文
              <Textarea
                aria-label="帖子正文"
                rows={4}
                placeholder="补充细节、地点、时间等"
                value={body}
                onChange={(event) => setBody(event.target.value)}
              />
            </label>
            <label className="grid gap-1 text-13 text-ink-2">
              标签（空格或逗号分隔）
              <Input
                aria-label="标签"
                placeholder="如图书馆 期末"
                value={tags}
                onChange={(event) => setTags(event.target.value)}
              />
            </label>
            {board === 'market' && (
              <div className="grid gap-3 sm:grid-cols-2">
                <label className="grid gap-1 text-13 text-ink-2">
                  价格（元）
                  <Input
                    aria-label="价格"
                    inputMode="numeric"
                    placeholder="0 表示赠送"
                    value={price}
                    onChange={(event) => setPrice(event.target.value)}
                  />
                </label>
                <label className="grid gap-1 text-13 text-ink-2">
                  成色
                  <select
                    aria-label="成色"
                    className="rounded-control bg-field px-3 py-2 text-13 text-ink"
                    value={condition}
                    onChange={(event) => setCondition(event.target.value as CommunityCondition)}
                  >
                    {conditions.map((value) => (
                      <option key={value} value={value}>
                        {value}
                      </option>
                    ))}
                  </select>
                </label>
              </div>
            )}
            {board === 'research' && (
              <div className="grid gap-3">
                <label className="grid gap-1 text-13 text-ink-2">
                  来源链接（必填，用于核实）
                  <Input
                    aria-label="来源链接"
                    placeholder="https://"
                    value={sourceUrl}
                    onChange={(event) => setSourceUrl(event.target.value)}
                  />
                </label>
                <label className="grid gap-1 text-13 text-ink-2">
                  课题组 / 实验室
                  <Input
                    aria-label="课题组"
                    value={lab}
                    onChange={(event) => setLab(event.target.value)}
                  />
                </label>
              </div>
            )}
            {board === 'contest' && (
              <div className="grid gap-3 sm:grid-cols-2">
                <label className="grid gap-1 text-13 text-ink-2">
                  比赛名称
                  <Input
                    aria-label="比赛名称"
                    value={competition}
                    onChange={(event) => setCompetition(event.target.value)}
                  />
                </label>
                <label className="grid gap-1 text-13 text-ink-2">
                  截止日期
                  <Input
                    aria-label="截止日期"
                    type="date"
                    value={deadline}
                    onChange={(event) => setDeadline(event.target.value)}
                  />
                </label>
              </div>
            )}
            {board === 'food' && (
              <div className="grid gap-3 sm:grid-cols-3">
                <label className="grid gap-1 text-13 text-ink-2 sm:col-span-1">
                  店铺
                  <Input
                    aria-label="店铺"
                    value={shop}
                    onChange={(event) => setShop(event.target.value)}
                  />
                </label>
                <label className="grid gap-1 text-13 text-ink-2">
                  评分（1–5）
                  <Input
                    aria-label="评分"
                    inputMode="decimal"
                    value={rating}
                    onChange={(event) => setRating(event.target.value)}
                  />
                </label>
                <label className="grid gap-1 text-13 text-ink-2">
                  人均（元）
                  <Input
                    aria-label="人均"
                    inputMode="numeric"
                    value={pricePerPerson}
                    onChange={(event) => setPricePerPerson(event.target.value)}
                  />
                </label>
              </div>
            )}
            <label className="grid gap-1 text-13 text-ink-2">
              联系方式（选填）
              <Input
                aria-label="联系方式"
                placeholder="站内留言即可，也可留其他方式"
                value={contact}
                onChange={(event) => setContact(event.target.value)}
              />
            </label>
            <div
              className={cn(
                'grid gap-1 rounded-control p-3 text-xs',
                preview.level === 'block'
                  ? 'bg-red-tint text-red'
                  : preview.level === 'warn'
                    ? 'bg-orange-tint text-orange'
                    : 'bg-green-tint text-green',
              )}
              role="status"
            >
              <p className="font-medium">
                基础审核：
                {preview.level === 'block'
                  ? '将被拦截'
                  : preview.level === 'warn'
                    ? '需复核'
                    : '可直接发布'}
              </p>
              {preview.reasons.length > 0 && (
                <ul className="grid list-disc gap-0.5 pl-4">
                  {preview.reasons.map((reason) => (
                    <li key={reason}>{reason}</li>
                  ))}
                </ul>
              )}
              {board === 'research' && <p>科研信息一律标注来源并等待人工核实。</p>}
            </div>
          </div>
          <div className="mt-5 flex justify-end gap-2">
            <Dialog.Close asChild>
              <Button size="sm" variant="ghost">
                取消
              </Button>
            </Dialog.Close>
            <Button
              size="sm"
              disabled={busy || title.trim().length < 2 || body.trim().length < 1}
              onClick={() => onSubmit(input)}
            >
              提交
            </Button>
          </div>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  );
}
