import { common } from '@kit.AbilityKit';
import { webview } from '@kit.ArkWeb';
import { BusinessError } from '@kit.BasicServicesKit';
import router from '@ohos.router';
import util from '@ohos.util';
import { aiLogError, aiLogInfo } from '../../model/AiphoneLogger';
import {
  COLOR_CARD_EDGE,
  COLOR_INK,
  COLOR_PAGE,
  COLOR_PANEL
} from './style/A2uiHomeTheme';

const ANYTHING_FEED_RAWFILE: string = 'anything_worldcup_feed.json';
const ANYTHING_BASE_URL: string = 'https://aiphone.local/';

type AnythingValue = Object | string | number | boolean | null | undefined;

interface AnythingAction {
  id?: string;
  label?: string;
  url?: string;
}

class AnythingBridge {
  onOpenUrl: (url: string) => void = (_url: string): void => {};

  postAction(raw: string): void {
    try {
      const action = JSON.parse(raw) as AnythingAction;
      const url = action.url === undefined || action.url === null ? '' : action.url.toString();
      if (url.length > 0) {
        this.onOpenUrl(url);
      }
    } catch (_error) {
    }
  }
}

@Entry
@Component
struct AnythingDemo {
  @State html: string = '';
  @State errorText: string = '';
  private controller: webview.WebviewController = new webview.WebviewController();
  private bridge: AnythingBridge = new AnythingBridge();
  private webReady: boolean = false;
  private loadedHtml: string = '';

  aboutToAppear(): void {
    this.bridge.onOpenUrl = (url: string): void => {
      this.openExternalUrl(url);
    };
    this.loadFeedHtml();
  }

  private rawfileText(path: string): string {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const bytes = context.resourceManager.getRawFileContentSync(path);
    const decoder = util.TextDecoder.create('utf-8');
    return decoder.decodeToString(bytes);
  }

  private loadFeedHtml(): void {
    try {
      const json = this.rawfileText(ANYTHING_FEED_RAWFILE);
      this.html = renderAnythingHtml(json);
      this.errorText = '';
      this.loadHtmlIfNeeded();
    } catch (error) {
      const message = describeAnythingError(error);
      this.errorText = 'Anything Demo 数据未加载：' + message;
      this.html = renderAnythingErrorHtml(this.errorText);
      this.loadHtmlIfNeeded();
      aiLogError('[AIPhone][AnythingDemoLoadError] ' + message);
    }
  }

  private loadHtmlIfNeeded(): void {
    if (!this.webReady || this.html.length === 0 || this.html === this.loadedHtml) {
      return;
    }
    try {
      this.controller.loadData(this.html, 'text/html', 'UTF-8', ANYTHING_BASE_URL);
      this.loadedHtml = this.html;
      aiLogInfo('[AIPhone][AnythingDemoLoad] chars=' + this.html.length.toString());
    } catch (error) {
      aiLogError('[AIPhone][AnythingDemoWebLoadError] ' + JSON.stringify(error));
    }
  }

  private async openExternalUrl(url: string): Promise<void> {
    if (url.length === 0) {
      return;
    }
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await context.startAbility({
        action: 'ohos.want.action.viewData',
        uri: url
      });
    } catch (error) {
      const businessError = error as BusinessError;
      this.errorText = '外部链接打开失败：' + businessError.message;
      aiLogError('[AIPhone][AnythingDemoOpenUrlError] url=' + url + ' message=' + businessError.message);
    }
  }

  build() {
    Column() {
      Row() {
        Button('返回')
          .height(38)
          .width(68)
          .fontSize(13)
          .fontColor(COLOR_INK)
          .backgroundColor(COLOR_PANEL)
          .borderRadius(18)
          .border({ width: 1, color: COLOR_CARD_EDGE })
          .onClick(() => {
            router.back();
          })

        Text('Anything')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_INK)
          .margin({ left: 12 })
          .layoutWeight(1)
      }
      .width('100%')
      .height(54)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 14, right: 14 })
      .backgroundColor(COLOR_PAGE)

      if (this.errorText.length > 0) {
        Text(this.errorText)
          .fontSize(12)
          .fontColor('#B04A42')
          .padding({ left: 14, right: 14, bottom: 8 })
      }

      Web({ src: 'data:text/html;charset=utf-8,<body style="margin:0;background:%23f7f0e5"></body>', controller: this.controller })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .javaScriptProxy({
          object: this.bridge,
          name: 'AIPhoneAnything',
          methodList: ['postAction'],
          controller: this.controller
        })
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('#F7F0E5')
        .onPageEnd(() => {
          this.webReady = true;
          this.loadHtmlIfNeeded();
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_PAGE)
  }
}

function renderAnythingHtml(feedJson: string): string {
  return '<!DOCTYPE html><html lang="zh-CN"><head>' +
    '<meta charset="UTF-8">' +
    '<meta name="referrer" content="strict-origin-when-cross-origin">' +
    '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">' +
    '<title>Anything World Cup</title>' +
    '<style>' + anythingCss() + '</style>' +
    '</head><body><main id="app"></main>' +
    '<script id="feed-data" type="application/json">' + escapeScriptJson(feedJson) + '</script>' +
    '<script>' + anythingJs() + '</script>' +
    '</body></html>';
}

function renderAnythingErrorHtml(message: string): string {
  const escaped = escapeHtmlText(message);
  return '<!DOCTYPE html><html lang="zh-CN"><head>' +
    '<meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1">' +
    '<style>body{margin:0;min-height:100dvh;display:grid;place-items:center;background:#f7f0e5;color:#19140f;font-family:-apple-system,BlinkMacSystemFont,&quot;PingFang SC&quot;,sans-serif}p{max-width:24em;line-height:1.5;color:#6f665c}</style>' +
    '</head><body><p>' + escaped + '</p></body></html>';
}

function anythingCss(): string {
  return `
:root {
  color-scheme: light;
  --paper: #f7f0e5;
  --paper-2: #efe5d6;
  --cream: #fffaf2;
  --ink: #19140f;
  --muted: #746a5f;
  --line: rgba(25,20,15,.12);
  --line-strong: rgba(25,20,15,.2);
  --pitch: #1f6b4b;
  --pitch-2: #154532;
  --rust: #b95d37;
  --gold: #d6a648;
  --shadow: 0 18px 46px rgba(48,33,18,.14);
  --tight-shadow: 0 10px 24px rgba(48,33,18,.1);
  --radius-xl: 30px;
  --radius-lg: 22px;
  --radius-md: 16px;
}
* { box-sizing: border-box; }
html {
  background: var(--paper);
  overflow-x: hidden;
  overflow-x: clip;
  scroll-behavior: smooth;
}
body {
  margin: 0;
  min-height: 100dvh;
  background:
    radial-gradient(circle at 18% -4%, rgba(31,107,75,.14), transparent 34%),
    linear-gradient(180deg, rgba(255,250,242,.82), rgba(247,240,229,1) 48%),
    var(--paper);
  color: var(--ink);
  font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Noto Sans SC", "Helvetica Neue", Arial, sans-serif;
  letter-spacing: 0;
  -webkit-font-smoothing: antialiased;
  overflow-x: hidden;
  overflow-x: clip;
}
h1, h2, h3, p { margin: 0; }
button {
  border: 0;
  font: inherit;
  cursor: pointer;
}
img { display: block; max-width: 100%; }
.shell {
  width: min(100%, 860px);
  min-height: 100dvh;
  margin: 0 auto;
  padding-bottom: calc(92px + env(safe-area-inset-bottom, 0px));
}
.hero {
  position: relative;
  min-height: 430px;
  padding: 22px 16px 18px;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
  isolation: isolate;
}
.hero::before {
  content: "";
  position: absolute;
  inset: 0;
  z-index: -3;
  background:
    linear-gradient(180deg, rgba(25,20,15,.1) 0%, rgba(25,20,15,.12) 38%, rgba(247,240,229,.96) 100%),
    var(--hero-image),
    linear-gradient(135deg, #ccdcc8, #7ca77f 48%, #f0d08e);
  background-size: cover;
  background-position: center;
  transform: scale(1.04);
}
.hero::after {
  content: "";
  position: absolute;
  inset: 0;
  z-index: -2;
  background:
    linear-gradient(90deg, rgba(247,240,229,.88) 0%, rgba(247,240,229,.56) 45%, rgba(247,240,229,.16) 100%),
    repeating-linear-gradient(90deg, rgba(25,20,15,.045) 0 1px, transparent 1px 42px);
}
.kicker {
  width: fit-content;
  border: 1px solid rgba(25,20,15,.13);
  border-radius: 999px;
  padding: 8px 11px;
  background: rgba(255,250,242,.74);
  color: var(--pitch-2);
  font-size: 12px;
  font-weight: 850;
  line-height: 1;
  box-shadow: 0 8px 22px rgba(48,33,18,.08);
  backdrop-filter: blur(16px);
}
.hero h1 {
  max-width: 7.5em;
  margin-top: 15px;
  overflow-wrap: anywhere;
  color: var(--ink);
  font-size: 46px;
  line-height: .98;
  font-weight: 900;
  text-wrap: balance;
}
.hero p {
  max-width: 28em;
  margin-top: 11px;
  color: rgba(25,20,15,.75);
  font-size: 14px;
  font-weight: 650;
  line-height: 1.5;
}
.source-rail {
  position: sticky;
  top: 0;
  z-index: 20;
  display: flex;
  gap: 8px;
  overflow-x: auto;
  padding: 12px 14px 13px;
  border-bottom: 1px solid rgba(25,20,15,.06);
  background: rgba(247,240,229,.92);
  backdrop-filter: blur(18px);
  scrollbar-width: none;
}
.source-rail::-webkit-scrollbar { display: none; }
.source-tab {
  flex: 0 0 auto;
  display: inline-flex;
  align-items: center;
  gap: 7px;
  min-height: 40px;
  border: 1px solid var(--line);
  border-radius: 999px;
  padding: 9px 13px;
  background: rgba(255,250,242,.9);
  color: var(--ink);
  font-size: 12px;
  font-weight: 820;
  line-height: 1;
  white-space: nowrap;
  box-shadow: 0 8px 18px rgba(48,33,18,.06);
  transition: transform 140ms ease, background 140ms ease, border-color 140ms ease;
}
.source-tab.active {
  border-color: var(--ink);
  background: var(--ink);
  color: var(--cream);
}
.source-tab:active { transform: translateY(1px); }
.stage-wrap {
  padding: 12px 14px 16px;
}
.video-stage {
  overflow: hidden;
  border: 1px solid rgba(25,20,15,.12);
  border-radius: var(--radius-xl);
  background:
    radial-gradient(circle at 20% 0%, rgba(31,107,75,.18), transparent 42%),
    #18120d;
  color: var(--cream);
  box-shadow: var(--shadow);
}
.stage-player {
  position: relative;
  aspect-ratio: 16 / 9;
  min-height: 204px;
  overflow: hidden;
  background: #090806;
}
.stage-poster {
  position: absolute;
  inset: 0;
  z-index: 0;
  background: var(--poster), linear-gradient(135deg, #261b12, #050403);
  background-size: cover;
  background-position: center;
  filter: saturate(.85) blur(12px);
  opacity: .38;
  transform: scale(1.08);
}
.stage-player iframe,
.stage-player video {
  position: relative;
  z-index: 1;
  width: 100%;
  height: 100%;
  border: 0;
  display: block;
  background: transparent;
}
.stage-player video {
  object-fit: cover;
}
.player-fallback {
  position: absolute;
  inset: 0;
  z-index: 3;
  display: grid;
  place-content: center;
  gap: 10px;
  padding: 18px;
  background: linear-gradient(180deg, rgba(8,6,4,.62), rgba(8,6,4,.84));
  color: var(--cream);
  text-align: center;
}
.player-fallback b {
  color: var(--cream);
  font-size: 16px;
  line-height: 1.2;
  font-weight: 880;
}
.player-fallback span {
  max-width: 24em;
  color: rgba(255,250,242,.72);
  font-size: 12px;
  line-height: 1.45;
}
.player-fallback button {
  justify-self: center;
  border: 1px solid rgba(255,250,242,.18);
  border-radius: 999px;
  padding: 9px 12px;
  background: #e1c071;
  color: #17120d;
  font-size: 12px;
  font-weight: 850;
}
.stage-chrome {
  position: absolute;
  left: 10px;
  right: 10px;
  bottom: 10px;
  z-index: 2;
  display: flex;
  align-items: center;
  gap: 8px;
  min-height: 34px;
  border: 1px solid rgba(255,250,242,.16);
  border-radius: 999px;
  padding: 7px 10px;
  background: rgba(8,6,4,.54);
  color: rgba(255,250,242,.86);
  backdrop-filter: blur(16px);
  pointer-events: none;
}
.stage-dot {
  width: 8px;
  height: 8px;
  border-radius: 999px;
  background: #d75638;
  box-shadow: 0 0 0 3px rgba(215,86,56,.18);
}
.stage-chrome span {
  min-width: 0;
  overflow: hidden;
  font-size: 11px;
  font-weight: 780;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.stage-body {
  padding: 16px 17px 17px;
}
.stage-meta {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  flex-wrap: wrap;
}
.provider-badge {
  border-radius: 999px;
  padding: 6px 9px;
  background: rgba(255,250,242,.12);
  color: rgba(255,250,242,.86);
  font-size: 11px;
  font-weight: 850;
  line-height: 1;
}
.status-chip {
  border-radius: 999px;
  padding: 6px 9px;
  background: rgba(31,107,75,.9);
  color: var(--cream);
  font-size: 11px;
  font-weight: 850;
  line-height: 1;
}
.stage-body h2 {
  margin-top: 12px;
  color: var(--cream);
  font-size: 22px;
  line-height: 1.18;
  font-weight: 880;
  overflow-wrap: anywhere;
}
.stage-body p {
  margin-top: 8px;
  color: rgba(255,250,242,.7);
  font-size: 13px;
  line-height: 1.46;
}
.stage-actions {
  display: flex;
  gap: 8px;
  margin-top: 14px;
  flex-wrap: wrap;
}
.stage-action {
  border: 1px solid rgba(255,250,242,.16);
  border-radius: 999px;
  padding: 9px 12px;
  background: rgba(255,250,242,.1);
  color: var(--cream);
  font-size: 12px;
  font-weight: 820;
  white-space: nowrap;
}
.stage-action.primary {
  border-color: #e1c071;
  background: #e1c071;
  color: #17120d;
}
.video-rail {
  display: grid;
  grid-auto-flow: column;
  grid-auto-columns: minmax(164px, 74%);
  gap: 10px;
  margin-top: 12px;
  overflow-x: auto;
  padding: 2px 1px 4px;
  scrollbar-width: none;
}
.video-rail::-webkit-scrollbar { display: none; }
.video-chip {
  min-width: 0;
  border: 1px solid rgba(25,20,15,.1);
  border-radius: 20px;
  padding: 8px;
  background: rgba(255,250,242,.9);
  color: var(--ink);
  box-shadow: 0 10px 22px rgba(48,33,18,.08);
  text-align: left;
}
.video-chip.active {
  border-color: var(--pitch);
  box-shadow: 0 14px 30px rgba(31,107,75,.18);
}
.video-thumb {
  aspect-ratio: 16 / 9;
  overflow: hidden;
  border-radius: 14px;
  background: var(--thumb), linear-gradient(135deg, #e7d8c2, #a8bfa4);
  background-size: cover;
  background-position: center;
}
.video-chip b {
  display: block;
  margin-top: 8px;
  overflow: hidden;
  color: var(--ink);
  font-size: 12px;
  line-height: 1.25;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.video-chip span {
  display: block;
  margin-top: 5px;
  color: var(--muted);
  font-size: 10px;
  font-weight: 780;
  line-height: 1;
}
.fixture-strip {
  display: grid;
  grid-auto-flow: column;
  grid-auto-columns: minmax(180px, 72%);
  gap: 10px;
  overflow-x: auto;
  padding: 0 14px 14px;
  scrollbar-width: none;
}
.fixture-strip::-webkit-scrollbar { display: none; }
.fixture {
  border: 1px solid rgba(25,20,15,.1);
  border-radius: 20px;
  padding: 13px;
  background: rgba(255,250,242,.74);
  box-shadow: 0 10px 24px rgba(48,33,18,.08);
}
.fixture span {
  color: var(--muted);
  font-size: 11px;
  font-weight: 820;
  line-height: 1;
}
.fixture b {
  display: block;
  margin-top: 8px;
  color: var(--ink);
  font-size: 14px;
  line-height: 1.2;
}
.section-title {
  padding: 12px 16px 9px;
  color: var(--ink);
  font-size: 18px;
  line-height: 1.2;
  font-weight: 880;
}
.content-grid {
  display: grid;
  gap: 14px;
  padding: 0 14px 22px;
}
.content-card {
  --kind-accent: var(--pitch);
  position: relative;
  overflow: hidden;
  border: 1px solid rgba(25,20,15,.1);
  border-radius: 24px;
  padding: 17px;
  background:
    radial-gradient(circle at 92% 0%, rgba(214,166,72,.16), transparent 36%),
    linear-gradient(135deg, rgba(31,107,75,.1), rgba(255,250,242,0) 52%),
    rgba(255,250,242,.92);
  color: var(--ink);
  box-shadow: 0 14px 34px rgba(48,33,18,.11);
  text-align: left;
  transition: transform 140ms ease, border-color 140ms ease;
}
.content-card[data-kind="news"] { --kind-accent: var(--rust); }
.content-card[data-kind="clip"] { --kind-accent: #8a6640; }
.content-card[data-kind="schedule"] { --kind-accent: var(--pitch-2); }
.content-card[data-kind="data"] { --kind-accent: var(--gold); }
.content-card::before {
  content: "";
  position: absolute;
  left: 0;
  top: 0;
  bottom: 0;
  width: 5px;
  background: var(--kind-accent);
}
.content-card[hidden] { display: none; }
.card-topline {
  display: flex;
  justify-content: space-between;
  gap: 10px;
  color: var(--muted);
  font-size: 11px;
  font-weight: 820;
  line-height: 1;
}
.card-topline span {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.content-card h3 {
  margin-top: 11px;
  color: var(--ink);
  font-size: 20px;
  line-height: 1.22;
  font-weight: 880;
  overflow-wrap: anywhere;
}
.content-card p {
  margin-top: 8px;
  color: var(--muted);
  font-size: 13px;
  line-height: 1.45;
  overflow-wrap: anywhere;
}
.card-copy {
  color: #4e463e;
}
.card-bullets {
  display: grid;
  gap: 7px;
  margin: 12px 0 0;
  padding: 0;
  list-style: none;
}
.card-bullets li {
  position: relative;
  padding-left: 14px;
  color: #52483f;
  font-size: 12px;
  font-weight: 680;
  line-height: 1.4;
}
.card-bullets li::before {
  content: "";
  position: absolute;
  left: 0;
  top: .62em;
  width: 6px;
  height: 2px;
  border-radius: 999px;
  background: var(--kind-accent);
}
.feed-player {
  position: relative;
  aspect-ratio: 16 / 9;
  min-height: 178px;
  margin-top: 14px;
  overflow: hidden;
  border: 1px solid rgba(25,20,15,.1);
  border-radius: 18px;
  background: #0b0805;
  box-shadow: inset 0 0 0 1px rgba(255,250,242,.05);
}
.feed-player iframe,
.feed-player video {
  position: relative;
  z-index: 1;
  width: 100%;
  height: 100%;
  border: 0;
  display: block;
  background: transparent;
}
.feed-player video {
  object-fit: cover;
}
.short-card {
  display: grid;
  grid-template-columns: minmax(0, 1.05fr) minmax(118px, .72fr);
  gap: 10px 16px;
  border: 0;
  border-radius: 28px;
  padding: 14px;
  background:
    radial-gradient(circle at 16% 8%, rgba(214,166,72,.28), transparent 34%),
    radial-gradient(circle at 88% 12%, rgba(255,250,242,.11), transparent 30%),
    linear-gradient(135deg, #11100e 0%, #211913 54%, #342719 100%);
  color: var(--cream);
  box-shadow: 0 22px 48px rgba(28,20,12,.28);
}
.short-card::before { display: none; }
.short-card .card-topline {
  grid-column: 2;
  display: flex;
  align-items: center;
  margin-top: 2px;
  color: rgba(255,250,242,.58);
  font-size: 10px;
  letter-spacing: .02em;
}
.short-card .card-topline span:first-child {
  flex: 0 0 auto;
  border-radius: 999px;
  padding: 6px 8px;
  background: rgba(255,250,242,.12);
  color: rgba(255,250,242,.82);
}
.short-card .card-topline span:last-child {
  text-align: right;
}
.short-card h3,
.short-card > p,
.short-card .card-copy,
.short-card .card-actions {
  grid-column: 2;
}
.short-card h3 {
  margin-top: 8px;
  color: var(--cream);
  font-size: 23px;
  line-height: 1.08;
}
.short-card > p {
  margin-top: 4px;
  color: rgba(255,250,242,.62);
  font-size: 14px;
  font-weight: 760;
}
.short-card .card-copy {
  margin-top: 18px;
  color: rgba(255,250,242,.58);
  font-size: 14px;
  line-height: 1.58;
}
.short-card .feed-player {
  grid-column: 1;
  grid-row: 1 / span 7;
  aspect-ratio: 9 / 16;
  min-height: 336px;
  margin-top: 0;
  border: 0;
  border-radius: 24px;
  background: #080706;
  box-shadow: 0 18px 42px rgba(0,0,0,.42), inset 0 0 0 1px rgba(255,250,242,.06);
}
.short-card .feed-player video {
  object-fit: cover;
}
.short-card .card-actions {
  display: grid;
  grid-template-columns: 1fr;
  gap: 9px;
  align-self: end;
  margin-top: 22px;
}
.short-card .card-action {
  border: 0;
  padding: 12px 10px;
  background: rgba(255,250,242,.12);
  color: var(--cream);
  text-align: center;
  box-shadow: inset 0 0 0 1px rgba(255,250,242,.09);
}
.short-card .card-action.primary {
  background: var(--gold);
  color: var(--ink);
  box-shadow: 0 14px 24px rgba(214,166,72,.24);
}
.news-card {
  padding: 20px 18px;
  background:
    linear-gradient(180deg, rgba(255,250,242,.96), rgba(247,240,229,.86)),
    var(--cream);
}
.news-card::before {
  width: 100%;
  height: 5px;
  bottom: auto;
  background: linear-gradient(90deg, var(--rust), rgba(185,93,55,.12));
}
.news-card h3 {
  margin-top: 16px;
  font-size: 24px;
  line-height: 1.12;
}
.news-card > p {
  color: #6a5e52;
  font-size: 12px;
  font-weight: 760;
}
.news-card .card-copy {
  color: #332a22;
  font-size: 15px;
  line-height: 1.58;
}
.card-actions {
  display: flex;
  gap: 8px;
  margin-top: 13px;
  flex-wrap: wrap;
}
.card-action {
  border: 1px solid rgba(25,20,15,.12);
  border-radius: 999px;
  padding: 9px 12px;
  background: rgba(247,240,229,.76);
  color: var(--ink);
  font-size: 12px;
  font-weight: 820;
  line-height: 1;
  white-space: nowrap;
}
.card-action.primary {
  border-color: var(--pitch);
  background: var(--pitch);
  color: var(--cream);
}
.card-action:active {
  transform: translateY(1px);
}
.metric-row {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
  margin-top: 12px;
}
.metric-cell {
  min-width: 0;
  border: 1px solid rgba(25,20,15,.08);
  border-radius: 14px;
  padding: 9px;
  background: rgba(247,240,229,.72);
}
.metric-cell b {
  display: block;
  color: var(--ink);
  font-size: 14px;
  line-height: 1;
  overflow-wrap: anywhere;
}
.metric-cell span {
  display: block;
  margin-top: 6px;
  color: var(--muted);
  font-size: 10px;
  font-weight: 800;
  line-height: 1;
}
.fixture-board {
  display: grid;
  gap: 10px;
  margin-top: 14px;
}
.fixture-card {
  position: relative;
  overflow: hidden;
  border: 1px solid rgba(25,20,15,.1);
  border-radius: 18px;
  padding: 13px;
  background:
    linear-gradient(135deg, rgba(31,107,75,.12), rgba(255,250,242,.2)),
    rgba(247,240,229,.82);
}
.fixture-card b {
  display: block;
  color: var(--ink);
  font-size: 16px;
  line-height: 1.18;
}
.fixture-meta {
  display: grid;
  grid-template-columns: 1fr;
  gap: 6px;
  margin-top: 10px;
}
.fixture-meta span {
  color: #5a5047;
  font-size: 11px;
  font-weight: 760;
  line-height: 1.25;
}
.fixture-angle {
  margin-top: 10px;
  color: var(--muted);
  font-size: 12px;
  line-height: 1.42;
}
.player-board {
  display: grid;
  gap: 12px;
  margin-top: 14px;
}
.player-card {
  position: relative;
  min-height: 168px;
  overflow: hidden;
  border: 1px solid rgba(25,20,15,.1);
  border-radius: 20px;
  padding: 13px;
  background:
    radial-gradient(circle at 90% 10%, rgba(214,166,72,.22), transparent 34%),
    linear-gradient(135deg, rgba(31,107,75,.14), rgba(247,240,229,.92));
  box-shadow: 0 12px 26px rgba(48,33,18,.08);
}
.player-head {
  display: grid;
  grid-template-columns: 76px 1fr;
  gap: 12px;
  align-items: center;
}
.player-photo {
  width: 76px;
  height: 76px;
  overflow: hidden;
  border: 1px solid rgba(25,20,15,.12);
  border-radius: 18px;
  background:
    linear-gradient(180deg, rgba(255,250,242,.8), rgba(214,166,72,.22)),
    #e9ddca;
}
.player-photo img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.player-name {
  color: var(--ink);
  font-size: 18px;
  line-height: 1.08;
  font-weight: 900;
}
.player-role {
  margin-top: 5px;
  color: var(--muted);
  font-size: 11px;
  font-weight: 820;
  line-height: 1.2;
}
.player-match {
  margin-top: 7px;
  color: #51483f;
  font-size: 12px;
  font-weight: 760;
  line-height: 1.25;
}
.player-stats {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
  margin-top: 12px;
}
.player-stat {
  min-width: 0;
  border: 1px solid rgba(25,20,15,.08);
  border-radius: 14px;
  padding: 9px;
  background: rgba(255,250,242,.66);
}
.player-stat b {
  display: block;
  color: var(--pitch-2);
  font-size: 14px;
  line-height: 1;
  overflow-wrap: anywhere;
}
.player-stat span {
  display: block;
  margin-top: 6px;
  color: var(--muted);
  font-size: 10px;
  font-weight: 820;
  line-height: 1;
}
.player-note {
  margin-top: 10px;
  color: #51483f;
  font-size: 12px;
  font-weight: 650;
  line-height: 1.45;
}
.empty {
  margin: 0 14px 22px;
  border: 1px dashed rgba(25,20,15,.18);
  border-radius: 20px;
  padding: 16px;
  background: rgba(255,250,242,.68);
  color: var(--muted);
  font-size: 13px;
  line-height: 1.45;
}
@media (max-width: 360px) {
  .hero h1 { font-size: 40px; }
  .metric-row { grid-template-columns: 1fr; }
  .player-head { grid-template-columns: 1fr; }
  .short-card { grid-template-columns: 1fr; }
  .short-card h3,
  .short-card > p,
  .short-card .card-copy,
  .short-card .card-actions,
  .short-card .feed-player { grid-column: 1; }
}
@media (min-width: 720px) {
  .hero { min-height: 470px; padding-left: 24px; padding-right: 24px; }
  .hero h1 { font-size: 56px; }
  .fixture-board { grid-template-columns: repeat(3, minmax(0, 1fr)); }
  .player-board { grid-template-columns: repeat(2, minmax(0, 1fr)); }
}
@media (prefers-reduced-motion: reduce) {
  html { scroll-behavior: auto; }
  .content-card,
  .source-tab { transition: none; }
}
`;
}

function anythingJs(): string {
  return `
(function () {
  var app = document.getElementById('app');
  var node = document.getElementById('feed-data');
  var data = {};
  try { data = JSON.parse(node && node.textContent ? node.textContent : '{}') || {}; } catch (error) { data = {}; }
  var state = { filter: 'all', videoId: '' };
  function text(value) { return value === undefined || value === null ? '' : String(value); }
  function list(value) { return Array.isArray(value) ? value : []; }
  function add(parent, tag, className, value) {
    var el = document.createElement(tag);
    if (className) { el.className = className; }
    if (value !== undefined && value !== null && text(value).length > 0) { el.textContent = text(value); }
    parent.appendChild(el);
    return el;
  }
  function postAction(action) {
    try {
      if (window.AIPhoneAnything && typeof window.AIPhoneAnything.postAction === 'function') {
        window.AIPhoneAnything.postAction(JSON.stringify(action || {}));
      }
    } catch (error) {}
  }
  function videoById(id) {
    var videos = list(data.videos);
    for (var i = 0; i < videos.length; i += 1) {
      if (text(videos[i] && videos[i].id) === text(id)) { return videos[i]; }
    }
    return videos[0] || {};
  }
  function cardVideo(card) {
    var id = text(card && card.videoId);
    if (id.length === 0) { return {}; }
    return videoById(id);
  }
  function kindLabel(value) {
    var key = text(value);
    var labels = {
      video: '集锦',
      news: '战报',
      data: '数据',
      schedule: '赛程',
      clip: '短视频'
    };
    return labels[key] || key;
  }
  function sourceUrlForCard(card) {
    var direct = text(card && card.sourceUrl);
    if (direct.length > 0) { return direct; }
    return text(cardVideo(card).sourceUrl);
  }
  function mediaUrl(video) {
    var direct = text(video && video.streamUrl);
    if (direct.length > 0) { return direct; }
    var mp4 = text(video && video.mp4Url);
    if (mp4.length > 0) { return mp4; }
    var hls = text(video && video.hlsUrl);
    if (hls.length > 0) { return hls; }
    var local = text(video && video.localMp4);
    if (local.length > 0) { return localMediaUrl(local); }
    return '';
  }
  function mediaKind(video) {
    var explicit = text(video && video.streamType);
    if (explicit.length > 0) { return explicit; }
    var url = mediaUrl(video).toLowerCase();
    if (url.indexOf('.m3u8') >= 0) { return 'HLS'; }
    if (url.indexOf('.mp4') >= 0) { return 'MP4'; }
    return 'Video';
  }
  function youtubeUrl(video) {
    return 'https://www.youtube.com/embed/' + encodeURIComponent(text(video.youtubeId)) +
      '?playsinline=1&rel=0&modestbranding=1&origin=https%3A%2F%2Faiphone.local';
  }
  function localMediaUrl(file) {
    var raw = text(file);
    if (raw.indexOf('http://') === 0 || raw.indexOf('https://') === 0 || raw.indexOf('resource://') === 0) {
      return raw;
    }
    return 'resource://rawfile/' + raw;
  }
  function posterStyle(url) {
    var raw = text(url);
    if (raw.length === 0) { return ''; }
    return 'url("' + raw.split('"').join('%22') + '")';
  }
  function showPlayerFallback(player, video, message) {
    if (player.querySelector('.player-fallback')) { return; }
    var fallback = add(player, 'div', 'player-fallback');
    add(fallback, 'b', '', '视频源暂时无法载入');
    add(fallback, 'span', '', message || '可以打开官方来源继续观看。');
    var button = add(fallback, 'button', '', '打开官方来源');
    button.type = 'button';
    button.addEventListener('click', function () { postAction({ url: text(video.sourceUrl) }); });
  }
  function appendVideoPlayer(player, video, src) {
    var media = document.createElement('video');
    media.src = src;
    media.poster = text(video.thumbnail);
    media.controls = true;
    media.preload = 'metadata';
    media.playsInline = true;
    media.crossOrigin = 'anonymous';
    media.setAttribute('playsinline', '');
    media.setAttribute('webkit-playsinline', '');
    media.addEventListener('error', function () {
      showPlayerFallback(player, video, '当前网络未能载入这条 ' + mediaKind(video) + ' 视频流。');
    });
    player.appendChild(media);
  }
  function renderStage(parent) {
    var video = videoById(state.videoId);
    if (state.videoId.length === 0) { state.videoId = text(video.id); }
    parent.textContent = '';
    var stage = add(parent, 'section', 'video-stage');
    var player = add(stage, 'div', 'stage-player');
    player.style.setProperty('--poster', posterStyle(video.thumbnail));
    add(player, 'div', 'stage-poster');
    var src = mediaUrl(video);
    if (src.length > 0) {
      appendVideoPlayer(player, video, src);
    } else if (text(video.youtubeId).length > 0) {
      var iframe = document.createElement('iframe');
      iframe.src = youtubeUrl(video);
      iframe.title = text(video.title);
      iframe.allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share';
      iframe.setAttribute('loading', 'lazy');
      iframe.setAttribute('allowfullscreen', 'true');
      iframe.setAttribute('referrerpolicy', 'origin-when-cross-origin');
      iframe.allowFullscreen = true;
      player.appendChild(iframe);
    } else {
      showPlayerFallback(player, video, '这条内容还没有可用的视频源。');
    }
    var chrome = add(player, 'div', 'stage-chrome');
    add(chrome, 'span', 'stage-dot');
    add(chrome, 'span', '', text(video.provider) + ' · direct ' + mediaKind(video) + ' · ' + text(video.duration));
    var body = add(stage, 'div', 'stage-body');
    var meta = add(body, 'div', 'stage-meta');
    add(meta, 'span', 'provider-badge', text(video.provider));
    add(meta, 'span', 'status-chip', text(video.status) + ' · ' + text(video.score));
    add(body, 'h2', '', text(video.match) || text(video.title));
    add(body, 'p', '', text(video.summary));
    var actions = add(body, 'div', 'stage-actions');
    var open = add(actions, 'button', 'stage-action primary', '打开官方来源');
    open.type = 'button';
    open.addEventListener('click', function () { postAction({ url: text(video.sourceUrl) }); });
    var note = add(actions, 'button', 'stage-action', '真实视频源 · 可拖动进度');
    note.type = 'button';
    note.disabled = true;
  }
  function renderVideoRail(parent) {
    var rail = add(parent, 'div', 'video-rail');
    list(data.videos).forEach(function (video) {
      var button = add(rail, 'button', 'video-chip', '');
      button.type = 'button';
      button.setAttribute('data-video-id', text(video.id));
      var thumb = add(button, 'div', 'video-thumb');
      thumb.style.setProperty('--thumb', posterStyle(video.thumbnail));
      add(button, 'b', '', text(video.match) || text(video.title));
      add(button, 'span', '', text(video.provider) + ' · ' + text(video.status));
      button.addEventListener('click', function () {
        state.videoId = text(video.id);
        renderStage(document.getElementById('stage-root'));
        syncVideoRail();
      });
    });
  }
  function syncVideoRail() {
    Array.prototype.slice.call(document.querySelectorAll('.video-chip')).forEach(function (button) {
      button.classList.toggle('active', button.getAttribute('data-video-id') === state.videoId);
    });
  }
  function renderFixtures(parent) {
    var fixtures = list(data.fixtures);
    if (fixtures.length === 0) { return; }
    var strip = add(parent, 'section', 'fixture-strip');
    fixtures.forEach(function (fixture) {
      var item = add(strip, 'div', 'fixture');
      add(item, 'span', '', text(fixture.timeET || fixture.timeLocal || fixture.time) + ' · ' + text(fixture.status));
      add(item, 'b', '', text(fixture.match));
      add(item, 'span', '', text(fixture.venue) + ' / ' + text(fixture.city));
    });
  }
  function metricGrid(parent, metrics) {
    var items = list(metrics);
    if (items.length === 0) { return; }
    var grid = add(parent, 'div', 'metric-row');
    items.forEach(function (metric) {
      var cell = add(grid, 'div', 'metric-cell');
      add(cell, 'b', '', text(metric.value));
      add(cell, 'span', '', text(metric.label));
    });
  }
  function renderParagraphs(parent, paragraphs) {
    if (Array.isArray(paragraphs)) {
      paragraphs.forEach(function (paragraph) {
        add(parent, 'p', 'card-copy', paragraph);
      });
      return;
    }
    var body = text(paragraphs);
    if (body.length > 0) {
      add(parent, 'p', 'card-copy', body);
    }
  }
  function renderBullets(parent, bullets) {
    var items = list(bullets);
    if (items.length === 0) { return; }
    var listNode = add(parent, 'ul', 'card-bullets');
    items.forEach(function (item) {
      add(listNode, 'li', '', item);
    });
  }
  function renderInlineVideo(parent, video) {
    if (text(video && video.id).length === 0) { return; }
    var player = add(parent, 'div', 'feed-player');
    player.style.setProperty('--poster', posterStyle(video.thumbnail));
    add(player, 'div', 'stage-poster');
    var src = mediaUrl(video);
    if (src.length > 0) {
      appendVideoPlayer(player, video, src);
    } else if (text(video.youtubeId).length > 0) {
      var iframe = document.createElement('iframe');
      iframe.src = youtubeUrl(video);
      iframe.title = text(video.title);
      iframe.allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share';
      iframe.setAttribute('loading', 'lazy');
      iframe.setAttribute('allowfullscreen', 'true');
      iframe.setAttribute('referrerpolicy', 'origin-when-cross-origin');
      iframe.allowFullscreen = true;
      player.appendChild(iframe);
    } else {
      showPlayerFallback(player, video, '这条内容还没有可用的视频源。');
    }
  }
  function renderCardActions(parent, card, linked) {
    var url = sourceUrlForCard(card);
    var hasVideo = text(linked && linked.id).length > 0;
    if (!hasVideo && url.length === 0) { return; }
    var actions = add(parent, 'div', 'card-actions');
    if (hasVideo) {
      var play = add(actions, 'button', 'card-action primary', '主舞台播放');
      play.type = 'button';
      play.addEventListener('click', function () {
        state.videoId = text(linked.id);
        renderStage(document.getElementById('stage-root'));
        syncVideoRail();
        document.getElementById('stage-root').scrollIntoView({ behavior: 'smooth', block: 'start' });
      });
    }
    if (url.length > 0) {
      var open = add(actions, 'button', 'card-action', '打开来源');
      open.type = 'button';
      open.addEventListener('click', function () { postAction({ url: url }); });
    }
  }
  function renderFixtureBoard(parent) {
    var fixtures = list(data.fixtures);
    if (fixtures.length === 0) { return; }
    var board = add(parent, 'div', 'fixture-board');
    fixtures.forEach(function (fixture) {
      var card = add(board, 'article', 'fixture-card');
      add(card, 'b', '', text(fixture.match));
      var meta = add(card, 'div', 'fixture-meta');
      add(meta, 'span', '', text(fixture.timeLocal) + ' / ' + text(fixture.timeET));
      add(meta, 'span', '', text(fixture.timeChina));
      add(meta, 'span', '', text(fixture.venue) + ' / ' + text(fixture.city));
      add(card, 'p', 'fixture-angle', text(fixture.angle));
      var url = text(fixture.sourceUrl);
      if (url.length > 0) {
        var actions = add(card, 'div', 'card-actions');
        var open = add(actions, 'button', 'card-action', '赛程来源');
        open.type = 'button';
        open.addEventListener('click', function () { postAction({ url: url }); });
      }
    });
  }
  function renderPlayerBoard(parent) {
    var players = list(data.players);
    if (players.length === 0) { return; }
    var board = add(parent, 'div', 'player-board');
    board.setAttribute('data-kind', 'data');
    players.forEach(function (player) {
      var card = add(board, 'article', 'player-card');
      card.setAttribute('data-kind', 'data');
      var head = add(card, 'div', 'player-head');
      var photo = add(head, 'div', 'player-photo');
      var image = document.createElement('img');
      image.src = text(player.image);
      image.alt = text(player.name);
      photo.appendChild(image);
      var identity = add(head, 'div', '');
      add(identity, 'div', 'player-name', text(player.name));
      add(identity, 'div', 'player-role', text(player.team) + ' / ' + text(player.role));
      add(identity, 'div', 'player-match', text(player.match));
      var stats = add(card, 'div', 'player-stats');
      list(player.stats).forEach(function (stat) {
        var cell = add(stats, 'div', 'player-stat');
        add(cell, 'b', '', text(stat.value));
        add(cell, 'span', '', text(stat.label));
      });
      add(card, 'p', 'player-note', text(player.note));
      var url = text(player.sourceUrl);
      if (url.length > 0) {
        var actions = add(card, 'div', 'card-actions');
        var open = add(actions, 'button', 'card-action', '数据来源');
        open.type = 'button';
        open.addEventListener('click', function () { postAction({ url: url }); });
      }
    });
  }
  function renderCards(parent) {
    add(parent, 'h2', 'section-title', '今日聚合流');
    var grid = add(parent, 'section', 'content-grid');
    list(data.cards).forEach(function (card) {
      if (text(card.kind) === 'data') {
        renderPlayerBoard(grid);
        return;
      }
      var article = add(grid, 'article', 'content-card');
      if (text(card.kind) === 'clip') { article.className += ' short-card'; }
      if (text(card.kind) === 'news') { article.className += ' news-card'; }
      article.setAttribute('data-kind', text(card.kind));
      var top = add(article, 'div', 'card-topline');
      add(top, 'span', '', kindLabel(card.kind));
      add(top, 'span', '', text(card.source));
      add(article, 'h3', '', text(card.title));
      add(article, 'p', '', text(card.subtitle));
      renderParagraphs(article, card.body);
      var linked = cardVideo(card);
      renderInlineVideo(article, linked);
      renderBullets(article, card.bullets);
      if (text(card.kind) !== 'news' && text(linked && linked.id).length === 0) { metricGrid(article, card.metrics); }
      if (text(card.kind) === 'schedule') { renderFixtureBoard(article); }
      renderCardActions(article, card, linked);
    });
  }
  function applyFilter(kind) {
    state.filter = kind;
    var visibleCount = 0;
    Array.prototype.slice.call(document.querySelectorAll('.content-card, .player-card[data-kind]')).forEach(function (card) {
      var keep = kind === 'all' || card.getAttribute('data-kind') === kind;
      card.hidden = !keep;
      if (keep) { visibleCount += 1; }
    });
    Array.prototype.slice.call(document.querySelectorAll('.source-tab')).forEach(function (button) {
      button.classList.toggle('active', button.getAttribute('data-kind') === kind);
    });
    var empty = document.getElementById('empty-state');
    empty.hidden = visibleCount > 0;
  }
  function renderSourceRail(parent) {
    var rail = add(parent, 'nav', 'source-rail');
    list(data.sources).forEach(function (source, index) {
      var kind = text(source.kind || source.id);
      var button = add(rail, 'button', 'source-tab' + (index === 0 ? ' active' : ''), text(source.label));
      button.type = 'button';
      button.setAttribute('data-kind', kind);
      button.addEventListener('click', function () { applyFilter(kind); });
    });
  }
  app.textContent = '';
  var shell = add(app, 'div', 'shell');
  var hero = data.hero || {};
  var heroNode = add(shell, 'section', 'hero');
  heroNode.style.setProperty('--hero-image', posterStyle(hero.background));
  add(heroNode, 'span', 'kicker', text(hero.kicker) || text(data.date));
  add(heroNode, 'h1', '', text(hero.title) || '世界杯 Anything OS');
  add(heroNode, 'p', '', text(hero.subtitle) || text(data.sourceNote));
  renderSourceRail(shell);
  var stageWrap = add(shell, 'section', 'stage-wrap');
  var stageRoot = add(stageWrap, 'div', '');
  stageRoot.id = 'stage-root';
  renderStage(stageRoot);
  renderVideoRail(stageWrap);
  syncVideoRail();
  renderFixtures(shell);
  renderCards(shell);
  var empty = add(shell, 'div', 'empty', '这个筛选暂无卡片。');
  empty.id = 'empty-state';
  empty.hidden = true;
  applyFilter('all');
  var resetUntil = Date.now() + 900;
  function resetScroll() {
    window.scrollTo(0, 0);
    if (Date.now() < resetUntil) { requestAnimationFrame(resetScroll); }
  }
  resetScroll();
})();
`;
}

function escapeScriptJson(json: string): string {
  return json
    .split('&').join('\\u0026')
    .split('<').join('\\u003c')
    .split('>').join('\\u003e')
    .split('\u2028').join('\\u2028')
    .split('\u2029').join('\\u2029');
}

function escapeHtmlText(value: AnythingValue): string {
  if (value === undefined || value === null) {
    return '';
  }
  return value.toString()
    .split('&').join('&amp;')
    .split('<').join('&lt;')
    .split('>').join('&gt;')
    .split('"').join('&quot;');
}

function describeAnythingError(error: Error | Object | string | number | boolean | null | undefined): string {
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
