import { HtmlHomeDocument } from './HtmlHomeTypes';
import { renderCalendarHomeDocument, shouldRenderCalendarHomeDocument } from './HtmlCalendarHomeRenderer';
import { renderFoodHomeDocument, shouldRenderFoodHomeDocument } from './HtmlFoodHomeRenderer';
import { renderMediaHomeDocument, shouldRenderMediaHomeDocument } from './HtmlMediaHomeRenderer';
import { renderPaymentHomeDocument, shouldRenderPaymentHomeDocument } from './HtmlPaymentHomeRenderer';
import { renderRideHailingHomeDocument, shouldRenderRideHailingHomeDocument } from './HtmlRideHailingHomeRenderer';
import { renderTravelHomeDocument, shouldRenderTravelHomeDocument } from './HtmlTravelHomeRenderer';
import { personaAvatarDataUri } from './PersonaAvatarDataUri';

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
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.9);
  box-shadow: 0 8px 22px rgba(194, 70, 54, 0.08);
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
  width: 5px;
  background: linear-gradient(180deg, var(--kind-accent), transparent);
}
body[data-scene="gmail"] .block {
  border-color: rgba(194, 70, 54, 0.2);
}
body[data-scene="gmail"] .details {
  border-top-color: rgba(194, 70, 54, 0.14);
}
body[data-scene="gmail"] .mail-tech-details {
  margin-top: 10px;
  border: 1px solid rgba(194, 70, 54, 0.12);
  border-radius: 16px;
  padding: 0;
  background: rgba(255, 250, 244, 0.62);
}
body[data-scene="gmail"] .mail-tech-details > summary {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 12px;
  color: #9b3f34;
  font-size: 12px;
  font-weight: 760;
  list-style: none;
}
body[data-scene="gmail"] .mail-tech-details > summary::-webkit-details-marker {
  display: none;
}
body[data-scene="gmail"] .mail-tech-details > summary::after {
  content: "+";
  color: rgba(155, 63, 52, 0.72);
  font-size: 16px;
  line-height: 1;
}
body[data-scene="gmail"] .mail-tech-details[open] > summary::after {
  content: "-";
}
body[data-scene="gmail"] .mail-tech-body {
  border-top: 1px solid rgba(194, 70, 54, 0.1);
  padding: 0 12px 12px;
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
  var localState = { travel: 'all', food: 'all', mail: 'all', trainFastest: false, trainAvailable: false, trainShowMore: false, expandedKey: '' };
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
  var MAIL_ICON_GMAIL = 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCA2NCA2NCI+PHJlY3Qgd2lkdGg9IjY0IiBoZWlnaHQ9IjY0IiByeD0iMTUiIGZpbGw9IiNmZmYiLz48cGF0aCBkPSJNMTIgMjB2MjhoNDBWMjBMMzIgMzUgMTIgMjBaIiBmaWxsPSIjZmZmIiBzdHJva2U9IiNkOWRkZTMiIHN0cm9rZS13aWR0aD0iMyIvPjxwYXRoIGQ9Ik0xMiAyMGwyMCAxNSAyMC0xNSIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjZWE0MzM1IiBzdHJva2Utd2lkdGg9IjciIHN0cm9rZS1saW5lam9pbj0icm91bmQiLz48cGF0aCBkPSJNMTIgMjB2MjgiIHN0cm9rZT0iIzQyODVmNCIgc3Ryb2tlLXdpZHRoPSI3Ii8+PHBhdGggZD0iTTUyIDIwdjI4IiBzdHJva2U9IiMzNGE4NTMiIHN0cm9rZS13aWR0aD0iNyIvPjxwYXRoIGQ9Ik0xMiA0OGg0MCIgc3Ryb2tlPSIjZmJiYzA1IiBzdHJva2Utd2lkdGg9IjciLz48L3N2Zz4=';
  var MAIL_ICON_QQ = 'data:image/png;base64,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';
  var MEDIA_ICON_YOUTUBE = 'data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 64 64%22%3E%3Crect width=%2264%22 height=%2264%22 rx=%2215%22 fill=%22%23c4302b%22/%3E%3Cpath d=%22M26 21v22l20-11z%22 fill=%22%23fff%22/%3E%3C/svg%3E';
  var MEDIA_ICON_BILIBILI = 'data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 64 64%22%3E%3Crect width=%2264%22 height=%2264%22 rx=%2215%22 fill=%22%232d8fbd%22/%3E%3Crect x=%2211%22 y=%2220%22 width=%2242%22 height=%2230%22 rx=%227%22 fill=%22%23fff%22/%3E%3Cpath d=%22M23 13l7 7M41 13l-7 7%22 stroke=%22%23fff%22 stroke-width=%224%22 stroke-linecap=%22round%22/%3E%3Ccircle cx=%2225%22 cy=%2235%22 r=%223%22 fill=%22%232d8fbd%22/%3E%3Ccircle cx=%2239%22 cy=%2235%22 r=%223%22 fill=%22%232d8fbd%22/%3E%3C/svg%3E';
  var COMPOSIO_ICON_GITHUB = 'data:image/svg+xml,%3Csvg%20fill%3D%22%23181717%22%20role%3D%22img%22%20viewBox%3D%220%200%2024%2024%22%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%3E%3Cpath%20d%3D%22M12%20.297c-6.63%200-12%205.373-12%2012%200%205.303%203.438%209.8%208.205%2011.385.6.113.82-.258.82-.577%200-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422%2018.07%203.633%2017.7%203.633%2017.7c-1.087-.744.084-.729.084-.729%201.205.084%201.838%201.236%201.838%201.236%201.07%201.835%202.809%201.305%203.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93%200-1.31.465-2.38%201.235-3.22-.135-.303-.54-1.523.105-3.176%200%200%201.005-.322%203.3%201.23.96-.267%201.98-.399%203-.405%201.02.006%202.04.138%203%20.405%202.28-1.552%203.285-1.23%203.285-1.23.645%201.653.24%202.873.12%203.176.765.84%201.23%201.91%201.23%203.22%200%204.61-2.805%205.625-5.475%205.92.42.36.81%201.096.81%202.22%200%201.606-.015%202.896-.015%203.286%200%20.315.21.69.825.57C20.565%2022.092%2024%2017.592%2024%2012.297c0-6.627-5.373-12-12-12%22%2F%3E%3C%2Fsvg%3E';
  var COMPOSIO_ICON_DRIVE = 'data:image/svg+xml,%3Csvg%20fill%3D%22%234285F4%22%20role%3D%22img%22%20viewBox%3D%220%200%2024%2024%22%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%3E%3Cpath%20d%3D%22M12.01%201.485c-2.082%200-3.754.02-3.743.047.01.02%201.708%203.001%203.774%206.62l3.76%206.574h3.76c2.081%200%203.753-.02%203.742-.047-.005-.02-1.708-3.001-3.775-6.62l-3.76-6.574zm-4.76%201.73a789.828%20789.861%200%200%200-3.63%206.319L0%2015.868l1.89%203.298%201.885%203.297%203.62-6.335%203.618-6.33-1.88-3.287C8.1%204.704%207.255%203.22%207.25%203.214zm2.259%2012.653-.203.348c-.114.198-.96%201.672-1.88%203.287a423.93%20423.948%200%200%201-1.698%202.97c-.01.026%203.24.042%207.222.042h7.244l1.796-3.157c.992-1.734%201.85-3.23%201.906-3.323l.104-.167h-7.249z%22%2F%3E%3C%2Fsvg%3E';
  var COMPOSIO_ICON_DOCS = 'data:image/svg+xml,%3Csvg%20fill%3D%22%234285F4%22%20role%3D%22img%22%20viewBox%3D%220%200%2024%2024%22%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%3E%3Cpath%20d%3D%22M14.727%206.727H14V0H4.91c-.905%200-1.637.732-1.637%201.636v20.728c0%20.904.732%201.636%201.636%201.636h14.182c.904%200%201.636-.732%201.636-1.636V6.727h-6zm-.545%2010.455H7.09v-1.364h7.09v1.364zm2.727-3.273H7.091v-1.364h9.818v1.364zm0-3.273H7.091V9.273h9.818v1.363zM14.727%206h6l-6-6v6z%22%2F%3E%3C%2Fsvg%3E';
  var COMPOSIO_ICON_SLACK = 'data:image/svg+xml,%3C%3Fxml%20version%3D%221.0%22%20standalone%3D%22no%22%3F%3E%20%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20width%3D%2232%22%20height%3D%2232%22%20viewBox%3D%220%200%2032%2032%22%3E%20%3Crect%20width%3D%2232%22%20height%3D%2232%22%20rx%3D%227%22%20fill%3D%22%23FFFFFF%22%2F%3E%20%3Cpath%20d%3D%22M13.3%204.8C12%204.8%2010.9%205.9%2010.9%207.2V13.3H7.2C5.9%2013.3%204.8%2014.4%204.8%2015.7C4.8%2017%205.9%2018.1%207.2%2018.1H13.3C14.6%2018.1%2015.7%2017%2015.7%2015.7V7.2C15.7%205.9%2014.6%204.8%2013.3%204.8Z%22%20fill%3D%22%2336C5F0%22%2F%3E%20%3Cpath%20d%3D%22M27.2%2013.3C27.2%2012%2026.1%2010.9%2024.8%2010.9H18.7V7.2C18.7%205.9%2017.6%204.8%2016.3%204.8C15%204.8%2013.9%205.9%2013.9%207.2V13.3C13.9%2014.6%2015%2015.7%2016.3%2015.7H24.8C26.1%2015.7%2027.2%2014.6%2027.2%2013.3Z%22%20fill%3D%22%232EB67D%22%2F%3E%20%3Cpath%20d%3D%22M18.7%2027.2C20%2027.2%2021.1%2026.1%2021.1%2024.8V18.7H24.8C26.1%2018.7%2027.2%2017.6%2027.2%2016.3C27.2%2015%2026.1%2013.9%2024.8%2013.9H18.7C17.4%2013.9%2016.3%2015%2016.3%2016.3V24.8C16.3%2026.1%2017.4%2027.2%2018.7%2027.2Z%22%20fill%3D%22%23ECB22E%22%2F%3E%20%3Cpath%20d%3D%22M4.8%2018.7C4.8%2020%205.9%2021.1%207.2%2021.1H13.3V24.8C13.3%2026.1%2014.4%2027.2%2015.7%2027.2C17%2027.2%2018.1%2026.1%2018.1%2024.8V18.7C18.1%2017.4%2017%2016.3%2015.7%2016.3H7.2C5.9%2016.3%204.8%2017.4%204.8%2018.7Z%22%20fill%3D%22%23E01E5A%22%2F%3E%20%3C%2Fsvg%3E';
  var COMPOSIO_ICON_NOTION = 'data:image/svg+xml,%3Csvg%20fill%3D%22%23000000%22%20role%3D%22img%22%20viewBox%3D%220%200%2024%2024%22%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%3E%3Cpath%20d%3D%22M4.459%204.208c.746.606%201.026.56%202.428.466l13.215-.793c.28%200%20.047-.28-.046-.326L17.86%201.968c-.42-.326-.981-.7-2.055-.607L3.01%202.295c-.466.046-.56.28-.374.466zm.793%203.08v13.904c0%20.747.373%201.027%201.214.98l14.523-.84c.841-.046.935-.56.935-1.167V6.354c0-.606-.233-.933-.748-.887l-15.177.887c-.56.047-.747.327-.747.933zm14.337.745c.093.42%200%20.84-.42.888l-.7.14v10.264c-.608.327-1.168.514-1.635.514-.748%200-.935-.234-1.495-.933l-4.577-7.186v6.952L12.21%2019s0%20.84-1.168.84l-3.222.186c-.093-.186%200-.653.327-.746l.84-.233V9.854L7.822%209.76c-.094-.42.14-1.026.793-1.073l3.456-.233%204.764%207.279v-6.44l-1.215-.139c-.093-.514.28-.887.747-.933zM1.936%201.035l13.31-.98c1.634-.14%202.055-.047%203.082.7l4.249%202.986c.7.513.934.653.934%201.213v16.378c0%201.026-.373%201.634-1.68%201.726l-15.458.934c-.98.047-1.448-.093-1.962-.747l-3.129-4.06c-.56-.747-.793-1.306-.793-1.96V2.667c0-.839.374-1.54%201.447-1.632z%22%2F%3E%3C%2Fsvg%3E';
  var COMPOSIO_ICON_LINEAR = 'data:image/svg+xml,%3Csvg%20fill%3D%22%235E6AD2%22%20role%3D%22img%22%20viewBox%3D%220%200%2024%2024%22%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%3E%3Cpath%20d%3D%22M2.886%204.18A11.982%2011.982%200%200%201%2011.99%200C18.624%200%2024%205.376%2024%2012.009c0%203.64-1.62%206.903-4.18%209.105L2.887%204.18ZM1.817%205.626l16.556%2016.556c-.524.33-1.075.62-1.65.866L.951%207.277c.247-.575.537-1.126.866-1.65ZM.322%209.163l14.515%2014.515c-.71.172-1.443.282-2.195.322L0%2011.358a12%2012%200%200%201%20.322-2.195Zm-.17%204.862%209.823%209.824a12.02%2012.02%200%200%201-9.824-9.824Z%22%2F%3E%3C%2Fsvg%3E';
  var COMPOSIO_ICON_ASANA = 'data:image/svg+xml,%3Csvg%20fill%3D%22%23F06A6A%22%20role%3D%22img%22%20viewBox%3D%220%200%2024%2024%22%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%3E%3Cpath%20d%3D%22M18.78%2012.653c-2.882%200-5.22%202.336-5.22%205.22s2.338%205.22%205.22%205.22%205.22-2.34%205.22-5.22-2.336-5.22-5.22-5.22zm-13.56%200c-2.88%200-5.22%202.337-5.22%205.22s2.338%205.22%205.22%205.22%205.22-2.338%205.22-5.22-2.336-5.22-5.22-5.22zm12-6.525c0%202.883-2.337%205.22-5.22%205.22-2.882%200-5.22-2.337-5.22-5.22%200-2.88%202.338-5.22%205.22-5.22%202.883%200%205.22%202.34%205.22%205.22z%22%2F%3E%3C%2Fsvg%3E';
  var COMPOSIO_ICON_TRELLO = 'data:image/svg+xml,%3Csvg%20fill%3D%22%230052CC%22%20role%3D%22img%22%20viewBox%3D%220%200%2024%2024%22%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%3E%3Cpath%20d%3D%22M21.147%200H2.853A2.86%202.86%200%20000%202.853v18.294A2.86%202.86%200%20002.853%2024h18.294A2.86%202.86%200%200024%2021.147V2.853A2.86%202.86%200%200021.147%200zM10.34%2017.287a.953.953%200%2001-.953.953h-4a.954.954%200%2001-.954-.953V5.38a.953.953%200%2001.954-.953h4a.954.954%200%2001.953.953zm9.233-5.467a.944.944%200%2001-.953.947h-4a.947.947%200%2001-.953-.947V5.38a.953.953%200%2001.953-.953h4a.954.954%200%2001.953.953z%22%2F%3E%3C%2Fsvg%3E';
  var COMPOSIO_ICON_OUTLOOK = 'data:image/svg+xml,%3Csvg%20fill%3D%22%230078D4%22%20role%3D%22img%22%20viewBox%3D%220%200%2024%2024%22%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%3E%3Cpath%20d%3D%22M7.88%2012.04q0%20.45-.11.87-.1.41-.33.74-.22.33-.58.52-.37.2-.87.2t-.85-.2q-.35-.21-.57-.55-.22-.33-.33-.75-.1-.42-.1-.86t.1-.87q.1-.43.34-.76.22-.34.59-.54.36-.2.87-.2t.86.2q.35.21.57.55.22.34.31.77.1.43.1.88zM24%2012v9.38q0%20.46-.33.8-.33.32-.8.32H7.13q-.46%200-.8-.33-.32-.33-.32-.8V18H1q-.41%200-.7-.3-.3-.29-.3-.7V7q0-.41.3-.7Q.58%206%201%206h6.5V2.55q0-.44.3-.75.3-.3.75-.3h12.9q.44%200%20.75.3.3.3.3.75V10.85l1.24.72h.01q.1.07.18.18.07.12.07.25zm-6-8.25v3h3v-3zm0%204.5v3h3v-3zm0%204.5v1.83l3.05-1.83zm-5.25-9v3h3.75v-3zm0%204.5v3h3.75v-3zm0%204.5v2.03l2.41%201.5%201.34-.8v-2.73zM9%203.75V6h2l.13.01.12.04v-2.3zM5.98%2015.98q.9%200%201.6-.3.7-.32%201.19-.86.48-.55.73-1.28.25-.74.25-1.61%200-.83-.25-1.55-.24-.71-.71-1.24t-1.15-.83q-.68-.3-1.55-.3-.92%200-1.64.3-.71.3-1.2.85-.5.54-.75%201.3-.25.74-.25%201.63%200%20.85.26%201.56.26.72.74%201.23.48.52%201.17.81.69.3%201.56.3zM7.5%2021h12.39L12%2016.08V17q0%20.41-.3.7-.29.3-.7.3H7.5zm15-.13v-7.24l-5.9%203.54Z%22%2F%3E%3C%2Fsvg%3E';
  var COMPOSIO_ICON_DISCORD = 'data:image/svg+xml,%3C%3Fxml%20version%3D%221.0%22%20standalone%3D%22no%22%3F%3E%20%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20width%3D%2232%22%20height%3D%2232%22%20viewBox%3D%220%200%2032%2032%22%3E%20%3Crect%20width%3D%2232%22%20height%3D%2232%22%20rx%3D%228%22%20fill%3D%22%235865F2%22%2F%3E%20%3Cpath%20d%3D%22M11.3%2010.4C14.1%209.6%2017.9%209.6%2020.7%2010.4C22.1%2012.5%2022.8%2014.9%2022.9%2017.5C20.8%2019%2018.8%2019.6%2016.8%2019.8L16.1%2018.6C17.2%2018.4%2018.2%2018%2019.1%2017.4C18.8%2017.2%2018.5%2017.1%2018.2%2016.9C16.8%2017.5%2015.2%2017.5%2013.8%2016.9C13.5%2017.1%2013.2%2017.2%2012.9%2017.4C13.8%2018%2014.8%2018.4%2015.9%2018.6L15.2%2019.8C13.2%2019.6%2011.2%2019%209.1%2017.5C9.2%2014.9%209.9%2012.5%2011.3%2010.4Z%22%20fill%3D%22%23FFFFFF%22%2F%3E%20%3Ccircle%20cx%3D%2213.5%22%20cy%3D%2215.2%22%20r%3D%221.3%22%20fill%3D%22%235865F2%22%2F%3E%20%3Ccircle%20cx%3D%2218.5%22%20cy%3D%2215.2%22%20r%3D%221.3%22%20fill%3D%22%235865F2%22%2F%3E%20%3C%2Fsvg%3E';
  var COMPOSIO_ICON_LINKEDIN = 'data:image/svg+xml,%3C%3Fxml%20version%3D%221.0%22%20standalone%3D%22no%22%3F%3E%20%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20width%3D%2232%22%20height%3D%2232%22%20viewBox%3D%220%200%2032%2032%22%3E%20%3Crect%20width%3D%2232%22%20height%3D%2232%22%20rx%3D%228%22%20fill%3D%22%230A66C2%22%2F%3E%20%3Crect%20x%3D%228%22%20y%3D%2213%22%20width%3D%223.6%22%20height%3D%2211%22%20rx%3D%220.7%22%20fill%3D%22%23FFFFFF%22%2F%3E%20%3Ccircle%20cx%3D%229.8%22%20cy%3D%229.6%22%20r%3D%222.1%22%20fill%3D%22%23FFFFFF%22%2F%3E%20%3Cpath%20d%3D%22M14.1%2013H17.5V14.5C18.1%2013.6%2019.2%2012.8%2020.9%2012.8C24%2012.8%2025%2014.8%2025%2018.3V24H21.4V18.7C21.4%2016.9%2020.9%2015.9%2019.6%2015.9C17.9%2015.9%2017.7%2017.2%2017.7%2018.7V24H14.1V13Z%22%20fill%3D%22%23FFFFFF%22%2F%3E%20%3C%2Fsvg%3E';
  var COMPOSIO_ICON_WHATSAPP = 'data:image/svg+xml,%3C%3Fxml%20version%3D%221.0%22%20standalone%3D%22no%22%3F%3E%20%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20width%3D%2232%22%20height%3D%2232%22%20viewBox%3D%220%200%2032%2032%22%3E%20%3Crect%20width%3D%2232%22%20height%3D%2232%22%20rx%3D%228%22%20fill%3D%22%2325D366%22%2F%3E%20%3Cpath%20d%3D%22M16%207.3C11.2%207.3%207.4%2011%207.4%2015.6C7.4%2017.1%207.8%2018.5%208.5%2019.7L7.3%2024.7L12.5%2023.4C13.6%2024%2014.8%2024.3%2016%2024.3C20.8%2024.3%2024.6%2020.5%2024.6%2015.8C24.6%2011.1%2020.8%207.3%2016%207.3Z%22%20fill%3D%22%23FFFFFF%22%2F%3E%20%3Cpath%20d%3D%22M12.5%2011.8C12.8%2011.2%2013%2011.2%2013.4%2011.2H14C14.2%2011.2%2014.4%2011.3%2014.5%2011.6L15.4%2013.7C15.5%2014%2015.5%2014.2%2015.3%2014.4L14.7%2015.1C15.3%2016.2%2016.2%2017.1%2017.6%2017.8L18.4%2016.9C18.6%2016.7%2018.8%2016.6%2019.1%2016.7L21.1%2017.6C21.4%2017.8%2021.5%2018%2021.5%2018.3C21.4%2019.2%2020.7%2020.3%2019.5%2020.3C17.2%2020.3%2011.7%2017.7%2011.7%2013.4C11.7%2012.8%2012.1%2012.2%2012.5%2011.8Z%22%20fill%3D%22%2325D366%22%2F%3E%20%3C%2Fsvg%3E';
  var COMPOSIO_ICON_INSTAGRAM = 'data:image/svg+xml,%3C%3Fxml%20version%3D%221.0%22%20standalone%3D%22no%22%3F%3E%20%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20width%3D%2232%22%20height%3D%2232%22%20viewBox%3D%220%200%2032%2032%22%3E%20%3Cdefs%3E%20%3ClinearGradient%20id%3D%22g%22%20x1%3D%224%22%20y1%3D%2228%22%20x2%3D%2228%22%20y2%3D%224%22%20gradientUnits%3D%22userSpaceOnUse%22%3E%20%3Cstop%20stop-color%3D%22%23FCAF45%22%2F%3E%20%3Cstop%20offset%3D%220.45%22%20stop-color%3D%22%23E1306C%22%2F%3E%20%3Cstop%20offset%3D%221%22%20stop-color%3D%22%235851DB%22%2F%3E%20%3C%2FlinearGradient%3E%20%3C%2Fdefs%3E%20%3Crect%20width%3D%2232%22%20height%3D%2232%22%20rx%3D%228%22%20fill%3D%22url(%23g)%22%2F%3E%20%3Crect%20x%3D%229%22%20y%3D%229%22%20width%3D%2214%22%20height%3D%2214%22%20rx%3D%224%22%20fill%3D%22none%22%20stroke%3D%22%23FFFFFF%22%20stroke-width%3D%222%22%2F%3E%20%3Ccircle%20cx%3D%2216%22%20cy%3D%2216%22%20r%3D%223.4%22%20fill%3D%22none%22%20stroke%3D%22%23FFFFFF%22%20stroke-width%3D%222%22%2F%3E%20%3Ccircle%20cx%3D%2220.9%22%20cy%3D%2211.3%22%20r%3D%221.2%22%20fill%3D%22%23FFFFFF%22%2F%3E%20%3C%2Fsvg%3E';
  var COMPOSIO_ICON_SPOTIFY = 'data:image/svg+xml,%3Csvg%20fill%3D%22%231ED760%22%20role%3D%22img%22%20viewBox%3D%220%200%2024%2024%22%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%3E%3Cpath%20d%3D%22M12%200C5.4%200%200%205.4%200%2012s5.4%2012%2012%2012%2012-5.4%2012-12S18.66%200%2012%200zm5.521%2017.34c-.24.359-.66.48-1.021.24-2.82-1.74-6.36-2.101-10.561-1.141-.418.122-.779-.179-.899-.539-.12-.421.18-.78.54-.9%204.56-1.021%208.52-.6%2011.64%201.32.42.18.479.659.301%201.02zm1.44-3.3c-.301.42-.841.6-1.262.3-3.239-1.98-8.159-2.58-11.939-1.38-.479.12-1.02-.12-1.14-.6-.12-.48.12-1.021.6-1.141C9.6%209.9%2015%2010.561%2018.72%2012.84c.361.181.54.78.241%201.2zm.12-3.36C15.24%208.4%208.82%208.16%205.16%209.301c-.6.179-1.2-.181-1.38-.721-.18-.601.18-1.2.72-1.381%204.26-1.26%2011.28-1.02%2015.721%201.621.539.3.719%201.02.419%201.56-.299.421-1.02.599-1.559.3z%22%2F%3E%3C%2Fsvg%3E';
  var COMPOSIO_ICON_TIKTOK = 'data:image/svg+xml,%3Csvg%20fill%3D%22%23000000%22%20role%3D%22img%22%20viewBox%3D%220%200%2024%2024%22%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%3E%3Cpath%20d%3D%22M12.525.02c1.31-.02%202.61-.01%203.91-.02.08%201.53.63%203.09%201.75%204.17%201.12%201.11%202.7%201.62%204.24%201.79v4.03c-1.44-.05-2.89-.35-4.2-.97-.57-.26-1.1-.59-1.62-.93-.01%202.92.01%205.84-.02%208.75-.08%201.4-.54%202.79-1.35%203.94-1.31%201.92-3.58%203.17-5.91%203.21-1.43.08-2.86-.31-4.08-1.03-2.02-1.19-3.44-3.37-3.65-5.71-.02-.5-.03-1-.01-1.49.18-1.9%201.12-3.72%202.58-4.96%201.66-1.44%203.98-2.13%206.15-1.72.02%201.48-.04%202.96-.04%204.44-.99-.32-2.15-.23-3.02.37-.63.41-1.11%201.04-1.36%201.75-.21.51-.15%201.07-.14%201.61.24%201.64%201.82%203.02%203.5%202.87%201.12-.01%202.19-.66%202.77-1.61.19-.33.4-.67.41-1.06.1-1.79.06-3.57.07-5.36.01-4.03-.01-8.05.02-12.07z%22%2F%3E%3C%2Fsvg%3E';
  var COMPOSIO_ICON_TICKETMASTER = 'data:image/svg+xml,%3Csvg%20fill%3D%22%23026CDF%22%20role%3D%22img%22%20viewBox%3D%220%200%2024%2024%22%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%3E%3Cpath%20d%3D%22M14.5153%2011.3333c-.2454%200-.4826.0464-.716.1304l-.0776.4499c.2168-.105.4499-.1681.6912-.1681.1924%200%20.4214.063.4214.2817%200%20.063%200%20.126-.0163.185h-.1923c-.5153%200-1.2924.0546-1.2924.7697%200%20.3994.2699.6181.6502.6181.3026%200%20.4909-.1388.679-.3828h.0082l-.0574.3324h.4624c.0491-.408.2576-1.2576.2576-1.5477%200-.5088-.3966-.6686-.818-.6686zm-.3805%201.8546c-.139%200-.2781-.0758-.2781-.2272%200-.3658.4418-.412.7076-.412h.1922c-.0857.349-.2125.6392-.6217.6392zm-8.647-.7826l.656%201.1947h-.6391l-.563-1.1647h-.0084L4.688%2013.6h-.5546l.6731-3.2h.567l-.3767%201.8007h.0085l.7915-.798h.7366L5.488%2012.4053zm3.8071.746c.0947%200%20.1894-.0216.2562-.0517l-.0907.4485c-.0905.0216-.193.052-.2837.052-.3587%200-.6111-.1554-.6111-.5825%200-.1725.0316-.3407.067-.5175l.1498-.7506H8.4l.0828-.4228h.3824l.0907-.4574.5677-.2026-.1301.66h.4732l-.0828.4226h-.4734l-.193.9707a.9992.9992%200%2000-.0236.2156c0%20.1339.0826.2157.201.2157zm-8.4%200c.0947%200%20.1894-.0216.2564-.0517l-.0906.4485c-.0908.0216-.1934.052-.284.052-.3587%200-.6111-.1554-.6111-.5825%200-.1725.0316-.3407.067-.5175l.1498-.7506H0l.0827-.4228h.3826l.0907-.4574.5675-.2026-.1302.66h.4734l-.0828.4226H.9107l-.1931.9707a1.004%201.004%200%2000-.0237.2156c0%20.1339.0828.2157.201.2157zm2.1018-.5521c0%20.2816.0937.5633.4858.5633.1406%200%20.3154-.0378.4644-.1093l-.0638.4459c-.1747.084-.3623.101-.5498.101-.5668%200-.9333-.3742-.9333-.9337%200-.757.5072-1.333%201.2956-1.333.213%200%20.4176.0378.571.084l-.1406.4626c-.111-.0715-.26-.1093-.4176-.1093-.456%200-.7117.4205-.7117.8285zm-.4574-1.6433h-.61l.1276-.556h.6098l-.1274.556zm-.0956.408L1.9432%2013.6h-.6099l.5006-2.236h.6098zm18.3563.7937c0%20.164-.0199.3236-.0515.4836h-1.2524c.001-.1027.0094-.2168.0564-.387h.7276a.9136.9136%200%2000.012-.1471c0-.2314-.1152-.3616-.3373-.3616-.3133%200-.4579.1904-.56.466a1.2249%201.2249%200%2000-.0864.4297h-.0004l.0001.0063-.0002.012c0%20.0208.0017.04.0026.0598h.0004c.0258.3406.2243.4686.5646.4686.2182%200%20.4285-.0588.627-.1558l-.0677.446c-.2061.0672-.4324.122-.6507.122-.5873%200-.9841-.3029-.9841-.9464%200-.6726.4921-1.3204%201.1627-1.3204.504%200%20.8373.2732.8373.8243zm1.773-.8243c.0755%200%20.156.0042.227.0215l-.1247.5635a.7823.7823%200%2000-.2272-.0344c-.4233%200-.628.3656-.704.7226l-.2137.9935h-.597l.4098-1.9183c.0177-.0946.0356-.1936.0535-.2968h.5702l-.0802.4174h.0089c.107-.241.401-.469.6773-.469zm1.1433.2631c0-.1183-.0707-.1763-.2142-.1763h-.239v.6255h.1018v-.2765h.0852l.1746.2765h.1082l-.178-.2765c.098%200%20.1614-.0724.1614-.1727zm-.3514.093v-.1892h.1208c.0654%200%20.129.0206.129.0915%200%20.0812-.0507.0976-.129.0976h-.1208zM13.2%2011.9398c0%20.1977-.0497.4216-.0955.602L12.8804%2013.6h-.5564l.2243-1.0796c.029-.1333.0706-.3399.0706-.473%200-.1635-.1205-.2667-.2616-.2667-.3862%200-.4817.4644-.5522.7656l-.22%201.0537h-.5564l.2242-1.0796c.0291-.1333.0707-.3399.0707-.473%200-.1635-.1205-.2667-.2616-.2667-.3779%200-.4817.4688-.5523.7656l-.22%201.0537h-.5564l.3903-1.9699c.0167-.086.0332-.1764.0457-.2453h.519l-.0498.297h.0082c.1496-.228.3944-.3485.656-.3485.2533%200%20.5148.1548.544.4215h.0082c.1411-.2881.4526-.4215.7514-.4215.3197%200%20.5937.271.5937.6066zM23.4668%2011.2h-.0001a.5343.5343%200%2000-.5334.5337.534.534%200%2000.5334.533.5341.5341%200%2000.5333-.533.5343.5343%200%2000-.5332-.5337zm.0017.9872c-.2481%200-.4333-.198-.4333-.4535%200-.2556.1852-.4537.4332-.4537.2448%200%20.4297.1981.4297.4537%200%20.2555-.1849.4534-.4296.4535zm-5.4177.5328a1%201%200%2000-.0236.2156c0%20.1339.0828.2157.201.2157.0947%200%20.1894-.0216.2563-.0517l-.0906.4485c-.0907.0216-.1932.052-.284.052-.3587%200-.6111-.1554-.6111-.5825%200-.1725.0317-.3407.067-.5175l.15-.7506h-.3825l.0827-.4228h.3827l.0906-.4574.5676-.2026-.13.66H18.8l-.0828.4226h-.4733l-.1931.9707zm-1.4036-1.3867c.216%200%20.4364.0379.5528.0667l-.128.4247c-.0635-.033-.2267-.0792-.3941-.0792-.1762%200-.3967.0462-.3967.2186%200%20.2734.767.3744.767.9042%200%20.5636-.5157.7317-1.0226.7317-.2381%200-.4763-.0336-.6923-.1303l.128-.45c.1675.0883.335.1682.5642.1682.1984%200%20.4056-.0632.4056-.2396%200-.3491-.767-.383-.767-.9254%200-.5088.5156-.6896.9831-.6896zm-8.3805.8243c0%20.164-.02.3236-.0516.4836H6.9628c.001-.1027.0092-.2168.0565-.387h.7275a.9136.9136%200%2000.012-.1471c0-.2314-.1152-.3616-.3373-.3616-.3134%200-.4579.1904-.56.466a1.2276%201.2276%200%2000-.0864.4297h-.0004l.0001.0063-.0003.012c0%20.0208.0018.04.0027.0598h.0005c.0255.3406.2243.4686.5644.4686.2182%200%20.4286-.0588.627-.1558l-.0676.446c-.2062.0672-.4324.122-.6507.122-.5873%200-.9841-.3028-.9841-.9464%200-.6726.492-1.3204%201.1626-1.3204.504%200%20.8374.2732.8374.8243z%22%2F%3E%3C%2Fsvg%3E';
  var COMPOSIO_ICON_HUBSPOT = 'data:image/svg+xml,%3Csvg%20fill%3D%22%23FF7A59%22%20role%3D%22img%22%20viewBox%3D%220%200%2024%2024%22%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%3E%3Cpath%20d%3D%22M18.164%207.93V5.084a2.198%202.198%200%20001.267-1.978v-.067A2.2%202.2%200%200017.238.845h-.067a2.2%202.2%200%2000-2.193%202.193v.067a2.196%202.196%200%20001.252%201.973l.013.006v2.852a6.22%206.22%200%2000-2.969%201.31l.012-.01-7.828-6.095A2.497%202.497%200%20104.3%204.656l-.012.006%207.697%205.991a6.176%206.176%200%2000-1.038%203.446c0%201.343.425%202.588%201.147%203.607l-.013-.02-2.342%202.343a1.968%201.968%200%2000-.58-.095h-.002a2.033%202.033%200%20102.033%202.033%201.978%201.978%200%2000-.1-.595l.005.014%202.317-2.317a6.247%206.247%200%20104.782-11.134l-.036-.005zm-.964%209.378a3.206%203.206%200%20113.215-3.207v.002a3.206%203.206%200%2001-3.207%203.207z%22%2F%3E%3C%2Fsvg%3E';
  var COMPOSIO_ICON_SALESFORCE = 'data:image/svg+xml,%3Csvg%20fill%3D%22%2300A1E0%22%20role%3D%22img%22%20viewBox%3D%220%200%2024%2024%22%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%3E%3Cpath%20d%3D%22M10.006%205.415a4.195%204.195%200%20013.045-1.306c1.56%200%202.954.9%203.69%202.205.63-.3%201.35-.45%202.1-.45%202.85%200%205.159%202.34%205.159%205.22s-2.31%205.22-5.176%205.22c-.345%200-.69-.044-1.02-.104a3.75%203.75%200%2001-3.3%201.95c-.6%200-1.155-.15-1.65-.375A4.314%204.314%200%20018.88%2020.4a4.302%204.302%200%2001-4.05-2.82c-.27.062-.54.076-.825.076-2.204%200-4.005-1.8-4.005-4.05%200-1.5.811-2.805%202.01-3.51-.255-.57-.39-1.2-.39-1.846%200-2.58%202.1-4.65%204.65-4.65%201.53%200%202.85.705%203.72%201.8%22%2F%3E%3C%2Fsvg%3E';
  var COMPOSIO_ICON_DEFAULT = 'data:image/svg+xml,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20width%3D%221024%22%20height%3D%221024%22%20viewBox%3D%220%200%201024%201024%22%3E%20%3Cg%20fill%3D%22none%22%20stroke-linecap%3D%22round%22%20stroke-linejoin%3D%22round%22%3E%20%3Cpath%20d%3D%22M246%20792L512%20224L730%20792%22%20stroke%3D%22%237D4B3B%22%20stroke-width%3D%22118%22%20opacity%3D%220.36%22%2F%3E%20%3Cpath%20d%3D%22M246%20792L512%20224L730%20792%22%20stroke%3D%22%23995F4C%22%20stroke-width%3D%2292%22%2F%3E%20%3Cpath%20d%3D%22M332%20632H650%22%20stroke%3D%22%237D4B3B%22%20stroke-width%3D%22118%22%20opacity%3D%220.36%22%2F%3E%20%3Cpath%20d%3D%22M332%20632H650%22%20stroke%3D%22%23995F4C%22%20stroke-width%3D%2292%22%2F%3E%20%3Cpath%20d%3D%22M246%20792H360%22%20stroke%3D%22%23995F4C%22%20stroke-width%3D%2292%22%2F%3E%20%3Cpath%20d%3D%22M650%20792H770%22%20stroke%3D%22%23995F4C%22%20stroke-width%3D%2292%22%2F%3E%20%3C%2Fg%3E%20%3Cg%20fill%3D%22%23995F4C%22%3E%20%3Crect%20x%3D%22612%22%20y%3D%22208%22%20width%3D%2274%22%20height%3D%2274%22%20rx%3D%2216%22%20transform%3D%22rotate(18%20649%20245)%22%20opacity%3D%220.96%22%2F%3E%20%3Crect%20x%3D%22704%22%20y%3D%22216%22%20width%3D%2248%22%20height%3D%2248%22%20rx%3D%2211%22%20transform%3D%22rotate(-26%20728%20240)%22%20opacity%3D%220.82%22%2F%3E%20%3Crect%20x%3D%22790%22%20y%3D%22274%22%20width%3D%2234%22%20height%3D%2234%22%20rx%3D%228%22%20transform%3D%22rotate(17%20807%20291)%22%20opacity%3D%220.72%22%2F%3E%20%3Crect%20x%3D%22648%22%20y%3D%22352%22%20width%3D%2258%22%20height%3D%2258%22%20rx%3D%2213%22%20transform%3D%22rotate(-18%20677%20381)%22%20opacity%3D%220.86%22%2F%3E%20%3Crect%20x%3D%22758%22%20y%3D%22410%22%20width%3D%2245%22%20height%3D%2245%22%20rx%3D%2210%22%20transform%3D%22rotate(26%20780.5%20432.5)%22%20opacity%3D%220.74%22%2F%3E%20%3Crect%20x%3D%22844%22%20y%3D%22510%22%20width%3D%2228%22%20height%3D%2228%22%20rx%3D%227%22%20transform%3D%22rotate(-18%20858%20524)%22%20opacity%3D%220.58%22%2F%3E%20%3Crect%20x%3D%22706%22%20y%3D%22556%22%20width%3D%2236%22%20height%3D%2236%22%20rx%3D%228%22%20transform%3D%22rotate(20%20724%20574)%22%20opacity%3D%220.68%22%2F%3E%20%3Crect%20x%3D%22805%22%20y%3D%22682%22%20width%3D%2228%22%20height%3D%2228%22%20rx%3D%227%22%20transform%3D%22rotate(-25%20819%20696)%22%20opacity%3D%220.52%22%2F%3E%20%3C%2Fg%3E%20%3C%2Fsvg%3E';
  var COMPOSIO_ICON_X = 'data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBzdGFuZGFsb25lPSJubyI/Pgo8c3ZnIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgd2lkdGg9IjMyIiBoZWlnaHQ9IjMyIiB2aWV3Qm94PSIwIDAgMzIgMzIiPgogIDxyZWN0IHdpZHRoPSIzMiIgaGVpZ2h0PSIzMiIgcng9IjciIGZpbGw9IiMwMDAwMDAiLz4KICA8cGF0aCBkPSJNMTguMyAxNC4xTDI2IDVIMjQuMkwxNy41IDEyLjhMMTIuMiA1SDZMMTQuMSAxNi45TDYgMjYuNUg3LjhMMTQuOSAxOC4yTDIwLjYgMjYuNUgyNi44TDE4LjMgMTQuMVpNMTUuOCAxN0wxNSAxNS45TDguNSA2LjRIMTEuM0wxNi42IDE0LjJMMTcuNCAxNS4zTDI0LjIgMjUuMkgyMS40TDE1LjggMTdaIiBmaWxsPSIjRkZGRkZGIi8+Cjwvc3ZnPgo=';
  var COMPOSIO_ICON_WECOM = 'data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBzdGFuZGFsb25lPSJubyI/Pgo8c3ZnIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgd2lkdGg9IjMyIiBoZWlnaHQ9IjMyIiB2aWV3Qm94PSIwIDAgMzIgMzIiPgogIDxyZWN0IHdpZHRoPSIzMiIgaGVpZ2h0PSIzMiIgcng9IjciIGZpbGw9IiNGRkZGRkYiLz4KICA8cGF0aCBkPSJNMTQuMiA3LjFDOC44IDcuMSA0LjUgMTAuNiA0LjUgMTVDNC41IDE3LjUgNS45IDE5LjcgOC4xIDIxLjJMNy4zIDI0LjJDNy4yIDI0LjggNy44IDI1LjIgOC4zIDI0LjlMMTEuOCAyMy4xQzEyLjYgMjMuMyAxMy40IDIzLjQgMTQuMiAyMy40QzE5LjYgMjMuNCAyMy45IDE5LjggMjMuOSAxNS40QzIzLjkgMTAuOSAxOS42IDcuMSAxNC4yIDcuMVoiIGZpbGw9IiMxQUFEMTkiLz4KICA8cGF0aCBkPSJNMTguNyAxMS4zQzIzLjUgMTEuMyAyNy40IDE0LjUgMjcuNCAxOC40QzI3LjQgMjAuNyAyNi4xIDIyLjcgMjQuMSAyNEwyNC44IDI2LjdDMjQuOSAyNy4yIDI0LjQgMjcuNiAyMy45IDI3LjNMMjAuOCAyNS44QzIwLjEgMjYgMTkuNCAyNi4xIDE4LjcgMjYuMUMxMy45IDI2LjEgMTAgMjIuOSAxMCAxOUMxMCAxNSAxMy45IDExLjMgMTguNyAxMS4zWiIgZmlsbD0iIzJGOEZFRSIvPgogIDxjaXJjbGUgY3g9IjEwLjMiIGN5PSIxNC4yIiByPSIxLjEiIGZpbGw9IiNGRkZGRiIvPgogIDxjaXJjbGUgY3g9IjE0LjQiIGN5PSIxNC4yIiByPSIxLjEiIGZpbGw9IiNGRkZGRiIvPgogIDxjaXJjbGUgY3g9IjE3LjEiIGN5PSIxOC43IiByPSIxIiBmaWxsPSIjRkZGRkYiLz4KICA8Y2lyY2xlIGN4PSIyMC43IiBjeT0iMTguNyIgcj0iMSIgZmlsbD0iI0ZGRkZGRiIvPgo8L3N2Zz4K';
  function kindLabel(value) {
    var kind = text(value);
    if (kind === 'welcome') { return '欢迎'; }
    if (kind === 'thinking') { return '执行中'; }
    if (kind === 'travel') { return '出行'; }
    if (kind === 'food') { return '附近餐饮'; }
    if (kind === 'social') { return '社交'; }
    if (kind === 'dynamic-tools') { return '动态工具'; }
    if (kind === 'gmail') { return 'Gmail'; }
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
    if (key === 'social-slack') { return COMPOSIO_ICON_SLACK; }
    if (key === 'social-x') { return COMPOSIO_ICON_X; }
    if (key === 'social-wecom') { return COMPOSIO_ICON_WECOM; }
    if (key === 'social-discord') { return COMPOSIO_ICON_DISCORD; }
    if (key === 'social-linkedin') { return COMPOSIO_ICON_LINKEDIN; }
    if (key === 'social-whatsapp') { return COMPOSIO_ICON_WHATSAPP; }
    if (key === 'social-instagram') { return COMPOSIO_ICON_INSTAGRAM; }
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
	    if (kind === 'persona-memory-update') {
	      return false;
	    }
	    if (kind === 'ride-tool-panel') {
	      return false;
	    }
	    if (kind === 'generic-tool-result') {
	      return list(block && block.metrics).length > 0 ||
	        list(block && block.rows).length > 0 ||
	        list(block && block.actions).length > 0 ||
	        text(block && block.rawPreview).length > 0;
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
    localState.expandedKey = localState.expandedKey === key ? '' : key;
    applyExpandedState();
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
    if (scene === 'thinking') { return '执行状态'; }
    if (scene === 'welcome') { return '起始面板'; }
    return '结果看板';
  }
  function sceneVisualTitle() {
    if (scene === 'gmail') { return '收件预览舱'; }
    if (scene === 'social') { return 'Message Flow'; }
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
    return scene === 'gmail' || scene === 'social';
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
  function addMailExpandedDetails(parent, block) {
    addActions(parent, block.actions);
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
      var button = add(row, 'button', 'action', action.label || action.id);
      button.type = 'button';
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
  renderSceneHero(shell);
  renderPersonaBanner(shell);
  var chips = list(data.chips).slice();
  if (chips.length > 0) {
    var chipbar = add(shell, 'nav', 'chipbar');
    chips.forEach(function (chip) {
      add(chipbar, 'span', 'chip', [text(chip.label), text(chip.value)].filter(Boolean).join(' · '));
    });
  }
  var blocks = list(data.blocks);
  if (blocks.length > 0) {
    var blocksSection = add(shell, 'section', isEnhancedScene() ? 'section blocks-' + scene : 'section');
    var blocksHead = add(blocksSection, 'div', 'section-head');
    add(blocksHead, 'h2', '', isEnhancedScene() ? sceneSectionTitle() : '任务结果');
    var countNode = add(blocksHead, 'div', 'meta', String(blocks.length) + ' 条');
    countNode.id = 'block-count';
    var filterEmpty = add(blocksSection, 'div', 'empty filter-empty', '当前筛选下暂无匹配结果。');
    filterEmpty.id = 'filter-empty';
    var trainIndex = 0;
    blocks.forEach(function (block, index) {
      var card = add(blocksSection, 'article', 'block');
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
          addMailExpandedDetails(detailHost, block);
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
    var firstMediaCard = blocksSection.querySelector('[data-has-media="true"]');
    if (firstMediaCard && !localState.expandedKey) {
      expandCard(firstMediaCard);
    }
    applyLocalView();
  } else {
    add(shell, 'section', 'empty', emptyCopy());
  }
  var timeline = list(data.timeline);
  if (timeline.length > 0 && (blocks.length === 0 || isBusy)) {
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
  if (history.length > 0) {
    var historySection = add(shell, 'section', 'section');
    var historyHead = add(historySection, 'div', 'section-head');
    add(historyHead, 'h2', '', '上下文');
    history.forEach(function (item) {
      var node = add(historySection, 'article', 'history-item');
      add(node, 'div', 'meta', text(item.role));
      add(node, 'p', 'subtitle', text(item.content));
    });
  }
})();
`;

export function renderHtmlHomeDocument(document: HtmlHomeDocument, isBusy: boolean = false): string {
  if (shouldRenderCalendarHomeDocument(document)) {
    return renderCalendarHomeDocument(document, isBusy);
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
  const enhancedScene: boolean = document.kind === 'gmail' || document.kind === 'social';
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
