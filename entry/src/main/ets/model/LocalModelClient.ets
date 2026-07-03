import { AgentEvent, LoopBackend, LoopBackendRequest, LoopMessage, LoopToolTrace } from '@loop/agent-core';
import {
  A2uiCallResult,
  A2uiEnvelope,
  A2uiMessage,
  A2uiPersonaData,
  A2uiPersonaMemoryData,
  A2uiRuntimeDataModel,
  A2uiSurfaceState,
  A2uiToolRequestData
} from '@loop/agent-core';
import { parseA2uiJsonl } from '@loop/agent-core';
import { A2uiSurfaceStore } from '@loop/agent-core';
import { LocalModelSettings } from '@loop/agent-core';
import { aiLogError, aiLogInfo } from '@loop/agent-core';
import { attachPersonaDataToSurface } from './PersonaA2ui';
import {
  memoryUpdateSurface,
  parsePersonaMemoryUpdateInput,
  PersonaMemoryUpdateRequest
} from './PersonaMemoryUpdate';
import { preparePersonaPrompt } from './PersonaPrompt';
import { PersonaMemoryRuntimeData, PersonaRuntimeData } from './PersonaTypes';

export interface A2uiStreamMeta {
  thinkClosed: boolean;
}

export type A2uiSurfaceCallback = (surface: A2uiSurfaceState, raw: string, meta?: A2uiStreamMeta) => void;
export type PersonaMemoryUpdateCallback = (update: PersonaMemoryUpdateRequest) => void;

export function modelThinkCloseSeen(text: string): boolean {
  const lower = text.toLowerCase();
  return lower.indexOf('</think>') >= 0;
}

export function resolveSystemPrompt(_prompt: string = ''): string {
  return 'AIPhoneDemo temporary Loopy adapter. Model loop and tool execution are provided by @loop/agent-core.';
}

export function buildChatCompletionsUrl(baseUrl: string): string {
  let cleaned = baseUrl.trim();
  while (cleaned.endsWith('/')) {
    cleaned = cleaned.substring(0, cleaned.length - 1);
  }
  if (cleaned.endsWith('/v1/chat/completions') || cleaned.endsWith('/chat/completions')) {
    return cleaned;
  }
  if (cleaned.endsWith('/v1')) {
    return cleaned + '/chat/completions';
  }
  return cleaned + '/v1/chat/completions';
}

function loopHistory(history: A2uiMessage[]): LoopMessage[] {
  const messages: LoopMessage[] = [];
  history.forEach((item: A2uiMessage) => {
    if (item.role === 'user' || item.role === 'assistant') {
      messages.push({
        role: item.role,
        content: item.content
      });
    }
  });
  return messages;
}

function applyEnvelopes(store: A2uiSurfaceStore, envelopes: A2uiEnvelope[]): string {
  let error = '';
  envelopes.forEach((envelope: A2uiEnvelope) => {
    const result = store.apply(envelope);
    if (!result.ok && error.length === 0) {
      error = result.error;
    }
  });
  return error;
}

function emptyToolRequest(): A2uiToolRequestData {
  return {
    toolId: '',
    prompt: '',
    actionId: ''
  };
}

function clearExecutedToolRequests(surface: A2uiSurfaceState): A2uiSurfaceState {
  let dataModelJson = surface.dataModelJson;
  try {
    const model = JSON.parse(dataModelJson.length > 0 ? dataModelJson : '{}') as A2uiRuntimeDataModel;
    model.toolRequest = emptyToolRequest();
    model.toolRequests = [];
    dataModelJson = JSON.stringify(model);
  } catch (_err) {
    return surface;
  }
  return {
    surfaceId: surface.surfaceId,
    rootId: surface.rootId,
    title: surface.title,
    intent: surface.intent,
    status: surface.status,
    components: surface.components,
    dataModelJson: dataModelJson,
    error: surface.error,
    sequence: surface.sequence
  };
}

function loopyAssistantText(finalAnswer: string, raw: string): string {
  if (finalAnswer.trim().length > 0) {
    return finalAnswer;
  }
  return raw;
}

function requestDebug(settings: LocalModelSettings, prompt: string, history: A2uiMessage[]): string {
  return JSON.stringify({
    endpoint: '@loop/agent-core/LoopBackend',
    provider: settings.provider,
    baseUrl: settings.baseUrl,
    model: settings.model,
    promptChars: prompt.length,
    historyTurns: history.length
  });
}

function a2uiPersonaData(persona: PersonaRuntimeData): A2uiPersonaData {
  return {
    id: persona.id,
    name: persona.name,
    avatarKey: persona.avatarKey,
    status: persona.status,
    reason: persona.reason
  };
}

function a2uiPersonaMemoryData(memory: PersonaMemoryRuntimeData): A2uiPersonaMemoryData {
  return {
    summary: memory.summary,
    preferences: memory.preferences
  };
}

function firstPersonaMemoryUpdate(toolCalls: LoopToolTrace[], activePersonaId: string): PersonaMemoryUpdateRequest | null {
  for (let index = 0; index < toolCalls.length; index++) {
    const toolCall = toolCalls[index];
    if (toolCall.toolId === 'memory.update') {
      return parsePersonaMemoryUpdateInput(toolCall.input, activePersonaId);
    }
  }
  return null;
}

export async function callLocalModel(
  settings: LocalModelSettings,
  prompt: string,
  history: A2uiMessage[],
  onSurface: A2uiSurfaceCallback,
  initialSurface: A2uiSurfaceState | null = null,
  onPersonaMemoryUpdate: PersonaMemoryUpdateCallback | null = null
): Promise<A2uiCallResult> {
  const store = new A2uiSurfaceStore();
  if (initialSurface !== null) {
    store.seed(initialSurface);
  }

  let raw = '';
  let error = '';
  let loopDebug = '';
  const preparedPersona = preparePersonaPrompt(prompt);
  const runtimePersona = a2uiPersonaData(preparedPersona.runtime);
  const runtimePersonaMemory = a2uiPersonaMemoryData(preparedPersona.memoryRuntime);
  const surfaceWithPersona = (surface: A2uiSurfaceState): A2uiSurfaceState => {
    return clearExecutedToolRequests(attachPersonaDataToSurface(surface, runtimePersona, runtimePersonaMemory));
  };
  const debug = requestDebug(settings, prompt, history);
  const backend = new LoopBackend();
  const request: LoopBackendRequest = {
    prompt: preparedPersona.modelPrompt,
    userPrompt: preparedPersona.userPrompt,
    history: loopHistory(history),
    modelSettings: {
      provider: settings.provider,
      baseUrl: settings.baseUrl,
      apiKey: settings.apiKey,
      model: settings.model,
      customParametersJson: settings.customParametersJson
    },
    surfaceId: 'surface_model',
    actionId: 'model_tool_request',
    args: preparedPersona.toolArgs,
    persona: preparedPersona.runtime as Object,
    maxSteps: 6
  };

  try {
    const result = await backend.run(request, {
      onEvent: (event: AgentEvent): void => {
        loopDebug += event.kind + ': ' + event.text + '\n';
        aiLogInfo('[AIPhone][LoopyEvent] kind=' + event.kind + ' text=' + event.text.substring(0, 240));
      },
      onA2uiJsonl: (line: string): void => {
        raw += line + '\n';
        const parsed = parseA2uiJsonl(line + '\n');
        if (parsed.error.length > 0) {
          error = parsed.error;
          aiLogError('[AIPhone][LoopyA2uiParseError] ' + parsed.error);
          return;
        }
        const applyError = applyEnvelopes(store, parsed.envelopes);
        if (applyError.length > 0) {
          error = applyError;
          aiLogError('[AIPhone][LoopyA2uiApplyError] ' + applyError);
          return;
        }
        onSurface(surfaceWithPersona(store.getSurface()), raw, { thinkClosed: true });
      }
    });
    if (result.ok) {
      aiLogInfo('[AIPhone][ModelRawResponse] code=200 source=loopy');
    }
    if (result.toolCalls.length === 0) {
      aiLogInfo('[AIPhone][ToolRequest] none');
    } else {
      result.toolCalls.forEach((toolCall) => {
        if (toolCall.toolId.length > 0) {
          aiLogInfo('[AIPhone][ToolRequest] toolId=' + toolCall.toolId + ' source=loopy inputChars=' + toolCall.input.length.toString());
          aiLogInfo('[AIPhone][ToolResult] ok=true toolId=' + toolCall.toolId + ' source=loopy observationChars=' + toolCall.observation.length.toString());
        }
      });
    }
    if (result.error.length > 0 && error.length === 0) {
      error = result.error;
    }
    if (raw.trim().length === 0 && error.length > 0) {
      store.applyError('Loopy 后端异常', error);
    }
    const memoryUpdate = firstPersonaMemoryUpdate(result.toolCalls, preparedPersona.runtime.id);
    if (memoryUpdate !== null && error.length === 0) {
      if (onPersonaMemoryUpdate !== null) {
        onPersonaMemoryUpdate(memoryUpdate);
      }
      const updateSurface = clearExecutedToolRequests(memoryUpdateSurface('surface_model', memoryUpdate));
      onSurface(updateSurface, raw, { thinkClosed: true });
      return {
        ok: result.ok,
        raw: raw,
        error: error,
        requestDebug: debug,
        assistantDebug: memoryUpdate.personaId + ' memory updated: ' + memoryUpdate.summary,
        surface: updateSurface
      };
    }
    return {
      ok: result.ok && error.length === 0,
      raw: raw,
      error: error,
      requestDebug: debug,
      assistantDebug: loopyAssistantText(result.finalAnswer, loopDebug.length > 0 ? loopDebug : result.raw),
      surface: surfaceWithPersona(store.getSurface())
    };
  } catch (err) {
    const message = err instanceof Error ? err.message : JSON.stringify(err);
    aiLogError('[AIPhone][LoopyException] ' + message);
    store.applyError('Loopy 后端异常', message);
    return {
      ok: false,
      raw: raw,
      error: message,
      requestDebug: debug,
      assistantDebug: loopDebug,
      surface: surfaceWithPersona(store.getSurface())
    };
  }
}
