import { HandlerRegistry } from '../../registry/HandlerRegistry';
import { HandlerBackedBackend } from '../transport/HandlerBackedBackend';

export class WebSessionBackend extends HandlerBackedBackend {
  constructor(handlers: HandlerRegistry) {
    super('web_session', handlers);
  }
}
