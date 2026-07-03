---
name: travel-planning
description: Compare real itinerary, train, and flight options against user travel preferences.
tools:
  - travel.search
  - train.search
  - flight.search
  - memory.update
status: active
---

# Travel Planning

## When to Use
用户请求路线、目的地、周末出行、火车/高铁、航班、机场或跨城方案。

## Checklist
- 读取 memory 中的出发地、座位、预算、不便时间和同行偏好。
- 城市/附近安排走 travel.search；火车/高铁走 train.search；航班走 flight.search。
- 比较总耗时、到达时间、换乘、价格、余票和用户偏好。
- 长期偏好变化先调用 memory.update，再让用户重新查。

## Boundaries
不编造班次、票价、余票、延误、酒店或景点开放状态。
