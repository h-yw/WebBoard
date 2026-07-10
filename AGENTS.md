# AGENTS.md — WebBoard (浮叶 / WebLeaf)

## What this is

A compact instruction file for future OpenCode / AI coding sessions working on this HarmonyOS ArkTS project. Every line here answers: "Would an agent likely miss this without help?" If not, leave it out.

## Project identity

- **Bundle**: `life.hlovez.webboard`
- **Target SDK**: 6.0.2(22) / API 12+ (HarmonyOS NEXT)
- **App names**: English = "WebLeaf", Chinese = "浮叶", code-on-disk = "WebBoard"
- **Single-module**: only `entry/` (no multi-module boundaries)
- **Single-ability**: `EntryAbility` → `SplashPage` (not Index directly)

## High-signal architecture facts

### Navigation

- Uses `Navigation` + `NavDestination` pattern (the recommended approach for API 12+).
- **Only** `pages/Index` is registered in `main_pages.json`. All other pages (`ImportPage`, `ViewerPage`, `EditPage`, `SettingsPage`) are registered via `@Builder buildNavDestination()` inside `Index.ets` — this is the **correct best practice** for HarmonyOS API 12+.
- Parameters are passed via `NavPathStack.pushPath({name, param})` and retrieved with `navPathStack.getParamByName()` in `aboutToAppear()`.
- `SplashPage` is the sole holdout using the legacy `router.replaceUrl()` API. Future refactor should either: (a) move splash animation into Index and load `pages/Index` directly from EntryAbility, or (b) give SplashPage its own `NavPathStack`.

### State refresh across pages

- A custom `EventEmitter` (`common/EventEmitter.ets`) handles cross-page data sync. When `EditPage` saves changes, it calls `eventEmitter.emit("item:update", ...)`, and `Index.ets` listens via `eventEmitter.on("item:update", ...)` to reload the list.
- Also uses `@StorageProp('dataRefreshTick')` with `@Watch` as a backup refresh signal.

### Database

- SQLite via `@ohos.data.relationalStore`. Singleton `DatabaseManager` (lazy init with `initPromise` guard).
- Two tables: `web_apps` (10 columns) and `settings` (key-value).
- CRUD for apps uses `RdbPredicates`; settings uses upsert pattern (`update` → if 0 rows affected → `insert`).
- **Wait for `dbMgr.init()` before calling any CRUD** — it's async and runs in `EntryAbility.onCreate()`.
- DB is initialized in `EntryAbility.onCreate()`. Pages should call `DatabaseManager.getInstance(context)` and may call `init()` if not already initialized.

### WebView / JSBridge

- H5↔Native bridge uses `javaScriptProxy` (inject `JSBridgeHandle`) + `runJavaScript` (callback dispatch).
- JSBridge is initialized in `ViewerPage` via `aboutToAppear()` and `onControllerAttached()`.
- 8 native methods: `getAppInfo`, `modifyNavStyle`, `systemShare`, `systemImagePick`, `vibrate`, `onBackPress`, `navigateBack`, plus a generic `call()` entry point.
- `WebPreloader` creates hidden `WebviewController` instances for preloading. Uses LRU eviction (max 5) and stale cleanup (5 min TTL).

### UI utilities

- Custom `Toast`, `Loading`, `Dialog` built on `promptAction.openCustomDialog` / `showToast`. These are wrappers, not system APIs.
- `Loading` uses `wrapBuilder(LoadingContentBuilder)` pattern with a global `isShowing` flag to prevent stacking.
- `Dialog` uses a global `dialogState` object + `DialogContentBuilder`. `confirm()` and `alert()` are modal.

### LazyForEach

- `AppDataSource` implements `IDataSource` interface for `LazyForEach` in the list/grid.
- `setApps()` calls `listener.onDataReloaded()` — not incremental. For small datasets (< 200 items) this is fine.

### Permissions (module.json5)

| Permission | Purpose |
|---|---|
| `ohos.permission.INTERNET` | WebView network access |
| `ohos.permission.FILE_ACCESS_PERSIST` | Persistent file URI access across reboots |
| `ohos.permission.VIBRATE` | JSBridge vibrate method |
| `ohos.permission.GET_NETWORK_INFO` | JSBridge getAppInfo network status |

### ArkTS specifics

- **No `any` / `unknown` / `as` type assertions** — the codebase uses explicit interfaces and type-safe patterns (`Record<string, ValueType>` style for generic maps).
- Uses `type` for interfaces and `export struct` for components.
- All components are `struct` with `@Component` and `export` (except `@Entry` pages which are top-level).
- Static singleton pattern used: `DatabaseManager.getInstance()`, `WebPreloader.getInstance()`.
- No DI framework or dependency injection — context is passed explicitly.

### Key build / dev commands

- Build: `hvigorw assembleHap` or use DevEco Studio
- Lint: configured in `code-linter.json5` — security rules (`@security/no-unsafe-*`) flagged as errors
- Test deps: `@ohos/hypium`, `@ohos/hamock` (in root `oh-package.json5`)
- No CI workflows, no pre-commit hooks, no snapshot tests found

## Important docs & specs

| File | Content |
|---|---|
| `docs/README.md` | Main dev docs — architecture, routing, Web component, navigation |
| `docs/feature.md` | Feature spec: URL params + JSBridge methods |
| `docs/feature2.md` | Feature v2: edit page, card list fix, share card |
| `docs/data-model.md` | Data model and storage design |
| `docs/refactor.md` | Refactoring notes and optimization TODOs |
| `docs/ui-design.md` | UI design specs (colors, spacing, typography) |
| `docs/arkts-pitfalls.md` | Known ArkTS/ArkUI issues (Radio onChange bug) |
| `spec/webview-jsbridge/plan.md` | Implementation plan for JSBridge |
| `spec/webboard-refactor/plan.md` | Implementation plan for the SQLite + branding refactor |

## Code structure (entry/src/main/ets/)

```
├── common/          Constants.ets, EventEmitter.ets, Logger.ets
├── component/       AppShareCard.ets
├── database/        DatabaseManager.ets (SQLite singleton)
├── entryability/    EntryAbility.ets
├── entrybackupability/
├── model/           WebAppItem.ets, AppDataSource.ets
├── pages/           Index.ets, ImportPage.ets, ViewerPage.ets, EditPage.ets, SettingsPage.ets, SplashPage.ets
├── ui/              ToastUtil.ets, LoadingUtil.ets, DialogUtil.ets
└── util/            FileManager.ets, JSBridge.ets, WebPreloader.ets, WorkDirectory.ets
```

## Gotchas & pitfalls

- **Radio `onChange` bug**: Radio's `onChange` fires on programmatic changes in some API versions. Use `onClick` on the parent `Row` instead. Documented in `docs/arkts-pitfalls.md`.
- **Custom image cards**: Images in cards need `hitTestMode(HitTestMode.None)` so the parent's long-press gesture (`LongPressGesture`) fires. Without this, tapping the image region won't trigger the action sheet.
- **Backup extension**: `EntryBackupAbility` exists with a backup profile config resource — don't remove it accidentally.
- **Share card** uses `ComponentContent` + `getComponentSnapshot().createFromComponent()` + `ImagePacker` to render a card as PixelMap → PNG. This is async and needs `waitUntilRenderFinished: true`.
- **QR scan** expects JSON format `{"t":"title","d":"desc","u":"url"}`. Parsing failure shows the raw content in an alert dialog.
- **ViewerPage back press** has a triage: (1) Web history backward → (2) JSBridge back callback → (3) NavStack pop. The JSBridge path shows a confirm dialog to the user.
- **Loading/Dialog singletons**: `Loading` and `Dialog` use global variables (`currentLoadingId`, `currentDialogId`, `dialogState`). Only one can be shown at a time. Calling `Loading.show()` while already showing is a no-op.

## What to do when stuck

1. Check `docs/README.md` — covers architecture, routing, Web component, navigation
2. Check `docs/` other files — data model, UI design, known pitfalls
3. Check `spec/` — has specs and implementation plans for major features
4. Check `common/Constants.ets` for enum values and thresholds
5. For JSBridge issues, see `util/JSBridge.ets` and `spec/webview-jsbridge/`
6. Use `arkts_check` tool to detect ArkTS strict-mode violations before building
