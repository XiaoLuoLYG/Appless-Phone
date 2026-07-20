import { describe, it, expect } from '@ohos/hypium';
import {
  composioAuthActionLabel,
  composioAuthStatusLabel,
  composioToolkitDisplayName,
  EXTERNAL_AUTH_APPS,
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

    it('shows app names instead of auth config names', 0, () => {
      expect(composioToolkitDisplayName('github', 'auth_config_github_1783335201301')).assertEqual('GitHub');
      expect(composioToolkitDisplayName('googlecalendar', 'googlecalendar-1z473s')).assertEqual('Google Calendar');
      expect(composioToolkitDisplayName('spotify', 'AIPhoneDemo Spotify')).assertEqual('Spotify');
      expect(composioToolkitDisplayName('reddit', 'reddit-l3wrzh')).assertEqual('Reddit');
    });

    it('shows app names for external authorization links', 0, () => {
      expect(composioToolkitDisplayName('qqmail')).assertEqual('QQ 邮箱');
      expect(composioToolkitDisplayName('luckin')).assertEqual('瑞幸咖啡');
      expect(composioToolkitDisplayName('didi')).assertEqual('滴滴出行');
      expect(EXTERNAL_AUTH_APPS.length).assertEqual(3);
      expect(EXTERNAL_AUTH_APPS[0].url).assertEqual('https://wx.mail.qq.com/list/readtemplate?name=app_intro.html#/agreement/authorizationCode');
      expect(EXTERNAL_AUTH_APPS[1].url).assertEqual('https://open01.luckincoffeecdn.com/');
      expect(EXTERNAL_AUTH_APPS[2].url).assertEqual('https://mcp.didichuxing.com');
      expect(EXTERNAL_AUTH_APPS[0].source).assertEqual('QQ 邮箱官方页面 · 当前默认凭证');
      expect(EXTERNAL_AUTH_APPS[1].source).assertEqual('瑞幸官方页面 · 当前默认凭证');
      expect(EXTERNAL_AUTH_APPS[2].source).assertEqual('滴滴官方页面 · 当前默认凭证');
    });
  });
}
