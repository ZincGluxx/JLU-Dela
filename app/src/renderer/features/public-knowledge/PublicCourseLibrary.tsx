import { useState } from 'react';
import { Dialog } from 'radix-ui';
import {
  ArrowLeft,
  ArrowUpRight,
  BookOpen,
  Bookmark,
  ChevronRight,
  Download,
  FileText,
  Folder,
  MessageSquare,
  Search,
  ThumbsUp,
  Upload,
  Users,
  X,
} from 'lucide-react';
import { Button } from '../../components/ui/button';
import { Input } from '../../components/ui/input';
import { Textarea } from '../../components/ui/textarea';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '../../components/ui/select';
import { SegmentedControl } from '../../components/ui/beautifului/atoms/SegmentedControl';
import { dialogOverlay, dialogPanel } from '../../components/ui/motion';
import { cn } from '../../lib/utils';
import {
  courseCategories,
  courseGrades,
  courseExamples,
  dataStructureMaterials,
  materialTypes,
  type MaterialExample,
  type PublicCourseExample,
} from './public-course-examples';

const levels = ['学院', '专业', '年级', '课程类别'] as const;
const directoryButton =
  'flex min-w-0 items-center gap-3 rounded-card bg-inset p-4 text-left text-ink transition-colors duration-150 hover:bg-hover focus-visible:outline-2 focus-visible:outline-bui-accent';

export function PublicCourseLibrary() {
  const [path, setPath] = useState<string[]>([]);
  const [course, setCourse] = useState<PublicCourseExample | null>(null);
  const [query, setQuery] = useState('');
  const matchingCourses = courseExamples.filter((item) =>
    path.every((part, index) => item.classification[index] === part),
  );
  const courses = matchingCourses.filter((item) => item.name.includes(query.trim()));
  const options =
    path.length === 2
      ? courseGrades
      : path.length === 3
        ? courseCategories
        : [
            ...new Set(
              matchingCourses.flatMap((item) =>
                item.classification.slice(path.length, path.length + 1),
              ),
            ),
          ];

  function navigate(nextPath: string[]) {
    setPath(nextPath);
    setCourse(null);
    setQuery('');
  }

  return (
    <div className="min-h-0 flex-1 overflow-y-auto p-4 md:p-6">
      <div className="mx-auto w-full max-w-6xl">
        <header className="mb-6 flex flex-wrap items-start justify-between gap-3">
          <div>
            <div className="flex flex-wrap items-center gap-2">
              <h1 className="text-xl font-semibold text-ink">公共课程知识库</h1>
              <span className="rounded-chip bg-inset px-2 py-1 text-xs text-ink-2">示例原型</span>
            </div>
            <p className="mt-2 text-13 text-ink-2">一起整理课程资料，让下一次学习有迹可循。</p>
          </div>
          <span className="flex items-center gap-1.5 text-xs text-ink-3">
            <Users className="size-4" />
            同学共享空间
          </span>
        </header>

        <p className="mb-6 rounded-control bg-inset p-3 text-xs leading-relaxed text-ink-2">
          分类、课程归属、帖子、评论及互动数量均为示例，不代表学校正式培养方案。上传、下载、评论发布与互动同步待接入。
        </p>

        <nav aria-label="课程分类位置" className="mb-6 flex flex-wrap items-center gap-1 text-13">
          <Button
            size="sm"
            variant="ghost"
            onClick={() => navigate([])}
            aria-current={!path.length && !course ? 'page' : undefined}
          >
            全部学院
          </Button>
          {path.map((part, index) => (
            <span className="flex min-w-0 items-center gap-1" key={index}>
              <ChevronRight aria-hidden="true" className="size-3 shrink-0 text-ink-3" />
              <Button
                size="sm"
                variant="ghost"
                className="h-auto min-w-0 whitespace-normal text-left"
                onClick={() => navigate(path.slice(0, index + 1))}
                aria-current={index === path.length - 1 && !course ? 'page' : undefined}
              >
                {part}
              </Button>
            </span>
          ))}
          {course && (
            <span aria-current="page" className="flex min-w-0 items-center gap-2 text-ink">
              <ChevronRight aria-hidden="true" className="size-3 shrink-0 text-ink-3" />
              {course.name}
            </span>
          )}
        </nav>

        {(course || path.length > 0) && (
          <Button
            className="mb-4"
            size="sm"
            variant="ghost"
            onClick={() => (course ? setCourse(null) : navigate(path.slice(0, -1)))}
          >
            <ArrowLeft className="size-4" />
            返回上一级
          </Button>
        )}

        {course ? (
          <CourseRepository key={course.id} course={course} />
        ) : (
          <>
            {path.length < levels.length && (
              <section className="mb-8" aria-label={`选择${levels[path.length]}`}>
                <h2 className="mb-3 text-sm font-medium text-ink">选择{levels[path.length]}</h2>
                <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
                  {options.map((option) => (
                    <button
                      key={option}
                      className={directoryButton}
                      onClick={() => navigate([...path, option])}
                    >
                      <Folder aria-hidden="true" className="size-5 shrink-0 text-ink-3" />
                      <span className="min-w-0 flex-1 break-words text-13 font-medium">
                        {option}
                      </span>
                      <ChevronRight aria-hidden="true" className="size-4 shrink-0 text-ink-3" />
                    </button>
                  ))}
                </div>
              </section>
            )}

            <section aria-label="当前分类课程">
              <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
                <h2 className="text-sm font-medium text-ink">
                  {path.length ? `${path.at(-1)}下的课程` : '全部示例课程'}
                  <span className="ml-2 text-xs font-normal text-ink-3">{courses.length} 门</span>
                </h2>
                <div className="relative w-full md:w-64">
                  <Search
                    aria-hidden="true"
                    className="pointer-events-none absolute top-2 left-2.5 size-4 text-ink-3"
                  />
                  <Input
                    aria-label="按课程名称查找"
                    placeholder="查找课程名称"
                    value={query}
                    onChange={(event) => setQuery(event.target.value)}
                    className="pl-8"
                  />
                </div>
              </div>
              <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
                {courses.map((item) => (
                  <button
                    className={cn(directoryButton, 'items-start p-5')}
                    key={item.id}
                    onClick={() => {
                      setPath([...item.classification]);
                      setCourse(item);
                    }}
                  >
                    <BookOpen aria-hidden="true" className="mt-0.5 size-5 shrink-0 text-ink-3" />
                    <span className="min-w-0 flex-1">
                      <span className="flex items-start justify-between gap-2">
                        <span className="break-words text-sm font-medium">{item.name}</span>
                        <ArrowUpRight aria-hidden="true" className="size-4 shrink-0 text-ink-3" />
                      </span>
                      <span className="mt-2 block text-xs leading-relaxed text-ink-2">
                        {item.description}
                      </span>
                      <span className="mt-4 block text-xs leading-relaxed text-ink-3">
                        {item.classification.join(' / ')}
                      </span>
                      <span className="mt-2 block text-xs text-ink-2">
                        {item.id === 'data-structures' ? '4 篇示例资料帖' : '暂无示例资料帖'}
                      </span>
                    </span>
                  </button>
                ))}
              </div>
              {!courses.length && (
                <div className="rounded-card bg-inset px-4 py-12 text-center">
                  <BookOpen className="mx-auto mb-3 size-6 text-ink-3" />
                  <p className="text-sm text-ink">
                    {query.trim() ? '没有找到匹配的课程' : '此分类暂无示例课程'}
                  </p>
                  <p className="mt-2 text-xs text-ink-2">
                    {query.trim()
                      ? '试试其他课程名称，或清空搜索。'
                      : '可以返回上一级选择其他分类。'}
                  </p>
                  {query.trim() && (
                    <Button variant="ghost" size="sm" className="mt-3" onClick={() => setQuery('')}>
                      清空搜索
                    </Button>
                  )}
                </div>
              )}
            </section>
          </>
        )}
      </div>
    </div>
  );
}

function CourseRepository({ course }: { course: PublicCourseExample }) {
  const [section, setSection] = useState<'posts' | 'materials' | 'discussion'>('posts');
  const [material, setMaterial] = useState<MaterialExample | null>(null);
  const [uploadOpen, setUploadOpen] = useState(false);
  const [notice, setNotice] = useState('');
  const [likedIds, setLikedIds] = useState<string[]>([]);
  const [savedIds, setSavedIds] = useState<string[]>([]);
  const [postFilter, setPostFilter] = useState<'all' | 'saved'>('all');
  const [postSort, setPostSort] = useState<'latest' | 'likes'>('latest');
  const materials = course.id === 'data-structures' ? dataStructureMaterials : [];
  const visiblePosts = materials
    .filter((item) => postFilter === 'all' || savedIds.includes(item.id))
    .sort(
      (left, right) =>
        (postSort === 'likes'
          ? right.likes +
            Number(likedIds.includes(right.id)) -
            left.likes -
            Number(likedIds.includes(left.id))
          : 0) || right.uploadedAt.localeCompare(left.uploadedAt),
    );
  const rankedMaterials = [...materials].sort(
    (left, right) =>
      right.downloads - left.downloads || right.uploadedAt.localeCompare(left.uploadedAt),
  );

  function toggleLike(id: string) {
    setLikedIds((ids) => (ids.includes(id) ? ids.filter((item) => item !== id) : [...ids, id]));
  }

  function toggleSave(id: string) {
    setSavedIds((ids) => (ids.includes(id) ? ids.filter((item) => item !== id) : [...ids, id]));
  }
  return (
    <>
      <header className="mb-6 flex flex-wrap items-start justify-between gap-4">
        <div className="min-w-0 flex-1">
          <h2 className="break-words text-xl font-semibold text-ink">{course.name}</h2>
          <p className="mt-2 text-xs leading-relaxed text-ink-3">
            {course.classification.join(' / ')}
          </p>
          <p className="mt-3 text-13 leading-relaxed text-ink-2">{course.description}</p>
        </div>
        <Button onClick={() => setUploadOpen(true)}>
          <Upload className="size-4" />
          发布资料帖
        </Button>
      </header>
      <div className="mb-5 flex flex-wrap items-center justify-between gap-3">
        <SegmentedControl
          options={['posts', 'materials', 'discussion']}
          labels={{
            posts: `帖子 · ${materials.length}`,
            materials: `资料 · ${materials.length}`,
            discussion: '课程讨论',
          }}
          value={section}
          onChange={(next) => {
            setSection(next);
            setNotice('');
          }}
        />
        <span className="text-xs text-ink-3">仅展示示例内容</span>
      </div>
      {notice && (
        <p role="status" className="mb-4 rounded-control bg-inset p-3 text-13 text-ink-2">
          {notice}
        </p>
      )}
      {section === 'posts' ? (
        <section aria-label="课程帖子">
          <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
            <div className="flex flex-wrap gap-1" role="group" aria-label="帖子筛选">
              <Button
                size="sm"
                variant={postFilter === 'all' ? 'secondary' : 'ghost'}
                aria-pressed={postFilter === 'all'}
                onClick={() => setPostFilter('all')}
              >
                全部帖子
              </Button>
              <Button
                size="sm"
                variant={postFilter === 'saved' ? 'secondary' : 'ghost'}
                aria-pressed={postFilter === 'saved'}
                onClick={() => setPostFilter('saved')}
              >
                <Bookmark className="size-3.5" />
                本页收藏 · {savedIds.length}
              </Button>
            </div>
            <div role="group" aria-label="帖子排序">
              <SegmentedControl
                options={['latest', 'likes']}
                labels={{ latest: '最新发布', likes: '最多点赞' }}
                value={postSort}
                onChange={setPostSort}
              />
            </div>
          </div>
          <p className="mb-4 text-xs text-ink-2">点赞、收藏仅本页体验，离开课程后重置</p>
          {visiblePosts.length ? (
            <ul className="max-w-4xl space-y-4">
              {visiblePosts.map((item) => (
                <li key={item.id}>
                  <article
                    aria-label={item.title}
                    className="min-w-0 rounded-card bg-surface p-4 shadow-hairline md:p-5"
                  >
                    <header className="mb-4 flex flex-wrap items-center justify-between gap-3">
                      <div className="flex min-w-0 items-center gap-2.5">
                        <span
                          aria-hidden="true"
                          className="flex size-8 shrink-0 items-center justify-center rounded-full bg-inset text-xs font-medium text-ink-2"
                        >
                          {item.contributor.slice(-1)}
                        </span>
                        <div className="min-w-0">
                          <p className="text-13 font-medium text-ink">
                            {item.contributor}
                            <span className="ml-2 text-xs font-normal text-ink-3">示例用户</span>
                          </p>
                          <time
                            className="mt-0.5 block text-xs text-ink-3"
                            dateTime={item.uploadedAt}
                          >
                            {item.uploadedAt} 分享
                          </time>
                        </div>
                      </div>
                      <span className="rounded-chip bg-inset px-2 py-1 text-xs text-ink-2">
                        {item.type}
                      </span>
                    </header>
                    <h3>
                      <button
                        className="rounded-chip text-left text-base font-semibold break-words text-ink hover:text-bui-accent-ink focus-visible:outline-2 focus-visible:outline-bui-accent"
                        onClick={() => {
                          setNotice('');
                          setMaterial(item);
                        }}
                      >
                        {item.title}
                      </button>
                    </h3>
                    <p className="mt-3 text-13 leading-relaxed text-ink-2">{item.description}</p>
                    <button
                      className="mt-4 flex w-full min-w-0 items-center gap-3 rounded-control bg-inset p-3 text-left hover:bg-hover focus-visible:outline-2 focus-visible:outline-bui-accent"
                      aria-label={`查看 ${item.title}`}
                      onClick={() => {
                        setNotice('');
                        setMaterial(item);
                      }}
                    >
                      <FileText aria-hidden="true" className="size-5 shrink-0 text-ink-3" />
                      <span className="min-w-0 flex-1">
                        <span className="block text-13 break-all text-ink">{item.filename}</span>
                        <span className="mt-1 block text-xs text-ink-3">
                          示例附件 · {item.downloads} 次下载 · 查看预览
                        </span>
                      </span>
                      <ChevronRight aria-hidden="true" className="size-4 shrink-0 text-ink-3" />
                    </button>
                    <footer className="mt-4 flex flex-wrap items-center justify-between gap-2">
                      <div className="flex flex-wrap items-center gap-1">
                        <PostReactions
                          material={item}
                          liked={likedIds.includes(item.id)}
                          saved={savedIds.includes(item.id)}
                          onLike={() => toggleLike(item.id)}
                          onSave={() => toggleSave(item.id)}
                        />
                        <Button
                          size="sm"
                          variant="ghost"
                          aria-label={`评价 ${item.title}`}
                          onClick={() => {
                            setNotice('');
                            setMaterial(item);
                          }}
                        >
                          <MessageSquare className="size-4" />
                          评价
                        </Button>
                      </div>
                      <Button
                        size="sm"
                        variant="ghost"
                        aria-label={`下载 ${item.title}（待接入）`}
                        onClick={() => setNotice('下载待接入；此示例未附带可下载文件。')}
                      >
                        <Download className="size-4" />
                        下载
                      </Button>
                    </footer>
                  </article>
                </li>
              ))}
            </ul>
          ) : (
            <div className="max-w-4xl rounded-card bg-inset px-4 py-12 text-center">
              {postFilter === 'saved' ? (
                <Bookmark className="mx-auto mb-3 size-6 text-ink-3" />
              ) : (
                <Folder className="mx-auto mb-3 size-6 text-ink-3" />
              )}
              <h3 className="text-sm font-medium text-ink">
                {postFilter === 'saved' ? '本页还没有收藏的帖子' : '这门课程暂无示例资料帖'}
              </h3>
              <p className="mt-2 text-xs text-ink-2">
                {postFilter === 'saved'
                  ? '在帖子下方点收藏，即可在这里查看。'
                  : '分享资料、写下简介，和同学交流学习心得。上传与发布待接入。'}
              </p>
              {postFilter === 'saved' ? (
                <Button variant="ghost" className="mt-4" onClick={() => setPostFilter('all')}>
                  查看全部帖子
                </Button>
              ) : (
                <Button variant="outline" className="mt-4" onClick={() => setUploadOpen(true)}>
                  <Upload className="size-4" />
                  发布资料帖
                </Button>
              )}
            </div>
          )}
        </section>
      ) : section === 'materials' ? (
        <section aria-label="课程资料">
          <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
            <h3 className="text-sm font-medium text-ink">资料下载排行</h3>
            <span className="text-xs text-ink-2">按下载量从高到低 · 下载量为示例</span>
          </div>
          <p className="mb-4 text-xs text-ink-2">
            资料来自课程帖子的附件，发帖时一并上传。真实上传与下载待接入。
          </p>
          {rankedMaterials.length ? (
            <ol aria-label="资料下载排行" className="max-w-4xl space-y-3">
              {rankedMaterials.map((item, index) => (
                <li
                  key={item.id}
                  className="flex min-w-0 flex-col gap-3 rounded-card bg-inset p-4 md:flex-row md:items-center"
                >
                  <div className="flex min-w-0 flex-1 items-start gap-3">
                    <span
                      aria-label={`第 ${index + 1} 名`}
                      className="flex size-7 shrink-0 items-center justify-center rounded-chip bg-surface text-xs font-medium tabular-nums text-ink-2"
                    >
                      {index + 1}
                    </span>
                    <div className="min-w-0 flex-1">
                      <button
                        aria-label={`查看 ${item.title}`}
                        className="rounded-chip text-left text-13 font-medium break-all text-ink hover:text-bui-accent-ink focus-visible:outline-2 focus-visible:outline-bui-accent"
                        onClick={() => {
                          setNotice('');
                          setMaterial(item);
                        }}
                      >
                        {item.filename}
                      </button>
                      <p className="mt-1 text-xs leading-relaxed break-words text-ink-2">
                        {item.type} · {item.contributor} ·{' '}
                        <time dateTime={item.uploadedAt}>{item.uploadedAt}</time>
                      </p>
                      <p className="mt-2 text-xs break-words text-ink-3">来自帖子：{item.title}</p>
                    </div>
                  </div>
                  <div className="flex flex-wrap items-center gap-2 md:justify-end">
                    <span
                      aria-label={`示例下载量 ${item.downloads}`}
                      className="mr-2 text-xs tabular-nums text-ink-2"
                    >
                      {item.downloads} 次下载
                    </span>
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => {
                        setNotice('');
                        setMaterial(item);
                      }}
                    >
                      查看原帖
                    </Button>
                    <Button
                      variant="ghost"
                      size="sm"
                      aria-label={`下载 ${item.title}（待接入）`}
                      onClick={() =>
                        setNotice('下载待接入；此示例未附带可下载文件，下载量未改变。')
                      }
                    >
                      <Download className="size-4" />
                      下载
                    </Button>
                  </div>
                </li>
              ))}
            </ol>
          ) : (
            <div className="max-w-4xl rounded-card bg-inset px-4 py-12 text-center">
              <Folder className="mx-auto mb-3 size-6 text-ink-3" />
              <h3 className="text-sm font-medium text-ink">这门课程暂无示例资料</h3>
              <p className="mt-2 text-xs text-ink-2">
                使用上方「发布资料帖」，一起分享帖子和附件。
              </p>
            </div>
          )}
        </section>
      ) : (
        <Discussion key={course.id} courseName={course.name} />
      )}

      <Dialog.Root open={material !== null} onOpenChange={(open) => !open && setMaterial(null)}>
        <Dialog.Portal>
          <Dialog.Overlay className={dialogOverlay} />
          <Dialog.Content className={cn(dialogPanel, 'max-h-[85vh] max-w-2xl overflow-y-auto')}>
            <div className="flex items-start justify-between gap-3">
              <Dialog.Title className="min-w-0 break-words text-base font-semibold">
                {material?.title}
              </Dialog.Title>
              <Dialog.Close asChild>
                <Button variant="ghost" size="icon-sm" aria-label="关闭帖子详情">
                  <X className="size-4" />
                </Button>
              </Dialog.Close>
            </div>
            <Dialog.Description className="mt-2 text-xs leading-relaxed text-ink-2">
              {course.name} · {material?.type} · {material?.contributor} · {material?.uploadedAt}
            </Dialog.Description>
            {material && (
              <>
                <p className="mt-4 text-13 leading-relaxed text-ink-2">{material.description}</p>
                <section aria-label="示例内容预览" className="my-5 rounded-control bg-inset p-4">
                  <h3 className="text-sm font-medium">示例内容预览</h3>
                  <p className="mt-2 text-xs text-ink-2">
                    以下为演示文本，非真实文件正文。文件预览待接入。
                  </p>
                  <p className="mt-4 text-13 leading-relaxed text-ink">{material.preview}</p>
                </section>
                <p className="text-xs break-all text-ink-3">
                  文件：{material.filename} · 示例下载量：{material.downloads} · 下载待接入
                </p>
                <div className="mt-4 flex flex-wrap gap-1">
                  <PostReactions
                    material={material}
                    liked={likedIds.includes(material.id)}
                    saved={savedIds.includes(material.id)}
                    onLike={() => toggleLike(material.id)}
                    onSave={() => toggleSave(material.id)}
                  />
                </div>
                <p className="mt-2 text-xs text-ink-3">点赞、收藏仅本页体验，离开课程后重置</p>
                <Discussion
                  key={material.id}
                  courseName={course.name}
                  materialTitle={material.title}
                />
              </>
            )}
          </Dialog.Content>
        </Dialog.Portal>
      </Dialog.Root>

      <Dialog.Root open={uploadOpen} onOpenChange={setUploadOpen}>
        <Dialog.Portal>
          <Dialog.Overlay className={dialogOverlay} />
          <Dialog.Content className={cn(dialogPanel, 'max-h-[85vh] max-w-lg overflow-y-auto')}>
            <div className="flex items-center justify-between gap-3">
              <Dialog.Title className="text-base font-semibold">发布资料帖</Dialog.Title>
              <Dialog.Close asChild>
                <Button variant="ghost" size="icon-sm" aria-label="关闭上传窗口">
                  <X className="size-4" />
                </Button>
              </Dialog.Close>
            </div>
            <Dialog.Description className="mt-2 text-xs leading-relaxed text-ink-2">
              发布到「{course.name}」，帖子和资料一并发布。当前上传与发布待接入，所选文件不会上传。
            </Dialog.Description>
            <ContributionForm course={course} />
          </Dialog.Content>
        </Dialog.Portal>
      </Dialog.Root>
    </>
  );
}

function PostReactions({
  material,
  liked,
  saved,
  onLike,
  onSave,
}: {
  material: MaterialExample;
  liked: boolean;
  saved: boolean;
  onLike: () => void;
  onSave: () => void;
}) {
  return (
    <>
      <Button
        size="sm"
        variant={liked ? 'secondary' : 'ghost'}
        aria-pressed={liked}
        aria-label={`${liked ? '取消点赞' : '点赞'} ${material.title}`}
        onClick={onLike}
      >
        <ThumbsUp className={cn('size-4', liked && 'fill-current')} />赞{' '}
        {material.likes + Number(liked)}
      </Button>
      <Button
        size="sm"
        variant={saved ? 'secondary' : 'ghost'}
        aria-pressed={saved}
        aria-label={`${saved ? '取消收藏' : '收藏'} ${material.title}`}
        onClick={onSave}
      >
        <Bookmark className={cn('size-4', saved && 'fill-current')} />
        {saved ? '已收藏' : '收藏'}
      </Button>
    </>
  );
}

function ContributionForm({ course }: { course: PublicCourseExample }) {
  const [file, setFile] = useState<File | null>(null);
  const [title, setTitle] = useState('');
  const [type, setType] = useState<string>('笔记');
  const [description, setDescription] = useState('');
  const [notice, setNotice] = useState('');
  return (
    <form
      className="mt-5 space-y-4"
      onSubmit={(event) => {
        event.preventDefault();
        setNotice('上传与发布待接入，文件未上传，帖子未发布或保存。');
      }}
    >
      <p className="rounded-control bg-inset p-3 text-xs leading-relaxed text-ink-2">
        {course.classification.join(' / ')} / {course.name}
      </p>
      <label className="block text-13 text-ink">
        选择文件
        <Input
          required
          type="file"
          className="mt-2 h-auto py-2"
          onChange={(event) => {
            const selected = event.target.files?.[0] ?? null;
            setFile(selected);
            if (selected && !title) setTitle(selected.name.replace(/\.[^.]+$/, ''));
            setNotice('');
          }}
        />
      </label>
      {file && (
        <p className="text-xs break-all text-ink-2">已选择：{file.name} · 仅在此表单中使用</p>
      )}
      <label className="block text-13 text-ink">
        帖子标题
        <Input
          required
          maxLength={120}
          value={title}
          onChange={(event) => {
            setTitle(event.target.value);
            setNotice('');
          }}
          className="mt-2"
          placeholder="例如：第三章课堂笔记"
        />
      </label>
      <div>
        <label id="contribution-type-label" className="mb-2 block text-13 text-ink">
          资料类型
        </label>
        <Select value={type} onValueChange={setType}>
          <SelectTrigger aria-labelledby="contribution-type-label" className="w-full">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {materialTypes.map((item) => (
              <SelectItem key={item} value={item}>
                {item}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>
      <label className="block text-13 text-ink">
        帖子简介
        <Textarea
          required
          maxLength={2000}
          value={description}
          onChange={(event) => setDescription(event.target.value)}
          className="mt-2"
          placeholder="介绍资料的内容、适用范围或使用建议"
        />
      </label>
      {notice && (
        <p role="status" className="rounded-control bg-inset p-3 text-13 text-ink-2">
          {notice}
        </p>
      )}
      <div className="flex flex-wrap items-center justify-end gap-2">
        <Dialog.Close asChild>
          <Button variant="ghost">取消</Button>
        </Dialog.Close>
        <Button type="submit" disabled={!file || !title.trim() || !description.trim()}>
          <Upload className="size-4" />
          发布资料帖（待接入）
        </Button>
      </div>
    </form>
  );
}

function Discussion({ courseName, materialTitle }: { courseName: string; materialTitle?: string }) {
  const [text, setText] = useState('');
  const [notice, setNotice] = useState('');
  const comments = materialTitle
    ? [
        {
          author: '阿禾',
          date: '2026-10-20',
          text: '复习时可以结合自己的课堂记录，补充还没理解的部分。',
        },
        { author: '小林', date: '2026-10-21', text: '也欢迎在这里交流这份资料里的疑问。' },
      ]
    : [
        {
          author: '小周',
          date: '2026-10-20',
          text: '大家整理这门课时，会按章节还是按知识点记笔记？',
        },
        {
          author: '阿禾',
          date: '2026-10-21',
          text: '我先按章节整理，再单独列一张知识点清单，方便复习。',
        },
      ];
  return (
    <section className="mt-6" aria-label={materialTitle ? '帖子评价' : '课程讨论'}>
      <h3 className="flex items-center gap-2 text-sm font-medium text-ink">
        <MessageSquare className="size-4 text-ink-3" />
        {materialTitle ? '帖子评价' : '课程讨论'}
        <span className="text-xs font-normal text-ink-3">示例 · {comments.length} 条</span>
      </h3>
      <ol className="mt-4 space-y-4">
        {comments.map((comment) => (
          <li className="rounded-card bg-inset p-4" key={comment.author}>
            <div className="flex flex-wrap items-center gap-2 text-xs">
              <span className="font-medium text-ink">{comment.author}</span>
              <span className="text-ink-3">示例用户</span>
              <time className="text-ink-3" dateTime={comment.date}>
                {comment.date}
              </time>
            </div>
            <p className="mt-2 text-13 leading-relaxed text-ink-2">{comment.text}</p>
          </li>
        ))}
      </ol>
      <form
        className="mt-5"
        onSubmit={(event) => {
          event.preventDefault();
          setNotice('评论发布待接入，内容未发布或保存。');
        }}
      >
        <label
          className="mb-2 block text-xs text-ink-2"
          htmlFor={materialTitle ? 'material-comment' : 'course-comment'}
        >
          {materialTitle ? `评价「${materialTitle}」` : `参与「${courseName}」的讨论`}
        </label>
        <Textarea
          id={materialTitle ? 'material-comment' : 'course-comment'}
          required
          value={text}
          onChange={(event) => {
            setText(event.target.value);
            setNotice('');
          }}
          placeholder="写下你的评价、问题或补充…"
        />
        <div className="mt-3 flex flex-wrap items-center justify-between gap-3">
          <p className="text-xs text-ink-3">发布与保存待接入</p>
          <Button type="submit" size="sm" disabled={!text.trim()}>
            提交评论（待接入）
          </Button>
        </div>
        {notice && (
          <p role="status" className="mt-3 rounded-control bg-inset p-3 text-13 text-ink-2">
            {notice}
          </p>
        )}
      </form>
    </section>
  );
}
