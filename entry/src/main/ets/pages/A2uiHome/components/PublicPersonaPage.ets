import {
  PublicPersonaCandidate,
  PublicPersonaPhase,
  PublicPersonaPlatform,
  PublicPersonaProgress,
  PublicPersonaSnapshot,
  PublicPersonaSourceRef,
  publicPersonaPreviewMarkdown
} from '../../../publicpersona/PublicPersonaModel';
import {
  COLOR_ACCENT,
  COLOR_ACCENT_SOFT,
  COLOR_CARD,
  COLOR_CARD_EDGE,
  COLOR_ERROR,
  COLOR_ERROR_SOFT,
  COLOR_INK,
  COLOR_MUTED,
  COLOR_PANEL,
  COLOR_TEXT,
  COLOR_WARNING,
  COLOR_WARNING_SOFT
} from '../style/A2uiHomeTheme';
import {
  A2UI_MOTION_CURVE,
  A2UI_MOTION_MOVE_CURVE,
  A2UI_MOTION_NORMAL_MS
} from '../style/A2uiHomeMotion';

@Component
export struct PublicPersonaPage {
  @Prop phase: PublicPersonaPhase = 'input';
  @Prop candidates: PublicPersonaCandidate[] = [];
  @Prop progress: PublicPersonaProgress | null = null;
  @Prop snapshot: PublicPersonaSnapshot | null = null;
  @Prop errorMessage: string = '';
  @State profileUrl: string = '';
  @State possibleExpanded: boolean = false;
  @State selectedIds: string[] = [];
  @State selectionTouched: boolean = false;
  @State editingMarkdown: boolean = false;
  @State draftMarkdown: string = '';
  @State mbtiMenuOpen: boolean = false;
  @State deleteConfirm: boolean = false;

  onBack: () => void = () => {};
  onChooseSetup: () => void = () => {};
  onSkip: () => void = () => {};
  onStartDiscovery: (profileUrl: string) => void = (_profileUrl: string): void => {};
  onConfirm: (candidateIds: string[]) => void = (_candidateIds: string[]): void => {};
  onSaveMarkdown: (markdown: string) => boolean = (_markdown: string): boolean => false;
  onReinferMbti: () => void = () => {};
  onSetMbtiHidden: (hidden: boolean) => void = (_hidden: boolean): void => {};
  onDelete: () => boolean = (): boolean => false;

  private platformLabel(platform: PublicPersonaPlatform): string {
    switch (platform) {
      case 'bilibili': return '哔哩哔哩';
      case 'zhihu': return '知乎';
      case 'weibo': return '微博';
      case 'xiaohongshu': return '小红书';
      case 'douyin': return '抖音';
      case 'github': return 'GitHub';
      case 'x': return 'X';
      case 'youtube': return 'YouTube';
      case 'linkedin': return 'LinkedIn';
      case 'reddit': return 'Reddit';
      case 'instagram': return 'Instagram';
    }
  }

  private platformLogo(platform: PublicPersonaPlatform): Resource {
    switch (platform) {
      case 'bilibili': return $r('app.media.logo_bilibili');
      case 'zhihu': return $r('app.media.logo_zhihu');
      case 'weibo': return $r('app.media.logo_weibo');
      case 'xiaohongshu': return $r('app.media.logo_xiaohongshu');
      case 'douyin': return $r('app.media.logo_douyin');
      case 'github': return $r('app.media.logo_github');
      case 'x': return $r('app.media.logo_x');
      case 'youtube': return $r('app.media.logo_youtube');
      case 'linkedin': return $r('app.media.logo_linkedin');
      case 'reddit': return $r('app.media.logo_reddit');
      case 'instagram': return $r('app.media.logo_instagram');
    }
  }

  private highCandidates(): PublicPersonaCandidate[] {
    return this.candidates.filter((candidate: PublicPersonaCandidate): boolean => candidate.ownershipBand === 'high');
  }

  private possibleCandidates(): PublicPersonaCandidate[] {
    return this.candidates.filter((candidate: PublicPersonaCandidate): boolean => candidate.ownershipBand === 'possible');
  }

  private isSelected(candidate: PublicPersonaCandidate): boolean {
    return this.selectionTouched ? this.selectedIds.indexOf(candidate.id) >= 0 : candidate.selected;
  }

  private toggleCandidate(candidate: PublicPersonaCandidate): void {
    if (!this.selectionTouched) {
      this.selectedIds = this.candidates
        .filter((item: PublicPersonaCandidate): boolean => item.selected)
        .map((item: PublicPersonaCandidate): string => item.id);
      this.selectionTouched = true;
    }
    const index = this.selectedIds.indexOf(candidate.id);
    if (index >= 0) {
      this.selectedIds.splice(index, 1);
    } else {
      this.selectedIds.push(candidate.id);
    }
    this.selectedIds = this.selectedIds.slice();
  }

  private selectedCandidateIds(): string[] {
    if (this.selectionTouched) {
      return this.selectedIds.slice();
    }
    return this.candidates
      .filter((candidate: PublicPersonaCandidate): boolean => candidate.selected)
      .map((candidate: PublicPersonaCandidate): string => candidate.id);
  }

  private sourceUsername(source: PublicPersonaSourceRef): string {
    const value = source.profileUrl.substring(source.profileUrl.lastIndexOf('/') + 1);
    return value.replace(/^@/, '').trim();
  }

  private mbtiLine(markdown: string): string {
    const lines = markdown.replace(/\r\n/g, '\n').split('\n');
    for (let index = 0; index < lines.length; index++) {
      if (/^[EI][NS][TF][JP] · [0-9]+%/.test(lines[index])) {
        return lines[index];
      }
    }
    return 'MBTI 暂无';
  }

  private progressText(): string {
    if (this.progress === null) {
      return this.phase === 'discovering' ? '正在检查公开主页…' : '正在整理已确认账号…';
    }
    return this.progress.message + '  ' + this.progress.completed.toString() + '/' + this.progress.total.toString();
  }

  private providerFailureMessage(): string {
    if (this.progress === null) {
      return '';
    }
    switch (this.progress.state) {
      case 'needs_auth': return '公开资料服务需要配置或授权，当前没有读取任何主页。';
      case 'blocked_by_site': return '目标站点暂时限制公开读取，当前没有确认账号。';
      case 'rate_limited': return '公开资料服务触发频率限制，请稍后重试。';
      case 'credits_exhausted': return '公开资料服务额度不足，当前没有读取任何主页。';
      case 'timeout': return '公开资料读取超时，当前没有确认账号。';
      case 'error': return '公开资料服务调用失败，当前没有确认账号。';
      default: return '';
    }
  }

  private markdownForEdit(): string {
    if (this.draftMarkdown.length > 0) {
      return this.draftMarkdown;
    }
    return this.snapshot === null ? '' : this.snapshot.personaMarkdown;
  }

  @Builder
  private Header(title: string, subtitle: string = '') {
    Row() {
      Button('返回')
        .height(38)
        .width(72)
        .fontSize(13)
        .fontColor(COLOR_INK)
        .backgroundColor(COLOR_CARD)
        .borderRadius(10)
        .border({ width: 1, color: COLOR_CARD_EDGE })
        .animation({ duration: 120, curve: A2UI_MOTION_CURVE })
        .onClick(() => {
          this.onBack();
        })

      Column() {
        Text(title)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_INK)
        if (subtitle.length > 0) {
          Text(subtitle)
            .fontSize(12)
            .fontColor(COLOR_MUTED)
            .margin({ top: 3 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .margin({ bottom: 16 })
  }

  @Builder
  private PlatformBadge(platform: PublicPersonaPlatform) {
    Stack({ alignContent: Alignment.Center }) {
      Image(this.platformLogo(platform))
        .width(20)
        .height(20)
        .objectFit(ImageFit.Contain)
    }
    .width(28)
    .height(28)
    .backgroundColor(COLOR_CARD)
    .borderRadius(8)
    .border({ width: 1, color: COLOR_CARD_EDGE })
  }

  @Builder
  private AccountRow(candidate: PublicPersonaCandidate) {
    Row() {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Image(candidate.avatarUrl)
          .width(44)
          .height(44)
          .objectFit(ImageFit.Cover)
          .borderRadius(22)
        this.PlatformBadge(candidate.platform)
      }
      Column() {
        Text(candidate.displayName)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_INK)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text('@' + candidate.username.replace(/^@/, '') + '  ·  ' + this.platformLabel(candidate.platform))
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .margin({ top: 4 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 10, right: 10 })
      Text(this.isSelected(candidate) ? '已选' : '选择')
        .fontSize(12)
        .fontColor(this.isSelected(candidate) ? COLOR_ACCENT : COLOR_MUTED)
        .padding({ left: 10, right: 10, top: 7, bottom: 7 })
        .backgroundColor(this.isSelected(candidate) ? COLOR_ACCENT_SOFT : COLOR_PANEL)
        .borderRadius(9)
    }
    .width('100%')
    .padding(12)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(COLOR_CARD)
    .borderRadius(12)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .onClick(() => {
      this.toggleCandidate(candidate);
    })
    .animation({ duration: 120, curve: A2UI_MOTION_CURVE })
    .margin({ bottom: 8 })
  }

  @Builder
  private SourceRow(source: PublicPersonaSourceRef) {
    Row() {
      Image(source.avatarUrl)
        .width(34)
        .height(34)
        .objectFit(ImageFit.Cover)
        .borderRadius(17)
      this.PlatformBadge(source.platform)
      Column() {
        Text(this.platformLabel(source.platform))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_INK)
        Text('@' + this.sourceUsername(source))
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text('已确认')
        .fontSize(11)
        .fontColor(COLOR_ACCENT)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  @Builder
  private WelcomeView() {
    this.Header('我的画像', '只读取你主动确认的公开账号')
    Column() {
      Text('相见如故')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_INK)
      Text('从公开资料开始，整理一份可以查看和编辑的 persona.md。账号会先展示给你确认，未确认的资料不会被读取。')
        .fontSize(14)
        .fontColor(COLOR_TEXT)
        .lineHeight(22)
        .margin({ top: 12, bottom: 20 })
      Button('开始设置')
        .width('100%')
        .height(46)
        .fontSize(15)
        .fontColor(Color.White)
        .backgroundColor(COLOR_ACCENT)
        .borderRadius(12)
        .animation({ duration: 120, curve: A2UI_MOTION_CURVE })
        .onClick(() => {
          this.onChooseSetup();
        })
      Button('先跳过')
        .width('100%')
        .height(42)
        .fontSize(13)
        .fontColor(COLOR_MUTED)
        .backgroundColor(COLOR_PANEL)
        .borderRadius(12)
        .margin({ top: 8 })
        .onClick(() => {
          this.onSkip();
        })
    }
    .width('100%')
    .padding(20)
    .backgroundColor(COLOR_CARD)
    .borderRadius(16)
    .border({ width: 1, color: COLOR_CARD_EDGE })
  }

  @Builder
  private InputView() {
    this.Header('找到你的公开账号', '输入一个你愿意公开确认的主页链接')
    Column() {
      Text('从一个公开主页开始即可')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_INK)
      Text('我们会检查 11 个公开平台，只展示能够确认真实头像、名称、用户名和主页链接的账号。')
        .fontSize(13)
        .fontColor(COLOR_MUTED)
        .lineHeight(20)
        .margin({ top: 7, bottom: 16 })
      TextInput({ placeholder: '例如 https://github.com/username', text: this.profileUrl })
        .width('100%')
        .height(48)
        .fontSize(14)
        .fontColor(COLOR_TEXT)
        .backgroundColor(COLOR_PANEL)
        .borderRadius(11)
        .border({ width: 1, color: COLOR_CARD_EDGE })
        .padding({ left: 12, right: 12 })
        .onChange((value: string) => {
          this.profileUrl = value;
        })
      Button('开始查找')
        .width('100%')
        .height(46)
        .fontSize(15)
        .fontColor(Color.White)
        .backgroundColor(COLOR_ACCENT)
        .borderRadius(12)
        .enabled(this.profileUrl.trim().length > 0)
        .margin({ top: 14 })
        .onClick(() => {
          this.selectionTouched = false;
          this.selectedIds = [];
          this.possibleExpanded = false;
          this.onStartDiscovery(this.profileUrl.trim());
        })
      Text('只读取公开页面，不会尝试登录或绕过站点限制。')
        .fontSize(12)
        .fontColor(COLOR_MUTED)
        .margin({ top: 12 })
    }
    .width('100%')
    .padding(20)
    .backgroundColor(COLOR_CARD)
    .borderRadius(16)
    .border({ width: 1, color: COLOR_CARD_EDGE })
  }

  @Builder
  private BusyView() {
    this.Header(this.phase === 'discovering' ? '正在查找公开账号' : '正在整理你的画像', '页面可以随时返回，任务会在后台继续')
    Column() {
      Row() {
        Circle({ width: 10, height: 10 })
          .fill(COLOR_ACCENT)
        Text(this.progressText())
          .fontSize(14)
          .fontColor(COLOR_TEXT)
          .margin({ left: 10 })
      }
      .width('100%')
      .padding({ top: 6, bottom: 14 })
      Text(this.phase === 'discovering' ? '正在逐个平台确认公开资料。' : '只会读取你在上一步确认的账号。')
        .fontSize(13)
        .fontColor(COLOR_MUTED)
        .lineHeight(20)
    }
    .width('100%')
    .padding(20)
    .backgroundColor(COLOR_CARD)
    .borderRadius(16)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .animation({ duration: A2UI_MOTION_NORMAL_MS, curve: A2UI_MOTION_MOVE_CURVE })
  }

  @Builder
  private ConfirmationView() {
    this.Header('确认这些账号', '只选择你能确认属于自己的账号')
    Column() {
      if (this.highCandidates().length > 0) {
        Text('可以确认 · ' + this.highCandidates().length.toString())
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_INK)
          .margin({ bottom: 9 })
        ForEach(this.highCandidates(), (candidate: PublicPersonaCandidate) => {
          this.AccountRow(candidate)
        }, (candidate: PublicPersonaCandidate) => candidate.id)
      }
      if (this.progress !== null && this.progress.completed >= this.progress.total) {
        Text('已检查 ' + this.progress.total.toString() + ' 个公开平台')
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .margin({ top: 2, bottom: 8 })
      }
      if (this.possibleCandidates().length > 0) {
        Row() {
          Column() {
            Text('可能是你 · ' + this.possibleCandidates().length.toString())
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(COLOR_TEXT)
            Text('折叠显示，点开后自行判断')
              .fontSize(12)
              .fontColor(COLOR_MUTED)
              .margin({ top: 3 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Text(this.possibleExpanded ? '收起' : '展开')
            .fontSize(12)
            .fontColor(COLOR_ACCENT)
        }
        .width('100%')
        .padding({ top: 12, bottom: 10 })
        .onClick(() => {
          this.possibleExpanded = !this.possibleExpanded;
        })
        if (this.possibleExpanded) {
          ForEach(this.possibleCandidates(), (candidate: PublicPersonaCandidate) => {
            this.AccountRow(candidate)
          }, (candidate: PublicPersonaCandidate) => candidate.id)
        }
      }
      if (this.candidates.length === 0) {
        if (this.providerFailureMessage().length > 0) {
          Text(this.providerFailureMessage())
            .fontSize(13)
            .fontColor(COLOR_WARNING)
            .lineHeight(20)
            .padding(16)
        }
        Text('暂时没有能确认的公开账号。')
          .fontSize(14)
          .fontColor(COLOR_MUTED)
          .padding(16)
        Button('重新输入')
          .width('100%')
          .height(44)
          .fontSize(14)
          .fontColor(COLOR_INK)
          .backgroundColor(COLOR_PANEL)
          .borderRadius(11)
          .onClick(() => {
            this.onChooseSetup();
          })
      } else {
        Button('确认并生成画像')
          .width('100%')
          .height(46)
          .fontSize(15)
          .fontColor(Color.White)
          .backgroundColor(COLOR_ACCENT)
          .borderRadius(12)
          .enabled(this.selectedCandidateIds().length > 0)
          .margin({ top: 8 })
          .onClick(() => {
            this.onConfirm(this.selectedCandidateIds());
          })
      }
    }
    .width('100%')
    .padding(18)
    .backgroundColor(COLOR_CARD)
    .borderRadius(16)
    .border({ width: 1, color: COLOR_CARD_EDGE })
  }

  @Builder
  private ErrorView() {
    this.Header('这次没有完成', '公开资料可能暂时不可读')
    Column() {
      Text(this.errorMessage.length > 0 ? this.errorMessage : '请稍后重试。')
        .fontSize(14)
        .fontColor(COLOR_ERROR)
        .lineHeight(21)
        .padding(16)
        .backgroundColor(COLOR_ERROR_SOFT)
        .borderRadius(12)
      Button('重新开始')
        .width('100%')
        .height(44)
        .fontSize(14)
        .fontColor(COLOR_INK)
        .backgroundColor(COLOR_PANEL)
        .borderRadius(11)
        .margin({ top: 12 })
        .onClick(() => {
          this.onChooseSetup();
        })
    }
    .width('100%')
    .padding(18)
    .backgroundColor(COLOR_CARD)
    .borderRadius(16)
    .border({ width: 1, color: COLOR_CARD_EDGE })
  }

  @Builder
  private CompleteView() {
    if (this.snapshot === null) {
      this.ErrorView()
    } else {
      this.CompleteContent(this.snapshot)
    }
  }

  @Builder
  private CompleteContent(snapshot: PublicPersonaSnapshot) {
    this.Header('你的画像', '可查看、编辑，也可以随时删除')
    Column() {
      Image(snapshot.primaryAvatarUrl)
        .width(78)
        .height(78)
        .objectFit(ImageFit.Cover)
        .borderRadius(39)
        .border({ width: 2, color: COLOR_CARD_EDGE })
      Text('公开资料画像')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_INK)
        .margin({ top: 12 })
      if (!snapshot.mbtiHidden) {
        Row() {
          Text(this.mbtiLine(snapshot.personaMarkdown))
            .fontSize(13)
            .fontColor(COLOR_ACCENT)
          Text('  ›')
            .fontSize(14)
            .fontColor(COLOR_MUTED)
        }
        .padding({ left: 10, right: 10, top: 7, bottom: 7 })
        .backgroundColor(COLOR_ACCENT_SOFT)
        .borderRadius(9)
        .margin({ top: 10 })
        .onClick(() => {
          this.mbtiMenuOpen = !this.mbtiMenuOpen;
        })
        if (this.mbtiMenuOpen) {
          Row() {
            Button('重新推测')
              .height(34)
              .fontSize(12)
              .fontColor(COLOR_INK)
              .backgroundColor(COLOR_PANEL)
              .borderRadius(8)
              .onClick(() => {
                this.mbtiMenuOpen = false;
                this.onReinferMbti();
              })
            Button('隐藏 MBTI')
              .height(34)
              .fontSize(12)
              .fontColor(COLOR_MUTED)
              .backgroundColor(COLOR_PANEL)
              .borderRadius(8)
              .margin({ left: 8 })
              .onClick(() => {
                this.mbtiMenuOpen = false;
                this.onSetMbtiHidden(true);
              })
          }
          .margin({ top: 8 })
        }
      } else {
        Button('显示 MBTI')
          .height(34)
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .backgroundColor(COLOR_PANEL)
          .borderRadius(8)
          .margin({ top: 10 })
          .onClick(() => {
            this.onSetMbtiHidden(false);
          })
      }
      Button('重新认识我')
        .height(38)
        .fontSize(13)
        .fontColor(COLOR_TEXT)
        .backgroundColor(COLOR_PANEL)
        .borderRadius(10)
        .margin({ top: 12 })
        .onClick(() => {
          this.onChooseSetup();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding(18)
    .backgroundColor(COLOR_CARD)
    .borderRadius(16)
    .border({ width: 1, color: COLOR_CARD_EDGE })

    Column() {
      Row() {
        Text('persona.md')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_INK)
          .layoutWeight(1)
        Button(this.editingMarkdown ? '保存' : '编辑')
          .height(34)
          .fontSize(12)
          .fontColor(Color.White)
          .backgroundColor(COLOR_ACCENT)
          .borderRadius(8)
          .onClick(() => {
            if (this.editingMarkdown) {
              const saved = this.onSaveMarkdown(this.markdownForEdit());
              if (saved) {
                this.editingMarkdown = false;
                this.draftMarkdown = '';
              }
            } else {
              this.draftMarkdown = snapshot.personaMarkdown;
              this.editingMarkdown = true;
            }
          })
      }
      .width('100%')
      if (this.editingMarkdown) {
        TextArea({ text: this.markdownForEdit() })
          .width('100%')
          .height(310)
          .fontSize(13)
          .fontColor(COLOR_TEXT)
          .lineHeight(20)
          .backgroundColor(COLOR_PANEL)
          .borderRadius(10)
          .margin({ top: 10 })
          .onChange((value: string) => {
            this.draftMarkdown = value;
          })
      } else {
        Scroll() {
          Text(publicPersonaPreviewMarkdown(snapshot.personaMarkdown, snapshot.mbtiHidden))
            .fontSize(13)
            .fontColor(COLOR_TEXT)
            .lineHeight(20)
            .textAlign(TextAlign.Start)
        }
        .width('100%')
        .height(310)
        .padding(12)
        .backgroundColor(COLOR_PANEL)
        .borderRadius(10)
        .margin({ top: 10 })
      }
      if (this.errorMessage.length > 0) {
        Text(this.errorMessage)
          .fontSize(12)
          .fontColor(COLOR_ERROR)
          .margin({ top: 8 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor(COLOR_CARD)
    .borderRadius(16)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .margin({ top: 12 })

    Column() {
      Text('已确认账号')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_INK)
        .margin({ bottom: 6 })
      ForEach(snapshot.sources, (source: PublicPersonaSourceRef) => {
        this.SourceRow(source)
      }, (source: PublicPersonaSourceRef) => source.platform + source.profileUrl)
      if (this.deleteConfirm) {
        Column() {
          Text('删除本地 persona.md 和已保存的账号资料？')
            .fontSize(13)
            .fontColor(COLOR_WARNING)
            .lineHeight(19)
          Row() {
            Button('取消')
              .height(34)
              .fontSize(12)
              .fontColor(COLOR_TEXT)
              .backgroundColor(COLOR_PANEL)
              .borderRadius(8)
              .onClick(() => {
                this.deleteConfirm = false;
              })
            Button('确认删除')
              .height(34)
              .fontSize(12)
              .fontColor(COLOR_ERROR)
              .backgroundColor(COLOR_ERROR_SOFT)
              .borderRadius(8)
              .margin({ left: 8 })
              .onClick(() => {
                if (this.onDelete()) {
                  this.deleteConfirm = false;
                }
              })
          }
          .margin({ top: 8 })
        }
        .width('100%')
        .padding(12)
        .backgroundColor(COLOR_WARNING_SOFT)
        .borderRadius(10)
        .margin({ top: 8 })
      } else {
        Button('删除画像')
          .height(36)
          .fontSize(12)
          .fontColor(COLOR_ERROR)
          .backgroundColor(COLOR_ERROR_SOFT)
          .borderRadius(9)
          .margin({ top: 8 })
          .onClick(() => {
            this.deleteConfirm = true;
          })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor(COLOR_CARD)
    .borderRadius(16)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .margin({ top: 12 })
  }

  build() {
    Scroll() {
      Column() {
        if (this.phase === 'welcome') {
          this.WelcomeView()
        } else if (this.phase === 'input') {
          this.InputView()
        } else if (this.phase === 'discovering' || this.phase === 'reading' || this.phase === 'summarizing') {
          this.BusyView()
        } else if (this.phase === 'awaiting_confirmation') {
          this.ConfirmationView()
        } else if (this.phase === 'complete') {
          this.CompleteView()
        } else {
          this.ErrorView()
        }
      }
      .width('100%')
      .padding(16)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_PANEL)
    .animation({ duration: A2UI_MOTION_NORMAL_MS, curve: A2UI_MOTION_MOVE_CURVE })
  }
}
