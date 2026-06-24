import { describe, it, expect } from '@ohos/hypium';
import { A2uiSurfaceState } from '../main/ets/model/A2uiTypes';
import { A2uiSurfaceThrottle } from '../main/ets/model/A2uiSurfaceThrottle';

function throttleSurface(sequence: number): A2uiSurfaceState {
  return {
    surfaceId: 'surface_model',
    rootId: 'root',
    title: '餐饮',
    intent: 'food',
    status: 'calling_tool',
    components: [],
    dataModelJson: '{}',
    error: '',
    sequence: sequence
  };
}

export default function a2uiSurfaceThrottleTest() {
  describe('a2uiSurfaceThrottle', () => {
    it('coalesces queued surfaces and emits the latest snapshot', 0, async () => {
      const sequences: number[] = [];
      const throttle = new A2uiSurfaceThrottle(20, (surface: A2uiSurfaceState, _raw: string) => {
        sequences.push(surface.sequence);
      });

      throttle.enqueue(throttleSurface(1), 'one');
      throttle.enqueue(throttleSurface(2), 'two');
      await new Promise<void>((resolve: () => void) => {
        setTimeout(resolve, 40);
      });

      expect(sequences.length).assertEqual(1);
      expect(sequences[0]).assertEqual(2);
    });

    it('flushes the latest queued surface immediately', 0, () => {
      const sequences: number[] = [];
      const throttle = new A2uiSurfaceThrottle(500, (surface: A2uiSurfaceState, _raw: string) => {
        sequences.push(surface.sequence);
      });

      throttle.enqueue(throttleSurface(3), 'three');
      throttle.flush();

      expect(sequences.length).assertEqual(1);
      expect(sequences[0]).assertEqual(3);
    });
  });
}
