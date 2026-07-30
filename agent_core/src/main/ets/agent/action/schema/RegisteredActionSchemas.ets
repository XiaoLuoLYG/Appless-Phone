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

function registeredToolOutputSchema(
  actionId: string = ''
): ActionJsonSchema {
  const resultProperties: Record<string, ActionJsonSchema> = {};
  resultProperties['sourceTag'] = STRING;
  resultProperties['toolName'] = REQUIRED_STRING;
  resultProperties['title'] = STRING;
  resultProperties['status'] = REQUIRED_STRING;
  resultProperties['summary'] = STRING;
  resultProperties['rows'] = {
    type: 'array',
    items: { type: 'object', additionalProperties: true }
  };
  resultProperties['rawPreview'] = STRING;

  const dataProperties: Record<string, ActionJsonSchema> = {};
  dataProperties['genericToolResults'] = {
    type: 'array',
    items: {
      type: 'object',
      properties: resultProperties,
      required: [
        'sourceTag',
        'toolName',
        'title',
        'status',
        'summary',
        'rows',
        'rawPreview'
      ],
      additionalProperties: true
    }
  };

  const outputProperties: Record<string, ActionJsonSchema> = {};
  outputProperties['actionId'] = actionId.length === 0 ?
    REQUIRED_STRING : { type: 'string', enum: [actionId] };
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
  return {
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
  };
}

function registerLuckinOrderPreview(schemas: ActionSchemaCatalog): void {
  const inputProperties: Record<string, ActionJsonSchema> = {};
  inputProperties['originalQuery'] = {
    type: 'string',
    description:
      'The complete user request when an exact store or product selection is not yet available.'
  };
  inputProperties['deptId'] = STRING;
  inputProperties['deptName'] = STRING;
  inputProperties['address'] = STRING;
  inputProperties['distance'] = STRING;
  inputProperties['location'] = STRING;
  inputProperties['status'] = STRING;
  inputProperties['productId'] = STRING;
  inputProperties['productName'] = STRING;
  inputProperties['skuCode'] = STRING;
  inputProperties['pictureUrl'] = STRING;
  inputProperties['previewPrompt'] = STRING;
  inputProperties['attrGroup'] = STRING;
  inputProperties['attrChoice'] = STRING;
  inputProperties['attrSelections'] =
    { type: 'object', additionalProperties: true };
  inputProperties['quantity'] = POSITIVE_INTEGER;
  inputProperties['price'] = STRING;
  inputProperties['couponCodeList'] =
    { type: 'array', items: STRING };
  inputProperties['remark'] = STRING;
  inputProperties['orderId'] = STRING;
  inputProperties['payOrderUrl'] = STRING;
  inputProperties['payOrderQrCodeUrl'] = STRING;
  schemas.register({
    schemaId: 'luckinOrderPreviewRequest',
    revision: REVISION,
    schema: {
      type: 'object',
      properties: inputProperties,
      additionalProperties: false
    }
  });
}

function registerGenericToolResults(schemas: ActionSchemaCatalog): void {
  schemas.register({
    schemaId: 'genericToolResults',
    revision: REVISION,
    schema: registeredToolOutputSchema()
  });
}

function registerPaymentSend(schemas: ActionSchemaCatalog): void {
  const inputProperties: Record<string, ActionJsonSchema> = {};
  inputProperties['originalQuery'] = {
    type: 'string',
    description:
      'The complete user request when payment fields or provider are not fully specified.'
  };
  inputProperties['recipient'] = STRING;
  inputProperties['provider'] = STRING;
  inputProperties['fundingSource'] = STRING;
  inputProperties['amountText'] = STRING;
  inputProperties['currency'] = STRING;
  inputProperties['note'] = STRING;
  inputProperties['phase'] = STRING;
  inputProperties['accountId'] = STRING;
  inputProperties['targetType'] = STRING;
  inputProperties['checkoutUrl'] = STRING;
  inputProperties['providerSessionId'] = STRING;
  inputProperties['paypalClientId'] = STRING;
  inputProperties['paypalEnvironment'] = STRING;
  inputProperties['paypalEmail'] = STRING;
  inputProperties['paypalMerchantId'] = STRING;
  schemas.register({
    schemaId: 'paymentSendRequest',
    revision: REVISION,
    schema: {
      type: 'object',
      properties: inputProperties,
      additionalProperties: false
    }
  });
  schemas.register({
    schemaId: 'paymentCheckout',
    revision: REVISION,
    schema: registeredToolOutputSchema('payment.send')
  });
}

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

function registerMailThreadRead(schemas: ActionSchemaCatalog): void {
  const inputProperties: Record<string, ActionJsonSchema> = {};
  inputProperties['requestKey'] = REQUIRED_STRING;
  inputProperties['provider'] = {
    type: 'string',
    enum: ['gmail', 'qq']
  };
  inputProperties['threadId'] = STRING;
  inputProperties['messageId'] = REQUIRED_STRING;
  inputProperties['subject'] = STRING;
  schemas.register({
    schemaId: 'mailThreadReadQuery',
    revision: REVISION,
    schema: {
      type: 'object',
      properties: inputProperties,
      required: ['requestKey', 'provider', 'threadId', 'messageId', 'subject'],
      additionalProperties: false
    }
  });

  const outputProperties: Record<string, ActionJsonSchema> = {};
  outputProperties['requestKey'] = REQUIRED_STRING;
  outputProperties['provider'] = {
    type: 'string',
    enum: ['gmail', 'qq']
  };
  outputProperties['threadId'] = STRING;
  outputProperties['messageId'] = REQUIRED_STRING;
  outputProperties['internetMessageId'] = STRING;
  outputProperties['subject'] = STRING;
  outputProperties['from'] = STRING;
  outputProperties['replyTo'] = STRING;
  outputProperties['to'] = { type: 'array', items: STRING };
  outputProperties['cc'] = { type: 'array', items: STRING };
  outputProperties['body'] = STRING;
  outputProperties['bodyHtml'] = STRING;
  schemas.register({
    schemaId: 'mailThread',
    revision: REVISION,
    schema: {
      type: 'object',
      properties: outputProperties,
      required: [
        'requestKey',
        'provider',
        'threadId',
        'messageId',
        'internetMessageId',
        'subject',
        'from',
        'replyTo',
        'to',
        'cc',
        'body',
        'bodyHtml'
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
  registerLuckinOrderPreview(schemas);
  registerGenericToolResults(schemas);
  registerPaymentSend(schemas);
  registerHotelNavigation(schemas);
  registerMapsRouteOpen(schemas);
  registerSocialPostPreview(schemas);
  registerGmailDraft(schemas);
  registerMailThreadRead(schemas);
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
