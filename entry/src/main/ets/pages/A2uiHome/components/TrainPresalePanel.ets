import { build12306BookingUrl, extractExactTrainCode } from '@loop/agent-core';
import {
  COLOR_ACCENT,
  COLOR_ACCENT_SOFT,
  COLOR_CARD,
  COLOR_CARD_EDGE,
  COLOR_ERROR,
  COLOR_ERROR_LINE,
  COLOR_ERROR_SOFT,
  COLOR_FIELD,
  COLOR_INK,
  COLOR_MUTED,
  COLOR_SUCCESS,
  COLOR_SUCCESS_SOFT,
  COLOR_TEXT
} from '../style/A2uiHomeTheme';
import { A2UI_HOME_FLOATING_RADIUS } from '../style/A2uiHomeLayout';
import { TrainPresaleTask } from '../train/TrainPresaleTaskStore';
import { TrainPresaleTaskStore } from '../train/TrainPresaleTaskStore';
import { SystemOneShotScheduler } from '../train/SystemOneShotScheduler';
import { A2uiButtonView } from './common/A2uiButtonView';

export const TRAIN_PRESALE_SEAT_PREFERENCES: string[] = ['二等座', '一等座', '商务座', '无座'];

export interface TrainPresaleTrip {
  trainCode: string;
  travelDate: string;
  fromName: string;
  fromCode: string;
  toName: string;
  toCode: string;
  saleAt: string;
}

export interface TrainPresalePanelSubmission {
  source: 'presale' | 'debug';
  passengerNames: string[];
  seatPriority: string;
  unpaidOrderAuthorized: boolean;
  debugConfirmed: boolean;
}

export interface TrainPresaleConfirmationInput extends TrainPresaleTrip, TrainPresalePanelSubmission {
  debugEnabled: boolean;
  taskId: string;
  createdAt: string;
}

export interface TrainPresaleConfirmationResult {
  error: string;
  task: TrainPresaleTask | undefined;
}

export interface TrainPresaleScheduleResult {
  error: string;
  task: TrainPresaleTask | undefined;
}

export function emptyTrainPresaleTrip(): TrainPresaleTrip {
  return {
    trainCode: '',
    travelDate: '',
    fromName: '',
    fromCode: '',
    toName: '',
    toCode: '',
    saleAt: ''
  };
}

function validationError(message: string): TrainPresaleConfirmationResult {
  return { error: message, task: undefined };
}

function isValidDate(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return false;
  }
  const parts = value.split('-');
  const year = Number(parts[0]);
  const month = Number(parts[1]);
  const day = Number(parts[2]);
  const date = new Date(year, month - 1, day);
  return year >= 2000 && year <= 2099 && date.getFullYear() === year &&
    date.getMonth() === month - 1 && date.getDate() === day;
}

function isSupportedSeat(value: string): boolean {
  return TRAIN_PRESALE_SEAT_PREFERENCES.indexOf(value) >= 0;
}

export function validateTrainPresaleConfirmation(
  input: TrainPresaleConfirmationInput
): TrainPresaleConfirmationResult {
  const passengerNames: string[] = input.passengerNames
    .map((name: string): string => name.trim())
    .filter((name: string): boolean => name.length > 0);
  if (passengerNames.length === 0) {
    return validationError('请填写至少一位乘车人姓名。');
  }
  const seatPriority = input.seatPriority.trim();
  if (!isSupportedSeat(seatPriority)) {
    return validationError('请选择支持的席别。');
  }
  const trainCode = extractExactTrainCode(input.trainCode);
  const travelDate = input.travelDate.trim();
  const fromName = input.fromName.trim();
  const fromCode = input.fromCode.trim().toUpperCase();
  const toName = input.toName.trim();
  const toCode = input.toCode.trim().toUpperCase();
  const saleAt = input.saleAt.trim();
  if (trainCode.length === 0 || trainCode !== input.trainCode.trim().toUpperCase() || !isValidDate(travelDate) ||
    fromName.length === 0 || toName.length === 0 ||
    !/^[A-Z]{3}$/.test(fromCode) || !/^[A-Z]{3}$/.test(toCode) ||
    fromName === toName || fromCode === toCode ||
    !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\+08:00$/.test(saleAt) ||
    saleAt.substring(0, 10) !== travelDate || isNaN(new Date(saleAt).getTime())) {
    return validationError('车次、日期、路线或开售时间无效，请重新查询。');
  }
  if (!input.unpaidOrderAuthorized) {
    return validationError('请明确授权在开售时提交真实未支付订单。');
  }
  if (input.source === 'debug' && !input.debugEnabled) {
    return validationError('当前版本不允许调试测试。');
  }
  if (input.source === 'debug' && !input.debugConfirmed) {
    return validationError('请再次确认这是调试测试。');
  }
  const taskId = input.taskId.trim();
  const createdAt = input.createdAt.trim();
  if (taskId.length === 0 || isNaN(new Date(createdAt).getTime())) {
    return validationError('无法创建提醒，请重试。');
  }
  return {
    error: '',
    task: {
      taskId: taskId,
      source: input.source,
      state: 'scheduled',
      trainCode: trainCode,
      travelDate: travelDate,
      fromName: fromName,
      fromCode: fromCode,
      toName: toName,
      toCode: toCode,
      saleAt: saleAt,
      passengerNames: passengerNames,
      seatPriority: seatPriority,
      bookingUrl: build12306BookingUrl(travelDate, fromName, fromCode, toName, toCode),
      reminderId: -1,
      createdAt: createdAt,
      lastError: ''
    }
  };
}

export async function scheduleTrainPresaleTask(
  task: TrainPresaleTask,
  store: TrainPresaleTaskStore,
  scheduler: SystemOneShotScheduler
): Promise<TrainPresaleScheduleResult> {
  let reminderId = -1;
  try {
    store.create(task);
    if (store.get(task.taskId) === undefined) {
      throw new Error('任务保存失败');
    }
    reminderId = await scheduler.schedule(task, task.saleAt);
    store.update(task.taskId, { reminderId: reminderId });
    const persisted = store.get(task.taskId);
    if (persisted === undefined || persisted.reminderId !== reminderId) {
      throw new Error('提醒编号保存失败');
    }
    return { error: '', task: persisted };
  } catch (error) {
    const message = error instanceof Error ? error.message : JSON.stringify(error);
    let cleanupError = '';
    if (reminderId >= 0) {
      try {
        await scheduler.cancel(reminderId);
      } catch (cancelError) {
        cleanupError = cancelError instanceof Error ? cancelError.message : JSON.stringify(cancelError);
      }
    }
    try {
      store.update(task.taskId, { lastError: message });
      store.cancel(task.taskId);
    } catch (_storeError) {
    }
    return {
      error: '提醒创建失败：' + message +
        (cleanupError.length > 0 ? '；已发布提醒取消失败：' + cleanupError : ''),
      task: undefined
    };
  }
}

@Component
export struct TrainPresalePanel {
  @Prop trip: TrainPresaleTrip = emptyTrainPresaleTrip();
  @Prop taskState: string = '';
  @Prop errorMessage: string = '';
  @Prop isWorking: boolean = false;
  @Prop isDebugBuild: boolean = false;
  @State passengerName: string = '';
  @State seatPriority: string = TRAIN_PRESALE_SEAT_PREFERENCES[0];
  @State unpaidOrderAuthorized: boolean = false;
  @State debugMode: boolean = false;
  @State debugConfirmed: boolean = false;
  onConfirm: (submission: TrainPresalePanelSubmission) => void = (_submission: TrainPresalePanelSubmission): void => {};
  onClose: () => void = (): void => {};
  onCancelTask: () => void = (): void => {};

  private saleTimeText(): string {
    return this.trip.saleAt.length >= 16 ? this.trip.saleAt.substring(11, 16) : this.trip.saleAt;
  }

  private statusLabel(): string {
    if (this.taskState === 'scheduled') {
      return '已安排';
    }
    if (this.taskState === 'cancelled') {
      return '已取消';
    }
    return this.taskState;
  }

  private submit(): void {
    this.onConfirm({
      source: this.debugMode && this.isDebugBuild ? 'debug' : 'presale',
      passengerNames: [this.passengerName],
      seatPriority: this.seatPriority,
      unpaidOrderAuthorized: this.unpaidOrderAuthorized,
      debugConfirmed: this.debugConfirmed
    });
  }

  @Builder
  private VerifiedTripCard() {
    Column() {
      Row() {
        Text(this.trip.trainCode)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_INK)
        Text('已核验')
          .fontSize(11)
          .fontColor(COLOR_SUCCESS)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(COLOR_SUCCESS_SOFT)
          .borderRadius(8)
          .margin({ left: 10 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.trip.fromName + ' → ' + this.trip.toName)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_TEXT)
        .margin({ top: 10 })

      Text(this.trip.travelDate + ' · ' + this.saleTimeText() + ' 开售')
        .fontSize(13)
        .fontColor(COLOR_MUTED)
        .margin({ top: 6 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor(COLOR_ACCENT_SOFT)
    .borderRadius(16)
    .border({ width: 1, color: COLOR_CARD_EDGE })
  }

  @Builder
  private StatusCard() {
    Column() {
      Row() {
        Text(this.trip.trainCode + ' 开售任务')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_INK)
          .layoutWeight(1)
        Text(this.statusLabel())
          .fontSize(12)
          .fontColor(this.taskState === 'scheduled' ? COLOR_SUCCESS : COLOR_MUTED)
      }
      .width('100%')

      Text(this.trip.travelDate + ' · ' + this.trip.fromName + ' → ' + this.trip.toName)
        .fontSize(13)
        .fontColor(COLOR_TEXT)
        .margin({ top: 8 })
      Text(this.saleTimeText() + ' 开售 · ' + this.seatPriority)
        .fontSize(12)
        .fontColor(COLOR_MUTED)
        .margin({ top: 5 })

      if (this.errorMessage.length > 0) {
        Text(this.errorMessage)
          .width('100%')
          .fontSize(12)
          .fontColor(COLOR_ERROR)
          .padding(10)
          .backgroundColor(COLOR_ERROR_SOFT)
          .borderRadius(10)
          .border({ width: 1, color: COLOR_ERROR_LINE })
          .margin({ top: 12 })
      }

      if (this.taskState === 'scheduled') {
        A2uiButtonView({ label: '取消任务', shape: 'pill', tone: 'secondary', isEnabled: !this.isWorking })
          .enabled(!this.isWorking)
          .margin({ top: 16 })
          .onClick(() => this.onCancelTask())
      } else {
        A2uiButtonView({ label: '关闭', shape: 'pill', tone: 'secondary' })
          .margin({ top: 16 })
          .onClick(() => this.onClose())
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(18)
    .backgroundColor(COLOR_CARD)
    .borderRadius(18)
    .border({ width: 1, color: COLOR_CARD_EDGE })
  }

  build() {
    Scroll() {
      Column() {
        Row() {
          Column() {
            Text('开售任务确认')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(COLOR_INK)
            Text('仅保存显示名称，不保存证件或支付信息')
              .fontSize(12)
              .fontColor(COLOR_MUTED)
              .margin({ top: 4 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          A2uiButtonView({ label: '返回', shape: 'pill', tone: 'secondary', isEnabled: !this.isWorking })
            .enabled(!this.isWorking)
            .onClick(() => this.onClose())
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ bottom: 14 })

        if (this.taskState === 'scheduled' || this.taskState === 'cancelled') {
          this.StatusCard()
        } else {
          this.VerifiedTripCard()

          Text('乘车人显示名称')
            .fontSize(12)
            .fontColor(COLOR_MUTED)
            .margin({ top: 16, bottom: 6 })
          TextInput({ text: this.passengerName, placeholder: '例如：张三' })
            .width('100%')
            .height(44)
            .fontSize(14)
            .fontColor(COLOR_TEXT)
            .placeholderColor(COLOR_MUTED)
            .backgroundColor(COLOR_FIELD)
            .borderRadius(11)
            .border({ width: 1, color: COLOR_CARD_EDGE })
            .padding({ left: 12, right: 12 })
            .enabled(!this.isWorking)
            .onChange((value: string) => {
              this.passengerName = value;
            })

          Text('席别偏好')
            .fontSize(12)
            .fontColor(COLOR_MUTED)
            .margin({ top: 16, bottom: 6 })
          Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
            ForEach(TRAIN_PRESALE_SEAT_PREFERENCES, (label: string) => {
              A2uiButtonView({
                label: label,
                shape: 'pill',
                tone: 'secondary',
                active: this.seatPriority === label,
                isEnabled: !this.isWorking
              })
                .enabled(!this.isWorking)
                .margin({ right: 7, bottom: 7 })
                .onClick(() => {
                  this.seatPriority = label;
                })
            })
          }
          .width('100%')

          Row() {
            Column() {
              Text('授权提交真实未支付订单')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(COLOR_INK)
              Text('开售后会在 12306 创建真实订单，但不会自动付款。')
                .fontSize(12)
                .fontColor(COLOR_MUTED)
                .margin({ top: 4 })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            Toggle({ type: ToggleType.Switch, isOn: this.unpaidOrderAuthorized })
              .selectedColor(COLOR_ACCENT)
              .enabled(!this.isWorking)
              .onChange((isOn: boolean) => {
                this.unpaidOrderAuthorized = isOn;
              })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .padding(14)
          .backgroundColor(COLOR_CARD)
          .borderRadius(14)
          .border({ width: 1, color: COLOR_CARD_EDGE })
          .margin({ top: 16 })

          if (this.isDebugBuild) {
            Row() {
              A2uiButtonView({
                label: '10秒测试',
                shape: 'pill',
                tone: 'secondary',
                active: this.debugMode,
                isEnabled: !this.isWorking
              })
                .enabled(!this.isWorking)
                .onClick(() => {
                  this.debugMode = !this.debugMode;
                  this.debugConfirmed = false;
                })
              if (this.debugMode) {
                Text('调试模式 · 需再次确认')
                  .fontSize(11)
                  .fontColor(COLOR_MUTED)
                  .margin({ left: 10 })
                  .layoutWeight(1)
              }
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
            .margin({ top: 12 })

            if (this.debugMode) {
              Row() {
                Text('再次确认这是调试测试')
                  .fontSize(13)
                  .fontColor(COLOR_TEXT)
                  .layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.debugConfirmed })
                  .selectedColor(COLOR_ACCENT)
                  .enabled(!this.isWorking)
                  .onChange((isOn: boolean) => {
                    this.debugConfirmed = isOn;
                  })
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
              .padding({ top: 10, bottom: 4 })
            }
          }

          if (this.errorMessage.length > 0) {
            Text(this.errorMessage)
              .width('100%')
              .fontSize(12)
              .fontColor(COLOR_ERROR)
              .padding(12)
              .backgroundColor(COLOR_ERROR_SOFT)
              .borderRadius(10)
              .border({ width: 1, color: COLOR_ERROR_LINE })
              .margin({ top: 12 })
          }

          Row({ space: 10 }) {
            A2uiButtonView({ label: '取消', shape: 'pill', tone: 'secondary', fill: true, isEnabled: !this.isWorking })
              .layoutWeight(1)
              .enabled(!this.isWorking)
              .onClick(() => this.onClose())
            A2uiButtonView({ label: '确认提醒', shape: 'pill', tone: 'primary', fill: true, isEnabled: !this.isWorking })
              .layoutWeight(1)
              .enabled(!this.isWorking)
              .onClick(() => this.submit())
          }
          .width('100%')
          .margin({ top: 16 })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(18)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_CARD)
    .borderRadius(A2UI_HOME_FLOATING_RADIUS)
    .border({ width: 1, color: COLOR_CARD_EDGE })
  }
}
