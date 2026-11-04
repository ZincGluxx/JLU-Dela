/** 登录失效错误：调用方据此引导重新登录，而非当作普通失败。 */
export class CampusAuthError extends Error {}

/**
 * 校外 VPN 会话失效：与学校统一认证失效不同，重建 SSO 会话没有意义，
 * 必须先回 VPN 入口重新登录，因此单独区分，避免上层白跑一次登录恢复。
 */
export class CampusVpnAuthError extends CampusAuthError {}
