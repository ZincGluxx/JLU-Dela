// 校园地图的检索与文案规则：老师、事项、院系都必须能落到具体房间。
import { describe, expect, it } from 'vitest';
import {
  distanceMeters,
  formatDistance,
  formatOfficeLocation,
  mapLinkFor,
  placeBuildingOf,
  searchPlaces,
  type PlaceCoordinate,
  type PlacesSnapshot,
} from './places';

const now = '2025-01-01T00:00:00.000Z';

function snapshot(): PlacesSnapshot {
  return {
    version: 1,
    generatedAt: now,
    campuses: [
      { id: 'qianwei-south', name: '中心校区', address: '前进大街 2699 号' },
      { id: 'nanling', name: '南岭校区', address: '人民大街 5988 号' },
    ],
    buildings: [
      {
        id: 'xz',
        campusId: 'qianwei-south',
        name: '行政楼',
        alias: '行政',
        floors: 8,
        coordinate: { latitude: 43.8266, longitude: 125.2871 },
      },
      {
        id: 'jx',
        campusId: 'nanling',
        name: '机械材料馆',
        floors: 5,
        coordinate: { latitude: 43.8613, longitude: 125.3155 },
      },
    ],
    departments: [
      { id: 'fin', name: '财务处', category: '行政', buildingId: 'xz' },
      { id: 'me', name: '机械与航空航天工程学院', category: '学院', buildingId: 'jx' },
    ],
    offices: [
      {
        id: 'fin-bx',
        buildingId: 'xz',
        floor: '1 层',
        room: '101 报销大厅',
        name: '财务处报销大厅',
        kind: 'service',
        departmentIds: ['fin'],
        serviceIds: ['sv-bx'],
        teacherIds: ['t-zhao'],
        source: 'demo',
        verifiedAt: null,
        updatedAt: now,
      },
      {
        id: 'me-jw',
        buildingId: 'jx',
        floor: '3 层',
        room: '305',
        name: '机械学院教务办公室',
        kind: 'office',
        departmentIds: ['me'],
        serviceIds: [],
        teacherIds: [],
        source: 'user',
        verifiedAt: '2025-02-01',
        updatedAt: now,
      },
    ],
    teachers: [
      { id: 't-zhao', name: '赵敏', title: '科员', departmentId: 'fin', officeId: 'fin-bx' },
    ],
    services: [
      {
        id: 'sv-bx',
        name: '发票报销',
        category: '报销',
        officeId: 'fin-bx',
        steps: ['整理票据'],
        materials: ['发票原件'],
      },
    ],
    corrections: [],
  };
}

describe('地点展示', () => {
  it('把校区、楼宇、楼层、房间按顺序拼成一行', () => {
    const data = snapshot();
    expect(formatOfficeLocation(data, data.offices[0]!)).toBe(
      '中心校区 · 行政楼 · 1 层 · 101 报销大厅',
    );
  });

  it('楼层与房间留空时不留下多余分隔符', () => {
    const data = snapshot();
    expect(formatOfficeLocation(data, { buildingId: 'xz', floor: '', room: '' })).toBe(
      '中心校区 · 行政楼',
    );
  });

  it('按办公室反查楼宇，找不到时返回 null', () => {
    const data = snapshot();
    expect(placeBuildingOf(data, 'fin-bx')?.name).toBe('行政楼');
    expect(placeBuildingOf(data, '不存在')).toBeNull();
  });
});

describe('检索', () => {
  it('空条件列出全部办公室', () => {
    const hits = searchPlaces(snapshot());
    expect(hits.map((hit) => hit.kind)).toEqual(['office', 'office']);
    expect(hits.every((hit) => hit.score > 0)).toBe(true);
  });

  it('按老师姓名命中，并带上他所在的办公室', () => {
    const hits = searchPlaces(snapshot(), { text: '赵敏' });
    const teacher = hits.find((hit) => hit.kind === 'teacher');
    expect(teacher).toMatchObject({ id: 't-zhao', officeId: 'fin-bx' });
    expect(teacher?.subtitle).toContain('行政楼');
  });

  it('事项名称命中时排在只沾边的办公室前面', () => {
    const hits = searchPlaces(snapshot(), { text: '报销' });
    expect(hits[0]).toMatchObject({ kind: 'service', title: '发票报销', officeId: 'fin-bx' });
    expect(hits.some((hit) => hit.kind === 'office')).toBe(true);
  });

  it('按院系名称命中，并落到该院系的办公室', () => {
    const hits = searchPlaces(snapshot(), { text: '机械与航空航天' });
    expect(hits.find((hit) => hit.kind === 'department')).toMatchObject({
      id: 'me',
      officeId: 'me-jw',
    });
  });

  it('筛选校区、类型、院系与事项分类都会过滤掉不相关的结果', () => {
    const data = snapshot();
    expect(searchPlaces(data, { campusId: 'nanling' }).map((hit) => hit.id)).toEqual(['me-jw']);
    expect(searchPlaces(data, { kind: 'service' }).map((hit) => hit.id)).toEqual(['fin-bx']);
    expect(searchPlaces(data, { departmentId: 'me' }).map((hit) => hit.id)).toEqual(['me-jw']);
    expect(searchPlaces(data, { serviceCategory: '报销' }).map((hit) => hit.id)).toEqual([
      'fin-bx',
    ]);
    expect(searchPlaces(data, { serviceCategory: '证明' })).toEqual([]);
  });

  it('关键词和筛选条件都不沾边时没有结果', () => {
    expect(searchPlaces(snapshot(), { text: '食堂' })).toEqual([]);
    expect(searchPlaces(snapshot(), { text: '报销', campusId: 'nanling' })).toEqual([]);
  });
});

describe('距离与地图链接', () => {
  it('坐标缺失时距离为 null，文案说明未知', () => {
    expect(distanceMeters(snapshot().buildings[0]!.coordinate, undefined)).toBeNull();
    expect(formatDistance(null)).toBe('距离未知');
  });

  it('两个校区的楼宇距离在合理量级，且方向对称', () => {
    const data = snapshot();
    const from = data.buildings[0]!.coordinate;
    const to = data.buildings[1]!.coordinate;
    const forward = distanceMeters(from, to);
    expect(forward).toBeGreaterThan(4000);
    expect(forward).toBeLessThan(5200);
    expect(distanceMeters(to, from)).toBe(forward);
    expect(formatDistance(forward)).toMatch(/^约 4\.\d 公里$/);
  });

  it('1 公里内按米显示，最小 10 米', () => {
    expect(formatDistance(3)).toBe('约 10 米');
    expect(formatDistance(42)).toBe('约 40 米');
    expect(formatDistance(999)).toBe('约 1000 米');
  });

  it('有坐标时给出高德打点链接，没有坐标时退回按名称搜索', () => {
    const data = snapshot();
    const marker = mapLinkFor(data, data.offices[0]!);
    expect(marker.label).toBe('在高德地图中导航');
    expect(marker.url).toContain('https://uri.amap.com/marker?position=125.2871,43.8266');

    const orphan: PlaceCoordinate = { latitude: 43.9, longitude: 125.3 };
    expect(distanceMeters(orphan, orphan)).toBe(0);
    const fallback = mapLinkFor(data, { ...data.offices[0]!, buildingId: '不存在' });
    expect(fallback.label).toBe('在地图中搜索该地点');
    expect(fallback.url).toContain('https://uri.amap.com/search?keyword=');
  });
});
