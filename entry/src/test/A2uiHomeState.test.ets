import { describe, it, expect } from '@ohos/hypium';
import { A2uiSurfaceState } from '@loop/agent-core';
import {
  A2UI_SEND_SPINNER_STEP_DEG,
  createInitialConnectionPanelState,
  inputTextAfterPromptSubmit,
  isWelcomeSurface,
  isPromptInputEnabled,
  nextSendSpinnerRotation,
  runtimeCallbackIsCurrent,
  runtimeOwnerAllowsSurfaceAction,
  runtimeSurfaceIdentityMatches,
  shouldShowWelcome,
  shouldShowQueryPendingSurface,
  shouldApplySurfaceUpdate,
  updateConnectionPanelState,
  voiceInputTextAfterRecognition
} from '../main/ets/pages/A2uiHome/state/A2uiHomeState';

function surface(
  sequence: number,
  status: string,
  surfaceId: string = 'surface_model',
  runtimeOwner: 'multi_agent' | 'legacy' = 'multi_agent',
  runtimeGeneration: number = 1
): A2uiSurfaceState {
  return {
    surfaceId: surfaceId,
    rootId: 'root',
    title: '测试',
    intent: 'food',
    status: status,
    components: [],
    dataModelJson: '{}',
    error: '',
    sequence: sequence,
    runtimeOwner,
    runtimeGeneration
  };
}

export default function a2uiHomeStateTest() {
  describe('a2uiHomeState', () => {
    it('updates panel state after a successful connection check', 0, () => {
      const initial = createInitialConnectionPanelState();
      const next = updateConnectionPanelState(initial, {
        ok: true,
        status: 'ready',
        message: '模型连接正常',
        requestDebug: 'POST /chat/completions',
        assistantDebug: '{"version":"v0.9.1"}',
        error: ''
      });

      expect(next.connectionStatus).assertEqual('ready');
      expect(next.connectionMessage).assertEqual('模型连接正常');
      expect(next.lastModelRequest).assertEqual('POST /chat/completions');
      expect(next.lastModelOutput).assertEqual('{"version":"v0.9.1"}');
      expect(next.lastError).assertEqual('');
      expect(next.refreshTick).assertEqual(1);
    });

    it('updates panel state after a failed connection check', 0, () => {
      const initial = createInitialConnectionPanelState();
      const next = updateConnectionPanelState(initial, {
        ok: false,
        status: 'error',
        message: '模型连接异常',
        requestDebug: '',
        assistantDebug: '',
        error: 'ECONNREFUSED'
      });

      expect(next.connectionStatus).assertEqual('error');
      expect(next.connectionMessage).assertEqual('模型连接异常');
      expect(next.lastError).assertEqual('ECONNREFUSED');
      expect(next.refreshTick).assertEqual(1);
    });

    it('skips applying the same surface sequence twice', 0, () => {
      expect(shouldApplySurfaceUpdate(surface(12, 'ready'), surface(12, 'ready'))).assertFalse();
      expect(shouldApplySurfaceUpdate(surface(12, 'calling_tool'), surface(13, 'ready'))).assertTrue();
    });

    it('accepts only exact-owner actions and rejects stale or late owner changes', 0, () => {
      const multi = surface(12, 'ready', 'surface_multi', 'multi_agent', 4);
      const legacy = surface(12, 'ready', 'surface_legacy', 'legacy', 4);

      expect(runtimeOwnerAllowsSurfaceAction(multi, 'multi_agent')).assertTrue();
      expect(runtimeOwnerAllowsSurfaceAction(multi, 'legacy')).assertFalse();
      expect(runtimeOwnerAllowsSurfaceAction(legacy, 'legacy')).assertTrue();
      expect(runtimeOwnerAllowsSurfaceAction(legacy, 'multi_agent')).assertFalse();
      expect(shouldApplySurfaceUpdate(
        multi,
        surface(99, 'ready', 'surface_old', 'legacy', 3)
      )).assertFalse();
      expect(shouldApplySurfaceUpdate(
        multi,
        surface(13, 'ready', 'surface_mutated', 'legacy', 4)
      )).assertFalse();
      expect(shouldApplySurfaceUpdate(
        multi,
        surface(1, 'ready', 'surface_next', 'legacy', 5)
      )).assertTrue();
    });

    it('accepts callback state only for the generation and owner captured at submit', 0, () => {
      expect(runtimeCallbackIsCurrent('multi_agent', 7, 'multi_agent', 7)).assertTrue();
      expect(runtimeCallbackIsCurrent('multi_agent', 8, 'multi_agent', 7)).assertFalse();
      expect(runtimeCallbackIsCurrent('legacy', 7, 'multi_agent', 7)).assertFalse();

      let activeOwner: 'multi_agent' | 'legacy' = 'multi_agent';
      let activeGeneration = 10;
      let mutations = 0;
      const mutate = (owner: 'multi_agent' | 'legacy', generation: number): void => {
        if (runtimeCallbackIsCurrent(activeOwner, activeGeneration, owner, generation)) {
          mutations++;
        }
      };
      const oldMultiAgent = (): void => mutate('multi_agent', 10);
      const oldLegacyStream = (): void => mutate('legacy', 10);
      const oldToolStream = (): void => mutate('multi_agent', 10);
      activeGeneration = 11;
      oldMultiAgent();
      oldLegacyStream();
      oldToolStream();
      expect(mutations).assertEqual(0);
      mutate('multi_agent', 11);
      expect(mutations).assertEqual(1);
    });

    it('requires exact current host and retained snapshot identity for page actions', 0, () => {
      const current = surface(20, 'ready', 'surface-current', 'multi_agent', 9);
      const retained = surface(20, 'ready', 'surface-current', 'multi_agent', 9);
      expect(runtimeSurfaceIdentityMatches(current, retained, 'multi_agent', 9)).assertTrue();
      expect(runtimeSurfaceIdentityMatches(
        surface(21, 'ready', 'surface-newer', 'multi_agent', 10),
        retained,
        'multi_agent',
        10
      )).assertFalse();
      expect(runtimeSurfaceIdentityMatches(
        current,
        surface(20, 'ready', 'surface-current', 'legacy', 9),
        'multi_agent',
        9
      )).assertFalse();
      expect(runtimeSurfaceIdentityMatches(current, retained, 'legacy', 9)).assertFalse();
    });

    it('keeps send spinner rotation monotonic while loading', 0, () => {
      expect(nextSendSpinnerRotation(360 - A2UI_SEND_SPINNER_STEP_DEG, true)).assertEqual(360);
      expect(nextSendSpinnerRotation(360, true)).assertEqual(360 + A2UI_SEND_SPINNER_STEP_DEG);
      expect(nextSendSpinnerRotation(360 + A2UI_SEND_SPINNER_STEP_DEG, false)).assertEqual(0);
    });

    it('locks prompt input while busy and preserves submitted text', 0, () => {
      expect(isPromptInputEnabled(false)).assertTrue();
      expect(isPromptInputEnabled(true)).assertFalse();
      expect(inputTextAfterPromptSubmit('帮我查深圳北站附近餐馆')).assertEqual('帮我查深圳北站附近餐馆');
    });

    it('appends recognized voice input to the current draft', 0, () => {
      expect(voiceInputTextAfterRecognition('', ' 明天的天气 ')).assertEqual('明天的天气');
      expect(voiceInputTextAfterRecognition('帮我查深圳北站', '附近餐馆')).assertEqual('帮我查深圳北站 附近餐馆');
      expect(voiceInputTextAfterRecognition('帮我查深圳北站 ', '附近餐馆')).assertEqual('帮我查深圳北站 附近餐馆');
      expect(voiceInputTextAfterRecognition('原始草稿 ', '   ')).assertEqual('原始草稿 ');
    });

    it('shows the query pending surface only before the first new render arrives', 0, () => {
      expect(shouldShowQueryPendingSurface(true, true)).assertTrue();
      expect(shouldShowQueryPendingSurface(true, false)).assertFalse();
      expect(shouldShowQueryPendingSurface(false, true)).assertFalse();
    });

    it('shows welcome only for an idle seed surface with no messages', 0, () => {
      const welcome = surface(1, 'idle', 'surface_seed');
      expect(isWelcomeSurface(welcome)).assertTrue();
      expect(shouldShowWelcome(false, 0, welcome)).assertTrue();
      expect(shouldShowWelcome(true, 0, welcome)).assertFalse();
      expect(shouldShowWelcome(false, 1, welcome)).assertFalse();
      expect(shouldShowWelcome(false, 0, surface(2, 'ready', 'surface_food'))).assertFalse();
    });
  });
}
