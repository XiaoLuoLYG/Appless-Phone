import {
  ToolAuthMode,
  ToolBackendType,
  ToolDefinition,
  ToolRiskLevel
} from '../../../aiphone/runtime/ToolDefinitionTypes';
import { ToolDefinitionLookup } from '../ActionCatalogTypes';
import {
  ActionSchemaCatalog,
  ActionSchemaSnapshot
} from './ActionSchemaCatalog';
import { ActionJsonSchema, cloneActionSchema } from './ActionJsonSchema';

export interface SchemaAwareActionDefinition {
  actionId: string;
  domain: string;
  intent: string;
  riskLevel: ToolRiskLevel;
  backendPriority: ToolBackendType[];
  authModes: ToolAuthMode[];
  inputSchemaId: string;
  outputSchemaId: string;
  inputSchemaRevision: string;
  outputSchemaRevision: string;
  inputSchema: ActionJsonSchema;
  outputSchema: ActionJsonSchema;
  inputSchemaFingerprint: string;
  outputSchemaFingerprint: string;
  definitionFingerprint: string;
}

export interface SchemaAwareActionDefinitionResult {
  ok: boolean;
  definition: SchemaAwareActionDefinition | null;
  code: string;
  message: string;
}

function failure(
  code: string,
  message: string
): SchemaAwareActionDefinitionResult {
  return {
    ok: false,
    definition: null,
    code,
    message
  };
}

function fingerprintValue(value: string): string {
  let hash: number = 2166136261;
  for (let index = 0; index < value.length; index++) {
    hash = Math.imul(hash ^ value.charCodeAt(index), 16777619) >>> 0;
  }
  return hash.toString(16).padStart(8, '0');
}

function definitionFingerprint(
  tool: ToolDefinition,
  input: ActionSchemaSnapshot,
  output: ActionSchemaSnapshot
): string {
  return fingerprintValue(JSON.stringify({
    actionId: tool.toolId,
    domain: tool.domain,
    intent: tool.intent,
    riskLevel: tool.riskLevel,
    backendPriority: tool.backendPriority,
    authModes: tool.authModes,
    inputSchemaId: tool.inputSchema,
    inputSchemaFingerprint: input.fingerprint,
    outputSchemaId: tool.outputSchema,
    outputSchemaFingerprint: output.fingerprint
  }));
}

function definitionSnapshot(
  tool: ToolDefinition,
  input: ActionSchemaSnapshot,
  output: ActionSchemaSnapshot
): SchemaAwareActionDefinition {
  return {
    actionId: tool.toolId,
    domain: tool.domain,
    intent: tool.intent,
    riskLevel: tool.riskLevel,
    backendPriority: tool.backendPriority.slice(),
    authModes: tool.authModes.slice(),
    inputSchemaId: tool.inputSchema,
    outputSchemaId: tool.outputSchema,
    inputSchemaRevision: input.revision,
    outputSchemaRevision: output.revision,
    inputSchema: cloneActionSchema(input.schema),
    outputSchema: cloneActionSchema(output.schema),
    inputSchemaFingerprint: input.fingerprint,
    outputSchemaFingerprint: output.fingerprint,
    definitionFingerprint: definitionFingerprint(tool, input, output)
  };
}

export class SchemaAwareActionDefinitionLookup {
  private readonly tools: ToolDefinitionLookup;
  private readonly schemas: ActionSchemaCatalog;

  constructor(
    tools: ToolDefinitionLookup,
    schemas: ActionSchemaCatalog
  ) {
    this.tools = tools;
    this.schemas = schemas;
  }

  find(actionId: string): SchemaAwareActionDefinitionResult {
    let tool: ToolDefinition | null;
    try {
      tool = this.tools.find(actionId);
    } catch (_error) {
      return failure(
        'ACTION_DEFINITION_LOOKUP_FAILED',
        'Action definition lookup failed.'
      );
    }
    if (tool === null) {
      return failure(
        'ACTION_DEFINITION_NOT_FOUND',
        `Action is not registered: ${actionId}.`
      );
    }
    const input = this.schemas.find(tool.inputSchema);
    if (input === null) {
      return failure(
        'ACTION_INPUT_SCHEMA_NOT_FOUND',
        `Action input schema is not registered: ${tool.inputSchema}.`
      );
    }
    const output = this.schemas.find(tool.outputSchema);
    if (output === null) {
      return failure(
        'ACTION_OUTPUT_SCHEMA_NOT_FOUND',
        `Action output schema is not registered: ${tool.outputSchema}.`
      );
    }
    return {
      ok: true,
      definition: definitionSnapshot(tool, input, output),
      code: '',
      message: ''
    };
  }

  describe(actionIds: string[]): SchemaAwareActionDefinitionResult[] {
    const result: SchemaAwareActionDefinitionResult[] = [];
    const seen: Set<string> = new Set<string>();
    for (let index = 0; index < actionIds.length; index++) {
      const actionId = actionIds[index];
      if (seen.has(actionId)) {
        result.push(failure(
          'ACTION_DEFINITION_DUPLICATE',
          `Action id is duplicated: ${actionId}.`
        ));
        continue;
      }
      seen.add(actionId);
      result.push(this.find(actionId));
    }
    return result;
  }
}
