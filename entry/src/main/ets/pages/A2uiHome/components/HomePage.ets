import {
  COLOR_ACCENT,
  COLOR_ACCENT_DEEP,
  COLOR_ACCENT_SHADOW,
  COLOR_ACCENT_SOFT,
  COLOR_CARD,
  COLOR_CARD_EDGE,
  COLOR_CARD_GLOW,
  COLOR_INK,
  COLOR_MUTED,
  COLOR_PAGE,
  COLOR_TEXT
} from '../style/A2uiHomeTheme';
import { KeyboardAvoidMode } from '@ohos.arkui.UIContext';
import {
  A2uiAction,
  A2uiMessage,
  A2uiSurfaceState,
  emptyA2uiSurface
} from '@loop/agent-core';
import { A2uiButtonView } from './common/A2uiButtonView';
import { HistoryPanelView } from './HistoryPanelView';
import { HtmlHomeSurfaceView } from './HtmlHomeSurfaceView';
import { A2uiSurfaceView } from './A2uiSurfaceView';
import { PaymentCheckoutOverlay } from './PaymentCheckoutOverlay';
import {
  isPromptInputEnabled,
  nextSendSpinnerRotation
} from '../state/A2uiHomeState';
import {
  A2UI_HOME_MAX_WIDTH
} from '../style/A2uiHomeLayout';
import { A2UI_MOTION_CURVE, A2UI_MOTION_NORMAL_MS } from '../style/A2uiHomeMotion';
import { A2uiWorkspaceScene, isWorkspaceSceneBusy } from '../state/A2uiWorkspaceState';

const A2UI_HISTORY_EMPTY_HEIGHT: number = 108;
const A2UI_HISTORY_ROW_HEIGHT: number = 76;
const A2UI_HISTORY_MAX_HEIGHT: number = 254;
const A2UI_SEND_SPINNER_INTERVAL_MS: number = 90;
const A2UI_HEADER_BUTTON_GAP: number = 4;
const A2UI_HEADER_BUTTON_SIZE: number = 38;
const A2UI_HEADER_BUTTON_ICON_SIZE: number = 19;
const A2UI_HEADER_LOGO_SIZE: number = 28;
const A2UI_HEADER_TITLE_FONT_SIZE: number = 16;
const A2UI_VOICE_DOCK_HEIGHT: number = 72;
const A2UI_VOICE_PULSE_STEPS: number = 12;
const A2UI_SCENE_SWIPE_THRESHOLD: number = 52;

@Component
struct WorkspaceSceneTab {
  @Prop title: string = '';
  @Prop sceneId: string = '';
  @Prop isActive: boolean = false;
  onSelect: () => void = (): void => {};

  build() {
    Row({ space: 7 }) {
      if (this.isActive) {
        Circle({ width: 7, height: 7 })
          .fill(COLOR_ACCENT_DEEP)
      }

      Text(this.title.trim().length > 0 ? this.title : this.sceneId)
        .fontSize(13)
        .fontWeight(this.isActive ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.isActive ? COLOR_INK : COLOR_MUTED)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .height(38)
    .justifyContent(FlexAlign.Center)
    .padding({ left: 10, right: 10 })
    .borderRadius(12)
    .backgroundColor(this.isActive ? COLOR_CARD : COLOR_PAGE)
    .border({
      width: 1,
      color: this.isActive ? COLOR_CARD_EDGE : '#00000000'
    })
    .onClick(() => {
      this.onSelect();
    })
  }
}

@Component
struct WorkspaceSceneSurfaceHost {
  @Prop surface: A2uiSurfaceState = emptyA2uiSurface();
  @Prop html: string = '';
  @Prop documentKey: string = '';
  @Prop renderTick: number = 0;
  @Prop isActive: boolean = false;
  @Prop isBusy: boolean = false;
  @Prop mailDetailEventJson: string = '';
  @Prop mailReplyEventJson: string = '';
  @Prop mailCalendarEventJson: string = '';
  @Prop luckinInlinePatchJson: string = '';
  @Prop luckinInlinePatchTick: number = 0;
  onAction: (action: A2uiAction) => void = (_action: A2uiAction): void => {};

  build() {
    Column() {
      if (this.surface.intent === 'social') {
        A2uiSurfaceView({
          surface: this.surface,
          renderTick: this.renderTick,
          isBusy: this.isBusy,
          showPendingSurface: false,
          onAction: this.onAction
        })
        .height('100%')
      } else {
        HtmlHomeSurfaceView({
          surfaceId: this.surface.surfaceId,
          html: this.html,
          documentKey: this.documentKey,
          mailDetailEventJson: this.isActive ? this.mailDetailEventJson : '',
          mailReplyEventJson: this.isActive ? this.mailReplyEventJson : '',
          mailCalendarEventJson: this.isActive ? this.mailCalendarEventJson : '',
          isBusy: this.isBusy,
          renderTick: this.renderTick,
          luckinInlinePatchJson: this.isActive ? this.luckinInlinePatchJson : '',
          luckinInlinePatchTick: this.isActive ? this.luckinInlinePatchTick : 0,
          onAction: this.onAction
        })
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .visibility(this.isActive ? Visibility.Visible : Visibility.Hidden)
  }
}

@Component
export struct HomePage {
  @Link inputText: string;
  @Prop isBusy: boolean = false;
  @Prop showHistory: boolean = false;
  @Prop messages: A2uiMessage[] = [];
  @Prop currentSurface: A2uiSurfaceState = emptyA2uiSurface();
  @Prop workspaceScenes: A2uiWorkspaceScene[] = [];
  @Prop activeSceneIndex: number = 0;
  @Prop htmlHomeHtml: string = '';
  @Prop mailDetailEventJson: string = '';
  @Prop mailReplyEventJson: string = '';
  @Prop mailCalendarEventJson: string = '';
  @Prop surfaceRenderTick: number = 0;
  @Prop luckinInlinePatchJson: string = '';
  @Prop luckinInlinePatchTick: number = 0;
  @Prop isAwaitingFirstSurface: boolean = false;
  @Prop inputPlaceholder: string = '告诉 Appless Phone 你想完成什么';
  @Prop isVoiceListening: boolean = false;
  @Prop voiceInputMessage: string = '';
  @Prop showWelcome: boolean = false;
  @Prop showPaymentCheckout: boolean = false;
  @Prop paymentCheckoutUrl: string = '';
  @State sendSpinnerRotation: number = 0;
  @State voicePulseTick: number = 0;
  private sendSpinnerTimerId: number = -1;
  private previousKeyboardAvoidMode: KeyboardAvoidMode = KeyboardAvoidMode.OFFSET;
  onToggleHistory: () => void = () => {};
  onOpenConfig: () => void = () => {};
  onOpenSocialHub: () => void = () => {};
  onSendPrompt: () => void = () => {};
  onStartVoiceInput: () => void = () => {};
  onStopVoiceInput: () => void = () => {};
  onResetSession: () => void = () => {};
  onClosePaymentCheckout: () => void = () => {};
  onSelectScene: (index: number) => void = (_index: number): void => {};
  onPaymentCheckoutReturn: (url: string) => void = (_url: string): void => {};
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};

  aboutToAppear(): void {
    const uiContext = this.getUIContext();
    this.previousKeyboardAvoidMode = uiContext.getKeyboardAvoidMode();
    uiContext.setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
    this.startSendSpinnerTimer();
  }

  aboutToDisappear(): void {
    this.getUIContext().setKeyboardAvoidMode(this.previousKeyboardAvoidMode);
    this.stopSendSpinnerTimer();
  }

  private startSendSpinnerTimer(): void {
    if (this.sendSpinnerTimerId >= 0) {
      return;
    }
    this.sendSpinnerTimerId = setInterval(() => {
      this.sendSpinnerRotation = nextSendSpinnerRotation(this.sendSpinnerRotation, this.isBusy);
      if (this.isVoiceListening) {
        this.voicePulseTick = (this.voicePulseTick + 1) % A2UI_VOICE_PULSE_STEPS;
      } else if (this.voicePulseTick !== 0) {
        this.voicePulseTick = 0;
      }
    }, A2UI_SEND_SPINNER_INTERVAL_MS);
  }

  private stopSendSpinnerTimer(): void {
    if (this.sendSpinnerTimerId < 0) {
      return;
    }
    clearInterval(this.sendSpinnerTimerId);
    this.sendSpinnerTimerId = -1;
  }

  private historyPanelHeight(): number {
    if (!this.showHistory) {
      return 0;
    }
    if (this.messages.length === 0) {
      return A2UI_HISTORY_EMPTY_HEIGHT;
    }
    const contentHeight = A2UI_HISTORY_EMPTY_HEIGHT + this.messages.length * A2UI_HISTORY_ROW_HEIGHT;
    return Math.min(contentHeight, A2UI_HISTORY_MAX_HEIGHT);
  }

  private canResetSession(): boolean {
    return !this.isBusy && (!this.showWelcome || this.inputText.trim().length > 0);
  }

  private useNativeSurface(): boolean {
    return this.currentSurface.intent === 'social';
  }

  private surfaceDocumentKey(surface: A2uiSurfaceState): string {
    return surface.surfaceId + ':' + surface.sequence.toString() + ':' + surface.status;
  }

  private selectScene(index: number): void {
    if (index < 0 || index >= this.workspaceScenes.length || index === this.activeSceneIndex) {
      return;
    }
    this.onSelectScene(index);
  }

  private currentSceneIndex(): number {
    return this.activeSceneIndex >= 0 && this.activeSceneIndex < this.workspaceScenes.length ?
      this.activeSceneIndex : 0;
  }

  private selectAdjacentScene(offset: number): void {
    this.selectScene(this.currentSceneIndex() + offset);
  }

  private handleSceneSwipe(event: GestureEvent): void {
    if (event.offsetX <= -A2UI_SCENE_SWIPE_THRESHOLD) {
      this.selectAdjacentScene(1);
    } else if (event.offsetX >= A2UI_SCENE_SWIPE_THRESHOLD) {
      this.selectAdjacentScene(-1);
    }
  }

  @Builder
  private WorkspaceSceneTabs() {
    Row({ space: 8 }) {
      ForEach(this.workspaceScenes, (scene: A2uiWorkspaceScene, index: number) => {
        WorkspaceSceneTab({
          title: scene.title,
          sceneId: scene.sceneId,
          isActive: index === this.activeSceneIndex,
          onSelect: () => {
            this.selectScene(index);
          }
        })
      }, (scene: A2uiWorkspaceScene) => scene.sceneId + '-' + scene.renderTick.toString())
    }
    .width('100%')
    .margin({ bottom: 8 })
  }

  private voiceWaveHeight(index: number): number {
    const phase = (this.voicePulseTick + index * 2) % A2UI_VOICE_PULSE_STEPS;
    const peak = phase <= 6 ? phase : A2UI_VOICE_PULSE_STEPS - phase;
    return 10 + peak * 4;
  }

  private voiceWaveOpacity(index: number): number {
    const phase = (this.voicePulseTick + index * 2) % A2UI_VOICE_PULSE_STEPS;
    const peak = phase <= 6 ? phase : A2UI_VOICE_PULSE_STEPS - phase;
    return 0.38 + peak * 0.08;
  }

  private voiceOrbScale(): number {
    return this.voicePulseTick < 6 ? 1 + this.voicePulseTick * 0.018 : 1.18 - (this.voicePulseTick - 6) * 0.018;
  }

  private voiceOrbOpacity(): number {
    return this.voicePulseTick < 6 ? 0.18 + this.voicePulseTick * 0.018 : 0.29 - (this.voicePulseTick - 6) * 0.018;
  }

  private voiceDisplayText(): string {
    const text = this.voiceInputMessage.trim();
    return text.length > 0 ? text : '语音识别中';
  }

  private handleVoiceTouch(event: TouchEvent): void {
    if (this.isBusy) {
      return;
    }
    if (event.type === TouchType.Down) {
      if (!this.isVoiceListening) {
        this.onStartVoiceInput();
      }
      return;
    }
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.onStopVoiceInput();
    }
  }

  @Builder
  private VoiceWaveBar(index: number) {
    Column() {}
      .width(index === 4 ? 4 : 3)
      .height(this.voiceWaveHeight(index))
      .backgroundColor(index === 4 ? COLOR_ACCENT_DEEP : COLOR_ACCENT)
      .borderRadius(4)
      .opacity(this.voiceWaveOpacity(index))
      .animation({ duration: 220, curve: A2UI_MOTION_CURVE })
  }

  @Builder
  private VoiceListeningView() {
    Row() {
      Stack({ alignContent: Alignment.Center }) {
        Circle({ width: 58, height: 58 })
          .fill(COLOR_ACCENT_SOFT)
          .opacity(this.voiceOrbOpacity())
          .scale({ x: this.voiceOrbScale(), y: this.voiceOrbScale() })
          .animation({ duration: 220, curve: A2UI_MOTION_CURVE })

        Circle({ width: 48, height: 48 })
          .fill('#FFFFFF')
          .opacity(0.48)

        Circle({ width: 40, height: 40 })
          .fill('#FFFBF7')

        Circle({ width: 28, height: 28 })
          .fill(COLOR_ACCENT)
          .opacity(0.1)

        Image($r('app.media.icon_microphone'))
          .width(18)
          .height(18)
      }
      .width(68)
      .height(58)

      Text(this.voiceDisplayText())
        .layoutWeight(1)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_INK)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ left: 8, right: 14 })

      Row() {
        this.VoiceWaveBar(0)
        this.VoiceWaveBar(1)
        this.VoiceWaveBar(2)
        this.VoiceWaveBar(3)
        this.VoiceWaveBar(4)
        this.VoiceWaveBar(5)
        this.VoiceWaveBar(6)
        this.VoiceWaveBar(7)
        this.VoiceWaveBar(8)
      }
      .width(76)
      .height(42)
      .alignItems(VerticalAlign.Center)
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('100%')
    .height(A2UI_VOICE_DOCK_HEIGHT)
    .alignItems(VerticalAlign.Center)
    .onTouch((event: TouchEvent) => {
      this.handleVoiceTouch(event);
    })
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Row() {
          Image($r('app.media.logo_appless'))
            .width(A2UI_HEADER_LOGO_SIZE)
            .height(A2UI_HEADER_LOGO_SIZE)
            .objectFit(ImageFit.Contain)
            .margin({ right: 8 })

          Text('Appless Phone')
            .fontSize(A2UI_HEADER_TITLE_FONT_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLOR_INK)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          A2uiButtonView({
            icon: $r('app.media.icon_history'),
            hasIcon: true,
            shape: 'circle',
            circleSize: A2UI_HEADER_BUTTON_SIZE,
            iconSize: A2UI_HEADER_BUTTON_ICON_SIZE,
            tone: 'secondary',
            active: this.showHistory
          })
            .onClick(() => {
              this.onToggleHistory();
            })
            .margin({ left: A2UI_HEADER_BUTTON_GAP })

          A2uiButtonView({
            icon: $r('app.media.icon_reset'),
            hasIcon: true,
            shape: 'circle',
            circleSize: A2UI_HEADER_BUTTON_SIZE,
            iconSize: A2UI_HEADER_BUTTON_ICON_SIZE,
            tone: 'secondary',
            isEnabled: this.canResetSession()
          })
            .enabled(this.canResetSession())
            .onClick(() => {
              if (!this.canResetSession()) {
                return;
              }
              this.onResetSession();
            })
            .margin({ left: A2UI_HEADER_BUTTON_GAP })

          A2uiButtonView({
            icon: $r('app.media.icon_social'),
            hasIcon: true,
            shape: 'circle',
            circleSize: A2UI_HEADER_BUTTON_SIZE,
            iconSize: A2UI_HEADER_BUTTON_ICON_SIZE,
            tone: 'secondary',
            active: this.currentSurface.intent === 'social',
            customBackgroundColor: this.currentSurface.intent === 'social' ? COLOR_ACCENT_SOFT : '',
            customBorderColor: this.currentSurface.intent === 'social' ? COLOR_ACCENT : '',
            isEnabled: !this.isBusy
          })
            .enabled(!this.isBusy)
            .onClick(() => {
              if (this.isBusy) {
                return;
              }
              this.onOpenSocialHub();
            })
            .margin({ left: A2UI_HEADER_BUTTON_GAP })

          A2uiButtonView({
            icon: $r('app.media.icon_settings'),
            hasIcon: true,
            shape: 'circle',
            circleSize: A2UI_HEADER_BUTTON_SIZE,
            iconSize: A2UI_HEADER_BUTTON_ICON_SIZE,
            tone: 'secondary'
          })
            .onClick(() => {
              this.onOpenConfig();
            })
            .margin({ left: A2UI_HEADER_BUTTON_GAP })
        }
        .width('100%')
        .height(44)
        .alignItems(VerticalAlign.Center)
        .padding({ left: 0, right: 0 })
        .margin({ bottom: 12 })

      Column() {
        if (this.showHistory) {
          HistoryPanelView({
            messages: this.messages
          })
          .height('100%')
        }
      }
      .width('100%')
      .height(this.historyPanelHeight())
      .opacity(this.showHistory ? 1 : 0)
      .clip(true)
      .margin({ top: this.showHistory ? 14 : 0 })
      .animation({ duration: A2UI_MOTION_NORMAL_MS, curve: A2UI_MOTION_CURVE })

      if (this.showPaymentCheckout && this.paymentCheckoutUrl.trim().length > 0) {
        PaymentCheckoutOverlay({
          url: this.paymentCheckoutUrl,
          onClose: this.onClosePaymentCheckout,
          onReturnUrl: this.onPaymentCheckoutReturn
        })
          .layoutWeight(1)
          .margin({ top: 12 })
          .borderRadius(22)
          .clip(true)
      } else if (this.workspaceScenes.length > 0) {
        Column() {
          if (this.workspaceScenes.length > 1) {
            this.WorkspaceSceneTabs()
          }
          Stack() {
            ForEach(this.workspaceScenes, (scene: A2uiWorkspaceScene, index: number) => {
              WorkspaceSceneSurfaceHost({
                surface: scene.surface,
                html: scene.html,
                documentKey: this.surfaceDocumentKey(scene.surface),
                renderTick: scene.renderTick,
                isActive: index === this.activeSceneIndex,
                isBusy: isWorkspaceSceneBusy(scene),
                mailDetailEventJson: this.mailDetailEventJson,
                mailReplyEventJson: this.mailReplyEventJson,
                mailCalendarEventJson: this.mailCalendarEventJson,
                luckinInlinePatchJson: this.luckinInlinePatchJson,
                luckinInlinePatchTick: this.luckinInlinePatchTick,
                onAction: this.onAction
              })
            }, (scene: A2uiWorkspaceScene) => scene.sceneId)
          }
          .width('100%')
          .layoutWeight(1)
          .gesture(
            PanGesture({ direction: PanDirection.Horizontal, distance: 24 })
              .onActionEnd((event: GestureEvent) => {
                this.handleSceneSwipe(event);
              })
          )
        }
        .layoutWeight(1)
        .margin({ top: 6 })
      } else if (this.useNativeSurface()) {
        A2uiSurfaceView({
          surface: this.currentSurface,
          renderTick: this.surfaceRenderTick,
          isBusy: this.isBusy,
          showPendingSurface: false,
          onAction: this.onAction
        })
        .layoutWeight(1)
        .margin({ top: 12 })
      } else {
        HtmlHomeSurfaceView({
          surfaceId: this.currentSurface.surfaceId,
          html: this.htmlHomeHtml,
          documentKey: this.surfaceDocumentKey(this.currentSurface),
          mailDetailEventJson: this.mailDetailEventJson,
          mailReplyEventJson: this.mailReplyEventJson,
          mailCalendarEventJson: this.mailCalendarEventJson,
          isBusy: this.isBusy,
          renderTick: this.surfaceRenderTick,
          luckinInlinePatchJson: this.luckinInlinePatchJson,
          luckinInlinePatchTick: this.luckinInlinePatchTick,
          onAction: this.onAction
        })
        .layoutWeight(1)
        .margin({ top: 12 })
      }

      Column() {
        Row() {
          if (this.isVoiceListening) {
            this.VoiceListeningView()
          } else {
            TextArea({
              placeholder: this.inputPlaceholder,
              text: this.inputText
            })
              .constraintSize({ minHeight: 36, maxHeight: 80 })
              .layoutWeight(1)
              .fontSize(16)
              .fontColor(COLOR_TEXT)
              .lineHeight(24)
              .enterKeyType(EnterKeyType.Send)
              .placeholderColor(COLOR_MUTED)
              .backgroundColor('#00000000')
              .borderRadius(0)
              .border({ width: 0 })
              .padding({
                left: 0,
                right: 0,
                top: 6,
                bottom: 8
              })
              .enabled(isPromptInputEnabled(this.isBusy))
              .onChange((value: string) => {
                if (!isPromptInputEnabled(this.isBusy)) {
                  return;
                }
                this.inputText = value;
              })
              .onSubmit(() => {
                if (!isPromptInputEnabled(this.isBusy)) {
                  return;
                }
                this.onSendPrompt();
              })

            A2uiButtonView({
              icon: $r('app.media.icon_microphone'),
              hasIcon: true,
              shape: 'circle',
              circleSize: 40,
              iconSize: 18,
              tone: 'secondary',
              active: this.isVoiceListening,
              isEnabled: !this.isBusy && !this.isVoiceListening
            })
              .margin({ left: 8 })
              .enabled(!this.isBusy && !this.isVoiceListening)
              .onTouch((event: TouchEvent) => {
                this.handleVoiceTouch(event);
              })

            A2uiButtonView({
              icon: this.isBusy ? $r('app.media.icon_wait_spinner') : $r('app.media.arrow_up'),
              hasIcon: true,
              shape: 'circle',
              circleSize: 40,
              iconSize: this.isBusy ? 22 : 18,
              customBackgroundColor: COLOR_ACCENT,
              customBorderWidth: 0,
              shadowColor: COLOR_ACCENT_SHADOW,
              shadowRadius: 15,
              iconRotation: this.sendSpinnerRotation
            })
              .animation({ duration: A2UI_SEND_SPINNER_INTERVAL_MS, curve: Curve.Linear })
              .margin({ left: 8 })
              .enabled(!this.isBusy)
              .onClick(() => {
                if (this.isBusy) {
                  return;
                }
                this.onSendPrompt();
              })
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .constraintSize({ minHeight: this.isVoiceListening ? A2UI_VOICE_DOCK_HEIGHT : 56 })
        .padding({
          left: this.isVoiceListening ? 10 : 18,
          right: this.isVoiceListening ? 14 : 8,
          top: this.isVoiceListening ? 4 : 7,
          bottom: this.isVoiceListening ? 4 : 7
        })
        .backgroundColor('#FFFCF8')
        .linearGradient({
          angle: 110,
          colors: [['#FFFFFF', 0], ['#FFF8F2', 0.62], ['#F6ECE3', 1]]
        })
        .borderRadius(this.isVoiceListening ? 34 : 30)
        .border({ width: 1, color: this.isVoiceListening ? '#D8BCAF' : COLOR_CARD_EDGE })
        .shadow({
          radius: this.isVoiceListening ? 32 : 22,
          color: this.isVoiceListening ? '#995F4C2E' : COLOR_CARD_GLOW,
          offsetX: 0,
          offsetY: this.isVoiceListening ? 10 : 7
        })
        .animation({ duration: A2UI_MOTION_NORMAL_MS, curve: A2UI_MOTION_CURVE })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ top: 12, left: 0, right: 0 })
      }
      .width('100%')
      .constraintSize({ maxWidth: A2UI_HOME_MAX_WIDTH })
      .height('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 14 })
      .backgroundColor(COLOR_PAGE)

    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_PAGE)
  }
}
