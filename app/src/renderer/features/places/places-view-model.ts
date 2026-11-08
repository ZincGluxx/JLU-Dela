// 校园地图视图的纯装配逻辑：选项卡分组、楼宇/院系/事项的组织方式与定位权限话术。
import {
  placeServiceCategoryLabels,
  placeSourceLabels,
  servicesOf,
  teachersOf,
  type PlaceBuilding,
  type PlaceCampus,
  type PlaceCampusId,
  type PlaceDepartment,
  type PlaceOffice,
  type PlacesSnapshot,
  type PlaceService,
  type PlaceServiceCategory,
} from '../../../shared/places';

export type PlacesTab = 'search' | 'building' | 'people' | 'service';

export const placesTabs: readonly { id: PlacesTab; label: string }[] = [
  { id: 'search', label: '综合检索' },
  { id: 'building', label: '按楼宇' },
  { id: 'people', label: '院系与老师' },
  { id: 'service', label: '办事事项' },
];

export function campusNameOf(snapshot: PlacesSnapshot, campusId: PlaceCampusId | string): string {
  return snapshot.campuses.find((row) => row.id === campusId)?.name ?? '未知校区';
}

/** 按校区把楼宇分组，保持快照里的校区顺序。 */
export function buildingsByCampus(
  snapshot: PlacesSnapshot,
): { campus: PlaceCampus; buildings: PlaceBuilding[] }[] {
  return snapshot.campuses
    .map((campus) => ({
      campus,
      buildings: snapshot.buildings.filter((row) => row.campusId === campus.id),
    }))
    .filter((group) => group.buildings.length);
}

export function officesInBuilding(snapshot: PlacesSnapshot, buildingId: string): PlaceOffice[] {
  return snapshot.offices
    .filter((row) => row.buildingId === buildingId)
    .sort((left, right) => left.name.localeCompare(right.name, 'zh-CN'));
}

/** 院系分组：没有办公室的院系仍然列出，避免「查不到就是没有」。 */
export function departmentsWithOffices(
  snapshot: PlacesSnapshot,
): { department: PlaceDepartment; offices: PlaceOffice[] }[] {
  return snapshot.departments.map((department) => ({
    department,
    offices: snapshot.offices.filter((row) => row.departmentIds.includes(department.id)),
  }));
}

export function servicesByCategory(
  snapshot: PlacesSnapshot,
): { category: PlaceServiceCategory; services: PlaceService[] }[] {
  const categories = Object.keys(placeServiceCategoryLabels) as PlaceServiceCategory[];
  return categories
    .map((category) => ({
      category,
      services: snapshot.services.filter((row) => row.category === category),
    }))
    .filter((group) => group.services.length);
}

/** 办公室详情里的关联摘要：老师、事项、院系。 */
export function officeRelations(snapshot: PlacesSnapshot, office: PlaceOffice) {
  return {
    teachers: teachersOf(snapshot, office),
    services: servicesOf(snapshot, office),
    departments: office.departmentIds
      .map((id) => snapshot.departments.find((row) => row.id === id))
      .filter((row): row is PlaceDepartment => Boolean(row)),
  };
}

/** 数据可信度提示：示例数据与同学上报都要明确标注，避免被当成官方信息。 */
export function officeSourceHint(office: PlaceOffice): string {
  if (office.source === 'official') return placeSourceLabels.official;
  if (office.source === 'user') return `${placeSourceLabels.user} · 待核实`;
  return `${placeSourceLabels.demo} · 待同学核实`;
}

/** 定位说明文案：开启前必须让用户知道会用到什么。 */
export const locateConsent = {
  title: '开启定位以显示距离',
  description:
    '开启后 Dela 会用本机定位计算你到楼宇的大致距离，仅在本机计算、不上传位置。宿舍、教学楼等室内定位可能偏差较大，导航会交给系统地图应用。可随时关闭。',
  accept: '开启定位',
  cancel: '暂不开启',
} as const;

export function tabOfHit(kind: 'office' | 'teacher' | 'service' | 'department'): PlacesTab {
  if (kind === 'service') return 'service';
  if (kind === 'teacher' || kind === 'department') return 'people';
  return 'building';
}
