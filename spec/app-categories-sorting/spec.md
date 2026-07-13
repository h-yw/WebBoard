# Feature Specification: 应用分组 + 排序

## Overview
为 WebBoard 增加应用分组管理和多维度排序功能。

## Requirements
- **FR-001**: web_apps 表扩展字段：category, sort_order, open_count, last_opened_at（ALTER TABLE）
- **FR-002**: 新建 categories 表：id, name, icon, sort_order
- **FR-003**: DB_VERSION 从 1 升级到 2，含迁移逻辑
- **FR-004**: Index.ets 增加分组 Tab 栏（全部/分组1/分组2/...）
- **FR-005**: Index.ets 增加排序下拉（最近使用/名称/手动/创建时间）
- **FR-006**: 可在设置页管理分组（创建/重命名/删除）
- **FR-007**: 长按应用卡片可移动至分组
