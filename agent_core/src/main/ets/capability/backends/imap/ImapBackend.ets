import { HandlerRegistry } from '../../registry/HandlerRegistry';
import { HandlerBackedBackend } from '../transport/HandlerBackedBackend';

export class ImapBackend extends HandlerBackedBackend {
  constructor(handlers: HandlerRegistry) {
    super('imap', handlers);
  }
}
