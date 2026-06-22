import { common } from '@kit.AbilityKit';
import {
  AccessibilityElement,
  AccessibilityEvent,
  AccessibilityExtensionAbility
} from '@kit.AccessibilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { aiLogError, aiLogInfo } from '../model/AiphoneLogger';
import {
  SocialNotificationRecord,
  appendNotificationCapture,
  isWechatIdentity
} from '../model/SocialNotificationArchive';

const WECHAT_TARGET_BUNDLES: string[] = [
  'com.tencent.wechat.pc',
  'com.tencent.mm'
];

function textOf(value: string | undefined | null): string {
  if (value === undefined || value === null) {
    return '';
  }
  return value.trim();
}

function errorCodeOf(error: BusinessError): string {
  if (error.code === undefined || error.code === null) {
    return 'unknown';
  }
  return error.code.toString();
}

function stableHash(source: string): string {
  let hash = 0;
  for (let index = 0; index < source.length; index++) {
    hash = ((hash * 31) + source.charCodeAt(index)) % 1000000007;
  }
  return Math.abs(hash).toString();
}

function pushText(values: string[], value: string): void {
  const text = textOf(value);
  if (text.length === 0) {
    return;
  }
  if (values.indexOf(text) < 0) {
    values.push(text);
  }
}

function isGenericWechatLabel(value: string): boolean {
  const normalized = value.toLowerCase();
  return normalized === '微信' || normalized === 'wechat' || normalized === 'weixin';
}

function conversationTitleFromTexts(values: string[], fallback: string): string {
  for (let index = 0; index < values.length; index++) {
    const value = values[index];
    if (!isGenericWechatLabel(value) && value.length <= 80) {
      return value;
    }
  }
  return fallback;
}

function previewFromTexts(values: string[], title: string): string {
  for (let index = values.length - 1; index >= 0; index--) {
    const value = values[index];
    if (!isGenericWechatLabel(value) && value !== title) {
      return value;
    }
  }
  return '';
}

export default class SocialAccessibilityExtAbility extends AccessibilityExtensionAbility {
  onConnect(): void {
    aiLogInfo('[AIPhone][SocialAccessibilityConnect]');
    this.context.setTargetBundleName(WECHAT_TARGET_BUNDLES).then(() => {
      aiLogInfo('[AIPhone][SocialAccessibilityTarget] bundles=' + WECHAT_TARGET_BUNDLES.join(','));
    }).catch((error: BusinessError) => {
      aiLogError('[AIPhone][SocialAccessibilityTargetError] code=' + errorCodeOf(error) +
        ' message=' + error.message);
    });
  }

  onDisconnect(): void {
    aiLogInfo('[AIPhone][SocialAccessibilityDisconnect]');
  }

  onAccessibilityEvent(event: AccessibilityEvent): void {
    this.captureEvent(event);
  }

  private async captureEvent(event: AccessibilityEvent): Promise<void> {
    const target = event.target;
    if (target === undefined || target === null) {
      aiLogInfo('[AIPhone][SocialAccessibilitySkip] noTarget event=' + event.eventType);
      return;
    }
    try {
      const record = await this.recordFromTarget(event, target);
      appendNotificationCapture(this.context as common.Context, record);
    } catch (error) {
      const businessError = error as BusinessError;
      aiLogError('[AIPhone][SocialAccessibilityCaptureError] code=' + errorCodeOf(businessError) +
        ' message=' + businessError.message);
    }
  }

  private async recordFromTarget(event: AccessibilityEvent, target: AccessibilityElement): Promise<SocialNotificationRecord> {
    const bundleName = textOf(await target.attributeValue('bundleName'));
    const description = textOf(await target.attributeValue('description'));
    const lastContent = textOf(await target.attributeValue('lastContent'));
    const contents = await target.attributeValue('contents');
    const values: string[] = [];
    if (Array.isArray(contents)) {
      contents.forEach((item: string) => {
        pushText(values, item);
      });
    }
    pushText(values, description);
    pushText(values, lastContent);
    pushText(values, textOf(event.textAnnouncedForAccessibility));
    pushText(values, textOf(event.extraInfo));

    const identityText = values.join(' ');
    const platform = isWechatIdentity(bundleName, '', identityText) ? 'wechat' : '';
    const fallbackTitle = bundleName.length > 0 ? bundleName : '微信';
    const title = conversationTitleFromTexts(values, fallbackTitle);
    const preview = previewFromTexts(values, title);
    const receivedAt = event.timeStamp === undefined || event.timeStamp === null || event.timeStamp <= 0 ?
      new Date().toISOString() : new Date(event.timeStamp).toISOString();
    const hashSource = bundleName + '|' + title + '|' + preview + '|' + receivedAt + '|' + event.eventType;
    return {
      platform,
      conversationId: bundleName + ':' + title,
      conversationTitle: title,
      senderName: title,
      preview,
      receivedAt,
      source: 'accessibility',
      hashCode: 'accessibility-' + stableHash(hashSource),
      bundleName,
      appName: '微信',
      capturedAt: new Date().toISOString()
    };
  }
}
