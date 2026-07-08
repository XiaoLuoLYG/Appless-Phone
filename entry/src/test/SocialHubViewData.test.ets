import { describe, it, expect } from '@ohos/hypium';
import {
  socialHubCanAuthorize,
  socialHubComposioToolkitCandidates,
  socialHubKindLabel,
  socialHubPlatformLabel,
  socialHubPrimaryText,
  socialHubRecentMessageGroups,
  socialHubVisibleMessageCount
} from '../main/ets/pages/A2uiHome/components/SocialHubViewData';
import { normalizeSocialHubItem } from '@loop/agent-core';

export default function socialHubViewDataTest() {
  describe('socialHubViewData', () => {
    it('labels known platforms', 0, () => {
      expect(socialHubPlatformLabel('x')).assertEqual('X');
      expect(socialHubPlatformLabel('slack')).assertEqual('Slack');
      expect(socialHubPlatformLabel('wecom')).assertEqual('企业微信');
      expect(socialHubPlatformLabel('discord')).assertEqual('Discord');
      expect(socialHubPlatformLabel('linkedin')).assertEqual('LinkedIn');
      expect(socialHubPlatformLabel('whatsapp')).assertEqual('WhatsApp');
      expect(socialHubPlatformLabel('instagram')).assertEqual('Instagram');
    });

    it('labels post kind as public post', 0, () => {
      expect(socialHubKindLabel('post')).assertEqual('公开 post');
    });

    it('uses real item text without inventing empty content', 0, () => {
      const item = normalizeSocialHubItem({
        id: 'x-1',
        platform: 'x',
        kind: 'post',
        text: '真实内容'
      });
      const emptyItem = normalizeSocialHubItem({
        id: 'x-2',
        platform: 'x',
        kind: 'post',
        text: ''
      });

      expect(socialHubPrimaryText(item)).assertEqual('真实内容');
      expect(socialHubPrimaryText(emptyItem)).assertEqual('没有正文');
    });

    it('groups recent SocialHub messages by app and collapses overflow', 0, () => {
      const items = [
        normalizeSocialHubItem({ id: 'slack-1', platform: 'slack', kind: 'message', text: 'a', timestamp: '2026-07-08T10:00:00.000Z' }),
        normalizeSocialHubItem({ id: 'slack-2', platform: 'slack', kind: 'message', text: 'b', timestamp: '2026-07-08T09:00:00.000Z' }),
        normalizeSocialHubItem({ id: 'slack-3', platform: 'slack', kind: 'message', text: 'c', timestamp: '2026-07-08T08:00:00.000Z' }),
        normalizeSocialHubItem({ id: 'x-old', platform: 'x', kind: 'message', text: 'old', timestamp: '2026-05-01T00:00:00.000Z' }),
        normalizeSocialHubItem({ id: 'x-post', platform: 'x', kind: 'post', text: 'public', timestamp: '2026-07-08T00:00:00.000Z' })
      ];
      const groups = socialHubRecentMessageGroups(items, '2026-07-08T12:00:00.000Z', 2);

      expect(groups.length).assertEqual(1);
      expect(groups[0].platform).assertEqual('slack');
      expect(groups[0].visibleItems.length).assertEqual(2);
      expect(groups[0].hiddenCount).assertEqual(1);
    });

    it('treats filtered-out message groups as empty for rendering', 0, () => {
      const items = [
        normalizeSocialHubItem({ id: 'x-old', platform: 'x', kind: 'message', text: 'old', timestamp: '2026-05-01T00:00:00.000Z' }),
        normalizeSocialHubItem({ id: 'x-post', platform: 'x', kind: 'post', text: 'public', timestamp: '2026-07-08T00:00:00.000Z' })
      ];
      const groups = socialHubRecentMessageGroups(items, '2026-07-08T12:00:00.000Z', 5);

      expect(groups.length).assertEqual(0);
      expect(socialHubVisibleMessageCount(groups)).assertEqual(0);
    });

    it('maps SocialHub platforms to Composio toolkit candidates', 0, () => {
      expect(socialHubComposioToolkitCandidates('x').join(',')).assertEqual('x,twitter');
      expect(socialHubComposioToolkitCandidates('slack').join(',')).assertEqual('slack');
      expect(socialHubComposioToolkitCandidates('discord').join(',')).assertEqual('discord');
      expect(socialHubComposioToolkitCandidates('linkedin').join(',')).assertEqual('linkedin');
      expect(socialHubComposioToolkitCandidates('whatsapp').join(',')).assertEqual('whatsapp');
      expect(socialHubComposioToolkitCandidates('instagram').join(',')).assertEqual('instagram');
      expect(socialHubComposioToolkitCandidates('wecom').length).assertEqual(0);
    });

    it('allows authorization for every unavailable Composio-backed SocialHub app', 0, () => {
      expect(socialHubCanAuthorize('needs_auth')).assertTrue();
      expect(socialHubCanAuthorize('limited')).assertTrue();
      expect(socialHubCanAuthorize('disabled')).assertTrue();
      expect(socialHubCanAuthorize('connected')).assertFalse();
      expect(socialHubCanAuthorize('error')).assertFalse();
    });
  });
}
