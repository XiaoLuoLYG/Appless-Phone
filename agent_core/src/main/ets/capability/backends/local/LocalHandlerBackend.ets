import { HandlerRegistry } from '../../registry/HandlerRegistry';
import { HandlerBackedBackend } from '../transport/HandlerBackedBackend';

export class LocalHandlerBackend extends HandlerBackedBackend {
  constructor(handlers: HandlerRegistry) {
    super('local_adapter', handlers);
  }
}
