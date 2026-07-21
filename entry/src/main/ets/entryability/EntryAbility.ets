import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { preferences } from '@kit.ArkData';
import util from '@ohos.util';
import {
  aiLogError,
  aiLogInfo,
  AssetCredentialStore,
  configureComposioConfigFromRawJson,
  configureLocalModelSettingsFromRawJson,
  configureLocalProviderConfigFromRawJson,
  gmailOAuthConfigFromProvider,
  handleGmailOAuthRedirect,
  localModelSettingsDebugSummary,
  localProviderConfigDebugSummary
} from '@loop/agent-core';
import { configurePersonaStoreFromRaw } from '../model/PersonaStore';
import {
  claimDueTrainPresaleTask,
  parseTrainPresaleTaskList,
  serializeTrainPresaleTaskList,
  TRAIN_PRESALE_TASK_STORE_NAME,
  TrainPresaleTask,
  TrainPresaleTaskState,
  updateTrainPresaleTask
} from '../pages/A2uiHome/train/TrainPresaleTaskStore';

const DOMAIN = 0x0000;
const LOCAL_PROVIDER_CONFIG_RAWFILE = 'aiphone_provider_config.json';
const COMPOSIO_CONFIG_RAWFILE = 'composio_config.json';
const PERSONA_MANIFEST_RAWFILE = 'personas/personas.json';
const PERSONA_IDS: string[] = [
  'default_companion',
  'food_companion',
  'travel_companion',
  'work_companion',
  'entertainment_companion',
  'game_companion',
  'shopping_companion'
];
const PERSONA_SKILL_PATHS: Record<string, string[]> = {
  'default_companion': ['skills/default-general/SKILL.md'],
  'food_companion': ['skills/food-search/SKILL.md', 'skills/coffee-order/SKILL.md', 'skills/milk-tea/SKILL.md'],
  'travel_companion': ['skills/travel-planning/SKILL.md', 'skills/train-planning/SKILL.md', 'skills/flight-planning/SKILL.md'],
  'work_companion': ['skills/work-assistant/SKILL.md', 'skills/mail-draft/SKILL.md', 'skills/calendar-planning/SKILL.md'],
  'entertainment_companion': ['skills/media-search/SKILL.md', 'skills/worldcup-night/SKILL.md', 'skills/youtube-search/SKILL.md'],
  'game_companion': ['skills/game-research/SKILL.md', 'skills/build-guide/SKILL.md'],
  'shopping_companion': ['skills/shopping-research/SKILL.md', 'skills/budget-compare/SKILL.md']
};
const GMAIL_REVERSED_CLIENT_SCHEME = 'com.googleusercontent.apps.358078200829-covuu6l8dgvs7kaejua7mrkke7e8833b:/oauth2redirect';
const GMAIL_OAUTH_URI_HINTS: string[] = [
  'com.example.aiphonedemo:/oauth/google',
  'com.example.aiphonedemo://oauth/google',
  'aiphone://oauth/google',
  GMAIL_REVERSED_CLIENT_SCHEME
];
const COMPOSIO_CALLBACK_URI_HINTS: string[] = [
  'aiphone://composio/callback'
];
export const TRAIN_PRESALE_TASKS_KEY: string = 'tasks';
export const TRAIN_PRESALE_PENDING_TASK_KEY: string = 'pending_execution_task_id';
export const TRAIN_PRESALE_HANDOFF_EVENT: string = 'trainPresaleHandoffChanged';
const TRAIN_PRESALE_REPLACED_REASON: string = '新的开售提醒已到达；请重新打开此任务继续。';

export interface TrainPresaleHandoffClaimResult {
  taskId: string;
  changed: boolean;
}

export interface TrainPresaleHandoffTransitionResult {
  task: TrainPresaleTask | undefined;
  cleared: boolean;
}

function hasUriHint(uri: string, hints: string[]): boolean {
  for (let index = 0; index < hints.length; index++) {
    if (uri.indexOf(hints[index]) === 0) {
      return true;
    }
  }
  return false;
}

function isGmailOAuthRedirectUri(uri: string): boolean {
  return hasUriHint(uri, GMAIL_OAUTH_URI_HINTS);
}

function isComposioCallbackUri(uri: string): boolean {
  return hasUriHint(uri, COMPOSIO_CALLBACK_URI_HINTS);
}

function describeError(error: Error | Object | string | number | boolean | null | undefined): string {
  if (error === undefined || error === null) {
    return '';
  }
  if (error instanceof Error) {
    return error.message;
  }
  if (typeof error === 'string' || typeof error === 'number' || typeof error === 'boolean') {
    return error.toString();
  }
  return JSON.stringify(error);
}

function allOAuthUriHints(): string[] {
  return GMAIL_OAUTH_URI_HINTS.concat(COMPOSIO_CALLBACK_URI_HINTS);
}

function shouldInspectPotentialOAuthText(value: string): boolean {
  return value.indexOf('oauth') >= 0 ||
    value.indexOf('google') >= 0 ||
    value.indexOf('composio') >= 0 ||
    value.indexOf('callback') >= 0 ||
    value.indexOf('/x') >= 0 ||
    value.indexOf('state=') >= 0 ||
    value.indexOf('code=') >= 0;
}

function decodeUriCandidate(value: string): string {
  try {
    return decodeURIComponent(value.replace(/\+/g, ' '));
  } catch (_err) {
    return value;
  }
}

function embeddedUriFromText(value: string): string {
  const decoded = decodeUriCandidate(value);
  const variants: string[] = value === decoded ? [value] : [value, decoded];
  for (let valueIndex = 0; valueIndex < variants.length; valueIndex++) {
    const candidateText = variants[valueIndex];
    const hints = allOAuthUriHints();
    for (let hintIndex = 0; hintIndex < hints.length; hintIndex++) {
      const hint = hints[hintIndex];
      const start = candidateText.indexOf(hint);
      if (start < 0) {
        continue;
      }
      let end = candidateText.length;
      const terminators: string[] = ['"', '\'', ' ', '\n', '\r', '\t', '<', '>', '}'];
      for (let termIndex = 0; termIndex < terminators.length; termIndex++) {
        const termAt = candidateText.indexOf(terminators[termIndex], start);
        if (termAt >= 0 && termAt < end) {
          end = termAt;
        }
      }
      return candidateText.substring(start, end);
    }
  }
  return '';
}

function appendOAuthUriCandidates(candidates: string[], value: Object | string | number | boolean | null | undefined): void {
  if (value === undefined || value === null) {
    return;
  }
  if (typeof value === 'string') {
    if (!shouldInspectPotentialOAuthText(value)) {
      return;
    }
    candidates.push(value);
    const decoded = decodeUriCandidate(value);
    if (decoded !== value) {
      candidates.push(decoded);
    }
    const embedded = embeddedUriFromText(value);
    if (embedded.length > 0) {
      candidates.push(embedded);
    }
    return;
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return;
  }
  try {
    appendOAuthUriCandidates(candidates, JSON.stringify(value));
  } catch (_err) {
  }
}

function gmailOAuthWantParameterKeys(want: Want): string {
  const params = want.parameters;
  if (params === undefined || params === null) {
    return '';
  }
  const keys: string[] = [];
  Object.keys(params).forEach((key: string) => {
    keys.push(key);
  });
  return keys.join('|').substring(0, 240);
}

function oauthUriFromWant(want: Want): string {
  const candidates: string[] = [];
  appendOAuthUriCandidates(candidates, want.uri);
  const params = want.parameters;
  if (params !== undefined && params !== null) {
    Object.keys(params).forEach((key: string) => {
      appendOAuthUriCandidates(candidates, params[key]);
    });
  }
  for (let index = 0; index < candidates.length; index++) {
    const candidate = candidates[index];
    if (isGmailOAuthRedirectUri(candidate) || isComposioCallbackUri(candidate)) {
      return candidate;
    }
  }
  return '';
}

function preferenceText(value: preferences.ValueType): string {
  return typeof value === 'string' ? value : '';
}

function trainPresaleTaskIdFromWant(want: Want): string | undefined {
  const params = want.parameters;
  if (params === undefined || params === null) {
    return undefined;
  }
  const value = params['trainPresaleTaskId'];
  return typeof value === 'string' && value.trim().length > 0 ? value.trim() : undefined;
}

function trainPresaleTasks(store: preferences.Preferences): TrainPresaleTask[] {
  return parseTrainPresaleTaskList(preferenceText(store.getSync(TRAIN_PRESALE_TASKS_KEY, '')));
}

function trainPresaleTaskIndex(tasks: TrainPresaleTask[], taskId: string): number {
  for (let index = 0; index < tasks.length; index++) {
    if (tasks[index].taskId === taskId) {
      return index;
    }
  }
  return -1;
}

export function claimTrainPresaleHandoff(
  store: preferences.Preferences,
  nowIso: string,
  explicitTaskId?: string
): TrainPresaleHandoffClaimResult {
  const tasks = trainPresaleTasks(store);
  const previousPending = preferenceText(store.getSync(TRAIN_PRESALE_PENDING_TASK_KEY, '')).trim();
  const explicit = explicitTaskId === undefined ? '' : explicitTaskId.trim();
  if (explicit.length > 0) {
    const targetIndex = trainPresaleTaskIndex(tasks, explicit);
    if (targetIndex < 0) {
      return { taskId: previousPending, changed: false };
    }
    let updatedTasks = tasks;
    let target = tasks[targetIndex];
    if (target.state === 'scheduled') {
      const claimed = claimDueTrainPresaleTask(tasks, nowIso, explicit);
      if (claimed.task === undefined) {
        return { taskId: previousPending, changed: false };
      }
      updatedTasks = claimed.tasks;
      target = claimed.task;
    } else if (target.state !== 'executing') {
      return { taskId: previousPending, changed: false };
    }
    if (previousPending.length > 0 && previousPending !== explicit) {
      const replacedIndex = trainPresaleTaskIndex(updatedTasks, previousPending);
      if (replacedIndex >= 0 && updatedTasks[replacedIndex].state === 'executing') {
        updatedTasks[replacedIndex] = updateTrainPresaleTask(updatedTasks[replacedIndex], {
          state: 'needs_user',
          lastError: TRAIN_PRESALE_REPLACED_REASON
        });
      }
    }
    store.putSync(TRAIN_PRESALE_TASKS_KEY, serializeTrainPresaleTaskList(updatedTasks));
    store.putSync(TRAIN_PRESALE_PENDING_TASK_KEY, target.taskId);
    store.flushSync();
    return { taskId: target.taskId, changed: previousPending !== target.taskId || tasks[targetIndex].state === 'scheduled' };
  }
  const pendingIndex = trainPresaleTaskIndex(tasks, previousPending);
  if (pendingIndex >= 0 && tasks[pendingIndex].state === 'executing') {
    return { taskId: previousPending, changed: false };
  }
  const claimed = claimDueTrainPresaleTask(tasks, nowIso);
  if (claimed.task === undefined) {
    if (previousPending.length > 0) {
      store.deleteSync(TRAIN_PRESALE_PENDING_TASK_KEY);
      store.flushSync();
    }
    return { taskId: '', changed: false };
  }
  store.putSync(TRAIN_PRESALE_TASKS_KEY, serializeTrainPresaleTaskList(claimed.tasks));
  store.putSync(TRAIN_PRESALE_PENDING_TASK_KEY, claimed.task.taskId);
  store.flushSync();
  return { taskId: claimed.task.taskId, changed: true };
}

export function transitionTrainPresaleHandoff(
  store: preferences.Preferences,
  taskId: string,
  state: TrainPresaleTaskState,
  reason: string
): TrainPresaleHandoffTransitionResult {
  const pending = preferenceText(store.getSync(TRAIN_PRESALE_PENDING_TASK_KEY, '')).trim();
  const tasks = trainPresaleTasks(store);
  const index = trainPresaleTaskIndex(tasks, taskId);
  const current = index < 0 ? undefined : tasks[index];
  if (state === 'executing' || pending !== taskId || current === undefined) {
    return { task: current, cleared: false };
  }
  const updated = updateTrainPresaleTask(current, { state: state, lastError: reason });
  if (updated.state !== state) {
    return { task: current, cleared: false };
  }
  tasks[index] = updated;
  store.putSync(TRAIN_PRESALE_TASKS_KEY, serializeTrainPresaleTaskList(tasks));
  store.flushSync();
  const pendingAfterTaskFlush = preferenceText(store.getSync(TRAIN_PRESALE_PENDING_TASK_KEY, '')).trim();
  if (pendingAfterTaskFlush !== taskId) {
    return { task: tasks[index], cleared: false };
  }
  store.deleteSync(TRAIN_PRESALE_PENDING_TASK_KEY);
  store.flushSync();
  return { task: tasks[index], cleared: true };
}

export function transitionBoundTrainPresaleCheckout(
  store: preferences.Preferences,
  boundCheckoutTaskId: string,
  closingTaskId: string,
  reason: string
): TrainPresaleHandoffTransitionResult {
  if (boundCheckoutTaskId.length === 0 || closingTaskId !== boundCheckoutTaskId) {
    return { task: undefined, cleared: false };
  }
  return transitionTrainPresaleHandoff(store, closingTaskId, 'needs_user', reason);
}

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    this.loadLocalProviderConfig();
    this.loadComposioConfig();
    this.loadPersonaPacks();
    this.handleOAuthWant(want);
    this.claimTrainPresaleTask(want);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  private rawfileText(path: string): string {
    const bytes = this.context.resourceManager.getRawFileContentSync(path);
    const decoder = util.TextDecoder.create('utf-8');
    return decoder.decodeToString(bytes);
  }

  private optionalRawfileText(path: string): string {
    try {
      return this.rawfileText(path);
    } catch (_err) {
      return '';
    }
  }

  private loadLocalProviderConfig(): void {
    try {
      const rawJson = this.rawfileText(LOCAL_PROVIDER_CONFIG_RAWFILE);
      configureLocalProviderConfigFromRawJson(rawJson);
      configureLocalModelSettingsFromRawJson(rawJson);
      hilog.info(DOMAIN, 'testTag', 'Loaded local provider config. agentCore=%{public}s %{public}s',
        localProviderConfigDebugSummary(),
        localModelSettingsDebugSummary());
    } catch (err) {
      hilog.info(DOMAIN, 'testTag', 'Local provider config not loaded from %{public}s. Cause: %{public}s', LOCAL_PROVIDER_CONFIG_RAWFILE, JSON.stringify(err));
    }
  }

  private loadComposioConfig(): void {
    try {
      configureComposioConfigFromRawJson(this.rawfileText(COMPOSIO_CONFIG_RAWFILE));
      hilog.info(DOMAIN, 'testTag', 'Loaded Composio config.');
    } catch (err) {
      hilog.info(DOMAIN, 'testTag', 'Composio config not loaded from %{public}s. Cause: %{public}s', COMPOSIO_CONFIG_RAWFILE, JSON.stringify(err));
    }
  }

  private loadPersonaPacks(): void {
    try {
      const files: Record<string, string> = {};
      for (let index = 0; index < PERSONA_IDS.length; index++) {
        const personaId = PERSONA_IDS[index];
        files[personaId + '/soul.md'] = this.rawfileText('personas/' + personaId + '/soul.md');
        files[personaId + '/skills.md'] = this.rawfileText('personas/' + personaId + '/skills.md');
        files[personaId + '/memory.md'] = this.rawfileText('personas/' + personaId + '/memory.md');
        const skillManifest = this.optionalRawfileText('personas/' + personaId + '/skills.json');
        if (skillManifest.length > 0) {
          files[personaId + '/skills.json'] = skillManifest;
        }
        const skillPaths = PERSONA_SKILL_PATHS[personaId];
        if (skillPaths !== undefined) {
          for (let skillIndex = 0; skillIndex < skillPaths.length; skillIndex++) {
            const skillPath = skillPaths[skillIndex];
            const skillText = this.optionalRawfileText('personas/' + personaId + '/' + skillPath);
            if (skillText.length > 0) {
              files[personaId + '/' + skillPath] = skillText;
            }
          }
        }
      }
      configurePersonaStoreFromRaw(this.rawfileText(PERSONA_MANIFEST_RAWFILE), files);
      hilog.info(DOMAIN, 'testTag', 'Loaded persona packs. count=%{public}d', PERSONA_IDS.length);
    } catch (err) {
      hilog.info(DOMAIN, 'testTag', 'Persona packs not loaded from rawfile. Cause: %{public}s', JSON.stringify(err));
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onNewWant');
    const uri = oauthUriFromWant(want);
    this.loadLocalProviderConfig();
    if (!isComposioCallbackUri(uri)) {
      this.loadComposioConfig();
    }
    this.loadPersonaPacks();
    this.handleOAuthWant(want);
    const result = this.claimTrainPresaleTask(want);
    if (result.changed) {
      this.context.getApplicationContext().eventHub.emit(TRAIN_PRESALE_HANDOFF_EVENT);
    }
  }

  private claimTrainPresaleTask(want: Want): TrainPresaleHandoffClaimResult {
    try {
      const store = preferences.getPreferencesSync(this.context, { name: TRAIN_PRESALE_TASK_STORE_NAME });
      const result = claimTrainPresaleHandoff(store, new Date().toISOString(), trainPresaleTaskIdFromWant(want));
      if (result.taskId.length > 0) {
        aiLogInfo('[AIPhone][TrainPresaleClaim] taskId=' + result.taskId +
          ' changed=' + (result.changed ? 'true' : 'false'));
      }
      return result;
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      aiLogError('[AIPhone][TrainPresaleClaim] error=' + message.substring(0, 240));
      return { taskId: '', changed: false };
    }
  }

  private handleOAuthWant(want: Want): void {
    const directUri = want.uri === undefined ? '' : want.uri;
    const uri = oauthUriFromWant(want);
    if (isComposioCallbackUri(uri)) {
      aiLogInfo('[AIPhone][ComposioCallbackWantReceived] uriChars=' + uri.length.toString());
      return;
    }
    if (!isGmailOAuthRedirectUri(uri)) {
      const parameterKeys = gmailOAuthWantParameterKeys(want);
      if (directUri.indexOf('oauth') >= 0 || directUri.indexOf('google') >= 0 || parameterKeys.length > 0) {
        aiLogInfo('[AIPhone][GmailOAuthWantIgnored] directUriChars=' + directUri.length.toString() +
          ' directHasCode=' + (directUri.indexOf('code=') >= 0 ? 'true' : 'false') +
          ' directHasState=' + (directUri.indexOf('state=') >= 0 ? 'true' : 'false') +
          ' directHasError=' + (directUri.indexOf('error=') >= 0 ? 'true' : 'false') +
          ' parameterKeys=' + parameterKeys);
      }
      return;
    }
    const config = gmailOAuthConfigFromProvider();
    aiLogInfo('[AIPhone][GmailOAuthWantReceived] uriChars=' + uri.length.toString() +
      ' hasCode=' + (uri.indexOf('code=') >= 0 ? 'true' : 'false') +
      ' hasState=' + (uri.indexOf('state=') >= 0 ? 'true' : 'false') +
      ' hasError=' + (uri.indexOf('error=') >= 0 ? 'true' : 'false') +
      ' clientConfigured=' + (config.clientId.length > 0 ? 'true' : 'false') +
      ' secretConfigured=' + (config.clientSecret.length > 0 ? 'true' : 'false') +
      ' redirectChars=' + config.redirectUri.length.toString());
    handleGmailOAuthRedirect(new AssetCredentialStore(), gmailOAuthConfigFromProvider(), uri)
      .then(() => {
        aiLogInfo('[AIPhone][GmailOAuthWantSaved] ok=true');
        hilog.info(DOMAIN, 'testTag', '%{public}s', 'Gmail OAuth authorization saved.');
      })
      .catch((err: Error | Object | string | number | boolean | null | undefined) => {
        const message = describeError(err);
        aiLogError('[AIPhone][GmailOAuthWantFailed] ' + message);
        hilog.error(DOMAIN, 'testTag', 'Gmail OAuth callback failed. Cause: %{public}s', message);
      });
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/A2uiHome/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    webview.WebCookieManager.saveCookieAsync()
      .catch((_error: Error) => {
        aiLogError('[AIPhone][WebCookieSaveOnBackground] ok=false');
      });
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
