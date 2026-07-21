import {
  CreateDataTaskPayload,
  DataStepDecision,
  DataTaskPlanner,
  LocalModel,
  ObservationDigest
} from '@loop/agent-core';

const DECISION_KEYS: string = 'args,kind,summary,toolId';

interface JsonContainerFrame {
  object: boolean;
  expectingKey: boolean;
  keys: Set<string>;
}

export class ReadOnlyDataPlanner implements DataTaskPlanner {
  private readonly model: LocalModel;

  constructor(model: LocalModel) {
    this.model = model;
  }

  async next(
    task: CreateDataTaskPayload,
    observations: ObservationDigest[],
    _step: number
  ): Promise<DataStepDecision> {
    const safeObservations: ObservationDigest[] = this.boundedObservations(observations);
    const output: string = await this.model.complete(this.prompt(task, safeObservations));
    const trimmed: string = output.trim();
    if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) {
      throw new Error('Data planner requires exactly one JSON object.');
    }
    let parsed: Object;
    try {
      parsed = JSON.parse(trimmed) as Object;
    } catch (_error) {
      throw new Error('Data planner requires exactly one JSON object.');
    }
    if (this.hasDuplicateObjectKeys(trimmed)) {
      throw new Error('Data planner JSON contains duplicate object keys.');
    }
    return this.decision(parsed);
  }

  private prompt(task: CreateDataTaskPayload, observations: ObservationDigest[]): string {
    return 'You are the Appless Data Agent. Return one DataStepDecision JSON.\n' +
      'Use only allowed read tools. Maximum 3 steps. Preserve real IDs and sources.\n' +
      'Do not execute writes, system intents, web sessions, client actions, or code.\n' +
      'Task: ' + JSON.stringify(task) + '\nObservations: ' + JSON.stringify(observations);
  }

  private decision(parsed: Object): DataStepDecision {
    if (parsed === null || Array.isArray(parsed) ||
      Object.keys(parsed).sort().join(',') !== DECISION_KEYS) {
      throw new Error('Data decision contains missing or unknown fields.');
    }
    const values = parsed as Record<string, Object | string | number | boolean | null | undefined>;
    const kind = values['kind'];
    const toolId = values['toolId'];
    const args = values['args'];
    const summary = values['summary'];
    if ((kind !== 'call' && kind !== 'finish') ||
      typeof toolId !== 'string' || toolId.trim().length === 0 ||
      args === null || typeof args !== 'object' || Array.isArray(args) ||
      typeof summary !== 'string' || summary.trim().length === 0) {
      throw new Error('Data decision fields are malformed.');
    }
    return {
      kind: kind === 'call' ? 'call' : 'finish',
      toolId,
      args,
      summary
    };
  }

  private boundedObservations(values: ObservationDigest[]): ObservationDigest[] {
    const result: ObservationDigest[] = [];
    const start: number = values.length > 8 ? values.length - 8 : 0;
    for (let index = start; index < values.length; index++) {
      const value = values[index];
      result.push({
        taskId: this.boundedText(value.taskId, 128),
        toolId: this.boundedText(value.toolId, 128),
        status: this.boundedText(value.status, 32),
        summary: this.boundedText(value.summary, 240),
        entityRefs: this.boundedStrings(value.entityRefs, 16, 128)
      });
    }
    return result;
  }

  private boundedStrings(values: string[], maximum: number, length: number): string[] {
    const result: string[] = [];
    for (let index = 0; index < values.length && result.length < maximum; index++) {
      if (values[index].trim().length > 0) {
        result.push(this.boundedText(values[index], length));
      }
    }
    return result;
  }

  private boundedText(value: string, maximum: number): string {
    const trimmed: string = value.trim();
    return trimmed.length > maximum ? trimmed.substring(0, maximum) : trimmed;
  }

  private hasDuplicateObjectKeys(json: string): boolean {
    const frames: JsonContainerFrame[] = [];
    for (let index = 0; index < json.length; index++) {
      const character: string = json[index];
      if (character === '{' || character === '[') {
        frames.push({
          object: character === '{',
          expectingKey: character === '{',
          keys: new Set<string>()
        });
        continue;
      }
      if (character === '}' || character === ']') {
        frames.pop();
        continue;
      }
      if (character === ',') {
        if (frames.length > 0 && frames[frames.length - 1].object) {
          frames[frames.length - 1].expectingKey = true;
        }
        continue;
      }
      if (character !== '"') {
        continue;
      }
      let end: number = index + 1;
      let escaped: boolean = false;
      while (end < json.length) {
        const next: string = json[end];
        if (escaped) {
          escaped = false;
        } else if (next === '\\') {
          escaped = true;
        } else if (next === '"') {
          break;
        }
        end++;
      }
      const frame: JsonContainerFrame | undefined = frames.length === 0 ? undefined :
        frames[frames.length - 1];
      if (frame !== undefined && frame.object && frame.expectingKey) {
        const key: string = JSON.parse(json.substring(index, end + 1)) as string;
        if (frame.keys.has(key)) {
          return true;
        }
        frame.keys.add(key);
        frame.expectingKey = false;
      }
      index = end;
    }
    return false;
  }
}
