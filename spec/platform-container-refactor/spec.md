# Feature Specification: 浮叶（WebLeaf）平台容器化与轻应用分发重构

**Created**: 2026-07-13  
**Status**: Draft  
**Input**: User description: "平台容器化重构，实现容器与业务分离，纯粹化入口，提炼 JS SDK 并设计轻应用演示市场"

## Overview

为了将底层容器能力（WebView渲染、JSBridge、数据库持久化等）与上层垂直业务（如轻应用市场、教育组件、企业工具等）解耦，本项目将进行**平台容器化重构**。

重构后的系统将分离为：
1. **容器底座（Container Core）**：以 HSP（Harmony Shared Package）动态共享包形式存在，封装 WebView、JSBridge、数据库及系统原生能力。
2. **应用分发与管理壳（Entry HAP）**：纯粹化的入口，只包含品牌启动页、本地轻应用管理器、以及一个展示内置 rawfile 演示应用的“轻应用市场”。
3. **前端 JS SDK**：提炼标准的客户端 API 包装层，对 H5 开发者提供规范、好用的原生调用接口。

## User Scenarios & Testing

### User Story 1 - 作为普通用户，我能通过“轻应用市场”发现并一键添加内置演示应用 (Priority: P1)

用户进入应用后，除了手动导入本地 HTML，还能在首页或市场页浏览内置的演示应用。点击“添加”卡片后，该应用会被保存到本地轻应用列表中；点击应用能通过统一的容器拉起并正常运行。

**Why this priority**: 这是轻应用平台化转型最核心的用户链路。它改变了用户只能手动寻找并拷贝 H5 文件的繁琐体验，极大地降低了使用门槛。

**Independent Test**: 在不添加任何复杂插件或本地功能的情况下，启动应用进入“轻应用市场”，点击其中一个演示卡片，验证其是否成功保存至本地列表，并能点击拉起 WebView 正常加载该网页。

**Acceptance Scenarios**:

1. **Given** 用户在首页，**When** 点击切换到“轻应用市场”标签，**Then** 界面展示内置的演示应用列表。
2. **Given** 市场列表，**When** 点击某个应用的“添加/获取”按钮，**Then** 提示添加成功，且该应用立即同步到本地列表中，卡片标记为“预设”来源。
3. **Given** 本地列表，**When** 点击新添加的演示应用卡片，**Then** 跳转至查看器，加载对应的 rawfile 路径。

---

### User Story 2 - 作为 H5 开发者，我可以使用标准的 webleaf-sdk 极简地调用系统能力 (Priority: P2)

H5 开发者在编写轻应用网页时，无需理解底层 JSBridgeHandle 的原生接口细节。他们只需要在网页中引用 SDK 或直接使用全局挂载的 `webLeaf` 对象，调用标准方法（如 `webLeaf.getAppInfo()`），即可通过标准 Promise 形式获取原生信息。

**Why this priority**: 规范的前端 SDK 是生态建立的基石。良好的开发体验是吸引第三方开发者为平台提供 H5 内容的关键。

**Independent Test**: 加载测试页面，通过网页中的 JS 代码调用 `window.webLeaf.getAppInfo().then(...)`。验证是否能成功收到格式规范、字段完整的原生信息，并且支持标准的异步 catch 异常。

**Acceptance Scenarios**:

1. **Given** 查看器加载了支持 SDK 调用的测试 H5，**When** 网页执行 SDK 的 API 调用，**Then** 无需关心复杂的 JSON 解析，直接通过 `.then()` 拿到强类型数据。
2. **Given** H5 页面一加载就立即调用 SDK，**When** 页面加载完成，**Then** SDK 内部能妥善处理加载顺序的时机偏差，保证 `webLeaf` 对象完全 Ready 后再触发调用，不产生未定义错误。

---

### User Story 3 - 作为应用，系统底层容器（HSP）应当保持独立且高效，上层管理壳保持轻量 (Priority: P3)

用户打开应用时，启动页快速展现并平滑过渡到首页。首页加载速度和内存占用不受复杂业务代码影响，底层 `container` (HSP) 动态按需加载，实现高复用和高响应。

**Why this priority**: 保证优秀的冷启动性能和合理的系统架构设计。

**Independent Test**: 编译打包 entry.hap 和 container.hsp 并运行，验证应用冷启动时间符合原生性能要求，且模块间调用无崩溃或加载卡顿。

**Acceptance Scenarios**:

1. **Given** 应用首次安装，**When** 启动 App，**Then** SplashPage 平滑展现，平滑过渡到本地应用列表。
2. **Given** 数据库操作或查看器启动，**When** HSP 代码在运行时被激活，**Then** 系统能正常完成动态链接，页面不卡顿。

### Edge Cases

- 轻应用市场中的演示应用源自 rawfile，无需网络即可使用。但后续版本可能支持线上 URL 分发，届时需要处理网络不可用时的错误回退。
- JSBridge 异步调用超时或中断：H5 频繁调用高耗时原生接口（例如系统图片选取后取消），SDK 需能妥善捕获错误并返回标准规范的失败状态，不导致 H5 阻塞。
- 多模块打包签名与安装冲突：在真机调试多模块时，需确保 entry.hap 依赖的 container.hsp 签名一致并共同安装，否则会导致运行崩溃。

## Requirements

### Functional Requirements

- **FR-001**: 必须将现有工程解耦为独立的应用主入口模块（`entry` HAP）与容器核心模块（`container` HSP）。
- **FR-002**: 容器模块（`container`）必须完全接管关系型数据库（RelationalStore）的所有操作。
- **FR-003**: 容器模块（`container`）必须封装好包含 JSBridge 交互、加载进度条、错误重试与返回按键拦截的 `WebContainer` 组件，并向外暴露。
- **FR-004**: 必须提炼出一个统一的前端包装层 `webleaf-sdk.js`，该 SDK 挂载于 `window.webLeaf`，并使用 Promise 封装底层 `JSBridgeHandle` 的 8 个方法（getAppInfo, modifyNavStyle, systemShare, systemImagePick, vibrate, onBackPress, navigateBack, call）。
- **FR-005**: 容器底座在 WebView 页面加载开始时，必须自动在全局注入 `window.webLeaf`，保证 H5 网页不引用本地 JS 文件也能直接使用。
- **FR-006**: 应用入口（`entry`）必须移除非必要的底层逻辑（如数据库原始访问、FileManager、WebPreloader 等），将其收拢为对 `container` 的高层调用。
- **FR-007**: 应用入口（`entry`）首页中必须实现一个“轻应用市场”标签/区域，使用静态数据展示 rawfile 中已有的 HTML5 应用（如 JSBridge 测试页、速算估算微练等），作为分发演示。

### Key Entities

- **WebAppItem**：代表一个轻应用项。包含：id, name, description, logoType, logoUri, entryHtml, sourceType（新增 `'url'` 的支持，代表线上网页）, createTime, persistUri, persistMode。
- **Settings**：用户偏好设置。包含：selectedMode（外观模式：跟随系统、浅色、深色），preloadEnabled（是否启用预载）。

## Success Criteria

### Measurable Outcomes

- **SC-001**: 成功完成 HSP 模块与 HAP 模块的分离，在真机和模拟器上编译成功（`BUILD SUCCESSFUL`）。
- **SC-002**: 动态自动注入成功。任何在线/离线 HTML5 页面中，`typeof window.webLeaf` 的返回值应当在页面生命周期的 `onPageEnd` 及之后为 `'object'`。
- **SC-003**: 用户在“轻应用市场”中点击添加演示应用，该应用 100% 被保存到本地列表，且点击能够顺利跳转并加载对应的 rawfile 内容。
- **SC-004**: 所有的单元或页面级交互保持原有的稳定性，长按卡片操作、二维码扫码、编辑修改等功能在多模块重构后功能完全正常。

## Assumptions

- 假设 HarmonyOS API 12+ (SDK 6.0.2) 完美支持同一个包名下 HAP 依赖并联合安装 HSP，无需额外的企业级复杂签名配置。
- 假设重构不引入任何破坏性的 API 变更，原有的预设应用（如 JSBridge 测试、速算估算微练）依然能够正常运行且无需修改 HTML 代码。

## Open Questions

- **H5 调用的 SDK 版本控制**：自动注入的 `webLeaf` 对象如何向网页提供自身的版本号？（暂时决定在 `getAppInfo()` 中顺带返回容器及 SDK 的版本号）。
