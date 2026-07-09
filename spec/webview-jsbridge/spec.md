# Feature Specification: WebView JSBridge & Navigation Control

**Created**: 2026-07-09  
**Status**: Draft  
**Input**: docs/feature.md

## Overview

为 WebBoard 的 WebView 组件增加两大部分能力：(1) **路由参数识别** — 导入 URL 时通过查询参数控制导航栏样式和标题；(2) **JSBridge** — 在 WebView 加载的 H5 页面与原生 ArkTS 之间建立双向通信桥梁，暴露 6 个原生方法供 H5 调用。

## User Scenarios & Testing

### User Story 1 - 路由参数控制导航栏 (Priority: P1)

用户导入一个带参数的 URL（如 `https://example.com?wl_nav_style=0`），打开后导航栏按参数样式显示。

**Independent Test**: 导入 `?wl_nav_style=0` 的 URL → 导航栏隐藏；导入 `?wl_nav_style=1` → 导航栏透明仅显示返回按钮。

### User Story 2 - JSBridge 获取应用信息 (Priority: P1)

H5 页面通过 `JSBridge.call('getAppInfo', {})` 获取应用基本信息。

**Independent Test**: H5 页面调用后返回正确的应用名称、版本号、网络状态、设备型号。

### User Story 3 - JSBridge 修改导航栏 (Priority: P1)

H5 页面通过 `JSBridge.call('modifyNavStyle', {style: 0})` 控制导航栏样式。

**Independent Test**: H5 调用后导航栏立即响应变化。

### User Story 4 - JSBridge 系统分享 (Priority: P2)

H5 页面通过 `JSBridge.call('systemShare', {...})` 调起系统分享面板。

**Independent Test**: H5 调用后弹出系统分享面板，可选择应用进行分享。

### User Story 5 - JSBridge 图片选择 (Priority: P2)

H5 页面通过 `JSBridge.call('systemImagePick', {...})` 调起系统图片选择器。

**Independent Test**: H5 调用后弹出系统相册，选择图片后返回路径和 base64 信息。

### User Story 6 - JSBridge 震动 (Priority: P2)

H5 页面通过 `JSBridge.call('vibrate', {...})` 触发设备震动。

**Independent Test**: H5 调用后设备按参数震动。

### User Story 7 - JSBridge 返回拦截 (Priority: P2)

H5 页面注册返回拦截回调，在用户按下返回键时询问 H5 是否允许返回。

**Independent Test**: H5 注册回调并返回 0 → 正常返回；返回非 0 → 阻止返回。

## Requirements

### Functional Requirements

- **FR-001**: ViewerPage MUST 解析 URL 中的 `wl_nav_style` 参数（0/1）并控制导航栏样式
- **FR-002**: ViewerPage MUST 解析 URL 中的 `wl_nav_title` 参数并设置为导航栏标题
- **FR-003**: `wl_nav_title` 优先级高于导入时设置的应用名称，但低于 `wl_nav_style` 的覆盖
- **FR-004**: System MUST 通过 `javaScriptProxy` 注入 `JSBridge` 对象到 H5 页面 window 对象
- **FR-005**: JSBridge MUST 支持 `call(method, params, callback)` 统一调用入口
- **FR-006**: JSBridge MUST 提供 `getAppInfo` 方法返回应用和设备的完整信息
- **FR-007**: JSBridge MUST 提供 `modifyNavStyle` 方法让 H5 控制导航栏样式和标题
- **FR-008**: JSBridge MUST 提供 `systemShare` 方法调起系统分享面板
- **FR-009**: JSBridge MUST 提供 `systemImagePick` 方法调起系统图片选择器
- **FR-010**: JSBridge MUST 提供 `vibrate` 方法触发设备震动
- **FR-011**: JSBridge MUST 提供 `onBackPress` 注册机制，供 H5 拦截返回操作
- **FR-012**: System MUST 在 `module.json5` 中添加 `ohos.permission.VIBRATE` 和 `ohos.permission.GET_NETWORK_INFO` 权限

### Key Entities

- **JSBridge**: WebView 与原生之间的通信桥梁，基于 `javaScriptProxy` + `runJavaScript` 实现
- **NavStyleManager**: 管理导航栏的显示/隐藏/透明状态
- **URLParams**: 从导入 URL 中解析出的参数（wl_nav_style, wl_nav_title）
- **ViewerParam**: 扩展的页面参数（新增 navStyle, navTitle 字段）

## Assumptions

- H5 页面需要先调用 `JSBridge.init()` 才能使用 JSBridge 功能
- 返回拦截（FR-011）使用 `ViewerPage.onBackPress()` 生命周期方法 + JSBridge callback
- ShareKit 的 `systemShare.ShareController` 在部分设备上可能不支持所有内容类型
- Image Pick 使用 `photoAccessHelper.PhotoViewPicker`（API 10+），无需申请权限
- 震动需要 `ohos.permission.VIBRATE` 权限

## Open Questions

- `wl_nav_style=1`（透明导航栏只显示返回按钮）在 Navigation 组件中的具体实现方式需要调研
