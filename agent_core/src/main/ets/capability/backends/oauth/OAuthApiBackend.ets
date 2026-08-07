import { HandlerRegistry } from '../../registry/HandlerRegistry';
import { HandlerBackedBackend } from '../transport/HandlerBackedBackend';

export class OAuthApiBackend extends HandlerBackedBackend {
  constructor(handlers: HandlerRegistry) {
    super('oauth_api', handlers);
  }
}
