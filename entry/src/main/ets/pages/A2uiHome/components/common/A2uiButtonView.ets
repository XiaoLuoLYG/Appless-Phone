import {
  A2UI_CIRCLE_BUTTON_BACKGROUND,
  A2UI_CIRCLE_BUTTON_BORDER,
  A2UI_CIRCLE_BUTTON_ICON_SIZE,
  A2UI_CIRCLE_BUTTON_SIZE,
  A2uiButtonVisualStyle,
  resolveA2uiButtonColor,
  resolveA2uiButtonStyle
} from '../../style/A2uiButtonStyle';

@Component
export struct A2uiButtonView {
  @Prop label: string = '';
  @Prop icon: Resource = $r('app.media.startIcon');
  @Prop hasIcon: boolean = false;
  @Prop shape: string = 'pill';
  @Prop tone: string = 'secondary';
  @Prop active: boolean = false;
  @Prop isEnabled: boolean = true;
  @Prop fill: boolean = false;
  @Prop circleSize: number = A2UI_CIRCLE_BUTTON_SIZE;
  @Prop iconSize: number = 0;
  @Prop customBackgroundColor: string = '';
  @Prop customBorderColor: string = '';
  @Prop customBorderWidth: number = 1;
  @Prop shadowColor: string = '';
  @Prop shadowRadius: number = 0;
  @Prop shadowOffsetY: number = 0;
  @Prop iconRotation: number = 0;

  private visualStyle(): A2uiButtonVisualStyle {
    return resolveA2uiButtonStyle(this.tone, this.active, this.isEnabled);
  }

  private resolvedIconSize(): number {
    if (this.iconSize > 0) {
      return this.iconSize;
    }
    return this.shape === 'circle' ? A2UI_CIRCLE_BUTTON_ICON_SIZE : 20;
  }

  private circleBackgroundColor(style: A2uiButtonVisualStyle): string {
    if (this.customBackgroundColor.length > 0) {
      return this.customBackgroundColor;
    }
    if (this.active || this.tone !== 'secondary' || !this.isEnabled) {
      return style.backgroundColor;
    }
    return A2UI_CIRCLE_BUTTON_BACKGROUND;
  }

  private circleBorderColor(style: A2uiButtonVisualStyle): string {
    if (this.customBorderColor.length > 0) {
      return this.customBorderColor;
    }
    if (this.active || this.tone !== 'secondary' || !this.isEnabled) {
      return style.borderColor;
    }
    return A2UI_CIRCLE_BUTTON_BORDER;
  }

  @Builder
  private Content(style: A2uiButtonVisualStyle) {
    if (this.hasIcon) {
      Image(this.icon)
        .width(this.resolvedIconSize())
        .height(this.resolvedIconSize())
        .objectFit(ImageFit.Contain)
        .rotate({ angle: this.iconRotation })
    } else {
      Text(this.label)
        .fontSize(this.shape === 'circle' ? 12 : 13)
        .fontWeight(FontWeight.Medium)
        .fontColor(style.textColor)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
  }

  build() {
    if (this.shape === 'circle') {
      Stack() {
        this.Content(this.visualStyle())
      }
      .width(this.circleSize)
      .height(this.circleSize)
      .backgroundColor(this.circleBackgroundColor(this.visualStyle()))
      .borderRadius(this.circleSize / 2)
      .border({ width: this.customBorderWidth, color: this.circleBorderColor(this.visualStyle()) })
      .shadow({
        radius: this.shadowRadius,
        color: resolveA2uiButtonColor(this.shadowColor, '#00000000'),
        offsetX: 0,
        offsetY: this.shadowOffsetY
      })
      .opacity(this.visualStyle().opacity)
      .animation({ duration: 120, curve: Curve.EaseOut })
    } else if (this.fill) {
      Stack() {
        this.Content(this.visualStyle())
      }
      .width('100%')
      .height(40)
      .padding({ left: 14, right: 14 })
      .backgroundColor(this.visualStyle().backgroundColor)
      .borderRadius(12)
      .border({ width: 1, color: this.visualStyle().borderColor })
      .opacity(this.visualStyle().opacity)
      .animation({ duration: 120, curve: Curve.EaseOut })
    } else {
      Stack() {
        this.Content(this.visualStyle())
      }
      .height(38)
      .padding({ left: 14, right: 14 })
      .backgroundColor(this.visualStyle().backgroundColor)
      .borderRadius(11)
      .border({ width: 1, color: this.visualStyle().borderColor })
      .opacity(this.visualStyle().opacity)
      .animation({ duration: 120, curve: Curve.EaseOut })
    }
  }
}
