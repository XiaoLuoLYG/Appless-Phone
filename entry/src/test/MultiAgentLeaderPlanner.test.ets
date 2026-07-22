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
const TRAVEL_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["travel.search"],"roundAction":"execute",' +
  '"dataTasks":[{"localId":"travel","goal":"我明天要从北京去上海，帮我搜索出行方案",' +
  '"allowedToolIds":["travel.search"],"toolId":"travel.search",' +
  '"input":{"origin":"北京","destination":"上海","date":"明天",' +
  '"query":"我明天要从北京去上海，帮我搜索出行方案"},"required":true}],' +
  '"uiIntent":{"purpose":"展示综合出行方案","preferredDensity":"comfortable",' +
  '"requiredSections":["travel"]},"reasonCode":"travel_search"}';
const FLIGHT_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["flight.search"],"roundAction":"execute",' +
  '"dataTasks":[{"localId":"flight","goal":"帮我查明天北京到上海的航班",' +
  '"allowedToolIds":["flight.search"],"toolId":"flight.search",' +
  '"input":{"origin":"北京","destination":"上海","date":"明天"},"required":true}],' +
  '"uiIntent":{"purpose":"展示航班","preferredDensity":"comfortable",' +
  '"requiredSections":["flight"]},"reasonCode":"flight_search"}';
const TRAIN_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["train.search"],"roundAction":"execute",' +
  '"dataTasks":[{"localId":"train","goal":"帮我查询明天晚上六点以后深圳北到香港西九龙的高铁",' +
  '"allowedToolIds":["train.search"],"toolId":"train.search",' +
  '"input":{"origin":"深圳北","destination":"香港西九龙","date":"明天",' +
  '"departureAfter":"18:00"},"required":true}],' +
  '"uiIntent":{"purpose":"展示高铁","preferredDensity":"comfortable",' +
  '"requiredSections":["train"]},"reasonCode":"train_search"}';
const ANSWER_FROM_TRAVEL_OBSERVATION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["travel.search"],"roundAction":"answer","dataTasks":[],' +
  '"uiIntent":{"purpose":"总结真实出行结果","preferredDensity":"comfortable",' +
  '"requiredSections":["travel"]},"answer":"根据上一轮真实结果继续回答。"}';
const MAP_DETAILS_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["maps.place.details"],"roundAction":"execute",' +
  '"dataTasks":[{"localId":"place-details","goal":"读取上一轮真实地点的详情",' +
  '"allowedToolIds":["maps.place.details"],"toolId":"maps.place.details",' +
  '"input":{"placeId":"place-real-1"},"required":true}],' +
  '"uiIntent":{"purpose":"展示地点详情","preferredDensity":"comfortable",' +
  '"requiredSections":["place"]}}';
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
const MISSING_PERSONA_DECISION: string = LIVE_ANSWER_WITHOUT_REASON_CODE.replace(
  '"personaId":"travel_companion",',
  ''
);

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

class TravelPromptAwareModel implements LocalModel {
  prompts: string[] = [];

  async complete(prompt: string): Promise<string> {
    this.prompts.push(prompt);
    const hasAggregateContract: boolean = prompt.indexOf(
      'Broad or multimodal requests such as 出行方案, 怎么去, or 比较 must select exactly one travel.search Data task.'
    ) >= 0;
    if (prompt.indexOf('我明天要从北京去上海，帮我搜索出行方案') >= 0) {
      return hasAggregateContract ? TRAVEL_DECISION : PARALLEL_DECISION;
    }
    if (prompt.indexOf('帮我查明天北京到上海的航班') >= 0) {
      return FLIGHT_DECISION;
    }
    if (prompt.indexOf('帮我查询明天晚上六点以后深圳北到香港西九龙的高铁') >= 0) {
      return TRAIN_DECISION;
    }
    return PARALLEL_DECISION;
  }
}

class ObservationPromptAwareModel implements LocalModel {
  prompts: string[] = [];

  async complete(prompt: string): Promise<string> {
    this.prompts.push(prompt);
    const hasCompletedTools: boolean = prompt.indexOf(
      'Current-turn completed Data tool IDs: ["travel.search"]'
    ) >= 0;
    const hasNoRepeatContract: boolean = prompt.indexOf(
      'Never schedule a listed tool again in a later round, regardless of success, partial, empty, or error status.'
    ) >= 0;
    if (!hasCompletedTools || !hasNoRepeatContract) {
      return TRAVEL_DECISION;
    }
    if (prompt.indexOf('读取上一轮真实地点详情') >= 0) {
      return MAP_DETAILS_DECISION;
    }
    return ANSWER_FROM_TRAVEL_OBSERVATION;
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
      toolId: 'travel.search',
      intent: 'Search aggregate real travel options',
      riskLevel: 'read',
      inputSchema: 'travelSearchQuery',
      outputSchema: 'travelOptions',
      actions: []
    }, {
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
      toolId: 'maps.place.details',
      intent: 'Read details for one real place ID',
      riskLevel: 'read',
      inputSchema: 'mapsPlaceDetailsQuery',
      outputSchema: 'place',
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
      expect(decision.reasonCode).assertEqual('host_execute');
      expect(decision.dataTasks.length).assertEqual(2);
      expect(decision.dataTasks[0].toolId).assertEqual('flight.search');
      expect(decision.dataTasks[1].toolId).assertEqual('train.search');
      expect(model.prompts[0].indexOf('Round: 2') >= 0).assertTrue();
      expect(model.prompts[0].indexOf('flight.search') >= 0).assertTrue();
      expect(model.prompts[0].indexOf('travel_companion') >= 0).assertTrue();
      expect(model.systemPrompts[0].indexOf('exactly one JSON object') >= 0).assertTrue();
      expect(model.systemPrompts[0].indexOf('Do not include Thought') >= 0).assertTrue();
      expect(model.systemPrompts[0].indexOf('markdown') >= 0).assertTrue();
      expect(model.systemPrompts[0].indexOf('Omit reasonCode') >= 0).assertTrue();
      expect(model.prompts[0].indexOf('Omit reasonCode') >= 0).assertTrue();
      expect(model.prompts[0].indexOf('"reasonCode":"string"')).assertEqual(-1);
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

    it('lets the model distinguish aggregate travel explicit modes and an explicit pair', 0, async () => {
      const model: TravelPromptAwareModel = new TravelPromptAwareModel();
      const planner: MultiAgentLeaderPlanner = new MultiAgentLeaderPlanner(model);
      const c02Text: string = '我明天要从北京去上海，帮我搜索出行方案';
      const c02Input: InputUserPayload = { text: c02Text };
      const c02Message: AgentMessage = {
        type: AgentMessageType.INPUT_USER,
        conversationId: 'conversation-c02',
        turnId: 'turn-c02',
        taskId: 'input-c02',
        payload: c02Input
      };

      const c02: LeaderDecision = await planner.plan(c02Message, c02Input, planningContext(), 1);
      const flight: LeaderDecision = await planner.plan(
        inputMessage(),
        { text: '帮我查明天北京到上海的航班' },
        planningContext(),
        1
      );
      const train: LeaderDecision = await planner.plan(
        inputMessage(),
        { text: '帮我查询明天晚上六点以后深圳北到香港西九龙的高铁' },
        planningContext(),
        1
      );
      const both: LeaderDecision = await planner.plan(
        inputMessage(),
        { text: '查明天北京到上海的航班和高铁' },
        planningContext(),
        1
      );

      expect(c02.dataTasks.length).assertEqual(1);
      expect(c02.dataTasks[0].toolId).assertEqual('travel.search');
      const c02Args = c02.dataTasks[0].input as Record<string, Object | string | number | boolean>;
      expect(c02Args['date']).assertEqual('明天');
      expect(c02Args['query']).assertEqual(c02Text);
      expect(flight.dataTasks.length).assertEqual(1);
      expect(flight.dataTasks[0].toolId).assertEqual('flight.search');
      expect(train.dataTasks.length).assertEqual(1);
      expect(train.dataTasks[0].toolId).assertEqual('train.search');
      expect(both.dataTasks.length).assertEqual(2);
      expect(both.dataTasks[0].toolId).assertEqual('flight.search');
      expect(both.dataTasks[1].toolId).assertEqual('train.search');
    });

    it('tells later rounds not to repeat completed tools while allowing a different dependent tool', 0, async () => {
      const terminalStatuses: string[] = ['success', 'partial', 'empty', 'error'];
      for (let index = 0; index < terminalStatuses.length; index++) {
        const model: ObservationPromptAwareModel = new ObservationPromptAwareModel();
        const planner: MultiAgentLeaderPlanner = new MultiAgentLeaderPlanner(model);
        const input: InputUserPayload = {
          text: '根据上一轮结果继续回答',
          recentObservations: [{
            taskId: 'input-1:round-1:travel',
            toolId: 'travel.search',
            status: terminalStatuses[index],
            summary: '真实出行结果',
            entityRefs: ['travel-real-1']
          }, {
            taskId: 'older-input:round-1:flight',
            toolId: 'flight.search',
            status: 'success',
            summary: '旧 turn 结果',
            entityRefs: ['flight-old-1']
          }]
        };

        const decision: LeaderDecision = await planner.plan(
          inputMessage(), input, planningContext(), 2
        );

        expect(decision.roundAction).assertEqual('answer');
        expect(decision.dataTasks.length).assertEqual(0);
        expect(model.prompts[0].indexOf(
          'Current-turn completed Data tool IDs: ["travel.search"]'
        ) >= 0).assertTrue();
        expect(model.prompts[0].indexOf(
          'Data Agent owns same-tool adapter fallback and retry.'
        ) >= 0).assertTrue();
        expect(model.prompts[0].indexOf(
          'Current-turn completed Data tool IDs: ["travel.search","flight.search"]'
        )).assertEqual(-1);
      }

      const dependentModel: ObservationPromptAwareModel = new ObservationPromptAwareModel();
      const dependentInput: InputUserPayload = {
        text: '读取上一轮真实地点详情',
        recentObservations: [{
          taskId: 'input-1:round-1:travel',
          toolId: 'travel.search',
          status: 'success',
          summary: '真实地点 place-real-1',
          entityRefs: ['place-real-1']
        }]
      };
      const dependent: LeaderDecision = await new MultiAgentLeaderPlanner(dependentModel).plan(
        inputMessage(), dependentInput, planningContext(), 2
      );

      expect(dependent.dataTasks.length).assertEqual(1);
      expect(dependent.dataTasks[0].toolId).assertEqual('maps.place.details');
      expect(dependentModel.prompts[0].indexOf(
        'A different later-round tool is allowed only when it requires real prior output.'
      ) >= 0).assertTrue();
    });

    it('repairs one missing authority field once without exposing its output', 0, async () => {
      const model = new QueueLocalModel([MISSING_PERSONA_DECISION, LIVE_ANSWER_WITHOUT_REASON_CODE]);
      const planner = new MultiAgentLeaderPlanner(model);
      const input: InputUserPayload = { text: '你好' };

      const decision = await planner.plan(
        inputMessage(),
        input,
        planningContext(),
        1,
        (): boolean => true
      );

      expect(decision.reasonCode).assertEqual('host_answer');
      expect(model.prompts.length).assertEqual(2);
      expect(model.prompts[1].indexOf(model.prompts[0])).assertEqual(0);
      expect(model.prompts[1].indexOf('previous decision rejected by strict schema') >= 0).assertTrue();
      expect(model.prompts[1].indexOf('LIVE_PRIVATE_MARKER')).assertEqual(-1);
      expect(model.systemPrompts[1]).assertEqual(model.systemPrompts[0]);
      expect(model.prompts[1].indexOf('Round: 1') >= 0).assertTrue();
    });

    it('stops after one invalid or throwing strict-schema repair', 0, async () => {
      const model = new QueueLocalModel([MISSING_PERSONA_DECISION, MISSING_PERSONA_DECISION]);
      const throwingModel = new QueueLocalModel([MISSING_PERSONA_DECISION]);
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
      const absentModel = new QueueLocalModel([MISSING_PERSONA_DECISION, LIVE_ANSWER_WITHOUT_REASON_CODE]);
      const inactiveModel = new QueueLocalModel([MISSING_PERSONA_DECISION, LIVE_ANSWER_WITHOUT_REASON_CODE]);
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

    it('owns diagnostic reason codes for omitted forged and legacy values', 0, async () => {
      const omittedModel = new QueueLocalModel([LIVE_ANSWER_WITHOUT_REASON_CODE]);
      const forgedModel = new QueueLocalModel([VALID_ANSWER_DECISION]);
      const clarifyModel = new QueueLocalModel(['{"personaId":"travel_companion","skillId":"",' +
        '"requestedCapabilityIds":[],"roundAction":"clarify","dataTasks":[],' +
        '"uiIntent":{"purpose":"clarify","preferredDensity":"comfortable","requiredSections":[]},' +
        '"answer":"请提供城市"}']);
      const legacyModel = new QueueLocalModel(['{"personaId":"travel_companion","skillId":"",' +
        '"requestedCapabilityIds":["payment.create"],"roundAction":"legacy_handoff","dataTasks":[],' +
        '"uiIntent":{"purpose":"handoff","preferredDensity":"comfortable","requiredSections":[]},' +
        '"reasonCode":"forged_by_model"}']);
      const input: InputUserPayload = { text: '你好' };

      const omitted = await new MultiAgentLeaderPlanner(omittedModel).plan(
        inputMessage(), input, planningContext(), 1
      );
      const forged = await new MultiAgentLeaderPlanner(forgedModel).plan(
        inputMessage(), input, planningContext(), 1
      );
      const clarify = await new MultiAgentLeaderPlanner(clarifyModel).plan(
        inputMessage(), input, planningContext(), 1
      );
      const legacy = await new MultiAgentLeaderPlanner(legacyModel).plan(
        inputMessage(), input, planningContext(), 1
      );

      expect(omitted.reasonCode).assertEqual('host_answer');
      expect(forged.reasonCode).assertEqual('host_answer');
      expect(clarify.reasonCode).assertEqual('host_clarify');
      expect(legacy.reasonCode).assertEqual('unmigrated_tool');
      expect(omittedModel.prompts.length).assertEqual(1);
      expect(forgedModel.prompts.length).assertEqual(1);
      expect(clarifyModel.prompts.length).assertEqual(1);
      expect(legacyModel.prompts.length).assertEqual(1);
    });

    it('repairs a present malformed reason code while ignoring a valid model value', 0, async () => {
      const malformed: string = LIVE_ANSWER_WITHOUT_REASON_CODE.substring(
        0,
        LIVE_ANSWER_WITHOUT_REASON_CODE.length - 1
      ) + ',"reasonCode":42}';
      const model = new QueueLocalModel([malformed, VALID_ANSWER_DECISION]);

      const decision = await new MultiAgentLeaderPlanner(model).plan(
        inputMessage(),
        { text: '你好' },
        planningContext(),
        1,
        (): boolean => true
      );

      expect(decision.reasonCode).assertEqual('host_answer');
      expect(model.prompts.length).assertEqual(2);
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
