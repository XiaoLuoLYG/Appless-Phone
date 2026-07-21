import { describe, it, expect } from '@ohos/hypium';
import { resolveData } from '@loop/agent-core';
import { parseA2uiJsonl } from '@loop/agent-core';
import { A2uiSurfaceStore } from '@loop/agent-core';
import { SocialHubConnectionData, SocialHubDraftData, SocialHubItemData } from '@loop/agent-core';
import {
  SocialHubStructuredData,
  socialHubDraftA2ui,
  socialHubFeedA2ui,
  socialHubStructuredDataA2ui,
  socialHubStructuredDataResult
} from '@loop/agent-core';

function applyJsonl(jsonl: string): A2uiSurfaceStore {
  const parsed = parseA2uiJsonl(jsonl);
  const store = new A2uiSurfaceStore();
  expect(parsed.error).assertEqual('');
  parsed.envelopes.forEach(envelope => {
    expect(store.apply(envelope).error).assertEqual('');
  });
  return store;
}

export default function socialHubA2uiTest() {
  describe('socialHubA2ui', () => {
    it('renders feed into SocialHub data paths', 0, () => {
      const items: SocialHubItemData[] = [{
        id: 'x-1',
        platform: 'x',
        kind: 'message',
        author: 'OpenAI',
        handle: '@openai',
        text: 'Hello',
        timestamp: '2026-07-01T01:00:00.000Z',
        url: 'https://x.com/openai/status/1',
        mediaUrl: '',
        channel: '',
        channelId: '',
        threadId: '',
        unread: false
      }];
      const connections: SocialHubConnectionData[] = [{
        platform: 'slack',
        status: 'needs_auth',
        displayName: 'Slack',
        accountId: '',
        message: 'Slack OAuth required'
      }];
      const store = applyJsonl(socialHubFeedA2ui('surface_social_hub', items, connections));
      const parsedItems = resolveData(store.getSurface(), '/socialHub/items') as SocialHubItemData[];
      const selected = resolveData(store.getSurface(), '/socialHub/selected') as SocialHubItemData;
      const parsedConnections = resolveData(store.getSurface(), '/socialHub/connections') as SocialHubConnectionData[];

      expect(store.getSurface().intent).assertEqual('social');
      expect(store.getSurface().components[1].component).assertEqual('SocialHub');
      expect(parsedItems.length).assertEqual(1);
      expect(parsedItems[0].text).assertEqual('Hello');
      expect(selected.id).assertEqual('x-1');
      expect(parsedConnections[0].message).assertEqual('Slack OAuth required');
    });

    it('does not write public posts into SocialHub data paths', 0, () => {
      const items: SocialHubItemData[] = [{
        id: 'x-post',
        platform: 'x',
        kind: 'post',
        author: 'OpenAI',
        handle: '@openai',
        text: 'public',
        timestamp: '2026-07-01T01:00:00.000Z',
        url: 'https://x.com/openai/status/1',
        mediaUrl: '',
        channel: '',
        channelId: '',
        threadId: '',
        unread: false
      }];
      const store = applyJsonl(socialHubFeedA2ui('surface_social_hub', items, []));
      const parsedItems = resolveData(store.getSurface(), '/socialHub/items') as SocialHubItemData[];

      expect(parsedItems.length).assertEqual(0);
    });

    it('renders drafts as local unsent SocialHub state', 0, () => {
      const draft: SocialHubDraftData = {
        itemId: 'x-1',
        platform: 'x',
        text: 'Thanks for sharing.',
        status: 'draft',
        error: '',
        localOnly: true,
        sent: false
      };
      const jsonl = socialHubDraftA2ui('surface_social_hub', draft);
      const store = applyJsonl(jsonl);
      const parsedDraft = resolveData(store.getSurface(), '/socialHub/draft') as SocialHubDraftData;

      expect(parsedDraft.text).assertEqual('Thanks for sharing.');
      expect(parsedDraft.localOnly).assertTrue();
      expect(parsedDraft.sent).assertFalse();
    });

    it('keeps typed SocialHub items and connections in structured data and renderer actions', 0, () => {
      const items: SocialHubItemData[] = [{
        id: 'slack-message-1', platform: 'slack', kind: 'message', author: 'Alice', handle: 'alice',
        text: 'Please review', timestamp: '2026-07-22T01:00:00.000Z', url: '', mediaUrl: '',
        channel: 'agents', channelId: 'C123', threadId: '1780000000.001', unread: true
      }];
      const connections: SocialHubConnectionData[] = [
        { platform: 'slack', status: 'connected', displayName: 'Slack', accountId: 'acct-1', message: 'Connected' },
        { platform: 'x', status: 'error', displayName: 'X', accountId: '', message: 'X provider failed' }
      ];
      const result = socialHubStructuredDataResult({ items: items, connections: connections });
      const data = result.data as SocialHubStructuredData;
      const jsonl = socialHubStructuredDataA2ui('surface_social_structured', data);

      expect(result.status).assertEqual('partial');
      expect(data.items[0].id).assertEqual('slack-message-1');
      expect(data.connections[0].accountId).assertEqual('acct-1');
      expect(jsonl.indexOf('slack-message-1')).assertLarger(-1);
      expect(jsonl.indexOf('1780000000.001')).assertLarger(-1);
      expect(JSON.stringify(result.data).indexOf('updateComponents')).assertEqual(-1);
    });

    it('distinguishes successful empty SocialHub feeds from all-provider errors', 0, () => {
      const empty = socialHubStructuredDataResult({
        items: [],
        connections: [{ platform: 'slack', status: 'connected', displayName: 'Slack', accountId: 'acct-1', message: '0 messages' }]
      });
      const failed = socialHubStructuredDataResult({
        items: [],
        connections: [{ platform: 'slack', status: 'error', displayName: 'Slack', accountId: '', message: 'provider unavailable' }]
      });

      expect(empty.status).assertEqual('empty');
      expect(failed.status).assertEqual('error');
      expect(failed.error?.code).assertEqual('SOCIAL_PROVIDERS_FAILED');
    });

    it('rejects limited-only SocialHub reads without inventing provider sources', 0, () => {
      const result = socialHubStructuredDataResult({
        items: [],
        connections: [
          { platform: 'whatsapp', status: 'limited', displayName: 'WhatsApp', accountId: '', message: 'Inbox reads unsupported' },
          { platform: 'discord', status: 'limited', displayName: 'Discord', accountId: '', message: 'Message reads unsupported' }
        ]
      });

      expect(result.status).assertEqual('error');
      expect(result.error?.code).assertEqual('SOCIAL_SOURCES_UNSUPPORTED');
      expect(result.sources.length).assertEqual(0);
      expect(result.warnings.length).assertEqual(2);
    });

    it('uses partial only for real social data plus a limited source', 0, () => {
      const items: SocialHubItemData[] = [{
        id: 'slack-real-1', platform: 'slack', kind: 'message', author: 'Alice', handle: 'alice',
        text: 'Real provider message', timestamp: '2026-07-22T02:00:00.000Z', url: '', mediaUrl: '',
        channel: 'agents', channelId: 'C123', threadId: 'thread-1', unread: true
      }];
      const result = socialHubStructuredDataResult({
        items: items,
        connections: [
          { platform: 'slack', status: 'connected', displayName: 'Slack', accountId: 'acct-1', message: '1 message' },
          { platform: 'linkedin', status: 'limited', displayName: 'LinkedIn', accountId: '', message: 'DM reads unsupported' }
        ]
      });

      expect(result.status).assertEqual('partial');
      expect(result.sources.length).assertEqual(1);
      expect(result.sources[0].provider).assertEqual('Slack');
      expect(result.warnings.length).assertEqual(1);
    });

    it('keeps supported empty plus limited as empty with a warning', 0, () => {
      const result = socialHubStructuredDataResult({
        items: [],
        connections: [
          { platform: 'slack', status: 'connected', displayName: 'Slack', accountId: 'acct-1', message: '0 messages' },
          { platform: 'whatsapp', status: 'limited', displayName: 'WhatsApp', accountId: '', message: 'Inbox reads unsupported' }
        ]
      });

      expect(result.status).assertEqual('empty');
      expect(result.sources.length).assertEqual(1);
      expect(result.sources[0].provider).assertEqual('Slack');
      expect(result.warnings.length).assertEqual(1);
      expect(result.warnings[0].indexOf('WhatsApp')).assertLarger(-1);
    });
  });
}
