# Feature Specification: WebBoard Refactor — "浮叶 (WebLeaf)"

**Created**: 2026-07-09  
**Status**: Draft  
**Input**: User description from `docs/refactor.md` + supplemental optimizations

## Overview

对现有的 HarmonyOS 应用 WebBoard 进行全面迭代优化，包括中文品牌命名「浮叶」/ 英文名「WebLeaf」、文件与网络导入机制重构、数据存储从 Preferences 迁移至 SQLite、通用 UI 能力封装（Toast/Loading/Dialog）、UI/UX 全面升级，以及代码结构和性能优化。目标是将应用打造为更现代、更高效、更具品牌感的 HTML 内容管理工具。

## User Scenarios & Testing

### User Story 1 - 品牌形象全面焕新 (Priority: P1)

用户打开应用时，看到全新的品牌名称「浮叶 / WebLeaf」、更新后的应用图标与启动页，所有页面内引用均统一为新品牌名。

**Why this priority**: 品牌更名是所有后续改版的基础，涉及应用配置、资源文件、代码中所有字符串引用。

**Independent Test**: 安装应用后，桌面图标显示新名称「浮叶」，设置页面显示版本信息和品牌名「浮叶 / WebLeaf」。

**Acceptance Scenarios**:
1. **Given** 应用已安装，**When** 查看桌面应用图标，**Then** 显示名称为「浮叶」
2. **Given** 进入设置页，**When** 查看关于信息，**Then** 显示「浮叶 WebLeaf」及版本号
3. **Given** 应用任意页面，**When** 查看导航栏标题，**Then** 显示「浮叶」而非「WebBoard」

---

### User Story 2 - SQLite 数据存储迁移 (Priority: P1)

应用的 Web 应用数据从 Preferences 迁移至 SQLite 关系型数据库，提供结构化的数据管理能力。

**Why this priority**: SQLite 是后续功能（搜索、分类、排序）的基础，且需要优先迁移以清空旧数据全新开始。

**Independent Test**: 导入一个 HTML 应用后，数据存储在 SQLite 数据库中。重启应用后该应用仍然存在并可正常打开。

**Acceptance Scenarios**:
1. **Given** 数据库已初始化，**When** 导入一个新的 HTML 应用，**Then** 数据写入 SQLite 的 apps 表
2. **Given** SQLite 中有应用数据，**When** 重启应用并返回首页，**Then** 应用列表正常加载
3. **Given** 导入应用后，**When** 删除该应用，**Then** SQLite 中对应记录被删除

---

### User Story 3 - 网络导入支持纯 URL 引用 (Priority: P1)

用户从 URL 导入 HTML 应用时，不再需要下载到本地，系统直接记录 URL 地址并通过 Web 组件在线加载。

**Why this priority**: 减少不必要的下载和存储空间占用，提升导入效率。

**Independent Test**: 输入一个 URL 并保存后，打开该应用时 Web 组件直接加载网络 URL，显示对应网页内容。

**Acceptance Scenarios**:
1. **Given** 用户输入有效的 HTML 页面 URL，**When** 保存导入，**Then** 仅记录 URL 不下载文件
2. **Given** 已保存的 URL 导入项，**When** 在查看页打开，**Then** Web 组件加载该 URL 显示内容
3. **Given** 无网络连接时，**When** 尝试打开 URL 导入项，**Then** 显示网络错误提示

---

### User Story 4 - 文件导入支持持久化授权 (Priority: P2)

从本地文件导入 HTML 时，尝试通过 `ohos.fileshare.persistPermission` 获取持久化授权，使应用重启后仍能直接访问原文件路径。

**Why this priority**: 减少文件复制开销，同时保持应用重启后的文件访问能力。复杂度较高，列为 P2。

**Independent Test**: 选择外部 HTML 文件导入后，杀掉应用进程重新打开，该应用仍能正常加载。

**Acceptance Scenarios**:
1. **Given** 设备支持持久化授权，**When** 选择外部 HTML 文件导入，**Then** 调用 persistPermission 持久化授权
2. **Given** 已持久化授权的文件，**When** 重启应用并访问该应用，**Then** 调用 activatePermission 激活权限后加载
3. **Given** 设备不支持持久化授权，**When** 选择外部文件，**Then** 回退到沙箱复制方案

---

### User Story 5 - 通用 UI 能力封装 (Priority: P2)

提供全局可用的 Toast、Loading、Dialog 工具函数，统一应用的交互反馈体验。

**Why this priority**: 消除各页面零散的 promptAction / AlertDialog 调用，提升代码复用性和交互一致性。

**Independent Test**: 在任意页面调用 Toast.show()、Loading.show()、Dialog.confirm()，均可正常显示对应 UI 元素。

**Acceptance Scenarios**:
1. **Given** 任意页面，**When** 调用 `Toast.show('操作成功')`，**Then** 底部/居中显示提示消息并在 1.5s 后自动消失
2. **Given** 执行耗时操作，**When** 调用 `Loading.show('加载中...')`，**Then** 显示加载动画弹窗，操作完成后 `Loading.hide()` 关闭
3. **Given** 需要用户确认的操作，**When** 调用 `Dialog.confirm({title:'确认', message:'确定删除吗？'})`，**Then** 显示确认弹窗，用户可选择确认或取消

---

### User Story 6 - UI/UX 全面升级 (Priority: P2)

基于新品牌「浮叶 / WebLeaf」对应用视觉风格、交互体验、页面布局进行全面优化，完美适配系统深色/浅色模式。

**Why this priority**: 提升用户体验和品牌感知，但功能实现后美学优化可逐步进行。

**Independent Test**: 切换系统深色/浅色模式后，应用各页面自动适配，所有 UI 元素风格统一。

**Acceptance Scenarios**:
1. **Given** 应用首页，**When** 切换 Grid/List 布局，**Then** 切换动画流畅，布局正确
2. **Given** 系统切换深色模式，**When** 返回应用，**Then** 所有页面自动适配深色主题
3. **Given** 任意页面，**When** 执行操作（导入、保存、删除），**Then** 有对应的过渡动画和反馈

---

### User Story 7 - 国际化支持 (Priority: P3)

应用支持中英文界面切换，根据系统语言自动适配，品牌名「浮叶 / WebLeaf」在不同语言下显示对应名称。

**Why this priority**: 扩大目标用户群，但当前主要用户为中文用户，优先级较低。

**Independent Test**: 切换系统语言为 English，重启应用后界面文字切换为英文。

**Acceptance Scenarios**:
1. **Given** 系统语言为中文，**When** 打开应用，**Then** 所有界面文字显示中文
2. **Given** 系统语言为 English，**When** 打开应用，**Then** 所有界面文字显示英文
3. **Given** 应用运行中切换系统语言，**When** 返回应用，**Then** 界面语言实时切换

---

### User Story 8 - 代码结构优化与性能提升 (Priority: P3)

重构代码结构，抽取公共逻辑，优化 Web 预加载和列表渲染性能。

**Why this priority**: 提升可维护性和性能，但对用户无直接感知，优先级较低。

**Independent Test**: 在 20+ 应用列表页面快速滚动，无明显卡顿。Web 预加载命中率提升。

**Acceptance Scenarios**:
1. **Given** 应用列表有 20+ 项，**When** 快速滚动列表，**Then** 帧率流畅无白块
2. **Given** 最近使用的应用，**When** 从首页点击打开，**Then** 预加载机制生效，加载速度显著提升

### Edge Cases

- 持久化授权设备不支持时，自动回退沙箱复制方案
- 网络导入 URL 失效时，显示友好的错误提示并提供重新编辑 URL 的入口
- SQLite 数据库损坏时，自动重建并提示用户重新导入数据
- 语言切换时，已缓存的页面内容不自动翻译

## Requirements

### Functional Requirements

- **FR-001**: 应用 MUST 在安装后显示中文名称「浮叶」和英文名称「WebLeaf」
- **FR-002**: 系统 MUST 支持使用 `@ohos.data.relationalStore` 操作 SQLite 数据库存储应用数据
- **FR-003**: SQLite 数据库 MUST 包含 web_apps 表（id, name, description, logo_type, logo_uri, entry_html, source_type, create_time）和 settings 表（key, value）
- **FR-004**: 导入 HTML 文件时 MUST 先尝试持久化授权，失败时回退到沙箱复制方案
- **FR-005**: 网络导入 MUST 支持直接记录 URL 引用，不下载到本地
- **FR-006**: Web 查看组件 MUST 能加载网络 URL（https/http）和本地沙箱文件
- **FR-007**: 系统 MUST 导出全局工具函数 `Toast.show()`、`Loading.show()`/`Loading.hide()`、`Dialog.confirm()`
- **FR-008**: 应用 MUST 支持通过系统深色/浅色模式自动切换主题
- **FR-009**: 应用 MUST 支持中英文界面切换，跟随系统语言设置
- **FR-010**: 系统 MUST 将应用内所有「WebBoard」引用更新为「浮叶」/「WebLeaf」

### Key Entities

- **WebAppItem (应用条目)**: 表示一个 HTML 应用，包含 id、名称、描述、图标类型/URI、入口 HTML（本地路径或网络 URL）、来源类型（预设/文件/网络）、创建时间。存储在 SQLite web_apps 表中。
- **AppSettings (应用设置)**: 键值对形式的设置项，包括 color_mode（颜色模式）、preload_enabled（预加载开关）、layout_mode（布局模式）。存储在 SQLite settings 表中。
- **SourceType**: 应用来源类型枚举，扩展为 PRESET（预设）、FILE（本地文件）、URL（网络引用）。
- **UI Utility (UI 工具)**: 全局可用的 Toast/Loading/Dialog 工具函数集合，不依赖特定页面上下文。

## Success Criteria

### Measurable Outcomes

- **SC-001**: 用户从输入 URL 到保存导入，耗时 < 2 秒（无需下载等待）
- **SC-002**: SQLite 数据库读写操作响应时间 < 50ms
- **SC-003**: 所有页面在深色/浅色模式下均正确渲染，无文字/背景对比度问题
- **SC-004**: UI 工具函数在任意页面调用均可正常显示，无白屏或崩溃
- **SC-005**: 中英文切换覆盖度 > 90% 的 UI 字符串
- **SC-006**: 应用列表 20+ 项时滚动帧率 > 55fps

## Assumptions

- 目标 SDK 版本为 API 12+ (HarmonyOS 6.0.2)，支持 `@ohos.data.relationalStore`、`ohos.fileshare` 等 API
- 持久化授权 `ohos.fileshare.persistPermission` 需要 `ohos.permission.FILE_ACCESS_PERSIST` 权限，部分设备可能不支持
- 旧 Preferences 数据将被清空，不执行自动迁移
- 应用更名涉及 AppScope 配置、资源文件、代码字符串、应用图标等全局更新
- 国际化 i18n 采用 resource 目录下的多语言文件（zh-CN / en-US）

## Open Questions

- [NEEDS CLARIFICATION: 持久化授权方案中，是否需要为已导入的每个文件单独维护持久化授权状态？建议在 SQLite apps 表中增加 persist_uri 和 persist_mode 字段。]
- 文件导入是否保留「目录扫描」功能（当前 WorkDirectory.scanDirectory）？建议保留并适配 SQLite。
