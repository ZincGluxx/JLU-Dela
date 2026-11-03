import { useEffect } from 'react';
import type { TabComponentProps } from '../../workbench/registry';
import { QqConversation } from './QqView';
import { attachQq } from './store';

export function QqTab({ tabId }: TabComponentProps) {
  useEffect(attachQq, []);
  const [accountId, groupId] = tabId.slice(3).split('/');
  if (!accountId || !groupId)
    return <p className="p-4 text-13 text-ink-3">群聊标签无效，请从 QQ 群列表重新打开。</p>;
  return <QqConversation key={`${accountId}/${groupId}`} accountId={accountId} groupId={groupId} />;
}
