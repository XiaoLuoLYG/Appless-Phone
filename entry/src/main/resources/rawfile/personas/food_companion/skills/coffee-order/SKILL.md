---
name: coffee-order
description: Preview and confirm Luckin coffee orders with real store, SKU, and pricing data.
tools:
  - luckin.order.preview
  - luckin.order.create
  - luckin.order.status
status: active
---

# Coffee Order

## When to Use
用户明确要点、买、下一杯瑞幸咖啡，或指定瑞幸商品（如生椰拿铁、冰美式、澳瑞白）并希望下单。

## Checklist
- 初始瑞幸点单只调用 luckin.order.preview，让工具查询门店、商品 SKU 和 previewOrder 价格。
- 用户确认后才调用 luckin.order.create。
- 用户查询取餐码、订单状态或刷新订单时调用 luckin.order.status。

## Boundaries
不替用户支付；支付链接或二维码只能来自瑞幸 MCP 的真实返回。
