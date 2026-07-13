import { webview } from '@kit.ArkWeb'
import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { WebPreloader } from '../util/WebPreloader'
import { JSBridge, type JsProxyObject } from '../util/JSBridge'
import { Logger } from '../common/Logger'

interface ViewerParam {
  entryHtml: string
  appName: string
}

@Component
export struct ViewerPage {
  @State entryHtml: string = ''
  @State appName: string = ''
  @State isLoading: boolean = true
  @State loadProgress: number = 0
  @State hasError: boolean = false
  @State errorMessage: string = ''
  @State navStyle: number = -1
  @State customTitle: string = ''
  private controller: webview.WebviewController = new webview.WebviewController()
  private preloader: WebPreloader = WebPreloader.getInstance()
  private navPathStack: NavPathStack | undefined = undefined
  private jsBridge: JSBridge | null = null
  private context: common.UIAbilityContext | null = null

  aboutToAppear(): void {
    const info = this.queryNavigationInfo()
    this.navPathStack = info?.pathStack
    if (this.navPathStack) {
      const paramObj = this.navPathStack.getParamByName('ViewerPage') as ViewerParam[]
      if (paramObj && paramObj.length > 0) {
        this.entryHtml = paramObj[0].entryHtml || ''
        this.appName = paramObj[0].appName || 'WebLeaf'
      }
    }

    this.parseNavParams()

    if (this.entryHtml.length > 0) {
      this.preloader.recordAccess(this.entryHtml)
    }

    try {
      this.context = getContext(this) as common.UIAbilityContext
    } catch (e) {
      Logger.warn('ViewerPage', 'getContext failed')
    }

    this.setupJSBridge()
  }

  private parseNavParams(): void {
    if (this.entryHtml.length <= 0) {
      return
    }
    try {
      const queryStart: number = this.entryHtml.indexOf('?')
      if (queryStart < 0) {
        return
      }
      const queryString: string = this.entryHtml.substring(queryStart + 1)
      const pairs: string[] = queryString.split('&')
      for (let i = 0; i < pairs.length; i++) {
        const pair: string[] = pairs[i].split('=')
        if (pair.length !== 2) {
          continue
        }
        const key: string = pair[0]
        const value: string = decodeURIComponent(pair[1])
        if (key === 'wl_nav_style') {
          const parsedStyle: number = parseInt(value)
          if (parsedStyle === 0 || parsedStyle === 1) {
            this.navStyle = parsedStyle
          }
        } else if (key === 'wl_nav_title') {
          this.customTitle = value
        }
      }
    } catch (e) {
      Logger.warn('ViewerPage', 'parseNavParams failed')
    }
  }

  isUrlSource(): boolean {
    return this.entryHtml.startsWith('http://') || this.entryHtml.startsWith('https://')
  }

  getWebSrc(): string | Resource {
    if (this.entryHtml.startsWith('rawfile://')) {
      return $rawfile(this.entryHtml.substring(10))
    }
    if (this.isUrlSource()) {
      return this.entryHtml
    }
    if (this.entryHtml.startsWith('file://')) {
      return this.entryHtml
    }
    return 'file://' + this.entryHtml
  }

  aboutToDisappear(): void {
    try {
      this.controller.clearHistory()
    } catch (e) {
      Logger.error('ViewerPage', 'clearHistory failed')
    }
  }

  retry(): void {
    this.hasError = false
    this.isLoading = true
    this.loadProgress = 0
    try {
      this.controller.refresh()
    } catch (e) {
      Logger.error('ViewerPage', 'refresh failed')
    }
  }

  private setupJSBridge(): void {
    if (this.jsBridge) {
      return
    }
    if (!this.context) {
      try {
        this.context = getContext(this) as common.UIAbilityContext
      } catch (e) {
        Logger.warn('ViewerPage', 'getContext failed in setupJSBridge')
        return
      }
    }
    this.jsBridge = new JSBridge(this.controller, this.context)
    this.jsBridge.setNavChangeCallback((style: number, title?: string): void => {
      this.navStyle = style
      if (title) {
        this.customTitle = title
      }
    })
    this.jsBridge.setNavigateBackCallback((): void => {
      if (this.navPathStack) {
        this.navPathStack.pop()
      }
    })
  }

  @Builder
  WebContent() {
    Web({
      src: this.getWebSrc(),
      controller: this.controller
    })
      .javaScriptAccess(true)
      .fileAccess(!this.entryHtml.startsWith('rawfile://') && !this.isUrlSource())
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
          } catch (e) {
            Logger.warn('ViewerPage', 'initJSBridge failed')
          }
        }
      })
      .onPageEnd(() => {
        this.isLoading = false
      })
      .onErrorReceive((event) => {
        if (event) {
          this.hasError = true
          this.errorMessage = '页面加载失败，请检查网络连接后重试'
        }
      })
      .layoutWeight(1)
      .width('100%')
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

  build() {
    NavDestination() {
      Column() {
        if (this.isLoading && !this.hasError) {
          Progress({ value: this.loadProgress, total: 100, type: ProgressType.Linear })
            .width('100%')
            .height(3)
            .color($r('app.color.app_primary'))
            .backgroundColor($r('app.color.app_divider'))
        } else {
          Divider().color($r('app.color.app_divider')).width('100%')
        }

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
              .onClick(() => { this.retry() })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .padding({ left: 32, right: 32 })
        } else if (this.entryHtml.length > 0) {
          this.WebContent()
        } else {
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
      .backgroundColor($r('app.color.app_card_bg'))
    }
    .title(this.getNavTitle(),{
      barStyle:this.navStyle===1?BarStyle.STACK: BarStyle.STANDARD
    })
    .hideTitleBar(this.navStyle === 0)
    .onBackPressed((): boolean => {
      // 1. Web 内部历史回退（优先）
      try {
        if (this.controller.accessBackward()) {
          this.controller.backward()
          return true
        }
      } catch (e) {
        Logger.warn('ViewerPage', 'accessBackward failed')
      }

      // 2. JSBridge 返回拦截（H5 请求确认）
      if (this.jsBridge && this.jsBridge.hasBackPressCallback()) {
        const showDialogParam: promptAction.ShowDialogOptions = {
          title: '确认返回',
          message: 'H5 页面请求确认是否返回？',
          buttons: [
            { text: '取消', color: $r('app.color.app_text_secondary') },
            { text: '确定返回', color: $r('app.color.app_primary') }
          ]
        }
        this.getUIContext().getPromptAction().showDialog(showDialogParam)
          .then((data: promptAction.ShowDialogSuccessResponse) => {
            if (data.index === 1) {
              // 用户确认返回，通知 H5 允许返回
              const cb = this.jsBridge!.getBackPressCallback()
              if (cb) {
                cb()
              }
              this.navPathStack?.pop()
            }
          })
        return true
      }

      // 3. 无拦截：系统处理 NavStack pop（返回 false）
      return false
    })
  }



  private getNavTitle(): string|CustomBuilder {
    if (this.navStyle === 0) {
      return ''
    }
    if (this.navStyle === 1) {
      return ''
    }
    return this.customTitle || this.appName
  }
}
