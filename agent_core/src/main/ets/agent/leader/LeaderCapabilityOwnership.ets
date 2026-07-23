import {
  actionAgentToolDefinitions,
  dataAgentToolDefinitions
} from '../../aiphone/runtime/ToolDefinitionRegistry';
import { ToolDefinition } from '../../aiphone/runtime/ToolDefinitionTypes';
import { LeaderPlanningContext, LeaderToolMetadata } from './LeaderTypes';

const DATA_OWNER_IDS: Set<string> = new Set<string>(dataAgentToolDefinitions().map(
  (definition: ToolDefinition): string => definition.toolId
));
DATA_OWNER_IDS.add('dynamic.search');

const ACTION_OWNER_IDS: Set<string> = new Set<string>(actionAgentToolDefinitions().map(
  (definition: ToolDefinition): string => definition.toolId
));
const VIRTUAL_ACTION_OWNER_IDS: Set<string> = new Set<string>([
  'memory.update',
  'gmail.draft.apply'
]);

function toolMetadata(context: LeaderPlanningContext, capabilityId: string): LeaderToolMetadata | null {
  for (let index = 0; index < context.tools.length; index++) {
    if (context.tools[index].toolId === capabilityId) {
      return context.tools[index];
    }
  }
  return null;
}

function sourceDeclaresAction(context: LeaderPlanningContext, capabilityId: string): boolean {
  if (toolMetadata(context, capabilityId) === null ||
    (!DATA_OWNER_IDS.has(capabilityId) &&
      !leaderIsExplicitActionOwner(context, capabilityId))) {
    return false;
  }
  for (let index = 0; index < context.tools.length; index++) {
    if (context.tools[index].actions.indexOf(capabilityId) >= 0) {
      return true;
    }
  }
  return false;
}

export function leaderIsDataCapability(
  context: LeaderPlanningContext,
  capabilityId: string
): boolean {
  const tool: LeaderToolMetadata | null = toolMetadata(context, capabilityId);
  return DATA_OWNER_IDS.has(capabilityId) && tool !== null && tool.riskLevel === 'read';
}

export function leaderIsExplicitActionOwner(
  context: LeaderPlanningContext,
  capabilityId: string
): boolean {
  const tool: LeaderToolMetadata | null = toolMetadata(context, capabilityId);
  return tool !== null &&
    (ACTION_OWNER_IDS.has(capabilityId) || VIRTUAL_ACTION_OWNER_IDS.has(capabilityId));
}

export function leaderIsActionCapability(
  context: LeaderPlanningContext,
  capabilityId: string
): boolean {
  return leaderIsExplicitActionOwner(context, capabilityId) ||
    sourceDeclaresAction(context, capabilityId);
}

export function leaderDataCapabilityIds(context: LeaderPlanningContext): string[] {
  const result: string[] = [];
  for (let index = 0; index < context.tools.length; index++) {
    const capabilityId: string = context.tools[index].toolId;
    if (leaderIsDataCapability(context, capabilityId) && result.indexOf(capabilityId) < 0) {
      result.push(capabilityId);
    }
  }
  return result;
}

export function leaderActionCapabilityIds(context: LeaderPlanningContext): string[] {
  const result: string[] = [];
  for (let index = 0; index < context.tools.length; index++) {
    const tool: LeaderToolMetadata = context.tools[index];
    if (leaderIsExplicitActionOwner(context, tool.toolId) && result.indexOf(tool.toolId) < 0) {
      result.push(tool.toolId);
    }
    for (let actionIndex = 0; actionIndex < tool.actions.length; actionIndex++) {
      const actionId: string = tool.actions[actionIndex];
      if (leaderIsActionCapability(context, actionId) && result.indexOf(actionId) < 0) {
        result.push(actionId);
      }
    }
  }
  return result;
}
