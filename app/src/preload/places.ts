import type {
  PlaceCorrectionInput,
  PlaceCorrectionStatus,
  PlaceOfficeInput,
  PlacesApi,
  PlaceSearchQuery,
} from '../shared/places';
import { invoke } from './lib';

export const places = {
  get: () => invoke('places:get'),
  search: (query: PlaceSearchQuery) => invoke('places:search', query),
  saveOffice: (input: PlaceOfficeInput) => invoke('places:save-office', input),
  submitCorrection: (input: PlaceCorrectionInput) => invoke('places:submit-correction', input),
  reviewCorrection: (id: string, status: PlaceCorrectionStatus) =>
    invoke('places:review-correction', id, status),
  regenerateDemo: () => invoke('places:regenerate-demo'),
} satisfies PlacesApi;
