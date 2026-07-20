import { describe, it, expect } from '@ohos/hypium';
import {
  ActionArgsValidator,
  ActionCatalog,
  ActionExecutionContext,
  ActionInputBinding,
  ActionPlan,
  ActionPlanOutcome,
  ActionPlanRunContext,
  ActionPlanRunner,
  ActionStepExecutionResult,
  ActionStepExecutor,
  ActionValidationResult,
  ClientActionAuthorizer,
  JsonPointerResult,
  JsonPointerSetResult,
  JsonValue,
  SurfaceActionAuthorizer,
  ToolDefinitionLookup,
  resolveJsonPointer,
  setJsonPointer
} from '@loop/agent-core';
import { ToolDefinition } from '@loop/agent-core';

type JsonRecord = Record<string, JsonValue | undefined>;

function json(raw: string): Object {
  return JSON.parse(raw) as Object;
}

function plan(raw: string): ActionPlan {
  return JSON.parse(raw) as ActionPlan;
}

function validPlan(): ActionPlan {
  return plan(
    '{"planId":"plan-1","turnId":"turn-1","surfaceId":"surface-1",' +
      '"label":"AI 回复并保存草稿","steps":[' +
      '{"stepId":"draft","actionId":"gmail.ai.reply.draft",' +
      '"args":{"threadId":"thread-real-1"}},' +
      '{"stepId":"save","actionId":"gmail.draft.create","args":{},' +
      '"inputFrom":[' +
      '{"target":"/to","stepId":"draft","path":"/to"},' +
      '{"target":"/subject","stepId":"draft","path":"/subject"},' +
      '{"target":"/body","stepId":"draft","path":"/body"},' +
      '{"target":"/threadId","stepId":"draft","path":"/threadId"}]}]}'
  );
}

function definition(toolId: string, actions: string[]): ToolDefinition {
  return {
    toolId: toolId,
    domain: 'gmail',
    intent: toolId,
    riskLevel: 'draft',
    backendPriority: ['oauth_api'],
    authModes: ['oauth'],
    inputSchema: toolId + 'Request',
    outputSchema: toolId + 'Result',
    a2uiComponent: 'GenericToolResults',
    actions: actions.slice()
  };
}

class PlanLookup implements ToolDefinitionLookup {
  find(toolId: string): ToolDefinition | null {
    if (toolId === 'gmail.thread.view') {
      return definition(toolId, ['gmail.ai.reply.draft']);
    }
    if (toolId === 'gmail.ai.reply.draft' ||
      toolId === 'gmail.draft.create' ||
      toolId === 'gmail.audit.record') {
      return definition(toolId, []);
    }
    return null;
  }
}

class ExactPlanSurface implements SurfaceActionAuthorizer {
  allows(
    conversationId: string,
    turnId: string,
    surfaceId: string,
    actionId: string,
    args: Object
  ): boolean {
    return conversationId === 'conversation-1' &&
      turnId === 'turn-1' &&
      surfaceId === 'surface-1' &&
      actionId === 'gmail.ai.reply.draft' &&
      JSON.stringify(args) === '{"threadId":"thread-real-1"}';
  }
}

class NoClientActions implements ClientActionAuthorizer {
  allows(_actionId: string, _args: Object): boolean {
    return false;
  }
}

class PlanArgsValidator implements ActionArgsValidator {
  rejectSecondSave: boolean = false;
  saveCalls: number = 0;

  validate(actionId: string, args: Object): ActionValidationResult {
    if (actionId === 'gmail.draft.create') {
      this.saveCalls += 1;
      if (this.rejectSecondSave && this.saveCalls > 1) {
        return {
          ok: false,
          code: 'ARGS_CHANGED',
          message: 'Current draft args are no longer allowed.'
        };
      }
    }
    return {
      ok: true,
      code: '',
      message: ''
    };
  }
}

function success(output: JsonValue): ActionStepExecutionResult {
  return {
    status: 'success',
    output: output
  };
}

class RecordingExecutor implements ActionStepExecutor {
  actionIds: string[] = [];
  serializedArgs: string[] = [];
  results: ActionStepExecutionResult[];

  constructor(results: ActionStepExecutionResult[]) {
    this.results = results;
  }

  async execute(
    actionId: string,
    args: Object,
    _context: ActionExecutionContext
  ): Promise<ActionStepExecutionResult> {
    this.actionIds.push(actionId);
    this.serializedArgs.push(JSON.stringify(args));
    return this.results[this.actionIds.length - 1];
  }
}

class ThrowingExecutor implements ActionStepExecutor {
  async execute(
    _actionId: string,
    _args: Object,
    _context: ActionExecutionContext
  ): Promise<ActionStepExecutionResult> {
    throw new Error('executor boundary failure');
  }
}

function context(): ActionPlanRunContext {
  return {
    conversationId: 'conversation-1',
    sourceToolId: 'gmail.thread.view'
  };
}

function runner(
  executor: ActionStepExecutor,
  validator: PlanArgsValidator = new PlanArgsValidator()
): ActionPlanRunner {
  return new ActionPlanRunner(
    new ActionCatalog(
      new PlanLookup(),
      new ExactPlanSurface(),
      new NoClientActions(),
      validator
    ),
    executor
  );
}

function validationCode(candidate: ActionPlan): string {
  return runner(new RecordingExecutor([])).validate(candidate, context()).errorCode;
}

function asRecord(value: JsonValue | undefined): JsonRecord {
  return value as JsonRecord;
}

export default function actionPlanRunnerTest() {
  describe('actionPlanRunner', () => {
    it('accepts only one to five serial steps with nonempty unique ids', 0, () => {
      const empty = plan(
        '{"planId":"p","turnId":"turn-1","surfaceId":"surface-1","label":"x","steps":[]}'
      );
      const six = plan(
        '{"planId":"p","turnId":"turn-1","surfaceId":"surface-1","label":"x","steps":[' +
          '{"stepId":"1","actionId":"gmail.ai.reply.draft","args":{"threadId":"thread-real-1"}},' +
          '{"stepId":"2","actionId":"gmail.draft.create","args":{}},' +
          '{"stepId":"3","actionId":"gmail.draft.create","args":{}},' +
          '{"stepId":"4","actionId":"gmail.draft.create","args":{}},' +
          '{"stepId":"5","actionId":"gmail.draft.create","args":{}},' +
          '{"stepId":"6","actionId":"gmail.draft.create","args":{}}]}'
      );
      const emptyId = plan(
        '{"planId":"p","turnId":"turn-1","surfaceId":"surface-1","label":"x",' +
          '"steps":[{"stepId":"","actionId":"gmail.ai.reply.draft","args":{"threadId":"thread-real-1"}}]}'
      );
      const duplicate = plan(
        '{"planId":"p","turnId":"turn-1","surfaceId":"surface-1","label":"x","steps":[' +
          '{"stepId":"same","actionId":"gmail.ai.reply.draft","args":{"threadId":"thread-real-1"}},' +
          '{"stepId":"same","actionId":"gmail.draft.create","args":{}}]}'
      );

      expect(validationCode(empty)).assertEqual('ACTION_PLAN_STEP_COUNT');
      expect(validationCode(six)).assertEqual('ACTION_PLAN_STEP_COUNT');
      expect(validationCode(emptyId)).assertEqual('ACTION_PLAN_STEP_ID');
      expect(validationCode(duplicate)).assertEqual('ACTION_PLAN_STEP_ID_DUPLICATE');
    });

    it('rejects unknown actions and a first action outside the exact source surface', 0, () => {
      const unknown = plan(
        '{"planId":"p","turnId":"turn-1","surfaceId":"surface-1","label":"x","steps":[' +
          '{"stepId":"draft","actionId":"gmail.ai.reply.draft","args":{"threadId":"thread-real-1"}},' +
          '{"stepId":"invented","actionId":"gmail.send.invented","args":{}}]}'
      );
      const wrongFirst = plan(
        '{"planId":"p","turnId":"turn-1","surfaceId":"surface-1","label":"x",' +
          '"steps":[{"stepId":"save","actionId":"gmail.draft.create","args":{}}]}'
      );

      expect(validationCode(unknown)).assertEqual('ACTION_NOT_REGISTERED');
      expect(validationCode(wrongFirst)).assertEqual('ACTION_NOT_DECLARED');
    });

    it('allows bindings only from existing earlier steps', 0, () => {
      const same = plan(
        '{"planId":"p","turnId":"turn-1","surfaceId":"surface-1","label":"x","steps":[' +
          '{"stepId":"draft","actionId":"gmail.ai.reply.draft","args":{"threadId":"thread-real-1"},' +
          '"inputFrom":[{"target":"/body","stepId":"draft","path":"/body"}]}]}'
      );
      const later = plan(
        '{"planId":"p","turnId":"turn-1","surfaceId":"surface-1","label":"x","steps":[' +
          '{"stepId":"draft","actionId":"gmail.ai.reply.draft","args":{"threadId":"thread-real-1"},' +
          '"inputFrom":[{"target":"/body","stepId":"save","path":"/body"}]},' +
          '{"stepId":"save","actionId":"gmail.draft.create","args":{}}]}'
      );
      const nonexistent = validPlan();
      (nonexistent.steps[1].inputFrom as ActionInputBinding[])[0].stepId = 'missing';

      expect(validationCode(same)).assertEqual('ACTION_PLAN_BINDING_SOURCE');
      expect(validationCode(later)).assertEqual('ACTION_PLAN_BINDING_SOURCE');
      expect(validationCode(nonexistent)).assertEqual('ACTION_PLAN_BINDING_SOURCE');
    });

    it('rejects malformed pointers and recursive executable payload fields', 0, () => {
      const noSlash = validPlan();
      (noSlash.steps[1].inputFrom as ActionInputBinding[])[0].path = 'to';
      const badEscape = validPlan();
      (badEscape.steps[1].inputFrom as ActionInputBinding[])[0].target = '/bad~2key';
      const dangerous = plan(
        '{"planId":"p","turnId":"turn-1","surfaceId":"surface-1","label":"x","steps":[' +
          '{"stepId":"draft","actionId":"gmail.ai.reply.draft","args":{' +
          '"threadId":"thread-real-1","nested":{"parallel":[]}}}]}'
      );
      const topLevelDangerous = plan(
        '{"planId":"p","turnId":"turn-1","surfaceId":"surface-1","label":"x","script":"bad",' +
          '"steps":[{"stepId":"draft","actionId":"gmail.ai.reply.draft",' +
          '"args":{"threadId":"thread-real-1"}}]}'
      );
      const expression = validPlan();
      (expression.steps[0].args as JsonRecord)['expression'] = 'bad';
      const loop = validPlan();
      (loop.steps[0].args as JsonRecord)['loop'] = json('{}');
      const branches = validPlan();
      (branches.steps[0].args as JsonRecord)['branches'] = JSON.parse('[]') as Object;

      expect(validationCode(noSlash)).assertEqual('JSON_POINTER_INVALID');
      expect(validationCode(badEscape)).assertEqual('JSON_POINTER_INVALID');
      expect(validationCode(dangerous)).assertEqual('ACTION_PLAN_FORBIDDEN_FIELD');
      expect(validationCode(topLevelDangerous)).assertEqual('ACTION_PLAN_FORBIDDEN_FIELD');
      expect(validationCode(expression)).assertEqual('ACTION_PLAN_FORBIDDEN_FIELD');
      expect(validationCode(loop)).assertEqual('ACTION_PLAN_FORBIDDEN_FIELD');
      expect(validationCode(branches)).assertEqual('ACTION_PLAN_FORBIDDEN_FIELD');
    });

    it('resolves RFC 6901 escapes object keys arrays and the whole document', 0, () => {
      const document = JSON.parse(
        '{"a/b":{"m~n":[{"value":"zero"},{"value":"one"}]},"":"empty-key"}'
      ) as JsonValue;
      const escaped: JsonPointerResult =
        resolveJsonPointer(document, '/a~1b/m~0n/1/value');
      const whole: JsonPointerResult = resolveJsonPointer(document, '');
      const emptyKey: JsonPointerResult = resolveJsonPointer(document, '/');

      expect(escaped.ok).assertTrue();
      expect(escaped.value as string).assertEqual('one');
      expect(whole.ok).assertTrue();
      expect(JSON.stringify(whole.value)).assertEqual(JSON.stringify(document));
      expect(emptyKey.value as string).assertEqual('empty-key');
    });

    it('rejects noncanonical array indexes invalid escapes and prototype segments', 0, () => {
      const document = JSON.parse('{"items":["zero","one"],"constructor":{"x":1}}') as JsonValue;
      const leadingZero = resolveJsonPointer(document, '/items/01');
      const negative = resolveJsonPointer(document, '/items/-1');
      const escape = resolveJsonPointer(document, '/items/~');
      const inherited = resolveJsonPointer(JSON.parse('{}') as JsonValue, '/toString');
      const constructor = resolveJsonPointer(document, '/constructor/x');
      const proto = setJsonPointer(document, '/__proto__/polluted', 'yes');
      const prototype = setJsonPointer(document, '/prototype/polluted', 'yes');

      expect(leadingZero.ok).assertFalse();
      expect(negative.ok).assertFalse();
      expect(escape.ok).assertFalse();
      expect(inherited.ok).assertFalse();
      expect(constructor.ok).assertFalse();
      expect(proto.ok).assertFalse();
      expect(prototype.ok).assertFalse();
    });

    it('never invokes prototype getters selected by pointer text', 0, () => {
      class GetterPayload {
        reads: number = 0;

        get secret(): string {
          this.reads += 1;
          return 'not-safe';
        }
      }

      const payload = new GetterPayload();
      const result = resolveJsonPointer(payload as Object, '/secret');

      expect(result.ok).assertFalse();
      expect(payload.reads).assertEqual(0);
    });

    it('sets only the explicit target on a deep clone and supports root replacement', 0, () => {
      const original = JSON.parse('{"body":"old","nested":{"keep":true}}') as JsonValue;
      const overwrite: JsonPointerSetResult = setJsonPointer(original, '/body', 'new');
      const root: JsonPointerSetResult =
        setJsonPointer(original, '', JSON.parse('{"replacement":true}') as JsonValue);

      expect(overwrite.ok).assertTrue();
      expect(JSON.stringify(overwrite.value)).assertEqual('{"body":"new","nested":{"keep":true}}');
      expect(JSON.stringify(original)).assertEqual('{"body":"old","nested":{"keep":true}}');
      expect(root.ok).assertTrue();
      expect(JSON.stringify(root.value)).assertEqual('{"replacement":true}');
    });

    it('binds prior output into cloned args and executes serially', 0, async () => {
      const candidate = validPlan();
      const executor = new RecordingExecutor([
        success(json(
          '{"to":"alice@example.com","subject":"Re: Status","body":"Draft body",' +
            '"threadId":"thread-real-1"}'
        )),
        success(json('{"draftId":"draft-real-1"}'))
      ]);

      const outcome: ActionPlanOutcome = await runner(executor).run(candidate, context());

      expect(outcome.status).assertEqual('success');
      expect(executor.actionIds.join(',')).assertEqual(
        'gmail.ai.reply.draft,gmail.draft.create'
      );
      expect(executor.serializedArgs[1]).assertEqual(
        '{"to":"alice@example.com","subject":"Re: Status","body":"Draft body",' +
          '"threadId":"thread-real-1"}'
      );
      expect(JSON.stringify(candidate.steps[1].args)).assertEqual('{}');
    });

    it('fails a missing source path before executing the target action', 0, async () => {
      const executor = new RecordingExecutor([
        success(json('{"subject":"missing body"}')),
        success(json('{"draftId":"must-not-run"}'))
      ]);

      const outcome = await runner(executor).run(validPlan(), context());

      expect(outcome.status).assertEqual('error');
      expect(outcome.failedStepId).assertEqual('save');
      expect(outcome.errorCode).assertEqual('JSON_POINTER_MISSING');
      expect(executor.actionIds.join(',')).assertEqual('gmail.ai.reply.draft');
    });

    it('fails a wrong target parent before executing the target action', 0, async () => {
      const candidate = validPlan();
      candidate.steps[1].args = json('{"nested":"not-an-object"}');
      candidate.steps[1].inputFrom = [
        { target: '/nested/body', stepId: 'draft', path: '/body' }
      ];
      const executor = new RecordingExecutor([
        success(json('{"body":"Draft body"}')),
        success(json('{"draftId":"must-not-run"}'))
      ]);

      const outcome = await runner(executor).run(candidate, context());

      expect(outcome.status).assertEqual('error');
      expect(outcome.failedStepId).assertEqual('save');
      expect(outcome.errorCode).assertEqual('JSON_POINTER_TARGET_TYPE');
      expect(executor.actionIds.length).assertEqual(1);
    });

    it('revalidates the fully bound args immediately before target execution', 0, async () => {
      const validator = new PlanArgsValidator();
      validator.rejectSecondSave = true;
      const executor = new RecordingExecutor([
        success(json(
          '{"to":"alice@example.com","subject":"Re: Status","body":"Draft body",' +
            '"threadId":"thread-real-1"}'
        )),
        success(json('{"draftId":"must-not-run"}'))
      ]);

      const outcome = await runner(executor, validator).run(validPlan(), context());

      expect(outcome.status).assertEqual('error');
      expect(outcome.failedStepId).assertEqual('save');
      expect(outcome.errorCode).assertEqual('ARGS_CHANGED');
      expect(validator.saveCalls).assertEqual(2);
      expect(executor.actionIds.length).assertEqual(1);
    });

    it('uses root-target replacement only when the bound result is an args object', 0, async () => {
      const candidate = validPlan();
      candidate.steps[1].args = json('{"old":true}');
      candidate.steps[1].inputFrom = [
        { target: '', stepId: 'draft', path: '' }
      ];
      const executor = new RecordingExecutor([
        success(json('{"body":"whole object"}')),
        success(json('{"draftId":"draft-real-1"}'))
      ]);

      const outcome = await runner(executor).run(candidate, context());

      expect(outcome.status).assertEqual('success');
      expect(executor.serializedArgs[1]).assertEqual('{"body":"whole object"}');

      const primitiveExecutor = new RecordingExecutor([
        success('not-an-args-object'),
        success(json('{"draftId":"must-not-run"}'))
      ]);
      const primitiveOutcome = await runner(primitiveExecutor).run(candidate, context());
      expect(primitiveOutcome.status).assertEqual('error');
      expect(primitiveOutcome.failedStepId).assertEqual('save');
      expect(primitiveOutcome.errorCode).assertEqual('ACTION_ARGS_MALFORMED');
      expect(primitiveExecutor.actionIds.length).assertEqual(1);
    });

    it('stops after the first non-success without rollback or later execution', 0, async () => {
      const candidate = validPlan();
      candidate.steps.push(plan(
        '{"planId":"p","turnId":"turn-1","surfaceId":"surface-1","label":"x",' +
          '"steps":[{"stepId":"audit","actionId":"gmail.audit.record","args":{}}]}'
      ).steps[0]);
      const executor = new RecordingExecutor([
        success(json(
          '{"to":"alice@example.com","subject":"Re: Status","body":"Draft body",' +
            '"threadId":"thread-real-1"}'
        )),
        {
          status: 'paused',
          errorCode: 'ACTION_TIMEOUT',
          message: 'Executor timeout.'
        },
        success(json('{"auditId":"must-not-run"}'))
      ]);

      const outcome = await runner(executor).run(candidate, context());

      expect(outcome.status).assertEqual('paused');
      expect(outcome.failedStepId).assertEqual('save');
      expect(outcome.errorCode).assertEqual('ACTION_TIMEOUT');
      expect(outcome.completedStepIds.join(',')).assertEqual('draft');
      expect(executor.actionIds.join(',')).assertEqual(
        'gmail.ai.reply.draft,gmail.draft.create'
      );
    });

    it('contains executor throws as typed error outcomes', 0, async () => {
      let outcome: ActionPlanOutcome = {
        status: 'success',
        completedStepIds: [],
        outputs: []
      };

      try {
        outcome = await runner(new ThrowingExecutor()).run(validPlan(), context());
      } catch (_error) {
      }

      expect(outcome.status).assertEqual('error');
      expect(outcome.failedStepId).assertEqual('draft');
      expect(outcome.errorCode).assertEqual('ACTION_EXECUTOR_FAILED');
    });
  });
}
