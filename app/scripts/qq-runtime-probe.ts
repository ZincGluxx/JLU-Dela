import { app } from 'electron';
import { existsSync, mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { QqService } from '../src/main/qq/service';

const profile = mkdtempSync(join(tmpdir(), 'dela-qq-probe-'));
app.setPath('userData', profile);
let finished = false;
const timeout = setTimeout(() => finish(1, 'QQ runtime probe timed out'), 150000);
const service = new QqService(
  (state) => {
    console.log(`QQ runtime: ${state.phase} ${state.progress}`);
    if (state.phase === 'login' && state.qrCode)
      finish(0, 'QQ runtime reached QR login. No account was logged in.');
    if (state.phase === 'error') finish(1, state.error ?? 'QQ runtime failed');
  },
  () => {},
);
function finish(code: number, message: string) {
  if (finished) return;
  finished = true;
  clearTimeout(timeout);
  console.log(message);
  const log = join(profile, 'qq/launcher.log');
  if (code && existsSync(log)) {
    const errors = readFileSync(log, 'utf8')
      .split('\n')
      .filter(
        (line) =>
          /error|failed|exception|not defined|abort/i.test(line) &&
          !/token|password|qrcode/i.test(line),
      );
    for (const line of errors.slice(-10)) console.log(line.slice(0, 1000));
  }
  service.stop();
  setTimeout(() => {
    rmSync(profile, { recursive: true, force: true });
    app.exit(code);
  }, 1500);
}
void app.whenReady().then(() => service.start());
app.on('will-quit', () => service.stop());
