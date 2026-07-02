import { describe, it, expect } from '@ohos/hypium';
import { configureDefaultPersonaStoreForTests } from '../main/ets/model/PersonaStore';
import { routePersonaForPrompt } from '../main/ets/model/PersonaRouter';

export default function personaRouterTest() {
  describe('personaRouter', () => {
    it('routes coffee to food companion', 0, () => {
      configureDefaultPersonaStoreForTests();
      const route = routePersonaForPrompt('点一杯咖啡');

      expect(route.personaId).assertEqual('food_companion');
      expect(route.reason.indexOf('饮食')).assertLarger(-1);
    });

    it('routes general travel to travel companion', 0, () => {
      configureDefaultPersonaStoreForTests();
      const route = routePersonaForPrompt('查明天北京到上海怎么走');

      expect(route.personaId).assertEqual('travel_companion');
      expect(route.reason.indexOf('出行')).assertLarger(-1);
    });

    it('routes work mail to work companion', 0, () => {
      configureDefaultPersonaStoreForTests();
      expect(routePersonaForPrompt('写封工作邮件给李老师').personaId).assertEqual('work_companion');
    });

    it('routes video to entertainment companion', 0, () => {
      configureDefaultPersonaStoreForTests();
      expect(routePersonaForPrompt('找个 qwen max 介绍视频看看').personaId).assertEqual('entertainment_companion');
    });

    it('routes game requests to game companion', 0, () => {
      configureDefaultPersonaStoreForTests();
      expect(routePersonaForPrompt('推荐一个游戏打法').personaId).assertEqual('game_companion');
    });

    it('routes shopping requests to shopping companion', 0, () => {
      configureDefaultPersonaStoreForTests();
      expect(routePersonaForPrompt('帮我买个耳机').personaId).assertEqual('shopping_companion');
    });

    it('routes plain greeting to default companion', 0, () => {
      configureDefaultPersonaStoreForTests();
      expect(routePersonaForPrompt('你好').personaId).assertEqual('default_companion');
    });

    it('keeps explicit Google Maps coffee on food persona', 0, () => {
      configureDefaultPersonaStoreForTests();
      expect(routePersonaForPrompt('帮我用 gmap 搜索附近咖啡店').personaId).assertEqual('food_companion');
    });
  });
}
