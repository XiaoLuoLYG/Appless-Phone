import {
  ActionOffer,
  ActionPlanCompiler,
  ActionPlanDraft,
  LocalModel
} from '@loop/agent-core';

const ACTION_AGENT_SYSTEM_PROMPT: string = 'You are the Appless Action Agent planner.\n' +
  'Compile the requested goal only from the supplied registered action definitions and current ActionOffers.\n' +
  'Use at most 5 serial steps.\n' +
  'A binding may reference only an earlier step through RFC 6901 JSON Pointer.\n' +
  'Do not emit code, expressions, loops, branches, parallel steps, new action IDs, or modified offer args.\n' +
  'Return only ActionPlanDraft JSON matching the schema.';

interface ActionCompilerInput {
  goal: string;
  allowedActionIds: string[];
  offers: ActionOffer[];
  outputSchema: string;
}

export class MultiAgentActionPlanCompiler implements ActionPlanCompiler {
  private readonly model: LocalModel;

  constructor(model: LocalModel) {
    this.model = model;
  }

  async compile(
    goal: string,
    offers: ActionOffer[],
    allowedActionIds: string[]
  ): Promise<ActionPlanDraft> {
    const input: ActionCompilerInput = {
      goal,
      allowedActionIds: allowedActionIds.slice(),
      offers: offers.slice(),
      outputSchema: '{"planId":"string","runId":"string","label":"string",' +
        '"steps":[{"stepId":"string","actionId":"string","args":{},' +
        '"inputFrom":[{"target":"/field","stepId":"earlier-step",' +
        '"path":"/field"}]}]}'
    };
    const raw = await this.model.complete(
      JSON.stringify(input),
      undefined,
      ACTION_AGENT_SYSTEM_PROMPT
    );
    const parsed = JSON.parse(raw.trim()) as Object;
    if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) {
      throw new Error('Action Agent returned a non-object draft.');
    }
    return parsed as ActionPlanDraft;
  }
}
