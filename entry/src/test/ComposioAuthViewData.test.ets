import { describe, it, expect } from '@ohos/hypium';
import {
  composioAuthActionLabel,
  composioAuthStatusLabel,
  composioToolkitDisplayName,
  COMPOSIO_SUPPORTED_TOOLKITS,
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
      expect(composioAuthStatusLabel('success')).assertEqual('无需授权');
      expect(composioAuthStatusLabel('disabled')).assertEqual('待配置');
      expect(composioAuthActionLabel(item('github', 'connected'))).assertEqual('重新授权');
      expect(composioAuthActionLabel(item('github', 'needs_auth'))).assertEqual('授权');
    });

    it('sorts connected configs first and keeps the full supported catalog', 0, () => {
      const sorted = sortedComposioAuthConfigs([
        item('slack', 'needs_auth'),
        item('github', 'connected'),
        item('asana', 'needs_auth')
      ]);

      expect(sorted.length).assertEqual(24);
      expect(sorted[0].toolkitSlug).assertEqual('github');
      expect(sorted.filter((config) => config.toolkitSlug === 'asana').length).assertEqual(1);
      expect(sorted.filter((config) => config.toolkitSlug === 'slack').length).assertEqual(1);
      expect(sorted.filter((config) => config.toolkitSlug === 'hackernews')[0].status).assertEqual('success');
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
      expect(EXTERNAL_AUTH_APPS.length).assertEqual(17);
      expect(COMPOSIO_SUPPORTED_TOOLKITS.length + EXTERNAL_AUTH_APPS.length).assertEqual(41);
      expect(EXTERNAL_AUTH_APPS[0].url).assertEqual('https://wx.mail.qq.com/list/readtemplate?name=app_intro.html#/agreement/authorizationCode');
      expect(EXTERNAL_AUTH_APPS[1].url).assertEqual('https://open01.luckincoffeecdn.com/');
      expect(EXTERNAL_AUTH_APPS[2].url).assertEqual('https://mcp.didichuxing.com');
      expect(EXTERNAL_AUTH_APPS[0].source).assertEqual('QQ 邮箱官方页面 · 当前默认凭证');
      expect(EXTERNAL_AUTH_APPS[1].source).assertEqual('瑞幸官方页面 · 当前默认凭证');
      expect(EXTERNAL_AUTH_APPS[2].source).assertEqual('滴滴官方页面 · 当前默认凭证');
      expect(EXTERNAL_AUTH_APPS.filter((app) => app.slug === 'zhihu')[0].requiresAuth).assertFalse();
    });

    it('lists supported no-auth toolkits on the authorization page', 0, () => {
      const hackerNews = COMPOSIO_SUPPORTED_TOOLKITS.filter((toolkit) => toolkit.slug === 'hackernews');

      expect(COMPOSIO_SUPPORTED_TOOLKITS.length).assertEqual(24);
      expect(hackerNews.length).assertEqual(1);
      expect(hackerNews[0].name).assertEqual('Hacker News');
    });
  });
}
