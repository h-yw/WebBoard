import { WebAppItem } from '../model/WebAppItem'
import { AppDataSource } from '../model/AppDataSource'
import { DatabaseManager } from '../database/DatabaseManager'
import { WebPreloader } from '../util/WebPreloader'
import { WorkDirectory } from '../util/WorkDirectory'
import { common } from '@kit.AbilityKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { fileUri } from '@kit.CoreFileKit'
import { systemShare } from '@kit.ShareKit'
import { uniformTypeDescriptor as utd } from '@kit.ArkData'
import { image } from '@kit.ImageKit'
import { ImportPage } from './ImportPage'
import { ViewerPage } from './ViewerPage'
import { EditPage } from './EditPage'
import { SettingsPage } from './SettingsPage'
import { LogoType, SourceType, LayoutMode } from '../common/Constants'
import { Toast } from '../ui/ToastUtil'
import { Logger } from '../common/Logger'
import { ComponentContent } from '@kit.ArkUI'
import { AppShareCardBuilder, ShareCardParams } from '../common/AppShareCard'

interface ViewerParam {
  entryHtml: string
  appName: string
}

interface EditParam {
  appId: string
  appName: string
  appDescription: string
  logoType: string
  logoUri: string
  entryHtml: string
  sourceType: string
}

@Entry
@Component
struct Index {
  @State appList: WebAppItem[] = []
  @State searchKeyword: string = ''
  @State isRefreshing: boolean = false
  @State layoutMode: string = LayoutMode.GRID
  @StorageProp('dataChanged') @Watch('onDataChanged') dataChanged: boolean = false
  private dataSource: AppDataSource = new AppDataSource()
  private dbMgr: DatabaseManager | null = null
  private context: common.UIAbilityContext | null = null
  private navPathStack: NavPathStack = new NavPathStack()

  getFilteredApps(): WebAppItem[] {
    if (!this.appList || this.appList.length === 0) {
      return []
    }
    if (this.searchKeyword.length === 0) {
      return this.appList
    }
    const keyword = this.searchKeyword.toLowerCase()
    const result: WebAppItem[] = []
    for (let i = 0; i < this.appList.length; i++) {
      const app = this.appList[i]
      if (app.name.toLowerCase().includes(keyword) ||
          app.description.toLowerCase().includes(keyword)) {
        result.push(app)
      }
    }
    return result
  }

  async aboutToAppear(): Promise<void> {
    this.context = this.getUIContext().getHostContext() as common.UIAbilityContext
    this.dbMgr = DatabaseManager.getInstance(this.context)
    await this.dbMgr.init()
    WorkDirectory.ensureDirectory(this.context)
    
    const layoutStr = await this.dbMgr.getSetting('layout_mode', LayoutMode.GRID)
    this.layoutMode = layoutStr
    await this.loadApps()
    await this.ensurePresetApps()
    this.preloadRecentApps()
  }

  onPageShow(): void {
    // dataChanged 通过 @Watch 自动触发，无需手动检查
  }

  onDataChanged(): void {
    if (this.dataChanged) {
      this.loadApps()
      AppStorage.setOrCreate('dataChanged', false)
    }
  }

  async ensurePresetApps(): Promise<void> {
    if (!this.dbMgr) {
      return
    }
    const existingApps = await this.dbMgr.getAllApps()
    const existingHtmlSet: Set<string> = new Set()
    for (let i = 0; i < existingApps.length; i++) {
      existingHtmlSet.add(existingApps[i].entryHtml)
    }
    let hasNew: boolean = false

    const presetHtml1: string = 'rawfile://code_artifact.html'
    if (!existingHtmlSet.has(presetHtml1)) {
      const item = new WebAppItem()
      item.id = WorkDirectory.generateId()
      item.name = '速算估算微练'
      item.description = '掌握 1/2 到 1/20 的快速转换，提升心算敏感度'
      item.logoType = LogoType.INITIAL
      item.logoUri = ''
      item.entryHtml = presetHtml1
      item.sourceType = SourceType.PRESET
      item.createTime = Date.now()
      await this.dbMgr.addApp(item)
      hasNew = true
    }

    const presetHtml2: string = 'rawfile://jsbridge_test.html'
    if (!existingHtmlSet.has(presetHtml2)) {
      const item = new WebAppItem()
      item.id = WorkDirectory.generateId()
      item.name = 'JSBridge 测试'
      item.description = '测试 JSBridge 所有原生方法调用'
      item.logoType = LogoType.INITIAL
      item.logoUri = ''
      item.entryHtml = presetHtml2
      item.sourceType = SourceType.PRESET
      item.createTime = Date.now()
      await this.dbMgr.addApp(item)
      hasNew = true
    }

    if (hasNew) {
      AppStorage.setOrCreate('dataChanged', true)
      await this.loadApps()
    }
  }

  async loadApps(): Promise<void> {
    if (this.dbMgr) {
      this.appList = await this.dbMgr.getAllApps()
      this.dataSource.setApps(this.getFilteredApps())
    }
  }

  async scanWorkDirectory(): Promise<void> {
    if (!this.context || !this.dbMgr) {
      this.isRefreshing = false
      return
    }

    const existingItems = await this.dbMgr.getAllApps()
    const scannedItems = WorkDirectory.scanDirectory(this.context)

    const existingPaths = new Set<string>()
    for (let i = 0; i < existingItems.length; i++) {
      existingPaths.add(existingItems[i].entryHtml)
    }

    let hasNew = false
    for (let i = 0; i < scannedItems.length; i++) {
      if (!existingPaths.has(scannedItems[i].entryHtml)) {
        await this.dbMgr.addApp(scannedItems[i])
        hasNew = true
      }
    }

    if (hasNew) {
      await this.loadApps()
    }

    this.isRefreshing = false
  }

  preloadRecentApps(): void {
    const preloader = WebPreloader.getInstance()
    const recentKeys = preloader.getRecentKeys()
    for (let i = 0; i < recentKeys.length; i++) {
      const key = recentKeys[i]
      const item = this.appList.find(app => app.entryHtml === key)
      if (!item) {
        continue
      }
      // Skip preloading for URL-type apps (loaded directly from network)
      if (item.entryHtml.startsWith('http://') || item.entryHtml.startsWith('https://')) {
        continue
      }
      if (!preloader.isPreloaded(key)) {
        let src = ''
        if (key.startsWith('rawfile://')) {
          src = key.substring(10)
        } else {
          src = 'file://' + key
        }
        preloader.preload(key, src)
      }
    }
  }

  getInitial(name: string): string {
    if (name.length > 0) {
      return name.charAt(0).toUpperCase()
    }
    return 'W'
  }

  getSourceColor(sourceType: string): Resource {
    if (sourceType === SourceType.PRESET) {
      return $r('app.color.app_success')
    }
    if (sourceType === SourceType.URL) {
      return $r('app.color.app_warning')
    }
    return $r('app.color.app_primary')
  }

  getSourceLabel(sourceType: string): Resource {
    if (sourceType === SourceType.PRESET) {
      return $r('app.string.source_preset')
    }
    if (sourceType === SourceType.URL) {
      return $r('app.string.source_url')
    }
    return $r('app.string.source_file')
  }

  toggleLayout(): void {
    this.layoutMode = this.layoutMode === LayoutMode.GRID ? LayoutMode.LIST : LayoutMode.GRID
    if (this.dbMgr) {
      this.dbMgr.setSetting('layout_mode', this.layoutMode)
    }
  }

  navigateToImport(): void {
    this.navPathStack.pushPath({ name: 'ImportPage' })
  }

  navigateToEdit(item: WebAppItem): void {
    const param: EditParam = {
      appId: item.id,
      appName: item.name,
      appDescription: item.description,
      logoType: item.logoType,
      logoUri: item.logoUri,
      entryHtml: item.entryHtml,
      sourceType: item.sourceType
    }
    this.navPathStack.pushPath({ name: 'EditPage', param: param })
  }

  showActionSheet(item: WebAppItem): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.action_title'),
      message: $r('app.string.action_prompt'),
      buttons: [
        {
          value: $r('app.string.btn_edit'),
          action: () => {
            this.navigateToEdit(item)
          }
        },
        {
          value: $r('app.string.btn_share'),
          action: () => {
            this.shareAppCard(item)
          }
        },
        {
          value: $r('app.string.btn_delete'),
          action: () => {
            this.confirmDelete(item)
          }
        },
        {
          value: $r('app.string.btn_cancel'),
          action: () => {}
        }
      ]
    })
  }

  openViewer(item: WebAppItem): void {
    const param: ViewerParam = { entryHtml: item.entryHtml, appName: item.name }
    this.navPathStack.pushPath({ name: 'ViewerPage', param: param })
  }

  confirmDelete(item: WebAppItem): void {
    const message = '确定要删除「' + item.name + '」吗？'
    this.getUIContext().showAlertDialog({
      title: $r('app.string.delete_confirm_title'),
      message: message,
      primaryButton: {
        value: $r('app.string.btn_confirm_delete'),
        action: () => {
          this.deleteApp(item)
        }
      },
      secondaryButton: {
        value: $r('app.string.btn_cancel'),
        action: () => {}
      }
    })
  }

  async deleteApp(item: WebAppItem): Promise<void> {
    if (!this.dbMgr) {
      return
    }
    await this.dbMgr.deleteApp(item.id)
    if (item.sourceType === SourceType.FILE && !item.entryHtml.startsWith('rawfile://') && item.persistMode.length === 0) {
      try {
        fs.accessSync(item.entryHtml)
        fs.unlinkSync(item.entryHtml)
      } catch (e) {
        Logger.error('Index', 'deleteApp file delete failed: ' + item.entryHtml)
      }
    }
    await this.loadApps()
    Toast.show('已删除')
  }

  private async shareAppCard(item: WebAppItem): Promise<void> {
    try {
      const uiContext: UIContext = this.getUIContext()
      const params: ShareCardParams = new ShareCardParams(item.name, item.description)
      const contentNode: ComponentContent<ShareCardParams> = new ComponentContent(uiContext, wrapBuilder(AppShareCardBuilder), params)

      const pixelMap: PixelMap = await uiContext.getComponentSnapshot()
        .createFromComponent(contentNode, 360, true, { scale: 2, waitUntilRenderFinished: true })

      const tmpPath: string = (this.context!).filesDir + '/share_card_' + Date.now().toString() + '.png'
      const packer: image.ImagePacker = image.createImagePacker()
      try {
        const packedData: ArrayBuffer = await packer.packToData(pixelMap, {
          format: 'image/png',
          quality: 100
        })
        const file = fs.openSync(tmpPath, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE)
        try {
          fs.writeSync(file.fd, packedData)
        } finally {
          fs.closeSync(file)
        }
      } finally {
        packer.release()
      }

      const imageUri: string = fileUri.getUriFromPath(tmpPath)
      const sharedData: systemShare.SharedData = new systemShare.SharedData({
        utd: utd.UniformDataType.IMAGE,
        uri: imageUri,
        title: item.name
      })

      const controller: systemShare.ShareController = new systemShare.ShareController(sharedData)
      let shared: boolean = false
      controller.on('shareCompleted', () => { shared = true })
      controller.on('dismiss', () => {
        setTimeout(() => {
          try {
            if (fs.accessSync(tmpPath)) { fs.unlinkSync(tmpPath) }
          } catch (e) { Logger.warn('Index', 'cleanup share temp file failed') }
        }, 3000)
      })
      controller.show(this.context! as common.UIAbilityContext, {})
    } catch (e) {
      Logger.error('Index', 'shareAppCard failed: ' + JSON.stringify(e))
      Toast.show('分享失败')
    }
  }

  private deleteDirectory(dirPath: string): void {
    try {
      const stack: string[] = [dirPath]
      const filesToDelete: string[] = []

      while (stack.length > 0) {
        const currentDir = stack.pop()!
        const entries = fs.listFileSync(currentDir)

        for (let i = 0; i < entries.length; i++) {
          const entry = entries[i]
          const fullPath = currentDir + '/' + entry
          const stat = fs.statSync(fullPath)
          if (stat.isDirectory()) {
            stack.push(fullPath)
          } else {
            filesToDelete.push(fullPath)
          }
        }
      }

      for (let i = filesToDelete.length - 1; i >= 0; i--) {
        fs.unlinkSync(filesToDelete[i])
      }

      const dirsToDelete: string[] = [dirPath]
      const tempStack: string[] = [dirPath]
      while (tempStack.length > 0) {
        const currentDir = tempStack.pop()!
        const entries = fs.listFileSync(currentDir)
        for (let i = 0; i < entries.length; i++) {
          const entry = entries[i]
          const fullPath = currentDir + '/' + entry
          const stat = fs.statSync(fullPath)
          if (stat.isDirectory()) {
            dirsToDelete.push(fullPath)
            tempStack.push(fullPath)
          }
        }
      }

      for (let i = dirsToDelete.length - 1; i >= 0; i--) {
        fs.rmdirSync(dirsToDelete[i])
      }
    } catch (e) {
      Logger.error('Index', 'deleteDirectory failed: ' + dirPath)
    }
  }

  @Builder
  SearchBar() {
    Row() {
      SymbolGlyph($r('sys.symbol.magnifyingglass'))
        .fontSize(16)
        .fontColor([$r('app.color.app_text_muted')])
      TextInput({ placeholder: $r('app.string.search_placeholder'), text: this.searchKeyword })
        .fontSize(14)
        .height(36)
        .backgroundColor(Color.Transparent)
        .layoutWeight(1)
        .onChange((value: string) => {
          this.searchKeyword = value
          this.dataSource.setApps(this.getFilteredApps())
        })
    }
    .width('100%')
    .height(44)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.app_search_bg'))
    .borderRadius(8)
    .margin({ left: 16, right: 16, top: 8, bottom: 8 })
  }

  @Builder
  CardItem(item: WebAppItem) {
    Row() {
      if (item.logoType === LogoType.CUSTOM && item.logoUri.length > 0) {
        Image('file://' + item.logoUri)
          .width(56)
          .height(56)
          .borderRadius(12)
          .objectFit(ImageFit.Cover)
          .hitTestBehavior(HitTestMode.None)
      } else {
        Stack() {
          Text(this.getInitial(item.name))
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .width(56)
        .height(56)
        .borderRadius(12)
        .linearGradient({
          angle: 135,
          colors: [['#6366F1', 0.0], ['#8B5CF6', 1.0]]
        })
        .alignContent(Alignment.Center)
      }

      Column() {
        Row() {
          Text(item.name)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.app_text_primary'))
            .layoutWeight(1)

          Text(this.getSourceLabel(item.sourceType))
            .fontSize(11)
            .fontColor(Color.White)
            .backgroundColor(this.getSourceColor(item.sourceType))
            .borderRadius(4)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .alignItems(VerticalAlign.Center)

        if (item.description.length > 0) {
          Text(item.description)
            .fontSize(13)
            .fontColor($r('app.color.app_text_secondary'))
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 6 })
            .width('100%')
        }
      }
      .layoutWeight(1)
      .margin({ left: 12 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(16)
    .borderRadius(12)
    .backgroundColor($r('app.color.app_card_bg'))
    .shadow({
      radius: 6,
      color: $r('app.color.app_shadow'),
      offsetX: 0,
      offsetY: 2
    })
    .onClick(() => {
      this.openViewer(item)
    })
    .gesture(
      LongPressGesture()
        .onAction(() => {
          this.showActionSheet(item)
        })
    )
    .stateStyles({
      pressed: {
        .scale({ x: 0.96, y: 0.96 })
      }
    })
  }

  @Builder
  GridCardItem(item: WebAppItem) {
    Column({ space: 8 }) {
      if (item.logoType === LogoType.CUSTOM && item.logoUri.length > 0) {
        Image('file://' + item.logoUri)
          .width(64)
          .height(64)
          .borderRadius(14)
          .objectFit(ImageFit.Cover)
          .hitTestBehavior(HitTestMode.None)
      } else {
        Stack() {
          Text(this.getInitial(item.name))
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .width(64)
        .height(64)
        .borderRadius(14)
        .linearGradient({
          angle: 135,
          colors: [['#6366F1', 0.0], ['#8B5CF6', 1.0]]
        })
        .alignContent(Alignment.Center)
      }

      Column({ space: 4 }) {
        Text(item.name)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.app_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)

        Text(this.getSourceLabel(item.sourceType))
          .fontSize(10)
          .fontColor(Color.White)
          .backgroundColor(this.getSourceColor(item.sourceType))
          .borderRadius(4)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
      }
      .alignItems(HorizontalAlign.Center)

      if (item.description.length > 0) {
        Text(item.description)
          .fontSize(11)
          .fontColor($r('app.color.app_text_muted'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor($r('app.color.app_card_bg'))
    .shadow({
      radius: 6,
      color: $r('app.color.app_shadow'),
      offsetX: 0,
      offsetY: 1
    })
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.openViewer(item)
    })
    .gesture(
      LongPressGesture()
        .onAction(() => {
          this.showActionSheet(item)
        })
    )
    .stateStyles({
      pressed: {
        .scale({ x: 0.96, y: 0.96 })
      }
    })
  }

  @Builder
  Menus() {
    Row({ space: 8 }) {
      Button({ type: ButtonType.Normal, buttonStyle: ButtonStyleMode.TEXTUAL }) {
        SymbolGlyph(this.layoutMode === LayoutMode.GRID ? $r('sys.symbol.list_bullet') : $r('sys.symbol.square_grid_2x2'))
          .fontSize(16)
          .fontColor([$r('app.color.app_text_secondary')])
      }
      .height(32)
      .borderRadius(6)
      .onClick(() => {
        this.toggleLayout()
      })

      Button({ type: ButtonType.Normal, buttonStyle: ButtonStyleMode.TEXTUAL }) {
        SymbolGlyph($r('sys.symbol.gearshape'))
          .fontSize(16)
          .fontColor([$r('app.color.app_text_secondary')])
      }
      .height(32)
      .borderRadius(6)
      .onClick(() => {
        this.navPathStack.pushPath({ name: 'SettingsPage' })
      })

      Button({ type: ButtonType.Normal, buttonStyle: ButtonStyleMode.TEXTUAL }) {
        Row({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.plus'))
            .fontSize(16)
            .fontColor([$r('app.color.app_primary')])
          Text($r('app.string.nav_title_import'))
            .fontSize(13)
            .fontColor($r('app.color.app_primary'))
        }
      }
      .height(32)
      .borderRadius(6)
      .onClick(() => {
        this.navigateToImport()
      })
    }
    .height('100%')
    .padding({ right: 8 })
  }

  @Builder
  buildNavDestination(name: string) {
    if (name === 'ImportPage') {
      ImportPage()
    } else if (name === 'ViewerPage') {
      ViewerPage()
    } else if (name === 'EditPage') {
      EditPage()
    } else if (name === 'SettingsPage') {
      SettingsPage()
    }
  }

  build() {
    Navigation(this.navPathStack) {
      Column() {
        this.SearchBar()

        if (this.getFilteredApps().length === 0) {
          Column({ space: 16 }) {
            if (this.searchKeyword.length > 0) {
              Text('🔍')
                .fontSize(48)
              Text($r('app.string.no_match_title'))
                .fontSize(16)
                .fontColor($r('app.color.app_text_muted'))
              Text($r('app.string.no_match_desc'))
                .fontSize(13)
                .fontColor($r('app.color.app_text_disabled'))
            } else {
              Text('📦')
                .fontSize(64)
              Column({ space: 4 }) {
                Text($r('app.string.empty_title'))
                  .fontSize(18)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.app_text_primary'))
                Text($r('app.string.empty_desc'))
                  .fontSize(13)
                  .fontColor($r('app.color.app_text_muted'))
              }

              Button() {
                Row({ space: 6 }) {
                  SymbolGlyph($r('sys.symbol.plus'))
                    .fontSize(16)
                    .fontColor([Color.White])
                  Text($r('app.string.btn_import_app'))
                    .fontSize(15)
                    .fontColor(Color.White)
                }
              }
              .height(44)
              .borderRadius(22)
              .backgroundColor($r('app.color.app_primary'))
              .padding({ left: 24, right: 24 })
              .onClick(() => {
                this.navigateToImport()
              })

              Button() {
                Row({ space: 4 }) {
                  Text('📋')
                    .fontSize(14)
                  Text($r('app.string.btn_try_preset'))
                    .fontSize(13)
                    .fontColor($r('app.color.app_text_secondary'))
                }
              }
              .height(36)
              .borderRadius(18)
              .backgroundColor($r('app.color.app_card_bg'))
              .border({ width: 1, color: $r('app.color.app_border') })
              .onClick(() => {
                this.ensurePresetApps()
              })
            }
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        } else {
          Refresh({ refreshing: $$this.isRefreshing }) {
            if (this.layoutMode === LayoutMode.GRID) {
              Scroll() {
                Grid() {
                  LazyForEach(this.dataSource, (item: WebAppItem) => {
                    GridItem() {
                      this.GridCardItem(item)
                    }
                  }, (item: WebAppItem) => item.id)
                }
                .cachedCount(10)
                .columnsTemplate('1fr 1fr')
                .columnsGap(12)
                .rowsGap(12)
                .width('100%')
                .padding({ left: 16, right: 16, top: 12, bottom: 16 })
              }
              .width('100%')
              .layoutWeight(1)
              .scrollBar(BarState.Off)
              .edgeEffect(EdgeEffect.Spring)
            } else {
              List({ space: 12 }) {
                LazyForEach(this.dataSource, (item: WebAppItem) => {
                  ListItem() {
                    this.CardItem(item)
                  }
                }, (item: WebAppItem) => item.id)
              }
              .cachedCount(10)
              .width('100%')
              .layoutWeight(1)
              .padding({ left: 16, right: 16, top: 12, bottom: 16 })
              .scrollBar(BarState.Off)
              .edgeEffect(EdgeEffect.Spring)
            }
          }
          .onRefreshing(() => {
            this.scanWorkDirectory()
          })
          .backgroundColor($r('app.color.app_background'))
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.app_background'))
      .transition(TransitionEffect.opacity(0.5).animation({ duration: 300, curve: Curve.EaseInOut }))
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.app_background'))
    .title($r('app.string.nav_title_apps'))
    .menus(this.Menus)
    .navDestination(this.buildNavDestination)
    .mode(NavigationMode.Stack)
  }
}
