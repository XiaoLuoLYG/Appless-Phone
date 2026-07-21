import { describe, it, expect } from '@ohos/hypium';
import {
  checkoutWebInitialSource,
  checkoutWebMobileReadable,
  checkoutWebNavigationDecision,
  isAllowed12306BookingUrl,
  isOfficial12306PaymentUrl,
  webHostForDisplay
} from '../main/ets/pages/A2uiHome/components/CheckoutWebOverlay';
import { a2uiWebExecutionTokenForRequest, a2uiWebNavigationBindingForBegin,
  a2uiWebNavigationTokenForEvent, a2uiWebOwnershipAfterPopupClose, a2uiWebOwnershipAfterPopupOpen,
  a2uiWebOwnershipAfterNavigationBegin, A2uiWebExecutionToken, A2uiWebNavigationBinding,
  initialA2uiWebExecutionOwnership, invalidateA2uiWebExecutionOwnership,
  isCurrentA2uiWebExecutionToken } from '../main/ets/pages/A2uiHome/components/common/A2uiWebSurfaceView';
import { isCurrentTrainWebAssistTimer, nextTrainWebAssistEpoch,
  trainWebAssistNavigationTimeoutOutcome,
  TrainWebAssistExecutionBinding } from '../main/ets/pages/A2uiHome/train/TrainPresaleWebAutomation';

export default function checkoutWebOverlayTest() {
  describe('checkoutWebOverlay', () => {
    it('accepts only the official 12306 route entry URL', 0, () => {
      expect(isAllowed12306BookingUrl(
        'https://kyfw.12306.cn/otn/leftTicket/init?date=2026-07-22'
      )).assertTrue();
      expect(isAllowed12306BookingUrl(
        'http://kyfw.12306.cn/otn/leftTicket/init?date=2026-07-22'
      )).assertFalse();
      expect(isAllowed12306BookingUrl(
        'https://kyfw.12306.cn.evil.example/otn/leftTicket/init'
      )).assertFalse();
      expect(isAllowed12306BookingUrl(
        'https://kyfw.12306.cn/otn/leftTicket/query'
      )).assertFalse();
      expect(isAllowed12306BookingUrl(
        'https://kyfw.12306.cn/otn/leftTicket/init.evil'
      )).assertFalse();
      expect(isAllowed12306BookingUrl(
        'https://user:secret@kyfw.12306.cn/otn/leftTicket/init'
      )).assertFalse();
      expect(isAllowed12306BookingUrl(
        'https://kyfw.12306.cn:8443/otn/leftTicket/init'
      )).assertFalse();
      expect(isAllowed12306BookingUrl(
        'https://KYFW.12306.CN/otn/leftTicket/init'
      )).assertTrue();
      expect(isAllowed12306BookingUrl(
        'https://kyfw.12306.cn/otn/leftticket/init'
      )).assertFalse();
    });

    it('filters the initial train source before handing it to WebView', 0, () => {
      const official = 'https://kyfw.12306.cn/otn/leftTicket/init?date=2026-07-22';
      expect(checkoutWebInitialSource('train', official)).assertEqual(official);
      expect(checkoutWebInitialSource(
        'train',
        'https://kyfw.12306.cn.evil.example/otn/leftTicket/init'
      )).assertEqual('');
      expect(checkoutWebInitialSource(
        'train',
        'https://kyfw.12306.cn@evil.example/otn/leftTicket/init'
      )).assertEqual('');
      expect(checkoutWebInitialSource('payment', 'https://checkout.stripe.com/pay')).assertEqual(
        'https://checkout.stripe.com/pay'
      );
      expect(checkoutWebInitialSource('hotel', 'https://rollinggo.cn/hotel')).assertEqual(
        'https://rollinggo.cn/hotel'
      );
    });

    it('uses mobile-readable WebView presentation only for train booking', 0, () => {
      expect(checkoutWebMobileReadable('train')).assertTrue();
      expect(checkoutWebMobileReadable('payment')).assertFalse();
      expect(checkoutWebMobileReadable('hotel')).assertFalse();
    });

    it('shows only the parsed hostname for loaded pages', 0, () => {
      expect(webHostForDisplay(
        'https://kyfw.12306.cn:user-secret@evil.example/otn/leftTicket/init'
      )).assertEqual('evil.example');
      expect(webHostForDisplay('https://epay.12306.cn:8443/pay/webBusiness')).assertEqual('epay.12306.cn');
      expect(webHostForDisplay('https://cashier.example.com/payment/return')).assertEqual('cashier.example.com');
      expect(webHostForDisplay('not a URL')).assertEqual('未加载');
      expect(webHostForDisplay(checkoutWebInitialSource(
        'train',
        'https://kyfw.12306.cn@evil.example/otn/leftTicket/init'
      ))).assertEqual('未加载');
    });

    it('keeps HTTPS train navigation in WebView and blocks unverified schemes', 0, () => {
      expect(checkoutWebNavigationDecision(
        'train',
        'https://kyfw.12306.cn/otn/leftTicket/init',
        true
      )).assertEqual('allow');
      expect(checkoutWebNavigationDecision(
        'train',
        'https://epay.12306.cn/pay/webBusiness',
        true
      )).assertEqual('allow');
      expect(checkoutWebNavigationDecision('train', 'alipays://platformapi/startapp', true)).assertEqual('block');
      expect(checkoutWebNavigationDecision('train', 'javascript:alert(1)', true)).assertEqual('block');
      expect(checkoutWebNavigationDecision('train', 'alipays://platformapi/startapp', false)).assertEqual('block');
    });

    it('does not regress payment and hotel decisions', 0, () => {
      expect(checkoutWebNavigationDecision(
        'payment',
        'aiphone://payment/success',
        true
      )).assertEqual('payment_return');
      expect(checkoutWebNavigationDecision(
        'hotel',
        'https://evil.example/',
        true
      )).assertEqual('block');
    });

    it('gives script ownership to only one active controller across popup handoff', 0, () => {
      const main = initialA2uiWebExecutionOwnership();
      const mainToken: A2uiWebExecutionToken = { controller: 'main', generation: 0, session: 1 };
      expect(isCurrentA2uiWebExecutionToken(main, mainToken)).assertTrue();
      const popup = a2uiWebOwnershipAfterPopupOpen(main);
      const popupToken: A2uiWebExecutionToken = {
        controller: 'popup', generation: popup.popupGeneration, session: 2
      };
      expect(isCurrentA2uiWebExecutionToken(popup, mainToken)).assertFalse();
      expect(isCurrentA2uiWebExecutionToken(popup, popupToken)).assertTrue();
      expect(a2uiWebExecutionTokenForRequest(popup, 'main', popup.mainGeneration, 3,
        'assist()', true, true)).assertEqual(undefined);
      expect(a2uiWebExecutionTokenForRequest(popup, 'popup', popup.popupGeneration, 3,
        'assist()', true, true)?.controller).assertEqual('popup');
      const returned = a2uiWebOwnershipAfterPopupClose(popup);
      expect(isCurrentA2uiWebExecutionToken(returned, popupToken)).assertFalse();
      expect(returned.active).assertEqual('main');
      const mainLoading = a2uiWebOwnershipAfterNavigationBegin(returned, 'main');
      expect(a2uiWebExecutionTokenForRequest(mainLoading, 'main', mainLoading.mainGeneration, 4,
        'assist()', false, false)).assertEqual(undefined);
    });

    it('invalidates late controller results on cancel and unmount and verifies payment callback URL', 0, () => {
      const state = initialA2uiWebExecutionOwnership();
      const token: A2uiWebExecutionToken = { controller: 'main', generation: 0, session: 1 };
      expect(isCurrentA2uiWebExecutionToken(invalidateA2uiWebExecutionOwnership(state), token)).assertFalse();
      const disposed = invalidateA2uiWebExecutionOwnership(state, true);
      expect(disposed.active).assertEqual('none');
      expect(isCurrentA2uiWebExecutionToken(disposed, token)).assertFalse();
      expect(a2uiWebExecutionTokenForRequest(state, 'main', 0, 2, '', true, false)).assertEqual(undefined);
      const navAState = a2uiWebOwnershipAfterNavigationBegin(state, 'main');
      const navA: A2uiWebNavigationBinding = a2uiWebNavigationBindingForBegin(undefined,
        navAState, 'main', 3, 'https://kyfw.12306.cn/otn/leftTicket/init');
      const navBState = a2uiWebOwnershipAfterNavigationBegin(navAState, 'main');
      const navB: A2uiWebNavigationBinding = a2uiWebNavigationBindingForBegin(navA,
        navBState, 'main', 3, 'https://kyfw.12306.cn/otn/leftTicket/init');
      expect(a2uiWebNavigationTokenForEvent(navBState, navA,
        'https://kyfw.12306.cn/otn/leftTicket/init')).assertEqual(undefined);
      expect(a2uiWebNavigationTokenForEvent(navBState, undefined,
        'https://kyfw.12306.cn/otn/leftTicket/init')).assertEqual(undefined);
      expect(a2uiWebNavigationTokenForEvent(navBState, navB,
        'https://kyfw.12306.cn/otn/leftTicket/init')).assertEqual(undefined);
      const currentPopupState = a2uiWebOwnershipAfterPopupOpen(state);
      const currentPopup: A2uiWebNavigationBinding = a2uiWebNavigationBindingForBegin(undefined,
        currentPopupState, 'popup', 4, 'https://kyfw.12306.cn/otn/confirmPassenger/initDc');
      expect(a2uiWebNavigationTokenForEvent(currentPopupState, currentPopup,
        'https://kyfw.12306.cn/otn/confirmPassenger/initDc')?.controller).assertEqual('popup');
      const popupReloadState = a2uiWebOwnershipAfterNavigationBegin(currentPopupState, 'popup');
      const popupReload = a2uiWebNavigationBindingForBegin(currentPopup, popupReloadState, 'popup', 4,
        'https://kyfw.12306.cn/otn/confirmPassenger/initDc');
      expect(a2uiWebNavigationTokenForEvent(popupReloadState, currentPopup, currentPopup.url))
        .assertEqual(undefined);
      expect(a2uiWebNavigationTokenForEvent(popupReloadState, popupReload, popupReload.url))
        .assertEqual(undefined);
      const redirectAState = a2uiWebOwnershipAfterNavigationBegin(state, 'main');
      const redirectA = a2uiWebNavigationBindingForBegin(undefined, redirectAState, 'main', 5,
        'https://kyfw.12306.cn/otn/leftTicket/init');
      const redirectBState = a2uiWebOwnershipAfterNavigationBegin(redirectAState, 'main');
      const redirectB = a2uiWebNavigationBindingForBegin(redirectA, redirectBState, 'main', 5,
        'https://kyfw.12306.cn/otn/confirmPassenger/initDc');
      expect(a2uiWebNavigationTokenForEvent(redirectBState, redirectB, redirectA.url)).assertEqual(undefined);
      const acceptedRedirectB = a2uiWebNavigationTokenForEvent(redirectBState, redirectB, redirectB.url);
      expect(acceptedRedirectB?.generation).assertEqual(redirectBState.mainGeneration);
      const mainTimeoutBinding: TrainWebAssistExecutionBinding = acceptedRedirectB === undefined ?
        { controller: 'main', generation: -1, session: -1 } :
        { controller: acceptedRedirectB.controller, generation: acceptedRedirectB.generation,
          session: acceptedRedirectB.session };
      expect(trainWebAssistNavigationTimeoutOutcome('main', mainTimeoutBinding.generation,
        mainTimeoutBinding.session, mainTimeoutBinding)?.state).assertEqual('needs_user');
      const mainTimeoutEpoch = 30;
      const mainClearedEpoch = nextTrainWebAssistEpoch(mainTimeoutEpoch);
      const lateMainTimeout = isCurrentTrainWebAssistTimer(mainTimeoutEpoch, mainClearedEpoch, false) ?
        trainWebAssistNavigationTimeoutOutcome('main', mainTimeoutBinding.generation,
          mainTimeoutBinding.session, mainTimeoutBinding) : undefined;
      expect(lateMainTimeout).assertEqual(undefined);
      const popupRedirectOwner = a2uiWebOwnershipAfterPopupOpen(state);
      const popupRedirectAState = a2uiWebOwnershipAfterNavigationBegin(popupRedirectOwner, 'popup');
      const popupRedirectA = a2uiWebNavigationBindingForBegin(undefined, popupRedirectAState, 'popup', 6,
        'https://kyfw.12306.cn/otn/leftTicket/init');
      const popupRedirectBState = a2uiWebOwnershipAfterNavigationBegin(popupRedirectAState, 'popup');
      const popupRedirectB = a2uiWebNavigationBindingForBegin(popupRedirectA, popupRedirectBState, 'popup', 6,
        'https://kyfw.12306.cn/otn/confirmPassenger/initDc');
      expect(a2uiWebNavigationTokenForEvent(popupRedirectBState, popupRedirectB, popupRedirectA.url))
        .assertEqual(undefined);
      const acceptedPopupRedirectB = a2uiWebNavigationTokenForEvent(popupRedirectBState,
        popupRedirectB, popupRedirectB.url);
      expect(acceptedPopupRedirectB?.controller).assertEqual('popup');
      const popupTimeoutBinding: TrainWebAssistExecutionBinding = acceptedPopupRedirectB === undefined ?
        { controller: 'popup', generation: -1, session: -1 } :
        { controller: acceptedPopupRedirectB.controller, generation: acceptedPopupRedirectB.generation,
          session: acceptedPopupRedirectB.session };
      const popupTimeoutEpoch = 40;
      const popupClearedEpoch = nextTrainWebAssistEpoch(popupTimeoutEpoch);
      const latePopupTimeout = isCurrentTrainWebAssistTimer(popupTimeoutEpoch, popupClearedEpoch, false) ?
        trainWebAssistNavigationTimeoutOutcome('popup', popupTimeoutBinding.generation,
          popupTimeoutBinding.session, popupTimeoutBinding) : undefined;
      expect(latePopupTimeout).assertEqual(undefined);
      expect(isOfficial12306PaymentUrl('https://epay.12306.cn/pay/webBusiness')).assertTrue();
      expect(isOfficial12306PaymentUrl('https://kyfw.12306.cn/payOrder/init')).assertTrue();
      expect(isOfficial12306PaymentUrl('https://kyfw.12306.cn/otn/confirmPassenger/initDc')).assertFalse();
      expect(isOfficial12306PaymentUrl('https://epay.12306.cn.evil.example/pay')).assertFalse();
      expect(isOfficial12306PaymentUrl('http://epay.12306.cn/pay')).assertFalse();
    });
  });
}
