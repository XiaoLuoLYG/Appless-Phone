import { common, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { A2uiAction, A2uiComponent, A2uiSurfaceState, emptyA2uiSurface } from '../../../model/A2uiTypes';
import { actionsOf, foodOptions, A2uiFoodOption } from '../../../model/A2uiData';
import { aiLogError, aiLogInfo } from '../../../model/AiphoneLogger';
import { buildSystemFoodNavigationUri, describeSystemFoodNavigationUri } from '../../../model/FoodNavigation';
import { foodDistanceMeters } from '../../../model/ToolGatewayClient';
import {
  COLOR_ACCENT,
  COLOR_ACCENT_DARK,
  COLOR_ACCENT_DEEP,
  COLOR_ACCENT_SOFT,
  COLOR_BUTTON_TEXT,
  COLOR_CARD_EDGE,
  COLOR_CARD_GLOW,
  COLOR_CARD_INSET,
  COLOR_CARD_RAISED,
  COLOR_ERROR,
  COLOR_FOOD_AMAP,
  COLOR_FOOD_AMAP_LINE,
  COLOR_FOOD_AMAP_SOFT,
  COLOR_FOOD_BAIDU,
  COLOR_FOOD_BAIDU_LINE,
  COLOR_FOOD_BAIDU_SOFT,
  COLOR_FOOD_MEITUAN,
  COLOR_FOOD_MEITUAN_LINE,
  COLOR_FOOD_MEITUAN_SOFT,
  COLOR_FOOD_MCD,
  COLOR_FOOD_MCD_LINE,
  COLOR_FOOD_MCD_SOFT,
  COLOR_FOOD_TAOBAO,
  COLOR_FOOD_TAOBAO_LINE,
  COLOR_FOOD_TAOBAO_SOFT,
  COLOR_FOOD_LUCKIN,
  COLOR_FOOD_LUCKIN_LINE,
  COLOR_FOOD_LUCKIN_SOFT,
  COLOR_FOOD_TENCENT,
  COLOR_FOOD_TENCENT_LINE,
  COLOR_FOOD_TENCENT_SOFT,
  COLOR_INK,
  COLOR_MUTED,
  COLOR_TEXT
} from '../style/A2uiHomeTheme';
import { componentBodyOf, componentStatusOf, componentTitleOf } from '../render/A2uiRenderData';
import { a2uiEnterTransition } from '../style/A2uiHomeMotion';
import {
  A2UI_PANEL_BACKGROUND_COLOR,
  A2UI_PANEL_BORDER_COLOR,
  A2UI_PANEL_CORNER_RADIUS
} from '../style/A2uiPanelFrameStyle';
import { ActionBarView } from './ActionBarView';
import { StatusBadgeView } from './StatusBadgeView';
import { A2uiPanelAccentView } from './common/A2uiPanelAccentView';

interface FoodNavigationTarget {
  name: string;
  want: Want;
}

type FoodFilterMode = 'all' | 'within_1km';

const FOOD_CARD_BACKGROUND: string = '#18181B';
const FOOD_CARD_BORDER: string = '#27272A';
const FOOD_CARD_ACTIVE_BORDER: string = '#0D9488';

@Component
export struct FoodChoicesView {
  @Prop surface: A2uiSurfaceState = emptyA2uiSurface();
  @Prop component: A2uiComponent = { id: '', component: 'FoodChoices' };
  @Prop renderTick: number = 0;
  @Prop isBusy: boolean = false;
  @State filterMode: FoodFilterMode = 'all';
  @State expandedFoodKey: string = '';
  @State foodNavigationStatus: string = '';
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};

  private foods(): A2uiFoodOption[] {
    return foodOptions(this.surface, this.component);
  }

  private visibleFoods(): A2uiFoodOption[] {
    let rows = this.foods();
    if (this.filterMode === 'within_1km') {
      rows = rows.filter((item: A2uiFoodOption) => foodDistanceMeters(item.distance) <= 1000);
    }
    return rows;
  }

  private foodRowKey(item: A2uiFoodOption): string {
    const location = item.location === undefined || item.location === null ? '' : item.location;
    return item.name + '|' + item.address + '|' + item.distance + '|' + location;
  }

  private sourceTags(item: A2uiFoodOption): string[] {
    if (item.sourceTags === undefined || item.sourceTags === null || !Array.isArray(item.sourceTags)) {
      return [];
    }
    const tags: string[] = [];
    item.sourceTags.forEach((tag: string) => {
      if (tag.length > 0 && tags.indexOf(tag) < 0) {
        tags.push(tag);
      }
    });
    return tags;
  }

  private sourceAccent(source: string): string {
    if (source === '高德') {
      return COLOR_FOOD_AMAP;
    }
    if (source === '腾讯地图') {
      return COLOR_FOOD_TENCENT;
    }
    if (source === '百度地图') {
      return COLOR_FOOD_BAIDU;
    }
    if (source === '美团') {
      return COLOR_FOOD_MEITUAN;
    }
    if (source === '淘宝闪购') {
      return COLOR_FOOD_TAOBAO;
    }
    if (source === '麦当劳') {
      return COLOR_FOOD_MCD;
    }
    if (source === '瑞幸') {
      return COLOR_FOOD_LUCKIN;
    }
    return COLOR_ACCENT_DARK;
  }

  private sourceSoft(source: string): string {
    if (source === '高德') {
      return COLOR_FOOD_AMAP_SOFT;
    }
    if (source === '腾讯地图') {
      return COLOR_FOOD_TENCENT_SOFT;
    }
    if (source === '百度地图') {
      return COLOR_FOOD_BAIDU_SOFT;
    }
    if (source === '美团') {
      return COLOR_FOOD_MEITUAN_SOFT;
    }
    if (source === '淘宝闪购') {
      return COLOR_FOOD_TAOBAO_SOFT;
    }
    if (source === '麦当劳') {
      return COLOR_FOOD_MCD_SOFT;
    }
    if (source === '瑞幸') {
      return COLOR_FOOD_LUCKIN_SOFT;
    }
    return COLOR_ACCENT_SOFT;
  }

  private sourceLine(source: string): string {
    if (source === '高德') {
      return COLOR_FOOD_AMAP_LINE;
    }
    if (source === '腾讯地图') {
      return COLOR_FOOD_TENCENT_LINE;
    }
    if (source === '百度地图') {
      return COLOR_FOOD_BAIDU_LINE;
    }
    if (source === '美团') {
      return COLOR_FOOD_MEITUAN_LINE;
    }
    if (source === '淘宝闪购') {
      return COLOR_FOOD_TAOBAO_LINE;
    }
    if (source === '麦当劳') {
      return COLOR_FOOD_MCD_LINE;
    }
    if (source === '瑞幸') {
      return COLOR_FOOD_LUCKIN_LINE;
    }
    return COLOR_CARD_EDGE;
  }

  private cardBorder(item: A2uiFoodOption): string {
    return this.expandedFoodKey === this.foodRowKey(item) ? FOOD_CARD_ACTIVE_BORDER : FOOD_CARD_BORDER;
  }

  private locationText(item: A2uiFoodOption): string {
    if (item.location === undefined || item.location === null) {
      return '';
    }
    return item.location.trim();
  }

  private canNavigate(item: A2uiFoodOption): boolean {
    return buildSystemFoodNavigationUri(this.locationText(item), '', item.name).length > 0;
  }

  private navigationUnavailableText(item: A2uiFoodOption): string {
    if (!this.canNavigate(item)) {
      return '缺少真实坐标，不能打开地图';
    }
    return '';
  }

  private navigationWant(uri: string): Want {
    return {
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: uri
    };
  }

  private navigationTargets(item: A2uiFoodOption): FoodNavigationTarget[] {
    const targets: FoodNavigationTarget[] = [];
    const debug = describeSystemFoodNavigationUri(this.locationText(item), '', item.name);
    aiLogInfo('[AIPhone][FoodNavigationUri] surface=a2ui_home mode=' + debug.mode +
      ' destinationRaw=' + this.locationText(item) + ' destinationMap=' + debug.destination +
      ' originRaw= originMap=' + debug.origin + ' name=' + debug.name + ' uri=' + debug.uri);
    if (debug.uri.length > 0) {
      targets.push({ name: '系统地图', want: this.navigationWant(debug.uri) });
    }
    return targets;
  }

  private async openFoodNavigation(item: A2uiFoodOption): Promise<void> {
    if (!this.canNavigate(item)) {
      this.foodNavigationStatus = this.navigationUnavailableText(item);
      return;
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    aiLogInfo('[AIPhone][FoodNavigationClick] surface=a2ui_home name=' + item.name +
      ' destinationRaw=' + this.locationText(item));
    const targets = this.navigationTargets(item);
    if (targets.length === 0) {
      this.foodNavigationStatus = this.navigationUnavailableText(item);
      return;
    }
    let lastError = '';
    for (let index = 0; index < targets.length; index++) {
      const target = targets[index];
      try {
        const uri: string = target.want.uri === undefined ? '' : target.want.uri;
        let launchMode = 'openLink';
        try {
          aiLogInfo('[AIPhone][FoodNavigationLaunchAttempt] surface=a2ui_home provider=' + target.name +
            ' launchMode=openLink uri=' + uri);
          await context.openLink(uri);
          aiLogInfo('[AIPhone][FoodNavigationLaunchResult] surface=a2ui_home provider=' + target.name +
            ' launchMode=openLink ok=true');
        } catch (linkError) {
          const linkBusinessError = linkError as BusinessError;
          launchMode = 'startAbility';
          aiLogError('[AIPhone][FoodNavigation] openLink failed provider=' + target.name + ' code=' + (linkBusinessError.code === undefined || linkBusinessError.code === null ? 'unknown' : linkBusinessError.code.toString()) + ' message=' + linkBusinessError.message);
          aiLogInfo('[AIPhone][FoodNavigationLaunchAttempt] surface=a2ui_home provider=' + target.name +
            ' launchMode=startAbility implicit=true uri=' + uri);
          await context.startAbility(target.want);
          aiLogInfo('[AIPhone][FoodNavigationLaunchResult] surface=a2ui_home provider=' + target.name +
            ' launchMode=startAbility ok=true');
        }
        this.foodNavigationStatus = '已在' + target.name + '打开目的地';
        aiLogInfo('[AIPhone][FoodNavigation] provider=' + target.name + ' launchMode=' + launchMode +
          ' uriChars=' + uri.length.toString() + ' mode=destination_only name=' + item.name);
        return;
      } catch (error) {
        const businessError = error as BusinessError;
        lastError = target.name + '：' + businessError.message;
        const code = businessError.code === undefined || businessError.code === null ? 'unknown' : businessError.code.toString();
        aiLogError('[AIPhone][FoodNavigation] failed provider=' + target.name + ' code=' + code + ' message=' + businessError.message);
      }
    }
    this.foodNavigationStatus = '地图打开失败：' + lastError;
  }

  private isLocalFoodAction(action: A2uiAction): boolean {
    return action.id === 'food_show_all' || action.id === 'food_filter_1km';
  }

  private actionForFilter(action: A2uiAction): A2uiAction {
    const active = (action.id === 'food_show_all' && this.filterMode === 'all') ||
      (action.id === 'food_filter_1km' && this.filterMode === 'within_1km');
    if (!active) {
      return action;
    }
    return {
      id: action.id,
      label: action.label,
      prompt: action.prompt,
      kind: action.kind,
      variant: 'activated'
    };
  }

  private visibleActions(): A2uiAction[] {
    const next: A2uiAction[] = [];
    actionsOf(this.component).forEach((action: A2uiAction) => {
      next.push(this.actionForFilter(action));
    });
    return next;
  }

  private handleAction(action: A2uiAction): void {
    if (!this.isLocalFoodAction(action)) {
      this.onAction(action);
      return;
    }
    this.filterMode = action.id === 'food_filter_1km' ? 'within_1km' : 'all';
  }

  @Builder
  private DetailRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(12)
        .fontColor(COLOR_MUTED)
        .width(58)
      Text(value)
        .fontSize(13)
        .fontColor(COLOR_TEXT)
        .lineHeight(20)
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ top: 4, bottom: 4 })
  }

  @Builder
  private FoodDetailPanel(item: A2uiFoodOption) {
    Column() {
      this.DetailRow('来源', this.sourceTags(item).length > 0 ? this.sourceTags(item).join(' / ') : '未知')
      if (item.category.length > 0) {
        this.DetailRow('分类', item.category)
      }
      if (item.distance.length > 0) {
        this.DetailRow('距离', item.distance)
      }
      this.DetailRow('地址', item.address.length > 0 ? item.address : '暂无地址')
      this.DetailRow('坐标', this.locationText(item).length > 0 ? this.locationText(item) : 'provider 未返回')
      if (this.navigationUnavailableText(item).length > 0) {
        Text(this.navigationUnavailableText(item))
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .lineHeight(18)
          .margin({ top: 8 })
      }
      if (this.foodNavigationStatus.length > 0) {
        Text(this.foodNavigationStatus)
          .fontSize(12)
          .fontColor(this.foodNavigationStatus.indexOf('失败') >= 0 || this.foodNavigationStatus.indexOf('缺少') >= 0 ? COLOR_ERROR : COLOR_ACCENT_DARK)
          .lineHeight(18)
          .margin({ top: 8 })
      }
      Button(this.canNavigate(item) ? '系统地图' : '地图不可用')
        .enabled(this.canNavigate(item) && !this.isBusy)
        .height(38)
        .width('100%')
        .fontSize(13)
        .fontColor(this.canNavigate(item) ? COLOR_BUTTON_TEXT : COLOR_MUTED)
        .backgroundColor(this.canNavigate(item) ? COLOR_ACCENT_DEEP : COLOR_CARD_RAISED)
        .borderRadius(10)
        .border({ width: 1, color: this.canNavigate(item) ? COLOR_ACCENT : COLOR_CARD_EDGE })
        .margin({ top: 10 })
        .onClick(() => {
          this.openFoodNavigation(item);
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 8 })
  }

  build() {
    Column() {
      A2uiPanelAccentView()

      Column() {
        Row() {
        Column() {
          Text(componentTitleOf(this.component, '附近餐饮'))
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_INK)
          if (componentBodyOf(this.component).length > 0) {
            Text(componentBodyOf(this.component))
              .fontSize(13)
              .fontColor(COLOR_MUTED)
              .lineHeight(20)
              .margin({ top: 7 })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        StatusBadgeView({
          status: componentStatusOf(this.component, this.surface.status),
          label: ''
        })
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        ActionBarView({
          actions: this.visibleActions(),
          isBusy: this.isBusy,
          onAction: (action: A2uiAction) => {
            this.handleAction(action);
          }
        })

      if (this.visibleFoods().length === 0 && this.foods().length > 0 && this.filterMode === 'within_1km') {
        Column() {
          Text('1 公里内暂无可展示店铺')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_INK)
          Text('当前结果里没有距离字段小于等于 1000 米的真实店铺。')
            .fontSize(13)
            .fontColor(COLOR_MUTED)
            .lineHeight(20)
            .margin({ top: 8 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(16)
        .backgroundColor(COLOR_CARD_INSET)
        .borderRadius(14)
        .border({ width: 1, color: COLOR_CARD_EDGE })
        .margin({ top: 10 })
      } else if (this.visibleFoods().length === 0) {
        Text('暂无可展示餐饮')
          .fontSize(13)
          .fontColor(COLOR_MUTED)
          .padding({ top: 14, bottom: 4 })
        } else {
          Column() {
            ForEach(this.visibleFoods(), (item: A2uiFoodOption) => {
          Column() {
            Column() {
              Row() {
                Text(item.name.length > 0 ? item.name : '未命名餐厅')
                  .fontSize(17)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(COLOR_INK)
                  .layoutWeight(1)
                if (item.distance.length > 0) {
                  Text(item.distance)
                    .fontSize(12)
                    .fontColor(COLOR_ACCENT_DARK)
                    .padding({ left: 9, right: 9, top: 5, bottom: 5 })
                    .backgroundColor(COLOR_ACCENT_SOFT)
                    .borderRadius(8)
                    .border({ width: 1, color: COLOR_ACCENT })
                }
              }
              .width('100%')

              if (this.sourceTags(item).length > 0) {
                Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
                  ForEach(this.sourceTags(item), (tag: string) => {
                    Text(tag)
                      .fontSize(11)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.sourceAccent(tag))
                      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                      .backgroundColor(this.sourceSoft(tag))
                      .borderRadius(7)
                      .border({ width: 1, color: this.sourceLine(tag) })
                      .margin({ right: 6, top: 7 })
                  }, (tag: string) => item.name + '-' + tag)
                }
                .width('100%')
              }

              if (item.category.length > 0) {
                Text(item.category)
                  .fontSize(12)
                  .fontColor(COLOR_MUTED)
                  .lineHeight(18)
                  .margin({ top: 6 })
              }

              Text(item.address.length > 0 ? item.address : '暂无地址')
                .fontSize(13)
                .fontColor(COLOR_TEXT)
                .lineHeight(19)
                .margin({ top: 7 })

              if (this.expandedFoodKey === this.foodRowKey(item)) {
                Row()
                  .width('100%')
                  .height(1)
                  .backgroundColor(FOOD_CARD_BORDER)
                  .margin({ top: 12 })

                this.FoodDetailPanel(item)
              }

              Row() {
                Text(this.expandedFoodKey === this.foodRowKey(item) ? '收起' : '详情')
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(COLOR_ACCENT_DARK)
                Blank()
                  .layoutWeight(1)
                if (this.expandedFoodKey === this.foodRowKey(item)) {
                  Text('只拉起路线规划，不下单不支付')
                    .fontSize(11)
                    .fontColor(COLOR_MUTED)
                    .textAlign(TextAlign.End)
                    .maxLines(2)
                } else if (this.canNavigate(item)) {
                  Text('可导航')
                    .fontSize(12)
                    .fontColor(COLOR_ACCENT_DARK)
                }
              }
              .width('100%')
              .alignItems(VerticalAlign.Bottom)
              .margin({ top: 10 })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(16)
            .backgroundColor(FOOD_CARD_BACKGROUND)
            .borderRadius(12)
            .border({ width: 1, color: this.cardBorder(item) })
            .onClick(() => {
              const rowKey = this.foodRowKey(item);
              this.expandedFoodKey = this.expandedFoodKey === rowKey ? '' : rowKey;
            })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .margin({ top: 10 })
          .transition(a2uiEnterTransition())
            }, (item: A2uiFoodOption) => this.foodRowKey(item) + '-' + this.renderTick.toString())
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 10, right: 10, bottom: 10 })
          .backgroundColor('#09090B')
          .borderRadius(14)
          .margin({ top: 12 })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: 17, bottom: 16 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(A2UI_PANEL_BACKGROUND_COLOR)
    .borderRadius(A2UI_PANEL_CORNER_RADIUS)
    .border({ width: 1, color: A2UI_PANEL_BORDER_COLOR })
    .shadow({ radius: 22, color: COLOR_CARD_GLOW, offsetX: 0, offsetY: 10 })
  }
}
