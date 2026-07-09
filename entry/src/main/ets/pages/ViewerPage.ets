import { webview } from '@kit.ArkWeb'
import { WebPreloader } from '../util/WebPreloader'
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
  private controller: webview.WebviewController = new webview.WebviewController()
  private preloader: WebPreloader = WebPreloader.getInstance()
  private navPathStack: NavPathStack | undefined = undefined

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

    if (this.entryHtml.length > 0) {
      this.preloader.recordAccess(this.entryHtml)
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
      .onProgressChange((event) => {
        if (event) {
          this.loadProgress = event.newProgress
        }
      })
      .onPageBegin(() => {
        this.isLoading = true
      })
      .onPageEnd(() => {
        this.isLoading = false
        this.preloader.markLoaded(this.entryHtml)
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
              .onClick(() => {
                this.retry()
              })
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
    .title(this.appName)
  }
}
