import { hilog } from '@kit.PerformanceAnalysisKit';

const LOG_DOMAIN = 0x0000;
const LOG_TAG = 'LoopSkill';
const MAX_LOG_LENGTH = 800;

export function skillLogInfo(message: string): void {
  const safe = trimForLog(message);
  hilog.info(LOG_DOMAIN, LOG_TAG, '%{public}s', safe);
}

export function skillLogWarn(message: string): void {
  const safe = trimForLog(message);
  hilog.warn(LOG_DOMAIN, LOG_TAG, '%{public}s', safe);
}

function trimForLog(message: string): string {
  if (message.length <= MAX_LOG_LENGTH) {
    return message;
  }
  return `${message.substring(0, MAX_LOG_LENGTH)}...`;
}
