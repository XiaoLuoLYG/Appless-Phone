import { describe, it, expect } from '@ohos/hypium';
import {
  composioAuthActionLabel,
  composioAuthStatusLabel,
  sortedComposioAuthConfigs
} from '../main/ets/pages/A2uiHome/components/ComposioAuthViewData';
import { ComposioAuthConfigItem } from '@loop/agent-core';

function item(slug: string, status: string): ComposioAuthConfigItem {
  return {
    authConfigId: 'ac_' + slug,
    toolkitSlug: slug,
    toolkitName: slug,
    logoUrl: '',
    authScheme: 'OAuth2',
    management: 'managed',
    status,
    connectedAccountId: status === 'connected' ? 'ca_' + slug : '',
    connectedAccountLabel: '',
    lastConnectedAt: '',
    canExecute: status === 'connected'
  };
}

export default function composioAuthViewDataTest() {
  describe('composioAuthViewData', () => {
    it('labels auth status and actions', 0, () => {
      expect(composioAuthStatusLabel('connected')).assertEqual('已连接');
      expect(composioAuthStatusLabel('needs_auth')).assertEqual('待授权');
      expect(composioAuthActionLabel(item('github', 'connected'))).assertEqual('重新授权');
      expect(composioAuthActionLabel(item('github', 'needs_auth'))).assertEqual('授权');
    });

    it('sorts connected configs first then by toolkit name', 0, () => {
      const sorted = sortedComposioAuthConfigs([
        item('slack', 'needs_auth'),
        item('github', 'connected'),
        item('asana', 'needs_auth')
      ]);

      expect(sorted[0].toolkitSlug).assertEqual('github');
      expect(sorted[1].toolkitSlug).assertEqual('asana');
      expect(sorted[2].toolkitSlug).assertEqual('slack');
    });
  });
}
