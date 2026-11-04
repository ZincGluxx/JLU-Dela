import { useEffect, useState } from 'react';
import { LoaderCircle, ShieldCheck, Wifi } from 'lucide-react';
import {
  JLU_WEBVPN_BASE,
  type CampusVpnConfig,
  type CampusVpnStatus,
} from '../../../shared/campus-vpn';
import { Button } from '../../components/ui/button';
import { Input } from '../../components/ui/input';
import { cn } from '../../lib/utils';
import { errorText } from '../../workspace/store';

/** 校外访问学校平台：默认直连（校园网或系统级 VPN 客户端），也可走学校 WebVPN 网页入口。 */
export function VpnCard() {
  const api = window.dela?.campusVpn;
  const [config, setConfig] = useState<CampusVpnConfig | null>(null);
  const [draft, setDraft] = useState(JLU_WEBVPN_BASE);
  const [status, setStatus] = useState<CampusVpnStatus | null>(null);
  const [busy, setBusy] = useState<'save' | 'check' | 'login' | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  useEffect(() => {
    if (!api) return;
    let active = true;
    void api
      .get()
      .then((value) => {
        if (!active) return;
        setConfig(value);
        setDraft(value.baseUrl);
      })
      .catch((cause) => {
        if (active) setError(errorText(cause));
      });
    return () => {
      active = false;
    };
  }, [api]);

  async function save(patch: Partial<CampusVpnConfig>) {
    if (!api) return;
    setBusy('save');
    setError(null);
    setNotice(null);
    setStatus(null);
    try {
      const value = await api.set(patch);
      setConfig(value);
      setDraft(value.baseUrl);
      setNotice(
        value.mode === 'webvpn'
          ? '已切换到学校 WebVPN 入口，请先在下面完成 VPN 登录再同步课表。'
          : '已切回直连，适合在校园网内或已开启系统级 VPN 客户端时使用。',
      );
    } catch (cause) {
      setError(errorText(cause));
    } finally {
      setBusy(null);
    }
  }

  async function check() {
    if (!api) return;
    setBusy('check');
    setError(null);
    setNotice(null);
    try {
      setStatus(await api.status());
    } catch (cause) {
      setError(errorText(cause));
    } finally {
      setBusy(null);
    }
  }

  async function login() {
    if (!api) return;
    setBusy('login');
    setError(null);
    setNotice(null);
    try {
      const result = await api.login();
      if (result.ok) {
        setNotice('VPN 登录已完成，可以回到课表或通知页同步。');
        setStatus(await api.status());
      } else setError(result.error ?? 'VPN 登录未完成');
    } catch (cause) {
      setError(errorText(cause));
    } finally {
      setBusy(null);
    }
  }

  const webvpn = config?.mode === 'webvpn';
  return (
    <section className="grid gap-3 rounded-xl border border-line p-5" data-setting-id="campus-vpn">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h2 className="flex items-center gap-2 text-base font-semibold text-ink">
          <ShieldCheck className="size-4 text-ink-3" aria-hidden="true" />
          校外网络（VPN）
        </h2>
        <span
          className={cn(
            'rounded-full px-2.5 py-1 text-xs',
            webvpn ? 'bg-bui-accent/15 text-bui-accent-ink' : 'bg-field text-ink-3',
          )}
        >
          {webvpn ? '学校 WebVPN' : '直连'}
        </span>
      </div>
      <p className="text-13 leading-relaxed text-ink-3">
        不在校园网内时，教务系统、校内通知等只能经学校 VPN 访问。已经装了学校 VPN
        客户端（EasyConnect 等）的保持「直连」即可；只想用浏览器登录的，选「学校 WebVPN」，Dela
        会把校内地址自动换成入口地址，并在本机保存登录状态。
      </p>
      <div className="flex flex-wrap gap-2">
        <Button
          size="sm"
          variant={webvpn ? 'ghost' : 'secondary'}
          disabled={!api || busy !== null}
          aria-pressed={!webvpn}
          onClick={() => void save({ mode: 'off' })}
        >
          <Wifi className="size-4" aria-hidden="true" />
          直连 / 系统 VPN
        </Button>
        <Button
          size="sm"
          variant={webvpn ? 'secondary' : 'ghost'}
          disabled={!api || busy !== null}
          aria-pressed={webvpn}
          onClick={() => void save({ mode: 'webvpn' })}
        >
          <ShieldCheck className="size-4" aria-hidden="true" />
          学校 WebVPN
        </Button>
      </div>
      {webvpn && (
        <div className="grid gap-2">
          <label className="grid gap-2 text-13 text-ink-2">
            VPN 入口地址
            <Input
              aria-label="VPN 入口地址"
              value={draft}
              disabled={busy !== null}
              placeholder={JLU_WEBVPN_BASE}
              onChange={(event) => setDraft(event.target.value)}
            />
          </label>
          <div className="flex flex-wrap gap-2">
            <Button
              size="sm"
              variant="outline"
              disabled={busy !== null || !draft.trim()}
              onClick={() => void save({ baseUrl: draft })}
            >
              保存入口
            </Button>
            <Button
              size="sm"
              variant="outline"
              disabled={busy !== null}
              onClick={() => void check()}
            >
              检测 VPN 状态
            </Button>
            <Button size="sm" disabled={busy !== null} onClick={() => void login()}>
              打开 VPN 登录
            </Button>
            {busy && <LoaderCircle className="size-4 animate-spin self-center text-ink-3" />}
          </div>
          {status && (
            <p className="text-xs text-ink-2" role="status">
              {status.reachable
                ? status.authenticated
                  ? '入口可访问，且已经登录；可以直接同步课表。'
                  : '入口可访问，但还没有登录；请点「打开 VPN 登录」完成学校认证。'
                : (status.error ?? '入口无法访问，请检查网络或入口地址。')}
            </p>
          )}
        </div>
      )}
      {notice && (
        <p className="text-xs text-ink-2" role="status">
          {notice}
        </p>
      )}
      {error && (
        <p className="break-words text-13 text-red" role="alert">
          {error}
        </p>
      )}
      {!api && <p className="text-xs text-ink-3">VPN 设置只在桌面应用中可用。</p>}
    </section>
  );
}
