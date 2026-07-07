import {
  COLOR_ACCENT,
  COLOR_ACCENT_DEEP,
  COLOR_BUTTON_TEXT,
  COLOR_CARD_EDGE,
  COLOR_CARD_RAISED,
  COLOR_ERROR,
  COLOR_ERROR_LINE,
  COLOR_ERROR_SOFT,
  COLOR_FIELD,
  COLOR_GLASS,
  COLOR_INK,
  COLOR_LINE,
  COLOR_MUTED,
  COLOR_PAGE,
  COLOR_PANEL,
  COLOR_PANEL_SHADOW,
  COLOR_TEXT,
  statusBackground,
  statusColor
} from '../style/A2uiHomeTheme';
import { PersonaPack } from '../../../model/PersonaTypes';
import { parsePersonaMarkdown, PersonaMarkdownSection, PersonaSkillMarkdown } from '../../../model/PersonaMarkdown';
import { connectionStatusLabel } from '../state/A2uiHomeState';
import { DebugTextPanel } from './DebugTextPanel';
import { personaAvatarResource } from './PersonaAvatar';

@Component
export struct ConfigPage {
  @Link baseUrl: string;
  @Link apiKey: string;
  @Link selectedModel: string;
  @Link customParametersJson: string;
  @Link foodProviderDelayEnabled: boolean;
  @Link foodProviderDelayMs: string;
  @Link foodPartialThrottleMs: string;
  @Link showAdvancedSettings: boolean;
  @Prop connectionStatus: string = 'idle';
  @Prop connectionMessage: string = '';
  @Prop isBusy: boolean = false;
  @Prop lastModelRequest: string = '';
  @Prop lastModelOutput: string = '';
  @Prop lastError: string = '';
  @Prop refreshTick: number = 0;
  @Prop personaPacks: PersonaPack[] = [];
  @Link selectedPersonaId: string;
  @Link personaSoulDraft: string;
  @Link personaMemoryDraft: string;
  @Prop personaSaveMessage: string = '';
  @State editingPersonaDoc: string = '';
  onBack: () => void = () => {};
  onTestConnection: () => void = () => {};
  onOpenComposioAuth: () => void = () => {};
  onSelectPersona: (personaId: string) => void = (_personaId: string) => {};
  onSavePersona: () => void = () => {};
  onResetPersona: () => void = () => {};

  @Builder
  InputLabel(label: string, top: number) {
    Text(label)
      .fontSize(12)
      .fontColor(COLOR_MUTED)
      .margin({ top: top, bottom: 6 })
  }

  @Builder
  StatusBadge() {
    Text(connectionStatusLabel(this.connectionStatus))
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor(statusColor(this.connectionStatus))
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .backgroundColor(statusBackground(this.connectionStatus))
      .borderRadius(9)
      .border({ width: 1, color: statusColor(this.connectionStatus) })
  }

  private selectedPersona(): PersonaPack | null {
    for (let index = 0; index < this.personaPacks.length; index++) {
      if (this.personaPacks[index].manifest.id === this.selectedPersonaId) {
        return this.personaPacks[index];
      }
    }
    return this.personaPacks.length > 0 ? this.personaPacks[0] : null;
  }

  private sectionBody(sections: PersonaMarkdownSection[], title: string): string {
    for (let index = 0; index < sections.length; index++) {
      if (sections[index].title === title) {
        return sections[index].body.trim();
      }
    }
    return '';
  }

  private clipped(text: string): string {
    const value = text.trim();
    return value.length <= 160 ? value : value.substring(0, 160) + '...';
  }

  private selectedSoulSummary(): string {
    const pack = this.selectedPersona();
    const parsed = parsePersonaMarkdown(pack === null ? this.personaSoulDraft : pack.soul);
    const identity = this.sectionBody(parsed.sections, 'Identity');
    const behavior = this.sectionBody(parsed.sections, 'Behavior');
    const source = identity.length > 0 ? identity : (behavior.length > 0 ? behavior : parsed.body);
    return this.clipped(source);
  }

  private selectedMemorySummary(): string {
    const pack = this.selectedPersona();
    const parsed = parsePersonaMarkdown(pack === null ? this.personaMemoryDraft : pack.memory);
    const preferences = this.sectionBody(parsed.sections, 'Stable Preferences');
    const constraints = this.sectionBody(parsed.sections, 'Constraints');
    const source = preferences.length > 0 ? preferences : (constraints.length > 0 ? constraints : parsed.body);
    return this.clipped(source);
  }

  private selectedPersonaSkillList(): PersonaSkillMarkdown[] {
    const pack = this.selectedPersona();
    return pack === null ? [] : pack.skillList;
  }

  private selectPersonaPack(pack: PersonaPack): void {
    this.editingPersonaDoc = '';
    this.selectedPersonaId = pack.manifest.id;
    this.personaSoulDraft = pack.soul;
    this.personaMemoryDraft = pack.memory;
    this.onSelectPersona(pack.manifest.id);
  }

  private startEditingPersonaDoc(target: string): void {
    const pack = this.selectedPersona();
    if (pack !== null) {
      this.personaSoulDraft = pack.soul;
      this.personaMemoryDraft = pack.memory;
    }
    this.editingPersonaDoc = target;
  }

  private selectedSummary(target: string): string {
    return target === 'soul' ? this.selectedSoulSummary() : this.selectedMemorySummary();
  }

  private skillStatusLabel(skill: PersonaSkillMarkdown): string {
    return skill.status === 'active' ? '已加载' : '占位';
  }

  private skillToolsLabel(skill: PersonaSkillMarkdown): string {
    return skill.tools.length > 0 ? '工具：' + skill.tools.join(', ') : '工具：暂未接入';
  }

  @Builder
  PersonaChip(pack: PersonaPack) {
    Row() {
      Image(personaAvatarResource(pack.manifest.avatarKey))
        .width(24)
        .height(24)
        .objectFit(ImageFit.Contain)
      Text(pack.manifest.name)
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.selectedPersonaId === pack.manifest.id ? COLOR_BUTTON_TEXT : COLOR_INK)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ left: 4 })
        .layoutWeight(1)
    }
    .height(40)
    .width('30%')
    .padding({ left: 6, right: 6 })
    .backgroundColor(this.selectedPersonaId === pack.manifest.id ? COLOR_ACCENT_DEEP : COLOR_CARD_RAISED)
    .borderRadius(12)
    .border({ width: 1, color: this.selectedPersonaId === pack.manifest.id ? COLOR_ACCENT : COLOR_CARD_EDGE })
    .margin({ right: 8, bottom: 8 })
    .onClick(() => {
      this.selectPersonaPack(pack);
    })
  }

  @Builder
  SummaryBlock(label: string, target: string) {
    Column() {
      Row() {
        Text(label)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_ACCENT)
          .layoutWeight(1)
        Text(this.editingPersonaDoc === target ? '编辑中' : '点击编辑')
          .fontSize(11)
          .fontColor(COLOR_MUTED)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.selectedSummary(target).length > 0 ? this.selectedSummary(target) : '未记录')
        .fontSize(12)
        .fontColor(COLOR_TEXT)
        .lineHeight(18)
        .margin({ top: 6 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor(COLOR_CARD_RAISED)
    .borderRadius(10)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .margin({ bottom: 8 })
    .onClick(() => {
      this.startEditingPersonaDoc(target);
    })
  }

  @Builder
  PersonaSummaryStrip() {
    Column() {
      this.SummaryBlock('Soul 摘要', 'soul')
      this.SummaryBlock('Memory 摘要', 'memory')
    }
    .width('100%')
    .margin({ bottom: 14 })
  }

  @Builder
  PersonaEditorDraft() {
    if (this.editingPersonaDoc === 'soul') {
      this.InputLabel('soul.md', 0)
      TextArea({ text: this.personaSoulDraft, placeholder: '这个分身是谁，应该怎样说话' })
        .height(132)
        .fontSize(13)
        .fontColor(COLOR_TEXT)
        .placeholderColor(COLOR_MUTED)
        .backgroundColor(COLOR_FIELD)
        .borderRadius(9)
        .border({ width: 1, color: COLOR_CARD_EDGE })
        .padding({ left: 10, right: 10, top: 8, bottom: 8 })
        .onChange((value: string) => {
          this.personaSoulDraft = value;
        })
    }
    if (this.editingPersonaDoc === 'memory') {
      this.InputLabel('memory.md', 0)
      TextArea({ text: this.personaMemoryDraft, placeholder: '例如：用户咖啡偏好：只喝瑞幸咖啡。' })
        .height(132)
        .fontSize(13)
        .fontColor(COLOR_TEXT)
        .placeholderColor(COLOR_MUTED)
        .backgroundColor(COLOR_FIELD)
        .borderRadius(9)
        .border({ width: 1, color: COLOR_CARD_EDGE })
        .padding({ left: 10, right: 10, top: 8, bottom: 8 })
        .onChange((value: string) => {
          this.personaMemoryDraft = value;
        })
    }
  }

  @Builder
  SkillStatusBadge(skill: PersonaSkillMarkdown) {
    Text(this.skillStatusLabel(skill))
      .fontSize(11)
      .fontWeight(FontWeight.Medium)
      .fontColor(skill.status === 'active' ? COLOR_BUTTON_TEXT : COLOR_MUTED)
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .backgroundColor(skill.status === 'active' ? COLOR_ACCENT_DEEP : COLOR_FIELD)
      .borderRadius(8)
      .border({ width: 1, color: skill.status === 'active' ? COLOR_ACCENT : COLOR_CARD_EDGE })
  }

  @Builder
  SkillRow(skill: PersonaSkillMarkdown) {
    Column() {
      Row() {
        Column() {
          Text(skill.name)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_INK)
          Text(skill.description.length > 0 ? skill.description : '待补充描述')
            .fontSize(12)
            .fontColor(COLOR_MUTED)
            .lineHeight(17)
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        this.SkillStatusBadge(skill)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.skillToolsLabel(skill))
        .fontSize(11)
        .fontColor(COLOR_TEXT)
        .lineHeight(16)
        .margin({ top: 8 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor(skill.status === 'active' ? COLOR_GLASS : COLOR_CARD_RAISED)
    .borderRadius(10)
    .border({ width: 1, color: skill.status === 'active' ? COLOR_ACCENT : COLOR_CARD_EDGE })
    .margin({ top: 8 })
  }

  @Builder
  SkillChecklist() {
    Column() {
      Row() {
        Text('Skills（只读）')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_INK)
          .layoutWeight(1)
        Text('active + checklist')
          .fontSize(11)
          .fontColor(COLOR_MUTED)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ top: 14 })

      ForEach(this.selectedPersonaSkillList(), (skill: PersonaSkillMarkdown) => {
        this.SkillRow(skill)
      }, (skill: PersonaSkillMarkdown) => skill.id + '_' + skill.status)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  PersonaEditorSection() {
    Column() {
      Row() {
        Column() {
          Text('数字分身')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_INK)
          Text('编辑 soul 和 memory；skills 只读。保存后下一次请求立即使用。')
            .fontSize(13)
            .fontColor(COLOR_MUTED)
            .lineHeight(19)
            .margin({ top: 8 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        if (this.personaSaveMessage.length > 0) {
          Text(this.personaSaveMessage)
            .fontSize(12)
            .fontColor(COLOR_ACCENT)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 14 })

      Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
        ForEach(this.personaPacks, (pack: PersonaPack) => {
          this.PersonaChip(pack)
        }, (pack: PersonaPack) => pack.manifest.id)
      }
      .width('100%')
      .margin({ bottom: 10 })

      this.PersonaSummaryStrip()
      this.PersonaEditorDraft()

      Row() {
        Button('保存')
          .height(40)
          .layoutWeight(1)
          .fontSize(13)
          .fontColor(COLOR_BUTTON_TEXT)
          .backgroundColor(COLOR_ACCENT_DEEP)
          .borderRadius(10)
          .border({ width: 1, color: COLOR_ACCENT })
          .onClick(() => {
            this.onSavePersona();
          })
        Button('恢复默认')
          .height(40)
          .layoutWeight(1)
          .fontSize(13)
          .fontColor(COLOR_INK)
          .backgroundColor(COLOR_CARD_RAISED)
          .borderRadius(10)
          .border({ width: 1, color: COLOR_CARD_EDGE })
          .margin({ left: 8 })
          .onClick(() => {
            this.onResetPersona();
          })
      }
      .width('100%')
      .margin({ top: this.editingPersonaDoc.length > 0 ? 14 : 0, bottom: 12 })

      this.SkillChecklist()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(18)
    .backgroundColor(COLOR_PANEL)
    .borderRadius(16)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .shadow({ radius: 22, color: COLOR_PANEL_SHADOW, offsetX: 0, offsetY: 10 })
    .margin({ bottom: 14 })
  }

  build() {
    Scroll() {
      Column() {
        Row() {
          Button('返回')
            .height(40)
            .width(76)
            .fontSize(13)
            .fontColor(COLOR_INK)
            .backgroundColor(COLOR_CARD_RAISED)
            .borderRadius(10)
            .border({ width: 1, color: COLOR_CARD_EDGE })
            .onClick(() => {
              this.onBack();
            })

          Column() {
            Text('配置')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor(COLOR_INK)
            Text('测试模型连接，并观察本页状态是否实时刷新')
              .fontSize(13)
              .fontColor(COLOR_MUTED)
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 12 })
          .layoutWeight(1)

          this.StatusBadge()
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ bottom: 16 })

        this.PersonaEditorSection()

        Column() {
          Text('模型连接')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_INK)
          Text('这里是最小刷新实验：点击测试连接后，状态、错误、请求和响应面板应立即更新，不需要切页。')
            .fontSize(13)
            .fontColor(COLOR_MUTED)
            .lineHeight(19)
            .margin({ top: 8, bottom: 14 })

          if (this.lastError.length > 0) {
            Column() {
              Text('最近异常')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(COLOR_ERROR)
              Text(this.lastError)
                .fontSize(12)
                .fontColor(COLOR_TEXT)
                .lineHeight(18)
                .margin({ top: 6 })
            }
            .width('100%')
            .padding(12)
            .alignItems(HorizontalAlign.Start)
            .backgroundColor(COLOR_ERROR_SOFT)
            .borderRadius(10)
            .border({ width: 1, color: COLOR_ERROR_LINE })
            .margin({ bottom: 14 })
          }

          Row() {
            Button('云端 Qwen Max')
              .height(36)
              .layoutWeight(1)
              .fontSize(11)
              .fontColor(COLOR_BUTTON_TEXT)
              .backgroundColor(COLOR_ACCENT_DEEP)
              .borderRadius(9)
              .border({ width: 1, color: COLOR_ACCENT })
              .margin({ right: 8 })
              .onClick(() => {
                this.baseUrl = 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions';
                this.selectedModel = 'qwen-max';
                this.customParametersJson = '{"enable_thinking":false}';
              })
            Button('本地 Qwen')
              .height(36)
              .layoutWeight(1)
              .fontSize(11)
              .fontColor(COLOR_INK)
              .backgroundColor(COLOR_CARD_RAISED)
              .borderRadius(9)
              .border({ width: 1, color: COLOR_CARD_EDGE })
              .onClick(() => {
                this.baseUrl = 'http://127.0.0.1:11434';
                this.selectedModel = 'Qwen3-8B';
                this.customParametersJson = '';
              })
          }
          .width('100%')
          .margin({ bottom: 14 })

          Button('Composio 授权')
            .height(36)
            .width('100%')
            .fontSize(12)
            .fontColor(COLOR_INK)
            .backgroundColor(COLOR_CARD_RAISED)
            .borderRadius(9)
            .border({ width: 1, color: COLOR_CARD_EDGE })
            .margin({ bottom: 14 })
            .onClick(() => {
              this.onOpenComposioAuth();
            })

          this.InputLabel('Model', 0)
          TextInput({ text: this.selectedModel, placeholder: 'qwen-max' })
            .height(42)
            .fontSize(13)
            .fontColor(COLOR_TEXT)
            .placeholderColor(COLOR_MUTED)
            .backgroundColor(COLOR_FIELD)
            .borderRadius(9)
            .border({ width: 1, color: COLOR_CARD_EDGE })
            .padding({ left: 10, right: 10 })
            .onChange((value: string) => {
              this.selectedModel = value;
            })

          this.InputLabel('Base URL', 12)
          TextInput({ text: this.baseUrl, placeholder: 'http://127.0.0.1:11434' })
            .height(42)
            .fontSize(13)
            .fontColor(COLOR_TEXT)
            .placeholderColor(COLOR_MUTED)
            .backgroundColor(COLOR_FIELD)
            .borderRadius(9)
            .border({ width: 1, color: COLOR_CARD_EDGE })
            .padding({ left: 10, right: 10 })
            .onChange((value: string) => {
              this.baseUrl = value;
            })

          Row() {
            Text('高级设置')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(COLOR_INK)
              .layoutWeight(1)
            Text(this.showAdvancedSettings ? '收起' : '展开')
              .fontSize(12)
              .fontColor(COLOR_ACCENT)
          }
          .width('100%')
          .padding({ top: 14, bottom: 10 })
          .onClick(() => {
            this.showAdvancedSettings = !this.showAdvancedSettings;
          })

          if (this.showAdvancedSettings) {
            this.InputLabel('API Key（可选）', 0)
            TextInput({ text: this.apiKey, placeholder: '如果接口要求鉴权，在这里填写' })
              .height(42)
              .fontSize(13)
              .fontColor(COLOR_TEXT)
              .placeholderColor(COLOR_MUTED)
              .backgroundColor(COLOR_FIELD)
              .borderRadius(9)
              .border({ width: 1, color: COLOR_CARD_EDGE })
              .padding({ left: 10, right: 10 })
              .onChange((value: string) => {
                this.apiKey = value;
              })

            this.InputLabel('自定义请求参数 JSON（可选）', 12)
            TextInput({ text: this.customParametersJson, placeholder: '{"enable_thinking":false}' })
              .height(42)
              .fontSize(13)
              .fontColor(COLOR_TEXT)
              .placeholderColor(COLOR_MUTED)
              .backgroundColor(COLOR_FIELD)
              .borderRadius(9)
              .border({ width: 1, color: COLOR_CARD_EDGE })
              .padding({ left: 10, right: 10 })
              .onChange((value: string) => {
                this.customParametersJson = value;
              })

            Divider()
              .color(COLOR_LINE)
              .margin({ top: 16, bottom: 12 })

            Row() {
              Column() {
                Text('餐饮来源延时')
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(COLOR_INK)
                Text('开启后延迟非首个餐饮来源，用于观察分步返回')
                  .fontSize(12)
                  .fontColor(COLOR_MUTED)
                  .margin({ top: 4 })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              Toggle({ type: ToggleType.Switch, isOn: this.foodProviderDelayEnabled })
                .selectedColor(COLOR_ACCENT)
                .onChange((isOn: boolean) => {
                  this.foodProviderDelayEnabled = isOn;
                })
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)

            this.InputLabel('延时毫秒', 12)
            TextInput({ text: this.foodProviderDelayMs, placeholder: '5000' })
              .height(42)
              .fontSize(13)
              .fontColor(COLOR_TEXT)
              .placeholderColor(COLOR_MUTED)
              .backgroundColor(COLOR_FIELD)
              .borderRadius(9)
              .border({ width: 1, color: COLOR_CARD_EDGE })
              .padding({ left: 10, right: 10 })
              .enabled(this.foodProviderDelayEnabled)
              .opacity(this.foodProviderDelayEnabled ? 1 : 0.55)
              .onChange((value: string) => {
                this.foodProviderDelayMs = value;
              })

            this.InputLabel('局部更新间隔（毫秒）', 12)
            TextInput({ text: this.foodPartialThrottleMs, placeholder: '500' })
              .height(42)
              .fontSize(13)
              .fontColor(COLOR_TEXT)
              .placeholderColor(COLOR_MUTED)
              .backgroundColor(COLOR_FIELD)
              .borderRadius(9)
              .border({ width: 1, color: COLOR_CARD_EDGE })
              .padding({ left: 10, right: 10 })
              .onChange((value: string) => {
                this.foodPartialThrottleMs = value;
              })
          }

          Button(this.isBusy ? '检查中' : '测试连接')
            .enabled(!this.isBusy)
            .height(44)
            .width('100%')
            .fontSize(15)
            .fontColor(COLOR_BUTTON_TEXT)
            .backgroundColor(COLOR_ACCENT_DEEP)
            .borderRadius(11)
            .border({ width: 1, color: COLOR_ACCENT })
            .margin({ top: 16 })
            .onClick(() => {
              this.onTestConnection();
            })

          Divider()
            .color(COLOR_LINE)
            .margin({ top: 16, bottom: 14 })

          Row() {
            Text('面板刷新计数')
              .fontSize(12)
              .fontColor(COLOR_MUTED)
            Text(this.refreshTick.toString())
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(COLOR_ACCENT)
              .margin({ left: 8 })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Text(this.connectionMessage)
            .fontSize(13)
            .fontColor(COLOR_TEXT)
            .lineHeight(20)
            .margin({ top: 10 })

          DebugTextPanel({
            label: '模型请求',
            value: this.lastModelRequest,
            refreshTick: this.refreshTick
          })
          DebugTextPanel({
            label: '模型输出',
            value: this.lastModelOutput,
            refreshTick: this.refreshTick
          })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(18)
        .backgroundColor(COLOR_PANEL)
        .borderRadius(16)
        .border({ width: 1, color: COLOR_CARD_EDGE })
        .shadow({ radius: 22, color: COLOR_PANEL_SHADOW, offsetX: 0, offsetY: 10 })
      }
      .width('100%')
      .padding(16)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_PAGE)
  }
}
