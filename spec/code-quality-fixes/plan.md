# Implementation Plan: Code Quality Fixes

**Input**: Feature specification from `spec/code-quality-fixes/spec.md`

## Summary

对 WebBoard 项目进行 15 项代码质量改进，涵盖 5 个 User Story 的架构一致性修复、预加载功能修复、事件系统修复、UI 组件可靠性修复和代码清理优化。所有修改遵循项目现有架构约定，保持向后兼容。

## Technical Context

**Language/Version**: ArkTS (HarmonyOS NEXT API 12+, SDK 6.0.2)  
**Primary Dependencies**: `@kit.ArkUI`, `@kit.AbilityKit`, `@kit.ArkWeb`, `@kit.ArkData`, `@kit.PerformanceAnalysisKit`  
**Storage**: SQLite via `@ohos.data.relationalStore`  
**Testing**: `@ohos/hypium 1.0.25`, `@ohos/hamock 1.0.0`  
**Target Platform**: HarmonyOS Phone (API 12+)  
**Project Type**: Mobile App (Stage Model, single-module `entry/`)  
**Performance Goals**: 预加载页面从点击到显示 < 300ms  
**Constraints**: 不引入第三方依赖，不改变现有业务逻辑，保持 API 兼容  
**Scale/Scope**: 22 个 .ets 源文件，涉及 5 个更改模块（SplashPage, WebPreloader, EventEmitter, Dialog/Loading, 代码清理）

## Project Structure

### Documentation (this feature)

```text
spec/code-quality-fixes/
├── spec.md              # Feature specification (Phase 1 output)
├── plan.md              # This file (Phase 2 output)
└── tasks.md             # Task breakdown (Phase 3 output)
```

### Source Code (repository root - existing project, no structural changes)

```text
entry/src/main/ets/
├── common/
│   ├── Constants.ets          # [MODIFY] no changes needed
│   ├── EventEmitter.ets       # [MODIFY] add subscribe/unsubscribe by ID
│   └── Logger.ets             # [MODIFY] replace with hilog-based implementation
├── component/
│   └── AppShareCard.ets       # [none]
├── database/
│   └── DatabaseManager.ets    # [none]
├── entryability/
│   └── EntryAbility.ets       # [MODIFY] load SplashPage as NavDestination, not router
├── entrybackupability/
│   └── EntryBackupAbility.ets # [none]
├── model/
│   ├── AppDataSource.ets      # [none]
│   └── WebAppItem.ets         # [none]
├── pages/
│   ├── Index.ets              # [none] (SplashPage routing change does not affect Index)
│   ├── SplashPage.ets         # [MODIFY] use NavPathStack instead of router.replaceUrl
│   ├── ViewerPage.ets         # [MODIFY] merge back press logic
│   ├── EditPage.ets           # [none]
│   ├── ImportPage.ets         # [none]
│   └── SettingsPage.ets       # [none]
├── ui/
│   ├── DialogUtil.ets         # [REWRITE] @Component-based dialog with ComponentContent
│   ├── LoadingUtil.ets        # [MODIFY] replace wrapBuilder with direct builder
│   └── ToastUtil.ets          # [none]
├── util/
│   ├── FileManager.ets        # [none]
│   ├── JSBridge.ets           # [none]
│   ├── WebPreloader.ets       # [MODIFY] actual WebView preloading via controller transfer
│   └── WorkDirectory.ets      # [none]
└── entrybackupability/
    └── EntryBackupAbility.ets # [none]

entry/src/main/resources/
├── base/element/color.json    # [MODIFY] add color resources for hardcoded values
└── ...
```

**Structure Decision**: This plan follows the existing project architecture (single-module, single-ability, Navigation + NavDestination pattern). No MVVM migration is introduced as this is a code quality improvement on an existing project, not a new feature. The existing directory structure is preserved with targeted modifications only to the files listed above.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Index.ets shrinking (860→~720 lines) | 共享逻辑（shareAppCard, deleteDirectory, startScan）抽取到独立 util 文件 | 保留在当前文件中会持续恶化单文件体积，影响可维护性 |

## Research & Decisions

### R-001: SplashPage Navigation 迁移方案

- **Decision**: SplashPage 获取自己的 `NavPathStack`（通过 `@Consume` 或从 EntryAbility 获取），使用 `replacePath` 在动画完成后替换到 Index。SplashPage 自身保持 `@Entry @Component`，不改为 NavDestination。
- **Rationale**: 
  - SplashPage 是启动入口页，用 `router` API 进行一次性跳转。通过从 EntryAbility 的 `windowStage.loadContent` 传入 Navigation 容器，或使用 `UIContext` 获取 Navigation 相关 API，可实现 `replacePath` 替换
  - 但鉴于 SplashPage 目前是独立加载的页面（由 EntryAbility 直接 `loadContent`），改为 Navigation 模式需要 EntryAbility 加载 Navigation 容器而非直接加载 SplashPage
  - **最终方案**：将 SplashPage 改造为 Navigation 容器 + 闪屏内容，持有 `NavPathStack`，动画结束后调用 `this.navPathStack.replacePath({ name: 'IndexPage' })`，通过 `navDestination` builder 路由到 Index 页面
- **Alternatives considered**:
  - 合并闪屏到 Index：会破坏 Index 的启动流程，且 Index 是卡片列表页，不适合放闪屏
  - 继续使用 `router` API：废弃 API，未来 SDK 版本可能移除

### R-002: WebPreloader 实际预加载方案

- **Decision**: WebPreloader 创建 `webview.WebviewController` 后，在 `Index.ets` 中维护一组隐藏的 `Web` 组件实例（offscreen，置于 Stack 中但通过 `position` 或 `scale(0)` 隐藏）。当用户导航到 ViewerPage 时，若命中预加载的 key，则将该 Web 组件的 controller 传递给 ViewerPage，实现预渲染效果。
- **Rationale**: ArkUI 中 `Web` 组件是声明式组件，不能在非组件树环境下单独加载。需要组件实例才能真正加载和渲染内容。通过管理后台隐藏 Web 组件池，既可实际加载内容，又可通过 controller 传递实现 ViewerPage 的秒开。
- **Alternatives considered**:
  - 仅缓存 `WebviewController` 不加载：和当前实现一样，无效。
  - 使用 `@ohos.web.webview` 的 `loadUrl` 离线加载：不可行，ArkUI 的 WebviewController 必须在 Web 组件中才能操作。

### R-003: EventEmitter 精确移除方案

- **Decision**: 新增 `subscribe(eventName, callback)` 方法返回 `string` 类型的订阅 ID，新增 `unsubscribe(id)` 方法按 ID 精确移除。保留 `on()`/`off()` 向后兼容但标记为 deprecated。
- **Rationale**: 最简洁的精确移除方案，与常见的 EventEmitter 模式（如 Node.js EventEmitter 的 `off` 传函数引用）不同，ArkTS 中函数引用比较不可靠，用 ID 更稳妥。
- **Alternatives considered**: 使用 Symbol/object 作为 listener key — ArkTS 不支持 Symbol。

### R-004: Dialog ComponentContent 封装方案

- **Decision**: Dialog 改为 `@Component` 结构 + `ComponentContent` 方式封装。创建 `DialogContent` struct 作为弹窗内容组件，使用 `ComponentContent.update()` 方法更新内容。工具类 `Dialog.confirm()` 返回并缓存 `ComponentContent` 实例，通过调用其 `update()` 方法在需要时刷新内容。
- **Rationale**: API 12+ 推荐使用 `ComponentContent` + `openCustomDialog` 的方式。`ComponentContent.update()` 可以在不关闭重新打开的情况下更新弹窗内容。
- **Alternatives considered**: 继续使用全局变量 — ArkTS 严格模式下不可靠。

## Data Model

本 Feature 不涉及新建数据模型。以下为需要修改的现有模型/接口：

### EventListenerEntry (新增，EventEmitter 内部使用)
```
{
  id: string        // 唯一订阅 ID，格式: "listener_${timestamp}_${random}"
  eventName: EventName  // 事件名称
  callback: EventFn     // 回调函数
}
```

### DialogState (重构，从全局变量改为 ComponentContent 封装)
```
不再使用全局 dialogState 对象
改为 DialogContent @Component 组件，通过 @Prop 接收数据
```

## Contracts & Interfaces

### EventEmitter 新增接口

```typescript
// 新增接口
subscribe(eventName: EventName, callback: EventFn): string  // 返回订阅ID
unsubscribe(id: string): void                                // 按ID精确移除

// 保持向后兼容（不修改签名）
on(eventName: EventName, callback: EventFn): void
off(eventName: EventName, callback?: EventFn): void
```

### WebPreloader 新增接口

```typescript
// 新增：获取或创建后台预加载 WebView
getOrPreloadController(key: string, src: string): webview.WebviewController | null

// 新增：检查预加载是否就绪（controller 已附加到隐藏 Web 且加载完成）
isPreloadReady(key: string): boolean
```

### DialogUtil 重构接口

```typescript
// 接口签名不变（向后兼容）
export class Dialog {
  static confirm(option: DialogOption): void
  static alert(option: DialogOption): void
}
// 但内部实现从全局变量改为 ComponentContent 模式
```

### LoadingUtil 重构接口

```typescript
// 接口签名不变（向后兼容）
export class Loading {
  static show(message?: string): void
  static hide(): void
}
// 内部实现替换 wrapBuilder 为直接 builder 引用
```

### Logger 统一接口

```typescript
// 接口签名不变（向后兼容）
export class Logger {
  static debug(tag: string, msg: string): void
  static info(tag: string, msg: string): void
  static warn(tag: string, msg: string): void
  static error(tag: string, msg: string): void
}
// 内部实现从 console.x 改为 hilog.x
```
