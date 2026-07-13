# Feature Specification: Code Quality Fixes

**Created**: 2026-07-13
**Status**: Draft
**Input**: Review report of WebBoard project — comprehensive code quality improvements

## Overview

对 WebBoard 项目进行全面的代码质量改进和 Bug 修复，涵盖架构一致性、组件可靠性、代码清理和性能优化。这些改进基于深度代码审查发现的 15 项问题，按优先级分为高、中、低三档。所有修改均在不破坏现有功能的前提下提升代码可维护性、可靠性和开发体验。

## User Scenarios & Testing

### User Story 1 - 导航架构统一 (Priority: P1)

SplashPage 从废弃的 `router.replaceUrl()` 迁移至 Navigation 体系，确保应用内页面跳转方式一致。

**Why this priority**: 使用废弃 API 存在未来 SDK 版本不兼容风险，且与项目其余部分架构不一致。

**Independent Test**: 应用启动后闪屏动画正常播放，自动跳转到首页，返回操作符合预期。

**Acceptance Scenarios**:
1. **Given** 用户打开应用, **When** 闪屏页加载完成, **Then** 自动跳转到 Index 首页
2. **Given** 用户正在查看闪屏页, **When** 用户点击"跳过"按钮, **Then** 立即跳转到首页
3. **Given** 应用处于前台, **When** 物理返回键被按下, **Then** 不会返回到闪屏页

---

### User Story 2 - WebView 预加载修复 (Priority: P1)

WebPreloader 从仅记录 key 改为真正创建隐藏 Web 组件并加载内容，实现秒开效果。

**Why this priority**: 当前预加载器形同虚设（只创建 controller 不加载），修复后用户体验有实质提升。

**Independent Test**: 访问一个应用后返回首页，再次打开同一应用时页面应已预加载完成。

**Acceptance Scenarios**:
1. **Given** 用户已访问过一个本地 HTML 应用, **When** 返回首页后再次点击该应用, **Then** 页面应在 300ms 内显示完成
2. **Given** 预加载列表已满（5个）, **When** 用户访问新应用, **Then** 最旧的预加载项被淘汰

---

### User Story 3 - EventEmitter 监听器管理修复 (Priority: P1)

修复 `EventEmitter.off()` 移除所有同名监听器的问题，改为按注册句柄精确移除。

**Why this priority**: 若多页面同时监听同一事件，一个页面的 `off()` 调用会错误地移除其他页面的监听器，导致跨页面同步失效。

**Independent Test**: 两个组件分别注册同一事件的监听器，其中一个卸载时不影响另一个的监听。

**Acceptance Scenarios**:
1. **Given** 组件 A 和组件 B 都监听了 "item:update" 事件, **When** 组件 B 卸载并调用 off(), **Then** 组件 A 的监听器仍然有效
2. **Given** 监听器已注册, **When** 事件被触发, **Then** 所有有效监听器按注册顺序收到回调

---

### User Story 4 - Dialog 和 Loading 组件可靠性修复 (Priority: P1/P2)

Dialog 的 `dialogState` 改为使用 `@Component` 封装，确保状态刷新可靠。Loading 的 `wrapBuilder` 替换为 API 12+ 推荐的 builder 模式。

**Why this priority**: Dialog 当前使用普通全局变量，ArkTS 严格模式下无法保证 UI 刷新，可能导致弹窗内容不更新。

**Independent Test**: 依次调用两次 Dialog.confirm() 带不同内容，第二次弹窗应正确显示新内容而非缓存旧内容。

**Acceptance Scenarios**:
1. **Given** Dialog 正在显示, **When** 状态变更, **Then** UI 立即刷新显示最新状态
2. **Given** Loading 正在显示, **When** 再次调用 Loading.show(), **Then** 不会出现多个重叠 loading

---

### User Story 5 - 代码清理与质量优化 (Priority: P3)

清理死代码（EventMap）、统一日志工具（Logger→hilog）、修复 ViewerPage 返回逻辑重复、启用 hvigor 编译优化、消除硬编码颜色、删除不必要的运行时类型判断。

**Why this priority**: 持续改进代码质量降低维护成本。

**Independent Test**: 应用构建无警告通过，日志格式一致，返回操作行为正确。

**Acceptance Scenarios**:
1. **Given** 代码库, **When** 编译, **Then** 无关于死代码或废弃 API 的 lint 警告
2. **Given** ViewerPage 打开, **When** 用户按返回键, **Then** Web 历史回退优先，无回调后 pop NavStack

---

### Edge Cases

- 预加载时应用被系统回收 → 预加载列表清空，下次启动正常重新预加载
- 多个组件同时监听到同一事件 → 所有有效监听器均收到通知
- Dialog 在组件卸载时未关闭 → 应优雅处理，不抛出异常
- SplashPage 的动画期间应用被切到后台 → 回到前台时动画继续或直接跳转

## Requirements

### Functional Requirements

- **FR-001**: SplashPage MUST 使用 Navigation（NavPathStack）替代 router.replaceUrl() 进行页面跳转
- **FR-002**: SplashPage MUST 保留完整的动画效果（叶片弹入、标题上浮、进度条推进）
- **FR-003**: WebPreloader MUST 真正创建 Web 组件并加载内容，而非仅存储 controller
- **FR-004**: WebPreloader MUST 保持 LRU 淘汰策略（max 5）和 5 分钟 TTL 失效机制
- **FR-005**: EventEmitter MUST 支持按注册句柄精确移除监听器
- **FR-006**: EventEmitter MUST 保持与现有 emit/on 接口兼容
- **FR-007**: Dialog 组件 MUST 使用 `@Component` 结构替代全局变量确保 UI 刷新
- **FR-008**: Loading 组件 MUST 使用 API 12+ 推荐的 builder 模式
- **FR-009**: 死代码 `EventMap` MUST 被移除
- **FR-010**: Logger 工具 MUST 统一使用 `@kit.PerformanceAnalysisKit` 的 hilog
- **FR-011**: ViewerPage 的 `onBackPressed` 和 `handleBackPress` MUST 合并为单一逻辑
- **FR-012**: hvigor-config.json5 中的 daemon、incremental、parallel 优化选项 MUST 被启用
- **FR-013**: DialogUtil 中的运行时 `typeof` 类型判断 MUST 替换为编译期类型安全方案
- **FR-014**: 硬编码颜色值 MUST 统一迁移到 `color.json` 资源文件中
- **FR-015**: Index.ets 超过 800 行，建议将共享逻辑抽取到独立工具文件

### Key Entities

- **EventEmitter**: 跨页面事件总线，支持按 ID 注册/注销监听器
- **DialogComponent**: 基于 `@Component` 的弹窗组件，替代全局变量模式
- **PreloadEntry**: 预加载条目，包含 WebviewController、加载状态、时间戳

## Success Criteria

### Measurable Outcomes

- **SC-001**: 所有 4 项 🔴 修复通过自动化验证（路由统一、预加载生效、事件监听正确、Dialog 刷新正常）
- **SC-002**: 应用构建 0 error、0 warning
- **SC-003**: 代码中无废弃 API（`router.replaceUrl`、`wrapBuilder`）使用
- **SC-004**: 死代码覆盖率为 0（`EventMap` 等已移除）
- **SC-005**: Index.ets 体积减少至少 15%（通过逻辑抽取）

## Assumptions

- 所有修复保持与现有业务逻辑的向后兼容性
- Dialog 和 Loading 现有调用方式（`Dialog.confirm()`、`Loading.show()`）不变
- SplashPage 的独立 NavPathStack 方案不引入额外性能开销
- 预加载仅在用户有可预加载内容时生效（已访问过至少一个应用）
- 不引入新的第三方依赖

## Open Questions

- Index.ets 的抽取粒度：是否将 shareAppCard、deleteDirectory、startScan 全部抽取，还是仅抽取部分？
