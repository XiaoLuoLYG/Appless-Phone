import { describe, it, expect } from '@ohos/hypium';
import { notificationExtensionSubscription } from '@kit.NotificationKit';
import {
  AccessibilityIngestProvider,
  NotificationIngestProvider,
  SOCIAL_SYSTEM_NOTIFICATION_PERMISSION_NAMES,
  SocialMessageStore,
  WechatReplyAutomation,
  buildSocialDiagnosticsRows,
  probeSocialCapabilities
} from '../main/ets/model/SocialBridge';
import { captureRecordFromNotificationInfo, isWechatIdentity } from '../main/ets/model/SocialNotificationArchive';

export default function socialBridgeTest() {
  describe('socialBridge', () => {
    it('keeps only real captured social messages and deduplicates repeats', 0, () => {
      const store = new SocialMessageStore(24 * 60 * 60 * 1000, 3);
      const first = store.ingest({
        platform: 'wechat',
        conversationTitle: 'Alice',
        senderName: 'Alice',
        preview: '晚上一起吃饭吗',
        receivedAt: '2026-06-11T08:30:00.000Z',
        source: 'notification'
      });
      const duplicate = store.ingest({
        platform: 'wechat',
        conversationTitle: 'Alice',
        senderName: 'Alice',
        preview: '晚上一起吃饭吗',
        receivedAt: '2026-06-11T08:30:20.000Z',
        source: 'notification'
      });

      expect(first.accepted).assertTrue();
      expect(duplicate.accepted).assertFalse();
      expect(store.messages()[0].id).assertEqual(first.message.id);
      expect(store.messages().length).assertEqual(1);
    });

    it('evicts old and overflow messages from local short term storage', 0, () => {
      const store = new SocialMessageStore(60 * 1000, 2);
      store.ingest({
        platform: 'wechat',
        conversationTitle: 'Old',
        senderName: 'Old',
        preview: '过期消息',
        receivedAt: '2026-06-11T08:00:00.000Z',
        source: 'notification'
      }, '2026-06-11T08:02:00.000Z');
      store.ingest({
        platform: 'wechat',
        conversationTitle: 'A',
        senderName: 'A',
        preview: '第一条',
        receivedAt: '2026-06-11T08:02:01.000Z',
        source: 'notification'
      }, '2026-06-11T08:02:01.000Z');
      store.ingest({
        platform: 'wechat',
        conversationTitle: 'B',
        senderName: 'B',
        preview: '第二条',
        receivedAt: '2026-06-11T08:02:02.000Z',
        source: 'notification'
      }, '2026-06-11T08:02:02.000Z');
      store.ingest({
        platform: 'wechat',
        conversationTitle: 'C',
        senderName: 'C',
        preview: '第三条',
        receivedAt: '2026-06-11T08:02:03.000Z',
        source: 'notification'
      }, '2026-06-11T08:02:03.000Z');

      expect(store.messages().length).assertEqual(2);
      expect(store.messages()[0].conversationTitle).assertEqual('C');
      expect(store.messages()[1].conversationTitle).assertEqual('B');
    });

    it('reports unavailable ingest providers without creating synthetic messages', 0, () => {
      const notification = new NotificationIngestProvider(false, '缺少通知控制权限');
      const accessibility = new AccessibilityIngestProvider(false, '辅助权限未授权');

      expect(notification.capture().messages.length).assertEqual(0);
      expect(notification.capture().ok).assertFalse();
      expect(accessibility.capture().messages.length).assertEqual(0);
      expect(accessibility.capture().error).assertEqual('辅助权限未授权');
    });

    it('recognizes WeChat PC bundle identity from HarmonyOS PC notifications', 0, () => {
      expect(isWechatIdentity('com.tencent.wechat.pc', '', '')).assertTrue();
    });

    it('normalizes nested system notification content from WeChat PC', 0, () => {
      const notificationInfo = {
        hashCode: 'wechat-system-core-1',
        bundleName: 'com.tencent.wechat.pc',
        appName: '微信',
        deliveryTime: Date.parse('2026-06-16T10:00:00.000Z'),
        content: {
          title: '',
          text: ''
        },
        request: {
          content: {
            normal: {
              title: '文件传输助手',
              text: 'system core hello'
            }
          }
        }
      } as Object as notificationExtensionSubscription.NotificationInfo;
      const record = captureRecordFromNotificationInfo(notificationInfo);

      expect(record.platform).assertEqual('wechat');
      expect(record.bundleName).assertEqual('com.tencent.wechat.pc');
      expect(record.conversationTitle).assertEqual('文件传输助手');
      expect(record.preview).assertEqual('system core hello');
      expect(record.source).assertEqual('notification');
      expect(record.receivedAt).assertEqual('2026-06-16T10:00:00.000Z');
    });

    it('prepares system-core notification subscriber permissions before signing', 0, () => {
      expect(SOCIAL_SYSTEM_NOTIFICATION_PERMISSION_NAMES.indexOf('ohos.permission.SUBSCRIBE_NOTIFICATION') >= 0).assertTrue();
      expect(SOCIAL_SYSTEM_NOTIFICATION_PERMISSION_NAMES.indexOf('ohos.permission.NOTIFICATION_SYSTEM_SUBSCRIBER') >= 0).assertTrue();
      expect(SOCIAL_SYSTEM_NOTIFICATION_PERMISSION_NAMES.indexOf('ohos.permission.NOTIFICATION_CONTROLLER') >= 0).assertTrue();
      expect(SOCIAL_SYSTEM_NOTIFICATION_PERMISSION_NAMES.indexOf('ohos.permission.SUBSCRIBE_NOTIFICATION_WINDOW_STATE') >= 0).assertTrue();
    });

    it('fails reply dispatch explicitly when WeChat automation is unavailable', 0, () => {
      const automation = new WechatReplyAutomation(false, '辅助自动化未授权');
      const result = automation.send({
        targetMessageId: 'wechat-1',
        platform: 'wechat',
        conversationId: 'wechat-alice',
        text: '可以'
      });

      expect(result.status).assertEqual('failed');
      expect(result.error).assertEqual('辅助自动化未授权');
      expect(result.text).assertEqual('可以');
    });

    it('builds diagnostics rows from capability probe without hiding unavailable paths', 0, () => {
      const capabilities = probeSocialCapabilities({
        notificationBridgeAvailable: false,
        notificationBridgeDetail: '通知权限未授予',
        accessibilityAvailable: true,
        accessibilityDetail: '辅助捕获可用',
        wechatInstalled: false,
        wechatBundleName: '',
        wechatDetectionDetail: 'bundle 查询失败',
        lastCapture: '无真实消息',
        lastSend: '未发送'
      });
      const rows = buildSocialDiagnosticsRows(capabilities);

      expect(rows[1].value).assertEqual('不可用');
      expect(rows[2].value).assertEqual('通知权限未授予');
      expect(rows[3].value).assertEqual('可用');
      expect(rows[4].value).assertEqual('辅助捕获可用');
      expect(rows[5].value).assertEqual('未检测到');
      expect(rows[6].value).assertEqual('无');
      expect(rows[7].value).assertEqual('bundle 查询失败');
    });
  });
}
