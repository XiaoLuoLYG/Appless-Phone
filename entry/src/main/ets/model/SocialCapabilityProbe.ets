import { bundleManager } from '@kit.AbilityKit';
import { accessibility } from '@kit.AccessibilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

export interface InstalledAppProbeResult {
  installed: boolean;
  bundleName: string;
  detail: string;
}

export interface AccessibilityProbeResult {
  available: boolean;
  detail: string;
}

const AIPHONE_BUNDLE_NAME: string = 'com.example.aiphonedemo';
const SOCIAL_ACCESSIBILITY_ABILITY: string = 'SocialAccessibilityExtAbility';

const WECHAT_BUNDLE_CANDIDATES: string[] = [
  'com.tencent.wechat.pc',
  'com.tencent.mm'
];

const WECHAT_LINK_CANDIDATES: string[] = [
  'weixin://',
  'wechat://'
];

function errorCodeOf(error: BusinessError): string {
  if (error.code === undefined || error.code === null) {
    return 'unknown';
  }
  return error.code.toString();
}

function hasSocialAccessibilityAbility(list: accessibility.AccessibilityAbilityInfo[]): boolean {
  for (let index = 0; index < list.length; index++) {
    const item = list[index];
    const id = item.id === undefined || item.id === null ? '' : item.id;
    if (item.bundleName === AIPHONE_BUNDLE_NAME &&
      (item.name === SOCIAL_ACCESSIBILITY_ABILITY || id.indexOf(SOCIAL_ACCESSIBILITY_ABILITY) >= 0)) {
      return true;
    }
  }
  return false;
}

export function detectSocialAccessibilitySync(): AccessibilityProbeResult {
  try {
    const enabled = accessibility.getAccessibilityExtensionListSync('all', 'enable');
    if (hasSocialAccessibilityAbility(enabled)) {
      return {
        available: true,
        detail: 'AIPhone 辅助扩展已启用'
      };
    }
    const installed = accessibility.getAccessibilityExtensionListSync('all', 'install');
    if (hasSocialAccessibilityAbility(installed)) {
      return {
        available: false,
        detail: 'AIPhone 辅助扩展已安装但未启用'
      };
    }
    return {
      available: false,
      detail: 'AIPhone 辅助扩展未出现在系统无障碍列表'
    };
  } catch (error) {
    const businessError = error as BusinessError;
    return {
      available: false,
      detail: '辅助扩展状态读取失败(' + errorCodeOf(businessError) + ')：' + businessError.message
    };
  }
}

export function detectWechatBundleSync(): InstalledAppProbeResult {
  const misses: string[] = [];
  for (let index = 0; index < WECHAT_BUNDLE_CANDIDATES.length; index++) {
    const candidate = WECHAT_BUNDLE_CANDIDATES[index];
    try {
      bundleManager.getBundleInfoSync(candidate, bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      return {
        installed: true,
        bundleName: candidate,
        detail: 'bundleManager 已检测到 ' + candidate
      };
    } catch (error) {
      const businessError = error as BusinessError;
      misses.push(candidate + '(' + errorCodeOf(businessError) + ')');
    }
  }
  for (let index = 0; index < WECHAT_LINK_CANDIDATES.length; index++) {
    const link = WECHAT_LINK_CANDIDATES[index];
    try {
      if (bundleManager.canOpenLink(link)) {
        return {
          installed: true,
          bundleName: 'scheme:' + link,
          detail: 'bundle 查询未命中；canOpenLink 可打开 ' + link + '；bundleMiss=' + misses.join(', ')
        };
      }
      misses.push(link + '(canOpen=false)');
    } catch (error) {
      const businessError = error as BusinessError;
      misses.push(link + '(' + errorCodeOf(businessError) + ')');
    }
  }
  return {
    installed: false,
    bundleName: '',
    detail: '未检测到候选包：' + misses.join(', ')
  };
}
