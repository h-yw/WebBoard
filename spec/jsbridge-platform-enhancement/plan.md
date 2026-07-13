# Implementation Plan: JSBridge 平台安全增强与 SDK 标准化

**Input**: Feature specification from `spec/jsbridge-platform-enhancement/spec.md`

## Summary

将 JSBridge 从裸桥升级为具备安全边界、标准化错误处理、SDK 自省和调试支持的平台级基础设施。核心变更集中在 `container/` HSP 模块的 `webview/` 目录（JSBridge.ets、WebContainer.ets、webleaf-sdk.ets）以及 rawfile 中的 `webleaf-sdk.js`。

## Technical Context

**Language/Version**: ArkTS 6.0.2 (API 22) / JavaScript (JS SDK)  
**Primary Dependencies**:
  - `container/src/main/ets/webview/JSBridge.ets` — Native bridge (main modification target)
  - `container/src/main/ets/webview/WebContainer.ets` — Lifecycle event dispatcher + debug mode
  - `container/src/main/ets/webview/webleaf-sdk.ets` — Embedded SDK script (synchronized with rawfile)
  - `entry/src/main/resources/rawfile/webleaf-sdk.js` — Standalone SDK file (synchronized with .ets)  
**Storage**: No DB changes. Permission map in memory (runtime config only)  
**Testing**: Build + deploy to HUAWEI Pura 80 Pro+. UI verify via JSBridge 测试页 (rawfile)  
**Target Platform**: HarmonyOS NEXT (phone). `life.hlovez.webboard` bundle  
**Project Type**: HSP shared module enhancement (container)  
**Performance Goals**: Permission check overhead < 1ms per call  
**Constraints**: No breaking changes to existing `window.JSBridgeHandle.call()` behavior. All additions must be backward compatible  
**Scale/Scope**: 6 ArkTS files modified/created + 1 JS file + 1 rawfile JS file

## Project Structure

```
container/src/main/ets/webview/
├── JSBridge.ets              ← [MODIFIED] Add permission check, error codes, getVersion/hasMethod handlers
├── WebContainer.ets          ← [MODIFIED] Add sourceType, push events, debug mode
├── webleaf-sdk.ets           ← [MODIFIED] Sync with rawfile: add getVersion, hasMethod, timeout, callback cap, iframe
└── WebContainerController.ets ← (unchanged)

container/src/main/ets/
└── common/
    └── Constants.ets          ← [MODIFIED] Add JSBridgeErrorCode enum (optional, or inline in JSBridge.ets)

entry/src/main/resources/rawfile/
├── webleaf-sdk.js            ← [MODIFIED] Sync with webleaf-sdk.ets
└── jsbridge_test.html        ← [MODIFIED] Add debug mode test UI (optional)
```

**Structure Decision**: Follows existing container HSP architecture. This enhancement is a purely internal refactoring of the JSBridge subsystem within `webview/`. No MVVM migration is introduced. All changes are backward-compatible additions to existing files.

## Research & Decisions

### Decision 1: Permission Check Location

**Decision**: Permission check is performed in `JSBridge.handleCall()`, the single entry point for all JSBridge invocations.

**Rationale**: All H5 → Native calls flow through `handleCall()`. Adding the permission check here guarantees no method can bypass it. The source type is passed from WebContainer to JSBridge constructor.

**Alternatives considered**:
- Checking in `JSBridgeProxyObject.call()`: Too low-level, would miss future non-proxy calls.
- Checking in each handler (handleGetAppInfo, handleVibrate, etc.): Duplicate logic, error-prone.

**SourceType flow**:
```
WebContainer.ets (getWebSrc() → detects prefix)
  → this.jsBridge = new JSBridge(controller, context, this.getSourceType())
    → JSBridge.handleCall(method, params, callId)
      → permissionMap[sourceType][method] === 'deny'? → callback({ code: 'PERMISSION_DENIED' })
      → dispatch to appropriate handler
```

### Decision 2: Permission Levels — Only 'allow'/'deny' (No 'prompt')

**Decision**: Only implement `'allow'` and `'deny'` for now. `'prompt'` (per-user confirmation dialog) is deferred.

**Rationale**: The current use cases (rawfile trust, file/https restrict) only need two levels. Adding `'prompt'` would require dialog management and user preference persistence, significantly increasing scope.

**Permission map**:
```typescript
type PermissionLevel = 'allow' | 'deny'
type PermissionMap = Record<string, PermissionLevel> // method name → level

// Default maps:
const RAW_PERMISSIONS: PermissionMap = { /* all methods: 'allow' */ }
const FILE_PERMISSIONS: PermissionMap = { 
  vibrate: 'deny', systemShare: 'deny', systemImagePick: 'deny',
  getAppInfo: 'allow', modifyNavStyle: 'allow', navigateBack: 'allow',
  onBackPress: 'allow'
}
const URL_PERMISSIONS: PermissionMap = { ...FILE_PERMISSIONS } // same as file for now
```

### Decision 3: Error Code Standardization

**Decision**: Define both `code` and `message` in error responses. The `JSBridgeResponse` interface gains a required `code` field.

**Standard error codes**:

| Code | Meaning | When |
|------|---------|------|
| `OK` | Success | Normal execution |
| `PERMISSION_DENIED` | Method not allowed for this source | Permission check fails |
| `USER_CANCELLED` | User cancelled the operation | Share dismissed, image pick cancelled |
| `METHOD_NOT_FOUND` | Unknown method | handleCall default branch |
| `TIMEOUT` | Call exceeded time limit | SDK-side 30s timeout |
| `INTERNAL_ERROR` | System internal error | Native exception caught |
| `INVALID_PARAMS` | Parameter validation failed | Malformed JSON or missing required fields |

### Decision 4: Push Events Dispatch

**Decision**: WebContainer leverages `onPageShow()` (ArkUI lifecycle) to dispatch `WebLeafForeground`. Network change detection is deferred (would require connection observer).

**Rationale**: ArkUI provides reliable lifecycle callbacks. `onPageShow()` fires when the page becomes visible (including return from background).

**Implementation**:
```typescript
// WebContainer.ets
onPageShow(): void {
  if (this.controller) {
    const script = 'try { window.dispatchEvent(new CustomEvent("WebLeafForeground")); } catch(e) {}'
    try { this.controller.runJavaScript(script) } catch(e) {}
  }
}

aboutToDisappear(): void {
  // onPageHide equivalent
  const script = 'try { window.dispatchEvent(new CustomEvent("WebLeafBackground")); } catch(e) {}'
  // ... existing clearHistory
}
```

### Decision 5: Iframe Security — Block Instead of Proxy

**Decision**: The SDK actively blocks iframe access. Instead of proxying `webLeaf` to iframes, the SDK deletes itself when detected in an iframe context.

**Rationale**: iframes are a common vector for bypassing permission controls. By actively removing JSBridge access in iframes, we implement a defense-in-depth strategy.

**Implementation**: In `webleaf-sdk.js`, after the module definition:
```javascript
try {
  if (window !== window.top) {
    // In iframe: block JSBridge access by deleting exposed objects
    delete window.JSBridgeHandle;
    delete window.JSBridge;
    delete window.webLeaf;
    delete window.__JSBridgeCallback__;
  }
} catch(e) {
  // Cross-origin iframe: silently ignore (already blocked by same-origin policy)
}
```

**Alternatives considered**:
- Proxying to parent (original plan): Creates a security hole; iframe could bypass permission checks
- Doing nothing: Cross-origin iframes are blocked by default, but same-origin iframes would have full JSBridge access

### Decision 6: Debug Mode

**Decision**: Enabled via `@Prop debugEnabled: boolean = false` on WebContainer, or via URL param `wldebug=1` in the src.

**Rationale**: Props give programmatic control; URL param gives quick developer access without code changes.

**Implementation**: In `onPageBegin`, after SDK injection, inject an additional intercept script:
```typescript
if (this.debugEnabled || this.src.includes('wldebug=1')) {
  const debugScript = `(function() {
    var origCall = window.JSBridge.call;
    window.JSBridge.call = function(m, p, cb) {
      console.log('[JSBridge] >>', m, JSON.stringify(p));
      origCall(m, p, function(res) {
        console.log('[JSBridge] <<', m, JSON.stringify(res));
        if (cb) cb(res);
      });
    };
  })()`
  this.controller.runJavaScript(debugScript)
}
```

**Rationale**: Props give programmatic control; URL param gives quick developer access without code changes.

**Implementation**: In `onPageBegin`, after SDK injection, inject an additional intercept script:
```typescript
if (this.debugEnabled || this.src.includes('wldebug=1')) {
  const debugScript = `(function() {
    var origCall = window.JSBridge.call;
    window.JSBridge.call = function(m, p, cb) {
      console.log('[JSBridge] >>', m, JSON.stringify(p));
      origCall(m, p, function(res) {
        console.log('[JSBridge] <<', m, JSON.stringify(res));
        if (cb) cb(res);
      });
    };
  })()`
  this.controller.runJavaScript(debugScript)
}
```

## Data Model

### Permission Map (in-memory, no persistence)

```typescript
type SourceType = 'rawfile' | 'file' | 'url'

interface PermissionConfig {
  sourceType: SourceType
  permissions: Record<string, PermissionLevel> // 'methodName' → 'allow' | 'deny'
}

// Default configurations:
const RAW_PERMISSIONS: Record<string, PermissionLevel> = {
  getAppInfo: 'allow',
  modifyNavStyle: 'allow',
  systemShare: 'allow',
  systemImagePick: 'allow',
  vibrate: 'allow',
  onBackPress: 'allow',
  navigateBack: 'allow'
}

const UNTRUSTED_PERMISSIONS: Record<string, PermissionLevel> = {
  getAppInfo: 'allow',
  modifyNavStyle: 'allow',
  systemShare: 'deny',      // SENSITIVE
  systemImagePick: 'deny',  // SENSITIVE
  vibrate: 'deny',          // SENSITIVE
  onBackPress: 'allow',
  navigateBack: 'allow'
}
```

### JSBridgeResponse (modified)

```typescript
interface JSBridgeResponse {
  status: 'ok' | 'error'
  code: string           // ← NEW: standardized error code
  data?: object | null
  error?: string         // ← Keep for backward compatibility
  message?: string       // ← NEW: human-readable message
  detail?: string        // ← NEW: additional debug info
}
```

### GetAppInfoResult (extended)

```typescript
interface GetAppInfoResult {
  // existing fields...
  sdkVersion: string     // ← NEW: e.g. '1.0.0'
}
```

## Contracts & Interfaces

### JSBridge.ets — New Constructor Signature

```typescript
export class JSBridge {
  constructor(
    controller: webview.WebviewController,
    context: common.UIAbilityContext,
    sourceType: SourceType    // ← NEW
  )
}
```

### JSBridge.ets — New Permission Check Method

```typescript
private checkPermission(method: string): boolean {
  const map = this.getPermissionMap(this.sourceType)
  return map[method] !== 'deny'
}
```

### JSBridge.ets — Modified handleCall

```typescript
handleCall(method: string, params: string, callId: string): void {
  // 1. Permission check (new)
  if (!this.checkPermission(method)) {
    this.callback(callId, { status: 'error', code: 'PERMISSION_DENIED', message: '不允许的来源调用' })
    return
  }
  // 2. Method dispatch (existing, extended with getVersion/hasMethod)
  switch (method) {
    case 'getAppInfo': ...
    case 'getVersion': this.handleGetVersion(callId)   // NEW
    case 'hasMethod': this.handleHasMethod(params, callId) // NEW
    // ... rest of existing cases
  }
}
```

### WebContainer.ets — New Props

```typescript
export struct WebContainer {
  @Prop src: string = ''
  @Prop appName: string = ''
  @Prop debugEnabled: boolean = false  // ← NEW
  // ...
}
```

### WebContainer.ets — New sourceType detection

```typescript
getSourceType(): SourceType {
  if (this.src.startsWith('rawfile://')) return 'rawfile'
  if (this.isUrlSource()) return 'url'
  return 'file'
}
```

### webleaf-sdk.js — New Methods

```javascript
// In window.webLeaf:
getVersion: function() {
  return window.webLeaf._call('getVersion');
},

hasMethod: function(name) {
  return window.webLeaf._call('hasMethod', { name: name });
},

// Existing methods unchanged
_call: function(method, params) {
  // Add 30s timeout
  var TIMEOUT_MS = 30000;
  var timeoutId;
  return new Promise(function(resolve, reject) {
    timeoutId = setTimeout(function() {
      reject(new JSBridgeError('TIMEOUT', '调用超时'));
    }, TIMEOUT_MS);
    window.JSBridge.call(method, params || {}, function(response) {
      clearTimeout(timeoutId);
      if (response && response.status === 'ok') {
        resolve(response.data || null);
      } else {
        reject(new JSBridgeError(
          response && response.code || 'UNKNOWN',
          response && response.message || '未知错误'
        ));
      }
    });
  });
},
```

### webleaf-sdk.js — Callback Cap & Iframe

```javascript
// In window.JSBridge initialization:
MAX_CALLBACKS: 500,

call: function(method, params, callback) {
  // Cap callbacks to prevent leak
  var keys = Object.keys(this._callbacks);
  if (keys.length >= this.MAX_CALLBACKS) {
    var toRemove = keys.slice(0, 100);
    for (var i = 0; i < toRemove.length; i++) {
      delete this._callbacks[toRemove[i]];
    }
  }
  // ... existing logic unchanged
}

// After window.webLeaf definition:
// Iframe support: proxy to parent
try {
  if (window !== window.top && window.top.webLeaf) {
    window.webLeaf = window.top.webLeaf;
  }
} catch(e) {
  // Cross-origin iframe: silently ignore
}
```
