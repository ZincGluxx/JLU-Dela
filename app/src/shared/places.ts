// 校园地图与办事地点：数据模型、检索与文案的单一真源。
// 本版为骨架：内容由 AI 模拟填充（source='demo'），同学上报与官方数据留待后续接入。

export type PlaceCampusId =
  'qianwei-south' | 'qianwei-north' | 'nanling' | 'xinmin' | 'zhaoyang' | 'nanhu' | 'heping';

export interface PlaceCampus {
  id: PlaceCampusId;
  name: string;
  address: string;
}

export interface PlaceBuilding {
  id: string;
  campusId: PlaceCampusId;
  name: string;
  /** 楼宇简称或工程编号，便于按名字检索。 */
  alias?: string;
  floors: number;
  /** 楼宇中心点，用于距离估算与外部地图跳转。 */
  coordinate: PlaceCoordinate;
  note?: string;
}

export interface PlaceCoordinate {
  latitude: number;
  longitude: number;
}

export type PlaceKind = 'office' | 'service' | 'teaching' | 'lab' | 'library' | 'canteen' | 'other';

export type PlaceSource = 'demo' | 'user' | 'official';

export interface PlaceDepartment {
  id: string;
  name: string;
  category: '学院' | '行政' | '后勤' | '其他';
  buildingId: string;
  /** 院系联系电话留空表示暂未收集。 */
  phone?: string;
}

/** 楼宇内的办公室 / 办事窗口；办事事项与老师都挂在这里。 */
export interface PlaceOffice {
  id: string;
  buildingId: string;
  floor: string;
  room: string;
  name: string;
  kind: PlaceKind;
  departmentIds: string[];
  serviceIds: string[];
  teacherIds: string[];
  hours?: string;
  phone?: string;
  note?: string;
  coordinate?: PlaceCoordinate;
  source: PlaceSource;
  /** 最近一次人工核实的日期；未核实为 null。 */
  verifiedAt: string | null;
  updatedAt: string;
}

export interface PlaceTeacher {
  id: string;
  name: string;
  title?: string;
  departmentId: string;
  officeId?: string;
  email?: string;
  officeHours?: string;
}

export type PlaceServiceCategory = '报销' | '证明' | '学籍' | '盖章' | '后勤' | '其他';

export interface PlaceService {
  id: string;
  name: string;
  category: PlaceServiceCategory;
  officeId: string;
  steps: string[];
  materials: string[];
  hours?: string;
  note?: string;
}

export type PlaceCorrectionTarget = 'office' | 'teacher' | 'service' | 'building';
export type PlaceCorrectionStatus = 'pending' | 'accepted' | 'rejected';

export interface PlaceCorrection {
  id: string;
  target: PlaceCorrectionTarget;
  targetId: string;
  targetName: string;
  message: string;
  contact?: string;
  status: PlaceCorrectionStatus;
  createdAt: string;
}

export interface PlacesSnapshot {
  version: number;
  generatedAt: string;
  campuses: PlaceCampus[];
  buildings: PlaceBuilding[];
  departments: PlaceDepartment[];
  offices: PlaceOffice[];
  teachers: PlaceTeacher[];
  services: PlaceService[];
  corrections: PlaceCorrection[];
}

/** 同学补充或修正办公室：新增时省略 id。 */
export interface PlaceOfficeInput {
  id?: string;
  buildingId: string;
  floor: string;
  room: string;
  name: string;
  kind: PlaceKind;
  departmentIds?: string[];
  hours?: string;
  phone?: string;
  note?: string;
}

export interface PlaceCorrectionInput {
  target: PlaceCorrectionTarget;
  targetId: string;
  /** 提交人看到的名称，便于在列表里直接阅读。 */
  targetName: string;
  message: string;
  contact?: string;
}

export interface PlacesApi {
  get(): Promise<PlacesSnapshot>;
  /** 服务端检索：与 searchPlaces 同源，避免两端规则漂移。 */
  search(query: PlaceSearchQuery): Promise<PlaceSearchHit[]>;
  saveOffice(input: PlaceOfficeInput): Promise<PlacesSnapshot>;
  submitCorrection(input: PlaceCorrectionInput): Promise<PlacesSnapshot>;
  reviewCorrection(id: string, status: PlaceCorrectionStatus): Promise<PlacesSnapshot>;
  /** 重新生成示例内容：保留同学上报的地点与纠错记录。 */
  regenerateDemo(): Promise<PlacesSnapshot>;
}

export const placeKindLabels: Record<PlaceKind, string> = {
  office: '办公室',
  service: '办事窗口',
  teaching: '教学楼',
  lab: '实验室',
  library: '图书馆',
  canteen: '食堂',
  other: '其他',
};

export const placeKinds = Object.keys(placeKindLabels) as PlaceKind[];

export const placeServiceCategories: [PlaceServiceCategory, ...PlaceServiceCategory[]] = [
  '报销',
  '证明',
  '学籍',
  '盖章',
  '后勤',
  '其他',
];

export const placeSourceLabels: Record<PlaceSource, string> = {
  demo: '示例数据',
  user: '同学上报',
  official: '官方',
};

export const placeServiceCategoryLabels: Record<PlaceServiceCategory, string> = {
  报销: '报销缴费',
  证明: '证明打印',
  学籍: '学籍教务',
  盖章: '盖章审批',
  后勤: '后勤报修',
  其他: '其他事务',
};

export const placeCorrectionStatusLabels: Record<PlaceCorrectionStatus, string> = {
  pending: '待处理',
  accepted: '已采纳',
  rejected: '未采纳',
};

/** 检索命中：同一份快照里可能同时命中办公室、老师、事项与院系。 */
export interface PlaceSearchHit {
  kind: 'office' | 'teacher' | 'service' | 'department';
  id: string;
  title: string;
  subtitle: string;
  /** 详情定位用的办公室 id；院系命中时为其主要办公室。 */
  officeId?: string;
  score: number;
  matched: string[];
}

export interface PlaceSearchQuery {
  text?: string;
  campusId?: PlaceCampusId | '';
  kind?: PlaceKind | '';
  departmentId?: string;
  serviceCategory?: PlaceServiceCategory | '';
}

export function placeBuildingOf(snapshot: PlacesSnapshot, officeId: string): PlaceBuilding | null {
  const office = snapshot.offices.find((row) => row.id === officeId);
  if (!office) return null;
  return snapshot.buildings.find((row) => row.id === office.buildingId) ?? null;
}

/** 办公室的展示位置：楼宇 · 层 · 房间。 */
export function formatOfficeLocation(
  snapshot: PlacesSnapshot,
  office: Pick<PlaceOffice, 'buildingId' | 'floor' | 'room'>,
): string {
  const building = snapshot.buildings.find((row) => row.id === office.buildingId);
  const campus = building
    ? snapshot.campuses.find((row) => row.id === building.campusId)
    : undefined;
  return [campus?.name, building?.name, office.floor, office.room]
    .filter((value): value is string => Boolean(value))
    .join(' · ');
}

export function departmentNamesOf(snapshot: PlacesSnapshot, office: PlaceOffice): string[] {
  return office.departmentIds
    .map((id) => snapshot.departments.find((row) => row.id === id)?.name)
    .filter((name): name is string => Boolean(name));
}

export function servicesOf(snapshot: PlacesSnapshot, office: PlaceOffice): PlaceService[] {
  return office.serviceIds
    .map((id) => snapshot.services.find((row) => row.id === id))
    .filter((row): row is PlaceService => Boolean(row));
}

export function teachersOf(snapshot: PlacesSnapshot, office: PlaceOffice): PlaceTeacher[] {
  return office.teacherIds
    .map((id) => snapshot.teachers.find((row) => row.id === id))
    .filter((row): row is PlaceTeacher => Boolean(row));
}

/** 办公室是否命中全部筛选条件（不含关键词）。 */
function officeMatchesFilters(
  snapshot: PlacesSnapshot,
  office: PlaceOffice,
  query: PlaceSearchQuery,
): boolean {
  if (query.kind && office.kind !== query.kind) return false;
  if (query.departmentId && !office.departmentIds.includes(query.departmentId)) return false;
  if (query.serviceCategory) {
    const hasCategory = servicesOf(snapshot, office).some(
      (service) => service.category === query.serviceCategory,
    );
    if (!hasCategory) return false;
  }
  if (query.campusId) {
    const building = snapshot.buildings.find((row) => row.id === office.buildingId);
    if (building?.campusId !== query.campusId) return false;
  }
  return true;
}

const normalize = (value: string) => value.trim().toLocaleLowerCase();

/** 关键词计分：标题完全匹配 > 前缀 > 包含；附带的说明文字按包含计分。 */
function scoreText(text: string, needle: string): number {
  const value = normalize(text);
  if (!needle) return 0;
  if (value === needle) return 6;
  if (value.startsWith(needle)) return 4;
  return value.includes(needle) ? 2 : 0;
}

/**
 * 跨类型检索：老师、事项、院系都能落到具体办公室。
 * 只做纯函数排序，调用方负责展示与二次筛选。
 */
export function searchPlaces(
  snapshot: PlacesSnapshot,
  query: PlaceSearchQuery = {},
): PlaceSearchHit[] {
  const needle = normalize(query.text ?? '');
  const hits: PlaceSearchHit[] = [];

  for (const office of snapshot.offices) {
    if (!officeMatchesFilters(snapshot, office, query)) continue;
    const location = formatOfficeLocation(snapshot, office);
    const departments = departmentNamesOf(snapshot, office);
    const services = servicesOf(snapshot, office).map((service) => service.name);
    const teachers = teachersOf(snapshot, office).map((teacher) => teacher.name);
    const haystack = [office.name, ...departments, ...services, ...teachers, office.note ?? ''];
    let score = scoreText(office.name, needle);
    const matched: string[] = [];
    for (const value of haystack.slice(1)) {
      const value2 = scoreText(value, needle);
      if (value2) {
        score += value2;
        matched.push(value);
      }
    }
    if (needle && !score) continue;
    hits.push({
      kind: 'office',
      id: office.id,
      title: office.name,
      subtitle: [location, departments.join('、')].filter(Boolean).join(' · '),
      officeId: office.id,
      score: score + 1,
      matched,
    });
  }

  if (needle) {
    for (const teacher of snapshot.teachers) {
      const score = scoreText(teacher.name, needle) + scoreText(teacher.title ?? '', needle);
      if (!score) continue;
      const office = snapshot.offices.find((row) => row.id === teacher.officeId);
      if (!office || !officeMatchesFilters(snapshot, office, query)) continue;
      hits.push({
        kind: 'teacher',
        id: teacher.id,
        title: teacher.name,
        subtitle: [
          teacher.title,
          snapshot.departments.find((row) => row.id === teacher.departmentId)?.name,
          formatOfficeLocation(snapshot, office),
        ]
          .filter((value): value is string => Boolean(value))
          .join(' · '),
        officeId: office.id,
        score,
        matched: [teacher.name],
      });
    }
    for (const service of snapshot.services) {
      if (query.serviceCategory && service.category !== query.serviceCategory) continue;
      const score =
        scoreText(service.name, needle) +
        scoreText(service.category, needle) +
        (service.materials.some((material) => normalize(material).includes(needle)) ? 1 : 0);
      if (!score) continue;
      const office = snapshot.offices.find((row) => row.id === service.officeId);
      if (!office || !officeMatchesFilters(snapshot, office, { ...query, serviceCategory: '' }))
        continue;
      hits.push({
        kind: 'service',
        id: service.id,
        title: service.name,
        subtitle: [service.category, formatOfficeLocation(snapshot, office)]
          .filter(Boolean)
          .join(' · '),
        officeId: office.id,
        score: score + 1,
        matched: [service.name],
      });
    }
    for (const department of snapshot.departments) {
      const score = scoreText(department.name, needle) + scoreText(department.category, needle);
      if (!score) continue;
      const office = snapshot.offices.find((row) => row.departmentIds.includes(department.id));
      if (!office || !officeMatchesFilters(snapshot, office, query)) continue;
      hits.push({
        kind: 'department',
        id: department.id,
        title: department.name,
        subtitle: [department.category, formatOfficeLocation(snapshot, office)]
          .filter(Boolean)
          .join(' · '),
        officeId: office.id,
        score,
        matched: [department.name],
      });
    }
  }

  return hits.sort(
    (left, right) => right.score - left.score || left.title.localeCompare(right.title, 'zh-CN'),
  );
}

/** 距离（米），Haversine；坐标缺失时返回 null。 */
export function distanceMeters(
  from: PlaceCoordinate,
  to: PlaceCoordinate | undefined,
): number | null {
  if (!to) return null;
  const rad = (value: number) => (value * Math.PI) / 180;
  const earth = 6_371_000;
  const dLat = rad(to.latitude - from.latitude);
  const dLon = rad(to.longitude - from.longitude);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(rad(from.latitude)) * Math.cos(rad(to.latitude)) * Math.sin(dLon / 2) ** 2;
  return Math.round(2 * earth * Math.asin(Math.sqrt(a)));
}

/** 距离文案：1 km 内按米，超出按公里保留一位小数。 */
export function formatDistance(meters: number | null): string {
  if (meters === null) return '距离未知';
  if (meters < 1000) return `约 ${Math.max(10, Math.round(meters / 10) * 10)} 米`;
  return `约 ${(meters / 1000).toFixed(1)} 公里`;
}

/** 外部地图链接：优先高德，坐标为空时退回按名称搜索。 */
export function mapLinkFor(
  snapshot: PlacesSnapshot,
  office: PlaceOffice,
): { url: string; label: string } {
  const building = snapshot.buildings.find((row) => row.id === office.buildingId);
  const campus = building
    ? snapshot.campuses.find((row) => row.id === building.campusId)
    : undefined;
  const point = office.coordinate ?? building?.coordinate;
  const name = [campus?.name, building?.name, office.floor, office.room, office.name]
    .filter((value): value is string => Boolean(value))
    .join(' ');
  if (point)
    return {
      url: `https://uri.amap.com/marker?position=${point.longitude},${point.latitude}&name=${encodeURIComponent(name)}&src=dela&coordinate=gaode&callnative=1`,
      label: '在高德地图中导航',
    };
  return {
    url: `https://uri.amap.com/search?keyword=${encodeURIComponent(name)}&src=dela&callnative=1`,
    label: '在地图中搜索该地点',
  };
}
