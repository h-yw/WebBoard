# Tasks: WebView 预热加速

## Phase 1: WebPreloader 预热池
- [X] T001 Add `PreloadEntry` interface and `preload()`, `takeController()`, `cleanup()`, `setEnabled()` to `container/src/main/ets/util/WebPreloader.ets`
- [X] T002 Add TTL cleanup timer (5 min interval) in `WebPreloader` — check and evict expired entries

## Phase 2: WebContainer 接收预热
- [X] T003 Add `@Prop preloadController?: webview.WebviewController` to `container/src/main/ets/webview/WebContainer.ets`
- [X] T004 In `WebContainer.aboutToAppear()`: if `this.preloadController` is provided, use it instead of `new webview.WebviewController()`; call `takeController()` on WebPreloader to remove from pool
- [X] T005 Update `WebContainerController` to expose preload state if needed

## Phase 3: 首页空闲预热
- [X] T006 In `entry/src/main/ets/pages/Index.ets`: after `loadApps()` + 2s delay, call `WebPreloader.getInstance().preload()` for the top 2 most-used apps (sorted by `open_count` or `last_opened_at`)
- [X] T007 Update `entry/src/main/ets/pages/ViewerPage.ets`: when opening an app, check WebPreloader for a pre-created controller and pass it as `preloadController` to WebContainer

## Phase 4: Verification
<!-- verification_scope: build-only -->
- [ ] T008 Build project
- [ ] T009 Deploy to real device
