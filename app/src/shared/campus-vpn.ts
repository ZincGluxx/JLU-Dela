/** 校外访问学校平台的方式：默认直连（校园网或系统级 VPN 客户端）。 */
export type CampusVpnMode = 'off' | 'webvpn';

export const JLU_WEBVPN_BASE = 'https://webvpn.jlu.edu.cn';
/** 网瑞达 WebVPN 的固定 AES 密钥与 IV（各校部署一致）。 */
export const WEBVPN_KEY = 'wrdvpnisthebest!';

export interface CampusVpnConfig {
  readonly mode: CampusVpnMode;
  /** WebVPN 反向代理入口，形如 https://webvpn.jlu.edu.cn。 */
  readonly baseUrl: string;
}

export interface CampusVpnStatus {
  readonly config: CampusVpnConfig;
  /** VPN 入口能否连上（说明网络可达）。 */
  readonly reachable: boolean;
  /** 是否已经在 VPN 页面完成登录。 */
  readonly authenticated: boolean;
  readonly error?: string;
}

export interface CampusVpnLoginResult {
  readonly ok: boolean;
  readonly error?: string;
}

export interface CampusVpnApi {
  get(): Promise<CampusVpnConfig>;
  set(patch: Partial<CampusVpnConfig>): Promise<CampusVpnConfig>;
  status(): Promise<CampusVpnStatus>;
  /** 打开学校 WebVPN 登录窗口，登录状态保存在本机校园会话中。 */
  login(): Promise<CampusVpnLoginResult>;
}
