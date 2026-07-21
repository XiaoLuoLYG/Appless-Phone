import { describe, expect, it } from '@ohos/hypium';
import {
  CreateDataTaskPayload,
  DataStepDecision,
  LocalModel,
  ObservationDigest
} from '@loop/agent-core';
import { ReadOnlyDataPlanner } from '../main/ets/pages/A2uiHome/agent/ReadOnlyDataPlanner';

class QueueLocalModel implements LocalModel {
  prompts: string[] = [];
  private readonly outputs: string[];

  constructor(outputs: string[]) {
    this.outputs = outputs.slice();
  }

  async complete(prompt: string): Promise<string> {
    this.prompts.push(prompt);
    if (this.outputs.length === 0) {
      throw new Error('No scripted Data planner output');
    }
    return this.outputs.shift() as string;
  }
}

function dataTask(): CreateDataTaskPayload {
  return {
    taskId: 'data-1',
    roundId: 'round-1',
    skillId: '',
    goal: '查天气',
    allowedToolIds: ['dynamic.search'],
    toolId: 'dynamic.search',
    outputSchema: 'dynamicToolConnect',
    args: new Object(),
    required: true
  };
}

function observations(): ObservationDigest[] {
  const values: ObservationDigest[] = [];
  for (let index = 0; index < 9; index++) {
    const refs: string[] = [];
    for (let refIndex = 0; refIndex < 20; refIndex++) {
      refs.push('entity-' + refIndex.toString() + '-'.repeat(130));
    }
    values.push({
      taskId: 'task-' + index.toString(),
      toolId: 'dynamic.search',
      status: 'success',
      summary: 'x'.repeat(300),
      entityRefs: refs
    });
  }
  return values;
}

async function fails(output: string): Promise<boolean> {
  const planner: ReadOnlyDataPlanner = new ReadOnlyDataPlanner(new QueueLocalModel([output]));
  try {
    await planner.next(dataTask(), [], 1);
    return false;
  } catch (_error) {
    return true;
  }
}

export default function readOnlyDataPlannerTest() {
  describe('readOnlyDataPlanner', () => {
    it('parses one exact decision and sends only bounded observation digests', 0, async () => {
      const output: string = '{"kind":"call","toolId":"dynamic.search",' +
        '"args":{"query":"深圳天气"},"summary":"read weather"}';
      const model: QueueLocalModel = new QueueLocalModel([output]);
      const planner: ReadOnlyDataPlanner = new ReadOnlyDataPlanner(model);

      const decision: DataStepDecision = await planner.next(dataTask(), observations(), 2);

      expect(decision.kind).assertEqual('call');
      expect(decision.toolId).assertEqual('dynamic.search');
      expect(model.prompts[0].indexOf('You are the Appless Data Agent. Return one DataStepDecision JSON.'))
        .assertEqual(0);
      expect(model.prompts[0].indexOf('Maximum 3 steps. Preserve real IDs and sources.'))
        .assertLarger(-1);
      expect(model.prompts[0].indexOf('Do not execute writes, system intents, web sessions, client actions, or code.'))
        .assertLarger(-1);
      const observationText: string = model.prompts[0].split('\nObservations: ')[1];
      const bounded: ObservationDigest[] = JSON.parse(observationText) as ObservationDigest[];
      expect(bounded.length).assertEqual(8);
      expect(bounded[0].taskId).assertEqual('task-1');
      expect(bounded[0].summary.length).assertEqual(240);
      expect(bounded[0].entityRefs.length).assertEqual(16);
      expect(bounded[0].entityRefs[0].length).assertEqual(128);
    });

    it('rejects prose arrays duplicate keys extra fields and malformed decisions', 0, async () => {
      const valid: string = '{"kind":"finish","toolId":"dynamic.search","args":{},"summary":"done"}';
      const duplicateTop: string = '{"kind":"finish","kind":"call",' +
        '"toolId":"dynamic.search","args":{},"summary":"done"}';
      const duplicateNested: string = '{"kind":"call","toolId":"dynamic.search",' +
        '"args":{"query":"a","query":"b"},"summary":"read"}';
      const extra: string = valid.substring(0, valid.length - 1) + ',"providerResult":{}}';
      const badKind: string = valid.replace('"finish"', '"write"');
      const badArgs: string = valid.replace('"args":{}', '"args":[]');

      expect(await fails('model says ' + valid)).assertTrue();
      expect(await fails('[' + valid + ']')).assertTrue();
      expect(await fails(valid + valid)).assertTrue();
      expect(await fails(duplicateTop)).assertTrue();
      expect(await fails(duplicateNested)).assertTrue();
      expect(await fails(extra)).assertTrue();
      expect(await fails(badKind)).assertTrue();
      expect(await fails(badArgs)).assertTrue();
    });
  });
}
