import { describe, it, expect } from '@ohos/hypium';
import {
  A2uiSurfaceState,
  childSurfaceIdForMultiTaskSlot,
  isMultiTaskSurface,
  MultiTaskBoardData,
  MultiToolSurfaceEmitHandler,
  MultiToolSurfaceComposer,
  resolveMultiTaskSlotId
} from '@loop/agent-core';

export default function agentCorePublicContractTest() {
  describe('AgentCorePublicContract', () => {
    it('exports the retained multi-task entry contracts', 0, () => {
      const board: MultiTaskBoardData = {
        batchId: 'batch_contract',
        mode: 'parallel',
        activeSectionId: 'slot_0',
        sections: []
      };
      const surface: A2uiSurfaceState = {
        surfaceId: 'surface_contract',
        rootId: 'root',
        title: '并行任务',
        intent: 'multi-task',
        status: 'ready',
        components: [],
        dataModelJson: JSON.stringify(board),
        error: '',
        sequence: 1
      };
      const onEmit: MultiToolSurfaceEmitHandler = (_surface: A2uiSurfaceState, _raw: string): void => {};
      const composer: MultiToolSurfaceComposer = new MultiToolSurfaceComposer('surface_contract', onEmit);

      expect(isMultiTaskSurface(surface)).assertTrue();
      expect(resolveMultiTaskSlotId(surface, 'flight.search')).assertEqual('');
      expect(childSurfaceIdForMultiTaskSlot('surface_contract', 'slot_0')).assertEqual('surface_contract_slot_0');
      expect(composer.childSurfaceId('slot_0')).assertEqual('surface_contract_slot_0');
    });
  });
}
