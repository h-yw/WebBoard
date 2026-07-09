# Implementation Plan: WebView JSBridge & Navigation Control

## Summary

为 ViewerPage 增加 URL 路由参数控制（`wl_nav_style`/`wl_nav_title`）和 JSBridge 双向通信，暴露 6 个原生方法供 H5 调用。

## Technical Context

**Language/Version**: ArkTS (API 12+, HarmonyOS 6.0.2)  
**Primary Dependencies**: `@kit.ArkWeb` (javaScriptProxy, runJavaScript), `@kit.ShareKit` (systemShare), `@kit.MediaLibraryKit` (photoAccessHelper), `@kit.SensorServiceKit` (vibrator), `@kit.NetworkKit` (connection), `@kit.AbilityKit` (common)  
**Target Platform**: HarmonyOS NEXT (API 12+), Phone

## Research & Decisions

### R-001: JSBridge 通信方案

- **Decision**: 使用 `javaScriptProxy` 注入 `JSBridgeHandle` 对象 + `runJavaScript` 回调
- **Rationale**: HarmonyOS 官方推荐的 H5↔原生通信方式，支持同步注入、异步回调
- **Alternatives considered**: `onMessage`/`postMessage` 方式（需要 iframe 桥接，不够直接）

### R-002: 导航栏控制方式

- **Decision**: 通过修改 `NavDestination` 的 `title` 属性和 `hideTitleBar`/`hideBackButton` 控制
- **Rationale**: Navigation 组件原生支持这些接口，无需额外 hack

### R-003: 路由参数解析

- **Decision**: 在 `ViewerPage.aboutToAppear()` 中解析 URL 查询参数
- **Rationale**: URL 直接加载时可以通过 `entryHtml` 字符串解析；需要在页面初始化前完成

## Data Model

### ViewerParam 扩展
```typescript
interface ViewerParam {
  entryHtml: string
  appName: string
  // 新增
  navStyle?: string    // '0' | '1' | undefined
  navTitle?: string    // 自定义标题
}
```

### JSBridge 协议
```typescript
// H5 -> Native 请求格式
interface JSBridgeRequest {
  method: string       // 方法名
  params: object       // 参数
  callbackId: string   // 回调标识
}

// Native -> H5 响应格式
interface JSBridgeResponse {
  callbackId: string
  status: 'ok' | 'error'
  data?: any
  error?: string
}
```

### 方法列表

| 方法 | 参数 | 返回值 |
|------|------|--------|
| getAppInfo | 无 | { appName, appVersion, appVersionName, internet, deviceBrand, deviceModel } |
| modifyNavStyle | { style: 0\|1, title?: string } | { status: 'ok' } |
| systemShare | { title, content, image?, url?, type? } | { status, data: { platform } } |
| systemImagePick | { type?, count?, limit? } | { status, data: [{ path, name, size, base64 }] } |
| vibrate | { type?, duration?, interval?, count? } | { status } |
| onBackPress | callbackId | — |

## Contracts & Interfaces

### JSBridge.ets
```typescript
export class JSBridge {
  constructor(controller: webview.WebviewController, context: common.UIAbilityContext)
  get javaScriptProxy(): JavaScriptProxy  // 注入到 Web 组件
  initJSBridge(): void                      // 在 onPageBegin 中调用
  handleCall(method: string, params: string): void
  callback(callbackId: string, data: any): void
  setNavChangeCallback(cb: (style: number, title?: string) => void): void
  setBackPressCallback(cb: () => boolean): void
}
```

### Project Structure Changes

```text
entry/src/main/ets/
├── util/
│   ├── JSBridge.ets           # [新增] JSBridge 核心通信 + 所有方法实现
│   └── ...
├── pages/
│   ├── ViewerPage.ets          # [修改] 注入 JSBridge、URL 参数解析、导航控制
│   └── ...
├── common/
│   ├── Constants.ets           # [修改] 可选：添加 JSBridge 相关常量
│   └── ...
```

### Module Permissions (module.json5)
```json5
{
  "name": "ohos.permission.VIBRATE"
}
{
  "name": "ohos.permission.GET_NETWORK_INFO"
}
```
