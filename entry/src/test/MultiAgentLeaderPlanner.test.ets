import { describe, expect, it } from '@ohos/hypium';
import {
  AgentMessage,
  AgentMessageType,
  ConversationContext,
  InputUserPayload,
  LeaderDecision,
  LeaderPlanningContext,
  LocalModel
} from '@loop/agent-core';
import { MultiAgentLeaderPlanner } from '../main/ets/pages/A2uiHome/agent/MultiAgentLeaderPlanner';

const PARALLEL_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["flight.search","train.search"],"roundAction":"execute",' +
  '"dataTasks":[' +
  '{"localId":"flight","goal":"查航班","allowedToolIds":["flight.search"],"toolId":"flight.search","input":{},"required":false},' +
  '{"localId":"train","goal":"查高铁","allowedToolIds":["train.search"],"toolId":"train.search","input":{},"required":false}' +
  '],"uiIntent":{"purpose":"比较出行方案","preferredDensity":"comfortable","requiredSections":["flight","train"]},' +
  '"reasonCode":"parallel_reads"}';
const EXACT_MULTI_TOOL_ACTION_DECISION: string = PARALLEL_DECISION
  .replace(
    '"requestedCapabilityIds":["flight.search","train.search"]',
    '"requestedCapabilityIds":["flight.search","train.search","memory.update"]'
  )
  .replace(
    '"allowedToolIds":["flight.search"]',
    '"allowedToolIds":["flight.search","train.search"]'
  )
  .replace(
    ',"reasonCode":"parallel_reads"}',
    ',"actionIntent":{"goal":"remember selection","allowedActionIds":["memory.update"]},' +
      '"reasonCode":"parallel_reads"}'
  );
const HOTEL_WITH_EXTRA_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["hotel.search","memory.update"],"roundAction":"execute",' +
  '"dataTasks":[{"localId":"hotel","goal":"查酒店","allowedToolIds":["hotel.search"],' +
  '"toolId":"hotel.search","input":{},"required":true}],' +
  '"uiIntent":{"purpose":"展示酒店","preferredDensity":"comfortable",' +
  '"requiredSections":["hotel"]},"reasonCode":"hotel_search"}';
const ANSWER_WITHOUT_ANSWER_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":[],"roundAction":"answer","dataTasks":[],' +
  '"uiIntent":{"purpose":"reply","preferredDensity":"comfortable","requiredSections":[]},' +
  '"reasonCode":"greeting"}';
const LIVE_ANSWER_WITHOUT_REASON_CODE: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":[],"roundAction":"answer","dataTasks":[],' +
  '"uiIntent":{"purpose":"reply","preferredDensity":"comfortable","requiredSections":[]},' +
  '"answer":"LIVE_PRIVATE_MARKER"}';
const VALID_ANSWER_DECISION: string = LIVE_ANSWER_WITHOUT_REASON_CODE.substring(
  0,
  LIVE_ANSWER_WITHOUT_REASON_CODE.length - 1
) + ',"reasonCode":"greeting"}';

class QueueLocalModel implements LocalModel {
  prompts: string[] = [];
  systemPrompts: string[] = [];
  private readonly outputs: string[];

  constructor(outputs: string[]) {
    this.outputs = outputs.slice();
  }

  async complete(
    prompt: string,
    _conversation?: ConversationContext,
    systemPrompt?: string
  ): Promise<string> {
    this.prompts.push(prompt);
    this.systemPrompts.push(systemPrompt ?? '');
    if (this.outputs.length === 0) {
      throw new Error('No scripted Leader output');
    }
    return this.outputs.shift() as string;
  }
}

function inputMessage(): AgentMessage {
  const payload: InputUserPayload = { text: '查航班和高铁' };
  return {
    type: AgentMessageType.INPUT_USER,
    conversationId: 'conversation-leader-planner',
    turnId: 'turn-1',
    taskId: 'input-1',
    payload
  };
}

function planningContext(): LeaderPlanningContext {
  return {
    tools: [{
      toolId: 'flight.search',
      intent: 'Search real flights',
      riskLevel: 'read',
      inputSchema: 'flightSearchRequest',
      outputSchema: 'flightSearchResults',
      actions: []
    }, {
      toolId: 'train.search',
      intent: 'Search real trains',
      riskLevel: 'read',
      inputSchema: 'trainSearchRequest',
      outputSchema: 'trainSearchResults',
      actions: []
    }, {
      toolId: 'hotel.search',
      intent: 'Search real hotels',
      riskLevel: 'read',
      inputSchema: 'hotelSearchRequest',
      outputSchema: 'hotelSearchResults',
      actions: []
    }, {
      toolId: 'hotel.navigate',
      intent: 'Open hotel navigation',
      riskLevel: 'read',
      inputSchema: 'hotelNavigateRequest',
      outputSchema: 'hotelNavigateResult',
      actions: []
    }, {
      toolId: 'memory.update',
      intent: 'Update persona memory',
      riskLevel: 'draft',
      inputSchema: 'memoryUpdateRequest',
      outputSchema: 'memoryUpdateResult',
      actions: ['memory.update']
    }, {
      toolId: 'payment.create',
      intent: 'Create a payment',
      riskLevel: 'confirm_required',
      inputSchema: 'paymentCreateRequest',
      outputSchema: 'paymentCreateResult',
      actions: []
    }],
    personas: [{
      personaId: 'travel_companion',
      name: 'Travel Companion',
      soul: 'Ground travel suggestions in real provider results.',
      memory: 'No saved preference.',
      previous: false,
      activeSkills: [{
        skillId: 'travel-planning',
        description: 'Plan travel',
        instructions: 'Use real travel inventory.',
        status: 'active'
      }]
    }]
  };
}

async function fails(output: string): Promise<boolean> {
  const model: QueueLocalModel = new QueueLocalModel([output, output]);
  const planner: MultiAgentLeaderPlanner = new MultiAgentLeaderPlanner(model);
  const input: InputUserPayload = { text: '查航班和高铁' };
  try {
    await planner.plan(inputMessage(), input, planningContext(), 1, (): boolean => true);
    return false;
  } catch (_error) {
    return true;
  }
}

async function failsAtRound(output: string, round: number): Promise<boolean> {
  const model: QueueLocalModel = new QueueLocalModel([output]);
  const planner: MultiAgentLeaderPlanner = new MultiAgentLeaderPlanner(model);
  const input: InputUserPayload = { text: '查航班和高铁' };
  try {
    await planner.plan(inputMessage(), input, planningContext(), round);
    return false;
  } catch (_error) {
    return true;
  }
}

export default function multiAgentLeaderPlannerTest() {
  describe('multiAgentLeaderPlanner', () => {
    it('parses one exact registry-bound LeaderDecision and includes round context', 0, async () => {
      const model: QueueLocalModel = new QueueLocalModel([PARALLEL_DECISION]);
      const planner: MultiAgentLeaderPlanner = new MultiAgentLeaderPlanner(model);
      const input: InputUserPayload = {
        text: '查航班和高铁',
        previousPersonaId: 'travel_companion',
        recentObservations: []
      };

      const decision: LeaderDecision = await planner.plan(inputMessage(), input, planningContext(), 2);

      expect(decision.personaId).assertEqual('travel_companion');
      expect(decision.dataTasks.length).assertEqual(2);
      expect(decision.dataTasks[0].toolId).assertEqual('flight.search');
      expect(decision.dataTasks[1].toolId).assertEqual('train.search');
      expect(model.prompts[0].indexOf('Round: 2') >= 0).assertTrue();
      expect(model.prompts[0].indexOf('flight.search') >= 0).assertTrue();
      expect(model.prompts[0].indexOf('travel_companion') >= 0).assertTrue();
      expect(model.systemPrompts[0].indexOf('exactly one JSON object') >= 0).assertTrue();
      expect(model.systemPrompts[0].indexOf('Do not include Thought') >= 0).assertTrue();
      expect(model.systemPrompts[0].indexOf('markdown') >= 0).assertTrue();
      expect(model.systemPrompts[0].indexOf(
        'For roundAction answer or clarify, include answer as a non-empty string. ' +
          'For roundAction execute or legacy_handoff, omit answer.'
      ) >= 0).assertTrue();
      expect(model.prompts[0].indexOf(
        'For roundAction answer or clarify, include answer as a non-empty string. ' +
          'For roundAction execute or legacy_handoff, omit answer.'
      ) >= 0).assertTrue();
    });

    it('carries the old hotel date and anti-invention contract in the shared prompt', 0, async () => {
      const model: QueueLocalModel = new QueueLocalModel([PARALLEL_DECISION]);
      const planner: MultiAgentLeaderPlanner = new MultiAgentLeaderPlanner(
        model,
        (): string => '2026-07-21'
      );
      const input: InputUserPayload = { text: '8月15日深圳住两晚的酒店' };

      await planner.plan(inputMessage(), input, planningContext(), 1);

      expect(model.prompts[0].indexOf('Current local date: 2026-07-21') >= 0).assertTrue();
      expect(model.prompts[0].indexOf('originQuery, place, placeType, countryCode') >= 0).assertTrue();
      expect(model.prompts[0].indexOf('Do not invent missing destination, date, year, guest') >= 0).assertTrue();
      expect(model.prompts[0].indexOf('Preserve originQuery exactly') >= 0).assertTrue();
    });

    it('repairs one completed strict-schema rejection once without exposing its output', 0, async () => {
      const model = new QueueLocalModel([LIVE_ANSWER_WITHOUT_REASON_CODE, VALID_ANSWER_DECISION]);
      const planner = new MultiAgentLeaderPlanner(model);
      const input: InputUserPayload = { text: '你好' };

      const decision = await planner.plan(
        inputMessage(),
        input,
        planningContext(),
        1,
        (): boolean => true
      );

      expect(decision.reasonCode).assertEqual('greeting');
      expect(model.prompts.length).assertEqual(2);
      expect(model.prompts[1].indexOf(model.prompts[0])).assertEqual(0);
      expect(model.prompts[1].indexOf('previous decision rejected by strict schema') >= 0).assertTrue();
      expect(model.prompts[1].indexOf('LIVE_PRIVATE_MARKER')).assertEqual(-1);
      expect(model.systemPrompts[1]).assertEqual(model.systemPrompts[0]);
      expect(model.prompts[1].indexOf('Round: 1') >= 0).assertTrue();
    });

    it('stops after one invalid or throwing strict-schema repair', 0, async () => {
      const model = new QueueLocalModel([LIVE_ANSWER_WITHOUT_REASON_CODE, LIVE_ANSWER_WITHOUT_REASON_CODE]);
      const throwingModel = new QueueLocalModel([LIVE_ANSWER_WITHOUT_REASON_CODE]);
      const planner = new MultiAgentLeaderPlanner(model);
      const input: InputUserPayload = { text: '你好' };
      let failed: boolean = false;
      let throwingFailed: boolean = false;

      try {
        await planner.plan(inputMessage(), input, planningContext(), 1, (): boolean => true);
      } catch (_error) {
        failed = true;
      }
      try {
        await new MultiAgentLeaderPlanner(throwingModel).plan(
          inputMessage(), input, planningContext(), 1, (): boolean => true
        );
      } catch (_error) {
        throwingFailed = true;
      }

      expect(failed).assertTrue();
      expect(throwingFailed).assertTrue();
      expect(model.prompts.length).assertEqual(2);
      expect(throwingModel.prompts.length).assertEqual(2);
    });

    it('does not repair without an active lifecycle signal', 0, async () => {
      const absentModel = new QueueLocalModel([LIVE_ANSWER_WITHOUT_REASON_CODE, VALID_ANSWER_DECISION]);
      const inactiveModel = new QueueLocalModel([LIVE_ANSWER_WITHOUT_REASON_CODE, VALID_ANSWER_DECISION]);
      const input: InputUserPayload = { text: '你好' };
      let absentFailed: boolean = false;
      let inactiveFailed: boolean = false;

      try {
        await new MultiAgentLeaderPlanner(absentModel).plan(
          inputMessage(), input, planningContext(), 1
        );
      } catch (_error) {
        absentFailed = true;
      }
      try {
        await new MultiAgentLeaderPlanner(inactiveModel).plan(
          inputMessage(), input, planningContext(), 1, (): boolean => false
        );
      } catch (_error) {
        inactiveFailed = true;
      }

      expect(absentFailed).assertTrue();
      expect(inactiveFailed).assertTrue();
      expect(absentModel.prompts.length).assertEqual(1);
      expect(inactiveModel.prompts.length).assertEqual(1);
    });

    it('does not repair a first model transport failure', 0, async () => {
      const model = new QueueLocalModel([]);
      const planner = new MultiAgentLeaderPlanner(model);
      const input: InputUserPayload = { text: '你好' };
      let failed: boolean = false;

      try {
        await planner.plan(inputMessage(), input, planningContext(), 1);
      } catch (_error) {
        failed = true;
      }

      expect(failed).assertTrue();
      expect(model.prompts.length).assertEqual(1);
    });

    it('uses one model call when the first decision is valid', 0, async () => {
      const model = new QueueLocalModel([VALID_ANSWER_DECISION]);
      const planner = new MultiAgentLeaderPlanner(model);
      const input: InputUserPayload = { text: '你好' };

      const decision = await planner.plan(inputMessage(), input, planningContext(), 1);

      expect(decision.reasonCode).assertEqual('greeting');
      expect(model.prompts.length).assertEqual(1);
    });

    it('rejects non-exact JSON, fields, IDs, ownership, and persona-skill pairs', 0, async () => {
      const extraTop = PARALLEL_DECISION.substring(0, PARALLEL_DECISION.length - 1) +
        ',"providerFacts":{}}';
      const duplicateTop = PARALLEL_DECISION.replace(
        '"personaId":"travel_companion"',
        '"personaId":"travel_companion","personaId":"travel_companion"'
      );
      const unknownTool = PARALLEL_DECISION.replace('"flight.search"', '"missing.search"');
      const outsideAllowed = PARALLEL_DECISION.replace(
        '"allowedToolIds":["flight.search"]',
        '"allowedToolIds":["train.search"]'
      );
      const writeTool = PARALLEL_DECISION.replace(/flight\.search/g, 'payment.create');
      const actionOwnedReadTool = PARALLEL_DECISION.replace(/flight\.search/g, 'hotel.navigate');
      const wrongSkill = PARALLEL_DECISION.replace('"skillId":""', '"skillId":"missing-skill"');
      const duplicateLocalId = PARALLEL_DECISION.replace('"localId":"train"', '"localId":"flight"');
      const extraTask = PARALLEL_DECISION.replace(
        '"input":{},"required":false',
        '"input":{},"required":false,"providerOutput":{"secret":"x"}'
      );
      const duplicateNested = PARALLEL_DECISION.replace(
        '"toolId":"flight.search","input":{}',
        '"toolId":"flight.search","toolId":"flight.search","input":{}'
      );

      expect(await fails('model says ' + PARALLEL_DECISION)).assertTrue();
      expect(await fails(PARALLEL_DECISION + PARALLEL_DECISION)).assertTrue();
      expect(await fails(extraTop)).assertTrue();
      expect(await fails(duplicateTop)).assertTrue();
      expect(await fails(unknownTool)).assertTrue();
      expect(await fails(outsideAllowed)).assertTrue();
      expect(await fails(writeTool)).assertTrue();
      expect(await fails(actionOwnedReadTool)).assertTrue();
      expect(await fails(wrongSkill)).assertTrue();
      expect(await fails(duplicateLocalId)).assertTrue();
      expect(await fails(extraTask)).assertTrue();
      expect(await fails(duplicateNested)).assertTrue();
      expect(await fails(ANSWER_WITHOUT_ANSWER_DECISION)).assertTrue();
      expect(await failsAtRound(PARALLEL_DECISION, 4)).assertTrue();
    });

    it('accepts zero Data only for an explicit registered Action intent', 0, async () => {
      const output: string = '{"personaId":"travel_companion","skillId":"",' +
        '"requestedCapabilityIds":["memory.update"],"roundAction":"execute","dataTasks":[],' +
        '"uiIntent":{"purpose":"remember","preferredDensity":"comfortable",' +
        '"requiredSections":[]},"actionIntent":{"goal":"remember explicit text",' +
        '"allowedActionIds":["memory.update"]},"reasonCode":"stable_preference"}';
      const planner = new MultiAgentLeaderPlanner(new QueueLocalModel([output]));
      const input: InputUserPayload = { text: '我在北京' };

      const decision = await planner.plan(inputMessage(), input, planningContext(), 1);

      expect(decision.dataTasks.length).assertEqual(0);
      expect(decision.actionIntent!.allowedActionIds[0]).assertEqual('memory.update');
    });

    it('requires unique registered requested capabilities covering every executed capability', 0, async () => {
      const missing: string = PARALLEL_DECISION.replace(
        '"requestedCapabilityIds":["flight.search","train.search"],',
        ''
      );
      const duplicate: string = PARALLEL_DECISION.replace(
        '"flight.search","train.search"',
        '"flight.search","flight.search","train.search"'
      );
      const unregistered: string = PARALLEL_DECISION.replace(
        '"flight.search","train.search"',
        '"flight.search","missing.search","train.search"'
      );
      const incomplete: string = PARALLEL_DECISION.replace(
        '"flight.search","train.search"',
        '"flight.search"'
      );

      expect(await fails(PARALLEL_DECISION)).assertFalse();
      expect(await fails(EXACT_MULTI_TOOL_ACTION_DECISION)).assertFalse();
      expect(await fails(missing)).assertTrue();
      expect(await fails(duplicate)).assertTrue();
      expect(await fails(unregistered)).assertTrue();
      expect(await fails(incomplete)).assertTrue();
      expect(await fails(HOTEL_WITH_EXTRA_DECISION)).assertTrue();
    });
  });
}
