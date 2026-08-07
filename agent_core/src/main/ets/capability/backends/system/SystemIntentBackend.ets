import { HandlerRegistry } from '../../registry/HandlerRegistry';
import { HandlerBackedBackend } from '../transport/HandlerBackedBackend';

export class SystemIntentBackend extends HandlerBackedBackend {
  constructor(handlers: HandlerRegistry) {
    super('system_intent', handlers);
  }
}
