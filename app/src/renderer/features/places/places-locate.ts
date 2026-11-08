// 定位能力：用户主动开启后才调用；取不到就退回示例位置并明确标注，绝不假装真实定位。
import type { PlaceCoordinate } from '../../../shared/places';

export interface LocatedPosition {
  coordinate: PlaceCoordinate;
  /** true 表示定位失败后退回的示例位置，界面必须提示。 */
  simulated: boolean;
  error?: string;
}

/** 中心校区作为演示锚点，仅用于「定位不可用」时的距离预览。 */
export const demoPosition: PlaceCoordinate = { latitude: 43.826_62, longitude: 125.287_05 };

interface GeolocationLike {
  getCurrentPosition(
    success: (position: {
      coords: { latitude: number; longitude: number; accuracy: number };
    }) => void,
    error: (error: { message?: string }) => void,
    options?: { enableHighAccuracy?: boolean; timeout?: number; maximumAge?: number },
  ): void;
}

/** 读取一次定位；失败时返回示例位置并把失败原因交回界面。 */
export function requestPosition(
  geolocation: GeolocationLike | undefined,
  timeoutMs = 8000,
): Promise<LocatedPosition> {
  if (!geolocation) return Promise.resolve(simulated('当前环境不支持定位'));
  return new Promise((resolve) => {
    geolocation.getCurrentPosition(
      (position) =>
        resolve({
          coordinate: {
            latitude: position.coords.latitude,
            longitude: position.coords.longitude,
          },
          simulated: false,
        }),
      (error) => resolve(simulated(error.message || '未能获取定位')),
      { enableHighAccuracy: false, timeout: timeoutMs, maximumAge: 60_000 },
    );
  });
}

function simulated(reason: string): LocatedPosition {
  return { coordinate: demoPosition, simulated: true, error: reason };
}
