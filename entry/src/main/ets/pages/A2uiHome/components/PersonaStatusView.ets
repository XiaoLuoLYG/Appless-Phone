import { A2uiPersonaData, A2uiPersonaMemoryData } from '@loop/agent-core';
import {
  COLOR_ACCENT_SOFT,
  COLOR_CARD_EDGE,
  COLOR_FIELD,
  COLOR_INK
} from '../style/A2uiHomeTheme';
import { personaAvatarResource } from './PersonaAvatar';

@Component
export struct PersonaStatusView {
  @Prop persona: A2uiPersonaData = { id: '', name: '', avatarKey: '', status: '', reason: '' };
  @Prop personaMemory: A2uiPersonaMemoryData = { summary: '', preferences: [] };

  private titleText(): string {
    return this.persona.name.length > 0 ? this.persona.name + '上线' : '';
  }

  build() {
    if (this.persona.id.length > 0) {
      Row() {
        Image(personaAvatarResource(this.persona.avatarKey))
          .width(38)
          .height(38)
          .objectFit(ImageFit.Contain)
          .backgroundColor(COLOR_ACCENT_SOFT)
          .borderRadius(14)
          .padding(5)
        Column() {
          Text(this.titleText())
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_INK)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 10 })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .backgroundColor(COLOR_FIELD)
      .borderRadius(16)
      .border({ width: 1, color: COLOR_CARD_EDGE })
      .margin({ bottom: 12 })
    }
  }
}
