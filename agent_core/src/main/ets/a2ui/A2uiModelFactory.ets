import { common } from '@kit.AbilityKit';
import { LlmProvider } from '../model/LlmProvider';
import { A2uiModel } from './A2uiModel';
import { OpenAiA2uiModel } from './OpenAiA2uiModel';
import { ScriptedA2uiModel } from './ScriptedA2uiModel';

export interface A2uiModelInfo {
  model: A2uiModel;
  mode: 'llm' | 'scripted';
  modelName: string;
}

export async function createA2uiModelInfo(context: common.UIAbilityContext): Promise<A2uiModelInfo> {
  const provider = await LlmProvider.fromContext(context);
  if (provider.isConfigured()) {
    return {
      model: new OpenAiA2uiModel(provider),
      mode: 'llm',
      modelName: provider.model
    };
  }
  return {
    model: new ScriptedA2uiModel(),
    mode: 'scripted',
    modelName: 'scripted-a2ui'
  };
}
