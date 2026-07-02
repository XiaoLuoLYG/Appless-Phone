import { aiphoneErrorJsonl } from './AiphoneA2ui';
import { A2uiSurfaceState } from './runtime/A2uiTypes';
import { callToolGateway, defaultToolGatewayUrl, isRegisteredToolId } from './runtime/ToolGatewayClient';

const ignoreSurface = (_surface: A2uiSurfaceState, _raw: string): void => {};

export async function runAiphoneTool(
  toolId: string,
  prompt: string,
  surfaceId: string,
  actionId: string,
  args: Object | null = null
): Promise<string> {
  if (!isRegisteredToolId(toolId)) {
    return aiphoneErrorJsonl(surfaceId, '未知 AIPhone 工具', '未注册 AIPhone 工具：' + toolId);
  }

  const result = await callToolGateway(
    defaultToolGatewayUrl(),
    toolId,
    prompt,
    surfaceId,
    actionId,
    ignoreSurface,
    null,
    args
  );
  if (result.raw.trim().length > 0) {
    return result.raw;
  }
  if (result.error.length > 0) {
    return aiphoneErrorJsonl(surfaceId, 'AIPhone 工具调用失败', result.error);
  }

  return aiphoneErrorJsonl(surfaceId, 'AIPhone 工具无输出', toolId + ' 没有返回 A2UI JSONL。');
}
