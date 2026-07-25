import { A2uiObservationDigest, summarizeAppliedA2uiSurface } from './A2uiObservationDigest';
import { MultiToolSectionContent, MultiToolSlotStatus } from './MultiToolTypes';
import { parseA2uiJsonl } from '../aiphone/runtime/A2uiParser';
import { A2uiSurfaceStore } from '../aiphone/runtime/A2uiSurfaceStore';
import { A2uiEnvelope, A2uiSurfaceState } from '../aiphone/runtime/A2uiTypes';

function defaultSectionTitle(toolId: string): string {
  if (toolId === 'time') {
    return '当前时间';
  }
  if (toolId === 'flight.search') {
    return '航班';
  }
  if (toolId === 'food.search') {
    return '美食';
  }
  if (toolId === 'train.search') {
    return '高铁';
  }
  if (toolId === 'travel.search') {
    return '出行';
  }
  if (toolId === 'luckin.order.preview') {
    return '瑞幸点单';
  }
  return toolId;
}

function slotStatusFromDigest(failureKey: string, parseError: string, plainTextObservation: boolean): MultiToolSlotStatus {
  if (failureKey.indexOf(':error') >= 0) {
    return 'error';
  }
  if (plainTextObservation) {
    return 'ready';
  }
  if (parseError.length > 0) {
    return 'error';
  }
  return 'ready';
}

function isPlainTextToolObservation(raw: string, parsedEnvelopes: number, parseError: string): boolean {
  if (parsedEnvelopes > 0) {
    return false;
  }
  const trimmed = raw.trim();
  if (trimmed.length === 0) {
    return false;
  }
  if (trimmed.startsWith('{')) {
    return false;
  }
  return true;
}

function nonA2uiDigest(observationRaw: string): A2uiObservationDigest {
  return {
    isA2ui: false,
    text: observationRaw,
    shouldStop: false,
    failureKey: '',
    finalText: ''
  };
}

export function ingestToolObservation(
  slotId: string,
  toolId: string,
  observationRaw: string
): MultiToolSectionContent {
  const parsed = parseA2uiJsonl(observationRaw);
  let embeddedSurface: A2uiSurfaceState | null = null;
  let title = defaultSectionTitle(toolId);
  let digest: A2uiObservationDigest = nonA2uiDigest(observationRaw);
  if (parsed.error.length === 0 && parsed.envelopes.length > 0) {
    const store = new A2uiSurfaceStore();
    for (let index = 0; index < parsed.envelopes.length; index++) {
      const envelope: A2uiEnvelope = parsed.envelopes[index];
      const applied = store.apply(envelope);
      if (!applied.ok) {
        digest = {
          isA2ui: true,
          text: 'ObservationDigest\nerror: ' + applied.error,
          shouldStop: true,
          failureKey: 'a2ui:error',
          finalText: ''
        };
        break;
      }
    }
    if (digest.failureKey !== 'a2ui:error') {
      embeddedSurface = store.getSurface();
      digest = summarizeAppliedA2uiSurface(observationRaw, embeddedSurface);
      if (embeddedSurface.title.trim().length > 0) {
        title = embeddedSurface.title.trim();
      }
    }
  }
  const summary = digest.isA2ui ? digest.text.split('\n').slice(0, 3).join(' ') : observationRaw.substring(0, 180);
  const plainTextObservation = isPlainTextToolObservation(observationRaw, parsed.envelopes.length, parsed.error);
  const content: MultiToolSectionContent = {
    slotId: slotId,
    toolId: toolId,
    title: title,
    status: slotStatusFromDigest(digest.failureKey, parsed.error, plainTextObservation),
    summary: summary,
    completionReply: '',
    observationDigest: digest.text,
    failureKey: digest.failureKey,
    embeddedSurface: embeddedSurface
  };
  content.completionReply = serialStepCompletionReply(toolId, content);
  return content;
}

function compactReply(value: string, limit: number = 96): string {
  const normalized = value.split('\n').join(' ').split('\r').join(' ').trim();
  if (normalized.length <= limit) {
    return normalized;
  }
  return normalized.substring(0, limit) + '…';
}

function rowValue(content: MultiToolSectionContent, label: string): string {
  const lines = content.observationDigest.split('\n');
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index].trim();
    if (line.indexOf(label + ':') === 0) {
      return compactReply(line.substring(label.length + 1).trim());
    }
  }
  return '';
}

export function serialStepCompletionReply(toolId: string, content: MultiToolSectionContent): string {
  if (content.status === 'error' || content.failureKey.length > 0) {
    return content.title.length > 0 ? content.title + '未完成' : toolId + ' 未完成';
  }
  if (toolId === 'time') {
    const observed = content.observationDigest.replace(/^Observation:\s*/u, '').trim();
    return observed.length > 0 ? '已获取当前时间 · ' + compactReply(observed, 72) : '已获取当前时间';
  }
  if (toolId === 'calendar.event.create') {
    const eventTitle = rowValue(content, 'result 1') || content.title;
    return '会议已创建 · ' + compactReply(eventTitle.length > 0 ? eventTitle : '新日程');
  }
  if (toolId === 'calendar.event.update') {
    return '日程已更新 · ' + compactReply(content.title);
  }
  if (toolId === 'calendar.events.search') {
    return '日程查询完成 · ' + compactReply(content.title);
  }
  if (toolId === 'gmail.draft.create' || toolId === 'mail.draft.create') {
    const subject = rowValue(content, 'Subject');
    return subject.length > 0 ? '邮件草稿已准备好 · ' + subject : '邮件草稿已准备好';
  }
  if (toolId === 'gmail.message.send') {
    return '邮件已发送 · ' + compactReply(content.title);
  }
  if (toolId.indexOf('luckin.order') === 0) {
    return '瑞幸订单已更新 · ' + compactReply(content.title);
  }
  if (toolId === 'ride.estimate') {
    return '打车估价完成 · ' + compactReply(content.title);
  }
  if (toolId === 'ride.order.create') {
    return '叫车订单已创建 · ' + compactReply(content.title);
  }
  if (toolId === 'payment.send') {
    return '支付请求已提交 · ' + compactReply(content.title);
  }
  if (toolId === 'hotel.search' || toolId === 'hotel.detail') {
    return '酒店信息已就绪 · ' + compactReply(content.title);
  }
  if (toolId === 'flight.search' || toolId === 'train.search' || toolId === 'travel.search') {
    return '出行方案已返回 · ' + compactReply(content.title);
  }
  if (toolId === 'food.search') {
    return '美食推荐已返回 · ' + compactReply(content.title);
  }
  return compactReply(content.title.length > 0 ? content.title + ' · 已完成' : toolId + ' · 已完成');
}
