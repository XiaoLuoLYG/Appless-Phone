import { describe, expect, it } from '@ohos/hypium';
import {
  BimLifecycleState,
  BimRecord
} from '../main/ets/pages/A2uiHome/bim/BimStore';
import {
  combineBimErrorMessages,
  formatBimCount,
  groupVisibleBims,
  shouldShowBimSuggestion
} from '../main/ets/pages/A2uiHome/components/BimHomePage';
import {
  BIM_DASHBOARD_CARD_GAP,
  BIM_DASHBOARD_SECTION_GAP
} from '../main/ets/pages/A2uiHome/components/BimDashboardView';
import { LeaderBimSuggestion } from '@loop/agent-core';

function suggestion(): LeaderBimSuggestion {
  return {
    title: '东京旅行',
    summary: '八月东京一周旅行',
    reason: '还需要继续选择机票与酒店',
    keywords: ['东京', '旅行', '机票', '酒店']
  };
}

function viewRecord(
  lifecycle: BimLifecycleState,
  updatedAt: string,
  id: string = 'bim-' + lifecycle
): BimRecord {
  return {
    id,
    title: lifecycle,
    lifecycle,
    createdAt: updatedAt,
    updatedAt,
    lastInteractionAt: updatedAt,
    lastLifecycleCheckAt: updatedAt,
    endedAt: lifecycle === 'ended' ? updatedAt : undefined,
    relatedBimIds: [],
    contextJson: '{"summary":"test","facts":[],"constraints":[],"decisions":[]}',
    retrievalIndex: {
      summary: 'test', entities: [], timeAnchors: [], locations: [],
      commitments: [], keywords: ['test']
    },
    surfaceJson: '{"surfaceId":"surface-test","rootId":"root","title":"当前安排",' +
      '"intent":"general","status":"ready","components":[{"id":"root","component":"SurfaceRoot"}],' +
      '"dataModelJson":"{}","error":"","sequence":1}'
  };
}

export default function bimHomePageTest() {
  describe('bimHomePageViewData', () => {
    it('does not show a suggestion during a BIM-owned turn', 0, () => {
      expect(shouldShowBimSuggestion(suggestion(), 'bim-trip', false)).assertFalse();
      expect(shouldShowBimSuggestion(suggestion(), '', false)).assertTrue();
      expect(shouldShowBimSuggestion(suggestion(), '', true)).assertFalse();
    });

    it('keeps dashboard cards visually separated', 0, () => {
      expect(BIM_DASHBOARD_CARD_GAP).assertEqual(14);
      expect(BIM_DASHBOARD_SECTION_GAP).assertEqual(20);
    });

    it('groups lifecycle states so ended can stay behind a secondary entry', 0, () => {
      const grouped = groupVisibleBims([
        viewRecord('active', '2026-08-03T10:00:00+08:00'),
        viewRecord('quiet', '2026-08-02T10:00:00+08:00'),
        viewRecord('tucked', '2026-07-01T10:00:00+08:00'),
        viewRecord('ended', '2026-08-03T11:00:00+08:00')
      ]);

      expect(grouped.active.length).assertEqual(1);
      expect(grouped.quiet.length).assertEqual(1);
      expect(grouped.tucked.length).assertEqual(1);
      expect(grouped.ended.length).assertEqual(1);
    });

    it('sorts each lifecycle group by most recently updated first', 0, () => {
      const grouped = groupVisibleBims([
        viewRecord('active', '2026-08-02T10:00:00+08:00', 'bim-older'),
        viewRecord('active', '2026-08-03T10:00:00+08:00', 'bim-newer')
      ]);

      expect(grouped.active[0].id).assertEqual('bim-newer');
      expect(grouped.active[1].id).assertEqual('bim-older');
    });

    it('formats the system-level heart count', 0, () => {
      expect(formatBimCount(0)).assertEqual('');
      expect(formatBimCount(4)).assertEqual('4');
      expect(formatBimCount(10)).assertEqual('9+');
    });

    it('keeps Store errors visible beside transient detail errors', 0, () => {
      expect(combineBimErrorMessages('心上事暂时无法载入', ''))
        .assertEqual('心上事暂时无法载入');
      expect(combineBimErrorMessages('心上事暂时无法载入', '心上事更新失败'))
        .assertEqual('心上事暂时无法载入\n心上事更新失败');
      expect(combineBimErrorMessages('心上事暂时无法载入', '心上事暂时无法载入'))
        .assertEqual('心上事暂时无法载入');
    });
  });
}
