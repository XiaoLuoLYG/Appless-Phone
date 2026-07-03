---
name: food-search
description: Search nearby coffee, milk tea, restaurants, and food options with real provider results.
tools:
  - food.search
  - memory.update
status: active
---

# Food Search

## When to Use
用户请求咖啡、奶茶、餐厅、美食、附近店铺、外卖建议，或表达“帮我点/找/买一杯”的饮食意图。

## Checklist
- 读取 memory 中的品牌、甜度、忌口、预算、自取/配送偏好。
- 需要真实店铺结果时调用 food.search。
- 品牌词如瑞幸、星巴克、麦当劳、霸王茶姬仍走 food.search，把品牌作为筛选条件。
- 如果用户表达长期偏好，调用 memory.update，并建议重新查询。

## Boundaries
不伪造门店、价格、营业状态、评分、优惠或配送时间。不替用户支付或下单。
