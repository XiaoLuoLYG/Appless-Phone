import { A2uiSurfaceState } from '../../../model/A2uiTypes';
import { toolRequest } from '../../../model/A2uiData';

export interface A2uiHomeResolvedToolRequest {
  hasTool: boolean;
  toolId: string;
  prompt: string;
  actionId: string;
  modelPromptChars: number;
}

function containsAny(text: string, words: string[]): boolean {
  for (let index = 0; index < words.length; index++) {
    if (text.indexOf(words[index]) >= 0) {
      return true;
    }
  }
  return false;
}

function forcedDynamicToolIdForPrompt(prompt: string): string {
  if (prompt.length === 0) {
    return '';
  }
  if (containsAny(prompt, ['船票', '轮渡', '客船', '渡轮', '码头']) &&
    containsAny(prompt, ['查', '查询', '搜索', '帮我搜', '票', '余票', '班次'])) {
    return 'dynamic.search';
  }
  if (containsAny(prompt, ['天气', '气温', '下雨', '降雨']) &&
    containsAny(prompt, ['查', '查询', '搜索', '帮我搜', '今天', '明天'])) {
    return 'dynamic.search';
  }
  if (containsAny(prompt, ['统计局', 'GDP', 'CPI', '人口', '经济数据']) &&
    containsAny(prompt, ['查', '查询', '搜索', '帮我搜'])) {
    return 'dynamic.search';
  }
  if (containsAny(prompt, ['PPT', 'ppt', '幻灯片', '演示文稿']) &&
    containsAny(prompt, ['生成', '做', '制作', '创建'])) {
    return 'dynamic.search';
  }
  return '';
}

function gmailToolIdForPrompt(prompt: string): string {
  if (prompt.length === 0) {
    return '';
  }
  const normalized = prompt.toLowerCase();
  const hasGmailSignal = containsAny(normalized, ['gmail', 'google mail', 'mail.google.com']) ||
    containsAny(prompt, ['谷歌邮箱', '谷歌邮件']);
  if (!hasGmailSignal) {
    return '';
  }
  if (containsAny(prompt, ['打开', '网页版', '网页', '浏览器', '登录', '登陆'])) {
    return 'gmail.open.web';
  }
  if (containsAny(prompt, ['直接发送', '立刻发送', '马上发送', '自动发送', '不确认直接发', '不用确认直接发'])) {
    return 'gmail.message.send';
  }
  if (containsAny(prompt, ['回复', '写', '撰写', '起草', '草稿', '发一封', '发送邮件', '发出去']) ||
    containsAny(normalized, ['draft', 'drafts'])) {
    return 'gmail.draft.create';
  }
  if (containsAny(prompt, ['查', '查询', '搜索', '帮我搜', '看', '读取', '读', '找', '收件箱', '邮件', '最新', '重要'])) {
    return 'gmail.mail.search';
  }
  return '';
}

function inferredToolIdForPrompt(prompt: string): string {
  const dynamicToolId = forcedDynamicToolIdForPrompt(prompt);
  if (dynamicToolId.length > 0) {
    return dynamicToolId;
  }
  const gmailToolId = gmailToolIdForPrompt(prompt);
  if (gmailToolId.length > 0) {
    return gmailToolId;
  }
  if (containsAny(prompt, ['附近', '周边', '外卖', '咖啡', '奶茶', '餐饮', '美食', '肯德基']) &&
    containsAny(prompt, ['查', '查询', '搜索', '帮我搜', '附近', '周边'])) {
    return 'food.search';
  }
  if (containsAny(prompt, ['出行方案', '搜索出行', '怎么去', '比较出行', '出行选项', '可查的出行'])) {
    return 'travel.search';
  }
  if (containsAny(prompt, ['航班', '机票', '飞机'])) {
    return 'flight.search';
  }
  if (containsAny(prompt, ['高铁', '火车', '车票', '12306'])) {
    return 'train.search';
  }
  return '';
}

export function resolveA2uiHomeToolRequest(
  surface: A2uiSurfaceState,
  fallbackPrompt: string,
  fallbackActionId: string
): A2uiHomeResolvedToolRequest {
  const request = toolRequest(surface);
  let toolId = request.toolId;
  const prompt = request.prompt.length > 0 ? request.prompt : fallbackPrompt;
  let actionId = request.actionId.length > 0 ? request.actionId : fallbackActionId;
  const forcedDynamicToolId = forcedDynamicToolIdForPrompt(prompt);
  if (forcedDynamicToolId.length > 0) {
    toolId = forcedDynamicToolId;
    if (actionId.length === 0) {
      actionId = request.toolId.length > 0 ? 'client_dynamic_reroute' : 'client_intent_fallback';
    }
  } else if (toolId.length === 0) {
    toolId = inferredToolIdForPrompt(fallbackPrompt);
    if (toolId.length > 0 && actionId.length === 0) {
      actionId = 'client_intent_fallback';
    }
  }
  return {
    hasTool: toolId.length > 0,
    toolId: toolId,
    prompt: prompt,
    actionId: actionId,
    modelPromptChars: request.prompt.length
  };
}
