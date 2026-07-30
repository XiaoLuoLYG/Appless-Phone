import {
  ActionArgsValidator,
  ToolDefinitionLookup
} from '../ActionCatalogTypes';
import {
  ActionOffer,
  ActionOfferContext
} from '../ActionOfferTypes';
import { DataResult } from '../../message/DataResult';
import {
  SourceOfferContract,
  SourceOfferHandler
} from './SourceOfferHandler';
import { ActionOfferFactory } from './ActionOfferFactory';

function contractKey(toolId: string, outputSchema: string): string {
  return toolId + '\u0000' + outputSchema;
}

function supportedStatus(data: DataResult): boolean {
  return data.status === 'success' || data.status === 'partial';
}

export class ActionOfferResolverRouter {
  private readonly definitions: ToolDefinitionLookup;
  private readonly factory: ActionOfferFactory;
  private readonly handlers: Map<string, SourceOfferHandler> =
    new Map<string, SourceOfferHandler>();

  constructor(
    definitions: ToolDefinitionLookup,
    validator: ActionArgsValidator
  ) {
    this.definitions = definitions;
    this.factory = new ActionOfferFactory(validator);
  }

  register(handler: SourceOfferHandler): void {
    const contract: SourceOfferContract = handler.contract();
    const toolId = contract.toolId.trim();
    const outputSchema = contract.outputSchema.trim();
    if (toolId.length === 0 || outputSchema.length === 0) {
      throw new Error('Source offer handler contract must be non-empty.');
    }
    const key = contractKey(toolId, outputSchema);
    if (this.handlers.has(key)) {
      throw new Error(
        'Duplicate source offer handler: ' + toolId + ' + ' + outputSchema + '.'
      );
    }
    this.handlers.set(key, handler);
  }

  async resolve(
    data: DataResult,
    context: ActionOfferContext
  ): Promise<ActionOffer[]> {
    if (!supportedStatus(data)) {
      return [];
    }
    const definition = this.definitions.find(data.toolId);
    if (definition === null || definition.outputSchema !== data.outputSchema) {
      return [];
    }
    const handler = this.handlers.get(
      contractKey(data.toolId, data.outputSchema)
    );
    if (handler === undefined) {
      return [];
    }
    try {
      const candidates = handler.project(data, definition.actions.slice());
      return this.factory.createAll(candidates, context);
    } catch (_error) {
      return [];
    }
  }
}
