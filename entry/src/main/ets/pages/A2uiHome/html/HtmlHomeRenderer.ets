import { HtmlHomeDocument } from './HtmlHomeTypes';
import { renderAggregateSearchHomeDocument, shouldRenderAggregateSearchHomeDocument } from './HtmlAggregateSearchHomeRenderer';
import { renderCalendarHomeDocument, shouldRenderCalendarHomeDocument } from './HtmlCalendarHomeRenderer';
import { renderFoodHomeDocument, shouldRenderFoodHomeDocument } from './HtmlFoodHomeRenderer';
import { renderMediaHomeDocument, shouldRenderMediaHomeDocument } from './HtmlMediaHomeRenderer';
import { renderPaymentHomeDocument, shouldRenderPaymentHomeDocument } from './HtmlPaymentHomeRenderer';
import { renderRideHailingHomeDocument, shouldRenderRideHailingHomeDocument } from './HtmlRideHailingHomeRenderer';
import { renderTravelHomeDocument, shouldRenderTravelHomeDocument } from './HtmlTravelHomeRenderer';
import { personaAvatarDataUri } from './PersonaAvatarDataUri';
import { APP_LOGO_AMAP, APP_LOGO_ASANA, APP_LOGO_BAIDU_MAPS, APP_LOGO_BILIBILI, APP_LOGO_DISCORD, APP_LOGO_GITHUB, APP_LOGO_GMAIL, APP_LOGO_GOOGLE_DOCS, APP_LOGO_GOOGLE_DRIVE, APP_LOGO_GOOGLE_MAPS, APP_LOGO_HUBSPOT, APP_LOGO_INSTAGRAM, APP_LOGO_KFC, APP_LOGO_LINEAR, APP_LOGO_LINKEDIN, APP_LOGO_LUCKIN, APP_LOGO_MCDONALDS, APP_LOGO_MEITUAN, APP_LOGO_MICROSOFT_OUTLOOK, APP_LOGO_NOTION, APP_LOGO_QQMAIL, APP_LOGO_SALESFORCE, APP_LOGO_SLACK, APP_LOGO_SPOTIFY, APP_LOGO_TAOBAO, APP_LOGO_TENCENT_MAPS, APP_LOGO_TICKETMASTER, APP_LOGO_TIKTOK, APP_LOGO_TRELLO, APP_LOGO_WECOM, APP_LOGO_WHATSAPP, APP_LOGO_X, APP_LOGO_YOUTUBE } from './AppLogoDataUri';

type HtmlHomeTextValue = Object | string | number | boolean | null | undefined;

interface HtmlHomeDocumentWithBusy extends HtmlHomeDocument {
  isBusy?: boolean;
  personaAvatarDataUri?: string;
}

const HTML_HOME_CSS: string = `
:root {
  color-scheme: light;
  --paper: #f5f2ee;
  --paper-deep: #ebe5dc;
  --panel: rgba(255, 255, 255, 0.86);
  --panel-strong: #ffffff;
  --ink: #211b17;
  --ink-soft: #493f38;
  --muted: #786e66;
  --line: rgba(33, 27, 23, 0.12);
  --accent: #995f4c;
  --accent-soft: rgba(153, 95, 76, 0.13);
  --red: #b04a42;
  --red-soft: rgba(176, 74, 66, 0.1);
  --amber: #9a6a22;
  --shadow: 0 14px 34px rgba(44, 34, 26, 0.08);
  --train: #397a55;
  --train-soft: rgba(57, 122, 85, 0.12);
  --flight: #476f9f;
  --flight-soft: rgba(71, 111, 159, 0.12);
  --amap: #2f8f5f;
  --amap-soft: rgba(47, 143, 95, 0.12);
  --tencent: #2d78a8;
  --tencent-soft: rgba(45, 120, 168, 0.12);
  --baidu: #b34f66;
  --baidu-soft: rgba(179, 79, 102, 0.12);
  --meituan: #a77816;
  --meituan-soft: rgba(167, 120, 22, 0.14);
  --taobao: #7a5bb5;
  --taobao-soft: rgba(122, 91, 181, 0.12);
  --mcd: #b57915;
  --mcd-soft: rgba(181, 121, 21, 0.14);
  --luckin: #466eb8;
  --luckin-soft: rgba(70, 110, 184, 0.12);
  --gmail: #c24636;
  --gmail-soft: rgba(194, 70, 54, 0.12);
  --qqmail: #2d78c4;
  --qqmail-soft: rgba(45, 120, 196, 0.12);
  --youtube: #c4302b;
  --youtube-soft: rgba(196, 48, 43, 0.12);
  --bilibili: #2d8fbd;
  --bilibili-soft: rgba(45, 143, 189, 0.12);
  --social-x: #111111;
  --social-x-soft: rgba(17, 17, 17, 0.1);
  --social-slack: #4a154b;
  --social-slack-soft: rgba(74, 21, 75, 0.12);
  --social-wecom: #2368d8;
  --social-wecom-soft: rgba(35, 104, 216, 0.12);
  --github: #24292f;
  --github-soft: rgba(36, 41, 47, 0.1);
  --drive: #1a73e8;
  --drive-soft: rgba(26, 115, 232, 0.12);
  --docs: #2b67d8;
  --docs-soft: rgba(43, 103, 216, 0.12);
  --composio: #6f5bd6;
  --composio-soft: rgba(111, 91, 214, 0.12);
  --outlook: #0078d4;
  --outlook-soft: rgba(0, 120, 212, 0.12);
  --discord: #5865f2;
  --discord-soft: rgba(88, 101, 242, 0.12);
  --linkedin: #0a66c2;
  --linkedin-soft: rgba(10, 102, 194, 0.12);
  --whatsapp: #25d366;
  --whatsapp-soft: rgba(37, 211, 102, 0.13);
  --instagram: #c13584;
  --instagram-soft: rgba(193, 53, 132, 0.12);
  --spotify: #1db954;
  --spotify-soft: rgba(29, 185, 84, 0.13);
  --tiktok: #111111;
  --tiktok-soft: rgba(17, 17, 17, 0.1);
  --ticketmaster: #026cdf;
  --ticketmaster-soft: rgba(2, 108, 223, 0.12);
  --ride: #1f7a61;
  --ride-dark: #155c49;
  --ride-soft: rgba(31, 122, 97, 0.12);
  --ride-blue: #356fa3;
  --ride-blue-soft: rgba(53, 111, 163, 0.12);
  --mail-inbox-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='black' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpolyline points='22 12 16 12 14 15 10 15 8 12 2 12'/%3E%3Cpath d='M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z'/%3E%3C/svg%3E");
}
* { box-sizing: border-box; }
body {
  margin: 0;
  min-height: 100dvh;
  background:
    linear-gradient(180deg, rgba(255,255,255,0.72) 0%, rgba(255,255,255,0) 45%),
    var(--paper);
  color: var(--ink);
  font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Noto Sans SC", "Helvetica Neue", Arial, sans-serif;
  letter-spacing: 0;
  -webkit-font-smoothing: antialiased;
}
button { font: inherit; cursor: pointer; }
button:disabled {
  cursor: default;
  opacity: 0.5;
}
.shell {
  width: min(100%, 760px);
  margin: 0 auto;
  padding: 14px 14px calc(96px + env(safe-area-inset-bottom, 0px));
}
.hero {
  padding: 18px 2px 14px;
  border-bottom: 1px solid var(--line);
}
.persona-banner {
  display: flex;
  align-items: center;
  gap: 10px;
  margin: 12px 0 4px;
  border: 1px solid var(--line);
  border-radius: 16px;
  padding: 10px 12px;
  background: var(--panel);
  box-shadow: var(--shadow);
}
.persona-avatar {
  display: grid;
  place-items: center;
  width: 38px;
  height: 38px;
  border-radius: 14px;
  background: var(--accent-soft);
  color: var(--accent);
  font-size: 15px;
  font-weight: 840;
}
.persona-avatar img {
  width: 30px;
  height: 30px;
  object-fit: contain;
}
.persona-copy {
  min-width: 0;
  flex: 1 1 auto;
}
.persona-title {
  color: var(--ink);
  font-size: 14px;
  font-weight: 820;
  line-height: 1.25;
}
.persona-subtitle {
  margin-top: 4px;
  color: var(--muted);
  font-size: 12px;
  line-height: 1.4;
}
.eyebrow, .label, .meta {
  color: var(--muted);
  font-size: 11px;
  line-height: 1.35;
  letter-spacing: 0;
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
}
h1, h2, h3, p { margin: 0; }
h1 {
  margin-top: 8px;
  max-width: 12em;
  font-size: 27px;
  line-height: 1.08;
  font-weight: 760;
}
h2 {
  font-size: 16px;
  line-height: 1.25;
  font-weight: 760;
}
h3 {
  font-size: 17px;
  line-height: 1.24;
  font-weight: 760;
}
.subtitle {
  margin-top: 8px;
  color: var(--ink-soft);
  font-size: 14px;
  line-height: 1.55;
}
.chipbar {
  position: sticky;
  top: 0;
  z-index: 2;
  display: flex;
  gap: 8px;
  overflow-x: auto;
  padding: 10px 0 12px;
  background: rgba(245, 242, 238, 0.92);
  backdrop-filter: blur(12px);
}
.chip {
  flex: 0 0 auto;
  border: 1px solid var(--line);
  border-radius: 999px;
  padding: 8px 12px;
  background: var(--panel-strong);
  color: var(--ink-soft);
  font-size: 12px;
  line-height: 1;
  box-shadow: 0 2px 8px rgba(48, 34, 18, 0.05);
}
.metrics {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0 12px;
  margin-top: 12px;
}
.metric, .row {
  min-width: 0;
  border-top: 1px solid var(--line);
  padding: 8px 0;
  background: transparent;
}
.hero .metric {
  border: 1px solid var(--line);
  border-radius: 16px;
  padding: 9px 10px;
  background: var(--panel);
}
.value {
  margin-top: 4px;
  overflow-wrap: anywhere;
  font-size: 14px;
  line-height: 1.35;
  font-weight: 680;
}
.section {
  margin-top: 16px;
}
.section-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 10px;
  margin-bottom: 9px;
}
.block, .timeline-item, .empty, .history-item {
  border: 1px solid var(--line);
  border-radius: 16px;
  background: var(--panel);
  box-shadow: var(--shadow);
}
.block {
  --kind-accent: var(--accent);
  --kind-soft: var(--accent-soft);
  position: relative;
  overflow: hidden;
  padding: 12px 12px 13px;
  margin-top: 10px;
  border-color: var(--line);
}
.block:first-of-type { margin-top: 0; }
.block[data-kind="travel-option"],
.block[data-kind="train-option"] {
  --kind-accent: var(--train);
  --kind-soft: var(--train-soft);
}
.block[data-kind="flight-option"] {
  --kind-accent: var(--flight);
  --kind-soft: var(--flight-soft);
}
.block[data-kind="food-result"] {
  --kind-accent: var(--red);
  --kind-soft: var(--red-soft);
}
.block[data-source-key="travel-train"] {
  --kind-accent: var(--train);
  --kind-soft: var(--train-soft);
}
.block[data-source-key="travel-flight"] {
  --kind-accent: var(--flight);
  --kind-soft: var(--flight-soft);
}
.block[data-source-key="food-amap"] {
  --kind-accent: var(--amap);
  --kind-soft: var(--amap-soft);
}
.block[data-source-key="food-tencent"] {
  --kind-accent: var(--tencent);
  --kind-soft: var(--tencent-soft);
}
.block[data-source-key="food-baidu"] {
  --kind-accent: var(--baidu);
  --kind-soft: var(--baidu-soft);
}
.block[data-source-key="food-meituan"] {
  --kind-accent: var(--meituan);
  --kind-soft: var(--meituan-soft);
}
.block[data-source-key="food-taobao"] {
  --kind-accent: var(--taobao);
  --kind-soft: var(--taobao-soft);
}
.block[data-source-key="food-mcd"] {
  --kind-accent: var(--mcd);
  --kind-soft: var(--mcd-soft);
}
.block[data-source-key="food-luckin"] {
  --kind-accent: var(--luckin);
  --kind-soft: var(--luckin-soft);
}
.block[data-kind="dynamic-tool-connect"],
.block[data-kind="generic-tool-result"],
.block[data-kind="StripeReceivingAccountCard"] {
  --kind-accent: var(--amber);
  --kind-soft: rgba(154, 100, 24, 0.12);
}
.block[data-kind="persona-memory-update"] {
  --kind-accent: var(--accent);
  --kind-soft: var(--accent-soft);
  padding: 0;
  border-color: rgba(153, 95, 76, 0.26);
  background:
    linear-gradient(180deg, rgba(255, 252, 247, 0.98) 0%, rgba(255, 255, 255, 0.96) 100%);
  box-shadow: 0 18px 42px rgba(71, 48, 35, 0.12);
}
.block[data-kind="persona-memory-update"]::before {
  width: 0;
}
.block[data-kind="social-hub-item"],
.block[data-kind="social-hub-connection"],
.block[data-kind="social-hub-draft"] {
  border-color: rgba(42, 124, 255, 0.24);
}
.block[data-kind="social-hub-draft"] {
  background: rgba(36, 126, 94, 0.08);
}
.block[data-source-key="mail-gmail"] {
  --kind-accent: var(--gmail);
  --kind-soft: var(--gmail-soft);
  border-color: rgba(194, 70, 54, 0.45);
}
.block[data-source-key="mail-qq"] {
  --kind-accent: var(--qqmail);
  --kind-soft: var(--qqmail-soft);
  border-color: rgba(45, 120, 196, 0.45);
}
.block[data-source-key="media-youtube"] {
  --kind-accent: var(--youtube);
  --kind-soft: var(--youtube-soft);
  border-color: rgba(196, 48, 43, 0.45);
}
.block[data-source-key="media-bilibili"] {
  --kind-accent: var(--bilibili);
  --kind-soft: var(--bilibili-soft);
  border-color: rgba(45, 143, 189, 0.45);
}
.block[data-source-key="composio-github"] {
  --kind-accent: var(--github);
  --kind-soft: var(--github-soft);
  border-color: rgba(36, 41, 47, 0.28);
}
.block[data-source-key="composio-drive"] {
  --kind-accent: var(--drive);
  --kind-soft: var(--drive-soft);
  border-color: rgba(26, 115, 232, 0.3);
}
.block[data-source-key="composio-docs"] {
  --kind-accent: var(--docs);
  --kind-soft: var(--docs-soft);
  border-color: rgba(43, 103, 216, 0.3);
}
.block[data-source-key="composio-slack"] {
  --kind-accent: var(--social-slack);
  --kind-soft: var(--social-slack-soft);
  border-color: rgba(74, 21, 75, 0.28);
}
.block[data-source-key="composio-outlook"] {
  --kind-accent: var(--outlook);
  --kind-soft: var(--outlook-soft);
  border-color: rgba(0, 120, 212, 0.28);
}
.block[data-source-key="composio-discord"] {
  --kind-accent: var(--discord);
  --kind-soft: var(--discord-soft);
  border-color: rgba(88, 101, 242, 0.28);
}
.block[data-source-key="composio-linkedin"] {
  --kind-accent: var(--linkedin);
  --kind-soft: var(--linkedin-soft);
  border-color: rgba(10, 102, 194, 0.28);
}
.block[data-source-key="composio-whatsapp"] {
  --kind-accent: var(--whatsapp);
  --kind-soft: var(--whatsapp-soft);
  border-color: rgba(37, 211, 102, 0.3);
}
.block[data-source-key="composio-instagram"] {
  --kind-accent: var(--instagram);
  --kind-soft: var(--instagram-soft);
  border-color: rgba(193, 53, 132, 0.28);
}
.block[data-source-key="composio-spotify"] {
  --kind-accent: var(--spotify);
  --kind-soft: var(--spotify-soft);
  border-color: rgba(29, 185, 84, 0.3);
}
.block[data-source-key="composio-tiktok"] {
  --kind-accent: var(--tiktok);
  --kind-soft: var(--tiktok-soft);
  border-color: rgba(17, 17, 17, 0.18);
}
.block[data-source-key="composio-ticketmaster"] {
  --kind-accent: var(--ticketmaster);
  --kind-soft: var(--ticketmaster-soft);
  border-color: rgba(2, 108, 223, 0.28);
}
.block[data-source-key="composio"] {
  --kind-accent: var(--composio);
  --kind-soft: var(--composio-soft);
  border-color: rgba(111, 91, 214, 0.28);
}
.block[data-source-key="social-x"] {
  --kind-accent: var(--social-x);
  --kind-soft: var(--social-x-soft);
}
.block[data-source-key="social-slack"] {
  --kind-accent: var(--social-slack);
  --kind-soft: var(--social-slack-soft);
}
.block[data-source-key="social-wecom"] {
  --kind-accent: var(--social-wecom);
  --kind-soft: var(--social-wecom-soft);
}
.block[data-source-key="social-discord"] {
  --kind-accent: var(--discord);
  --kind-soft: var(--discord-soft);
}
.block[data-source-key="social-linkedin"] {
  --kind-accent: var(--linkedin);
  --kind-soft: var(--linkedin-soft);
}
.block[data-source-key="social-whatsapp"] {
  --kind-accent: var(--whatsapp);
  --kind-soft: var(--whatsapp-soft);
}
.block[data-source-key="social-instagram"] {
  --kind-accent: var(--instagram);
  --kind-soft: var(--instagram-soft);
}
.block::before {
  content: "";
  position: absolute;
  inset: 0 auto 0 0;
  width: 4px;
  background: var(--kind-accent);
}
.block[data-expandable="true"] {
  cursor: pointer;
}
.block:not(.expanded) .details {
  display: none;
}
.details {
  margin-top: 10px;
  border-top: 1px solid var(--line);
  padding-top: 10px;
}
.expand-button {
  border: 1px solid var(--line);
  border-radius: 999px;
  flex: 0 0 auto;
  min-width: 58px;
  min-height: 34px;
  padding: 7px 12px;
  background: var(--kind-soft);
  color: var(--kind-accent);
  font-size: 13px;
  font-weight: 760;
  line-height: 1;
  white-space: nowrap;
  box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.58);
}
.block-top {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 12px;
}
.block-top > * {
  min-width: 0;
}
.block-title {
  flex: 1 1 auto;
}
h3, .subtitle, .kind-tag, .status, .action, .chip, .label, .meta {
  min-width: 0;
  overflow-wrap: anywhere;
}
.kind-tag {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  width: fit-content;
  margin-bottom: 7px;
  border-radius: 11px;
  padding: 4px 7px;
  background: var(--kind-soft);
  color: var(--kind-accent);
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  font-size: 10px;
  line-height: 1;
}
.kind-tag .mail-source-icon {
  width: 18px;
  height: 18px;
  border-radius: 5px;
  background: white;
  object-fit: cover;
  box-shadow: 0 0 0 1px rgba(33, 27, 23, 0.1);
}
.status {
  align-self: flex-start;
  max-width: min(42%, 180px);
  border-radius: 999px;
  padding: 6px 8px;
  background: var(--kind-soft);
  color: var(--kind-accent);
  font-size: 11px;
  line-height: 1.25;
  text-align: right;
  white-space: normal;
}
.rows {
  display: grid;
  gap: 7px;
  margin-top: 8px;
}
.composio-preview {
  margin-top: 12px;
  border: 1px solid rgba(33, 27, 23, 0.11);
  border-radius: 16px;
  padding: 12px;
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.92), rgba(255, 250, 244, 0.78));
  box-shadow: 0 12px 28px rgba(44, 34, 26, 0.07);
}
.composio-preview-head {
  display: flex;
  align-items: center;
  gap: 10px;
}
.composio-app-logo {
  flex: 0 0 auto;
  width: 40px;
  height: 40px;
  border-radius: 12px;
  background: white;
  object-fit: cover;
  box-shadow: 0 0 0 1px rgba(33, 27, 23, 0.1), 0 8px 18px rgba(44, 34, 26, 0.08);
}
.composio-app-copy {
  min-width: 0;
  flex: 1 1 auto;
}
.composio-app-name {
  color: var(--ink);
  font-size: 14px;
  font-weight: 840;
  line-height: 1.25;
}
.composio-app-meta {
  margin-top: 3px;
  color: var(--muted);
  font-size: 12px;
  line-height: 1.35;
  overflow-wrap: anywhere;
}
.composio-items {
  display: grid;
  gap: 8px;
  margin-top: 11px;
}
.composio-item {
  min-width: 0;
  border: 1px solid var(--line);
  border-radius: 14px;
  padding: 10px 11px;
  background: rgba(255, 255, 255, 0.74);
}
.composio-item-title {
  color: var(--ink);
  font-size: 13px;
  font-weight: 800;
  line-height: 1.35;
  overflow-wrap: anywhere;
}
.composio-item-detail {
  margin-top: 5px;
  color: var(--muted);
  font-size: 12px;
  line-height: 1.42;
  overflow-wrap: anywhere;
}
.composio-item-link {
  display: inline-flex;
  width: fit-content;
  max-width: 100%;
  margin-top: 7px;
  color: var(--kind-accent);
  font-size: 12px;
  font-weight: 720;
  text-decoration: none;
  overflow-wrap: anywhere;
}
.memory-update-card {
  padding: 14px;
}
.memory-update-head {
  display: flex;
  align-items: flex-start;
  gap: 11px;
}
.memory-update-avatar {
  display: grid;
  flex: 0 0 auto;
  place-items: center;
  width: 42px;
  height: 42px;
  border-radius: 15px;
  background: var(--accent-soft);
  color: var(--accent);
  font-size: 16px;
  font-weight: 840;
  box-shadow: inset 0 0 0 1px rgba(153, 95, 76, 0.12);
}
.memory-update-avatar img {
  width: 32px;
  height: 32px;
  object-fit: contain;
}
.memory-update-title {
  min-width: 0;
  flex: 1 1 auto;
}
.memory-update-title h3 {
  font-size: 18px;
  line-height: 1.22;
}
.memory-update-kicker {
  width: fit-content;
  margin-top: 5px;
  border-radius: 999px;
  padding: 5px 8px;
  background: var(--accent-soft);
  color: var(--accent);
  font-size: 11px;
  font-weight: 760;
  line-height: 1;
}
.memory-update-reason {
  margin-top: 7px;
  color: var(--muted);
  font-size: 12px;
  line-height: 1.45;
}
.memory-update-hero {
  margin-top: 13px;
  border: 1px solid rgba(153, 95, 76, 0.18);
  border-radius: 15px;
  padding: 13px 14px;
  background:
    radial-gradient(circle at 0% 0%, rgba(153, 95, 76, 0.14), transparent 44%),
    #f9eee8;
}
.memory-update-hero .label,
.memory-panel .label {
  color: var(--accent);
  font-weight: 780;
}
.memory-update-preference {
  margin-top: 7px;
  color: #251a16;
  font-size: 20px;
  font-weight: 820;
  line-height: 1.35;
}
.memory-update-note {
  margin-top: 7px;
  color: var(--muted);
  font-size: 12px;
  line-height: 1.45;
}
.memory-grid {
  display: grid;
  grid-template-columns: minmax(0, 1fr);
  gap: 10px;
  margin-top: 11px;
}
.memory-panel {
  min-width: 0;
  border: 1px solid var(--line);
  border-radius: 14px;
  padding: 11px 12px 12px;
  background: rgba(255, 255, 255, 0.82);
}
.memory-lines {
  display: grid;
  gap: 6px;
  margin-top: 8px;
}
.memory-line {
  color: var(--ink-soft);
  font-size: 12px;
  font-weight: 620;
  line-height: 1.45;
  overflow-wrap: anywhere;
}
.memory-line::before {
  content: "";
  display: inline-block;
  width: 5px;
  height: 5px;
  margin-right: 7px;
  border-radius: 999px;
  background: var(--accent);
  vertical-align: 2px;
}
.timeline {
  border-left: 1px solid var(--line);
  margin-left: 7px;
  padding-left: 11px;
}
.timeline-item {
  position: relative;
  margin-top: 8px;
  padding: 10px 11px;
}
.timeline-item::before {
  content: "";
  position: absolute;
  left: -16px;
  top: 14px;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: var(--accent);
}
.actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 12px;
}
.action {
  min-width: 0;
  border: 1px solid var(--line);
  border-radius: 999px;
  min-height: 40px;
  padding: 9px 13px;
  background: var(--accent);
  color: white;
  font-weight: 650;
  box-shadow: 0 8px 18px rgba(153, 95, 76, 0.14);
  overflow-wrap: anywhere;
  white-space: normal;
}
.action.secondary {
  background: var(--panel-strong);
  color: var(--kind-accent);
  box-shadow: none;
}
.action.payment-icon-action {
  min-width: 0;
  min-height: 0;
  height: auto;
  padding: 6px;
  border-radius: 12px;
  border: 1px solid rgba(33, 27, 23, 0.06);
  background: #fffdfa;
  box-shadow: 0 4px 12px rgba(33, 27, 23, 0.03);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0;
  overflow: hidden;
}
.payment-action-icon {
  width: 100%;
  height: 100%;
  border-radius: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  background: transparent;
}
.payment-action-icon-image {
  display: block;
  width: auto;
  height: auto;
  max-width: 100%;
  max-height: 100%;
  object-fit: contain;
  border-radius: 0;
}
.stripe-onboarding-link {
  display: inline-flex;
  align-items: center;
  width: fit-content;
  margin-top: 12px;
  border: 1px solid var(--line);
  border-radius: 999px;
  min-height: 40px;
  padding: 9px 13px;
  color: var(--kind-accent);
  background: var(--panel-strong);
  font-weight: 650;
  text-decoration: none;
}
.credential {
  display: grid;
  gap: 8px;
  margin-top: 12px;
  border: 1px dashed rgba(15, 118, 110, 0.34);
  border-radius: 8px;
  padding: 10px;
  background: rgba(15, 118, 110, 0.08);
}
.credential input {
  width: 100%;
  border: 1px solid var(--line);
  border-radius: 8px;
  padding: 10px 11px;
  background: white;
  color: var(--ink);
  font: inherit;
}
.raw {
  margin: 10px 0 0;
  overflow: auto;
  border-radius: 12px;
  padding: 10px;
  background: rgba(24, 22, 20, 0.06);
  color: #332d28;
  font-size: 12px;
  line-height: 1.45;
  white-space: pre-wrap;
}
.google-map-preview {
  position: relative;
  overflow: hidden;
  margin-top: 12px;
  border: 1px solid var(--line);
  border-radius: 14px;
  background:
    radial-gradient(circle at 28% 22%, rgba(65, 95, 155, 0.18), transparent 23%),
    radial-gradient(circle at 72% 68%, rgba(135, 98, 59, 0.16), transparent 25%),
    linear-gradient(135deg, rgba(255, 255, 255, 0.94), rgba(237, 242, 247, 0.92));
  aspect-ratio: 16 / 9;
}
.google-map-preview::before {
  content: "";
  position: absolute;
  inset: 0;
  background:
    linear-gradient(90deg, rgba(33, 27, 23, 0.05) 1px, transparent 1px),
    linear-gradient(0deg, rgba(33, 27, 23, 0.05) 1px, transparent 1px);
  background-size: 34px 34px;
  pointer-events: none;
}
.google-map-preview::after {
  content: "Maps";
  position: absolute;
  left: 14px;
  top: 14px;
  z-index: 2;
  border-radius: 10px;
  padding: 8px 10px;
  background: rgba(255, 255, 255, 0.82);
  color: #2563af;
  font-weight: 760;
  box-shadow: 0 8px 18px rgba(44, 34, 26, 0.1);
}
.google-map-preview iframe {
  display: block;
  position: relative;
  z-index: 1;
  width: 100%;
  height: 100%;
  border: 0;
  opacity: 0.18;
}
.media-player {
  overflow: hidden;
  margin-top: 12px;
  border: 1px solid var(--line);
  border-radius: 14px;
  background: #0f0d0b;
  aspect-ratio: 16 / 9;
  box-shadow: 0 12px 28px rgba(20, 14, 10, 0.16);
}
.media-player iframe {
  display: block;
  width: 100%;
  height: 100%;
  border: 0;
  background: #0f0d0b;
}
.empty {
  padding: 18px;
  color: var(--muted);
  line-height: 1.55;
  border-style: dashed;
  background: rgba(255, 250, 242, 0.62);
}
.filter-empty {
  display: none;
  margin-top: 10px;
}
.history-item {
  padding: 10px 11px;
  margin-top: 8px;
}
body[data-scene] {
  --scene-accent: #995f4c;
  --scene-accent-2: #476f9f;
  --scene-bg: #f5f2ee;
  --scene-panel: rgba(255, 255, 255, 0.78);
  --scene-image: url('https://images.unsplash.com/photo-1497366754035-f200968a6e72?auto=format&fit=crop&w=1200&q=80');
  background:
    radial-gradient(circle at 12% 0%, rgba(255, 255, 255, 0.9), transparent 31%),
    linear-gradient(180deg, rgba(255, 255, 255, 0.5), transparent 44%),
    var(--scene-bg);
}
body[data-scene="gmail"] {
  --scene-accent: #c24636;
  --scene-accent-2: #476f9f;
  --scene-bg: #f7f3ee;
  --scene-image: url('https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=1200&q=80');
}
body[data-scene="luckin"] {
  --scene-accent: #466eb8;
  --scene-accent-2: #356fc0;
  --scene-bg: #f5f2ee;
  --scene-image: url('resource://rawfile/luckin_store.jpeg');
  background: var(--scene-bg);
}
body[data-scene="luckin"] .shell {
  min-height: 100dvh;
}
body[data-scene="luckin"] .section.blocks-luckin {
  margin-top: 0;
  min-height: calc(100dvh - 24px - env(safe-area-inset-bottom, 0px));
  border-radius: 28px;
  overflow: hidden;
  border: 1px solid rgba(33, 27, 23, 0.1);
  padding: 14px;
  background:
    linear-gradient(180deg, rgba(18, 14, 10, 0.72) 0%, rgba(44, 34, 26, 0.38) 42%, rgba(255, 250, 244, 0.12) 100%),
    var(--scene-image) center/cover;
  box-shadow: 0 24px 54px rgba(44, 34, 26, 0.18);
}
body[data-scene="luckin"] .section.blocks-luckin.blocks-luckin-confirm {
  position: relative;
  padding: 0 0 14px;
  overflow: visible;
  background:
    linear-gradient(180deg, rgba(255, 250, 244, 0.92) 0%, rgba(255, 252, 248, 0.86) 42%, rgba(255, 250, 244, 0.78) 100%),
    url('resource://rawfile/luckin_store.jpeg') center/cover;
}
.luckin-confirm-hero {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 252px;
  z-index: 0;
  margin: 0;
  overflow: hidden;
  pointer-events: none;
}
.luckin-confirm-hero .luckin-coconut-float {
  position: absolute;
  inset: 0;
  z-index: 1;
  width: 100%;
  height: 100%;
  margin: 0;
  background-color: #e8f5ec;
  background-image:
    linear-gradient(180deg,
      rgba(255, 250, 244, 0) 0%,
      rgba(255, 250, 244, 0) 48%,
      rgba(255, 250, 244, 0.22) 68%,
      rgba(255, 250, 244, 0.58) 82%,
      rgba(255, 250, 244, 0.94) 96%,
      #fffaf4 100%),
    url('resource://rawfile/luckin_coconut_many.jpeg');
  background-position: center top, center top;
  background-size: cover, cover;
  background-repeat: no-repeat, no-repeat;
}
.luckin-confirm-head {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  z-index: 2;
  margin: 0;
  padding: 18px 16px 12px;
  pointer-events: none;
}
body[data-scene="luckin"] .section.blocks-luckin.blocks-luckin-confirm .luckin-confirm-head h2 {
  color: #fffaf4;
  text-shadow: 0 2px 12px rgba(18, 14, 10, 0.55);
}
body[data-scene="luckin"] .section.blocks-luckin.blocks-luckin-confirm .luckin-confirm-body {
  position: relative;
  z-index: 10;
  margin-top: 114px;
  padding: 0 14px 14px;
  pointer-events: auto;
}
.luckin-product-badge {
  position: absolute;
  top: 0;
  left: 50%;
  z-index: 15;
  width: 76px;
  height: 76px;
  margin-left: -38px;
  transform: translateY(-50%);
  border-radius: 50%;
  padding: 3px;
  background: #fffaf4;
  border: 2px solid rgba(255, 255, 255, 0.96);
  box-shadow: 0 10px 28px rgba(44, 34, 26, 0.2);
  overflow: hidden;
  pointer-events: none;
}
.luckin-product-badge-image {
  display: block;
  width: 100%;
  height: 100%;
  border-radius: 50%;
  object-fit: cover;
  background: #fffaf4;
}
body[data-scene="luckin"] .luckin-order-card.luckin-order-confirm .luckin-order-stage {
  min-height: 0;
  padding: 44px 16px 8px;
  pointer-events: auto;
}
body[data-scene="luckin"] .section.blocks-luckin.blocks-luckin-confirm .luckin-order-headline {
  max-width: 100%;
  padding-right: 0;
}
body[data-scene="luckin"] .section.blocks-luckin.blocks-luckin-confirm .luckin-option-panel {
  max-width: 100%;
  padding-right: 0;
}
body[data-scene="luckin"] .section.blocks-luckin.blocks-luckin-confirm .luckin-confirm-body .block.luckin-order-block {
  position: relative;
  z-index: 10;
  margin: 0;
  padding: 0;
  background: transparent;
  backdrop-filter: none;
  -webkit-backdrop-filter: none;
}
body[data-scene="luckin"] .section.blocks-luckin.blocks-luckin-confirm .luckin-order-card.luckin-order-confirm {
  position: relative;
  z-index: 10;
  background: #fffaf4;
  padding-bottom: 64px;
}
.luckin-coconut-float {
  display: block;
  background-color: #d9efe2;
  background-image: url('resource://rawfile/luckin_coconut_many.jpeg');
  background-position: center;
  background-size: cover;
  background-repeat: no-repeat;
  border: 0;
  box-shadow: none;
}
body[data-scene="luckin"] .section.blocks-luckin .section-head h2 {
  color: rgba(255, 250, 244, 0.96);
}
.luckin-relocate {
  border: 0;
  background: transparent;
  padding: 0;
  font-size: 13px;
  font-weight: 600;
  color: rgba(214, 228, 255, 0.96);
  cursor: pointer;
}
.luckin-relocate:disabled {
  opacity: 0.6;
  cursor: default;
}
body[data-scene="luckin"] .section.blocks-luckin .section-head {
  margin: 0 2px 12px;
}
body[data-scene="luckin"] .section.blocks-luckin .block,
body[data-scene="luckin"] .section.blocks-luckin .empty {
  background: rgba(255, 250, 244, 0.92);
  backdrop-filter: blur(10px);
  -webkit-backdrop-filter: blur(10px);
}
body[data-scene="luckin"] .block.luckin-shop-block {
  padding: 0;
  background: transparent;
  box-shadow: none;
  border: 0;
}
.luckin-shop-picker {
  display: grid;
  gap: 0;
  border-radius: 18px;
  overflow: hidden;
  background: rgba(255, 255, 255, 0.96);
  border: 1px solid rgba(33, 27, 23, 0.08);
}
.luckin-shop-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 14px 16px 10px;
  border-bottom: 1px solid rgba(33, 27, 23, 0.08);
}
.luckin-shop-title {
  margin: 0;
  font-size: 17px;
  font-weight: 650;
  color: #211b17;
}
.luckin-shop-list {
  display: grid;
}
.luckin-shop-row {
  display: block;
  width: 100%;
  border: 0;
  border-bottom: 1px solid rgba(33, 27, 23, 0.08);
  background: rgba(255, 255, 255, 0.72);
  padding: 14px 16px;
  text-align: left;
  cursor: pointer;
  font: inherit;
  color: inherit;
}
.luckin-shop-row:last-child {
  border-bottom: 0;
}
.luckin-shop-row.is-selected {
  background: #e8e2da;
}
.luckin-shop-row:active:not(:disabled) {
  background: #e0dbd3;
}
.luckin-shop-row:disabled {
  opacity: 0.72;
  cursor: default;
}
.luckin-shop-line {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
}
.luckin-shop-name {
  min-width: 0;
  font-size: 15px;
  font-weight: 650;
  color: #211b17;
  line-height: 1.35;
}
.luckin-shop-distance {
  flex: 0 0 auto;
  font-size: 13px;
  font-weight: 600;
  color: #466eb8;
}
.luckin-shop-address {
  margin-top: 4px;
  font-size: 12px;
  line-height: 1.45;
  color: #786e66;
}
.luckin-shop-status {
  display: inline-block;
  margin-top: 6px;
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 11px;
  color: #2f7a4f;
  background: rgba(47, 122, 79, 0.12);
}
body[data-scene="luckin"] .block.luckin-order-block {
  padding: 0;
  background: transparent;
  box-shadow: none;
  border: 0;
}
body[data-scene="luckin"] .block.luckin-order-block::before {
  display: none;
}
.luckin-order-card {
  display: grid;
  gap: 0;
  border-radius: 18px;
  overflow: hidden;
  background: rgba(255, 255, 255, 0.96);
  border: 1px solid rgba(33, 27, 23, 0.08);
}
.luckin-order-card.luckin-order-confirm {
  background: #fffaf4;
  border: 1px solid rgba(33, 27, 23, 0.1);
  box-shadow: 0 18px 42px rgba(44, 34, 26, 0.14);
  border-radius: 22px;
}
.luckin-order-stage {
  position: relative;
  min-height: 196px;
  padding: 16px 16px 8px;
}
.luckin-order-headline {
  max-width: calc(100% - 188px);
  padding-right: 12px;
}
.luckin-order-visual {
  position: relative;
  isolation: isolate;
}
.luckin-product-float {
  position: absolute;
  right: 8px;
  top: 8px;
  z-index: 2;
  width: 168px;
  height: 168px;
  border-radius: 28px;
  padding: 10px;
  background: rgba(255, 255, 255, 0.98);
  box-shadow:
    0 22px 44px rgba(44, 34, 26, 0.2),
    0 0 0 1px rgba(33, 27, 23, 0.08);
}
.luckin-product-float-image {
  display: block;
  width: 100%;
  height: 100%;
  border-radius: 20px;
  object-fit: cover;
  background: #fffaf4;
}
.luckin-option-panel {
  display: grid;
  gap: 12px;
  margin-top: 12px;
  max-width: calc(100% - 188px);
  padding-right: 12px;
  position: relative;
  z-index: 2;
  pointer-events: auto;
}
.luckin-option-panel.is-updating {
  pointer-events: none;
}
.luckin-option-group {
  display: grid;
  gap: 8px;
}
.luckin-option-label {
  font-size: 12px;
  font-weight: 650;
  color: #5f564d;
}
.luckin-option-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}
.luckin-option-chip {
  border: 1px solid rgba(33, 27, 23, 0.12);
  border-radius: 999px;
  padding: 7px 12px;
  background: rgba(255, 255, 255, 0.88);
  color: #5f564d;
  font-size: 12px;
  line-height: 1.2;
  cursor: pointer;
  pointer-events: auto;
  touch-action: manipulation;
  -webkit-tap-highlight-color: rgba(70, 110, 184, 0.16);
}
.luckin-option-chip.is-alt {
  border-style: dashed;
  background: rgba(255, 255, 255, 0.72);
  cursor: pointer;
}
.luckin-option-chip.is-alt:active {
  background: rgba(70, 110, 184, 0.14);
  border-color: rgba(70, 110, 184, 0.42);
}
.luckin-option-chip.is-selected {
  border-color: rgba(70, 110, 184, 0.42);
  background: rgba(70, 110, 184, 0.14);
  color: #2f4f86;
  font-weight: 650;
  pointer-events: none;
}
.luckin-option-chip:disabled {
  opacity: 0.55;
  cursor: default;
  pointer-events: none;
}
.luckin-product-hero {
  width: 100%;
  aspect-ratio: 4 / 3;
  background: linear-gradient(180deg, rgba(245, 240, 232, 0.9), rgba(255, 255, 255, 0.96));
  overflow: hidden;
}
.luckin-product-image {
  display: block;
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.luckin-order-copy {
  position: relative;
  z-index: 1;
  padding: 0 16px 12px;
}
.luckin-order-card.luckin-order-confirm .luckin-order-copy {
  padding-top: 0;
}
body[data-scene="luckin"] .luckin-order-card.luckin-order-confirm .luckin-order-product-group {
  display: grid;
  gap: 8px;
  margin-top: 12px;
}
body[data-scene="luckin"] .luckin-order-card.luckin-order-confirm .luckin-order-product-value {
  font-size: 13px;
  line-height: 1.45;
  color: #211b17;
  word-break: break-word;
}
body[data-scene="luckin"] .luckin-order-card.luckin-order-confirm .actions {
  position: absolute;
  right: 14px;
  bottom: 14px;
  margin: 0;
  padding: 0;
  justify-content: flex-end;
  z-index: 20;
  pointer-events: auto;
}
body[data-scene="luckin"] .luckin-order-card.luckin-order-confirm .luckin-order-copy {
  position: relative;
  z-index: 2;
  pointer-events: auto;
}
.luckin-order-title {
  margin: 0;
  font-size: 17px;
  font-weight: 650;
  color: #211b17;
}
.luckin-order-rows {
  display: grid;
  gap: 8px;
  margin-top: 10px;
}
.luckin-order-price-bar {
  display: flex;
  align-items: stretch;
  justify-content: space-between;
  gap: 10px;
  margin-top: 12px;
  padding-top: 12px;
  border-top: 1px solid rgba(33, 27, 23, 0.08);
}
.luckin-price-item {
  flex: 1;
  display: grid;
  gap: 4px;
  justify-items: center;
  text-align: center;
}
.luckin-price-item .label {
  font-size: 11px;
  font-weight: 600;
  color: #786e66;
}
.luckin-price-item .value {
  font-size: 15px;
  font-weight: 700;
  line-height: 1.2;
}
.luckin-price-item.is-origin .value {
  color: #9a9088;
  text-decoration: line-through;
}
.luckin-price-item.is-discount .value {
  color: #2f7a4f;
}
.luckin-price-item.is-pay .value {
  color: #c24636;
}
.luckin-order-row {
  display: grid;
  grid-template-columns: 72px minmax(0, 1fr);
  gap: 10px;
  align-items: start;
}
.luckin-order-row .label {
  color: #786e66;
  font-size: 12px;
}
.luckin-order-row .value {
  color: #211b17;
  font-size: 13px;
  line-height: 1.45;
  word-break: break-word;
}
body[data-scene="luckin"] .luckin-order-card:not(.luckin-order-confirm) .actions {
  display: flex;
  flex-wrap: wrap;
  align-items: stretch;
  gap: 10px;
  width: 100%;
  padding: 14px 16px 16px;
}
body[data-scene="luckin"] .luckin-order-card:not(.luckin-order-confirm) .action.payment-icon-action {
  flex: 1 1 0;
  width: auto;
  height: 38px;
  border-color: rgba(33, 27, 23, 0.06);
  background: #fffdfa;
  color: #211b17;
  box-shadow: 0 4px 12px rgba(33, 27, 23, 0.03);
}
body[data-scene="luckin"] .luckin-order-card:not(.luckin-order-confirm) .action:not(.payment-icon-action) {
  flex: 1 1 100%;
  width: 100%;
  border-radius: 14px;
  border-color: rgba(33, 27, 23, 0.06);
  background: rgba(255, 255, 255, 0.72);
  color: #493f38;
  box-shadow: none;
}
body[data-scene="luckin"] .section.blocks-luckin.blocks-luckin-payment {
  position: relative;
  padding: 0 0 14px;
  overflow: visible;
  background:
    linear-gradient(180deg, rgba(255, 250, 244, 0.92) 0%, rgba(255, 252, 248, 0.86) 42%, rgba(255, 250, 244, 0.78) 100%),
    url('resource://rawfile/luckin_payment_hero_spill.jpeg') center/cover;
  box-shadow: none;
}
.luckin-payment-hero {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 252px;
  z-index: 0;
  margin: 0;
  overflow: hidden;
  pointer-events: none;
}
.luckin-payment-hero-image {
  position: absolute;
  inset: 0;
  z-index: 1;
  width: 100%;
  height: 100%;
  margin: 0;
  background-color: #e8f5ec;
  background-image:
    linear-gradient(180deg,
      rgba(255, 250, 244, 0) 0%,
      rgba(255, 250, 244, 0) 48%,
      rgba(255, 250, 244, 0.22) 68%,
      rgba(255, 250, 244, 0.58) 82%,
      rgba(255, 250, 244, 0.94) 96%,
      #fffaf4 100%),
    url('resource://rawfile/luckin_payment_hero_spill.jpeg');
  background-position: center top, center top;
  background-size: cover, cover;
  background-repeat: no-repeat, no-repeat;
}
.luckin-payment-head {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  z-index: 2;
  margin: 0;
  padding: 18px 16px 12px;
  pointer-events: none;
}
body[data-scene="luckin"] .section.blocks-luckin.blocks-luckin-payment .luckin-payment-head h2 {
  color: #fffaf4;
  text-shadow: 0 2px 12px rgba(18, 14, 10, 0.55);
}
body[data-scene="luckin"] .section.blocks-luckin.blocks-luckin-payment .luckin-payment-body {
  position: relative;
  z-index: 10;
  margin-top: 114px;
  padding: 0 14px 14px;
  pointer-events: auto;
}
body[data-scene="luckin"] .section.blocks-luckin.blocks-luckin-payment .luckin-payment-body .block.luckin-order-block {
  position: relative;
  z-index: 10;
  margin: 0;
  padding: 0;
  background: transparent;
  backdrop-filter: none;
  -webkit-backdrop-filter: none;
}
body[data-scene="luckin"] .section.blocks-luckin.blocks-luckin-payment .luckin-payment-card {
  position: relative;
  z-index: 10;
  background: #fffaf4;
  padding-bottom: 16px;
}
body[data-scene="luckin"] .section.blocks-luckin.blocks-luckin-payment .section-head {
  display: none;
}
body[data-scene="luckin"] .section.blocks-luckin.blocks-luckin-payment .block.luckin-order-block {
  background: transparent;
  backdrop-filter: none;
  -webkit-backdrop-filter: none;
}
.luckin-payment-card {
  display: grid;
  gap: 0;
  border-radius: 22px;
  overflow: hidden;
  background: #fffaf4;
  border: 1px solid rgba(33, 27, 23, 0.1);
  box-shadow: 0 18px 42px rgba(44, 34, 26, 0.12);
}
.luckin-payment-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 16px 16px 12px;
  border-bottom: 1px solid rgba(33, 27, 23, 0.08);
}
.luckin-payment-header h3 {
  margin: 0;
  font-size: 17px;
  font-weight: 700;
  color: #211b17;
}
.luckin-payment-countdown {
  flex: 0 0 auto;
  font-size: 13px;
  font-weight: 700;
  color: #c24636;
  font-variant-numeric: tabular-nums;
}
.luckin-payment-product {
  display: grid;
  grid-template-columns: 72px minmax(0, 1fr);
  gap: 12px;
  align-items: center;
  padding: 14px 16px;
  border-bottom: 1px solid rgba(33, 27, 23, 0.08);
}
.luckin-payment-product-image {
  display: block;
  width: 72px;
  height: 72px;
  border-radius: 14px;
  object-fit: cover;
  background: #fff;
  border: 1px solid rgba(33, 27, 23, 0.08);
}
.luckin-payment-product-name {
  font-size: 16px;
  font-weight: 700;
  color: #211b17;
  line-height: 1.3;
}
.luckin-payment-store-name {
  margin-top: 4px;
  font-size: 13px;
  line-height: 1.4;
  color: #786e66;
}
.luckin-payment-option-summary {
  margin-top: 4px;
  font-size: 13px;
  line-height: 1.45;
  color: #786e66;
}
.luckin-payment-amount {
  display: grid;
  justify-items: center;
  gap: 6px;
  padding: 18px 16px 14px;
  border-bottom: 1px solid rgba(33, 27, 23, 0.08);
  text-align: center;
}
.luckin-payment-amount-label {
  font-size: 12px;
  font-weight: 650;
  color: #786e66;
}
.luckin-payment-amount-value {
  font-size: 36px;
  font-weight: 800;
  line-height: 1.05;
  color: #211b17;
  font-variant-numeric: tabular-nums;
}
.luckin-payment-amount-meta {
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: 10px;
  font-size: 12px;
  line-height: 1.35;
}
.luckin-payment-amount-meta .origin {
  color: #9a9088;
  text-decoration: line-through;
}
.luckin-payment-amount-meta .discount {
  color: #2f7a4f;
  font-weight: 650;
}
.luckin-payment-methods {
  padding: 14px 16px;
  border-bottom: 1px solid rgba(33, 27, 23, 0.08);
}
.luckin-payment-methods-label {
  margin-bottom: 10px;
  font-size: 13px;
  font-weight: 650;
  color: #493f38;
}
.luckin-payment-methods .actions {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 10px;
  margin-top: 0;
  padding: 0;
}
.luckin-payment-methods .action.payment-icon-action {
  min-width: 0;
  width: 100%;
  min-height: 72px;
  height: auto;
  padding: 8px 6px 6px;
  border-radius: 12px;
  border-color: rgba(33, 27, 23, 0.1);
  background: #fff;
  box-shadow: 0 4px 12px rgba(33, 27, 23, 0.03);
  display: grid;
  gap: 4px;
  justify-items: center;
  align-content: center;
}
.luckin-payment-methods .payment-action-icon {
  width: 100%;
  min-height: 34px;
}
.luckin-payment-methods .payment-action-icon-image {
  height: 34px;
  max-width: 100%;
}
.luckin-payment-methods-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 10px;
}
.luckin-payment-method {
  min-width: 0;
  min-height: 38px;
  height: 38px;
  border: 1px solid rgba(33, 27, 23, 0.1);
  border-radius: 12px;
  padding: 4px 6px;
  background: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  box-shadow: 0 4px 12px rgba(33, 27, 23, 0.03);
  pointer-events: auto;
}
.luckin-payment-method:disabled {
  opacity: 0.55;
  cursor: default;
}
.luckin-payment-method-icon-wrap {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  height: 100%;
}
.luckin-payment-method-icon {
  display: block;
  width: auto;
  height: 28px;
  max-width: 100%;
  object-fit: contain;
}
.luckin-payment-method .payment-action-icon.wechat .payment-action-icon-image {
  transform: scale(1.333);
}
.luckin-payment-method-text {
  display: none;
}
.luckin-payment-option-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-top: 4px;
}
.luckin-payment-option-chip {
  border: 1px solid rgba(70, 110, 184, 0.28);
  border-radius: 999px;
  padding: 4px 10px;
  background: rgba(70, 110, 184, 0.1);
  color: #2f4f86;
  font-size: 11px;
  line-height: 1.2;
  font-weight: 650;
}
.luckin-payment-meta {
  display: grid;
  gap: 6px;
  padding: 12px 16px 0;
  font-size: 12px;
  line-height: 1.45;
  color: #786e66;
}
.luckin-payment-meta-row {
  display: flex;
  gap: 8px;
  align-items: baseline;
}
.luckin-payment-meta-row .label {
  flex: 0 0 auto;
  color: #9a9088;
}
.luckin-payment-meta-row .value {
  min-width: 0;
  color: #493f38;
  overflow-wrap: anywhere;
}
.luckin-payment-refresh {
  margin: 14px 16px 16px;
  width: calc(100% - 32px);
  min-height: 44px;
  border: 1px solid rgba(33, 27, 23, 0.1);
  border-radius: 14px;
  background: rgba(255, 252, 248, 0.98);
  color: #5c524a;
  font-size: 14px;
  font-weight: 650;
  letter-spacing: 0.01em;
  box-shadow: 0 4px 14px rgba(33, 27, 23, 0.05);
}
.luckin-payment-refresh:disabled {
  opacity: 0.55;
  cursor: default;
}
.luckin-payment-refresh:active:not(:disabled) {
  transform: translateY(1px);
  background: rgba(247, 238, 226, 0.98);
}
body[data-scene] .shell {
  padding: 12px 12px calc(96px + env(safe-area-inset-bottom, 0px));
}
body[data-scene] .hero {
  position: relative;
  isolation: isolate;
  display: grid;
  gap: 14px;
  overflow: hidden;
  min-height: 312px;
  border: 1px solid rgba(33, 27, 23, 0.1);
  border-radius: 28px;
  padding: 18px;
  background:
    linear-gradient(142deg, rgba(24, 20, 16, 0.86), rgba(24, 20, 16, 0.46) 52%, rgba(255, 255, 255, 0.06)),
    var(--scene-image) center/cover;
  color: #fffaf4;
  box-shadow: 0 24px 54px rgba(44, 34, 26, 0.18);
}
body[data-scene] .hero::after {
  content: "";
  position: absolute;
  inset: auto -16% -22% 18%;
  height: 46%;
  border-radius: 999px;
  background: radial-gradient(circle, rgba(255, 255, 255, 0.38), transparent 64%);
  filter: blur(8px);
  z-index: -1;
}
.hero-copy {
  position: relative;
  z-index: 1;
}
body[data-scene] .eyebrow {
  display: inline-flex;
  width: fit-content;
  border: 1px solid rgba(255, 255, 255, 0.26);
  border-radius: 999px;
  padding: 7px 10px;
  background: rgba(255, 255, 255, 0.12);
  color: rgba(255, 250, 244, 0.88);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
}
body[data-scene] h1 {
  max-width: 8.8em;
  color: #fffaf4;
  font-size: 34px;
  font-weight: 880;
  letter-spacing: 0;
}
body[data-scene] .hero .subtitle {
  max-width: 25em;
  color: rgba(255, 250, 244, 0.84);
  font-size: 14px;
}
.hero-stats {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 8px;
  margin-top: 16px;
}
.hero-stat {
  min-width: 0;
  border: 1px solid rgba(255, 255, 255, 0.18);
  border-radius: 16px;
  padding: 9px 10px;
  background: rgba(255, 255, 255, 0.12);
  backdrop-filter: blur(14px);
  -webkit-backdrop-filter: blur(14px);
}
.hero-stat .label {
  color: rgba(255, 250, 244, 0.66);
}
.hero-stat .value {
  color: #fffaf4;
  font-size: 16px;
}
.scene-visual {
  position: relative;
  z-index: 1;
  align-self: end;
  overflow: hidden;
  border: 1px solid rgba(255, 255, 255, 0.24);
  border-radius: 22px;
  padding: 12px;
  background:
    linear-gradient(135deg, rgba(255, 255, 255, 0.22), rgba(255, 255, 255, 0.08)),
    rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(18px) saturate(160%);
  -webkit-backdrop-filter: blur(18px) saturate(160%);
}
.scene-visual-title {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  color: rgba(255, 250, 244, 0.92);
  font-size: 12px;
  font-weight: 760;
}
.scene-orb {
  width: 34px;
  height: 34px;
  flex: 0 0 auto;
  border-radius: 14px;
  background: linear-gradient(135deg, var(--scene-accent), var(--scene-accent-2));
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.34);
}
.mini-stack {
  display: grid;
  gap: 8px;
  margin-top: 10px;
}
.mini-row {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr);
  gap: 9px;
  align-items: center;
  border-radius: 15px;
  padding: 9px;
  background: rgba(255, 250, 244, 0.88);
  color: #211b17;
}
.mini-avatar {
  display: grid;
  place-items: center;
  width: 32px;
  height: 32px;
  border-radius: 12px;
  background: rgba(255, 250, 244, 0.86);
  color: var(--scene-accent);
  font-weight: 860;
}
.mini-avatar img {
  width: 24px;
  height: 24px;
  border-radius: 7px;
}
.mini-title {
  overflow: hidden;
  color: #211b17;
  font-size: 12px;
  font-weight: 780;
  line-height: 1.2;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.mini-subtitle {
  overflow: hidden;
  margin-top: 3px;
  color: #786e66;
  font-size: 10px;
  line-height: 1.25;
  text-overflow: ellipsis;
  white-space: nowrap;
}
body[data-scene="gmail"] .scene-gmail .gmail-hero {
  grid-template-columns: 1fr;
  min-height: 0;
  align-items: stretch;
  background:
    linear-gradient(120deg, rgba(39, 32, 27, 0.9), rgba(39, 32, 27, 0.48) 44%, rgba(194, 70, 54, 0.22)),
    var(--scene-image) center/cover;
}
.scene-gmail .eyebrow {
  display: none;
}
.mail-rail {
  position: relative;
  z-index: 1;
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  align-content: start;
  gap: 0;
  border: 1px solid rgba(255, 255, 255, 0.2);
  border-radius: 999px;
  padding: 4px;
  background: rgba(255, 250, 244, 0.16);
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.22);
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
}
.mail-rail::before {
  content: "";
  position: absolute;
  top: 4px;
  bottom: 4px;
  left: 4px;
  width: calc((100% - 8px) / 4);
  border-radius: 999px;
  background: rgba(255, 250, 244, 0.9);
  box-shadow: 0 10px 22px rgba(36, 24, 18, 0.16);
  transition: transform 220ms cubic-bezier(0.16, 1, 0.3, 1);
}
.mail-rail[data-mail-filter="mail-gmail"]::before {
  transform: translateX(100%);
}
.mail-rail[data-mail-filter="mail-qq"]::before {
  transform: translateX(200%);
}
.mail-rail[data-mail-filter="composio-outlook"]::before {
  transform: translateX(300%);
}
.mail-folder {
  appearance: none;
  -webkit-appearance: none;
  position: relative;
  z-index: 1;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 5px;
  min-width: 0;
  overflow: hidden;
  border: 0;
  border-radius: 999px;
  padding: 8px 5px;
  background: transparent;
  color: rgba(255, 250, 244, 0.88);
  font-size: 11px;
  font-weight: 720;
  font-family: inherit;
  text-align: center;
  text-overflow: ellipsis;
  white-space: nowrap;
  cursor: pointer;
  transition: color 180ms ease, transform 180ms ease;
}
.mail-folder span {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.mail-folder:focus-visible {
  outline: 2px solid rgba(255, 250, 244, 0.9);
  outline-offset: 2px;
}
.mail-folder.primary {
  background: transparent;
  color: #c24636;
}
.mail-folder:active {
  transform: scale(0.98);
}
.mail-folder-icon {
  width: 16px;
  height: 16px;
  flex: 0 0 auto;
  border-radius: 4px;
  object-fit: contain;
}
.mail-folder-icon.inbox {
  background: currentColor;
  -webkit-mask: var(--mail-inbox-icon) center/contain no-repeat;
  mask: var(--mail-inbox-icon) center/contain no-repeat;
}
.mail-copy {
  position: relative;
  align-self: end;
  padding-top: 0;
}
.mail-hero-icon {
  display: inline-block;
  width: 40px;
  height: 40px;
  margin-left: 12px;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%23fffaf4' stroke-width='2.35' stroke-linecap='round' stroke-linejoin='round'%3E%3Crect width='20' height='16' x='2' y='4' rx='2'/%3E%3Cpath d='m22 7-8.991 5.727a2 2 0 0 1-2.018 0L2 7'/%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-size: 100% 100%;
  filter: drop-shadow(0 3px 4px rgba(0, 0, 0, 0.26));
  opacity: 0.96;
  vertical-align: -6px;
}
.mail-deck {
  grid-column: auto;
  position: relative;
  z-index: 1;
  isolation: isolate;
  display: grid;
  gap: 8px;
  border: 1px solid rgba(255, 255, 255, 0.24);
  border-radius: 22px;
  padding: 12px 11px 13px;
  background:
    linear-gradient(145deg, rgba(255, 250, 244, 0.94), rgba(255, 250, 244, 0.78));
  color: #211b17;
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.5),
    0 18px 38px rgba(36, 24, 18, 0.16);
}
.mail-deck::before,
.mail-deck::after {
  content: "";
  position: absolute;
  left: 18px;
  right: 18px;
  bottom: -8px;
  height: 26px;
  border-radius: 0 0 20px 20px;
  background: rgba(255, 250, 244, 0.5);
  z-index: -1;
  filter: blur(0.2px);
}
.mail-deck::after {
  left: 32px;
  right: 32px;
  bottom: -14px;
  opacity: 0.46;
}
.mail-deck-title {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  color: #c24636;
  font-size: 12px;
  font-weight: 820;
}
.mail-deck-kicker {
  color: rgba(33, 27, 23, 0.44);
  font-size: 10px;
  font-weight: 680;
}
.mail-thread {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr) auto;
  gap: 9px;
  align-items: center;
  border-radius: 15px;
  padding: 9px;
  background: rgba(255, 255, 255, 0.82);
  box-shadow: 0 8px 16px rgba(36, 24, 18, 0.06);
}
.mail-thread.depth-1 {
  margin: -1px 6px 0;
  opacity: 0.92;
}
.mail-thread.depth-2 {
  margin: -1px 14px 0;
  opacity: 0.82;
}
.mail-thread-dot {
  width: 10px;
  height: 10px;
  border-radius: 999px;
  background: #c24636;
}
.mail-thread-meta {
  color: #786e66;
  font-size: 10px;
  white-space: nowrap;
}
body[data-scene="gmail"] .section {
  margin-top: 18px;
}
body[data-scene="gmail"] .block {
  border-color: rgba(33, 27, 23, 0.08);
  border-radius: 16px;
  background: #ffffff;
  box-shadow: 0 10px 28px rgba(42, 34, 27, 0.06);
}
body[data-scene="gmail"] .block-top {
  align-items: center;
}
body[data-scene="gmail"] .mini-row {
  grid-template-columns: auto minmax(0, 1fr);
  border-left: 4px solid rgba(194, 70, 54, 0.72);
}
body[data-scene] .chipbar {
  margin-top: 12px;
  border: 1px solid rgba(33, 27, 23, 0.08);
  border-radius: 999px;
  padding: 8px;
  background: rgba(255, 255, 255, 0.66);
}
body[data-scene] .section {
  margin-top: 14px;
}
body[data-scene] .section-head {
  margin: 0 2px 10px;
}
body[data-scene] .block,
body[data-scene] .timeline-item,
body[data-scene] .history-item,
body[data-scene] .empty {
  border-radius: 22px;
  background:
    linear-gradient(145deg, rgba(255, 255, 255, 0.92), rgba(255, 255, 255, 0.74)),
    var(--panel);
  box-shadow: 0 18px 42px rgba(44, 34, 26, 0.1);
}
body[data-scene] .block {
  padding: 14px;
}
body[data-scene] .block::before {
  width: 0;
  background: transparent;
}
body[data-scene="gmail"] .block {
  border-color: rgba(33, 27, 23, 0.08);
  padding: 0;
  overflow: hidden;
}
body[data-scene="gmail"] .block[data-source-key="mail-gmail"],
body[data-scene="gmail"] .block[data-source-key="mail-qq"],
body[data-scene="gmail"] .block[data-source-key="composio-outlook"] {
  background: var(--kind-soft);
}
body[data-scene="gmail"] .details {
  border-top-color: rgba(33, 27, 23, 0.06);
}
body[data-scene="gmail"] .mail-tech-details {
  margin-top: 0;
  border: 0;
  border-top: 1px solid rgba(33, 27, 23, 0.06);
  border-radius: 0;
  padding: 0;
  background: #ffffff;
}
body[data-scene="gmail"] .mail-tech-details > summary {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 13px 20px;
  color: #9ca3af;
  font-size: 12px;
  font-weight: 760;
  list-style: none;
}
body[data-scene="gmail"] .mail-tech-details > summary::-webkit-details-marker {
  display: none;
}
body[data-scene="gmail"] .mail-tech-details > summary::after {
  content: "+";
  color: #d1d5db;
  font-size: 16px;
  line-height: 1;
}
body[data-scene="gmail"] .mail-tech-details[open] > summary::after {
  content: "-";
}
body[data-scene="gmail"] .mail-tech-body {
  border-top: 1px solid rgba(33, 27, 23, 0.06);
  padding: 0 20px 14px;
}
body[data-scene="gmail"] .block-top {
  padding: 18px 20px 18px;
}
body[data-scene="gmail"] .block-title {
  gap: 9px;
}
body[data-scene="gmail"] .block-title h3 {
  margin-top: 2px;
  color: #111827;
  font-size: 18px;
  font-weight: 720;
  line-height: 1.26;
}
body[data-scene="gmail"] .block-title .subtitle {
  display: none;
}
body[data-scene="gmail"] .kind-tag {
  width: fit-content;
  border: 1px solid color-mix(in srgb, var(--kind-accent) 20%, transparent);
  border-radius: 7px;
  padding: 4px 8px;
  background: color-mix(in srgb, var(--kind-accent) 9%, white);
  color: var(--kind-accent);
  font-size: 12px;
  font-weight: 680;
}
body[data-scene="gmail"] .expand-button {
  color: #8c7a6b;
  font-size: 14px;
  font-weight: 680;
  background: transparent;
}
body[data-scene="gmail"] .details {
  padding: 0 20px 0;
}
.mail-detail-host {
  display: grid;
  gap: 10px;
  margin-bottom: 0;
}
.mail-detail-skeleton {
  display: grid;
  gap: 9px;
  padding: 4px 0 8px;
}
.mail-skeleton-line {
  height: 12px;
  border-radius: 4px;
  background: rgba(75, 66, 59, 0.13);
  animation: mail-skeleton-pulse 1.15s ease-in-out infinite alternate;
}
.mail-skeleton-line.short { width: 42%; }
.mail-skeleton-line.medium { width: 68%; }
.mail-detail-meta {
  display: grid;
  gap: 5px;
  border-bottom: 0;
  padding: 6px 0 14px;
  color: #9ca3af;
  font-size: 12px;
  line-height: 1.45;
}
.mail-detail-from {
  color: #111827;
  font-size: 14px;
  font-weight: 760;
}
.mail-detail-route {
  color: #9ca3af;
  font-size: 12px;
  line-height: 1.5;
}
.mail-detail-body {
  margin: 0;
  color: #374151;
  font: inherit;
  font-size: 15px;
  line-height: 1.65;
  white-space: pre-wrap;
  overflow-wrap: anywhere;
  padding-bottom: 18px;
}
.mail-calendar-card {
  display: grid;
  gap: 12px;
  margin: 0 0 18px;
  border: 1px solid #ebe5d9;
  border-radius: 12px;
  padding: 14px;
  background: #f8f6f1;
}
.mail-calendar-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}
.mail-calendar-title {
  min-width: 0;
  color: #4a4036;
  font-size: 14px;
  font-weight: 760;
  line-height: 1.3;
}
.mail-calendar-confidence {
  flex: 0 0 auto;
  border: 1px solid #fed7aa;
  border-radius: 999px;
  padding: 2px 9px;
  background: #ffedd5;
  color: #c2410c;
  font-size: 10px;
  font-weight: 820;
  line-height: 1.4;
  text-transform: uppercase;
}
.mail-calendar-lines {
  display: grid;
  gap: 8px;
  color: #5c544d;
  font-size: 13px;
  line-height: 1.45;
}
.mail-calendar-line {
  display: flex;
  gap: 12px;
}
.mail-calendar-label {
  flex: 0 0 32px;
  color: #8c7a6b;
}
.mail-calendar-value {
  min-width: 0;
  color: #4a4036;
}
.mail-calendar-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  margin-top: 2px;
  border-top: 1px solid #ebe5d9;
  padding-top: 12px;
}
.mail-calendar-status {
  min-width: 0;
  color: #8c7a6b;
  font-size: 12px;
  font-weight: 680;
  line-height: 1.4;
}
.mail-calendar-status.error { color: #a13f35; }
.mail-calendar-status.success { color: #2d6a4f; }
.mail-calendar-add {
  flex: 0 0 auto;
  min-width: 104px;
  border-radius: 8px;
  background: #8c7a6b;
  color: #ffffff;
  font-size: 12px;
  box-shadow: 0 2px 8px rgba(75, 66, 59, 0.1);
}
.mail-calendar-add:disabled {
  border: 1px solid #d5cec4;
  background: transparent;
  color: #a89f91;
  box-shadow: none;
}
.mail-detail-error {
  color: #a13f35;
  font-size: 13px;
  line-height: 1.5;
}
.mail-reply-launch {
  display: flex;
  justify-content: center;
  padding: 0 0 18px;
}
.mail-reply-launch .action {
  width: 100%;
  min-width: 132px;
  border-radius: 12px;
  background: #262626;
  color: #ffffff;
  justify-content: center;
}
.mail-reply-overlay {
  position: fixed;
  inset: 0;
  z-index: 120;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 16px;
  background: transparent;
  pointer-events: none;
}
.mail-reply-dialog {
  width: min(432px, 100%);
  max-height: min(560px, calc(100vh - 32px));
  overflow: auto;
  pointer-events: auto;
  border: 1px solid rgba(229, 231, 235, 0.88);
  border-radius: 16px;
  background: #ffffff;
  box-shadow: 0 26px 70px rgba(17, 24, 39, 0.24);
}
.mail-reply-header {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 16px 20px;
  border-bottom: 1px solid rgba(229, 231, 235, 0.84);
}
.mail-reply-title {
  flex: 1;
  margin: 0;
  color: #111827;
  font-size: 17px;
  font-weight: 720;
  letter-spacing: 0;
}
.mail-reply-ai {
  min-width: 74px;
  height: 32px;
  border: 1px solid #ebe5d9;
  border-radius: 8px;
  padding: 0 12px;
  background: #f8f6f1;
  color: #7a6a5c;
  font-size: 12px;
  font-weight: 760;
  line-height: 1;
  box-shadow: 0 1px 5px rgba(75, 66, 59, 0.06);
}
.mail-reply-close {
  width: 30px;
  height: 30px;
  border: 0;
  border-radius: 6px;
  background: transparent;
  color: #9ca3af;
  font-size: 22px;
  line-height: 1;
  cursor: pointer;
}
.mail-reply-close:hover { background: #f9fafb; color: #4b5563; }
.mail-reply-editor {
  display: block;
  width: calc(100% - 40px);
  min-height: 180px;
  margin: 20px;
  resize: vertical;
  border: 1px solid #e5e7eb;
  border-radius: 12px;
  padding: 14px;
  background: #fafafa;
  color: #1f2937;
  font: inherit;
  font-size: 15px;
  line-height: 1.6;
  outline: none;
}
.mail-reply-editor:focus {
  border-color: #8c7a6b;
  box-shadow: 0 0 0 1px #8c7a6b;
}
.mail-reply-status {
  min-height: 20px;
  padding: 0 20px 10px;
  color: #6b7280;
  font-size: 12px;
}
.mail-reply-status.error { color: #a13f35; }
.mail-reply-status.success { color: #2d6a4f; }
.mail-reply-footer {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
  padding: 0 20px 20px;
}
.mail-reply-footer .action {
  width: 100%;
  justify-content: center;
  border-radius: 12px;
  padding: 10px 12px;
  font-size: 14px;
  font-weight: 680;
  box-shadow: 0 2px 8px rgba(31, 41, 55, 0.06);
}
.mail-reply-footer .action.secondary {
  border: 1px solid #e5e7eb;
  background: #ffffff;
  color: #4b5563;
}
.mail-reply-footer .action.primary {
  background: #262626;
  color: #ffffff;
}
.aiphone-toast {
  position: fixed;
  top: max(12px, env(safe-area-inset-top, 0px));
  left: 50%;
  z-index: 180;
  transform: translate(-50%, -18px);
  opacity: 0;
  pointer-events: none;
  border: 1px solid rgba(47, 119, 84, 0.22);
  border-radius: 999px;
  padding: 10px 15px;
  background: rgba(255, 255, 255, 0.96);
  color: #2d6a4f;
  font-size: 13px;
  font-weight: 720;
  box-shadow: 0 14px 34px rgba(36, 31, 27, 0.14);
  transition: opacity 180ms ease, transform 180ms ease;
}
.aiphone-toast.visible {
  transform: translate(-50%, 0);
  opacity: 1;
}
@media (max-width: 560px) {
  .mail-reply-overlay { padding: 12px; }
  .mail-reply-dialog { max-height: calc(100vh - 24px); }
  .mail-reply-editor { min-height: 190px; }
}
@keyframes mail-skeleton-pulse {
  from { opacity: 0.42; }
  to { opacity: 0.9; }
}
@media (prefers-reduced-motion: reduce) {
  .mail-skeleton-line { animation: none; opacity: 0.64; }
}
body[data-scene] .kind-tag {
  border-radius: 999px;
  padding: 6px 8px;
  background: var(--kind-soft);
}
body[data-scene] .expand-button {
  border: 0;
  border-bottom: 1px solid currentColor;
  border-radius: 0;
  min-width: 0;
  min-height: 0;
  padding: 3px 0;
  background: transparent;
  box-shadow: none;
  font-size: 11px;
}
body[data-scene] .actions {
  gap: 7px;
}
body[data-scene] .action {
  border-color: transparent;
  background: var(--scene-accent);
  color: #fffaf4;
  box-shadow: 0 10px 22px rgba(44, 34, 26, 0.14);
}
body[data-scene] .action.secondary {
  border-color: rgba(33, 27, 23, 0.1);
  background: rgba(255, 255, 255, 0.78);
  color: var(--scene-accent);
}
body[data-scene="gmail"] .mail-calendar-add.action.primary {
  border: 0;
  border-radius: 8px;
  min-height: 30px;
  padding: 7px 14px;
  background: #8c7a6b;
  color: #ffffff;
  font-size: 12px;
  font-weight: 680;
  box-shadow: 0 2px 8px rgba(75, 66, 59, 0.1);
}
body[data-scene="gmail"] .mail-calendar-add.action.primary:disabled {
  border: 1px solid #d5cec4;
  background: transparent;
  color: #a89f91;
  box-shadow: none;
}
body[data-scene="gmail"] .mail-reply-launch .action.primary {
  border: 0;
  min-height: 42px;
  border-radius: 12px;
  background: #262626;
  color: #ffffff;
  font-size: 14px;
  font-weight: 680;
  box-shadow: 0 2px 8px rgba(31, 41, 55, 0.08);
}
body[data-scene="gmail"] .mail-reply-ai.action.secondary {
  min-width: 74px;
  height: 32px;
  border: 1px solid #ebe5d9;
  border-radius: 8px;
  padding: 0 12px;
  background: #f8f6f1;
  color: #7a6a5c;
  font-size: 12px;
  font-weight: 760;
  box-shadow: 0 1px 5px rgba(75, 66, 59, 0.06);
}
body[data-scene="gmail"] .mail-reply-footer .action.secondary {
  border: 1px solid #e5e7eb;
  background: #ffffff;
  color: #6b7280;
  font-weight: 680;
  box-shadow: 0 2px 8px rgba(31, 41, 55, 0.04);
}
body[data-scene="gmail"] .mail-reply-footer .action.primary {
  border: 0;
  background: #262626;
  color: #ffffff;
  font-weight: 680;
  box-shadow: 0 2px 8px rgba(31, 41, 55, 0.08);
}
body[data-scene] .credential {
  border: 1px solid rgba(46, 111, 143, 0.22);
  border-radius: 18px;
  background:
    linear-gradient(135deg, rgba(46, 111, 143, 0.12), rgba(161, 107, 31, 0.08)),
    rgba(255, 255, 255, 0.72);
}
body[data-scene] .credential input {
  border-radius: 14px;
}
body[data-scene] .raw {
  border: 1px solid rgba(33, 27, 23, 0.08);
  background: rgba(255, 255, 255, 0.66);
}
body[data-scene] .google-map-preview,
body[data-scene] .media-player {
  border-radius: 18px;
}
@media (prefers-reduced-motion: no-preference) {
  body[data-scene] .hero,
  body[data-scene] .block {
    animation: scene-rise 420ms cubic-bezier(0.16, 1, 0.3, 1) both;
  }
}
@keyframes scene-rise {
  from { opacity: 0; transform: translateY(14px); }
  to { opacity: 1; transform: translateY(0); }
}
@media (min-width: 620px) {
  .shell { padding: 24px 22px calc(112px + env(safe-area-inset-bottom, 0px)); }
  h1 { font-size: 34px; }
  .metrics { grid-template-columns: repeat(3, minmax(0, 1fr)); }
  .memory-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  body[data-scene] .shell { padding: 18px 18px calc(112px + env(safe-area-inset-bottom, 0px)); }
  body[data-scene] .hero {
    grid-template-columns: minmax(0, 1.1fr) minmax(230px, 0.72fr);
    min-height: 292px;
  }
  body[data-scene="gmail"] .scene-gmail .gmail-hero {
    grid-template-columns: 82px minmax(0, 0.9fr) minmax(230px, 1fr);
  }
  .mail-rail {
    grid-column: 1;
    grid-row: 1;
    grid-template-columns: 1fr;
  }
  .mail-rail::before {
    top: 4px;
    bottom: auto;
    right: 4px;
    width: auto;
    height: calc((100% - 8px) / 4);
  }
  .mail-rail[data-mail-filter="mail-gmail"]::before {
    transform: translateY(100%);
  }
  .mail-rail[data-mail-filter="mail-qq"]::before {
    transform: translateY(200%);
  }
  .mail-rail[data-mail-filter="composio-outlook"]::before {
    transform: translateY(300%);
  }
  .mail-copy {
    grid-column: 2;
    grid-row: 1;
  }
  .scene-gmail .mail-deck {
    grid-column: 3;
    grid-row: 1;
    align-self: end;
  }
  .mail-copy {
    padding-top: 0;
  }
  body[data-scene] .scene-visual { align-self: center; }
}
`;

const HTML_HOME_JS: string = `
(function () {
  var dataNode = document.getElementById('home-data');
  var data = {};
  try {
    data = JSON.parse(dataNode && dataNode.textContent ? dataNode.textContent : '{}') || {};
  } catch (error) {
    data = {};
  }
  var app = document.getElementById('app');
  if (!app) { return; }
  var localState = { travel: 'all', food: 'all', mail: 'all', trainFastest: false, trainAvailable: false, trainShowMore: false, expandedKey: '', luckinShopKey: '' };
  var mailDetailEntries = {};
  var mailCalendarSuggestions = {};
  var mailReplyDrafts = {};
  var activeMailReply = null;
  var toastTimer = null;
  function text(value) {
    return value === undefined || value === null ? '' : String(value);
  }
  function list(value) {
    return Array.isArray(value) ? value : [];
  }
  var isBusy = text(data.isBusy).toLowerCase() === 'true';
  var scene = sceneKey();
  if (document.body) {
    if (isEnhancedScene()) {
      document.body.setAttribute('data-scene', scene);
    } else {
      document.body.removeAttribute('data-scene');
    }
  }
  var MAIL_ICON_GMAIL = '${APP_LOGO_GMAIL}';
  var MAIL_ICON_QQ = '${APP_LOGO_QQMAIL}';
  var MEDIA_ICON_YOUTUBE = '${APP_LOGO_YOUTUBE}';
  var MEDIA_ICON_BILIBILI = '${APP_LOGO_BILIBILI}';
  var COMPOSIO_ICON_GITHUB = '${APP_LOGO_GITHUB}';
  var COMPOSIO_ICON_DRIVE = '${APP_LOGO_GOOGLE_DRIVE}';
  var COMPOSIO_ICON_DOCS = '${APP_LOGO_GOOGLE_DOCS}';
  var COMPOSIO_ICON_SLACK = '${APP_LOGO_SLACK}';
  var COMPOSIO_ICON_WECOM = '${APP_LOGO_WECOM}';
  var COMPOSIO_ICON_X = '${APP_LOGO_X}';
  var COMPOSIO_ICON_NOTION = '${APP_LOGO_NOTION}';
  var COMPOSIO_ICON_LINEAR = '${APP_LOGO_LINEAR}';
  var COMPOSIO_ICON_ASANA = '${APP_LOGO_ASANA}';
  var COMPOSIO_ICON_TRELLO = '${APP_LOGO_TRELLO}';
  var COMPOSIO_ICON_OUTLOOK = '${APP_LOGO_MICROSOFT_OUTLOOK}';
  var COMPOSIO_ICON_DISCORD = '${APP_LOGO_DISCORD}';
  var COMPOSIO_ICON_LINKEDIN = '${APP_LOGO_LINKEDIN}';
  var COMPOSIO_ICON_WHATSAPP = '${APP_LOGO_WHATSAPP}';
  var COMPOSIO_ICON_INSTAGRAM = '${APP_LOGO_INSTAGRAM}';
  var COMPOSIO_ICON_SPOTIFY = '${APP_LOGO_SPOTIFY}';
  var COMPOSIO_ICON_TIKTOK = '${APP_LOGO_TIKTOK}';
  var COMPOSIO_ICON_TICKETMASTER = '${APP_LOGO_TICKETMASTER}';
  var COMPOSIO_ICON_HUBSPOT = '${APP_LOGO_HUBSPOT}';
  var COMPOSIO_ICON_SALESFORCE = '${APP_LOGO_SALESFORCE}';
  var FOOD_ICON_AMAP = '${APP_LOGO_AMAP}';
  var FOOD_ICON_TENCENT = '${APP_LOGO_TENCENT_MAPS}';
  var FOOD_ICON_BAIDU = '${APP_LOGO_BAIDU_MAPS}';
  var FOOD_ICON_GOOGLE_MAPS = '${APP_LOGO_GOOGLE_MAPS}';
  var FOOD_ICON_MEITUAN = '${APP_LOGO_MEITUAN}';
  var FOOD_ICON_TAOBAO = '${APP_LOGO_TAOBAO}';
  var FOOD_ICON_MCDONALDS = '${APP_LOGO_MCDONALDS}';
  var FOOD_ICON_KFC = '${APP_LOGO_KFC}';
  var FOOD_ICON_LUCKIN = '${APP_LOGO_LUCKIN}';
  function kindLabel(value) {
    var kind = text(value);
    if (kind === 'welcome') { return '欢迎'; }
    if (kind === 'thinking') { return '执行中'; }
    if (kind === 'travel') { return '出行'; }
    if (kind === 'food') { return '附近餐饮'; }
    if (kind === 'social') { return '社交'; }
    if (kind === 'dynamic-tools') { return '动态工具'; }
    if (kind === 'gmail') { return 'Gmail'; }
    if (kind === 'luckin') { return '瑞幸咖啡'; }
    if (kind === 'generic') { return '通用任务'; }
    return kind;
  }
  function sceneKey() {
    var kind = text(data.kind);
    return kind.length > 0 ? kind : 'generic';
  }
  function blockKindLabel(value) {
    var kind = text(value);
    if (kind === 'travel-option') { return '出行方案'; }
    if (kind === 'train-option') { return '高铁'; }
    if (kind === 'flight-option') { return '航班'; }
    if (kind === 'food-result') { return '餐饮'; }
    if (kind === 'persona-memory-update') { return '记忆更新'; }
    if (kind === 'dynamic-tool-connect') { return '授权'; }
    if (kind === 'generic-tool-result') { return '工具结果'; }
    if (kind === 'ride-tool-panel') { return '打车'; }
    if (kind === 'StripeReceivingAccountCard') { return 'Stripe 收款'; }
    if (kind === 'social-hub-item') { return '社交'; }
    if (kind === 'social-hub-draft') { return '草稿'; }
    if (kind === 'social-hub-connection') { return '连接'; }
    return kind;
  }
  function blockTagLabel(block) {
    var key = sourceKey(block);
    if (key === 'composio-github') { return 'GitHub'; }
    if (key === 'composio-drive') { return 'Google Drive'; }
    if (key === 'composio-docs') { return 'Google Docs'; }
    if (key === 'composio-slack') { return 'Slack'; }
    if (key === 'composio-notion') { return 'Notion'; }
    if (key === 'composio-linear') { return 'Linear'; }
    if (key === 'composio-asana') { return 'Asana'; }
    if (key === 'composio-trello') { return 'Trello'; }
    if (key === 'composio-outlook') { return 'Outlook'; }
    if (key === 'composio-discord') { return 'Discord'; }
    if (key === 'composio-linkedin') { return 'LinkedIn'; }
    if (key === 'composio-whatsapp') { return 'WhatsApp'; }
    if (key === 'composio-instagram') { return 'Instagram'; }
    if (key === 'composio-spotify') { return 'Spotify'; }
    if (key === 'composio-tiktok') { return 'TikTok'; }
    if (key === 'composio-ticketmaster') { return 'Ticketmaster'; }
    if (key === 'composio-hubspot') { return 'HubSpot'; }
    if (key === 'composio-salesforce') { return 'Salesforce'; }
    if (key === 'composio-x' || key === 'social-x') { return 'X'; }
    if (key === 'social-wecom') { return '企业微信'; }
    if (key === 'composio') { return 'Composio'; }
    if (text(block && block.kind) === 'food-result' && text(block && block.source).length > 0) {
      return text(block && block.source);
    }
    if (text(block && block.kind) === 'generic-tool-result' && text(block && block.source).length > 0) {
      return text(block && block.source);
    }
    return blockKindLabel(block && block.kind);
  }
  function mailIconData(key) {
    if (key === 'mail-gmail') { return MAIL_ICON_GMAIL; }
    if (key === 'mail-qq') { return MAIL_ICON_QQ; }
    if (key === 'media-youtube') { return MEDIA_ICON_YOUTUBE; }
    if (key === 'media-bilibili') { return MEDIA_ICON_BILIBILI; }
    if (key === 'composio-github') { return COMPOSIO_ICON_GITHUB; }
    if (key === 'composio-drive') { return COMPOSIO_ICON_DRIVE; }
    if (key === 'composio-docs') { return COMPOSIO_ICON_DOCS; }
    if (key === 'composio-slack') { return COMPOSIO_ICON_SLACK; }
    if (key === 'composio-notion') { return COMPOSIO_ICON_NOTION; }
    if (key === 'composio-linear') { return COMPOSIO_ICON_LINEAR; }
    if (key === 'composio-asana') { return COMPOSIO_ICON_ASANA; }
    if (key === 'composio-trello') { return COMPOSIO_ICON_TRELLO; }
    if (key === 'composio-outlook') { return COMPOSIO_ICON_OUTLOOK; }
    if (key === 'composio-discord') { return COMPOSIO_ICON_DISCORD; }
    if (key === 'composio-linkedin') { return COMPOSIO_ICON_LINKEDIN; }
    if (key === 'composio-whatsapp') { return COMPOSIO_ICON_WHATSAPP; }
    if (key === 'composio-instagram') { return COMPOSIO_ICON_INSTAGRAM; }
    if (key === 'composio-spotify') { return COMPOSIO_ICON_SPOTIFY; }
    if (key === 'composio-tiktok') { return COMPOSIO_ICON_TIKTOK; }
    if (key === 'composio-ticketmaster') { return COMPOSIO_ICON_TICKETMASTER; }
    if (key === 'composio-hubspot') { return COMPOSIO_ICON_HUBSPOT; }
    if (key === 'composio-salesforce') { return COMPOSIO_ICON_SALESFORCE; }
    if (key === 'composio-x') { return COMPOSIO_ICON_X; }
    if (key === 'composio') { return ''; }
    if (key === 'social-x') { return COMPOSIO_ICON_X; }
    if (key === 'social-slack') { return COMPOSIO_ICON_SLACK; }
    if (key === 'social-wecom') { return COMPOSIO_ICON_WECOM; }
    if (key === 'social-discord') { return COMPOSIO_ICON_DISCORD; }
    if (key === 'social-linkedin') { return COMPOSIO_ICON_LINKEDIN; }
    if (key === 'social-whatsapp') { return COMPOSIO_ICON_WHATSAPP; }
    if (key === 'social-instagram') { return COMPOSIO_ICON_INSTAGRAM; }
    if (key === 'food-amap') { return FOOD_ICON_AMAP; }
    if (key === 'food-tencent') { return FOOD_ICON_TENCENT; }
    if (key === 'food-baidu') { return FOOD_ICON_BAIDU; }
    if (key === 'food-google-maps') { return FOOD_ICON_GOOGLE_MAPS; }
    if (key === 'food-meituan') { return FOOD_ICON_MEITUAN; }
    if (key === 'food-taobao') { return FOOD_ICON_TAOBAO; }
    if (key === 'food-mcd') { return FOOD_ICON_MCDONALDS; }
    if (key === 'food-kfc') { return FOOD_ICON_KFC; }
    if (key === 'food-luckin') { return FOOD_ICON_LUCKIN; }
    return '';
  }
  function addBlockTag(parent, block, key) {
    var tag = add(parent, 'div', 'kind-tag');
    var icon = mailIconData(key);
    if (icon.length > 0) {
      var img = document.createElement('img');
      img.className = 'mail-source-icon';
      img.src = icon;
      img.alt = '';
      img.setAttribute('aria-hidden', 'true');
      tag.appendChild(img);
    }
    add(tag, 'span', '', blockTagLabel(block));
  }
  function sourceKey(block) {
    var kind = text(block && block.kind).toLowerCase();
    if (kind === 'persona-memory-update') {
      return 'persona-memory';
    }
    if (kind === 'food-result' && text(block && block.source).indexOf(' / ') >= 0) {
      return 'food-local';
    }
    var raw = [
      text(block && block.source),
      metricValue(block, ['source', 'provider', 'sourceTag']),
      metricValue(block, ['toolName']),
      text(block && block.title),
      text(block && block.subtitle)
    ].join(' ').toLowerCase();
    if (raw.indexOf('gmail') >= 0) {
      return 'mail-gmail';
    }
    if (raw.indexOf('qq mail') >= 0 || raw.indexOf('qq邮箱') >= 0 || raw.indexOf('provider qq') >= 0) {
      return 'mail-qq';
    }
    if (raw.indexOf('youtube') >= 0 || raw.indexOf('youtu.be') >= 0) {
      return 'media-youtube';
    }
    if (raw.indexOf('bilibili') >= 0 || raw.indexOf('哔哩哔哩') >= 0 || raw.indexOf('b 站') >= 0 || raw.indexOf('b站') >= 0) {
      return 'media-bilibili';
    }
    if (kind === 'generic-tool-result' && (raw.indexOf('composio') >= 0 ||
      raw.indexOf('googledrive') >= 0 || raw.indexOf('google drive') >= 0 ||
      raw.indexOf('googledocs') >= 0 || raw.indexOf('google docs') >= 0 ||
      raw.indexOf('github') >= 0 || raw.indexOf('slack') >= 0 ||
      raw.indexOf('twitter') >= 0 || raw.indexOf('x.post.search') >= 0 ||
      raw.indexOf('notion') >= 0 || raw.indexOf('linear') >= 0 ||
      raw.indexOf('asana') >= 0 || raw.indexOf('trello') >= 0 ||
      raw.indexOf('outlook') >= 0 || raw.indexOf('discord') >= 0 ||
      raw.indexOf('linkedin') >= 0 || raw.indexOf('whatsapp') >= 0 ||
      raw.indexOf('instagram') >= 0 || raw.indexOf('instgram') >= 0 ||
      raw.indexOf('spotify') >= 0 || raw.indexOf('soptify') >= 0 ||
      raw.indexOf('tiktok') >= 0 || raw.indexOf('tik tok') >= 0 ||
      raw.indexOf('ticketmaster') >= 0 || raw.indexOf('ticket master') >= 0 ||
      raw.indexOf('hubspot') >= 0 || raw.indexOf('salesforce') >= 0)) {
      if (raw.indexOf('github') >= 0) { return 'composio-github'; }
      if (raw.indexOf('twitter') >= 0 || raw.indexOf('x.post.search') >= 0) { return 'composio-x'; }
      if (raw.indexOf('googledrive') >= 0 || raw.indexOf('google drive') >= 0) { return 'composio-drive'; }
      if (raw.indexOf('googledocs') >= 0 || raw.indexOf('google docs') >= 0) { return 'composio-docs'; }
      if (raw.indexOf('slack') >= 0) { return 'composio-slack'; }
      if (raw.indexOf('notion') >= 0) { return 'composio-notion'; }
      if (raw.indexOf('linear') >= 0) { return 'composio-linear'; }
      if (raw.indexOf('asana') >= 0) { return 'composio-asana'; }
      if (raw.indexOf('trello') >= 0) { return 'composio-trello'; }
      if (raw.indexOf('outlook') >= 0) { return 'composio-outlook'; }
      if (raw.indexOf('discord') >= 0) { return 'composio-discord'; }
      if (raw.indexOf('linkedin') >= 0) { return 'composio-linkedin'; }
      if (raw.indexOf('whatsapp') >= 0) { return 'composio-whatsapp'; }
      if (raw.indexOf('instagram') >= 0 || raw.indexOf('instgram') >= 0) { return 'composio-instagram'; }
      if (raw.indexOf('spotify') >= 0 || raw.indexOf('soptify') >= 0) { return 'composio-spotify'; }
      if (raw.indexOf('tiktok') >= 0 || raw.indexOf('tik tok') >= 0) { return 'composio-tiktok'; }
      if (raw.indexOf('ticketmaster') >= 0 || raw.indexOf('ticket master') >= 0) { return 'composio-ticketmaster'; }
      if (raw.indexOf('hubspot') >= 0) { return 'composio-hubspot'; }
      if (raw.indexOf('salesforce') >= 0) { return 'composio-salesforce'; }
      return 'composio';
    }
    if (kind.indexOf('social-hub') === 0) {
      var platform = [text(block && block.source), metricValue(block, ['platform'])].join(' ').toLowerCase();
      if (platform.indexOf('slack') >= 0) { return 'social-slack'; }
      if (platform.indexOf('wecom') >= 0 || platform.indexOf('wework') >= 0 || platform.indexOf('企业微信') >= 0) { return 'social-wecom'; }
      if (platform.indexOf('discord') >= 0) { return 'social-discord'; }
      if (platform.indexOf('linkedin') >= 0) { return 'social-linkedin'; }
      if (platform.indexOf('whatsapp') >= 0) { return 'social-whatsapp'; }
      if (platform.indexOf('instagram') >= 0 || platform.indexOf('instgram') >= 0) { return 'social-instagram'; }
      if (platform === 'x' || platform.indexOf(' x') >= 0 || platform.indexOf('twitter') >= 0) { return 'social-x'; }
    }
    if (kind === 'train-option' || raw.indexOf('12306') >= 0 || raw.indexOf('train') >= 0 || raw.indexOf('高铁') >= 0) {
      return 'travel-train';
    }
    if (kind === 'flight-option' || raw.indexOf('flight') >= 0 || raw.indexOf('飞常准') >= 0 || raw.indexOf('航班') >= 0) {
      return 'travel-flight';
    }
    if (raw.indexOf('amap') >= 0 || raw.indexOf('gaode') >= 0 || raw.indexOf('高德') >= 0) {
      return 'food-amap';
    }
    if (raw.indexOf('tencent') >= 0 || raw.indexOf('腾讯') >= 0) {
      return 'food-tencent';
    }
    if (raw.indexOf('baidu') >= 0 || raw.indexOf('百度') >= 0) {
      return 'food-baidu';
    }
    if (raw.indexOf('google maps') >= 0 || raw.indexOf('google places') >= 0) {
      return 'food-google-maps';
    }
    if (raw.indexOf('meituan') >= 0 || raw.indexOf('美团') >= 0) {
      return 'food-meituan';
    }
    if (raw.indexOf('taobao') >= 0 || raw.indexOf('淘宝') >= 0 || raw.indexOf('闪购') >= 0) {
      return 'food-taobao';
    }
    if (raw.indexOf('mcd') >= 0 || raw.indexOf('mcdonald') >= 0 || raw.indexOf('麦当劳') >= 0) {
      return 'food-mcd';
    }
    if (raw.indexOf('luckin') >= 0 || raw.indexOf('瑞幸') >= 0) {
      return 'food-luckin';
    }
    if (kind === 'food-result') {
      return 'food-local';
    }
    if (kind === 'ride-tool-panel' || raw.indexOf('ride.') >= 0 || raw.indexOf('滴滴') >= 0 || raw.indexOf('打车') >= 0) {
      return 'ride';
    }
    return kind || 'generic';
  }
  function isMailBlock(block) {
    var key = sourceKey(block);
    return key === 'mail-gmail' || key === 'mail-qq' || key === 'composio-outlook';
  }
	function isExpandable(block) {
	    var kind = text(block && block.kind);
	    if (kind === 'generic-tool-result' && isMailBlock(block)) {
	      return true;
	    }
	    if (kind === 'ride-tool-panel') {
	      return false;
	    }
	    if (kind === 'persona-memory-update' || kind === 'generic-tool-result') {
	      return false;
	    }
	    return kind === 'travel-option' || kind === 'train-option' || kind === 'flight-option' || kind === 'food-result';
	  }
  function updateExpandLabel(card) {
    var button = card.querySelector('.expand-button');
    if (!button) { return; }
    var expanded = card.classList.contains('expanded');
    button.textContent = expanded ? '收起' : '展开';
    card.setAttribute('aria-expanded', expanded ? 'true' : 'false');
  }
  function applyExpandedState() {
    Array.prototype.slice.call(document.querySelectorAll('[data-expandable="true"]')).forEach(function (item) {
      var expanded = (item.getAttribute('data-card-key') || '') === localState.expandedKey;
      item.classList.toggle('expanded', expanded);
      updateExpandLabel(item);
    });
  }
  function setExpandedCard(card) {
    var key = card.getAttribute('data-card-key') || '';
    var expanding = localState.expandedKey !== key;
    var beforeTop = card.getBoundingClientRect().top;
    localState.expandedKey = expanding ? key : '';
    applyExpandedState();
    if (expanding) {
      var afterTop = card.getBoundingClientRect().top;
      window.scrollBy(0, afterTop - beforeTop);
    }
    if (expanding) { requestMailDetail(card); }
  }
  function expandCard(card) {
    localState.expandedKey = card.getAttribute('data-card-key') || '';
    applyExpandedState();
  }
  function statusLabel(value) {
    var raw = text(value);
    var key = raw.toLowerCase();
    if (key === 'ready' || key === 'success' || key === 'available') { return '已完成'; }
    if (key === 'pending' || key === 'thinking') { return '执行中'; }
    if (key === 'tool') { return '工具结果'; }
    if (key === 'model') { return '模型结果'; }
    if (key === 'welcome') { return '待输入'; }
    if (key === 'needs_auth') { return '待授权'; }
    if (key === 'error' || key === 'failed' || key === 'fail') { return '失败'; }
    return raw;
  }
  function heroTitle() {
    var raw = text(data.title);
    if ((text(data.kind) === 'thinking' || text(data.source) === 'pending') && raw === 'Generating') {
      return '正在整理结果';
    }
    return raw || kindLabel(data.kind) || 'A2UI';
  }
  function heroSubtitle() {
    var raw = text(data.subtitle);
    if (raw.length > 0) { return raw; }
    if (text(data.source) === 'pending' || text(data.kind) === 'thinking') {
      return '已收到请求，正在等待模型或工具返回。';
    }
    if (text(data.kind) === 'welcome') {
      return '输入需求后，这里会展示真实返回的任务结果。';
    }
    return '';
  }
  function emptyCopy() {
    if (text(data.source) === 'pending' || text(data.kind) === 'thinking') {
      return '正在执行，结果会在这里出现。';
    }
    if (text(data.kind) === 'welcome') {
      return '还没有任务结果。发起一次查询后，卡片会在这里展开。';
    }
    return '暂无任务结果。真实返回后会显示在这里。';
  }
  function sceneSectionTitle() {
    if (scene === 'gmail') { return '邮件线程'; }
    if (scene === 'social') { return '消息卡片'; }
    if (scene === 'luckin') { return '瑞幸订单'; }
    if (scene === 'thinking') { return '执行状态'; }
    if (scene === 'welcome') { return '起始面板'; }
    return '结果看板';
  }
  function sceneVisualTitle() {
    if (scene === 'gmail') { return '收件预览舱'; }
    if (scene === 'social') { return 'Message Flow'; }
    if (scene === 'luckin') { return 'Luckin Order'; }
    if (scene === 'thinking') { return 'Running'; }
    if (scene === 'welcome') { return 'Ready'; }
    return 'Result Board';
  }
  function previewBlocks() {
    var blocks = scene === 'gmail' ? list(data.blocks).filter(isMailBlock) : list(data.blocks);
    blocks = blocks.slice(0, 3);
    if (blocks.length > 0) { return blocks; }
    var timeline = list(data.timeline).slice(0, 3);
    if (timeline.length > 0) {
      return timeline.map(function (item, index) {
        return {
          id: 'timeline-' + String(index),
          title: text(item.title) === 'prompt' ? '用户请求' : text(item.title),
          subtitle: text(item.subtitle),
          status: text(item.status),
          source: ''
        };
      });
    }
    return [{
      id: 'empty',
      title: heroTitle(),
      subtitle: emptyCopy(),
      status: statusLabel(data.source),
      source: ''
    }];
  }
  function previewInitial(block, index) {
    var raw = text(block && block.title).trim();
    if (scene === 'gmail') { return '@'; }
    if (scene === 'social') { return raw.length > 0 ? raw.substring(0, 1) : '聊'; }
    if (scene === 'thinking') { return String(index + 1); }
    return raw.length > 0 ? raw.substring(0, 1) : '#';
  }
  function previewSubtitle(block) {
    return text(block && block.subtitle) || text(block && block.source) || statusLabel(block && block.status);
  }
  function addHeroStats(parent) {
    var stats = add(parent, 'div', 'hero-stats');
    var blocks = list(data.blocks);
    addHeroStat(stats, '结果', blocks.length > 0 ? String(blocks.length) + ' 条' : '待返回');
    addHeroStat(stats, '状态', isBusy ? '执行中' : statusLabel(data.source || data.kind));
    addHeroStat(stats, '动作', list(data.actions).length > 0 ? String(list(data.actions).length) + ' 个' : '按卡片');
  }
  function addHeroStat(parent, label, value) {
    var node = add(parent, 'div', 'hero-stat');
    add(node, 'div', 'label', label);
    add(node, 'div', 'value', value);
  }
  function sceneClassName() {
    return 'scene-' + scene.replace(/[^a-z0-9-]/g, '');
  }
  function isEnhancedScene() {
    return scene === 'gmail' || scene === 'social' || scene === 'luckin';
  }
  function addLegacyHero(parent) {
    var hero = add(parent, 'header', 'hero');
    var eyebrow = text(data.kind) === 'welcome' ? '' : kindLabel(data.kind);
    if (eyebrow.length > 0) { add(hero, 'div', 'eyebrow', eyebrow); }
    add(hero, 'h1', '', heroTitle());
    add(hero, 'p', 'subtitle', heroSubtitle());
    addActions(hero, data.actions);
  }
  function addHeroCopy(parent, className) {
    var heroCopy = add(parent, 'div', className || 'hero-copy');
    var eyebrow = text(data.kind) === 'welcome' || scene === 'gmail' ? '' : kindLabel(data.kind);
    if (eyebrow.length > 0) { add(heroCopy, 'div', 'eyebrow', eyebrow); }
    add(heroCopy, 'h1', '', heroTitle());
    add(heroCopy, 'p', 'subtitle', heroSubtitle());
    addActions(heroCopy, data.actions);
    return heroCopy;
  }
  function addMailThread(parent, block, index) {
    var row = add(parent, 'div', 'mail-thread depth-' + String(index));
    add(row, 'span', 'mail-thread-dot');
    var copy = add(row, 'div', 'mini-copy');
    add(copy, 'div', 'mini-title', text(block && block.title) || '邮件线程');
    add(copy, 'div', 'mini-subtitle', previewSubtitle(block));
    add(row, 'span', 'mail-thread-meta', index === 0 ? '新' : statusLabel(block && block.status));
  }
  function addMailFolderIcon(parent, key) {
    if (key === 'inbox') {
      add(parent, 'span', 'mail-folder-icon inbox');
      return;
    }
    var icon = key === 'gmail' ? MAIL_ICON_GMAIL : (key === 'qq' ? MAIL_ICON_QQ : (key === 'outlook' ? COMPOSIO_ICON_OUTLOOK : ''));
    if (icon.length === 0) { return; }
    var img = document.createElement('img');
    img.className = 'mail-folder-icon';
    img.src = icon;
    img.alt = '';
    img.setAttribute('aria-hidden', 'true');
    parent.appendChild(img);
  }
  function addGmailHero(parent) {
    var hero = add(parent, 'header', 'hero gmail-hero');
    var copy = addHeroCopy(hero, 'hero-copy mail-copy');
    var titleNode = copy.querySelector('h1') || copy;
    var icon = add(titleNode, 'span', 'mail-hero-icon');
    icon.setAttribute('aria-hidden', 'true');
    var deck = add(hero, 'aside', 'mail-deck');
    var title = add(deck, 'div', 'mail-deck-title');
    add(title, 'span', '', '收件预览舱');
    var mailBlocks = previewBlocks().slice(0, 3);
    var mailCount = list(data.blocks).filter(isMailBlock).length;
    add(title, 'span', 'mail-deck-kicker', String(mailCount) + ' 封');
    mailBlocks.forEach(function (block, index) {
      addMailThread(deck, block, index);
    });
    var rail = add(hero, 'nav', 'mail-rail');
    rail.setAttribute('data-mail-filter', localState.mail);
    [
      ['收件箱', 'mail_filter_all', 'inbox'],
      ['Gmail', 'mail_filter_gmail', 'gmail'],
      ['QQ Mail', 'mail_filter_qq', 'qq'],
      ['Outlook', 'mail_filter_outlook', 'outlook']
    ].forEach(function (item, index) {
      var button = add(rail, 'button', index === 0 ? 'mail-folder primary' : 'mail-folder');
      button.type = 'button';
      addMailFolderIcon(button, item[2]);
      add(button, 'span', '', item[0]);
      button.setAttribute('data-mail-filter', item[1] === 'mail_filter_all' ? 'all' : (item[1] === 'mail_filter_gmail' ? 'mail-gmail' : (item[1] === 'mail_filter_qq' ? 'mail-qq' : 'composio-outlook')));
      button.addEventListener('click', function () {
        handleLocalAction({ id: item[1] });
      });
    });
  }
  function renderSceneHero(parent) {
    if (!isEnhancedScene()) { addLegacyHero(parent); return; }
    if (scene === 'gmail') { addGmailHero(parent); return; }
    addLegacyHero(parent);
  }
  function addSceneVisual(parent) {
    var visual = add(parent, 'aside', 'scene-visual');
    visual.setAttribute('aria-hidden', 'true');
    var head = add(visual, 'div', 'scene-visual-title');
    add(head, 'span', '', sceneVisualTitle());
    add(head, 'span', 'scene-orb');
    var stack = add(visual, 'div', 'mini-stack');
    previewBlocks().forEach(function (block, index) {
      var row = add(stack, 'div', 'mini-row');
      var avatar = add(row, 'div', 'mini-avatar', previewInitial(block, index));
      if (scene === 'gmail' && sourceKey(block) === 'mail-gmail') {
        avatar.textContent = '';
        var icon = document.createElement('img');
        icon.src = MAIL_ICON_GMAIL;
        icon.alt = '';
        icon.setAttribute('aria-hidden', 'true');
        avatar.appendChild(icon);
      }
      var copy = add(row, 'div', 'mini-copy');
      add(copy, 'div', 'mini-title', text(block && block.title) || sceneSectionTitle());
      add(copy, 'div', 'mini-subtitle', previewSubtitle(block));
    });
  }
  function add(parent, tag, className, value) {
    var node = document.createElement(tag);
    if (className) { node.className = className; }
    if (value !== undefined && value !== null && text(value).length > 0) {
      node.textContent = text(value);
    }
    parent.appendChild(node);
    return node;
  }
  function postAction(action) {
    if (isBusy) { return; }
    try {
      if (window.AIPhoneHome && typeof window.AIPhoneHome.postAction === 'function') {
        window.AIPhoneHome.postAction(JSON.stringify({
          id: text(action.id),
          label: text(action.label || action.id),
          prompt: text(action.prompt),
          variant: text(action.variant),
          kind: text(action.kind),
          args: action.args && typeof action.args === 'object' ? action.args : null
        }));
      }
    } catch (error) {
    }
  }
  function mailReplyActions(block) {
    return list(block && block.actions).filter(function (action) {
      var id = text(action && action.id);
      return id === 'mail.ai.reply.draft' || id === 'gmail.ai.reply.draft';
    });
  }
  function visibleMailActions(block) {
    return list(block && block.actions).filter(function (action) {
      var id = text(action && action.id);
      return id !== 'html_mail_detail_read' && id !== 'mail.ai.reply.draft' && id !== 'gmail.ai.reply.draft';
    });
  }
  function mailDetailAction(block) {
    var actions = list(block && block.actions);
    for (var index = 0; index < actions.length; index += 1) {
      if (text(actions[index] && actions[index].id) === 'html_mail_detail_read') {
        return actions[index];
      }
    }
    return null;
  }
  function mailSkeleton(host) {
    host.textContent = '';
    var skeleton = add(host, 'div', 'mail-detail-skeleton');
    add(skeleton, 'div', 'mail-skeleton-line short');
    add(skeleton, 'div', 'mail-skeleton-line medium');
    add(skeleton, 'div', 'mail-skeleton-line');
    add(skeleton, 'div', 'mail-skeleton-line');
    skeleton.setAttribute('aria-label', '正在加载邮件正文');
  }
  function displayNameFromAddress(value) {
    var raw = text(value).trim();
    var left = raw.indexOf('<');
    if (left > 0) {
      var name = raw.substring(0, left).replace(/^["“]+|["”]+$/g, '').trim();
      if (name.length > 0) { return name; }
    }
    var at = raw.indexOf('@');
    if (at > 0) { return raw.substring(0, at); }
    return raw;
  }
  function emailFromAddress(value) {
    var raw = text(value).trim();
    var match = raw.match(/<([^>]+)>/);
    if (match && match[1]) { return match[1].trim(); }
    var bare = raw.match(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}/i);
    return bare && bare[0] ? bare[0].trim() : '';
  }
  function mailRouteText(detail) {
    var fromEmail = emailFromAddress(detail.from);
    var to = list(detail.to);
    var firstToName = to.length > 0 ? displayNameFromAddress(to[0]) : '';
    var route = fromEmail.length > 0 ? fromEmail : text(detail.from);
    if (route.length === 0) { route = '发件人'; }
    if (firstToName.length > 0) {
      route += ' 发给 ' + firstToName + ' (我)';
    }
    return route;
  }
  function copiedMailReplyArgs(action, detail, requestKey) {
    var source = action && action.args && typeof action.args === 'object' ? action.args : {};
    var args = {};
    Object.keys(source).forEach(function (key) { args[key] = source[key]; });
    var recipient = text(detail.replyTo) || text(detail.from);
    args.requestKey = requestKey;
    args.provider = text(detail.provider) || text(args.provider);
    args.threadId = text(detail.threadId) || text(args.threadId);
    args.messageId = text(detail.messageId) || text(args.messageId);
    args.internetMessageId = text(detail.internetMessageId);
    args.to = recipient.length > 0 ? [recipient] : list(args.to);
    args.subject = text(detail.subject).indexOf('Re:') === 0 ? text(detail.subject) : 'Re: ' + text(detail.subject);
    args.replyMode = 'reply';
    args.contextSummary = text(detail.subject) + '\\n\\n' + text(detail.bodyText);
    args.body = '';
    return args;
  }
  function closeMailReply() {
    if (!activeMailReply) { return; }
    mailReplyDrafts[activeMailReply.requestKey] = activeMailReply.editor.value;
    if (activeMailReply.overlay.parentNode) {
      activeMailReply.overlay.parentNode.removeChild(activeMailReply.overlay);
    }
    activeMailReply = null;
  }
  function submitMailReply(operation) {
    if (!activeMailReply || activeMailReply.busy) { return; }
    var body = activeMailReply.editor.value.trim();
    mailReplyDrafts[activeMailReply.requestKey] = activeMailReply.editor.value;
    if (body.length === 0) {
      activeMailReply.status.className = 'mail-reply-status error';
      activeMailReply.status.textContent = '请输入回复内容。';
      return;
    }
    if (list(activeMailReply.args.to).length === 0) {
      activeMailReply.status.className = 'mail-reply-status error';
      activeMailReply.status.textContent = '这封邮件缺少可回复的发件人地址。';
      return;
    }
    activeMailReply.busy = true;
    activeMailReply.saveButton.disabled = true;
    activeMailReply.sendButton.disabled = true;
    activeMailReply.status.className = 'mail-reply-status';
    activeMailReply.status.textContent = operation === 'draft' ? '正在保存草稿…' : '正在发送回复…';
    var args = {};
    Object.keys(activeMailReply.args).forEach(function (key) { args[key] = activeMailReply.args[key]; });
    args.body = body;
    postAction({
      id: operation === 'draft' ? 'html_mail_reply_save' : 'html_mail_reply_send',
      label: operation === 'draft' ? '保存草稿' : '发送回复',
      prompt: activeMailReply.requestKey,
      variant: operation === 'draft' ? 'secondary' : 'primary',
      kind: 'client',
      args: args
    });
  }
  function requestMailReplyAiDraft() {
    if (!activeMailReply || activeMailReply.busy) { return; }
    activeMailReply.busy = true;
    activeMailReply.aiButton.disabled = true;
    activeMailReply.saveButton.disabled = true;
    activeMailReply.sendButton.disabled = true;
    activeMailReply.aiButton.textContent = '...';
    activeMailReply.status.className = 'mail-reply-status';
    activeMailReply.status.textContent = '正在生成回复草稿…';
    postAction({
      id: 'html_mail_reply_ai_generate',
      label: 'AI回复',
      prompt: activeMailReply.requestKey,
      variant: 'secondary',
      kind: 'client',
      args: activeMailReply.args
    });
  }
  function openMailReply(entry, detail) {
    if (!entry.replyAction) { return; }
    if (activeMailReply) { closeMailReply(); }
    var requestKey = text(detail.requestKey) || text(entry.detailAction.prompt);
    var overlay = add(document.body, 'div', 'mail-reply-overlay');
    var dialog = add(overlay, 'section', 'mail-reply-dialog');
    dialog.setAttribute('role', 'dialog');
    dialog.setAttribute('aria-modal', 'false');
    var header = add(dialog, 'header', 'mail-reply-header');
    add(header, 'h2', 'mail-reply-title', '编辑回复');
    var aiButton = add(header, 'button', 'action secondary mail-reply-ai', 'AI回复');
    aiButton.type = 'button';
    var closeButton = add(header, 'button', 'mail-reply-close', '×');
    closeButton.type = 'button';
    closeButton.setAttribute('aria-label', '关闭');
    var editor = document.createElement('textarea');
    editor.className = 'mail-reply-editor';
    editor.value = text(mailReplyDrafts[requestKey]);
    dialog.appendChild(editor);
    var status = add(dialog, 'div', 'mail-reply-status', '');
    var footer = add(dialog, 'footer', 'mail-reply-footer');
    var saveButton = add(footer, 'button', 'action secondary', '保存草稿');
    var sendButton = add(footer, 'button', 'action primary', '发送回复');
    saveButton.type = 'button';
    sendButton.type = 'button';
    activeMailReply = {
      requestKey: requestKey,
      overlay: overlay,
      editor: editor,
      status: status,
      aiButton: aiButton,
      saveButton: saveButton,
      sendButton: sendButton,
      args: copiedMailReplyArgs(entry.replyAction, detail, requestKey),
      busy: false
    };
    editor.addEventListener('input', function () { mailReplyDrafts[requestKey] = editor.value; });
    closeButton.addEventListener('click', closeMailReply);
    aiButton.addEventListener('click', function () { requestMailReplyAiDraft(); });
    saveButton.addEventListener('click', function () { submitMailReply('draft'); });
    sendButton.addEventListener('click', function () { submitMailReply('send'); });
    editor.focus();
  }
  function renderMailReplyLaunch(entry, detail) {
    entry.replyHost.textContent = '';
    if (!entry.replyAction) { return; }
    var wrap = add(entry.replyHost, 'div', 'mail-reply-launch');
    var button = add(wrap, 'button', 'action primary', '回复');
    button.type = 'button';
    button.addEventListener('click', function (event) {
      event.stopPropagation();
      openMailReply(entry, detail);
    });
  }
  function showToast(message) {
    var toast = document.querySelector('.aiphone-toast');
    if (!toast) {
      toast = add(document.body, 'div', 'aiphone-toast');
      toast.setAttribute('role', 'status');
      toast.setAttribute('aria-live', 'polite');
    }
    toast.textContent = text(message) || '已完成';
    toast.classList.add('visible');
    if (toastTimer) { clearTimeout(toastTimer); }
    toastTimer = setTimeout(function () {
      toast.classList.remove('visible');
    }, 2600);
  }
  function calendarSuggestionReady(suggestion) {
    return !!suggestion &&
      !!suggestion.isWorkRelated &&
      !!suggestion.hasMeeting &&
      text(suggestion.start).length > 0 &&
      text(suggestion.title).length > 0;
  }
  function addCalendarLine(parent, label, value) {
    var clean = text(value);
    if (clean.length === 0) { return; }
    var row = add(parent, 'div', 'mail-calendar-line');
    add(row, 'span', 'mail-calendar-label', label);
    add(row, 'span', 'mail-calendar-value', clean);
  }
  function padTimePart(value) {
    return value < 10 ? '0' + value : String(value);
  }
  function parseCalendarDate(value) {
    var clean = text(value);
    if (clean.length === 0) { return null; }
    var date = new Date(clean);
    return isNaN(date.getTime()) ? null : date;
  }
  function formatCalendarDate(date) {
    return (date.getMonth() + 1) + '月' + date.getDate() + '日';
  }
  function formatCalendarClock(date) {
    return padTimePart(date.getHours()) + ':' + padTimePart(date.getMinutes());
  }
  function formatCalendarDateTime(date) {
    return formatCalendarDate(date) + ' ' + formatCalendarClock(date);
  }
  function formatCalendarTimeRange(suggestion) {
    var modelTime = text(suggestion && suggestion.displayTime);
    if (modelTime.length > 0) { return modelTime; }
    var start = parseCalendarDate(suggestion && suggestion.start);
    var end = parseCalendarDate(suggestion && suggestion.end);
    if (!start) { return text(suggestion && suggestion.start); }
    if (!end) { return formatCalendarDateTime(start); }
    if (start.getFullYear() === end.getFullYear() &&
      start.getMonth() === end.getMonth() &&
      start.getDate() === end.getDate()) {
      return formatCalendarDate(start) + ' ' + formatCalendarClock(start) + '-' + formatCalendarClock(end);
    }
    return formatCalendarDateTime(start) + ' - ' + formatCalendarDateTime(end);
  }
  function cleanCalendarDescription(value) {
    var lines = text(value).split('\\n');
    var kept = [];
    lines.forEach(function (line) {
      var clean = text(line).trim();
      if (clean.length === 0) { return; }
      if (/^(来源|邮件来源|Source|发件人|From)\\s*[:：]/i.test(clean)) { return; }
      kept.push(clean);
    });
    return kept.join('\\n')
      .replace(/[；;，,。\\s]*(来源|邮件来源|Source|发件人|From)\\s*[:：][^\\n]*$/i, '')
      .trim();
  }
  function renderMailCalendarSuggestion(entry, detail, suggestion) {
    entry.calendarHost.textContent = '';
    if (!calendarSuggestionReady(suggestion)) { return; }
    var card = add(entry.calendarHost, 'section', 'mail-calendar-card');
    var head = add(card, 'div', 'mail-calendar-head');
    add(head, 'div', 'mail-calendar-title', text(suggestion.title));
    add(head, 'div', 'mail-calendar-confidence', text(suggestion.confidence) || 'medium');
    var lines = add(card, 'div', 'mail-calendar-lines');
    addCalendarLine(lines, '时间', formatCalendarTimeRange(suggestion));
    addCalendarLine(lines, '地点', suggestion.location);
    addCalendarLine(lines, '内容', cleanCalendarDescription(suggestion.description));
    addCalendarLine(lines, '来源', displayNameFromAddress(detail.from) + ' 邮件');
    var footer = add(card, 'div', 'mail-calendar-footer');
    var status = add(footer, 'div', 'mail-calendar-status', '已识别为会议日程');
    var button = add(footer, 'button', 'action primary mail-calendar-add', '添加日程');
    button.type = 'button';
    entry.calendarStatus = status;
    entry.calendarButton = button;
    button.addEventListener('click', function (event) {
      event.stopPropagation();
      if (button.disabled) { return; }
      button.disabled = true;
      status.className = 'mail-calendar-status';
      status.textContent = '正在添加到手机日历…';
      postAction({
        id: 'html_mail_calendar_add',
        label: '添加日程',
        prompt: text(detail.requestKey),
        variant: 'primary',
        kind: 'client',
        args: {
          requestKey: text(detail.requestKey),
          provider: text(detail.provider),
          threadId: text(detail.threadId),
          messageId: text(detail.messageId)
        }
      });
    });
  }
  function renderMailDetail(entry, detail) {
    entry.host.textContent = '';
    entry.replyHost.textContent = '';
    entry.calendarHost.textContent = '';
    var meta = add(entry.host, 'div', 'mail-detail-meta');
    add(meta, 'div', 'mail-detail-from', displayNameFromAddress(detail.from) || '邮件发件人');
    add(meta, 'div', 'mail-detail-route', mailRouteText(detail));
    add(entry.host, 'pre', 'mail-detail-body', text(detail.bodyText) || '邮件正文为空。');
    renderMailCalendarSuggestion(entry, detail, mailCalendarSuggestions[text(detail.requestKey)]);
    renderMailReplyLaunch(entry, detail);
  }
  function renderMailDetailError(entry, message) {
    entry.host.textContent = '';
    entry.calendarHost.textContent = '';
    add(entry.host, 'div', 'mail-detail-error', text(message) || '邮件正文加载失败。');
    var retry = add(entry.host, 'button', 'action secondary', '重试');
    retry.type = 'button';
    retry.addEventListener('click', function (event) {
      event.stopPropagation();
      entry.status = '';
      requestMailDetail(entry.card);
    });
  }
  function requestMailDetail(card) {
    var key = card.getAttribute('data-mail-detail-key') || '';
    var entry = mailDetailEntries[key];
    if (!entry || entry.status === 'loading' || entry.status === 'success') { return; }
    entry.status = 'loading';
    mailSkeleton(entry.host);
    postAction(entry.detailAction);
  }
  window.__aiphoneApplyMailDetail = function (event) {
    var key = text(event && event.requestKey);
    var entry = mailDetailEntries[key];
    if (!entry) { return; }
    if (text(event && event.status) === 'success' && event.detail) {
      entry.status = 'success';
      if (event.calendarSuggestion) {
        mailCalendarSuggestions[key] = event.calendarSuggestion;
      }
      renderMailDetail(entry, event.detail);
      return;
    }
    entry.status = 'error';
    renderMailDetailError(entry, event && event.error);
  };
  window.__aiphoneApplyMailCalendar = function (event) {
    var key = text(event && event.requestKey);
    var entry = mailDetailEntries[key];
    if (!entry) { return; }
    if (entry.calendarButton) {
      entry.calendarButton.disabled = false;
    }
    if (!entry.calendarStatus) { return; }
    if (text(event && event.status) === 'success') {
      entry.calendarStatus.className = 'mail-calendar-status success';
      entry.calendarStatus.textContent = text(event && event.message) || '已添加日程';
      if (entry.calendarButton) {
        entry.calendarButton.disabled = true;
        entry.calendarButton.textContent = '已添加';
      }
      showToast(text(event && event.message) || '已添加日程');
      return;
    }
    entry.calendarStatus.className = 'mail-calendar-status error';
    entry.calendarStatus.textContent = text(event && event.error) || '添加日程失败';
  };
  window.__aiphoneApplyMailReply = function (event) {
    if (!activeMailReply || text(event && event.requestKey) !== activeMailReply.requestKey) { return; }
    activeMailReply.busy = false;
    activeMailReply.aiButton.disabled = false;
    activeMailReply.saveButton.disabled = false;
    activeMailReply.sendButton.disabled = false;
    activeMailReply.aiButton.textContent = 'AI回复';
    if (text(event && event.operation) === 'ai') {
      if (text(event && event.status) === 'success') {
        activeMailReply.editor.value = text(event.message);
        mailReplyDrafts[activeMailReply.requestKey] = activeMailReply.editor.value;
        activeMailReply.status.className = 'mail-reply-status success';
        activeMailReply.status.textContent = 'AI 回复已填入，可继续编辑。';
        activeMailReply.editor.focus();
        return;
      }
      activeMailReply.status.className = 'mail-reply-status error';
      activeMailReply.status.textContent = text(event && event.error) || 'AI 回复生成失败，请重试。';
      return;
    }
    if (text(event && event.status) === 'success') {
      delete mailReplyDrafts[activeMailReply.requestKey];
      activeMailReply.editor.value = '';
      activeMailReply.status.className = 'mail-reply-status success';
      activeMailReply.status.textContent = text(event.message) || '操作成功。';
      setTimeout(closeMailReply, 700);
      return;
    }
    activeMailReply.status.className = 'mail-reply-status error';
    activeMailReply.status.textContent = text(event && event.error) || '操作失败，请重试。';
  };
  function metricValue(block, labels) {
    var items = list(block && block.metrics).concat(list(block && block.rows));
    for (var itemIndex = 0; itemIndex < items.length; itemIndex += 1) {
      var label = text(items[itemIndex] && items[itemIndex].label);
      if (labels.indexOf(label) >= 0) {
        return text(items[itemIndex] && items[itemIndex].value);
      }
    }
    return '';
  }
  function isGoogleMapsBlock(block) {
    var raw = [
      text(block && block.source),
      metricValue(block, ['source', 'toolName']),
      text(block && block.title)
    ].join(' ').toLowerCase();
    return raw.indexOf('google places') >= 0 ||
      raw.indexOf('google maps') >= 0 ||
      raw.indexOf('maps.place.') >= 0;
  }
  function validMapLocation(value) {
    return /^-?[0-9]+(?:\\.[0-9]+)?\\s*,\\s*-?[0-9]+(?:\\.[0-9]+)?$/.test(text(value));
  }
  function googleMapLocation(block) {
    var location = metricValue(block, ['Map Location', 'Google Maps Location']);
    return validMapLocation(location) ? location.replace(/\\s+/g, '') : '';
  }
  function googleMapEmbedUrl(block) {
    var url = metricValue(block, ['Maps URL', 'Google Maps URL']);
    if (url.length > 0) {
      return url + (url.indexOf('?') >= 0 ? '&' : '?') + 'output=embed';
    }
    var location = googleMapLocation(block);
    return location.length > 0 ? 'https://www.google.com/maps?q=' + encodeURIComponent(location) + '&output=embed' : '';
  }
  function addGoogleMapPreview(parent, block) {
    if (!isGoogleMapsBlock(block)) { return; }
    var embedUrl = googleMapEmbedUrl(block);
    if (embedUrl.length === 0) { return; }
    var preview = add(parent, 'div', 'google-map-preview');
    var iframe = document.createElement('iframe');
    iframe.title = 'Google Maps preview';
    iframe.setAttribute('loading', 'lazy');
    iframe.setAttribute('referrerpolicy', 'no-referrer-when-downgrade');
    iframe.src = embedUrl;
    preview.appendChild(iframe);
  }
  function isAllowedMediaEmbedUrl(url) {
    var raw = text(url);
    return raw.indexOf('https://www.youtube.com/embed/') === 0 ||
      raw.indexOf('https://player.bilibili.com/player.html?') === 0;
  }
  function addMediaEmbed(parent, block) {
    var media = block && block.mediaEmbed ? block.mediaEmbed : null;
    if (!media) { return; }
    var embedUrl = text(media.embedUrl);
    if (!isAllowedMediaEmbedUrl(embedUrl)) { return; }
    var preview = add(parent, 'div', 'media-player');
    preview.addEventListener('click', function (event) {
      event.stopPropagation();
    });
    var iframe = document.createElement('iframe');
    iframe.title = text(media.title) || 'media player';
    iframe.setAttribute('loading', 'lazy');
    iframe.setAttribute('allowfullscreen', 'true');
    iframe.setAttribute('allow', 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share');
    iframe.setAttribute('referrerpolicy', 'origin-when-cross-origin');
    iframe.src = embedUrl;
    preview.appendChild(iframe);
  }
  function addStripeReceivingOnboarding(parent, block) {
    var receiving = block && block.stripeReceiving ? block.stripeReceiving : null;
    if (!receiving) { return; }
    var url = text(receiving.onboardingUrl);
    if (url.indexOf('https://') !== 0) { return; }
    var link = add(parent, 'a', 'stripe-onboarding-link', '打开 Stripe 托管认证');
    link.href = url;
    link.target = '_self';
    link.rel = 'noreferrer';
    link.addEventListener('click', function (event) {
      event.preventDefault();
      event.stopPropagation();
      postStripeReceivingOpen(url);
    });
    autoOpenStripeReceivingOnboarding(receiving, url);
  }
  function postStripeReceivingOpen(url) {
    postAction({
      id: 'stripe.account.open',
      label: '打开 Stripe 托管认证',
      prompt: url,
      variant: 'primary',
      kind: 'client',
      args: { onboardingUrl: url }
    });
  }
  function autoOpenStripeReceivingOnboarding(receiving, url) {
    if (text(receiving.status) !== 'onboarding_required') { return; }
    var key = 'aiphone.stripe.onboarding.' + url;
    try {
      if (window.sessionStorage && window.sessionStorage.getItem(key) === '1') { return; }
      if (window.sessionStorage) { window.sessionStorage.setItem(key, '1'); }
    } catch (_error) {}
    window.setTimeout(function () {
      postStripeReceivingOpen(url);
    }, 0);
  }
  function numberIn(value) {
    var match = text(value).replace(/,/g, '').match(/[0-9]+(?:\\.[0-9]+)?/);
    return match ? Number(match[0]) : Number.NaN;
  }
  function distanceMeters(value) {
    var raw = text(value).toLowerCase();
    var valueNumber = numberIn(raw);
    if (!(valueNumber >= 0)) { return Number.POSITIVE_INFINITY; }
    return raw.indexOf('km') >= 0 || raw.indexOf('公里') >= 0 ? valueNumber * 1000 : valueNumber;
  }
  function durationMinutes(value) {
    var raw = text(value);
    var colon = raw.match(/([0-9]+):([0-9]+)/);
    if (colon) { return Number(colon[1]) * 60 + Number(colon[2]); }
    var hours = raw.match(/([0-9]+)\\s*(?:h|小时|时)/i);
    var minutes = raw.match(/([0-9]+)\\s*(?:m|分钟|分)/i);
    var total = (hours ? Number(hours[1]) * 60 : 0) + (minutes ? Number(minutes[1]) : 0);
    return total > 0 ? total : 999999;
  }
  function hasAvailableText(value) {
    var raw = text(value);
    if (raw.indexOf('有') >= 0 || raw.toLowerCase().indexOf('available') >= 0) { return true; }
    if (raw.indexOf('无') >= 0 && raw.indexOf('有') < 0) { return false; }
    return /[1-9][0-9]*/.test(raw);
  }
  function handleLocalAction(action) {
    if (isBusy) { return false; }
    var id = text(action && action.id);
    if (id === 'mail_filter_all') { localState.mail = 'all'; applyLocalView(); return true; }
    if (id === 'mail_filter_gmail') { localState.mail = 'mail-gmail'; applyLocalView(); return true; }
    if (id === 'mail_filter_qq') { localState.mail = 'mail-qq'; applyLocalView(); return true; }
    if (id === 'mail_filter_outlook') { localState.mail = 'composio-outlook'; applyLocalView(); return true; }
    if (id === 'travel_show_all') { localState.travel = 'all'; applyLocalView(); return true; }
    if (id === 'travel_filter_train') { localState.travel = 'train'; applyLocalView(); return true; }
    if (id === 'travel_filter_flight') { localState.travel = 'flight'; applyLocalView(); return true; }
    if (id === 'food_show_all' || id === 'food_show_more') { localState.food = 'all'; applyLocalView(); return true; }
    if (id === 'food_filter_1km') { localState.food = 'within_1km'; applyLocalView(); return true; }
    if (id === 'client_show_more') { localState.trainShowMore = !localState.trainShowMore; applyLocalView(); return true; }
    if (id === 'client_sort_fastest') { localState.trainFastest = !localState.trainFastest; applyLocalView(); return true; }
    if (id === 'client_filter_available') { localState.trainAvailable = !localState.trainAvailable; applyLocalView(); return true; }
    return false;
  }
  function updateVisibleCount(visibleCount, totalCount) {
    if (scene === 'luckin') { return; }
    var countNode = document.getElementById('block-count');
    if (countNode) {
      countNode.textContent = String(visibleCount) + ' / ' + String(totalCount) + ' 条';
    }
    var emptyNode = document.getElementById('filter-empty');
    if (emptyNode) {
      emptyNode.style.display = totalCount > 0 && visibleCount === 0 ? '' : 'none';
    }
  }
  function updateMailFilterButtons() {
    var rail = document.querySelector('.mail-rail');
    if (rail) {
      rail.setAttribute('data-mail-filter', localState.mail);
    }
    Array.prototype.slice.call(document.querySelectorAll('.mail-folder[data-mail-filter]')).forEach(function (button) {
      button.classList.toggle('primary', (button.getAttribute('data-mail-filter') || '') === localState.mail);
    });
  }
  function applyLocalView() {
    var cards = Array.prototype.slice.call(document.querySelectorAll('.block'));
    var trains = cards.filter(function (card) {
      return (card.getAttribute('data-kind') || '') === 'train-option';
    }).sort(function (left, right) {
      if (localState.trainFastest) {
        return durationMinutes(left.getAttribute('data-duration') || '') - durationMinutes(right.getAttribute('data-duration') || '');
      }
      return numberIn(left.getAttribute('data-train-index') || '') - numberIn(right.getAttribute('data-train-index') || '');
    });
    trains.forEach(function (card) {
      if (card.parentNode) { card.parentNode.appendChild(card); }
    });
    cards = Array.prototype.slice.call(document.querySelectorAll('.block'));
    var trainVisibleCount = 0;
    var visibleCount = 0;
    cards.forEach(function (card) {
      var kind = card.getAttribute('data-kind') || '';
      var visible = true;
      if (kind === 'travel-option' && localState.travel !== 'all') {
        visible = (card.getAttribute('data-source') || '').toLowerCase().indexOf(localState.travel) >= 0;
      }
      if (kind === 'food-result' && localState.food === 'within_1km') {
        visible = distanceMeters(card.getAttribute('data-distance') || '') <= 1000;
      }
      if (kind === 'generic-tool-result' && localState.mail !== 'all') {
        visible = (card.getAttribute('data-source-key') || '') === localState.mail;
      }
      if (kind === 'train-option' && localState.trainAvailable) {
        visible = hasAvailableText(card.getAttribute('data-availability') || '');
      }
      if (kind === 'train-option' && visible) {
        trainVisibleCount += 1;
        if (!localState.trainShowMore && trainVisibleCount > 6) {
          visible = false;
        }
      }
      if (visible) { visibleCount += 1; }
      card.style.display = visible ? '' : 'none';
    });
    updateVisibleCount(visibleCount, cards.length);
    updateMailFilterButtons();
  }
  function rowValue(block, label) {
    var rows = list(block && block.rows);
    for (var index = 0; index < rows.length; index += 1) {
      if (text(rows[index] && rows[index].label) === label) {
        return text(rows[index] && rows[index].value);
      }
    }
    return '';
  }
  function isComposioSourceKey(key) {
    return text(key).indexOf('composio') === 0;
  }
  function composioAppName(key) {
    if (key === 'composio-github') { return 'GitHub'; }
    if (key === 'composio-drive') { return 'Google Drive'; }
    if (key === 'composio-docs') { return 'Google Docs'; }
    if (key === 'composio-slack') { return 'Slack'; }
    if (key === 'composio-notion') { return 'Notion'; }
    if (key === 'composio-linear') { return 'Linear'; }
    if (key === 'composio-asana') { return 'Asana'; }
    if (key === 'composio-trello') { return 'Trello'; }
    if (key === 'composio-outlook') { return 'Outlook'; }
    if (key === 'composio-discord') { return 'Discord'; }
    if (key === 'composio-linkedin') { return 'LinkedIn'; }
    if (key === 'composio-whatsapp') { return 'WhatsApp'; }
    if (key === 'composio-instagram') { return 'Instagram'; }
    if (key === 'composio-spotify') { return 'Spotify'; }
    if (key === 'composio-tiktok') { return 'TikTok'; }
    if (key === 'composio-ticketmaster') { return 'Ticketmaster'; }
    if (key === 'composio-hubspot') { return 'HubSpot'; }
    if (key === 'composio-salesforce') { return 'Salesforce'; }
    if (key === 'composio-x') { return 'X'; }
    return 'Composio';
  }
  function isComposioSystemRow(row) {
    var label = text(row && row.label);
    return label === '执行工具' || label === '查询' || label === '结果数量' || label === '结果摘要' ||
      label === 'toolName' || label === 'source' || label === 'provider';
  }
  function composioVisibleRows(block) {
    return list(block && block.rows).filter(function (row) {
      return !isComposioSystemRow(row) && text(row && row.label).length > 0;
    }).slice(0, 3);
  }
  function trimUrlTail(value) {
    var clean = text(value);
    while (clean.length > 0) {
      var last = clean.charAt(clean.length - 1);
      if (last === ')' || last === ']' || last === ',' || last === ';' || last === '.') {
        clean = clean.slice(0, clean.length - 1);
      } else {
        break;
      }
    }
    return clean;
  }
  function firstUrl(value) {
    var parts = text(value).split('|').join(' ').split(' ');
    for (var index = 0; index < parts.length; index += 1) {
      var part = trimUrlTail(parts[index]);
      if (part.indexOf('https://') === 0 || part.indexOf('http://') === 0) {
        return part;
      }
    }
    return '';
  }
  function addComposioPreview(parent, block, key) {
    if (!isComposioSourceKey(key)) { return; }
    var wrap = add(parent, 'div', 'composio-preview');
    var head = add(wrap, 'div', 'composio-preview-head');
    var iconData = mailIconData(key);
    if (iconData.length > 0) {
      var icon = document.createElement('img');
      icon.className = 'composio-app-logo';
      icon.src = iconData;
      icon.alt = '';
      icon.setAttribute('aria-hidden', 'true');
      head.appendChild(icon);
    }
    var copy = add(head, 'div', 'composio-app-copy');
    add(copy, 'div', 'composio-app-name', composioAppName(key));
    var count = rowValue(block, '结果数量');
    var status = statusLabel(block && block.status);
    add(copy, 'div', 'composio-app-meta', count.length > 0 ? count + ' 条结果 · ' + status : status);
    var rows = composioVisibleRows(block);
    var items = add(wrap, 'div', 'composio-items');
    if (rows.length === 0) {
      add(items, 'div', 'composio-item-detail', rowValue(block, '结果摘要') || text(block && block.subtitle) || '没有可展示结果');
      return;
    }
    rows.forEach(function (row) {
      var item = add(items, 'article', 'composio-item');
      add(item, 'div', 'composio-item-title', text(row && row.label));
      var detail = text(row && row.value);
      if (detail.length > 0) {
        add(item, 'div', 'composio-item-detail', detail);
      }
      var url = firstUrl(detail);
      if (url.length > 0) {
        var link = add(item, 'a', 'composio-item-link', '打开结果');
        link.href = url;
        link.target = '_blank';
        link.rel = 'noopener noreferrer';
        link.addEventListener('click', function (event) {
          event.stopPropagation();
        });
      }
    });
  }
  function cleanMemoryLine(value) {
    var line = text(value).trim();
    while (line.indexOf('#') === 0) {
      line = line.slice(1).trim();
    }
    if (line.indexOf('- [ ]') === 0 || line.indexOf('- [x]') === 0 || line.indexOf('- [X]') === 0) {
      line = line.slice(5).trim();
    }
    if (line.indexOf('- ') === 0 || line.indexOf('* ') === 0) {
      line = line.slice(2).trim();
    }
    return line;
  }
  function memoryLines(value) {
    var raw = text(value).replace(/\\r/g, '\\n').split('\\n');
    var lines = [];
    raw.forEach(function (item) {
      var line = cleanMemoryLine(item);
      if (line.length > 0 && lines.length < 4) {
        lines.push(line);
      }
    });
    if (lines.length === 0) {
      lines.push('暂无摘要');
    }
    return lines;
  }
  function addMemoryPanel(parent, title, value) {
    var panel = add(parent, 'div', 'memory-panel');
    add(panel, 'div', 'label', title);
    var lines = add(panel, 'div', 'memory-lines');
    memoryLines(value).forEach(function (line) {
      add(lines, 'div', 'memory-line', line);
    });
  }
  function addMemoryAvatar(parent) {
    var persona = data.persona || {};
    var name = text(persona.name) || '分';
    var avatar = add(parent, 'div', 'memory-update-avatar');
    var avatarSrc = text(data.personaAvatarDataUri);
    if (avatarSrc.length > 0) {
      var img = add(avatar, 'img');
      img.src = avatarSrc;
      img.alt = '';
      img.setAttribute('aria-hidden', 'true');
    } else {
      avatar.textContent = name.slice(0, 1);
    }
  }
  function addPersonaMemoryUpdateCard(parent, block) {
    var wrap = add(parent, 'div', 'memory-update-card');
    var head = add(wrap, 'div', 'memory-update-head');
    addMemoryAvatar(head);
    var title = add(head, 'div', 'memory-update-title');
    add(title, 'h3', '', text(block.title) || '记忆已更新');
    add(title, 'div', 'memory-update-kicker', '记忆已写入');
    var reason = rowValue(block, '原因') || text(block.subtitle);
    if (reason.length > 0) {
      add(title, 'div', 'memory-update-reason', reason);
    }

    var hero = add(wrap, 'div', 'memory-update-hero');
    add(hero, 'div', 'label', '已记录偏好');
    add(hero, 'div', 'memory-update-preference', rowValue(block, '已记录') || text(block.subtitle) || '已写入新的长期偏好');
    add(hero, 'div', 'memory-update-note', '后续同类请求会优先按这条偏好重新筛选结果。');

    var grid = add(wrap, 'div', 'memory-grid');
    addMemoryPanel(grid, 'Memory 摘要', rowValue(block, 'Memory 摘要'));
    addMemoryPanel(grid, 'Soul 摘要', rowValue(block, 'Soul 摘要'));
    addActions(wrap, block.actions);
  }
  function actionArg(action, key) {
    var args = action && action.args;
    if (!args || typeof args !== 'object') { return ''; }
    return text(args[key]);
  }
  function luckinRelocatePrompt() {
    var blocks = list(data.blocks);
    for (var blockIndex = 0; blockIndex < blocks.length; blockIndex += 1) {
      var actions = luckinShopActionItems(blocks[blockIndex]);
      if (actions.length > 0 && text(actions[0].prompt).length > 0) {
        return text(actions[0].prompt);
      }
    }
    return text(data.subtitle) || text(data.title) || '';
  }
  function addLuckinRelocateButton(parent) {
    var button = add(parent, 'button', 'luckin-relocate', '重新定位 ›');
    button.type = 'button';
    button.disabled = isBusy;
    if (isBusy) { button.setAttribute('aria-disabled', 'true'); }
    button.addEventListener('click', function (event) {
      event.stopPropagation();
      if (isBusy) { return; }
      postAction({
        id: 'luckin.order.preview',
        label: '重新定位',
        prompt: luckinRelocatePrompt(),
        variant: 'secondary',
        kind: 'prompt',
        args: { location: '', locationSource: 'refresh' }
      });
    });
  }
  function luckinShopActionItems(block) {
    return list(block && block.actions).filter(function (action) {
      return text(action && action.id) === 'luckin.order.preview' && actionArg(action, 'deptName').length > 0;
    });
  }
  function luckinProductImageUrl(block) {
    var url = metricValue(block, ['商品图']);
    if (url.indexOf('https://') === 0 || url.indexOf('http://') === 0 || url.indexOf('resource://') === 0) {
      return url;
    }
    if (isLuckinPaymentOrderBlock(block) || isLuckinConfirmOrderBlock(block)) {
      return 'resource://rawfile/luckin_coconut.jpeg';
    }
    return '';
  }
  function hasLuckinPaymentBlock(blocks) {
    for (var blockIndex = 0; blockIndex < blocks.length; blockIndex += 1) {
      if (isLuckinPaymentOrderBlock(blocks[blockIndex])) {
        return true;
      }
    }
    return false;
  }
  function hasLuckinConfirmBlock(blocks) {
    for (var blockIndex = 0; blockIndex < blocks.length; blockIndex += 1) {
      if (isLuckinConfirmOrderBlock(blocks[blockIndex])) {
        return true;
      }
    }
    return false;
  }
  function isLuckinConfirmOrderBlock(block) {
    if (scene !== 'luckin') { return false; }
    return text(block && block.title).indexOf('确认瑞幸订单') >= 0;
  }
  function isLuckinPaymentOrderBlock(block) {
    if (scene !== 'luckin') { return false; }
    return text(block && block.title).indexOf('瑞幸订单已创建') >= 0;
  }
  function isLuckinOrderBlock(block) {
    if (scene !== 'luckin') { return false; }
    var title = text(block && block.title);
    if (isLuckinConfirmOrderBlock(block)) {
      return true;
    }
    if (isLuckinPaymentOrderBlock(block)) {
      return true;
    }
    return false;
  }
  function luckinConfirmAction(block) {
    var actions = list(block && block.actions);
    for (var actionIndex = 0; actionIndex < actions.length; actionIndex += 1) {
      if (text(actions[actionIndex] && actions[actionIndex].id) === 'luckin.order.create') {
        return actions[actionIndex];
      }
    }
    return null;
  }
  function luckinOptionChoices(value) {
    return text(value).split('|').map(function (part) {
      var segments = part.split(':');
      if (segments.length < 2) { return null; }
      return {
        name: text(segments[0]),
        selected: text(segments[1]) === '1'
      };
    }).filter(function (choice) {
      return choice !== null && text(choice.name).length > 0;
    });
  }
  function luckinPromptWithOption(block, groupName, choiceName) {
    var parts = [];
    var productLine = metricValue(block, ['商品']).split(' x')[0].trim();
    if (productLine.length > 0) {
      parts.push(productLine);
    }
    list(block && block.rows).forEach(function (row) {
      var label = text(row && row.label);
      if (label.indexOf('选项·') !== 0) { return; }
      var group = label.slice(3);
      var choices = luckinOptionChoices(text(row && row.value));
      var selectedName = '';
      choices.forEach(function (choice) {
        if (group === groupName) {
          if (text(choice.name) === choiceName) {
            selectedName = text(choice.name);
          }
        } else if (choice.selected) {
          selectedName = text(choice.name);
        }
      });
      if (selectedName.length > 0) {
        parts.push(selectedName);
      }
    });
    var remark = metricValue(block, ['备注']);
    if (remark.length > 0) {
      parts.push(remark);
    }
    if (parts.length > 0) {
      return parts.join('，');
    }
    return text(groupName) + choiceName;
  }
  function luckinConfirmBlockFromData(fallbackBlock) {
    var blocks = list(data.blocks);
    for (var blockIndex = 0; blockIndex < blocks.length; blockIndex += 1) {
      if (text(blocks[blockIndex] && blocks[blockIndex].title).indexOf('确认瑞幸订单') >= 0) {
        return blocks[blockIndex];
      }
    }
    return fallbackBlock || null;
  }
  function luckinSelectedOptionMap(block, groupName, choiceName) {
    var selections = {};
    list(block && block.rows).forEach(function (row) {
      var label = text(row && row.label);
      if (label.indexOf('选项·') !== 0) { return; }
      var group = label.slice(3);
      luckinOptionChoices(text(row && row.value)).forEach(function (choice) {
        if (choice.selected) {
          selections[group] = text(choice.name);
        }
      });
    });
    selections[groupName] = choiceName;
    return selections;
  }
  function luckinConfirmPreviewPicture(block, confirmAction) {
    var fromAction = actionArg(confirmAction, 'pictureUrl');
    if (fromAction.length > 0) {
      return fromAction;
    }
    return luckinProductImageUrl(block);
  }
  function luckinConfirmPreviewArgs(block, groupName, choiceName, nextPrompt) {
    var confirmAction = luckinConfirmAction(block);
    if (!confirmAction) { return null; }
    return {
      deptId: actionArg(confirmAction, 'deptId'),
      location: actionArg(confirmAction, 'location'),
      productId: actionArg(confirmAction, 'productId'),
      skuCode: actionArg(confirmAction, 'skuCode'),
      quantity: actionArg(confirmAction, 'quantity'),
      previewPrompt: nextPrompt,
      attrGroup: groupName,
      attrChoice: choiceName,
      attrSelections: luckinSelectedOptionMap(block, groupName, choiceName),
      pictureUrl: luckinConfirmPreviewPicture(block, confirmAction)
    };
  }
  function postLuckinOptionPreview(block, groupName, choiceName) {
    var currentBlock = luckinConfirmBlockFromData(block);
    if (!currentBlock) { return; }
    var nextPrompt = luckinPromptWithOption(currentBlock, groupName, choiceName);
    var previewArgs = luckinConfirmPreviewArgs(currentBlock, groupName, choiceName, nextPrompt);
    if (!previewArgs || text(previewArgs.deptId).length === 0) { return; }
    postAction({
      id: 'luckin.order.preview',
      label: '调整' + groupName,
      prompt: nextPrompt,
      variant: 'secondary',
      kind: 'prompt',
      args: previewArgs
    });
  }
  function bindLuckinOptionChip(chip, block, groupName, choice) {
    var choiceName = text(choice.name);
    var onActivate = function (event) {
      if (event && typeof event.preventDefault === 'function') {
        event.preventDefault();
      }
      if (event && typeof event.stopPropagation === 'function') {
        event.stopPropagation();
      }
      if (isBusy || choice.selected) { return; }
      setLuckinOptionPanelUpdating(true);
      postLuckinOptionPreview(block, groupName, choiceName);
    };
    chip.addEventListener('click', onActivate);
  }
  function addLuckinOptionPanel(parent, block) {
    var optionRows = list(block && block.rows).filter(function (row) {
      return text(row && row.label).indexOf('选项·') === 0;
    });
    if (optionRows.length === 0) { return; }
    var panel = add(parent, 'div', 'luckin-option-panel');
    optionRows.forEach(function (row) {
      var groupName = text(row.label).slice(3);
      var choices = luckinOptionChoices(text(row.value));
      if (groupName.length === 0 || choices.length === 0) { return; }
      var group = add(panel, 'div', 'luckin-option-group');
      add(group, 'div', 'luckin-option-label', groupName);
      var chips = add(group, 'div', 'luckin-option-chips');
      choices.forEach(function (choice) {
        var chip = add(chips, 'button', 'luckin-option-chip' + (choice.selected ? ' is-selected' : ' is-alt'));
        chip.type = 'button';
        chip.textContent = text(choice.name);
        chip.disabled = isBusy || choice.selected;
        if (choice.selected) {
          chip.setAttribute('aria-pressed', 'true');
        }
        bindLuckinOptionChip(chip, block, groupName, choice);
      });
    });
  }
  function luckinPriceItemClass(label) {
    if (label === '原价') { return 'is-origin'; }
    if (label === '优惠') { return 'is-discount'; }
    if (label === '应付') { return 'is-pay'; }
    return '';
  }
  function addLuckinOrderRows(parent, block) {
    var isConfirm = isLuckinConfirmOrderBlock(block);
    var hiddenLabels = ['商品图', 'SKU'];
    if (isConfirm) {
      hiddenLabels.push('门店', '地址', '备注');
    }
    var kept = list(block && block.rows).filter(function (item) {
      var label = text(item && item.label);
      return text(item && item.value).length > 0 &&
        hiddenLabels.indexOf(label) < 0 &&
        label.indexOf('选项·') !== 0;
    });
    if (kept.length === 0) { return; }
    var priceLabels = ['原价', '优惠', '应付'];
    if (isConfirm) {
      var priceMap = {};
      var detailRows = [];
      var detailGrid = null;
      kept.forEach(function (item) {
        var label = text(item && item.label);
        if (priceLabels.indexOf(label) >= 0) {
          priceMap[label] = text(item.value);
        } else {
          detailRows.push(item);
        }
      });
      if (detailRows.length > 0) {
        detailRows.forEach(function (item) {
          var label = text(item && item.label);
          var value = text(item && item.value);
          if (label === '商品') {
            var productGroup = add(parent, 'div', 'luckin-order-product-group');
            add(productGroup, 'div', 'luckin-option-label', '商品');
            add(productGroup, 'div', 'luckin-order-product-value', value);
            return;
          }
          if (!detailGrid) {
            detailGrid = add(parent, 'div', 'luckin-order-rows');
          }
          var row = add(detailGrid, 'div', 'luckin-order-row');
          add(row, 'div', 'label', item.label);
          add(row, 'div', 'value', item.value);
        });
      }
      var hasPrice = false;
      priceLabels.forEach(function (label) {
        if (text(priceMap[label]).length > 0) {
          hasPrice = true;
        }
      });
      if (!hasPrice) { return; }
      var priceBar = add(parent, 'div', 'luckin-order-price-bar');
      priceLabels.forEach(function (label) {
        var value = text(priceMap[label]);
        if (value.length === 0) { return; }
        var itemNode = add(priceBar, 'div', 'luckin-price-item ' + luckinPriceItemClass(label));
        add(itemNode, 'div', 'label', label);
        add(itemNode, 'div', 'value', value);
      });
      return;
    }
    var grid = add(parent, 'div', 'luckin-order-rows');
    kept.forEach(function (item) {
      var row = add(grid, 'div', 'luckin-order-row');
      add(row, 'div', 'label', item.label);
      add(row, 'div', 'value', item.value);
    });
  }
  function addLuckinConfirmProductBadge(parent, block) {
    var imageUrl = luckinProductImageUrl(block);
    if (imageUrl.length === 0) { return; }
    var badge = add(parent, 'div', 'luckin-product-badge');
    var img = document.createElement('img');
    img.className = 'luckin-product-badge-image';
    img.src = imageUrl;
    img.alt = metricValue(block, ['商品']) || text(block.title);
    img.setAttribute('loading', 'lazy');
    badge.appendChild(img);
  }
  function shouldShowLuckinOrderSubtitle(block) {
    return text(block && block.title).indexOf('瑞幸订单已创建') < 0;
  }
  function luckinPaymentProductName(block) {
    var product = metricValue(block, ['商品']);
    if (product.length === 0) { return '瑞幸饮品'; }
    var parts = product.split(' x');
    return text(parts[0]).length > 0 ? text(parts[0]) : product;
  }
  function luckinPaymentStoreName(block) {
    var store = metricValue(block, ['门店']);
    if (store.length === 0) { return '瑞幸咖啡'; }
    return store.replace(/^瑞幸咖啡\s+/, '瑞幸咖啡·');
  }
  function luckinPaymentOptionSummary(block) {
    var parts = [];
    list(block && block.rows).forEach(function (row) {
      var label = text(row && row.label);
      if (label.indexOf('选项·') !== 0) { return; }
      luckinOptionChoices(text(row && row.value)).forEach(function (choice) {
        if (choice.selected) {
          parts.push(text(choice.name));
        }
      });
    });
    if (parts.length > 0) {
      return parts.join(' · ');
    }
    var remark = metricValue(block, ['备注']);
    return remark.length > 0 ? remark : '默认规格';
  }
  function luckinPaymentAmountText(block) {
    var amount = metricValue(block, ['应付']);
    if (amount.length === 0) { return '¥ --'; }
    var normalized = amount.replace(/^¥\s*/, '').trim();
    return normalized.length > 0 ? '¥ ' + normalized : amount;
  }
  function luckinPaymentDiscountText(block) {
    var discount = metricValue(block, ['优惠']);
    if (discount.length === 0) { return ''; }
    var normalized = discount.replace(/^¥\s*/, '').trim();
    return normalized.length > 0 ? '已优惠 ¥' + normalized : '已优惠 ' + discount;
  }
  function luckinPaymentOrderContext(block) {
    var orderId = metricValue(block, ['订单号']);
    var payOrderUrl = metricValue(block, ['支付链接']);
    var payOrderQrCodeUrl = metricValue(block, ['支付二维码']);
    var pools = [list(block && block.actions), list(data && data.actions)];
    list(data && data.blocks).forEach(function (item) {
      pools.push(list(item && item.actions));
    });
    for (var poolIndex = 0; poolIndex < pools.length; poolIndex += 1) {
      var actions = pools[poolIndex];
      for (var actionIndex = 0; actionIndex < actions.length; actionIndex += 1) {
        var action = actions[actionIndex];
        if (text(actionArg(action, 'orderId')).length > 0 && orderId.length === 0) {
          orderId = actionArg(action, 'orderId');
        }
        if (text(actionArg(action, 'payOrderUrl')).length > 0 && payOrderUrl.length === 0) {
          payOrderUrl = actionArg(action, 'payOrderUrl');
        }
        if (text(actionArg(action, 'payOrderQrCodeUrl')).length > 0 && payOrderQrCodeUrl.length === 0) {
          payOrderQrCodeUrl = actionArg(action, 'payOrderQrCodeUrl');
        }
        if (text(action && action.id) === 'luckin.pay.open' && payOrderUrl.length === 0 && text(action.prompt).length > 0) {
          payOrderUrl = text(action.prompt);
        }
      }
    }
    return {
      orderId: orderId,
      payOrderUrl: payOrderUrl,
      payOrderQrCodeUrl: payOrderQrCodeUrl
    };
  }
  function luckinPaymentOrderId(block) {
    return text(luckinPaymentOrderContext(block).orderId);
  }
  function luckinPaymentActionById(block, id) {
    var pools = [list(block && block.actions), list(data && data.actions)];
    list(data && data.blocks).forEach(function (item) {
      pools.push(list(item && item.actions));
    });
    for (var poolIndex = 0; poolIndex < pools.length; poolIndex += 1) {
      var actions = pools[poolIndex];
      for (var actionIndex = 0; actionIndex < actions.length; actionIndex += 1) {
        if (text(actions[actionIndex] && actions[actionIndex].id) === id) {
          return actions[actionIndex];
        }
      }
    }
    return null;
  }
  function luckinPaymentOrderArgs(block) {
    var ctx = luckinPaymentOrderContext(block);
    var args = {
      orderId: ctx.orderId,
      payOrderUrl: ctx.payOrderUrl,
      payOrderQrCodeUrl: ctx.payOrderQrCodeUrl
    };
    var copyKeys = ['deptId', 'deptName', 'address', 'distance', 'location', 'productId', 'productName', 'skuCode', 'pictureUrl', 'previewPrompt', 'quantity', 'price', 'remark', 'couponCodeList', 'attrSelections'];
    var pools = [list(block && block.actions), list(data && data.actions)];
    list(data && data.blocks).forEach(function (item) {
      pools.push(list(item && item.actions));
    });
    for (var poolIndex = 0; poolIndex < pools.length; poolIndex += 1) {
      var actions = pools[poolIndex];
      for (var actionIndex = 0; actionIndex < actions.length; actionIndex += 1) {
        var action = actions[actionIndex];
        for (var keyIndex = 0; keyIndex < copyKeys.length; keyIndex += 1) {
          var key = copyKeys[keyIndex];
          var value = actionArg(action, key);
          if (text(value).length > 0 && text(args[key]).length === 0) {
            args[key] = value;
          }
        }
      }
    }
    return args;
  }
  function luckinPaymentActionForMethod(block, method) {
    var resolved = luckinPaymentActionById(block, method.id);
    if (resolved !== null) {
      return resolved;
    }
    var ctx = luckinPaymentOrderContext(block);
    var args = luckinPaymentOrderArgs(block);
    if (method.id === 'luckin.pay.open') {
      var payUrl = text(ctx.payOrderUrl).length > 0 ? text(ctx.payOrderUrl) : text(ctx.payOrderQrCodeUrl);
      return {
        id: method.id,
        label: method.label,
        prompt: payUrl,
        variant: 'primary',
        kind: 'client',
        args: args
      };
    }
    if (method.id === 'luckin.demo.alipay.open') {
      return {
        id: method.id,
        label: '支付宝支付（Demo）',
        prompt: 'alipays://',
        variant: 'secondary',
        kind: 'client',
        args: args
      };
    }
    if (method.id === 'luckin.demo.googlepay.open') {
      return {
        id: method.id,
        label: 'Google Pay 转 5 美金（Demo）',
        prompt: '用 Google Pay 给罗一格转 5 美金',
        variant: 'secondary',
        kind: 'client',
        args: args
      };
    }
    return null;
  }
  function luckinPaymentMethodDefs() {
    return [
      { id: 'luckin.pay.open', type: 'wechat', label: '微信' },
      { id: 'luckin.demo.alipay.open', type: 'alipay', label: '支付宝' },
      { id: 'luckin.demo.googlepay.open', type: 'googlepay', label: 'GPay' }
    ];
  }
  function startLuckinPaymentCountdown(node) {
    if (!node || node.getAttribute('data-running') === 'true') { return; }
    var seconds = Number(node.getAttribute('data-seconds') || '900');
    if (isNaN(seconds) || seconds <= 0) { seconds = 900; }
    node.setAttribute('data-running', 'true');
    function render() {
      var minutes = Math.floor(seconds / 60);
      var remain = seconds % 60;
      node.textContent = text(minutes) + ':' + (remain < 10 ? '0' : '') + text(remain);
      if (seconds <= 0) {
        node.textContent = '00:00';
        return;
      }
      seconds -= 1;
      window.setTimeout(render, 1000);
    }
    render();
  }
  function addLuckinPaymentOptionSummary(parent, block) {
    var optionRows = list(block && block.rows).filter(function (row) {
      return text(row && row.label).indexOf('选项·') === 0;
    });
    if (optionRows.length > 0) {
      var chips = add(parent, 'div', 'luckin-payment-option-chips');
      optionRows.forEach(function (row) {
        luckinOptionChoices(text(row && row.value)).forEach(function (choice) {
          if (!choice.selected) { return; }
          add(chips, 'span', 'luckin-payment-option-chip', text(choice.name));
        });
      });
      if (chips.childNodes.length > 0) {
        return;
      }
    }
    var summary = luckinPaymentOptionSummary(block);
    if (summary.length > 0) {
      add(parent, 'div', 'luckin-payment-option-summary', summary);
    }
  }
  function luckinPaymentStatusAction(block) {
    var statusAction = luckinPaymentActionById(block, 'luckin.order.status');
    var orderId = luckinPaymentOrderId(block);
    if (statusAction === null && orderId.length > 0) {
      statusAction = {
        id: 'luckin.order.status',
        label: '刷新订单状态',
        prompt: '查询瑞幸订单状态',
        variant: 'secondary',
        kind: 'prompt',
        args: luckinPaymentOrderArgs(block)
      };
    }
    return statusAction;
  }
  function addLuckinPaymentActions(parent, block) {
    var section = add(parent, 'div', 'luckin-payment-methods');
    add(section, 'div', 'luckin-payment-methods-label', '选择支付方式');
    var grid = add(section, 'div', 'luckin-payment-methods-grid');
    luckinPaymentMethodDefs().forEach(function (method) {
      var action = luckinPaymentActionForMethod(block, method);
      var button = add(grid, 'button', 'luckin-payment-method');
      button.type = 'button';
      button.title = action ? text(action.label || method.label) : method.label;
      button.setAttribute('aria-label', action ? text(action.label || method.label) : method.label);
      button.disabled = isBusy || action === null;
      var iconWrap = add(button, 'span', 'luckin-payment-method-icon-wrap');
      addPaymentActionIcon(iconWrap, method.type);
      if (action === null) { return; }
      button.addEventListener('click', function (event) {
        event.stopPropagation();
        if (isBusy) { return; }
        if (handleLocalAction(action)) {
          return;
        }
        postAction(action);
      });
    });
  }
  function addLuckinPaymentMeta(parent, block) {
    var meta = add(parent, 'div', 'luckin-payment-meta');
    var orderId = luckinPaymentOrderId(block);
    var orderRow = add(meta, 'div', 'luckin-payment-meta-row');
    add(orderRow, 'span', 'label', '订单号');
    add(orderRow, 'span', 'value', orderId.length > 0 ? orderId : '无');
    var storeName = luckinPaymentStoreName(block);
    if (storeName.length > 0) {
      var storeRow = add(meta, 'div', 'luckin-payment-meta-row');
      add(storeRow, 'span', 'label', '门店');
      add(storeRow, 'span', 'value', storeName);
    }
  }
  function addLuckinPaymentCard(parent, block) {
    var wrap = add(parent, 'div', 'luckin-payment-card');
    var header = add(wrap, 'div', 'luckin-payment-header');
    add(header, 'h3', '', '待支付');
    var countdown = add(header, 'span', 'luckin-payment-countdown', '15:00');
    countdown.setAttribute('data-seconds', '900');
    startLuckinPaymentCountdown(countdown);
    var product = add(wrap, 'div', 'luckin-payment-product');
    var imageUrl = luckinProductImageUrl(block);
    if (imageUrl.length > 0) {
      var img = document.createElement('img');
      img.className = 'luckin-payment-product-image';
      img.src = imageUrl;
      img.alt = luckinPaymentProductName(block);
      img.setAttribute('loading', 'lazy');
      product.appendChild(img);
    }
    var productCopy = add(product, 'div', 'luckin-payment-product-copy');
    add(productCopy, 'div', 'luckin-payment-product-name', luckinPaymentProductName(block));
    addLuckinPaymentOptionSummary(productCopy, block);
    var amount = add(wrap, 'div', 'luckin-payment-amount');
    add(amount, 'div', 'luckin-payment-amount-label', '应付金额');
    add(amount, 'div', 'luckin-payment-amount-value', luckinPaymentAmountText(block));
    var origin = metricValue(block, ['原价']);
    var discountText = luckinPaymentDiscountText(block);
    if (origin.length > 0 || discountText.length > 0) {
      var amountMeta = add(amount, 'div', 'luckin-payment-amount-meta');
      if (origin.length > 0) {
        var originNode = add(amountMeta, 'span', 'origin', '原价 ' + origin);
        originNode.setAttribute('aria-label', '原价');
      }
      if (discountText.length > 0) {
        add(amountMeta, 'span', 'discount', discountText);
      }
    }
    addLuckinPaymentActions(wrap, block);
    addLuckinPaymentMeta(wrap, block);
    var statusAction = luckinPaymentStatusAction(block);
    if (statusAction !== null) {
      var refresh = document.createElement('button');
      refresh.className = 'luckin-payment-refresh';
      refresh.type = 'button';
      refresh.textContent = statusAction.label || '刷新订单状态';
      refresh.disabled = isBusy;
      refresh.addEventListener('click', function (event) {
        event.stopPropagation();
        if (isBusy) { return; }
        postAction(statusAction);
      });
      wrap.appendChild(refresh);
    }
    return true;
  }
  function addLuckinOrderCard(parent, block) {
    var wrap = add(parent, 'div', 'luckin-order-card');
    var imageUrl = luckinProductImageUrl(block);
    var useCoconutStage = isLuckinConfirmOrderBlock(block);
    if (useCoconutStage) {
      wrap.classList.add('luckin-order-confirm');
    }
    if (useCoconutStage) {
      var stage = add(wrap, 'div', 'luckin-order-stage');
      var headline = add(stage, 'div', 'luckin-order-headline');
      add(headline, 'h3', 'luckin-order-title', text(block.title) || '瑞幸订单');
      if (shouldShowLuckinOrderSubtitle(block) && text(block.subtitle).length > 0) {
        add(headline, 'p', 'subtitle', text(block.subtitle));
      }
      addLuckinOptionPanel(stage, block);
    } else if (imageUrl.length > 0) {
      var visual = add(wrap, 'div', 'luckin-order-visual');
      var fallbackHost = add(visual, 'div', 'luckin-product-hero');
      var fallbackImg = document.createElement('img');
      fallbackImg.className = 'luckin-product-image';
      fallbackImg.src = imageUrl;
      fallbackImg.alt = metricValue(block, ['商品']) || text(block.title);
      fallbackImg.setAttribute('loading', 'lazy');
      fallbackHost.appendChild(fallbackImg);
      var copy = add(wrap, 'div', 'luckin-order-copy');
      add(copy, 'h3', 'luckin-order-title', text(block.title) || '瑞幸订单');
      if (shouldShowLuckinOrderSubtitle(block) && text(block.subtitle).length > 0) {
        add(copy, 'p', 'subtitle', text(block.subtitle));
      }
      addLuckinOrderRows(copy, block);
      addActions(wrap, block.actions);
      return true;
    }
    var details = add(wrap, 'div', 'luckin-order-copy');
    if (!useCoconutStage) {
      add(details, 'h3', 'luckin-order-title', text(block.title) || '瑞幸订单');
      if (shouldShowLuckinOrderSubtitle(block) && text(block.subtitle).length > 0) {
        add(details, 'p', 'subtitle', text(block.subtitle));
      }
    }
    addLuckinOrderRows(details, block);
    addActions(wrap, block.actions);
    return true;
  }
  function shouldShowLuckinRelocate() {
    var blocks = list(data.blocks);
    for (var blockIndex = 0; blockIndex < blocks.length; blockIndex += 1) {
      if (isLuckinShopSelectBlock(blocks[blockIndex])) {
        return true;
      }
    }
    return false;
  }
  function isLuckinShopSelectBlock(block) {
    if (scene !== 'luckin') { return false; }
    var title = text(block && block.title);
    if (title.indexOf('门店') < 0) { return false; }
    return luckinShopActionItems(block).length > 0;
  }
  function applyLuckinShopSelection(listEl) {
    var rows = listEl.querySelectorAll('.luckin-shop-row');
    rows.forEach(function (row) {
      var key = row.getAttribute('data-shop-key') || '';
      row.classList.toggle('is-selected', key.length > 0 && key === localState.luckinShopKey);
    });
  }
  function addLuckinShopPicker(parent, block) {
    var shops = luckinShopActionItems(block);
    if (shops.length === 0) { return false; }
    var wrap = add(parent, 'div', 'luckin-shop-picker');
    var head = add(wrap, 'div', 'luckin-shop-head');
    add(head, 'h3', 'luckin-shop-title', '选择门店');
    var listEl = add(wrap, 'div', 'luckin-shop-list');
    shops.forEach(function (action, index) {
      var row = add(listEl, 'button', 'luckin-shop-row');
      row.type = 'button';
      var shopKey = actionArg(action, 'deptId') || String(index);
      row.setAttribute('data-shop-key', shopKey);
      var main = add(row, 'div', 'luckin-shop-main');
      var topLine = add(main, 'div', 'luckin-shop-line');
      add(topLine, 'div', 'luckin-shop-name', actionArg(action, 'deptName'));
      var distance = actionArg(action, 'distance');
      if (distance.length > 0) {
        add(topLine, 'div', 'luckin-shop-distance', distance);
      }
      var address = actionArg(action, 'address');
      if (address.length > 0) {
        add(main, 'div', 'luckin-shop-address', address);
      }
      var status = actionArg(action, 'status') || '营业中';
      add(main, 'div', 'luckin-shop-status', status);
      row.disabled = isBusy;
      if (isBusy) { row.setAttribute('aria-disabled', 'true'); }
      row.addEventListener('click', function (event) {
        event.stopPropagation();
        if (isBusy) { return; }
        localState.luckinShopKey = shopKey;
        applyLuckinShopSelection(listEl);
        if (handleLocalAction(action)) {
          return;
        }
        postAction(action);
      });
    });
    applyLuckinShopSelection(listEl);
    return true;
  }
  function addPairs(parent, items, className) {
    var kept = list(items).filter(function (item) {
      return text(item && item.label).length > 0 && text(item && item.value).length > 0;
    });
    if (kept.length === 0) { return; }
    var grid = add(parent, 'div', className || 'metrics');
    kept.forEach(function (item) {
      var card = add(grid, 'div', className === 'rows' ? 'row' : 'metric');
      add(card, 'div', 'label', item.label);
      add(card, 'div', 'value', item.value);
    });
  }
  function addMailExpandedDetails(parent, block, card) {
    var detailAction = mailDetailAction(block);
    if (detailAction) {
      var requestKey = text(detailAction.prompt);
      var detailHost = add(parent, 'div', 'mail-detail-host');
      var calendarHost = add(parent, 'div', 'mail-calendar-host');
      var replyHost = add(parent, 'div', 'mail-reply-actions');
      detailHost.addEventListener('click', function (event) { event.stopPropagation(); });
      calendarHost.addEventListener('click', function (event) { event.stopPropagation(); });
      replyHost.addEventListener('click', function (event) { event.stopPropagation(); });
      if (card && requestKey.length > 0) {
        card.setAttribute('data-mail-detail-key', requestKey);
        mailDetailEntries[requestKey] = {
          card: card,
          host: detailHost,
          calendarHost: calendarHost,
          replyHost: replyHost,
          detailAction: detailAction,
          replyAction: mailReplyActions(block).length > 0 ? mailReplyActions(block)[0] : null,
          status: ''
        };
      }
      addActions(parent, visibleMailActions(block));
    } else {
      addActions(parent, block.actions);
    }
    var hasTechDetails = list(block && block.metrics).length > 0 ||
      list(block && block.rows).length > 0 ||
      text(block && block.rawPreview).length > 0;
    if (!hasTechDetails) { return; }
    var wrap = document.createElement('details');
    wrap.className = 'mail-tech-details';
    wrap.addEventListener('click', function (event) {
      event.stopPropagation();
    });
    parent.appendChild(wrap);
    add(wrap, 'summary', '', '详情');
    var body = add(wrap, 'div', 'mail-tech-body');
    addPairs(body, block.metrics, 'metrics');
    addPairs(body, block.rows, 'rows');
    if (text(block.rawPreview).length > 0) {
      add(body, 'pre', 'raw', block.rawPreview);
    }
  }
  function addActions(parent, actions) {
    var kept = list(actions).filter(function (action) {
      return text(action && (action.label || action.id)).length > 0;
    });
    if (kept.length === 0) { return; }
    var row = add(parent, 'div', 'actions');
    kept.forEach(function (action) {
      var iconType = paymentActionIconType(action);
      var button = add(row, 'button', iconType.length > 0 ? 'action payment-icon-action' : 'action');
      button.type = 'button';
      button.title = text(action.label || action.id);
      button.setAttribute('aria-label', text(action.label || action.id));
      if (iconType.length > 0) {
        addPaymentActionIcon(button, iconType);
      } else {
        button.textContent = text(action.label || action.id);
      }
      button.disabled = isBusy;
      if (isBusy) { button.setAttribute('aria-disabled', 'true'); }
      button.addEventListener('click', function (event) {
        event.stopPropagation();
        if (isBusy) { return; }
        if (handleLocalAction(action)) {
          return;
        }
        postAction(action);
      });
    });
  }
  function paymentActionIconType(action) {
    var id = text(action && action.id);
    if (id === 'luckin.pay.open') { return 'wechat'; }
    if (id === 'luckin.demo.alipay.open') { return 'alipay'; }
    if (id === 'luckin.demo.googlepay.open') { return 'googlepay'; }
    return '';
  }
  function paymentIconSrc(type) {
    if (type === 'wechat') {
      return 'resource://rawfile/wechat_pay.jpeg';
    }
    if (type === 'alipay') {
      return 'resource://rawfile/alipay.jpeg';
    }
    if (type === 'googlepay') {
      return 'resource://rawfile/google_pay.jpeg';
    }
    return '';
  }
  function addPaymentActionIcon(parent, type) {
    var icon = add(parent, 'span', 'payment-action-icon ' + type);
    icon.setAttribute('aria-hidden', 'true');
    var src = paymentIconSrc(type);
    if (src.length > 0) {
      var img = document.createElement('img');
      img.className = 'payment-action-icon-image';
      img.src = src;
      img.alt = '';
      img.setAttribute('aria-hidden', 'true');
      icon.appendChild(img);
    } else {
      icon.textContent = type === 'wechat' ? '微信' : (type === 'alipay' ? '支付宝' : 'GPay');
    }
  }
  function addCredentialForm(parent, block) {
    var credentialName = text(block && block.credentialName);
    var credentialRef = text(block && block.credentialRef);
    if (text(block && block.kind) !== 'dynamic-tool-connect' || credentialName.length === 0 || credentialRef.length === 0) {
      return;
    }
    var wrap = add(parent, 'div', 'credential');
    wrap.addEventListener('click', function (event) {
      event.stopPropagation();
    });
    var input = document.createElement('input');
    input.type = 'password';
    input.placeholder = '粘贴 ' + credentialName;
    input.disabled = isBusy;
    wrap.appendChild(input);
    var button = add(wrap, 'button', 'action', '保存并测试');
    button.type = 'button';
    button.disabled = isBusy;
    button.addEventListener('click', function (event) {
      event.stopPropagation();
      if (isBusy) { return; }
      if ((input.value || '').trim().length === 0) {
        input.focus();
        return;
      }
      postAction({
        id: 'html_dynamic_save_and_test',
        label: '保存并测试',
        prompt: JSON.stringify({
          credentialRef: credentialRef,
          credentialValue: input.value || '',
          toolId: text(block.toolId),
          prompt: text(block.prompt)
        }),
        variant: 'primary',
        kind: 'client'
      });
    });
  }
  function renderPersonaBanner(parent) {
    var persona = data.persona || {};
    var memory = data.personaMemory || {};
    var name = text(persona.name);
    if (text(persona.id).length === 0 || name.length === 0) {
      return;
    }
    var banner = add(parent, 'section', 'persona-banner');
    var avatar = add(banner, 'div', 'persona-avatar');
    var avatarSrc = text(data.personaAvatarDataUri);
    if (avatarSrc.length > 0) {
      var img = add(avatar, 'img');
      img.src = avatarSrc;
      img.alt = '';
      img.setAttribute('aria-hidden', 'true');
    } else {
      avatar.textContent = name.slice(0, 1);
    }
    var copy = add(banner, 'div', 'persona-copy');
    add(copy, 'div', 'persona-title', name + '上线');
    add(copy, 'div', 'persona-subtitle', text(memory.summary) || text(persona.reason));
  }
  app.textContent = '';
  var shell = add(app, 'main', isEnhancedScene() ? 'shell ' + sceneClassName() : 'shell');
  if (scene !== 'luckin') {
    renderSceneHero(shell);
    renderPersonaBanner(shell);
  }
  var chips = list(data.chips).slice();
  if (scene !== 'luckin' && chips.length > 0) {
    var chipbar = add(shell, 'nav', 'chipbar');
    chips.forEach(function (chip) {
      add(chipbar, 'span', 'chip', [text(chip.label), text(chip.value)].filter(Boolean).join(' · '));
    });
  }
  var blocks = list(data.blocks);
  if (blocks.length > 0) {
    var sectionClass = isEnhancedScene() ? 'section blocks-' + scene : 'section';
    if (scene === 'luckin' && hasLuckinConfirmBlock(blocks)) {
      sectionClass += ' blocks-luckin-confirm';
    } else if (scene === 'luckin' && hasLuckinPaymentBlock(blocks)) {
      sectionClass += ' blocks-luckin-payment';
    }
    var blocksSection = add(shell, 'section', sectionClass);
    var isLuckinConfirm = scene === 'luckin' && hasLuckinConfirmBlock(blocks);
    var isLuckinPayment = scene === 'luckin' && hasLuckinPaymentBlock(blocks);
    var confirmBody = null;
    var paymentBody = null;
    if (isLuckinConfirm) {
      confirmBody = add(blocksSection, 'div', 'luckin-confirm-body');
    } else if (isLuckinPayment) {
      paymentBody = add(blocksSection, 'div', 'luckin-payment-body');
    } else {
      var blocksHead = add(blocksSection, 'div', 'section-head');
      add(blocksHead, 'h2', '', isEnhancedScene() ? sceneSectionTitle() : '任务结果');
      if (scene === 'luckin' && shouldShowLuckinRelocate()) {
        addLuckinRelocateButton(blocksHead);
      } else if (scene !== 'luckin') {
        var countNode = add(blocksHead, 'div', 'meta', String(blocks.length) + ' 条');
        countNode.id = 'block-count';
      }
    }
    var filterEmpty = add(blocksSection, 'div', 'empty filter-empty', '当前筛选下暂无匹配结果。');
    filterEmpty.id = 'filter-empty';
    var trainIndex = 0;
    blocks.forEach(function (block, index) {
      var blockHost = blocksSection;
      if (isLuckinConfirm && confirmBody && isLuckinOrderBlock(block)) {
        blockHost = confirmBody;
      } else if (isLuckinPayment && paymentBody && isLuckinPaymentOrderBlock(block)) {
        blockHost = paymentBody;
      }
      var card = add(blockHost, 'article', 'block');
      card.style.setProperty('--card-index', String(index));
      card.style.animationDelay = String(Math.min(index, 6) * 42) + 'ms';
      var expandable = isExpandable(block);
      var blockSourceKey = sourceKey(block);
      card.setAttribute('data-kind', text(block.kind));
      card.setAttribute('data-source-key', blockSourceKey);
      if (expandable) {
        card.setAttribute('data-card-key', text(block.id) || text(block.title) || String(blocks.indexOf(block)));
        card.setAttribute('data-expandable', 'true');
        card.setAttribute('aria-expanded', 'false');
        card.addEventListener('click', function () {
          setExpandedCard(card);
        });
      }
      if (text(block.kind) === 'train-option') {
        card.setAttribute('data-train-index', String(trainIndex));
        trainIndex += 1;
      }
      card.setAttribute('data-source', [text(block.source), metricValue(block, ['source'])].join(' '));
      if (block && block.mediaEmbed && text(block.mediaEmbed.embedUrl).length > 0) {
        card.setAttribute('data-has-media', 'true');
      }
      card.setAttribute('data-distance', metricValue(block, ['distance']));
      card.setAttribute('data-duration', metricValue(block, ['duration']));
      card.setAttribute('data-availability', [
        metricValue(block, ['availability', 'status']),
        metricValue(block, ['seats', 'business', 'first', 'second', 'noSeat', 'hardSeat', 'sleeperSoft'])
      ].join(' '));
      if (text(block.kind) === 'persona-memory-update') {
        addPersonaMemoryUpdateCard(card, block);
      } else if (isLuckinShopSelectBlock(block)) {
        card.classList.add('luckin-shop-block');
        addLuckinShopPicker(card, block);
      } else if (isLuckinOrderBlock(block)) {
        card.classList.add('luckin-order-block');
        if (isLuckinPaymentOrderBlock(block)) {
          addLuckinPaymentCard(card, block);
        } else {
          addLuckinOrderCard(card, block);
          if (isLuckinConfirm && confirmBody && isLuckinConfirmOrderBlock(block)) {
            addLuckinConfirmProductBadge(confirmBody, block);
          }
        }
      } else {
        var top = add(card, 'div', 'block-top');
        var titleWrap = add(top, 'div', 'block-title');
        addBlockTag(titleWrap, block, blockSourceKey);
        add(titleWrap, 'h3', '', text(block.title) || text(block.kind) || text(block.id));
        add(titleWrap, 'p', 'subtitle', text(block.subtitle));
        if (expandable) {
          var expandButton = add(top, 'button', 'expand-button', '展开');
          expandButton.type = 'button';
          expandButton.addEventListener('click', function (event) {
            event.stopPropagation();
            setExpandedCard(card);
          });
        }
        addComposioPreview(card, block, blockSourceKey);
        addGoogleMapPreview(card, block);
        var detailHost = expandable ? add(card, 'div', 'details') : card;
        addMediaEmbed(detailHost, block);
        addStripeReceivingOnboarding(detailHost, block);
        if (scene === 'gmail' && text(block.kind) === 'generic-tool-result') {
          addMailExpandedDetails(detailHost, block, card);
        } else {
          addActions(detailHost, block.actions);
          addPairs(detailHost, block.metrics, 'metrics');
          addPairs(detailHost, block.rows, 'rows');
          if (text(block.rawPreview).length > 0) {
            add(detailHost, 'pre', 'raw', block.rawPreview);
          }
        }
        addCredentialForm(detailHost, block);
      }
    });
    if (isLuckinConfirm) {
      var confirmHero = add(blocksSection, 'div', 'luckin-confirm-hero');
      add(confirmHero, 'div', 'luckin-coconut-float');
      var confirmHead = add(confirmHero, 'div', 'section-head luckin-confirm-head');
      add(confirmHead, 'h2', '', sceneSectionTitle());
      blocksSection.insertBefore(confirmHero, blocksSection.firstChild);
    } else if (isLuckinPayment) {
      var paymentHero = add(blocksSection, 'div', 'luckin-payment-hero');
      add(paymentHero, 'div', 'luckin-payment-hero-image');
      var paymentHead = add(paymentHero, 'div', 'section-head luckin-payment-head');
      add(paymentHead, 'h2', '', '订单支付');
      blocksSection.insertBefore(paymentHero, blocksSection.firstChild);
    }
    var firstMediaCard = blocksSection.querySelector('[data-has-media="true"]');
    if (firstMediaCard && !localState.expandedKey) {
      expandCard(firstMediaCard);
    }
    applyLocalView();
  } else if (scene === 'luckin') {
    var emptySection = add(shell, 'section', 'section blocks-luckin');
    var emptyHead = add(emptySection, 'div', 'section-head');
    add(emptyHead, 'h2', '', sceneSectionTitle());
    add(emptySection, 'div', 'empty', emptyCopy());
  } else {
    add(shell, 'section', 'empty', emptyCopy());
  }
  var timeline = list(data.timeline);
  if (scene !== 'luckin' && timeline.length > 0 && (blocks.length === 0 || isBusy)) {
    var timelineSection = add(shell, 'section', 'section');
    var timelineHead = add(timelineSection, 'div', 'section-head');
    add(timelineHead, 'h2', '', '执行轨迹');
    var timelineWrap = add(timelineSection, 'div', 'timeline');
    timeline.forEach(function (item) {
      var node = add(timelineWrap, 'article', 'timeline-item');
      add(node, 'h3', '', text(item.title) === 'prompt' ? '用户请求' : text(item.title) || statusLabel(item.status));
      add(node, 'p', 'subtitle', text(item.subtitle));
      add(node, 'div', 'meta', statusLabel(item.status));
    });
  }
  var history = list(data.history);
  if (scene !== 'luckin' && history.length > 0) {
    var historySection = add(shell, 'section', 'section');
    var historyHead = add(historySection, 'div', 'section-head');
    add(historyHead, 'h2', '', '上下文');
    history.forEach(function (item) {
      var node = add(historySection, 'article', 'history-item');
      add(node, 'div', 'meta', text(item.role));
      add(node, 'p', 'subtitle', text(item.content));
    });
  }
  function setLuckinOptionPanelUpdating(updating) {
    var panel = document.querySelector('.luckin-option-panel');
    if (panel) {
      panel.classList.toggle('is-updating', !!updating);
    }
    if (window.__luckinOptionUpdatingTimer) {
      clearTimeout(window.__luckinOptionUpdatingTimer);
      window.__luckinOptionUpdatingTimer = 0;
    }
    if (updating) {
      window.__luckinOptionUpdatingTimer = setTimeout(function () {
        setLuckinOptionPanelUpdating(false);
      }, 8000);
    }
  }
  function syncLuckinConfirmData(block) {
    var blocks = list(data.blocks);
    var replaced = false;
    for (var blockIndex = 0; blockIndex < blocks.length; blockIndex += 1) {
      if (text(blocks[blockIndex] && blocks[blockIndex].title).indexOf('确认瑞幸订单') >= 0) {
        data.blocks[blockIndex] = block;
        replaced = true;
        break;
      }
    }
    if (!replaced) {
      data.blocks = [block];
    }
    var dataNode = document.getElementById('home-data');
    if (dataNode) {
      dataNode.textContent = JSON.stringify(data);
    }
  }
  function refreshLuckinConfirmBlock(block) {
    var section = document.querySelector('.section.blocks-luckin.blocks-luckin-confirm');
    if (!section) {
      setLuckinOptionPanelUpdating(false);
      return false;
    }
    var confirmBody = section.querySelector('.luckin-confirm-body');
    if (!confirmBody) {
      setLuckinOptionPanelUpdating(false);
      return false;
    }
    var orderBlock = confirmBody.querySelector('.block.luckin-order-block');
    if (!orderBlock) {
      setLuckinOptionPanelUpdating(false);
      return false;
    }
    orderBlock.innerHTML = '';
    addLuckinOrderCard(orderBlock, block);
    var existingBadge = confirmBody.querySelector('.luckin-product-badge');
    var existingImg = existingBadge ? existingBadge.querySelector('.luckin-product-badge-image') : null;
    var existingImageSrc = existingImg ? text(existingImg.getAttribute('src') || existingImg.src) : '';
    if (!(existingBadge && existingImageSrc.length > 0)) {
      if (existingBadge && existingBadge.parentNode) {
        existingBadge.parentNode.removeChild(existingBadge);
      }
      addLuckinConfirmProductBadge(confirmBody, block);
    }
    syncLuckinConfirmData(block);
    setLuckinOptionPanelUpdating(false);
    return true;
  }
  window.AIPhoneHome = window.AIPhoneHome || {};
  window.AIPhoneHome.patchLuckinConfirm = function (blockJson) {
    try {
      return refreshLuckinConfirmBlock(JSON.parse(blockJson));
    } catch (error) {
      setLuckinOptionPanelUpdating(false);
      return false;
    }
  };
  window.AIPhoneHome.clearLuckinOptionUpdating = function () {
    setLuckinOptionPanelUpdating(false);
    return true;
  };
})();
`;

export function renderHtmlHomeDocument(document: HtmlHomeDocument, isBusy: boolean = false): string {
  if (shouldRenderCalendarHomeDocument(document)) {
    return renderCalendarHomeDocument(document, isBusy);
  }
  if (shouldRenderAggregateSearchHomeDocument(document)) {
    return renderAggregateSearchHomeDocument(document, isBusy);
  }
  if (shouldRenderMediaHomeDocument(document)) {
    return renderMediaHomeDocument(document, isBusy);
  }
  if (shouldRenderTravelHomeDocument(document)) {
    return renderTravelHomeDocument(document, isBusy);
  }
  if (shouldRenderFoodHomeDocument(document)) {
    return renderFoodHomeDocument(document, isBusy);
  }
  if (shouldRenderRideHailingHomeDocument(document)) {
    return renderRideHailingHomeDocument(document, isBusy);
  }
  if (shouldRenderPaymentHomeDocument(document)) {
    return renderPaymentHomeDocument(document, isBusy);
  }
  const renderDocument: HtmlHomeDocumentWithBusy = {
    version: document.version,
    source: document.source,
    kind: document.kind,
    title: document.title,
    subtitle: document.subtitle,
    chips: document.chips,
    metrics: document.metrics,
    timeline: document.timeline,
    blocks: document.blocks,
    actions: document.actions,
    history: document.history,
    persona: document.persona,
    personaMemory: document.personaMemory,
    personaAvatarDataUri: personaAvatarDataUri(document.persona.avatarKey),
    rawSurfaceRoot: document.rawSurfaceRoot,
    generatedAt: '',
    isBusy: isBusy || (document as HtmlHomeDocumentWithBusy).isBusy === true
  };
  const json = escapeScriptJson(JSON.stringify(renderDocument));
  const title = escapeHtmlText(document.title.length > 0 ? document.title : document.kind);
  const enhancedScene: boolean = document.kind === 'gmail' || document.kind === 'social' || document.kind === 'luckin';
  const bodyScene = enhancedScene ? ` data-scene="${escapeHtmlText(document.kind)}"` : '';
  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${title}</title>
<style>${HTML_HOME_CSS}</style>
</head>
<body${bodyScene}>
<div id="app"></div>
<script id="home-data" type="application/json">${json}</script>
<script>${HTML_HOME_JS}</script>
</body>
</html>`;
}

function escapeScriptJson(json: string): string {
  return json
    .split('&').join('\\u0026')
    .split('<').join('\\u003c')
    .split('>').join('\\u003e')
    .split('\u2028').join('\\u2028')
    .split('\u2029').join('\\u2029');
}

function escapeHtmlText(value: HtmlHomeTextValue): string {
  if (value === undefined || value === null) {
    return '';
  }
  return value.toString()
    .split('&').join('&amp;')
    .split('<').join('&lt;')
    .split('>').join('&gt;')
    .split('"').join('&quot;');
}
