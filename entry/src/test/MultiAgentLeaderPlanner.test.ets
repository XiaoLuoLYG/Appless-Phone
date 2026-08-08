import { describe, expect, it } from '@ohos/hypium';
import {
  AgentMessage,
  AgentMessageType,
  ConversationContext,
  InputUserPayload,
  LeaderDataTaskInputNormalizer,
  LeaderDecision,
  LeaderDecisionDataTask,
  LeaderPlanningContext,
  LocalModel,
  ObservationDigest,
  ToolDefinition,
  actionAgentToolDefinitions
} from '@loop/agent-core';
import { MultiAgentLeaderPlanner } from '../main/ets/pages/A2uiHome/agent/MultiAgentLeaderPlanner';

const PARALLEL_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["flight.search","train.search"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[' +
  '{"localId":"flight","goal":"查航班","allowedToolIds":["flight.search"],"toolId":"flight.search","input":{},"required":false},' +
  '{"localId":"train","goal":"查高铁","allowedToolIds":["train.search"],"toolId":"train.search","input":{},"required":false}' +
  '],"uiIntent":{"purpose":"比较出行方案","preferredDensity":"comfortable","requiredSections":["flight","train"]},' +
  '"reasonCode":"parallel_reads"}';
const TRAVEL_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["travel.search"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"travel","goal":"我明天要从北京去上海，帮我搜索出行方案",' +
  '"allowedToolIds":["travel.search"],"toolId":"travel.search",' +
  '"input":{"origin":"北京","destination":"上海","date":"明天",' +
  '"query":"我明天要从北京去上海，帮我搜索出行方案"},"required":true}],' +
  '"uiIntent":{"purpose":"展示综合出行方案","preferredDensity":"comfortable",' +
  '"requiredSections":["travel"]},"reasonCode":"travel_search"}';
const FLIGHT_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["flight.search"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"flight","goal":"帮我查明天北京到上海的航班",' +
  '"allowedToolIds":["flight.search"],"toolId":"flight.search",' +
  '"input":{"origin":"北京","destination":"上海","date":"明天"},"required":true}],' +
  '"uiIntent":{"purpose":"展示航班","preferredDensity":"comfortable",' +
  '"requiredSections":["flight"]},"reasonCode":"flight_search"}';
const TRAIN_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["train.search"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"train","goal":"帮我查询明天晚上六点以后深圳北到香港西九龙的高铁",' +
  '"allowedToolIds":["train.search"],"toolId":"train.search",' +
  '"input":{"origin":"深圳北","destination":"香港西九龙","date":"明天",' +
  '"departureAfter":"18:00"},"required":true}],' +
  '"uiIntent":{"purpose":"展示高铁","preferredDensity":"comfortable",' +
  '"requiredSections":["train"]},"reasonCode":"train_search"}';
const OVERLAPPING_VIDEO_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["media.video.search","youtube.video.search"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"task1","goal":"搜索 B 站上的 Qwen 官方视频",' +
  '"allowedToolIds":["media.video.search"],"toolId":"media.video.search",' +
  '"input":{"query":"Qwen 官方视频","platform":"B站"},"required":true},' +
  '{"localId":"task2","goal":"搜索 YouTube 上的 Qwen 官方视频",' +
  '"allowedToolIds":["youtube.video.search"],"toolId":"youtube.video.search",' +
  '"input":{"query":"Qwen 官方视频"},"required":true}],' +
  '"uiIntent":{"purpose":"search","preferredDensity":"medium","requiredSections":["results"]}}';
const AGGREGATE_VIDEO_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["media.video.search"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"videos","goal":"搜索 B 站和 YouTube 上的 Qwen 官方视频",' +
  '"allowedToolIds":["media.video.search"],"toolId":"media.video.search",' +
  '"input":{"query":"Qwen 官方视频","sources":["youtube","bilibili"]},"required":true}],' +
  '"uiIntent":{"purpose":"展示多源视频","preferredDensity":"comfortable",' +
  '"requiredSections":["video"]}}';
const YOUTUBE_ONLY_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["youtube.video.search"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"youtube","goal":"搜索 YouTube 视频",' +
  '"allowedToolIds":["youtube.video.search"],"toolId":"youtube.video.search",' +
  '"input":{"query":"世界杯"},"required":true}],' +
  '"uiIntent":{"purpose":"展示 YouTube 视频","preferredDensity":"comfortable",' +
  '"requiredSections":["video"]}}';
const BILIBILI_ONLY_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["media.video.search"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"bilibili","goal":"搜索 B 站视频",' +
  '"allowedToolIds":["media.video.search"],"toolId":"media.video.search",' +
  '"input":{"query":"Qwen","sources":["bilibili"]},"required":true}],' +
  '"uiIntent":{"purpose":"展示 B 站视频","preferredDensity":"comfortable",' +
  '"requiredSections":["video"]}}';
const SOCIAL_ONLY_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["social.feed.search"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"social","goal":"查看 X 和 Slack 消息",' +
  '"allowedToolIds":["social.feed.search"],"toolId":"social.feed.search",' +
  '"input":{"platforms":["x","slack"]},"required":true}],' +
  '"uiIntent":{"purpose":"展示 SocialHub 消息","preferredDensity":"comfortable",' +
  '"requiredSections":["social"]}}';
const SOCIAL_WITH_DATE_DECISION: string = SOCIAL_ONLY_DECISION.replace(
  '"input":{"platforms":["x","slack"]}',
  '"input":{"platforms":["x","slack"],"date":"2026-07-23"}'
);
const SOCIAL_MAIL_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["social.feed.search","mail.search"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"social","goal":"查看 X 和 Slack 消息",' +
  '"allowedToolIds":["social.feed.search"],"toolId":"social.feed.search",' +
  '"input":{"platforms":["x","slack"]},"required":true},' +
  '{"localId":"mail","goal":"查看邮件","allowedToolIds":["mail.search"],' +
  '"toolId":"mail.search","input":{"providers":["gmail","qq","outlook"],"query":"","pageSize":10},' +
  '"required":true}],"uiIntent":{"purpose":"展示消息和邮件","preferredDensity":"comfortable",' +
  '"requiredSections":["social","mail"]}}';
const X_POST_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["x.post.search"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"x-posts","goal":"查看 OpenAI 最近的公开 post",' +
  '"allowedToolIds":["x.post.search"],"toolId":"x.post.search",' +
  '"input":{"query":"OpenAI"},"required":true}],"uiIntent":{' +
  '"purpose":"展示 X 公开 post","preferredDensity":"comfortable",' +
  '"requiredSections":["posts"]}}';
const FOOD_COFFEE_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["food.search"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"coffee","goal":"点一杯咖啡",' +
  '"allowedToolIds":["food.search"],"toolId":"food.search",' +
  '"input":{"query":"咖啡"},"required":true}],"uiIntent":{' +
  '"purpose":"展示咖啡选择","preferredDensity":"comfortable",' +
  '"requiredSections":["food"]}}';
const MIXED_DATA_ACTION_QUERY: string =
  '我现在要打车从深圳华为坂田基地到秋港花园，帮我点一杯瑞幸生椰拿铁，半糖少冰，转账给罗一格5美金';
const MIXED_DATA_ACTION_DECISION: string =
  '{"personaId":"travel_companion","skillId":"","requestedCapabilityIds":[' +
  '"ride.estimate","luckin.order.preview","payment.send"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"ride","goal":"查询从深圳华为坂田基地到秋港花园的打车估价",' +
  '"allowedToolIds":["ride.estimate"],"toolId":"ride.estimate",' +
  '"input":{"origin":"深圳华为坂田基地","destination":"秋港花园"},' +
  '"required":true}],"uiIntent":{"purpose":"展示打车估价、瑞幸预览和转账确认",' +
  '"preferredDensity":"comfortable","requiredSections":["ride","luckin","payment"]},' +
  '"actionIntent":{"goal":"预览瑞幸订单，然后打开转账确认",' +
  '"allowedActionIds":["luckin.order.preview","payment.send"]},' +
  '"reasonCode":"mixed_data_action"}';
const MIXED_MISPLACED_ACTION_DECISION: string = MIXED_DATA_ACTION_DECISION
  .replace(
    '"dataTasks":[{"localId":"ride"',
    '"dataTasks":[{"localId":"luckin","goal":"预览瑞幸订单",' +
      '"allowedToolIds":["luckin.order.preview"],"toolId":"luckin.order.preview",' +
      '"input":{"prompt":"帮我点一杯瑞幸生椰拿铁，半糖少冰"},"required":true},' +
      '{"localId":"ride"'
  )
  .replace(
    '"allowedActionIds":["luckin.order.preview","payment.send"]',
    '"allowedActionIds":["payment.send"]'
  );
const MIXED_SEQUENCE_WITH_FUTURE_CAPABILITIES_DECISION: string =
  MIXED_DATA_ACTION_DECISION
    .replace('"continuationMode":"complete"', '"continuationMode":"sequence"')
    .replace(
      ',"actionIntent":{"goal":"预览瑞幸订单，然后打开转账确认",' +
        '"allowedActionIds":["luckin.order.preview","payment.send"]}',
      ''
    );
const MIXED_SEQUENCE_WITH_OMITTED_ACTION_INTENT_DECISION: string =
  MIXED_MISPLACED_ACTION_DECISION
    .replace('"continuationMode":"complete"', '"continuationMode":"sequence"')
    .replace(
      ',"actionIntent":{"goal":"预览瑞幸订单，然后打开转账确认",' +
        '"allowedActionIds":["payment.send"]}',
      ''
    );
const MULTI_DATA_SEQUENCE_WITH_FUTURE_CAPABILITIES_DECISION: string =
  MIXED_SEQUENCE_WITH_FUTURE_CAPABILITIES_DECISION.replace(
    '"required":true}],"uiIntent"',
    '"required":true},{"localId":"travel","goal":"搜索深圳到秋港花园的出行方案",' +
      '"allowedToolIds":["travel.search"],"toolId":"travel.search",' +
      '"input":{"origin":"深圳华为坂田基地","destination":"秋港花园","date":"今天"},' +
      '"required":true}],"uiIntent"'
  );
const EXPLICIT_GOOGLE_MAPS_AS_FOOD_DECISION: string =
  '{"personaId":"travel_companion","skillId":"","requestedCapabilityIds":["food.search"],' +
  '"roundAction":"execute","continuationMode":"complete","dataTasks":[{"localId":"places","goal":"在 Google Maps 搜索附近中餐",' +
  '"allowedToolIds":["food.search"],"toolId":"food.search",' +
  '"input":{"query":"伦敦国王十字车站附近的中餐"},"required":true}],' +
  '"uiIntent":{"purpose":"展示 Google Maps 地点","preferredDensity":"comfortable",' +
  '"requiredSections":["places"]}}';
const EXPLICIT_GOOGLE_MAPS_DECISION: string =
  '{"personaId":"travel_companion","skillId":"","requestedCapabilityIds":["maps.place.search"],' +
  '"roundAction":"execute","continuationMode":"complete","dataTasks":[{"localId":"places","goal":"在 Google Maps 搜索附近中餐",' +
  '"allowedToolIds":["maps.place.search"],"toolId":"maps.place.search",' +
  '"input":{"query":"伦敦国王十字车站附近的中餐"},"required":true}],' +
  '"uiIntent":{"purpose":"展示 Google Maps 地点","preferredDensity":"comfortable",' +
  '"requiredSections":["places"]}}';
const PLANNING_INCOMPLETE_GOOGLE_MAPS_DECISION: string = EXPLICIT_GOOGLE_MAPS_DECISION.replace(
  '"roundAction":"execute","continuationMode":"complete",',
  '"roundAction":"execute","continuationMode":"dependency",'
);
const DEVICE_C04_FOOD_DECISION: string =
  '{"personaId":"food_companion","skillId":"","requestedCapabilityIds":["food.search"],' +
  '"roundAction":"execute","continuationMode":"complete","dataTasks":[{"localId":"search_chinese_restaurant_near_kings_cross",' +
  '"goal":"搜索伦敦国王十字车站附近的中餐","allowedToolIds":["food.search"],"toolId":"food.search",' +
  '"input":{"query":"中餐 伦敦国王十字车站附近","location":"伦敦国王十字车站",' +
  '"radius":5000,"language":"zh"},"required":true}],"uiIntent":{"purpose":"search",' +
  '"preferredDensity":"compact","requiredSections":["results"]}}';
const DEVICE_C04_MAPS_REPAIR: string =
  '{"personaId":"default_companion","skillId":"","requestedCapabilityIds":["maps.place.search"],' +
  '"roundAction":"execute","continuationMode":"complete","dataTasks":[{"localId":"search_chinese_restaurant_near_kings_cross",' +
  '"goal":"搜索伦敦国王十字车站附近的中餐","allowedToolIds":["maps.place.search"],' +
  '"toolId":"maps.place.search","input":{"query":"中餐 伦敦国王十字车站附近",' +
  '"location":"伦敦国王十字车站"},"required":true}],"uiIntent":{"purpose":"search",' +
  '"preferredDensity":"compact","requiredSections":["results"]}}}';
const PREMATURE_GOOGLE_MAPS_DETAILS_DECISION: string = EXPLICIT_GOOGLE_MAPS_DECISION.replace(
  '["maps.place.search"]',
  '["maps.place.search","maps.place.details"]'
);
const ANSWER_FROM_TRAVEL_OBSERVATION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["travel.search"],"roundAction":"answer","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"总结真实出行结果","preferredDensity":"comfortable",' +
  '"requiredSections":["travel"]},"answer":"根据上一轮真实结果继续回答。"}';
const MODEL_OWNED_TERMINAL_REPAIR: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["travel.search"],"roundAction":"answer","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"模型选择的真实出行总结","preferredDensity":"compact",' +
  '"requiredSections":["travel","next-step"]},"answer":"根据上一轮真实出行结果回答。"}';
const MODEL_OWNED_UNBOUND_REPAIR: string = MODEL_OWNED_TERMINAL_REPAIR
  .replace('"travel.search"', '"food.search"')
  .replace('模型选择的真实出行总结', '模型选择的真实地点总结')
  .replace('"travel","next-step"', '"place","next-step"');
const SPARSE_TERMINAL_REPAIR: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["travel.search"],"roundAction":"answer","continuationMode":"complete",' +
  '"answer":"根据上一轮真实出行结果回答。"}';
const REPEATED_TRAVEL_PRIVATE_DECISION: string = TRAVEL_DECISION.replace(
  '"goal":"我明天要从北京去上海，帮我搜索出行方案"',
  '"goal":"FIRST_MODEL_PRIVATE_MARKER"'
);
const MAP_DETAILS_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["maps.place.details"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"place-details","goal":"读取上一轮真实地点的详情",' +
  '"allowedToolIds":["maps.place.details"],"toolId":"maps.place.details",' +
  '"input":{"placeId":"place-real-1"},"required":true}],' +
  '"uiIntent":{"purpose":"展示地点详情","preferredDensity":"comfortable",' +
  '"requiredSections":["place"]}}';
const UNBOUND_FOOD_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["food.search"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"food","goal":"查询附近餐厅",' +
  '"allowedToolIds":["food.search"],"toolId":"food.search",' +
  '"input":{"query":"附近餐厅"},"required":true}],' +
  '"uiIntent":{"purpose":"展示餐厅","preferredDensity":"comfortable",' +
  '"requiredSections":["food"]}}';
const MAIL_READ_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["mail.thread.read"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"mail-read","goal":"读取真实邮件正文",' +
  '"allowedToolIds":["mail.thread.read"],"toolId":"mail.thread.read",' +
  '"input":{"provider":"gmail","requestKey":"gmail:thread-real-1",' +
  '"threadId":"thread-real-1","messageId":"message-real-1"},"required":true}],' +
  '"uiIntent":{"purpose":"展示邮件正文","preferredDensity":"comfortable",' +
  '"requiredSections":["mail"]}}';
const GMAIL_READ_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["gmail.thread.read"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"gmail-read","goal":"读取真实 Gmail 正文",' +
  '"allowedToolIds":["gmail.thread.read"],"toolId":"gmail.thread.read",' +
  '"input":{"requestKey":"gmail:thread-real-1","threadId":"thread-real-1",' +
  '"messageId":"message-real-1"},"required":true}],' +
  '"uiIntent":{"purpose":"展示 Gmail 正文","preferredDensity":"comfortable",' +
  '"requiredSections":["mail"]}}';
const EXACT_MULTI_TOOL_ACTION_DECISION: string = PARALLEL_DECISION
  .replace(
    '"requestedCapabilityIds":["flight.search","train.search"]',
    '"requestedCapabilityIds":["flight.search","train.search","memory.update"]'
  )
  .replace(
    '"allowedToolIds":["flight.search"]',
    '"allowedToolIds":["flight.search","train.search"]'
  )
  .replace(
    ',"reasonCode":"parallel_reads"}',
    ',"actionIntent":{"goal":"remember selection","allowedActionIds":["memory.update"]},' +
      '"reasonCode":"parallel_reads"}'
  );
const HOTEL_WITH_EXTRA_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["hotel.search","memory.update"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"hotel","goal":"查酒店","allowedToolIds":["hotel.search"],' +
  '"toolId":"hotel.search","input":{},"required":true}],' +
  '"uiIntent":{"purpose":"展示酒店","preferredDensity":"comfortable",' +
  '"requiredSections":["hotel"]},"reasonCode":"hotel_search"}';
const ANSWER_WITHOUT_ANSWER_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":[],"roundAction":"answer","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"reply","preferredDensity":"comfortable","requiredSections":[]},' +
  '"reasonCode":"greeting"}';
const LIVE_ANSWER_WITHOUT_REASON_CODE: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":[],"roundAction":"answer","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"reply","preferredDensity":"comfortable","requiredSections":[]},' +
  '"answer":"LIVE_PRIVATE_MARKER"}';
const VALID_ANSWER_DECISION: string = LIVE_ANSWER_WITHOUT_REASON_CODE.substring(
  0,
  LIVE_ANSWER_WITHOUT_REASON_CODE.length - 1
) + ',"reasonCode":"greeting"}';
const BIM_STATE_ONLY_TOOL_DECISION: string =
  '{"personaId":"travel_companion","skillId":"","requestedCapabilityIds":["hotel.search"],' +
  '"roundAction":"execute","continuationMode":"complete","dataTasks":[{"localId":"hotel",' +
  '"goal":"更新东京旅行酒店要求","allowedToolIds":["hotel.search"],"toolId":"hotel.search",' +
  '"input":{},"required":true}],"uiIntent":{"purpose":"更新东京旅行","preferredDensity":"comfortable",' +
  '"requiredSections":["hotel"]}}';
const BIM_STATE_ONLY_ANSWER: string =
  '{"personaId":"travel_companion","skillId":"","requestedCapabilityIds":[],' +
  '"roundAction":"answer","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"更新东京旅行","preferredDensity":"comfortable",' +
  '"requiredSections":["overview"]},"answer":"已把人数更新为四人，并记录两间双床房。",' +
  '"bimContextUpdate":{"summary":"东京四人旅行，酒店需要两间双床房",' +
  '"facts":["出行人数为四人"],"constraints":["酒店需要两间双床房"],"decisions":[],' +
  '"entities":["东京","四人"],"timeAnchors":[],"locations":["东京"],' +
  '"commitments":["预订两间双床房"],"keywords":["东京","旅行","四人","双床房"]}}';
const BIM_CREATION_ANSWER: string =
  '{"personaId":"travel_companion","skillId":"","requestedCapabilityIds":[],' +
  '"roundAction":"answer","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"记录长期事项","preferredDensity":"comfortable",' +
  '"requiredSections":["overview"]},"answer":"已记下这件长期事项。",' +
  '"bimSuggestion":{"title":"南京婚宴","summary":"跟进南京婚宴宾客安排",' +
  '"reason":"有日期、参与人和后续确认进度","keywords":["南京","婚宴","宾客"]},' +
  '"bimContextUpdate":{"summary":"2027年2月14日南京婚宴，持续跟进宾客确认",' +
  '"facts":["当前小王和李阿姨参加"],"constraints":["总人数50人","每桌10人"],' +
  '"decisions":[],"entities":["小王","李阿姨"],"timeAnchors":["2027-02-14"],' +
  '"locations":["南京"],"commitments":["持续跟进宾客确认"],' +
  '"keywords":["南京","婚宴","宾客"],"dashboardItems":[' +
  '{"kind":"event","title":"婚宴日期","value":"2027-02-14",' +
  '"detail":"南京","status":"进行中"}]}}';
const EXPLICIT_SERIAL_QUERY: string =
  '查一下现在的时间，查好时间之后帮我打车从华为坂田基地打车到秋岗花园，再在明天的这个时间新建一个会议日程';
const EXPLICIT_SERIAL_QUERY_WITH_DURATION: string =
  '查一下现在的时间，查好时间之后帮我打车从华为坂田基地打车到秋岗花园，' +
  '再在明天的这个时间新建一个30分钟的会议日程';
const EXPLICIT_SERIAL_FIRST_DECISION: string =
  '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["time","ride.estimate","calendar.event.create"],' +
  '"roundAction":"execute","continuationMode":"sequence","dataTasks":[' +
  '{"localId":"time","goal":"查询当前时间","allowedToolIds":["time"],' +
  '"toolId":"time","input":{},"required":true},' +
  '{"localId":"ride","goal":"查询打车费用","allowedToolIds":["ride.estimate"],' +
  '"toolId":"ride.estimate","input":{"origin":"华为坂田基地","destination":"秋岗花园",' +
  '"city":"深圳"},"required":true}],"uiIntent":{"purpose":"串行执行请求",' +
  '"preferredDensity":"comfortable","requiredSections":["time","ride","calendar"]},' +
  '"actionIntent":{"goal":"创建明天同一时间的会议日程",' +
  '"allowedActionIds":["calendar.event.create"]}}';
const EXPLICIT_SERIAL_SECOND_DECISION: string =
  '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["ride.estimate","calendar.event.create"],' +
  '"roundAction":"execute","continuationMode":"sequence","dataTasks":[' +
  '{"localId":"ride","goal":"查询打车费用","allowedToolIds":["ride.estimate"],' +
  '"toolId":"ride.estimate","input":{"origin":"华为坂田基地","destination":"秋岗花园",' +
  '"city":"深圳"},"required":true}],"uiIntent":{"purpose":"串行执行请求",' +
  '"preferredDensity":"comfortable","requiredSections":["ride","calendar"]},' +
  '"actionIntent":{"goal":"创建明天同一时间的会议日程",' +
  '"allowedActionIds":["calendar.event.create"]}}';
const EXPLICIT_SERIAL_THIRD_DECISION: string =
  '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["calendar.event.create"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[],' +
  '"uiIntent":{"purpose":"创建明天同一时间的会议日程","preferredDensity":"comfortable",' +
  '"requiredSections":["calendar"]},"actionIntent":{"goal":"创建明天同一时间的会议日程",' +
  '"allowedActionIds":["calendar.event.create"]}}';

function sameRoundDependencyDecision(
  sourceToolId: string,
  consumerToolId: string,
  consumerInput: string,
  reversed: boolean = false
): string {
  return sameRoundDependencyDecisionWithConsumers(
    sourceToolId,
    consumerToolId,
    [consumerInput],
    reversed
  );
}

function sameRoundDependencyDecisionWithConsumers(
  sourceToolId: string,
  consumerToolId: string,
  consumerInputs: string[],
  reversed: boolean = false
): string {
  const source: string = '{"localId":"source","goal":"read source",' +
    '"allowedToolIds":["' + sourceToolId + '"],"toolId":"' + sourceToolId + '",' +
    '"input":{},"required":true}';
  const consumers: string[] = [];
  for (let index = 0; index < consumerInputs.length; index++) {
    consumers.push('{"localId":"consumer-' + index.toString() + '","goal":"read dependent detail",' +
      '"allowedToolIds":["' + consumerToolId + '"],"toolId":"' + consumerToolId + '",' +
      '"input":' + consumerInputs[index] + ',"required":true}');
  }
  const consumerTasks: string = consumers.join(',');
  const tasks: string = reversed ? consumerTasks + ',' + source : source + ',' + consumerTasks;
  return '{"personaId":"travel_companion","skillId":"",' +
    '"requestedCapabilityIds":["' + sourceToolId + '","' + consumerToolId + '"],' +
    '"roundAction":"execute","continuationMode":"complete","dataTasks":[' + tasks + '],"uiIntent":{' +
    '"purpose":"read source and dependent detail","preferredDensity":"comfortable",' +
    '"requiredSections":["source","detail"]}}';
}

function producerOnlyRepairDecision(toolId: string): string {
  return '{"personaId":"travel_companion","skillId":"",' +
    '"requestedCapabilityIds":["' + toolId + '"],"roundAction":"execute","continuationMode":"complete",' +
    '"dataTasks":[{"localId":"source","goal":"read source",' +
    '"allowedToolIds":["' + toolId + '"],"toolId":"' + toolId + '",' +
    '"input":{},"required":true}],"uiIntent":{' +
    '"purpose":"read source and dependent detail","preferredDensity":"comfortable",' +
    '"requiredSections":["source","detail"]}}';
}

function directDependencyConsumerDecision(toolId: string, input: string): string {
  return '{"personaId":"travel_companion","skillId":"",' +
    '"requestedCapabilityIds":["' + toolId + '"],"roundAction":"execute","continuationMode":"complete",' +
    '"dataTasks":[{"localId":"direct-detail","goal":"read an explicit detail",' +
    '"allowedToolIds":["' + toolId + '"],"toolId":"' + toolId + '",' +
    '"input":' + input + ',"required":true}],"uiIntent":{' +
    '"purpose":"read a direct detail","preferredDensity":"comfortable",' +
    '"requiredSections":["detail"]}}';
}

function sameRoundMapsWithFood(
  includeConsumer: boolean,
  foodAllowedToolIds: string
): string {
  const source: string = '{"localId":"source","goal":"read source",' +
    '"allowedToolIds":["maps.place.search"],"toolId":"maps.place.search",' +
    '"input":{},"required":true}';
  const food: string = '{"localId":"food","goal":"search food",' +
    '"allowedToolIds":' + foodAllowedToolIds + ',"toolId":"food.search",' +
    '"input":{"query":"coffee"},"required":false}';
  const consumer: string = '{"localId":"consumer","goal":"read dependent detail",' +
    '"allowedToolIds":["maps.place.details"],"toolId":"maps.place.details",' +
    '"input":{},"required":true}';
  const tasks: string = includeConsumer ? source + ',' + food + ',' + consumer : source + ',' + food;
  const capabilityIds: string = includeConsumer || foodAllowedToolIds.indexOf('maps.place.details') >= 0 ?
    '["maps.place.search","food.search","maps.place.details"]' :
    '["maps.place.search","food.search"]';
  return '{"personaId":"travel_companion","skillId":"",' +
    '"requestedCapabilityIds":' + capabilityIds + ',"roundAction":"execute","continuationMode":"complete","dataTasks":[' +
    tasks + '],"uiIntent":{"purpose":"read source and food","preferredDensity":"comfortable",' +
    '"requiredSections":["source","food"]}}';
}

async function sameRoundDependencyError(output: string): Promise<string> {
  const model = new QueueLocalModel([output]);
  try {
    await new MultiAgentLeaderPlanner(model).plan(
      inputMessage(), { text: 'search then details' }, planningContext(), 1,
      (): boolean => true
    );
  } catch (error) {
    return error instanceof Error ? error.message : 'unknown';
  }
  return '';
}

const MISSING_PERSONA_DECISION: string = LIVE_ANSWER_WITHOUT_REASON_CODE.replace(
  '"personaId":"travel_companion",',
  ''
);
const REGISTERED_DATA_TOOL_IDS: string[] = [
  'travel.search',
  'train.search',
  'flight.search',
  'hotel.search',
  'food.search',
  'social.feed.search',
  'x.post.search',
  'mail.search',
  'mail.thread.read',
  'gmail.mail.search'
];

function manyTravelDecision(count: number): string {
  const tasks: string[] = [];
  for (let index = 0; index < count; index++) {
    tasks.push('{"localId":"travel-' + index.toString() + '",' +
      '"goal":"read travel source","allowedToolIds":["travel.search"],' +
      '"toolId":"travel.search","input":{"query":"北京到上海"},"required":true}');
  }
  return '{"personaId":"travel_companion","skillId":"",' +
    '"requestedCapabilityIds":["travel.search"],"roundAction":"execute","continuationMode":"complete",' +
    '"dataTasks":[' + tasks.join(',') + '],"uiIntent":{"purpose":"travel.search",' +
    '"preferredDensity":"comfortable","requiredSections":["travel"]}}';
}

class QueueLocalModel implements LocalModel {
  prompts: string[] = [];
  systemPrompts: string[] = [];
  conversations: string[][] = [];
  private readonly outputs: string[];

  constructor(outputs: string[]) {
    this.outputs = outputs.slice();
  }

  async complete(
    prompt: string,
    conversation?: ConversationContext,
    systemPrompt?: string
  ): Promise<string> {
    this.prompts.push(prompt);
    this.systemPrompts.push(systemPrompt ?? '');
    this.conversations.push(conversation === undefined ? [] :
      conversation.toChatMessages().map((message) => message.role + ':' + message.content));
    if (this.outputs.length === 0) {
      throw new Error('No scripted Leader output');
    }
    return this.outputs.shift() as string;
  }
}

const CAPTURED_LOCAL_FOOD_DECISION: string = '{"personaId":"food_companion","skillId":"",' +
  '"requestedCapabilityIds":["local.food.search"],"roundAction":"execute",' +
  '"continuationMode":"complete","dataTasks":[{"localId":"search_coffee_shops",' +
  '"goal":"搜索深圳坂田华为基地附近的咖啡店","allowedToolIds":["local.food.search"],' +
  '"toolId":"local.food.search","input":{"query":"深圳坂田华为基地附近的咖啡店"},' +
  '"required":true}],"uiIntent":{"purpose":"search","preferredDensity":"compact",' +
  '"requiredSections":["results"]}}';

class IntentAliasSensitiveFoodModel implements LocalModel {
  prompts: string[] = [];

  async complete(prompt: string): Promise<string> {
    this.prompts.push(prompt);
    return prompt.indexOf('local.food.search') >= 0 ?
      CAPTURED_LOCAL_FOOD_DECISION :
      CAPTURED_LOCAL_FOOD_DECISION.replaceAll('local.food.search', 'food.search');
  }
}

const socialInputNormalizer: LeaderDataTaskInputNormalizer = (
  _input: InputUserPayload,
  task: LeaderDecisionDataTask
): Object => {
  const values = task.input as Record<string, Object | string | number | boolean | null | undefined>;
  if (task.toolId !== 'social.feed.search' ||
    Object.keys(values).join(',') !== 'platforms' ||
    !Array.isArray(values['platforms'])) {
    throw new Error('SOCIAL_FEED_PLATFORMS_INVALID');
  }
  return task.input;
};

const rejectedHotelInputNormalizer: LeaderDataTaskInputNormalizer = (
  _input: InputUserPayload,
  task: LeaderDecisionDataTask
): Object => {
  if (task.toolId === 'hotel.search') {
    throw new Error('HOTEL_STATE_UPDATE_IS_NOT_SEARCH');
  }
  return task.input;
};

class TravelPromptAwareModel implements LocalModel {
  prompts: string[] = [];

  async complete(prompt: string): Promise<string> {
    this.prompts.push(prompt);
    const hasAggregateContract: boolean = prompt.indexOf(
      'For requests that do not explicitly name those concrete modes, broad or multimodal wording such as ' +
        '出行方案, 怎么去, or 综合比较 means exactly one travel.search Data task.'
    ) >= 0;
    const hasExplicitPairPrecedence: boolean = prompt.indexOf(
      'Explicitly naming both flight/航班/飞机 and train/高铁/火车 takes precedence over broad words such as 比较.'
    ) >= 0;
    if (prompt.indexOf('我明天要从北京去上海，帮我搜索出行方案') >= 0) {
      return hasAggregateContract ? TRAVEL_DECISION : PARALLEL_DECISION;
    }
    if (prompt.indexOf('比较明天北京到上海的航班和高铁') >= 0) {
      return hasExplicitPairPrecedence ? PARALLEL_DECISION : TRAVEL_DECISION;
    }
    if (prompt.indexOf('帮我查明天北京到上海的航班') >= 0) {
      return FLIGHT_DECISION;
    }
    if (prompt.indexOf('帮我查询明天晚上六点以后深圳北到香港西九龙的高铁') >= 0) {
      return TRAIN_DECISION;
    }
    return PARALLEL_DECISION;
  }
}

class RequestScopePromptAwareModel implements LocalModel {
  prompts: string[] = [];
  systemPrompts: string[] = [];

  async complete(
    prompt: string,
    _conversation?: ConversationContext,
    systemPrompt?: string
  ): Promise<string> {
    this.prompts.push(prompt);
    this.systemPrompts.push(systemPrompt ?? '');
    const explicitMultiDomain: boolean = prompt.indexOf('同时查看 X、Slack 和邮件') >= 0;
    const scoped: boolean = prompt.indexOf(
      'The current user request defines a closed capability and source set.'
    ) >= 0 && (systemPrompt ?? '').indexOf(
      'The current user request defines a closed capability and source set.'
    ) >= 0 && prompt.indexOf('silently scope-check') >= 0;
    return explicitMultiDomain || !scoped ? SOCIAL_MAIL_DECISION : SOCIAL_ONLY_DECISION;
  }
}

class C10C11PromptAwareModel implements LocalModel {
  prompts: string[] = [];

  async complete(prompt: string): Promise<string> {
    this.prompts.push(prompt);
    const hasSelectionContract: boolean = prompt.indexOf(
      'C10/C11 selection contract: Explicit X/Twitter public post searches use x.post.search.'
    ) >= 0;
    if (prompt.indexOf('"text":"帮我查看 X 上 OpenAI 最近的公开 post"') >= 0) {
      return hasSelectionContract ? X_POST_DECISION : SOCIAL_ONLY_DECISION;
    }
    if (prompt.indexOf('"text":"帮我查看我今天 X 和 Slack 上的消息"') >= 0) {
      return hasSelectionContract ? SOCIAL_ONLY_DECISION : X_POST_DECISION;
    }
    if (prompt.indexOf('"text":"点一杯咖啡"') >= 0) {
      return hasSelectionContract ? FOOD_COFFEE_DECISION : actionDecision('luckin.order.preview');
    }
    if (prompt.indexOf('"text":"帮我点一杯瑞幸生椰拿铁，半糖少冰"') >= 0) {
      return hasSelectionContract ? actionDecision('luckin.order.preview') : FOOD_COFFEE_DECISION;
    }
    return hasSelectionContract ? actionDecision('memory.update') : FOOD_COFFEE_DECISION;
  }
}

class MixedOwnershipPromptAwareModel implements LocalModel {
  prompts: string[] = [];

  async complete(prompt: string): Promise<string> {
    this.prompts.push(prompt);
    const hasMixedOwnershipContract: boolean = prompt.indexOf(
      'For a mixed request, put Data-owned capabilities only in dataTasks and Action-owned capabilities only in actionIntent.'
    ) >= 0;
    if (hasMixedOwnershipContract) {
      return MIXED_DATA_ACTION_DECISION;
    }
    return MIXED_DATA_ACTION_DECISION
      .replace(
        '"dataTasks":[{"localId":"ride"',
        '"dataTasks":[{"localId":"luckin","goal":"点瑞幸","allowedToolIds":[' +
          '"luckin.order.preview"],"toolId":"luckin.order.preview","input":{},' +
          '"required":true},{"localId":"ride"'
      )
      .replace(
        ',"actionIntent":{"goal":"预览瑞幸订单，然后打开转账确认",' +
          '"allowedActionIds":["luckin.order.preview","payment.send"]}',
        ''
      );
  }
}

class ObservationPromptAwareModel implements LocalModel {
  prompts: string[] = [];

  async complete(prompt: string): Promise<string> {
    this.prompts.push(prompt);
    const hasCompletedTools: boolean = prompt.indexOf(
      'Current-turn completed Data tool IDs: ["travel.search"]'
    ) >= 0;
    const hasNoRepeatContract: boolean = prompt.indexOf(
      'Never schedule a listed tool again in a later round, regardless of success, partial, empty, or error status.'
    ) >= 0;
    if (!hasCompletedTools || !hasNoRepeatContract) {
      return TRAVEL_DECISION;
    }
    if (prompt.indexOf('读取上一轮真实地点详情') >= 0) {
      return MAP_DETAILS_DECISION;
    }
    return ANSWER_FROM_TRAVEL_OBSERVATION;
  }
}

class LockedSelectionPromptAwareModel implements LocalModel {
  prompts: string[] = [];

  async complete(prompt: string): Promise<string> {
    this.prompts.push(prompt);
    const locked: boolean = prompt.indexOf(
      'Locked turn persona/skill: {"personaId":"travel_companion","skillId":""}'
    ) >= 0 && prompt.indexOf(
      'Every later-round decision must preserve this exact personaId and skillId.'
    ) >= 0;
    return locked ? ANSWER_FROM_TRAVEL_OBSERVATION :
      ANSWER_FROM_TRAVEL_OBSERVATION.replace(
        '"personaId":"travel_companion"',
        '"personaId":"default_companion"'
      );
  }
}

class TerminalRepairPromptAwareModel implements LocalModel {
  prompts: string[] = [];
  private readonly firstDecision: string;
  private readonly repairedDecision: string;

  constructor(firstDecision: string, repairedDecision: string = MODEL_OWNED_TERMINAL_REPAIR) {
    this.firstDecision = firstDecision;
    this.repairedDecision = repairedDecision;
  }

  async complete(prompt: string): Promise<string> {
    this.prompts.push(prompt);
    if (this.prompts.length === 1) {
      return this.firstDecision;
    }
    const hasMandatoryFields: boolean = prompt.indexOf(
      'including a correction or repair, must include personaId, skillId, requestedCapabilityIds, ' +
        'roundAction, continuationMode, dataTasks, and uiIntent'
    ) >= 0;
    const hasTerminalShape: boolean = prompt.indexOf(
      'For answer or clarify, set continuationMode to complete, set dataTasks to [], and include a non-empty answer.'
    ) >= 0;
    const hasModelOwnedUi: boolean = prompt.indexOf(
      'Choose purpose, preferredDensity, and requiredSections'
    ) >= 0;
    const hasObservationGrounding: boolean = prompt.indexOf(
      'real recentObservations'
    ) >= 0;
    return hasMandatoryFields && hasTerminalShape && hasModelOwnedUi && hasObservationGrounding ?
      this.repairedDecision : SPARSE_TERMINAL_REPAIR;
  }
}

function inputMessage(): AgentMessage {
  const payload: InputUserPayload = { text: '查航班和高铁' };
  return {
    type: AgentMessageType.INPUT_USER,
    conversationId: 'conversation-leader-planner',
    turnId: 'turn-1',
    taskId: 'input-1',
    payload
  };
}

function completedTravelInput(status: string = 'success'): InputUserPayload {
  return {
    text: '根据上一轮结果继续回答',
    recentObservations: [{
      taskId: 'input-1:round-1:travel',
      toolId: 'travel.search',
      status,
      summary: 'OBSERVATION_PRIVATE_SUMMARY',
      entityRefs: ['ENTITY_PRIVATE_MARKER']
    }]
  };
}

function planningContext(): LeaderPlanningContext {
  return {
    tools: [{
      toolId: 'travel.search',
      domain: 'travel',
      intent: 'Search aggregate real travel options',
      riskLevel: 'read',
      registeredBackends: ['local_adapter'],
      inputSchema: 'travelSearchQuery',
      outputSchema: 'travelOptions',
      actions: []
    }, {
      toolId: 'flight.search',
      domain: 'travel',
      intent: 'Search real flights',
      riskLevel: 'read',
      registeredBackends: ['mcp_remote'],
      inputSchema: 'flightSearchRequest',
      outputSchema: 'flightSearchResults',
      actions: []
    }, {
      toolId: 'train.search',
      domain: 'travel',
      intent: 'Search real trains',
      riskLevel: 'read',
      registeredBackends: ['local_adapter'],
      inputSchema: 'trainSearchRequest',
      outputSchema: 'trainSearchResults',
      actions: []
    }, {
      toolId: 'hotel.search',
      domain: 'hotel',
      intent: 'Search real hotels',
      riskLevel: 'read',
      registeredBackends: ['mcp_remote'],
      inputSchema: 'hotelSearchRequest',
      outputSchema: 'hotelSearchResults',
      actions: []
    }, {
      toolId: 'hotel.navigate',
      domain: 'hotel',
      intent: 'Open hotel navigation',
      riskLevel: 'read',
      registeredBackends: ['system_intent'],
      inputSchema: 'hotelNavigateRequest',
      outputSchema: 'hotelNavigateResult',
      actions: []
    }, {
      toolId: 'maps.place.search',
      domain: 'maps',
      intent: 'Search real places',
      riskLevel: 'read',
      registeredBackends: ['oauth_api'],
      inputSchema: 'mapsPlaceSearchQuery',
      outputSchema: 'places',
      actions: []
    }, {
      toolId: 'maps.place.details',
      domain: 'maps',
      intent: 'Read details for one real place ID',
      riskLevel: 'read',
      registeredBackends: ['oauth_api'],
      inputSchema: 'mapsPlaceDetailsQuery',
      outputSchema: 'place',
      actions: []
    }, {
      toolId: 'food.search',
      domain: 'food',
      intent: 'Search food for an explicitly scoped place',
      riskLevel: 'read',
      registeredBackends: ['local_adapter'],
      inputSchema: 'foodSearchRequest',
      outputSchema: 'foodSearchResults',
      actions: []
    }, {
      toolId: 'social.feed.search',
      domain: 'social',
      intent: 'Search real SocialHub messages',
      riskLevel: 'read',
      registeredBackends: ['local_adapter'],
      inputSchema: 'socialFeedSearchQuery',
      outputSchema: 'socialHubFeed',
      actions: []
    }, {
      toolId: 'mail.search',
      domain: 'mail',
      intent: 'Search real mail',
      riskLevel: 'read',
      registeredBackends: ['oauth_api', 'imap', 'workspace_mcp'],
      inputSchema: 'mailSearchRequest',
      outputSchema: 'mailSearchResults',
      actions: []
    }, {
      toolId: 'mail.thread.read',
      domain: 'mail',
      intent: 'Read one exact mail identity',
      riskLevel: 'read',
      registeredBackends: ['oauth_api', 'imap', 'workspace_mcp'],
      inputSchema: 'mailThreadReadRequest',
      outputSchema: 'mailThread',
      actions: []
    }, {
      toolId: 'gmail.mail.search',
      domain: 'gmail',
      intent: 'Search real Gmail',
      riskLevel: 'read',
      registeredBackends: ['oauth_api', 'workspace_mcp'],
      inputSchema: 'gmailSearchRequest',
      outputSchema: 'mailSearchResults',
      actions: []
    }, {
      toolId: 'gmail.thread.read',
      domain: 'gmail',
      intent: 'Read one exact Gmail identity',
      riskLevel: 'read',
      registeredBackends: ['oauth_api', 'workspace_mcp'],
      inputSchema: 'mailThreadReadRequest',
      outputSchema: 'mailThread',
      actions: []
    }, {
      toolId: 'media.video.search',
      domain: 'media',
      intent: 'Search real Bilibili or multi-source videos',
      riskLevel: 'read',
      registeredBackends: ['local_adapter'],
      inputSchema: 'mediaVideoSearchQuery',
      outputSchema: 'videoSearchResults',
      actions: []
    }, {
      toolId: 'youtube.video.search',
      domain: 'media',
      intent: 'Search real YouTube-only videos',
      riskLevel: 'read',
      registeredBackends: ['oauth_api'],
      inputSchema: 'youtubeVideoSearchQuery',
      outputSchema: 'videoSearchResults',
      actions: []
    }, {
      toolId: 'memory.update',
      domain: 'persona',
      intent: 'Update persona memory',
      riskLevel: 'draft',
      registeredBackends: ['local_adapter'],
      inputSchema: 'memoryUpdateRequest',
      outputSchema: 'memoryUpdateResult',
      actions: ['memory.update']
    }, {
      toolId: 'payment.create',
      domain: 'payment',
      intent: 'Create a payment',
      riskLevel: 'confirm_required',
      registeredBackends: ['web_session'],
      inputSchema: 'paymentCreateRequest',
      outputSchema: 'paymentCreateResult',
      actions: []
    }],
    personas: [{
      personaId: 'travel_companion',
      name: 'Travel Companion',
      soul: 'Ground travel suggestions in real provider results.',
      memory: 'No saved preference.',
      previous: false,
      activeSkills: [{
        skillId: 'travel-planning',
        description: 'Plan travel',
        instructions: 'Use real travel inventory.',
        status: 'active',
        toolIds: ['travel.search']
      }]
    }]
  };
}

function actionOwnerContext(): LeaderPlanningContext {
  const context = planningContext();
  const definitions: ToolDefinition[] = actionAgentToolDefinitions();
  for (let index = 0; index < definitions.length; index++) {
    const definition = definitions[index];
    if (context.tools.some((tool): boolean => tool.toolId === definition.toolId)) {
      continue;
    }
    context.tools.push({
      toolId: definition.toolId,
      domain: definition.domain,
      intent: definition.intent,
      riskLevel: definition.riskLevel,
      registeredBackends: definition.backendPriority.slice(),
      inputSchema: definition.inputSchema,
      outputSchema: definition.outputSchema,
      actions: []
    });
  }
  for (let index = 0; index < context.tools.length; index++) {
    if (context.tools[index].toolId === 'memory.update') {
      context.tools[index].actions = [];
    }
  }
  return context;
}

function c10C11Context(): LeaderPlanningContext {
  const context = actionOwnerContext();
  context.tools.push({
    toolId: 'x.post.search',
    domain: 'x',
    intent: 'Search real public X posts',
    riskLevel: 'read',
    registeredBackends: ['local_adapter'],
    inputSchema: 'xPostSearchQuery',
    outputSchema: 'xPostSearchResults',
    actions: []
  });
  return context;
}

function actionDecision(actionId: string): string {
  return '{"personaId":"travel_companion","skillId":"",' +
    '"requestedCapabilityIds":["' + actionId + '"],"roundAction":"execute","continuationMode":"complete","dataTasks":[],' +
    '"uiIntent":{"purpose":"perform requested action","preferredDensity":"comfortable",' +
    '"requiredSections":[]},"actionIntent":{"goal":"perform requested action",' +
    '"allowedActionIds":["' + actionId + '"]}}';
}

function actionAsDataDecision(actionId: string): string {
  return '{"personaId":"travel_companion","skillId":"",' +
    '"requestedCapabilityIds":["' + actionId + '"],"roundAction":"execute","continuationMode":"complete",' +
    '"dataTasks":[{"localId":"action-as-data","goal":"perform requested action",' +
    '"allowedToolIds":["' + actionId + '"],"toolId":"' + actionId + '",' +
    '"input":{},"required":true}],"uiIntent":{"purpose":"perform requested action",' +
    '"preferredDensity":"comfortable","requiredSections":[]}}';
}

function hotelDetailDualRoleDecision(): string {
  return '{"personaId":"travel_companion","skillId":"",' +
    '"requestedCapabilityIds":["hotel.detail"],"roundAction":"execute","continuationMode":"complete",' +
    '"dataTasks":[{"localId":"hotel-detail","goal":"read exact hotel detail",' +
    '"allowedToolIds":["hotel.detail"],"toolId":"hotel.detail",' +
    '"input":{"hotelId":47675},"required":true}],"uiIntent":{' +
    '"purpose":"show hotel detail","preferredDensity":"comfortable",' +
    '"requiredSections":["hotel"]},"actionIntent":{"goal":"offer the declared hotel detail follow-up",' +
    '"allowedActionIds":["hotel.detail"]}}';
}

function hotelDetailDataOnlyDecision(): string {
  return '{"personaId":"travel_companion","skillId":"",' +
    '"requestedCapabilityIds":["hotel.detail"],"roundAction":"execute","continuationMode":"complete",' +
    '"dataTasks":[{"localId":"hotel-detail","goal":"read exact hotel detail",' +
    '"allowedToolIds":["hotel.detail"],"toolId":"hotel.detail",' +
    '"input":{"hotelId":47675},"required":true}],"uiIntent":{' +
    '"purpose":"show hotel detail","preferredDensity":"comfortable",' +
    '"requiredSections":["hotel"]}}';
}

function hotelDetailActionOnlyDecision(): string {
  return '{"personaId":"travel_companion","skillId":"",' +
    '"requestedCapabilityIds":["hotel.detail"],"roundAction":"execute","continuationMode":"complete","dataTasks":[],' +
    '"uiIntent":{"purpose":"offer hotel detail","preferredDensity":"comfortable",' +
    '"requiredSections":["hotel"]},"actionIntent":{"goal":"offer the declared hotel detail follow-up",' +
    '"allowedActionIds":["hotel.detail"]}}';
}

function withoutPersona(decision: string): string {
  return decision.replace('"personaId":"travel_companion",', '');
}

async function repairFails(
  first: string,
  repaired: string,
  context: LeaderPlanningContext
): Promise<boolean> {
  const model = new QueueLocalModel([first, repaired]);
  try {
    await new MultiAgentLeaderPlanner(model).plan(
      inputMessage(),
      { text: '执行原始请求' },
      context,
      1,
      (): boolean => true
    );
    return false;
  } catch (_error) {
    return true;
  }
}

async function repairErrorCode(
  first: string,
  repaired: string,
  context: LeaderPlanningContext
): Promise<string> {
  const model = new QueueLocalModel([first, repaired]);
  try {
    await new MultiAgentLeaderPlanner(model).plan(
      inputMessage(),
      { text: '执行原始请求' },
      context,
      1,
      (): boolean => true
    );
    return '';
  } catch (error) {
    return error instanceof Error ? error.message : 'unknown';
  }
}

async function fails(output: string): Promise<boolean> {
  const model: QueueLocalModel = new QueueLocalModel([output, output]);
  const planner: MultiAgentLeaderPlanner = new MultiAgentLeaderPlanner(model);
  const input: InputUserPayload = { text: '查航班和高铁' };
  try {
    await planner.plan(inputMessage(), input, planningContext(), 1, (): boolean => true);
    return false;
  } catch (_error) {
    return true;
  }
}

async function failsAtRound(output: string, round: number): Promise<boolean> {
  const model: QueueLocalModel = new QueueLocalModel([output]);
  const planner: MultiAgentLeaderPlanner = new MultiAgentLeaderPlanner(model);
  const input: InputUserPayload = { text: '查航班和高铁' };
  try {
    await planner.plan(inputMessage(), input, planningContext(), round);
    return false;
  } catch (_error) {
    return true;
  }
}

export default function multiAgentLeaderPlannerTest() {
  describe('multiAgentLeaderPlanner', () => {
    it('passes prior conversation messages to the Leader model', 0, async () => {
      const model = new QueueLocalModel([LIVE_ANSWER_WITHOUT_REASON_CODE]);
      await new MultiAgentLeaderPlanner(model).plan(
        inputMessage(),
        {
          text: '帮我订7月30日的机票',
          recentMessages: [{ role: 'user', content: '我现在在深圳，想去上海' }]
        },
        planningContext(),
        1
      );

      expect(model.conversations.length).assertEqual(1);
      expect(model.conversations[0].length).assertEqual(1);
      expect(model.conversations[0][0]).assertEqual('user:我现在在深圳，想去上海');
    });

    it('keeps internal food intent aliases out of Leader capability IDs', 0, async () => {
      const context = planningContext();
      let foodToolIndex: number = -1;
      for (let index = 0; index < context.tools.length; index++) {
        if (context.tools[index].toolId === 'food.search') {
          foodToolIndex = index;
          context.tools[index].intent = 'local.food.search';
          context.tools[index].planningHint =
            'local.food.search risk=read inputSchema=foodSearchQuery outputSchema=foodChoices';
        }
      }
      context.personas[0].personaId = 'food_companion';
      context.personas[0].activeSkills = [];
      const model = new IntentAliasSensitiveFoodModel();

      const decision = await new MultiAgentLeaderPlanner(model).plan(
        inputMessage(),
        { text: '帮我搜索深圳坂田华为基地附近的咖啡店' },
        context,
        1,
        (): boolean => true
      );

      expect(decision.dataTasks[0].toolId).assertEqual('food.search');
      expect(model.prompts.length).assertEqual(1);
      expect(model.prompts[0].indexOf('local.food.search')).assertEqual(-1);
      expect(foodToolIndex).assertLarger(-1);
      expect(context.tools[foodToolIndex].intent).assertEqual('local.food.search');
    });

    it('accepts a conservative BIM suggestion from the same Leader call', 0, async () => {
      const output: string = LIVE_ANSWER_WITHOUT_REASON_CODE.substring(
        0, LIVE_ANSWER_WITHOUT_REASON_CODE.length - 1
      ) + ',"bimSuggestion":{"title":"东京旅行","summary":"八月东京一周旅行",' +
        '"reason":"需要继续筛选机票和酒店","keywords":["东京","旅行","机票","酒店"]}}';
      const decision = await new MultiAgentLeaderPlanner(new QueueLocalModel([output])).plan(
        inputMessage(), { text: '规划东京旅行' }, planningContext(), 1
      );

      expect(decision.bimSuggestion?.title).assertEqual('东京旅行');
      expect(decision.bimSuggestion?.keywords.length).assertEqual(4);
    });

    it('accepts initial dashboard state together with a BIM suggestion', 0, async () => {
      const prefix: string = LIVE_ANSWER_WITHOUT_REASON_CODE.substring(
        0, LIVE_ANSWER_WITHOUT_REASON_CODE.length - 1
      );
      const output: string = prefix +
        ',"bimSuggestion":{"title":"婚宴宾客","summary":"南京婚宴宾客安排",' +
        '"reason":"需要持续确认宾客","keywords":["婚宴","宾客","南京"]},' +
        '"bimContextUpdate":{"summary":"49 位宾客已确认，3 位待确认",' +
        '"facts":["婚宴在南京举办"],"constraints":["每桌10人"],"decisions":[],' +
        '"entities":["017","小王","李阿姨"],"timeAnchors":["2027-02-14"],' +
        '"locations":["南京"],"commitments":["持续确认三位宾客"],' +
        '"keywords":["婚宴","宾客","桌数"],"dashboardItems":[' +
        '{"kind":"metric","title":"已确认","value":"49","detail":"位宾客","status":""},' +
        '{"kind":"person","title":"小王","value":"待确认","detail":"","status":"待回复"}]}}';
      const fallback: string = prefix +
        ',"bimSuggestion":{"title":"婚宴宾客","summary":"南京婚宴宾客安排",' +
        '"reason":"需要持续确认宾客","keywords":["婚宴","宾客","南京"]}}';
      const model = new QueueLocalModel([output, fallback]);
      const decision = await new MultiAgentLeaderPlanner(model).plan(
        inputMessage(), { text: '帮我持续跟进婚宴宾客' }, planningContext(), 1,
        (): boolean => true
      );

      expect(model.prompts.length).assertEqual(1);
      expect(decision.bimSuggestion?.title).assertEqual('婚宴宾客');
      expect(decision.bimContextUpdate?.dashboardItems?.length).assertEqual(2);
      expect(decision.bimContextUpdate?.dashboardItems?.[1].title).assertEqual('小王');
    });

    it('moves a new long-running wedding matter out of persona memory', 0, async () => {
      const model = new QueueLocalModel([
        actionDecision('memory.update'),
        BIM_CREATION_ANSWER
      ]);
      const decision = await new MultiAgentLeaderPlanner(model).plan(
        inputMessage(),
        { text: '2027年2月14日在南京办婚宴，小王和李阿姨参加，总人数50人，每桌10人，后续持续跟进宾客确认。' },
        actionOwnerContext(),
        1,
        (): boolean => true
      );

      expect(model.prompts.length).assertEqual(2);
      expect(decision.requestedCapabilityIds.length).assertEqual(0);
      expect(decision.actionIntent === undefined).assertTrue();
      expect(decision.bimSuggestion?.title).assertEqual('南京婚宴');
      expect(decision.bimContextUpdate?.dashboardItems?.length).assertEqual(1);
    });

    it('uses the same boundary for a non-wedding multi-stage group matter', 0, async () => {
      const model = new QueueLocalModel([
        actionDecision('memory.update'),
        BIM_CREATION_ANSWER
      ]);
      const decision = await new MultiAgentLeaderPlanner(model).plan(
        inputMessage(),
        { text: '下个月和三位同事分阶段推进展会，后续每周跟进任务。' },
        actionOwnerContext(),
        1,
        (): boolean => true
      );

      expect(model.prompts.length).assertEqual(2);
      expect(decision.requestedCapabilityIds.length).assertEqual(0);
      expect(decision.bimSuggestion !== undefined).assertTrue();
      expect(decision.bimContextUpdate?.dashboardItems?.length).assertEqual(1);
    });

    it('suggests a natural long-running matter without a remember prefix', 0, async () => {
      const model = new QueueLocalModel([
        LIVE_ANSWER_WITHOUT_REASON_CODE,
        BIM_CREATION_ANSWER
      ]);
      const decision = await new MultiAgentLeaderPlanner(model).plan(
        inputMessage(),
        { text: '我下个月要去上海参加展会，后面还要持续跟进准备，先帮我把这个计划记下来。' },
        actionOwnerContext(),
        1,
        (): boolean => true
      );

      expect(model.prompts.length).assertEqual(2);
      expect(decision.requestedCapabilityIds.length).assertEqual(0);
      expect(decision.actionIntent === undefined).assertTrue();
      expect(decision.bimSuggestion !== undefined).assertTrue();
      expect(decision.bimContextUpdate?.dashboardItems?.length).assertEqual(1);
    });

    it('recognizes natural staged progress without a remember prefix', 0, async () => {
      const model = new QueueLocalModel([
        LIVE_ANSWER_WITHOUT_REASON_CODE,
        BIM_CREATION_ANSWER
      ]);
      const decision = await new MultiAgentLeaderPlanner(model).plan(
        inputMessage(),
        { text: '孩子明年参加高考，报名、备考和志愿分阶段推进，每周跟进准备进度。' },
        actionOwnerContext(),
        1,
        (): boolean => true
      );

      expect(model.prompts.length).assertEqual(2);
      expect(decision.requestedCapabilityIds.length).assertEqual(0);
      expect(decision.bimSuggestion !== undefined).assertTrue();
      expect(decision.bimContextUpdate?.dashboardItems?.length).assertEqual(1);
    });

    it('repairs a new long-running matter that the model routes to a business action', 0, async () => {
      const model = new QueueLocalModel([
        actionDecision('calendar.event.create'),
        BIM_CREATION_ANSWER
      ]);
      const decision = await new MultiAgentLeaderPlanner(model).plan(
        inputMessage(),
        { text: '请记在心上：2027年5月和三位同事分阶段筹备展会，后续每周跟进准备状态。' },
        actionOwnerContext(),
        1,
        (): boolean => true
      );

      expect(model.prompts.length).assertEqual(2);
      expect(decision.requestedCapabilityIds.length).assertEqual(0);
      expect(decision.actionIntent === undefined).assertTrue();
      expect(decision.bimSuggestion !== undefined).assertTrue();
      expect(decision.bimContextUpdate?.dashboardItems?.length).assertEqual(1);
    });

    it('requires a complete initial BIM payload for an explicit new matter', 0, async () => {
      const prefix: string = LIVE_ANSWER_WITHOUT_REASON_CODE.substring(
        0, LIVE_ANSWER_WITHOUT_REASON_CODE.length - 1
      );
      const incomplete: string = prefix +
        ',"bimSuggestion":{"title":"展会筹备","summary":"分阶段跟进展会准备",' +
        '"reason":"有日期、参与人和持续进度","keywords":["展会","同事"]}}';
      const model = new QueueLocalModel([incomplete, BIM_CREATION_ANSWER]);
      const decision = await new MultiAgentLeaderPlanner(model).plan(
        inputMessage(),
        { text: '请记在心上：2027年5月和三位同事分阶段筹备展会，后续每周跟进准备状态。' },
        actionOwnerContext(),
        1,
        (): boolean => true
      );

      expect(model.prompts.length).assertEqual(2);
      expect(decision.bimSuggestion !== undefined).assertTrue();
      expect(decision.bimContextUpdate?.dashboardItems?.length).assertEqual(1);
    });

    it('keeps a stable preference in persona memory', 0, async () => {
      const decision = await new MultiAgentLeaderPlanner(
        new QueueLocalModel([actionDecision('memory.update')])
      ).plan(
        inputMessage(),
        { text: '请记住我喜欢清淡口味，偏好少油少盐。' },
        actionOwnerContext(),
        1
      );

      expect(decision.requestedCapabilityIds.join(',')).assertEqual('memory.update');
      expect(decision.actionIntent!.allowedActionIds.join(',')).assertEqual('memory.update');
      expect(decision.bimSuggestion === undefined).assertTrue();
    });

    it('repairs an empty initial dashboard into known current state', 0, async () => {
      const prefix: string = LIVE_ANSWER_WITHOUT_REASON_CODE.substring(
        0, LIVE_ANSWER_WITHOUT_REASON_CODE.length - 1
      );
      const suggestion: string =
        ',"bimSuggestion":{"title":"可信考试","summary":"跟进四科考试进度",' +
        '"reason":"需要跨多次更新","keywords":["考试","科目","进度"]}';
      const contextPrefix: string =
        ',"bimContextUpdate":{"summary":"目标在截止日前通过四科","facts":[],' +
        '"constraints":["2027-02-28前通过4科"],"decisions":[],"entities":["可信考试"],' +
        '"timeAnchors":["2027-02-28"],"locations":[],"commitments":["持续跟进"],' +
        '"keywords":["考试","科目","进度"],"dashboardItems":';
      const empty: string = prefix + suggestion + contextPrefix + '[]}}';
      const repaired: string = prefix + suggestion + contextPrefix +
        '[{"kind":"progress","title":"通过进度","value":"0/4",' +
        '"detail":"截止 2027-02-28","status":"进行中"}]}}';
      const model = new QueueLocalModel([empty, repaired]);
      const decision = await new MultiAgentLeaderPlanner(model).plan(
        inputMessage(), { text: '持续跟进可信考试四科进度' }, planningContext(), 1,
        (): boolean => true
      );

      expect(model.prompts.length).assertEqual(2);
      expect(decision.bimContextUpdate?.dashboardItems?.length).assertEqual(1);
      expect(decision.bimContextUpdate?.dashboardItems?.[0].value).assertEqual('0/4');
    });

    it('rejects BIM metadata with an oversized summary', 0, async () => {
      const invalid: string = LIVE_ANSWER_WITHOUT_REASON_CODE.substring(
        0, LIVE_ANSWER_WITHOUT_REASON_CODE.length - 1
      ) + ',"bimSuggestion":{"title":"东京旅行","summary":"' + 'a'.repeat(2001) +
        '","reason":"later","keywords":["东京"]}}';
      const model = new QueueLocalModel([invalid, LIVE_ANSWER_WITHOUT_REASON_CODE]);
      const decision = await new MultiAgentLeaderPlanner(model).plan(
        inputMessage(), { text: '规划东京旅行' }, planningContext(), 1,
        (): boolean => true
      );

      expect(model.prompts.length).assertEqual(2);
      expect(decision.bimSuggestion === undefined).assertTrue();
    });

    it('rejects BIM metadata with an unknown key', 0, async () => {
      const invalid: string = LIVE_ANSWER_WITHOUT_REASON_CODE.substring(
        0, LIVE_ANSWER_WITHOUT_REASON_CODE.length - 1
      ) + ',"bimSuggestion":{"title":"东京旅行","summary":"八月东京一周旅行",' +
        '"reason":"later","keywords":["东京"],"extra":"not allowed"}}';
      const model = new QueueLocalModel([invalid, LIVE_ANSWER_WITHOUT_REASON_CODE]);
      const decision = await new MultiAgentLeaderPlanner(model).plan(
        inputMessage(), { text: '规划东京旅行' }, planningContext(), 1,
        (): boolean => true
      );

      expect(model.prompts.length).assertEqual(2);
      expect(decision.bimSuggestion === undefined).assertTrue();
    });

    it('rejects untrimmed BIM scalars and trim-equivalent array duplicates', 0, async () => {
      const prefix: string = LIVE_ANSWER_WITHOUT_REASON_CODE.substring(
        0, LIVE_ANSWER_WITHOUT_REASON_CODE.length - 1
      );
      const untrimmed: string = prefix +
        ',"bimSuggestion":{"title":" 东京旅行 ","summary":"八月东京一周旅行",' +
        '"reason":"later","keywords":["东京"]}}';
      const duplicate: string = prefix +
        ',"bimSuggestion":{"title":"东京旅行","summary":"八月东京一周旅行",' +
        '"reason":"later","keywords":["东京"," 东京 "]}}';
      const scalarModel = new QueueLocalModel([untrimmed, LIVE_ANSWER_WITHOUT_REASON_CODE]);
      const duplicateModel = new QueueLocalModel([duplicate, LIVE_ANSWER_WITHOUT_REASON_CODE]);

      const scalar = await new MultiAgentLeaderPlanner(scalarModel).plan(
        inputMessage(), { text: '规划东京旅行' }, planningContext(), 1,
        (): boolean => true
      );
      const array = await new MultiAgentLeaderPlanner(duplicateModel).plan(
        inputMessage(), { text: '规划东京旅行' }, planningContext(), 1,
        (): boolean => true
      );

      expect(scalarModel.prompts.length).assertEqual(2);
      expect(scalar.bimSuggestion === undefined).assertTrue();
      expect(duplicateModel.prompts.length).assertEqual(2);
      expect(array.bimSuggestion === undefined).assertTrue();
    });

    it('allows context updates only for internal BIM context turns', 0, async () => {
      const contextUpdate: string = LIVE_ANSWER_WITHOUT_REASON_CODE.substring(
        0, LIVE_ANSWER_WITHOUT_REASON_CODE.length - 1
      ) + ',"bimContextUpdate":{"summary":"东京旅行，机票待确认","facts":["八月出发"],' +
        '"constraints":["预算有限"],"decisions":[],"entities":["东京"],"timeAnchors":["八月"],' +
        '"locations":["东京"],"commitments":["筛选机票"],"keywords":["东京","机票"]}}';
      const suggestion: string = LIVE_ANSWER_WITHOUT_REASON_CODE.substring(
        0, LIVE_ANSWER_WITHOUT_REASON_CODE.length - 1
      ) + ',"bimSuggestion":{"title":"东京旅行","summary":"八月东京一周旅行",' +
        '"reason":"需要继续筛选机票","keywords":["东京","机票"]}}';
      const redundantSuggestionUpdate: string = contextUpdate.substring(
        0, contextUpdate.length - 1
      ) + ',"bimSuggestion":{"title":"东京旅行","summary":"八月东京一周旅行",' +
        '"reason":"需要继续筛选机票","keywords":["东京","机票"]}}';
      const ordinaryModel = new QueueLocalModel([contextUpdate, LIVE_ANSWER_WITHOUT_REASON_CODE]);
      const ordinary = await new MultiAgentLeaderPlanner(ordinaryModel).plan(
        inputMessage(), { text: '规划东京旅行' }, planningContext(), 1,
        (): boolean => true
      );
      const contextModel = new QueueLocalModel([suggestion, contextUpdate]);
      const updated = await new MultiAgentLeaderPlanner(contextModel).plan(
        inputMessage(), { text: '[BIM_CONTEXT] 继续规划东京旅行' }, planningContext(), 1,
        (): boolean => true
      );
      const requiredModel = new QueueLocalModel([LIVE_ANSWER_WITHOUT_REASON_CODE, contextUpdate]);
      const required = await new MultiAgentLeaderPlanner(requiredModel).plan(
        inputMessage(), { text: '[BIM_CONTEXT] 继续规划东京旅行' }, planningContext(), 1,
        (): boolean => true
      );
      const memoryModel = new QueueLocalModel([actionDecision('memory.update'), contextUpdate]);
      const memorySeparated = await new MultiAgentLeaderPlanner(memoryModel).plan(
        inputMessage(), { text: '[BIM_CONTEXT] 继续规划东京旅行' }, planningContext(), 1,
        (): boolean => true
      );
      const redundantModel = new QueueLocalModel([redundantSuggestionUpdate]);
      const redundant = await new MultiAgentLeaderPlanner(redundantModel).plan(
        inputMessage(), { text: '[BIM_CONTEXT] 继续规划东京旅行' }, planningContext(), 1,
        (): boolean => true
      );

      expect(ordinaryModel.prompts.length).assertEqual(2);
      expect(ordinary.bimContextUpdate === undefined).assertTrue();
      expect(contextModel.prompts.length).assertEqual(2);
      expect(updated.bimSuggestion === undefined).assertTrue();
      expect(updated.bimContextUpdate?.summary).assertEqual('东京旅行，机票待确认');
      expect(requiredModel.prompts.length).assertEqual(2);
      expect(required.bimContextUpdate?.summary).assertEqual('东京旅行，机票待确认');
      expect(memoryModel.prompts.length).assertEqual(2);
      expect(memorySeparated.requestedCapabilityIds.length).assertEqual(0);
      expect(memorySeparated.bimContextUpdate?.summary).assertEqual('东京旅行，机票待确认');
      expect(redundantModel.prompts.length).assertEqual(1);
      expect(redundant.bimSuggestion === undefined).assertTrue();
      expect(redundant.bimContextUpdate?.summary).assertEqual('东京旅行，机票待确认');
    });

    it('rejects an oversized registered tool catalog before calling the model', 0, async () => {
      const model = new QueueLocalModel([LIVE_ANSWER_WITHOUT_REASON_CODE]);
      const context = planningContext();
      context.tools[0].planningHint = 'x'.repeat(65000);
      let errorCode: string = '';

      try {
        await new MultiAgentLeaderPlanner(model).plan(
          inputMessage(), { text: 'hello' }, context, 1
        );
      } catch (error) {
        errorCode = error instanceof Error ? error.message : 'unknown';
      }

      expect(errorCode).assertEqual('LEADER_TOOL_CATALOG_LIMIT');
      expect(model.prompts.length).assertEqual(0);
    });

    it('rejects oversized persona context before calling the model', 0, async () => {
      const model = new QueueLocalModel([LIVE_ANSWER_WITHOUT_REASON_CODE]);
      const context = planningContext();
      context.personas[0].memory = 'x'.repeat(100001);
      let errorCode: string = '';

      try {
        await new MultiAgentLeaderPlanner(model).plan(
          inputMessage(), { text: 'hello' }, context, 1
        );
      } catch (error) {
        errorCode = error instanceof Error ? error.message : 'unknown';
      }

      expect(errorCode).assertEqual('LEADER_PROMPT_LIMIT');
      expect(model.prompts.length).assertEqual(0);
    });

    it('bounds the repair prompt after an initially valid-sized model call', 0, async () => {
      const baselineModel = new QueueLocalModel([LIVE_ANSWER_WITHOUT_REASON_CODE]);
      await new MultiAgentLeaderPlanner(baselineModel).plan(
        inputMessage(), { text: 'hello' }, planningContext(), 1
      );
      const context = planningContext();
      context.personas[0].memory += 'x'.repeat(99900 - baselineModel.prompts[0].length);
      const model = new QueueLocalModel([MISSING_PERSONA_DECISION, LIVE_ANSWER_WITHOUT_REASON_CODE]);
      let errorCode: string = '';

      try {
        await new MultiAgentLeaderPlanner(model).plan(
          inputMessage(), { text: 'hello' }, context, 1, (): boolean => true
        );
      } catch (error) {
        errorCode = error instanceof Error ? error.message : 'unknown';
      }

      expect(model.prompts[0].length).assertLess(100001);
      expect(errorCode).assertEqual('LEADER_PROMPT_LIMIT');
      expect(model.prompts.length).assertEqual(1);
    });

    it('normalizes every registered same-round dependency to the exact producer without another model call', 0, async () => {
      const sources: string[] = [
        'maps.place.search',
        'mail.search',
        'gmail.mail.search'
      ];
      const consumers: string[] = [
        'maps.place.details',
        'mail.thread.read',
        'gmail.thread.read'
      ];
      for (let index = 0; index < sources.length; index++) {
        let invalid = sameRoundDependencyDecision(
          sources[index], consumers[index], '{}', index === 0
        );
        if (index === 0) {
          invalid = invalid.replace(
            '"requestedCapabilityIds":["maps.place.search","maps.place.details"]',
            '"requestedCapabilityIds":["maps.place.search","maps.place.details","memory.update"]'
          ).replace(
            '],"uiIntent":',
            '],"actionIntent":{"goal":"remember source","allowedActionIds":["memory.update"]},"uiIntent":'
          );
        }
        const model = new QueueLocalModel([invalid]);
        const decision = await new MultiAgentLeaderPlanner(model).plan(
          inputMessage(), { text: 'read source then dependent detail' }, planningContext(), 1,
          (): boolean => true
        );

        expect(decision.requestedCapabilityIds.join(',')).assertEqual(
          index === 0 ? sources[index] + ',memory.update' : sources[index]
        );
        expect(decision.dataTasks.length).assertEqual(1);
        expect(decision.dataTasks[0].localId).assertEqual('source');
        expect(decision.dataTasks[0].goal).assertEqual('read source');
        expect(decision.dataTasks[0].allowedToolIds.join(',')).assertEqual(sources[index]);
        expect(decision.dataTasks[0].toolId).assertEqual(sources[index]);
        expect(JSON.stringify(decision.dataTasks[0].input)).assertEqual('{}');
        expect(decision.dataTasks[0].required).assertTrue();
        expect(decision.personaId).assertEqual('travel_companion');
        expect(decision.skillId).assertEqual('');
        expect(decision.reasonCode).assertEqual('dependency_requires_next_round');
        expect(decision.uiIntent.purpose).assertEqual('read source and dependent detail');
        expect(decision.uiIntent.preferredDensity).assertEqual('comfortable');
        expect(decision.uiIntent.requiredSections.join(',')).assertEqual('source,detail');
        if (index === 0) {
          expect(decision.actionIntent!.goal).assertEqual('remember source');
          expect(decision.actionIntent!.allowedActionIds.join(',')).assertEqual('memory.update');
        } else {
          expect(decision.actionIntent === undefined).assertTrue();
        }
        expect(model.prompts.length).assertEqual(1);
        expect(model.prompts[0].indexOf(
          'requestedCapabilityIds is the exact current-round execution union'
        )).assertLarger(-1);
        expect(model.prompts[0].indexOf(
          'For dependent serial tools, emit exactly one data task in this planning round.\n' +
          'Wait for its Observation, then emit the next task with args derived from that real output.\n' +
          'Never pre-fill placeId, eventId, threadId, messageId, orderId, or provider receipt.'
        )).assertLarger(-1);
      }
    });

    it('retains independent Data tasks while dropping only the real same-round consumer', 0, async () => {
      const model = new QueueLocalModel([
        sameRoundMapsWithFood(true, '["food.search"]')
      ]);
      const decision = await new MultiAgentLeaderPlanner(model).plan(
        inputMessage(), { text: 'search then details and food' }, planningContext(), 1,
        (): boolean => true
      );

      expect(decision.requestedCapabilityIds.join(',')).assertEqual('maps.place.search,food.search');
      expect(decision.dataTasks.length).assertEqual(2);
      expect(decision.dataTasks[0].localId).assertEqual('source');
      expect(decision.dataTasks[0].toolId).assertEqual('maps.place.search');
      expect(decision.dataTasks[1].localId).assertEqual('food');
      expect(decision.dataTasks[1].goal).assertEqual('search food');
      expect(decision.dataTasks[1].allowedToolIds.join(',')).assertEqual('food.search');
      expect(JSON.stringify(decision.dataTasks[1].input)).assertEqual('{"query":"coffee"}');
      expect(decision.dataTasks[1].required).assertFalse();
      expect(model.prompts.length).assertEqual(1);
    });

    it('drops every same-round consumer with a hostile explicit entity input', 0, async () => {
      const sources: string[] = [
        'maps.place.search',
        'mail.search',
        'gmail.mail.search'
      ];
      const consumers: string[] = [
        'maps.place.details',
        'mail.thread.read',
        'gmail.thread.read'
      ];
      const inputs: string[] = [
        '{"placeId":"place-explicit"}',
        '{"threadId":"thread-explicit"}',
        '{"threadId":"gmail-thread-explicit"}'
      ];
      for (let index = 0; index < sources.length; index++) {
        const decision = await new MultiAgentLeaderPlanner(new QueueLocalModel([
          sameRoundDependencyDecision(sources[index], consumers[index], inputs[index])
        ])).plan(inputMessage(), { text: 'search then details' }, planningContext(), 1,
          (): boolean => true);
        expect(decision.requestedCapabilityIds.join(',')).assertEqual(sources[index]);
        expect(decision.dataTasks.length).assertEqual(1);
        expect(decision.dataTasks[0].toolId).assertEqual(sources[index]);
        expect(decision.reasonCode).assertEqual('dependency_requires_next_round');
      }
    });

    it('drops mail consumers with a hostile supplied provider', 0, async () => {
      const sources: string[] = ['mail.search', 'gmail.mail.search'];
      const consumers: string[] = ['mail.thread.read', 'gmail.thread.read'];
      const providerInputs: string[] = [
        '{"provider":"qq"}',
        '{"provider":7}',
        '{"provider":null}',
        '{"provider":{}}'
      ];
      for (let sourceIndex = 0; sourceIndex < sources.length; sourceIndex++) {
        for (let inputIndex = 0; inputIndex < providerInputs.length; inputIndex++) {
          const decision = await new MultiAgentLeaderPlanner(new QueueLocalModel([
            sameRoundDependencyDecision(
              sources[sourceIndex],
              consumers[sourceIndex],
              providerInputs[inputIndex]
            )
          ])).plan(inputMessage(), { text: 'search then details' }, planningContext(), 1,
            (): boolean => true);
          expect(decision.requestedCapabilityIds.join(',')).assertEqual(sources[sourceIndex]);
          expect(decision.dataTasks.length).assertEqual(1);
          expect(decision.dataTasks[0].toolId).assertEqual(sources[sourceIndex]);
        }
      }
    });

    it('normalizes mail and Gmail consumers only when provider and entities are blank or absent', 0, async () => {
      const sources: string[] = ['mail.search', 'gmail.mail.search'];
      const consumers: string[] = ['mail.thread.read', 'gmail.thread.read'];
      const emptyInputs: string[] = [
        '{}',
        '{"provider":"  ","threadId":"","messageId":"","requestKey":""}'
      ];
      for (let sourceIndex = 0; sourceIndex < sources.length; sourceIndex++) {
        for (let inputIndex = 0; inputIndex < emptyInputs.length; inputIndex++) {
          const model = new QueueLocalModel([
            sameRoundDependencyDecision(
              sources[sourceIndex],
              consumers[sourceIndex],
              emptyInputs[inputIndex]
            )
          ]);
          const decision = await new MultiAgentLeaderPlanner(model).plan(
            inputMessage(), { text: 'read source then details' }, planningContext(), 1,
            (): boolean => true
          );
          expect(decision.requestedCapabilityIds.join(',')).assertEqual(sources[sourceIndex]);
          expect(decision.dataTasks.length).assertEqual(1);
          expect(decision.dataTasks[0].toolId).assertEqual(sources[sourceIndex]);
          expect(model.prompts.length).assertEqual(1);
        }
      }
    });

    it('drops every same-round Maps consumer when one carries a forged placeId', 0, async () => {
      const decision = await new MultiAgentLeaderPlanner(new QueueLocalModel([
        sameRoundDependencyDecisionWithConsumers(
          'maps.place.search',
          'maps.place.details',
          ['{}', '{"placeId":"place-explicit"}']
        )
      ])).plan(inputMessage(), { text: 'search then details' }, planningContext(), 1,
        (): boolean => true);
      expect(decision.requestedCapabilityIds.join(',')).assertEqual('maps.place.search');
      expect(decision.dataTasks.length).assertEqual(1);
      expect(decision.dataTasks[0].toolId).assertEqual('maps.place.search');
    });

    it('keeps direct Maps details available without a same-round producer', 0, async () => {
      const model = new QueueLocalModel([
        directDependencyConsumerDecision('maps.place.details', '{"placeId":"place-explicit"}')
      ]);
      const decision = await new MultiAgentLeaderPlanner(model).plan(
        inputMessage(), { text: 'show the selected place details' }, planningContext(), 1,
        (): boolean => true
      );

      expect(decision.requestedCapabilityIds.join(',')).assertEqual('maps.place.details');
      expect(decision.dataTasks.length).assertEqual(1);
      expect(decision.dataTasks[0].localId).assertEqual('direct-detail');
      expect(decision.dataTasks[0].toolId).assertEqual('maps.place.details');
      expect(JSON.stringify(decision.dataTasks[0].input)).assertEqual('{"placeId":"place-explicit"}');
      expect(model.prompts.length).assertEqual(1);
    });

    it('does not normalize an allowlist-only dependent consumer', 0, async () => {
      expect(await sameRoundDependencyError(
        sameRoundMapsWithFood(false, '["food.search","maps.place.details"]')
      )).assertEqual('LEADER_SAME_ROUND_DEPENDENCY');
    });

    it('fails closed when an unrelated retained task advertises the dependent consumer', 0, async () => {
      expect(await sameRoundDependencyError(
        sameRoundMapsWithFood(true, '["food.search","maps.place.details"]')
      )).assertEqual('LEADER_SAME_ROUND_DEPENDENCY');
    });

    it('does not consume a queued consumer-only or mutated dependency repair', 0, async () => {
      const invalid = sameRoundDependencyDecision(
        'maps.place.search', 'maps.place.details', '{}'
      );
      const exact = producerOnlyRepairDecision('maps.place.search');
      const changed: string[] = [
        exact.replace('"localId":"source"', '"localId":"changed-source"'),
        exact.replace('"goal":"read source"', '"goal":"changed goal"'),
        exact.replace('"input":{}', '"input":{"query":"forged"}'),
        exact.replace('"required":true', '"required":false'),
        exact.replace('"personaId":"travel_companion"', '"personaId":"unknown-persona"'),
        exact.replace('"skillId":""', '"skillId":"travel-planning"'),
        exact.replace(
          '"purpose":"read source and dependent detail"',
          '"purpose":"changed purpose"'
        ),
        exact.replace('"roundAction":"execute"', '"roundAction":"answer"')
          .replace('"dataTasks":[', '"answer":"changed","dataTasks":['),
        producerOnlyRepairDecision('travel.search'),
        exact.replace(
          '"requestedCapabilityIds":["maps.place.search"]',
          '"requestedCapabilityIds":["maps.place.search","memory.update"]'
        ).replace(
          ',"uiIntent":',
          ',"actionIntent":{"goal":"changed action","allowedActionIds":["memory.update"]},"uiIntent":'
        )
      ];
      for (let index = 0; index < changed.length; index++) {
        const model = new QueueLocalModel([invalid, changed[index]]);
        const decision = await new MultiAgentLeaderPlanner(model).plan(
          inputMessage(), { text: 'search then details' }, planningContext(), 1,
          (): boolean => true
        );
        expect(decision.requestedCapabilityIds.join(',')).assertEqual('maps.place.search');
        expect(decision.dataTasks.length).assertEqual(1);
        expect(decision.dataTasks[0].localId).assertEqual('source');
        expect(decision.dataTasks[0].goal).assertEqual('read source');
        expect(decision.dataTasks[0].toolId).assertEqual('maps.place.search');
        expect(JSON.stringify(decision.dataTasks[0].input)).assertEqual('{}');
        expect(decision.personaId).assertEqual('travel_companion');
        expect(decision.skillId).assertEqual('');
        expect(decision.uiIntent.purpose).assertEqual('read source and dependent detail');
        expect(model.prompts.length).assertEqual(1);
      }
    });

    it('fails closed without a repair call when producer metadata also advertises the consumer', 0, async () => {
      const invalid = sameRoundDependencyDecision(
        'maps.place.search', 'maps.place.details', '{"placeId":"place-forged"}'
      ).replace(
        '"allowedToolIds":["maps.place.search"]',
        '"allowedToolIds":["maps.place.search","maps.place.details"]'
      );
      const model = new QueueLocalModel([invalid]);
      let errorCode: string = '';

      try {
        await new MultiAgentLeaderPlanner(model).plan(
          inputMessage(), { text: 'search then details' }, planningContext(), 1,
          (): boolean => true
        );
      } catch (error) {
        errorCode = error instanceof Error ? error.message : 'unknown';
      }

      expect(errorCode).assertEqual('LEADER_SAME_ROUND_DEPENDENCY');
      expect(model.prompts.length).assertEqual(1);
    });

    it('keeps direct details with an explicit ID and independent flight train tasks valid', 0, async () => {
      const direct = await new MultiAgentLeaderPlanner(
        new QueueLocalModel([MAP_DETAILS_DECISION])
      ).plan(inputMessage(), { text: 'place-real-1 的详情' }, planningContext(), 1);
      const parallel = await new MultiAgentLeaderPlanner(
        new QueueLocalModel([PARALLEL_DECISION])
      ).plan(inputMessage(), { text: '查航班和高铁' }, planningContext(), 1);

      expect(direct.dataTasks.length).assertEqual(1);
      expect(direct.dataTasks[0].toolId).assertEqual('maps.place.details');
      expect(parallel.dataTasks.length).assertEqual(2);
      expect(parallel.dataTasks[0].toolId).assertEqual('flight.search');
      expect(parallel.dataTasks[1].toolId).assertEqual('train.search');
    });

    it('rejects a model decision that exceeds the per-round Data task budget', 0, async () => {
      const model = new QueueLocalModel([manyTravelDecision(33)]);
      let errorCode: string = '';

      try {
        await new MultiAgentLeaderPlanner(model).plan(
          inputMessage(), { text: '查询很多来源' }, planningContext(), 1
        );
      } catch (error) {
        errorCode = error instanceof Error ? error.message : 'unknown';
      }

      expect(errorCode).assertEqual('LEADER_DATA_TASK_LIMIT');
      expect(model.prompts.length).assertEqual(1);
    });
    it('parses one exact registry-bound LeaderDecision and includes round context', 0, async () => {
      const model: QueueLocalModel = new QueueLocalModel([PARALLEL_DECISION]);
      const planner: MultiAgentLeaderPlanner = new MultiAgentLeaderPlanner(model);
      const input: InputUserPayload = {
        text: '查航班和高铁',
        previousPersonaId: 'travel_companion',
        recentObservations: []
      };

      const decision: LeaderDecision = await planner.plan(inputMessage(), input, planningContext(), 1);

      expect(decision.personaId).assertEqual('travel_companion');
      expect(decision.reasonCode).assertEqual('host_execute');
      expect(decision.dataTasks.length).assertEqual(2);
      expect(decision.dataTasks[0].toolId).assertEqual('flight.search');
      expect(decision.dataTasks[1].toolId).assertEqual('train.search');
      expect(model.prompts[0].indexOf('Round: 1') >= 0).assertTrue();
      expect(model.prompts[0].indexOf('flight.search') >= 0).assertTrue();
      expect(model.prompts[0].indexOf('travel_companion') >= 0).assertTrue();
      expect(model.systemPrompts[0].indexOf('exactly one JSON object') >= 0).assertTrue();
      expect(model.systemPrompts[0].indexOf('Do not include Thought') >= 0).assertTrue();
      expect(model.systemPrompts[0].indexOf('markdown') >= 0).assertTrue();
      expect(model.systemPrompts[0].indexOf('Omit reasonCode') >= 0).assertTrue();
      expect(model.systemPrompts[0].indexOf(
        'When included, emit every core bimContextUpdate schema field and dashboardItems'
      ) >= 0).assertTrue();
      expect(model.prompts[0].indexOf('Omit reasonCode') >= 0).assertTrue();
      expect(model.prompts[0].indexOf('"reasonCode":"string"')).assertEqual(-1);
      expect(model.systemPrompts[0].indexOf(
        'For roundAction answer or clarify, include answer as a non-empty string. ' +
          'For roundAction execute, omit answer.'
      ) >= 0).assertTrue();
      expect(model.prompts[0].indexOf(
        'For roundAction answer or clarify, include answer as a non-empty string. ' +
          'For roundAction execute, omit answer.'
      ) >= 0).assertTrue();
    });

    it('preserves the locked first-round persona and skill in later-round prompt and decision', 0, async () => {
      const model = new LockedSelectionPromptAwareModel();
      const context = planningContext();
      context.personas.push({
        personaId: 'default_companion',
        name: 'Default Companion',
        soul: 'General conversation.',
        memory: '',
        previous: false,
        activeSkills: []
      });
      context.lockedPersonaId = 'travel_companion';
      context.lockedSkillId = '';

      const decision = await new MultiAgentLeaderPlanner(model).plan(
        inputMessage(),
        completedTravelInput(),
        context,
        2
      );

      expect(decision.personaId).assertEqual('travel_companion');
      expect(decision.skillId).assertEqual('');
      expect(model.prompts.length).assertEqual(1);
    });

    it('rejects a later-round persona switch and clearing a locked skill to bypass its capability set', 0,
      async () => {
        const personaSwitchContext = planningContext();
        personaSwitchContext.personas.push({
          personaId: 'default_companion',
          name: 'Default Companion',
          soul: 'General conversation.',
          memory: '',
          previous: false,
          activeSkills: []
        });
        personaSwitchContext.lockedPersonaId = 'travel_companion';
        personaSwitchContext.lockedSkillId = '';
        const switched = ANSWER_FROM_TRAVEL_OBSERVATION.replace(
          '"personaId":"travel_companion"',
          '"personaId":"default_companion"'
        );
        let personaError: string = '';
        try {
          await new MultiAgentLeaderPlanner(new QueueLocalModel([switched])).plan(
            inputMessage(), completedTravelInput(), personaSwitchContext, 2
          );
        } catch (error) {
          personaError = error instanceof Error ? error.message : 'unknown';
        }

        const skillBypassContext = planningContext();
        skillBypassContext.lockedPersonaId = 'travel_companion';
        skillBypassContext.lockedSkillId = 'travel-planning';
        let skillError: string = '';
        try {
          await new MultiAgentLeaderPlanner(new QueueLocalModel([SOCIAL_ONLY_DECISION])).plan(
            inputMessage(), { text: '帮我查看我今天 X 和 Slack 上的消息' },
            skillBypassContext, 2
          );
        } catch (error) {
          skillError = error instanceof Error ? error.message : 'unknown';
        }

        expect(personaError).assertEqual('LEADER_PERSONA_SKILL_SWITCH');
        expect(skillError).assertEqual('LEADER_PERSONA_SKILL_SWITCH');
      });

    it('carries the old hotel date and anti-invention contract in the shared prompt', 0, async () => {
      const model: QueueLocalModel = new QueueLocalModel([PARALLEL_DECISION]);
      const planner: MultiAgentLeaderPlanner = new MultiAgentLeaderPlanner(
        model,
        (): string => '2026-07-21'
      );
      const input: InputUserPayload = { text: '8月15日深圳住两晚的酒店' };

      await planner.plan(inputMessage(), input, planningContext(), 1);

      expect(model.prompts[0].indexOf('Current local date: 2026-07-21') >= 0).assertTrue();
      expect(model.prompts[0].indexOf('originQuery, place, placeType, countryCode') >= 0).assertTrue();
      expect(model.prompts[0].indexOf('Do not invent missing destination, date, year, guest') >= 0).assertTrue();
      expect(model.prompts[0].indexOf('Preserve originQuery exactly') >= 0).assertTrue();
    });

    it('keeps aggregate media and dependent Maps rounds explicit in the Leader prompt', 0, async () => {
      const model: QueueLocalModel = new QueueLocalModel([PARALLEL_DECISION]);
      await new MultiAgentLeaderPlanner(model).plan(
        inputMessage(),
        { text: '查看今天的人工智能新闻和讨论' },
        planningContext(),
        1
      );

      expect(model.prompts[0].indexOf(
        'A request for both 新闻 and 讨论 about the same topic uses exactly media.aggregate.search'
      ) >= 0).assertTrue();
      expect(model.prompts[0].indexOf(
        'In round 1 requestedCapabilityIds is exactly ["maps.place.search"]'
      ) >= 0).assertTrue();
    });

    it('lets the model distinguish aggregate travel explicit modes and an explicit pair', 0, async () => {
      const model: TravelPromptAwareModel = new TravelPromptAwareModel();
      const planner: MultiAgentLeaderPlanner = new MultiAgentLeaderPlanner(model);
      const c02Text: string = '我明天要从北京去上海，帮我搜索出行方案';
      const c02Input: InputUserPayload = { text: c02Text };
      const c02Message: AgentMessage = {
        type: AgentMessageType.INPUT_USER,
        conversationId: 'conversation-c02',
        turnId: 'turn-c02',
        taskId: 'input-c02',
        payload: c02Input
      };

      const c02: LeaderDecision = await planner.plan(c02Message, c02Input, planningContext(), 1);
      const flight: LeaderDecision = await planner.plan(
        inputMessage(),
        { text: '帮我查明天北京到上海的航班' },
        planningContext(),
        1
      );
      const train: LeaderDecision = await planner.plan(
        inputMessage(),
        { text: '帮我查询明天晚上六点以后深圳北到香港西九龙的高铁' },
        planningContext(),
        1
      );
      const both: LeaderDecision = await planner.plan(
        inputMessage(),
        { text: '查明天北京到上海的航班和高铁' },
        planningContext(),
        1
      );
      const comparisonPair: LeaderDecision = await planner.plan(
        inputMessage(),
        { text: '比较明天北京到上海的航班和高铁' },
        planningContext(),
        1
      );

      expect(c02.dataTasks.length).assertEqual(1);
      expect(c02.dataTasks[0].toolId).assertEqual('travel.search');
      const c02Args = c02.dataTasks[0].input as Record<string, Object | string | number | boolean>;
      expect(c02Args['date']).assertEqual('明天');
      expect(c02Args['query']).assertEqual(c02Text);
      expect(flight.dataTasks.length).assertEqual(1);
      expect(flight.dataTasks[0].toolId).assertEqual('flight.search');
      expect(train.dataTasks.length).assertEqual(1);
      expect(train.dataTasks[0].toolId).assertEqual('train.search');
      expect(both.dataTasks.length).assertEqual(2);
      expect(both.dataTasks[0].toolId).assertEqual('flight.search');
      expect(both.dataTasks[1].toolId).assertEqual('train.search');
      expect(comparisonPair.dataTasks.length).assertEqual(2);
      expect(comparisonPair.dataTasks[0].toolId).assertEqual('flight.search');
      expect(comparisonPair.dataTasks[1].toolId).assertEqual('train.search');
    });

    it('lets the model select C10/C11 public posts messages coffee preferences and Luckin orders', 0,
      async () => {
      const model = new C10C11PromptAwareModel();
      const planner = new MultiAgentLeaderPlanner(model);
      const context = c10C11Context();
      const publicPosts = await planner.plan(
        inputMessage(),
        { text: '帮我查看 X 上 OpenAI 最近的公开 post' },
        context,
        1
      );
      const messages = await planner.plan(
        inputMessage(),
        { text: '帮我查看我今天 X 和 Slack 上的消息' },
        context,
        1
      );
      const genericCoffee = await planner.plan(
        inputMessage(),
        { text: '点一杯咖啡' },
        context,
        1
      );
      const preferenceTexts: string[] = [
        '我只喝瑞幸咖啡',
        '以后只喝燕麦拿铁',
        '请记住我只喝美式咖啡'
      ];
      for (let index = 0; index < preferenceTexts.length; index++) {
        const preference = await planner.plan(
          inputMessage(),
          { text: preferenceTexts[index] },
          context,
          1
        );
        expect(preference.dataTasks.length).assertEqual(0);
        expect(preference.actionIntent!.allowedActionIds.join(',')).assertEqual('memory.update');
      }
      const luckinOrder = await planner.plan(
        inputMessage(),
        { text: '帮我点一杯瑞幸生椰拿铁，半糖少冰' },
        context,
        1
      );

      expect(publicPosts.dataTasks[0].toolId).assertEqual('x.post.search');
      expect(messages.dataTasks[0].toolId).assertEqual('social.feed.search');
      expect(genericCoffee.dataTasks[0].toolId).assertEqual('food.search');
      expect(luckinOrder.dataTasks.length).assertEqual(0);
      expect(luckinOrder.actionIntent!.allowedActionIds.join(',')).assertEqual('luckin.order.preview');
      expect(model.prompts[0].indexOf('C10/C11 selection contract:')).assertLarger(-1);
    });

    it('asks the Leader model once to correct an explicit Google Maps selection without host rewriting', 0,
      async () => {
      const model = new QueueLocalModel([
        EXPLICIT_GOOGLE_MAPS_AS_FOOD_DECISION,
        EXPLICIT_GOOGLE_MAPS_DECISION
      ]);
      const decision = await new MultiAgentLeaderPlanner(model).plan(
        inputMessage(),
        { text: '请用 Google Maps 查伦敦国王十字车站附近的中餐' },
        planningContext(),
        1,
        (): boolean => true
      );

      expect(decision.requestedCapabilityIds.join(',')).assertEqual('maps.place.search');
      expect(decision.dataTasks.length).assertEqual(1);
      expect(decision.dataTasks[0].toolId).assertEqual('maps.place.search');
      expect(decision.dataTasks[0].allowedToolIds.join(',')).assertEqual('maps.place.search');
      expect(model.prompts.length).assertEqual(2);
      expect(model.prompts[1].indexOf('LEADER_EXPLICIT_MAPS_SELECTION') >= 0).assertTrue();
      expect(model.prompts[1].indexOf(EXPLICIT_GOOGLE_MAPS_AS_FOOD_DECISION) >= 0).assertTrue();
    });

    it('accepts the device C04 Maps repair with one redundant terminal object closure', 0, async () => {
      const model = new QueueLocalModel([DEVICE_C04_FOOD_DECISION, DEVICE_C04_MAPS_REPAIR]);
      const context = planningContext();
      context.personas.push({
        personaId: 'food_companion',
        name: 'Food Companion',
        soul: 'Use registered food tools only.',
        memory: '',
        previous: false,
        activeSkills: []
      });
      context.personas.push({
        personaId: 'default_companion',
        name: 'Default Companion',
        soul: 'Use registered tools only.',
        memory: '',
        previous: false,
        activeSkills: []
      });

      const decision = await new MultiAgentLeaderPlanner(model).plan(
        inputMessage(),
        { text: '帮我用 Google Maps 搜索伦敦国王十字车站附近的中餐' },
        context,
        1,
        (): boolean => true
      );

      expect(decision.requestedCapabilityIds.join(',')).assertEqual('maps.place.search');
      expect(decision.dataTasks[0].toolId).assertEqual('maps.place.search');
      expect(model.prompts.length).assertEqual(2);
    });

    it('fails closed when the one explicit Google Maps correction is still food search', 0, async () => {
      const model = new QueueLocalModel([
        EXPLICIT_GOOGLE_MAPS_AS_FOOD_DECISION,
        EXPLICIT_GOOGLE_MAPS_AS_FOOD_DECISION,
        EXPLICIT_GOOGLE_MAPS_DECISION
      ]);
      let errorCode: string = '';

      try {
        await new MultiAgentLeaderPlanner(model).plan(
          inputMessage(),
          { text: '请用谷歌地图查伦敦国王十字车站附近的中餐' },
          planningContext(),
          1,
          (): boolean => true
        );
      } catch (error) {
        errorCode = error instanceof Error ? error.message : 'unknown';
      }

      expect(errorCode).assertEqual('LEADER_EXPLICIT_MAPS_SELECTION');
      expect(model.prompts.length).assertEqual(2);
    });

    it('asks the Leader model once to remove only premature Maps details scope', 0, async () => {
      const model = new QueueLocalModel([
        PREMATURE_GOOGLE_MAPS_DETAILS_DECISION,
        EXPLICIT_GOOGLE_MAPS_DECISION
      ]);
      const decision = await new MultiAgentLeaderPlanner(model).plan(
        inputMessage(),
        { text: '先用 Google Maps 搜索国王十字车站，再用真实 placeId 查询详情' },
        planningContext(),
        1,
        (): boolean => true
      );

      expect(decision.requestedCapabilityIds.join(',')).assertEqual('maps.place.search');
      expect(decision.dataTasks[0].toolId).assertEqual('maps.place.search');
      expect(model.prompts.length).assertEqual(2);
      expect(model.prompts[1].indexOf('LEADER_PREMATURE_MAPS_DETAILS') >= 0).assertTrue();
    });

    it('continues planning when the Leader model says the current tool round is incomplete', 0, async () => {
      const model = new QueueLocalModel([PLANNING_INCOMPLETE_GOOGLE_MAPS_DECISION]);
      const decision = await new MultiAgentLeaderPlanner(model).plan(
        inputMessage(),
        { text: '请用 Google Maps 找到伦敦国王十字车站并展示完整地点信息' },
        planningContext(),
        1,
        (): boolean => true
      );

      expect(decision.reasonCode).assertEqual('dependency_requires_next_round');
    });

    it('repairs a missing continuation mode instead of treating the round as complete', 0, async () => {
      const missingMode: string = PLANNING_INCOMPLETE_GOOGLE_MAPS_DECISION.replace(
        '"continuationMode":"dependency",',
        ''
      );
      const model = new QueueLocalModel([
        missingMode,
        PLANNING_INCOMPLETE_GOOGLE_MAPS_DECISION
      ]);
      const decision = await new MultiAgentLeaderPlanner(model).plan(
        inputMessage(),
        { text: '请用 Google Maps 找到伦敦国王十字车站并展示完整地点信息' },
        planningContext(),
        1,
        (): boolean => true
      );

      expect(decision.reasonCode).assertEqual('dependency_requires_next_round');
      expect(model.prompts.length).assertEqual(2);
    });

    it('keeps tool scope closed while preserving an explicitly requested parallel domain', 0, async () => {
      const socialModel = new RequestScopePromptAwareModel();
      const explicitMultiModel = new RequestScopePromptAwareModel();
      const workPersonaModel = new RequestScopePromptAwareModel();
      const workContext = planningContext();
      workContext.personas[0].name = 'Work Assistant';
      workContext.personas[0].soul = 'Help with work messages and mail.';
      workContext.personas[0].memory = 'The user often reads work email.';
      workContext.personas[0].activeSkills[0].skillId = 'work-assistant';
      workContext.personas[0].activeSkills[0].description = 'Manage work communication';
      workContext.personas[0].activeSkills[0].instructions = 'Use mail tools for email.';

      const social = await new MultiAgentLeaderPlanner(socialModel).plan(
        inputMessage(),
        { text: '帮我查看我今天 X 和 Slack 上的消息' },
        planningContext(),
        1
      );
      const explicitMulti = await new MultiAgentLeaderPlanner(explicitMultiModel).plan(
        inputMessage(),
        { text: '同时查看 X、Slack 和邮件' },
        planningContext(),
        1
      );
      const workPersona = await new MultiAgentLeaderPlanner(workPersonaModel).plan(
        inputMessage(),
        { text: '帮我查看我今天 X 和 Slack 上的消息' },
        workContext,
        1
      );

      expect(social.dataTasks.length).assertEqual(1);
      expect(social.dataTasks[0].toolId).assertEqual('social.feed.search');
      expect(workPersona.dataTasks.length).assertEqual(1);
      expect(workPersona.dataTasks[0].toolId).assertEqual('social.feed.search');
      expect(explicitMulti.dataTasks.length).assertEqual(2);
      expect(explicitMulti.dataTasks[0].toolId).assertEqual('social.feed.search');
      expect(explicitMulti.dataTasks[1].toolId).assertEqual('mail.search');
      expect(socialModel.prompts.length).assertEqual(1);
      expect(explicitMultiModel.prompts.length).assertEqual(1);
      expect(workPersonaModel.prompts.length).assertEqual(1);
    });

    it('fails closed when C07 overlap repair would remove requested capability scope', 0, async () => {
      const model = new QueueLocalModel([
        OVERLAPPING_VIDEO_DECISION,
        AGGREGATE_VIDEO_DECISION
      ]);
      let errorCode: string = '';
      try {
        await new MultiAgentLeaderPlanner(model).plan(
          inputMessage(),
          { text: '帮我在 B 站和 YouTube 里搜索 Qwen 的官方视频' },
          planningContext(),
          1,
          (): boolean => true
        );
      } catch (error) {
        errorCode = error instanceof Error ? error.message : 'unknown';
      }

      expect(errorCode).assertEqual('LEADER_REPAIR_SCOPE_INVALID');
      expect(model.prompts.length).assertEqual(2);
      expect(model.prompts[0].indexOf(
        'YouTube and Bilibili means exactly one media.video.search Data task'
      ) >= 0).assertTrue();
      expect(model.prompts[1].indexOf('LEADER_OVERLAPPING_VIDEO_TOOLS') >= 0).assertTrue();
    });

    it('fails closed when the one video overlap repair still overlaps', 0, async () => {
      const model = new QueueLocalModel([
        OVERLAPPING_VIDEO_DECISION,
        OVERLAPPING_VIDEO_DECISION,
        AGGREGATE_VIDEO_DECISION
      ]);
      let errorCode: string = '';

      try {
        await new MultiAgentLeaderPlanner(model).plan(
          inputMessage(),
          { text: '帮我在 B 站和 YouTube 里搜索 Qwen 的官方视频' },
          planningContext(),
          1,
          (): boolean => true
        );
      } catch (error) {
        errorCode = error instanceof Error ? error.message : 'unknown';
      }

      expect(errorCode).assertEqual('LEADER_OVERLAPPING_VIDEO_TOOLS');
      expect(model.prompts.length).assertEqual(2);
    });

    it('keeps YouTube-only Bilibili-only and unrelated parallel decisions valid', 0, async () => {
      const youtubeModel = new QueueLocalModel([YOUTUBE_ONLY_DECISION]);
      const bilibiliModel = new QueueLocalModel([BILIBILI_ONLY_DECISION]);
      const parallelModel = new QueueLocalModel([PARALLEL_DECISION]);

      const youtube = await new MultiAgentLeaderPlanner(youtubeModel).plan(
        inputMessage(), { text: '帮我在 YouTube 搜世界杯视频' }, planningContext(), 1
      );
      const bilibili = await new MultiAgentLeaderPlanner(bilibiliModel).plan(
        inputMessage(), { text: '帮我在 B 站搜 Qwen 视频' }, planningContext(), 1
      );
      const parallel = await new MultiAgentLeaderPlanner(parallelModel).plan(
        inputMessage(), { text: '查航班和高铁' }, planningContext(), 1
      );

      expect(youtube.dataTasks[0].toolId).assertEqual('youtube.video.search');
      expect(bilibili.dataTasks[0].toolId).assertEqual('media.video.search');
      expect(parallel.dataTasks.length).assertEqual(2);
      expect(youtubeModel.prompts.length).assertEqual(1);
      expect(bilibiliModel.prompts.length).assertEqual(1);
      expect(parallelModel.prompts.length).assertEqual(1);
    });

    it('tells later rounds not to repeat completed tools while allowing a different dependent tool', 0, async () => {
      const terminalStatuses: string[] = ['success', 'partial', 'empty', 'error'];
      for (let index = 0; index < terminalStatuses.length; index++) {
        const model: ObservationPromptAwareModel = new ObservationPromptAwareModel();
        const planner: MultiAgentLeaderPlanner = new MultiAgentLeaderPlanner(model);
        const input: InputUserPayload = {
          text: '根据上一轮结果继续回答',
          recentObservations: [{
            taskId: 'input-1:round-1:travel',
            toolId: 'travel.search',
            status: terminalStatuses[index],
            summary: '真实出行结果',
            entityRefs: ['travel-real-1']
          }, {
            taskId: 'older-input:round-1:flight',
            toolId: 'flight.search',
            status: 'success',
            summary: '旧 turn 结果',
            entityRefs: ['flight-old-1']
          }]
        };

        const decision: LeaderDecision = await planner.plan(
          inputMessage(), input, planningContext(), 2
        );

        expect(decision.roundAction).assertEqual('answer');
        expect(decision.dataTasks.length).assertEqual(0);
        expect(model.prompts[0].indexOf(
          'Current-turn completed Data tool IDs: ["travel.search"]'
        ) >= 0).assertTrue();
        expect(model.prompts[0].indexOf(
          'Data Agent owns same-tool adapter fallback and retry.'
        ) >= 0).assertTrue();
        expect(model.prompts[0].indexOf(
          'Current-turn completed Data tool IDs: ["travel.search","flight.search"]'
        )).assertEqual(-1);
      }

      const dependentModel = new QueueLocalModel([MAP_DETAILS_DECISION]);
      const dependentInput: InputUserPayload = {
        text: '读取上一轮真实地点详情',
        recentObservations: [{
          taskId: 'input-1:round-1:place',
          toolId: 'maps.place.search',
          status: 'success',
          summary: '真实地点 place-real-1',
          entityRefs: ['place-real-1']
        }]
      };
      const dependent: LeaderDecision = await new MultiAgentLeaderPlanner(dependentModel).plan(
        inputMessage(), dependentInput, planningContext(), 2
      );

      expect(dependent.dataTasks.length).assertEqual(1);
      expect(dependent.dataTasks[0].toolId).assertEqual('maps.place.details');
      expect(dependentModel.prompts[0].indexOf('place-real-1')).assertLarger(-1);
      expect(dependentModel.prompts[0].indexOf(
        'A different later-round tool is allowed only when it requires real prior output.'
      ) >= 0).assertTrue();
    });

    it('repairs one repeated completed C02 tool into a model-owned terminal answer', 0, async () => {
      const model = new QueueLocalModel([
        REPEATED_TRAVEL_PRIVATE_DECISION,
        ANSWER_FROM_TRAVEL_OBSERVATION
      ]);
      const planner = new MultiAgentLeaderPlanner(model);

      const decision = await planner.plan(
        inputMessage(),
        completedTravelInput(),
        planningContext(),
        2,
        (): boolean => true
      );

      expect(decision.roundAction).assertEqual('answer');
      expect(decision.dataTasks.length).assertEqual(0);
      expect(decision.answer as string).assertEqual('根据上一轮真实结果继续回答。');
      expect(model.prompts.length).assertEqual(2);
      expect(model.prompts[1].indexOf(
        'previous decision repeated a completed Data tool'
      ) >= 0).assertTrue();
      expect(model.prompts[1].indexOf(model.prompts[0])).assertEqual(0);
      expect(model.prompts[1].indexOf('FIRST_MODEL_PRIVATE_MARKER')).assertEqual(-1);
      const repairSuffix: string = model.prompts[1].substring(model.prompts[0].length);
      expect(repairSuffix.indexOf('OBSERVATION_PRIVATE_SUMMARY')).assertEqual(-1);
      expect(repairSuffix.indexOf('ENTITY_PRIVATE_MARKER')).assertEqual(-1);
      expect(repairSuffix.toLowerCase().indexOf('credential')).assertEqual(-1);
      expect(model.systemPrompts[1]).assertEqual(model.systemPrompts[0]);
    });

    it('gives completed-tool repair enough contract to return a full model-owned terminal decision', 0,
      async () => {
        const model = new TerminalRepairPromptAwareModel(REPEATED_TRAVEL_PRIVATE_DECISION);

        const decision = await new MultiAgentLeaderPlanner(model).plan(
          inputMessage(), completedTravelInput(), planningContext(), 2, (): boolean => true
        );

        expect(model.prompts.length).assertEqual(2);
        expect(decision.roundAction).assertEqual('answer');
        expect(decision.dataTasks.length).assertEqual(0);
        expect(decision.uiIntent.purpose).assertEqual('模型选择的真实出行总结');
        expect(decision.uiIntent.preferredDensity).assertEqual('compact');
        expect(decision.uiIntent.requiredSections.join(',')).assertEqual('travel,next-step');
      });

    it('treats every terminal Data status and repeated authority as completed', 0, async () => {
      const terminalStatuses: string[] = ['success', 'partial', 'empty', 'error'];
      for (let index = 0; index < terminalStatuses.length; index++) {
        const repeatedAuthority: string = MAP_DETAILS_DECISION
          .replace(
            '"requestedCapabilityIds":["maps.place.details"]',
            '"requestedCapabilityIds":["maps.place.details","travel.search"]'
          )
          .replace(
            '"allowedToolIds":["maps.place.details"]',
            '"allowedToolIds":["maps.place.details","travel.search"]'
          );
        const model = new QueueLocalModel([
          index === 0 ? repeatedAuthority : TRAVEL_DECISION,
          index === 0 ? ANSWER_FROM_TRAVEL_OBSERVATION.replace(
            '"requestedCapabilityIds":["travel.search"]',
            '"requestedCapabilityIds":["maps.place.details","travel.search"]'
          ) : ANSWER_FROM_TRAVEL_OBSERVATION
        ]);

        const decision = await new MultiAgentLeaderPlanner(model).plan(
          inputMessage(),
          completedTravelInput(terminalStatuses[index]),
          planningContext(),
          2,
          (): boolean => true
        );

        expect(decision.roundAction).assertEqual('answer');
        expect(model.prompts.length).assertEqual(2);
      }
    });

    it('fails closed after one repeated repair or repair transport error', 0, async () => {
      const repeatedModel = new QueueLocalModel([
        TRAVEL_DECISION,
        TRAVEL_DECISION,
        ANSWER_FROM_TRAVEL_OBSERVATION
      ]);
      const throwingModel = new QueueLocalModel([TRAVEL_DECISION]);
      let repeatedFailed: boolean = false;
      let throwingFailed: boolean = false;

      try {
        await new MultiAgentLeaderPlanner(repeatedModel).plan(
          inputMessage(), completedTravelInput(), planningContext(), 2, (): boolean => true
        );
      } catch (_error) {
        repeatedFailed = true;
      }
      try {
        await new MultiAgentLeaderPlanner(throwingModel).plan(
          inputMessage(), completedTravelInput(), planningContext(), 2, (): boolean => true
        );
      } catch (_error) {
        throwingFailed = true;
      }

      expect(repeatedFailed).assertTrue();
      expect(throwingFailed).assertTrue();
      expect(repeatedModel.prompts.length).assertEqual(2);
      expect(throwingModel.prompts.length).assertEqual(2);
    });

    it('does not repair repeated tools without an active lifecycle signal', 0, async () => {
      const absentModel = new QueueLocalModel([TRAVEL_DECISION, ANSWER_FROM_TRAVEL_OBSERVATION]);
      const inactiveModel = new QueueLocalModel([TRAVEL_DECISION, ANSWER_FROM_TRAVEL_OBSERVATION]);
      let absentFailed: boolean = false;
      let inactiveFailed: boolean = false;

      try {
        await new MultiAgentLeaderPlanner(absentModel).plan(
          inputMessage(), completedTravelInput(), planningContext(), 2
        );
      } catch (_error) {
        absentFailed = true;
      }
      try {
        await new MultiAgentLeaderPlanner(inactiveModel).plan(
          inputMessage(), completedTravelInput(), planningContext(), 2, (): boolean => false
        );
      } catch (_error) {
        inactiveFailed = true;
      }

      expect(absentFailed).assertTrue();
      expect(inactiveFailed).assertTrue();
      expect(absentModel.prompts.length).assertEqual(1);
      expect(inactiveModel.prompts.length).assertEqual(1);
    });

    it('allows first-round selection and a different dependent tool after completion', 0, async () => {
      const firstRoundModel = new QueueLocalModel([TRAVEL_DECISION]);
      const dependentModel = new QueueLocalModel([MAP_DETAILS_DECISION]);
      const dependentInput: InputUserPayload = {
        text: '读取上一轮真实地点详情',
        recentObservations: [{
          taskId: 'input-1:round-1:place',
          toolId: 'maps.place.search',
          status: 'success',
          summary: 'real place',
          entityRefs: ['place-real-1']
        }]
      };

      const firstRound = await new MultiAgentLeaderPlanner(firstRoundModel).plan(
        inputMessage(), completedTravelInput(), planningContext(), 1
      );
      const dependent = await new MultiAgentLeaderPlanner(dependentModel).plan(
        inputMessage(), dependentInput, planningContext(), 2
      );

      expect(firstRound.dataTasks[0].toolId).assertEqual('travel.search');
      expect(firstRoundModel.prompts.length).assertEqual(1);
      expect(dependent.dataTasks[0].toolId).assertEqual('maps.place.details');
      expect(dependentModel.prompts.length).assertEqual(1);
    });

    it('repairs one unbound later-round tool into a terminal answer without exposing observations', 0, async () => {
      const model = new QueueLocalModel([
        UNBOUND_FOOD_DECISION,
        ANSWER_FROM_TRAVEL_OBSERVATION.replace(
          '"requestedCapabilityIds":["travel.search"]',
          '"requestedCapabilityIds":["food.search"]'
        )
      ]);
      const planner = new MultiAgentLeaderPlanner(model);
      const input: InputUserPayload = {
        text: '继续',
        recentObservations: [{
          taskId: 'input-1:round-1:place',
          toolId: 'maps.place.search',
          status: 'success',
          summary: 'OBSERVATION_PRIVATE_SUMMARY',
          entityRefs: ['place-real-1']
        }]
      };

      const decision = await planner.plan(
        inputMessage(), input, planningContext(), 2, (): boolean => true
      );

      expect(decision.roundAction).assertEqual('answer');
      expect(model.prompts.length).assertEqual(2);
      expect(model.prompts[1].indexOf('LEADER_UNBOUND_LATER_TOOL')).assertLarger(-1);
      expect(model.prompts[1].substring(model.prompts[0].length).indexOf(
        'OBSERVATION_PRIVATE_SUMMARY'
      )).assertEqual(-1);
    });

    it('gives unbound-tool repair the same full terminal contract and keeps model-owned UI intent', 0,
      async () => {
        const model = new TerminalRepairPromptAwareModel(
          UNBOUND_FOOD_DECISION,
          MODEL_OWNED_UNBOUND_REPAIR
        );
        const input: InputUserPayload = {
          text: '继续',
          recentObservations: [{
            taskId: 'input-1:round-1:place',
            toolId: 'maps.place.search',
            status: 'success',
            summary: 'real place result',
            entityRefs: ['place-real-1']
          }]
        };

        const decision = await new MultiAgentLeaderPlanner(model).plan(
          inputMessage(), input, planningContext(), 2, (): boolean => true
        );

        expect(model.prompts.length).assertEqual(2);
        expect(decision.roundAction).assertEqual('answer');
        expect(decision.dataTasks.length).assertEqual(0);
        expect(decision.requestedCapabilityIds.join(',')).assertEqual('food.search');
        expect(decision.uiIntent.purpose).assertEqual('模型选择的真实地点总结');
        expect(decision.uiIntent.preferredDensity).assertEqual('compact');
        expect(decision.uiIntent.requiredSections.join(',')).assertEqual('place,next-step');
      });

    it('accepts a later tool only when its own input contains an earlier successful entity reference', 0, async () => {
      const successInput: InputUserPayload = {
        text: '查看这个地点详情',
        recentObservations: [{
          taskId: 'input-1:round-1:place',
          toolId: 'maps.place.search',
          status: 'success',
          summary: 'real place',
          entityRefs: ['place-real-1']
        }]
      };
      const emptyInput: InputUserPayload = {
        text: successInput.text,
        recentObservations: [{
          taskId: 'input-1:round-1:place',
          toolId: 'maps.place.search',
          status: 'empty',
          summary: 'empty',
          entityRefs: ['place-real-1']
        }]
      };
      const errorInput: InputUserPayload = {
        text: successInput.text,
        recentObservations: [{
          taskId: 'input-1:round-1:place',
          toolId: 'maps.place.search',
          status: 'error',
          summary: 'provider error',
          entityRefs: ['place-real-1']
        }]
      };
      const valid = await new MultiAgentLeaderPlanner(
        new QueueLocalModel([MAP_DETAILS_DECISION])
      ).plan(inputMessage(), successInput, planningContext(), 2);
      const validFallbackId = await new MultiAgentLeaderPlanner(
        new QueueLocalModel([
          MAP_DETAILS_DECISION.replace(
            '"input":{"placeId":"place-real-1"}',
            '"input":{"id":"place-real-1"}'
          )
        ])
      ).plan(inputMessage(), successInput, planningContext(), 2);
      let fakeRejected: boolean = false;
      let emptyRejected: boolean = false;
      let errorRejected: boolean = false;
      try {
        await new MultiAgentLeaderPlanner(
          new QueueLocalModel([MAP_DETAILS_DECISION.replace('place-real-1', 'place-forged')])
        ).plan(inputMessage(), successInput, planningContext(), 2);
      } catch (_error) {
        fakeRejected = true;
      }
      try {
        await new MultiAgentLeaderPlanner(
          new QueueLocalModel([MAP_DETAILS_DECISION])
        ).plan(inputMessage(), emptyInput, planningContext(), 2);
      } catch (_error) {
        emptyRejected = true;
      }
      try {
        await new MultiAgentLeaderPlanner(
          new QueueLocalModel([MAP_DETAILS_DECISION])
        ).plan(inputMessage(), errorInput, planningContext(), 2);
      } catch (_error) {
        errorRejected = true;
      }

      expect(valid.dataTasks[0].toolId).assertEqual('maps.place.details');
      expect(validFallbackId.dataTasks[0].toolId).assertEqual('maps.place.details');
      expect(fakeRejected).assertTrue();
      expect(emptyRejected).assertTrue();
      expect(errorRejected).assertTrue();
    });

    it('rejects real references hidden in unused fields forged consumed fields and cross-tool sources', 0, async () => {
      const mapsInput: InputUserPayload = {
        text: '查看这个地点详情',
        recentObservations: [{
          taskId: 'input-1:round-1:place',
          toolId: 'maps.place.search',
          status: 'success',
          summary: 'real place',
          entityRefs: ['place-real-1']
        }]
      };
      const foodWithUnusedRef: string = UNBOUND_FOOD_DECISION.replace(
        '"input":{"query":"附近餐厅"}',
        '"input":{"query":"附近餐厅","unusedPlaceId":"place-real-1"}'
      );
      const mapsWithForgedConsumedField: string = MAP_DETAILS_DECISION.replace(
        '"input":{"placeId":"place-real-1"}',
        '"input":{"placeId":"place-forged","unused":{"placeId":"place-real-1"}}'
      );
      const mapsWithForgedPreferredField: string = MAP_DETAILS_DECISION.replace(
        '"input":{"placeId":"place-real-1"}',
        '"input":{"placeId":"place-forged","id":"place-real-1"}'
      );
      const mailBackedMapsInput: InputUserPayload = {
        text: mapsInput.text,
        recentObservations: [{
          taskId: 'input-1:round-1:mail',
          toolId: 'mail.search',
          status: 'success',
          summary: 'mail result',
          entityRefs: ['place-real-1']
        }]
      };
      const rejected: boolean[] = [];
      const attempts: Array<[string, InputUserPayload]> = [
        [foodWithUnusedRef, mapsInput],
        [mapsWithForgedConsumedField, mapsInput],
        [mapsWithForgedPreferredField, mapsInput],
        [MAP_DETAILS_DECISION, mailBackedMapsInput]
      ];
      for (let index = 0; index < attempts.length; index++) {
        try {
          await new MultiAgentLeaderPlanner(
            new QueueLocalModel([attempts[index][0]])
          ).plan(inputMessage(), attempts[index][1], planningContext(), 2);
          rejected.push(false);
        } catch (_error) {
          rejected.push(true);
        }
      }

      expect(rejected.join(',')).assertEqual('true,true,true,true');
    });

    it('allows mail search to read only an exact real result identity', 0, async () => {
      const input: InputUserPayload = {
        text: '打开第一封邮件',
        recentObservations: [{
          taskId: 'input-1:round-1:mail-search',
          toolId: 'mail.search',
          status: 'success',
          summary: 'real mail list',
          entityRefs: ['gmail:thread-real-1', 'thread-real-1', 'message-real-1']
        }]
      };
      const valid = await new MultiAgentLeaderPlanner(
        new QueueLocalModel([MAIL_READ_DECISION])
      ).plan(inputMessage(), input, planningContext(), 2);
      const qqInput: InputUserPayload = {
        text: input.text,
        recentObservations: [{
          taskId: 'input-1:round-1:qq-mail-search',
          toolId: 'mail.search',
          status: 'success',
          summary: 'real QQ mail list',
          entityRefs: ['qq:message-real-1', 'thread-real-1', 'message-real-1']
        }]
      };
      const qqDecision: string = MAIL_READ_DECISION
        .replace('"provider":"gmail"', '"provider":"qq"')
        .replace('gmail:thread-real-1', 'qq:message-real-1');
      const validQq = await new MultiAgentLeaderPlanner(
        new QueueLocalModel([qqDecision])
      ).plan(inputMessage(), qqInput, planningContext(), 2);
      let forgedRejected: boolean = false;
      let forgedPreferredIdentityRejected: boolean = false;
      let forgedQqIdentityRejected: boolean = false;
      try {
        await new MultiAgentLeaderPlanner(new QueueLocalModel([
          MAIL_READ_DECISION
            .replace('gmail:thread-real-1', 'gmail:thread-forged')
            .replace('thread-real-1', 'thread-forged')
            .replace('message-real-1', 'message-forged')
        ])).plan(inputMessage(), input, planningContext(), 2);
      } catch (_error) {
        forgedRejected = true;
      }
      try {
        await new MultiAgentLeaderPlanner(new QueueLocalModel([
          MAIL_READ_DECISION
            .replace('gmail:thread-real-1', 'gmail:thread-forged')
            .replace('"threadId":"thread-real-1"', '"threadId":"thread-forged"')
        ])).plan(inputMessage(), input, planningContext(), 2);
      } catch (_error) {
        forgedPreferredIdentityRejected = true;
      }
      try {
        await new MultiAgentLeaderPlanner(new QueueLocalModel([
          qqDecision
            .replace('qq:message-real-1', 'qq:message-forged')
            .replace('"messageId":"message-real-1"', '"messageId":"message-forged"')
        ])).plan(inputMessage(), qqInput, planningContext(), 2);
      } catch (_error) {
        forgedQqIdentityRejected = true;
      }

      expect(valid.dataTasks[0].toolId).assertEqual('mail.thread.read');
      expect(validQq.dataTasks[0].toolId).assertEqual('mail.thread.read');
      expect(forgedRejected).assertTrue();
      expect(forgedPreferredIdentityRejected).assertTrue();
      expect(forgedQqIdentityRejected).assertTrue();
    });

    it('allows Gmail read only from a real Gmail search identity', 0, async () => {
      const input: InputUserPayload = {
        text: '打开第一封 Gmail',
        recentObservations: [{
          taskId: 'input-1:round-1:gmail-search',
          toolId: 'gmail.mail.search',
          status: 'partial',
          summary: 'real Gmail list',
          entityRefs: ['gmail:thread-real-1', 'thread-real-1', 'message-real-1']
        }]
      };
      const valid = await new MultiAgentLeaderPlanner(
        new QueueLocalModel([GMAIL_READ_DECISION])
      ).plan(inputMessage(), input, planningContext(), 2);
      let wrongSourceRejected: boolean = false;
      let forgedPreferredIdentityRejected: boolean = false;
      try {
        const wrongSource: InputUserPayload = {
          text: input.text,
          recentObservations: [{
            taskId: 'input-1:round-1:mail-search',
            toolId: 'mail.search',
            status: 'success',
            summary: 'wrong source',
            entityRefs: ['thread-real-1']
          }]
        };
        await new MultiAgentLeaderPlanner(
          new QueueLocalModel([GMAIL_READ_DECISION])
        ).plan(inputMessage(), wrongSource, planningContext(), 2);
      } catch (_error) {
        wrongSourceRejected = true;
      }
      try {
        await new MultiAgentLeaderPlanner(new QueueLocalModel([
          GMAIL_READ_DECISION
            .replace('gmail:thread-real-1', 'gmail:thread-forged')
            .replace('"threadId":"thread-real-1"', '"threadId":"thread-forged"')
        ])).plan(inputMessage(), input, planningContext(), 2);
      } catch (_error) {
        forgedPreferredIdentityRejected = true;
      }

      expect(valid.dataTasks[0].toolId).assertEqual('gmail.thread.read');
      expect(wrongSourceRejected).assertTrue();
      expect(forgedPreferredIdentityRejected).assertTrue();
    });

    it('ignores old forged current and future observations for repeat authority', 0, async () => {
      const model = new QueueLocalModel([TRAVEL_DECISION]);
      const input: InputUserPayload = {
        text: '继续查询出行方案',
        recentObservations: [{
          taskId: 'other-input:round-1:old',
          toolId: 'travel.search',
          status: 'success',
          summary: 'old turn',
          entityRefs: []
        }, {
          taskId: 'input-1:round-forged:fake',
          toolId: 'travel.search',
          status: 'success',
          summary: 'forged round',
          entityRefs: []
        }, {
          taskId: 'input-1:round-2:current',
          toolId: 'travel.search',
          status: 'success',
          summary: 'current round',
          entityRefs: []
        }, {
          taskId: 'input-1:round-3:future',
          toolId: 'travel.search',
          status: 'success',
          summary: 'future round',
          entityRefs: []
        }]
      };

      let rejected: boolean = false;
      try {
        await new MultiAgentLeaderPlanner(model).plan(
          inputMessage(), input, planningContext(), 2
        );
      } catch (_error) {
        rejected = true;
      }

      expect(rejected).assertTrue();
      expect(model.prompts.length).assertEqual(1);
      expect(model.prompts[0].indexOf(
        'Current-turn completed Data tool IDs: []'
      ) >= 0).assertTrue();
    });

    it('does not promote a whitespace near-match into completed authority', 0, async () => {
      const model = new QueueLocalModel([TRAVEL_DECISION]);
      const input: InputUserPayload = {
        text: '继续查询出行方案',
        recentObservations: [{
          taskId: 'input-1:round-1:travel',
          toolId: ' travel.search ',
          status: 'success',
          summary: 'near match',
          entityRefs: []
        }]
      };

      let rejected: boolean = false;
      try {
        await new MultiAgentLeaderPlanner(model).plan(
          inputMessage(), input, planningContext(), 2
        );
      } catch (_error) {
        rejected = true;
      }

      expect(rejected).assertTrue();
      expect(model.prompts.length).assertEqual(1);
      const metadataStart: number = model.prompts[0].indexOf(
        'Current-turn completed Data tool IDs:'
      );
      const metadataEnd: number = model.prompts[0].indexOf('\n', metadataStart);
      const metadataLine: string = model.prompts[0].substring(metadataStart, metadataEnd);
      expect(metadataLine).assertEqual('Current-turn completed Data tool IDs: []');
      expect(metadataLine.indexOf(' travel.search ')).assertEqual(-1);
    });

    it('does not let invalid observations hide a later registered completed tool', 0, async () => {
      const observations: ObservationDigest[] = [];
      for (let index = 0; index < 10; index++) {
        observations.push({
          taskId: 'input-1:round-1:invalid-' + index.toString(),
          toolId: 'invalid.tool.' + index.toString(),
          status: 'success',
          summary: 'invalid summary',
          entityRefs: []
        });
      }
      observations.push({
        taskId: 'input-1:round-1:travel',
        toolId: 'travel.search',
        status: 'success',
        summary: 'real travel result',
        entityRefs: []
      });
      const model = new QueueLocalModel([TRAVEL_DECISION, ANSWER_FROM_TRAVEL_OBSERVATION]);

      const decision = await new MultiAgentLeaderPlanner(model).plan(
        inputMessage(),
        { text: '继续', recentObservations: observations },
        planningContext(),
        2,
        (): boolean => true
      );

      expect(decision.roundAction).assertEqual('answer');
      expect(model.prompts.length).assertEqual(2);
      const metadataStart: number = model.prompts[0].indexOf(
        'Current-turn completed Data tool IDs:'
      );
      const metadataEnd: number = model.prompts[0].indexOf('\n', metadataStart);
      const metadataLine: string = model.prompts[0].substring(metadataStart, metadataEnd);
      expect(metadataLine).assertEqual(
        'Current-turn completed Data tool IDs: ["travel.search"]'
      );
      expect(metadataLine.indexOf('invalid.tool.')).assertEqual(-1);
    });

    it('accepts only exact earlier-round task identities and bounds the completed tool list', 0, async () => {
      const probeInput: InputUserPayload = {
        text: '根据真实结果继续',
        recentObservations: [{
          taskId: 'input-1:round-1:travel-a',
          toolId: 'travel.search',
          status: 'success',
          summary: 'must-not-enter-completed-tool-metadata',
          entityRefs: []
        }, {
          taskId: 'input-1:round-2:flight-a',
          toolId: 'flight.search',
          status: 'partial',
          summary: 'valid prior round',
          entityRefs: []
        }, {
          taskId: 'input-1:round-2:travel-b',
          toolId: 'travel.search',
          status: 'empty',
          summary: 'duplicate tool',
          entityRefs: []
        }, {
          taskId: 'input-1:round-forged:train',
          toolId: 'train.search',
          status: 'success',
          summary: 'forged round',
          entityRefs: []
        }, {
          taskId: 'input-1:round-0:hotel',
          toolId: 'hotel.search',
          status: 'success',
          summary: 'zero round',
          entityRefs: []
        }, {
          taskId: 'input-1:round-99:maps',
          toolId: 'maps.place.details',
          status: 'success',
          summary: 'future round',
          entityRefs: []
        }, {
          taskId: 'input-1:round-3:current',
          toolId: 'current.search',
          status: 'success',
          summary: 'current round',
          entityRefs: []
        }, {
          taskId: 'input-1:round-4:future',
          toolId: 'future.search',
          status: 'success',
          summary: 'future round',
          entityRefs: []
        }, {
          taskId: 'input-1:round-2:',
          toolId: 'missing-local.search',
          status: 'success',
          summary: 'missing local ID',
          entityRefs: []
        }, {
          taskId: 'other-input:round-1:travel',
          toolId: 'other.search',
          status: 'success',
          summary: 'other input task',
          entityRefs: []
        }]
      };
      const roundThreeModel: QueueLocalModel = new QueueLocalModel([ANSWER_FROM_TRAVEL_OBSERVATION]);

      await new MultiAgentLeaderPlanner(roundThreeModel).plan(
        inputMessage(), probeInput, planningContext(), 3
      );

      expect(roundThreeModel.prompts[0].indexOf(
        'Current-turn completed Data tool IDs: ["travel.search","flight.search"]'
      ) >= 0).assertTrue();
      const metadataStart: number = roundThreeModel.prompts[0].indexOf(
        'Current-turn completed Data tool IDs:'
      );
      const metadataEnd: number = roundThreeModel.prompts[0].indexOf('\n', metadataStart);
      const metadataLine: string = roundThreeModel.prompts[0].substring(metadataStart, metadataEnd);
      expect(metadataLine.indexOf('must-not-enter-completed-tool-metadata')).assertEqual(-1);
      expect(roundThreeModel.prompts[0].indexOf(
        'Current-turn completed Data tool IDs: ["travel.search","flight.search","train.search"'
      )).assertEqual(-1);

      const firstRoundModel: QueueLocalModel = new QueueLocalModel([ANSWER_FROM_TRAVEL_OBSERVATION]);
      await new MultiAgentLeaderPlanner(firstRoundModel).plan(
        inputMessage(), probeInput, planningContext(), 1
      );
      expect(firstRoundModel.prompts[0].indexOf(
        'Current-turn completed Data tool IDs: []'
      ) >= 0).assertTrue();

      const many: ObservationDigest[] = [];
      for (let index = 0; index < REGISTERED_DATA_TOOL_IDS.length; index++) {
        many.push({
          taskId: 'input-1:round-1:local-' + index.toString(),
          toolId: REGISTERED_DATA_TOOL_IDS[index],
          status: 'success',
          summary: 'summary-' + index.toString(),
          entityRefs: []
        });
      }
      const boundedModel: QueueLocalModel = new QueueLocalModel([ANSWER_FROM_TRAVEL_OBSERVATION]);
      await new MultiAgentLeaderPlanner(boundedModel).plan(
        inputMessage(), { text: '继续', recentObservations: many }, planningContext(), 2
      );
      expect(boundedModel.prompts[0].indexOf(
        'Current-turn completed Data tool IDs: ["travel.search","train.search",' +
          '"flight.search","hotel.search","food.search","social.feed.search",' +
          '"mail.search","mail.thread.read"]'
      ) >= 0).assertTrue();
      expect(boundedModel.prompts[0].indexOf(
        'Current-turn completed Data tool IDs: ["travel.search","train.search",' +
          '"flight.search","hotel.search","food.search","social.feed.search",' +
          '"mail.search","mail.thread.read","gmail.mail.search"'
      )).assertEqual(-1);
    });

    it('repairs one missing authority field once without exposing its output', 0, async () => {
      const model = new QueueLocalModel([MISSING_PERSONA_DECISION, LIVE_ANSWER_WITHOUT_REASON_CODE]);
      const planner = new MultiAgentLeaderPlanner(model);
      const input: InputUserPayload = { text: '你好' };

      const decision = await planner.plan(
        inputMessage(),
        input,
        planningContext(),
        1,
        (): boolean => true
      );

      expect(decision.reasonCode).assertEqual('host_answer');
      expect(model.prompts.length).assertEqual(2);
      expect(model.prompts[1].indexOf(model.prompts[0])).assertEqual(0);
      expect(model.prompts[1].indexOf('previous decision rejected by strict schema') >= 0).assertTrue();
      expect(model.prompts[1].indexOf('LIVE_PRIVATE_MARKER')).assertEqual(-1);
      expect(model.systemPrompts[1]).assertEqual(model.systemPrompts[0]);
      expect(model.prompts[1].indexOf('Round: 1') >= 0).assertTrue();
    });

    it('repairs only invalid Data task input once and preserves the accepted plan', 0, async () => {
      const model = new QueueLocalModel([SOCIAL_WITH_DATE_DECISION, SOCIAL_ONLY_DECISION]);
      const planner = new MultiAgentLeaderPlanner(model, undefined, socialInputNormalizer);
      const input: InputUserPayload = { text: '帮我查看我今天 X 和 Slack 上的消息' };

      const decision = await planner.plan(
        inputMessage(),
        input,
        planningContext(),
        1,
        (): boolean => true
      );
      const repairedInput = decision.dataTasks[0].input as
        Record<string, Object | string | number | boolean>;

      expect(model.prompts.length).assertEqual(2);
      expect(model.prompts[1].indexOf('LEADER_TASK_INPUT_INVALID')).assertLarger(-1);
      expect(model.prompts[1].indexOf('Change only dataTasks[].input')).assertLarger(-1);
      expect(decision.personaId).assertEqual('travel_companion');
      expect(decision.requestedCapabilityIds.join(',')).assertEqual('social.feed.search');
      expect(decision.dataTasks[0].toolId).assertEqual('social.feed.search');
      expect(decision.uiIntent.purpose).assertEqual('展示 SocialHub 消息');
      expect(Object.keys(repairedInput).join(',')).assertEqual('platforms');
    });

    it('repairs a BIM-only state change without forcing an unrelated business tool', 0, async () => {
      const model = new QueueLocalModel([BIM_STATE_ONLY_TOOL_DECISION, BIM_STATE_ONLY_ANSWER]);
      const planner = new MultiAgentLeaderPlanner(model, undefined, rejectedHotelInputNormalizer);
      const input: InputUserPayload = {
        text: '[BIM_CONTEXT]\n{"query":"我去东京旅行的人数增加到四个人，酒店我希望是两间双床房"}'
      };

      const decision = await planner.plan(
        inputMessage(), input, planningContext(), 1, (): boolean => true
      );

      expect(model.prompts.length).assertEqual(2);
      expect(model.prompts[1].indexOf('BIM state-only update')).assertLarger(-1);
      expect(decision.roundAction).assertEqual('answer');
      expect(decision.requestedCapabilityIds.length).assertEqual(0);
      expect(decision.dataTasks.length).assertEqual(0);
      expect(decision.bimContextUpdate?.facts[0]).assertEqual('出行人数为四人');
      expect(decision.bimContextUpdate?.constraints[0]).assertEqual('酒店需要两间双床房');
    });

    it('captures one local date snapshot for prompt and every repair normalization', 0, async () => {
      let dateCalls: number = 0;
      const normalizedDates: string[] = [];
      const currentLocalDate = (): string => {
        dateCalls++;
        return dateCalls === 1 ? '2026-07-20' : '2031-01-01';
      };
      const recordingNormalizer: LeaderDataTaskInputNormalizer = (
        input: InputUserPayload,
        task: LeaderDecisionDataTask,
        localDate: string
      ): Object => {
        normalizedDates.push(localDate);
        return socialInputNormalizer(input, task, localDate);
      };
      const model = new QueueLocalModel([SOCIAL_WITH_DATE_DECISION, SOCIAL_ONLY_DECISION]);
      const planner = new MultiAgentLeaderPlanner(model, currentLocalDate, recordingNormalizer);

      const decision = await planner.plan(
        inputMessage(),
        { text: '帮我查看我今天 X 和 Slack 上的消息' },
        planningContext(),
        1,
        (): boolean => true
      );

      expect(decision.dataTasks[0].toolId).assertEqual('social.feed.search');
      expect(decision.normalizationCurrentLocalDate).assertEqual('2026-07-20');
      expect(dateCalls).assertEqual(1);
      expect(normalizedDates.join(',')).assertEqual('2026-07-20,2026-07-20');
      expect(model.prompts[0].indexOf('Current local date: 2026-07-20')).assertLarger(-1);
      expect(model.prompts[1].indexOf('Current local date: 2031-01-01')).assertEqual(-1);
    });

    it('fails closed when Data input repair changes tools or non-input plan fields', 0, async () => {
      const changedTool = new QueueLocalModel([SOCIAL_WITH_DATE_DECISION, SOCIAL_MAIL_DECISION]);
      const changedUi = new QueueLocalModel([
        SOCIAL_WITH_DATE_DECISION,
        SOCIAL_ONLY_DECISION.replace('展示 SocialHub 消息', '展示篡改后的界面')
      ]);
      const input: InputUserPayload = { text: '帮我查看我今天 X 和 Slack 上的消息' };
      let changedToolFailed: boolean = false;
      let changedUiFailed: boolean = false;

      try {
        await new MultiAgentLeaderPlanner(changedTool, undefined, socialInputNormalizer).plan(
          inputMessage(), input, planningContext(), 1, (): boolean => true
        );
      } catch (_error) {
        changedToolFailed = true;
      }
      try {
        await new MultiAgentLeaderPlanner(changedUi, undefined, socialInputNormalizer).plan(
          inputMessage(), input, planningContext(), 1, (): boolean => true
        );
      } catch (_error) {
        changedUiFailed = true;
      }

      expect(changedToolFailed).assertTrue();
      expect(changedUiFailed).assertTrue();
      expect(changedTool.prompts.length).assertEqual(2);
      expect(changedUi.prompts.length).assertEqual(2);
    });

    it('does not start Data input repair after lifecycle cancellation', 0, async () => {
      const model = new QueueLocalModel([SOCIAL_WITH_DATE_DECISION, SOCIAL_ONLY_DECISION]);
      const input: InputUserPayload = { text: '帮我查看我今天 X 和 Slack 上的消息' };
      let failed: boolean = false;

      try {
        await new MultiAgentLeaderPlanner(model, undefined, socialInputNormalizer).plan(
          inputMessage(), input, planningContext(), 1, (): boolean => false
        );
      } catch (_error) {
        failed = true;
      }

      expect(failed).assertTrue();
      expect(model.prompts.length).assertEqual(1);
    });

    it('stops after one invalid or throwing strict-schema repair', 0, async () => {
      const model = new QueueLocalModel([MISSING_PERSONA_DECISION, MISSING_PERSONA_DECISION]);
      const throwingModel = new QueueLocalModel([MISSING_PERSONA_DECISION]);
      const planner = new MultiAgentLeaderPlanner(model);
      const input: InputUserPayload = { text: '你好' };
      let failed: boolean = false;
      let throwingFailed: boolean = false;

      try {
        await planner.plan(inputMessage(), input, planningContext(), 1, (): boolean => true);
      } catch (_error) {
        failed = true;
      }
      try {
        await new MultiAgentLeaderPlanner(throwingModel).plan(
          inputMessage(), input, planningContext(), 1, (): boolean => true
        );
      } catch (_error) {
        throwingFailed = true;
      }

      expect(failed).assertTrue();
      expect(throwingFailed).assertTrue();
      expect(model.prompts.length).assertEqual(2);
      expect(throwingModel.prompts.length).assertEqual(2);
    });

    it('does not repair without an active lifecycle signal', 0, async () => {
      const absentModel = new QueueLocalModel([MISSING_PERSONA_DECISION, LIVE_ANSWER_WITHOUT_REASON_CODE]);
      const inactiveModel = new QueueLocalModel([MISSING_PERSONA_DECISION, LIVE_ANSWER_WITHOUT_REASON_CODE]);
      const input: InputUserPayload = { text: '你好' };
      let absentFailed: boolean = false;
      let inactiveFailed: boolean = false;

      try {
        await new MultiAgentLeaderPlanner(absentModel).plan(
          inputMessage(), input, planningContext(), 1
        );
      } catch (_error) {
        absentFailed = true;
      }
      try {
        await new MultiAgentLeaderPlanner(inactiveModel).plan(
          inputMessage(), input, planningContext(), 1, (): boolean => false
        );
      } catch (_error) {
        inactiveFailed = true;
      }

      expect(absentFailed).assertTrue();
      expect(inactiveFailed).assertTrue();
      expect(absentModel.prompts.length).assertEqual(1);
      expect(inactiveModel.prompts.length).assertEqual(1);
    });

    it('does not repair a first model transport failure', 0, async () => {
      const model = new QueueLocalModel([]);
      const planner = new MultiAgentLeaderPlanner(model);
      const input: InputUserPayload = { text: '你好' };
      let failed: boolean = false;

      try {
        await planner.plan(inputMessage(), input, planningContext(), 1);
      } catch (_error) {
        failed = true;
      }

      expect(failed).assertTrue();
      expect(model.prompts.length).assertEqual(1);
    });

    it('owns diagnostic reason codes for omitted and forged model values', 0, async () => {
      const omittedModel = new QueueLocalModel([LIVE_ANSWER_WITHOUT_REASON_CODE]);
      const forgedModel = new QueueLocalModel([VALID_ANSWER_DECISION]);
      const clarifyModel = new QueueLocalModel(['{"personaId":"travel_companion","skillId":"",' +
        '"requestedCapabilityIds":[],"roundAction":"clarify","continuationMode":"complete","dataTasks":[],' +
        '"uiIntent":{"purpose":"clarify","preferredDensity":"comfortable","requiredSections":[]},' +
        '"answer":"请提供城市"}']);
      const input: InputUserPayload = { text: '你好' };

      const omitted = await new MultiAgentLeaderPlanner(omittedModel).plan(
        inputMessage(), input, planningContext(), 1
      );
      const forged = await new MultiAgentLeaderPlanner(forgedModel).plan(
        inputMessage(), input, planningContext(), 1
      );
      const clarify = await new MultiAgentLeaderPlanner(clarifyModel).plan(
        inputMessage(), input, planningContext(), 1
      );
      expect(omitted.reasonCode).assertEqual('host_answer');
      expect(forged.reasonCode).assertEqual('host_answer');
      expect(clarify.reasonCode).assertEqual('host_clarify');
      expect(omittedModel.prompts.length).assertEqual(1);
      expect(forgedModel.prompts.length).assertEqual(1);
      expect(clarifyModel.prompts.length).assertEqual(1);
    });

    it('repairs a present malformed reason code while ignoring a valid model value', 0, async () => {
      const malformed: string = LIVE_ANSWER_WITHOUT_REASON_CODE.substring(
        0,
        LIVE_ANSWER_WITHOUT_REASON_CODE.length - 1
      ) + ',"reasonCode":42}';
      const model = new QueueLocalModel([malformed, VALID_ANSWER_DECISION]);

      const decision = await new MultiAgentLeaderPlanner(model).plan(
        inputMessage(),
        { text: '你好' },
        planningContext(),
        1,
        (): boolean => true
      );

      expect(decision.reasonCode).assertEqual('host_answer');
      expect(model.prompts.length).assertEqual(2);
    });

    it('clears a selected skill that does not declare the complete capability set', 0,
      async () => {
        const invalidSkill: string = SOCIAL_ONLY_DECISION.replace(
          '"skillId":""',
          '"skillId":"travel-planning"'
        );
        const model = new QueueLocalModel([invalidSkill, invalidSkill]);

        const decision = await new MultiAgentLeaderPlanner(model).plan(
          inputMessage(),
          { text: '帮我查看我今天 X 和 Slack 上的消息' },
          planningContext(),
          1,
          (): boolean => true
        );

        expect(model.prompts.length).assertEqual(1);
        expect(decision.skillId).assertEqual('');
        expect(decision.requestedCapabilityIds.join(',')).assertEqual('social.feed.search');
        expect(decision.dataTasks[0].toolId).assertEqual('social.feed.search');
      });

    it('executes explicitly ordered independent capabilities one planning round at a time', 0,
      async () => {
        const context = actionOwnerContext();
        context.tools.push({
          toolId: 'time',
          domain: 'system',
          intent: 'time.now',
          riskLevel: 'read',
          registeredBackends: ['local_adapter'],
          inputSchema: 'emptyObject',
          outputSchema: 'genericToolResults',
          actions: []
        }, {
          toolId: 'ride.estimate',
          domain: 'ride',
          intent: 'ride.estimate',
          riskLevel: 'read',
          registeredBackends: ['local_adapter'],
          inputSchema: 'rideEstimateQuery',
          outputSchema: 'genericToolResults',
          actions: []
        });
        const first = await new MultiAgentLeaderPlanner(
          new QueueLocalModel([EXPLICIT_SERIAL_FIRST_DECISION])
        ).plan(
          inputMessage(),
          { text: EXPLICIT_SERIAL_QUERY },
          context,
          1
        );
        context.lockedPersonaId = 'travel_companion';
        context.lockedSkillId = '';
        const second = await new MultiAgentLeaderPlanner(
          new QueueLocalModel([EXPLICIT_SERIAL_SECOND_DECISION])
        ).plan(
          inputMessage(),
          {
            text: EXPLICIT_SERIAL_QUERY,
            orderedContinuationAuthorized: true,
            recentObservations: [{
              taskId: 'input-1:round-1:time',
              toolId: 'time',
              status: 'success',
              summary: '2026-07-27 11:30',
              entityRefs: []
            }]
          },
          context,
          2
        );
        const third = await new MultiAgentLeaderPlanner(
          new QueueLocalModel([EXPLICIT_SERIAL_THIRD_DECISION])
        ).plan(
          inputMessage(),
          {
            text: EXPLICIT_SERIAL_QUERY,
            orderedContinuationAuthorized: true,
            recentObservations: [{
              taskId: 'input-1:round-1:time',
              toolId: 'time',
              status: 'success',
              summary: '2026-07-27 11:30',
              entityRefs: []
            }, {
              taskId: 'input-1:round-2:ride',
              toolId: 'ride.estimate',
              status: 'success',
              summary: '滴滴估价已返回',
              entityRefs: []
            }]
          },
          context,
          3
        );

        expect(first.dataTasks.length).assertEqual(1);
        expect(first.dataTasks[0].toolId).assertEqual('time');
        expect(first.requestedCapabilityIds.join(',')).assertEqual('time');
        expect(first.actionIntent === undefined).assertTrue();
        expect(second.dataTasks.length).assertEqual(1);
        expect(second.dataTasks[0].toolId).assertEqual('ride.estimate');
        expect(second.requestedCapabilityIds.join(',')).assertEqual('ride.estimate');
        expect(second.actionIntent === undefined).assertTrue();
        expect(third.roundAction).assertEqual('clarify');
        expect(third.dataTasks.length).assertEqual(0);
        expect(third.actionIntent === undefined).assertTrue();
        expect(third.requestedCapabilityIds.join(',')).assertEqual('calendar.event.create');
        expect(third.answer!.indexOf('结束时间或时长')).assertLarger(-1);

        const thirdWithDuration = await new MultiAgentLeaderPlanner(
          new QueueLocalModel([EXPLICIT_SERIAL_THIRD_DECISION])
        ).plan(
          inputMessage(),
          {
            text: EXPLICIT_SERIAL_QUERY_WITH_DURATION,
            orderedContinuationAuthorized: true,
            recentObservations: [{
              taskId: 'input-1:round-1:time',
              toolId: 'time',
              status: 'success',
              summary: '2026-07-27 11:30',
              entityRefs: []
            }, {
              taskId: 'input-1:round-2:ride',
              toolId: 'ride.estimate',
              status: 'success',
              summary: '滴滴估价已返回',
              entityRefs: []
            }]
          },
          context,
          3
        );
        expect(thirdWithDuration.roundAction).assertEqual('execute');
        expect(thirdWithDuration.actionIntent === undefined).assertFalse();
      });

    it('keeps mixed read and Action-owned capabilities in their declared agents', 0, async () => {
      const context = actionOwnerContext();
      context.tools.push({
        toolId: 'ride.estimate',
        domain: 'ride',
        intent: 'ride.estimate',
        riskLevel: 'read',
        registeredBackends: ['local_adapter'],
        inputSchema: 'rideEstimateQuery',
        outputSchema: 'genericToolResults',
        actions: []
      });
      const model = new MixedOwnershipPromptAwareModel();
      const decision = await new MultiAgentLeaderPlanner(model).plan(
        inputMessage(),
        { text: MIXED_DATA_ACTION_QUERY },
        context,
        1
      );

      expect(model.prompts.length).assertEqual(1);
      expect(decision.requestedCapabilityIds.join(',')).assertEqual(
        'ride.estimate,luckin.order.preview,payment.send'
      );
      expect(decision.dataTasks.length).assertEqual(1);
      expect(decision.dataTasks[0].toolId).assertEqual('ride.estimate');
      expect(decision.actionIntent!.allowedActionIds.join(',')).assertEqual(
        'luckin.order.preview,payment.send'
      );
    });

    it('scopes sequence capability IDs to the current Data task', 0, async () => {
      const context = actionOwnerContext();
      context.tools.push({
        toolId: 'ride.estimate',
        domain: 'ride',
        intent: 'ride.estimate',
        riskLevel: 'read',
        registeredBackends: ['local_adapter'],
        inputSchema: 'rideEstimateQuery',
        outputSchema: 'genericToolResults',
        actions: []
      });
      const decision = await new MultiAgentLeaderPlanner(new QueueLocalModel([
        MIXED_SEQUENCE_WITH_FUTURE_CAPABILITIES_DECISION
      ])).plan(
        inputMessage(),
        { text: MIXED_DATA_ACTION_QUERY },
        context,
        1
      );

      expect(decision.requestedCapabilityIds.join(',')).assertEqual('ride.estimate');
      expect(decision.dataTasks.length).assertEqual(1);
      expect(decision.dataTasks[0].toolId).assertEqual('ride.estimate');
      expect(decision.actionIntent === undefined).assertTrue();
      expect(decision.reasonCode).assertEqual('sequence_requires_next_round');
    });

    it('scopes sequence capability IDs to all current Data tasks before normalization', 0, async () => {
      const context = actionOwnerContext();
      context.tools.push({
        toolId: 'ride.estimate',
        domain: 'ride',
        intent: 'ride.estimate',
        riskLevel: 'read',
        registeredBackends: ['local_adapter'],
        inputSchema: 'rideEstimateQuery',
        outputSchema: 'genericToolResults',
        actions: []
      });
      const decision = await new MultiAgentLeaderPlanner(new QueueLocalModel([
        MULTI_DATA_SEQUENCE_WITH_FUTURE_CAPABILITIES_DECISION
      ])).plan(
        inputMessage(),
        { text: MIXED_DATA_ACTION_QUERY },
        context,
        1
      );

      expect(decision.requestedCapabilityIds.join(',')).assertEqual('ride.estimate');
      expect(decision.dataTasks.length).assertEqual(1);
      expect(decision.dataTasks[0].toolId).assertEqual('ride.estimate');
      expect(decision.actionIntent === undefined).assertTrue();
      expect(decision.reasonCode).assertEqual('sequence_requires_next_round');
    });

    it('normalizes one model-selected mixed Action into its declared owner', 0, async () => {
      const context = actionOwnerContext();
      context.tools.push({
        toolId: 'ride.estimate',
        domain: 'ride',
        intent: 'ride.estimate',
        riskLevel: 'read',
        registeredBackends: ['local_adapter'],
        inputSchema: 'rideEstimateQuery',
        outputSchema: 'genericToolResults',
        actions: []
      });
      const model = new QueueLocalModel([MIXED_MISPLACED_ACTION_DECISION]);
      const decision = await new MultiAgentLeaderPlanner(model).plan(
        inputMessage(),
        { text: MIXED_DATA_ACTION_QUERY },
        context,
        1
      );

      expect(model.prompts.length).assertEqual(1);
      expect(decision.dataTasks.length).assertEqual(1);
      expect(decision.dataTasks[0].toolId).assertEqual('ride.estimate');
      expect(decision.actionIntent!.allowedActionIds.join(',')).assertEqual(
        'luckin.order.preview,payment.send'
      );
    });

    it('normalizes the omitted Action intent before the first mixed sequence round', 0,
      async () => {
      const context = actionOwnerContext();
      context.tools.push({
        toolId: 'ride.estimate',
        domain: 'ride',
        intent: 'ride.estimate',
        riskLevel: 'read',
        registeredBackends: ['local_adapter'],
        inputSchema: 'rideEstimateQuery',
        outputSchema: 'genericToolResults',
        actions: []
      });
      const model = new QueueLocalModel([
        MIXED_SEQUENCE_WITH_OMITTED_ACTION_INTENT_DECISION
      ]);
      const decision = await new MultiAgentLeaderPlanner(model).plan(
        inputMessage(),
        { text: MIXED_DATA_ACTION_QUERY },
        context,
        1
      );

      expect(model.prompts.length).assertEqual(1);
      expect(decision.requestedCapabilityIds.join(',')).assertEqual('ride.estimate');
      expect(decision.dataTasks.length).assertEqual(1);
      expect(decision.dataTasks[0].toolId).assertEqual('ride.estimate');
      expect(decision.actionIntent === undefined).assertTrue();
      expect(decision.reasonCode).assertEqual('sequence_requires_next_round');
    });

    it('does not request a second model decision while clearing an invalid skill', 0, async () => {
      const invalidSocialSkill: string = SOCIAL_ONLY_DECISION.replace(
        '"skillId":""',
        '"skillId":"travel-planning"'
      );
      const changedInput: string = SOCIAL_ONLY_DECISION.replace(
        '"platforms":["x","slack"]',
        '"platforms":["x"]'
      );
      const model = new QueueLocalModel([invalidSocialSkill, changedInput]);

      const decision = await new MultiAgentLeaderPlanner(model).plan(
        inputMessage(),
        { text: '帮我查看我今天 X 和 Slack 上的消息' },
        planningContext(),
        1,
        (): boolean => true
      );

      expect(model.prompts.length).assertEqual(1);
      expect(decision.skillId).assertEqual('');
      expect(JSON.stringify(decision.dataTasks[0].input))
        .assertEqual('{"platforms":["x","slack"]}');
    });

    it('rejects non-exact JSON, fields, IDs, ownership, and persona-skill pairs', 0, async () => {
      const extraTop = PARALLEL_DECISION.substring(0, PARALLEL_DECISION.length - 1) +
        ',"providerFacts":{}}';
      const forgedHostDate = PARALLEL_DECISION.substring(0, PARALLEL_DECISION.length - 1) +
        ',"normalizationCurrentLocalDate":"2026-07-20"}';
      const duplicateTop = PARALLEL_DECISION.replace(
        '"personaId":"travel_companion"',
        '"personaId":"travel_companion","personaId":"travel_companion"'
      );
      const unknownTool = PARALLEL_DECISION.replace('"flight.search"', '"missing.search"');
      const outsideAllowed = PARALLEL_DECISION.replace(
        '"allowedToolIds":["flight.search"]',
        '"allowedToolIds":["train.search"]'
      );
      const writeTool = PARALLEL_DECISION.replace(/flight\.search/g, 'payment.create');
      const actionOwnedReadTool = PARALLEL_DECISION.replace(/flight\.search/g, 'hotel.navigate');
      const wrongSkill = PARALLEL_DECISION.replace('"skillId":""', '"skillId":"missing-skill"');
      const duplicateLocalId = PARALLEL_DECISION.replace('"localId":"train"', '"localId":"flight"');
      const delimitedLocalId = PARALLEL_DECISION.replace(
        '"localId":"train"',
        '"localId":"step:round-1:x"'
      );
      const extraTask = PARALLEL_DECISION.replace(
        '"input":{},"required":false',
        '"input":{},"required":false,"providerOutput":{"secret":"x"}'
      );
      const duplicateNested = PARALLEL_DECISION.replace(
        '"toolId":"flight.search","input":{}',
        '"toolId":"flight.search","toolId":"flight.search","input":{}'
      );

      expect(await fails('model says ' + PARALLEL_DECISION)).assertTrue();
      expect(await fails(PARALLEL_DECISION + PARALLEL_DECISION)).assertTrue();
      expect(await fails(extraTop)).assertTrue();
      expect(await fails(forgedHostDate)).assertTrue();
      expect(await fails(duplicateTop)).assertTrue();
      expect(await fails(unknownTool)).assertTrue();
      expect(await fails(outsideAllowed)).assertTrue();
      expect(await fails(writeTool)).assertTrue();
      expect(await fails(actionOwnedReadTool)).assertTrue();
      expect(await fails(wrongSkill)).assertTrue();
      expect(await fails(duplicateLocalId)).assertTrue();
      expect(await fails(delimitedLocalId)).assertTrue();
      expect(await fails(extraTask)).assertTrue();
      expect(await fails(duplicateNested)).assertTrue();
      expect(await fails(ANSWER_WITHOUT_ANSWER_DECISION)).assertTrue();
      expect(await failsAtRound(PARALLEL_DECISION, 4)).assertTrue();
    });

    it('accepts zero Data only for an explicit registered Action intent', 0, async () => {
      const output: string = '{"personaId":"travel_companion","skillId":"",' +
        '"requestedCapabilityIds":["memory.update"],"roundAction":"execute","continuationMode":"complete","dataTasks":[],' +
        '"uiIntent":{"purpose":"remember","preferredDensity":"comfortable",' +
        '"requiredSections":[]},"actionIntent":{"goal":"remember explicit text",' +
        '"allowedActionIds":["memory.update"]},"reasonCode":"stable_preference"}';
      const planner = new MultiAgentLeaderPlanner(new QueueLocalModel([output]));
      const input: InputUserPayload = { text: '我在北京' };

      const decision = await planner.plan(inputMessage(), input, planningContext(), 1);

      expect(decision.dataTasks.length).assertEqual(0);
      expect(decision.actionIntent!.allowedActionIds[0]).assertEqual('memory.update');
    });

    it('accepts every Action owner self ID without relying on source actions', 0, async () => {
      const actionIds: string[] = [
        'memory.update',
        'worldcup.open',
        'maps.route.open',
        'calendar.event.create',
        'luckin.order.preview',
        'payment.send'
      ];
      for (let index = 0; index < actionIds.length; index++) {
        const actionId = actionIds[index];
        const planner = new MultiAgentLeaderPlanner(
          new QueueLocalModel([actionDecision(actionId)])
        );
        const decision = await planner.plan(
          inputMessage(),
          { text: '执行 ' + actionId },
          actionOwnerContext(),
          1
        );

        expect(decision.dataTasks.length).assertEqual(0);
        expect(decision.actionIntent!.allowedActionIds[0]).assertEqual(actionId);
      }
    });

    it('repairs exactly one Action-owned capability from Data into Action intent', 0,
      async () => {
      const actionIds: string[] = [
        'memory.update',
        'worldcup.open',
        'maps.route.open',
        'calendar.event.create',
        'luckin.order.preview',
        'payment.send'
      ];
      for (let index = 0; index < actionIds.length; index++) {
        const actionId = actionIds[index];
        const model = new QueueLocalModel([
          actionAsDataDecision(actionId),
          actionDecision(actionId)
        ]);
        const decision = await new MultiAgentLeaderPlanner(model).plan(
          inputMessage(),
          { text: '执行 ' + actionId },
          actionOwnerContext(),
          1,
          (): boolean => true
        );

        expect(model.prompts.length).assertEqual(2);
        expect(decision.dataTasks.length).assertEqual(0);
        expect(decision.actionIntent!.allowedActionIds[0]).assertEqual(actionId);
      }
    });

    it('gives Action ownership repair its one permitted Data-to-Action move', 0, async () => {
      const model = new QueueLocalModel([
        actionAsDataDecision('memory.update'),
        actionDecision('memory.update')
      ]);
      await new MultiAgentLeaderPlanner(model).plan(
        inputMessage(),
        { text: '记住我的偏好' },
        actionOwnerContext(),
        1,
        (): boolean => true
      );

      expect(model.prompts.length).assertEqual(2);
      expect(model.prompts[1].indexOf(
        'The corrected decision must preserve all three frozen sets exactly and must not move a ' +
          'capability between Data and actionIntent positions.'
      )).assertEqual(-1);
      expect(model.prompts[1].indexOf(
        'Action-owned repair freeze: preserve personaId, skillId, requestedCapabilityIds, roundAction, answer, ' +
          'uiIntent, each non-Action Data task, all existing Action IDs, and the original request intent exactly.'
      )).assertLarger(-1);
      expect(model.prompts[1].indexOf(
        'Move exactly one Action-only capability ID from Data positions to actionIntent.allowedActionIds.'
      )).assertLarger(-1);
      expect(model.prompts[1].indexOf(
        'When that move leaves dataTasks empty, set continuationMode to complete.'
      )).assertLarger(-1);
    });

    it('includes the rejected Action-owned decision without private observations in its repair prompt', 0,
      async () => {
      const rejected: string = actionAsDataDecision('worldcup.open');
      const model = new QueueLocalModel([
        rejected,
        actionDecision('worldcup.open')
      ]);
      await new MultiAgentLeaderPlanner(model).plan(
        inputMessage(),
        { text: '查看世界杯比赛信息' },
        actionOwnerContext(),
        1,
        (): boolean => true
      );

      expect(model.prompts.length).assertEqual(2);
      expect(model.prompts[1].indexOf('Rejected decision: ' + rejected)).assertLarger(-1);
      expect(model.prompts[1].indexOf('OBSERVATION_PRIVATE_SUMMARY')).assertEqual(-1);
      expect(model.prompts[1].indexOf('ENTITY_PRIVATE_MARKER')).assertEqual(-1);
    });

    it('rejects Action ownership repair that changes UI or moves multiple Action capabilities', 0,
      async () => {
      const changedUi: string = actionDecision('memory.update').replace(
        '"purpose":"perform requested action"',
        '"purpose":"changed purpose"'
      );
      const twoMisplaced: string = actionAsDataDecision('memory.update').replace(
        '"requestedCapabilityIds":["memory.update"]',
        '"requestedCapabilityIds":["memory.update","payment.send"]'
      ).replace(
        '],"uiIntent"',
        '},{"localId":"second","goal":"second","allowedToolIds":["payment.send"],' +
          '"toolId":"payment.send","input":{},"required":true}],"uiIntent"'
      );

      expect(await repairFails(
        actionAsDataDecision('memory.update'),
        changedUi,
        actionOwnerContext()
      )).assertTrue();
      expect(await repairFails(
        twoMisplaced,
        actionDecision('memory.update'),
        actionOwnerContext()
      )).assertTrue();
    });

    it('freezes Data and Action positions independently for a declared dual-role capability', 0,
      async () => {
        const context = planningContext();
        for (let index = 0; index < context.tools.length; index++) {
          if (context.tools[index].toolId === 'hotel.search') {
            context.tools[index].actions = ['hotel.detail'];
          }
        }
        context.tools.push({
          toolId: 'hotel.detail',
          domain: 'hotel',
          intent: 'hotel.detail',
          riskLevel: 'read',
          registeredBackends: ['local_adapter'],
          inputSchema: 'hotelDetailRequest',
          outputSchema: 'hotelRatePlans',
          actions: []
        });

        const dataToAction: string = await repairErrorCode(
          withoutPersona(hotelDetailDataOnlyDecision()),
          hotelDetailActionOnlyDecision(),
          context
        );
        const actionToData: string = await repairErrorCode(
          withoutPersona(hotelDetailActionOnlyDecision()),
          hotelDetailDataOnlyDecision(),
          context
        );
        const bothToData: string = await repairErrorCode(
          withoutPersona(hotelDetailDualRoleDecision()),
          hotelDetailDataOnlyDecision(),
          context
        );

        expect(dataToAction).assertEqual('LEADER_REPAIR_SCOPE_INVALID');
        expect(actionToData).assertEqual('LEADER_REPAIR_SCOPE_INVALID');
        expect(bothToData).assertEqual('LEADER_REPAIR_SCOPE_INVALID');
      });

    it('fails closed when repair replaces payment scope with Calendar, memory, or an owned capability', 0,
      async () => {
        const context = actionOwnerContext();
        expect(await repairFails(
          actionAsDataDecision('payment.send'),
          actionDecision('calendar.event.create'),
          context
        )).assertTrue();
        expect(await repairFails(
          actionAsDataDecision('payment.send'),
          actionDecision('memory.update'),
          context
        )).assertTrue();
        const unmigrated = actionAsDataDecision('unmigrated.action');
        expect(await repairFails(
          unmigrated,
          actionDecision('payment.send'),
          context
        )).assertTrue();
        const frozenRequestedIds: string =
          '"requestedCapabilityIds":["payment.send","calendar.event.create"]';
        expect(await repairFails(
          actionAsDataDecision('payment.send').replace(
            '"requestedCapabilityIds":["payment.send"]',
            frozenRequestedIds
          ),
          actionDecision('calendar.event.create').replace(
            '"requestedCapabilityIds":["calendar.event.create"]',
            frozenRequestedIds
          ),
          context
        )).assertTrue();
      });

    it('fails closed without a repair call when the first raw capability scope cannot be extracted', 0,
      async () => {
        const unextractable: string = MISSING_PERSONA_DECISION.replace(
          '"requestedCapabilityIds":[],',
          ''
        );
        const model = new QueueLocalModel([unextractable, LIVE_ANSWER_WITHOUT_REASON_CODE]);
        let failed: boolean = false;
        try {
          await new MultiAgentLeaderPlanner(model).plan(
            inputMessage(),
            { text: '你好' },
            planningContext(),
            1,
            (): boolean => true
          );
        } catch (_error) {
          failed = true;
        }

        expect(failed).assertTrue();
        expect(model.prompts.length).assertEqual(1);
      });

    it('keeps Data owners out of actionIntent unless a source declares the same ID as a follow-up', 0, async () => {
      expect(await fails(actionDecision('flight.search'))).assertTrue();

      const context = planningContext();
      for (let index = 0; index < context.tools.length; index++) {
        if (context.tools[index].toolId === 'hotel.search') {
          context.tools[index].actions = ['hotel.detail'];
        }
      }
      context.tools.push({
        toolId: 'hotel.detail',
        domain: 'hotel',
        intent: 'hotel.detail',
        riskLevel: 'read',
        registeredBackends: ['local_adapter'],
        inputSchema: 'hotelDetailRequest',
        outputSchema: 'hotelRatePlans',
        actions: []
      });
      const decision = await new MultiAgentLeaderPlanner(
        new QueueLocalModel([hotelDetailDualRoleDecision()])
      ).plan(inputMessage(), { text: '查看酒店详情' }, context, 1);

      expect(decision.dataTasks[0].toolId).assertEqual('hotel.detail');
      expect(decision.actionIntent!.allowedActionIds[0]).assertEqual('hotel.detail');
    });

    it('keeps source-declared page-only actions out of model Data and actionIntent ownership', 0,
      async () => {
        const context = planningContext();
        for (let index = 0; index < context.tools.length; index++) {
          if (context.tools[index].toolId === 'hotel.search') {
            context.tools[index].actions = [
              'hotel.search.restore',
              'unregistered.dynamic.action'
            ];
          }
        }
        context.tools.push({
          toolId: 'unregistered.dynamic.action',
          domain: 'client',
          intent: 'unregistered.dynamic.action',
          riskLevel: 'draft',
          registeredBackends: ['local_adapter'],
          inputSchema: 'clientActionRequest',
          outputSchema: 'clientActionResult',
          actions: []
        });
        let actionRejected: boolean = false;
        let dataRejected: boolean = false;
        let contextOnlyActionRejected: boolean = false;
        try {
          await new MultiAgentLeaderPlanner(
            new QueueLocalModel([actionDecision('hotel.search.restore')])
          ).plan(inputMessage(), { text: '返回酒店搜索页' }, context, 1);
        } catch (_error) {
          actionRejected = true;
        }
        try {
          await new MultiAgentLeaderPlanner(
            new QueueLocalModel([actionAsDataDecision('hotel.search.restore')])
          ).plan(inputMessage(), { text: '返回酒店搜索页' }, context, 1);
        } catch (_error) {
          dataRejected = true;
        }
        try {
          await new MultiAgentLeaderPlanner(
            new QueueLocalModel([actionDecision('unregistered.dynamic.action')])
          ).plan(inputMessage(), { text: '执行未注册 client action' }, context, 1);
        } catch (_error) {
          contextOnlyActionRejected = true;
        }

        expect(actionRejected).assertTrue();
        expect(dataRejected).assertTrue();
        expect(contextOnlyActionRejected).assertTrue();
      });

    it('requires unique registered requested capabilities covering every executed capability', 0, async () => {
      const missing: string = PARALLEL_DECISION.replace(
        '"requestedCapabilityIds":["flight.search","train.search"],',
        ''
      );
      const duplicate: string = PARALLEL_DECISION.replace(
        '"flight.search","train.search"',
        '"flight.search","flight.search","train.search"'
      );
      const unregistered: string = PARALLEL_DECISION.replace(
        '"flight.search","train.search"',
        '"flight.search","missing.search","train.search"'
      );
      const incomplete: string = PARALLEL_DECISION.replace(
        '"flight.search","train.search"',
        '"flight.search"'
      );

      expect(await fails(PARALLEL_DECISION)).assertFalse();
      expect(await fails(EXACT_MULTI_TOOL_ACTION_DECISION)).assertFalse();
      expect(await fails(missing)).assertTrue();
      expect(await fails(duplicate)).assertTrue();
      expect(await fails(unregistered)).assertTrue();
      expect(await fails(incomplete)).assertTrue();
      expect(await fails(HOTEL_WITH_EXTRA_DECISION)).assertTrue();
    });
  });
}
