import type { CampusVpnApi, CampusVpnConfig } from '../shared/campus-vpn';
import { invoke } from './lib';

export const campusVpn = {
  get: () => invoke('campus:vpn:get'),
  set: (patch: Partial<CampusVpnConfig>) => invoke('campus:vpn:set', patch),
  status: () => invoke('campus:vpn:status'),
  login: () => invoke('campus:vpn:login'),
} satisfies CampusVpnApi;
