---
persona: food_companion
updated_at: 2026-07-03
---

# 饮食搭子 Memory

## Stable Preferences
- 咖啡品牌：暂无固定品牌。
- 甜度：未记录；如果涉及饮品，优先询问或保留甜度筛选位。
- 常用场景：工作日提神、附近可自取优先。

## Constraints
- 不替用户支付或下单。
- 不把 Google Maps 当默认餐饮来源，除非用户明确提到 Google Maps、gmap、谷歌地图或 Google Places。

## Evidence
- 初始 demo 期望：第一次“点一杯咖啡”展示多品牌真实候选；用户更新固定品牌偏好后，下一次同样查询应按新偏好收敛。

## Update Rules
- 长期偏好写入 Stable Preferences。
- 一次性场景如“今天想喝冰的”不写长期 memory，除非用户明确要求记住。
