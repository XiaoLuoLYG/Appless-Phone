import { HtmlHomeAction, HtmlHomeBlock, HtmlHomeDocument, HtmlHomeMetric } from './HtmlHomeTypes';

type HtmlFirecrawlTextValue = Object | string | number | boolean | null | undefined;

interface HtmlFirecrawlHomeDocumentWithBusy extends HtmlHomeDocument {
  isBusy?: boolean;
}

const FIRECRAWL_HOME_CSS: string = `
:root {
  color-scheme: light;
  --paper: #f5f2ee;
  --panel: rgba(255, 255, 255, 0.92);
  --panel-strong: #ffffff;
  --ink: #211b17;
  --ink-soft: #493f38;
  --muted: #7a6e64;
  --line: rgba(33, 27, 23, 0.12);
  --accent: #995f4c;
  --accent-strong: #7b4637;
  --accent-soft: rgba(153, 95, 76, 0.13);
  --success: #397a55;
  --success-soft: rgba(57, 122, 85, 0.12);
  --notice: #9a6a22;
  --notice-soft: rgba(154, 106, 34, 0.12);
  --danger: #b04a42;
  --danger-soft: rgba(176, 74, 66, 0.1);
  --shadow: 0 10px 28px rgba(44, 34, 26, 0.08);
  --ease-out: cubic-bezier(0.23, 1, 0.32, 1);
}
* { box-sizing: border-box; }
body {
  margin: 0;
  min-height: 100dvh;
  background: linear-gradient(180deg, rgba(255,255,255,0.7), rgba(255,255,255,0) 28%), var(--paper);
  color: var(--ink);
  font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Noto Sans SC", "Helvetica Neue", Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
}
button { font: inherit; cursor: pointer; }
button:disabled { cursor: default; opacity: 0.58; }
h1, h2, h3, p { margin: 0; }
.firecrawl-shell {
  width: min(100%, 760px);
  margin: 0 auto;
  padding: 14px 14px calc(96px + env(safe-area-inset-bottom, 0px));
}
.firecrawl-hero {
  position: relative;
  overflow: hidden;
  border: 1px solid var(--line);
  border-radius: 18px;
  padding: 18px;
  background: var(--panel-strong);
  box-shadow: var(--shadow);
}
.firecrawl-hero::after {
  content: "";
  position: absolute;
  right: -44px;
  top: -62px;
  width: 164px;
  height: 164px;
  border-radius: 50%;
  background: radial-gradient(circle, rgba(153,95,76,0.2), rgba(153,95,76,0));
  pointer-events: none;
}
.firecrawl-provider {
  position: relative;
  z-index: 1;
  display: inline-flex;
  align-items: center;
  min-height: 28px;
  border: 1px solid rgba(153,95,76,0.24);
  border-radius: 999px;
  padding: 5px 9px;
  color: var(--accent-strong);
  background: var(--accent-soft);
  font-size: 12px;
  font-weight: 780;
  line-height: 1;
}
.firecrawl-hero h1 {
  position: relative;
  z-index: 1;
  margin-top: 12px;
  max-width: 18ch;
  font-size: clamp(28px, 8vw, 38px);
  line-height: 1.08;
  letter-spacing: -0.045em;
  font-weight: 820;
  overflow-wrap: anywhere;
}
.firecrawl-hero p {
  position: relative;
  z-index: 1;
  margin-top: 9px;
  max-width: 48ch;
  color: var(--ink-soft);
  font-size: 14px;
  line-height: 1.52;
  overflow-wrap: anywhere;
}
.firecrawl-summary {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 8px;
  margin: 14px 0 18px;
}
.firecrawl-stat {
  min-width: 0;
  border: 1px solid var(--line);
  border-radius: 14px;
  padding: 10px;
  background: rgba(255,255,255,0.72);
}
.firecrawl-stat span {
  display: block;
  color: var(--muted);
  font-size: 11px;
  line-height: 1.25;
}
.firecrawl-stat b {
  display: block;
  margin-top: 4px;
  color: var(--ink);
  font-size: 17px;
  line-height: 1.2;
  overflow-wrap: anywhere;
}
.firecrawl-section { margin-top: 22px; }
.firecrawl-section-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 12px;
  margin: 0 2px 10px;
}
.firecrawl-section-head h2 {
  font-size: 18px;
  line-height: 1.2;
  letter-spacing: -0.02em;
  font-weight: 780;
}
.firecrawl-section-head span {
  color: var(--muted);
  font-size: 12px;
  line-height: 1.35;
}
.firecrawl-list { display: grid; gap: 10px; }
.firecrawl-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px;
}
.firecrawl-card {
  min-width: 0;
  border: 1px solid var(--line);
  border-radius: 16px;
  background: var(--panel);
  box-shadow: 0 6px 16px rgba(44, 34, 26, 0.04);
}
.firecrawl-card[data-status="success"] { border-color: rgba(57, 122, 85, 0.28); }
.firecrawl-card[data-status="blocked_by_site"],
.firecrawl-card[data-status="needs_auth"],
.firecrawl-card[data-status="error"] { border-color: rgba(176, 74, 66, 0.28); }
.firecrawl-card[data-status="confirm_required"] { border-color: rgba(153, 95, 76, 0.34); }
.firecrawl-card summary {
  display: block;
  list-style: none;
  cursor: pointer;
  padding: 14px;
}
.firecrawl-card summary::-webkit-details-marker { display: none; }
.firecrawl-card-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}
.firecrawl-kind, .firecrawl-status {
  display: inline-flex;
  align-items: center;
  min-height: 25px;
  border-radius: 999px;
  padding: 4px 8px;
  font-size: 11px;
  font-weight: 760;
  line-height: 1;
}
.firecrawl-kind { background: var(--accent-soft); color: var(--accent-strong); }
.firecrawl-status { background: var(--notice-soft); color: var(--notice); }
.firecrawl-card[data-status="success"] .firecrawl-status { background: var(--success-soft); color: var(--success); }
.firecrawl-card[data-status="blocked_by_site"] .firecrawl-status,
.firecrawl-card[data-status="needs_auth"] .firecrawl-status,
.firecrawl-card[data-status="error"] .firecrawl-status { background: var(--danger-soft); color: var(--danger); }
.firecrawl-card h3 {
  margin-top: 11px;
  color: var(--ink);
  font-size: 18px;
  line-height: 1.25;
  letter-spacing: -0.025em;
  font-weight: 780;
  overflow-wrap: anywhere;
}
.firecrawl-card p {
  margin-top: 7px;
  color: var(--ink-soft);
  font-size: 14px;
  line-height: 1.48;
  overflow-wrap: anywhere;
}
.firecrawl-card .firecrawl-expand {
  display: block;
  margin-top: 10px;
  color: var(--muted);
  font-size: 12px;
  line-height: 1;
}
.firecrawl-card[open] .firecrawl-expand { display: none; }
.firecrawl-card-detail {
  border-top: 1px solid var(--line);
  padding: 13px 14px 14px;
}
.firecrawl-rows { display: grid; gap: 8px; }
.firecrawl-row {
  display: grid;
  grid-template-columns: minmax(74px, 0.45fr) minmax(0, 1fr);
  gap: 10px;
  padding-bottom: 8px;
  border-bottom: 1px solid rgba(33, 27, 23, 0.07);
}
.firecrawl-row:last-child { padding-bottom: 0; border-bottom: 0; }
.firecrawl-row b {
  color: var(--muted);
  font-size: 12px;
  font-weight: 680;
  line-height: 1.42;
}
.firecrawl-row span {
  color: var(--ink-soft);
  font-size: 13px;
  line-height: 1.42;
  overflow-wrap: anywhere;
  white-space: pre-wrap;
}
.firecrawl-actions {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(132px, 1fr));
  gap: 8px;
  margin-top: 13px;
}
.firecrawl-action {
  min-width: 0;
  min-height: 44px;
  border: 1px solid var(--line);
  border-radius: 12px;
  padding: 10px 12px;
  color: var(--ink-soft);
  background: var(--panel-strong);
  font-size: 13px;
  font-weight: 760;
  line-height: 1.2;
  transition: transform 140ms var(--ease-out), background-color 140ms var(--ease-out), border-color 140ms var(--ease-out);
}
.firecrawl-action.primary { border-color: var(--accent); color: #fff; background: var(--accent); }
.firecrawl-action.danger { border-color: var(--danger); color: #fff; background: var(--danger); }
.firecrawl-action.is-pending { opacity: 0.72; }
.firecrawl-action:active { transform: scale(0.98); }
.firecrawl-xhs-note {
  border: 1px solid rgba(153, 95, 76, 0.28);
  border-radius: 14px;
  padding: 12px;
  color: var(--ink-soft);
  background: var(--accent-soft);
  font-size: 13px;
  line-height: 1.48;
}
.firecrawl-read-card,
.firecrawl-social-card {
  border: 1px solid var(--line);
  border-radius: 16px;
  background: var(--panel);
  box-shadow: 0 6px 16px rgba(44, 34, 26, 0.04);
}
.firecrawl-read-card { padding: 16px; }
.firecrawl-content-label,
.firecrawl-source-label {
  display: block;
  color: var(--muted);
  font-size: 11px;
  font-weight: 760;
  line-height: 1.2;
  letter-spacing: 0.04em;
}
.firecrawl-read-card h2,
.firecrawl-social-card h3 {
  margin-top: 8px;
  color: var(--ink);
  font-size: 20px;
  line-height: 1.28;
  letter-spacing: -0.026em;
  font-weight: 790;
  overflow-wrap: anywhere;
}
.firecrawl-read-card p,
.firecrawl-social-card p {
  margin-top: 10px;
  color: var(--ink-soft);
  font-size: 14px;
  line-height: 1.6;
  overflow-wrap: anywhere;
}
.firecrawl-source-host {
  margin-top: 12px;
  color: var(--muted);
  font-size: 12px;
  line-height: 1.35;
  overflow-wrap: anywhere;
}
.firecrawl-social-list { display: grid; gap: 10px; }
.firecrawl-shopping-board {
  margin-top: 18px;
  overflow: hidden;
  border: 1px solid var(--line);
  border-radius: 18px;
  background: var(--panel-strong);
  box-shadow: var(--shadow);
}
.firecrawl-shopping-hero {
  padding: 17px;
  border-bottom: 1px solid var(--line);
  background: rgba(255, 252, 249, 0.94);
}
.firecrawl-shopping-hero > span {
  color: var(--accent-strong);
  font-size: 12px;
  font-weight: 780;
}
.firecrawl-shopping-hero h2 {
  margin-top: 7px;
  font-size: 21px;
  line-height: 1.2;
  letter-spacing: -0.025em;
}
.firecrawl-shopping-hero strong {
  display: block;
  margin-top: 8px;
  color: var(--ink);
  font-size: 28px;
  line-height: 1.1;
  font-variant-numeric: tabular-nums;
}
.firecrawl-shopping-hero.is-lowest strong { color: var(--danger); }
.firecrawl-shopping-hero .firecrawl-shopping-hero-price-kind {
  display: block;
  margin-top: 4px;
  color: var(--muted);
  font-size: 11px;
}
.firecrawl-shopping-hero p {
  margin-top: 7px;
  color: var(--muted);
  font-size: 12px;
  line-height: 1.45;
}
.firecrawl-shopping-source-list { display: grid; }
.firecrawl-shopping-source-row {
  min-width: 0;
  border-top: 1px solid var(--line);
  padding: 15px 16px 16px;
  transition: opacity 160ms var(--ease-out);
}
.firecrawl-shopping-source-row[data-status="partial"] { opacity: 0.7; }
.firecrawl-shopping-source-top {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  align-items: start;
  gap: 12px;
}
.firecrawl-shopping-platform,
.firecrawl-shopping-product,
.firecrawl-shopping-price strong { display: block; }
.firecrawl-shopping-platform {
  color: var(--ink);
  font-size: 15px;
  font-weight: 790;
  line-height: 1.35;
}
.firecrawl-shopping-evidence {
  display: block;
  margin-top: 3px;
  color: var(--muted);
  font-size: 11px;
  line-height: 1.4;
  overflow-wrap: anywhere;
}
.firecrawl-shopping-price {
  min-width: 78px;
  text-align: right;
  font-variant-numeric: tabular-nums;
}
.firecrawl-shopping-price strong {
  color: var(--ink);
  font-size: 18px;
  font-weight: 800;
  line-height: 1.25;
}
.firecrawl-shopping-source-row.is-lowest .firecrawl-shopping-price strong { color: var(--danger); }
.firecrawl-shopping-price-kind {
  display: block;
  margin-top: 3px;
  color: var(--muted);
  font-size: 11px;
}
.firecrawl-shopping-product {
  margin-top: 11px;
  color: var(--ink);
  font-size: 14px;
  font-weight: 730;
  line-height: 1.42;
  overflow-wrap: anywhere;
}
.firecrawl-shopping-spec {
  display: block;
  margin-top: 4px;
  color: var(--muted);
  font-size: 12px;
  line-height: 1.45;
  overflow-wrap: anywhere;
}
.firecrawl-shopping-toggle {
  width: 100%;
  min-height: 44px;
  margin-top: 12px;
  border: 1px solid var(--line);
  border-radius: 11px;
  padding: 9px 11px;
  color: var(--accent-strong);
  background: var(--panel-strong);
  font-size: 12px;
  font-weight: 760;
  transition: transform 140ms var(--ease-out), border-color 140ms var(--ease-out);
}
.firecrawl-shopping-toggle:active { transform: scale(.99); }
.firecrawl-shopping-board .firecrawl-action:active { transform: scale(.97); }
.firecrawl-shopping-detail {
  margin-top: 12px;
  border-top: 1px solid rgba(33, 27, 23, 0.07);
  padding-top: 12px;
}
.firecrawl-shopping-detail[hidden] { display: none; }
.firecrawl-shopping-detail .firecrawl-rows {
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px 14px;
}
.firecrawl-shopping-detail .firecrawl-row { grid-template-columns: 74px minmax(0, 1fr); }
.firecrawl-shopping-group-title {
  border-top: 1px solid var(--line);
  padding: 13px 16px 8px;
  color: var(--muted);
  background: rgba(245, 242, 238, 0.5);
  font-size: 12px;
  font-weight: 780;
}
.firecrawl-shopping-source-row.is-pending {
  color: var(--muted);
  background: rgba(245, 242, 238, 0.3);
}
.firecrawl-shopping-source-row.is-pending strong {
  display: block;
  color: var(--ink-soft);
  font-size: 13px;
}
.firecrawl-shopping-source-row.is-pending span {
  display: block;
  margin-top: 4px;
  font-size: 12px;
}
.firecrawl-social-list {
  grid-template-columns: repeat(2, minmax(0, 1fr));
  align-items: start;
  gap: 12px 10px;
}
.firecrawl-social-card {
  min-width: 0;
  overflow: hidden;
  border: 0;
  border-radius: 14px;
  padding: 0;
  background: var(--panel-strong);
  box-shadow: none;
  cursor: pointer;
}
.firecrawl-social-card:focus-visible {
  outline: 3px solid rgba(153,95,76,0.3);
  outline-offset: 3px;
}
.firecrawl-social-card.is-featured {
  grid-column: 1 / -1;
  border: 1px solid var(--line);
}
.firecrawl-social-media {
  position: relative;
  overflow: hidden;
  aspect-ratio: 3 / 4;
  background: linear-gradient(145deg, #eee7e1, #ded3cb);
}
.firecrawl-social-card.is-featured .firecrawl-social-media { aspect-ratio: 4 / 3; }
.firecrawl-social-carousel {
  display: flex;
  width: 100%;
  height: 100%;
  overflow-x: auto;
  scroll-snap-type: x mandatory;
  scrollbar-width: none;
  overscroll-behavior-x: contain;
}
.firecrawl-social-carousel::-webkit-scrollbar { display: none; }
.firecrawl-social-slide {
  position: relative;
  flex: 0 0 100%;
  width: 100%;
  height: 100%;
  scroll-snap-align: start;
}
.firecrawl-social-slide img {
  display: block;
  width: 100%;
  height: 100%;
  object-fit: cover;
  background: #eee7e1;
}
.firecrawl-social-slide.is-missing::after,
.firecrawl-social-media.is-missing::after {
  content: "图片暂时无法加载";
  position: absolute;
  inset: 0;
  display: grid;
  place-items: center;
  padding: 16px;
  color: var(--muted);
  font-size: 12px;
  text-align: center;
}
.firecrawl-social-media-badge {
  position: absolute;
  z-index: 1;
  top: 9px;
  right: 9px;
  display: inline-flex;
  align-items: center;
  min-height: 24px;
  border-radius: 999px;
  padding: 4px 8px;
  color: #fff;
  background: rgba(20, 17, 15, 0.62);
  backdrop-filter: blur(8px);
  font-size: 11px;
  font-weight: 760;
  line-height: 1;
}
.firecrawl-social-play {
  position: absolute;
  z-index: 1;
  left: 50%;
  top: 50%;
  width: 46px;
  height: 46px;
  border: 1px solid rgba(255,255,255,0.56);
  border-radius: 50%;
  background: rgba(20, 17, 15, 0.52);
  backdrop-filter: blur(8px);
  transform: translate(-50%, -50%);
}
.firecrawl-social-play::after {
  content: "";
  position: absolute;
  left: 18px;
  top: 14px;
  border-top: 8px solid transparent;
  border-bottom: 8px solid transparent;
  border-left: 12px solid #fff;
}
.firecrawl-social-content { padding: 10px 9px 9px; }
.firecrawl-social-card.is-featured .firecrawl-social-content { padding: 14px; }
.firecrawl-social-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}
.firecrawl-social-card .firecrawl-source-label {
  color: var(--accent-strong);
  font-size: 10px;
}
.firecrawl-social-status {
  display: inline-flex;
  align-items: center;
  min-height: 22px;
  border-radius: 999px;
  padding: 4px 7px;
  color: var(--notice);
  background: var(--notice-soft);
  font-size: 10px;
  font-weight: 760;
  line-height: 1;
}
.firecrawl-social-card h3 {
  display: -webkit-box;
  margin-top: 7px;
  overflow: hidden;
  color: var(--ink);
  font-size: 15px;
  line-height: 1.38;
  letter-spacing: -0.018em;
  font-weight: 740;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}
.firecrawl-social-card.is-featured h3 {
  font-size: 21px;
  line-height: 1.3;
  font-weight: 790;
  -webkit-line-clamp: 3;
}
.firecrawl-social-card p {
  display: -webkit-box;
  margin-top: 9px;
  overflow: hidden;
  color: var(--ink-soft);
  font-size: 14px;
  line-height: 1.58;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 4;
}
.firecrawl-social-meta {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-top: 9px;
  color: var(--muted);
  font-size: 11px;
  line-height: 1.4;
}
.firecrawl-social-author-dot {
  width: 18px;
  height: 18px;
  flex: 0 0 auto;
  border-radius: 50%;
  background: linear-gradient(145deg, #e7b8a9, var(--accent));
}
.firecrawl-social-card .firecrawl-source-host { display: none; }
.firecrawl-social-card .firecrawl-actions {
  display: block;
  margin-top: 10px;
}
.firecrawl-social-card .firecrawl-action {
  width: 100%;
  min-height: 40px;
  border-color: transparent;
  border-radius: 10px;
  padding: 9px 10px;
  color: var(--accent-strong);
  background: var(--accent-soft);
  font-size: 12px;
}
.firecrawl-social-card .firecrawl-action:focus-visible {
  outline: 3px solid rgba(153,95,76,0.3);
  outline-offset: 2px;
}
.firecrawl-social-card[data-status="success"] .firecrawl-social-status { color: var(--success); background: var(--success-soft); }
.firecrawl-social-card[data-status="blocked_by_site"] .firecrawl-social-status,
.firecrawl-social-card[data-status="needs_auth"] .firecrawl-social-status,
.firecrawl-social-card[data-status="error"] .firecrawl-social-status { color: var(--danger); background: var(--danger-soft); }
.firecrawl-social-detail {
  position: fixed;
  z-index: 20;
  inset: 0;
  display: none;
  overflow-y: auto;
  overscroll-behavior: contain;
  background: var(--paper);
}
.firecrawl-social-detail.is-open { display: block; }
.firecrawl-social-detail-shell {
  width: min(100%, 760px);
  min-height: 100%;
  margin: 0 auto;
  padding-bottom: calc(48px + env(safe-area-inset-bottom, 0px));
  background: var(--panel-strong);
}
.firecrawl-social-detail-head {
  position: sticky;
  z-index: 3;
  top: 0;
  display: flex;
  align-items: center;
  justify-content: space-between;
  min-height: 56px;
  padding: calc(8px + env(safe-area-inset-top, 0px)) 14px 8px;
  border-bottom: 1px solid var(--line);
  background: rgba(255,255,255,0.94);
  backdrop-filter: blur(14px);
}
.firecrawl-social-detail-head strong {
  font-size: 15px;
  line-height: 1.3;
}
.firecrawl-social-detail-close {
  min-width: 44px;
  min-height: 40px;
  border: 0;
  border-radius: 999px;
  color: var(--ink);
  background: var(--accent-soft);
  font-size: 13px;
  font-weight: 720;
}
.firecrawl-social-detail-media {
  position: relative;
  overflow: hidden;
  aspect-ratio: 4 / 5;
  background: linear-gradient(145deg, #eee7e1, #ded3cb);
}
.firecrawl-social-detail-body { padding: 20px 18px; }
.firecrawl-social-detail-body h2 {
  color: var(--ink);
  font-size: 24px;
  line-height: 1.3;
  letter-spacing: -0.03em;
  overflow-wrap: anywhere;
}
.firecrawl-social-detail-body p {
  margin-top: 14px;
  color: var(--ink-soft);
  font-size: 15px;
  line-height: 1.75;
  white-space: pre-wrap;
  overflow-wrap: anywhere;
}
.firecrawl-social-detail-meta {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: 12px;
  color: var(--muted);
  font-size: 12px;
  line-height: 1.4;
}
body.firecrawl-detail-open { overflow: hidden; }
.firecrawl-empty {
  border: 1px dashed var(--line);
  border-radius: 16px;
  padding: 20px;
  color: var(--muted);
  background: rgba(255,255,255,0.55);
  font-size: 14px;
  line-height: 1.5;
}
.firecrawl-loading {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-top: 18px;
  border: 1px solid var(--line);
  border-radius: 16px;
  padding: 16px;
  background: var(--panel);
  box-shadow: 0 6px 16px rgba(44, 34, 26, 0.04);
}
.firecrawl-loading-mark {
  width: 10px;
  height: 10px;
  flex: 0 0 auto;
  border-radius: 50%;
  background: var(--accent);
  animation: firecrawl-pulse 1.1s var(--ease-out) infinite alternate;
}
.firecrawl-loading b {
  display: block;
  font-size: 15px;
  line-height: 1.32;
}
.firecrawl-loading span {
  display: block;
  margin-top: 3px;
  color: var(--muted);
  font-size: 13px;
  line-height: 1.42;
}
@keyframes firecrawl-pulse {
  from { opacity: 0.38; transform: scale(0.82); }
  to { opacity: 1; transform: scale(1); }
}
@media (hover: hover) and (pointer: fine) {
  .firecrawl-action:hover { transform: translateY(-1px); border-color: rgba(153,95,76,0.48); }
  .firecrawl-action.primary:hover { background: var(--accent-strong); }
  .firecrawl-social-card .firecrawl-action:hover { background: rgba(153,95,76,0.2); }
  .firecrawl-social-card:hover { background: rgba(255,255,255,0.9); }
}
@media (max-width: 560px) {
  .firecrawl-grid { grid-template-columns: 1fr; }
  .firecrawl-hero h1 { max-width: 14ch; }
}
@media (prefers-reduced-motion: reduce) {
  .firecrawl-action { transition: background-color 100ms linear, border-color 100ms linear; }
  .firecrawl-action:active { transform: none; }
  .firecrawl-shopping-source-row,
  .firecrawl-shopping-toggle { transition: none; }
  .firecrawl-shopping-toggle:active,
  .firecrawl-shopping-board .firecrawl-action:active { transform: none; }
  .firecrawl-loading-mark { animation: none; }
}
`;

const FIRECRAWL_HOME_JS: string = `
(function () {
  var actionData = document.getElementById('firecrawl-actions');
  var actions = [];
  try { actions = JSON.parse(actionData ? actionData.textContent || '[]' : '[]'); } catch (error) { actions = []; }
  document.addEventListener('click', function (event) {
    var target = event.target;
    if (!target || typeof target.closest !== 'function') { return; }
    var detailButton = target.closest('[data-shopping-detail]');
    if (detailButton) {
      var index = detailButton.getAttribute('data-shopping-detail');
      var row = document.getElementById('shopping-detail-' + index);
      var expanded = detailButton.getAttribute('aria-expanded') === 'true';
      detailButton.setAttribute('aria-expanded', expanded ? 'false' : 'true');
      if (row) {
        row.hidden = expanded;
      }
      return;
    }
  });
  var triggers = document.querySelectorAll('[data-firecrawl-action-index]');
  for (var index = 0; index < triggers.length; index += 1) {
    (function (trigger) {
      function activate() {
        if (trigger.disabled || trigger.classList.contains('is-pending')) { return; }
        var actionIndex = Number(trigger.getAttribute('data-firecrawl-action-index'));
        var action = actions[actionIndex];
        if (!action || !window.AIPhoneHome || typeof window.AIPhoneHome.postAction !== 'function') { return; }
        if (trigger.tagName === 'BUTTON') { trigger.disabled = true; }
        trigger.classList.add('is-pending');
        try { window.AIPhoneHome.postAction(JSON.stringify(action)); } catch (error) {
          if (trigger.tagName === 'BUTTON') { trigger.disabled = false; }
          trigger.classList.remove('is-pending');
        }
      }
      trigger.addEventListener('click', function (event) {
        event.stopPropagation();
        activate();
      });
      if (trigger.getAttribute('role') === 'link') {
        trigger.addEventListener('keydown', function (event) {
          if (event.key !== 'Enter' && event.key !== ' ') { return; }
          event.preventDefault();
          activate();
        });
      }
    })(triggers[index]);
  }
  var noteTriggers = document.querySelectorAll('[data-firecrawl-note-index]');
  function closeNote(detail) {
    detail.classList.remove('is-open');
    detail.setAttribute('aria-hidden', 'true');
    document.body.classList.remove('firecrawl-detail-open');
  }
  for (var noteIndex = 0; noteIndex < noteTriggers.length; noteIndex += 1) {
    (function (trigger) {
      function openNote() {
        var index = trigger.getAttribute('data-firecrawl-note-index');
        var detail = document.querySelector('[data-firecrawl-detail-index="' + index + '"]');
        if (!detail) { return; }
        detail.classList.add('is-open');
        detail.setAttribute('aria-hidden', 'false');
        document.body.classList.add('firecrawl-detail-open');
        detail.scrollTop = 0;
      }
      trigger.addEventListener('click', openNote);
      trigger.addEventListener('keydown', function (event) {
        if (event.key !== 'Enter' && event.key !== ' ') { return; }
        event.preventDefault();
        openNote();
      });
    })(noteTriggers[noteIndex]);
  }
  var details = document.querySelectorAll('[data-firecrawl-detail-index]');
  for (var detailIndex = 0; detailIndex < details.length; detailIndex += 1) {
    (function (detail) {
      var close = detail.querySelector('[data-firecrawl-detail-close]');
      if (close) { close.addEventListener('click', function () { closeNote(detail); }); }
    })(details[detailIndex]);
  }
  document.addEventListener('keydown', function (event) {
    if (event.key !== 'Escape') { return; }
    var openDetail = document.querySelector('.firecrawl-social-detail.is-open');
    if (openDetail) { closeNote(openDetail); }
  });
})();
`;

const FIRECRAWL_TOOL_IDS: string[] = [
  'web.research.search',
  'web.page.read',
  'shopping.research',
  'social.public.search',
  'web.monitor.create',
  'web.monitor.list'
];

export function shouldRenderFirecrawlHomeDocument(document: HtmlHomeDocument): boolean {
  for (let index = 0; index < document.blocks.length; index++) {
    const block = document.blocks[index];
    if (text(block.source).toLowerCase() === 'firecrawl' &&
      FIRECRAWL_TOOL_IDS.indexOf(toolName(block)) >= 0) {
      return true;
    }
  }
  return false;
}

export function isFirecrawlToolId(toolId: string): boolean {
  return FIRECRAWL_TOOL_IDS.indexOf(toolId) >= 0;
}

export function createFirecrawlPendingDocument(toolId: string): HtmlHomeDocument {
  const profile = toolProfile(toolId);
  return {
    version: 1,
    source: 'tool',
    kind: 'generic',
    title: profile.title,
    subtitle: '',
    chips: [],
    metrics: [],
    timeline: [],
    blocks: [{
      id: 'firecrawl-pending',
      kind: 'generic-tool-result',
      title: profile.pendingTitle,
      subtitle: profile.pendingSubtitle,
      status: 'calling_tool',
      source: 'Firecrawl',
      toolId: toolId,
      metrics: [],
      rows: [],
      actions: []
    }],
    actions: [],
    history: [],
    persona: { id: '', name: '', avatarKey: '', status: '', reason: '' },
    personaMemory: { summary: '', preferences: [] },
    rawSurfaceRoot: null,
    generatedAt: ''
  };
}

export function renderFirecrawlHomeDocument(document: HtmlHomeDocument, isBusy: boolean = false): string {
  const renderDocument: HtmlFirecrawlHomeDocumentWithBusy = {
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
    history: [],
    persona: document.persona,
    personaMemory: document.personaMemory,
    rawSurfaceRoot: null,
    generatedAt: '',
    isBusy: isBusy || (document as HtmlFirecrawlHomeDocumentWithBusy).isBusy === true
  };
  const toolId = primaryToolId(document);
  const profile = toolProfile(toolId);
  const actions = collectActions(document);
  const cards = document.blocks.filter((block: HtmlHomeBlock): boolean =>
    text(block.source).toLowerCase() === 'firecrawl'
  );
  const overview = cards.filter((block: HtmlHomeBlock): boolean => isOverview(block));
  const details = cards.filter((block: HtmlHomeBlock): boolean => !isOverview(block));
  const visibleCards = details.length > 0 ? details : cards;
  const pendingOnly = renderDocument.isBusy === true && cards.length > 0 &&
    cards.every((block: HtmlHomeBlock): boolean => text(block.status) === 'calling_tool');
  const stats = summaryStats(cards);
  const pageTitle = escapeHtmlText(document.title.length > 0 ? document.title : profile.title);
  if (toolId === 'shopping.research') {
    renderDocument.blocks = shoppingHomeDataBlocks(renderDocument.blocks);
  }
  const json = escapeScriptJson(JSON.stringify(renderDocument));
  const actionJson = escapeScriptJson(JSON.stringify(actions));
  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${pageTitle}</title>
<style>${FIRECRAWL_HOME_CSS}</style>
</head>
<body data-scene="firecrawl">
<main class="firecrawl-shell">
  <header class="firecrawl-hero">
    <div class="firecrawl-provider">公开网页</div>
    <h1>${escapeHtmlText(profile.title)}</h1>
    <p>${escapeHtmlText(profile.subtitle(document.subtitle, renderDocument.isBusy === true))}</p>
  </header>
  ${pendingOnly ? (toolId === 'shopping.research' ? renderShoppingPendingState() :
    renderPendingState(profile)) :
    renderFirecrawlResultSections(toolId, profile, stats, overview, visibleCards, actions)}
</main>
<script id="home-data" type="application/json">${json}</script>
<script id="firecrawl-actions" type="application/json">${actionJson}</script>
<script>${FIRECRAWL_HOME_JS}</script>
</body>
</html>`;
}

interface FirecrawlToolProfile {
  title: string;
  listTitle: string;
  subtitle: (fallback: string, busy: boolean) => string;
  pendingTitle: string;
  pendingSubtitle: string;
}

function toolProfile(toolId: string): FirecrawlToolProfile {
  if (toolId === 'web.page.read') {
    return { title: '网页阅读', listTitle: '页面内容', subtitle: pageSubtitle,
      pendingTitle: '正在读取网页', pendingSubtitle: '正在整理页面重点和原网页入口。' };
  }
  if (toolId === 'shopping.research') {
    return { title: '商品比较', listTitle: '商品证据', subtitle: shoppingSubtitle,
      pendingTitle: '正在比较商品', pendingSubtitle: '正在核对公开价格、规格和来源。' };
  }
  if (toolId === 'social.public.search') {
    return { title: '小红书公开搜索', listTitle: '公开结果', subtitle: socialSubtitle,
      pendingTitle: '正在查询公开内容', pendingSubtitle: '只会展示可公开核验的小红书内容。' };
  }
  if (toolId === 'web.monitor.create') {
    return { title: '网页监控', listTitle: '监控操作', subtitle: monitorSubtitle,
      pendingTitle: '正在准备监控', pendingSubtitle: '正在核对监控条件，请稍候。' };
  }
  if (toolId === 'web.monitor.list') {
    return { title: '网页监控', listTitle: '当前监控', subtitle: monitorSubtitle,
      pendingTitle: '正在读取监控', pendingSubtitle: '正在同步已有监控的最新状态。' };
  }
  return { title: '网页研究工作台', listTitle: '来源证据', subtitle: researchSubtitle,
    pendingTitle: '正在读取公开来源', pendingSubtitle: '正在筛选可验证的信息，请稍候。' };
}

function researchSubtitle(fallback: string, busy: boolean): string {
  return busy ? '正在更新公开来源，请稍候。' : fallbackOr(fallback, '把已核验来源、候选来源与搜索用量放在同一处。');
}

function pageSubtitle(fallback: string, busy: boolean): string {
  return busy ? '正在读取公开页面，请稍候。' : fallbackOr(fallback, '保留页面摘要、来源 URL 与打开原网页动作。');
}

function shoppingSubtitle(fallback: string, busy: boolean): string {
  return busy ? '正在比对公开商品信息，请稍候。' : fallbackOr(fallback, '价格、规格和来源各自可追溯。');
}

function socialSubtitle(fallback: string, busy: boolean): string {
  return busy ? '正在打开小红书并整理笔记，请稍候。' : fallbackOr(fallback, '呈现可核验的小红书笔记与原始链接。');
}

function monitorSubtitle(fallback: string, busy: boolean): string {
  return busy ? '正在与 Firecrawl 同步 Monitor 状态，请稍候。' : fallbackOr(fallback, '创建、状态和后续操作都保留 Provider 事实。');
}

function fallbackOr(value: string, fallback: string): string {
  return value.trim().length > 0 ? value : fallback;
}

function renderPendingState(profile: FirecrawlToolProfile): string {
  return '<section class="firecrawl-loading" aria-live="polite"><span class="firecrawl-loading-mark"></span><div><b>' +
    escapeHtmlText(profile.pendingTitle) + '</b><span>' +
    escapeHtmlText(profile.pendingSubtitle) + '</span></div></section>';
}

function renderShoppingPendingState(): string {
  return '<section class="firecrawl-shopping-board" aria-live="polite">' +
    '<header class="firecrawl-shopping-hero"><span>商品比价</span>' +
    '<h2>正在查询固定公开来源</h2>' +
    '<p>先返回的价格会先显示，无需等待全部站点</p></header>' +
    '<div class="firecrawl-shopping-source-list" data-shopping-source-count="0" ' +
    'data-shopping-comparable-count="0">' +
    '<article class="firecrawl-shopping-source-row is-pending"><strong>正在查询第一个公开来源</strong>' +
    '<span>找到价格后会立即展示</span></article>' +
    '<article class="firecrawl-shopping-source-row is-pending"><strong>仍在寻找第二个可比来源</strong>' +
    '<span>用于核验同款最低价</span></article></div></section>';
}

function renderFirecrawlResultSections(
  toolId: string,
  profile: FirecrawlToolProfile,
  stats: string[][],
  overview: HtmlHomeBlock[],
  visibleCards: HtmlHomeBlock[],
  actions: HtmlHomeAction[]
): string {
  if (toolId === 'web.page.read') {
    return renderPageReadSections(profile, visibleCards, actions);
  }
  if (toolId === 'shopping.research') {
    return renderShoppingSections(profile, visibleCards, actions);
  }
  if (toolId === 'social.public.search') {
    return renderSocialSections(visibleCards);
  }
  return renderStats(stats) +
    (overview.length > 0 ? '<section class="firecrawl-section"><div class="firecrawl-section-head"><h2>要点</h2><span>来自公开网页</span></div><div class="firecrawl-list">' + overview.map((block: HtmlHomeBlock, index: number): string => renderCard(block, actions, index === 0, toolId)).join('') + '</div></section>' : '') +
    '<section class="firecrawl-section"><div class="firecrawl-section-head"><h2>' +
    escapeHtmlText(profile.listTitle) + '</h2><span>' + visibleCards.length.toString() +
    ' 条</span></div>' +
    (visibleCards.length > 0 ? '<div class="firecrawl-list">' +
      visibleCards.map((block: HtmlHomeBlock, index: number): string => renderCard(block, actions, index === 0, toolId)).join('') +
      '</div>' : '<div class="firecrawl-empty">暂时没有可展示的公开网页结果，请稍后重试。</div>') +
    '</section>';
}

function renderPageReadSections(
  profile: FirecrawlToolProfile,
  cards: HtmlHomeBlock[],
  actions: HtmlHomeAction[]
): string {
  if (cards.length === 0) {
    return renderEmptySection(profile.listTitle, '暂时没有可读的网页内容，请稍后重试。');
  }
  return '<section class="firecrawl-section"><div class="firecrawl-section-head"><h2>阅读摘要</h2><span>来自原网页</span></div><div class="firecrawl-list">' +
    cards.map((block: HtmlHomeBlock): string => renderPageReadCard(block, actions)).join('') +
    '</div></section>';
}

function renderPageReadCard(block: HtmlHomeBlock, actions: HtmlHomeAction[]): string {
  const summary = displaySubtitle('web.page.read', text(block.status), text(block.subtitle));
  const host = sourceHost(block);
  return '<article class="firecrawl-read-card" data-status="' + escapeAttribute(text(block.status)) + '"><span class="firecrawl-content-label">网页重点</span><h2>' +
    escapeHtmlText(displayTitle('web.page.read', text(block.status), text(block.title))) +
    '</h2>' + (summary.length > 0 ? '<p>' + escapeHtmlText(summary) + '</p>' : '') +
    (host.length > 0 ? '<div class="firecrawl-source-host">来源：' + escapeHtmlText(host) + '</div>' : '') +
    renderActions(block.actions, actions) + '</article>';
}

function renderShoppingSections(
  profile: FirecrawlToolProfile,
  cards: HtmlHomeBlock[],
  actions: HtmlHomeAction[]
): string {
  const sources = cards.filter((block: HtmlHomeBlock): boolean => sourceHost(block).length > 0);
  if (sources.length === 0) {
    return renderEmptySection(profile.listTitle, '暂未找到可核验的同款公开价格');
  }
  const domestic = sources.filter((block: HtmlHomeBlock): boolean => shoppingMarket(block) === 'CN');
  const international = sources.filter((block: HtmlHomeBlock): boolean => shoppingMarket(block) !== 'CN');
  const comparable = domestic.filter(shoppingComparable);
  const keys: string[] = [];
  for (let index = 0; index < domestic.length; index++) {
    const key = shoppingComparisonKey(domestic[index]);
    if (key.length > 0 && keys.indexOf(key) < 0) {
      keys.push(key);
    }
  }
  let canCompare = comparable.length >= 2 && keys.length === 1;
  const comparisonKey = comparable.length > 0 ? shoppingComparisonKey(comparable[0]) : '';
  let lowestFen = 0;
  for (let index = 0; index < comparable.length; index++) {
    if (shoppingComparisonKey(comparable[index]) !== comparisonKey) {
      canCompare = false;
    }
    const priceFen = shoppingPriceFen(comparable[index]);
    if (lowestFen === 0 || priceFen < lowestFen) {
      lowestFen = priceFen;
    }
  }
  return '<section class="firecrawl-shopping-board">' + renderShoppingSummary(domestic, sources.length) +
    '<div class="firecrawl-shopping-source-list" data-shopping-source-count="' + sources.length.toString() +
    '" data-shopping-comparable-count="' + comparable.length.toString() + '">' +
    domestic.map((block: HtmlHomeBlock, index: number): string =>
      renderShoppingRow(block, actions, index,
        canCompare && shoppingPriceFen(block) === lowestFen)
    ).join('') +
    (international.length > 0 ? '<h3 class="firecrawl-shopping-group-title">海外参考</h3>' +
      international.map((block: HtmlHomeBlock, index: number): string =>
        renderShoppingRow(block, actions, domestic.length + index, false)
      ).join('') : '') +
    '</div></section>';
}

function shoppingComparable(block: HtmlHomeBlock): boolean {
  return rowValue(block, ['comparisonEligible']) === 'true' &&
    shoppingPriceFen(block) > 0 && shoppingComparisonKey(block).length > 0;
}

function shoppingPriceFen(block: HtmlHomeBlock): number {
  const value = Number(rowValue(block, ['comparisonPriceFen']));
  return Number.isFinite(value) && value > 0 ? Math.floor(value) : 0;
}

function shoppingComparisonKey(block: HtmlHomeBlock): string {
  return rowValue(block, ['comparisonKey']);
}

function shoppingMarket(block: HtmlHomeBlock): string {
  const market = rowValue(block, ['市场']).trim().toUpperCase();
  return market.length > 0 ? market : 'CN';
}

function renderShoppingSummary(sources: HtmlHomeBlock[], totalSourceCount: number): string {
  const comparable = sources.filter(shoppingComparable);
  const keys: string[] = [];
  for (let index = 0; index < sources.length; index++) {
    const key = shoppingComparisonKey(sources[index]);
    if (key.length > 0 && keys.indexOf(key) < 0) {
      keys.push(key);
    }
  }
  let canCompare = comparable.length >= 2 && keys.length === 1;
  const comparisonKey = comparable.length > 0 ? shoppingComparisonKey(comparable[0]) : '';
  let priceBlock: HtmlHomeBlock | null = null;
  for (let index = 0; index < comparable.length; index++) {
    if (shoppingComparisonKey(comparable[index]) !== comparisonKey) {
      canCompare = false;
    }
    if (priceBlock === null ||
      shoppingPriceFen(comparable[index]) < shoppingPriceFen(priceBlock)) {
      priceBlock = comparable[index];
    }
  }
  let title = sources.length === 0 ? '暂无国内可比价格' : '来源不足，暂不能形成比价';
  let isLowest = false;
  if (canCompare && priceBlock !== null) {
    title = rowValue(priceBlock, ['comparisonPriceKind']) === 'estimated' ?
      '当前最低预估到手价' : '当前最低公开价';
    isLowest = true;
  } else if (keys.length > 1) {
    title = '来源规格不同，暂不计算最低价';
    priceBlock = null;
  } else if (comparable.length === 0) {
    title = '当前可见公开价';
    for (let index = 0; index < sources.length; index++) {
      if (rowValue(sources[index], ['预估到手价', '价格']).length > 0) {
        priceBlock = sources[index];
        break;
      }
    }
  }
  const price = priceBlock === null ? '' : rowValue(priceBlock, ['预估到手价', '价格']);
  const priceKind = priceBlock !== null &&
    rowValue(priceBlock, ['comparisonPriceKind']) === 'estimated' ? '预估到手价' : '';
  const sourceLabel = canCompare ? comparable.length.toString() + ' 个同款公开来源' :
    totalSourceCount.toString() + ' 个公开来源';
  return '<header class="firecrawl-shopping-hero' + (isLowest ? ' is-lowest' : '') +
    '"><span>商品比价</span><h2>' + escapeHtmlText(title) + '</h2>' +
    (price.length > 0 ? '<strong>' + escapeHtmlText(compactText(price, 48)) + '</strong>' : '') +
    (priceKind.length > 0 ? '<span class="firecrawl-shopping-hero-price-kind">' +
      escapeHtmlText(priceKind) + '</span>' : '') +
    '<p>' + escapeHtmlText(sourceLabel + ' · 价格来自抓取时页面') + '</p></header>';
}

function renderShoppingRow(
  block: HtmlHomeBlock,
  actions: HtmlHomeAction[],
  index: number,
  isLowest: boolean
): string {
  const host = sourceHost(block);
  const platform = shoppingPlatform(block, host);
  const evidenceHost = sourceHostFromUrl(rowValue(block, ['数据页面']));
  const price = rowValue(block, ['预估到手价', '价格']);
  const priceKind = rowValue(block, ['comparisonPriceKind']) === 'estimated' ?
    '预估到手价' : '公开价';
  const specification = rowValue(block, ['规格']);
  const seller = rowValue(block, ['卖家']);
  const coupon = rowValue(block, ['优惠券', '券']);
  const shipping = rowValue(block, ['运费']);
  const fetchedAt = rowValue(block, ['抓取时间']);
  const detailRows: HtmlHomeMetric[] = [
    { label: '卖家', value: seller.length > 0 ? seller : '页面未返回' },
    { label: '规格', value: specification.length > 0 ? specification : '页面未返回' },
    { label: '优惠券', value: coupon.length > 0 ? coupon : '页面未返回' },
    { label: '运费', value: shipping.length > 0 ? shipping : '页面未返回' },
    { label: '抓取时间', value: fetchedAt.length > 0 ? fetchedAt : '页面未返回' }
  ];
  const sourceActions = block.actions.filter((action: HtmlHomeAction): boolean =>
    text(action.id) === 'web.open.source' && text(action.label) === '打开原网页'
  );
  const rowIndex = index.toString();
  const evidence = (seller.length > 0 ? seller + ' · ' : '') + '数据页面：' +
    (evidenceHost.length > 0 ? evidenceHost : host);
  return '<article class="firecrawl-shopping-source-row' + (isLowest ? ' is-lowest' : '') +
    '" data-status="' + escapeAttribute(text(block.status)) + '">' +
    '<div class="firecrawl-shopping-source-top"><div><strong class="firecrawl-shopping-platform">' +
    escapeHtmlText(platform) + '</strong><small class="firecrawl-shopping-evidence">' +
    escapeHtmlText(evidence) + '</small></div><div class="firecrawl-shopping-price"><strong>' +
    escapeHtmlText(price.length > 0 ? compactText(price, 48) : '价格未知') +
    '</strong><span class="firecrawl-shopping-price-kind">' + escapeHtmlText(priceKind) +
    '</span></div></div><strong class="firecrawl-shopping-product">' +
    escapeHtmlText(displayTitle('shopping.research', text(block.status), text(block.title))) +
    '</strong><span class="firecrawl-shopping-spec">' +
    escapeHtmlText(specification.length > 0 ? compactText(specification, 100) : '规格未返回') +
    '</span><button type="button" class="firecrawl-shopping-toggle" data-shopping-detail="' +
    rowIndex + '" aria-expanded="false" aria-controls="shopping-detail-' + rowIndex +
    '">查看详情</button><div id="shopping-detail-' + rowIndex +
    '" class="firecrawl-shopping-detail" hidden><div class="firecrawl-rows">' +
    detailRows.map(renderRow).join('') + '</div>' +
    renderActions(sourceActions, actions) + '</div></article>';
}

function renderSocialSections(cards: HtmlHomeBlock[]): string {
  const sources = cards.filter((block: HtmlHomeBlock): boolean => sourceHost(block).length > 0);
  const platform = cards.find((block: HtmlHomeBlock): boolean =>
    rowValue(block, ['平台域名']) === 'xiaohongshu.com'
  );
  const terminal = cards.find((block: HtmlHomeBlock): boolean =>
    text(block.status) === 'error' || text(block.status) === 'needs_auth'
  );
  const state = platform === undefined ? (terminal === undefined ? '' : text(terminal.status)) : text(platform.status);
  const note = '以下内容来自小红书公开笔记；点开卡片可在应用内查看正文和图片。';
  return '<section class="firecrawl-section"><div class="firecrawl-xhs-note">' + note +
    '</div></section><section class="firecrawl-section"><div class="firecrawl-section-head"><h2>精选笔记</h2><span>' +
    sources.length.toString() + ' 条</span></div>' +
    (sources.length > 0 ? '<div class="firecrawl-social-list">' +
      sources.map((block: HtmlHomeBlock, index: number): string =>
        renderSocialCard(block, index, index === 0) + renderSocialDetail(block, index)).join('') +
      '</div>' : '<div class="firecrawl-empty">' + escapeHtmlText(socialEmptyText(state)) + '</div>') +
    '</section>';
}

function renderSocialCard(
  block: HtmlHomeBlock,
  noteIndex: number,
  featured: boolean
): string {
  const status = text(block.status);
  const summary = displaySubtitle('social.public.search', status, text(block.subtitle));
  const host = sourceHost(block);
  const author = rowValue(block, ['作者']);
  const published = rowValue(block, ['发布时间']);
  const mediaType = rowValue(block, ['内容类型']);
  const duration = rowValue(block, ['视频时长']);
  const coverUrl = rowValue(block, ['封面图']);
  const imageUrls = socialImageUrls(block, coverUrl);
  const imageCountText = rowValue(block, ['图片数量']);
  const imageCount = imageCountText.length > 0 ? imageCountText : imageUrls.length.toString();
  const isVideo = mediaType === '视频';
  const meta = [author, published].filter(
    (item: string): boolean => item.length > 0
  ).join(' · ');
  const badge = isVideo ? (duration.length > 0 ? duration : '视频') :
    (imageUrls.length > 1 ? imageCount + ' 图' : '');
  const title = displayTitle('social.public.search', status, text(block.title));
  const carousel = renderSocialCarousel(imageUrls, title, featured);
  return '<article class="firecrawl-social-card' + (featured ? ' is-featured' : '') +
    '" data-status="' + escapeAttribute(status) + '" role="button" tabindex="0" aria-label="应用内查看完整笔记：' +
    escapeAttribute(title) + '" data-firecrawl-note-index="' + noteIndex.toString() +
    '"><div class="firecrawl-social-media' +
    (imageUrls.length === 0 ? ' is-missing' : '') + '">' + carousel +
    (badge.length > 0 ? '<span class="firecrawl-social-media-badge">' +
      escapeHtmlText(badge) + '</span>' : '') +
    (isVideo ? '<span class="firecrawl-social-play" aria-label="视频笔记"></span>' : '') +
    '</div><div class="firecrawl-social-content"><div class="firecrawl-social-top"><span class="firecrawl-source-label">小红书笔记</span>' +
    (status === 'success' || status === 'partial' ? '' : '<span class="firecrawl-social-status">' +
      escapeHtmlText(statusLabel(status)) + '</span>') + '</div><h3>' +
    escapeHtmlText(title) +
    '</h3>' + (featured && summary.length > 0 ? '<p>' + escapeHtmlText(summary) + '</p>' : '') +
    (meta.length > 0 ? '<div class="firecrawl-social-meta"><span class="firecrawl-social-author-dot"></span><span>' +
      escapeHtmlText(meta) + '</span></div>' : '') +
    (host.length > 0 ? '<div class="firecrawl-source-host">来源：' + escapeHtmlText(host) + '</div>' : '') +
    '</div></article>';
}

function renderSocialDetail(block: HtmlHomeBlock, noteIndex: number): string {
  const title = displayTitle('social.public.search', text(block.status), text(block.title));
  const author = rowValue(block, ['作者']);
  const published = rowValue(block, ['发布时间']);
  const body = rowValue(block, ['完整正文']).length > 0 ?
    rowValue(block, ['完整正文']) : text(block.subtitle);
  const mediaType = rowValue(block, ['内容类型']);
  const duration = rowValue(block, ['视频时长']);
  const coverUrl = rowValue(block, ['封面图']);
  const imageUrls = socialImageUrls(block, coverUrl);
  const meta = [author, published, mediaType === '视频' && duration.length > 0 ?
    duration : mediaType].filter((item: string): boolean => item.length > 0).join(' · ');
  return '<section class="firecrawl-social-detail" aria-hidden="true" data-firecrawl-detail-index="' +
    noteIndex.toString() + '"><div class="firecrawl-social-detail-shell"><header class="firecrawl-social-detail-head">' +
    '<strong>笔记详情</strong><button class="firecrawl-social-detail-close" type="button" ' +
    'data-firecrawl-detail-close aria-label="返回笔记列表">返回</button></header>' +
    '<div class="firecrawl-social-detail-media' + (imageUrls.length === 0 ? ' is-missing' : '') + '">' +
    renderSocialCarousel(imageUrls, title, true) +
    (mediaType === '视频' ? '<span class="firecrawl-social-play" aria-label="视频笔记"></span>' : '') +
    '</div><div class="firecrawl-social-detail-body"><h2>' + escapeHtmlText(title) + '</h2>' +
    (meta.length > 0 ? '<div class="firecrawl-social-detail-meta"><span class="firecrawl-social-author-dot"></span><span>' +
      escapeHtmlText(meta) + '</span></div>' : '') +
    (body.length > 0 ? '<p>' + escapeHtmlText(body) + '</p>' :
      '<p>该笔记暂未返回可展示的完整正文。</p>') +
    '</div></div></section>';
}

function renderSocialCarousel(urls: string[], title: string, featured: boolean): string {
  if (urls.length === 0) {
    return '';
  }
  return '<div class="firecrawl-social-carousel" aria-label="笔记图片，可左右滑动">' +
    urls.map((url: string, index: number): string =>
      '<div class="firecrawl-social-slide"><img src="' + escapeAttribute(url) +
      '" alt="' + escapeAttribute(title + ' 第 ' + (index + 1).toString() + ' 张') +
      '" loading="' + (featured && index === 0 ? 'eager' : 'lazy') +
      '" decoding="async" referrerpolicy="no-referrer" onerror="this.parentElement.classList.add(\'is-missing\');this.remove()"></div>'
    ).join('') + '</div>';
}

function socialImageUrls(block: HtmlHomeBlock, coverUrl: string): string[] {
  const raw = rowValue(block, ['图片列表']);
  const candidates = raw.length > 0 ? raw.split('\n') : [];
  const urls: string[] = [];
  if (coverUrl.length > 0) {
    urls.push(coverUrl);
  }
  for (let index = 0; index < candidates.length && urls.length < 12; index++) {
    const value = candidates[index].trim();
    if (value.length > 0 && urls.indexOf(value) < 0) {
      urls.push(value);
    }
  }
  return urls;
}

function socialEmptyText(state: string): string {
  if (state === 'blocked_by_site') {
    return '小红书当前未返回可打开的公开页面；可稍后重试或换更具体的关键词。';
  }
  if (state === 'error') {
    return '暂时无法查询小红书公开内容，请稍后重试。';
  }
  if (state === 'needs_auth') {
    return '小红书登录态已失效，请重新登录 Firecrawl 小红书会话。';
  }
  return '这次没有找到可公开核验的小红书内容，试试更具体的生活场景或商品关键词。';
}

function renderEmptySection(title: string, message: string): string {
  return '<section class="firecrawl-section"><div class="firecrawl-section-head"><h2>' +
    escapeHtmlText(title) + '</h2></div><div class="firecrawl-empty">' +
    escapeHtmlText(message) + '</div></section>';
}

function renderStats(stats: string[][]): string {
  return '<section class="firecrawl-summary" aria-label="Firecrawl 摘要">' +
    stats.map((item: string[]): string => '<div class="firecrawl-stat"><span>' +
      escapeHtmlText(item[0]) + '</span><b>' + escapeHtmlText(item[1]) + '</b></div>').join('') +
    '</section>';
}

function summaryStats(blocks: HtmlHomeBlock[]): string[][] {
  let success = 0;
  let blocked = 0;
  let credits = '';
  for (let index = 0; index < blocks.length; index++) {
    const status = text(blocks[index].status);
    if (status === 'success') {
      success++;
    }
    if (status === 'blocked_by_site' || status === 'needs_auth' || status === 'error') {
      blocked++;
    }
    if (credits.length === 0) {
      credits = rowValue(blocks[index], ['Search Credits', 'Scrape Credits', 'Monitor Credits']);
    }
  }
  const result: string[][] = [['来源', blocks.length.toString()], ['已核验', success.toString()]];
  if (credits.length > 0) {
    result.push(['剩余额度', credits]);
  }
  if (success === 0 && blocked > 0) {
    result[1] = ['状态', '暂不可用'];
  }
  return result;
}

function renderCard(block: HtmlHomeBlock, actions: HtmlHomeAction[], open: boolean, toolId: string): string {
  const status = text(block.status);
  const actionHtml = renderActions(block.actions, actions);
  const rows = rowsForDisplay(block, toolId);
  const label = cardKind(toolId, block);
  return '<details class="firecrawl-card" data-status="' + escapeAttribute(status) + '"' +
    (open ? ' open' : '') + '><summary><div class="firecrawl-card-top"><span class="firecrawl-kind">' +
    escapeHtmlText(label) + '</span><span class="firecrawl-status">' +
    escapeHtmlText(statusLabel(status)) + '</span></div><h3>' +
    escapeHtmlText(displayTitle(toolId, status, block.title)) +
    '</h3>' + (text(block.subtitle).length > 0 ? '<p>' +
      escapeHtmlText(displaySubtitle(toolId, status, text(block.subtitle))) + '</p>' : '') +
    '<span class="firecrawl-expand">展开详情</span></summary><div class="firecrawl-card-detail">' +
    (rows.length > 0 ? '<div class="firecrawl-rows">' + rows.map(renderRow).join('') + '</div>' : '') +
    actionHtml + '</div></details>';
}

function renderRow(row: HtmlHomeMetric): string {
  return '<div class="firecrawl-row"><b>' + escapeHtmlText(row.label) + '</b><span>' +
    escapeHtmlText(row.value) + '</span></div>';
}

function renderActions(
  blockActions: HtmlHomeAction[],
  actions: HtmlHomeAction[],
  labelOverride: string = ''
): string {
  if (blockActions.length === 0) {
    return '';
  }
  const buttons: string[] = [];
  for (let index = 0; index < blockActions.length; index++) {
    const actionIndex = actions.indexOf(blockActions[index]);
    if (actionIndex < 0) {
      continue;
    }
    const variant = text(blockActions[index].variant);
    const className = variant === 'danger' ? ' danger' : (variant === 'primary' ? ' primary' : '');
    buttons.push('<button type="button" class="firecrawl-action' + className +
      '" data-firecrawl-action-index="' + actionIndex.toString() + '">' +
      escapeHtmlText(labelOverride.length > 0 ? labelOverride : blockActions[index].label) +
      '</button>');
  }
  return buttons.length > 0 ? '<div class="firecrawl-actions">' + buttons.join('') + '</div>' : '';
}

function sourceHost(block: HtmlHomeBlock): string {
  return sourceHostFromUrl(rowValue(block, ['URL', 'Page URL', '页面 1']));
}

function sourceHostFromUrl(url: string): string {
  const schemeEnd = url.indexOf('://');
  if (schemeEnd < 0) {
    return '';
  }
  const pathStart = url.indexOf('/', schemeEnd + 3);
  return (pathStart < 0 ? url.substring(schemeEnd + 3) : url.substring(schemeEnd + 3, pathStart))
    .replace(/^www\./, '');
}

function shoppingPlatform(block: HtmlHomeBlock, host: string): string {
  const platform = rowValue(block, ['平台']);
  if (platform.length > 0) {
    return platform;
  }
  if (host === 'jd.com' || host.endsWith('.jd.com')) {
    return '京东';
  }
  if (host === 'tmall.com' || host.endsWith('.tmall.com')) {
    return '天猫';
  }
  if (host === 'taobao.com' || host.endsWith('.taobao.com')) {
    return '淘宝';
  }
  if (host === 'zol.com.cn' || host.endsWith('.zol.com.cn')) {
    return '中关村在线';
  }
  if (host === 'pconline.com.cn' || host.endsWith('.pconline.com.cn')) {
    return '太平洋电脑网';
  }
  if (host === 'idealo.de' || host.endsWith('.idealo.de')) {
    return 'Idealo';
  }
  if (host === 'amazon.com' || host.endsWith('.amazon.com')) {
    return 'Amazon';
  }
  if (host === 'bestbuy.com' || host.endsWith('.bestbuy.com')) {
    return 'Best Buy';
  }
  if (host === 'bhphotovideo.com' || host.endsWith('.bhphotovideo.com')) {
    return 'B&H';
  }
  return host;
}

function rowsForDisplay(block: HtmlHomeBlock, toolId: string): HtmlHomeMetric[] {
  if (toolId === 'web.research.search' && isOverview(block)) {
    return [];
  }
  const visible: HtmlHomeMetric[] = [];
  const rows = block.metrics.concat(block.rows);
  for (let index = 0; index < rows.length; index++) {
    const label = text(rows[index].label).trim();
    const lower = label.toLowerCase();
    if (isTechnicalRow(lower) || text(rows[index].value).trim().length === 0) {
      continue;
    }
    visible.push({
      label: friendlyRowLabel(label),
      value: compactRowValue(label, text(rows[index].value))
    });
  }
  return visible.slice(0, 6);
}

function isTechnicalRow(lower: string): boolean {
  return isShoppingComparisonRow(lower) ||
    lower === 'source' || lower === 'toolname' || lower.indexOf('provider') >= 0 ||
    lower.indexOf('credit') >= 0 || lower.indexOf('search id') >= 0 ||
    lower.indexOf('scrape id') >= 0 || lower.indexOf('mcp') >= 0 ||
    lower.indexOf('request id') >= 0 || lower === 'status' || lower === 'error';
}

function isShoppingComparisonRow(lower: string): boolean {
  return lower === 'comparisoneligible' || lower === 'comparisonpricefen' ||
    lower === 'comparisonpricekind' || lower === 'comparisonkey';
}

function shoppingHomeDataBlocks(blocks: HtmlHomeBlock[]): HtmlHomeBlock[] {
  return blocks.map((block: HtmlHomeBlock): HtmlHomeBlock => ({
    id: block.id,
    kind: block.kind,
    title: block.title,
    subtitle: block.subtitle,
    status: block.status,
    source: block.source,
    credentialName: block.credentialName,
    credentialRef: block.credentialRef,
    toolId: block.toolId,
    prompt: block.prompt,
    metrics: block.metrics.filter((row: HtmlHomeMetric): boolean =>
      !isShoppingComparisonRow(text(row.label).trim().toLowerCase())
    ),
    rows: block.rows.filter((row: HtmlHomeMetric): boolean =>
      !isShoppingComparisonRow(text(row.label).trim().toLowerCase())
    ),
    actions: block.actions,
    rawPreview: block.rawPreview,
    mediaEmbed: block.mediaEmbed,
    stripeReceiving: block.stripeReceiving
  }));
}

function friendlyRowLabel(label: string): string {
  const lower = label.toLowerCase();
  if (lower === 'url' || lower === 'page url' || lower === '页面 1') { return '原网页'; }
  if (lower === 'content' || lower === 'markdown' || lower === 'text' ||
    lower === 'description' || lower === 'summary') { return '摘要'; }
  if (lower === 'schedule') { return '频率'; }
  return label;
}

function compactRowValue(label: string, value: string): string {
  const lower = label.toLowerCase();
  const limit = lower === 'content' || lower === 'markdown' || lower === 'text' ||
    lower === 'description' || lower === 'summary' ? 220 : 120;
  return compactText(value, limit);
}

function displaySubtitle(toolId: string, status: string, subtitle: string): string {
  if (status === 'error' && /preflight failed|firecrawl.*failed|provider.*failed/i.test(subtitle)) {
    if (toolId === 'social.public.search') { return '暂时无法获取小红书公开内容，请稍后重试。'; }
    if (toolId === 'web.page.read') { return '暂时无法读取该网页，请稍后重试。'; }
    if (toolId === 'web.monitor.create' || toolId === 'web.monitor.list') {
      return '暂时无法完成监控操作，请稍后重试。';
    }
    return '暂时无法获取公开网页信息，请稍后重试。';
  }
  return compactText(subtitle, 180);
}

function displayTitle(toolId: string, status: string, title: string): string {
  if (status === 'error' && /调用失败|failed|error/i.test(title)) {
    if (toolId === 'social.public.search') { return '暂时无法获取小红书公开内容'; }
    if (toolId === 'web.page.read') { return '暂时无法读取该网页'; }
    if (toolId === 'web.monitor.create' || toolId === 'web.monitor.list') {
      return '暂时无法完成监控操作';
    }
    return '暂时无法获取公开网页信息';
  }
  return compactText(title, 86);
}

function compactText(value: string, limit: number): string {
  const normalized = value.replace(/\s+/g, ' ').trim();
  if (normalized.length <= limit) {
    return normalized;
  }
  return normalized.slice(0, limit) + '…';
}

function cardKind(toolId: string, block: HtmlHomeBlock): string {
  if (toolId === 'web.page.read') {
    return '网页内容';
  }
  if (toolId === 'shopping.research') {
    return '商品';
  }
  if (toolId === 'social.public.search') {
    return rowValue(block, ['平台域名']).length > 0 ? '小红书' : '平台状态';
  }
  if (toolId === 'web.monitor.create' || toolId === 'web.monitor.list') {
    return '监控';
  }
  return isOverview(block) ? '研究摘要' : '公开来源';
}

function statusLabel(status: string): string {
  if (status === 'success') { return '已验证'; }
  if (status === 'partial') { return '部分返回'; }
  if (status === 'confirm_required') { return '等待确认'; }
  if (status === 'blocked_by_site') { return '站点受限'; }
  if (status === 'needs_auth') { return '需要授权'; }
  if (status === 'empty') { return '暂无结果'; }
  if (status === 'calling_tool') { return '查询中'; }
  if (status === 'error') { return '调用失败'; }
  return status.length > 0 ? status : '待确认';
}

function isOverview(block: HtmlHomeBlock): boolean {
  const title = text(block.title);
  return title.indexOf('综述') >= 0 || title.indexOf('摘要') >= 0;
}

function primaryToolId(document: HtmlHomeDocument): string {
  for (let index = 0; index < document.blocks.length; index++) {
    const toolId = toolName(document.blocks[index]);
    if (FIRECRAWL_TOOL_IDS.indexOf(toolId) >= 0) {
      return toolId;
    }
  }
  return 'web.research.search';
}

function toolName(block: HtmlHomeBlock): string {
  if (text(block.toolId).trim().length > 0) {
    return text(block.toolId).trim();
  }
  return rowValue(block, ['toolName']);
}

function rowValue(block: HtmlHomeBlock, labels: string[]): string {
  const rows = block.metrics.concat(block.rows);
  for (let index = 0; index < rows.length; index++) {
    const label = text(rows[index].label).trim().toLowerCase();
    for (let candidate = 0; candidate < labels.length; candidate++) {
      if (label === labels[candidate].toLowerCase()) {
        return text(rows[index].value).trim();
      }
    }
  }
  return '';
}

function collectActions(document: HtmlHomeDocument): HtmlHomeAction[] {
  const actions: HtmlHomeAction[] = [];
  const append = (action: HtmlHomeAction): void => {
    if (actions.indexOf(action) < 0) {
      actions.push(action);
    }
  };
  for (let index = 0; index < document.blocks.length; index++) {
    document.blocks[index].actions.forEach(append);
  }
  document.actions.forEach(append);
  return actions;
}

function text(value: HtmlFirecrawlTextValue): string {
  if (value === undefined || value === null) {
    return '';
  }
  return value.toString();
}

function escapeScriptJson(json: string): string {
  return json
    .split('&').join('\\u0026')
    .split('<').join('\\u003c')
    .split('>').join('\\u003e')
    .split('\u2028').join('\\u2028')
    .split('\u2029').join('\\u2029');
}

function escapeHtmlText(value: HtmlFirecrawlTextValue): string {
  return text(value)
    .split('&').join('&amp;')
    .split('<').join('&lt;')
    .split('>').join('&gt;')
    .split('"').join('&quot;');
}

function escapeAttribute(value: HtmlFirecrawlTextValue): string {
  return escapeHtmlText(value).split("'").join('&#39;');
}
