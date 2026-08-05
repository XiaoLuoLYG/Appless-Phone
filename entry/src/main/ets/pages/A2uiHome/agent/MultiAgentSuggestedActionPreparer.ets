import {
  HotelSearchParseResult,
  LocalModel,
  PreparedActionDraft,
  PreparedActionDraftStep,
  SuggestedActionPreparer,
  ToolDefinition,
  ToolInputValidationResult,
  validateToolInputValue,
  parseHotelSearchRequest
} from '@loop/agent-core';

const SUGGESTED_ACTION_SYSTEM_PROMPT: string =
  'You are the Appless Action Agent suggested-action preparer. ' +
  'Convert only the supplied natural-language goal into executable arguments using the supplied registered tool ' +
  'catalog. Every usable tool includes its real inputJsonSchema and field descriptions. Select only a tool listed ' +
  'in supportedPreparedToolIds, and make args strictly satisfy that tool inputJsonSchema. ' +
  'Return exactly one JSON object with exactly canImplement, reasonCode, label, and steps. ' +
  'Set canImplement to true only when one tool in supportedPreparedToolIds can fully satisfy every constraint in ' +
  'the goal. Never drop, weaken, or rewrite a goal constraint merely to produce a plan. For canImplement=true, ' +
  'reasonCode must be the empty string, label must be a concise user-facing label, and steps must contain exactly ' +
  'one object with exactly stepId, toolId, and args. stepId must be a non-empty descriptive JSON string. ' +
  'For canImplement=false, reasonCode must be one of NO_SUPPORTED_TOOL, UNSUPPORTED_CONSTRAINT, or ' +
  'UNSUPPORTED_FLOW, label must be the empty string, and steps must be an empty array. ' +
  'Use currentLocalDate only to resolve relative dates. Use schema descriptions for omitted-value defaults. ' +
  'Do not add bindings, sources, explanations, markdown, or fields absent from the selected inputJsonSchema.';

export type SuggestedActionCurrentLocalDateProvider = () => string;

interface SuggestedActionCompilerInput {
  goal: string;
  currentLocalDate: string;
  registeredTools: ToolDefinition[];
  supportedPreparedToolIds: string[];
}

function tomorrow(localDate: string): string {
  const parts: string[] = localDate.split('-');
  if (parts.length !== 3) {
    return '';
  }
  const date = new Date(Date.UTC(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2])));
  if (!Number.isFinite(date.getTime())) {
    return '';
  }
  date.setUTCDate(date.getUTCDate() + 1);
  const month: string = (date.getUTCMonth() + 1).toString().padStart(2, '0');
  const day: string = date.getUTCDate().toString().padStart(2, '0');
  return date.getUTCFullYear().toString() + '-' + month + '-' + day;
}

export class MultiAgentSuggestedActionPreparer implements SuggestedActionPreparer {
  private readonly model: LocalModel;
  private readonly tools: ToolDefinition[];
  private readonly currentLocalDate: SuggestedActionCurrentLocalDateProvider;

  constructor(
    model: LocalModel,
    tools: ToolDefinition[],
    currentLocalDate?: SuggestedActionCurrentLocalDateProvider
  ) {
    this.model = model;
    this.tools = tools.slice();
    this.currentLocalDate = currentLocalDate === undefined ? (): string => {
      const now = new Date();
      const month: string = (now.getMonth() + 1).toString().padStart(2, '0');
      const day: string = now.getDate().toString().padStart(2, '0');
      return now.getFullYear().toString() + '-' + month + '-' + day;
    } : currentLocalDate;
  }

  async prepare(goal: string): Promise<PreparedActionDraft> {
    const currentLocalDate: string = this.currentLocalDate();
    if (goal.trim().length === 0 || goal !== goal.trim() || goal.length > 240 ||
      tomorrow(currentLocalDate).length === 0) {
      throw new Error('Suggested action preparation input is invalid.');
    }
    const input: SuggestedActionCompilerInput = {
      goal,
      currentLocalDate,
      registeredTools: this.tools,
      supportedPreparedToolIds: this.supportedPreparedToolIds()
    };
    const raw: string = await this.model.complete(
      JSON.stringify(input),
      undefined,
      SUGGESTED_ACTION_SYSTEM_PROMPT
    );
    const parsed: Object = JSON.parse(raw.trim()) as Object;
    if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed) ||
      Object.keys(parsed).sort().join(',') !== 'canImplement,label,reasonCode,steps') {
      throw new Error('Suggested action preparer returned an invalid object.');
    }
    const draft: PreparedActionDraft = parsed as PreparedActionDraft;
    if (draft.canImplement === false) {
      if ((draft.reasonCode !== 'NO_SUPPORTED_TOOL' &&
        draft.reasonCode !== 'UNSUPPORTED_CONSTRAINT' &&
        draft.reasonCode !== 'UNSUPPORTED_FLOW') || draft.label !== '' ||
        !Array.isArray(draft.steps) || draft.steps.length !== 0) {
        throw new Error('Suggested action preparer returned an invalid unsupported result.');
      }
      return draft;
    }
    if (draft.canImplement !== true || draft.reasonCode !== '' ||
      typeof draft.label !== 'string' || draft.label.trim().length === 0 ||
      draft.label !== draft.label.trim() || draft.label.length > 80 ||
      !Array.isArray(draft.steps) || draft.steps.length !== 1) {
      throw new Error('Suggested action preparer returned an invalid draft.');
    }
    const step: PreparedActionDraftStep = draft.steps[0];
    if (step === null || typeof step !== 'object' || Array.isArray(step) ||
      Object.keys(step).sort().join(',') !== 'args,stepId,toolId' ||
      typeof step.stepId !== 'string' || step.stepId.trim().length === 0 ||
      step.stepId !== step.stepId.trim() || step.stepId.length > 80 ||
      step.args === null || typeof step.args !== 'object' || Array.isArray(step.args)) {
      throw new Error('Suggested action preparer returned an unsupported step.');
    }
    const definition: ToolDefinition | null = this.supportedTool(step.toolId);
    if (definition === null || definition.inputJsonSchema === undefined) {
      return this.unsupported('NO_SUPPORTED_TOOL');
    }
    const validation: ToolInputValidationResult =
      validateToolInputValue(definition.inputJsonSchema, step.args);
    if (!validation.ok) {
      return this.unsupported('UNSUPPORTED_CONSTRAINT');
    }
    if (step.toolId === 'hotel.search') {
      const hotel: HotelSearchParseResult = parseHotelSearchRequest(step.args);
      if (!hotel.ok || hotel.value === null) {
        return this.unsupported('UNSUPPORTED_CONSTRAINT');
      }
    }
    return draft;
  }

  private supportedPreparedToolIds(): string[] {
    const ids: string[] = [];
    for (let index = 0; index < this.tools.length; index++) {
      if (this.supportedTool(this.tools[index].toolId) !== null) {
        ids.push(this.tools[index].toolId);
      }
    }
    return ids;
  }

  private supportedTool(toolId: string): ToolDefinition | null {
    for (let index = 0; index < this.tools.length; index++) {
      if (this.tools[index].toolId === toolId &&
        this.tools[index].riskLevel === 'read' &&
        this.tools[index].inputJsonSchema !== undefined &&
        this.tools[index].backendPriority.length > 0 &&
        this.tools[index].backendPriority.indexOf('system_intent') < 0) {
        return this.tools[index];
      }
    }
    return null;
  }

  private unsupported(reasonCode: string): PreparedActionDraft {
    return {
      canImplement: false,
      reasonCode,
      label: '',
      steps: []
    };
  }
}
