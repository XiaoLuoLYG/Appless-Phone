import { ToolDefinitionLookup } from '../ActionCatalogTypes';
import { ActionJsonSchema } from './ActionJsonSchema';
import { ActionSchemaCatalog } from './ActionSchemaCatalog';
import {
  SchemaAwareActionDefinitionLookup
} from './SchemaAwareActionDefinition';

const REVISION: string = '1';

const STRING: ActionJsonSchema = { type: 'string' };
const REQUIRED_STRING: ActionJsonSchema = { type: 'string', minLength: 1 };
const POSITIVE_INTEGER: ActionJsonSchema = { type: 'integer', minimum: 1 };

function registerHotelNavigation(schemas: ActionSchemaCatalog): void {
  const inputProperties: Record<string, ActionJsonSchema> = {};
  inputProperties['hotelId'] = POSITIVE_INTEGER;
  inputProperties['name'] = REQUIRED_STRING;
  inputProperties['address'] = STRING;
  inputProperties['latitude'] =
    { type: 'number', minimum: -90, maximum: 90 };
  inputProperties['longitude'] =
    { type: 'number', minimum: -180, maximum: 180 };
  schemas.register({
    schemaId: 'hotelNavigateRequest',
    revision: REVISION,
    schema: {
      type: 'object',
      properties: inputProperties,
      required: ['hotelId', 'name', 'address', 'latitude', 'longitude'],
      additionalProperties: false
    }
  });

  const outputProperties: Record<string, ActionJsonSchema> = {};
  outputProperties['actionId'] =
    { type: 'string', enum: ['hotel.navigate'] };
  outputProperties['status'] = { type: 'string', enum: ['opened'] };
  outputProperties['uri'] = REQUIRED_STRING;
  outputProperties['message'] = REQUIRED_STRING;
  schemas.register({
    schemaId: 'systemIntentResult',
    revision: REVISION,
    schema: {
      type: 'object',
      properties: outputProperties,
      required: ['actionId', 'status', 'uri', 'message'],
      additionalProperties: false
    }
  });
}

function registerGmailDraft(schemas: ActionSchemaCatalog): void {
  const inputProperties: Record<string, ActionJsonSchema> = {};
  inputProperties['to'] = { type: 'array', items: REQUIRED_STRING };
  inputProperties['subject'] = STRING;
  inputProperties['body'] = REQUIRED_STRING;
  schemas.register({
    schemaId: 'draftCreateRequest',
    revision: REVISION,
    schema: {
      type: 'object',
      properties: inputProperties,
      required: ['to', 'body'],
      additionalProperties: false
    }
  });

  const outputProperties: Record<string, ActionJsonSchema> = {};
  outputProperties['actionId'] =
    { type: 'string', enum: ['gmail.draft.create'] };
  outputProperties['pageActionId'] = REQUIRED_STRING;
  outputProperties['conversationId'] = REQUIRED_STRING;
  outputProperties['turnId'] = REQUIRED_STRING;
  outputProperties['surfaceId'] = REQUIRED_STRING;
  outputProperties['status'] = REQUIRED_STRING;
  outputProperties['data'] =
    { type: 'object', additionalProperties: true };
  schemas.register({
    schemaId: 'draftReply',
    revision: REVISION,
    schema: {
      type: 'object',
      properties: outputProperties,
      required: [
        'actionId',
        'pageActionId',
        'conversationId',
        'turnId',
        'surfaceId',
        'status',
        'data'
      ],
      additionalProperties: false
    }
  });
}

function registerMapsRouteOpen(schemas: ActionSchemaCatalog): void {
  const inputProperties: Record<string, ActionJsonSchema> = {};
  inputProperties['origin'] = REQUIRED_STRING;
  inputProperties['destination'] = REQUIRED_STRING;
  inputProperties['travelMode'] = {
    type: 'string',
    enum: ['driving', 'walking', 'bicycling', 'transit', 'two-wheeler']
  };
  inputProperties['navigate'] = { type: 'boolean' };
  schemas.register({
    schemaId: 'mapsRouteOpenRequest',
    revision: REVISION,
    schema: {
      type: 'object',
      properties: inputProperties,
      required: ['origin', 'destination'],
      additionalProperties: false
    }
  });

  const genericResultProperties: Record<string, ActionJsonSchema> = {};
  genericResultProperties['toolName'] = {
    type: 'string',
    enum: ['maps.route.open']
  };
  genericResultProperties['status'] = REQUIRED_STRING;
  genericResultProperties['rawPreview'] = REQUIRED_STRING;
  const dataProperties: Record<string, ActionJsonSchema> = {};
  dataProperties['genericToolResults'] = {
    type: 'array',
    items: {
      type: 'object',
      properties: genericResultProperties,
      required: ['toolName', 'status', 'rawPreview'],
      additionalProperties: true
    }
  };
  const outputProperties: Record<string, ActionJsonSchema> = {};
  outputProperties['actionId'] =
    { type: 'string', enum: ['maps.route.open'] };
  outputProperties['pageActionId'] = REQUIRED_STRING;
  outputProperties['conversationId'] = REQUIRED_STRING;
  outputProperties['turnId'] = REQUIRED_STRING;
  outputProperties['surfaceId'] = REQUIRED_STRING;
  outputProperties['status'] = REQUIRED_STRING;
  outputProperties['data'] = {
    type: 'object',
    properties: dataProperties,
    required: ['genericToolResults'],
    additionalProperties: true
  };
  schemas.register({
    schemaId: 'mapsRouteOpenResult',
    revision: REVISION,
    schema: {
      type: 'object',
      properties: outputProperties,
      required: [
        'actionId',
        'pageActionId',
        'conversationId',
        'turnId',
        'surfaceId',
        'status',
        'data'
      ],
      additionalProperties: false
    }
  });
}

function registerSocialPostPreview(schemas: ActionSchemaCatalog): void {
  const inputProperties: Record<string, ActionJsonSchema> = {};
  inputProperties['platform'] = {
    type: 'string',
    enum: ['x', 'linkedin', 'instagram', 'reddit']
  };
  inputProperties['operation'] = {
    type: 'string',
    enum: ['publish']
  };
  inputProperties['text'] = REQUIRED_STRING;
  schemas.register({
    schemaId: 'socialPostPreviewRequest',
    revision: REVISION,
    schema: {
      type: 'object',
      properties: inputProperties,
      required: ['platform', 'operation', 'text'],
      additionalProperties: false
    }
  });

  const publicationProperties: Record<string, ActionJsonSchema> = {};
  publicationProperties['text'] = REQUIRED_STRING;
  const socialHubProperties: Record<string, ActionJsonSchema> = {};
  socialHubProperties['publication'] = {
    type: 'object',
    properties: publicationProperties,
    required: ['text'],
    additionalProperties: true
  };
  const dataProperties: Record<string, ActionJsonSchema> = {};
  dataProperties['socialHub'] = {
    type: 'object',
    properties: socialHubProperties,
    required: ['publication'],
    additionalProperties: true
  };
  const outputProperties: Record<string, ActionJsonSchema> = {};
  outputProperties['actionId'] =
    { type: 'string', enum: ['social.post.preview'] };
  outputProperties['pageActionId'] = REQUIRED_STRING;
  outputProperties['conversationId'] = REQUIRED_STRING;
  outputProperties['turnId'] = REQUIRED_STRING;
  outputProperties['surfaceId'] = REQUIRED_STRING;
  outputProperties['status'] = REQUIRED_STRING;
  outputProperties['data'] = {
    type: 'object',
    properties: dataProperties,
    required: ['socialHub'],
    additionalProperties: true
  };
  schemas.register({
    schemaId: 'socialHubPublication',
    revision: REVISION,
    schema: {
      type: 'object',
      properties: outputProperties,
      required: [
        'actionId',
        'pageActionId',
        'conversationId',
        'turnId',
        'surfaceId',
        'status',
        'data'
      ],
      additionalProperties: false
    }
  });
}

export function createRegisteredActionSchemaCatalog(): ActionSchemaCatalog {
  const schemas = new ActionSchemaCatalog();
  registerHotelNavigation(schemas);
  registerMapsRouteOpen(schemas);
  registerSocialPostPreview(schemas);
  registerGmailDraft(schemas);
  return schemas;
}

export function createRegisteredActionDefinitionLookup(
  tools: ToolDefinitionLookup
): SchemaAwareActionDefinitionLookup {
  return new SchemaAwareActionDefinitionLookup(
    tools,
    createRegisteredActionSchemaCatalog()
  );
}
