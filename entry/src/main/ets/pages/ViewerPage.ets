import { WebContainer, WebContainerController, WebPreloader, Logger } from 'container'

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

    if (this.entryHtml.length > 0) {
      this.preloader.recordAccess(this.entryHtml)
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
        wcController: $wcController
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
