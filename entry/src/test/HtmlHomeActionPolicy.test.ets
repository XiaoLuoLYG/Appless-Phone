import { describe, it, expect } from '@ohos/hypium';
import { A2uiAction } from '@loop/agent-core';
import { isHtmlHomeActionAllowed } from '../main/ets/pages/A2uiHome/html/HtmlHomeActionPolicy';
import { HtmlHomeAction, HtmlHomeDocument } from '../main/ets/pages/A2uiHome/html/HtmlHomeTypes';

interface ThreadOnlyArgsFixture {
  threadId: string;
}

interface StripeOnboardingArgsFixture {
  onboardingUrl: string;
}

interface PaymentCaptureArgsFixture {
  provider: string;
  phase: string;
  providerSessionId: string;
}

interface PaymentCheckoutArgsFixture {
  provider: string;
  providerSessionId: string;
}

interface MailReplyArgsFixture {
  requestKey: string;
  provider: string;
  threadId: string;
  messageId: string;
  to: string[];
  subject: string;
  body: string;
}

interface MailCalendarArgsFixture {
  requestKey: string;
  provider: string;
  threadId: string;
  messageId: string;
}

interface CalendarDeleteArgsFixture {
  eventId: string;
  calendarId: string;
  confirmed: boolean;
}

interface LuckinArgsFixture {
  deptId?: string;
  location?: string;
  productId?: string;
  skuCode?: string;
  quantity?: number;
  previewPrompt?: string;
  attrGroup?: string;
  attrChoice?: string;
  locationSource?: string;
  orderId?: string;
}

interface HotelNavigateArgsFixture {
  hotelId: number;
  name: string;
  address: string;
  latitude: number;
  longitude: number;
}

interface HotelCallArgsFixture {
  hotelId: number;
  name: string;
  displayPhone: string;
  dialPhone: string;
  provider: string;
  providerPlaceId: string;
}

interface HotelDetailArgsFixture {
  hotelId: number;
  checkInDate: string;
  checkOutDate: string;
  countryCode: string;
  currency: string;
  adultCount: number;
  childCount: number;
  childAgeDetails: number[];
  roomCount: number;
}

function action(id: string, prompt: string, kind: string = 'client', args: Object | null = null): A2uiAction {
  const next: A2uiAction = {
    id: id,
    label: id,
    prompt: prompt,
    variant: 'primary',
    kind: kind
  };
  if (args !== null) {
    next.args = args;
  }
  return next;
}

function documentFixture(): HtmlHomeDocument {
  return {
    version: 1,
    source: 'tool',
    kind: 'dynamic-tools',
    title: 'Tool',
    subtitle: '',
    chips: [],
    metrics: [],
    timeline: [],
    blocks: [{
      id: 'connect',
      kind: 'dynamic-tool-connect',
      title: 'Weather',
      subtitle: '',
      status: 'needs_auth',
      credentialName: 'Authorization',
      credentialRef: 'dynamic:weather:Authorization',
      toolId: 'weather.query',
      prompt: '深圳天气',
      metrics: [],
      rows: [],
      actions: [{ id: 'dynamic_test_connection', label: '测试连接', prompt: '深圳天气', variant: 'primary', kind: 'client' }]
    }, {
      id: 'food-1',
      kind: 'food-result',
      title: 'Coffee',
      subtitle: '',
      status: 'ready',
      source: 'amap',
      metrics: [],
      rows: [],
      actions: [{ id: 'html_open_food_map', label: '打开地图', prompt: '{"index":0,"name":"Coffee"}', variant: 'primary', kind: 'client' }]
    }],
    actions: [{ id: 'gmail.open.web', label: 'Gmail Web', prompt: 'https://mail.google.com/', variant: 'secondary', kind: 'client' }],
    history: [],
    persona: { id: '', name: '', avatarKey: '', status: '', reason: '' },
    personaMemory: { summary: '', preferences: [] },
    rawSurfaceRoot: null,
    generatedAt: '2026-06-26T00:00:00.000Z'
  };
}

function hotelActionDocumentFixture(): HtmlHomeDocument {
  const doc = documentFixture();
  doc.kind = 'hotel';
  const detail: HotelDetailArgsFixture = {
    hotelId: 47675,
    checkInDate: '2026-08-15',
    checkOutDate: '2026-08-17',
    countryCode: 'CN',
    currency: 'CNY',
    adultCount: 2,
    childCount: 0,
    childAgeDetails: [],
    roomCount: 1
  };
  const navigate: HotelNavigateArgsFixture = {
    hotelId: 47675,
    name: '深圳测试酒店',
    address: '深圳市南山区科技南路 88 号',
    latitude: 22.5431,
    longitude: 114.0579
  };
  const call: HotelCallArgsFixture = {
    hotelId: 47675,
    name: '深圳测试酒店',
    displayPhone: '+86 755 1234 5678',
    dialPhone: '+8675512345678',
    provider: 'Google Places',
    providerPlaceId: 'places/ChIJ-real-hotel'
  };
  doc.blocks = [{
    id: 'hotel-47675',
    kind: 'generic-tool-result',
    title: '深圳测试酒店',
    status: 'success',
    source: 'RollingGo',
    metrics: [{ label: 'toolName', value: 'hotel.search' }],
    rows: [{ label: '酒店 ID', value: '47675' }],
    actions: [
      { id: 'hotel.detail', label: '查看实时房型', prompt: '查看实时房型', variant: 'primary', kind: 'prompt', args: detail },
      { id: 'hotel.navigate', label: '导航到酒店', prompt: '导航到酒店', variant: 'secondary', kind: 'prompt', args: navigate },
      { id: 'hotel.call', label: '联系酒店', prompt: '联系酒店', variant: 'secondary', kind: 'prompt', args: call },
      { id: 'hotel.book', label: '预订酒店', prompt: '预订酒店', variant: 'primary', kind: 'prompt', args: detail }
    ]
  }];
  doc.actions = doc.blocks[0].actions.slice();
  return doc;
}

export default function htmlHomeActionPolicyTest() {
  describe('htmlHomeActionPolicy', () => {
    it('allows only actions from the current HTML document snapshot', 0, () => {
      const doc = documentFixture();

      expect(isHtmlHomeActionAllowed(doc, action('gmail.open.web', 'https://mail.google.com/'))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, action('gmail.open.web', 'https://evil.example/'))).assertFalse();
      expect(isHtmlHomeActionAllowed(doc, action('html_open_food_map', '{"index":0,"name":"Coffee"}'))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, action('html_open_food_map', '{"index":99,"name":"Other"}'))).assertFalse();
    });

    it('allows Calendar delete only for a visible real event after confirmation', 0, () => {
      const doc = documentFixture();
      doc.blocks.push({
        id: 'calendar-event-1',
        kind: 'generic-tool-result',
        title: '产品同步',
        subtitle: '',
        status: 'success',
        source: 'Google Calendar API',
        toolId: 'calendar.events.search',
        metrics: [],
        rows: [{ label: 'Event ID', value: 'event-1' }],
        actions: []
      });
      const allowed: CalendarDeleteArgsFixture = { eventId: 'event-1', calendarId: 'primary', confirmed: true };
      const wrongEvent: CalendarDeleteArgsFixture = { eventId: 'event-2', calendarId: 'primary', confirmed: true };
      const unconfirmed: CalendarDeleteArgsFixture = { eventId: 'event-1', calendarId: 'primary', confirmed: false };

      expect(isHtmlHomeActionAllowed(doc,
        action('calendar.event.delete.confirm', '删除日程', 'prompt', allowed))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc,
        action('calendar.event.delete.confirm', '删除日程', 'prompt', wrongEvent))).assertFalse();
      expect(isHtmlHomeActionAllowed(doc,
        action('calendar.event.delete.confirm', '删除日程', 'prompt', unconfirmed))).assertFalse();
      expect(isHtmlHomeActionAllowed(doc,
        action('calendar.event.delete.confirm', '删除日程', 'client', allowed))).assertFalse();
    });

    it('allows dynamic credential save only for the current dynamic block', 0, () => {
      const doc = documentFixture();
      const allowedPayload = JSON.stringify({
        credentialRef: 'dynamic:weather:Authorization',
        credentialValue: 'secret',
        toolId: 'weather.query',
        prompt: '深圳天气'
      });
      const blockedPayload = JSON.stringify({
        credentialRef: 'dynamic:other:Authorization',
        credentialValue: 'secret',
        toolId: 'statistics.search',
        prompt: 'GDP'
      });

      expect(isHtmlHomeActionAllowed(doc, action('html_dynamic_save_and_test', allowedPayload))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, action('html_dynamic_save_and_test', blockedPayload))).assertFalse();
    });

    it('checks action args when allowing HTML actions', 0, () => {
      const doc = documentFixture();
      const expectedArgs: ThreadOnlyArgsFixture = {
        threadId: 'thread-123'
      };
      const blockedArgs: ThreadOnlyArgsFixture = {
        threadId: 'thread-999'
      };
      doc.actions.push({
        id: 'gmail.ai.reply.draft',
        label: 'AI 回复草稿',
        prompt: 'reply',
        variant: 'primary',
        kind: 'prompt',
        args: expectedArgs
      });

      expect(isHtmlHomeActionAllowed(doc, action('gmail.ai.reply.draft', 'reply', 'prompt', expectedArgs))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, action('gmail.ai.reply.draft', 'reply', 'prompt', blockedArgs))).assertFalse();
    });

    it('allows only exact visible read-only hotel actions', 0, () => {
      const doc = hotelActionDocumentFixture();
      const detail = doc.blocks[0].actions[0] as A2uiAction;
      const navigate = doc.blocks[0].actions[1] as A2uiAction;
      const call = doc.blocks[0].actions[2] as A2uiAction;
      const changedNavigate = JSON.parse(JSON.stringify(navigate)) as A2uiAction;
      const changedCall = JSON.parse(JSON.stringify(call)) as A2uiAction;
      const changedDetail = JSON.parse(JSON.stringify(detail)) as A2uiAction;
      (changedNavigate.args as HotelNavigateArgsFixture).latitude = 23.1;
      (changedCall.args as HotelCallArgsFixture).providerPlaceId = 'places/other';
      (changedDetail.args as HotelDetailArgsFixture).hotelId = 99999;

      expect(isHtmlHomeActionAllowed(doc, detail)).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, navigate)).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, call)).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, changedNavigate)).assertFalse();
      expect(isHtmlHomeActionAllowed(doc, changedCall)).assertFalse();
      expect(isHtmlHomeActionAllowed(doc, changedDetail)).assertFalse();

      const changedPhone = JSON.parse(JSON.stringify(call)) as A2uiAction;
      const changedDisplay = JSON.parse(JSON.stringify(call)) as A2uiAction;
      const changedProvider = JSON.parse(JSON.stringify(call)) as A2uiAction;
      const changedCallName = JSON.parse(JSON.stringify(call)) as A2uiAction;
      const changedCallHotel = JSON.parse(JSON.stringify(call)) as A2uiAction;
      (changedPhone.args as HotelCallArgsFixture).dialPhone = '+8675599999999';
      (changedDisplay.args as HotelCallArgsFixture).displayPhone = '+86 755 9999 9999';
      (changedProvider.args as HotelCallArgsFixture).provider = 'Other Places';
      (changedCallName.args as HotelCallArgsFixture).name = '其他酒店';
      (changedCallHotel.args as HotelCallArgsFixture).hotelId = 99999;
      expect(isHtmlHomeActionAllowed(doc, changedPhone)).assertFalse();
      expect(isHtmlHomeActionAllowed(doc, changedDisplay)).assertFalse();
      expect(isHtmlHomeActionAllowed(doc, changedProvider)).assertFalse();
      expect(isHtmlHomeActionAllowed(doc, changedCallName)).assertFalse();
      expect(isHtmlHomeActionAllowed(doc, changedCallHotel)).assertFalse();

      const changedAddress = JSON.parse(JSON.stringify(navigate)) as A2uiAction;
      const changedLongitude = JSON.parse(JSON.stringify(navigate)) as A2uiAction;
      const changedNavigateName = JSON.parse(JSON.stringify(navigate)) as A2uiAction;
      const changedNavigateHotel = JSON.parse(JSON.stringify(navigate)) as A2uiAction;
      (changedAddress.args as HotelNavigateArgsFixture).address = '其他地址';
      (changedLongitude.args as HotelNavigateArgsFixture).longitude = 113.1;
      (changedNavigateName.args as HotelNavigateArgsFixture).name = '其他酒店';
      (changedNavigateHotel.args as HotelNavigateArgsFixture).hotelId = 99999;
      expect(isHtmlHomeActionAllowed(doc, changedAddress)).assertFalse();
      expect(isHtmlHomeActionAllowed(doc, changedLongitude)).assertFalse();
      expect(isHtmlHomeActionAllowed(doc, changedNavigateName)).assertFalse();
      expect(isHtmlHomeActionAllowed(doc, changedNavigateHotel)).assertFalse();

      const changedDate = JSON.parse(JSON.stringify(detail)) as A2uiAction;
      const changedGuests = JSON.parse(JSON.stringify(detail)) as A2uiAction;
      (changedDate.args as HotelDetailArgsFixture).checkInDate = '2026-08-16';
      (changedGuests.args as HotelDetailArgsFixture).adultCount = 3;
      expect(isHtmlHomeActionAllowed(doc, changedDate)).assertFalse();
      expect(isHtmlHomeActionAllowed(doc, changedGuests)).assertFalse();

      const current = hotelActionDocumentFixture();
      current.blocks[0].actions.splice(2, 1);
      current.actions = current.blocks[0].actions.slice();
      expect(isHtmlHomeActionAllowed(current, call)).assertFalse();
      expect(isHtmlHomeActionAllowed(current, doc.blocks[0].actions[3] as A2uiAction)).assertFalse();
    });

    it('allows mail reply submissions only for the matching visible mail card', 0, () => {
      const doc = documentFixture();
      const template: MailReplyArgsFixture = {
        requestKey: '',
        provider: 'gmail',
        threadId: 'thread-123',
        messageId: 'message-123',
        to: ['alice@example.com'],
        subject: 'Re: Status update',
        body: ''
      };
      doc.blocks.push({
        id: 'gmail-message-123',
        kind: 'generic-tool-result',
        title: 'Status update',
        subtitle: '',
        status: 'success',
        source: 'Gmail',
        metrics: [],
        rows: [],
        actions: [{
          id: 'html_mail_detail_read',
          label: '加载正文',
          prompt: 'gmail:thread-123',
          variant: 'secondary',
          kind: 'client'
        }, {
          id: 'gmail.ai.reply.draft',
          label: 'AI 回复草稿',
          prompt: 'reply',
          variant: 'primary',
          kind: 'prompt',
          args: template
        }]
      });
      const allowed: MailReplyArgsFixture = {
        requestKey: 'gmail:thread-123',
        provider: 'gmail',
        threadId: 'thread-123',
        messageId: 'message-123',
        to: ['alice@example.com'],
        subject: 'Re: Status update',
        body: 'Confirmed.'
      };
      const blocked: MailReplyArgsFixture = {
        requestKey: 'gmail:thread-123',
        provider: 'gmail',
        threadId: 'thread-other',
        messageId: 'message-123',
        to: ['alice@example.com'],
        subject: 'Re: Status update',
        body: 'Confirmed.'
      };

      expect(isHtmlHomeActionAllowed(doc,
        action('html_mail_reply_save', 'gmail:thread-123', 'client', allowed))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc,
        action('html_mail_reply_send', 'gmail:thread-123', 'client', allowed))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc,
        action('html_mail_reply_ai_generate', 'gmail:thread-123', 'client', allowed))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc,
        action('html_mail_reply_send', 'gmail:thread-123', 'client', blocked))).assertFalse();
      expect(isHtmlHomeActionAllowed(doc,
        action('html_mail_reply_ai_generate', 'gmail:thread-123', 'client', blocked))).assertFalse();
    });

    it('allows mail calendar add only for the matching visible mail card', 0, () => {
      const doc = documentFixture();
      const detailArgs: MailCalendarArgsFixture = {
        requestKey: '',
        provider: 'gmail',
        threadId: 'thread-123',
        messageId: 'message-123'
      };
      doc.blocks.push({
        id: 'gmail-meeting-123',
        kind: 'generic-tool-result',
        title: 'Meeting invite',
        subtitle: '',
        status: 'success',
        source: 'Gmail',
        metrics: [],
        rows: [],
        actions: [{
          id: 'html_mail_detail_read',
          label: '加载正文',
          prompt: 'gmail:thread-123',
          variant: 'secondary',
          kind: 'client',
          args: detailArgs
        }]
      });
      const allowed: MailCalendarArgsFixture = {
        requestKey: 'gmail:thread-123',
        provider: 'gmail',
        threadId: 'thread-123',
        messageId: 'message-123'
      };
      const blocked: MailCalendarArgsFixture = {
        requestKey: 'gmail:thread-123',
        provider: 'gmail',
        threadId: 'thread-other',
        messageId: 'message-123'
      };

      expect(isHtmlHomeActionAllowed(doc,
        action('html_mail_calendar_add', 'gmail:thread-123', 'client', allowed))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc,
        action('html_mail_calendar_add', 'gmail:thread-123', 'client', blocked))).assertFalse();
    });

    it('allows only matching payment actions from the current HTML document', 0, () => {
      const doc = documentFixture();
      const expectedArgs: ThreadOnlyArgsFixture = {
        threadId: 'payment-123'
      };
      const blockedArgs: ThreadOnlyArgsFixture = {
        threadId: 'payment-999'
      };
      doc.actions.push({
        id: 'payment.confirm',
        label: '确认支付',
        prompt: 'confirm',
        variant: 'primary',
        kind: 'prompt',
        args: expectedArgs
      });

      expect(isHtmlHomeActionAllowed(doc, action('payment.confirm', 'confirm', 'prompt', expectedArgs))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, action('payment.confirm', 'confirm', 'prompt', blockedArgs))).assertFalse();
    });

    it('allows payment account saves only on payment pages with a usable target', 0, () => {
      const doc = documentFixture();
      doc.kind = 'payment';
      doc.blocks = [{
        id: 'payment-save',
        kind: 'generic-tool-result',
        title: '补充金额',
        subtitle: 'Payment target resolved.',
        status: 'ready',
        source: 'PayPal',
        metrics: [
          { label: 'source', value: 'PayPal' },
          { label: 'toolName', value: 'payment.send' }
        ],
        rows: [{ label: '收款方', value: 'Dana' }],
        actions: []
      }];
      const allowed = JSON.stringify({
        displayName: 'Dana',
        aliases: '小丹',
        paypalEmail: 'dana@example.com'
      });
      const missingTarget = JSON.stringify({
        displayName: 'Dana'
      });

      expect(isHtmlHomeActionAllowed(doc, action('payment.account.save', allowed))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, action('payment.account.save', missingTarget))).assertFalse();
      doc.kind = 'generic';
      expect(isHtmlHomeActionAllowed(doc, action('payment.account.save', allowed))).assertFalse();
    });

    it('allows PayPal Google Pay capture only for the current checkout order', 0, () => {
      const doc = documentFixture();
      const checkoutArgs: PaymentCheckoutArgsFixture = {
        provider: 'paypal',
        providerSessionId: 'ORDER-1'
      };
      const checkoutAction: HtmlHomeAction = {
        id: 'payment.checkout.open',
        label: '打开确认页',
        prompt: 'https://www.sandbox.paypal.com/checkoutnow?token=ORDER-1',
        variant: 'primary',
        kind: 'client',
        args: checkoutArgs
      };
      doc.kind = 'payment';
      doc.blocks = [{
        id: 'payment-google-pay',
        kind: 'generic-tool-result',
        title: '打开支付确认页',
        subtitle: 'PayPal Google Pay',
        status: 'needs_user',
        source: 'PayPal',
        metrics: [
          { label: 'source', value: 'PayPal' },
          { label: 'toolName', value: 'payment.send' }
        ],
        rows: [
          { label: '支付方式', value: 'PayPal' },
          { label: '付款方式偏好', value: 'Google Pay' }
        ],
        actions: [checkoutAction]
      }];
      const allowed: PaymentCaptureArgsFixture = {
        provider: 'paypal',
        phase: 'capture',
        providerSessionId: 'ORDER-1'
      };
      const wrongOrder: PaymentCaptureArgsFixture = {
        provider: 'paypal',
        phase: 'capture',
        providerSessionId: 'ORDER-2'
      };

      expect(isHtmlHomeActionAllowed(doc, action('payment.capture', 'capture', 'prompt', allowed))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, action('payment.capture', 'capture', 'prompt', wrongOrder))).assertFalse();
    });

    it('allows luckin confirm option preview actions with switched attrs', 0, () => {
      const doc = documentFixture();
      doc.kind = 'luckin';
      const createArgs: LuckinArgsFixture = {
        deptId: '1001',
        location: '114.0,22.5',
        productId: '2002',
        skuCode: 'SKU001',
        quantity: 1
      };
      const createAction: HtmlHomeAction = {
        id: 'luckin.order.create',
        label: '确认下单',
        prompt: '确认创建瑞幸订单',
        variant: 'primary',
        kind: 'prompt',
        args: createArgs
      };
      doc.blocks = [{
        id: 'luckin-confirm',
        kind: 'generic-tool-result',
        title: '确认瑞幸订单',
        subtitle: '',
        status: 'ready',
        source: '瑞幸',
        metrics: [],
        rows: [],
        actions: [createAction]
      }];
      const optionArgs: LuckinArgsFixture = {
        deptId: '1001',
        location: '114.0,22.5',
        productId: '2002',
        skuCode: 'SKU001',
        quantity: 1,
        previewPrompt: '生椰拿铁，少甜，冰',
        attrGroup: '糖度',
        attrChoice: '少甜'
      };
      const invalidOptionArgs: LuckinArgsFixture = {
        deptId: '1001',
        attrGroup: '糖度',
        attrChoice: '少甜'
      };
      const optionPreview = action('luckin.order.preview', '生椰拿铁，少甜，冰', 'prompt', optionArgs);

      expect(isHtmlHomeActionAllowed(doc, optionPreview)).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, action('luckin.order.preview', 'evil', 'prompt', invalidOptionArgs))).assertFalse();
    });

    it('allows luckin create after option switch when sku changes', 0, () => {
      const doc = documentFixture();
      doc.kind = 'luckin';
      const createArgs: LuckinArgsFixture = {
        deptId: '1001',
        location: '114.0,22.5',
        productId: '2002',
        skuCode: 'SKU001',
        quantity: 1
      };
      const createAction: HtmlHomeAction = {
        id: 'luckin.order.create',
        label: '确认下单',
        prompt: '确认创建瑞幸订单',
        variant: 'primary',
        kind: 'prompt',
        args: createArgs
      };
      doc.blocks = [{
        id: 'luckin-confirm',
        kind: 'generic-tool-result',
        title: '确认瑞幸订单',
        subtitle: '',
        status: 'ready',
        source: '瑞幸',
        metrics: [],
        rows: [],
        actions: [createAction]
      }];
      const switchedArgs: LuckinArgsFixture = {
        deptId: '1001',
        location: '114.0,22.5',
        productId: '2002',
        skuCode: 'SKU002',
        previewPrompt: '生椰拿铁，少甜，冰',
        quantity: 1
      };
      const switchedCreate = action('luckin.order.create', '确认创建瑞幸订单', 'prompt', switchedArgs);

      expect(isHtmlHomeActionAllowed(doc, switchedCreate)).assertTrue();
    });

    it('allows luckin relocate refresh preview on luckin pages', 0, () => {
      const doc = documentFixture();
      doc.kind = 'luckin';
      const args: LuckinArgsFixture = {
        locationSource: 'refresh'
      };
      expect(isHtmlHomeActionAllowed(doc, action('luckin.order.preview', '生椰拿铁', 'prompt', args))).assertTrue();
    });

    it('allows luckin payment page actions without exact snapshot match', 0, () => {
      const doc = documentFixture();
      doc.kind = 'luckin';
      doc.blocks = [{
        id: 'luckin-payment',
        kind: 'generic-tool-result',
        title: '瑞幸订单已创建',
        subtitle: '',
        status: 'success',
        source: '瑞幸',
        metrics: [{ label: 'toolName', value: 'luckin.order.create' }],
        rows: [{ label: '订单号', value: 'LK001' }],
        actions: []
      }];
      doc.actions = [];

      const args: LuckinArgsFixture = { orderId: 'LK001' };

      expect(isHtmlHomeActionAllowed(doc, action('luckin.pay.open', 'weixin://wxpay/bizpayurl?pr=abc', 'client', args))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, action('luckin.demo.alipay.open', 'alipays://', 'client', args))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, action('luckin.demo.googlepay.open', 'google pay', 'client', args))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, action('luckin.order.status', '查询瑞幸订单状态', 'prompt', args))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, action('luckin.pay.open', '', 'client'))).assertTrue();
    });

    it('allows only the current Stripe onboarding URL to open from HTML', 0, () => {
      const doc = documentFixture();
      doc.blocks.push({
        id: 'stripe-receiving',
        kind: 'StripeReceivingAccountCard',
        title: 'Stripe 收款账户',
        subtitle: '继续认证',
        status: 'onboarding_required',
        source: 'stripe',
        metrics: [],
        rows: [],
        actions: [],
        stripeReceiving: {
          status: 'onboarding_required',
          message: '继续认证',
          stripeAccountId: 'acct_123',
          onboardingUrl: 'https://connect.stripe.com/setup/s/acct_123',
          currentlyDue: []
        }
      });

      const allowedArgs: StripeOnboardingArgsFixture = {
        onboardingUrl: 'https://connect.stripe.com/setup/s/acct_123'
      };
      const blockedArgs: StripeOnboardingArgsFixture = {
        onboardingUrl: 'https://evil.example/setup'
      };

      expect(isHtmlHomeActionAllowed(doc, action('stripe.account.open', 'https://connect.stripe.com/setup/s/acct_123', 'client', allowedArgs))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, action('stripe.account.open', 'https://evil.example/setup', 'client', blockedArgs))).assertFalse();
    });
  });
}
