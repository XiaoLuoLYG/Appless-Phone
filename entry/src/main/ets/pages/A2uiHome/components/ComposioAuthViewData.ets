import { ComposioAuthConfigItem } from '@loop/agent-core';

export function composioAuthStatusLabel(status: string): string {
  if (status === 'connected') {
    return '已连接';
  }
  if (status === 'error') {
    return '异常';
  }
  if (status === 'disabled') {
    return '已停用';
  }
  return '待授权';
}

export function composioAuthActionLabel(item: ComposioAuthConfigItem): string {
  return item.status === 'connected' ? '重新授权' : '授权';
}

export function sortedComposioAuthConfigs(items: ComposioAuthConfigItem[]): ComposioAuthConfigItem[] {
  return items.slice().sort((left: ComposioAuthConfigItem, right: ComposioAuthConfigItem) => {
    const leftRank = left.status === 'connected' ? 0 : 1;
    const rightRank = right.status === 'connected' ? 0 : 1;
    if (leftRank !== rightRank) {
      return leftRank - rightRank;
    }
    return left.toolkitName.localeCompare(right.toolkitName);
  });
}
