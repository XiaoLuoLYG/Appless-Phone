import { common } from '@kit.AbilityKit';
import { SkillSnapshot } from '../skill/SkillSnapshot';
import { LocalModel } from './LocalModel';
import { LlmProvider } from './LlmProvider';
import { OpenAiCompatibleModel } from './OpenAiCompatibleModel';
import { ScriptedLocalModel } from './ScriptedLocalModel';

export interface LoopModelInfo {
  model: LocalModel;
  mode: 'llm' | 'scripted';
  modelName: string;
}

export async function createLoopModel(context: common.UIAbilityContext, skillSnapshot?: SkillSnapshot): Promise<LocalModel> {
  return (await createLoopModelInfo(context, skillSnapshot)).model;
}

export async function createLoopModelInfo(
  context: common.UIAbilityContext,
  skillSnapshot?: SkillSnapshot
): Promise<LoopModelInfo> {
  const provider = await LlmProvider.fromContext(context);
  if (provider.isConfigured()) {
    return {
      model: new OpenAiCompatibleModel(provider, skillSnapshot),
      mode: 'llm',
      modelName: provider.model
    };
  }
  return {
    model: new ScriptedLocalModel(),
    mode: 'scripted',
    modelName: 'scripted-local'
  };
}
