import type {
  CommunityApi,
  CommunityDealStatus,
  CommunityModerationDecision,
  CommunityPostInput,
} from '../shared/community';
import { invoke } from './lib';

export const community = {
  get: () => invoke('community:get'),
  create: (input: CommunityPostInput) => invoke('community:create', input),
  like: (id: string) => invoke('community:like', id),
  reply: (id: string, body: string) => invoke('community:reply', id, body),
  moderate: (id: string, decision: CommunityModerationDecision) =>
    invoke('community:moderate', id, decision),
  setDealStatus: (id: string, status: CommunityDealStatus) =>
    invoke('community:deal-status', id, status),
  report: (id: string) => invoke('community:report', id),
  remove: (id: string) => invoke('community:remove', id),
  regenerateDemo: () => invoke('community:regenerate-demo'),
} satisfies CommunityApi;
