import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { notificationExtensionSubscription } from '@kit.NotificationKit';
import { aiLogError, aiLogInfo } from './AiphoneLogger';
import { SocialCaptureCandidate } from './SocialBridge';

const SOCIAL_NOTIFICATION_STORE: string = 'aiphone_social_notifications';
const SOCIAL_NOTIFICATION_RECORDS_KEY: string = 'records';
const MAX_NOTIFICATION_RECORDS: number = 100;

export interface SocialNotificationRecord extends SocialCaptureCandidate {
  hashCode: string;
  bundleName: string;
  appName: string;
  capturedAt: string;
}

export interface SocialNotificationArchiveRead {
  ok: boolean;
  candidates: SocialCaptureCandidate[];
  count: number;
  error: string;
}

interface NotificationContentProbe {
  title?: string;
  text?: string;
  additionalText?: string;
  longText?: Object | string;
  briefText?: string;
  expandedTitle?: string;
  longTitle?: string;
  lines?: string[];
  normal?: NotificationBasicContentProbe;
  multiLine?: NotificationBasicContentProbe;
  picture?: NotificationBasicContentProbe;
  systemLiveView?: NotificationBasicContentProbe;
}

interface NotificationBasicContentProbe {
  title?: string;
  text?: string;
  additionalText?: string;
  longText?: string;
  briefText?: string;
  expandedTitle?: string;
  longTitle?: string;
  lines?: string[];
}

interface NotificationRequestProbe {
  content?: NotificationContentProbe;
  deliveryTime?: number;
  appMessageId?: string;
}

interface NotificationInfoProbe {
  hashCode?: string;
  bundleName?: string;
  appName?: string;
  deliveryTime?: number;
  groupName?: string;
  content?: NotificationContentProbe;
  request?: NotificationRequestProbe;
  notification?: NotificationRequestProbe;
}

interface NotificationTextPair {
  title: string;
  preview: string;
}

function textOf(value: string | undefined | null): string {
  if (value === undefined || value === null) {
    return '';
  }
  return value.trim();
}

function textFromValue(value: Object | string | number | boolean | null | undefined): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value.trim();
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return '';
}

function errorCodeOf(error: BusinessError): string {
  if (error.code === undefined || error.code === null) {
    return 'unknown';
  }
  return error.code.toString();
}

export function isWechatIdentity(bundleName: string, appName: string, title: string): boolean {
  const identity = (bundleName + ' ' + appName + ' ' + title).toLowerCase();
  return identity.indexOf('com.tencent.mm') >= 0 ||
    identity.indexOf('com.tencent.wechat') >= 0 ||
    identity.indexOf('wechat') >= 0 ||
    identity.indexOf('weixin') >= 0 ||
    identity.indexOf('micromsg') >= 0 ||
    identity.indexOf('微信') >= 0;
}

function receivedAtOf(deliveryTime: number | undefined): string {
  if (deliveryTime !== undefined && deliveryTime > 0) {
    return new Date(deliveryTime).toISOString();
  }
  return new Date().toISOString();
}

function firstText(values: Array<Object | string | number | boolean | null | undefined>): string {
  for (let index = 0; index < values.length; index++) {
    const value = textFromValue(values[index]);
    if (value.length > 0) {
      return value;
    }
  }
  return '';
}

function nestedBasicContent(value: Object | string | undefined): NotificationBasicContentProbe | undefined {
  if (value !== undefined && value !== null && typeof value === 'object') {
    return value as NotificationBasicContentProbe;
  }
  return undefined;
}

function linesText(lines: string[] | undefined): string {
  if (lines === undefined || lines.length === 0) {
    return '';
  }
  const texts: string[] = [];
  lines.forEach((line: string) => {
    const text = textOf(line);
    if (text.length > 0) {
      texts.push(text);
    }
  });
  return texts.join('\n');
}

function pairFromBasicContent(content: NotificationBasicContentProbe | undefined): NotificationTextPair {
  if (content === undefined || content === null) {
    return {
      title: '',
      preview: ''
    };
  }
  return {
    title: firstText([content.title, content.expandedTitle, content.longTitle]),
    preview: firstText([content.text, content.longText, content.briefText, content.additionalText, linesText(content.lines)])
  };
}

function mergeTextPair(primary: NotificationTextPair, fallback: NotificationTextPair): NotificationTextPair {
  return {
    title: primary.title.length > 0 ? primary.title : fallback.title,
    preview: primary.preview.length > 0 ? primary.preview : fallback.preview
  };
}

function pairFromNotificationContent(content: NotificationContentProbe | undefined): NotificationTextPair {
  if (content === undefined || content === null) {
    return {
      title: '',
      preview: ''
    };
  }
  let pair = pairFromBasicContent(content as Object as NotificationBasicContentProbe);
  pair = mergeTextPair(pair, pairFromBasicContent(content.normal));
  pair = mergeTextPair(pair, pairFromBasicContent(nestedBasicContent(content.longText)));
  pair = mergeTextPair(pair, pairFromBasicContent(content.multiLine));
  pair = mergeTextPair(pair, pairFromBasicContent(content.picture));
  pair = mergeTextPair(pair, pairFromBasicContent(content.systemLiveView));
  return pair;
}

function pairFromNotificationInfo(probe: NotificationInfoProbe): NotificationTextPair {
  let pair = pairFromNotificationContent(probe.content);
  if (probe.request !== undefined) {
    pair = mergeTextPair(pair, pairFromNotificationContent(probe.request.content));
  }
  if (probe.notification !== undefined) {
    pair = mergeTextPair(pair, pairFromNotificationContent(probe.notification.content));
  }
  return pair;
}

function deliveryTimeFromProbe(probe: NotificationInfoProbe): number | undefined {
  if (probe.deliveryTime !== undefined && probe.deliveryTime > 0) {
    return probe.deliveryTime;
  }
  if (probe.request !== undefined && probe.request.deliveryTime !== undefined && probe.request.deliveryTime > 0) {
    return probe.request.deliveryTime;
  }
  if (probe.notification !== undefined && probe.notification.deliveryTime !== undefined && probe.notification.deliveryTime > 0) {
    return probe.notification.deliveryTime;
  }
  return undefined;
}

function hashCodeFromProbe(probe: NotificationInfoProbe): string {
  const hashCode = textOf(probe.hashCode);
  if (hashCode.length > 0) {
    return hashCode;
  }
  if (probe.request !== undefined) {
    const appMessageId = textOf(probe.request.appMessageId);
    if (appMessageId.length > 0) {
      return appMessageId;
    }
  }
  if (probe.notification !== undefined) {
    const appMessageId = textOf(probe.notification.appMessageId);
    if (appMessageId.length > 0) {
      return appMessageId;
    }
  }
  return '';
}

function normalizeRecord(record: SocialNotificationRecord): SocialNotificationRecord {
  const conversationTitle = textOf(record.conversationTitle);
  const senderName = textOf(record.senderName).length > 0 ? textOf(record.senderName) : conversationTitle;
  const source = textOf(record.source).length > 0 ? textOf(record.source) : 'notification';
  return {
    platform: textOf(record.platform),
    conversationId: textOf(record.conversationId),
    conversationTitle,
    senderName,
    preview: textOf(record.preview),
    receivedAt: textOf(record.receivedAt).length > 0 ? textOf(record.receivedAt) : new Date().toISOString(),
    source,
    hashCode: textOf(record.hashCode),
    bundleName: textOf(record.bundleName),
    appName: textOf(record.appName),
    capturedAt: textOf(record.capturedAt).length > 0 ? textOf(record.capturedAt) : new Date().toISOString()
  };
}

function isUsableRecord(record: SocialNotificationRecord): boolean {
  return record.platform === 'wechat' &&
    record.conversationTitle.length > 0 &&
    record.preview.length > 0 &&
    (record.source === 'notification' || record.source === 'accessibility');
}

function recordFromObject(value: Object): SocialNotificationRecord {
  const loose = value as SocialNotificationRecord;
  return normalizeRecord({
    platform: textOf(loose.platform),
    conversationId: textOf(loose.conversationId),
    conversationTitle: textOf(loose.conversationTitle),
    senderName: textOf(loose.senderName),
    preview: textOf(loose.preview),
    receivedAt: textOf(loose.receivedAt),
    source: textOf(loose.source),
    hashCode: textOf(loose.hashCode),
    bundleName: textOf(loose.bundleName),
    appName: textOf(loose.appName),
    capturedAt: textOf(loose.capturedAt)
  });
}

function readRecordsFromRaw(raw: string): SocialNotificationRecord[] {
  if (raw.trim().length === 0) {
    return [];
  }
  try {
    const parsed = JSON.parse(raw) as Object;
    if (!Array.isArray(parsed)) {
      return [];
    }
    const records: SocialNotificationRecord[] = [];
    (parsed as Object[]).forEach((item: Object) => {
      const record = recordFromObject(item);
      if (isUsableRecord(record)) {
        records.push(record);
      }
    });
    return records;
  } catch (_error) {
    return [];
  }
}

function dedupeKey(record: SocialNotificationRecord): string {
  if (record.hashCode.length > 0) {
    return record.hashCode;
  }
  return record.bundleName + '|' + record.conversationTitle + '|' + record.preview + '|' + record.receivedAt;
}

function trimRecords(records: SocialNotificationRecord[]): SocialNotificationRecord[] {
  const deduped: SocialNotificationRecord[] = [];
  const keys: string[] = [];
  records.forEach((record: SocialNotificationRecord) => {
    const key = dedupeKey(record);
    const existing = keys.indexOf(key);
    if (existing >= 0) {
      deduped[existing] = record;
    } else {
      keys.push(key);
      deduped.push(record);
    }
  });
  deduped.sort((left: SocialNotificationRecord, right: SocialNotificationRecord) => {
    return Date.parse(left.receivedAt) - Date.parse(right.receivedAt);
  });
  while (deduped.length > MAX_NOTIFICATION_RECORDS) {
    deduped.shift();
  }
  return deduped;
}

function candidateFromRecord(record: SocialNotificationRecord): SocialCaptureCandidate {
  return {
    platform: record.platform,
    conversationId: record.conversationId,
    conversationTitle: record.conversationTitle,
    senderName: record.senderName,
    preview: record.preview,
    receivedAt: record.receivedAt,
    source: record.source
  };
}

export function captureRecordFromNotificationInfo(notificationInfo: notificationExtensionSubscription.NotificationInfo): SocialNotificationRecord {
  const probe = notificationInfo as NotificationInfoProbe;
  const content = pairFromNotificationInfo(probe);
  const bundleName = textOf(probe.bundleName);
  const appName = textOf(probe.appName);
  const title = content.title;
  const text = content.preview;
  const platform = isWechatIdentity(bundleName, appName, title) ? 'wechat' : '';
  return normalizeRecord({
    platform,
    conversationId: bundleName + ':' + title,
    conversationTitle: title.length > 0 ? title : appName,
    senderName: title.length > 0 ? title : appName,
    preview: text,
    receivedAt: receivedAtOf(deliveryTimeFromProbe(probe)),
    source: 'notification',
    hashCode: hashCodeFromProbe(probe),
    bundleName,
    appName,
    capturedAt: new Date().toISOString()
  });
}

export function shouldArchiveNotification(record: SocialNotificationRecord): boolean {
  return isUsableRecord(record);
}

export function appendNotificationCapture(context: common.Context, record: SocialNotificationRecord): void {
  if (!shouldArchiveNotification(record)) {
    aiLogInfo('[AIPhone][SocialNotificationSkip] bundle=' + record.bundleName +
      ' app=' + record.appName +
      ' titleChars=' + record.conversationTitle.length.toString() +
      ' textChars=' + record.preview.length.toString());
    return;
  }
  try {
    const store = preferences.getPreferencesSync(context, { name: SOCIAL_NOTIFICATION_STORE });
    const raw = textFromValue(store.getSync(SOCIAL_NOTIFICATION_RECORDS_KEY, ''));
    const records = trimRecords(readRecordsFromRaw(raw).concat([record]));
    store.putSync(SOCIAL_NOTIFICATION_RECORDS_KEY, JSON.stringify(records));
    store.flush().then(() => {
      aiLogInfo('[AIPhone][SocialNotificationArchive] count=' + records.length.toString() +
        ' bundle=' + record.bundleName +
        ' hash=' + record.hashCode);
    }).catch((error: BusinessError) => {
      aiLogError('[AIPhone][SocialNotificationArchiveFlushError] code=' + errorCodeOf(error) +
        ' message=' + error.message);
    });
  } catch (error) {
    const businessError = error as BusinessError;
    aiLogError('[AIPhone][SocialNotificationArchiveError] code=' + errorCodeOf(businessError) +
      ' message=' + businessError.message);
  }
}

export function readNotificationCaptureArchive(context: common.Context): SocialNotificationArchiveRead {
  try {
    const store = preferences.getPreferencesSync(context, { name: SOCIAL_NOTIFICATION_STORE });
    const raw = textFromValue(store.getSync(SOCIAL_NOTIFICATION_RECORDS_KEY, ''));
    const records = readRecordsFromRaw(raw);
    const candidates: SocialCaptureCandidate[] = [];
    records.forEach((record: SocialNotificationRecord) => {
      candidates.push(candidateFromRecord(record));
    });
    return {
      ok: true,
      candidates,
      count: candidates.length,
      error: ''
    };
  } catch (error) {
    const businessError = error as BusinessError;
    return {
      ok: false,
      candidates: [],
      count: 0,
      error: businessError.message
    };
  }
}
