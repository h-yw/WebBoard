# Feature Specification: JSBridge 平台安全增强与 SDK 标准化

**Created**: 2026-07-13  
**Status**: Draft  
**Input**: User request: "对 JSBridge 进行平台化改进，包含权限管控、版本协商、错误码标准化、回调防泄漏、原生推事件、iframe 支持、调试模式"

## Overview

当前 WebBoard 的 JSBridge 实现缺少平台级安全管控、标准化错误处理和开发者工具支持。任何 H5 页面都可以调用所有原生能力（振动、分享、文件选择等），回调可能泄漏，错误信息是非结构化的自由文本。

本次增强将 JSBridge 从一个"裸桥"升级为具备安全边界、可观测、可调试的平台级 SDK 基础设施，为未来第三方 H5 应用的开放性铺平安全基座。

## User Scenarios & Testing

### User Story 1 - 平台运营者：我能按来源控制原生能力访问 (Priority: P1)

作为平台运营者，我不希望随机加载的第三方 H5 网页能够随意调用系统分享、图片选择、振动等原生 API。我可以配置不同来源（rawfile 内置 / 本地文件 / 线上网页）的权限策略，敏感方法（如 `systemShare`、`systemImagePick`、`vibrate`）在非受信来源下自动拒绝。

**Why this priority**: 安全是平台化最关键的基石。无权限管控时，恶意 H5 可以在用户无感知的情况下调用敏感原生能力。

**Independent Test**: 加载一个线上 URL 类型的 H5 应用，尝试调用 `window.webLeaf.systemShare()`，验证调用被拒绝并返回 `PERMISSION_DENIED` 错误码。rawfile 内置应用调用相同方法时正常执行。

**Acceptance Scenarios**:

1. **Given** 一个 rawfile 内置应用 (源类型为 `'rawfile://'`)，**When** 调用任何 JSBridge 方法，**Then** 所有方法均可执行（完全信任）。
2. **Given** 一个本地文件导入应用 (源类型为 `'file://'`)，**When** 调用 `vibrate`/`systemShare`/`systemImagePick`，**Then** 返回 `{ code: 'PERMISSION_DENIED' }`。
3. **Given** 一个线上 URL 应用 (源类型为 `'https://'`)，**When** 调用 `getAppInfo`/`modifyNavStyle`（非敏感），**Then** 正常执行；调用 `vibrate`，**Then** 返回 `PERMISSION_DENIED`。

---

### User Story 2 - H5 开发者：我能通过 SDK 自省了解运行环境 (Priority: P1)

开发者在编写轻应用时，可以通过 `window.webLeaf.getVersion()` 获取 SDK 版本、容器版本和 API 级别。在调用某个新方法前，可以通过 `window.webLeaf.hasMethod('methodName')` 判断当前环境是否支持。

**Why this priority**: SDK 版本协商是生态开放的基础。没有版本信息，H5 无法知道自己运行在什么环境，也无法优雅降级。

**Independent Test**: 在任意 H5 页面中执行 `window.webLeaf.getVersion().then(v => console.log(v))`，收到包含 sdk、container、api 字段的 JSON。

**Acceptance Scenarios**:

1. **Given** 容器已初始化，**When** H5 调用 `webLeaf.getVersion()`，**Then** 返回 `{ sdk: '1.0.0', container: '1.0.0', api: 1 }`。
2. **Given** 容器已初始化，**When** H5 调用 `webLeaf.hasMethod('vibrate')`，**Then** 返回 `true`。
3. **Given** 容器已初始化，**When** H5 调用 `webLeaf.hasMethod('nonExistentMethod')`，**Then** 返回 `false`。

---

### User Story 3 - H5 开发者：我能收到统一的结构化错误，调用有超时保护 (Priority: P2)

当 JSBridge 调用失败时（如用户取消分享、权限不足、超时），H5 收到标准化的错误对象（包含 code、message），而不是自由文本字符串。所有调用在 30 秒后自动超时。

**Why this priority**: 可预测的错误处理是生产环境 H5 应用的基本需求。

**Independent Test**: 在 H5 中调用 `webLeaf.systemImagePick()` 并手动取消选择，catch 到的 error 对象包含 `{ code: 'USER_CANCELLED', message: '用户取消操作' }`。

**Acceptance Scenarios**:

1. **Given** H5 调用 `webLeaf.vibrate()` 但权限不足，**Then** catch 到 `{ code: 'PERMISSION_DENIED', message: '...' }`。
2. **Given** H5 调用 `webLeaf.systemShare()` 但用户关闭分享面板，**Then** catch 到 `{ code: 'USER_CANCELLED', message: '...' }`。
3. **Given** H5 调用一个未注册的 method，**Then** catch 到 `{ code: 'METHOD_NOT_FOUND', message: '...' }`。
4. **Given** H5 调用一个超时的方法（模拟），**Then** catch 到 `{ code: 'TIMEOUT', message: '调用超时' }`（30 秒后）。

---

### User Story 4 - H5 开发者：我能监听来自原生的主动推送事件 (Priority: P2)

应用从后台切回前台时，H5 能监听 `WebLeafForeground` 事件并自动刷新数据。网络从离线变为在线时，H5 能监听 `WebLeafNetworkChange` 事件并提示用户。

**Why this priority**: 原生推事件让 H5 应用感知运行环境变化，提升用户体验。

**Independent Test**: 按下 Home 键再回到应用，监听 `WebLeafForeground` 事件的回调被执行。

**Acceptance Scenarios**:

1. **Given** H5 页面上注册了 `window.addEventListener('WebLeafForeground', handler)`，**When** 应用从后台切回前台，**Then** handler 被执行。
2. **Given** 页面已注册 `WebLeafNetworkChange` 监听，**When** 网络从离线变为在线，**Then** handler 收到 `{ online: true }` 数据。

---

### User Story 5 - 平台运营者：iframe 中的页面无法调用 JSBridge (Priority: P2)

恶意 H5 可能通过 iframe 嵌入第三方页面来绕过权限检查。iframe 中的页面不应能访问 `window.webLeaf` 或 `window.JSBridgeHandle`。

**Why this priority**: 安全纵深防御。iframe 是绕过权限管控的常见攻击向量。

**Independent Test**: 创建一个包含 iframe 的测试页，iframe 加载的页面中尝试调用 `webLeaf.getAppInfo()`，应该收到错误或返回 `undefined`。

**Acceptance Scenarios**:

1. **Given** iframe 中的页面，**When** 尝试访问 `window.webLeaf`，**Then** 结果为 `undefined`。
2. **Given** iframe 中的页面，**When** 尝试访问 `window.JSBridgeHandle`，**Then** 结果为 `undefined`。

---

### User Story 6 - 开发者：我能开启 JSBridge 调试日志 (Priority: P3)

在开发 H5 轻应用时，打开调试模式后，所有 JSBridge 调用的入参和出参都在控制台打印，并同时输出到系统 hilog。

**Why this priority**: 调试工具提升开发效率。

**Independent Test**: 在 URL 参数中添加 `?wldebug=1`，控制台看到每条 JSBridge 调用的详细日志。

---

### Edge Cases

- **权限在高频调用时的性能**：每次 JSBridge 调用都检查来源和权限，不应导致明显的 UI 卡顿（控制在 1ms 内）。
- **WebLeafReady 事件重复触发**：如果 SDK 被显式 `<script>` 加载和自动注入各触发一次，`if (window.webLeaf) return;` 应防止重复初始化。
- **iframe 安全限制**：webleaf-sdk 在 iframe 中自动屏蔽，禁止子页面通过 JSBridge 调用原生能力。跨域 iframe 天然无法访问父页面变量。同域 iframe 由 SDK 主动清除 webLeaf。

## Requirements

### Functional Requirements

- **FR-001**: WebContainer 必须根据 `src` 的来源类型（`rawfile://`、`file://`、`https://`）确定 JSBridge 调用的权限级别。
- **FR-002**: 必须定义 `'allow'`、`'deny'` 两种权限级别。rawfile 所有方法 `allow`；file 和 https 的敏感方法（vibrate、systemShare、systemImagePick）为 `deny`；非敏感方法（getAppInfo、modifyNavStyle、navigateBack）为 `allow`。
- **FR-003**: 当 JSBridge 方法因权限不足被拒绝时，必须返回标准错误码 `PERMISSION_DENIED`。
- **FR-004**: JSBridge 所有方法必须返回结构化错误响应：`{ status, code, message, detail? }`。
- **FR-005**: 必须在 `webleaf-sdk.js` 中新增 `getVersion(): Promise<{ sdk, container, api }>` 和 `hasMethod(name): Promise<boolean>`。
- **FR-006**: 原生 `getAppInfo` 返回值中必须包含 `sdkVersion` 字段。
- **FR-007**: 所有 JSBridge 调用必须在 30 秒后超时（由 SDK 侧的超时 Promise 实现）。
- **FR-008**: webleaf-sdk.js 的 `_callbacks` 对象必须设置上限（500 个），超出时自动清理最旧的 100 个。
- **FR-009**: WebContainer 在 `onPageShow` 和 `onBackground` 时必须通过 `runJavaScript` 派发 `WebLeafForeground`/`WebLeafBackground` 事件。
- **FR-010**: webleaf-sdk 在 iframe 环境中必须自动设为 `undefined`，禁止 iframe 访问 JSBridge API。
- **FR-011**: WebContainer 必须支持通过 URL 参数 `wldebug=1` 或 props 开启 JSBridge 调试日志模式。

### Key Entities

- **PermissionMap**：方法名 → 权限级别的映射。`{ 'vibrate': 'deny', 'systemShare': 'deny', ... }`，按来源类型（rawfile/file/https）各一份。
- **JSBridgeError**：标准错误对象，包含 `code: string`、`message: string`、`detail?: string`。
- **VersionInfo**：版本信息对象，包含 `sdk: string`、`container: string`、`api: number`。

## Success Criteria

### Measurable Outcomes

- **SC-001**: rawfile 应用能调用所有 JSBridge 方法；file/https 应用调用敏感方法直接返回 `PERMISSION_DENIED`（零侵入，无需修改 H5 代码）。
- **SC-002**: `webLeaf.getVersion()` 在任意加载阶段调用都能返回完整版本对象，响应时间 < 10ms。
- **SC-003**: 错误响应始终包含 `code` 字段，100% 的 JSBridge 调用错误能被 H5 catch 到标准错误码。
- **SC-004**: `_callbacks` 数量稳定在 500 以下，无内存泄漏（可通过长时页面验证回调数不持续增长）。
- **SC-005**: 应用切前台后，已注册 `WebLeafForeground` 的 H5 在 1 秒内收到事件。

## Assumptions

- 假设未来可能引入 `prompt`（用户确认）级别，但目前只实现 `allow`/`deny` 两级。
- 假设 iframe 同源策略限制无法突破，跨域 iframe 的 JSBridge 访问不在本次范围内。
- 假设 H5 开发者通过 `wldebug=1` 启用调试，该参数可通过 URL query 或 WebContainer props 传入。
- 假设 JSBridge 调用的权限检查逻辑由容器侧（ArkTS）实现，webleaf-sdk.js 侧只负责传递标准错误码。

## Open Questions

- 权限管控配置是否需要持久化（数据库）还是仅运行时内存配置？（暂时采用内存配置，后续可扩展为 DB 持久化）
- 离线包场景下，file:// 应用的 permission map 是否需要允许部分敏感方法？（暂时统一 deny，后续可按需开放）
