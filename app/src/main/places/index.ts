import { ipcMain } from 'electron';
import { randomUUID } from 'node:crypto';
import { z } from 'zod';
import { getDatabase } from '../database';
import { checkWorkspaceSender } from '../ipc';
import {
  searchPlaces,
  type PlaceCorrection,
  type PlaceCorrectionStatus,
  type PlaceKind,
  type PlaceOffice,
  type PlaceSearchHit,
  type PlaceSearchQuery,
  type PlacesSnapshot,
  placeKinds,
  placeServiceCategories,
} from '../../shared/places';
import { demoPlacesSnapshot } from './seed';

const DOC_KIND = 'places';

type DocRow = { version: number; data: string; updated_at: string };

function readDoc(): PlacesSnapshot | null {
  const row = getDatabase()
    .prepare('SELECT version,data,updated_at FROM campus_docs WHERE kind=?')
    .get(DOC_KIND) as DocRow | undefined;
  if (!row) return null;
  try {
    return JSON.parse(row.data) as PlacesSnapshot;
  } catch {
    return null;
  }
}

function writeDoc(snapshot: PlacesSnapshot): PlacesSnapshot {
  getDatabase()
    .prepare(
      `INSERT INTO campus_docs(kind,version,data,updated_at) VALUES(?,?,?,?)
       ON CONFLICT(kind) DO UPDATE SET version=excluded.version, data=excluded.data,
       updated_at=excluded.updated_at`,
    )
    .run(DOC_KIND, snapshot.version, JSON.stringify(snapshot), new Date().toISOString());
  return snapshot;
}

/** 读取快照；首次访问时写入示例内容，让骨架开箱可见。 */
export function getPlaces(): PlacesSnapshot {
  return readDoc() ?? writeDoc(demoPlacesSnapshot());
}

export function searchPlaceHits(input: unknown): PlaceSearchHit[] {
  const query = placeQuerySchema.parse(input ?? {});
  return searchPlaces(getPlaces(), query);
}

const placeKindsTuple = placeKinds as [PlaceKind, ...PlaceKind[]];

const placeQuerySchema = z
  .object({
    text: z.string().max(120).optional(),
    campusId: z.string().max(60).optional(),
    kind: z.enum(placeKindsTuple).optional(),
    departmentId: z.string().max(60).optional(),
    serviceCategory: z.enum(placeServiceCategories).optional(),
  })
  .strict()
  .transform<PlaceSearchQuery>((value) => ({
    text: value.text,
    campusId: value.campusId as PlaceSearchQuery['campusId'],
    kind: value.kind ?? '',
    departmentId: value.departmentId,
    serviceCategory: value.serviceCategory ?? '',
  }));

export const placeOfficeInputSchema = z
  .object({
    id: z.string().max(60).optional(),
    buildingId: z.string().min(1).max(60),
    floor: z.string().trim().max(20),
    room: z.string().trim().max(40),
    name: z.string().trim().min(2).max(80),
    kind: z.enum(placeKindsTuple),
    departmentIds: z.array(z.string().max(60)).max(6).optional(),
    hours: z.string().trim().max(80).optional(),
    phone: z.string().trim().max(40).optional(),
    note: z.string().trim().max(300).optional(),
  })
  .strict();

/** 新增或修改办公室：一律标记为同学上报，待后续核实。 */
export function savePlaceOffice(input: unknown): PlacesSnapshot {
  const value = placeOfficeInputSchema.parse(input);
  const snapshot = getPlaces();
  if (!snapshot.buildings.some((row) => row.id === value.buildingId))
    throw new Error('楼宇不存在，请先选择校区与楼宇');
  const now = new Date().toISOString();
  const existing = value.id ? snapshot.offices.find((row) => row.id === value.id) : undefined;
  if (value.id && !existing) throw new Error('要修改的办公室不存在');
  const office: PlaceOffice = {
    id: existing?.id ?? randomUUID(),
    buildingId: value.buildingId,
    floor: value.floor,
    room: value.room,
    name: value.name,
    kind: value.kind,
    departmentIds: value.departmentIds ?? existing?.departmentIds ?? [],
    serviceIds: existing?.serviceIds ?? [],
    teacherIds: existing?.teacherIds ?? [],
    ...(value.hours ? { hours: value.hours } : existing?.hours ? { hours: existing.hours } : {}),
    ...(value.phone ? { phone: value.phone } : existing?.phone ? { phone: existing.phone } : {}),
    ...(value.note ? { note: value.note } : existing?.note ? { note: existing.note } : {}),
    ...(existing?.coordinate ? { coordinate: existing.coordinate } : {}),
    source: existing?.source === 'official' ? 'official' : 'user',
    verifiedAt: existing?.verifiedAt ?? null,
    updatedAt: now,
  };
  return writeDoc({
    ...snapshot,
    generatedAt: now,
    offices: existing
      ? snapshot.offices.map((row) => (row.id === office.id ? office : row))
      : [...snapshot.offices, office],
  });
}

export const placeCorrectionInputSchema = z
  .object({
    target: z.enum(['office', 'teacher', 'service', 'building']),
    targetId: z.string().min(1).max(60),
    targetName: z.string().trim().min(1).max(80),
    message: z.string().trim().min(4).max(500),
    contact: z.string().trim().max(80).optional(),
  })
  .strict();

export function submitPlaceCorrection(input: unknown): PlacesSnapshot {
  const value = placeCorrectionInputSchema.parse(input);
  const snapshot = getPlaces();
  const correction: PlaceCorrection = {
    id: randomUUID(),
    target: value.target,
    targetId: value.targetId,
    targetName: value.targetName,
    message: value.message,
    ...(value.contact ? { contact: value.contact } : {}),
    status: 'pending',
    createdAt: new Date().toISOString(),
  };
  return writeDoc({ ...snapshot, corrections: [correction, ...snapshot.corrections] });
}

export function reviewPlaceCorrection(id: string, status: unknown): PlacesSnapshot {
  const decision = z.enum(['accepted', 'rejected']).parse(status) as PlaceCorrectionStatus;
  const snapshot = getPlaces();
  if (!snapshot.corrections.some((row) => row.id === id)) throw new Error('纠错记录不存在');
  return writeDoc({
    ...snapshot,
    corrections: snapshot.corrections.map((row) =>
      row.id === id ? { ...row, status: decision } : row,
    ),
  });
}

/** 重新生成示例内容：保留同学上报的地点与全部纠错记录。 */
export function regenerateDemoPlaces(): PlacesSnapshot {
  const current = getPlaces();
  const demo = demoPlacesSnapshot();
  const mine = current.offices.filter((row) => row.source === 'user');
  return writeDoc({
    ...demo,
    offices: [...demo.offices, ...mine.filter((row) => !demo.offices.some((d) => d.id === row.id))],
    corrections: current.corrections,
  });
}

export function registerPlacesIpc(): void {
  ipcMain.handle('places:get', (event) => {
    checkWorkspaceSender(event);
    return getPlaces();
  });
  ipcMain.handle('places:search', (event, query: unknown) => {
    checkWorkspaceSender(event);
    return searchPlaceHits(query);
  });
  ipcMain.handle('places:save-office', (event, input: unknown) => {
    checkWorkspaceSender(event);
    return savePlaceOffice(input);
  });
  ipcMain.handle('places:submit-correction', (event, input: unknown) => {
    checkWorkspaceSender(event);
    return submitPlaceCorrection(input);
  });
  ipcMain.handle('places:review-correction', (event, id: string, status: unknown) => {
    checkWorkspaceSender(event);
    return reviewPlaceCorrection(id, status);
  });
  ipcMain.handle('places:regenerate-demo', (event) => {
    checkWorkspaceSender(event);
    return regenerateDemoPlaces();
  });
}
