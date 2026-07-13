# Implementation Plan: WebView 预热加速

## Summary

升级 WebPreloader 从纯访问追踪器为真正的 WebView 预热池。WebContainer 支持接收预创建的 WebviewController，首页空闲时自动预热最常使用的应用。

## Technical Context

**Language/Version**: ArkTS 6.0.2 (API 22)  
**Target**: container HSP (WebPreloader.ets, WebContainer.ets) + entry (Index.ets, ViewerPage.ets)  
**Constraints**: 最大预热 2 个，TTL 5 分钟，feature flag 可降级

## Project Structure

```
container/src/main/ets/
└── util/
    └── WebPreloader.ets          ← [MODIFY] Add preheating pool
    └── webview/
        ├── WebContainer.ets      ← [MODIFY] Accept pre-created controller
        └── WebContainerController.ets  ← [MODIFY] Add preload support

entry/src/main/ets/
└── pages/
    ├── Index.ets                 ← [MODIFY] Trigger preheat on idle
    └── ViewerPage.ets            ← [MODIFY] Pass preheat controller
```

## Research & Decisions

### Decision 1: 预创建 vs 预渲染
- **Decision**: 只预创建 WebviewController，不预加载页面内容
- **Rationale**: ArkUI Web 组件必须在组件树中才能渲染内容。预创建 controller 并记录 src 是可行的优化，实际渲染在用户点击时由 WebContainer 完成。
- **Alternatives**: 预创建隐藏 Web 组件 → 经测试不可行（HiddenWebPool 已废弃）

### Decision 2: Controller 复用 + 重新加载
- **Decision**: 复用 controller 时调用 `controller.loadUrl()` 重新加载目标页面
- **Rationale**: 预创建的 controller 初始没有加载任何页面。当用户点击应用时，WebContainer 使用该 controller 并调用 `Web({ src, controller })`，自动触发加载。

## Data Model

```typescript
interface PreloadEntry {
  key: string           // 应用的 entryHtml
  controller: webview.WebviewController
  createdAt: number
}

class WebPreloader {
  private pool: PreloadEntry[] = []
  private readonly MAX_POOL = 2
  private readonly TTL = 5 * 60 * 1000
  private enabled: boolean = true  // feature flag

  preload(key: string): void { ... }
  takeController(key: string): webview.WebviewController | null { ... }
  cleanup(): void { ... }
  setEnabled(enabled: boolean): void { ... }
}
```

## Contracts & Interfaces

```typescript
// WebPreloader 新增方法
preload(key: string): void
takeController(key: string): webview.WebviewController | null
setEnabled(enabled: boolean): void

// WebContainer 新增构造参数
@Prop preloadController?: webview.WebviewController
```
