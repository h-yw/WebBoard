# Implementation Plan: Platform Container Refactor & Light App Distribution

**Input**: Feature specification from `spec/platform-container-refactor/spec.md`

**Note**: This template is filled in by the `/spec-plan` command.

## Summary

将 WebBoard 从单模块（entry HAP）重构为多模块架构：`entry HAP`（纯粹化管理壳）+ `container HSP`（容器核心动态共享包）。同时实现 JSBridge **双轨制** 前端 SDK（自动注入 `window.webLeaf` + 可引用 `webleaf-sdk.js`），并在 entry 首页增加"轻应用市场"区域，展示 rawfile 中已有的内置演示应用。

## Technical Context

**Language/Version**: ArkTS 6.0.2 (API 22)  
**Primary Dependencies**:
  - `entry` module: app shell + UI + nav routing
  - `container` module (HSP): `@kit.AbilityKit`, `@kit.ArkWeb`, `@ohos.data.relationalStore`, `@kit.NetworkKit`, `@kit.MediaLibraryKit`, `@kit.ShareKit`, `@kit.SensorServiceKit`
  - Inter-module: `oh-package.json5` declare `"container": "file:../container"`  
**Storage**: SQLite via `@ohos.data.relationalStore` — managed by `container` HSP. Two tables: `web_apps`, `settings`  
**Testing**: Manual verification on real device HUAWEI Pura 80 Pro+ (API 22). Build via `hvigorw assembleHap` (debug mode)  
**Target Platform**: HarmonyOS NEXT (phone). `life.hlovez.webboard` bundle  
**Project Type**: Multi-module HarmonyOS ArkTS (entry HAP + container HSP)  
**Performance Goals**: No regression in cold start time. HSP code-loaded modules must not block UI thread on initial load  
**Constraints**: All `entry` business logic (database, JSBridge, file management, WebView) **must** be fully delegated to `container`. No ArkTS `any`/`unknown`/`as` cast  
**Scale/Scope**: One shared module (`container` HSP) + one entry module. Future extensions can add feature HAPs on top of the same container

## Project Structure

### Documentation (this feature)

```text
spec/platform-container-refactor/
├── spec.md              # Phase 1: Requirements specification
├── plan.md              # Phase 2: This file (implementation plan)
└── tasks.md             # Phase 3: Task breakdown (to be generated)
```

### Source Code (repository root)

```text
WebBoard/                       # PROJECT_ROOT
├── build-profile.json5         # [MODIFIED] Add container module entry
├── hvigor/hvigor-config.json5  # Keep daemon/incremental/parallel
│
├── entry/                      # (HAP) — APPLICATION SHELL
│   ├── hvigorfile.ts
│   ├── oh-package.json5        # [MODIFIED] Add "container" dependency
│   └── src/main/
│       ├── module.json5        # Keep existing (entry type, unchanged)
│       ├── resources/          # Keep existing (string, color, media, etc.)
│       └── ets/
│           ├── entryability/   # Keep as-is
│           ├── pages/
│           │   ├── Index.ets   # [MODIFIED] Import from container; add "Light App Market" tab
│           │   ├── SplashPage.ets     # Keep as-is (uses router.replaceUrl)
│           │   ├── ImportPage.ets     # [MODIFIED] Import from container
│           │   ├── ViewerPage.ets     # [SIMPLIFIED] Uses WebContainer from container
│           │   ├── EditPage.ets       # [MODIFIED] Import from container
│           │   └── SettingsPage.ets   # [MODIFIED] Import from container
│           ├── util/
│           │   └── IndexActions.ets   # [KEEP] DOM-related actions (share card, scan)
│           ├── component/
│           │   └── AppShareCard.ets   # [KEEP] Share card rendering component
│           ├── common/
│           │   └── [EventEmitter.ets, Logger.ets, Constants.ets → MOVED to container]
│           ├── model/
│           │   └── [WebAppItem.ets, AppDataSource.ets → MOVED to container]
│           ├── database/
│           │   └── [DatabaseManager.ets → MOVED to container]
│           └── ui/
│               └── [ToastUtil.ets, LoadingUtil.ets, DialogUtil.ets → MOVED to container]
│
└── container/                  # (HSP) — CONTAINER CORE (NEW MODULE)
    ├── hvigorfile.ts           # [NEW] HSP hvigor config
    ├── oh-package.json5        # [NEW] Container package declaration
    └── src/main/
        ├── module.json5        # [NEW] type: "shared"
        ├── resources/          # [NEW] (minimal, only if needed)
        └── ets/
            ├── Index.ets       # [NEW] Facade — exports all public APIs
            ├── webview/
            │   ├── WebContainer.ets     # [NEW] Reusable WebView component (JSBridge + progress + error)
            │   └── JSBridge.ets         # [MOVED + REFACTORED] from entry/util/JSBridge.ets
            ├── database/
            │   └── DatabaseManager.ets  # [MOVED] from entry/src/main/ets/database/
            ├── model/
            │   ├── WebAppItem.ets       # [MOVED] from entry/src/main/ets/model/
            │   └── AppDataSource.ets    # [MOVED] from entry/src/main/ets/model/
            ├── ui/
            │   ├── ToastUtil.ets        # [MOVED] from entry/src/main/ets/ui/
            │   ├── LoadingUtil.ets      # [MOVED] from entry/src/main/ets/ui/
            │   └── DialogUtil.ets       # [MOVED] from entry/src/main/ets/ui/
            ├── util/
            │   ├── WebPreloader.ets     # [MOVED] from entry/src/main/ets/util/
            │   ├── FileManager.ets      # [MOVED] from entry/src/main/ets/util/
            │   └── WorkDirectory.ets    # [MOVED] from entry/src/main/ets/util/
            └── common/
                ├── EventEmitter.ets     # [MOVED] from entry/src/main/ets/common/
                ├── Logger.ets           # [MOVED] from entry/src/main/ets/common/
                └── Constants.ets        # [MOVED] from entry/src/main/ets/common/
```

**Structure Decision**: Multi-module HarmonyOS project follows standard HSP layout. Entry module stays a pure application shell. Container module acts as a dynamic shared library responsible for all core operations (WebView, JSBridge, persistence, file I/O, UI utilities). The `container/Index.ets` facade pattern is used (the standard HSP export pattern) where all public APIs are re-exported through a single file. No MVVM migration is introduced — modules follow the existing code structure preserved from the original single-module layout.

## Research & Decisions

### Decision 1: HSP (Dynamic Shared Package) vs HAR (Static Library)

**Decision**: Use HSP for the container module.

**Rationale**: 
- HSP produces a separate `.hsp` file that is loaded at runtime, not merged into the HAP at compile time
- Multiple modules can depend on the same HSP without duplication
- Future feature HAPs can also depend on the same `container` HSP
- ARK UI components (`@Component`) can be exported from HSP via Index.ets facade

**Alternatives considered**:
- HAR: Code is merged into every referencing HAP, causing code duplication and larger HAP size if multiple HAPs reference it
- Single HAP: The current architecture — no separation of concerns, impossible to independently evolve container

### Decision 2: JSBridge SDK Dual-Track (Dynamic Auto-Inject + Manual Script)

**Decision**: Implement **dual-track coexistence with dynamic injection priority**.

**Rationale**:
- **Track 1 (Native Injection)**: WebView's `javaScriptProxy` injects `window.JSBridgeHandle` at native level (synchronous, executes before H5 scripts)
- **Track 2 (Auto `runJavaScript`)**: In `WebContainer.ets`'s `onPageBegin` callback, `this.controller.runJavaScript(webLeafSDKCode)` injects the Promise-based `window.webLeaf` wrapper
- **Track 3 (Manual npm)**: External developers can independently import `webleaf-sdk.js` in their project for proper IDE type hints and TypeScript definitions

This guarantees:
- **Zero configuration** for simple H5 pages: `window.webLeaf.getAppInfo().then(...)` works out of the box
- **Backward compatibility**: All existing H5 using `window.JSBridgeHandle.call()` continues to work
- **Engineering excellence**: Frontend projects can `npm install webleaf-sdk` for type safety

**Alternatives considered**:
- Pure native injection only: Lacks the Promise wrapper and developer-friendly API
- Manual import only: Requires every H5 developer to add a script tag, creating adoption friction

### Decision 3: Light App Market Data Source

**Decision**: Use existing bundled rawfile H5s as the light app market demo content.

**Rationale**:
- Two rawfile H5s (`code_artifact.html`, `jsbridge_test.html`) are already bundled in the app and proven to work
- Zero network dependency — works offline and on first launch
- `jsbridge_test.html` is the perfect showcase of JSBridge capabilities for the platform
- Demonstrates the full platform flow: "Discover → Add → Launch" without external dependencies

**Static apps list** (from `entry/src/main/resources/rawfile/`):
1. Name: "JSBridge 测试" | Desc: "测试 JSBridge 所有原生方法调用" | Path: `rawfile://jsbridge_test.html`
2. Name: "速算估算微练" | Desc: "掌握 1/2 到 1/20 的快速转换，提升心算敏感度" | Path: `rawfile://code_artifact.html`

**Alternatives considered**:
- External URLs: Require network availability, prone to link rot, no control over content
- Hardcoded static list without rawfile: Would duplicate data already available in the project

### Decision 4: WebContainer Component Design for HSP Export

**Decision**: `WebContainer.ets` in `container` module is an `@Component` struct that:
- Accepts `src: string` and `appName: string` as parameters
- Encapsulates the entire `Web()` component with all required configurations (javaScriptAccess, mixedMode, domStorageAccess, cacheMode)
- Manages JSBridge lifecycle (init, onControllerAttached, cleanup)
- Exposes loading progress and error state
- Handles back press interception (Web history → JSBridge callback → navigateBack)
- Auto-injects `window.webLeaf` SDK on `onPageBegin`
- Does NOT include NavDestination wrapper (navigation is owned by Entry)

**Rationale**: A pure, reusable WebView component that can be consumed by any page (entry ViewerPage, future feature HAP pages, etc.).

**Alternatives considered**:
- Embedding NavDestination inside WebContainer: Would create tight coupling with navigation and prevent reuse
- Keeping all logic in ViewerPage: Defeats the purpose of container separation

## Data Model

### WebAppItem (moved to container module, no schema changes)

| Field | Type | Description |
|-------|------|-------------|
| id | string | Unique identifier (timestamp + random) |
| name | string | App display name |
| description | string | Optional app description |
| logoType | string | Logo type: `'initial'` (first letter) or `'custom'` (custom image) |
| logoUri | string | Custom logo image path (valid when logoType is 'custom') |
| entryHtml | string | Entry HTML path (supports `rawfile://`, `file://`, and `https://` URLs) |
| sourceType | string | Source: `'preset'`, `'file'`, or `'url'` (URL source is NEW — for light app market) |
| createTime | number | Creation timestamp |
| persistUri | string | File persistence URI (for file-based imports) |
| persistMode | string | File persistence mode |

**Note**: The light app market uses `sourceType === 'preset'` (same as existing presets), since market apps are bundled rawfile H5s. The key architectural distinction is that market apps are *user-discovered and voluntarily added*, while presets are *auto-installed*.

### Settings (unchanged)

| Field | Type | Description |
|-------|------|-------------|
| color_mode | string | Display mode: `'system'`, `'light'`, `'dark'` |
| preload_enabled | string | Preloading: `'true'` or `'false'` |
| layout_mode | string | Home layout: `'grid'` or `'list'` |

## Contracts & Interfaces

### Container HSP Exports (via container/Index.ets)

```typescript
// --- ArkUI Components ---
export { WebContainer }    // Reusable WebView component (JSBridge included)
export { AppShareCard }    // Share card rendering component

// --- Database ---
export { DatabaseManager } // SQLite singleton

// --- Data Models ---
export { WebAppItem, WebAppRecord }
export { AppDataSource }

// --- UI Utilities ---
export { Toast }
export { Loading }
export { Dialog }

// --- Common Utilities ---
export { Logger }
export { eventEmitter }
export { WebBoardConstants, ColorMode, LayoutMode, LogoType, SourceType }

// --- Services ---
export { WebPreloader }
export { FileManager }
export { WorkDirectory }
export { JSBridge, JsProxyObject }
```

### WebContainer Component Interface

```typescript
@Component
export struct WebContainer {
  @Prop src: string           // Source URL/path (rawfile://, file://, https://)
  @Prop appName: string       // App name for nav/title display
  // Internal state only: loadProgress, hasError, isLoading
  // JSBridge lifecycle: constructor → initJSBridge → controllerAttached → cleanup
  // Nav callbacks: setNavChangeCallback, setNavigateBackCallback, setBackPressCallback
}
```

### JSBridge Dual-Track SDK Contract

**Track 1: Native Injection Layer** (`window.JSBridgeHandle`, synchronous):
```typescript
// Injected by javaScriptProxy automatically
window.JSBridgeHandle.call(method: string, params: string, callId: string)
// Native calls back via:
window.__JSBridgeCallback__(id: string, data: string)
```

**Track 2: Wrapper SDK** (`window.webLeaf`, Promise-based):
```typescript
// Auto-injected on onPageBegin via runJavaScript
interface WebLeafSDK {
  getAppInfo(): Promise<GetAppInfoResult>
  modifyNavStyle(style: number, title?: string): Promise<void>
  systemShare(params: ShareParams): Promise<ShareResult>
  systemImagePick(params: ImagePickParams): Promise<PhotoItem[]>
  vibrate(params: VibrateParams): Promise<void>
  onBackPress(): Promise<void>
  navigateBack(): Promise<void>
  call(method: string, params: object): Promise<any>
}
```

### Entry-to-Container Import Contract

```typescript
// All cross-module imports use the 'container' alias (defined in entry/oh-package.json5)
// Example:
import { 
  WebAppItem, 
  AppDataSource, 
  DatabaseManager, 
  WebContainer,
  WebPreloader,
  Toast,
  Dialog,
  Logger,
  eventEmitter,
  SourceType,
  LayoutMode,
  ColorMode
} from 'container'
```

### build-profile.json5 Multi-Module Contract

```json5
{
  "modules": [
    {
      "name": "entry",
      "srcPath": "./entry",
      "targets": [
        { "name": "default", "applyToProducts": ["default"] }
      ]
    },
    {
      "name": "container",
      "srcPath": "./container",
      "targets": [
        { "name": "default", "applyToProducts": ["default"] }
      ]
    }
  ]
}
```
