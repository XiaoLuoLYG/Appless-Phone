import { ConversationContext } from '../agent/ConversationContext';
import {
  A2uiComponentDef,
  CreateSurfaceBody,
  CreateSurfaceEnvelope,
  UpdateComponentsBody,
  UpdateComponentsEnvelope
} from './A2uiTypes';
import { A2UI_VERSION, AGENUI_CATALOG_ID } from './A2uiProtocol';
import { A2uiModel } from './A2uiModel';

export function buildTaskCardComponents(userTask: string, includeSetupHint: boolean): A2uiComponentDef[] {
  const safeTask = userTask.replace(/"/g, '\\"');
  const titleText = userTask.length > 48 ? `${userTask.substring(0, 45)}…` : userTask;

  const root: A2uiComponentDef = {
    id: 'root',
    component: 'Card',
    child: 'content_col'
  };
  const contentCol: A2uiComponentDef = {
    id: 'content_col',
    component: 'Column',
    children: includeSetupHint ? ['title', 'body', 'hint'] : ['title', 'body'],
    align: 'stretch',
    justify: 'start'
  };
  const title: A2uiComponentDef = {
    id: 'title',
    component: 'Text',
    text: titleText,
    variant: 'h3'
  };
  const body: A2uiComponentDef = {
    id: 'body',
    component: 'Text',
    text: safeTask,
    variant: 'body'
  };
  const components: A2uiComponentDef[] = [root, contentCol, title, body];

  if (includeSetupHint) {
    const hint: A2uiComponentDef = {
      id: 'hint',
      component: 'Text',
      text: 'Add an API key in entry/src/main/resources/rawfile/llm_config.json',
      variant: 'caption'
    };
    components.push(hint);
  }

  return components;
}

export class ScriptedA2uiModel implements A2uiModel {
  async generate(userTask: string, surfaceId: string, _conversation?: ConversationContext): Promise<string> {
    const createSurface: CreateSurfaceBody = {
      surfaceId: surfaceId,
      catalogId: AGENUI_CATALOG_ID
    };
    const createEnvelope: CreateSurfaceEnvelope = {
      version: A2UI_VERSION,
      createSurface: createSurface
    };
    const createLine = JSON.stringify(createEnvelope);

    const components = buildTaskCardComponents(userTask, false);

    const updateComponents: UpdateComponentsBody = {
      surfaceId: surfaceId,
      components: components
    };
    const componentsEnvelope: UpdateComponentsEnvelope = {
      version: A2UI_VERSION,
      updateComponents: updateComponents
    };
    const componentsLine = JSON.stringify(componentsEnvelope);

    return `${createLine}\n${componentsLine}`;
  }
}
