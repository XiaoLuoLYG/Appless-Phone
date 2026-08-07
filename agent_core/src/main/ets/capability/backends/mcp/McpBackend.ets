import { HandlerRegistry } from '../../registry/HandlerRegistry';
import { HandlerBackedBackend } from '../transport/HandlerBackedBackend';

export class McpBackend extends HandlerBackedBackend {
  constructor(handlers: HandlerRegistry) {
    super('mcp_remote', handlers);
  }
}
