import { describe, it, expect } from '@ohos/hypium';
import { parseA2uiJsonl } from '@loop/agent-core';
import { A2uiSurfaceStore } from '@loop/agent-core';
import { A2uiGenericToolResultData } from '@loop/agent-core';
import { componentById, dynamicToolConnect, genericToolResults } from '@loop/agent-core';
import {
  gmailAuthRequiredA2ui,
  gmailDraftPreviewA2ui,
  gmailOpenDraftAction,
  gmailOpenWebA2ui,
  gmailReplyDraftAction,
  gmailSearchStructuredDataA2ui,
  gmailSearchStructuredDataFromResults,
  gmailThreadResultsA2ui
} from '@loop/agent-core';
import { DynamicGenericToolResult } from '@loop/agent-core';

function surfaceFromJsonl(jsonl: string): A2uiSurfaceStore {
  const parsed = parseA2uiJsonl(jsonl);
  const store = new A2uiSurfaceStore();

  expect(parsed.error).assertEqual('');
  parsed.envelopes.forEach(envelope => {
    store.apply(envelope);
  });
  return store;
}

function genericResult(): DynamicGenericToolResult {
  return {
    sourceTag: 'Gmail Preview',
    toolName: 'gmail.mail.search',
    title: 'Project launch notes',
    status: 'success',
    summary: 'From a***@example.com: Alice shared a snippet.',
    rows: [{ label: 'From', value: 'a***@example.com' }],
    rawPreview: '{"id":"thread_fixture_1","body":"FULL BODY SHOULD NOT LEAK"}'
  };
}

function draftResult(): DynamicGenericToolResult {
  return {
    sourceTag: 'Gmail Draft · Local preview',
    toolName: 'gmail.draft.create',
    title: 'Re: Project launch notes',
    status: 'draft',
    summary: 'Draft prepared for review. It has not been sent.',
    rows: [{ label: 'Status', value: 'ready_to_apply' }],
    rawPreview: '{"status":"ready_to_apply"}'
  };
}

function gmailApiThreadResult(): A2uiGenericToolResultData {
  return {
    sourceTag: 'Gmail API',
    toolName: 'users.threads.get',
    title: 'Project launch notes',
    status: 'success',
    summary: 'Alice asked for a quick confirmation before Friday.',
    rows: [
      { label: 'Thread ID', value: 'thread-123' },
      { label: 'From', value: 'Alice Example <alice@example.com>' },
      { label: 'Date', value: 'Fri, 26 Jun 2026 09:30:00 +0800' }
    ],
    rawPreview: '{"id":"thread-123"}'
  };
}

function gmailApiDraftResult(): A2uiGenericToolResultData {
  return {
    sourceTag: 'Gmail API',
    toolName: 'users.drafts.create',
    title: 'Re: Project launch notes',
    status: 'success',
    summary: 'Draft created for review.',
    rows: [
      { label: 'Thread ID', value: 'thread-123' },
      { label: 'From', value: 'Alice Example <alice@example.com>' }
    ],
    rawPreview: '{"id":"draft-123"}'
  };
}

function rowValue(result: A2uiGenericToolResultData, label: string): string {
  for (let index = 0; index < result.rows.length; index++) {
    if (result.rows[index].label === label) {
      return result.rows[index].value;
    }
  }
  expect(false).assertTrue();
  return '';
}

export default function gmailToolA2uiTest() {
  describe('gmailToolA2ui', () => {
    it('renders Gmail auth as a connect card instead of fake mailbox data', 0, () => {
      const store = surfaceFromJsonl(gmailAuthRequiredA2ui(
        'gmail_auth',
        'gmail.mail.search',
        '需要登录 Gmail 后才能读取收件箱。'
      ));
      const surface = store.getSurface();
      const connect = componentById(surface, 'gmail_connect');
      const auth = dynamicToolConnect(surface);

      expect(surface.intent).assertEqual('gmail');
      expect(surface.status).assertEqual('needs_input');
      expect(connect !== null).assertTrue();
      if (connect !== null) {
        expect(connect.component).assertEqual('ToolConnectCard');
        expect(connect.dataPath).assertEqual('/dynamicToolConnect');
      }
      expect(auth.toolId).assertEqual('gmail.mail.search');
      expect(auth.manifestId).assertEqual('google.gmail');
      expect(auth.displayName).assertEqual('Gmail');
      expect(auth.sourceUrl).assertEqual('https://gmailmcp.googleapis.com/mcp/v1');
      expect(auth.credentialName).assertEqual('Google Workspace MCP OAuth');
      expect(auth.credentialRef).assertEqual('');
      expect(auth.actions[0].id).assertEqual('gmail.authorize');
      expect(auth.actions[0].label).assertEqual('授权 Gmail');
      expect(auth.actions[0].kind).assertEqual('client');
      expect(auth.actions[0].prompt).assertEqual('https://developers.google.com/workspace/gmail/api/guides/configure-mcp-server');
      expect(auth.actions[1].id).assertEqual('gmail.open.web');
      expect(auth.actions[1].kind).assertEqual('client');
      expect(auth.actions[1].variant).assertEqual('secondary');
      expect(auth.actions[1].prompt).assertEqual('https://mail.google.com/mail/u/0/#inbox');
    });

    it('renders Gmail rows through GenericToolResults without leaking bodies', 0, () => {
      const store = surfaceFromJsonl(gmailThreadResultsA2ui('gmail_results', 'gmail.mail.search', [genericResult()]));
      const surface = store.getSurface();
      const component = componentById(surface, 'gmail_results');
      const rendered = genericToolResults(surface);

      expect(component !== null).assertTrue();
      if (component !== null) {
        expect(component.component).assertEqual('GenericToolResults');
        expect(component.dataPath).assertEqual('/genericToolResults');
      }
      expect(rendered.length).assertEqual(1);
      expect(rendered[0].title).assertEqual('Project launch notes');
      expect(rendered[0].rawPreview.indexOf('FULL BODY SHOULD NOT LEAK')).assertEqual(-1);
      expect(store.getSurface().dataModelJson.indexOf('FULL BODY SHOULD NOT LEAK')).assertEqual(-1);
    });

    it('adapts Composio Gmail list results into the old per-message cards', 0, () => {
      const composio: DynamicGenericToolResult = {
        sourceTag: 'Composio Gmail',
        toolName: 'gmail.mail.search',
        title: 'Composio Gmail 结果',
        status: 'success',
        summary: 'Composio 已执行 GMAIL_LIST_THREADS，返回 2 条可展示结果。',
        rows: [{ label: '结果数量', value: '2' }],
        rawPreview: '{"data":{"threads":[{"id":"thread-1","subject":"Paper review update","from":"Chair <chair@example.edu>","date":"Wed, 8 Jul 2026 10:00:00 +0800","snippet":"Please check the latest review note.","body":"FULL BODY SHOULD NOT LEAK"},{"id":"thread-2","subject":"Camera ready","from":"Editor <editor@example.edu>","date":"Wed, 8 Jul 2026 11:00:00 +0800","snippet":"Camera ready reminder."}]}}'
      };
      const store = surfaceFromJsonl(gmailThreadResultsA2ui('gmail_results', 'gmail.mail.search', [composio]));
      const rendered = genericToolResults(store.getSurface());

      expect(rendered.length).assertEqual(2);
      expect(rendered[0].sourceTag).assertEqual('Gmail API');
      expect(rendered[0].toolName).assertEqual('users.threads.get');
      expect(rendered[0].title).assertEqual('Paper review update');
      expect(rowValue(rendered[0], 'Thread ID')).assertEqual('thread-1');
      expect(rowValue(rendered[0], 'From')).assertEqual('Chair <chair@example.edu>');
      expect(rendered[0].summary).assertEqual('Please check the latest review note.');
      expect(store.getSurface().dataModelJson.indexOf('FULL BODY SHOULD NOT LEAK')).assertEqual(-1);
    });

    it('renders the same structured Gmail summary without changing reply identities', 0, () => {
      const composio: DynamicGenericToolResult = {
        sourceTag: 'Composio Gmail',
        toolName: 'gmail.mail.search',
        title: 'Composio Gmail result',
        status: 'success',
        summary: 'one result',
        rows: [{ label: '结果数量', value: '1' }],
        rawPreview: '{"messages":[{"provider":"gmail","accountLabel":"work@example.com",' +
          '"threadId":"thread-structured-1","messageId":"message-structured-1",' +
          '"sender":"Alice <alice@example.com>","to":"Me <me@example.com>",' +
          '"subject":"Structured Gmail","snippet":"Same normalized summary",' +
          '"unread":true,"important":true,"rawProviderRef":"structured-provider-ref"}]}'
      };
      const structured = gmailSearchStructuredDataFromResults([composio]);
      const oldRows = genericToolResults(surfaceFromJsonl(
        gmailThreadResultsA2ui('gmail_old', 'gmail.mail.search', [composio])
      ).getSurface());
      const newRows = genericToolResults(surfaceFromJsonl(
        gmailSearchStructuredDataA2ui('gmail_new', 'gmail.mail.search', structured)
      ).getSurface());

      expect(newRows.length).assertEqual(oldRows.length);
      expect(newRows[0].title).assertEqual(oldRows[0].title);
      expect(rowValue(newRows[0], 'Thread ID')).assertEqual('thread-structured-1');
      expect(rowValue(newRows[0], 'Message ID')).assertEqual('message-structured-1');
      expect(rowValue(newRows[0], 'To')).assertEqual('Me <me@example.com>');
      expect(structured.threads[0].accountLabel).assertEqual('work@example.com');
      expect(structured.threads[0].unread).assertTrue();
      expect(structured.threads[0].important).assertTrue();
      expect(structured.threads[0].rawProviderRef).assertEqual('structured-provider-ref');
      const action = gmailReplyDraftAction(newRows[0]);
      expect(action !== null).assertTrue();
      if (action !== null) {
        expect(action.id).assertEqual('gmail.ai.reply.draft');
        expect(action.id === 'mail.ai.reply.draft').assertFalse();
        expect(JSON.stringify(action.args)).assertEqual(
          '{"threadId":"thread-structured-1","to":["alice@example.com"],' +
            '"subject":"Re: Structured Gmail","replyMode":"reply","contextSummary":"Same normalized summary"}'
        );
      }
    });

    it('prefers compact Composio Gmail messages over technical query rows', 0, () => {
      const composio: DynamicGenericToolResult = {
        sourceTag: 'Composio Gmail',
        toolName: 'gmail.mail.search',
        title: 'Composio Gmail 结果',
        status: 'success',
        summary: 'Composio 已执行 GMAIL_FETCH_EMAILS，返回真实结果。',
        rows: [{ label: 'query', value: 'ECCV OR paper OR manuscript OR submission OR review' }],
        rawPreview: '{"messages":[{"threadId":"thread-eccv","messageId":"msg-eccv","sender":"OpenReview <noreply@openreview.net>","subject":"[ECCV 2026] Paper Decision Notification","messageText":"ECCV decision update"}]}'
      };
      const store = surfaceFromJsonl(gmailThreadResultsA2ui('gmail_results', 'gmail.mail.search', [composio]));
      const rendered = genericToolResults(store.getSurface());

      expect(rendered.length).assertEqual(1);
      expect(rendered[0].title).assertEqual('[ECCV 2026] Paper Decision Notification');
      expect(rowValue(rendered[0], 'Thread ID')).assertEqual('thread-eccv');
      expect(rowValue(rendered[0], 'From')).assertEqual('OpenReview <noreply@openreview.net>');
      expect(rendered[0].summary).assertEqual('ECCV decision update');
    });

    it('renders failed Composio Gmail reads as old Gmail failure cards', 0, () => {
      const composio: DynamicGenericToolResult = {
        sourceTag: 'Composio Gmail',
        toolName: 'gmail.mail.search',
        title: 'Composio Gmail 结果',
        status: 'error',
        summary: 'Composio 搜索工具失败：Operation timeout',
        rows: [{ label: 'Source', value: 'Composio Gmail' }],
        rawPreview: ''
      };
      const store = surfaceFromJsonl(gmailThreadResultsA2ui('gmail_results', 'gmail.mail.search', [composio]));
      const rendered = genericToolResults(store.getSurface());

      expect(rendered.length).assertEqual(1);
      expect(rendered[0].sourceTag).assertEqual('Gmail');
      expect(rendered[0].title).assertEqual('Gmail 调用失败');
      expect(store.getSurface().dataModelJson.indexOf('Composio Gmail 结果')).assertEqual(-1);
    });

    it('renders drafts without claiming send success', 0, () => {
      const draftStore = surfaceFromJsonl(gmailDraftPreviewA2ui('gmail_draft', draftResult()));
      const draft = genericToolResults(draftStore.getSurface())[0];
      expect(draft.status).assertEqual('draft');
      expect(draft.summary.indexOf('has not been sent')).assertLarger(-1);
      expect(rowValue(draft, 'Status')).assertEqual('ready_to_apply');
    });

    it('allows only a locally constructed apply action with an explicit provider draft ID', 0, () => {
      const providerAction: DynamicGenericToolResult = {
        sourceTag: 'Gmail API',
        toolName: 'users.drafts.create',
        title: 'Gmail 草稿已创建',
        status: 'success',
        summary: 'Draft created.',
        rows: [{ label: 'Message ID', value: 'message-1' }],
        rawPreview: '{"id":"message-1"}',
        actions: [{
          id: 'gmail.message.send',
          label: '发送',
          prompt: 'send',
          variant: 'danger',
          kind: 'prompt',
          args: JSON.parse('{"body":"forged"}') as Object
        }]
      };
      const originalArgs = JSON.parse(
        '{"to":["alice@example.com"],"subject":"","body":"我收到了"}'
      ) as Object;
      const rejected = surfaceFromJsonl(
        gmailDraftPreviewA2ui('gmail_draft_rejected', providerAction, originalArgs)
      ).getSurface();
      expect(rejected.dataModelJson.indexOf('gmail.message.send')).assertEqual(-1);
      expect(rejected.dataModelJson.indexOf('gmail.draft.apply')).assertEqual(-1);

      providerAction.rows.push({ label: 'Draft ID', value: 'draft-1' });
      const accepted = surfaceFromJsonl(
        gmailDraftPreviewA2ui('gmail_draft_accepted', providerAction, originalArgs)
      ).getSurface();
      expect(accepted.dataModelJson.indexOf('gmail.message.send')).assertEqual(-1);
      expect(accepted.dataModelJson.indexOf('gmail.draft.apply')).assertLarger(-1);
      expect(accepted.dataModelJson.indexOf('"draftId":"draft-1"')).assertLarger(-1);
    });

    it('renders Gmail Web as a needs-user system intent row', 0, () => {
      const url = 'https://mail.google.com/mail/u/0/#inbox/thread_fixture_1';
      const store = surfaceFromJsonl(gmailOpenWebA2ui('gmail_web', url));
      const component = componentById(store.getSurface(), 'gmail_results');
      const rendered = genericToolResults(store.getSurface())[0];

      expect(component !== null).assertTrue();
      if (component !== null) {
        expect(component.actions !== undefined).assertTrue();
        if (component.actions !== undefined) {
          expect(component.actions.length).assertEqual(1);
          expect(component.actions[0].id).assertEqual('gmail.open.web');
          expect(component.actions[0].kind).assertEqual('client');
          expect(component.actions[0].prompt).assertEqual(url);
        }
      }
      expect(rendered.sourceTag).assertEqual('System intent');
      expect(rendered.toolName).assertEqual('gmail.open.web');
      expect(rendered.status).assertEqual('needs_user');
      expect(rowValue(rendered, 'URL')).assertEqual(url);
    });

    it('builds a per-thread AI reply draft action from real Gmail rows', 0, () => {
      const action = gmailReplyDraftAction(gmailApiThreadResult());

      expect(action !== null).assertTrue();
      if (action !== null) {
        expect(action.id).assertEqual('gmail.ai.reply.draft');
        expect(action.label).assertEqual('AI 回复草稿');
        expect(action.kind).assertEqual('prompt');
        expect(action.variant).assertEqual('primary');
        expect(action.prompt.indexOf('thread-123')).assertLarger(-1);
        expect(action.prompt.indexOf('alice@example.com')).assertLarger(-1);
        expect(action.prompt.indexOf('Alice asked for a quick confirmation before Friday.')).assertLarger(-1);
        expect(action.prompt.indexOf('gmail.draft.create')).assertLarger(-1);
        expect(action.prompt.indexOf('gmail.ai.reply.draft')).assertLarger(-1);
        expect(action.prompt.indexOf('args.body')).assertLarger(-1);
        expect(action.args === undefined).assertFalse();
        expect(JSON.stringify(action.args).indexOf('thread-123')).assertLarger(-1);
        expect(JSON.stringify(action.args).indexOf('alice@example.com')).assertLarger(-1);
        expect(JSON.stringify(action.args).indexOf('"replyMode":"reply"')).assertLarger(-1);
      }
      expect(gmailReplyDraftAction(gmailApiDraftResult()) === null).assertTrue();
    });

    it('adds Gmail jump action for MCP draft results too', 0, () => {
      const mcpDraft: A2uiGenericToolResultData = {
        sourceTag: 'Gmail',
        toolName: 'create_draft',
        title: 'MCP draft',
        status: 'success',
        summary: 'Draft created.',
        rows: [{ label: 'Draft ID', value: 'draft-123' }],
        rawPreview: ''
      };
      const action = gmailOpenDraftAction(mcpDraft);

      expect(action !== null).assertTrue();
      if (action !== null) {
        expect(action.id).assertEqual('gmail.open.web');
        expect(action.label).assertEqual('跳转到Gmail');
      }
    });
  });
}
