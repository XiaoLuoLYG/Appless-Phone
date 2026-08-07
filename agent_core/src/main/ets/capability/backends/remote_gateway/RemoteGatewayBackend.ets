import { HandlerRegistry } from '../../registry/HandlerRegistry';
import { HandlerBackedBackend } from '../transport/HandlerBackedBackend';

export class RemoteGatewayBackend extends HandlerBackedBackend {
  constructor(handlers: HandlerRegistry) {
    super('remote_gateway', handlers);
  }
}
