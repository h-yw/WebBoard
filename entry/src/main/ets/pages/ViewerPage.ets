import { webview } from '@kit.ArkWeb'
import { WebContainer, WebContainerController, WebPreloader, DatabaseManager, Logger } from 'container'
import http from '@ohos.net.http'
import { promptAction } from '@kit.ArkUI'

interface ViewerParam {
  entryHtml: string
  appName: string
}

@Component
export struct ViewerPage {
  @State entryHtml: string = ''
  @State appName: string = ''
  @State wcController: WebContainerController = new WebContainerController()
  private preloader: WebPreloader = WebPreloader.getInstance()
  private navPathStack: NavPathStack | undefined = undefined
  private preloadController: webview.WebviewController | undefined = undefined
  private dbMgr: DatabaseManager | null = null

  aboutToAppear(): void {
    const info = this.queryNavigationInfo()
    this.navPathStack = info?.pathStack
    if (this.navPathStack) {
      // Provide a navigateBack callback so WebContainer (in HSP) can
      // pop the stack without importing NavPathStack type
      this.wcController.navigateBack = (): void => {
        this.navPathStack!.pop()
      }
      const paramObj = this.navPathStack.getParamByName('ViewerPage') as ViewerParam[]
      if (paramObj && paramObj.length > 0) {
        this.entryHtml = paramObj[0].entryHtml || ''
        this.appName = paramObj[0].appName || 'WebLeaf'
      }
    }

    this.parseNavParams()

    // Check for preheated controller from the preheating pool
    if (this.entryHtml.length > 0) {
      const preloader = WebPreloader.getInstance()
      const taken: webview.WebviewController | null = preloader.takeController(this.entryHtml)
      if (taken) {
        this.preloadController = taken
        Logger.debug('ViewerPage', 'using preheated controller for: ' + this.entryHtml)
      }
    }

    if (this.entryHtml.length > 0) {
      this.preloader.recordAccess(this.entryHtml)
    }

    // Check for app updates (only for URL-sourced apps)
    if (this.entryHtml.length > 0 && this.isUrlSource(this.entryHtml)) {
      this.checkForUpdate(this.entryHtml)
    }
  }

  private isUrlSource(src: string): boolean {
    return src.startsWith('http://') || src.startsWith('https://')
  }

  private async checkForUpdate(url: string): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext()
      this.dbMgr = DatabaseManager.getInstance(context as Context)
      await this.dbMgr.init()

      const savedHash: string = await this.dbMgr.getSetting('app_hash_' + url, '')
      const httpRequest = http.createHttp()
      httpRequest.request(url, { method: http.RequestMethod.HEAD, connectTimeout: 5000, readTimeout: 5000 }, (err: Error | null, resp: http.HttpResponse): void => {
        if (err) {
          Logger.warn('ViewerPage', 'checkForUpdate HEAD failed')
          return
        }
        const etag: string = (resp.header as Record<string, string>)['ETag'] || ''
        const lastMod: string = (resp.header as Record<string, string>)['Last-Modified'] || ''
        const currentHash: string = etag || lastMod || ''
        if (currentHash.length > 0 && savedHash.length > 0 && currentHash !== savedHash) {
          // Content changed, prompt user
          promptAction.showDialog({
            title: '应用已更新',
            message: '此在线应用有新版本，是否刷新？',
            buttons: [
              { text: '忽略', color: '#666666' },
              { text: '刷新', color: '#6366F1' }
            ]
          }).then((data) => {
            if (data.index === 1) {
              this.dbMgr!.setSetting('app_hash_' + url, currentHash)
              // Refresh needs WebContainer controller — handled by the WebView
            }
          })
        } else if (currentHash.length > 0 && savedHash.length === 0) {
          // First visit, save hash
          this.dbMgr!.setSetting('app_hash_' + url, currentHash)
        }
      })
    } catch (e) {
      Logger.warn('ViewerPage', 'checkForUpdate failed')
    }
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
            this.wcController.navStyle = parsedStyle
          }
        } else if (key === 'wl_nav_title') {
          this.wcController.customTitle = value
        }
      }
    } catch (e) {
      Logger.warn('ViewerPage', 'parseNavParams failed')
    }
  }

  private getNavTitle(): string {
    if (this.wcController.navStyle === 0) {
      return ''
    }
    if (this.wcController.navStyle === 1) {
      return ''
    }
    return this.wcController.customTitle.length > 0 ? this.wcController.customTitle : this.appName
  }

  build() {
    NavDestination() {
      WebContainer({
        src: this.entryHtml,
        appName: this.appName,
        wcController: $wcController,
        preloadController: this.preloadController
      })
    }
    .title(this.getNavTitle(), {
      barStyle: this.wcController.navStyle === 1 ? BarStyle.STACK : BarStyle.STANDARD
    })
    .hideTitleBar(this.wcController.navStyle === 0)
    .onBackPressed((): boolean => {
      return this.wcController.handleBackPress()
    })
  }
}
