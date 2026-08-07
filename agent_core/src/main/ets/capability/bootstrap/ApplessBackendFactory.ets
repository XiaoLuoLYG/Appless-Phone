import { ImapBackend } from '../backends/imap/ImapBackend';
import { LocalHandlerBackend } from '../backends/local/LocalHandlerBackend';
import { McpBackend } from '../backends/mcp/McpBackend';
import { WorkspaceMcpBackend } from '../backends/mcp/WorkspaceMcpBackend';
import { OAuthApiBackend } from '../backends/oauth/OAuthApiBackend';
import { RemoteGatewayBackend } from '../backends/remote_gateway/RemoteGatewayBackend';
import { SystemIntentBackend } from '../backends/system/SystemIntentBackend';
import { WebSessionBackend } from '../backends/web_session/WebSessionBackend';
import { CapabilityRegistry } from '../registry/CapabilityRegistry';
import { ToolResolver } from '../runtime/ToolResolver';

export class ApplessBackendFactory {
  static create(registry: CapabilityRegistry): ToolResolver {
    const resolver = new ToolResolver();
    resolver.register(new LocalHandlerBackend(registry.handlers));
    resolver.register(new OAuthApiBackend(registry.handlers));
    resolver.register(new ImapBackend(registry.handlers));
    resolver.register(new WorkspaceMcpBackend(registry.handlers));
    resolver.register(new McpBackend(registry.handlers));
    resolver.register(new SystemIntentBackend(registry.handlers));
    resolver.register(new WebSessionBackend(registry.handlers));
    resolver.register(new RemoteGatewayBackend(registry.handlers));
    return resolver;
  }
}
