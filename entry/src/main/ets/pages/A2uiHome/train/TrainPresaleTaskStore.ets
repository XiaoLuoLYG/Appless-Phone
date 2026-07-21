import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const STORE_NAME: string = 'aiphone_train_presale_tasks';
const STORE_KEY: string = 'tasks';

export type TrainPresaleTaskState =
  'scheduled' | 'executing' | 'awaiting_payment' | 'needs_user' | 'cancelled';

export interface TrainPresaleTask {
  taskId: string;
  source: 'presale' | 'debug';
  state: TrainPresaleTaskState;
  trainCode: string;
  travelDate: string;
  fromName: string;
  fromCode: string;
  toName: string;
  toCode: string;
  saleAt: string;
  passengerNames: string[];
  seatPriority: string;
  bookingUrl: string;
  reminderId: number;
  createdAt: string;
  lastError: string;
}

export interface ClaimDueTrainPresaleTaskResult {
  tasks: TrainPresaleTask[];
  task: TrainPresaleTask | undefined;
}

function text(value: string | number | boolean | preferences.ValueType | undefined): string {
  return typeof value === 'string' ? value : '';
}

function isState(value: TrainPresaleTaskState): boolean {
  return value === 'scheduled' || value === 'executing' || value === 'awaiting_payment' ||
    value === 'needs_user' || value === 'cancelled';
}

function isTask(value: TrainPresaleTask): boolean {
  return typeof value.taskId === 'string' &&
    (value.source === 'presale' || value.source === 'debug') &&
    isState(value.state) &&
    typeof value.trainCode === 'string' &&
    typeof value.travelDate === 'string' &&
    typeof value.fromName === 'string' &&
    typeof value.fromCode === 'string' &&
    typeof value.toName === 'string' &&
    typeof value.toCode === 'string' &&
    typeof value.saleAt === 'string' &&
    Array.isArray(value.passengerNames) &&
    typeof value.seatPriority === 'string' &&
    typeof value.bookingUrl === 'string' &&
    typeof value.reminderId === 'number' &&
    typeof value.createdAt === 'string' &&
    typeof value.lastError === 'string';
}

function copyTask(value: TrainPresaleTask): TrainPresaleTask {
  return {
    taskId: value.taskId,
    source: value.source,
    state: value.state,
    trainCode: value.trainCode,
    travelDate: value.travelDate,
    fromName: value.fromName,
    fromCode: value.fromCode,
    toName: value.toName,
    toCode: value.toCode,
    saleAt: value.saleAt,
    passengerNames: value.passengerNames.slice(),
    seatPriority: value.seatPriority,
    bookingUrl: value.bookingUrl,
    reminderId: value.reminderId,
    createdAt: value.createdAt,
    lastError: value.lastError
  };
}

function canTransition(from: TrainPresaleTaskState, to: TrainPresaleTaskState): boolean {
  return from === to ||
    (from === 'scheduled' && (to === 'executing' || to === 'cancelled')) ||
    (from === 'executing' && (to === 'awaiting_payment' || to === 'needs_user'));
}

export function serializeTrainPresaleTaskList(tasks: TrainPresaleTask[]): string {
  const safeTasks: TrainPresaleTask[] = [];
  for (let index = 0; index < tasks.length; index++) {
    if (isTask(tasks[index])) {
      safeTasks.push(copyTask(tasks[index]));
    }
  }
  return JSON.stringify(safeTasks);
}

export function parseTrainPresaleTaskList(raw: string): TrainPresaleTask[] {
  try {
    const parsed = JSON.parse(raw) as TrainPresaleTask[];
    if (!Array.isArray(parsed)) {
      return [];
    }
    const tasks: TrainPresaleTask[] = [];
    for (let index = 0; index < parsed.length; index++) {
      if (isTask(parsed[index])) {
        tasks.push(copyTask(parsed[index]));
      }
    }
    return tasks;
  } catch (_error) {
    return [];
  }
}

export function updateTrainPresaleTask(task: TrainPresaleTask, patch: Partial<TrainPresaleTask>): TrainPresaleTask {
  const updated = copyTask(task);
  if (patch.state !== undefined && canTransition(task.state, patch.state)) {
    updated.state = patch.state;
  }
  if (patch.reminderId !== undefined) {
    updated.reminderId = patch.reminderId;
  }
  if (patch.lastError !== undefined) {
    updated.lastError = patch.lastError;
  }
  return updated;
}

export function claimDueTrainPresaleTask(
  tasks: TrainPresaleTask[],
  nowIso: string,
  taskId?: string
): ClaimDueTrainPresaleTaskResult {
  const updated = tasks.map((task: TrainPresaleTask): TrainPresaleTask => copyTask(task));
  const now = new Date(nowIso).getTime();
  if (isNaN(now)) {
    return { tasks: updated, task: undefined };
  }
  for (let index = 0; index < updated.length; index++) {
    const task = updated[index];
    const saleAt = new Date(task.saleAt).getTime();
    if ((taskId === undefined || task.taskId === taskId) && task.state === 'scheduled' && !isNaN(saleAt) && saleAt <= now) {
      task.state = 'executing';
      return { tasks: updated, task: copyTask(task) };
    }
  }
  return { tasks: updated, task: undefined };
}

export class TrainPresaleTaskStore {
  private context: common.Context;

  constructor(context: common.Context) {
    this.context = context;
  }

  private preferences(): preferences.Preferences {
    return preferences.getPreferencesSync(this.context, { name: STORE_NAME });
  }

  private tasks(): TrainPresaleTask[] {
    return parseTrainPresaleTaskList(text(this.preferences().getSync(STORE_KEY, '')));
  }

  private save(tasks: TrainPresaleTask[]): void {
    const store = this.preferences();
    store.putSync(STORE_KEY, serializeTrainPresaleTaskList(tasks));
    store.flushSync();
  }

  create(task: TrainPresaleTask): void {
    const tasks = this.tasks();
    for (let index = 0; index < tasks.length; index++) {
      if (tasks[index].taskId === task.taskId) {
        return;
      }
    }
    tasks.push(copyTask(task));
    this.save(tasks);
  }

  get(taskId: string): TrainPresaleTask | undefined {
    const tasks = this.tasks();
    for (let index = 0; index < tasks.length; index++) {
      if (tasks[index].taskId === taskId) {
        return copyTask(tasks[index]);
      }
    }
    return undefined;
  }

  list(): TrainPresaleTask[] {
    return this.tasks();
  }

  update(taskId: string, patch: Partial<TrainPresaleTask>): void {
    const tasks = this.tasks();
    for (let index = 0; index < tasks.length; index++) {
      if (tasks[index].taskId === taskId) {
        tasks[index] = updateTrainPresaleTask(tasks[index], patch);
        this.save(tasks);
        return;
      }
    }
  }

  cancel(taskId: string): void {
    this.update(taskId, { state: 'cancelled' });
  }

  claimDue(nowIso: string, taskId?: string): TrainPresaleTask | undefined {
    const result = claimDueTrainPresaleTask(this.tasks(), nowIso, taskId);
    if (result.task !== undefined) {
      this.save(result.tasks);
    }
    return result.task;
  }
}
