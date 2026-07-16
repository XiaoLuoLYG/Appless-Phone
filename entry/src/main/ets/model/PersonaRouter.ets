import { PersonaRoute } from './PersonaTypes';

function containsAny(text: string, words: string[]): boolean {
  for (let index = 0; index < words.length; index++) {
    if (text.indexOf(words[index]) >= 0) {
      return true;
    }
  }
  return false;
}

export function routePersonaForPrompt(prompt: string): PersonaRoute {
  return routePersonasForPrompt(prompt)[0];
}

export function routePersonasForPrompt(prompt: string): PersonaRoute[] {
  const text = prompt.trim();
  const lowered = text.toLowerCase();
  if (text.length === 0) {
    return [{ personaId: 'default_companion', reason: '空请求使用默认分身。' }];
  }
  const routes: PersonaRoute[] = [];
  if (containsAny(text, ['咖啡', '奶茶', '餐厅', '餐饮', '美食', '外卖', '吃', '喝', '瑞幸', '麦当劳', '肯德基']) ||
    lowered.indexOf('luckin') >= 0 || lowered.indexOf('mcdonald') >= 0) {
    routes.push({ personaId: 'food_companion', reason: '用户请求包含饮食、饮品或附近餐饮场景。' });
  }
  if (containsAny(text, ['出行', '怎么走', '怎么去', '高铁', '火车', '航班', '机票', '车票', '旅行', '酒店'])) {
    routes.push({ personaId: 'travel_companion', reason: '用户请求包含旅行或出行规划场景。' });
  }
  if (containsAny(text, ['邮件', '邮箱', 'Gmail', '日程', '会议', '工作', '简历', '汇报', '同事', '老师'])) {
    routes.push({ personaId: 'work_companion', reason: '用户请求包含工作沟通、邮件或日程场景。' });
  }
  if (containsAny(text, ['视频', '电影', '音乐', 'B站', '哔哩哔哩', 'YouTube', '油管', '娱乐'])) {
    routes.push({ personaId: 'entertainment_companion', reason: '用户请求包含娱乐或媒体内容场景。' });
  }
  if (containsAny(text, ['游戏', '打法', '开黑', '副本', '攻略', '装备'])) {
    routes.push({ personaId: 'game_companion', reason: '用户请求包含游戏或攻略场景。' });
  }
  if (containsAny(text, ['买', '购物', '下单', '商品', '价格', '耳机', '手机', '电脑', '优惠'])) {
    routes.push({ personaId: 'shopping_companion', reason: '用户请求包含购物决策场景。' });
  }
  if (routes.length === 0) {
    routes.push({ personaId: 'default_companion', reason: '没有匹配到专用分身，使用默认分身。' });
  }
  return routes;
}
