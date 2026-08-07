import { HandlerRegistry } from '../../registry/HandlerRegistry';
import { HandlerBackedBackend } from '../transport/HandlerBackedBackend';

export class WorkspaceMcpBackend extends HandlerBackedBackend {
  constructor(handlers: HandlerRegistry) {
    super('workspace_mcp', handlers);
  }
}
