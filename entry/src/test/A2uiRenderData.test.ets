import { describe, it, expect } from '@ohos/hypium';
import {
  childIdsOf,
  componentTextOf,
  findA2uiComponent,
  rootComponentIdOf
} from '../main/ets/pages/A2uiHome/A2uiRenderData';
import { A2uiSurfaceState } from '../main/ets/model/A2uiTypes';

function sampleSurface(): A2uiSurfaceState {
  return {
    surfaceId: 's',
    rootId: 'root',
    title: '测试',
    intent: 'general',
    status: 'ready',
    components: [
      {
        id: 'root',
        component: 'SurfaceRoot',
        child: 'body'
      },
      {
        id: 'body',
        component: 'Column',
        children: ['title', 'info']
      },
      {
        id: 'title',
        component: 'Text',
        text: '你好'
      },
      {
        id: 'info',
        component: 'InfoRows',
        dataPath: '/rows'
      }
    ],
    dataModelJson: '{"rows":[{"label":"数值","value":"42"}]}',
    error: '',
    sequence: 1
  };
}

export default function a2uiRenderDataTest() {
  describe('a2uiRenderData', () => {
    it('finds the root component id from a surface', 0, () => {
      expect(rootComponentIdOf(sampleSurface())).assertEqual('root');
    });

    it('resolves child and children ids in render order', 0, () => {
      const surface = sampleSurface();
      const root = findA2uiComponent(surface, 'root');
      const body = findA2uiComponent(surface, 'body');

      expect(root !== null).assertTrue();
      expect(body !== null).assertTrue();
      if (root !== null && body !== null) {
        expect(childIdsOf(root).join(',')).assertEqual('body');
        expect(childIdsOf(body).join(',')).assertEqual('title,info');
      }
    });

    it('reads text before body fallback', 0, () => {
      const surface = sampleSurface();
      const title = findA2uiComponent(surface, 'title');

      expect(title !== null).assertTrue();
      if (title !== null) {
        expect(componentTextOf(title)).assertEqual('你好');
      }
    });
  });
}
