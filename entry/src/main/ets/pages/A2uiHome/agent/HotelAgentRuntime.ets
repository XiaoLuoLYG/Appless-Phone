import {
  ActionAgent,
  ActionArgsValidator,
  ActionCatalog,
  ActionOffer,
  ActionOfferContext,
  ActionOfferResolver,
  ActionPlanStepOutput,
  ActionProgressPayload,
  ActionResultPayload,
  ActionRunPayload,
  ActionValidationResult,
  AgentMessage,
  AgentMessageReader,
  AgentMessageType,
  A2uiAction,
  A2uiApplyResult,
  A2uiEnvelope,
  A2uiRuntimeDataModel,
  A2uiSurfaceState,
  A2uiSurfaceStore,
  ClientActionAuthorizer,
  CreateDataTaskPayload,
  CreateUiTaskPayload,
  DataAgent,
  DataResult,
  DataTaskAuthorizationResult,
  DataTaskExecutor,
  HotelBookingOpenArgs,
  HotelDetailResult,
  HotelNavigateArgs,
  HotelRatePlan,
  HotelSearchItem,
  HotelSearchResult,
  LeaderAgent,
  LeaderPlanningContext,
  LinkedMessageBus,
  LocalModel,
  SingleDataUiTaskRenderer,
  SingleDataUiTaskRendererAdapter,
  SurfaceActionAuthorizer,
  TaskErrorPayload,
  ToolDefinition,
  ToolDefinitionLookup,
  UiLayoutPlanner,
  UiAgent,
  UiRenderResult,
  UiRenderResultPayload,
  UiSurfaceWriteLease,
  UiSurfaceWriter,
  UserInputPayload,
  callStructuredHotelTool,
  hotelActionsFor,
  hotelBookingOpenAction,
  hotelDetailA2uiFromOffers,
  hotelFailureA2ui,
  hotelNavigationUri,
  hotelPendingA2ui,
  hotelSearchA2uiFromOffers,
  mergeA2uiLayout,
  parseA2uiJsonl,
  parseHotelDetailRequest,
  parseHotelSearchRequest,
  toolDefinitionForToolId,
  validateHotelActionArgs
} from '@loop/agent-core';
import { createHtmlHomeDocument } from '../html/HtmlHomeSnapshot';
import { isHtmlHomeActionAllowed } from '../html/HtmlHomeActionPolicy';
import { HtmlHomeAction, HtmlHomeDocument } from '../html/HtmlHomeTypes';
import {
  HotelActionIdFactory,
  HotelRegisteredActionExecutor,
  SystemUriOpener
} from './HotelRegisteredActionExecutor';
import {
  HotelLeaderPlanner,
  HotelLocalDateProvider,
  HotelPlannerIdFactory
} from './HotelLeaderPlanner';

const DEFAULT_SUBMIT_TIMEOUT_MS: number = 30000;
const DEFAULT_ACTION_TIMEOUT_MS: number = 15000;
const DEFAULT_LAYOUT_TIMEOUT_MS: number = 6000;
const MAX_DEADLINE_MS: number = 120000;
const SURFACE_HISTORY_LIMIT: number = 20;

type HotelValue = Object | string | number | boolean | null | undefined;

export type HotelSurfaceCallback = (surface: A2uiSurfaceState) => void;
export type HotelTurnStatus = 'success' | 'partial' | 'empty' | 'error' | 'canceled' | 'timeout';

export interface HotelTurnOutcome {
  ok: boolean;
  status: HotelTurnStatus;
  message: string;
  surfaceId: string;
}

export interface HotelAgentRuntimeOptions {
  model: LocalModel;
  currentLocalDate: HotelLocalDateProvider;
  opener: SystemUriOpener;
  dataExecutor?: DataTaskExecutor;
  writer?: UiSurfaceWriter;
  onSurface?: HotelSurfaceCallback;
  bus?: LinkedMessageBus;
  conversationId?: string;
  submitTimeoutMs?: number;
  actionTimeoutMs?: number;
  uiLayoutPlanner?: UiLayoutPlanner;
  uiLayoutTimeoutMs?: number;
}

export interface HotelActionContext {
  conversationId: string;
  turnId: string;
  surfaceId: string;
  sourceToolId: string;
}

interface HotelDataAssessment {
  ok: boolean;
  status: 'success' | 'partial' | 'empty' | 'error';
  message: string;
}

interface HotelTurnCorrelation {
  conversationId: string;
  turnId: string;
  inputTaskId: string;
  generation: number;
  uiTaskId: string;
  dataTaskId: string;
  expectedSchema: string;
  toolId: string;
  surfaceId: string;
  paired: boolean;
  uiCreated: boolean;
  dataCreated: boolean;
  dataAssessment: HotelDataAssessment | null;
}

interface PendingTurn extends HotelTurnCorrelation {
  resolve: (outcome: HotelTurnOutcome) => void;
  timerId: number;
}

interface PendingAction {
  conversationId: string;
  turnId: string;
  surfaceId: string;
  sourceToolId: string;
  taskId: string;
  runId: string;
  planId: string;
  actionId: string;
  stepId: string;
  expectedOutputUri: string;
  expectedOutputMessage: string;
  generation: number;
  expectedFollowUpUiTaskId: string;
  expectedFollowUpDataTaskId: string;
  followUpTurnId: string;
  followUpUiSeen: boolean;
  followUpDataSeen: boolean;
  followUpPromoted: boolean;
  directResultSeen: boolean;
  directResultSucceeded: boolean;
  followUpTerminalSeen: boolean;
  followUpTerminalSucceeded: boolean;
  resolve: (ok: boolean) => void;
  timerId: number;
}

interface HotelActionStatusRecord {
  actionId?: string;
  status?: string;
  message?: string;
  errorCode?: string;
}

interface HotelStatusSummary {
  text: string;
  toolName: string;
  dataLabel: string;
  count: number;
}

interface HotelCancelPayload {
  reason: string;
  runId?: string;
}

interface PreparedFollowUpIds {
  dataTaskId: string;
  uiTaskId: string;
}

interface HotelSurfaceRecord {
  turnId: string;
  surfaceId: string;
  store: A2uiSurfaceStore;
  sourceToolId: string;
  surface?: A2uiSurfaceState;
  document?: HtmlHomeDocument;
  lease?: UiSurfaceWriteLease;
  generation: number;
  revision: number;
  downstreamRevision: number;
  deliveredRevision: number;
}

interface HotelSearchSurfaceSnapshot {
  turnId: string;
  surfaceId: string;
  sourceToolId: string;
  surface: A2uiSurfaceState;
  lease: UiSurfaceWriteLease;
}

function boundedDeadline(value: number | undefined, fallback: number): number {
  if (value === undefined || !Number.isFinite(value) || value <= 0) {
    return fallback;
  }
  return Math.min(Math.floor(value), MAX_DEADLINE_MS);
}

function outcome(
  status: HotelTurnStatus,
  message: string,
  surfaceId: string = ''
): HotelTurnOutcome {
  return {
    ok: status === 'success' || status === 'partial' || status === 'empty',
    status: status,
    message: message,
    surfaceId: surfaceId
  };
}

function recordOf(value: HotelValue): Record<string, HotelValue> | null {
  if (value === null || value === undefined || typeof value !== 'object' || Array.isArray(value)) {
    return null;
  }
  return value as Record<string, HotelValue>;
}

function hasOnlyKeys(value: Object, expected: string): boolean {
  return Object.keys(value).sort().join(',') === expected;
}

function nonempty(value: HotelValue): boolean {
  return typeof value === 'string' && value.trim().length > 0;
}

function isStringArray(value: HotelValue): boolean {
  if (!Array.isArray(value)) {
    return false;
  }
  const values = value as HotelValue[];
  for (let index = 0; index < values.length; index++) {
    if (typeof values[index] !== 'string') {
      return false;
    }
  }
  return true;
}

function isActionOutputs(value: HotelValue): boolean {
  if (!Array.isArray(value)) {
    return false;
  }
  const outputs = value as HotelValue[];
  for (let index = 0; index < outputs.length; index++) {
    const entry = recordOf(outputs[index]);
    if (entry === null ||
      !hasOnlyKeys(entry, 'output,stepId') ||
      !nonempty(entry['stepId']) ||
      entry['output'] === undefined) {
      return false;
    }
    const output = entry['output'];
    if (output !== null &&
      typeof output !== 'object' &&
      typeof output !== 'string' &&
      typeof output !== 'number' &&
      typeof output !== 'boolean') {
      return false;
    }
    if (typeof output === 'number' && !Number.isFinite(output)) {
      return false;
    }
  }
  return true;
}

function isNumberArray(value: HotelValue): boolean {
  if (!Array.isArray(value)) {
    return false;
  }
  const values = value as HotelValue[];
  for (let index = 0; index < values.length; index++) {
    if (typeof values[index] !== 'number' || !Number.isFinite(values[index] as number)) {
      return false;
    }
  }
  return true;
}

function finiteNumber(value: HotelValue): boolean {
  return typeof value === 'number' && Number.isFinite(value);
}

function finiteNumberOrNull(value: HotelValue): boolean {
  return value === null || finiteNumber(value);
}

function validSearchRequest(value: HotelValue): boolean {
  const raw = recordOf(value);
  if (raw === null || typeof raw['checkOutDate'] !== 'string') {
    return false;
  }
  const parsed = parseHotelSearchRequest(raw);
  return parsed.ok && parsed.value !== null &&
    parsed.value.checkOutDate === raw['checkOutDate'];
}

function validDetailRequest(value: HotelValue): boolean {
  const raw = recordOf(value);
  if (raw === null) {
    return false;
  }
  const parsed = parseHotelDetailRequest(raw);
  return parsed.ok && parsed.value !== null;
}

function validHotelPrice(value: HotelValue): boolean {
  const price = recordOf(value);
  return price !== null &&
    typeof price['message'] === 'string' &&
    typeof price['hasPrice'] === 'boolean' &&
    typeof price['currency'] === 'string' &&
    finiteNumber(price['lowestPrice']);
}

function validSearchItem(value: HotelValue): boolean {
  const item = recordOf(value);
  if (item === null ||
    !finiteNumber(item['hotelId']) ||
    typeof item['bookingUrl'] !== 'string' ||
    typeof item['name'] !== 'string' ||
    typeof item['nameEn'] !== 'string' ||
    typeof item['brand'] !== 'string' ||
    typeof item['address'] !== 'string' ||
    typeof item['destinationId'] !== 'string' ||
    !finiteNumberOrNull(item['latitude']) ||
    !finiteNumberOrNull(item['longitude']) ||
    !finiteNumber(item['distanceInMeters']) ||
    !finiteNumber(item['starRating']) ||
    !validHotelPrice(item['price']) ||
    typeof item['areaCode'] !== 'string' ||
    typeof item['description'] !== 'string' ||
    typeof item['imageUrl'] !== 'string' ||
    !isStringArray(item['hotelAmenities']) ||
    !isStringArray(item['tags'])) {
    return false;
  }
  return true;
}

function validSearchResult(value: HotelValue): boolean {
  const result = recordOf(value);
  if (result === null ||
    result['ok'] !== true ||
    typeof result['error'] !== 'string' ||
    typeof result['message'] !== 'string' ||
    !validSearchRequest(result['query']) ||
    !Array.isArray(result['hotels'])) {
    return false;
  }
  const hotels = result['hotels'] as HotelValue[];
  for (let index = 0; index < hotels.length; index++) {
    if (!validSearchItem(hotels[index])) {
      return false;
    }
  }
  return true;
}

function validRatePlan(value: HotelValue): boolean {
  const rate = recordOf(value);
  return rate !== null &&
    typeof rate['roomName'] === 'string' &&
    typeof rate['roomNameCn'] === 'string' &&
    typeof rate['ratePlanId'] === 'string' &&
    typeof rate['ratePlanName'] === 'string' &&
    finiteNumberOrNull(rate['averagePrice']) &&
    typeof rate['bedTypeDescription'] === 'string' &&
    typeof rate['currency'] === 'string' &&
    finiteNumber(rate['mealAmount']) &&
    typeof rate['mealTypeStr'] === 'string' &&
    (rate['isOnRequest'] === null || typeof rate['isOnRequest'] === 'boolean') &&
    typeof rate['cancelPolicy'] === 'string';
}

function validDetailResult(value: HotelValue): boolean {
  const result = recordOf(value);
  if (result === null ||
    result['ok'] !== true ||
    typeof result['error'] !== 'string' ||
    typeof result['message'] !== 'string' ||
    !validDetailRequest(result['query']) ||
    !finiteNumber(result['hotelId']) ||
    typeof result['bookingUrl'] !== 'string' ||
    typeof result['name'] !== 'string' ||
    typeof result['nameEn'] !== 'string' ||
    typeof result['checkIn'] !== 'string' ||
    typeof result['checkOut'] !== 'string' ||
    !Array.isArray(result['rates'])) {
    return false;
  }
  const rates = result['rates'] as HotelValue[];
  for (let index = 0; index < rates.length; index++) {
    if (!validRatePlan(rates[index])) {
      return false;
    }
  }
  return true;
}

function validWarnings(value: HotelValue): boolean {
  return isStringArray(value);
}

function errorMessageOf(data: DataResult): string {
  const error = data.error;
  return error !== undefined && typeof error.message === 'string' &&
    error.message.trim().length > 0 ?
    error.message : '酒店供应商调用失败。';
}

function hotelDataAssessment(data: DataResult, expectedToolId: string): HotelDataAssessment {
  const raw = recordOf(data);
  if (raw === null ||
    data.toolId !== expectedToolId ||
    !validWarnings(data.warnings) ||
    (data.status !== 'success' && data.status !== 'partial' &&
      data.status !== 'empty' && data.status !== 'error')) {
    return { ok: false, status: 'error', message: '酒店数据格式无效。' };
  }
  if (data.status === 'error') {
    return { ok: false, status: 'error', message: errorMessageOf(data) };
  }
  let count = -1;
  let message = '';
  if (data.toolId === 'hotel.search' && validSearchResult(data.data)) {
    const result = data.data as HotelSearchResult;
    count = result.hotels.length;
    message = result.message;
  } else if (data.toolId === 'hotel.detail' && validDetailResult(data.data)) {
    const result = data.data as HotelDetailResult;
    count = result.rates.length;
    message = result.message;
  } else {
    return { ok: false, status: 'error', message: '酒店数据格式无效。' };
  }
  const warnings = data.warnings;
  if (data.status === 'empty' && count === 0 && warnings.length === 0) {
    return { ok: true, status: 'empty', message: message };
  }
  if (data.status === 'success' && count > 0 && warnings.length === 0) {
    return { ok: true, status: 'success', message: message };
  }
  if (data.status === 'partial' && count > 0 && warnings.length > 0) {
    return { ok: true, status: 'partial', message: warnings.join(' · ') };
  }
  return { ok: false, status: 'error', message: '酒店数据状态与内容不一致。' };
}

function uiTaskPayload(message: AgentMessage): CreateUiTaskPayload | null {
  const payload = recordOf(message.payload);
  if (payload === null ||
    !hasOnlyKeys(payload, 'dataTaskIds,expectedOutputSchema,intent,skillId,taskId') ||
    payload['taskId'] !== message.taskId ||
    !Array.isArray(payload['dataTaskIds']) || payload['dataTaskIds'].length !== 1 ||
    !nonempty(payload['dataTaskIds'][0]) || payload['dataTaskIds'][0] === message.taskId ||
    typeof payload['skillId'] !== 'string' ||
    !nonempty(payload['intent']) ||
    !nonempty(payload['expectedOutputSchema'])) {
    return null;
  }
  return message.payload as CreateUiTaskPayload;
}

function dataTaskPayload(message: AgentMessage): CreateDataTaskPayload | null {
  const payload = recordOf(message.payload);
  if (payload === null ||
    !hasOnlyKeys(payload, 'allowedToolIds,args,goal,outputSchema,required,roundId,skillId,taskId,toolId') ||
    payload['taskId'] !== message.taskId ||
    !nonempty(payload['roundId']) ||
    typeof payload['skillId'] !== 'string' ||
    !nonempty(payload['goal']) ||
    !Array.isArray(payload['allowedToolIds']) || payload['allowedToolIds'].length === 0 ||
    !nonempty(payload['toolId']) ||
    !nonempty(payload['outputSchema']) ||
    recordOf(payload['args']) === null ||
    typeof payload['required'] !== 'boolean') {
    return null;
  }
  return message.payload as CreateDataTaskPayload;
}

function uiResultPayload(message: AgentMessage): UiRenderResultPayload | null {
  const payload = recordOf(message.payload);
  if (payload === null ||
    !hasOnlyKeys(payload, 'state,surfaceId') ||
    !nonempty(payload['surfaceId']) ||
    (payload['state'] !== 'skeleton' && payload['state'] !== 'result' &&
      payload['state'] !== 'error' && payload['state'] !== 'action')) {
    return null;
  }
  return message.payload as UiRenderResultPayload;
}

function taskErrorPayload(message: AgentMessage): TaskErrorPayload | null {
  const payload = recordOf(message.payload);
  if (payload === null ||
    !nonempty(payload['code']) ||
    !nonempty(payload['message']) ||
    (payload['retryable'] !== undefined && typeof payload['retryable'] !== 'boolean')) {
    return null;
  }
  const keys = Object.keys(payload).sort().join(',');
  if (keys !== 'code,message' && keys !== 'code,message,retryable') {
    return null;
  }
  return message.payload as TaskErrorPayload;
}

function actionResultPayload(message: AgentMessage): ActionResultPayload | null {
  const payload = recordOf(message.payload);
  if (payload === null ||
    !nonempty(payload['surfaceId']) ||
    !nonempty(payload['planId']) ||
    !nonempty(payload['runId']) ||
    !isStringArray(payload['completedStepIds']) ||
    (payload['status'] !== 'success' && payload['status'] !== 'paused' &&
      payload['status'] !== 'canceled' && payload['status'] !== 'error')) {
    return null;
  }
  const status = payload['status'];
  const keys = Object.keys(payload).sort().join(',');
  if (status === 'success') {
    if (keys !== 'completedStepIds,outputs,planId,runId,status,surfaceId' ||
      !isActionOutputs(payload['outputs'])) {
      return null;
    }
  } else if (status === 'paused') {
    if (keys !==
      'completedStepIds,errorCode,message,outputs,planId,runId,status,stepId,surfaceId' ||
      !isActionOutputs(payload['outputs']) ||
      !nonempty(payload['stepId']) ||
      !nonempty(payload['errorCode']) ||
      !nonempty(payload['message'])) {
      return null;
    }
  } else if (status === 'canceled') {
    const canceledKeys = 'completedStepIds,errorCode,message,planId,runId,status,surfaceId';
    const canceledOutputKeys =
      'completedStepIds,errorCode,message,outputs,planId,runId,status,surfaceId';
    if ((keys !== canceledKeys && keys !== canceledOutputKeys) ||
      !nonempty(payload['errorCode']) ||
      !nonempty(payload['message']) ||
      (keys === canceledOutputKeys && !isActionOutputs(payload['outputs']))) {
      return null;
    }
  } else {
    const errorKeys = 'completedStepIds,errorCode,message,planId,runId,status,surfaceId';
    const errorStepKeys =
      'completedStepIds,errorCode,message,planId,runId,status,stepId,surfaceId';
    if ((keys !== errorKeys && keys !== errorStepKeys) ||
      !nonempty(payload['errorCode']) ||
      !nonempty(payload['message']) ||
      (keys === errorStepKeys && typeof payload['stepId'] !== 'string')) {
      return null;
    }
  }
  return message.payload as ActionResultPayload;
}

function expectedActionSuccess(
  pending: PendingAction,
  result: ActionResultPayload
): boolean {
  if (result.status !== 'success' ||
    result.completedStepIds.length !== 1 ||
    result.completedStepIds[0] !== pending.stepId ||
    result.outputs === undefined ||
    result.outputs.length !== 1) {
    return false;
  }
  const step = recordOf(result.outputs[0] as ActionPlanStepOutput);
  if (step === null ||
    !hasOnlyKeys(step, 'output,stepId') ||
    step['stepId'] !== pending.stepId) {
    return false;
  }
  const output = recordOf(step['output']);
  if (output === null || output['actionId'] !== pending.actionId) {
    return false;
  }
  if (pending.actionId === 'hotel.detail') {
    return hasOnlyKeys(output, 'actionId,status') &&
      output['status'] === 'follow_up_created';
  }
  return hasOnlyKeys(output, 'actionId,message,status,uri') &&
    output['status'] === 'opened' &&
    pending.expectedOutputUri.length > 0 &&
    output['uri'] === pending.expectedOutputUri &&
    output['message'] === pending.expectedOutputMessage;
}

function actionProgressPayload(message: AgentMessage): ActionProgressPayload | null {
  const payload = recordOf(message.payload);
  if (payload === null ||
    !hasOnlyKeys(payload, 'actionId,planId,runId,status,stepId,surfaceId') ||
    !nonempty(payload['surfaceId']) ||
    !nonempty(payload['planId']) ||
    !nonempty(payload['runId']) ||
    !nonempty(payload['stepId']) ||
    !nonempty(payload['actionId']) ||
    (payload['status'] !== 'running' && payload['status'] !== 'success')) {
    return null;
  }
  return message.payload as ActionProgressPayload;
}

function copyTurn(source: HotelTurnCorrelation, generation: number): HotelTurnCorrelation {
  return {
    conversationId: source.conversationId,
    turnId: source.turnId,
    inputTaskId: source.inputTaskId,
    generation: generation,
    uiTaskId: source.uiTaskId,
    dataTaskId: source.dataTaskId,
    expectedSchema: source.expectedSchema,
    toolId: source.toolId,
    surfaceId: source.surfaceId,
    paired: source.paired,
    uiCreated: source.uiCreated,
    dataCreated: source.dataCreated,
    dataAssessment: source.dataAssessment
  };
}

class MonotonicHotelIds implements HotelPlannerIdFactory, HotelActionIdFactory {
  private next: number = 0;

  nextId(prefix: string): string {
    this.next += 1;
    return prefix + '-' + this.next.toString();
  }
}

class PreparedHotelFollowUpIds implements HotelActionIdFactory {
  private readonly ids: MonotonicHotelIds;
  private preparedDataTaskId: string = '';
  private preparedUiTaskId: string = '';

  constructor(ids: MonotonicHotelIds) {
    this.ids = ids;
  }

  prepare(): PreparedFollowUpIds {
    this.clear();
    this.preparedDataTaskId = this.ids.nextId('hotel-detail-data');
    this.preparedUiTaskId = this.ids.nextId('hotel-detail-ui');
    return {
      dataTaskId: this.preparedDataTaskId,
      uiTaskId: this.preparedUiTaskId
    };
  }

  nextId(prefix: string): string {
    if (prefix === 'hotel-detail-data' && this.preparedDataTaskId.length > 0) {
      const value = this.preparedDataTaskId;
      this.preparedDataTaskId = '';
      return value;
    }
    if (prefix === 'hotel-detail-ui' && this.preparedUiTaskId.length > 0) {
      const value = this.preparedUiTaskId;
      this.preparedUiTaskId = '';
      return value;
    }
    return this.ids.nextId(prefix);
  }

  clear(): void {
    this.preparedDataTaskId = '';
    this.preparedUiTaskId = '';
  }
}

class CurrentHotelToolLookup implements ToolDefinitionLookup {
  find(toolId: string): ToolDefinition | null {
    return toolDefinitionForToolId(toolId);
  }
}

class RejectHotelClientAction implements ClientActionAuthorizer {
  allows(_actionId: string, _args: Object): boolean {
    return false;
  }
}

class CurrentHotelArgsValidator implements ActionArgsValidator {
  validate(actionId: string, args: Object): ActionValidationResult {
    return validateHotelActionArgs(actionId, args);
  }
}

class StructuredHotelDataExecutor implements DataTaskExecutor {
  async execute(task: CreateDataTaskPayload): Promise<DataResult> {
    return callStructuredHotelTool(task.toolId, task.args);
  }
}

function authorizeHotelDataTask(task: CreateDataTaskPayload): DataTaskAuthorizationResult {
  const definition = toolDefinitionForToolId(task.toolId);
  if (definition === null || definition.riskLevel !== 'read' ||
    definition.outputSchema !== task.outputSchema) {
    return {
      ok: false,
      code: 'DATA_TASK_UNAUTHORIZED',
      message: 'Hotel data task is not a registered read capability.'
    };
  }
  const dataBackends: Set<string> = new Set<string>([
    'local_adapter',
    'oauth_api',
    'imap',
    'workspace_mcp',
    'web_session',
    'mcp_remote'
  ]);
  for (let index = 0; index < definition.backendPriority.length; index++) {
    if (!dataBackends.has(definition.backendPriority[index])) {
      return {
        ok: false,
        code: 'DATA_TASK_BACKEND_FORBIDDEN',
        message: 'Hotel data task cannot execute a system action backend.'
      };
    }
  }
  const parsed = task.toolId === 'hotel.search' ?
    parseHotelSearchRequest(task.args) :
    task.toolId === 'hotel.detail' ? parseHotelDetailRequest(task.args) : null;
  if (parsed === null || !parsed.ok || parsed.value === null) {
    return {
      ok: false,
      code: 'DATA_TASK_ARGS_INVALID',
      message: 'Hotel data task arguments are invalid.'
    };
  }
  return { ok: true, code: '', message: '' };
}

function hotelLeaderPlanningContext(): LeaderPlanningContext {
  const definition = toolDefinitionForToolId('hotel.search');
  if (definition === null) {
    return { tools: [], personas: [] };
  }
  return {
    tools: [{
      toolId: definition.toolId,
      intent: definition.intent,
      riskLevel: definition.riskLevel,
      inputSchema: definition.inputSchema,
      outputSchema: definition.outputSchema,
      actions: definition.actions.slice()
    }],
    personas: []
  };
}

function actionOffer(action: A2uiAction, suffix: string): ActionOffer | null {
  if (action.args === undefined) {
    return null;
  }
  return {
    offerId: action.id + ':' + suffix,
    actionId: action.id,
    label: action.label,
    variant: action.variant,
    args: action.args
  };
}

async function resolveHotelActionOffers(
  catalog: ActionCatalog,
  data: DataResult,
  _context: ActionOfferContext
): Promise<ActionOffer[]> {
  const offers: ActionOffer[] = [];
  if (data.toolId === 'hotel.search' && validSearchResult(data.data)) {
    const result = data.data as HotelSearchResult;
    for (let hotelIndex = 0; hotelIndex < result.hotels.length; hotelIndex++) {
      const hotel = result.hotels[hotelIndex];
      const actions = hotelActionsFor(
        hotel,
        result.query,
        (candidate: A2uiAction): boolean => candidate.args !== undefined &&
          catalog.validatePlacement('hotel.search', candidate.id, candidate.args).ok
      );
      for (let actionIndex = 0; actionIndex < actions.length; actionIndex++) {
        const offer = actionOffer(actions[actionIndex], hotel.hotelId.toString());
        if (offer !== null) {
          offers.push(offer);
        }
      }
    }
    return offers;
  }
  if (data.toolId === 'hotel.detail' && validDetailResult(data.data)) {
    const result = data.data as HotelDetailResult;
    const booking = hotelBookingOpenAction(result);
    if (booking.args !== undefined &&
      catalog.validatePlacement('hotel.detail', booking.id, booking.args).ok) {
      const offer = actionOffer(booking, result.hotelId.toString());
      if (offer !== null) {
        offers.push(offer);
      }
    }
  }
  return offers;
}

function hotelOfferResolver(catalog: ActionCatalog): ActionOfferResolver {
  return async (data: DataResult, context: ActionOfferContext): Promise<ActionOffer[]> => {
    return resolveHotelActionOffers(catalog, data, context);
  };
}

class IgnoreHotelSurfaceWriter implements UiSurfaceWriter {
  async write(
    _turnId: string,
    _surfaceId: string,
    _jsonl: string,
    _lease: UiSurfaceWriteLease
  ): Promise<void> {
  }
}

class HotelSurfaceAuthority implements SurfaceActionAuthorizer {
  private conversationId: string = '';
  private turnId: string = '';
  private surfaceId: string = '';
  private sourceToolId: string = '';
  private readonly allowed: Set<string> = new Set<string>();

  activate(
    conversationId: string,
    turnId: string,
    surfaceId: string,
    sourceToolId: string,
    document: HtmlHomeDocument
  ): void {
    this.clear();
    this.conversationId = conversationId;
    this.turnId = turnId;
    this.surfaceId = surfaceId;
    this.sourceToolId = sourceToolId;
    this.collect(document, document.actions);
    document.blocks.forEach((block) => {
      this.collect(document, block.actions);
    });
  }

  clear(): void {
    this.conversationId = '';
    this.turnId = '';
    this.surfaceId = '';
    this.sourceToolId = '';
    this.allowed.clear();
  }

  allows(
    conversationId: string,
    turnId: string,
    surfaceId: string,
    actionId: string,
    args: Object
  ): boolean {
    return conversationId === this.conversationId &&
      turnId === this.turnId &&
      surfaceId === this.surfaceId &&
      this.allowed.has(this.actionKey(actionId, args));
  }

  context(): HotelActionContext | null {
    if (this.conversationId.length === 0 || this.turnId.length === 0 ||
      this.surfaceId.length === 0 || this.sourceToolId.length === 0) {
      return null;
    }
    return {
      conversationId: this.conversationId,
      turnId: this.turnId,
      surfaceId: this.surfaceId,
      sourceToolId: this.sourceToolId
    };
  }

  private collect(document: HtmlHomeDocument, actions: HtmlHomeAction[]): void {
    actions.forEach((candidate: HtmlHomeAction) => {
      if (candidate.id !== 'hotel.detail' &&
        candidate.id !== 'hotel.navigate' &&
        candidate.id !== 'hotel.booking.open') {
        return;
      }
      const action: A2uiAction = {
        id: candidate.id,
        label: candidate.label,
        prompt: candidate.prompt,
        variant: candidate.variant,
        kind: candidate.kind
      };
      if (candidate.args !== undefined) {
        action.args = candidate.args;
      }
      if (action.args !== undefined && isHtmlHomeActionAllowed(document, action)) {
        this.allowed.add(this.actionKey(action.id, action.args));
      }
    });
  }

  private actionKey(actionId: string, args: Object): string {
    return actionId + '\n' + JSON.stringify(args);
  }
}

class HotelUiRenderer implements SingleDataUiTaskRenderer {
  private readonly layoutPlanner: UiLayoutPlanner | null;
  private readonly layoutTimeoutMs: number;

  constructor(layoutPlanner: UiLayoutPlanner | null = null, layoutTimeoutMs: number = DEFAULT_LAYOUT_TIMEOUT_MS) {
    this.layoutPlanner = layoutPlanner;
    this.layoutTimeoutMs = boundedDeadline(layoutTimeoutMs, DEFAULT_LAYOUT_TIMEOUT_MS);
  }

  async skeleton(task: CreateUiTaskPayload, surfaceId: string): Promise<UiRenderResult> {
    const prompt = task.intent === 'hotel.detail' ?
      '正在等待 RollingGo 返回实时房型、价格与取消政策。' :
      '正在等待 RollingGo 返回真实酒店与报价。';
    return this.rendered(hotelPendingA2ui(surfaceId, prompt));
  }

  async result(
    task: CreateUiTaskPayload,
    data: DataResult,
    offers: ActionOffer[],
    surfaceId: string
  ): Promise<UiRenderResult> {
    const expectedToolId = task.intent === 'hotel.detail' ? 'hotel.detail' : 'hotel.search';
    const assessment = hotelDataAssessment(data, expectedToolId);
    if (!assessment.ok) {
      return this.rendered(hotelFailureA2ui(surfaceId, expectedToolId, assessment.message));
    }
    try {
      if (data.toolId === 'hotel.search') {
        const result = data.data as HotelSearchResult;
        const baseline = hotelSearchA2uiFromOffers(
          surfaceId,
          result,
          offers,
          data.warnings
        );
        return this.rendered(await this.layout(task, data, offers, surfaceId, baseline, result.hotels.length));
      }
      if (data.toolId === 'hotel.detail') {
        const result = data.data as HotelDetailResult;
        const baseline = hotelDetailA2uiFromOffers(
          surfaceId,
          result,
          offers,
          data.warnings
        );
        return this.rendered(await this.layout(task, data, offers, surfaceId, baseline, result.rates.length));
      }
    } catch (_error) {
      return this.rendered(
        hotelFailureA2ui(surfaceId, expectedToolId, '酒店数据格式无效。')
      );
    }
    return this.rendered(
      hotelFailureA2ui(surfaceId, expectedToolId, 'Unsupported hotel data result.')
    );
  }

  async error(
    task: CreateUiTaskPayload,
    message: string,
    surfaceId: string
  ): Promise<UiRenderResult> {
    return this.rendered(hotelFailureA2ui(surfaceId, task.intent, message));
  }

  async actionStatus(payload: Object, surfaceId: string): Promise<UiRenderResult> {
    const raw = recordOf(payload);
    const status: HotelActionStatusRecord = raw === null ? {} : payload as HotelActionStatusRecord;
    let text = '酒店操作状态已更新。';
    if (status.status === 'running') {
      text = '正在打开系统酒店操作。';
    } else if (status.status === 'success') {
      text = '系统酒店操作已打开。';
    } else if (status.status === 'error' || status.status === 'canceled') {
      text = status.message === undefined || status.message.length === 0 ?
        '系统酒店操作失败。' : status.message;
    }
    const summary: HotelStatusSummary = {
      text: text,
      toolName: status.actionId === undefined ? 'hotel.action' : status.actionId,
      dataLabel: 'actionStatus',
      count: 0
    };
    const envelope: A2uiEnvelope = {
      version: 'v0.9.1',
      updateDataModel: {
        surfaceId: surfaceId,
        path: '/summary',
        value: summary
      }
    };
    return this.rendered(JSON.stringify(envelope));
  }

  private rendered(jsonl: string): UiRenderResult {
    return { jsonl: jsonl };
  }

  private async layout(
    task: CreateUiTaskPayload,
    data: DataResult,
    offers: ActionOffer[],
    surfaceId: string,
    baseline: string,
    itemCount: number
  ): Promise<string> {
    if (this.layoutPlanner === null || itemCount <= 0 ||
      (data.status !== 'success' && data.status !== 'partial')) {
      return baseline;
    }
    const prompt = this.layoutPrompt(task, data, offers, itemCount);
    let timerId: number = -1;
    const timeout = new Promise<string | null>((resolve: (value: string | null) => void) => {
      timerId = setTimeout(() => resolve(null), this.layoutTimeoutMs);
    });
    try {
      const candidate = await Promise.race<string | null>([
        this.layoutPlanner.plan(prompt, surfaceId),
        timeout
      ]);
      return candidate === null ? baseline : mergeA2uiLayout(baseline, candidate, surfaceId, offers);
    } catch (_error) {
      return baseline;
    } finally {
      if (timerId >= 0) {
        clearTimeout(timerId);
      }
    }
  }

  private layoutPrompt(
    task: CreateUiTaskPayload,
    data: DataResult,
    offers: ActionOffer[],
    itemCount: number
  ): string {
    const offerIds: string[] = [];
    for (let index = 0; index < offers.length; index++) {
      offerIds.push(offers[index].offerId);
    }
    return 'Arrange the existing hotel result without inventing facts.\n' +
      'intent=' + task.intent + '\n' +
      'toolId=' + data.toolId + '\n' +
      'itemCount=' + itemCount.toString() + '\n' +
      'allowedDataPaths=/genericToolResults,/summary\n' +
      'offerIds=' + offerIds.join(',');
  }
}

class HotelVisibility {
  private turnId: string = '';
  private generation: number = 0;
  private surfaceId: string = '';

  expect(turnId: string, generation: number): void {
    this.turnId = turnId;
    this.generation = generation;
    this.surfaceId = '';
  }

  activate(turnId: string, generation: number): boolean {
    if (this.turnId !== turnId || this.generation !== generation) {
      return false;
    }
    return true;
  }

  restore(turnId: string, generation: number, surfaceId: string): void {
    this.turnId = turnId;
    this.generation = generation;
    this.surfaceId = surfaceId;
  }

  setSurface(turnId: string, generation: number, surfaceId: string): boolean {
    if (this.turnId !== turnId || this.generation !== generation) {
      return false;
    }
    this.surfaceId = surfaceId;
    return true;
  }

  matches(turnId: string, generation: number): boolean {
    return this.turnId === turnId && this.generation === generation;
  }

  currentSurfaceId(): string {
    return this.surfaceId;
  }

  currentTurnId(): string {
    return this.turnId;
  }

  generationFor(turnId: string): number {
    return this.turnId === turnId ? this.generation : 0;
  }

  clear(): void {
    this.turnId = '';
    this.generation = 0;
    this.surfaceId = '';
  }
}

class HotelRuntimeSurfaceWriter implements UiSurfaceWriter {
  private readonly conversationId: string;
  private readonly downstream: UiSurfaceWriter;
  private readonly callback: HotelSurfaceCallback | null;
  private readonly authority: HotelSurfaceAuthority;
  private readonly visibility: HotelVisibility;
  private readonly records: Map<string, HotelSurfaceRecord> =
    new Map<string, HotelSurfaceRecord>();
  private readonly recordOrder: string[] = [];
  private searchRecord: HotelSearchSurfaceSnapshot | null = null;
  private disposed: boolean = false;

  constructor(
    conversationId: string,
    downstream: UiSurfaceWriter,
    callback: HotelSurfaceCallback | null,
    authority: HotelSurfaceAuthority,
    visibility: HotelVisibility
  ) {
    this.conversationId = conversationId;
    this.downstream = downstream;
    this.callback = callback;
    this.authority = authority;
    this.visibility = visibility;
  }

  async write(
    turnId: string,
    surfaceId: string,
    jsonl: string,
    lease: UiSurfaceWriteLease
  ): Promise<void> {
    if (this.disposed) {
      return;
    }
    const parsed = parseA2uiJsonl(jsonl);
    if (parsed.error.length > 0) {
      throw new Error(parsed.error);
    }
    let record = this.records.get(surfaceId);
    if (record === undefined) {
      record = {
        turnId: turnId,
        surfaceId: surfaceId,
        store: new A2uiSurfaceStore(),
        sourceToolId: '',
        generation: this.visibility.generationFor(turnId),
        revision: 0,
        downstreamRevision: 0,
        deliveredRevision: 0
      };
      this.records.set(surfaceId, record);
      this.recordOrder.push(surfaceId);
      this.prune();
    } else if (record.turnId !== turnId) {
      throw new Error('Hotel surface identity changed turns.');
    }
    if (record.generation === 0) {
      record.generation = this.visibility.generationFor(turnId);
    }
    parsed.envelopes.forEach((envelope: A2uiEnvelope) => {
      const applied: A2uiApplyResult = (record as HotelSurfaceRecord).store.apply(envelope);
      if (!applied.ok) {
        throw new Error(applied.error);
      }
    });
    record.revision += 1;
    record.surface = record.store.getSurface();
    record.document = createHtmlHomeDocument({
      surface: record.surface,
      messages: [],
      isBusy: false,
      isAwaitingFirstSurface: false
    });
    const detected = this.sourceToolId(record.surface);
    if (detected === 'hotel.search' || detected === 'hotel.detail') {
      record.sourceToolId = detected;
    }
    const revision = record.revision;
    await this.downstream.write(turnId, surfaceId, jsonl, lease);
    if (this.disposed || !lease.isActive()) {
      return;
    }
    record.lease = lease;
    record.downstreamRevision = Math.max(record.downstreamRevision, revision);
    if (this.visibility.matches(turnId, record.generation)) {
      this.deliver(record);
    }
    this.prune();
  }

  activateTurn(turnId: string, generation: number): boolean {
    if (this.disposed || !this.visibility.activate(turnId, generation)) {
      return false;
    }
    let delivered = true;
    this.records.forEach((record: HotelSurfaceRecord) => {
      if (record.turnId !== turnId) {
        return;
      }
      record.generation = generation;
      if (record.downstreamRevision > record.deliveredRevision) {
        try {
          this.deliver(record);
        } catch (_error) {
          delivered = false;
        }
      }
    });
    return delivered;
  }

  markSearchReference(turnId: string): void {
    const surfaceId = this.visibility.currentSurfaceId();
    const record = this.records.get(surfaceId);
    if (record !== undefined && record.turnId === turnId &&
      record.sourceToolId === 'hotel.search' &&
      record.surface !== undefined &&
      record.document !== undefined &&
      record.lease !== undefined &&
      record.lease.isActive()) {
      const snapshotStore = new A2uiSurfaceStore();
      this.searchRecord = {
        turnId: record.turnId,
        surfaceId: record.surfaceId,
        sourceToolId: record.sourceToolId,
        surface: snapshotStore.seed(record.surface),
        lease: record.lease
      };
    }
    this.prune();
  }

  restoreSearchSurface(turnId: string, generation: number): boolean {
    const record = this.searchRecord;
    if (this.disposed || record === null || record.turnId !== turnId ||
      !record.lease.isActive()) {
      return false;
    }
    const snapshotStore = new A2uiSurfaceStore();
    const surface = snapshotStore.seed(record.surface);
    const document = createHtmlHomeDocument({
      surface: surface,
      messages: [],
      isBusy: false,
      isAwaitingFirstSurface: false
    });
    this.visibility.restore(record.turnId, generation, record.surfaceId);
    try {
      if (this.callback !== null) {
        this.callback(surface);
      }
      this.authority.activate(
        this.conversationId,
        record.turnId,
        record.surfaceId,
        record.sourceToolId,
        document
      );
      return true;
    } catch (_error) {
      this.visibility.clear();
      this.authority.clear();
      return false;
    }
  }

  activeSurfaceId(): string {
    return this.visibility.currentSurfaceId();
  }

  searchReturnSurface(): A2uiSurfaceState | null {
    if (this.searchRecord === null) {
      return null;
    }
    const snapshotStore = new A2uiSurfaceStore();
    return snapshotStore.seed(this.searchRecord.surface);
  }

  retainedSurfaceCount(): number {
    return this.records.size;
  }

  clearSearchReference(): void {
    this.searchRecord = null;
    this.prune();
  }

  pruneRetained(): void {
    this.prune();
  }

  dispose(): void {
    this.disposed = true;
    this.records.clear();
    this.recordOrder.splice(0, this.recordOrder.length);
    this.searchRecord = null;
  }

  private deliver(record: HotelSurfaceRecord): void {
    if (this.disposed ||
      record.surface === undefined ||
      record.document === undefined ||
      record.lease === undefined ||
      !record.lease.isActive() ||
      !this.visibility.matches(record.turnId, record.generation) ||
      record.downstreamRevision <= record.deliveredRevision) {
      return;
    }
    if (!this.visibility.setSurface(record.turnId, record.generation, record.surfaceId)) {
      return;
    }
    if (this.callback !== null) {
      this.callback(record.surface);
    }
    this.authority.activate(
      this.conversationId,
      record.turnId,
      record.surfaceId,
      record.sourceToolId,
      record.document
    );
    record.deliveredRevision = record.downstreamRevision;
  }

  private prune(): void {
    while (this.recordOrder.length > SURFACE_HISTORY_LIMIT) {
      let removed = false;
      for (let index = 0; index < this.recordOrder.length; index++) {
        const surfaceId = this.recordOrder[index];
        const record = this.records.get(surfaceId);
        if (record === undefined) {
          this.recordOrder.splice(index, 1);
          removed = true;
          break;
        }
        const protectedActive = surfaceId === this.visibility.currentSurfaceId();
        if (!protectedActive) {
          this.records.delete(surfaceId);
          this.recordOrder.splice(index, 1);
          removed = true;
          break;
        }
      }
      if (!removed) {
        return;
      }
    }
  }

  private sourceToolId(surface: A2uiSurfaceState): string {
    try {
      const model = JSON.parse(surface.dataModelJson) as A2uiRuntimeDataModel;
      if (model.summary.dataLabel === 'actionStatus') {
        return '';
      }
      return model.summary.toolName.indexOf('hotel.') === 0 ? model.summary.toolName : '';
    } catch (_error) {
      return '';
    }
  }
}

export class HotelAgentRuntime {
  private readonly bus: LinkedMessageBus;
  private readonly reader: AgentMessageReader;
  private readonly conversationId: string;
  private readonly ids: MonotonicHotelIds;
  private readonly followUpIds: PreparedHotelFollowUpIds;
  private readonly leader: LeaderAgent;
  private readonly data: DataAgent;
  private readonly ui: UiAgent;
  private readonly action: ActionAgent;
  private readonly catalog: ActionCatalog;
  private readonly authority: HotelSurfaceAuthority;
  private readonly visibility: HotelVisibility;
  private readonly surfaceWriter: HotelRuntimeSurfaceWriter;
  private readonly submitTimeoutMs: number;
  private readonly actionTimeoutMs: number;
  private readonly pendingTurns: Map<string, PendingTurn> = new Map<string, PendingTurn>();
  private readonly pendingActions: Map<string, PendingAction> = new Map<string, PendingAction>();
  private generation: number = 0;
  private activeTurn: HotelTurnCorrelation | null = null;
  private searchTurn: HotelTurnCorrelation | null = null;
  private active: boolean = true;

  constructor(options: HotelAgentRuntimeOptions) {
    this.bus = options.bus === undefined ? new LinkedMessageBus() : options.bus;
    this.ids = new MonotonicHotelIds();
    this.followUpIds = new PreparedHotelFollowUpIds(this.ids);
    this.conversationId = options.conversationId === undefined || options.conversationId.length === 0 ?
      'hotel-page-' + Date.now().toString() : options.conversationId;
    this.submitTimeoutMs = boundedDeadline(options.submitTimeoutMs, DEFAULT_SUBMIT_TIMEOUT_MS);
    this.actionTimeoutMs = boundedDeadline(options.actionTimeoutMs, DEFAULT_ACTION_TIMEOUT_MS);
    this.authority = new HotelSurfaceAuthority();
    this.visibility = new HotelVisibility();
    this.catalog = new ActionCatalog(
      new CurrentHotelToolLookup(),
      this.authority,
      new RejectHotelClientAction(),
      new CurrentHotelArgsValidator()
    );
    const downstream = options.writer === undefined ?
      new IgnoreHotelSurfaceWriter() : options.writer;
    this.surfaceWriter = new HotelRuntimeSurfaceWriter(
      this.conversationId,
      downstream,
      options.onSurface === undefined ? null : options.onSurface,
      this.authority,
      this.visibility
    );
    const planner = new HotelLeaderPlanner(options.model, options.currentLocalDate, this.ids);
    const executor = options.dataExecutor === undefined ?
      new StructuredHotelDataExecutor() : options.dataExecutor;
    const renderer = new HotelUiRenderer(
      options.uiLayoutPlanner === undefined ? null : options.uiLayoutPlanner,
      boundedDeadline(options.uiLayoutTimeoutMs, DEFAULT_LAYOUT_TIMEOUT_MS)
    );
    const registered = new HotelRegisteredActionExecutor(
      this.catalog,
      options.opener,
      this.followUpIds
    );
    this.leader = new LeaderAgent(this.bus, planner, hotelLeaderPlanningContext());
    this.data = new DataAgent(this.bus, authorizeHotelDataTask, executor);
    this.ui = new UiAgent(
      this.bus,
      new SingleDataUiTaskRendererAdapter(renderer),
      this.surfaceWriter
    );
    this.action = new ActionAgent(
      this.bus,
      this.catalog,
      hotelOfferResolver(this.catalog),
      registered
    );
    this.reader = this.bus.openReader();
    this.leader.start();
    this.data.start();
    this.ui.start();
    this.action.start();
    this.observe();
  }

  submit(prompt: string): Promise<HotelTurnOutcome> {
    const text = prompt.trim();
    if (!this.active || text.length === 0) {
      return Promise.resolve(outcome('canceled', '酒店运行时不可用。'));
    }
    this.cancelActiveTurn('superseded');
    this.generation += 1;
    const turnId = this.ids.nextId('hotel-turn');
    const taskId = this.ids.nextId('hotel-input');
    this.visibility.expect(turnId, this.generation);
    return new Promise<HotelTurnOutcome>((resolve: (value: HotelTurnOutcome) => void) => {
      const pending: PendingTurn = {
        conversationId: this.conversationId,
        turnId: turnId,
        inputTaskId: taskId,
        generation: this.generation,
        uiTaskId: '',
        dataTaskId: '',
        expectedSchema: '',
        toolId: 'hotel.search',
        surfaceId: '',
        paired: false,
        uiCreated: false,
        dataCreated: false,
        dataAssessment: null,
        resolve: resolve,
        timerId: -1
      };
      pending.timerId = setTimeout(() => {
        this.timeoutTurn(turnId, pending.generation);
      }, this.submitTimeoutMs);
      this.pendingTurns.set(turnId, pending);
      this.activeTurn = pending;
      const payload: UserInputPayload = { text: text };
      this.bus.publish({
        type: AgentMessageType.INPUT_USER,
        conversationId: this.conversationId,
        turnId: turnId,
        taskId: taskId,
        payload: payload
      });
    });
  }

  cancelActiveTurn(reason: string = 'canceled'): void {
    if (!this.active) {
      return;
    }
    const canceledTurnIds: string[] = [];
    const rememberTurn = (turnId: string): void => {
      if (turnId.length > 0 && canceledTurnIds.indexOf(turnId) < 0) {
        canceledTurnIds.push(turnId);
      }
    };
    if (this.activeTurn !== null) {
      rememberTurn(this.activeTurn.turnId);
    }
    if (this.searchTurn !== null) {
      rememberTurn(this.searchTurn.turnId);
    }
    this.pendingTurns.forEach((pending: PendingTurn) => {
      rememberTurn(pending.turnId);
    });
    this.pendingActions.forEach((pending: PendingAction) => {
      rememberTurn(pending.turnId);
      rememberTurn(pending.followUpTurnId);
    });
    this.pendingTurns.forEach((pending: PendingTurn) => {
      this.settleTurn(pending, outcome('canceled', '酒店查询已取消。'), false);
    });
    this.pendingActions.forEach((pending: PendingAction) => {
      this.settleAction(pending, false);
    });
    this.followUpIds.clear();
    this.activeTurn = null;
    this.searchTurn = null;
    this.surfaceWriter.clearSearchReference();
    this.visibility.clear();
    this.authority.clear();
    canceledTurnIds.forEach((turnId: string) => {
      this.cancelTurnMessage(turnId, reason);
    });
    this.surfaceWriter.pruneRetained();
  }

  currentActionContext(): HotelActionContext | null {
    return this.authority.context();
  }

  runAction(
    action: A2uiAction,
    suppliedContext?: HotelActionContext,
    suppliedDocument?: HtmlHomeDocument
  ): Promise<boolean> {
    if (!this.active || action.args === undefined || this.pendingActions.size > 0) {
      return Promise.resolve(false);
    }
    if (suppliedDocument !== undefined && !isHtmlHomeActionAllowed(suppliedDocument, action)) {
      return Promise.resolve(false);
    }
    const context = suppliedContext === undefined ? this.authority.context() : suppliedContext;
    const activeTurn = this.activeTurn;
    if (context === null || activeTurn === null ||
      context.conversationId !== this.conversationId ||
      context.turnId !== activeTurn.turnId ||
      context.surfaceId !== activeTurn.surfaceId) {
      return Promise.resolve(false);
    }
    const current = this.catalog.validateSurfaceExecution(
      context.conversationId,
      context.turnId,
      context.surfaceId,
      context.sourceToolId,
      action.id,
      action.args
    );
    if (!current.ok) {
      return Promise.resolve(false);
    }
    let expectedOutputUri = '';
    let expectedOutputMessage = '';
    if (action.id === 'hotel.navigate') {
      expectedOutputUri = hotelNavigationUri(action.args as HotelNavigateArgs);
      expectedOutputMessage = 'Petal Maps opened.';
    } else if (action.id === 'hotel.booking.open') {
      expectedOutputUri = (action.args as HotelBookingOpenArgs).bookingUrl;
      expectedOutputMessage = 'RollingGo booking opened in App.';
    }
    if ((action.id === 'hotel.navigate' || action.id === 'hotel.booking.open') &&
      expectedOutputUri.length === 0) {
      return Promise.resolve(false);
    }
    const runId = this.ids.nextId('hotel-action-run');
    const taskId = this.ids.nextId('hotel-action-task');
    const planId = 'direct:' + runId;
    let followUpUiTaskId = '';
    let followUpDataTaskId = '';
    if (action.id === 'hotel.detail') {
      const prepared = this.followUpIds.prepare();
      followUpUiTaskId = prepared.uiTaskId;
      followUpDataTaskId = prepared.dataTaskId;
    } else {
      this.followUpIds.clear();
    }
    const payload: ActionRunPayload = {
      surfaceId: context.surfaceId,
      runId: runId,
      sourceToolId: context.sourceToolId,
      actionId: action.id,
      args: action.args
    };
    return new Promise<boolean>((resolve: (ok: boolean) => void) => {
      const pending: PendingAction = {
        conversationId: context.conversationId,
        turnId: context.turnId,
        surfaceId: context.surfaceId,
        sourceToolId: context.sourceToolId,
        taskId: taskId,
        runId: runId,
        planId: planId,
        actionId: action.id,
        stepId: 'step-1',
        expectedOutputUri: expectedOutputUri,
        expectedOutputMessage: expectedOutputMessage,
        generation: activeTurn.generation,
        expectedFollowUpUiTaskId: followUpUiTaskId,
        expectedFollowUpDataTaskId: followUpDataTaskId,
        followUpTurnId: '',
        followUpUiSeen: false,
        followUpDataSeen: false,
        followUpPromoted: false,
        directResultSeen: false,
        directResultSucceeded: false,
        followUpTerminalSeen: false,
        followUpTerminalSucceeded: false,
        resolve: resolve,
        timerId: -1
      };
      pending.timerId = setTimeout(() => {
        this.timeoutAction(taskId, runId);
      }, this.actionTimeoutMs);
      this.pendingActions.set(taskId, pending);
      this.bus.publish({
        type: AgentMessageType.ACTION_RUN,
        conversationId: context.conversationId,
        turnId: context.turnId,
        taskId: taskId,
        payload: payload
      });
    });
  }

  restoreSearchSurface(): boolean {
    if (!this.active || this.searchTurn === null || this.pendingActions.size > 0) {
      return false;
    }
    const abandonedTurnId = this.activeTurn === null ||
      this.activeTurn.turnId === this.searchTurn.turnId ?
      '' : this.activeTurn.turnId;
    if (abandonedTurnId.length > 0) {
      this.cancelTurnMessage(abandonedTurnId, 'restore_search');
    }
    this.generation += 1;
    const restored = copyTurn(this.searchTurn, this.generation);
    if (!this.surfaceWriter.restoreSearchSurface(restored.turnId, restored.generation)) {
      if (abandonedTurnId.length > 0) {
        this.activeTurn = null;
      }
      return false;
    }
    restored.surfaceId = this.surfaceWriter.activeSurfaceId();
    this.activeTurn = restored;
    this.searchTurn = copyTurn(restored, restored.generation);
    return true;
  }

  searchReturnSurface(): A2uiSurfaceState | null {
    return this.surfaceWriter.searchReturnSurface();
  }

  retainedSurfaceCount(): number {
    return this.surfaceWriter.retainedSurfaceCount();
  }

  stop(): void {
    this.dispose();
  }

  dispose(): void {
    if (!this.active) {
      return;
    }
    this.cancelActiveTurn('disposed');
    this.active = false;
    this.reader.close();
    this.leader.stop();
    this.data.stop();
    this.ui.stop();
    this.action.stop();
    this.pendingTurns.forEach((pending: PendingTurn) => {
      if (pending.timerId >= 0) {
        clearTimeout(pending.timerId);
      }
      pending.resolve(outcome('canceled', '酒店运行时已释放。'));
    });
    this.pendingActions.forEach((pending: PendingAction) => {
      if (pending.timerId >= 0) {
        clearTimeout(pending.timerId);
      }
      pending.resolve(false);
    });
    this.pendingTurns.clear();
    this.pendingActions.clear();
    this.followUpIds.clear();
    this.activeTurn = null;
    this.searchTurn = null;
    this.visibility.clear();
    this.authority.clear();
    this.surfaceWriter.dispose();
  }

  private async observe(): Promise<void> {
    while (this.active) {
      let message: AgentMessage | null = null;
      try {
        message = await this.reader.receive();
      } catch (_error) {
        this.failPending('酒店消息观察器失败。');
        return;
      }
      if (message === null || !this.active) {
        return;
      }
      try {
        this.observeMessage(message);
      } catch (_error) {
        this.failPending('酒店消息关联失败。');
      }
    }
  }

  private observeMessage(message: AgentMessage): void {
    if (message.conversationId !== this.conversationId) {
      return;
    }
    if (message.type === AgentMessageType.TASK_CREATE_UI) {
      this.observeUiTask(message);
      return;
    }
    if (message.type === AgentMessageType.TASK_CREATE_DATA) {
      this.observeDataTask(message);
      return;
    }
    if (message.type === AgentMessageType.TASK_RESULT_DATA) {
      this.observeDataResult(message);
      return;
    }
    if (message.type === AgentMessageType.TASK_RESULT_UI) {
      this.observeUiResult(message);
      return;
    }
    if (message.type === AgentMessageType.TASK_ERROR) {
      this.observeTaskError(message);
      return;
    }
    if (message.type === AgentMessageType.ACTION_PROGRESS) {
      this.observeActionProgress(message);
      return;
    }
    if (message.type === AgentMessageType.ACTION_RESULT) {
      this.observeActionResult(message);
    }
  }

  private observeUiTask(message: AgentMessage): void {
    const task = uiTaskPayload(message);
    if (task === null) {
      return;
    }
    const pending = this.pendingTurns.get(message.turnId);
    if (pending !== undefined && pending.uiTaskId.length === 0 &&
      task.intent === 'hotel.search' &&
      task.expectedOutputSchema === 'hotelSearchResults') {
      pending.uiTaskId = message.taskId;
      pending.dataTaskId = task.dataTaskIds[0];
      pending.expectedSchema = task.expectedOutputSchema;
      pending.uiCreated = true;
      this.tryPairTurn(pending);
      return;
    }
    this.pendingActions.forEach((action: PendingAction) => {
      if (action.actionId !== 'hotel.detail' ||
        action.expectedFollowUpUiTaskId !== message.taskId ||
        task.taskId !== action.expectedFollowUpUiTaskId ||
        task.dataTaskIds[0] !== action.expectedFollowUpDataTaskId ||
        task.intent !== 'hotel.detail' ||
        task.expectedOutputSchema !== 'hotelRatePlans' ||
        message.turnId === action.turnId ||
        (action.followUpTurnId.length > 0 && action.followUpTurnId !== message.turnId)) {
        return;
      }
      action.followUpTurnId = message.turnId;
      action.followUpUiSeen = true;
      this.tryPromoteFollowUp(action);
    });
  }

  private observeDataTask(message: AgentMessage): void {
    const task = dataTaskPayload(message);
    if (task === null) {
      return;
    }
    const pending = this.pendingTurns.get(message.turnId);
    if (pending !== undefined &&
      task.toolId === 'hotel.search' &&
      task.outputSchema === 'hotelSearchResults' &&
      validSearchRequest(task.args)) {
      if (pending.dataTaskId.length === 0 || pending.dataTaskId === message.taskId) {
        pending.dataTaskId = message.taskId;
        pending.toolId = task.toolId;
        pending.expectedSchema = task.outputSchema;
        pending.dataCreated = true;
        this.tryPairTurn(pending);
      }
      return;
    }
    this.pendingActions.forEach((action: PendingAction) => {
      if (action.actionId !== 'hotel.detail' ||
        action.expectedFollowUpDataTaskId !== message.taskId ||
        task.taskId !== action.expectedFollowUpDataTaskId ||
        task.toolId !== 'hotel.detail' ||
        task.outputSchema !== 'hotelRatePlans' ||
        !validDetailRequest(task.args) ||
        message.turnId === action.turnId ||
        (action.followUpTurnId.length > 0 && action.followUpTurnId !== message.turnId)) {
        return;
      }
      action.followUpTurnId = message.turnId;
      action.followUpDataSeen = true;
      this.tryPromoteFollowUp(action);
    });
  }

  private tryPairTurn(pending: PendingTurn): void {
    if (pending.paired ||
      pending.uiTaskId.length === 0 ||
      pending.dataTaskId.length === 0 ||
      !pending.uiCreated ||
      !pending.dataCreated ||
      pending.uiTaskId === pending.dataTaskId ||
      pending.expectedSchema !== 'hotelSearchResults') {
      return;
    }
    pending.paired = true;
    this.activeTurn = pending;
    if (!this.surfaceWriter.activateTurn(pending.turnId, pending.generation)) {
      this.settleTurn(
        pending,
        outcome('error', '酒店页面回调失败。'),
        true
      );
    }
  }

  private tryPromoteFollowUp(action: PendingAction): void {
    if (action.followUpPromoted ||
      !action.followUpUiSeen ||
      !action.followUpDataSeen ||
      action.followUpTurnId.length === 0) {
      return;
    }
    this.generation += 1;
    const turn: HotelTurnCorrelation = {
      conversationId: action.conversationId,
      turnId: action.followUpTurnId,
      inputTaskId: action.taskId,
      generation: this.generation,
      uiTaskId: action.expectedFollowUpUiTaskId,
      dataTaskId: action.expectedFollowUpDataTaskId,
      expectedSchema: 'hotelRatePlans',
      toolId: 'hotel.detail',
      surfaceId: '',
      paired: true,
      uiCreated: true,
      dataCreated: true,
      dataAssessment: null
    };
    this.authority.clear();
    this.visibility.expect(turn.turnId, turn.generation);
    this.activeTurn = turn;
    action.followUpPromoted = this.surfaceWriter.activateTurn(turn.turnId, turn.generation);
    if (!action.followUpPromoted) {
      action.followUpTerminalSeen = true;
      action.followUpTerminalSucceeded = false;
      this.trySettleDetailAction(action);
    }
  }

  private observeDataResult(message: AgentMessage): void {
    const turn = this.turnForMessage(message);
    if (turn === null || !turn.paired || message.taskId !== turn.dataTaskId) {
      return;
    }
    const raw = recordOf(message.payload);
    if (raw === null ||
      typeof raw['toolId'] !== 'string' ||
      typeof raw['outputSchema'] !== 'string' ||
      raw['outputSchema'] !== turn.expectedSchema ||
      raw['toolId'] !== turn.toolId) {
      turn.dataAssessment = {
        ok: false,
        status: 'error',
        message: '酒店数据格式无效。'
      };
      return;
    }
    turn.dataAssessment = hotelDataAssessment(message.payload as DataResult, turn.toolId);
  }

  private observeUiResult(message: AgentMessage): void {
    const turn = this.turnForMessage(message);
    const result = uiResultPayload(message);
    if (turn === null || result === null || !turn.paired ||
      message.taskId !== turn.uiTaskId ||
      result.surfaceId !== this.surfaceWriter.activeSurfaceId()) {
      return;
    }
    if (result.state === 'skeleton') {
      turn.surfaceId = result.surfaceId;
      return;
    }
    if (result.state !== 'result' && result.state !== 'error') {
      return;
    }
    turn.surfaceId = result.surfaceId;
    if (turn.toolId === 'hotel.detail') {
      const action = this.actionForFollowUp(turn.turnId);
      if (action === null || message.taskId !== action.expectedFollowUpUiTaskId) {
        return;
      }
      const assessment = turn.dataAssessment;
      action.followUpTerminalSeen = true;
      action.followUpTerminalSucceeded =
        result.state === 'result' &&
        assessment !== null &&
        assessment.ok;
      this.trySettleDetailAction(action);
      return;
    }
    const pending = this.pendingTurns.get(turn.turnId);
    if (pending === undefined) {
      return;
    }
    if (result.state === 'error') {
      this.settleTurn(
        pending,
        outcome('error', '酒店界面渲染失败。', result.surfaceId),
        false
      );
      return;
    }
    const assessment = pending.dataAssessment;
    if (assessment === null || !assessment.ok) {
      this.settleTurn(
        pending,
        outcome(
          'error',
          assessment === null ? '酒店数据结果缺失。' : assessment.message,
          result.surfaceId
        ),
        false
      );
      return;
    }
    this.surfaceWriter.markSearchReference(pending.turnId);
    this.searchTurn = copyTurn(pending, pending.generation);
    this.settleTurn(
      pending,
      outcome(assessment.status, assessment.message, result.surfaceId),
      false
    );
  }

  private observeTaskError(message: AgentMessage): void {
    const error = taskErrorPayload(message);
    if (error === null) {
      return;
    }
    const pending = this.pendingTurns.get(message.turnId);
    if (pending !== undefined &&
      (message.taskId === pending.inputTaskId ||
        message.taskId === pending.uiTaskId ||
        message.taskId === pending.dataTaskId)) {
      this.settleTurn(
        pending,
        outcome('error', error.message, pending.surfaceId),
        true
      );
      return;
    }
    const action = this.actionForFollowUp(message.turnId);
    if (action !== null &&
      message.taskId === action.expectedFollowUpUiTaskId) {
      action.followUpTerminalSeen = true;
      action.followUpTerminalSucceeded = false;
      this.trySettleDetailAction(action);
    }
  }

  private observeActionProgress(message: AgentMessage): void {
    const pending = this.pendingActions.get(message.taskId);
    const progress = actionProgressPayload(message);
    if (pending === undefined || progress === null ||
      !this.matchesActionMessage(pending, message, progress.surfaceId, progress.planId, progress.runId)) {
      return;
    }
  }

  private observeActionResult(message: AgentMessage): void {
    const pending = this.pendingActions.get(message.taskId);
    const result = actionResultPayload(message);
    if (pending === undefined || result === null ||
      !this.matchesActionMessage(pending, message, result.surfaceId, result.planId, result.runId)) {
      return;
    }
    if (result.status === 'success' && !expectedActionSuccess(pending, result)) {
      return;
    }
    if (pending.actionId !== 'hotel.detail') {
      this.settleAction(pending, result.status === 'success');
      return;
    }
    pending.directResultSeen = true;
    pending.directResultSucceeded = result.status === 'success';
    if (!pending.followUpPromoted && result.status !== 'success') {
      this.settleAction(pending, false);
      return;
    }
    this.trySettleDetailAction(pending);
  }

  private actionForFollowUp(turnId: string): PendingAction | null {
    let found: PendingAction | null = null;
    this.pendingActions.forEach((pending: PendingAction) => {
      if (found === null &&
        pending.actionId === 'hotel.detail' &&
        pending.followUpPromoted &&
        pending.followUpTurnId === turnId) {
        found = pending;
      }
    });
    return found;
  }

  private trySettleDetailAction(pending: PendingAction): void {
    if (this.pendingActions.get(pending.taskId) !== pending ||
      !pending.followUpTerminalSeen ||
      !pending.directResultSeen) {
      return;
    }
    this.settleAction(
      pending,
      pending.followUpTerminalSucceeded && pending.directResultSucceeded
    );
  }

  private matchesActionMessage(
    pending: PendingAction,
    message: AgentMessage,
    surfaceId: string,
    planId: string,
    runId: string
  ): boolean {
    return message.conversationId === pending.conversationId &&
      message.turnId === pending.turnId &&
      message.taskId === pending.taskId &&
      surfaceId === pending.surfaceId &&
      planId === pending.planId &&
      runId === pending.runId;
  }

  private turnForMessage(message: AgentMessage): HotelTurnCorrelation | null {
    const pending = this.pendingTurns.get(message.turnId);
    if (pending !== undefined) {
      return pending;
    }
    const active = this.activeTurn;
    return active !== null && active.turnId === message.turnId ? active : null;
  }

  private settleTurn(
    pending: PendingTurn,
    result: HotelTurnOutcome,
    cancel: boolean
  ): void {
    if (this.pendingTurns.get(pending.turnId) !== pending) {
      return;
    }
    this.pendingTurns.delete(pending.turnId);
    if (pending.timerId >= 0) {
      clearTimeout(pending.timerId);
      pending.timerId = -1;
    }
    if (cancel) {
      this.cancelTurnMessage(pending.turnId, 'failed');
      if (this.activeTurn !== null && this.activeTurn.turnId === pending.turnId) {
        this.activeTurn = null;
        this.visibility.clear();
        this.authority.clear();
      }
      this.surfaceWriter.pruneRetained();
    }
    pending.resolve(result);
  }

  private settleAction(pending: PendingAction, ok: boolean): void {
    if (this.pendingActions.get(pending.taskId) !== pending) {
      return;
    }
    this.pendingActions.delete(pending.taskId);
    if (pending.timerId >= 0) {
      clearTimeout(pending.timerId);
      pending.timerId = -1;
    }
    this.followUpIds.clear();
    pending.resolve(ok);
  }

  private timeoutTurn(turnId: string, generation: number): void {
    const pending = this.pendingTurns.get(turnId);
    if (pending === undefined || pending.generation !== generation) {
      return;
    }
    this.settleTurn(
      pending,
      outcome('timeout', '酒店查询超时。', pending.surfaceId),
      true
    );
  }

  private timeoutAction(taskId: string, runId: string): void {
    const pending = this.pendingActions.get(taskId);
    if (pending === undefined || pending.runId !== runId) {
      return;
    }
    this.settleAction(pending, false);
    const hasPromotedDetail = pending.actionId === 'hotel.detail' &&
      pending.followUpTurnId.length > 0 &&
      pending.followUpTurnId !== pending.turnId;
    if (!hasPromotedDetail) {
      this.cancelTurnMessage(pending.turnId, 'action_timeout', pending.runId);
    }
    if (hasPromotedDetail) {
      this.cancelTurnMessage(
        pending.followUpTurnId,
        'action_timeout',
        pending.runId
      );
    }
    const active = this.activeTurn;
    if (active !== null &&
      (active.turnId === pending.turnId || active.turnId === pending.followUpTurnId)) {
      this.activeTurn = null;
      this.visibility.clear();
      this.authority.clear();
    }
    this.surfaceWriter.pruneRetained();
  }

  private cancelTurnMessage(turnId: string, reason: string, runId: string = ''): void {
    if (!this.active || turnId.length === 0) {
      return;
    }
    const payload: HotelCancelPayload = { reason: reason };
    if (runId.length > 0) {
      payload.runId = runId;
    }
    this.bus.publish({
      type: AgentMessageType.TURN_CANCEL,
      conversationId: this.conversationId,
      turnId: turnId,
      taskId: this.ids.nextId('hotel-cancel'),
      payload: payload
    });
  }

  private failPending(message: string): void {
    this.pendingTurns.forEach((pending: PendingTurn) => {
      this.settleTurn(pending, outcome('error', message, pending.surfaceId), true);
    });
    this.pendingActions.forEach((pending: PendingAction) => {
      this.settleAction(pending, false);
    });
  }
}
