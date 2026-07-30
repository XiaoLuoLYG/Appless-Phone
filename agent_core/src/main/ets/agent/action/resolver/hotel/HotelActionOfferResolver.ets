import { toolDefinitionForToolId } from '../../../../aiphone/runtime/ToolDefinitionRegistry';
import { ToolDefinition } from '../../../../aiphone/runtime/ToolDefinitionTypes';
import { validateHotelActionArgs } from '../../../../aiphone/runtime/HotelActions';
import {
  ActionArgsValidator,
  ActionValidationResult,
  ToolDefinitionLookup
} from '../../ActionCatalogTypes';
import { ActionOfferResolver } from '../../ActionOfferTypes';
import { ActionOfferResolverRouter } from '../ActionOfferResolverRouter';
import {
  HotelDetailOfferHandler,
  HotelSearchOfferHandler
} from './HotelOfferHandlers';

class RuntimeToolDefinitionLookup implements ToolDefinitionLookup {
  find(toolId: string): ToolDefinition | null {
    return toolDefinitionForToolId(toolId);
  }
}

class HotelActionArgsValidator implements ActionArgsValidator {
  validate(actionId: string, args: Object): ActionValidationResult {
    return validateHotelActionArgs(actionId, args);
  }
}

export function registerHotelOfferHandlers(
  router: ActionOfferResolverRouter
): void {
  router.register(new HotelSearchOfferHandler());
  router.register(new HotelDetailOfferHandler());
}

export function createHotelActionOfferResolver(
  definitions: ToolDefinitionLookup = new RuntimeToolDefinitionLookup(),
  validator: ActionArgsValidator = new HotelActionArgsValidator()
): ActionOfferResolver {
  const router = new ActionOfferResolverRouter(definitions, validator);
  registerHotelOfferHandlers(router);
  return async (data, context) => router.resolve(data, context);
}
