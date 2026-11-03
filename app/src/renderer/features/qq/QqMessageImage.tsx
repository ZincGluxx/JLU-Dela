import { useEffect, useRef, useState } from 'react';
import { Dialog } from 'radix-ui';
import { X } from 'lucide-react';
import type { QqImage } from '../../../shared/qq';
import { Button } from '../../components/ui/button';
import { dialogOverlay, dialogPanel } from '../../components/ui/motion';
import { errorText } from '../../workspace/store';

export function QqMessageImage({
  groupId,
  messageId,
  image,
}: {
  groupId: string;
  messageId: string;
  image: QqImage;
}) {
  const host = useRef<HTMLDivElement>(null);
  const [source, setSource] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);
  useEffect(() => {
    let active = true;
    const observer = new IntersectionObserver((entries) => {
      if (!entries.some((entry) => entry.isIntersecting)) return;
      observer.disconnect();
      void window.dela!.qq.image(groupId, messageId, image.id).then(
        (value) => {
          if (active) setSource(value);
        },
        (cause) => {
          if (active) setError(errorText(cause));
        },
      );
    });
    if (host.current) observer.observe(host.current);
    return () => {
      active = false;
      observer.disconnect();
    };
  }, [groupId, messageId, image.id, attempt]);
  return (
    <div ref={host} className="mt-2 min-h-8">
      {source ? (
        <Dialog.Root>
          <Dialog.Trigger asChild>
            <button aria-label={`查看${image.label}`} className="block max-w-full rounded-control">
              <img
                src={source}
                alt={image.label}
                className="max-h-64 max-w-full rounded-control object-contain"
              />
            </button>
          </Dialog.Trigger>
          <Dialog.Portal>
            <Dialog.Overlay className={dialogOverlay} />
            <Dialog.Content
              className={`${dialogPanel} flex max-h-dvh w-full max-w-5xl flex-col gap-3 p-4`}
              aria-describedby={undefined}
            >
              <div className="flex items-center justify-between gap-3">
                <Dialog.Title className="text-sm font-medium">{image.label}</Dialog.Title>
                <Dialog.Close asChild>
                  <Button variant="ghost" size="icon-sm" aria-label="关闭图片">
                    <X />
                  </Button>
                </Dialog.Close>
              </div>
              <img
                src={source}
                alt={image.label}
                className="min-h-0 max-w-full flex-1 object-contain"
              />
            </Dialog.Content>
          </Dialog.Portal>
        </Dialog.Root>
      ) : error ? (
        <div className="flex flex-wrap items-center gap-2 text-xs text-ink-3">
          <span>{error}</span>
          <Button
            size="sm"
            variant="ghost"
            onClick={() => {
              setError(null);
              setAttempt(attempt + 1);
            }}
          >
            重试图片
          </Button>
        </div>
      ) : (
        <p className="text-xs text-ink-3">正在加载{image.label}…</p>
      )}
    </div>
  );
}
