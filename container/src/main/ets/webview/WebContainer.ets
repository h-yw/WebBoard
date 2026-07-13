import { webview } from '@kit.ArkWeb'
import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { JSBridge, type JsProxyObject, type SourceType } from './JSBridge'
import { Logger } from '../common/Logger'
import { WEBLEAF_SDK_SCRIPT } from './webleaf-sdk'
import { WebContainerController } from './WebContainerController'

/**
 * WebContainer — A reusable, self-contained WebView component.
 *
 * Encapsulates:
 * - Web component with all required configurations (javaScriptAccess, mixedMode, etc.)
 * - JSBridge lifecycle (init, onControllerAttached, javaScriptProxy)
 * - Loading progress bar + error/retry UI
 * - Auto-injection of `window.webLeaf` SDK via `onPageBegin`
 *
 * Does NOT include NavDestination wrapper — navigation is owned by the
 * parent hosting page (typically ViewerPage in entry module).
 *
 * Back press handling is exposed via getController() and getJSBridge() so
 * the parent NavDestination can implement onBackPressed triage.
 */
@Component
export struct WebContainer {
  @Prop src: string = ''
  @Prop appName: string = ''
  @Prop debugEnabled: boolean = false
  @Link wcController: WebContainerController
  @State loadProgress: number = 0
  @State hasError: boolean = false
  @State isLoading: boolean = true
  @State navStyle: number = -1
  @State customTitle: string = ''
  private controller: webview.WebviewController = new webview.WebviewController()
  private jsBridge: JSBridge | null = null
  private context: common.UIAbilityContext | null = null

  // --- Public accessors for parent (ViewerPage) ---

  getController(): webview.WebviewController {
    return this.controller
  }

  getJSBridge(): JSBridge | null {
    return this.jsBridge
  }

  getNavStyle(): number {
    return this.navStyle
  }

  getCustomTitle(): string {
    return this.customTitle
  }

  // --- Lifecycle ---

  onPageShow(): void {
    const script: string = 'try { window.dispatchEvent(new CustomEvent("WebLeafForeground")); } catch(e) {}'
    try {
      this.controller.runJavaScript(script)
    } catch (e) {
      Logger.warn('WebContainer', 'push foreground event failed')
    }
  }

  aboutToAppear(): void {
    // Wire up the controller for back press delegation
    this.wcController.handleBackPress = (): boolean => {
      return this.handleBackPress()
    }
    try {
      this.context = getContext(this) as common.UIAbilityContext
    } catch (e) {
      Logger.warn('WebContainer', 'getContext failed')
    }
    this.setupJSBridge()
  }

  aboutToDisappear(): void {
    const bgScript: string = 'try { window.dispatchEvent(new CustomEvent("WebLeafBackground")); } catch(e) {}'
    try {
      this.controller.runJavaScript(bgScript)
    } catch (e) {
      Logger.warn('WebContainer', 'push background event failed')
    }
    try {
      this.controller.clearHistory()
    } catch (e) {
      Logger.error('WebContainer', 'clearHistory failed')
    }
  }

  retry(): void {
    this.hasError = false
    this.isLoading = true
    this.loadProgress = 0
    try {
      this.controller.refresh()
    } catch (e) {
      Logger.error('WebContainer', 'refresh failed')
    }
  }

  getWebSrc(): string {
    if (this.src.startsWith('rawfile://')) {
      return 'resource://rawfile/' + this.src.substring(10)
    }
    if (this.isUrlSource()) {
      return this.src
    }
    if (this.src.startsWith('file://')) {
      return this.src
    }
    return 'file://' + this.src
  }

  isUrlSource(): boolean {
    return this.src.startsWith('http://') || this.src.startsWith('https://')
  }

  getSourceType(): SourceType {
    if (this.src.startsWith('rawfile://')) {
      return 'rawfile'
    }
    if (this.src.startsWith('http://') || this.src.startsWith('https://')) {
      return 'url'
    }
    return 'file'
  }

  // --- JSBridge setup ---

  private setupJSBridge(): void {
    if (this.jsBridge) {
      return
    }
    if (!this.context) {
      try {
        this.context = getContext(this) as common.UIAbilityContext
      } catch (e) {
        Logger.warn('WebContainer', 'getContext failed in setupJSBridge')
        return
      }
    }
    this.jsBridge = new JSBridge(this.controller, this.context, this.getSourceType())
    this.jsBridge.setNavChangeCallback((style: number, title?: string): void => {
      this.navStyle = style
      this.wcController.navStyle = style
      if (title) {
        this.customTitle = title
        this.wcController.customTitle = title
      }
    })
    this.jsBridge.setNavigateBackCallback((): void => {
      this.wcController.navigateBack()
    })
  }

  private getJSBridgeProxy(): JsProxyObject {
    if (this.jsBridge) {
      return this.jsBridge.javaScriptProxy
    }
    const emptyProxy: object = new Object()
    const emptyList: string[] = []
    return {
      object: emptyProxy,
      name: 'JSBridgeHandle',
      methodList: emptyList,
      controller: this.controller
    }
  }

  // --- Handle back press internally (called by ViewerPage) ---
  // Returns true if back press was handled, false if parent should pop

  handleBackPress(): boolean {
    // 1. Web history backward (priority)
    try {
      if (this.controller.accessBackward()) {
        this.controller.backward()
        return true
      }
    } catch (e) {
      Logger.warn('WebContainer', 'accessBackward failed')
    }

    // 2. JSBridge back press callback (H5 requests confirmation)
    if (this.jsBridge && this.jsBridge.hasBackPressCallback()) {
      const showDialogParam: promptAction.ShowDialogOptions = {
        title: '确认返回',
        message: 'H5 页面请求确认是否返回？',
        buttons: [
          { text: '取消', color: $r('app.color.app_text_secondary') },
          { text: '确定返回', color: $r('app.color.app_primary') }
        ]
      }
      try {
        this.getUIContext().getPromptAction().showDialog(showDialogParam)
          .then((data: promptAction.ShowDialogSuccessResponse) => {
            if (data.index === 1) {
              const cb = this.jsBridge!.getBackPressCallback()
              if (cb) {
                cb()
              }
              this.wcController.navigateBack()
            }
          })
      } catch (e) {
        Logger.error('WebContainer', 'showDialog failed')
      }
      return true
    }

    // 3. Not handled - parent should pop
    return false
  }

  // --- Build ---

  build() {
    Column() {
      // Loading progress bar
      if (this.isLoading && !this.hasError) {
        Progress({ value: this.loadProgress, total: 100, type: ProgressType.Linear })
          .width('100%')
          .height(3)
          .color($r('app.color.app_primary'))
          .backgroundColor($r('app.color.app_divider'))
      } else {
        Divider().color($r('app.color.app_divider')).width('100%')
      }

      // Error state
      if (this.hasError) {
        Column() {
          Text($r('app.string.viewer_loading_failed'))
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.app_text_primary'))
          Text($r('app.string.viewer_error_message'))
            .fontSize(14)
            .fontColor($r('app.color.app_text_secondary'))
            .margin({ top: 8 })
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .textAlign(TextAlign.Center)
          Button($r('app.string.btn_retry'))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .height(44)
            .borderRadius(8)
            .backgroundColor($r('app.color.app_primary'))
            .margin({ top: 20 })
            .onClick(() => {
              this.retry()
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding({ left: 32, right: 32 })
      } else if (this.src.length > 0) {
        // Web content with JSBridge and SDK auto-injection
        Web({
          src: this.getWebSrc(),
          controller: this.controller
        })
          .javaScriptAccess(true)
          .fileAccess(!this.src.startsWith('rawfile://') && !this.isUrlSource())
          .mixedMode(MixedMode.All)
          .domStorageAccess(true)
          .cacheMode(CacheMode.Default)
          .javaScriptProxy(this.getJSBridgeProxy())
          .onControllerAttached(() => {
            this.setupJSBridge()
          })
          .onProgressChange((event) => {
            if (event) {
              this.loadProgress = event.newProgress
            }
          })
          .onPageBegin(() => {
            this.isLoading = true
            if (this.jsBridge) {
              try {
                this.jsBridge.initJSBridge()
                // Auto-inject the window.webLeaf SDK
                this.controller.runJavaScript(WEBLEAF_SDK_SCRIPT)
                Logger.debug('WebContainer', 'webleaf SDK auto-injected via runJavaScript')
                // Debug mode: wrap JSBridge.call with console logging
                if (this.debugEnabled || this.src.includes('wldebug=1')) {
                  const debugScript: string = `(function() {
                    if (window.__webLeafDebug) return; window.__webLeafDebug = true;
                    var origCall = window.JSBridge.call;
                    window.JSBridge.call = function(m, p, cb) {
                      console.log('[JSBridge] >>', m, JSON.stringify(p));
                      // Use .call() to preserve 'this' reference to window.JSBridge
                      origCall.call(window.JSBridge, m, p, function(res) { console.log('[JSBridge] <<', m, JSON.stringify(res)); if (cb) cb(res); });
                    };
                  })()`
                  this.controller.runJavaScript(debugScript)
                  Logger.debug('WebContainer', 'JSBridge debug mode enabled')
                }
              } catch (e) {
                Logger.warn('WebContainer', 'initJSBridge/runJavaScript failed')
              }
            }
          })
          .onPageEnd(() => {
            this.isLoading = false
          })
          .onErrorReceive((event) => {
            if (event) {
              this.hasError = true
            }
          })
          .layoutWeight(1)
          .width('100%')
      } else {
        // Empty state
        Column() {
          Text($r('app.string.viewer_no_content'))
            .fontSize(16)
            .fontColor($r('app.color.app_text_muted'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
  }
}
