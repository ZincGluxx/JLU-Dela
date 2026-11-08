import { useEffect, useMemo, useState } from 'react';
import { AlertDialog, Dialog } from 'radix-ui';
import {
  Building2,
  Compass,
  ExternalLink,
  Info,
  MapPin,
  PencilLine,
  Plus,
  RefreshCw,
  Search,
  Send,
} from 'lucide-react';
import {
  departmentsWithOffices,
  buildingsByCampus,
  campusNameOf,
  locateConsent,
  officeRelations,
  officeSourceHint,
  officesInBuilding,
  placesTabs,
  servicesByCategory,
  type PlacesTab,
} from './places-view-model';
import { requestPosition, type LocatedPosition } from './places-locate';
import {
  distanceMeters,
  formatDistance,
  formatOfficeLocation,
  mapLinkFor,
  placeKindLabels,
  placeServiceCategories,
  placeServiceCategoryLabels,
  searchPlaces,
  type PlaceBuilding,
  type PlaceOffice,
  type PlacesSnapshot,
  type PlaceSearchQuery,
} from '../../../shared/places';
import { Button } from '../../components/ui/button';
import { Input } from '../../components/ui/input';
import { Textarea } from '../../components/ui/textarea';
import { SegmentedControl } from '../../components/ui/beautifului/atoms/SegmentedControl';
import { dialogOverlay, dialogPanel } from '../../components/ui/motion';
import { cn } from '../../lib/utils';
import { errorText } from '../../workspace/store';

const kindOptions = ['', ...Object.keys(placeKindLabels)] as const;

export function PlacesView({
  api = window.dela?.places,
}: {
  api?: NonNullable<typeof window.dela>['places'];
}) {
  const [snapshot, setSnapshot] = useState<PlacesSnapshot | null>(null);
  const [tab, setTab] = useState<PlacesTab>('search');
  const [text, setText] = useState('');
  const [campusId, setCampusId] = useState('');
  const [kind, setKind] = useState('');
  const [departmentId, setDepartmentId] = useState('');
  const [serviceCategory, setServiceCategory] = useState('');
  const [selectedOfficeId, setSelectedOfficeId] = useState<string | null>(null);
  const [selectedBuildingId, setSelectedBuildingId] = useState<string | null>(null);
  const [selectedDepartmentId, setSelectedDepartmentId] = useState<string | null>(null);
  const [position, setPosition] = useState<LocatedPosition | null>(null);
  const [locateOpen, setLocateOpen] = useState(false);
  const [editorOpen, setEditorOpen] = useState(false);
  const [editingOffice, setEditingOffice] = useState<PlaceOffice | null>(null);
  const [correctionOpen, setCorrectionOpen] = useState(false);
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

  const query: PlaceSearchQuery = {
    text,
    campusId: campusId as PlaceSearchQuery['campusId'],
    kind: kind as PlaceSearchQuery['kind'],
    departmentId,
    serviceCategory: serviceCategory as PlaceSearchQuery['serviceCategory'],
  };
  const hits = useMemo(
    () => (snapshot ? searchPlaces(snapshot, query) : []),
    // query 由原始状态派生，依赖原始值避免每次渲染新建对象导致重复计算。
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [snapshot, text, campusId, kind, departmentId, serviceCategory],
  );
  const selectedOffice =
    snapshot?.offices.find((row) => row.id === selectedOfficeId) ??
    (hits[0]?.officeId
      ? snapshot?.offices.find((row) => row.id === hits[0]!.officeId)
      : undefined) ??
    null;
  const selectedBuilding =
    snapshot?.buildings.find(
      (row) => row.id === (selectedBuildingId ?? selectedOffice?.buildingId),
    ) ?? null;
  const campusGroups = useMemo(() => (snapshot ? buildingsByCampus(snapshot) : []), [snapshot]);
  const departmentGroups = useMemo(
    () => (snapshot ? departmentsWithOffices(snapshot) : []),
    [snapshot],
  );
  const serviceGroups = useMemo(() => (snapshot ? servicesByCategory(snapshot) : []), [snapshot]);
  const myCorrections = snapshot?.corrections ?? [];

  async function apply(next: Promise<PlacesSnapshot>, message: string) {
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

  async function locate() {
    setLocateOpen(false);
    const value = await requestPosition(navigator.geolocation);
    setPosition(value);
    if (value.simulated)
      setNotice(`未取得本机定位（${value.error ?? '未知原因'}），距离按示例位置估算。`);
    else setNotice('已按本机定位估算距离；室内定位可能有偏差。');
  }

  function openMap(office: PlaceOffice) {
    if (!snapshot) return;
    const link = mapLinkFor(snapshot, office);
    void window.dela?.workspace
      .openLink(link.url)
      .catch((cause: unknown) => setError(errorText(cause)));
  }

  if (!api)
    return (
      <div className="min-h-0 flex-1 overflow-y-auto bg-surface p-10">
        <p className="text-13 text-ink-3">校园地图只在桌面应用中可用。</p>
      </div>
    );

  return (
    <div className="min-h-0 flex-1 overflow-y-auto bg-surface">
      <div className="mx-auto grid w-full max-w-6xl gap-5 px-6 py-8 md:px-10">
        <header className="flex flex-wrap items-start justify-between gap-3">
          <div className="min-w-0">
            <div className="flex items-center gap-2">
              <MapPin className="size-5 text-ink-3" />
              <h1 className="text-xl font-semibold text-ink">校园地图与办事地点</h1>
            </div>
            <p className="mt-1 text-xs leading-relaxed text-ink-3">
              查校区、楼宇、院系、老师和办事窗口；按老师、部门或事项都能找到具体房间。
            </p>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <Button
              size="sm"
              variant={position ? 'secondary' : 'outline'}
              aria-pressed={Boolean(position)}
              onClick={() => (position ? setPosition(null) : setLocateOpen(true))}
            >
              <Compass className="size-4" />
              {position ? '定位已开启' : '开启定位'}
            </Button>
            <Button
              size="sm"
              variant="ghost"
              disabled={busy}
              onClick={() => void apply(api.regenerateDemo(), '已重新生成示例内容。')}
            >
              <RefreshCw className={busy ? 'size-4 animate-spin' : 'size-4'} />
              重新生成示例内容
            </Button>
          </div>
        </header>

        <p className="rounded-control bg-field px-3 py-2 text-xs leading-relaxed text-ink-2">
          <Info className="mr-1 inline size-3.5 align-[-2px]" />
          当前为骨架版本：楼宇、办公室与办事流程均为 AI
          模拟的示例内容，请以学校官方通知为准。同学上报的地点会标记来源，纠错会保存在本机等待处理。
        </p>
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
        {position?.simulated && (
          <p className="text-xs text-orange">
            当前使用示例位置估算距离；点「定位已开启」可关闭，或在系统设置中允许定位后重试。
          </p>
        )}

        <div className="grid gap-3">
          <div className="flex flex-wrap items-center gap-2">
            <SegmentedControl
              options={placesTabs.map((item) => item.id)}
              labels={
                Object.fromEntries(placesTabs.map((item) => [item.id, item.label])) as Record<
                  PlacesTab,
                  string
                >
              }
              value={tab}
              onChange={setTab}
            />
            <div className="relative min-w-0 flex-1">
              <Search className="absolute left-3 top-2 size-4 text-ink-3" />
              <Input
                aria-label="搜索地点、老师或办事事项"
                placeholder="搜索老师、部门、办事事项或房间号"
                value={text}
                onChange={(event) => setText(event.target.value)}
                className="pl-9"
              />
            </div>
          </div>
          <div className="flex flex-wrap gap-2">
            <select
              aria-label="筛选校区"
              className="rounded-control bg-field px-3 py-1.5 text-13 text-ink"
              value={campusId}
              onChange={(event) => setCampusId(event.target.value)}
            >
              <option value="">全部校区</option>
              {(snapshot?.campuses ?? []).map((campus) => (
                <option key={campus.id} value={campus.id}>
                  {campus.name}
                </option>
              ))}
            </select>
            <select
              aria-label="筛选地点类型"
              className="rounded-control bg-field px-3 py-1.5 text-13 text-ink"
              value={kind}
              onChange={(event) => setKind(event.target.value)}
            >
              <option value="">全部类型</option>
              {kindOptions
                .filter((value) => value)
                .map((value) => (
                  <option key={value} value={value}>
                    {placeKindLabels[value as keyof typeof placeKindLabels]}
                  </option>
                ))}
            </select>
            <select
              aria-label="筛选院系"
              className="rounded-control bg-field px-3 py-1.5 text-13 text-ink"
              value={departmentId}
              onChange={(event) => setDepartmentId(event.target.value)}
            >
              <option value="">全部院系</option>
              {(snapshot?.departments ?? []).map((department) => (
                <option key={department.id} value={department.id}>
                  {department.name}
                </option>
              ))}
            </select>
            <select
              aria-label="筛选事项分类"
              className="rounded-control bg-field px-3 py-1.5 text-13 text-ink"
              value={serviceCategory}
              onChange={(event) => setServiceCategory(event.target.value)}
            >
              <option value="">全部事项</option>
              {placeServiceCategories.map((category) => (
                <option key={category} value={category}>
                  {placeServiceCategoryLabels[category]}
                </option>
              ))}
            </select>
          </div>
        </div>

        <div className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.1fr)]">
          <div className="grid content-start gap-2">
            {!snapshot && <p className="py-10 text-center text-13 text-ink-3">正在读取地点数据…</p>}
            {snapshot && tab === 'search' && (
              <section aria-label="检索结果" className="grid gap-2">
                <p className="text-xs text-ink-3">找到 {hits.length} 条结果</p>
                {hits.map((hit) => (
                  <button
                    key={`${hit.kind}:${hit.id}`}
                    type="button"
                    disabled={!hit.officeId}
                    onClick={() => {
                      setSelectedOfficeId(hit.officeId ?? null);
                      setSelectedBuildingId(null);
                    }}
                    className={cn(
                      'grid gap-1 rounded-control bg-field p-3 text-left hover:bg-hover disabled:opacity-50',
                      selectedOffice?.id === hit.officeId && 'ring-1 ring-bui-accent',
                    )}
                  >
                    <span className="flex flex-wrap items-center gap-2">
                      <span className="text-sm font-medium text-ink">{hit.title}</span>
                      <span className="rounded-chip bg-inset px-1.5 py-0.5 text-2xs text-ink-3">
                        {hit.kind === 'office'
                          ? '地点'
                          : hit.kind === 'teacher'
                            ? '老师'
                            : hit.kind === 'service'
                              ? '事项'
                              : '院系'}
                      </span>
                    </span>
                    <span className="text-xs text-ink-3">{hit.subtitle}</span>
                  </button>
                ))}
                {!hits.length && (
                  <p className="py-8 text-center text-13 text-ink-3">
                    没有匹配的地点。可以换个关键词，或到「按楼宇」里逐栋查看。
                  </p>
                )}
              </section>
            )}
            {snapshot && tab === 'building' && (
              <section aria-label="按楼宇浏览" className="grid gap-3">
                {campusGroups.map((group) => (
                  <div key={group.campus.id} className="grid gap-1.5">
                    <h2 className="text-xs font-medium text-ink-2">{group.campus.name}</h2>
                    {group.buildings.map((building) => (
                      <BuildingRow
                        key={building.id}
                        building={building}
                        snapshot={snapshot}
                        active={selectedBuilding?.id === building.id}
                        onSelect={() => {
                          setSelectedBuildingId(building.id);
                          const first = officesInBuilding(snapshot, building.id)[0];
                          setSelectedOfficeId(first?.id ?? null);
                        }}
                      />
                    ))}
                  </div>
                ))}
              </section>
            )}
            {snapshot && tab === 'people' && (
              <section aria-label="院系与老师" className="grid gap-2">
                {departmentGroups.map(({ department, offices: list }) => (
                  <div key={department.id} className="grid gap-1">
                    <button
                      type="button"
                      className={cn(
                        'flex flex-wrap items-center justify-between gap-2 rounded-control bg-field p-3 text-left hover:bg-hover',
                        selectedDepartmentId === department.id && 'ring-1 ring-bui-accent',
                      )}
                      onClick={() => {
                        setSelectedDepartmentId(department.id);
                        setSelectedOfficeId(list[0]?.id ?? null);
                      }}
                    >
                      <span className="text-sm font-medium text-ink">{department.name}</span>
                      <span className="text-xs text-ink-3">
                        {department.category} · {list.length} 个地点
                      </span>
                    </button>
                    {selectedDepartmentId === department.id &&
                      list.map((office) => (
                        <button
                          key={office.id}
                          type="button"
                          onClick={() => setSelectedOfficeId(office.id)}
                          className={cn(
                            'ml-3 flex flex-wrap items-center justify-between gap-2 rounded-control px-3 py-2 text-left hover:bg-hover',
                            selectedOffice?.id === office.id && 'bg-hover-2',
                          )}
                        >
                          <span className="text-13 text-ink">{office.name}</span>
                          <span className="text-xs text-ink-3">
                            {formatOfficeLocation(snapshot, office)}
                          </span>
                        </button>
                      ))}
                  </div>
                ))}
              </section>
            )}
            {snapshot && tab === 'service' && (
              <section aria-label="办事事项" className="grid gap-3">
                {serviceGroups.map((group) => (
                  <div key={group.category} className="grid gap-1.5">
                    <h2 className="text-xs font-medium text-ink-2">
                      {placeServiceCategoryLabels[group.category]}
                    </h2>
                    {group.services.map((service) => (
                      <button
                        key={service.id}
                        type="button"
                        onClick={() => {
                          setSelectedOfficeId(service.officeId);
                          setSelectedBuildingId(null);
                        }}
                        className={cn(
                          'grid gap-1 rounded-control bg-field p-3 text-left hover:bg-hover',
                          selectedOffice?.id === service.officeId && 'ring-1 ring-bui-accent',
                        )}
                      >
                        <span className="text-sm font-medium text-ink">{service.name}</span>
                        <span className="text-xs text-ink-3">{service.materials.join('、')}</span>
                      </button>
                    ))}
                  </div>
                ))}
              </section>
            )}
          </div>

          <div className="grid content-start gap-3">
            {snapshot && selectedOffice && (
              <OfficeDetail
                snapshot={snapshot}
                office={selectedOffice}
                position={position}
                busy={busy}
                onMap={() => openMap(selectedOffice)}
                onEdit={() => {
                  setEditingOffice(selectedOffice);
                  setEditorOpen(true);
                }}
                onCorrect={() => setCorrectionOpen(true)}
                onOpenOffice={setSelectedOfficeId}
              />
            )}
            {snapshot && !selectedOffice && (
              <p className="rounded-control bg-field p-6 text-13 text-ink-3">
                左侧选择一栋楼、一个院系或一条办事事项，这里会显示楼层房间、办公时间与关联人员。
              </p>
            )}
            {snapshot && (
              <Button
                size="sm"
                variant="outline"
                className="justify-self-start"
                onClick={() => {
                  setEditingOffice(null);
                  setEditorOpen(true);
                }}
              >
                <Plus className="size-4" />
                补充一个地点
              </Button>
            )}
            {myCorrections.length > 0 && (
              <section aria-label="我的纠错记录" className="grid gap-2">
                <h2 className="text-xs font-medium text-ink-2">纠错与更新记录</h2>
                {myCorrections.slice(0, 6).map((correction) => (
                  <article key={correction.id} className="grid gap-1 rounded-control bg-field p-3">
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <span className="text-13 font-medium text-ink">{correction.targetName}</span>
                      <span className="text-xs text-ink-3">
                        {correction.status === 'pending'
                          ? '待处理'
                          : correction.status === 'accepted'
                            ? '已采纳'
                            : '未采纳'}
                      </span>
                    </div>
                    <p className="text-xs text-ink-2">{correction.message}</p>
                    <div className="flex flex-wrap gap-2">
                      {correction.status === 'pending' && (
                        <>
                          <Button
                            size="sm"
                            variant="ghost"
                            disabled={busy}
                            onClick={() =>
                              void apply(
                                api.reviewCorrection(correction.id, 'accepted'),
                                '已标记为采纳；地点信息更新仍待人工核对。',
                              )
                            }
                          >
                            标记采纳
                          </Button>
                          <Button
                            size="sm"
                            variant="ghost"
                            disabled={busy}
                            onClick={() =>
                              void apply(
                                api.reviewCorrection(correction.id, 'rejected'),
                                '已标记为未采纳。',
                              )
                            }
                          >
                            标记未采纳
                          </Button>
                        </>
                      )}
                    </div>
                  </article>
                ))}
              </section>
            )}
          </div>
        </div>
      </div>

      <AlertDialog.Root open={locateOpen} onOpenChange={setLocateOpen}>
        <AlertDialog.Portal>
          <AlertDialog.Overlay className={dialogOverlay} />
          <AlertDialog.Content className={cn(dialogPanel, 'max-w-md')}>
            <AlertDialog.Title className="text-base font-semibold">
              {locateConsent.title}
            </AlertDialog.Title>
            <AlertDialog.Description className="mt-2 text-xs leading-relaxed text-ink-3">
              {locateConsent.description}
            </AlertDialog.Description>
            <div className="mt-4 flex justify-end gap-2">
              <AlertDialog.Cancel asChild>
                <Button size="sm" variant="ghost">
                  {locateConsent.cancel}
                </Button>
              </AlertDialog.Cancel>
              <AlertDialog.Action asChild>
                <Button size="sm" onClick={() => void locate()}>
                  {locateConsent.accept}
                </Button>
              </AlertDialog.Action>
            </div>
          </AlertDialog.Content>
        </AlertDialog.Portal>
      </AlertDialog.Root>

      {snapshot && (
        <OfficeEditor
          open={editorOpen}
          snapshot={snapshot}
          office={editingOffice}
          busy={busy}
          onOpenChange={setEditorOpen}
          onSubmit={(input) =>
            void apply(
              api.saveOffice(input),
              editingOffice
                ? '地点已更新，标记为同学上报待核实。'
                : '已添加地点，标记为同学上报待核实。',
            ).then(() => setEditorOpen(false))
          }
        />
      )}

      {snapshot && selectedOffice && (
        <CorrectionDialog
          open={correctionOpen}
          office={selectedOffice}
          busy={busy}
          onOpenChange={setCorrectionOpen}
          onSubmit={(message, contact) =>
            void apply(
              api.submitCorrection({
                target: 'office',
                targetId: selectedOffice.id,
                targetName: selectedOffice.name,
                message,
                ...(contact ? { contact } : {}),
              }),
              '纠错已记录，处理结果会显示在「纠错与更新记录」里。',
            ).then(() => setCorrectionOpen(false))
          }
        />
      )}
    </div>
  );
}

function BuildingRow({
  building,
  snapshot,
  active,
  onSelect,
}: {
  building: PlaceBuilding;
  snapshot: PlacesSnapshot;
  active: boolean;
  onSelect: () => void;
}) {
  const count = officesInBuilding(snapshot, building.id).length;
  return (
    <button
      type="button"
      onClick={onSelect}
      className={cn(
        'flex flex-wrap items-center justify-between gap-2 rounded-control bg-field p-3 text-left hover:bg-hover',
        active && 'ring-1 ring-bui-accent',
      )}
    >
      <span className="flex items-center gap-2">
        <Building2 className="size-4 text-ink-3" />
        <span className="text-sm font-medium text-ink">{building.name}</span>
        {building.alias && <span className="text-xs text-ink-3">（{building.alias}）</span>}
      </span>
      <span className="text-xs text-ink-3">
        {count} 个地点 · {building.floors} 层
      </span>
    </button>
  );
}

function OfficeDetail({
  snapshot,
  office,
  position,
  busy,
  onMap,
  onEdit,
  onCorrect,
  onOpenOffice,
}: {
  snapshot: PlacesSnapshot;
  office: PlaceOffice;
  position: LocatedPosition | null;
  busy: boolean;
  onMap: () => void;
  onEdit: () => void;
  onCorrect: () => void;
  onOpenOffice: (id: string) => void;
}) {
  const relations = officeRelations(snapshot, office);
  const building = snapshot.buildings.find((row) => row.id === office.buildingId);
  const distance = position
    ? distanceMeters(position.coordinate, office.coordinate ?? building?.coordinate)
    : null;
  return (
    <section aria-label="地点详情" className="grid gap-3 rounded-card bg-field p-4">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div className="min-w-0">
          <h2 className="break-words text-base font-semibold text-ink">{office.name}</h2>
          <p className="mt-1 text-xs text-ink-2">
            {formatOfficeLocation(snapshot, office)}
            {building ? ` · ${building.name}` : ''}
          </p>
        </div>
        <span className="rounded-chip bg-inset px-2 py-0.5 text-2xs text-ink-3">
          {officeSourceHint(office)}
        </span>
      </div>
      <dl className="grid gap-1.5 text-13 text-ink-2">
        <div className="flex flex-wrap gap-2">
          <dt className="text-ink-3">类型</dt>
          <dd>{placeKindLabels[office.kind]}</dd>
        </div>
        {office.hours && (
          <div className="flex flex-wrap gap-2">
            <dt className="text-ink-3">办公时间</dt>
            <dd>{office.hours}</dd>
          </div>
        )}
        {office.phone && (
          <div className="flex flex-wrap gap-2">
            <dt className="text-ink-3">电话</dt>
            <dd>{office.phone}</dd>
          </div>
        )}
        {relations.departments.length > 0 && (
          <div className="flex flex-wrap gap-2">
            <dt className="text-ink-3">所属</dt>
            <dd>{relations.departments.map((row) => row.name).join('、')}</dd>
          </div>
        )}
        {position && (
          <div className="flex flex-wrap gap-2">
            <dt className="text-ink-3">距离</dt>
            <dd>
              {formatDistance(distance)}
              {position.simulated ? '（示例位置）' : ''}
            </dd>
          </div>
        )}
        {office.note && (
          <div className="flex flex-wrap gap-2">
            <dt className="text-ink-3">说明</dt>
            <dd className="break-words">{office.note}</dd>
          </div>
        )}
      </dl>
      {relations.teachers.length > 0 && (
        <div className="grid gap-1">
          <h3 className="text-xs font-medium text-ink-2">在这里的老师</h3>
          <div className="flex flex-wrap gap-1.5">
            {relations.teachers.map((teacher) => (
              <span
                key={teacher.id}
                className="rounded-chip bg-surface px-2 py-1 text-xs text-ink-2"
                title={teacher.officeHours ?? ''}
              >
                {teacher.name}
                {teacher.title ? ` · ${teacher.title}` : ''}
              </span>
            ))}
          </div>
        </div>
      )}
      {relations.services.length > 0 && (
        <div className="grid gap-2">
          <h3 className="text-xs font-medium text-ink-2">可以在这里办理</h3>
          {relations.services.map((service) => (
            <article key={service.id} className="grid gap-1 rounded-control bg-surface p-3">
              <p className="text-13 font-medium text-ink">
                {service.name}
                <span className="ml-2 text-2xs text-ink-3">
                  {placeServiceCategoryLabels[service.category]}
                </span>
              </p>
              <ol className="grid list-decimal gap-0.5 pl-4 text-xs text-ink-2">
                {service.steps.map((step) => (
                  <li key={step}>{step}</li>
                ))}
              </ol>
              <p className="text-xs text-ink-3">
                需要：{service.materials.join('、') || '以窗口要求为准'}
              </p>
              {service.note && <p className="text-2xs text-ink-3">{service.note}</p>}
            </article>
          ))}
        </div>
      )}
      <div className="flex flex-wrap gap-2">
        <Button size="sm" onClick={onMap}>
          <ExternalLink className="size-3.5" />
          在地图中导航
        </Button>
        <Button size="sm" variant="outline" disabled={busy} onClick={onEdit}>
          <PencilLine className="size-3.5" />
          更新信息
        </Button>
        <Button size="sm" variant="ghost" disabled={busy} onClick={onCorrect}>
          <Send className="size-3.5" />
          报错 / 纠错
        </Button>
        {relations.departments[0] && (
          <Button
            size="sm"
            variant="ghost"
            onClick={() => {
              const sibling = snapshot.offices.find((row) =>
                row.departmentIds.includes(relations.departments[0]!.id),
              );
              if (sibling) onOpenOffice(sibling.id);
            }}
          >
            查看该院系其他地点
          </Button>
        )}
      </div>
      <p className="text-2xs leading-relaxed text-ink-3">
        数据核对于 {new Date(office.updatedAt).toLocaleString('zh-CN')}
        {office.verifiedAt
          ? ` · 核实于 ${office.verifiedAt}`
          : ` · 尚未人工核实（${campusNameOf(snapshot, building?.campusId ?? '')}）`}
      </p>
    </section>
  );
}

function OfficeEditor({
  open,
  snapshot,
  office,
  busy,
  onOpenChange,
  onSubmit,
}: {
  open: boolean;
  snapshot: PlacesSnapshot;
  office: PlaceOffice | null;
  busy: boolean;
  onOpenChange: (open: boolean) => void;
  onSubmit: (input: {
    id?: string;
    buildingId: string;
    floor: string;
    room: string;
    name: string;
    kind: PlaceOffice['kind'];
    departmentIds: string[];
    hours?: string;
    phone?: string;
    note?: string;
  }) => void;
}) {
  const [buildingId, setBuildingId] = useState(
    office?.buildingId ?? snapshot.buildings[0]?.id ?? '',
  );
  const [floor, setFloor] = useState(office?.floor ?? '');
  const [room, setRoom] = useState(office?.room ?? '');
  const [name, setName] = useState(office?.name ?? '');
  const [kind, setKind] = useState<PlaceOffice['kind']>(office?.kind ?? 'office');
  const [departmentId, setDepartmentId] = useState(office?.departmentIds[0] ?? '');
  const [hours, setHours] = useState(office?.hours ?? '');
  const [phone, setPhone] = useState(office?.phone ?? '');
  const [note, setNote] = useState(office?.note ?? '');

  useEffect(() => {
    if (!open) return;
    setBuildingId(office?.buildingId ?? snapshot.buildings[0]?.id ?? '');
    setFloor(office?.floor ?? '');
    setRoom(office?.room ?? '');
    setName(office?.name ?? '');
    setKind(office?.kind ?? 'office');
    setDepartmentId(office?.departmentIds[0] ?? '');
    setHours(office?.hours ?? '');
    setPhone(office?.phone ?? '');
    setNote(office?.note ?? '');
  }, [open, office, snapshot.buildings]);

  return (
    <Dialog.Root open={open} onOpenChange={onOpenChange}>
      <Dialog.Portal>
        <Dialog.Overlay className={dialogOverlay} />
        <Dialog.Content className={cn(dialogPanel, 'max-h-[85vh] max-w-lg overflow-y-auto')}>
          <Dialog.Title className="text-base font-semibold">
            {office ? '更新地点信息' : '补充一个地点'}
          </Dialog.Title>
          <Dialog.Description className="mt-1 text-xs text-ink-3">
            提交后标记为「同学上报 · 待核实」，方便后续与学院或部门核对。
          </Dialog.Description>
          <div className="mt-4 grid gap-3">
            <label className="grid gap-1 text-13 text-ink-2">
              楼宇
              <select
                aria-label="选择楼宇"
                className="rounded-control bg-field px-3 py-2 text-13 text-ink"
                value={buildingId}
                onChange={(event) => setBuildingId(event.target.value)}
              >
                {snapshot.buildings.map((building) => (
                  <option key={building.id} value={building.id}>
                    {campusNameOf(snapshot, building.campusId)} · {building.name}
                  </option>
                ))}
              </select>
            </label>
            <div className="grid gap-3 sm:grid-cols-2">
              <label className="grid gap-1 text-13 text-ink-2">
                楼层
                <Input
                  aria-label="楼层"
                  placeholder="如 4 层"
                  value={floor}
                  onChange={(event) => setFloor(event.target.value)}
                />
              </label>
              <label className="grid gap-1 text-13 text-ink-2">
                房间
                <Input
                  aria-label="房间"
                  placeholder="如 A 区 412"
                  value={room}
                  onChange={(event) => setRoom(event.target.value)}
                />
              </label>
            </div>
            <label className="grid gap-1 text-13 text-ink-2">
              地点名称
              <Input
                aria-label="地点名称"
                placeholder="如 计算机学院本科教务办公室"
                value={name}
                onChange={(event) => setName(event.target.value)}
              />
            </label>
            <div className="grid gap-3 sm:grid-cols-2">
              <label className="grid gap-1 text-13 text-ink-2">
                类型
                <select
                  aria-label="地点类型"
                  className="rounded-control bg-field px-3 py-2 text-13 text-ink"
                  value={kind}
                  onChange={(event) => setKind(event.target.value as PlaceOffice['kind'])}
                >
                  {(Object.keys(placeKindLabels) as PlaceOffice['kind'][]).map((value) => (
                    <option key={value} value={value}>
                      {placeKindLabels[value]}
                    </option>
                  ))}
                </select>
              </label>
              <label className="grid gap-1 text-13 text-ink-2">
                所属单位
                <select
                  aria-label="所属单位"
                  className="rounded-control bg-field px-3 py-2 text-13 text-ink"
                  value={departmentId}
                  onChange={(event) => setDepartmentId(event.target.value)}
                >
                  <option value="">暂不指定</option>
                  {snapshot.departments.map((department) => (
                    <option key={department.id} value={department.id}>
                      {department.name}
                    </option>
                  ))}
                </select>
              </label>
            </div>
            <div className="grid gap-3 sm:grid-cols-2">
              <label className="grid gap-1 text-13 text-ink-2">
                办公时间
                <Input
                  aria-label="办公时间"
                  placeholder="如 工作日 08:30–11:30"
                  value={hours}
                  onChange={(event) => setHours(event.target.value)}
                />
              </label>
              <label className="grid gap-1 text-13 text-ink-2">
                电话
                <Input
                  aria-label="电话"
                  placeholder="选填"
                  value={phone}
                  onChange={(event) => setPhone(event.target.value)}
                />
              </label>
            </div>
            <label className="grid gap-1 text-13 text-ink-2">
              说明
              <Textarea
                aria-label="说明"
                rows={2}
                placeholder="办理提示、入口位置等"
                value={note}
                onChange={(event) => setNote(event.target.value)}
              />
            </label>
          </div>
          <div className="mt-5 flex justify-end gap-2">
            <Dialog.Close asChild>
              <Button size="sm" variant="ghost">
                取消
              </Button>
            </Dialog.Close>
            <Button
              size="sm"
              disabled={busy || name.trim().length < 2 || !buildingId}
              onClick={() =>
                onSubmit({
                  ...(office ? { id: office.id } : {}),
                  buildingId,
                  floor,
                  room,
                  name,
                  kind,
                  departmentIds: departmentId ? [departmentId] : [],
                  ...(hours.trim() ? { hours } : {}),
                  ...(phone.trim() ? { phone } : {}),
                  ...(note.trim() ? { note } : {}),
                })
              }
            >
              保存
            </Button>
          </div>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  );
}

function CorrectionDialog({
  open,
  office,
  busy,
  onOpenChange,
  onSubmit,
}: {
  open: boolean;
  office: PlaceOffice;
  busy: boolean;
  onOpenChange: (open: boolean) => void;
  onSubmit: (message: string, contact: string) => void;
}) {
  const [message, setMessage] = useState('');
  const [contact, setContact] = useState('');
  useEffect(() => {
    if (open) {
      setMessage('');
      setContact('');
    }
  }, [open]);
  return (
    <Dialog.Root open={open} onOpenChange={onOpenChange}>
      <Dialog.Portal>
        <Dialog.Overlay className={dialogOverlay} />
        <Dialog.Content className={cn(dialogPanel, 'max-w-md')}>
          <Dialog.Title className="text-base font-semibold">纠错：{office.name}</Dialog.Title>
          <Dialog.Description className="mt-1 text-xs text-ink-3">
            写清楚哪里不对（房间号、办公时间、负责事项等），记录只保存在本机，接入服务后会上报给维护同学。
          </Dialog.Description>
          <div className="mt-4 grid gap-3">
            <label className="grid gap-1 text-13 text-ink-2">
              问题描述
              <Textarea
                aria-label="纠错说明"
                rows={3}
                placeholder="如：搬到 A 区 418，办公时间改为下午"
                value={message}
                onChange={(event) => setMessage(event.target.value)}
              />
            </label>
            <label className="grid gap-1 text-13 text-ink-2">
              联系方式（选填）
              <Input
                aria-label="联系方式"
                placeholder="便于核实时联系"
                value={contact}
                onChange={(event) => setContact(event.target.value)}
              />
            </label>
          </div>
          <div className="mt-5 flex justify-end gap-2">
            <Dialog.Close asChild>
              <Button size="sm" variant="ghost">
                取消
              </Button>
            </Dialog.Close>
            <Button
              size="sm"
              disabled={busy || message.trim().length < 4}
              onClick={() => onSubmit(message.trim(), contact.trim())}
            >
              提交纠错
            </Button>
          </div>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  );
}
