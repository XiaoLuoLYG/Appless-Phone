import http from '@ohos.net.http';
import { ChatMessage } from '../../../ConversationContext';
import { LlmProvider } from '../../../../model/LlmProvider';
import {
  ActionPlanningFunctionTool,
  ActionPlanningModel,
  ActionPlanningModelRequest,
  ActionPlanningModelResult
} from './ActionPlanningModel';

const CONNECT_TIMEOUT_MS: number = 20000;
const READ_TIMEOUT_MS: number = 120000;

interface PlanningFunctionChoice {
  name: string;
}

interface PlanningToolChoice {
  type: 'function';
  function: PlanningFunctionChoice;
}

interface PlanningChatRequest {
  model: string;
  messages: ChatMessage[];
  temperature: number;
  stream: boolean;
  tools: ActionPlanningFunctionTool[];
  tool_choice: PlanningToolChoice;
  parallel_tool_calls: boolean;
}

interface ResponseToolFunction {
  name?: string;
  arguments?: string;
}

interface ResponseToolCall {
  type?: string;
  function?: ResponseToolFunction;
}

interface ResponseMessage {
  tool_calls?: ResponseToolCall[];
}

interface ResponseChoice {
  message?: ResponseMessage;
}

interface PlanningChatResponse {
  choices?: ResponseChoice[];
}

type RequestRecord =
  Record<string, Object | string | number | boolean | null | undefined>;

function modelResult(
  ok: boolean,
  argumentsJson: string = '',
  errorCode: string = '',
  message: string = ''
): ActionPlanningModelResult {
  return {
    ok,
    argumentsJson,
    errorCode,
    message
  };
}

function responsePreview(body: string): string {
  return body.length <= 2048 ? body : `${body.substring(0, 2048)}...`;
}

export function parseActionPlanningToolCallResponse(
  body: string,
  expectedToolName: string
): ActionPlanningModelResult {
  let response: PlanningChatResponse;
  try {
    response = JSON.parse(body) as PlanningChatResponse;
  } catch (_error) {
    return modelResult(
      false,
      '',
      'ACTION_PLAN_MODEL_RESPONSE_JSON_INVALID',
      'Action planning model response is not valid JSON.'
    );
  }
  const choices = response.choices;
  if (choices === undefined || choices.length !== 1 ||
    choices[0].message === undefined) {
    return modelResult(
      false,
      '',
      'ACTION_PLAN_MODEL_CHOICE_INVALID',
      'Action planning model must return exactly one choice.'
    );
  }
  const calls = choices[0].message?.tool_calls;
  if (calls === undefined || calls.length === 0) {
    return modelResult(
      false,
      '',
      'ACTION_PLAN_TOOL_CALL_MISSING',
      `Action planning model did not call ${expectedToolName}.`
    );
  }
  if (calls.length !== 1) {
    return modelResult(
      false,
      '',
      'ACTION_PLAN_TOOL_CALL_MULTIPLE',
      'Action planning model must make exactly one tool call.'
    );
  }
  const call = calls[0];
  if ((call.type !== undefined && call.type !== 'function') ||
    call.function === undefined ||
    call.function.name !== expectedToolName) {
    return modelResult(
      false,
      '',
      'ACTION_PLAN_TOOL_CALL_NAME_INVALID',
      'Action planning model called an unexpected function.'
    );
  }
  const argumentsJson = call.function.arguments;
  if (typeof argumentsJson !== 'string' || argumentsJson.trim().length === 0) {
    return modelResult(
      false,
      '',
      'ACTION_PLAN_TOOL_CALL_ARGUMENTS_MISSING',
      `${expectedToolName} arguments are missing.`
    );
  }
  return modelResult(true, argumentsJson);
}

export class OpenAiCompatibleActionPlanningModel
implements ActionPlanningModel {
  private readonly provider: LlmProvider;

  constructor(provider: LlmProvider) {
    this.provider = provider;
  }

  async submit(
    request: ActionPlanningModelRequest
  ): Promise<ActionPlanningModelResult> {
    if (!this.provider.isConfigured()) {
      return modelResult(
        false,
        '',
        'ACTION_PLAN_MODEL_NOT_CONFIGURED',
        'Action planning model is not configured.'
      );
    }
    const expectedToolName = request.submitTool.function.name;
    if (expectedToolName.trim().length === 0) {
      return modelResult(
        false,
        '',
        'ACTION_PLAN_TOOL_NAME_INVALID',
        'Action planning submit tool name must not be empty.'
      );
    }
    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(
        this.provider.chatCompletionsUrl(),
        {
          method: http.RequestMethod.POST,
          header: {
            'Authorization': `Bearer ${this.provider.apiKey}`,
            'Content-Type': 'application/json; charset=utf-8',
            'Accept': 'application/json'
          },
          extraData: this.buildRequestJson(request),
          expectDataType: http.HttpDataType.STRING,
          connectTimeout: CONNECT_TIMEOUT_MS,
          readTimeout: READ_TIMEOUT_MS
        }
      );
      const body = `${response.result ?? ''}`;
      if (response.responseCode < 200 || response.responseCode >= 300) {
        return modelResult(
          false,
          '',
          'ACTION_PLAN_MODEL_HTTP_FAILED',
          `Action planning model returned HTTP ${response.responseCode}: ` +
            responsePreview(body)
        );
      }
      return parseActionPlanningToolCallResponse(body, expectedToolName);
    } catch (error) {
      const message = error instanceof Error ? error.message : `${error}`;
      return modelResult(
        false,
        '',
        'ACTION_PLAN_MODEL_REQUEST_FAILED',
        `Action planning model request failed: ${message}`
      );
    } finally {
      httpRequest.destroy();
    }
  }

  private buildRequestJson(
    request: ActionPlanningModelRequest
  ): string {
    const choiceFunction: PlanningFunctionChoice = {
      name: request.submitTool.function.name
    };
    const toolChoice: PlanningToolChoice = {
      type: 'function',
      function: choiceFunction
    };
    const messages: ChatMessage[] = [{
      role: 'system',
      content: request.systemPrompt
    }, {
      role: 'user',
      content: request.userPrompt
    }];
    const base: PlanningChatRequest = {
      model: this.provider.model,
      messages,
      temperature: 0,
      stream: false,
      tools: [request.submitTool],
      tool_choice: toolChoice,
      parallel_tool_calls: false
    };
    return this.mergeCustomParameters(base);
  }

  private mergeCustomParameters(base: PlanningChatRequest): string {
    const customJson = this.provider.customParametersJson.trim();
    if (customJson.length === 0) {
      return JSON.stringify(base);
    }
    let custom: RequestRecord;
    try {
      const parsed = JSON.parse(customJson) as Object;
      if (parsed === null || Array.isArray(parsed)) {
        return JSON.stringify(base);
      }
      custom = parsed as RequestRecord;
    } catch (_error) {
      return JSON.stringify(base);
    }
    const merged: RequestRecord = {};
    const baseRecord = base as Object as RequestRecord;
    const baseKeys = Object.keys(baseRecord);
    for (let index = 0; index < baseKeys.length; index++) {
      merged[baseKeys[index]] = baseRecord[baseKeys[index]];
    }
    const blocked: string[] = [
      'model',
      'messages',
      'temperature',
      'stream',
      'tools',
      'tool_choice',
      'parallel_tool_calls',
      'response_format',
      'n',
      'functions',
      'function_call'
    ];
    const customKeys = Object.keys(custom);
    for (let index = 0; index < customKeys.length; index++) {
      const key = customKeys[index];
      if (blocked.indexOf(key) < 0) {
        merged[key] = custom[key];
      }
    }
    return JSON.stringify(merged);
  }
}
