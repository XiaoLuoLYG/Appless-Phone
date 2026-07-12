import { rideAmapWebKeyForUi } from '@loop/agent-core';
import { HtmlHomeDocument } from './HtmlHomeTypes';
import { personaAvatarDataUri } from './PersonaAvatarDataUri';
import { renderRideDriverMapHtml } from './RideDriverMapHtmlRenderer';

type HtmlRideTextValue = Object | string | number | boolean | null | undefined;

interface HtmlRideHomeDocumentWithBusy extends HtmlHomeDocument {
  isBusy?: boolean;
  personaAvatarDataUri?: string;
  rideMapHtml?: string;
}

const RIDE_HAILING_HOME_CSS: string = `
:root {
  color-scheme: light;
  --paper: #f8f2ea;
  --ink: #211b17;
  --ink-soft: #493f38;
  --muted: #806f61;
  --line: rgba(33, 27, 23, 0.12);
  --panel: rgba(255, 252, 247, 0.86);
  --ride: #b5654d;
  --ride-dark: #7d3e31;
  --ride-soft: rgba(181, 101, 77, 0.13);
  --ride-warm: #d9955f;
  --glass: rgba(255, 249, 239, 0.68);
  --didi: #ff7a00;
  --rail: #16875b;
  --air: #2f79b7;
  --signal: #d8492f;
  --red: #b04a42;
  --red-soft: rgba(176, 74, 66, 0.1);
  --shadow: 0 18px 40px rgba(95, 54, 35, 0.13);
}
* { box-sizing: border-box; }
body {
  margin: 0;
  min-height: 100vh;
  background:
    radial-gradient(circle at 18% 0%, rgba(217, 149, 95, 0.16), transparent 35%),
    radial-gradient(circle at 90% 18%, rgba(181, 101, 77, 0.1), transparent 32%),
    linear-gradient(180deg, #fffaf4 0%, var(--paper) 100%);
  color: var(--ink);
  font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Noto Sans SC", "Helvetica Neue", Arial, sans-serif;
  letter-spacing: 0;
  -webkit-font-smoothing: antialiased;
}
button { font: inherit; cursor: pointer; }
button:disabled { cursor: default; opacity: 0.5; }
.ride-shell {
  width: min(100%, 820px);
  min-height: 100vh;
  margin: 0 auto;
  padding-bottom: calc(96px + env(safe-area-inset-bottom, 0px));
  overflow: hidden;
  background: var(--paper);
}
.ride-hero {
  position: relative;
  overflow: hidden;
  min-height: 384px;
  padding: 14px 14px 18px;
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
  isolation: isolate;
  color: var(--ink);
}
.ride-cover-media {
  position: relative;
  z-index: 1;
  flex: 0 0 auto;
  min-height: 358px;
  margin: 0;
  overflow: hidden;
  border: 0;
  border-radius: 28px;
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
  align-items: flex-start;
  gap: 10px;
  padding: 24px 18px 18px;
  background:
    linear-gradient(135deg, #2f1b10, #b5654d 58%, #f0bc58);
  transform: none;
  box-shadow: none;
}
.ride-cover-media::after {
  content: "";
  position: absolute;
  inset: 0;
  z-index: 1;
  background:
    linear-gradient(180deg, rgba(255, 250, 241, 0.36) 0%, rgba(255, 250, 241, 0.2) 36%, rgba(255, 250, 241, 0.56) 100%),
    radial-gradient(circle at 18% 12%, rgba(231, 245, 252, 0.38), transparent 34%),
    radial-gradient(circle at 72% 76%, rgba(255, 235, 206, 0.34), transparent 42%);
  pointer-events: none;
}
.ride-cover-image {
  display: block;
  position: absolute;
  inset: 0;
  z-index: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.ride-cover-title {
  position: absolute;
  z-index: 2;
  top: 50px;
  left: 18px;
  margin: 0;
  max-width: 7.6em;
  color: var(--ink);
  overflow-wrap: anywhere;
  text-shadow: 0 2px 18px rgba(255, 250, 241, 0.9);
}
.ride-hero::after {
  content: "";
  position: absolute;
  inset: 0;
  z-index: -1;
  background:
    repeating-linear-gradient(90deg, rgba(23, 18, 13, 0.045) 0 1px, transparent 1px 42px),
    repeating-linear-gradient(0deg, rgba(23, 18, 13, 0.035) 0 1px, transparent 1px 38px);
  mask-image: linear-gradient(180deg, rgba(0,0,0,0.74), transparent 70%);
}
.ride-hero > * {
  position: relative;
  z-index: 1;
}
.ride-hero-copy {
  max-width: 100%;
}
.ride-hero-kicker {
  position: absolute;
  top: 12px;
  left: 18px;
  z-index: 2;
  width: fit-content;
  max-width: 100%;
  display: inline-flex;
  align-items: center;
  gap: 7px;
  min-height: 28px;
  border: 1px solid rgba(23, 18, 13, 0.1);
  border-radius: 999px;
  padding: 8px 11px;
  background: rgba(255, 250, 241, 0.86);
  color: var(--ink);
  font-size: 12px;
  font-weight: 820;
  line-height: 1;
  backdrop-filter: blur(18px);
}
.ride-hero-kicker::before {
  content: "";
  width: 13px;
  height: 13px;
  border-radius: 999px;
  background: linear-gradient(135deg, var(--ride), var(--ride-warm));
  box-shadow: inset 0 0 0 3px rgba(255, 250, 241, 0.72);
}
.ride-hero h1 {
  margin: 0;
  max-width: 8.4em;
  overflow-wrap: anywhere;
  font-size: 48px;
  line-height: 0.98;
  font-weight: 900;
}
.ride-stage {
  position: absolute;
  top: 12px;
  right: 12px;
  z-index: 2;
  width: fit-content;
  max-width: calc(100% - 24px);
  border: 1px solid rgba(23, 18, 13, 0.14);
  border-radius: 999px;
  padding: 9px 12px;
  background: rgba(255, 250, 241, 0.62);
  color: var(--ink);
  font-size: 12px;
  font-weight: 860;
  line-height: 1;
  backdrop-filter: blur(18px);
}
.ride-route-map {
  position: relative;
  z-index: 2;
  align-self: stretch;
  margin-top: 8px;
  border: 1px solid var(--line);
  border-radius: 22px;
  padding: 10px;
  background: rgba(255, 250, 241, 0.74);
  box-shadow: var(--shadow);
  backdrop-filter: blur(20px);
}
.ride-route-cities {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto minmax(0, 1fr);
  gap: 10px;
  align-items: center;
}
.ride-route-city {
  position: relative;
  min-width: 0;
  min-height: 84px;
  border-radius: 16px;
  padding: 12px 12px 30px;
  background: rgba(23, 18, 13, 0.035);
}
.ride-route-city b {
  display: block;
  overflow-wrap: anywhere;
  font-size: 18px;
  line-height: 1.1;
}
.ride-route-city span {
  position: absolute;
  left: 12px;
  bottom: 11px;
  display: block;
  margin-top: 0;
  color: var(--muted);
  font-size: 11px;
  line-height: 1.2;
}
.ride-route-mid {
  position: relative;
  width: 78px;
  height: 42px;
}
.ride-route-mid::before {
  content: "";
  position: absolute;
  left: 12px;
  right: 12px;
  top: 23px;
  height: 7px;
  background: linear-gradient(90deg, var(--rail), var(--air), var(--signal));
  clip-path: polygon(0 38%, calc(100% - 8px) 38%, calc(100% - 8px) 0, 100% 50%, calc(100% - 8px) 100%, calc(100% - 8px) 62%, 0 62%);
}
.ride-route-mid::after {
  content: "";
  position: absolute;
  left: 50%;
  top: 12px;
  width: 30px;
  height: 30px;
  border-radius: 50%;
  border: 1px solid transparent;
  background-color: transparent;
  background-image: url("data:image/svg+xml,%3Csvg%20width%3D%2224%22%20height%3D%2224%22%20viewBox%3D%220%200%2024%2024%22%20fill%3D%22none%22%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%3E%3Cpath%20d%3D%22M5%2016H4.5C3.7%2016%203%2015.3%203%2014.5V12.8C3%2012.1%203.5%2011.5%204.2%2011.3L5.9%2010.8L7.5%207.9C7.8%207.3%208.4%207%209%207H15C15.7%207%2016.3%207.4%2016.6%208L18.1%2010.8L19.8%2011.3C20.5%2011.5%2021%2012.1%2021%2012.8V14.5C21%2015.3%2020.3%2016%2019.5%2016H19%22%20stroke%3D%22black%22%20stroke-width%3D%221.5%22%20stroke-linecap%3D%22round%22%20stroke-linejoin%3D%22round%22%2F%3E%3Cpath%20d%3D%22M7%2016H17%22%20stroke%3D%22black%22%20stroke-width%3D%221.5%22%20stroke-linecap%3D%22round%22%2F%3E%3Cpath%20d%3D%22M7.3%2011H16.7%22%20stroke%3D%22black%22%20stroke-width%3D%221.5%22%20stroke-linecap%3D%22round%22%2F%3E%3Ccircle%20cx%3D%226.5%22%20cy%3D%2216%22%20r%3D%221.8%22%20stroke%3D%22black%22%20stroke-width%3D%221.5%22%2F%3E%3Ccircle%20cx%3D%2217.5%22%20cy%3D%2216%22%20r%3D%221.8%22%20stroke%3D%22black%22%20stroke-width%3D%221.5%22%2F%3E%3C%2Fsvg%3E");
  background-repeat: no-repeat;
  background-size: 18px 18px;
  background-position: center;
  box-shadow: none;
  transform: translate(-50%, -50%);
}
.ride-route-stats {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 8px;
  margin-top: 12px;
}
.ride-route-stat {
  min-width: 0;
  border-radius: 14px;
  padding: 9px;
  background: rgba(23, 18, 13, 0.032);
}
.ride-route-stat span {
  display: block;
  color: var(--muted);
  font-size: 10px;
  line-height: 1;
}
.ride-route-stat b {
  display: block;
  margin-top: 6px;
  overflow-wrap: anywhere;
  font-size: 14px;
  line-height: 1.15;
}
.ride-persona {
  position: relative;
  z-index: 2;
  display: flex;
  align-items: center;
  gap: 10px;
  width: fit-content;
  max-width: 100%;
  margin-top: 14px;
  border: 1px solid rgba(23, 18, 13, 0.14);
  border-radius: 18px;
  padding: 10px 12px;
  background: rgba(255, 250, 241, 0.78);
  color: var(--ink);
  backdrop-filter: blur(18px);
}
.ride-cover-media > .ride-persona {
  width: min(100%, 560px);
  margin-top: 0;
  border-color: rgba(23, 18, 13, 0.08);
  border-radius: 22px;
  padding: 14px 16px;
  background: rgba(255, 250, 241, 0.9);
  box-shadow: 0 14px 28px rgba(37, 24, 13, 0.08);
}
.ride-persona-avatar {
  display: grid;
  place-items: center;
  width: 38px;
  height: 38px;
  border-radius: 14px;
  background: var(--ride-soft);
  color: var(--ride-dark);
  font-size: 15px;
  font-weight: 840;
}
.ride-persona-avatar img {
  width: 30px;
  height: 30px;
  object-fit: contain;
}
.ride-persona-title {
  font-size: 14px;
  font-weight: 840;
  line-height: 1.25;
}
.ride-persona-note {
  margin-top: 4px;
  color: var(--muted);
  font-size: 12px;
  line-height: 1.4;
}
.ride-board {
  display: grid;
  gap: 10px;
  padding: 10px 14px 20px;
}
.ride-panel-card {
  position: relative;
  overflow: hidden;
  border: 1px solid var(--line);
  border-radius: 22px;
  padding: 12px;
  background:
    linear-gradient(135deg, rgba(255, 250, 241, 0.98), rgba(255, 247, 231, 0.9)),
    var(--panel);
  box-shadow: 0 12px 30px rgba(37, 24, 13, 0.09);
}
.ride-panel-card::before {
  content: "";
  position: absolute;
  inset: 0 0 auto;
  height: 5px;
  background: linear-gradient(90deg, rgba(181, 101, 77, 0.52), rgba(217, 149, 95, 0.34), rgba(23, 18, 13, 0.04));
}
.ride-panel-card::after {
  content: "";
  position: absolute;
  right: -48px;
  top: -48px;
  width: 132px;
  height: 132px;
  border-radius: 50%;
  border: 1px solid rgba(23, 18, 13, 0.08);
  background: radial-gradient(circle, rgba(23, 18, 13, 0.06), transparent 68%);
  opacity: 0.72;
  pointer-events: none;
}
.ride-status-strip {
  position: relative;
  z-index: 1;
  border: 0;
  border-radius: 0;
  padding: 6px 0 12px;
  background: transparent;
}
.ride-status-strip[data-stage="estimate"] {
  background: transparent;
}
.ride-status-strip[data-stage="cancelled"] {
  background: transparent;
}
.ride-status-strip[data-stage="error"] {
  background: transparent;
}
.ride-status-kicker {
  display: inline-flex;
  align-items: center;
  border: 1px solid var(--ride);
  border-radius: 999px;
  padding: 6px 9px;
  background: rgba(255, 250, 241, 0.9);
  color: var(--ride-dark);
  font-size: 11px;
  font-weight: 860;
  line-height: 1;
}
.ride-status-title {
  margin-top: 11px;
  color: var(--ink);
  font-size: 24px;
  line-height: 1;
  font-weight: 850;
  overflow-wrap: anywhere;
}
.ride-status-note {
  margin-top: 6px;
  color: var(--muted);
  font-size: 13px;
  line-height: 1.42;
  overflow-wrap: anywhere;
}
.ride-route-line {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-top: 14px;
}
.ride-dot {
  flex: 0 0 auto;
  border-radius: 999px;
  padding: 7px 10px;
  background: var(--ride);
  color: #fff;
  font-size: 11px;
  font-weight: 840;
}
.ride-dot.dark { background: var(--ink); }
.ride-track {
  position: relative;
  flex: 1 1 auto;
  height: 36px;
}
.ride-track::before {
  content: "";
  position: absolute;
  left: 0;
  right: 0;
  top: 17px;
  height: 3px;
  border-radius: 999px;
  background: #e4b58c;
}
.ride-driver {
  position: absolute;
  right: 72px;
  top: 6px;
  border-radius: 999px;
  padding: 5px 10px;
  background: #5f6f86;
  color: #fff;
  font-size: 10px;
  font-weight: 840;
}
.ride-estimates {
  position: relative;
  z-index: 1;
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 9px;
  margin-top: 10px;
}
.ride-estimate {
  position: relative;
  min-width: 0;
  border: 1px solid var(--line);
  border-radius: 18px;
  min-height: 124px;
  padding: 10px 10px 11px;
  background: rgba(255, 250, 241, 0.82);
}
.ride-estimate-action {
  appearance: none;
  -webkit-appearance: none;
  width: 100%;
  text-align: left;
  opacity: 0;
  transform: translateY(12px);
  animation: ride-estimate-enter 420ms cubic-bezier(.2, .86, .28, 1) forwards;
  transition: border-color 140ms ease, box-shadow 140ms ease, transform 140ms ease, background 140ms ease;
}
.ride-estimate-enter {}
@keyframes ride-estimate-enter {
  from { opacity: 0; transform: translateY(12px) scale(0.985); }
  to { opacity: 1; transform: translateY(0) scale(1); }
}
.ride-estimate-action:active {
  transform: translateY(0) scale(0.992);
}
.ride-estimate-action:focus-visible {
  outline: 2px solid rgba(181, 101, 77, 0.42);
  outline-offset: 2px;
}
.ride-estimate-action[data-selected="true"] {
  border-color: rgba(181, 101, 77, 0.78);
  background:
    linear-gradient(135deg, rgba(255, 244, 232, 0.98), rgba(255, 250, 241, 0.96)),
    #fff;
  box-shadow: 0 12px 24px rgba(37, 24, 13, 0.12), inset 0 0 0 1px rgba(181, 101, 77, 0.24);
}
.ride-estimate-action[data-selected="true"]::after {
  content: "✓";
  position: absolute;
  right: 9px;
  bottom: 9px;
  display: grid;
  place-items: center;
  width: 22px;
  height: 22px;
  border-radius: 999px;
  background: var(--ride);
  color: #fff;
  font-size: 13px;
  font-weight: 900;
}
.ride-estimate-source {
  position: absolute;
  display: grid;
  place-items: center;
  top: 8px;
  right: 8px;
  border-radius: 999px;
  width: 22px;
  height: 22px;
  background: rgba(255, 122, 0, 0.09);
  box-shadow: inset 0 0 0 1px rgba(255, 122, 0, 0.12);
}
.ride-estimate-source img {
  width: 14px;
  height: 14px;
  display: block;
}
.ride-estimate-art {
  position: absolute;
  left: 10px;
  top: 10px;
  width: 66px;
  height: 38px;
  object-fit: contain;
  opacity: 0.98;
  pointer-events: none;
}
.ride-estimate-name {
  margin-top: 49px;
  max-width: 100%;
  color: var(--ink);
  font-size: 15px;
  font-weight: 820;
  line-height: 1.25;
  overflow-wrap: anywhere;
}
.ride-estimate-price {
  display: inline-flex;
  align-items: baseline;
  margin-top: 5px;
  color: var(--ride-dark);
  line-height: 1;
  font-weight: 900;
}
.ride-estimate-price-currency {
  margin-right: 2px;
  font-size: 13px;
  font-weight: 820;
}
.ride-estimate-price-whole {
  font-size: 28px;
}
.ride-estimate-price-decimal {
  margin-left: 1px;
  font-size: 14px;
  font-weight: 840;
}
.ride-details {
  position: relative;
  z-index: 1;
  margin-top: 11px;
  border-top: 1px solid var(--line);
  padding-top: 11px;
  background: transparent;
}
.ride-detail {
  display: grid;
  grid-template-columns: 78px minmax(0, 1fr);
  gap: 10px;
  border-top: 0;
  padding: 4px 0;
  color: var(--muted);
  font-size: 12px;
  line-height: 1.45;
  overflow-wrap: anywhere;
}
.ride-detail:first-child { border-top: 0; }
.ride-detail span:first-child {
  color: var(--muted);
  font-size: 12px;
}
.ride-detail span:last-child {
  color: var(--ink);
  font-weight: 760;
}
.ride-actions {
  position: relative;
  z-index: 1;
  display: flex;
  flex-wrap: wrap;
  gap: 9px;
  margin-top: 11px;
}
.ride-actions button,
.ride-link-row button {
  appearance: none;
  -webkit-appearance: none;
  border: 0;
}
.ride-action-primary {
  min-height: 42px;
  border-radius: 999px;
  padding: 10px 16px;
  background: linear-gradient(135deg, var(--ride), var(--ride-dark));
  color: #fff;
  font-size: 13px;
  font-weight: 830;
  line-height: 1;
  box-shadow: 0 12px 22px rgba(181, 101, 77, 0.2);
}
.ride-confirm-label {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 4em;
}
.ride-action-secondary,
.ride-action-danger,
.ride-action-link {
  min-height: 42px;
  border-radius: 999px;
  padding: 10px 14px;
  background: rgba(33, 27, 23, 0.06);
  color: var(--ink-soft);
  font-size: 13px;
  font-weight: 780;
  line-height: 1;
}
.ride-action-danger {
  background: var(--red-soft);
  color: var(--red);
}
.ride-link-row {
  position: relative;
  z-index: 1;
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 10px;
}
.ride-action-link {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 7px;
  min-height: 34px;
  padding: 8px 11px;
  background: transparent;
  color: var(--ride-dark);
  border: 1px solid rgba(181, 101, 77, 0.24);
  box-shadow: none;
}
.ride-action-logo {
  display: block;
  width: 18px;
  height: 18px;
  border-radius: 5px;
  object-fit: cover;
}
.ride-empty {
  border: 1px dashed rgba(23, 18, 13, 0.18);
  border-radius: 20px;
  padding: 18px;
  background: var(--panel);
  color: var(--muted);
  font-size: 13px;
  line-height: 1.5;
}
.ride-map-frame {
  display: block;
  width: 100%;
  height: 224px;
  border: 1px solid rgba(181, 101, 77, 0.18);
  border-radius: 22px;
  background: #f5e9dd;
  box-shadow: 0 14px 30px rgba(95, 54, 35, 0.12);
}
.ride-map-panel {
  position: relative;
  margin-top: 14px;
}
.ride-map-head {
  position: absolute;
  top: 10px;
  right: 10px;
  z-index: 3;
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 8px;
  pointer-events: none;
}
.ride-map-head > * {
  pointer-events: auto;
}
.ride-map-eta {
  display: none;
  min-height: 28px;
  align-items: center;
  border: 1px solid rgba(255, 255, 255, 0.58);
  border-radius: 999px;
  padding: 7px 10px;
  background: rgba(255, 250, 241, 0.9);
  color: var(--ride-dark);
  box-shadow: 0 10px 20px rgba(95, 54, 35, 0.12);
  font-size: 12px;
  font-weight: 840;
  line-height: 1;
  backdrop-filter: blur(10px);
}
.ride-map-control {
  appearance: none;
  -webkit-appearance: none;
  border: 1px solid rgba(255, 255, 255, 0.58);
  border-radius: 999px;
  padding: 7px 10px;
  background: rgba(125, 62, 49, 0.88);
  color: #fff;
  box-shadow: 0 10px 20px rgba(95, 54, 35, 0.18);
  font-size: 12px;
  font-weight: 840;
  line-height: 1;
  backdrop-filter: blur(10px);
  touch-action: manipulation;
}
body.ride-map-fullscreen {
  overflow: hidden;
}
body.ride-map-fullscreen .ride-map-panel[data-fullscreen="true"] {
  position: fixed;
  inset: 0;
  z-index: 2147483000;
  display: flex;
  flex-direction: column;
  margin: 0;
  padding: calc(12px + env(safe-area-inset-top, 0px)) 12px calc(12px + env(safe-area-inset-bottom, 0px));
  background: var(--paper);
}
body.ride-map-fullscreen .ride-panel-card > :not(.ride-status-strip) {
  display: none !important;
}
body.ride-map-fullscreen .ride-status-strip > :not(.ride-map-panel) {
  display: none !important;
}
body.ride-map-fullscreen .ride-map-panel[data-fullscreen="true"] > .ride-map-head {
  position: static;
  display: flex;
  align-self: stretch;
  justify-content: space-between;
  flex: 0 0 auto;
  margin: 0 0 8px;
  z-index: 2147483647;
  pointer-events: auto;
}
body.ride-map-fullscreen .ride-map-panel[data-fullscreen="true"] .ride-map-eta {
  display: inline-flex;
}
body.ride-map-fullscreen .ride-map-panel[data-fullscreen="true"] .ride-map-frame {
  flex: 1 1 auto;
  min-height: 0;
  height: auto;
  border-radius: 24px;
}
@media (max-width: 420px) {
  .ride-hero { min-height: 382px; padding: 12px 12px 16px; }
  .ride-cover-media { min-height: 354px; border-radius: 26px; padding: 22px 14px 16px; }
  .ride-hero h1 { font-size: 40px; }
  .ride-stage { right: 12px; }
  .ride-hero-kicker { top: 12px; left: 14px; }
  .ride-cover-title { top: 50px; left: 14px; }
  .ride-board { padding-left: 12px; padding-right: 12px; }
  .ride-route-cities { grid-template-columns: minmax(0, 1fr) 42px minmax(0, 1fr); gap: 6px; }
  .ride-route-city { min-height: 78px; padding: 10px 10px 28px; }
  .ride-route-city b { font-size: 17px; }
  .ride-route-city span { left: 10px; bottom: 10px; }
  .ride-route-mid { width: 42px; height: 30px; }
  .ride-route-mid::before { left: 5px; right: 5px; top: 18px; }
  .ride-route-stats { grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 6px; }
  .ride-route-stat { padding: 8px 7px; }
  .ride-route-stat b { font-size: 13px; }
  .ride-estimates { grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px; }
  .ride-estimate { min-height: 126px; }
  .ride-estimate-art { width: 58px; height: 34px; }
  .ride-estimate-name { margin-top: 46px; }
  .ride-action-primary,
  .ride-action-secondary,
  .ride-action-danger { flex: 1 1 auto; }
}
@media (min-width: 680px) {
  .ride-hero { min-height: 468px; padding: 24px 28px 24px; }
  .ride-cover-media { min-height: 420px; border-radius: 30px; padding: 34px 28px 24px; }
  .ride-hero h1 { font-size: 58px; }
  .ride-stage { top: 36px; right: 28px; }
  .ride-hero-kicker { top: 36px; left: 28px; }
  .ride-cover-title { top: 78px; left: 28px; }
  .ride-board { padding-left: 22px; padding-right: 22px; grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .ride-panel-card { grid-column: 1 / -1; }
}
@media (prefers-reduced-motion: no-preference) {
  .ride-route-mid::after { animation: travelPulse 2.6s ease-in-out infinite; }
  .ride-panel-card { transition: transform 180ms ease, border-color 180ms ease; }
  .ride-panel-card:active { transform: scale(0.992); }
}
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.001ms !important;
    animation-iteration-count: 1 !important;
    scroll-behavior: auto !important;
    transition-duration: 0.001ms !important;
  }
}
@keyframes travelPulse {
  0%, 100% { opacity: 0.72; }
  50% { opacity: 1; }
}
`;

const RIDE_HAILING_HOME_JS: string = `
(function () {
  var dataNode = document.getElementById('home-data');
  var data = {};
  try { data = JSON.parse(dataNode ? dataNode.textContent || '{}' : '{}'); } catch (error) { data = {}; }
  var isBusy = data.isBusy === true;
  var app = document.getElementById('app');
  function text(value) {
    if (value === undefined || value === null) { return ''; }
    return String(value);
  }
  function list(value) {
    return Array.isArray(value) ? value : [];
  }
  function add(parent, tag, className, content) {
    var node = document.createElement(tag);
    if (className) { node.className = className; }
    if (content !== undefined && content !== null) { node.textContent = text(content); }
    parent.appendChild(node);
    return node;
  }
  function rideAssetUrl(file) {
    return 'resource://rawfile/ride/' + text(file);
  }
  function addRideLogo(parent, file, className) {
    var image = add(parent, 'img', className || '');
    image.src = rideAssetUrl(file);
    image.alt = '';
    image.setAttribute('aria-hidden', 'true');
    return image;
  }
  function metricValue(block, labels) {
    var keys = list(labels).map(function (label) { return text(label).toLowerCase(); });
    var values = list(block && block.metrics).concat(list(block && block.rows));
    for (var index = 0; index < values.length; index++) {
      var item = values[index] || {};
      if (keys.indexOf(text(item.label).toLowerCase()) >= 0) {
        return text(item.value);
      }
    }
    return '';
  }
  function postAction(action) {
    var payload = {
      id: text(action && action.id),
      label: text(action && (action.label || action.id)),
      prompt: text(action && action.prompt),
      variant: text(action && action.variant),
      kind: text(action && action.kind),
      sourceComponentId: text(action && action.sourceComponentId),
      args: action && action.args && typeof action.args === 'object' ? action.args : null
    };
    if (window.AIPhoneHome && typeof window.AIPhoneHome.postAction === 'function') {
      window.AIPhoneHome.postAction(JSON.stringify(payload));
    }
  }
  function rideBlock() {
    var blocks = list(data.blocks);
    for (var index = 0; index < blocks.length; index++) {
      if (text(blocks[index] && blocks[index].kind) === 'ride-tool-panel') {
        return blocks[index];
      }
    }
    return null;
  }
  function rideEstimates(block) {
    return list(block && block.rows).filter(function (row) {
      return text(row && row.label).indexOf('estimate|') === 0;
    }).map(function (row) {
      var parts = text(row && row.label).split('|');
      return {
        category: parts.length > 1 ? parts[1] : '',
        name: parts.length > 2 ? parts.slice(2).join('|') : '',
        price: text(row && row.value)
      };
    }).filter(function (item) {
      return item.name.length > 0 || item.price.length > 0;
    });
  }
  function ridePrice(value) {
    return text(value).replace(/^¥\\s*/, '').replace(/元$/, '');
  }
  function formatRidePriceParts(value) {
    var raw = ridePrice(value).trim();
    var amount = Number(raw);
    if (Number.isFinite(amount)) {
      var fixed = amount.toFixed(2);
      var split = fixed.split('.');
      return { whole: split[0], decimal: '.' + split[1] };
    }
    var match = raw.match(/^(.*?)(\\.\\d+)$/);
    if (match) {
      return { whole: match[1], decimal: match[2] };
    }
    return { whole: raw, decimal: '' };
  }
  function renderRidePrice(parent, value) {
    var parts = formatRidePriceParts(value);
    var price = add(parent, 'div', 'ride-estimate-price');
    add(price, 'span', 'ride-estimate-price-currency', '¥');
    add(price, 'span', 'ride-estimate-price-whole', parts.whole || '0');
    if (parts.decimal.length > 0) {
      add(price, 'span', 'ride-estimate-price-decimal', parts.decimal);
    }
  }
  function rideConfirmActions(actions) {
    return list(actions).filter(function (action) {
      return text(action && action.id) === 'ride.order.confirm';
    });
  }
  function rideActionForEstimate(actions, item) {
    var confirms = rideConfirmActions(actions);
    if (confirms.length === 0) { return null; }
    var name = text(item && item.name);
    var price = ridePrice(item && item.price);
    var category = text(item && item.category);
    for (var index = 0; index < confirms.length; index++) {
      var action = confirms[index];
      var haystack = (text(action && action.label) + ' ' + text(action && action.prompt)).toLowerCase();
      if (name.length > 0 && haystack.indexOf(name.toLowerCase()) >= 0) {
        return action;
      }
      if (category.length > 0 && haystack.indexOf(category.toLowerCase()) >= 0) {
        return action;
      }
      if (price.length > 0 && haystack.indexOf(price.toLowerCase()) >= 0) {
        return action;
      }
    }
    return confirms[0];
  }
  function rideStageLabel(stage, showDriver) {
    if (stage === 'estimate') { return '待确认'; }
    if (stage === 'order_submitted') { return '等司机'; }
    if (stage === 'driver_location') { return showDriver ? '司机已定位' : '待定位'; }
    if (stage === 'cancelled') { return '已取消'; }
    return '需处理';
  }
  function rideStatusKicker(stage, showDriver) {
    if (stage === 'estimate') { return '极速叫车'; }
    if (stage === 'order_submitted') { return '订单已提交'; }
    if (stage === 'driver_location') { return showDriver ? '司机正在前往' : '位置待查询'; }
    if (stage === 'cancelled') { return '订单已取消'; }
    return '需要处理';
  }
  function rideStatusTitle(stage, routeText, visualLabel, statusText, showDriver) {
    if (stage === 'estimate') { return '选择车型，确认叫车'; }
    if (stage === 'order_submitted') { return '司机位置待查询'; }
    if (stage === 'driver_location') { return showDriver ? '司机位置已返回' : (visualLabel || '司机位置未返回'); }
    if (stage === 'cancelled') { return statusText || '订单已取消'; }
    return statusText || visualLabel || '打车任务需要处理';
  }
  function rideStatusNote(stage, showDriver, routeText) {
    if (stage === 'estimate') { return routeText || '已为你整理可选车型和预估价格。'; }
    if (stage === 'order_submitted') { return '订单已提交，正在刷新司机位置。'; }
    if (stage === 'driver_location') {
      return showDriver ? '' : 'provider 返回坐标前不展示地图或真实路线。';
    }
    if (stage === 'cancelled') { return ''; }
    return '请按 provider 返回结果继续处理。';
  }
  function isRideHandoffAction(action) {
    var id = text(action && action.id);
    return id === 'ride.open.didi' || id === 'ride.open.amap' || (text(action && action.kind) === 'client' && id.indexOf('open') >= 0);
  }
  function isRideDangerAction(action) {
    return text(action && action.id) === 'ride.order.cancel' ||
      text(action && action.variant) === 'danger' ||
      text(action && action.variant) === 'destructive';
  }
  function isRidePrimaryAction(action) {
    var id = text(action && action.id);
    return !isRideHandoffAction(action) && !isRideDangerAction(action) &&
      (id === 'ride.order.confirm' || id === 'ride.driver.location.refresh' || text(action && action.variant) === 'primary');
  }
  function rideActionLogoFile(action) {
    var id = text(action && action.id);
    if (id === 'ride.open.didi') { return 'ride_logo_didi.svg'; }
    if (id === 'ride.open.amap') { return 'ride_logo_amap.jpg'; }
    return '';
  }
  function rideVehicleImage(item) {
    var key = (text(item && item.category) + ' ' + text(item && item.name)).toLowerCase();
    if (key.indexOf('luxury') >= 0 || key.indexOf('豪华') >= 0) { return 'ride_vehicle_luxury.svg'; }
    if (key.indexOf('premium') >= 0 || key.indexOf('专车') >= 0) { return 'ride_vehicle_premium.svg'; }
    if (key.indexOf('discount') >= 0 || key.indexOf('特惠') >= 0) { return 'ride_vehicle_discount.svg'; }
    return 'ride_vehicle_express.svg';
  }
  function rideRouteParts(routeText) {
    var raw = text(routeText);
    var parts = raw.split(/\\s*(?:→|->|到|至)\\s*/).filter(function (part) { return part.trim().length > 0; });
    if (parts.length >= 2) {
      return { from: parts[0].trim(), to: parts[parts.length - 1].trim() };
    }
    return { from: '上车点', to: raw.trim().length > 0 ? raw.trim() : '目的地' };
  }
  function addRideRouteStat(parent, label, value) {
    var stat = add(parent, 'div', 'ride-route-stat');
    add(stat, 'span', '', label);
    add(stat, 'b', '', value);
  }
  function rideVehicleStatText(block, estimates) {
    var selected = metricValue(block, ['selectedVehicleText', '车型', 'vehicle', 'productName', 'productCategory']);
    if (selected.length > 0) { return selected; }
    return estimates.length > 0 ? String(estimates.length) + ' 种' : '待查询';
  }
  function renderRideRouteMap(parent, block) {
    var routeText = metricValue(block, ['routeText']) || text(block && block.subtitle);
    var route = rideRouteParts(routeText);
    var stage = metricValue(block, ['stage']);
    var showDriver = metricValue(block, ['showDriverMarker']) === 'true';
    var estimates = rideEstimates(block);
    var panel = add(parent, 'section', 'ride-route-map');
    var cities = add(panel, 'div', 'ride-route-cities');
    var from = add(cities, 'div', 'ride-route-city');
    add(from, 'b', '', route.from);
    add(from, 'span', '', '出发');
    var mid = add(cities, 'div', 'ride-route-mid');
    var to = add(cities, 'div', 'ride-route-city');
    add(to, 'b', '', route.to);
    add(to, 'span', '', '到达');
    var stats = add(panel, 'div', 'ride-route-stats');
    addRideRouteStat(stats, '状态', rideStageLabel(stage, showDriver));
    addRideRouteStat(stats, '车型', rideVehicleStatText(block, estimates));
    addRideRouteStat(stats, '接驾', showDriver ? '已定位' : '待返回');
  }
  function addRideActionButton(parent, action, className) {
    var button = add(parent, 'button', className);
    button.type = 'button';
    button.disabled = isBusy;
    if (isBusy) { button.setAttribute('aria-disabled', 'true'); }
    var logoFile = rideActionLogoFile(action);
    if (logoFile.length > 0) {
      addRideLogo(button, logoFile, 'ride-action-logo');
    }
    add(button, 'span', '', action.label || action.id);
    button.addEventListener('click', function (event) {
      event.stopPropagation();
      if (isBusy) { return; }
      postAction(action);
    });
  }
  function addRideEstimateConfirmButton(parent, selection, fallbackAction) {
    var row = add(parent, 'div', 'ride-actions');
    var button = add(row, 'button', 'ride-action-primary');
    button.type = 'button';
    button.disabled = isBusy;
    if (isBusy) { button.setAttribute('aria-disabled', 'true'); }
    add(button, 'span', 'ride-confirm-label', '确认叫车');
    button.addEventListener('click', function (event) {
      event.stopPropagation();
      if (isBusy) { return; }
      postAction(selection.action || fallbackAction);
    });
  }
  function addRideActions(parent, actions, selection) {
    var kept = list(actions).filter(function (action) {
      return text(action && (action.label || action.id)).length > 0;
    });
    if (kept.length === 0) { return; }
    var confirmActions = rideConfirmActions(kept);
    var primary = null;
    var secondary = [];
    var links = [];
    kept.forEach(function (action) {
      if (isRideHandoffAction(action)) {
        links.push(action);
      } else if (selection !== null && text(action && action.id) === 'ride.order.confirm') {
        return;
      } else if (primary === null && isRidePrimaryAction(action)) {
        primary = action;
      } else if (isRideDangerAction(action) || secondary.length < 1) {
        secondary.push(action);
      }
    });
    if (selection !== null && confirmActions.length > 0) {
      addRideEstimateConfirmButton(parent, selection, confirmActions[0]);
    } else
    if (primary !== null || secondary.length > 0) {
      var row = add(parent, 'div', 'ride-actions');
      if (primary !== null) { addRideActionButton(row, primary, 'ride-action-primary'); }
      secondary.forEach(function (action) {
        addRideActionButton(row, action, isRideDangerAction(action) ? 'ride-action-danger' : 'ride-action-secondary');
      });
    }
    if (links.length > 0) {
      var linkRow = add(parent, 'div', 'ride-link-row');
      links.forEach(function (action) {
        addRideActionButton(linkRow, action, 'ride-action-link');
      });
    }
  }
  function renderRideEstimates(parent, block, estimates) {
    if (estimates.length === 0) { return null; }
    var selection = { action: null };
    var buttons = [];
    var grid = add(parent, 'div', 'ride-estimates');
    function setSelectedEstimate(selectedIndex) {
      buttons.forEach(function (button, index) {
        var selected = index === selectedIndex;
        button.setAttribute('data-selected', selected ? 'true' : 'false');
        button.setAttribute('aria-pressed', selected ? 'true' : 'false');
      });
      selection.action = rideActionForEstimate(block.actions, estimates[selectedIndex]) || rideConfirmActions(block.actions)[0] || null;
    }
    estimates.forEach(function (item, index) {
      var estimate = add(grid, 'button', 'ride-estimate ride-estimate-action ride-estimate-enter');
      estimate.type = 'button';
      estimate.disabled = isBusy;
      if (isBusy) { estimate.setAttribute('aria-disabled', 'true'); }
      estimate.setAttribute('data-selected', 'false');
      estimate.setAttribute('aria-pressed', 'false');
      estimate.style.animationDelay = String(Math.min(index, 5) * 54) + 'ms';
      var source = add(estimate, 'div', 'ride-estimate-source');
      addRideLogo(source, 'ride_logo_didi.svg', '');
      var vehicle = addRideLogo(estimate, rideVehicleImage(item), 'ride-estimate-art');
      vehicle.alt = text(item.name || item.category || '车型') + '示例图';
      vehicle.removeAttribute('aria-hidden');
      add(estimate, 'div', 'ride-estimate-name', item.name || item.category || '车型');
      renderRidePrice(estimate, item.price);
      estimate.addEventListener('click', function (event) {
        event.stopPropagation();
        if (isBusy) { return; }
        setSelectedEstimate(index);
      });
      buttons.push(estimate);
    });
    setSelectedEstimate(0);
    return selection;
  }
  function addRideDetail(parent, label, value) {
    if (text(value).length === 0) { return; }
    var row = add(parent, 'div', 'ride-detail');
    add(row, 'span', '', label);
    add(row, 'span', '', text(value));
    return row;
  }
  function updateRideEtaText(value) {
    var etaText = text(value);
    if (etaText.length === 0) { return; }
    document.body.setAttribute('data-ride-eta', etaText);
    var etaNodes = document.querySelectorAll('[data-ride-eta-value], [data-ride-map-eta-value]');
    etaNodes.forEach(function (etaNode) {
      etaNode.textContent = etaText;
    });
  }
  function logRideMapRoute(payload) {
    var stage = text(payload && payload.stage);
    var detail = payload && payload.detail && typeof payload.detail === 'object' ? payload.detail : {};
    try {
      if (window.console && typeof window.console.log === 'function') {
        window.console.log('[AIPhone][RideMapRoute] ' + stage, detail);
      }
    } catch (error) {
    }
    postAction({
      id: 'ride.map.route.log',
      label: 'Ride map route log',
      prompt: '[AIPhone][RideMapRoute] ' + stage,
      kind: 'debug',
      args: {
        stage: stage,
        detail: detail
      }
    });
  }
  function setRideMapFullscreen(panel, enabled) {
    if (!panel) { return; }
    panel.setAttribute('data-fullscreen', enabled ? 'true' : 'false');
    document.body.classList.toggle('ride-map-fullscreen', enabled);
    var button = panel.querySelector('.ride-map-control');
    if (button) {
      button.textContent = enabled ? '退出全屏' : '全屏地图';
      button.setAttribute('aria-label', enabled ? '退出全屏地图' : '全屏查看地图');
    }
  }
  window.__rideMapSetFullscreen = function (enabled) {
    var activePanel = document.querySelector('.ride-map-panel[data-fullscreen="true"]') || document.querySelector('.ride-map-panel');
    setRideMapFullscreen(activePanel, enabled === true);
  };
  function renderRideMap(parent, routeText, driverEtaText) {
    var panel = add(parent, 'div', 'ride-map-panel');
    panel.setAttribute('data-fullscreen', 'false');
    var head = add(panel, 'div', 'ride-map-head');
    var etaBadge = add(head, 'div', 'ride-map-eta', driverEtaText || '路径规划中');
    etaBadge.setAttribute('data-ride-map-eta-value', 'true');
    var button = add(head, 'button', 'ride-map-control', '全屏地图');
    var lastMapControlActivateAt = 0;
    function handleMapControlActivate(event) {
      if (event && event.preventDefault) { event.preventDefault(); }
      if (event && event.stopPropagation) { event.stopPropagation(); }
      var now = Date.now();
      if (now - lastMapControlActivateAt < 450) { return; }
      lastMapControlActivateAt = now;
      setRideMapFullscreen(panel, panel.getAttribute('data-fullscreen') !== 'true');
    }
    button.type = 'button';
    button.setAttribute('aria-label', '全屏查看地图');
    button.addEventListener('click', handleMapControlActivate);
    button.addEventListener('pointerup', handleMapControlActivate);
    button.addEventListener('touchend', handleMapControlActivate, { passive: false });
    var frame = add(panel, 'iframe', 'ride-map-frame');
    frame.setAttribute('title', '司机位置地图');
    frame.setAttribute('loading', 'lazy');
    frame.setAttribute('referrerpolicy', 'origin-when-cross-origin');
    frame.srcdoc = text(data.rideMapHtml);
  }
  window.addEventListener('message', function (event) {
    var payload = event.data || {};
    if (payload.type === 'rideMapEta') {
      var etaText = text(payload.etaText);
      updateRideEtaText(etaText);
    } else if (payload.type === 'rideMapRouteLog') {
      logRideMapRoute(payload);
    }
  });
  function renderPersona(parent) {
    var persona = data.persona || {};
    var memory = data.personaMemory || {};
    var name = text(persona.name);
    if (text(persona.id).length === 0 || name.length === 0) { return; }
    var banner = add(parent, 'section', 'ride-persona');
    var avatar = add(banner, 'div', 'ride-persona-avatar');
    var avatarSrc = text(data.personaAvatarDataUri);
    if (avatarSrc.length > 0) {
      var img = add(avatar, 'img');
      img.src = avatarSrc;
      img.alt = '';
      img.setAttribute('aria-hidden', 'true');
    } else {
      avatar.textContent = name.slice(0, 1);
    }
    var copy = add(banner, 'div');
    add(copy, 'div', 'ride-persona-title', name + '上线');
    add(copy, 'div', 'ride-persona-note', text(memory.summary) || text(persona.reason));
  }
  function renderRideCard(parent, block) {
    var stage = metricValue(block, ['stage']);
    var routeText = metricValue(block, ['routeText']);
    var visualLabel = metricValue(block, ['visualLabel']);
    var driverEtaText = metricValue(block, ['driverEtaText', '预计接驾时间', 'etaText']);
    var showDriver = metricValue(block, ['showDriverMarker']) === 'true';
    var card = add(parent, 'article', 'ride-panel-card');
    var status = add(card, 'div', 'ride-status-strip');
    status.setAttribute('data-stage', stage || 'unknown');
    add(status, 'div', 'ride-status-kicker', rideStatusKicker(stage, showDriver));
    add(status, 'div', 'ride-status-title', rideStatusTitle(stage, routeText, visualLabel, metricValue(block, ['statusText']), showDriver));
    var statusNote = rideStatusNote(stage, showDriver, routeText);
    if (text(statusNote).length > 0) {
      add(status, 'div', 'ride-status-note', statusNote);
    }
    if (showDriver) {
      if (text(data.rideMapHtml).length > 0) {
        renderRideMap(status, routeText, driverEtaText);
      } else {
        var route = add(status, 'div', 'ride-route-line');
        add(route, 'span', 'ride-dot', '乘客');
        var track = add(route, 'div', 'ride-track');
        add(track, 'span', 'ride-driver', '司机');
        add(route, 'span', 'ride-dot dark', '目的地');
      }
    }
    var estimates = rideEstimates(block);
    var estimateSelection = renderRideEstimates(card, block, estimates);
    var details = add(card, 'div', 'ride-details');
    addRideDetail(details, '订单号', metricValue(block, ['orderId']));
    addRideDetail(details, '状态', metricValue(block, ['statusText']));
    addRideDetail(details, '司机', metricValue(block, ['driverName']));
    var etaRow = addRideDetail(details, '预计接驾时间', driverEtaText);
    if (!etaRow && showDriver) {
      etaRow = addRideDetail(details, '预计接驾时间', '正在估算');
    }
    if (etaRow) {
      var etaValueNode = etaRow.querySelector('span:last-child');
      if (etaValueNode) {
        etaValueNode.setAttribute('data-ride-eta-value', 'true');
      }
    }
    if (details.children.length === 0) { details.remove(); }
    addRideActions(card, block.actions, estimateSelection);
  }
  app.textContent = '';
  var shell = add(app, 'main', 'ride-shell');
  shell.setAttribute('data-ride-home', 'true');
  var block = rideBlock();
  var hero = add(shell, 'header', 'ride-hero');
  var cover = add(hero, 'div', 'ride-cover-media');
  var coverImage = add(cover, 'img', 'ride-cover-image');
  coverImage.src = rideAssetUrl('ride_cover_taxi_v2.png');
  coverImage.alt = '';
  coverImage.setAttribute('aria-hidden', 'true');
  add(cover, 'div', 'ride-hero-kicker', '打车方案 · 实时叫车');
  add(cover, 'h1', 'ride-cover-title', block ? (text(block.title) || '打车') : '打车');
  add(cover, 'div', 'ride-stage', block ? rideStageLabel(metricValue(block, ['stage']), metricValue(block, ['showDriverMarker']) === 'true') : '待处理');
  if (block) { renderRideRouteMap(cover, block); }
  var board = add(shell, 'section', 'ride-board');
  if (block) {
    renderRideCard(board, block);
  } else {
    add(board, 'div', 'ride-empty', '暂无打车任务结果。');
  }
})();
`;

export function shouldRenderRideHailingHomeDocument(document: HtmlHomeDocument): boolean {
  const blocks = document.blocks;
  for (let index = 0; index < blocks.length; index++) {
    if (blocks[index].kind === 'ride-tool-panel') {
      return true;
    }
  }
  return false;
}

export function renderRideHailingHomeDocument(document: HtmlHomeDocument, isBusy: boolean = false): string {
  const renderDocument: HtmlRideHomeDocumentWithBusy = {
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
    personaAvatarDataUri: personaAvatarDataUri(document.persona.avatarKey),
    rawSurfaceRoot: null,
    generatedAt: '',
    isBusy: isBusy || (document as HtmlRideHomeDocumentWithBusy).isBusy === true,
    rideMapHtml: rideMapHtmlForDocument(document)
  };
  const json = escapeScriptJson(JSON.stringify(renderDocument));
  const title = escapeHtmlText(document.title.length > 0 ? document.title : '打车');
  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${title}</title>
<style>${RIDE_HAILING_HOME_CSS}</style>
</head>
<body>
<div id="app"></div>
<script id="home-data" type="application/json">${json}</script>
<script>${RIDE_HAILING_HOME_JS}</script>
</body>
</html>`;
}

function rideMetricValue(document: HtmlHomeDocument, labels: string[]): string {
  const lowerLabels = labels.map((label: string) => label.toLowerCase());
  for (let blockIndex = 0; blockIndex < document.blocks.length; blockIndex++) {
    const block = document.blocks[blockIndex];
    if (block.kind !== 'ride-tool-panel') {
      continue;
    }
    const values = block.metrics.concat(block.rows);
    for (let index = 0; index < values.length; index++) {
      if (lowerLabels.indexOf(values[index].label.toLowerCase()) >= 0) {
        return values[index].value;
      }
    }
  }
  return '';
}

function rideMapHtmlForDocument(document: HtmlHomeDocument): string {
  if (rideMetricValue(document, ['stage']) !== 'driver_location' ||
    rideMetricValue(document, ['showDriverMarker']) !== 'true') {
    return '';
  }
  const pickupLocation = rideMetricValue(document, ['pickupLocation', '起点坐标']);
  const driverLocation = rideMetricValue(document, ['driverLocation', '司机位置']);
  if (pickupLocation.length === 0 || driverLocation.length === 0) {
    return '';
  }
  return renderRideDriverMapHtml({
    routeText: rideMetricValue(document, ['routeText']),
    pickupLocation: pickupLocation,
    driverLocation: driverLocation,
    driverName: rideMetricValue(document, ['driverName', '司机']),
    etaText: rideMetricValue(document, ['driverEtaText', '预计接驾时间', 'visualLabel']),
    amapKey: rideAmapWebKeyForUi(),
    amapSecurityJsCode: ''
  });
}

function escapeScriptJson(json: string): string {
  return json
    .split('&').join('\\u0026')
    .split('<').join('\\u003c')
    .split('>').join('\\u003e')
    .split('\u2028').join('\\u2028')
    .split('\u2029').join('\\u2029');
}

function escapeHtmlText(value: HtmlRideTextValue): string {
  if (value === undefined || value === null) {
    return '';
  }
  return value.toString()
    .split('&').join('&amp;')
    .split('<').join('&lt;')
    .split('>').join('&gt;')
    .split('"').join('&quot;');
}
