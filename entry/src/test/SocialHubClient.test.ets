import { describe, it, expect } from '@ohos/hypium';
import {
  createSocialHubPublicationPreview,
  parseComposioCommunityFeed,
  parseComposioSocialFeed,
  parseSocialHubDraftPayload,
  parseSocialHubFeedPayload,
  SocialHubClient,
  SocialHubProviderConfig,
  socialHubBridgeDraftError,
  socialHubBridgeHeaders,
  socialHubBridgeUnavailableFeed,
  socialHubPrivateItems,
  socialHubXPostResult,
  xSearchQuery
} from '@loop/agent-core';

export default function socialHubClientTest() {
  describe('socialHubClient', () => {
    it('parses bridge feed payloads without renaming current SocialHub fields', 0, () => {
      const result = parseSocialHubFeedPayload('{"items":[{"id":"slack-1","platform":"slack","kind":"message","author":"Ada","handle":"@ada","text":"standup moved","timestamp":"2026-07-01T01:00:00.000Z","channel":"#core","threadId":"t-1","unread":true}],"connections":[{"platform":"x","status":"needs_auth","message":"OAuth required"}]}');

      expect(result.items.length).assertEqual(1);
      expect(result.items[0].channel).assertEqual('#core');
      expect(result.items[0].unread).assertTrue();
      expect(result.connections[0].platform).assertEqual('x');
      expect(result.connections[0].message).assertEqual('OAuth required');
    });

    it('parses draft payloads as local-only and unsent', 0, () => {
      const draft = parseSocialHubDraftPayload('{"draft":{"itemId":"x-1","platform":"x","text":"Thanks","status":"draft","sent":true}}');

      expect(draft.itemId).assertEqual('x-1');
      expect(draft.status).assertEqual('draft');
      expect(draft.localOnly).assertTrue();
      expect(draft.sent).assertFalse();
    });

    it('filters X post results away from private social feed rows', 0, () => {
      const filtered = socialHubXPostResult(parseSocialHubFeedPayload('{"items":[{"id":"x-1","platform":"x","kind":"post","text":"public post"},{"id":"x-2","platform":"x","kind":"message","text":"not public post"},{"id":"slack-1","platform":"slack","kind":"message","text":"private slack"},{"id":"wecom-1","platform":"wecom","kind":"message","text":"private wecom"}],"connections":[{"platform":"x","status":"connected","message":"X connected"},{"platform":"slack","status":"connected","message":"Slack connected"},{"platform":"wecom","status":"connected","message":"WeCom connected"}]}'));

      expect(filtered.items.length).assertEqual(1);
      expect(filtered.items[0].id).assertEqual('x-1');
      expect(filtered.connections.length).assertEqual(1);
      expect(filtered.connections[0].platform).assertEqual('x');
    });

    it('keeps only received private message rows for SocialHub feed', 0, () => {
      const parsed = parseSocialHubFeedPayload('{"items":[{"id":"x-post","platform":"x","kind":"post","text":"public post"},{"id":"x-mention","platform":"x","kind":"mention","text":"public mention"},{"id":"x-dm","platform":"x","kind":"message","text":"private dm"},{"id":"slack-1","platform":"slack","kind":"message","text":"private slack"},{"id":"slack-conn","platform":"slack","kind":"connection","text":"connection state"},{"id":"ig-post","platform":"instagram","kind":"post","text":"public media"}],"connections":[]}');
      const filtered = socialHubPrivateItems(parsed.items);

      expect(filtered.length).assertEqual(2);
      expect(filtered[0].id).assertEqual('x-dm');
      expect(filtered[1].id).assertEqual('slack-1');
    });

    it('fails closed when the bridge is missing', 0, () => {
      const feed = socialHubBridgeUnavailableFeed('connect ECONNREFUSED');
      const draft = socialHubBridgeDraftError('x-1', 'x', 'connect ECONNREFUSED');

      expect(feed.items.length).assertEqual(0);
      expect(feed.connections.length).assertEqual(3);
      expect(feed.connections[0].status).assertEqual('error');
      expect(feed.connections[0].message.indexOf('connect ECONNREFUSED')).assertLarger(-1);
      expect(draft.itemId).assertEqual('x-1');
      expect(draft.status).assertEqual('error');
      expect(draft.localOnly).assertTrue();
      expect(draft.sent).assertFalse();
    });

    it('adds the gateway API key header only when configured', 0, () => {
      const missing = socialHubBridgeHeaders('');
      const present = socialHubBridgeHeaders(' secret ');

      expect(Object.keys(missing).indexOf('X-API-Key')).assertEqual(-1);
      expect(present['X-API-Key']).assertEqual('secret');
      expect(present['Accept']).assertEqual('application/json');
    });

    it('keeps aggregate X public post prompts as keyword searches', 0, () => {
      expect(xSearchQuery('X 公开 post 搜索关键词: openai codex', '')).assertEqual('openai codex');
      expect(xSearchQuery('帮我搜索 X 上 openai 最近的公开 post', '')).assertEqual('from:openai');
    });

    it('maps real community payloads and preserves provider failures', 0, () => {
      const reddit = parseComposioCommunityFeed(
        'reddit',
        '{"data":{"children":[{"data":{"name":"t3_real","title":"Real Reddit post",' +
          '"author":"dev_user","selftext":"Real discussion",' +
          '"subreddit_name_prefixed":"r/OpenAI","permalink":"/r/OpenAI/comments/real"}}]}}'
      );
      const failed = parseComposioCommunityFeed(
        'reddit',
        '{"data":null,"error":{"message":"Reddit account is not connected"}}'
      );
      const unsuccessful = parseComposioCommunityFeed(
        'reddit',
        '{"successful":false,"data":null,"error":null}'
      );

      expect(reddit.items.length).assertEqual(1);
      expect(reddit.items[0].id).assertEqual('t3_real');
      expect(reddit.items[0].text).assertContain('Real discussion');
      expect(failed.items.length).assertEqual(0);
      expect(failed.connections[0].status).assertEqual('error');
      expect(failed.connections[0].message).assertEqual('Reddit account is not connected');
      expect(unsuccessful.items.length).assertEqual(0);
      expect(unsuccessful.connections[0].status).assertEqual('error');
      expect(unsuccessful.connections[0].message).assertEqual(
        'Provider returned an unsuccessful execution status.'
      );
    });

    it('creates a preview only for one real provider identity', 0, () => {
      const preview = createSocialHubPublicationPreview({
        platform: 'x',
        operation: 'publish',
        accountId: 'x-real',
        accountName: '@real',
        text: 'Appless preview'
      }, '2026-07-18T02:00:00.000Z');
      const missingIdentity = createSocialHubPublicationPreview({
        platform: 'x',
        operation: 'publish',
        text: 'Appless preview'
      });

      expect(preview.status).assertEqual('preview');
      expect(preview.accountName).assertEqual('@real');
      expect(missingIdentity.status).assertEqual('error');
      expect(missingIdentity.error.indexOf('真实账号 ID')).assertLarger(-1);
    });

    it('parses real Composio social message payloads without turning errors into messages', 0, () => {
      const x = parseComposioSocialFeed(
        'x',
        '{"data":{"data":[{"id":"dm-in","event_type":"MessageCreate","text":"Can we move the demo?","sender_id":"user-2","dm_conversation_id":"dm-1","created_at":"2026-07-17T01:00:00.000Z"},{"id":"dm-out","event_type":"MessageCreate","text":"Sure","sender_id":"user-me","dm_conversation_id":"dm-1","created_at":"2026-07-17T01:05:00.000Z"}],"includes":{"users":[{"id":"user-me","name":"Me","username":"me"},{"id":"user-2","name":"Ada","username":"ada"}]}},"error":null}',
        '',
        'user-me'
      );
      expect(x.items.length).assertEqual(1);
      expect(x.items[0].author).assertEqual('Ada');
      expect(x.items[0].handle).assertEqual('@ada');
      expect(x.items[0].text).assertEqual('Can we move the demo?');

      const slack = parseComposioSocialFeed(
        'slack',
        '{"data":{"messages":{"matches":[{"iid":"slack-dm","ts":"1784250000.000100","channel":{"id":"D123","name":"Ada"},"username":"Ada","text":"Please review the launch copy","permalink":"https://workspace.slack.com/archives/D123/p1784250000000100"},{"iid":"slack-channel","ts":"1784250001.000100","channel":{"id":"C123","name":"general"},"username":"Bob","text":"public channel","permalink":"https://workspace.slack.com/archives/C123/p1784250001000100"}]}},"error":null}'
      );
      expect(slack.items.length).assertEqual(1);
      expect(slack.items[0].id).assertEqual('slack-dm');
      expect(slack.items[0].channelId).assertEqual('D123');

      const instagram = parseComposioSocialFeed(
        'instagram',
        '{"data":{"data":[{"id":"ig-in","created_time":"2026-07-17T02:00:00.000Z","from":{"id":"ig-ada","username":"ada"},"message":"Is the prototype ready?","to":{"data":[{"id":"ig-me"}]}},{"id":"ig-out","created_time":"2026-07-17T02:05:00.000Z","from":{"id":"ig-me","username":"me"},"message":"Almost","to":{"data":[{"id":"ig-ada"}]}}]},"error":null}',
        'conversation-1',
        'ig-me'
      );
      expect(instagram.items.length).assertEqual(1);
      expect(instagram.items[0].author).assertEqual('ada');
      expect(instagram.items[0].threadId).assertEqual('conversation-1');

      const failed = parseComposioSocialFeed(
        'whatsapp',
        '{"data":null,"error":{"message":"Account not registered"}}'
      );
      expect(failed.items.length).assertEqual(0);
      expect(failed.connections[0].status).assertEqual('error');
      expect(failed.connections[0].message).assertEqual('Account not registered');
    });

    it('does not send X replies through the legacy direct OAuth path', 0, async () => {
      const feed = parseSocialHubFeedPayload('{"items":[{"id":"x-dm","platform":"x","kind":"message","text":"hello","channel":"私信","channelId":"dm-1","threadId":"dm-1"}],"connections":[]}');
      const draft = await new SocialHubClient().sendReply(feed.items[0], '收到');

      expect(draft.status).assertEqual('error');
      expect(draft.error.indexOf('Composio')).assertLarger(-1);
      expect(draft.error.indexOf('X OAuth')).assertEqual(-1);
      expect(draft.sent).assertFalse();
    });

    it('fails closed on every legacy direct X and Slack entry point', 0, async () => {
      const client = new SocialHubClient();
      const legacyConfig: SocialHubProviderConfig = {
        xBearerToken: 'legacy-x-bearer',
        xUsername: 'legacy-user',
        xUserAccessToken: 'legacy-x-user',
        slackUserToken: 'legacy-slack-user',
        slackBotToken: 'legacy-slack-bot'
      };
      const feed = await client.feed('查看 X 和 Slack 消息', '', legacyConfig);
      const xPosts = await client.xPostSearch('X 公开 post 搜索关键词: codex', '', legacyConfig);
      const slackItem = parseSocialHubFeedPayload('{"items":[{"id":"slack-1","platform":"slack","kind":"message","text":"hello","channel":"general","channelId":"C123","threadId":"123.456"}],"connections":[]}').items[0];
      const reply = await client.sendReply(slackItem, '收到', '', legacyConfig);

      expect(feed.items.length).assertEqual(0);
      expect(feed.connections[0].message.indexOf('Composio')).assertLarger(-1);
      expect(feed.connections[1].message.indexOf('Composio')).assertLarger(-1);
      expect(xPosts.items.length).assertEqual(0);
      expect(xPosts.connections[0].message.indexOf('Composio')).assertLarger(-1);
      expect(reply.status).assertEqual('error');
      expect(reply.error.indexOf('Composio')).assertLarger(-1);
      expect(reply.sent).assertFalse();
    });
  });
}
