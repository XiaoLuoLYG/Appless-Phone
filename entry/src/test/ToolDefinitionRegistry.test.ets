import { describe, it, expect } from '@ohos/hypium';
import {
  GMAIL_TOOL_IDS,
  allToolDefinitions,
  backendLabel,
  isGmailToolId,
  isKnownDomainToolId,
  isLocalAdapterToolId,
  resolveBackendForTool,
  toolDefinitionForToolId
} from '../main/ets/model/ToolDefinitionRegistry';
import { BackendAvailability, BackendResolution, ToolBackendType, ToolDefinition } from '../main/ets/model/ToolDefinitionTypes';

function availability(
  backend: ToolBackendType,
  available: boolean,
  reason: string,
  accountHint: string
): BackendAvailability {
  return {
    backend: backend,
    available: available,
    reason: reason,
    accountHint: accountHint
  };
}

export default function toolDefinitionRegistryTest() {
  describe('toolDefinitionRegistry', () => {
    it('recognizes existing local adapters and Gmail tools through one registry', 0, () => {
      expect(isKnownDomainToolId('travel.search')).assertTrue();
      expect(isKnownDomainToolId('food.search')).assertTrue();
      expect(isKnownDomainToolId('social.reply.send')).assertTrue();
      expect(isKnownDomainToolId('gmail.mail.search')).assertTrue();
      expect(isKnownDomainToolId('gmail.thread.read')).assertTrue();
      expect(isKnownDomainToolId('gmail.draft.create')).assertTrue();
      expect(isKnownDomainToolId('gmail.draft.apply')).assertTrue();
      expect(isKnownDomainToolId('gmail.open.web')).assertTrue();
      expect(isKnownDomainToolId('gmail.message.send')).assertTrue();
      expect(isKnownDomainToolId('gmail.unknown')).assertFalse();

      expect(isLocalAdapterToolId('travel.search')).assertTrue();
      expect(isLocalAdapterToolId('gmail.mail.search')).assertFalse();
      expect(isGmailToolId('gmail.mail.search')).assertTrue();
      expect(isGmailToolId('food.search')).assertFalse();
    });

    it('keeps Gmail definitions declarative and direct send blocked', 0, () => {
      const mailSearch = toolDefinitionForToolId('gmail.mail.search') as ToolDefinition;
      const draftApply = toolDefinitionForToolId('gmail.draft.apply') as ToolDefinition;
      const messageSend = toolDefinitionForToolId('gmail.message.send') as ToolDefinition;

      expect(mailSearch.domain).assertEqual('gmail');
      expect(mailSearch.riskLevel).assertEqual('read');
      expect(mailSearch.backendPriority.join(',')).assertEqual('oauth_api,workspace_mcp,web_session');
      expect(mailSearch.authModes.join(',')).assertEqual('oauth,mcp_auth,web_session');
      expect(mailSearch.outputSchema).assertEqual('mailThreads');
      expect(mailSearch.a2uiComponent).assertEqual('GenericToolResults');
      expect(draftApply.riskLevel).assertEqual('confirm_required');
      expect(messageSend.riskLevel).assertEqual('blocked');
      expect(messageSend.outputSchema).assertEqual('blockedAction');
      expect(GMAIL_TOOL_IDS.indexOf('gmail.message.send') >= 0).assertTrue();
    });

    it('resolves available Gmail backends before returning an auth-needed reason', 0, () => {
      const webFallback: BackendResolution = resolveBackendForTool('gmail.mail.search', [
        availability('oauth_api', false, 'OAuth API sign-in is required.', 'u***@gmail.com'),
        availability('workspace_mcp', false, 'Workspace MCP auth is required.', ''),
        availability('web_session', true, '', 'browser-session')
      ] as BackendAvailability[]);

      expect(webFallback.ok).assertTrue();
      expect(webFallback.backend).assertEqual('web_session');
      expect(webFallback.accountHint).assertEqual('browser-session');

      const missing: BackendResolution = resolveBackendForTool('gmail.mail.search', [
        availability('oauth_api', false, 'OAuth API sign-in is required.', 'u***@gmail.com'),
        availability('web_session', false, 'Gmail Web session is not connected.', '')
      ] as BackendAvailability[]);

      expect(missing.ok).assertFalse();
      expect(missing.backend).assertEqual('oauth_api');
      expect(missing.reason).assertEqual('OAuth API sign-in is required.');
      expect(missing.accountHint).assertEqual('u***@gmail.com');
    });

    it('clones definitions and labels runner types stably', 0, () => {
      const definitions: ToolDefinition[] = allToolDefinitions();
      definitions[0].toolId = 'mutated.tool';
      definitions[0].backendPriority.push('web_session');

      const fresh: ToolDefinition[] = allToolDefinitions();
      expect(fresh[0].toolId).assertEqual('travel.search');
      expect(fresh[0].backendPriority.join(',')).assertEqual('local_adapter');
      expect(backendLabel('local_adapter')).assertEqual('Local adapter');
      expect(backendLabel('oauth_api')).assertEqual('OAuth API');
      expect(backendLabel('workspace_mcp')).assertEqual('Workspace MCP');
      expect(backendLabel('web_session')).assertEqual('Web session');
      expect(backendLabel('system_intent')).assertEqual('System intent');
      expect(backendLabel('mcp_remote')).assertEqual('Remote MCP');
    });
  });
}
