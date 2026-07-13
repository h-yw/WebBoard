# Feature Specification: WebView 预热加速

**Created**: 2026-07-13  
**Status**: Draft  
**Input**: Roadmap Item 3 — WebView 预热加速

## Overview

当前用户每次打开 HTML 查看器时，WebView 都是冷启动（新建 WebviewController → 创建 Web 组件 → 加载页面），导致明显的加载白屏等待。通过预热机制提前创建 WebViewController 并缓存 src，减少打开应用的感知延迟。

## User Scenarios & Testing

### User Story 1 - 作为用户，打开最常用的应用时感觉秒开 (Priority: P1)

首页空闲时（展示列表后 2 秒），系统自动预创建 2 个最常用应用的 WebviewController。当用户点击这些卡片时，WebContainer 直接使用预创建的控制器，跳过初始化阶段。

**Independent Test**: 预设两个应用（速算估算微练、JSBridge 测试），依次打开两次并关闭，第三次打开时计时应明显缩短。

**Acceptance Scenarios**:
1. **Given** 应用已打开超过 3 秒，**When** 查看 WebPreloader 内部状态，**Then** pool 中有 1-2 个预创建的 controller。
2. **Given** 用户点击已预热的应用卡片，**Then** WebContainer 使用预创建的 controller，页面加载时间不因 controller 初始化而增加。
3. **Given** pool 中的 controller 超过 5 分钟未使用，**Then** 自动过期清理。

### User Story 2 - 预加载不浪费资源 (Priority: P2)

预创建的 WebviewController 数量有上限（最多 2 个），超过 5 分钟不使用时自动释放。

**Independent Test**: 2 分钟内不操作，确认预创建的 controller 在 5 分钟后自动被清理。

**Acceptance Scenarios**:
1. **Given** pool 已达上限（2 个），**When** 尝试预创建第 3 个，**Then** 操作被忽略。
2. **Given** 预创建的 controller 已存在超过 5 分钟，**When** 检查 pool，**Then** 该 controller 已被移除。

## Requirements

### Functional Requirements
- **FR-001**: WebPreloader 必须能从 WebContainer 接收预创建的 WebviewController。
- **FR-002**: WebContainer 的构造函数必须支持接收可选的 `preloadController?: WebviewController` 参数，优先使用预创建的 controller。
- **FR-003**: WebPreloader 必须在首页空闲后（列表加载完成 2 秒后）自动预热前 2 个最常使用的应用。
- **FR-004**: 预热池最多保留 2 个条目，超过上限时忽略新请求。
- **FR-005**: 预热条目的 TTL 为 5 分钟，过期自动清理。
- **FR-006**: 当用户打开一个已预热的应用时，WebContainer 取出并使用对应的 controller，预热池同时移除该条目。
- **FR-007**: 预热机制必须有 feature flag，可随时降级为纯追踪器（当前行为）。

### Key Entities
- **PreloadEntry**: `{ key: string, controller: webview.WebviewController, createdAt: number }`
- **PreloadPool**: `PreloadEntry[]` 最大长度 2

## Success Criteria
- **SC-001**: 预热后的应用打开时，WebView 初始化阶段耗时减少到接近 0（无 `new WebviewController()` 开销）。
- **SC-002**: 预热池不会导致额外内存泄漏 — 连续打开 20 个不同应用后，系统内存不会持续增长。
- **SC-003**: 降级开关关闭后，行为完全回退到当前实现（对照无差异）。

## Assumptions
- ArkUI 允许提前创建 WebviewController 而不附加到组件树（已验证可行）。
- WebviewController 被复用后，通过 `Web({ src, controller })` 重新绑定到新页面时，能正确加载新 src 而不残留旧状态。
- 最常用应用的判定依据是 `open_count` 字段（目前已有记录机制）。

## Open Questions
- 创建后未使用的 WebviewController 是否会持有系统资源？（理论上会占用一定内存，所以设定 5 分钟 TTL 和最多 2 个的限制）
