<p align="center">
  <img src="docs/assets/readme/appless-phone-banner.png" alt="Appless Phone banner" />
</p>

<h1 align="center">Appless Phone</h1>

<p align="center">
  <strong>Mobile Codex for the apps you no longer have to open.</strong>
</p>

<p align="center">
  Tell Appless Phone what you want. It builds a task-specific mobile interface in real time, pulls the work across the apps behind it, and finishes multi-app jobs in one place instead of making you switch screens. Each request gets the interface it needs, not the interface a single app shipped with.
</p>

<p align="center">
  <a href="#-what-it-does">What it does</a> ·
  <a href="#-product-snapshots">Snapshots</a> ·
  <a href="#-connected-apps">Connected apps</a> ·
  <a href="#-demo-gallery">Demos</a> ·
  <a href="#-run-locally">Run locally</a>
</p>

## ✨ What it does

Appless Phone is built around the AI phone idea: the agent is the entry point, and apps become tools behind the task.

Ordering coffee, checking mail, planning a trip, searching videos, updating a calendar, or looking through SaaS tools should not mean jumping across a dozen apps. Appless Phone gives those jobs one mobile surface. It gathers real provider results, shows the source, and lets you review the final action.

Current capabilities include:

- Travel search across high-speed rail and flights.
- Nearby food and place search, with Google Maps when explicitly requested.
- Gmail, QQ Mail, and Outlook inbox aggregation, thread views, and draft creation.
- Google Calendar search and event creation with confirmation.
- YouTube and Bilibili video search in one media view.
- PayPal, Stripe, and Google Pay payment flows with review-first handoff.
- SocialHub reading across X, Slack, WeCom, and connected social apps.
- Composio-backed search for GitHub, Google Drive, Google Docs, Notion, Linear, Asana, Trello, HubSpot, Salesforce, and more.
- Personal memory updates, such as local preferences for coffee, food, or routine choices.

## 📱 Product snapshots

<table>
  <tr>
    <td align="center" width="25%"><img src="docs/assets/screenshots/current/travel-search.jpg" alt="Travel search" /><br><sub>Travel planning</sub></td>
    <td align="center" width="25%"><img src="docs/assets/screenshots/current/food-coffee.jpg" alt="Nearby coffee search" /><br><sub>Local food search</sub></td>
    <td align="center" width="25%"><img src="docs/assets/screenshots/current/mail-aggregate.jpg" alt="Mail aggregation" /><br><sub>Mail aggregation</sub></td>
    <td align="center" width="25%"><img src="docs/assets/screenshots/current/media-qwen.jpg" alt="Media search" /><br><sub>Media search</sub></td>
  </tr>
</table>

<table>
  <tr>
    <td align="center" width="25%"><img src="docs/assets/screenshots/current/calendar-month.jpg" alt="Calendar month view" /><br><sub>Calendar</sub></td>
    <td align="center" width="25%"><img src="docs/assets/screenshots/current/payment-send.jpg" alt="Payment confirmation" /><br><sub>Payments</sub></td>
    <td align="center" width="25%"><img src="docs/assets/screenshots/current/google-maps.jpg" alt="Google Maps place search" /><br><sub>Maps</sub></td>
    <td align="center" width="25%"><img src="docs/assets/screenshots/current/composio-github.jpg" alt="Composio GitHub result" /><br><sub>Composio tools</sub></td>
  </tr>
</table>

## 🔌 Connected apps

The app surface is designed around real providers and recognizable app entry points. The full capability table lives in [docs/current-capabilities.md](docs/current-capabilities.md).

<table>
  <tr>
    <td align="center"><img src="docs/assets/app-icons/gmail.svg" width="34" alt="Gmail" /><br><sub>Gmail</sub></td>
    <td align="center"><img src="docs/assets/app-icons/qqmail.png" width="34" alt="QQ Mail" /><br><sub>QQ Mail</sub></td>
    <td align="center"><img src="docs/assets/app-icons/outlook.svg" width="34" alt="Outlook" /><br><sub>Outlook</sub></td>
    <td align="center"><img src="docs/assets/app-icons/google-calendar.svg" width="34" alt="Google Calendar" /><br><sub>Calendar</sub></td>
    <td align="center"><img src="docs/assets/app-icons/google-maps.svg" width="34" alt="Google Maps" /><br><sub>Maps</sub></td>
    <td align="center"><img src="docs/assets/app-icons/youtube.svg" width="34" alt="YouTube" /><br><sub>YouTube</sub></td>
    <td align="center"><img src="docs/assets/app-icons/bilibili.svg" width="34" alt="Bilibili" /><br><sub>Bilibili</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/assets/app-icons/github.svg" width="34" alt="GitHub" /><br><sub>GitHub</sub></td>
    <td align="center"><img src="docs/assets/app-icons/google-drive.svg" width="34" alt="Google Drive" /><br><sub>Drive</sub></td>
    <td align="center"><img src="docs/assets/app-icons/google-docs.svg" width="34" alt="Google Docs" /><br><sub>Docs</sub></td>
    <td align="center"><img src="docs/assets/app-icons/slack.svg" width="34" alt="Slack" /><br><sub>Slack</sub></td>
    <td align="center"><img src="docs/assets/app-icons/wecom.svg" width="34" alt="WeCom" /><br><sub>WeCom</sub></td>
    <td align="center"><img src="docs/assets/app-icons/x.svg" width="34" alt="X" /><br><sub>X</sub></td>
    <td align="center"><img src="docs/assets/app-icons/notion.svg" width="34" alt="Notion" /><br><sub>Notion</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/assets/app-icons/linear.svg" width="34" alt="Linear" /><br><sub>Linear</sub></td>
    <td align="center"><img src="docs/assets/app-icons/asana.svg" width="34" alt="Asana" /><br><sub>Asana</sub></td>
    <td align="center"><img src="docs/assets/app-icons/trello.svg" width="34" alt="Trello" /><br><sub>Trello</sub></td>
    <td align="center"><img src="docs/assets/app-icons/hubspot.svg" width="34" alt="HubSpot" /><br><sub>HubSpot</sub></td>
    <td align="center"><img src="docs/assets/app-icons/salesforce.svg" width="34" alt="Salesforce" /><br><sub>Salesforce</sub></td>
    <td align="center"><img src="docs/assets/app-icons/discord.svg" width="34" alt="Discord" /><br><sub>Discord</sub></td>
    <td align="center"><img src="docs/assets/app-icons/linkedin.svg" width="34" alt="LinkedIn" /><br><sub>LinkedIn</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/assets/app-icons/whatsapp.svg" width="34" alt="WhatsApp" /><br><sub>WhatsApp</sub></td>
    <td align="center"><img src="docs/assets/app-icons/instagram.svg" width="34" alt="Instagram" /><br><sub>Instagram</sub></td>
    <td align="center"><img src="docs/assets/app-icons/spotify.svg" width="34" alt="Spotify" /><br><sub>Spotify</sub></td>
    <td align="center"><img src="docs/assets/app-icons/tiktok.svg" width="34" alt="TikTok" /><br><sub>TikTok</sub></td>
    <td align="center"><img src="docs/assets/app-icons/ticketmaster.svg" width="34" alt="Ticketmaster" /><br><sub>Ticketmaster</sub></td>
    <td align="center"><img src="docs/assets/app-icons/paypal.svg" width="34" alt="PayPal" /><br><sub>PayPal</sub></td>
    <td align="center"><img src="docs/assets/app-icons/stripe.svg" width="34" alt="Stripe" /><br><sub>Stripe</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/assets/app-icons/google-pay.svg" width="34" alt="Google Pay" /><br><sub>Google Pay</sub></td>
    <td align="center"><img src="docs/assets/app-icons/amap.jpg" width="34" alt="Amap" /><br><sub>Amap</sub></td>
    <td align="center"><img src="docs/assets/app-icons/baidu-maps.jpg" width="34" alt="Baidu Maps" /><br><sub>Baidu Maps</sub></td>
    <td align="center"><img src="docs/assets/app-icons/tencent-maps.jpg" width="34" alt="Tencent Maps" /><br><sub>Tencent Maps</sub></td>
    <td align="center"><img src="docs/assets/app-icons/meituan.jpg" width="34" alt="Meituan" /><br><sub>Meituan</sub></td>
    <td align="center"><img src="docs/assets/app-icons/taobao.jpg" width="34" alt="Taobao" /><br><sub>Taobao</sub></td>
    <td align="center"><img src="docs/assets/app-icons/luckin.jpg" width="34" alt="Luckin Coffee" /><br><sub>Luckin</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/assets/app-icons/mcdonalds.jpg" width="34" alt="McDonald's" /><br><sub>McDonald's</sub></td>
    <td align="center"><img src="docs/assets/app-icons/kfc.jpg" width="34" alt="KFC" /><br><sub>KFC</sub></td>
  </tr>
</table>

## 🎬 Demo gallery

Videos are embedded as muted autoplay loops with controls. The Chinese text is the exact query used in the demo, followed by a short English translation.

### Travel and local life

<table>
  <tr>
    <td align="center" width="33%"><video src="docs/assets/demos/latest/travel-beijing-shanghai.mp4" poster="docs/assets/demos/posters/travel-beijing-shanghai.jpg" autoplay muted loop playsinline controls width="100%" aria-label="Travel demo"></video><br><sub><code>我明天要从北京去上海，帮我搜索合适的出行方式</code><br>Find suitable travel options from Beijing to Shanghai tomorrow</sub></td>
    <td align="center" width="33%"><video src="docs/assets/demos/latest/food-coffee-huawei.mp4" poster="docs/assets/demos/posters/food-coffee-huawei.jpg" autoplay muted loop playsinline controls width="100%" aria-label="Coffee search demo"></video><br><sub><code>帮我查深圳坂田华为基地附近的咖啡店</code><br>Find coffee near Huawei Base in Bantian, Shenzhen</sub></td>
    <td align="center" width="33%"><video src="docs/assets/demos/latest/google-maps-kings-cross.mp4" poster="docs/assets/demos/posters/google-maps-kings-cross.jpg" autoplay muted loop playsinline controls width="100%" aria-label="Google Maps demo"></video><br><sub><code>帮我用 Google Maps 搜索伦敦国王十字车站附近的中餐</code><br>Search Google Maps for Chinese food near King's Cross</sub></td>
  </tr>
</table>

### Mail and calendar

<table>
  <tr>
    <td align="center" width="25%"><video src="docs/assets/demos/latest/mail-important-aggregate.mp4" poster="docs/assets/demos/posters/mail-important-aggregate.jpg" autoplay muted loop playsinline controls width="100%" aria-label="Mail aggregation demo"></video><br><sub><code>帮我查看邮箱里最新的重要邮件</code><br>Show the latest important emails across my inboxes</sub></td>
    <td align="center" width="25%"><video src="docs/assets/demos/latest/gmail-eccv-paper.mp4" poster="docs/assets/demos/posters/gmail-eccv-paper.jpg" autoplay muted loop playsinline controls width="100%" aria-label="Gmail ECCV demo"></video><br><sub><code>帮我查看我Gmail里和我eccv论文相关的邮件</code><br>Find Gmail messages related to my ECCV paper</sub></td>
    <td align="center" width="25%"><video src="docs/assets/demos/latest/gmail-web.mp4" poster="docs/assets/demos/posters/gmail-web.jpg" autoplay muted loop playsinline controls width="100%" aria-label="Gmail web demo"></video><br><sub><code>帮我打开 Gmail 网页版</code><br>Open Gmail on the web</sub></td>
    <td align="center" width="25%"><video src="docs/assets/demos/latest/calendar-month.mp4" poster="docs/assets/demos/posters/calendar-month.jpg" autoplay muted loop playsinline controls width="100%" aria-label="Calendar month demo"></video><br><sub><code>帮我查看我本月的calendar日程</code><br>Show this month's Google Calendar events</sub></td>
  </tr>
  <tr>
    <td align="center" width="25%"><video src="docs/assets/demos/latest/calendar-create-aiphonedemo.mp4" poster="docs/assets/demos/posters/calendar-create-aiphonedemo.jpg" autoplay muted loop playsinline controls width="100%" aria-label="Calendar create demo"></video><br><sub><code>帮我在 2026年7月30日下午3点创建一个title为AIPhoneDemo的30分钟日程</code><br>Create a 30-minute AIPhoneDemo event on July 30, 2026 at 3 PM</sub></td>
  </tr>
</table>

### Media, memory, and payments

<table>
  <tr>
    <td align="center" width="25%"><video src="docs/assets/demos/latest/media-qwen-official.mp4" poster="docs/assets/demos/posters/media-qwen-official.jpg" autoplay muted loop playsinline controls width="100%" aria-label="Qwen media search demo"></video><br><sub><code>帮我在b站和youtube里搜索qwen的官方视频</code><br>Search Bilibili and YouTube for official Qwen videos</sub></td>
    <td align="center" width="25%"><video src="docs/assets/demos/latest/youtube-world-cup.mp4" poster="docs/assets/demos/posters/youtube-world-cup.jpg" autoplay muted loop playsinline controls width="100%" aria-label="YouTube World Cup demo"></video><br><sub><code>帮我在 YouTube 里搜索世界杯相关视频</code><br>Search YouTube for World Cup videos</sub></td>
    <td align="center" width="25%"><video src="docs/assets/demos/latest/memory-luckin.mp4" poster="docs/assets/demos/posters/memory-luckin.jpg" autoplay muted loop playsinline controls width="100%" aria-label="Memory update demo"></video><br><sub><code>我只喝瑞幸咖啡</code><br>Remember that I only drink Luckin Coffee</sub></td>
    <td align="center" width="25%"><video src="docs/assets/demos/latest/payment-paypal-send.mp4" poster="docs/assets/demos/posters/payment-paypal-send.jpg" autoplay muted loop playsinline controls width="100%" aria-label="PayPal payment demo"></video><br><sub><code>用 PayPal 给罗一格转 1 美元</code><br>Send Luo Yige 1 USD with PayPal</sub></td>
  </tr>
  <tr>
    <td align="center" width="25%"><video src="docs/assets/demos/latest/stripe-receiving-account.mp4" poster="docs/assets/demos/posters/stripe-receiving-account.jpg" autoplay muted loop playsinline controls width="100%" aria-label="Stripe receiving account demo"></video><br><sub><code>帮我创建我的stripe收款账户</code><br>Create my Stripe receiving account</sub></td>
    <td align="center" width="25%"><video src="docs/assets/demos/latest/payment-google-pay-send.mp4" poster="docs/assets/demos/posters/payment-google-pay-send.jpg" autoplay muted loop playsinline controls width="100%" aria-label="Google Pay payment demo"></video><br><sub><code>用 Google Pay 给罗一格转账 5 美元</code><br>Send Luo Yige 5 USD with Google Pay</sub></td>
  </tr>
</table>

### Composio tools

<table>
  <tr>
    <td align="center" width="25%"><video src="docs/assets/demos/latest/composio-github-prs.mp4" poster="docs/assets/demos/posters/composio-github-prs.jpg" autoplay muted loop playsinline controls width="100%" aria-label="Composio GitHub demo"></video><br><sub><code>帮我在 GitHub 里找 Appless-Phone 最近的 pr</code><br>Find recent Appless-Phone pull requests in GitHub</sub></td>
    <td align="center" width="25%"><video src="docs/assets/demos/latest/composio-google-docs.mp4" poster="docs/assets/demos/posters/composio-google-docs.jpg" autoplay muted loop playsinline controls width="100%" aria-label="Composio Google Docs demo"></video><br><sub><code>帮我在 Google Docs 里找 AIPhoneDemo 设计文档</code><br>Find the AIPhoneDemo design doc in Google Docs</sub></td>
    <td align="center" width="25%"><video src="docs/assets/demos/latest/composio-google-drive.mp4" poster="docs/assets/demos/posters/composio-google-drive.jpg" autoplay muted loop playsinline controls width="100%" aria-label="Composio Google Drive demo"></video><br><sub><code>帮我在 Google Drive 里找专利申请交底书</code><br>Find a patent disclosure file in Google Drive</sub></td>
    <td align="center" width="25%"><video src="docs/assets/demos/latest/composio-connections.mp4" poster="docs/assets/demos/posters/composio-connections.jpg" autoplay muted loop playsinline controls width="100%" aria-label="Composio connection management demo"></video><br><sub><code>打开 Composio 授权配置</code><br>Review Composio app connections and OAuth status</sub></td>
  </tr>
</table>

## 🚀 Run locally

1. Open this repository in DevEco Studio.
2. Run the `entry` module on a HarmonyOS device or emulator.
3. Type a request in the bottom input.

For the full list of provider requirements, smoke queries, and network notes, read [docs/current-capabilities.md](docs/current-capabilities.md).

## 📄 License

No license has been selected yet. Treat the code and assets as all rights reserved until a license is added.
